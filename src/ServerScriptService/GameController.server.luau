--!strict
--[[
    GameController.server.luau
    Ubicación: ServerScriptService.GameController
    Propósito (Controlador de Lobby y Ciclo de Sesión):
    Encapsula el juego en modo LOBBY al arrancar el servidor.
    Espera a que cualquier jugador presione el botón "Iniciar" en su GUI
    (vía RemoteEvent 'StartGame') para disparar GameSession:iniciar().
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NetworkProtocol = require(Shared:WaitForChild("NetworkProtocol"))

local Modules = ServerScriptService:WaitForChild("Modules")
local Core = Modules:WaitForChild("Core")
local GameSession = require(Core:WaitForChild("GameSession"))
local PlayerActionHandler = require(Core:WaitForChild("PlayerActionHandler"))

-- 1. Inicializar los RemoteEvents y la Sesión encapsulada en estado LOBBY
local remotos = NetworkProtocol.obtenerRemotos()
local sesionActual = GameSession.new()

print("================================================================================")
print("  [LOBBY] Servidor Multiverso 5D listo.")
print("  Esperando a que el jugador presione 'INICIAR' desde el GUI para comenzar...")
print("================================================================================")

-- 2. Sincronizar el estado actual con cada jugador que entra o ya está en el servidor
local function sincronizarJugador(player: Player)
    remotos.OnGameStateChanged:FireClient(player, sesionActual:obtenerEstado())
end

Players.PlayerAdded:Connect(sincronizarJugador)
for _, player in ipairs(Players:GetPlayers()) do
    task.defer(sincronizarJugador, player)
end

-- 3. Escuchar la petición de inicio desde el GUI del cliente (ScreenGui o SurfaceGui)
remotos.StartGame.OnServerEvent:Connect(function(player: Player)
    if sesionActual:obtenerEstado() == "PLAYING" then
        warn(string.format("[LOBBY] %s intentó iniciar, pero la noche ya está en curso.", player.Name))
        return
    end

    print(string.format("[LOBBY] ¡%s presionó INICIAR! Lanzando simulación de la noche...", player.Name))
    sesionActual:iniciar()
end)

-- 4. Escuchar acciones del jugador en el grafo 2D (movimiento y tácticas de puertas)
remotos.RequestPlayerAction.OnServerEvent:Connect(function(player: Player, accion: any)
    PlayerActionHandler.procesar(player, sesionActual, accion)
end)
