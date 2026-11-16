--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimatronicConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimatronicConfig"))
local Animatronico = require(script.Parent.Animatronico)
local SimClock = require(script.Parent.Core:WaitForChild("SimClock"))

local cfg = AnimatronicConfig.Chica

local Chica = {}
Chica.__index = Chica
setmetatable(Chica, { __index = Animatronico })

function Chica.new(contexto: Animatronico.ContextoMultiverso)
    local self = Animatronico.new(cfg.nombre, cfg.intervalo, cfg.nodoInicial, contexto)
    setmetatable(self, Chica)

    self.ruta = table.clone(cfg.ruta)
    self.indiceRuta = 1
    return self
end

function Chica:volverAOrigen()
    self.indiceRuta = 1
    Animatronico.volverAOrigen(self)
end

function Chica:ejecutarAccion()
    self.estaActivo = true

    if self.indiceRuta < #self.ruta then
        self.indiceRuta += 1
    else
        self.indiceRuta = 2
    end

    local siguienteNodo = self.ruta[self.indiceRuta]
    print(string.format(
        "  [Chica | %s] Moviéndose hacia '%s' (demora %ds; flag estaActivo=true)...",
        self.lineaActual, siguienteNodo, cfg.demoraMovimiento
    ))

    task.spawn(function()
        SimClock.esperar(cfg.demoraMovimiento)
        if not self.enEjecucion or self.esperandoEnPuerta then
            return
        end

        if siguienteNodo == "Oficina" then
            local estadoPuerta = self.snapshotManager and self.snapshotManager:obtenerEstadoPresente(self.lineaActual)
            if estadoPuerta and estadoPuerta.puertaDerechaCerrada == true then
                print(string.format("[Chica | %s] Intentó entrar, pero la puerta derecha estaba cerrada.", self.lineaActual))
                self:manejarBloqueoDePuerta("PasilloDerecho")
                return
            end

            self:registrarMovimientoEnSnapshot("Oficina")
            print("chica esta en la oficina")
            self:atraparJugador(cfg.puertaAtaque)
            return
        end

        self:registrarMovimientoEnSnapshot(siguienteNodo)

        if self.nodoActual == "Banos" and self.causalGraph and self.snapshotManager then
            local estado = self.snapshotManager:obtenerEstadoPresente(self.lineaActual)
            local tEvento = if estado then estado.tiempo else 0
            self.causalGraph:propagarEfectoMariposa({
                idEvento = "SABOTAJE_CHICA_" .. tostring(tEvento),
                lineaOrigen = self.lineaActual,
                tiempoEvento = math.max(0, tEvento - 5),
                tipoEfecto = "SABOTAJE_GENERADOR",
                impactoEnergia = cfg.impactoSabotaje,
                objetoAfectado = "BateriaReserva",
                nuevoEstadoObjeto = { nodo = "Banos", activo = false, integridad = 30 },
                descripcion = string.format("Chica saboteó BateríaReserva en Baños (%d%% energía causal)", cfg.impactoSabotaje),
            })
        end

        print(string.format(
            "  [Chica | %s] Llegó a '%s'. Flag desactivado (estaActivo=false) | %s",
            self.lineaActual, self.nodoActual, self.relojEntidad:toString()
        ))
        self.estaActivo = false
    end)
end

return Chica
