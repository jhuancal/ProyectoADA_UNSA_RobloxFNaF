--!strict
--[[
    Animatronico.luau
    Ubicación: ServerScriptService.Modules.Animatronico
    Propósito (POO - Clase Padre de los Animatrónicos, hereda de TemporalEntity):
    Gestiona:
    - Reloj interno mediante subrutinas independientes (task.spawn)
    - Atributo común 'enojo' inicializado en 1
    - Tirada math.random(1, 20) <= enojo
    - Sincronización con el Árbol de Multiversos, Snapshots Persistentes y Relojes Vectoriales
    - Sistema de bloqueo por puertas funcionales: si se encuentra en PasilloIzquierdo o PasilloDerecho
      y la puerta correspondiente se cierra (arista eliminada), espera 5 segundos antes de volver
      a su lugar de origen.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimatronicConfig = require(Shared:WaitForChild("AnimatronicConfig"))
local RoomSpaceConfig = require(Shared:WaitForChild("RoomSpaceConfig"))

local TemporalEntity = require(script.Parent.Entities.TemporalEntity)
local SimClock = require(script.Parent.Core:WaitForChild("SimClock"))

local Animatronico = {}
Animatronico.__index = Animatronico
setmetatable(Animatronico, { __index = TemporalEntity })

export type ContextoMultiverso = {
    mapa: any,
    timelineTree: any,
    snapshotManager: any,
    causalGraph: any,
    astar: any,
    onAtraparJugador: ((atacante: string, linea: string, puerta: string) -> ())?,
}

function Animatronico.new(nombre: string, intervalo: number, nodoInicial: string, contexto: ContextoMultiverso)
    local self = TemporalEntity.new(nombre, nodoInicial, "L0")
    setmetatable(self, Animatronico)

    self.enojo = AnimatronicConfig.ENOJO_INICIAL -- Inicializado en 1 para todos los animatrónicos
    self.intervalo = intervalo -- Bonnie = 3s, Chica = 5s, Foxy = 7s
    self.estaActivo = false -- Flag de bloqueo mientras se desplaza o espera
    self.lugarDeOrigen = nodoInicial -- Nodo inicial para retorno tras bloqueo (Escenario o CuevaPirata)
    self.esperandoEnPuerta = false -- Flag de bloqueo de 5 segundos ante puerta cerrada
    self.hiloEsperaPuerta = nil :: thread?
    self.conDeltaPuerta = nil :: RBXScriptConnection?

    self.mapa = contexto.mapa
    self.timelineTree = contexto.timelineTree
    self.snapshotManager = contexto.snapshotManager
    self.causalGraph = contexto.causalGraph
    self.astar = contexto.astar
    self.onAtraparJugador = contexto.onAtraparJugador
    self.enEjecucion = false
    self.hiloReloj = nil :: thread?

    -- Escucha reactiva de eventos delta: si una puerta se cierra en su línea temporal
    -- mientras el animatrónico se encuentra en ese pasillo, se activa el bloqueo de 5s
    if self.snapshotManager and self.snapshotManager.OnDelta then
        self.conDeltaPuerta = self.snapshotManager.OnDelta.Event:Connect(function(lineaId: string, delta: any)
            if delta and delta.tipo == "ALTERNAR_PUERTA" and delta.valorNuevo == true and lineaId == self.lineaActual then
                local pasilloObjetivo = if delta.entidadId == "Izquierda" then "PasilloIzquierdo" else "PasilloDerecho"
                if self.nodoActual == pasilloObjetivo and not self.esperandoEnPuerta then
                    self:manejarBloqueoDePuerta(pasilloObjetivo)
                end
            end
        end)
    end

    return self
end

function Animatronico:iniciarReloj()
    self.enEjecucion = true
    self.hiloReloj = task.spawn(function()
        while self.enEjecucion do
            SimClock.esperar(self.intervalo)
            if not self.enEjecucion then break end

            if self.esperandoEnPuerta or self.estaActivo then
                print(string.format(
                    "  [%s | %s] En espera/movimiento activo. Ciclo de %ds pausado temporalmente.",
                    self.nombre, self.lineaActual, self.intervalo
                ))
                continue
            end

            local dado = math.random(1, AnimatronicConfig.DADO_MAX)
            print(string.format(
                "  [%s | Escenario %s | Enojo: %d] Reloj (%ds): tirada = %d vs Enojo = %d",
                self.nombre, self.lineaActual, self.enojo, self.intervalo, dado, self.enojo
            ))

            if dado <= self.enojo then
                print(string.format(
                    "  >>> [%s | %s] ¡Chequeo superado (%d <= %d)! Ejecutando algoritmo de acción...",
                    self.nombre, self.lineaActual, dado, self.enojo
                ))
                self:ejecutarAccion()
            end
        end
    end)
end

-- Se activa cuando el animatrónico se encuentra con una puerta cerrada o se le cierra en la cara
function Animatronico:manejarBloqueoDePuerta(pasillo: string)
    if self.esperandoEnPuerta then return end
    self.esperandoEnPuerta = true
    self.estaActivo = true

    print(string.format(
        "  🚪🚫 [%s | %s] ¡PUERTA CERRADA! Arista hacia Oficina eliminada. Bloqueado en '%s'. Esperando 5 segundos...",
        self.nombre, self.lineaActual, pasillo
    ))

    if self.timelineTree and self.snapshotManager then
        local nodoTimeline = self.timelineTree.nodos[self.lineaActual]
        local estado = self.snapshotManager:obtenerEstadoPresente(self.lineaActual)
        if nodoTimeline and estado then
            self:sincronizarConEscenario(nodoTimeline)
            self.snapshotManager:registrarDelta(self.lineaActual, {
                tiempo = estado.tiempo,
                tipo = "BLOQUEO_ANIMATRONICO" :: any,
                entidadId = self.nombre,
                valorAnterior = pasillo,
                valorNuevo = true,
                relojVectorialStr = self.relojEntidad:toString(),
            })
        end
    end

    if self.hiloEsperaPuerta then
        task.cancel(self.hiloEsperaPuerta)
        self.hiloEsperaPuerta = nil
    end

    self.hiloEsperaPuerta = task.spawn(function()
        SimClock.esperar(AnimatronicConfig.TIEMPO_ESPERA_PUERTA)
        if not self.enEjecucion then return end

        print(string.format(
            "  ↩️ [%s | %s] Cumplidos los 5s en '%s'. Regresando a su lugar de origen ('%s')...",
            self.nombre, self.lineaActual, pasillo, self.lugarDeOrigen
        ))

        self:volverAOrigen()
        self.esperandoEnPuerta = false
        self.estaActivo = false
        self.hiloEsperaPuerta = nil
    end)
end

-- Reinicia la posición al lugar de origen (sobreescrito por subclases para reiniciar rutas o fases)
function Animatronico:volverAOrigen()
    self:registrarMovimientoEnSnapshot(self.lugarDeOrigen)
    print(string.format("  [%s | %s] Regresó a su lugar de origen: %s", self.nombre, self.lineaActual, self.lugarDeOrigen))
end

function Animatronico:detenerReloj()
    self.enEjecucion = false
    if self.hiloReloj then
        task.cancel(self.hiloReloj)
        self.hiloReloj = nil
    end
    if self.hiloEsperaPuerta then
        task.cancel(self.hiloEsperaPuerta)
        self.hiloEsperaPuerta = nil
    end
    if self.conDeltaPuerta then
        self.conDeltaPuerta:Disconnect()
        self.conDeltaPuerta = nil
    end
    self.esperandoEnPuerta = false
    self.estaActivo = false
end

function Animatronico:aumentarEnojo(cantidad: number)
    self.enojo += cantidad
    print(string.format("  >> [%s] Enojo incrementado en +%d -> Nivel actual: %d", self.nombre, cantidad, self.enojo))
end

-- Notifica al coordinador de sesión (GameSession) que este animatrónico atrapó al jugador
function Animatronico:atraparJugador(puerta: string)
    self.enEjecucion = false
    self.estaActivo = false
    self.esperandoEnPuerta = false
    if self.onAtraparJugador then
        self.onAtraparJugador(self.nombre, self.lineaActual, puerta)
    end
end

-- Registra el cambio de ubicación en el SnapshotManager y actualiza el Reloj Vectorial de la línea actual
function Animatronico:registrarMovimientoEnSnapshot(nuevoNodo: string, gx: number?, gy: number?)
    local nodoAnterior = self.nodoActual
    self.nodoActual = nuevoNodo

    if gx and gy then
        self.gx = gx
        self.gy = gy
    else
        local sx, sy = RoomSpaceConfig.obtenerSpawnSala(nuevoNodo)
        self.gx = sx
        self.gy = sy
    end

    if self.timelineTree and self.snapshotManager then
        local nodoTimeline = self.timelineTree.nodos[self.lineaActual]
        local estado = self.snapshotManager:obtenerEstadoPresente(self.lineaActual)
        if nodoTimeline and estado then
            self:sincronizarConEscenario(nodoTimeline)
            self.snapshotManager:registrarDelta(self.lineaActual, {
                tiempo = estado.tiempo,
                tipo = "MOVER_ANIMATRONICO",
                entidadId = self.nombre,
                valorAnterior = nodoAnterior,
                valorNuevo = nuevoNodo,
                gx = self.gx,
                gy = self.gy,
                relojVectorialStr = self.relojEntidad:toString(),
            })
        end
    end
end

-- Movimiento simple bloque a bloque (estilo Pac-Man) hacia una sala destino
function Animatronico:caminarHaciaSalaPacMan(salaDestino: string, intervaloPaso: number, alLlegar: (() -> ())?)
    if self.esperandoEnPuerta then
        return
    end

    self.estaActivo = true
    local destX, destY = RoomSpaceConfig.obtenerSpawnSala(salaDestino)

    task.spawn(function()
        local estadoInicial = self.snapshotManager and self.snapshotManager:obtenerEstadoPresente(self.lineaActual)
        local camino = RoomSpaceConfig.encontrarCaminoPacMan(self.gx, self.gy, destX, destY, estadoInicial)

        -- Si no hay camino directo (ej. puerta de Oficina cerrada), intentar caminar hasta la puerta
        if #camino == 0 and salaDestino == "Oficina" then
            local pasilloObj = if self.nodoActual == "PasilloDerecho" or self.nombre == "Chica"
                then "PasilloDerecho"
                else "PasilloIzquierdo"
            local px, py = RoomSpaceConfig.obtenerSpawnSala(pasilloObj)
            local caminoPasillo = RoomSpaceConfig.encontrarCaminoPacMan(self.gx, self.gy, px, py, estadoInicial)
            for _, paso in ipairs(caminoPasillo) do
                SimClock.esperar(intervaloPaso)
                if not self.enEjecucion or self.esperandoEnPuerta then return end
                local celda = RoomSpaceConfig.obtenerCelda(paso.x, paso.y)
                local salaPaso = if celda and celda.tipo == "FLOOR" and celda.sala then celda.sala else self.nodoActual
                self:registrarMovimientoEnSnapshot(salaPaso, paso.x, paso.y)
            end
            self:manejarBloqueoDePuerta(pasilloObj)
            return
        end

        for _, paso in ipairs(camino) do
            SimClock.esperar(intervaloPaso)
            if not self.enEjecucion or self.esperandoEnPuerta then
                return
            end

            local estadoActual = self.snapshotManager and self.snapshotManager:obtenerEstadoPresente(self.lineaActual)
            if not RoomSpaceConfig.celdaEsTransitable(paso.x, paso.y, estadoActual) then
                local celda = RoomSpaceConfig.obtenerCelda(paso.x, paso.y)
                if celda and celda.puerta and celda.puerta.ladoSeguridad then
                    local pasillo = if celda.puerta.ladoSeguridad == "Izquierda" then "PasilloIzquierdo" else "PasilloDerecho"
                    self:manejarBloqueoDePuerta(pasillo)
                else
                    self.estaActivo = false
                end
                return
            end

            local celda = RoomSpaceConfig.obtenerCelda(paso.x, paso.y)
            local salaPaso = if celda and celda.tipo == "FLOOR" and celda.sala then celda.sala else self.nodoActual
            self:registrarMovimientoEnSnapshot(salaPaso, paso.x, paso.y)
        end

        if not self.enEjecucion or self.esperandoEnPuerta then
            return
        end

        if alLlegar then
            alLlegar()
        else
            self.estaActivo = false
        end
    end)
end

function Animatronico:ejecutarAccion()
    error("El método 'ejecutarAccion' debe ser implementado por la subclase.")
end

return Animatronico
