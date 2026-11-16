--!strict
--[[
    GridPathfinder.luau
    Ubicación: ReplicatedStorage.Shared.GridPathfinder
    Propósito (ADA - Búsqueda Heurística A* en Grilla 2D):
    Implementa el algoritmo A* con distancia Manhattan sobre celdas 2D
    para servidor y cliente, desacoplado de las reglas de negocio y entidades.
]]

local GridPathfinder = {}

export type CeldaCamino = {
    x: number,
    y: number,
}

type NodoHeap = {
    x: number,
    y: number,
    g: number,
    f: number,
}

local DIRS = {
    { dx = 0, dy = -1 },
    { dx = 0, dy = 1 },
    { dx = -1, dy = 0 },
    { dx = 1, dy = 0 },
}

local function key(x: number, y: number): number
    return y * 1000 + x
end

local function heuristicaManhattan(x1: number, y1: number, x2: number, y2: number): number
    return math.abs(x1 - x2) + math.abs(y1 - y2)
end

local function heapPush(heap: { NodoHeap }, nodo: NodoHeap)
    table.insert(heap, nodo)
    local idx = #heap
    while idx > 1 do
        local padre = math.floor(idx / 2)
        if heap[idx].f < heap[padre].f then
            heap[idx], heap[padre] = heap[padre], heap[idx]
            idx = padre
        else
            break
        end
    end
end

local function heapPop(heap: { NodoHeap }): NodoHeap?
    if #heap == 0 then
        return nil
    end
    local raiz = heap[1]
    local ultimo = table.remove(heap) :: NodoHeap
    if #heap > 0 then
        heap[1] = ultimo
        local idx = 1
        local n = #heap
        while true do
            local izq = 2 * idx
            local der = 2 * idx + 1
            local menor = idx

            if izq <= n and heap[izq].f < heap[menor].f then
                menor = izq
            end
            if der <= n and heap[der].f < heap[menor].f then
                menor = der
            end
            if menor ~= idx then
                heap[idx], heap[menor] = heap[menor], heap[idx]
                idx = menor
            else
                break
            end
        end
    end
    return raiz
end

-- Calcula el camino más corto usando A* con heurística Manhattan
function GridPathfinder.encontrarCamino(
    origenX: number,
    origenY: number,
    destinoX: number,
    destinoY: number,
    esTransitableFn: (number, number) -> boolean
): { CeldaCamino }
    if origenX == destinoX and origenY == destinoY then
        return {}
    end

    if not esTransitableFn(destinoX, destinoY) then
        return {}
    end

    local openSet: { NodoHeap } = {}
    local mejorG: { [number]: number } = {}
    local padre: { [number]: number } = {}
    local cerrado: { [number]: boolean } = {}

    local kInicio = key(origenX, origenY)
    local kDestino = key(destinoX, destinoY)

    mejorG[kInicio] = 0
    heapPush(openSet, {
        x = origenX,
        y = origenY,
        g = 0,
        f = heuristicaManhattan(origenX, origenY, destinoX, destinoY),
    })

    local encontrado = false
    while #openSet > 0 do
        local actual = heapPop(openSet) :: NodoHeap
        local kActual = key(actual.x, actual.y)

        if kActual == kDestino then
            encontrado = true
            break
        end

        if not cerrado[kActual] then
            cerrado[kActual] = true

            for _, d in ipairs(DIRS) do
                local nx = actual.x + d.dx
                local ny = actual.y + d.dy
                local kn = key(nx, ny)

                if not cerrado[kn] and esTransitableFn(nx, ny) then
                    local nuevoG = actual.g + 1
                    if mejorG[kn] == nil or nuevoG < mejorG[kn] then
                        mejorG[kn] = nuevoG
                        padre[kn] = kActual
                        local f = nuevoG + heuristicaManhattan(nx, ny, destinoX, destinoY)
                        heapPush(openSet, {
                            x = nx,
                            y = ny,
                            g = nuevoG,
                            f = f,
                        })
                    end
                end
            end
        end
    end

    if not encontrado then
        return {}
    end

    local camino: { CeldaCamino } = {}
    local currK: number? = kDestino
    while currK and currK ~= kInicio do
        local cy = math.floor(currK / 1000)
        local cx = currK % 1000
        table.insert(camino, 1, { x = cx, y = cy })
        currK = padre[currK]
    end

    return camino
end

return GridPathfinder
