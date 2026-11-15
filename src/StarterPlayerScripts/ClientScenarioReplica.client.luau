--!strict
--[[
    ClientScenarioReplica.client.luau
    Ubicación: StarterPlayer.StarterPlayerScripts.ClientScenarioReplica
    Propósito (Arquitectura Cliente-Servidor: Duplicación Perezosa / Lazy Viewport Hydration):
    Explica y ejecuta la carga que asume el Cliente para liberar al Servidor:
    1. El Servidor NO instancia 10 pizzerías 3D en Workspace; solo envía paquetes Delta (NetworkProtocol).
    2. El Cliente mantiene UNA sola instancia física 3D activa en su cámara (el escenario L_i donde está parado)
       y la hidrata/actualiza en O(1) cuando el jugador salta de línea temporal (Object Pooling).
    3. Para los demás escenarios paralelos del multiverso, el Cliente solo actualiza un Radar Táctico 2D (UI).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local NetworkProtocol = require(Shared:WaitForChild("NetworkProtocol"))

local remotos = NetworkProtocol.obtenerRemotos()

-- Estado en caché en el cliente de todas las líneas temporales conocidas (para el Radar 5D en UI)
local cacheMultiversoCliente: { [string]: NetworkProtocol.DeltaPayload } = {}
local escenarioVisibleActual = "L0"

local function renderizarEscenario3DLocal(payload: NetworkProtocol.DeltaPayload)
    -- Aquí el cliente actualiza las puertas físicas, luces, objetos y modelos 3D
    -- ÚNICAMENTE del escenario donde el jugador tiene su cámara actual (escenarioVisibleActual).
    print(string.format(
        "[CLIENTE - RENDER 3D ACTIVO (%s | t=%ds)] Energía: %d%% | PuertaIzq: %s | PuertaDer: %s | %s",
        payload.lineaId,
        payload.tiempo,
        payload.energiaActual,
        tostring(payload.puertaIzquierdaCerrada),
        tostring(payload.puertaDerechaCerrada),
        payload.relojVectorial
    ))
end

local function actualizarRadar2DMultiverso(payload: NetworkProtocol.DeltaPayload)
    -- Para escenarios donde el jugador NO está físicamente presente, el cliente solo
    -- actualiza los íconos del minimapa 2D (ahorrando 95% de GPU y memoria física).
    if payload.enJaqueTemporal then
        warn(string.format(
            "[CLIENTE - RADAR 5D ALERTA] ¡La Oficina del escenario paralelo %s (t=%ds) está en JAQUE TEMPORAL!",
            payload.lineaId, payload.tiempo
        ))
    end
end

remotos.OnTimelineDelta.OnClientEvent:Connect(function(payload: NetworkProtocol.DeltaPayload)
    cacheMultiversoCliente[payload.lineaId] = payload

    if payload.lineaId == escenarioVisibleActual then
        renderizarEscenario3DLocal(payload)
    else
        actualizarRadar2DMultiverso(payload)
    end
end)

remotos.OnBranchCreated.OnClientEvent:Connect(function(nuevaLineaId: string, lineaOrigenId: string, tOrigen: number)
    print(string.format(
        "[CLIENTE - UI MULTIVERSO] Nuevo tablero detectado en el árbol: %s (nacido de %s en t=%ds)",
        nuevaLineaId, lineaOrigenId, tOrigen
    ))
end)

remotos.OnCausalRipple.OnClientEvent:Connect(function(descripcion: string)
    print(string.format("[CLIENTE - EFECTO MARIPOSA] %s", descripcion))
end)
