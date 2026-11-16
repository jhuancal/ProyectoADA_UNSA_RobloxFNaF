--!strict
--[[
    Bonnie.luau
    Ubicación: ServerScriptService.Modules.Bonnie
    Propósito (POO - Clase Hija de Animatronico + Algoritmo A* y Poda de Candidatos):
    - Reloj interno: 3 segundos.
    - Lista de nodos candidatos (habitaciones): {"Backstage", "Comedor", "PasilloIzquierdo"}.
      (La Oficina ya no forma parte de la lista de candidatos directos).
    - Mecánica de aproximación: Se van retirando las demás habitaciones del arreglo
      hasta que la habitación esperada a la que llega es 'PasilloIzquierdo'.
    - Lógica en PasilloIzquierdo:
      Al llegar a PasilloIzquierdo, Bonnie espera 5 segundos frente a la puerta.
      - Si la puerta izquierda está ABIERTA (flag puertaIzquierdaCerrada == false):
        Bonnie se teletransporta a la Oficina y se emite el mensaje "bonnie esta en la oficina".
      - Si la puerta izquierda está CERRADA (flag puertaIzquierdaCerrada == true):
        Se emite el aviso "intento ingresar por el lado izquierdo y no pudo".
      - En AMBOS casos, Bonnie regresa al 'Escenario' y su lista de habitaciones se reinicia.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimatronicConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimatronicConfig"))
local Animatronico = require(script.Parent.Animatronico)
local SimClock = require(script.Parent.Core:WaitForChild("SimClock"))

local cfg = AnimatronicConfig.Bonnie

local Bonnie = {}
Bonnie.__index = Bonnie
setmetatable(Bonnie, { __index = Animatronico })

function Bonnie.new(contexto: Animatronico.ContextoMultiverso)
    local self = Animatronico.new(cfg.nombre, cfg.intervalo, cfg.nodoInicial, contexto)
    setmetatable(self, Bonnie)

    self.nodosDisponibles = {} :: { string }
    self:reiniciarNodos()
    return self
end

function Bonnie:reiniciarNodos()
    self.nodosDisponibles = table.clone(cfg.candidatos)
    print(string.format("  [Bonnie | %s] Candidatos reiniciados: [%s]", self.lineaActual, table.concat(self.nodosDisponibles, ", ")))
end

function Bonnie:volverAOrigen()
    self:reiniciarNodos()
    self:registrarMovimientoEnSnapshot(self.lugarDeOrigen)
    self.esperandoEnPuerta = false
    self.estaActivo = false
    print(string.format("  [Bonnie | %s] Regresó al Escenario y reinició sus nodos candidatos.", self.lineaActual))
end

function Bonnie:manejarBloqueoDePuerta(pasillo: string)
    -- Para Bonnie, la espera y verificación en PasilloIzquierdo se gestiona de forma autónoma
    if pasillo == "PasilloIzquierdo" then
        return
    end
    Animatronico.manejarBloqueoDePuerta(self, pasillo)
end

function Bonnie:ejecutarAccion()
    if self.esperandoEnPuerta or self.estaActivo then
        return
    end

    if #self.nodosDisponibles == 0 then
        self:reiniciarNodos()
    end

    local estadoEscenario = self.snapshotManager and self.snapshotManager:obtenerEstadoPresente(self.lineaActual)
    local tActual = if estadoEscenario then estadoEscenario.tiempo else 0

    -- Filtrar habitaciones disponibles que no sean PasilloIzquierdo
    local otrasHabitaciones = {}
    for i, sala in ipairs(self.nodosDisponibles) do
        if sala ~= "PasilloIzquierdo" then
            table.insert(otrasHabitaciones, { indice = i, sala = sala })
        end
    end

    local nodoElegido: string

    if #otrasHabitaciones > 0 then
        -- Se van quitando las demás habitaciones hasta que solo quede PasilloIzquierdo
        local seleccion = otrasHabitaciones[math.random(1, #otrasHabitaciones)]
        nodoElegido = seleccion.sala
        table.remove(self.nodosDisponibles, seleccion.indice)
    else
        -- Solo queda PasilloIzquierdo en el arreglo: es el nodo esperado a llegar
        nodoElegido = "PasilloIzquierdo"
        local idxPasillo = table.find(self.nodosDisponibles, "PasilloIzquierdo")
        if idxPasillo then
            table.remove(self.nodosDisponibles, idxPasillo)
        end
    end

    -- Consultar con el algoritmo A* el costo real hacia el nodo elegido en el escenario actual
    if self.astar then
        local caminoOptimo, costoAStar = self.astar:calcularRutaOptima(
            self.nodoActual,
            nodoElegido,
            self.lineaActual,
            tActual
        )
        print(string.format(
            "  [Bonnie | A* en %s] Ruta hacia '%s': [%s] (Costo heurístico f=%.1f)",
            self.lineaActual, nodoElegido, table.concat(caminoOptimo, " -> "), costoAStar
        ))
    end

    if nodoElegido == "PasilloIzquierdo" then
        print(string.format(
            "  [Bonnie | %s] Desplazándose hacia '%s' (nodo objetivo). Restantes: [%s] | %s",
            self.lineaActual, nodoElegido, table.concat(self.nodosDisponibles, ", "), self.relojEntidad:toString()
        ))

        self:caminarHaciaSalaPacMan("PasilloIzquierdo", cfg.velocidadPaso, function()
            self.estaActivo = true
            self.esperandoEnPuerta = true

            print(string.format(
                "  👀 [Bonnie | %s] Llegó a 'PasilloIzquierdo'. Esperando %d segundos frente a la puerta...",
                self.lineaActual, cfg.esperaEnPasillo
            ))

            SimClock.esperar(cfg.esperaEnPasillo)
            if not self.enEjecucion then return end

            local estPresente = self.snapshotManager and self.snapshotManager:obtenerEstadoPresente(self.lineaActual)
            local puertaCerrada = estPresente and estPresente.puertaIzquierdaCerrada == true

            if not puertaCerrada then
                -- Puerta abierta: Bonnie entra a la Oficina y activa la derrota en GameSession
                self:registrarMovimientoEnSnapshot("Oficina")
                print("bonnie esta en la oficina")
                print(string.format("  ⚠️ [Bonnie | %s] ¡bonnie esta en la oficina!", self.lineaActual))
                self:atraparJugador(cfg.puertaAtaque)
            else
                -- Puerta cerrada: aviso de que intentó ingresar y no pudo
                print("intento ingresar por el lado izquierdo y no pudo")
                print(string.format(
                    "  🚫 [Bonnie | %s] Intento ingresar por el lado izquierdo y no pudo (puerta izquierda cerrada).",
                    self.lineaActual
                ))

                self:volverAOrigen()
            end
        end)
    else
        -- Habitación intermedia (Backstage, Comedor)
        print(string.format(
            "  [Bonnie | %s] Caminando hacia '%s' bloque a bloque. Restantes: [%s] | %s",
            self.lineaActual, nodoElegido, table.concat(self.nodosDisponibles, ", "), self.relojEntidad:toString()
        ))

        self:caminarHaciaSalaPacMan(nodoElegido, cfg.velocidadPaso, function()
            self.estaActivo = false
        end)
    end
end

return Bonnie
