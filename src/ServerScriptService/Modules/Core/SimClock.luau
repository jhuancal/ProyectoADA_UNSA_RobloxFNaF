--!strict
--[[
    SimClock.luau
    Ubicación: ServerScriptService.Modules.Core.SimClock
    Propósito:
    Reloj simulado compartido para el servidor. Permite pausar, reanudar y avanzar
    paso a paso (1 tick = 1 segundo simulado) todas las subrutinas de la simulación
    sin modificar la lógica de negocio.
]]

local RunService = game:GetService("RunService")

type Waiter = {
    thread: thread,
    objetivo: number,
    inicio: number,
}

local SimClock = {}

local tiempoSim = 0
local pausado = false
local waiters: { Waiter } = {}

local onStateChanged = Instance.new("BindableEvent")
SimClock.OnStateChanged = onStateChanged

local function despacharVencidos()
    -- Ordenar por objetivo ascendente para respetar el orden temporal al avanzar varios segundos
    table.sort(waiters, function(a: Waiter, b: Waiter)
        return a.objetivo < b.objetivo
    end)

    local i = 1
    while i <= #waiters do
        local w = waiters[i]
        local estadoHilo = coroutine.status(w.thread)
        if estadoHilo == "dead" then
            table.remove(waiters, i)
        elseif tiempoSim >= w.objetivo then
            table.remove(waiters, i)
            if estadoHilo == "suspended" then
                local transcurrido = tiempoSim - w.inicio
                task.spawn(w.thread, transcurrido)
            end
        else
            i += 1
        end
    end
end

RunService.Heartbeat:Connect(function(dt: number)
    if pausado then
        return
    end
    tiempoSim += dt
    if #waiters > 0 then
        despacharVencidos()
    end
end)

function SimClock.esperar(segundos: number?): number
    local duracion = math.max(0, segundos or 0)
    local hilo = coroutine.running()
    local inicio = tiempoSim
    table.insert(waiters, {
        thread = hilo,
        objetivo = inicio + duracion,
        inicio = inicio,
    })
    return coroutine.yield()
end

function SimClock.pausar()
    if pausado then
        return
    end
    pausado = true
    onStateChanged:Fire(pausado, tiempoSim)
end

function SimClock.reanudar()
    if not pausado then
        return
    end
    pausado = false
    onStateChanged:Fire(pausado, tiempoSim)
end

function SimClock.avanzar(segundos: number?)
    local paso = math.max(0.05, segundos or 1)
    tiempoSim += paso
    despacharVencidos()
    onStateChanged:Fire(pausado, tiempoSim)
end

function SimClock.reiniciar()
    tiempoSim = 0
    pausado = false
    table.clear(waiters)
    onStateChanged:Fire(pausado, tiempoSim)
end

function SimClock.estaPausado(): boolean
    return pausado
end

function SimClock.obtenerTiempo(): number
    return tiempoSim
end

return SimClock
