--!strict
--[[
    LobbyClient.client.luau
    Ubicación: StarterGui.LobbyGui.LobbyClient
    Propósito (Controlador del Botón Iniciar en el GUI):
    Conecta el botón "Iniciar" del Lobby GUI con el servidor mediante el RemoteEvent 'StartGame'.
    Al iniciar la partida ("PLAYING"), oculta el botón/panel del Lobby y da paso a la vista del juego.
    Además, se coordina con MultiverseDebugGui: cuando el panel de Debug está abierto, cede el
    control al botón "▶ Iniciar Noche 5D" integrado en la barra superior del Debug para evitar
    superposiciones visuales; cuando el Debug se oculta, muestra el botón en la vista 3D.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local NetworkProtocol = require(Shared:WaitForChild("NetworkProtocol"))

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local remotos = NetworkProtocol.obtenerRemotos()
local screenGui = script.Parent :: ScreenGui
screenGui.DisplayOrder = 110

local botonIniciar = screenGui:WaitForChild("BotonIniciar") :: TextButton
local estadoJuegoActual: NetworkProtocol.GameStateType = "LOBBY"

local function esPanelDebugAbierto(): boolean
    local debugGui = playerGui:FindFirstChild("MultiverseDebug")
    if debugGui then
        local attr = debugGui:GetAttribute("PanelVisible")
        if type(attr) == "boolean" then
            return attr
        end
        local root = debugGui:FindFirstChild("Root")
        if root and root:IsA("GuiObject") then
            return root.Visible
        end
    end
    return false
end

local function actualizarUIEstadoLobby(nuevoEstado: NetworkProtocol.GameStateType)
    estadoJuegoActual = nuevoEstado
    local debugAbierto = esPanelDebugAbierto()

    if nuevoEstado == "LOBBY" then
        screenGui.Enabled = true
        botonIniciar.Visible = not debugAbierto
        botonIniciar.Active = true
        botonIniciar.Text = "INICIAR NOCHE 5D"
    elseif nuevoEstado == "PLAYING" then
        screenGui.Enabled = false
        botonIniciar.Visible = false
    elseif nuevoEstado == "ENDED" then
        screenGui.Enabled = true
        botonIniciar.Visible = not debugAbierto
        botonIniciar.Active = true
        botonIniciar.Text = "REINICIAR NOCHE 5D"
    end
end

local function conectarObservadorDebugGui(gui: Instance)
    if gui.Name ~= "MultiverseDebug" then
        return
    end
    gui:GetAttributeChangedSignal("PanelVisible"):Connect(function()
        actualizarUIEstadoLobby(estadoJuegoActual)
    end)
    actualizarUIEstadoLobby(estadoJuegoActual)
end

local debugExistente = playerGui:FindFirstChild("MultiverseDebug")
if debugExistente then
    conectarObservadorDebugGui(debugExistente)
end
playerGui.ChildAdded:Connect(conectarObservadorDebugGui)

-- 1. Disparar el inicio de la partida al hacer clic en el botón
botonIniciar.MouseButton1Click:Connect(function()
    if estadoJuegoActual == "PLAYING" then
        return
    end
    botonIniciar.Active = false
    botonIniciar.Text = "Iniciando..."
    if remotos.StartGame then
        remotos.StartGame:FireServer()
    end
end)

-- 2. Reaccionar a los cambios de estado del servidor (LOBBY -> PLAYING -> ENDED)
if remotos.OnGameStateChanged then
    remotos.OnGameStateChanged.OnClientEvent:Connect(function(nuevoEstado: NetworkProtocol.GameStateType)
        if nuevoEstado == "PLAYING" then
            print("[CLIENTE - LOBBY] ¡Partida iniciada! Ocultando menú de Lobby.")
        elseif nuevoEstado == "ENDED" then
            print("[CLIENTE - LOBBY] Noche concluida. Lobby listo para nueva partida.")
        end
        actualizarUIEstadoLobby(nuevoEstado)
    end)
end

-- 3. Sincronización inicial con el estado actual del servidor
task.spawn(function()
    if remotos.DebugGetEstado then
        local ok, data = pcall(function()
            return remotos.DebugGetEstado:InvokeServer()
        end)
        if ok and type(data) == "table" and data.estadoJuego then
            actualizarUIEstadoLobby(data.estadoJuego)
            return
        end
    end
    actualizarUIEstadoLobby(estadoJuegoActual)
end)
