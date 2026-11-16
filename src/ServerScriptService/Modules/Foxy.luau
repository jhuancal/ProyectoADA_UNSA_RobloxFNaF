--!strict
--[[
    Foxy.luau
    Ubicación: ServerScriptService.Modules.Foxy
    Propósito (POO - Clase Hija de Animatronico + Bifurcación del Árbol de Multiversos 5D):
    - Reloj interno: 7 segundos.
    - Mecánica de 3 fases en Cueva Pirata.
    - En Fase 3, ejecuta un sprint por el Pasillo Izquierdo hacia la Oficina.
    - Si la puerta izquierda está cerrada (arista eliminada), queda bloqueado en PasilloIzquierdo,
      espera 5 segundos y regresa a CuevaPirata reiniciando a Fase 1.
    - Si tiene suficiente enojo o detecta bloqueo, puede abrir una brecha temporal creando una
      nueva rama en TimelineTree.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimatronicConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimatronicConfig"))
local Animatronico = require(script.Parent.Animatronico)

local cfg = AnimatronicConfig.Foxy

local Foxy = {}
Foxy.__index = Foxy
setmetatable(Foxy, { __index = Animatronico })

function Foxy.new(contexto: Animatronico.ContextoMultiverso)
    local self = Animatronico.new(cfg.nombre, cfg.intervalo, cfg.nodoInicial, contexto)
    setmetatable(self, Foxy)

    self.fase = 1
    self.maxLineasCreadas = cfg.maxLineasCreadas -- Límite de seguridad para no saturar escenarios
    self.lineasCreadasPorFoxy = 0
    return self
end

function Foxy:volverAOrigen()
    self.fase = 1
    self:registrarMovimientoEnSnapshot(self.lugarDeOrigen)
    print(string.format("  [Foxy | %s] Regresó a la Cueva Pirata (Fase 1/3) | %s", self.lineaActual, self.relojEntidad:toString()))
end

function Foxy:ejecutarAccion()
    if self.esperandoEnPuerta then
        return
    end

    if self.fase == 1 then
        self.fase = 2
        print(string.format("  [Foxy | %s] Se asoma tras las cortinas de la Cueva Pirata (Fase 2/3).", self.lineaActual))

    elseif self.fase == 2 then
        self.fase = 3
        print(string.format("  [Foxy | %s] ¡Sale de la cortina listo para correr y rasgar el espacio-tiempo! (Fase 3/3).", self.lineaActual))

    elseif self.fase == 3 then
        self.estaActivo = true

        -- Evaluar si Foxy abre una brecha temporal al pasado creando un nuevo escenario en el TimelineTree
        if self.timelineTree and self.snapshotManager and self.lineasCreadasPorFoxy < self.maxLineasCreadas then
            local estadoActual = self.snapshotManager:obtenerEstadoPresente(self.lineaActual)
            local tActual = if estadoActual then estadoActual.tiempo else 0

            if tActual >= cfg.tiempoMinBifurcacion and (estadoActual.puertaIzquierdaCerrada or self.enojo >= 2) then
                local tPasado = math.max(5, tActual - cfg.saltoPasadoSegundos)
                self.lineasCreadasPorFoxy += 1
                local nuevoEscenario = self.timelineTree:bifurcarLinea(
                    self.lineaActual,
                    tPasado,
                    "Sprint Cuántico de Foxy hacia el pasado"
                )
                self:cambiarEscenario(nuevoEscenario.id, "PasilloIzquierdo", nuevoEscenario)
            end
        end

        print(string.format(
            "  [Foxy | %s] ¡¡ALERTA!! Foxy corre a máxima velocidad bloque a bloque hacia la Oficina!",
            self.lineaActual
        ))

        self:caminarHaciaSalaPacMan("Oficina", cfg.velocidadSprint, function()
            local estado = self.snapshotManager and self.snapshotManager:obtenerEstadoPresente(self.lineaActual)
            local puertaCerrada = estado and estado.puertaIzquierdaCerrada == true

            if puertaCerrada then
                print(string.format(
                    "  💥 [Foxy | %s] ¡BANG BANG! La puerta izquierda está CERRADA. Foxy golpea la puerta y queda bloqueado.",
                    self.lineaActual
                ))
                self:manejarBloqueoDePuerta("PasilloIzquierdo")
            else
                print("foxy esta en la oficina")
                self:atraparJugador(cfg.puertaAtaque)
            end
        end)
    end
end

return Foxy
