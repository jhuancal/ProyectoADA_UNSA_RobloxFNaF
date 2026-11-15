--!strict
--[[
    GameSession.luau
    Ubicación: ServerScriptService.Modules.Core.GameSession
    Propósito (Encapsulación POO de la Sesión de Juego):
    Encapsula todo el motor 5D Multiverse FNAF (Mapa, Snapshots, TimelineTree,
    CausalGraph, SpaceTimeAStar, Animatrónicos y Reloj Global de 140s).
    Permite mantener el juego en espera ("LOBBY") y arrancarlo bajo demanda
    mediante session:iniciar().
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NetworkProtocol = require(Shared:WaitForChild("NetworkProtocol"))

local Modules = ServerScriptService:WaitForChild("Modules")
local Core = Modules:WaitForChild("Core")
local Entities = Modules:WaitForChild("Entities")

local MapGraph = require(Modules:WaitForChild("MapGraph"))
local SnapshotManager = require(Core:WaitForChild("SnapshotManager"))
local TimelineTree = require(Core:WaitForChild("TimelineTree"))
local CausalGraph = require(Core:WaitForChild("CausalGraph"))
local SpaceTimeAStar = require(Core:WaitForChild("SpaceTimeAStar"))

local Bonnie = require(Modules:WaitForChild("Bonnie"))
local Chica = require(Modules:WaitForChild("Chica"))
local Foxy = require(Modules:WaitForChild("Foxy"))
local MultiversePlayer = require(Entities:WaitForChild("MultiversePlayer"))

local SimClock = require(Core:WaitForChild("SimClock"))
local DebugBridge = require(Modules:WaitForChild("Debug"):WaitForChild("DebugBridge"))

local GameSession = {}
GameSession.__index = GameSession

function GameSession.new()
    local self = setmetatable({}, GameSession)

    self.estado = "LOBBY" :: NetworkProtocol.GameStateType
    self.remotos = NetworkProtocol.obtenerRemotos()
    self.hiloPrincipal = nil :: thread?

    -- Inicializar estructuras del motor 5D en estado de espera
    self:_prepararMotor()
    return self
end

function GameSession:_prepararMotor()
    self.mapa = MapGraph.new()
    self.snapshotManager = SnapshotManager.new()
    self.timelineTree = TimelineTree.new(self.snapshotManager)
    self.causalGraph = CausalGraph.new(self.timelineTree, self.snapshotManager)
    self.astar = SpaceTimeAStar.new(self.mapa, self.snapshotManager)

    local contexto = {
        mapa = self.mapa,
        timelineTree = self.timelineTree,
        snapshotManager = self.snapshotManager,
        causalGraph = self.causalGraph,
        astar = self.astar,
    }

    self.bonnie = Bonnie.new(contexto)
    self.chica = Chica.new(contexto)
    self.foxy = Foxy.new(contexto)
    self.animatronicos = { self.bonnie, self.chica, self.foxy }

    self.guardiaAlfa = MultiversePlayer.new("Guardia_Alfa", contexto)
    self.guardiaBeta = MultiversePlayer.new("Guardia_Beta", contexto)

    -- Conectar el puente de depuración para visualización en tiempo real desde el Lobby
    DebugBridge.conectarSesion(self)
end

function GameSession:obtenerEstado(): NetworkProtocol.GameStateType
    return self.estado
end

function GameSession:_imprimirMatrizMultiverso()
    print("\n  ┌───────────────────────── MATRIZ DEL MULTIVERSO 5D ─────────────────────────┐")
    for _, nodoLinea in ipairs(self.timelineTree:obtenerLineasActivas()) do
        local est = self.snapshotManager:obtenerEstadoPresente(nodoLinea.id)
        if est then
            local origenInfo = if nodoLinea.padreId
                then string.format("rama de %s@t=%ds", nodoLinea.padreId, nodoLinea.tiempoOrigen)
                else "RAÍZ"
            print(string.format(
                "  │ [%s (%s) | RelojEscenario: t=%ds | %s]",
                nodoLinea.id, origenInfo, est.tiempo, nodoLinea.relojVectorial:toString()
            ))
            print(string.format(
                "  │   Energía: %d%% (Drenaje: %d/tick) | PuertaIzq: %s | PuertaDer: %s",
                est.energia,
                est.tasaDrenajeEnergia,
                if est.puertaIzquierdaCerrada then "CERRADA" else "ABIERTA",
                if est.puertaDerechaCerrada then "CERRADA" else "ABIERTA"
            ))
            print(string.format(
                "  │   Posiciones -> Bonnie: %s | Chica: %s | Foxy: %s",
                tostring(est.posicionesAnimatronicos["Bonnie"]),
                tostring(est.posicionesAnimatronicos["Chica"]),
                tostring(est.posicionesAnimatronicos["Foxy"])
            ))
        end
    end
    print("  └────────────────────────────────────────────────────────────────────────────┘\n")
end

-- Inicia la partida cuando un jugador presiona el botón "Iniciar" en el Lobby GUI
function GameSession:iniciar(): boolean
    if self.estado == "PLAYING" then
        warn("[GameSession] La partida ya se encuentra en curso.")
        return false
    end

    -- Si ya concluyó una partida anterior, reiniciamos el motor limpio
    if self.estado == "ENDED" then
        self:_prepararMotor()
    end

    self.estado = "PLAYING"
    self.remotos.OnGameStateChanged:FireAllClients("PLAYING")

    print("\n================================================================================")
    print("  INICIANDO MOTOR 5D MULTIVERSE FNAF - PROYECTO ADA (140 SEGUNDOS)")
    print("================================================================================")

    SimClock.reiniciar()
    self.timelineTree:iniciarRelojesDeEscenarios()
    for _, animatronico in ipairs(self.animatronicos) do
        animatronico:iniciarReloj()
    end

    local DURACION_TOTAL = 140
    local INTERVALO_HORA = 20
    local tiempoTranscurrido = 0

    self.hiloPrincipal = task.spawn(function()
        while tiempoTranscurrido < DURACION_TOTAL and self.estado == "PLAYING" do
            SimClock.esperar(INTERVALO_HORA)
            if self.estado ~= "PLAYING" then break end

            tiempoTranscurrido += INTERVALO_HORA
            print(string.format("\n================ [ RELOJ GLOBAL: %d / %d SEGUNDOS ] ================", tiempoTranscurrido, DURACION_TOTAL))

            if tiempoTranscurrido == 20 then
                print(">>> [20s - 1:00 AM] Bonnie aumenta su enojo en +1.")
                self.bonnie:aumentarEnojo(1)

            elseif tiempoTranscurrido == 40 then
                print(">>> [40s - 2:00 AM] Bonnie y Chica aumentan su enojo en +1.")
                self.bonnie:aumentarEnojo(1)
                self.chica:aumentarEnojo(1)
                local escenarioPasado = self.timelineTree:bifurcarLinea("L0", 15, "Salto táctico de Guardia_Beta al pasado")
                self.guardiaBeta:viajarAEscenario(escenarioPasado.id)
                self.guardiaBeta:colocarObjetoEnPasadoParaAlterarFuturo("SenueloSonoro", "Comedor", 15)

            elseif tiempoTranscurrido == 60 then
                print(">>> [60s - 3:00 AM] Bonnie, Chica y Foxy aumentan su enojo en +1.")
                self.bonnie:aumentarEnojo(1)
                self.chica:aumentarEnojo(1)
                self.foxy:aumentarEnojo(1)

            elseif tiempoTranscurrido == 80 then
                print(">>> [80s - 4:00 AM] Bonnie aumenta su enojo en +2.")
                self.bonnie:aumentarEnojo(2)

            elseif tiempoTranscurrido == 100 then
                print(">>> [100s - 5:00 AM] Bonnie y Chica aumentan su enojo en +2.")
                self.bonnie:aumentarEnojo(2)
                self.chica:aumentarEnojo(2)

            elseif tiempoTranscurrido == 120 then
                print(">>> [120s - 6:00 AM PREVIA] ¡Los 3 animatrónicos aumentan su enojo en +2!")
                self.bonnie:aumentarEnojo(2)
                self.chica:aumentarEnojo(2)
                self.foxy:aumentarEnojo(2)
            end

            self:_imprimirMatrizMultiverso()
        end

        if self.estado == "PLAYING" then
            print("\n================================================================================")
            print("concluyo la noche.")
            print("================================================================================")
            self:detener()
        end
    end)

    return true
end

function GameSession:alternarPuerta(lado: "Izquierda" | "Derecha", cerrada: boolean?, lineaId: string?): boolean
    local targetLinea = lineaId or (if self.guardiaAlfa then self.guardiaAlfa.lineaActual else "L0")
    local estado = self.snapshotManager:obtenerEstadoPresente(targetLinea)
    if not estado then return false end

    local estadoActualPuerta = if lado == "Izquierda" then estado.puertaIzquierdaCerrada else estado.puertaDerechaCerrada
    local nuevoValor = if cerrada ~= nil then cerrada else not estadoActualPuerta

    if nuevoValor and estado.energia <= 0 then
        warn(string.format("[GameSession] Imposible cerrar puerta %s en %s: ¡Energía agotada!", lado, targetLinea))
        return false
    end

    if self.guardiaAlfa and self.guardiaAlfa.lineaActual == targetLinea then
        self.guardiaAlfa:alternarPuerta(lado, nuevoValor)
    else
        local nodoTimeline = self.timelineTree.nodos[targetLinea]
        local relojStr = if nodoTimeline then nodoTimeline.relojVectorial:toString() else ""
        self.snapshotManager:registrarDelta(targetLinea, {
            tiempo = estado.tiempo,
            tipo = "ALTERNAR_PUERTA",
            entidadId = lado,
            valorAnterior = estadoActualPuerta,
            valorNuevo = nuevoValor,
            relojVectorialStr = relojStr,
        })
    end
    return true
end

function GameSession:detener()
    if self.estado == "ENDED" then return end
    self.estado = "ENDED"

    if self.hiloPrincipal then
        task.cancel(self.hiloPrincipal)
        self.hiloPrincipal = nil
    end

    for _, animatronico in ipairs(self.animatronicos) do
        animatronico:detenerReloj()
    end
    self.timelineTree:detenerTodosLosEscenarios()
    self.remotos.OnGameStateChanged:FireAllClients("ENDED")
end

return GameSession
