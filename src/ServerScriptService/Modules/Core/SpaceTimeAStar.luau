--!strict
--[[
    SpaceTimeAStar.luau
    Ubicación: ServerScriptService.Modules.Core.SpaceTimeAStar
    Propósito (ADA - Búsqueda Heurística A* con Cola de Prioridad Min-Heap Binario):
    Encuentra el camino óptimo para un animatrónico en el grafo espacio-temporal (u, t, L),
    evaluando el estado de las puertas de la Oficina y los objetos del escenario.
    Complejidad Temporal: O((|V| + |E|) log |V|) gracias al Min-Heap binario.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local SpaceTimeAStar = {}
SpaceTimeAStar.__index = SpaceTimeAStar

type HeapNode = {
    nodoEspacial: string,
    tiempo: number,
    lineaId: string,
    g: number,
    f: number,
    camino: { string },
}

-- Implementación de Cola de Prioridad (Binary Min-Heap) en O(log N)
local MinHeap = {}
MinHeap.__index = MinHeap

function MinHeap.new()
    return setmetatable({ datos = {} :: { HeapNode } }, MinHeap)
end

function MinHeap:estaVacio(): boolean
    return #self.datos == 0
end

function MinHeap:insertar(elemento: HeapNode)
    table.insert(self.datos, elemento)
    local idx = #self.datos
    while idx > 1 do
        local padre = math.floor(idx / 2)
        if self.datos[idx].f < self.datos[padre].f then
            self.datos[idx], self.datos[padre] = self.datos[padre], self.datos[idx]
            idx = padre
        else
            break
        end
    end
end

function MinHeap:extraerMinimo(): HeapNode?
    if #self.datos == 0 then return nil end
    local raiz = self.datos[1]
    local ultimo = table.remove(self.datos) :: HeapNode
    if #self.datos > 0 then
        self.datos[1] = ultimo
        local idx = 1
        local n = #self.datos
        while true do
            local izq = 2 * idx
            local der = 2 * idx + 1
            local menor = idx

            if izq <= n and self.datos[izq].f < self.datos[menor].f then
                menor = izq
            end
            if der <= n and self.datos[der].f < self.datos[menor].f then
                menor = der
            end
            if menor ~= idx then
                self.datos[idx], self.datos[menor] = self.datos[menor], self.datos[idx]
                idx = menor
            else
                break
            end
        end
    end
    return raiz
end

function SpaceTimeAStar.new(mapa: any, snapshotManager: any)
    local self = setmetatable({}, SpaceTimeAStar)
    self.mapa = mapa
    self.snapshotManager = snapshotManager
    return self
end

-- Calcula la ruta óptima desde nodoOrigen hacia nodoDestino considerando bloqueos de puertas en (lineaId)
function SpaceTimeAStar:calcularRutaOptima(
    nodoOrigen: string,
    nodoDestino: string,
    lineaId: string,
    tiempoActual: number
): ({ string }, number)
    local estadoEscenario = self.snapshotManager:obtenerEstadoPresente(lineaId)
    local openSet = MinHeap.new()
    local mejorCostoG: { [string]: number } = {}

    local hInicial = self.mapa:distanciaHacia(nodoOrigen, nodoDestino)
    openSet:insertar({
        nodoEspacial = nodoOrigen,
        tiempo = tiempoActual,
        lineaId = lineaId,
        g = 0,
        f = hInicial,
        camino = { nodoOrigen },
    })
    mejorCostoG[nodoOrigen] = 0

    while not openSet:estaVacio() do
        local actual = openSet:extraerMinimo() :: HeapNode
        if actual.nodoEspacial == nodoDestino then
            return actual.camino, actual.g
        end

        for _, vecino in ipairs(self.mapa:obtenerVecinosSinFiltro(actual.nodoEspacial)) do
            local costoArista = 1

            -- Si intenta entrar a la Oficina pero la puerta correspondiente está cerrada, penalizar con costo alto
            if vecino == "Oficina" and estadoEscenario then
                if actual.nodoEspacial == "PasilloIzquierdo" and estadoEscenario.puertaIzquierdaCerrada then
                    costoArista = GameConfig.PENALIZACION_PUERTA_CERRADA_ASTAR
                elseif actual.nodoEspacial == "PasilloDerecho" and estadoEscenario.puertaDerechaCerrada then
                    costoArista = GameConfig.PENALIZACION_PUERTA_CERRADA_ASTAR
                end
            end

            -- Si hay un señuelo sonoro activo en el nodo vecino, reduce el costo (atrae al animatrónico)
            if estadoEscenario and estadoEscenario.objetos["SenueloSonoro"] then
                local senuelo = estadoEscenario.objetos["SenueloSonoro"]
                if senuelo.activo and senuelo.nodo == vecino then
                    costoArista = GameConfig.BONO_SENUELO_ASTAR
                end
            end

            local nuevoG = actual.g + costoArista
            if mejorCostoG[vecino] == nil or nuevoG < mejorCostoG[vecino] then
                mejorCostoG[vecino] = nuevoG
                local h = self.mapa:distanciaHacia(vecino, nodoDestino)
                local nuevoCamino = table.clone(actual.camino)
                table.insert(nuevoCamino, vecino)

                openSet:insertar({
                    nodoEspacial = vecino,
                    tiempo = actual.tiempo + 1,
                    lineaId = lineaId,
                    g = nuevoG,
                    f = nuevoG + h,
                    camino = nuevoCamino,
                })
            end
        end
    end

    return { nodoOrigen }, 999
end

return SpaceTimeAStar
