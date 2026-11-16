--!strict
--[[
    SnapshotManager.luau
    Ubicación: ServerScriptService.Modules.Core.SnapshotManager
    Propósito (ADA - Estructuras de Datos Persistentes / Structural Sharing):
    En lugar de clonar todo el estado del juego en cada segundo y en cada línea temporal
    (lo que tendría una complejidad espacial O(|V| * T * |L|)), implementa un sistema de
    Snapshots Inmutables con Deltas Incrementales (Event Sourcing) en espacio O(E),
    donde E es la cantidad real de mutaciones.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local RoomSpaceConfig = require(Shared:WaitForChild("RoomSpaceConfig"))

export type ObjetoEscenario = {
    id: string,
    nodo: string,
    activo: boolean,
    integridad: number, -- 100 = intacto, 0 = saboteado/agotado
}

export type PosicionEspacial = {
    sala: string,
    gx: number,
    gy: number,
}

export type WorldState = {
    lineaId: string,
    tiempo: number,
    energia: number,
    tasaDrenajeEnergia: number,
    puertaIzquierdaCerrada: boolean,
    puertaDerechaCerrada: boolean,
    posicionesAnimatronicos: { [string]: string },
    posicionesEspaciales: { [string]: PosicionEspacial },
    objetos: { [string]: ObjetoEscenario },
    relojVectorialStr: string,
}

export type DeltaMutation = {
    tiempo: number,
    tipo: "MOVER_ANIMATRONICO" | "CAMBIAR_ENERGIA" | "ALTERNAR_PUERTA" | "MUTAR_OBJETO",
    entidadId: string,
    valorAnterior: any,
    valorNuevo: any,
    gx: number?,
    gy: number?,
    relojVectorialStr: string,
}

local SnapshotManager = {}
SnapshotManager.__index = SnapshotManager

function SnapshotManager.new()
    local self = setmetatable({}, SnapshotManager)
    -- Almacena el estado base de cada línea temporal al momento de su creación
    self.estadosBase = {} :: { [string]: WorldState }
    -- Almacena la lista ordenada de deltas por línea temporal: historialDeltas[lineaId] = { DeltaMutation }
    self.historialDeltas = {} :: { [string]: { DeltaMutation } }
    -- Caché del estado presente de cada línea temporal para lectura en O(1)
    self.estadoPresente = {} :: { [string]: WorldState }
    self.OnDelta = Instance.new("BindableEvent")
    return self
end

function SnapshotManager:clonarEstado(estado: WorldState): WorldState
    local copiaPosiciones: { [string]: string } = {}
    for k, v in pairs(estado.posicionesAnimatronicos) do
        copiaPosiciones[k] = v
    end

    local copiaEspaciales: { [string]: PosicionEspacial } = {}
    for k, pos in pairs(estado.posicionesEspaciales or {}) do
        copiaEspaciales[k] = {
            sala = pos.sala,
            gx = pos.gx,
            gy = pos.gy,
        }
    end

    local copiaObjetos: { [string]: ObjetoEscenario } = {}
    for k, obj in pairs(estado.objetos) do
        copiaObjetos[k] = {
            id = obj.id,
            nodo = obj.nodo,
            activo = obj.activo,
            integridad = obj.integridad,
        }
    end

    return {
        lineaId = estado.lineaId,
        tiempo = estado.tiempo,
        energia = estado.energia,
        tasaDrenajeEnergia = estado.tasaDrenajeEnergia,
        puertaIzquierdaCerrada = estado.puertaIzquierdaCerrada,
        puertaDerechaCerrada = estado.puertaDerechaCerrada,
        posicionesAnimatronicos = copiaPosiciones,
        posicionesEspaciales = copiaEspaciales,
        objetos = copiaObjetos,
        relojVectorialStr = estado.relojVectorialStr,
    }
end

function SnapshotManager:inicializarLineaRaiz(lineaId: string, relojStr: string): WorldState
    local estadoInicial: WorldState = {
        lineaId = lineaId,
        tiempo = 0,
        energia = GameConfig.ENERGIA_INICIAL,
        tasaDrenajeEnergia = GameConfig.TASA_DRENAJE_INICIAL,
        puertaIzquierdaCerrada = false,
        puertaDerechaCerrada = false,
        posicionesAnimatronicos = {
            ["Bonnie"] = "Escenario",
            ["Chica"]  = "Escenario",
            ["Foxy"]   = "CuevaPirata",
        },
        posicionesEspaciales = {
            ["Bonnie"] = { sala = "Escenario",   gx = select(1, RoomSpaceConfig.obtenerSpawnSala("Escenario")),   gy = select(2, RoomSpaceConfig.obtenerSpawnSala("Escenario")) },
            ["Chica"]  = { sala = "Escenario",   gx = select(1, RoomSpaceConfig.obtenerSpawnSala("Escenario")),   gy = select(2, RoomSpaceConfig.obtenerSpawnSala("Escenario")) },
            ["Foxy"]   = { sala = "CuevaPirata", gx = select(1, RoomSpaceConfig.obtenerSpawnSala("CuevaPirata")), gy = select(2, RoomSpaceConfig.obtenerSpawnSala("CuevaPirata")) },
        },
        objetos = {
            ["GeneradorPrincipal"] = { id = "GeneradorPrincipal", nodo = "FuenteEnergia", activo = true, integridad = 100 },
            ["BateriaReserva"]     = { id = "BateriaReserva", nodo = "Banos", activo = true, integridad = 100 },
            ["SenueloSonoro"]      = { id = "SenueloSonoro", nodo = "Comedor", activo = false, integridad = 100 },
        },
        relojVectorialStr = relojStr,
    }

    self.estadosBase[lineaId] = self:clonarEstado(estadoInicial)
    self.estadoPresente[lineaId] = self:clonarEstado(estadoInicial)
    self.historialDeltas[lineaId] = {}
    return self.estadoPresente[lineaId]
end

-- Reconstruye el estado exacto de una línea temporal L en cualquier instante pasado tObjetivo
-- aplicando únicamente los deltas con tiempo <= tObjetivo sobre el estadoBase.
-- Complejidad: O(k) donde k es el número de deltas en esa línea hasta tObjetivo.
function SnapshotManager:reconstruirEstadoEn(lineaId: string, tObjetivo: number): WorldState
    local base = self.estadosBase[lineaId]
    assert(base, "Línea temporal no encontrada: " .. tostring(lineaId))

    local estado = self:clonarEstado(base)
    estado.tiempo = tObjetivo

    local deltas = self.historialDeltas[lineaId] or {}
    for _, delta in ipairs(deltas) do
        if delta.tiempo <= tObjetivo then
            self:_aplicarDelta(estado, delta)
        else
            break
        end
    end

    return estado
end

function SnapshotManager:_aplicarDelta(estado: WorldState, delta: DeltaMutation)
    estado.relojVectorialStr = delta.relojVectorialStr
    if delta.tipo == "MOVER_ANIMATRONICO" then
        estado.posicionesAnimatronicos[delta.entidadId] = delta.valorNuevo
        local gx = delta.gx
        local gy = delta.gy
        if not gx or not gy then
            gx, gy = RoomSpaceConfig.obtenerSpawnSala(delta.valorNuevo)
        end
        estado.posicionesEspaciales[delta.entidadId] = {
            sala = delta.valorNuevo,
            gx = gx,
            gy = gy,
        }
    elseif delta.tipo == "CAMBIAR_ENERGIA" then
        estado.energia = math.clamp(delta.valorNuevo, 0, GameConfig.ENERGIA_INICIAL)
        if estado.energia <= 0 then
            estado.puertaIzquierdaCerrada = false
            estado.puertaDerechaCerrada = false
        end
    elseif delta.tipo == "ALTERNAR_PUERTA" then
        if delta.entidadId == "Izquierda" then
            estado.puertaIzquierdaCerrada = delta.valorNuevo
        else
            estado.puertaDerechaCerrada = delta.valorNuevo
        end
    elseif delta.tipo == "MUTAR_OBJETO" then
        local obj = estado.objetos[delta.entidadId]
        if obj and type(delta.valorNuevo) == "table" then
            obj.nodo = delta.valorNuevo.nodo or obj.nodo
            obj.activo = if delta.valorNuevo.activo ~= nil then delta.valorNuevo.activo else obj.activo
            obj.integridad = delta.valorNuevo.integridad or obj.integridad
            if delta.entidadId == "GeneradorPrincipal" and obj.integridad < 50 then
                estado.tasaDrenajeEnergia = 2 -- Si sabotean el generador en el pasado, el drenaje se duplica
            end
        end
    end
end

function SnapshotManager:registrarDelta(lineaId: string, delta: DeltaMutation)
    local lista = self.historialDeltas[lineaId]
    if not lista then
        lista = {}
        self.historialDeltas[lineaId] = lista
    end
    table.insert(lista, delta)

    local presente = self.estadoPresente[lineaId]
    if presente and delta.tiempo <= presente.tiempo then
        self:_aplicarDelta(presente, delta)
    end
    self.OnDelta:Fire(lineaId, delta)
end

-- Crea el estado inicial de una rama hija L_nueva a partir de un salto al pasado (lineaOrigen, tSalto)
function SnapshotManager:ramificarEstado(lineaOrigen: string, lineaNueva: string, tSalto: number, relojStr: string): WorldState
    local snapshotPasado = self:reconstruirEstadoEn(lineaOrigen, tSalto)
    snapshotPasado.lineaId = lineaNueva
    snapshotPasado.tiempo = tSalto
    snapshotPasado.relojVectorialStr = relojStr

    self.estadosBase[lineaNueva] = self:clonarEstado(snapshotPasado)
    self.estadoPresente[lineaNueva] = self:clonarEstado(snapshotPasado)
    self.historialDeltas[lineaNueva] = {}

    return self.estadoPresente[lineaNueva]
end

function SnapshotManager:obtenerEstadoPresente(lineaId: string): WorldState
    return self.estadoPresente[lineaId]
end

return SnapshotManager
