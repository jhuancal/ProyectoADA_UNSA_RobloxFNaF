--!strict
--[[
    MapGraph.luau
    Ubicación: ReplicatedStorage.Shared.MapGraph
    Propósito (ADA - Teoría de Grafos y Precomputación BFS):
    Define el grafo espacial del restaurante (9 nodos, incluyendo 'FuenteEnergia').
    - El nodo especial 'Oficina' mantiene su restricción de grado 2 (solo conecta con PasilloIzquierdo y PasilloDerecho).
    - El nodo 'FuenteEnergia' conecta con Backstage y PasilloIzquierdo.
    - Soporta aristas dinámicas (puertas funcionales): cuando la puerta izquierda o derecha está cerrada,
      la arista entre la Oficina y el pasillo correspondiente se elimina temporalmente del grafo.
    - Precomputa la matriz de distancias mínimas con BFS para servir como heurística O(1) admisible en A*.
]]

local MapGraph = {}
MapGraph.__index = MapGraph

export type MapGraphType = {
    nodos: { [string]: { string } },
    distanciasMinimas: { [string]: { [string]: number } },
    aristasBloqueadas: { [string]: boolean },
    obtenerVecinos: (self: MapGraphType, nodo: string, estadoEscenario: any?) -> { string },
    estanConectados: (self: MapGraphType, nodoA: string, nodoB: string, estadoEscenario: any?) -> boolean,
    aristaEstaBloqueada: (self: MapGraphType, nodoA: string, nodoB: string, estadoEscenario: any?) -> boolean,
    bloquearArista: (self: MapGraphType, nodoA: string, nodoB: string) -> (),
    desbloquearArista: (self: MapGraphType, nodoA: string, nodoB: string) -> (),
    obtenerAristasActivas: (self: MapGraphType, estadoEscenario: any?) -> { { origen: string, destino: string } },
    distanciaHacia: (self: MapGraphType, origen: string, destino: string) -> number,
}

function MapGraph.new(): MapGraphType
    local self = setmetatable({}, MapGraph)

    self.nodos = {
        ["Escenario"]        = { "Backstage", "PasilloIzquierdo" },
        ["Comedor"]          = { "PasilloIzquierdo", "PasilloDerecho", "Banos" },
        ["Backstage"]        = { "Escenario" },
        ["Banos"]            = { "Comedor", "PasilloDerecho" },
        ["CuevaPirata"]      = { "PasilloIzquierdo" },
        ["PasilloIzquierdo"] = { "Escenario", "CuevaPirata", "FuenteEnergia", "Comedor", "Oficina" },
        ["PasilloDerecho"]   = { "Comedor", "Banos", "Oficina" },
        ["Oficina"]          = { "PasilloIzquierdo", "PasilloDerecho" },
        ["FuenteEnergia"]    = { "PasilloIzquierdo" },
    }

    self.aristasBloqueadas = {}
    self.distanciasMinimas = {}
    self:_precomputarDistanciasBFS()

    return (self :: any) :: MapGraphType
end

function MapGraph:_precomputarDistanciasBFS()
    for nodoOrigen in pairs(self.nodos) do
        local dist: { [string]: number } = {}
        local cola: { string } = { nodoOrigen }
        dist[nodoOrigen] = 0

        local head = 1
        while head <= #cola do
            local actual = cola[head]
            head += 1

            local dActual = dist[actual]
            for _, vecino in ipairs(self.nodos[actual] or {}) do
                if dist[vecino] == nil then
                    dist[vecino] = dActual + 1
                    table.insert(cola, vecino)
                end
            end
        end

        self.distanciasMinimas[nodoOrigen] = dist
    end
end

-- Determina si la arista entre nodoA y nodoB está bloqueada (por puerta cerrada en el escenario o bloqueo manual)
function MapGraph:aristaEstaBloqueada(nodoA: string, nodoB: string, estadoEscenario: any?): boolean
    -- 1. Chequeo dinámico por estado de puertas en la línea temporal (multiverso 5D)
    if estadoEscenario then
        if (nodoA == "Oficina" and nodoB == "PasilloIzquierdo") or (nodoA == "PasilloIzquierdo" and nodoB == "Oficina") then
            if estadoEscenario.puertaIzquierdaCerrada == true then
                return true
            end
        end
        if (nodoA == "Oficina" and nodoB == "PasilloDerecho") or (nodoA == "PasilloDerecho" and nodoB == "Oficina") then
            if estadoEscenario.puertaDerechaCerrada == true then
                return true
            end
        end
    end

    -- 2. Chequeo por bloqueo explícito en la instancia
    local clave = if nodoA < nodoB then (nodoA .. "|" .. nodoB) else (nodoB .. "|" .. nodoA)
    return self.aristasBloqueadas[clave] == true
end

function MapGraph:bloquearArista(nodoA: string, nodoB: string)
    local clave = if nodoA < nodoB then (nodoA .. "|" .. nodoB) else (nodoB .. "|" .. nodoA)
    self.aristasBloqueadas[clave] = true
end

function MapGraph:desbloquearArista(nodoA: string, nodoB: string)
    local clave = if nodoA < nodoB then (nodoA .. "|" .. nodoB) else (nodoB .. "|" .. nodoA)
    self.aristasBloqueadas[clave] = nil
end

-- Retorna los vecinos accesibles de un nodo, filtrando aristas eliminadas por puertas cerradas
function MapGraph:obtenerVecinos(nodo: string, estadoEscenario: any?): { string }
    local listaBase = self.nodos[nodo]
    if not listaBase then return {} end

    local hayFiltro = (estadoEscenario ~= nil) or (next(self.aristasBloqueadas) ~= nil)
    if not hayFiltro then
        return listaBase
    end

    local vecinosFiltrados = {}
    for _, vecino in ipairs(listaBase) do
        if not self:aristaEstaBloqueada(nodo, vecino, estadoEscenario) then
            table.insert(vecinosFiltrados, vecino)
        end
    end
    return vecinosFiltrados
end

-- Retorna si dos nodos están conectados considerando puertas cerradas
function MapGraph:estanConectados(nodoA: string, nodoB: string, estadoEscenario: any?): boolean
    if self:aristaEstaBloqueada(nodoA, nodoB, estadoEscenario) then
        return false
    end
    local vecinos = self.nodos[nodoA]
    if not vecinos then return false end
    for _, vecino in ipairs(vecinos) do
        if vecino == nodoB then
            return true
        end
    end
    return false
end

-- Retorna la lista de todas las aristas activas (útil para dibujar el grafo en 2D sin las aristas bloqueadas)
function MapGraph:obtenerAristasActivas(estadoEscenario: any?): { { origen: string, destino: string } }
    local aristas: { { origen: string, destino: string } } = {}
    local vistas: { [string]: boolean } = {}
    for u, vecinos in pairs(self.nodos) do
        for _, v in ipairs(vecinos) do
            if not self:aristaEstaBloqueada(u, v, estadoEscenario) then
                local clave = if u < v then (u .. "|" .. v) else (v .. "|" .. u)
                if not vistas[clave] then
                    vistas[clave] = true
                    table.insert(aristas, { origen = u, destino = v })
                end
            end
        end
    end
    return aristas
end

function MapGraph:distanciaHacia(origen: string, destino: string): number
    local tablaOrigen = self.distanciasMinimas[origen]
    if not tablaOrigen then return 999 end
    return tablaOrigen[destino] or 999
end

return MapGraph
