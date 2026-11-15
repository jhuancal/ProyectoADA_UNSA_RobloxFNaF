--!strict
local Animatronico = require(script.Parent.Animatronico)
local SimClock = require(script.Parent.Core:WaitForChild("SimClock"))

local Chica = {}
Chica.__index = Chica
setmetatable(Chica, { __index = Animatronico })

function Chica.new(contexto: Animatronico.ContextoMultiverso)
    local self = Animatronico.new("Chica", 5, "Escenario", contexto)
    setmetatable(self, Chica)

    self.ruta = {
        "Escenario",
        "Comedor",
        "Banos",
        "PasilloDerecho",
        "Oficina",
    }
    self.indiceRuta = 1
    return self
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
        "  [Chica | %s] Moviéndose hacia '%s' (demora 2s; flag estaActivo=true)...",
        self.lineaActual, siguienteNodo
    ))

    task.spawn(function()
        SimClock.esperar(2)
        self:registrarMovimientoEnSnapshot(siguienteNodo)

        if self.nodoActual == "Banos" and self.causalGraph and self.snapshotManager then
            local estado = self.snapshotManager:obtenerEstadoPresente(self.lineaActual)
            local tEvento = if estado then estado.tiempo else 0
            self.causalGraph:propagarEfectoMariposa({
                idEvento = "SABOTAJE_CHICA_" .. tostring(tEvento),
                lineaOrigen = self.lineaActual,
                tiempoEvento = math.max(0, tEvento - 5),
                tipoEfecto = "SABOTAJE_GENERADOR",
                impactoEnergia = -8,
                objetoAfectado = "BateriaReserva",
                nuevoEstadoObjeto = { nodo = "Banos", activo = false, integridad = 30 },
                descripcion = "Chica saboteó BateríaReserva en Baños (-8% energía causal)",
            })
        end

        if self.nodoActual == "Oficina" then
            self.estaActivo = false
            local estadoPuerta = self.snapshotManager and self.snapshotManager:obtenerEstadoPresente(self.lineaActual)
            if estadoPuerta and estadoPuerta.puertaDerechaCerrada == true then
                print(string.format("[Chica | %s] Intentó entrar, pero la puerta derecha estaba cerrada.", self.lineaActual))
                self.indiceRuta = 1
                self:registrarMovimientoEnSnapshot("Escenario")
            else
                print("chica esta en la oficina")
                self.enEjecucion = false
                local remotos = game:GetService("ReplicatedStorage"):WaitForChild("MultiverseRemotes")
                remotos.OnDefeat:FireAllClients({ atacante = "Chica", linea = self.lineaActual, puerta = "derecha" })
                remotos.OnGameStateChanged:FireAllClients("ENDED")
                print(string.format("[DERROTA] Chica atrapó al jugador en %s.", self.lineaActual))
            end
        else
            print(string.format(
                "  [Chica | %s] Llegó a '%s'. Flag desactivado (estaActivo=false) | %s",
                self.lineaActual, self.nodoActual, self.relojEntidad:toString()
            ))
            self.estaActivo = false
        end
    end)
end

return Chica
