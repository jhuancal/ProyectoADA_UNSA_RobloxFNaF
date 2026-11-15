--!strict
--[[
    NetworkProtocol.luau
    Ubicación: ReplicatedStorage.Shared.NetworkProtocol
    Propósito (Arquitectura Cliente-Servidor y Lobby):
    Define los RemoteEvents para el flujo Lobby -> Partida en curso y replicación Delta 5D.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetworkProtocol = {}

export type GameStateType = "LOBBY" | "PLAYING" | "ENDED"

export type DeltaPayload = {
    lineaId: string,
    tiempo: number,
    relojVectorial: string,
    energiaActual: number,
    puertaIzquierdaCerrada: boolean,
    puertaDerechaCerrada: boolean,
    ubicacionAnimatronicos: { [string]: string },
    objetosEscenario: { [string]: { nodo: string, estado: string } },
    enJaqueTemporal: boolean,
}

function NetworkProtocol.obtenerRemotos()
    local carpetaRemotos = ReplicatedStorage:FindFirstChild("MultiverseRemotes")
    if not carpetaRemotos then
        carpetaRemotos = Instance.new("Folder")
        carpetaRemotos.Name = "MultiverseRemotes"
        carpetaRemotos.Parent = ReplicatedStorage
    end

    local function asegurarEvento(parent: Instance, nombre: string): RemoteEvent
        local ev = parent:FindFirstChild(nombre)
        if not ev then
            ev = Instance.new("RemoteEvent")
            ev.Name = nombre
            ev.Parent = parent
        end
        return ev :: RemoteEvent
    end

    local function asegurarFuncion(parent: Instance, nombre: string): RemoteFunction
        local fn = parent:FindFirstChild(nombre)
        if not fn then
            fn = Instance.new("RemoteFunction")
            fn.Name = nombre
            fn.Parent = parent
        end
        return fn :: RemoteFunction
    end

    -- Carpeta Debug para compatibilidad con MultiverseDebugGui
    local carpetaDebug = carpetaRemotos:FindFirstChild("Debug")
    if not carpetaDebug then
        carpetaDebug = Instance.new("Folder")
        carpetaDebug.Name = "Debug"
        carpetaDebug.Parent = carpetaRemotos
    end

    return {
        -- Ciclo de vida del Lobby y Partida
        StartGame           = asegurarEvento(carpetaRemotos, "StartGame"),
        OnGameStateChanged  = asegurarEvento(carpetaRemotos, "OnGameStateChanged"),
        OnDefeat            = asegurarEvento(carpetaRemotos, "OnDefeat"),
        -- Replicación del Multiverso 5D
        OnTimelineDelta     = asegurarEvento(carpetaRemotos, "OnTimelineDelta"),
        OnBranchCreated     = asegurarEvento(carpetaRemotos, "OnBranchCreated"),
        OnCausalRipple      = asegurarEvento(carpetaRemotos, "OnCausalRipple"),
        RequestPlayerAction = asegurarEvento(carpetaRemotos, "RequestPlayerAction"),
        -- Remotos de Debug
        DebugEvento         = asegurarEvento(carpetaDebug, "DebugEvento"),
        DebugControl        = asegurarEvento(carpetaDebug, "DebugControl"),
        DebugGetEstado      = asegurarFuncion(carpetaDebug, "DebugGetEstado"),
    }
end

return NetworkProtocol
