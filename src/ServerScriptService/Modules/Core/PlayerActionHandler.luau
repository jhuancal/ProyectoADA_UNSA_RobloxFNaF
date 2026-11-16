--!strict
--[[
    PlayerActionHandler.luau
    Ubicación: ServerScriptService.Modules.Core.PlayerActionHandler
    Propósito:
    Valida todas las acciones entrantes del cliente vía RequestPlayerAction
    (estado de partida, existencia de nodo, transitabilidad en grilla, lado de puerta)
    antes de delegar la ejecución a GameSession o actualizar al guardia.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local RoomSpaceConfig = require(Shared:WaitForChild("RoomSpaceConfig"))

local PlayerActionHandler = {}

function PlayerActionHandler.procesar(player: Player, sesion: any, accion: any)
    if type(accion) ~= "table" or not sesion then
        return
    end

    if sesion:obtenerEstado() ~= "PLAYING" then
        return
    end

    if accion.tipo == "MOVER_JUGADOR" and type(accion.nodo) == "string" then
        if not sesion.mapa or not sesion.mapa.nodos or not sesion.mapa.nodos[accion.nodo] then
            warn(string.format("[PlayerActionHandler] %s envió nodo inválido: %s", player.Name, tostring(accion.nodo)))
            return
        end

        local guardia = sesion.guardiaAlfa
        if not guardia then
            return
        end

        local tieneCoords = type(accion.gx) == "number" and type(accion.gy) == "number"
        if tieneCoords then
            local estado = sesion.snapshotManager and sesion.snapshotManager:obtenerEstadoPresente(guardia.lineaActual)
            if not RoomSpaceConfig.celdaEsTransitable(accion.gx, accion.gy, estado) then
                warn(string.format(
                    "[PlayerActionHandler] %s intentó moverse a celda no transitable (%d, %d).",
                    player.Name, accion.gx, accion.gy
                ))
                return
            end
        end

        local nodoPrevio = guardia.nodoActual
        guardia.nodoActual = accion.nodo
        if tieneCoords then
            guardia.gx = accion.gx
            guardia.gy = accion.gy
        end

        print(string.format(
            "  [SERVIDOR - JUGADOR %s] Movimiento en mapa 2D: %s -> %s (%s, %s)",
            player.Name, nodoPrevio, accion.nodo, tostring(accion.gx or "-"), tostring(accion.gy or "-")
        ))

    elseif accion.tipo == "ALTERNAR_PUERTA" then
        if accion.lado ~= "Izquierda" and accion.lado ~= "Derecha" then
            warn(string.format("[PlayerActionHandler] %s envió lado de puerta inválido: %s", player.Name, tostring(accion.lado)))
            return
        end
        if accion.cerrada ~= nil and type(accion.cerrada) ~= "boolean" then
            return
        end
        if accion.lineaId ~= nil and type(accion.lineaId) ~= "string" then
            return
        end

        local exito = sesion:alternarPuerta(accion.lado, accion.cerrada, accion.lineaId)
        print(string.format(
            "  [SERVIDOR - PUERTA] %s solicitó alternar puerta %s (resultado: %s)",
            player.Name, accion.lado, tostring(exito)
        ))
    end
end

return PlayerActionHandler
