--!strict
--[[
    TimelineTree.luau
    Ubicación: ServerScriptService.Modules.Core.TimelineTree
    Propósito (ADA - Árboles Dirigidos / DAG de Multiversos y Relojes por Escenario):
    Administra la topología del multiverso (L0, L1, L2...) como un Árbol de Bifurcación Temporal.
    Cada línea temporal posee:
    - Su propio Reloj Físico Local (tiempoActual en segundos desde que nació en t_origen)
    - Su propio Reloj Lógico Vectorial (VectorClock) para causalidad entre escenarios
    - Su propia subrutina independiente (task.spawn) para avanzar su tiempo y consumo energético
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local VectorClock = require(Shared:WaitForChild("VectorClock"))
local SimClock = require(script.Parent:WaitForChild("SimClock"))

export type TimelineNode = {
    id: string,
    padreId: string?,
    tiempoOrigen: number,
    tiempoActual: number,
    relojVectorial: VectorClock.VectorClockType,
    hijos: { string },
    activa: boolean,
    hiloEscenario: thread?,
}

local TimelineTree = {}
TimelineTree.__index = TimelineTree

function TimelineTree.new(snapshotManager: any)
    local self = setmetatable({}, TimelineTree)
    self.snapshotManager = snapshotManager
    self.nodos = {} :: { [string]: TimelineNode }
    self.ordenCreacion = {} :: { string }
    self.contadorLineas = 0
    self.enEjecucionGlobal = false
    self.OnBranch = Instance.new("BindableEvent")

    -- Crear la línea temporal raíz L0 en t = 0
    self:crearLineaRaiz()
    return self
end

function TimelineTree:crearLineaRaiz(): TimelineNode
    local id = "L0"
    local vc = VectorClock.new({ [id] = 1 }, 1)

    local nodoRaiz: TimelineNode = {
        id = id,
        padreId = nil,
        tiempoOrigen = 0,
        tiempoActual = 0,
        relojVectorial = vc,
        hijos = {},
        activa = true,
        hiloEscenario = nil,
    }

    self.nodos[id] = nodoRaiz
    table.insert(self.ordenCreacion, id)
    self.snapshotManager:inicializarLineaRaiz(id, vc:toString())
    return nodoRaiz
end

-- Crea una bifurcación en el árbol de multiversos cuando una entidad viaja al pasado (lineaOrigen, tSalto)
function TimelineTree:bifurcarLinea(lineaOrigenId: string, tSalto: number, motivo: string): TimelineNode
    local nodoPadre = self.nodos[lineaOrigenId]
    assert(nodoPadre, "No existe la línea temporal origen: " .. tostring(lineaOrigenId))

    self.contadorLineas += 1
    local nuevoId = string.format("L%d", self.contadorLineas)

    -- El reloj vectorial de la nueva rama hereda el estado causal del padre y se incrementa
    local nuevoVC = nodoPadre.relojVectorial:clonar()
    nuevoVC:incrementar(nuevoId)

    local nuevoNodo: TimelineNode = {
        id = nuevoId,
        padreId = lineaOrigenId,
        tiempoOrigen = tSalto,
        tiempoActual = tSalto,
        relojVectorial = nuevoVC,
        hijos = {},
        activa = true,
        hiloEscenario = nil,
    }

    table.insert(nodoPadre.hijos, nuevoId)
    self.nodos[nuevoId] = nuevoNodo
    table.insert(self.ordenCreacion, nuevoId)

    -- Ramificar el Snapshot persistente desde el instante tSalto
    self.snapshotManager:ramificarEstado(lineaOrigenId, nuevoId, tSalto, nuevoVC:toString())

    print(string.format(
        "\n  [MULTIVERSO - BIFURCACIÓN] ¡Nació la línea '%s' desde (%s @ t=%ds)! Motivo: %s | %s",
        nuevoId, lineaOrigenId, tSalto, motivo, nuevoVC:toString()
    ))
    self.OnBranch:Fire(nuevoId, lineaOrigenId, tSalto, motivo)

    -- Si el motor ya está corriendo, iniciar la subrutina de reloj para este nuevo escenario
    if self.enEjecucionGlobal then
        self:_iniciarSubrutinaEscenario(nuevoNodo)
    end

    return nuevoNodo
end

function TimelineTree:_iniciarSubrutinaEscenario(nodo: TimelineNode)
    if nodo.hiloEscenario then return end

    nodo.hiloEscenario = task.spawn(function()
        while self.enEjecucionGlobal and nodo.activa do
            SimClock.esperar(1)
            if not self.enEjecucionGlobal or not nodo.activa then break end

            nodo.tiempoActual += 1
            local estado = self.snapshotManager:obtenerEstadoPresente(nodo.id)
            if estado then
                estado.tiempo = nodo.tiempoActual

                -- Drenaje energético acelerado según uso de puertas funcionales:
                -- - Con 2 puertas cerradas: drena 1% cada 1 segundo (consumo crítico)
                -- - Con 1 puerta cerrada: drena 1% cada 2 segundos (consumo rápido)
                -- - Con 0 puertas cerradas: drena pasivamente cada 5 segundos (consumo base)
                local puertasCerradas = 0
                if estado.puertaIzquierdaCerrada then puertasCerradas += 1 end
                if estado.puertaDerechaCerrada then puertasCerradas += 1 end

                local debeDrenar = false
                local cantidadDrenaje = 0

                if puertasCerradas == 2 then
                    debeDrenar = true
                    cantidadDrenaje = 1 + (if estado.tasaDrenajeEnergia > 1 then 1 else 0)
                elseif puertasCerradas == 1 then
                    if nodo.tiempoActual % 2 == 0 then
                        debeDrenar = true
                        cantidadDrenaje = 1 + (if estado.tasaDrenajeEnergia > 1 then 1 else 0)
                    end
                else
                    if nodo.tiempoActual % 5 == 0 then
                        debeDrenar = true
                        cantidadDrenaje = estado.tasaDrenajeEnergia
                    end
                end

                if debeDrenar and estado.energia > 0 then
                    local nuevaEnergia = math.max(0, estado.energia - cantidadDrenaje)
                    nodo.relojVectorial:incrementar(nodo.id)

                    self.snapshotManager:registrarDelta(nodo.id, {
                        tiempo = nodo.tiempoActual,
                        tipo = "CAMBIAR_ENERGIA",
                        entidadId = "SistemaElectrico",
                        valorAnterior = estado.energia,
                        valorNuevo = nuevaEnergia,
                        relojVectorialStr = nodo.relojVectorial:toString(),
                    })
                end
            end
        end
    end)
end

function TimelineTree:iniciarRelojesDeEscenarios()
    self.enEjecucionGlobal = true
    for _, id in ipairs(self.ordenCreacion) do
        local nodo = self.nodos[id]
        if nodo and nodo.activa then
            self:_iniciarSubrutinaEscenario(nodo)
        end
    end
end

function TimelineTree:detenerTodosLosEscenarios()
    self.enEjecucionGlobal = false
    for _, id in ipairs(self.ordenCreacion) do
        local nodo = self.nodos[id]
        if nodo and nodo.hiloEscenario then
            task.cancel(nodo.hiloEscenario)
            nodo.hiloEscenario = nil
        end
    end
end

-- Recorrido en anchura (BFS) del árbol de multiversos para obtener todos los descendientes
-- de una línea temporal que nacieron después del instante tEvento.
function TimelineTree:obtenerRamasDescendientesPosterioresA(lineaOrigenId: string, tEvento: number): { string }
    local afectadas: { string } = { lineaOrigenId }
    local cola: { string } = { lineaOrigenId }
    local head = 1

    while head <= #cola do
        local actualId = cola[head]
        head += 1

        local nodoActual = self.nodos[actualId]
        if nodoActual then
            for _, hijoId in ipairs(nodoActual.hijos) do
                local nodoHijo = self.nodos[hijoId]
                -- Solo propaga a ramas hijas que se bifurcaron después del evento en el pasado
                if nodoHijo and nodoHijo.tiempoOrigen >= tEvento then
                    table.insert(afectadas, hijoId)
                    table.insert(cola, hijoId)
                end
            end
        end
    end

    return afectadas
end

function TimelineTree:obtenerLineasActivas(): { TimelineNode }
    local activas = {}
    for _, id in ipairs(self.ordenCreacion) do
        local n = self.nodos[id]
        if n and n.activa then
            table.insert(activas, n)
        end
    end
    return activas
end

return TimelineTree
