--!strict
--[[
    DebugBridge.luau
    Ubicación: ServerScriptService.Modules.Debug.DebugBridge
    Propósito:
    Puente autoritativo entre el motor 5D (GameSession, MapGraph, TimelineTree,
    SnapshotManager, Animatronico, SimClock) y la ScreenGui de depuración en el cliente.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Core = script.Parent.Parent:WaitForChild("Core")
local SimClock = require(Core:WaitForChild("SimClock"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NetworkProtocol = require(Shared:WaitForChild("NetworkProtocol"))

local DebugBridge = {}

local remotos = NetworkProtocol.obtenerRemotos()
local sesionActualRef: any = nil
local conDelta: RBXScriptConnection? = nil
local conBranch: RBXScriptConnection? = nil

local function analizarGrafo(nodos: { [string]: { string } })
    local dirigido = false
    for u, vecinos in pairs(nodos) do
        for _, v in ipairs(vecinos) do
            local rev = nodos[v]
            local encontrado = false
            if rev then
                for _, w in ipairs(rev) do
                    if w == u then
                        encontrado = true
                        break
                    end
                end
            end
            if not encontrado then
                dirigido = true
                break
            end
        end
        if dirigido then
            break
        end
    end

    local aristas: { { origen: string, destino: string } } = {}
    local vistas: { [string]: boolean } = {}
    for u, vecinos in pairs(nodos) do
        for _, v in ipairs(vecinos) do
            if dirigido then
                table.insert(aristas, { origen = u, destino = v })
            else
                local clave = if u < v then (u .. "|" .. v) else (v .. "|" .. u)
                if not vistas[clave] then
                    vistas[clave] = true
                    table.insert(aristas, { origen = u, destino = v })
                end
            end
        end
    end

    return dirigido, aristas
end

function DebugBridge.obtenerEstado()
    if not sesionActualRef then
        return nil
    end

    local mapa = sesionActualRef.mapa
    if not mapa then
        return nil
    end

    local timelineTree = sesionActualRef.timelineTree
    local snapshotManager = sesionActualRef.snapshotManager

    local dirigido, aristas = analizarGrafo(mapa.nodos or {})

    local lineas = {}
    if timelineTree then
        for _, nodoLinea in ipairs(timelineTree:obtenerLineasActivas()) do
            local est = if snapshotManager then snapshotManager:obtenerEstadoPresente(nodoLinea.id) else nil
            local copiaPos: { [string]: string } = {}
            if est and est.posicionesAnimatronicos then
                for k, v in pairs(est.posicionesAnimatronicos) do
                    copiaPos[k] = v
                end
            end

            local copiaEspacial: { [string]: { sala: string, gx: number, gy: number } } = {}
            if est and est.posicionesEspaciales then
                for k, v in pairs(est.posicionesEspaciales) do
                    copiaEspacial[k] = { sala = v.sala, gx = v.gx, gy = v.gy }
                end
            end

            table.insert(lineas, {
                id = nodoLinea.id,
                padreId = nodoLinea.padreId,
                tiempoOrigen = nodoLinea.tiempoOrigen,
                tiempo = if est then est.tiempo else nodoLinea.tiempoActual,
                energia = if est then est.energia else 100,
                puertaIzquierdaCerrada = if est then est.puertaIzquierdaCerrada else false,
                puertaDerechaCerrada = if est then est.puertaDerechaCerrada else false,
                posiciones = copiaPos,
                posicionesEspaciales = copiaEspacial,
                relojVectorial = if est then est.relojVectorialStr else "",
            })
        end
    end

    local listaAnims = {}
    if sesionActualRef.animatronicos then
        for _, anim in ipairs(sesionActualRef.animatronicos) do
            table.insert(listaAnims, {
                nombre = anim.nombre,
                nodoActual = anim.nodoActual,
                gx = anim.gx,
                gy = anim.gy,
                lineaActual = anim.lineaActual,
                enojo = anim.enojo,
                estaActivo = anim.estaActivo,
                fase = (anim :: any).fase,
                esperandoEnPuerta = (anim :: any).esperandoEnPuerta == true,
            })
        end
    end

    local estadoJuego = if sesionActualRef.obtenerEstado
        then sesionActualRef:obtenerEstado()
        else (sesionActualRef.estado or "LOBBY")

    return {
        estadoJuego = estadoJuego,
        grafo = {
            nodos = mapa.nodos,
            aristas = aristas,
            dirigido = dirigido,
        },
        lineas = lineas,
        animatronicos = listaAnims,
        reloj = {
            pausado = SimClock.estaPausado(),
            tiempoSim = SimClock.obtenerTiempo(),
        },
    }
end

function DebugBridge.conectarSesion(sesion: any)
    sesionActualRef = sesion

    if conDelta then
        conDelta:Disconnect()
        conDelta = nil
    end
    if conBranch then
        conBranch:Disconnect()
        conBranch = nil
    end

    if sesion.snapshotManager and sesion.snapshotManager.OnDelta then
        conDelta = sesion.snapshotManager.OnDelta.Event:Connect(function(lineaId: string, delta: any)
            if not delta then return end
            if delta.tipo == "MOVER_ANIMATRONICO" then
                remotos.DebugEvento:FireAllClients({
                    tipo = "MOVER",
                    linea = lineaId,
                    entidad = delta.entidadId,
                    de = delta.valorAnterior,
                    a = delta.valorNuevo,
                    gx = delta.gx,
                    gy = delta.gy,
                    t = delta.tiempo,
                })
            elseif delta.tipo == "ALTERNAR_PUERTA" then
                remotos.DebugEvento:FireAllClients({
                    tipo = "PUERTA",
                    linea = lineaId,
                    lado = delta.entidadId,
                    cerrada = delta.valorNuevo,
                    t = delta.tiempo,
                })
            elseif delta.tipo == "CAMBIAR_ENERGIA" then
                remotos.DebugEvento:FireAllClients({
                    tipo = "ENERGIA",
                    linea = lineaId,
                    energia = delta.valorNuevo,
                    t = delta.tiempo,
                })
            elseif delta.tipo == "BLOQUEO_ANIMATRONICO" then
                remotos.DebugEvento:FireAllClients({
                    tipo = "BLOQUEO",
                    linea = lineaId,
                    entidad = delta.entidadId,
                    pasillo = delta.valorAnterior,
                    t = delta.tiempo,
                })
            end
        end)
    end

    if sesion.timelineTree and sesion.timelineTree.OnBranch then
        conBranch = sesion.timelineTree.OnBranch.Event:Connect(function(nuevoId: string, origenId: string, tSalto: number, motivo: string)
            remotos.DebugEvento:FireAllClients({
                tipo = "BRANCH",
                linea = nuevoId,
                origen = origenId,
                t = tSalto,
                motivo = motivo,
            })
        end)
    end

    -- Notificar reinicio de sesión a todos los clientes conectados
    remotos.DebugEvento:FireAllClients({
        tipo = "RESET",
    })
end

-- Compatibilidad con llamada de inicio tradicional
function DebugBridge.iniciar(contexto: any, listaAnimatronicos: { any })
    local pseudoSesion = {
        mapa = contexto.mapa,
        timelineTree = contexto.timelineTree,
        snapshotManager = contexto.snapshotManager,
        animatronicos = listaAnimatronicos,
        obtenerEstado = function() return "PLAYING" end,
    }
    DebugBridge.conectarSesion(pseudoSesion)
end

-- Registrar handlers remotos de inmediato para evitar yields infinitos
remotos.DebugGetEstado.OnServerInvoke = function(_player: Player)
    if not RunService:IsStudio() then
        return nil
    end
    return DebugBridge.obtenerEstado()
end

remotos.DebugControl.OnServerEvent:Connect(function(_player: Player, accion: string, arg: any)
    if not RunService:IsStudio() then
        return
    end
    if accion == "Pausar" then
        SimClock.pausar()
    elseif accion == "Reanudar" then
        SimClock.reanudar()
    elseif accion == "Paso" then
        if SimClock.estaPausado() then
            SimClock.avanzar(tonumber(arg) or 1)
        end
    end
end)

SimClock.OnStateChanged.Event:Connect(function(pausado: boolean, tiempoSim: number)
    remotos.DebugEvento:FireAllClients({
        tipo = "RELOJ",
        pausado = pausado,
        tiempoSim = tiempoSim,
    })
end)

return DebugBridge
