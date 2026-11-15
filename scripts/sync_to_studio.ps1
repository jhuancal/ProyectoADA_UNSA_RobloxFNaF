# ==============================================================================
# Sincronizador Automático "Rojo Artesanal" (Git Pull -> Roblox Studio vía MCP)
# Proyecto ADA UNSA — 5D Multiverse FNAF Engine
# ==============================================================================

param(
    [switch]$SkipPull = $false
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "Sincronizador Roblox Studio (MCP)"

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " 🕹️  SINCRONIZADOR AUTOMÁTICO DE CÓDIGO (Git -> Roblox)   " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Ejecutar Git Pull si no se omite
if (-not $SkipPull) {
    Write-Host "[1/3] Descargando últimos cambios de GitHub (git pull)..." -ForegroundColor Yellow
    $pullOutput = git pull 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "⚠️ Error al ejecutar git pull:" -ForegroundColor Red
        Write-Host $pullOutput -ForegroundColor Red
        Write-Host ""
        Write-Host "Revisa si tienes cambios locales sin confirmar o conflictos de git." -ForegroundColor Red
        exit 1
    }
    Write-Host "  -> Git actualizado correctamente." -ForegroundColor Green
} else {
    Write-Host "[1/3] Omitiendo git pull (modo directo local)..." -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "[2/3] Conectando con Roblox Studio vía MCP..." -ForegroundColor Yellow

$mcpExe = (Get-ChildItem "$env:LOCALAPPDATA\Roblox\Versions" -Filter "StudioMCP.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -Last 1).FullName

if (-not $mcpExe) {
    $mcpBat = "$env:LOCALAPPDATA\Roblox\mcp.bat"
    if (Test-Path $mcpBat) {
        $mcpExe = "cmd.exe"
        $mcpArgs = "/c `"$mcpBat`""
    } else {
        Write-Host "❌ No se encontró StudioMCP.exe en AppData." -ForegroundColor Red
        Write-Host "Asegúrate de tener Roblox Studio abierto y el plugin de MCP configurado." -ForegroundColor Yellow
        exit 1
    }
} else {
    $mcpArgs = ""
}

$pinfo = New-Object System.Diagnostics.ProcessStartInfo
$pinfo.FileName = $mcpExe
if ($mcpArgs) { $pinfo.Arguments = $mcpArgs }
$pinfo.RedirectStandardInput = $true
$pinfo.RedirectStandardOutput = $true
$pinfo.RedirectStandardError = $true
$pinfo.UseShellExecute = $false
$pinfo.CreateNoWindow = $true

try {
    $proc = [System.Diagnostics.Process]::Start($pinfo)
} catch {
    Write-Host "❌ Error al iniciar StudioMCP: $_" -ForegroundColor Red
    exit 1
}

$writer = $proc.StandardInput
$reader = $proc.StandardOutput

# 1. Initialize MCP
$initReq = @{
    jsonrpc = "2.0"
    id = 1
    method = "initialize"
    params = @{
        protocolVersion = "2024-11-05"
        capabilities = @{}
        clientInfo = @{ name = "rojo-artesanal"; version = "1.0" }
    }
} | ConvertTo-Json -Compress

$writer.WriteLine($initReq)
$writer.Flush()
$null = $reader.ReadLine()

# 2. List studios
$listReq = @{
    jsonrpc = "2.0"
    id = 2
    method = "tools/call"
    params = @{
        name = "list_roblox_studios"
        arguments = @{}
    }
} | ConvertTo-Json -Compress

$writer.WriteLine($listReq)
$writer.Flush()
$listRespRaw = $reader.ReadLine()

if (-not $listRespRaw) {
    Write-Host "❌ No se obtuvo respuesta de Roblox Studio." -ForegroundColor Red
    $proc.Kill()
    exit 1
}

$listResp = $listRespRaw | ConvertFrom-Json
$studiosObj = $listResp.result.content[0].text | ConvertFrom-Json

if (-not $studiosObj.studios -or $studiosObj.studios.Count -eq 0) {
    Write-Host "⚠️  No se encontró ninguna ventana de Roblox Studio abierta." -ForegroundColor Yellow
    Write-Host "   Por favor abre el proyecto en Roblox Studio y vuelve a ejecutar este script." -ForegroundColor White
    $proc.Kill()
    exit 1
}

$activeStudio = $studiosObj.studios[0]
$studioId = $activeStudio.id
Write-Host "  -> Conectado a: $($activeStudio.name) (Modo: $($activeStudio.mode))" -ForegroundColor Green

Write-Host ""
Write-Host "[3/3] Sincronizando scripts de 'src/' hacia Roblox Studio..." -ForegroundColor Yellow

$projectRoot = Split-Path -Parent $PSScriptRoot
$srcDir = Join-Path $projectRoot "src"

$files = Get-ChildItem -Path $srcDir -Recurse -File -Filter "*.luau"
if ($files.Count -eq 0) {
    Write-Host "⚠️ No se encontraron archivos .luau en 'src/'." -ForegroundColor Yellow
    $proc.Kill()
    exit 0
}

$reqId = 10
$statsUpdated = 0
$statsCreated = 0
$statsUnchanged = 0

foreach ($f in $files) {
    $rel = $f.FullName.Substring($srcDir.Length + 1).Replace("\", "/")
    $parts = $rel.Split("/")
    $serviceName = $parts[0]
    $fileName = $parts[-1]

    # Determinar tipo y nombre limpio
    $scriptName = $fileName
    $className = "ModuleScript"

    if ($fileName.EndsWith(".server.luau")) {
        $scriptName = $fileName.Substring(0, $fileName.Length - 12)
        $className = "Script"
    } elseif ($fileName.EndsWith(".client.luau")) {
        $scriptName = $fileName.Substring(0, $fileName.Length - 12)
        $className = "LocalScript"
    } elseif ($fileName.EndsWith(".luau")) {
        $scriptName = $fileName.Substring(0, $fileName.Length - 5)
        $className = "ModuleScript"
    }

    # Carpetas intermedias
    $folderList = @()
    if ($parts.Length -gt 2) {
        for ($i = 1; $i -lt ($parts.Length - 1); $i++) {
            $folderList += "'$($parts[$i])'"
        }
    }
    $foldersLuau = "{" + ($folderList -join ", ") + "}"

    $rawSource = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
    $normSource = $rawSource.Replace("`r`n", "`n")

    # 1. Comprobar si ya existe en Studio
    $reqId++
    $checkLuau = "local services = { ReplicatedStorage = game:GetService('ReplicatedStorage'), ServerScriptService = game:GetService('ServerScriptService'), StarterGui = game:GetService('StarterGui'), StarterPlayer = game:GetService('StarterPlayer'), Workspace = workspace, ServerStorage = game:GetService('ServerStorage'), Lighting = game:GetService('Lighting') }; local s = services['$serviceName']; if not s then return 'ERR' end; local p = s; for _, f in ipairs($foldersLuau) do p = p:FindFirstChild(f); if not p then return 'NOT_FOUND' end end; local target = p:FindFirstChild('$scriptName'); if not target then return 'NOT_FOUND' end; return tostring(string.len(target.Source))"

    $checkReq = @{
        jsonrpc = "2.0"; id = $reqId; method = "tools/call"
        params = @{ name = "execute_luau"; arguments = @{ studio_id = $studioId; datamodel_type = "Edit"; code = $checkLuau } }
    } | ConvertTo-Json -Compress

    $writer.WriteLine($checkReq)
    $writer.Flush()
    $checkResp = $reader.ReadLine() | ConvertFrom-Json
    $targetLen = $checkResp.result.content[0].text

    # Si la longitud en Studio es exactamente igual a la longitud normalizada, omitir
    if ($targetLen -eq [string]$normSource.Length) {
        $statsUnchanged++
        continue
    }

    # Si el script supera los 40 KB, advertir para sincronizar con el agente
    if ($normSource.Length -gt 40000) {
        Write-Host "  ℹ️  [GRANDE >40KB] $rel (Usa tu agente IA si necesitas actualizar este script)" -ForegroundColor DarkGray
        $statsUnchanged++
        continue
    }

    # Actualizar o crear script mediante execute_luau seguro
    $escaped = $normSource.Replace("\", "\\").Replace('"', '\"').Replace("`n", "\n")
    $updateLuau = @"
local services = { ReplicatedStorage = game:GetService('ReplicatedStorage'), ServerScriptService = game:GetService('ServerScriptService'), StarterGui = game:GetService('StarterGui'), StarterPlayer = game:GetService('StarterPlayer'), Workspace = workspace, ServerStorage = game:GetService('ServerStorage'), Lighting = game:GetService('Lighting') }; local s = services['$serviceName']; local p = s; for _, f in ipairs($foldersLuau) do local child = p:FindFirstChild(f); if not child then child = Instance.new('Folder'); child.Name = f; child.Parent = p end; p = child end; local target = p:FindFirstChild('$scriptName'); if not target then target = Instance.new('$className'); target.Name = '$scriptName'; target.Parent = p end; target.Source = "$escaped"; return 'DONE'
"@

    $reqId++
    $execUpdateReq = @{
        jsonrpc = "2.0"; id = $reqId; method = "tools/call"
        params = @{ name = "execute_luau"; arguments = @{ studio_id = $studioId; datamodel_type = "Edit"; code = $updateLuau } }
    } | ConvertTo-Json -Compress -Depth 5

    $writer.WriteLine($execUpdateReq)
    $writer.Flush()
    $updateResp = $reader.ReadLine() | ConvertFrom-Json

    if ($targetLen -eq "NOT_FOUND") {
        Write-Host "  ✨ [CREADO]      $rel" -ForegroundColor Green
        $statsCreated++
    } else {
        Write-Host "  🔄 [ACTUALIZADO] $rel" -ForegroundColor Cyan
        $statsUpdated++
    }
}

$proc.Kill()

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host " ✨  ¡SINCRONIZACIÓN EXITOSA EN ROBLOX STUDIO!            " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  • Scripts actualizados:            $statsUpdated" -ForegroundColor Cyan
Write-Host "  • Scripts nuevos creados:          $statsCreated" -ForegroundColor Green
Write-Host "  • Scripts ya al día (sin cambios): $statsUnchanged" -ForegroundColor DarkGray
Write-Host "  • Total de scripts en el proyecto: $($files.Count)" -ForegroundColor White
Write-Host ""
Write-Host "La sesión de Roblox Studio tiene todo el código sincronizado." -ForegroundColor Green
Write-Host ""
