--!strict
--[[
    AnimatronicConfig.luau
    Ubicación: ReplicatedStorage.Shared.AnimatronicConfig
    Propósito:
    Centraliza todas las constantes de comportamiento, relojes, rutas,
    velocidades y parámetros de IA de los animatrónicos.
    Solo contiene datos declarativos (sin funciones).
]]

local AnimatronicConfig = {
    ENOJO_INICIAL = 1,
    DADO_MAX = 20,
    TIEMPO_ESPERA_PUERTA = 5,

    Bonnie = {
        nombre = "Bonnie",
        intervalo = 3,
        nodoInicial = "Escenario",
        velocidadPaso = 0.32,
        esperaEnPasillo = 5,
        puertaAtaque = "izquierda",
        candidatos = {
            "Backstage",
            "Comedor",
            "PasilloIzquierdo",
        },
    },

    Chica = {
        nombre = "Chica",
        intervalo = 5,
        nodoInicial = "Escenario",
        demoraMovimiento = 2,
        impactoSabotaje = -8,
        puertaAtaque = "derecha",
        ruta = {
            "Escenario",
            "Comedor",
            "Banos",
            "PasilloDerecho",
            "Oficina",
        },
    },

    Foxy = {
        nombre = "Foxy",
        intervalo = 7,
        nodoInicial = "CuevaPirata",
        velocidadSprint = 0.16,
        maxLineasCreadas = 3,
        tiempoMinBifurcacion = 15,
        saltoPasadoSegundos = 12,
        puertaAtaque = "izquierda",
    },
}

return AnimatronicConfig
