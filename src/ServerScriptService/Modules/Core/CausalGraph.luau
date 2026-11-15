--!strict
--[[
    CausalGraph.luau
    Ubicación: ServerScriptService.Modules.Core.CausalGraph
    Propósito (ADA - Grafos Acíclicos Dirigidos, Ordenamiento Topológico de Kahn y Propagación Causal):
    Resuelve el "Efecto Mariposa" cuando un jugador o animatrónico altera un objeto o consume
    energía en un escenario antiguo (pasado) y dicho cambio debe alterar el presente o futuro
    de las líneas temporales descendientes sin provocar ciclos ni paradojas.
]]

local CausalGraph = {}
CausalGraph.__index = CausalGraph

export type CausalEvent = {
    idEvento: string,
    lineaOrigen: string,
    tiempoEvento: number,
    tipoEfecto: "SABOTAJE_GENERADOR" | "TRANSFERENCIA_BATERIA" | "SOBRECARGA_PUERTA",
    impactoEnergia: number,
    objetoAfectado: string?,
    nuevoEstadoObjeto: any,
    descripcion: string,
}

function CausalGraph.new(timelineTree: any, snapshotManager: any)
    local self = setmetatable({}, CausalGraph)
    self.timelineTree = timelineTree
    self.snapshotManager = snapshotManager
    self.contadorEventos = 0
    return self
end

-- Algoritmo de Kahn para Ordenamiento Topológico sobre el subgrafo de líneas temporales afectadas
-- Complejidad Temporal: O(|L_afectadas| + |Aristas_Bifurcacion|)
function CausalGraph:ordenamientoTopologicoKahn(lineasIds: { string }): { string }
    local conjunto: { [string]: boolean } = {}
    local gradoEntrada: { [string]: number } = {}
    local adyacencia: { [string]: { string } } = {}

    for _, id in ipairs(lineasIds) do
        conjunto[id] = true
        gradoEntrada[id] = 0
        adyacencia[id] = {}
    end

    for _, id in ipairs(lineasIds) do
        local nodo = self.timelineTree.nodos[id]
        if nodo then
            for _, hijoId in ipairs(nodo.hijos) do
                if conjunto[hijoId] then
                    table.insert(adyacencia[id], hijoId)
                    gradoEntrada[hijoId] += 1
                end
            end
        end
    end

    -- Cola de nodos con grado de entrada 0
    local cola: { string } = {}
    for _, id in ipairs(lineasIds) do
        if gradoEntrada[id] == 0 then
            table.insert(cola, id)
        end
    end

    local ordenTopologico: { string } = {}
    local head = 1
    while head <= #cola do
        local u = cola[head]
        head += 1
        table.insert(ordenTopologico, u)

        for _, v in ipairs(adyacencia[u]) do
            gradoEntrada[v] -= 1
            if gradoEntrada[v] == 0 then
                table.insert(cola, v)
            end
        end
    end

    return ordenTopologico
end

-- Propaga un evento ocurrido en (lineaOrigen, tiempoEvento) hacia el presente y todas las ramas futuras dependientes
function CausalGraph:propagarEfectoMariposa(evento: CausalEvent)
    self.contadorEventos += 1
    local nodoOrigen = self.timelineTree.nodos[evento.lineaOrigen]
    if not nodoOrigen then return end

    -- Incrementar reloj vectorial de la línea donde ocurrió el evento causal
    nodoOrigen.relojVectorial:incrementar(evento.lineaOrigen)

    -- 1. Obtener todas las ramas descendientes que nacieron en o después de tiempoEvento
    local ramasCandidatas = self.timelineTree:obtenerRamasDescendientesPosterioresA(
        evento.lineaOrigen,
        evento.tiempoEvento
    )

    -- 2. Ordenar topológicamente con el Algoritmo de Kahn para garantizar propagación sin paradojas
    local ordenCausal = self:ordenamientoTopologicoKahn(ramasCandidatas)

    print(string.format(
        "\n  [CAUSALIDAD - ORDEN TOPOLÓGICO] Propagando '%s' desde (%s @ t=%ds) -> Orden Kahn: [%s]",
        evento.descripcion,
        evento.lineaOrigen,
        evento.tiempoEvento,
        table.concat(ordenCausal, " -> ")
    ))

    -- 3. Aplicar la mutación en orden topológico y sincronizar los Relojes Vectoriales (Merge)
    for _, lineaId in ipairs(ordenCausal) do
        local nodoDestino = self.timelineTree.nodos[lineaId]
        local estadoPresente = self.snapshotManager:obtenerEstadoPresente(lineaId)

        if nodoDestino and estadoPresente then
            if lineaId ~= evento.lineaOrigen then
                -- Fusionar el reloj vectorial para dejar constancia causal (Happens-Before)
                nodoDestino.relojVectorial:fusionar(nodoOrigen.relojVectorial)
            end

            -- Aplicar impacto de objeto si corresponde
            if evento.objetoAfectado and evento.nuevoEstadoObjeto then
                self.snapshotManager:registrarDelta(lineaId, {
                    tiempo = estadoPresente.tiempo,
                    tipo = "MUTAR_OBJETO",
                    entidadId = evento.objetoAfectado,
                    valorAnterior = estadoPresente.objetos[evento.objetoAfectado],
                    valorNuevo = evento.nuevoEstadoObjeto,
                    relojVectorialStr = nodoDestino.relojVectorial:toString(),
                })
            end

            -- Aplicar impacto energético acumulado hacia el presente/futuro
            if evento.impactoEnergia ~= 0 then
                local energiaPrevia = estadoPresente.energia
                local nuevaEnergia = math.clamp(energiaPrevia + evento.impactoEnergia, 0, 100)

                self.snapshotManager:registrarDelta(lineaId, {
                    tiempo = estadoPresente.tiempo,
                    tipo = "CAMBIAR_ENERGIA",
                    entidadId = "EfectoMariposa",
                    valorAnterior = energiaPrevia,
                    valorNuevo = nuevaEnergia,
                    relojVectorialStr = nodoDestino.relojVectorial:toString(),
                })

                print(string.format(
                    "    -> [Onda Causal en %s (t=%ds)] Energía alterada: %d%% -> %d%% | %s",
                    lineaId, estadoPresente.tiempo, energiaPrevia, nuevaEnergia, nodoDestino.relojVectorial:toString()
                ))
            end
        end
    end
end

return CausalGraph
