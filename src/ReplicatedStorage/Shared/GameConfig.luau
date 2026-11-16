--!strict
--[[
    GameConfig.luau
    Ubicación: ReplicatedStorage.Shared.GameConfig
    Propósito:
    Centraliza todas las constantes globales de reglas de juego, duración,
    energía, drenaje por puertas, penalizaciones de A* y escalado por hora.
    Solo contiene datos declarativos (sin funciones).
]]

local GameConfig = {
    DURACION_NOCHE = 140,
    INTERVALO_HORA = 20,
    ENERGIA_INICIAL = 100,
    TASA_DRENAJE_INICIAL = 1,

    -- Cada cuántos segundos de SimClock se drena energía según puertas cerradas
    INTERVALO_DRENAJE_POR_PUERTAS = {
        [0] = 5,
        [1] = 2,
        [2] = 1,
    },

    -- Pesos heurísticos de SpaceTimeAStar
    PENALIZACION_PUERTA_CERRADA_ASTAR = 50,
    BONO_SENUELO_ASTAR = 0.2,

    -- Evento guionizado de bifurcación y señuelo de Guardia_Beta
    EVENTO_GUARDIA_BETA = {
        segundo = 40,
        lineaOrigen = "L0",
        tiempoSalto = 15,
        objeto = "SenueloSonoro",
        sala = "Comedor",
        bonoEnergia = 15,
        motivo = "Salto táctico de Guardia_Beta al pasado",
    },

    -- Incremento de enojo por cada marca horaria (segundos transcurridos)
    ESCALADO_ENOJO = {
        [20] = { Bonnie = 1 },
        [40] = { Bonnie = 1, Chica = 1 },
        [60] = { Bonnie = 1, Chica = 1, Foxy = 1 },
        [80] = { Bonnie = 2 },
        [100] = { Bonnie = 2, Chica = 2 },
        [120] = { Bonnie = 2, Chica = 2, Foxy = 2 },
    },
}

return GameConfig
