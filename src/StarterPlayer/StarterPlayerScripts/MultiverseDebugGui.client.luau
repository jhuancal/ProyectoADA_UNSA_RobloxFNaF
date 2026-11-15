--!strict
--[[
    MultiverseDebugGui.client.luau
    Ubicación: StarterPlayer.StarterPlayerScripts.MultiverseDebugGui
    Propósito:
    LocalScript 100% autónomo que genera dinámicamente una ScreenGui de depuración
    para visualizar en tiempo real el grafo espacial, las líneas de tiempo del
    multiverso, el movimiento suavizado de los animatrónicos, controles de pausa/paso
    y el registro de eventos, compatible con el sistema de Lobby.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

if not RunService:IsStudio() then
    return
end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NetworkProtocol = require(Shared:WaitForChild("NetworkProtocol"))
local RoomSpaceConfig = require(Shared:WaitForChild("RoomSpaceConfig"))
local remotos = NetworkProtocol.obtenerRemotos()

local debugEvento = remotos.DebugEvento :: RemoteEvent
local debugControl = remotos.DebugControl :: RemoteEvent
local debugGetEstado = remotos.DebugGetEstado :: RemoteFunction

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- ============================================================================
-- Configuración visual y coordenadas predefinidas
-- ============================================================================

local COLORES_ANIMATRONICOS: { [string]: Color3 } = {
    Bonnie = Color3.fromRGB(136, 85, 216),
    Chica  = Color3.fromRGB(242, 202, 65),
    Foxy   = Color3.fromRGB(200, 66, 54),
    Freddy = Color3.fromRGB(145, 92, 54),
}

local MAX_LOGS = 150
local TWEEN_INFO_MOV = TweenInfo.new(0.14, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

-- ============================================================================
-- Construcción dinámica de la ScreenGui (100% Instance.new)
-- ============================================================================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MultiverseDebug"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 100
screenGui.Parent = playerGui

local function crearEsquina(parent: Instance, radio: number)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radio)
    c.Parent = parent
end

local function crearBorde(parent: Instance, color: Color3, grosor: number, transparencia: number?)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = grosor
    s.Transparency = transparencia or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

-- Botón flotante para ocultar/mostrar todo el panel de debug
local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "ToggleDebugButton"
toggleBtn.Size = UDim2.fromOffset(145, 30)
toggleBtn.Position = UDim2.new(1, -16, 0, 10)
toggleBtn.AnchorPoint = Vector2.new(1, 0)
toggleBtn.BackgroundColor3 = Color3.fromRGB(30, 34, 46)
toggleBtn.TextColor3 = Color3.fromRGB(235, 240, 250)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 12
toggleBtn.Text = "Ocultar Debug"
toggleBtn.ZIndex = 20
toggleBtn.Parent = screenGui
crearEsquina(toggleBtn, 6)
crearBorde(toggleBtn, Color3.fromRGB(80, 140, 220), 1.5)

-- Contenedor principal
local root = Instance.new("Frame")
root.Name = "Root"
root.Size = UDim2.fromScale(0.92, 0.85)
root.Position = UDim2.fromScale(0.5, 0.53)
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
root.BackgroundTransparency = 0.06
root.Parent = screenGui
crearEsquina(root, 10)
crearBorde(root, Color3.fromRGB(52, 60, 78), 1.5)
screenGui:SetAttribute("PanelVisible", root.Visible)

-- Barra superior
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, -16, 0, 44)
topBar.Position = UDim2.fromOffset(8, 8)
topBar.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
topBar.Parent = root
crearEsquina(topBar, 8)
crearBorde(topBar, Color3.fromRGB(45, 52, 68), 1)

local timelinesScroll = Instance.new("ScrollingFrame")
timelinesScroll.Name = "TimelinesScroll"
timelinesScroll.Size = UDim2.new(0.32, -8, 1, -8)
timelinesScroll.Position = UDim2.fromOffset(6, 4)
timelinesScroll.BackgroundTransparency = 1
timelinesScroll.ScrollBarThickness = 3
timelinesScroll.ScrollingDirection = Enum.ScrollingDirection.X
timelinesScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
timelinesScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
timelinesScroll.Parent = topBar

local timelinesLayout = Instance.new("UIListLayout")
timelinesLayout.FillDirection = Enum.FillDirection.Horizontal
timelinesLayout.VerticalAlignment = Enum.VerticalAlignment.Center
timelinesLayout.Padding = UDim.new(0, 6)
timelinesLayout.Parent = timelinesScroll

local controlesFrame = Instance.new("Frame")
controlesFrame.Name = "Controles"
controlesFrame.Size = UDim2.new(0.68, -8, 1, -8)
controlesFrame.Position = UDim2.new(0.32, 4, 0, 4)
controlesFrame.BackgroundTransparency = 1
controlesFrame.Parent = topBar

local btnIniciar = Instance.new("TextButton")
btnIniciar.Name = "BtnIniciarNoche"
btnIniciar.Size = UDim2.fromOffset(145, 30)
btnIniciar.Position = UDim2.new(0, 0, 0.5, 0)
btnIniciar.AnchorPoint = Vector2.new(0, 0.5)
btnIniciar.BackgroundColor3 = Color3.fromRGB(36, 155, 88)
btnIniciar.TextColor3 = Color3.fromRGB(255, 255, 255)
btnIniciar.Font = Enum.Font.GothamBold
btnIniciar.TextSize = 12
btnIniciar.Text = "▶ Iniciar Noche 5D"
btnIniciar.Parent = controlesFrame
crearEsquina(btnIniciar, 6)

local btnPausa = Instance.new("TextButton")
btnPausa.Name = "BtnPausa"
btnPausa.Size = UDim2.fromOffset(96, 30)
btnPausa.Position = UDim2.new(0, 151, 0.5, 0)
btnPausa.AnchorPoint = Vector2.new(0, 0.5)
btnPausa.BackgroundColor3 = Color3.fromRGB(40, 44, 56)
btnPausa.TextColor3 = Color3.fromRGB(130, 138, 155)
btnPausa.Font = Enum.Font.GothamBold
btnPausa.TextSize = 12
btnPausa.Text = "|| Pausar"
btnPausa.Active = false
btnPausa.Parent = controlesFrame
crearEsquina(btnPausa, 6)

local btnPaso = Instance.new("TextButton")
btnPaso.Name = "BtnPaso"
btnPaso.Size = UDim2.fromOffset(96, 30)
btnPaso.Position = UDim2.new(0, 253, 0.5, 0)
btnPaso.AnchorPoint = Vector2.new(0, 0.5)
btnPaso.BackgroundColor3 = Color3.fromRGB(40, 44, 56)
btnPaso.TextColor3 = Color3.fromRGB(130, 138, 155)
btnPaso.Font = Enum.Font.GothamBold
btnPaso.TextSize = 12
btnPaso.Text = ">> +1 Tick"
btnPaso.Active = false
btnPaso.Parent = controlesFrame
crearEsquina(btnPaso, 6)

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, -356, 1, 0)
statusLabel.Position = UDim2.fromOffset(355, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.fromRGB(195, 215, 240)
statusLabel.Font = Enum.Font.Code
statusLabel.TextSize = 11
statusLabel.TextXAlignment = Enum.TextXAlignment.Right
statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
statusLabel.Text = "[LOBBY] Conectando..."
statusLabel.Parent = controlesFrame

-- Cuerpo principal
local body = Instance.new("Frame")
body.Name = "Body"
body.Size = UDim2.new(1, -16, 1, -66)
body.Position = UDim2.fromOffset(8, 58)
body.BackgroundTransparency = 1
body.Parent = root

-- Panel Principal: Mapa Aéreo 2D de la Pizzería
local mapPanel = Instance.new("Frame")
mapPanel.Name = "MapPanel"
mapPanel.Size = UDim2.new(0.68, -6, 1, 0)
mapPanel.Position = UDim2.fromScale(0, 0)
mapPanel.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
mapPanel.ClipsDescendants = true
mapPanel.Parent = body
crearEsquina(mapPanel, 8)
crearBorde(mapPanel, Color3.fromRGB(45, 52, 68), 1)

-- Contenedor con proporción fija 30x17 para el mapa aéreo
local mapCanvas = Instance.new("Frame")
mapCanvas.Name = "MapCanvas"
mapCanvas.Size = UDim2.new(0.97, 0, 0.86, 0)
mapCanvas.Position = UDim2.new(0.5, 0, 0.46, 0)
mapCanvas.AnchorPoint = Vector2.new(0.5, 0.5)
mapCanvas.BackgroundColor3 = Color3.fromRGB(28, 33, 42)
mapCanvas.BorderSizePixel = 0
mapCanvas.Parent = mapPanel
crearEsquina(mapCanvas, 6)
crearBorde(mapCanvas, Color3.fromRGB(55, 64, 82), 1.5)

local aspect = Instance.new("UIAspectRatioConstraint")
aspect.AspectRatio = RoomSpaceConfig.GRID_COLS / RoomSpaceConfig.GRID_ROWS
aspect.AspectType = Enum.AspectType.FitWithinMaxSize
aspect.DominantAxis = Enum.DominantAxis.Width
aspect.Parent = mapCanvas

local tilesLayer = Instance.new("Frame")
tilesLayer.Name = "TilesLayer"
tilesLayer.Size = UDim2.fromScale(1, 1)
tilesLayer.BackgroundTransparency = 1
tilesLayer.ZIndex = 1
tilesLayer.Parent = mapCanvas

local labelsLayer = Instance.new("Frame")
labelsLayer.Name = "LabelsLayer"
labelsLayer.Size = UDim2.fromScale(1, 1)
labelsLayer.BackgroundTransparency = 1
labelsLayer.ZIndex = 4
labelsLayer.Parent = mapCanvas

local tokensLayer = Instance.new("Frame")
tokensLayer.Name = "TokensLayer"
tokensLayer.Size = UDim2.fromScale(1, 1)
tokensLayer.BackgroundTransparency = 1
tokensLayer.ZIndex = 6
tokensLayer.Parent = mapCanvas

-- Capa interactiva de controles de puertas (en la parte inferior del mapa)
local doorsLayer = Instance.new("Frame")
doorsLayer.Name = "DoorsLayer"
doorsLayer.Size = UDim2.fromScale(1, 1)
doorsLayer.BackgroundTransparency = 1
doorsLayer.ZIndex = 12
doorsLayer.Parent = mapPanel

local btnPuertaIzq = Instance.new("TextButton")
btnPuertaIzq.Name = "BtnPuertaIzquierda"
btnPuertaIzq.Size = UDim2.fromOffset(122, 32)
btnPuertaIzq.Position = UDim2.new(0, 12, 1, -70)
btnPuertaIzq.AnchorPoint = Vector2.new(0, 0)
btnPuertaIzq.BackgroundColor3 = Color3.fromRGB(26, 48, 38)
btnPuertaIzq.Font = Enum.Font.GothamBold
btnPuertaIzq.TextSize = 10
btnPuertaIzq.TextColor3 = Color3.fromRGB(130, 235, 175)
btnPuertaIzq.Text = "🚪 [Q] Izquierda: ABIERTA"
btnPuertaIzq.ZIndex = 14
btnPuertaIzq.Parent = doorsLayer
crearEsquina(btnPuertaIzq, 6)
crearBorde(btnPuertaIzq, Color3.fromRGB(45, 160, 100), 1.5)

local btnPuertaDer = Instance.new("TextButton")
btnPuertaDer.Name = "BtnPuertaDerecha"
btnPuertaDer.Size = UDim2.fromOffset(122, 32)
btnPuertaDer.Position = UDim2.new(1, -12, 1, -70)
btnPuertaDer.AnchorPoint = Vector2.new(1, 0)
btnPuertaDer.BackgroundColor3 = Color3.fromRGB(26, 48, 38)
btnPuertaDer.Font = Enum.Font.GothamBold
btnPuertaDer.TextSize = 10
btnPuertaDer.TextColor3 = Color3.fromRGB(130, 235, 175)
btnPuertaDer.Text = "🚪 [E] Derecha: ABIERTA"
btnPuertaDer.ZIndex = 14
btnPuertaDer.Parent = doorsLayer
crearEsquina(btnPuertaDer, 6)
crearBorde(btnPuertaDer, Color3.fromRGB(45, 160, 100), 1.5)

-- Banner de control y navegación por el grafo (teclado / mouse)
local navBadge = Instance.new("Frame")
navBadge.Name = "NavBadge"
navBadge.Size = UDim2.new(1, -20, 0, 26)
navBadge.Position = UDim2.new(0, 10, 1, -32)
navBadge.BackgroundColor3 = Color3.fromRGB(15, 18, 26)
navBadge.BackgroundTransparency = 0.2
navBadge.ZIndex = 25
navBadge.Parent = mapPanel
crearEsquina(navBadge, 6)
crearBorde(navBadge, Color3.fromRGB(0, 195, 230), 1)

local navLabel = Instance.new("TextLabel")
navLabel.Name = "NavLabel"
navLabel.Size = UDim2.fromScale(1, 1)
navLabel.BackgroundTransparency = 1
navLabel.Font = Enum.Font.GothamMedium
navLabel.TextSize = 11
navLabel.TextColor3 = Color3.fromRGB(180, 235, 255)
navLabel.Text = "🎮 NAVEGACIÓN [Flechas / WASD o Clic]: Moverse por el Grafo | Tu sala: Oficina"
navLabel.ZIndex = 26
navLabel.Parent = navBadge

-- Panel Lateral: Estado + Logs
local sidePanel = Instance.new("Frame")
sidePanel.Name = "SidePanel"
sidePanel.Size = UDim2.new(0.32, 0, 1, 0)
sidePanel.Position = UDim2.fromScale(0.68, 0)
sidePanel.BackgroundTransparency = 1
sidePanel.Parent = body

local estadoBox = Instance.new("Frame")
estadoBox.Name = "EstadoBox"
estadoBox.Size = UDim2.new(1, 0, 0.36, -4)
estadoBox.BackgroundColor3 = Color3.fromRGB(22, 25, 34)
estadoBox.Parent = sidePanel
crearEsquina(estadoBox, 8)
crearBorde(estadoBox, Color3.fromRGB(45, 52, 68), 1)

local estadoTitulo = Instance.new("TextLabel")
estadoTitulo.Name = "EstadoTitulo"
estadoTitulo.Size = UDim2.new(1, -12, 0, 24)
estadoTitulo.Position = UDim2.fromOffset(8, 4)
estadoTitulo.BackgroundTransparency = 1
estadoTitulo.Text = "ESTADO ANIMATRONICOS"
estadoTitulo.Font = Enum.Font.GothamBold
estadoTitulo.TextSize = 11
estadoTitulo.TextColor3 = Color3.fromRGB(130, 185, 255)
estadoTitulo.TextXAlignment = Enum.TextXAlignment.Left
estadoTitulo.Parent = estadoBox

local estadoScroll = Instance.new("ScrollingFrame")
estadoScroll.Name = "EstadoScroll"
estadoScroll.Size = UDim2.new(1, -10, 1, -30)
estadoScroll.Position = UDim2.fromOffset(5, 26)
estadoScroll.BackgroundTransparency = 1
estadoScroll.ScrollBarThickness = 4
estadoScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
estadoScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
estadoScroll.Parent = estadoBox

local estadoLayout = Instance.new("UIListLayout")
estadoLayout.Padding = UDim.new(0, 4)
estadoLayout.Parent = estadoScroll

local logsBox = Instance.new("Frame")
logsBox.Name = "LogsBox"
logsBox.Size = UDim2.new(1, 0, 0.64, -2)
logsBox.Position = UDim2.new(0, 0, 0.36, 2)
logsBox.BackgroundColor3 = Color3.fromRGB(22, 25, 34)
logsBox.Parent = sidePanel
crearEsquina(logsBox, 8)
crearBorde(logsBox, Color3.fromRGB(45, 52, 68), 1)

local logsTitulo = Instance.new("TextLabel")
logsTitulo.Name = "LogsTitulo"
logsTitulo.Size = UDim2.new(1, -12, 0, 24)
logsTitulo.Position = UDim2.fromOffset(8, 4)
logsTitulo.BackgroundTransparency = 1
logsTitulo.Text = "HISTORIAL DE MOVIMIENTOS"
logsTitulo.Font = Enum.Font.GothamBold
logsTitulo.TextSize = 11
logsTitulo.TextColor3 = Color3.fromRGB(130, 185, 255)
logsTitulo.TextXAlignment = Enum.TextXAlignment.Left
logsTitulo.Parent = logsBox

local logsScroll = Instance.new("ScrollingFrame")
logsScroll.Name = "LogsScroll"
logsScroll.Size = UDim2.new(1, -10, 1, -30)
logsScroll.Position = UDim2.fromOffset(5, 26)
logsScroll.BackgroundTransparency = 1
logsScroll.ScrollBarThickness = 4
logsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
logsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
logsScroll.Parent = logsBox

local logsLayout = Instance.new("UIListLayout")
logsLayout.Padding = UDim.new(0, 2)
logsLayout.Parent = logsScroll

-- ============================================================================
-- Estado interno del cliente de depuración
-- ============================================================================

local estadoActual: any = nil
local lineaSeleccionada = "L0"
local pausadoLocal = false

local mapaConstruido = false
local doorTileFrames: { [string]: Frame } = {}
local alertBadges: { [string]: Frame } = {}
local timelineButtons: { [string]: TextButton } = {}

type PasoCola = {
    sala: string,
    gx: number,
    gy: number,
}

type TokenInfo = {
    frame: Frame,
    stroke: UIStroke,
    nodoActual: string,
    gx: number,
    gy: number,
    cola: { PasoCola },
    animando: boolean,
}
local tokens: { [string]: TokenInfo } = {}
local estadoRows: { [string]: TextLabel } = {}
local logItems: { TextLabel } = {}

-- Variables de estado para navegación del jugador en el mapa aéreo 2D (estilo Pac-Man)
local nodoJugadorActual = "Oficina"
local gxJugador, gyJugador = RoomSpaceConfig.obtenerSpawnSala("Oficina")
local tokenJugadorFrame: Frame? = nil
local tokenJugadorStroke: UIStroke? = nil
local animandoJugador = false
local caminoJugadorId = 0
local intentarMoverJugadorACelda: ((number, number) -> ())? = nil
local asegurarTokenJugador: (() -> Frame)? = nil
local actualizarPuertasMapa: (() -> ())? = nil
local verificarPeligroAnimatronicoEnSala: (() -> ())? = nil
local actualizarBotonesPuertas: (() -> ())? = nil
local actualizarPanelEstado: ((any) -> ())? = nil
local alternarPuerta: ((lado: "Izquierda" | "Derecha") -> ())? = nil

-- Flags persistentes de puertas por línea de tiempo (mantienen el estado cerrado/abierto de forma estable)
local flagsPuertas: { [string]: { Izquierda: boolean, Derecha: boolean } } = {}
local function obtenerFlagsPuertas(lineaId: string): { Izquierda: boolean, Derecha: boolean }
    local f = flagsPuertas[lineaId]
    if not f then
        f = {
            Izquierda = false,
            Derecha = false,
        }
        flagsPuertas[lineaId] = f
    end
    return f
end

-- ============================================================================
-- Utilidades
-- ============================================================================

local function obtenerColorAnimatronico(nombre: string): Color3
    if COLORES_ANIMATRONICOS[nombre] then
        return COLORES_ANIMATRONICOS[nombre]
    end
    local hash = 0
    for i = 1, #nombre do
        hash = (hash * 31 + string.byte(nombre, i)) % 360
    end
    return Color3.fromHSV(hash / 360, 0.68, 0.92)
end

local function agregarLog(texto: string, color: Color3?)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -4, 0, 0)
    lbl.AutomaticSize = Enum.AutomaticSize.Y
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Code
    lbl.TextSize = 11
    lbl.TextColor3 = color or Color3.fromRGB(215, 222, 235)
    lbl.TextWrapped = true
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = texto
    lbl.Parent = logsScroll

    table.insert(logItems, lbl)
    if #logItems > MAX_LOGS then
        local viejo = table.remove(logItems, 1)
        if viejo then
            viejo:Destroy()
        end
    end

    task.defer(function()
        local maxY = math.max(0, logsScroll.AbsoluteCanvasSize.Y - logsScroll.AbsoluteWindowSize.Y)
        logsScroll.CanvasPosition = Vector2.new(0, maxY)
    end)
end

-- ============================================================================
-- Construcción del Mapa Aéreo 2D (30x17 bloques) y Marcadores tipo Pin
-- ============================================================================

local function obtenerLineaData(lineaId: string): any?
    if not estadoActual or not estadoActual.lineas then
        return nil
    end
    for _, l in ipairs(estadoActual.lineas) do
        if l.id == lineaId then
            return l
        end
    end
    return nil
end

local function celdaAUDim2(gx: number, gy: number): UDim2
    local u = (gx - 0.5) / RoomSpaceConfig.GRID_COLS
    local v = (gy - 0.5) / RoomSpaceConfig.GRID_ROWS
    return UDim2.fromScale(u, v)
end

-- Crea un marcador estilo pin pixelado/vectorial (inspirado en los íconos de referencia)
local function crearMarcadorPin(nombre: string, colorPrincipal: Color3, parent: Instance, zBase: number): (Frame, UIStroke)
    local pin = Instance.new("Frame")
    pin.Name = "Pin_" .. nombre
    pin.AnchorPoint = Vector2.new(0.5, 0.5)
    pin.Size = UDim2.fromScale(1 / RoomSpaceConfig.GRID_COLS * 0.96, 1 / RoomSpaceConfig.GRID_ROWS * 0.96)
    pin.BackgroundColor3 = colorPrincipal
    pin.ZIndex = zBase
    pin.Parent = parent
    crearEsquina(pin, 999)
    local stroke = crearBorde(pin, Color3.fromRGB(20, 22, 28), 2)

    -- Punta inferior del pin
    local punta = Instance.new("Frame")
    punta.Name = "Punta"
    punta.Size = UDim2.fromScale(0.36, 0.36)
    punta.Position = UDim2.fromScale(0.5, 0.92)
    punta.AnchorPoint = Vector2.new(0.5, 0.5)
    punta.Rotation = 45
    punta.BackgroundColor3 = colorPrincipal
    punta.BorderSizePixel = 0
    punta.ZIndex = zBase - 1
    punta.Parent = pin

    -- Rostro/silueta interior según personaje
    if nombre == "TÚ" then
        local gorra = Instance.new("Frame")
        gorra.Size = UDim2.fromScale(0.46, 0.22)
        gorra.Position = UDim2.fromScale(0.5, 0.30)
        gorra.AnchorPoint = Vector2.new(0.5, 0.5)
        gorra.BackgroundColor3 = Color3.fromRGB(16, 24, 30)
        gorra.BorderSizePixel = 0
        gorra.ZIndex = zBase + 1
        gorra.Parent = pin
        crearEsquina(gorra, 3)

        local cuerpo = Instance.new("Frame")
        cuerpo.Size = UDim2.fromScale(0.54, 0.34)
        cuerpo.Position = UDim2.fromScale(0.5, 0.66)
        cuerpo.AnchorPoint = Vector2.new(0.5, 0.5)
        cuerpo.BackgroundColor3 = Color3.fromRGB(16, 24, 30)
        cuerpo.BorderSizePixel = 0
        cuerpo.ZIndex = zBase + 1
        cuerpo.Parent = pin
        crearEsquina(cuerpo, 6)
    else
        -- Orejas o cresta arriba
        if nombre == "Bonnie" or nombre == "Foxy" then
            for _, sx in ipairs({ 0.32, 0.68 }) do
                local ear = Instance.new("Frame")
                ear.Size = UDim2.fromScale(0.20, if nombre == "Bonnie" then 0.34 else 0.24)
                ear.Position = UDim2.fromScale(sx, 0.10)
                ear.AnchorPoint = Vector2.new(0.5, 0.5)
                ear.BackgroundColor3 = colorPrincipal
                ear.BorderSizePixel = 0
                ear.ZIndex = zBase + 1
                ear.Parent = pin
                crearEsquina(ear, 3)
                crearBorde(ear, Color3.fromRGB(20, 22, 28), 1.5)
            end
        end

        -- Ojos expresivos
        for idx, ex in ipairs({ 0.35, 0.65 }) do
            local ojo = Instance.new("Frame")
            ojo.Size = UDim2.fromScale(0.18, 0.18)
            ojo.Position = UDim2.fromScale(ex, 0.44)
            ojo.AnchorPoint = Vector2.new(0.5, 0.5)
            ojo.BackgroundColor3 = if (nombre == "Foxy" and idx == 2) then Color3.fromRGB(20, 22, 28) else Color3.fromRGB(245, 248, 255)
            ojo.BorderSizePixel = 0
            ojo.ZIndex = zBase + 2
            ojo.Parent = pin
            crearEsquina(ojo, 999)
        end

        -- Pico / hocico
        local boca = Instance.new("Frame")
        boca.Size = UDim2.fromScale(0.38, 0.18)
        boca.Position = UDim2.fromScale(0.5, 0.68)
        boca.AnchorPoint = Vector2.new(0.5, 0.5)
        boca.BackgroundColor3 = if nombre == "Chica" then Color3.fromRGB(235, 130, 35) else Color3.fromRGB(28, 30, 38)
        boca.BorderSizePixel = 0
        boca.ZIndex = zBase + 2
        boca.Parent = pin
        crearEsquina(boca, 4)
    end

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.fromOffset(72, 13)
    sub.Position = UDim2.new(0.5, 0, 1, 2)
    sub.AnchorPoint = Vector2.new(0.5, 0)
    sub.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
    sub.BackgroundTransparency = 0.25
    sub.Font = Enum.Font.GothamBold
    sub.TextSize = 9
    sub.TextColor3 = colorPrincipal
    sub.Text = if nombre == "TÚ" then "TÚ" else nombre:upper()
    sub.ZIndex = zBase + 3
    sub.Parent = pin
    crearEsquina(sub, 3)

    return pin, stroke
end

actualizarPuertasMapa = function()
    local linea = obtenerLineaData(lineaSeleccionada)
    local flags = obtenerFlagsPuertas(lineaSeleccionada)
    local pIzq = if linea and linea.puertaIzquierdaCerrada ~= nil then (linea.puertaIzquierdaCerrada == true) else (flags.Izquierda == true)
    local pDer = if linea and linea.puertaDerechaCerrada ~= nil then (linea.puertaDerechaCerrada == true) else (flags.Derecha == true)

    for lado, frame in pairs(doorTileFrames) do
        local cerrada = if lado == "Izquierda" then pIzq else pDer
        local lbl = frame:FindFirstChild("DoorIcon") :: TextLabel?
        local stroke = frame:FindFirstChildOfClass("UIStroke")
        if cerrada then
            frame.BackgroundColor3 = Color3.fromRGB(210, 42, 52)
            if stroke then stroke.Color = Color3.fromRGB(255, 130, 130) end
            if lbl then lbl.Text = "🔒" end
        else
            frame.BackgroundColor3 = Color3.fromRGB(52, 168, 108)
            if stroke then stroke.Color = Color3.fromRGB(130, 240, 175) end
            if lbl then lbl.Text = "🚪" end
        end
    end
end

local function construirMapaAereo()
    if mapaConstruido then
        return
    end
    mapaConstruido = true

    for _, ch in ipairs(tilesLayer:GetChildren()) do ch:Destroy() end
    for _, ch in ipairs(labelsLayer:GetChildren()) do ch:Destroy() end
    doorTileFrames = {}
    alertBadges = {}

    local cols = RoomSpaceConfig.GRID_COLS
    local rows = RoomSpaceConfig.GRID_ROWS
    local tileW = 1 / cols
    local tileH = 1 / rows

    for y = 1, rows do
        for x = 1, cols do
            local celda = RoomSpaceConfig.obtenerCelda(x, y)
            if celda then
                local tile = Instance.new("Frame")
                tile.Name = string.format("Tile_%d_%d", x, y)
                tile.Position = UDim2.fromScale((x - 1) * tileW, (y - 1) * tileH)
                tile.Size = UDim2.fromScale(tileW, tileH)
                tile.BorderSizePixel = 1
                tile.BorderColor3 = Color3.fromRGB(36, 42, 52)
                tile.ZIndex = 1
                tile.Parent = tilesLayer

                if celda.tipo == "VOID" then
                    tile.BackgroundColor3 = Color3.fromRGB(38, 44, 54)
                    tile.BorderColor3 = Color3.fromRGB(46, 54, 66)
                elseif celda.tipo == "WALL" then
                    tile.BackgroundColor3 = Color3.fromRGB(16, 19, 25)
                    tile.BorderColor3 = Color3.fromRGB(10, 12, 16)
                elseif celda.tipo == "FLOOR" then
                    local cfg = if celda.sala then RoomSpaceConfig.SALAS[celda.sala] else nil
                    local col = if cfg then cfg.colorPiso else Color3.fromRGB(100, 115, 130)
                    if cfg and cfg.colorPisoAlt then
                        if celda.sala == "Comedor" and x <= 17 and y <= 4 then
                            col = cfg.colorPisoAlt
                        elseif celda.sala == "Banos" and y >= 11 then
                            col = cfg.colorPisoAlt
                        end
                    end
                    -- Patrón ajedrez sutil para ver cada bloque claramente
                    if (x + y) % 2 == 0 then
                        col = col:Lerp(Color3.new(0, 0, 0), 0.06)
                    end
                    tile.BackgroundColor3 = col
                    tile.BorderColor3 = Color3.fromRGB(44, 52, 62)

                    local btn = Instance.new("TextButton")
                    btn.Size = UDim2.fromScale(1, 1)
                    btn.BackgroundTransparency = 1
                    btn.Text = ""
                    btn.ZIndex = 2
                    btn.Parent = tile
                    local cx, cy = x, y
                    btn.MouseButton1Click:Connect(function()
                        if intentarMoverJugadorACelda then
                            intentarMoverJugadorACelda(cx, cy)
                        end
                    end)
                elseif celda.tipo == "PROP" then
                    local propCol = Color3.fromRGB(130, 92, 60)
                    if celda.propTipo == "Generator" then
                        propCol = Color3.fromRGB(58, 72, 92)
                    elseif celda.propTipo == "WallProp" then
                        propCol = Color3.fromRGB(22, 26, 34)
                    elseif celda.propTipo == "Stage" then
                        propCol = Color3.fromRGB(122, 82, 54)
                    end
                    tile.BackgroundColor3 = propCol
                    tile.BorderColor3 = Color3.fromRGB(25, 28, 35)
                elseif celda.tipo == "DOOR" then
                    tile.ZIndex = 3
                    if celda.puerta and celda.puerta.ladoSeguridad then
                        tile.BackgroundColor3 = Color3.fromRGB(52, 168, 108)
                        crearBorde(tile, Color3.fromRGB(130, 240, 175), 1.5)
                        local lbl = Instance.new("TextLabel")
                        lbl.Name = "DoorIcon"
                        lbl.Size = UDim2.fromScale(1, 1)
                        lbl.BackgroundTransparency = 1
                        lbl.Text = "🚪"
                        lbl.TextScaled = true
                        lbl.ZIndex = 4
                        lbl.Parent = tile
                        doorTileFrames[celda.puerta.ladoSeguridad] = tile
                    else
                        tile.BackgroundColor3 = Color3.fromRGB(138, 108, 78)
                        tile.BorderColor3 = Color3.fromRGB(60, 46, 34)
                    end

                    local btn = Instance.new("TextButton")
                    btn.Size = UDim2.fromScale(1, 1)
                    btn.BackgroundTransparency = 1
                    btn.Text = ""
                    btn.ZIndex = 5
                    btn.Parent = tile
                    local cx, cy = x, y
                    btn.MouseButton1Click:Connect(function()
                        if intentarMoverJugadorACelda then
                            intentarMoverJugadorACelda(cx, cy)
                        end
                    end)
                end
            end
        end
    end

    -- Etiquetas de habitaciones, ícono de energía y cámaras
    for salaId, cfg in pairs(RoomSpaceConfig.SALAS) do
        local lbl = Instance.new("TextLabel")
        lbl.Name = "Label_" .. salaId
        lbl.AnchorPoint = Vector2.new(0.5, 0.5)
        lbl.Position = celdaAUDim2(cfg.labelPos.x, cfg.labelPos.y)
        lbl.AutomaticSize = Enum.AutomaticSize.XY
        lbl.Size = UDim2.fromOffset(0, 14)
        lbl.BackgroundColor3 = Color3.fromRGB(12, 15, 20)
        lbl.BackgroundTransparency = 0.22
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 9
        lbl.TextColor3 = Color3.fromRGB(240, 245, 255)
        lbl.Text = " " .. cfg.nombreVisible .. " "
        lbl.ZIndex = 5
        lbl.Parent = labelsLayer
        crearEsquina(lbl, 3)

        if salaId == "FuenteEnergia" then
            local bolt = Instance.new("TextLabel")
            bolt.Size = UDim2.fromScale(tileW * 0.9, tileH * 0.9)
            bolt.Position = celdaAUDim2(4, 12.6)
            bolt.AnchorPoint = Vector2.new(0.5, 0.5)
            bolt.BackgroundColor3 = Color3.fromRGB(28, 38, 62)
            bolt.Text = "⚡"
            bolt.TextScaled = true
            bolt.ZIndex = 5
            bolt.Parent = labelsLayer
            crearEsquina(bolt, 4)
            crearBorde(bolt, Color3.fromRGB(90, 130, 210), 1)
        elseif cfg.tieneCamara then
            local cam = Instance.new("TextLabel")
            cam.Size = UDim2.fromOffset(16, 16)
            cam.Position = celdaAUDim2(cfg.rect.x2 - 0.3, cfg.rect.y1 + 0.3)
            cam.AnchorPoint = Vector2.new(0.5, 0.5)
            cam.BackgroundColor3 = Color3.fromRGB(26, 30, 38)
            cam.BackgroundTransparency = 0.2
            cam.Text = "📷"
            cam.TextSize = 10
            cam.ZIndex = 5
            cam.Parent = labelsLayer
            crearEsquina(cam, 4)
        end
    end

    -- Marcadores de Alerta (!) en los pasillos frente a la Oficina
    for lado, pos in pairs({ Izquierda = { x = 11.3, y = 13.5 }, Derecha = { x = 18.7, y = 13.5 } }) do
        local alerta = Instance.new("Frame")
        alerta.Name = "Alert_" .. lado
        alerta.Size = UDim2.fromOffset(20, 20)
        alerta.Position = celdaAUDim2(pos.x, pos.y)
        alerta.AnchorPoint = Vector2.new(0.5, 0.5)
        alerta.BackgroundColor3 = Color3.fromRGB(220, 42, 42)
        alerta.Visible = false
        alerta.ZIndex = 11
        alerta.Parent = labelsLayer
        crearEsquina(alerta, 999)
        crearBorde(alerta, Color3.fromRGB(255, 220, 220), 1.5)

        local txt = Instance.new("TextLabel")
        txt.Size = UDim2.fromScale(1, 1)
        txt.BackgroundTransparency = 1
        txt.Font = Enum.Font.GothamBold
        txt.TextSize = 13
        txt.TextColor3 = Color3.fromRGB(255, 255, 255)
        txt.Text = "!"
        txt.ZIndex = 12
        txt.Parent = alerta
        alertBadges[lado] = alerta
    end

    if actualizarPuertasMapa then
        actualizarPuertasMapa()
    end
end

-- ============================================================================
-- Representación y movimiento suavizado bloque a bloque (Animatrónicos)
-- ============================================================================

local function asegurarToken(nombre: string): TokenInfo
    if tokens[nombre] then
        return tokens[nombre]
    end

    local color = obtenerColorAnimatronico(nombre)
    local frame, stroke = crearMarcadorPin(nombre, color, tokensLayer, 8)
    local sx, sy = RoomSpaceConfig.obtenerSpawnSala(if nombre == "Foxy" then "CuevaPirata" else "Escenario")
    frame.Position = celdaAUDim2(sx, sy)

    local info: TokenInfo = {
        frame = frame,
        stroke = stroke,
        nodoActual = if nombre == "Foxy" then "CuevaPirata" else "Escenario",
        gx = sx,
        gy = sy,
        cola = {},
        animando = false,
    }
    tokens[nombre] = info
    return info
end

local function actualizarTransparenciaEcos()
    if not estadoActual then
        return
    end
    local presenteEnLinea: { [string]: boolean } = {}
    for _, anim in ipairs(estadoActual.animatronicos or {}) do
        if anim.lineaActual == lineaSeleccionada then
            presenteEnLinea[anim.nombre] = true
        end
    end
    for nombre, info in pairs(tokens) do
        local esPresente = presenteEnLinea[nombre] == true
        info.frame.BackgroundTransparency = if esPresente then 0 else 0.6
        info.stroke.Transparency = if esPresente then 0 else 0.55
    end
end

local function reposicionarInstantaneoLinea(lineaId: string)
    local linea = obtenerLineaData(lineaId)
    if not linea or not linea.posiciones then
        return
    end
    local espaciales = linea.posicionesEspaciales or {}
    for nombreAnim, nombreNodo in pairs(linea.posiciones) do
        local info = asegurarToken(nombreAnim)
        info.cola = {}
        info.animando = false
        info.nodoActual = nombreNodo
        local posEsp = espaciales[nombreAnim]
        if posEsp and posEsp.gx and posEsp.gy then
            info.gx = posEsp.gx
            info.gy = posEsp.gy
        else
            info.gx, info.gy = RoomSpaceConfig.obtenerSpawnSala(nombreNodo)
        end
        info.frame.Position = celdaAUDim2(info.gx, info.gy)
    end
    actualizarTransparenciaEcos()
end

local function procesarColaToken(nombreAnim: string)
    local info = tokens[nombreAnim]
    if not info or info.animando then
        return
    end

    local paso = table.remove(info.cola, 1)
    if not paso then
        return
    end

    info.animando = true
    info.nodoActual = paso.sala
    info.gx = paso.gx
    info.gy = paso.gy

    local destino = celdaAUDim2(paso.gx, paso.gy)
    local tween = TweenService:Create(info.frame, TWEEN_INFO_MOV, { Position = destino })
    tween:Play()
    tween.Completed:Connect(function()
        info.animando = false
        procesarColaToken(nombreAnim)
    end)
end

-- ============================================================================
-- Navegación del Jugador en el Mapa Aéreo 2D (Pac-Man: WASD / Flechas / Clic)
-- ============================================================================

local TECLAS_DIRECCION: { [Enum.KeyCode]: string } = {
    [Enum.KeyCode.Up]    = "Up",
    [Enum.KeyCode.W]     = "Up",
    [Enum.KeyCode.Down]  = "Down",
    [Enum.KeyCode.S]     = "Down",
    [Enum.KeyCode.Left]  = "Left",
    [Enum.KeyCode.A]     = "Left",
    [Enum.KeyCode.Right] = "Right",
    [Enum.KeyCode.D]     = "Right",
}

local VECTORES_DIRECCION: { [string]: Vector2 } = {
    Up    = Vector2.new(0, -1),
    Down  = Vector2.new(0, 1),
    Left  = Vector2.new(-1, 0),
    Right = Vector2.new(1, 0),
}

asegurarTokenJugador = function(): Frame
    if tokenJugadorFrame and tokenJugadorFrame.Parent then
        return tokenJugadorFrame
    end

    local frame, stroke = crearMarcadorPin("TÚ", Color3.fromRGB(43, 168, 156), tokensLayer, 10)
    tokenJugadorFrame = frame
    tokenJugadorStroke = stroke
    frame.Position = celdaAUDim2(gxJugador, gyJugador)
    return frame
end

verificarPeligroAnimatronicoEnSala = function()
    if not estadoActual or not estadoActual.animatronicos then return end
    local linea = obtenerLineaData(lineaSeleccionada)
    local animsEnSala: { string } = {}
    local animsEnPuertaIzq: { string } = {}
    local animsEnPuertaDer: { string } = {}

    for _, anim in ipairs(estadoActual.animatronicos) do
        if anim.lineaActual == lineaSeleccionada then
            if anim.nodoActual == nodoJugadorActual then
                table.insert(animsEnSala, anim.nombre)
            end
            if anim.nodoActual == "PasilloIzquierdo" then
                table.insert(animsEnPuertaIzq, anim.nombre)
            elseif anim.nodoActual == "PasilloDerecho" then
                table.insert(animsEnPuertaDer, anim.nombre)
            end
        end
    end

    if alertBadges["Izquierda"] then
        alertBadges["Izquierda"].Visible = (#animsEnPuertaIzq > 0)
    end
    if alertBadges["Derecha"] then
        alertBadges["Derecha"].Visible = (#animsEnPuertaDer > 0)
    end

    if #animsEnSala > 0 then
        navLabel.Text = string.format("⚠️ ¡ALERTA! %s en tu misma sala (%s)!", table.concat(animsEnSala, ", "), nodoJugadorActual)
        navLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
    elseif nodoJugadorActual == "Oficina" and #animsEnPuertaIzq > 0 and not (linea and linea.puertaIzquierdaCerrada) then
        navLabel.Text = string.format("🚨 ¡PELIGRO! %s en Pasillo Izquierdo (¡Cierra con [Q]!)", table.concat(animsEnPuertaIzq, ", "))
        navLabel.TextColor3 = Color3.fromRGB(255, 115, 80)
    elseif nodoJugadorActual == "Oficina" and #animsEnPuertaDer > 0 and not (linea and linea.puertaDerechaCerrada) then
        navLabel.Text = string.format("🚨 ¡PELIGRO! %s en Pasillo Derecho (¡Cierra con [E]!)", table.concat(animsEnPuertaDer, ", "))
        navLabel.TextColor3 = Color3.fromRGB(255, 115, 80)
    elseif nodoJugadorActual == "Oficina" and #animsEnPuertaIzq > 0 and (linea and linea.puertaIzquierdaCerrada) then
        navLabel.Text = string.format("🛡️ Puerta Izquierda bloqueando a %s (Esperando 5s)", table.concat(animsEnPuertaIzq, ", "))
        navLabel.TextColor3 = Color3.fromRGB(110, 220, 160)
    elseif nodoJugadorActual == "Oficina" and #animsEnPuertaDer > 0 and (linea and linea.puertaDerechaCerrada) then
        navLabel.Text = string.format("🛡️ Puerta Derecha bloqueando a %s (Esperando 5s)", table.concat(animsEnPuertaDer, ", "))
        navLabel.TextColor3 = Color3.fromRGB(110, 220, 160)
    else
        navLabel.Text = string.format("🎮 CONTROLES: [Flechas / WASD o Clic] Caminar | [Q] Puerta Izq | [E] Puerta Der | Sala: %s (%d,%d)", nodoJugadorActual, gxJugador, gyJugador)
        navLabel.TextColor3 = Color3.fromRGB(180, 235, 255)
    end
end

actualizarBotonesPuertas = function()
    local linea = obtenerLineaData(lineaSeleccionada)
    local flags = obtenerFlagsPuertas(lineaSeleccionada)
    local pIzq = if linea and linea.puertaIzquierdaCerrada ~= nil then (linea.puertaIzquierdaCerrada == true) else (flags.Izquierda == true)
    local pDer = if linea and linea.puertaDerechaCerrada ~= nil then (linea.puertaDerechaCerrada == true) else (flags.Derecha == true)
    local energia = if linea then (linea.energia or 0) else 100

    if btnPuertaIzq then
        local stroke = btnPuertaIzq:FindFirstChildOfClass("UIStroke")
        if pIzq then
            btnPuertaIzq.BackgroundColor3 = Color3.fromRGB(85, 25, 30)
            btnPuertaIzq.Text = "🔒 [Q] Izquierda\nCERRADA"
            btnPuertaIzq.TextColor3 = Color3.fromRGB(255, 130, 130)
            if stroke then stroke.Color = Color3.fromRGB(240, 65, 75) end
        else
            btnPuertaIzq.BackgroundColor3 = Color3.fromRGB(26, 48, 38)
            btnPuertaIzq.Text = "🚪 [Q] Izquierda\nABIERTA"
            btnPuertaIzq.TextColor3 = Color3.fromRGB(130, 235, 175)
            if stroke then stroke.Color = Color3.fromRGB(45, 160, 100) end
        end
        if energia <= 0 then
            btnPuertaIzq.TextColor3 = Color3.fromRGB(150, 150, 150)
            btnPuertaIzq.Text = "⚠️ [Q] Izq\nSIN ENERGÍA"
            if stroke then stroke.Color = Color3.fromRGB(90, 90, 90) end
        end
    end

    if btnPuertaDer then
        local stroke = btnPuertaDer:FindFirstChildOfClass("UIStroke")
        if pDer then
            btnPuertaDer.BackgroundColor3 = Color3.fromRGB(85, 25, 30)
            btnPuertaDer.Text = "🔒 [E] Derecha\nCERRADA"
            btnPuertaDer.TextColor3 = Color3.fromRGB(255, 130, 130)
            if stroke then stroke.Color = Color3.fromRGB(240, 65, 75) end
        else
            btnPuertaDer.BackgroundColor3 = Color3.fromRGB(26, 48, 38)
            btnPuertaDer.Text = "🚪 [E] Derecha\nABIERTA"
            btnPuertaDer.TextColor3 = Color3.fromRGB(130, 235, 175)
            if stroke then stroke.Color = Color3.fromRGB(45, 160, 100) end
        end
        if energia <= 0 then
            btnPuertaDer.TextColor3 = Color3.fromRGB(150, 150, 150)
            btnPuertaDer.Text = "⚠️ [E] Der\nSIN ENERGÍA"
            if stroke then stroke.Color = Color3.fromRGB(90, 90, 90) end
        end
    end
end

alternarPuerta = function(lado: "Izquierda" | "Derecha")
    if not remotos.RequestPlayerAction then return end
    local linea = obtenerLineaData(lineaSeleccionada)
    local flags = obtenerFlagsPuertas(lineaSeleccionada)

    -- El estado base se toma del flag persistente o del estado actual
    local estadoActualPuerta = flags[lado] == true
    if linea then
        if lado == "Izquierda" and linea.puertaIzquierdaCerrada ~= nil then
            estadoActualPuerta = linea.puertaIzquierdaCerrada == true
        elseif lado == "Derecha" and linea.puertaDerechaCerrada ~= nil then
            estadoActualPuerta = linea.puertaDerechaCerrada == true
        end
    end
    local nuevoCerrada = not estadoActualPuerta

    if linea and linea.energia <= 0 and nuevoCerrada then
        agregarLog(string.format("⚠️ [PUERTA] Sin energía en %s para cerrar la puerta %s.", lineaSeleccionada, lado), Color3.fromRGB(255, 120, 120))
        return
    end

    -- Actualizar flag local inmediatamente
    flags[lado] = nuevoCerrada

    -- Actualización optimista inmediata en cliente para máxima fluidez
    if linea then
        if lado == "Izquierda" then
            linea.puertaIzquierdaCerrada = nuevoCerrada
        else
            linea.puertaDerechaCerrada = nuevoCerrada
        end
    end

    if actualizarBotonesPuertas then
        actualizarBotonesPuertas()
    end
    if actualizarPuertasMapa then
        actualizarPuertasMapa()
    end
    if actualizarPanelEstado and estadoActual then
        actualizarPanelEstado(estadoActual)
    end
    if verificarPeligroAnimatronicoEnSala then
        verificarPeligroAnimatronicoEnSala()
    end

    remotos.RequestPlayerAction:FireServer({
        tipo = "ALTERNAR_PUERTA",
        lado = lado,
        cerrada = nuevoCerrada,
        lineaId = lineaSeleccionada,
    })
end

btnPuertaIzq.MouseButton1Click:Connect(function()
    if alternarPuerta then
        alternarPuerta("Izquierda")
    end
end)

btnPuertaDer.MouseButton1Click:Connect(function()
    if alternarPuerta then
        alternarPuerta("Derecha")
    end
end)

btnPuertaIzq.MouseEnter:Connect(function()
    local stroke = btnPuertaIzq:FindFirstChildOfClass("UIStroke")
    if stroke then stroke.Thickness = 2.5 end
end)
btnPuertaIzq.MouseLeave:Connect(function()
    local stroke = btnPuertaIzq:FindFirstChildOfClass("UIStroke")
    if stroke then stroke.Thickness = 1.5 end
end)

btnPuertaDer.MouseEnter:Connect(function()
    local stroke = btnPuertaDer:FindFirstChildOfClass("UIStroke")
    if stroke then stroke.Thickness = 2.5 end
end)
btnPuertaDer.MouseLeave:Connect(function()
    local stroke = btnPuertaDer:FindFirstChildOfClass("UIStroke")
    if stroke then stroke.Thickness = 1.5 end
end)

local function darPasoJugadorA(nx: number, ny: number, esAutomatico: boolean?)
    local linea = obtenerLineaData(lineaSeleccionada)
    if not RoomSpaceConfig.celdaEsTransitable(nx, ny, linea) then
        local celda = RoomSpaceConfig.obtenerCelda(nx, ny)
        if celda and celda.puerta and celda.puerta.ladoSeguridad then
            navLabel.Text = string.format("🔒 [Puerta %s Cerrada] Ábrela primero con [%s]", celda.puerta.ladoSeguridad, if celda.puerta.ladoSeguridad == "Izquierda" then "Q" else "E")
        else
            navLabel.Text = "⚠️ [Pared] No puedes atravesar este bloque"
        end
        navLabel.TextColor3 = Color3.fromRGB(255, 110, 110)
        return false
    end

    local celdaDest = RoomSpaceConfig.obtenerCelda(nx, ny)
    local salaNueva = if celdaDest and celdaDest.tipo == "FLOOR" and celdaDest.sala then celdaDest.sala else nodoJugadorActual
    local cambioDeSala = (salaNueva ~= nodoJugadorActual)

    gxJugador = nx
    gyJugador = ny
    nodoJugadorActual = salaNueva

    if asegurarTokenJugador then
        asegurarTokenJugador()
    end

    if cambioDeSala then
        agregarLog(string.format("[JUGADOR] Entró a %s (%d,%d)", salaNueva, nx, ny), Color3.fromRGB(80, 230, 255))
    end

    if remotos.RequestPlayerAction then
        remotos.RequestPlayerAction:FireServer({
            tipo = "MOVER_JUGADOR",
            nodo = nodoJugadorActual,
            gx = gxJugador,
            gy = gyJugador,
        })
    end

    local token = tokenJugadorFrame
    if token then
        animandoJugador = true
        local tween = TweenService:Create(token, TweenInfo.new(if esAutomatico then 0.11 else 0.10, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
            Position = celdaAUDim2(gxJugador, gyJugador)
        })
        tween:Play()
        tween.Completed:Wait()
        animandoJugador = false
    end

    if verificarPeligroAnimatronicoEnSala then
        verificarPeligroAnimatronicoEnSala()
    end
    return true
end

intentarMoverJugadorACelda = function(targetX: number, targetY: number)
    caminoJugadorId += 1
    local miId = caminoJugadorId
    local linea = obtenerLineaData(lineaSeleccionada)
    local camino = RoomSpaceConfig.encontrarCaminoPacMan(gxJugador, gyJugador, targetX, targetY, linea)
    if #camino == 0 then
        navLabel.Text = "🔒 [Bloqueado] No hay camino libre hacia esa casilla"
        navLabel.TextColor3 = Color3.fromRGB(255, 110, 110)
        return
    end

    task.spawn(function()
        for _, paso in ipairs(camino) do
            if miId ~= caminoJugadorId then
                return
            end
            while animandoJugador do
                task.wait(0.02)
                if miId ~= caminoJugadorId then return end
            end
            local ok = darPasoJugadorA(paso.x, paso.y, true)
            if not ok then
                return
            end
        end
    end)
end

local function moverJugadorPorDireccion(dirNombre: string)
    if animandoJugador then return end
    caminoJugadorId += 1 -- Cancela ruta por clic si el usuario usa teclado

    local vDir = VECTORES_DIRECCION[dirNombre]
    if not vDir then return end

    local nx = gxJugador + vDir.X
    local ny = gyJugador + vDir.Y

    task.spawn(function()
        local ok = darPasoJugadorA(nx, ny, false)
        if not ok then
            if asegurarTokenJugador then
                asegurarTokenJugador()
            end
            local token = tokenJugadorFrame
            if tokenJugadorStroke then
                tokenJugadorStroke.Color = Color3.fromRGB(255, 80, 80)
            end
            if token then
                local basePos = celdaAUDim2(gxJugador, gyJugador)
                local offsetPos = UDim2.new(basePos.X.Scale, vDir.X * 6, basePos.Y.Scale, vDir.Y * 6)
                local twRebote = TweenService:Create(token, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = offsetPos })
                twRebote:Play()
                twRebote.Completed:Connect(function()
                    local twRegreso = TweenService:Create(token, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = basePos })
                    twRegreso:Play()
                    twRegreso.Completed:Connect(function()
                        if tokenJugadorStroke then
                            tokenJugadorStroke.Color = Color3.fromRGB(20, 22, 28)
                        end
                    end)
                end)
            end
        end
    end)
end

-- ============================================================================
-- Barra superior, Panel de Estado y Sincronización
-- ============================================================================

local function actualizarBotonesLineas(lineas: { any })
    for _, l in ipairs(lineas or {}) do
        local btn = timelineButtons[l.id]
        if not btn then
            btn = Instance.new("TextButton")
            btn.Name = "Timeline_" .. l.id
            btn.Size = UDim2.fromOffset(58, 28)
            btn.Font = Enum.Font.GothamBold
            btn.TextSize = 12
            btn.Text = l.id
            btn.Parent = timelinesScroll
            crearEsquina(btn, 6)
            timelineButtons[l.id] = btn

            local idCap = l.id
            btn.MouseButton1Click:Connect(function()
                if lineaSeleccionada ~= idCap then
                    lineaSeleccionada = idCap
                    if estadoActual then
                        actualizarBotonesLineas(estadoActual.lineas)
                    end
                    reposicionarInstantaneoLinea(lineaSeleccionada)
                    if actualizarPuertasMapa then
                        actualizarPuertasMapa()
                    end
                    if actualizarBotonesPuertas then
                        actualizarBotonesPuertas()
                    end
                    if estadoActual then
                        actualizarPanelEstado(estadoActual)
                    end
                    if verificarPeligroAnimatronicoEnSala then
                        verificarPeligroAnimatronicoEnSala()
                    end
                end
            end)
        end

        local activa = (l.id == lineaSeleccionada)
        btn.BackgroundColor3 = if activa then Color3.fromRGB(48, 130, 215) else Color3.fromRGB(36, 42, 56)
        btn.TextColor3 = if activa then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(185, 195, 215)
    end
end

local function actualizarUIControlesReloj(pausado: boolean)
    pausadoLocal = pausado
    local modo = if estadoActual and estadoActual.estadoJuego then estadoActual.estadoJuego else "LOBBY"

    if modo == "LOBBY" then
        btnIniciar.Active = true
        btnIniciar.BackgroundColor3 = Color3.fromRGB(36, 155, 88)
        btnIniciar.TextColor3 = Color3.fromRGB(255, 255, 255)
        btnIniciar.Text = "▶ Iniciar Noche 5D"

        btnPausa.Active = false
        btnPausa.Text = "|| Pausar"
        btnPausa.BackgroundColor3 = Color3.fromRGB(40, 44, 56)
        btnPausa.TextColor3 = Color3.fromRGB(120, 128, 145)

        btnPaso.Active = false
        btnPaso.BackgroundColor3 = Color3.fromRGB(40, 44, 56)
        btnPaso.TextColor3 = Color3.fromRGB(120, 128, 145)
    elseif modo == "ENDED" then
        btnIniciar.Active = true
        btnIniciar.BackgroundColor3 = Color3.fromRGB(205, 115, 42)
        btnIniciar.TextColor3 = Color3.fromRGB(255, 255, 255)
        btnIniciar.Text = "↻ Reiniciar Noche"

        btnPausa.Active = false
        btnPausa.Text = "|| Pausar"
        btnPausa.BackgroundColor3 = Color3.fromRGB(40, 44, 56)
        btnPausa.TextColor3 = Color3.fromRGB(120, 128, 145)

        btnPaso.Active = false
        btnPaso.BackgroundColor3 = Color3.fromRGB(40, 44, 56)
        btnPaso.TextColor3 = Color3.fromRGB(120, 128, 145)
    else
        btnIniciar.Active = false
        btnIniciar.BackgroundColor3 = Color3.fromRGB(28, 68, 52)
        btnIniciar.TextColor3 = Color3.fromRGB(130, 235, 175)
        btnIniciar.Text = "● Noche Activa"

        btnPausa.Active = true
        if pausado then
            btnPausa.Text = "> Reanudar"
            btnPausa.BackgroundColor3 = Color3.fromRGB(46, 150, 92)
            btnPausa.TextColor3 = Color3.fromRGB(255, 255, 255)
            btnPaso.Active = true
            btnPaso.BackgroundColor3 = Color3.fromRGB(58, 110, 185)
            btnPaso.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            btnPausa.Text = "|| Pausar"
            btnPausa.BackgroundColor3 = Color3.fromRGB(42, 95, 165)
            btnPausa.TextColor3 = Color3.fromRGB(255, 255, 255)
            btnPaso.Active = false
            btnPaso.BackgroundColor3 = Color3.fromRGB(44, 48, 60)
            btnPaso.TextColor3 = Color3.fromRGB(130, 138, 155)
        end
    end
end

actualizarPanelEstado = function(estado: any)
    for _, anim in ipairs(estado.animatronicos or {}) do
        local row = estadoRows[anim.nombre]
        if not row then
            row = Instance.new("TextLabel")
            row.Name = "Estado_" .. anim.nombre
            row.Size = UDim2.new(1, -4, 0, 36)
            row.BackgroundColor3 = Color3.fromRGB(30, 34, 46)
            row.Font = Enum.Font.Code
            row.TextSize = 11
            row.TextColor3 = obtenerColorAnimatronico(anim.nombre)
            row.TextWrapped = true
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.Parent = estadoScroll
            crearEsquina(row, 5)
            estadoRows[anim.nombre] = row
        end

        local faseTxt = if anim.fase then string.format(" | Fase:%d", anim.fase) else ""
        local actTxt = ""
        if anim.esperandoEnPuerta then
            actTxt = " [🚪 ESPERANDO 5s]"
            row.BackgroundColor3 = Color3.fromRGB(56, 38, 22)
        elseif anim.estaActivo then
            actTxt = " [MOV]"
            row.BackgroundColor3 = Color3.fromRGB(30, 34, 46)
        else
            row.BackgroundColor3 = Color3.fromRGB(30, 34, 46)
        end

        row.Text = string.format(
            " %s (%s) @ %s\n   Enojo:%d%s%s",
            anim.nombre, anim.lineaActual, anim.nodoActual, anim.enojo, faseTxt, actTxt
        )
    end

    local modo = estado.estadoJuego or "PLAYING"
    actualizarUIControlesReloj(pausadoLocal)
    local linea = obtenerLineaData(lineaSeleccionada)
    if linea then
        local pI = if linea.puertaIzquierdaCerrada then "CERR" else "ABIE"
        local pD = if linea.puertaDerechaCerrada then "CERR" else "ABIE"
        local cantCerradas = (if linea.puertaIzquierdaCerrada then 1 else 0) + (if linea.puertaDerechaCerrada then 1 else 0)
        local drenajeTxt = if cantCerradas == 2 then "-1%/1s" elseif cantCerradas == 1 then "-1%/2s" else "-1%/5s"
        local iconoBateria = if linea.energia <= 0
            then "💀 E:0%"
            elseif linea.energia <= 20 then "🔴 E:" .. tostring(linea.energia) .. "%"
            elseif linea.energia <= 50 then "🟡 E:" .. tostring(linea.energia) .. "%"
            else "🔋 E:" .. tostring(linea.energia) .. "%"

        if modo == "LOBBY" then
            statusLabel.Text = string.format("[LOBBY - En Espera] [%s] t=%ds | %s", linea.id, linea.tiempo, iconoBateria)
        elseif modo == "ENDED" then
            statusLabel.Text = string.format("[NOCHE CONCLUIDA] [%s] t=%ds | %s", linea.id, linea.tiempo, iconoBateria)
        else
            statusLabel.Text = string.format("[%s] t=%ds | %s (%s) | [Q] Izq:%s [E] Der:%s", linea.id, linea.tiempo, iconoBateria, drenajeTxt, pI, pD)
        end
    end

    if actualizarBotonesPuertas then
        actualizarBotonesPuertas()
    end
end

local function aplicarEstadoCompleto(estado: any)
    if not estado then return end
    estadoActual = estado
    if estado.lineas then
        for _, l in ipairs(estado.lineas) do
            local f = obtenerFlagsPuertas(l.id)
            f.Izquierda = l.puertaIzquierdaCerrada == true
            f.Derecha = l.puertaDerechaCerrada == true
        end
    end
    construirMapaAereo()
    if asegurarTokenJugador then
        asegurarTokenJugador()
    end
    if estado.lineas then
        actualizarBotonesLineas(estado.lineas)
    end
    if estado.reloj then
        actualizarUIControlesReloj(estado.reloj.pausado == true)
    end
    reposicionarInstantaneoLinea(lineaSeleccionada)
    if actualizarPuertasMapa then
        actualizarPuertasMapa()
    end
    if actualizarBotonesPuertas then
        actualizarBotonesPuertas()
    end
    actualizarPanelEstado(estado)
    actualizarTransparenciaEcos()
    if verificarPeligroAnimatronicoEnSala then
        verificarPeligroAnimatronicoEnSala()
    end
end

-- ============================================================================
-- Eventos de usuario y red
-- ============================================================================

toggleBtn.MouseButton1Click:Connect(function()
    root.Visible = not root.Visible
    screenGui:SetAttribute("PanelVisible", root.Visible)
    toggleBtn.Text = if root.Visible then "Ocultar Debug" else "Mostrar Debug"
    if root.Visible then
        task.defer(function()
            if actualizarPuertasMapa then
                actualizarPuertasMapa()
            end
            if estadoActual then
                reposicionarInstantaneoLinea(lineaSeleccionada)
            end
        end)
    end
end)

btnIniciar.MouseButton1Click:Connect(function()
    local modo = if estadoActual and estadoActual.estadoJuego then estadoActual.estadoJuego else "LOBBY"
    if modo == "PLAYING" then
        return
    end
    btnIniciar.Active = false
    btnIniciar.Text = "Iniciando..."
    if remotos.StartGame then
        remotos.StartGame:FireServer()
    end
end)

btnPausa.MouseButton1Click:Connect(function()
    local modo = if estadoActual and estadoActual.estadoJuego then estadoActual.estadoJuego else "LOBBY"
    if modo ~= "PLAYING" then
        return
    end
    if pausadoLocal then
        debugControl:FireServer("Reanudar")
    else
        debugControl:FireServer("Pausar")
    end
end)

btnPaso.MouseButton1Click:Connect(function()
    local modo = if estadoActual and estadoActual.estadoJuego then estadoActual.estadoJuego else "LOBBY"
    if modo ~= "PLAYING" then
        return
    end
    if pausadoLocal then
        debugControl:FireServer("Paso", 1)
    end
end)

mapPanel:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
    if actualizarPuertasMapa then
        actualizarPuertasMapa()
    end
    if estadoActual then
        reposicionarInstantaneoLinea(lineaSeleccionada)
    end
    if tokenJugadorFrame then
        tokenJugadorFrame.Position = celdaAUDim2(gxJugador, gyJugador)
    end
end)

-- Conectar debugEvento de inmediato
if debugEvento then
    debugEvento.OnClientEvent:Connect(function(ev: any)
        if type(ev) ~= "table" then
            return
        end

        if ev.tipo == "MOVER" then
            if ev.de ~= ev.a then
                agregarLog(string.format(
                    "[%s @ t=%ds] %s: %s -> %s",
                    tostring(ev.linea), tonumber(ev.t) or 0, tostring(ev.entidad), tostring(ev.de), tostring(ev.a)
                ), obtenerColorAnimatronico(tostring(ev.entidad)))
            end

            local gxPaso = tonumber(ev.gx)
            local gyPaso = tonumber(ev.gy)
            if not gxPaso or not gyPaso then
                gxPaso, gyPaso = RoomSpaceConfig.obtenerSpawnSala(ev.a)
            end

            if estadoActual then
                local linea = obtenerLineaData(ev.linea)
                if linea and linea.posiciones then
                    linea.posiciones[ev.entidad] = ev.a
                end
                if linea then
                    linea.posicionesEspaciales = linea.posicionesEspaciales or {}
                    linea.posicionesEspaciales[ev.entidad] = { sala = ev.a, gx = gxPaso, gy = gyPaso }
                end
            end

            if ev.linea == lineaSeleccionada then
                local info = asegurarToken(ev.entidad)
                table.insert(info.cola, { sala = ev.a, gx = gxPaso :: number, gy = gyPaso :: number })
                procesarColaToken(ev.entidad)
            end

            if verificarPeligroAnimatronicoEnSala then
                verificarPeligroAnimatronicoEnSala()
            end

        elseif ev.tipo == "BRANCH" then
            agregarLog(string.format(
                "[BRANCH] +%s desde %s@t=%ds (%s)",
                tostring(ev.linea), tostring(ev.origen), tonumber(ev.t) or 0, tostring(ev.motivo)
            ), Color3.fromRGB(115, 225, 195))

            task.spawn(function()
                local ok, nuevoEstado = pcall(function()
                    return debugGetEstado:InvokeServer()
                end)
                if ok and nuevoEstado then
                    aplicarEstadoCompleto(nuevoEstado)
                end
            end)

        elseif ev.tipo == "PUERTA" then
            local flags = obtenerFlagsPuertas(ev.linea)
            flags[ev.lado] = ev.cerrada == true

            local linea = obtenerLineaData(ev.linea)
            if linea then
                if ev.lado == "Izquierda" then
                    linea.puertaIzquierdaCerrada = ev.cerrada
                elseif ev.lado == "Derecha" then
                    linea.puertaDerechaCerrada = ev.cerrada
                end
            end
            local estadoTxt = if ev.cerrada then "CERRADA" else "ABIERTA"
            local col = if ev.cerrada then Color3.fromRGB(255, 95, 95) else Color3.fromRGB(100, 230, 140)
            agregarLog(string.format("[%s @ t=%ds] 🚪 Puerta %s -> %s", tostring(ev.linea), tonumber(ev.t) or 0, tostring(ev.lado), estadoTxt), col)
            if actualizarBotonesPuertas then
                actualizarBotonesPuertas()
            end
            if actualizarPuertasMapa then
                actualizarPuertasMapa()
            end
            if actualizarPanelEstado and estadoActual then
                actualizarPanelEstado(estadoActual)
            end
            if verificarPeligroAnimatronicoEnSala then
                verificarPeligroAnimatronicoEnSala()
            end

        elseif ev.tipo == "ENERGIA" then
            local linea = obtenerLineaData(ev.linea)
            if linea then
                linea.energia = ev.energia
            end
            if actualizarBotonesPuertas then
                actualizarBotonesPuertas()
            end
            if estadoActual then
                actualizarPanelEstado(estadoActual)
            end

        elseif ev.tipo == "BLOQUEO" then
            agregarLog(string.format("🚪🚫 [%s @ t=%ds] ¡%s bloqueado por puerta en %s! Esperando 5s...", tostring(ev.linea), tonumber(ev.t) or 0, tostring(ev.entidad), tostring(ev.pasillo)), Color3.fromRGB(255, 180, 50))
            if estadoActual and estadoActual.animatronicos then
                for _, a in ipairs(estadoActual.animatronicos) do
                    if a.nombre == ev.entidad and a.lineaActual == ev.linea then
                        a.esperandoEnPuerta = true
                    end
                end
                actualizarPanelEstado(estadoActual)
            end
            if verificarPeligroAnimatronicoEnSala then
                verificarPeligroAnimatronicoEnSala()
            end

        elseif ev.tipo == "RELOJ" then
            actualizarUIControlesReloj(ev.pausado == true)

        elseif ev.tipo == "RESET" then
            agregarLog("[SISTEMA] Sesión del multiverso iniciada/reiniciada.", Color3.fromRGB(120, 220, 160))
            task.spawn(function()
                local ok, nuevoEstado = pcall(function()
                    return debugGetEstado:InvokeServer()
                end)
                if ok and nuevoEstado then
                    aplicarEstadoCompleto(nuevoEstado)
                end
            end)
        end
    end)
end

if remotos.OnDefeat then
	remotos.OnDefeat.OnClientEvent:Connect(function(datos: any)
		if screenGui:FindFirstChild("GameOverOverlay") then return end
		local overlay = Instance.new("Frame")
		overlay.Name = "GameOverOverlay"
		overlay.Size = UDim2.fromScale(1, 1)
		overlay.BackgroundColor3 = Color3.fromRGB(8, 0, 0)
		overlay.BackgroundTransparency = 0.08
		overlay.ZIndex = 100
		overlay.Parent = screenGui
		local titulo = Instance.new("TextLabel")
		titulo.Size = UDim2.fromScale(1, 0.34)
		titulo.Position = UDim2.fromScale(0, 0.24)
		titulo.BackgroundTransparency = 1
		titulo.Text = "GAME OVER"
		titulo.TextColor3 = Color3.fromRGB(235, 35, 35)
		titulo.Font = Enum.Font.GothamBlack
		titulo.TextScaled = true
		titulo.ZIndex = 101
		titulo.Parent = overlay
		local detalle = Instance.new("TextLabel")
		detalle.Size = UDim2.fromScale(0.82, 0.12)
		detalle.Position = UDim2.fromScale(0.09, 0.62)
		detalle.BackgroundTransparency = 1
		detalle.Text = string.format("%s entró a la oficina por la puerta %s abierta.", tostring(datos and datos.atacante or "Un animatrónico"), tostring(datos and datos.puerta or ""))
		detalle.TextColor3 = Color3.fromRGB(255, 220, 220)
		detalle.Font = Enum.Font.GothamBold
		detalle.TextScaled = true
		detalle.ZIndex = 101
		detalle.Parent = overlay
	end)
end

-- Escuchar cambios de estado del juego (Lobby -> Playing -> Ended)
if remotos.OnGameStateChanged then
    remotos.OnGameStateChanged.OnClientEvent:Connect(function(nuevoEstado: NetworkProtocol.GameStateType)
        if estadoActual then
            estadoActual.estadoJuego = nuevoEstado
            actualizarUIControlesReloj(pausadoLocal)
        end
        if nuevoEstado == "PLAYING" then
            agregarLog("[LOBBY] ¡Partida iniciada! Comenzando simulación 5D.", Color3.fromRGB(100, 230, 140))
        elseif nuevoEstado == "ENDED" then
            agregarLog("[LOBBY] Noche finalizada.", Color3.fromRGB(240, 160, 90))
        elseif nuevoEstado == "LOBBY" then
            agregarLog("[LOBBY] En espera de inicio.", Color3.fromRGB(150, 190, 240))
        end
        task.spawn(function()
            local ok, data = pcall(function()
                return debugGetEstado:InvokeServer()
            end)
            if ok and data then
                aplicarEstadoCompleto(data)
            end
        end)
    end)
end

-- Escuchar pulsación de teclas direccionales (Flechas y WASD) y atajos de puertas (Q y E)
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
    if gameProcessed then return end
    if not root.Visible then return end

    if input.KeyCode == Enum.KeyCode.Q then
        if alternarPuerta then
            alternarPuerta("Izquierda")
        end
        return
    elseif input.KeyCode == Enum.KeyCode.E then
        if alternarPuerta then
            alternarPuerta("Derecha")
        end
        return
    end

    local dir = TECLAS_DIRECCION[input.KeyCode]
    if dir then
        moverJugadorPorDireccion(dir)
    end
end)

-- ============================================================================
-- Hidratación inicial asíncrona y refresco periódico ligero
-- ============================================================================

task.spawn(function()
    while not estadoActual do
        local ok, data = pcall(function()
            return debugGetEstado:InvokeServer()
        end)
        if ok and data then
            aplicarEstadoCompleto(data)
            agregarLog(string.format("[DEBUG] Conectado al motor 5D (%s)", tostring(data.estadoJuego or "OK")), Color3.fromRGB(130, 185, 255))
            if data.estadoJuego == "LOBBY" then
                agregarLog("[LOBBY] Motor preparado. Presiona '▶ Iniciar Noche 5D' para arrancar los relojes.", Color3.fromRGB(110, 225, 165))
            end
            break
        end
        task.wait(0.5)
    end

    while screenGui.Parent do
        task.wait(1)
        local ok, est = pcall(function()
            return debugGetEstado:InvokeServer()
        end)
        if ok and est then
            estadoActual = est
            if est.lineas then
                for _, l in ipairs(est.lineas) do
                    local flags = obtenerFlagsPuertas(l.id)
                    flags.Izquierda = l.puertaIzquierdaCerrada == true
                    flags.Derecha = l.puertaDerechaCerrada == true
                end
            end
            if not mapaConstruido then
                construirMapaAereo()
            end
            actualizarBotonesLineas(est.lineas)
            if actualizarPanelEstado then
                actualizarPanelEstado(est)
            end
            if actualizarPuertasMapa then
                actualizarPuertasMapa()
            end
            actualizarTransparenciaEcos()
        end
    end
end)
