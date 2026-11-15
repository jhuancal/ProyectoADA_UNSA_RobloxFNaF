--!strict
--[[
    TemporalEntity.luau
    Ubicación: ServerScriptService.Modules.Entities.TemporalEntity
    Propósito (POO - Clase Padre Raíz):
    Clase base para cualquier entidad que existe en el espacio-tiempo 4D:
    Coordenada = (nodoActual, tiempoLocal, lineaActual) + Reloj Vectorial propio.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local VectorClock = require(Shared:WaitForChild("VectorClock"))
local RoomSpaceConfig = require(Shared:WaitForChild("RoomSpaceConfig"))

local TemporalEntity = {}
TemporalEntity.__index = TemporalEntity

function TemporalEntity.new(nombre: string, nodoInicial: string, lineaInicial: string)
    local self = setmetatable({}, TemporalEntity)
    self.nombre = nombre
    self.nodoActual = nodoInicial
    local sx, sy = RoomSpaceConfig.obtenerSpawnSala(nodoInicial)
    self.gx = sx
    self.gy = sy
    self.lineaActual = lineaInicial or "L0"
    self.relojEntidad = VectorClock.new({ [self.lineaActual] = 1 }, 1)
    return self
end

function TemporalEntity:sincronizarConEscenario(nodoTimeline: any)
    if nodoTimeline and nodoTimeline.relojVectorial then
        self.relojEntidad:incrementar(self.lineaActual)
        self.relojEntidad:fusionar(nodoTimeline.relojVectorial)
        nodoTimeline.relojVectorial:fusionar(self.relojEntidad)
    end
end

function TemporalEntity:cambiarEscenario(nuevaLineaId: string, nuevoNodoEspacial: string?, nodoTimelineDestino: any)
    self.lineaActual = nuevaLineaId
    if nuevoNodoEspacial then
        self.nodoActual = nuevoNodoEspacial
        local sx, sy = RoomSpaceConfig.obtenerSpawnSala(nuevoNodoEspacial)
        self.gx = sx
        self.gy = sy
    end
    self:sincronizarConEscenario(nodoTimelineDestino)
end

return TemporalEntity
