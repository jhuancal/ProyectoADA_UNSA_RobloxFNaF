--!strict
--[[
    MultiversePlayer.luau
    Ubicación: ServerScriptService.Modules.Entities.MultiversePlayer
    Propósito (POO - Clase Hija de TemporalEntity para Jugadores Multiverso):
    Permite que los jugadores viajen entre distintos escenarios (L0, L1, L2...),
    cierren puertas y coloquen o reparen objetos en un escenario antiguo para alterar
    causalmente el presente y futuro mediante CausalGraph y VectorClock.
]]

local TemporalEntity = require(script.Parent.TemporalEntity)

local MultiversePlayer = {}
MultiversePlayer.__index = MultiversePlayer
setmetatable(MultiversePlayer, { __index = TemporalEntity })

function MultiversePlayer.new(nombreJugador: string, contexto: any)
    local self = TemporalEntity.new(nombreJugador, "Oficina", "L0")
    setmetatable(self, MultiversePlayer)

    self.timelineTree = contexto.timelineTree
    self.snapshotManager = contexto.snapshotManager
    self.causalGraph = contexto.causalGraph
    return self
end

-- El jugador se traslada a otro escenario existente para defender esa Oficina
function MultiversePlayer:viajarAEscenario(lineaDestinoId: string)
    local nodoDestino = self.timelineTree.nodos[lineaDestinoId]
    if not nodoDestino then
        warn("Escenario destino no existe: " .. tostring(lineaDestinoId))
        return
    end

    local lineaPrevia = self.lineaActual
    self:cambiarEscenario(lineaDestinoId, "Oficina", nodoDestino)

    print(string.format(
        "  [JUGADOR %s] Viajó del escenario %s -> %s (Tiempo local del escenario: t=%ds) | %s",
        self.nombre, lineaPrevia, lineaDestinoId, nodoDestino.tiempoActual, self.relojEntidad:toString()
    ))
end

-- El jugador cierra o abre una puerta en su escenario actual
function MultiversePlayer:alternarPuerta(lado: "Izquierda" | "Derecha", cerrada: boolean)
    local estado = self.snapshotManager:obtenerEstadoPresente(self.lineaActual)
    local nodoTimeline = self.timelineTree.nodos[self.lineaActual]
    if not estado or not nodoTimeline then return end

    -- Si no hay energía, las puertas no pueden cerrarse
    if cerrada and estado.energia <= 0 then
        print(string.format(
            "  [JUGADOR %s | %s @ t=%ds] ¡Sin energía! No se puede cerrar la puerta %s.",
            self.nombre, self.lineaActual, estado.tiempo, lado
        ))
        return
    end

    self:sincronizarConEscenario(nodoTimeline)
    self.snapshotManager:registrarDelta(self.lineaActual, {
        tiempo = estado.tiempo,
        tipo = "ALTERNAR_PUERTA",
        entidadId = lado,
        valorAnterior = if lado == "Izquierda" then estado.puertaIzquierdaCerrada else estado.puertaDerechaCerrada,
        valorNuevo = cerrada,
        relojVectorialStr = self.relojEntidad:toString(),
    })

    print(string.format(
        "  [JUGADOR %s | %s @ t=%ds] Puerta %s -> %s | %s",
        self.nombre, self.lineaActual, estado.tiempo, lado, if cerrada then "CERRADA" else "ABIERTA", self.relojEntidad:toString()
    ))
end

-- El jugador activa un objeto o transfiere energía en un escenario antiguo (pasado relativo),
-- desencadenando el Ordenamiento Topológico en CausalGraph para alterar escenarios futuros.
function MultiversePlayer:colocarObjetoEnPasadoParaAlterarFuturo(objetoId: string, nodoUbicacion: string, bonoEnergia: number)
    local estado = self.snapshotManager:obtenerEstadoPresente(self.lineaActual)
    if not estado then return end

    self.causalGraph:propagarEfectoMariposa({
        idEvento = "JUGADOR_OBJETO_" .. objetoId .. "_" .. tostring(estado.tiempo),
        lineaOrigen = self.lineaActual,
        tiempoEvento = 0, -- Afecta desde la raíz causal hacia las ramas conectadas
        tipoEfecto = "TRANSFERENCIA_BATERIA",
        impactoEnergia = bonoEnergia,
        objetoAfectado = objetoId,
        nuevoEstadoObjeto = { nodo = nodoUbicacion, activo = true, integridad = 100 },
        descripcion = string.format("%s activó '%s' en '%s' desde %s", self.nombre, objetoId, nodoUbicacion, self.lineaActual),
    })
end

return MultiversePlayer
