--!strict
--[[
    VectorClock.luau
    Ubicación: ReplicatedStorage.Shared.VectorClock
    Propósito (ADA - Sistemas Distribuidos y Causalidad Temporal):
    Implementa Relojes Lógicos de Lamport y Relojes Vectoriales (Vector Clocks)
    para ordenar causalmente eventos entre múltiples líneas temporales (escenarios)
    sin depender de un único reloj físico global.

    Permite responder en O(|L|):
    1. ¿El evento A ocurrió causalmente antes que B? (A -> B / happens-before)
    2. ¿Son dos eventos en distintas líneas temporales concurrentes/independientes? (A || B)
    3. ¿Existe una paradoja causal al propagar objetos o energía hacia el futuro?
]]

local VectorClock = {}
VectorClock.__index = VectorClock

export type ClockMap = { [string]: number }

export type VectorClockType = {
    vector: ClockMap,
    lamport: number,
    clonar: (self: VectorClockType) -> VectorClockType,
    incrementar: (self: VectorClockType, lineaId: string) -> VectorClockType,
    fusionar: (self: VectorClockType, otro: VectorClockType) -> VectorClockType,
    ocurrioAntesQue: (self: VectorClockType, otro: VectorClockType) -> boolean,
    esConcurrenteCon: (self: VectorClockType, otro: VectorClockType) -> boolean,
    toString: (self: VectorClockType) -> string,
}

function VectorClock.new(inicial: ClockMap?, lamportInicial: number?): VectorClockType
    local self = setmetatable({}, VectorClock)
    self.vector = {}
    if inicial then
        for k, v in pairs(inicial) do
            self.vector[k] = v
        end
    end
    self.lamport = lamportInicial or 0
    return (self :: any) :: VectorClockType
end

function VectorClock:clonar(): VectorClockType
    return VectorClock.new(self.vector, self.lamport)
end

-- Regla 1 de Lamport/Fidge-Mattern: Antes de procesar un evento local en la línea L_i,
-- se incrementa la entrada correspondiente del vector y el contador escalar de Lamport.
function VectorClock:incrementar(lineaId: string): VectorClockType
    local actual = self.vector[lineaId] or 0
    self.vector[lineaId] = actual + 1
    self.lamport += 1
    return self
end

-- Regla 2 (Sincronización / Bifurcación / Salto Temporal):
-- Al viajar entre líneas temporales o propagar un efecto causal, el reloj receptor
-- toma el máximo componente a componente: VC[k] = max(VC_local[k], VC_remoto[k])
function VectorClock:fusionar(otro: VectorClockType): VectorClockType
    for lineaId, valorRemoto in pairs(otro.vector) do
        local valorLocal = self.vector[lineaId] or 0
        if valorRemoto > valorLocal then
            self.vector[lineaId] = valorRemoto
        end
    end
    self.lamport = math.max(self.lamport, otro.lamport) + 1
    return self
end

-- Relación de precedencia causal estricta (Happens-Before: self -> otro)
-- Devuelve true si para todo k: self[k] <= otro[k], y existe al menos un k con self[k] < otro[k].
-- Complejidad: O(|L|) donde |L| es el número de líneas temporales activas.
function VectorClock:ocurrioAntesQue(otro: VectorClockType): boolean
    local estrictamenteMenorEnAlguno = false

    -- Unir todas las claves de ambos vectores
    local todasLasLineas: { [string]: boolean } = {}
    for k in pairs(self.vector) do todasLasLineas[k] = true end
    for k in pairs(otro.vector) do todasLasLineas[k] = true end

    for lineaId in pairs(todasLasLineas) do
        local valA = self.vector[lineaId] or 0
        local valB = otro.vector[lineaId] or 0

        if valA > valB then
            return false
        elseif valA < valB then
            estrictamenteMenorEnAlguno = true
        end
    end

    return estrictamenteMenorEnAlguno
end

-- Dos eventos son concurrentes (A || B) si ninguno ocurrió causalmente antes que el otro.
-- Útil cuando dos jugadores modifican objetos en ramas paralelas independientes.
function VectorClock:esConcurrenteCon(otro: VectorClockType): boolean
    return (not self:ocurrioAntesQue(otro)) and (not otro:ocurrioAntesQue(self))
end

function VectorClock:toString(): string
    local partes = {}
    for k, v in pairs(self.vector) do
        table.insert(partes, string.format("%s:%d", k, v))
    end
    table.sort(partes)
    return string.format("VC{L=%d | %s}", self.lamport, table.concat(partes, ", "))
end

return VectorClock
