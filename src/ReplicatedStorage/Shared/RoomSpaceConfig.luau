--!strict
--[[
    RoomSpaceConfig.luau
    Ubicación: ReplicatedStorage.Shared.RoomSpaceConfig
    Propósito:
    Define el mapa aéreo 2D (grilla maestra de 30x17 bloques) y los parámetros
    espaciales configurables de cada habitación (dimensiones en metros, escala
    a studs de Roblox, obstáculos/muebles, puertas y pathfinding simple tipo Pac-Man).
]]

export type TileTipo = "VOID" | "WALL" | "FLOOR" | "PROP" | "DOOR"

export type PuertaInfo = {
    salaA: string,
    salaB: string,
    ladoSeguridad: ("Izquierda" | "Derecha")?,
}

export type CeldaMapa = {
    x: number,
    y: number,
    tipo: TileTipo,
    sala: string?,
    propTipo: string?,
    puerta: PuertaInfo?,
}

export type RoomConfig = {
    id: string,
    nombreVisible: string,
    anchoMetros: number,
    altoMetros: number,
    rect: { x1: number, y1: number, x2: number, y2: number },
    colorPiso: Color3,
    colorPisoAlt: Color3?,
    spawn: { x: number, y: number },
    labelPos: { x: number, y: number },
    tieneCamara: boolean?,
}

local GridPathfinder = require(script.Parent:WaitForChild("GridPathfinder"))

local RoomSpaceConfig = {}

RoomSpaceConfig.GRID_COLS = 30
RoomSpaceConfig.GRID_ROWS = 17
RoomSpaceConfig.STUDS_POR_METRO = 3.57 -- Escala estándar de Roblox (1 metro ≈ 3.57 studs)
RoomSpaceConfig.METROS_POR_BLOQUE_DEFECTO = 2.5

-- Definición de las 9 habitaciones con dimensiones físicas configurables (en metros)
-- y su área rectangular de piso transitable en la grilla aérea 30x17.
RoomSpaceConfig.SALAS = {
    Backstage = {
        id = "Backstage",
        nombreVisible = "BACKSTAGE",
        anchoMetros = 15,
        altoMetros = 10,
        rect = { x1 = 3, y1 = 2, x2 = 7, y2 = 5 },
        colorPiso = Color3.fromRGB(96, 124, 108),
        spawn = { x = 5, y = 4 },
        labelPos = { x = 5, y = 3 },
        tieneCamara = true,
    },
    Escenario = {
        id = "Escenario",
        nombreVisible = "ESCENARIO",
        anchoMetros = 15,
        altoMetros = 10,
        rect = { x1 = 9, y1 = 2, x2 = 14, y2 = 5 },
        colorPiso = Color3.fromRGB(108, 134, 114),
        spawn = { x = 11, y = 4 },
        labelPos = { x = 11.5, y = 3.5 },
        tieneCamara = true,
    },
    Comedor = {
        id = "Comedor",
        nombreVisible = "COMEDOR",
        anchoMetros = 20,
        altoMetros = 22,
        rect = { x1 = 16, y1 = 2, x2 = 23, y2 = 10 },
        colorPiso = Color3.fromRGB(224, 216, 182),
        colorPisoAlt = Color3.fromRGB(112, 138, 116),
        spawn = { x = 19, y = 6 },
        labelPos = { x = 19.5, y = 6 },
        tieneCamara = true,
    },
    CuevaPirata = {
        id = "CuevaPirata",
        nombreVisible = "CUEVA PIRATA",
        anchoMetros = 12.5,
        altoMetros = 10,
        rect = { x1 = 3, y1 = 7, x2 = 7, y2 = 10 },
        colorPiso = Color3.fromRGB(98, 128, 112),
        spawn = { x = 5, y = 9 },
        labelPos = { x = 5, y = 8.5 },
        tieneCamara = true,
    },
    FuenteEnergia = {
        id = "FuenteEnergia",
        nombreVisible = "FUENTE DE ENERGÍA",
        anchoMetros = 10,
        altoMetros = 10,
        rect = { x1 = 2, y1 = 12, x2 = 5, y2 = 15 },
        colorPiso = Color3.fromRGB(94, 122, 102),
        spawn = { x = 4, y = 14 },
        labelPos = { x = 3.5, y = 13.5 },
        tieneCamara = false,
    },
    PasilloIzquierdo = {
        id = "PasilloIzquierdo",
        nombreVisible = "PASILLO IZQUIERDO",
        anchoMetros = 15,
        altoMetros = 22,
        rect = { x1 = 9, y1 = 7, x2 = 14, y2 = 11 }, -- Hub superior; brazo inferior se agrega abajo
        colorPiso = Color3.fromRGB(108, 128, 144),
        spawn = { x = 11, y = 9 },
        labelPos = { x = 9.5, y = 14 },
        tieneCamara = true,
    },
    PasilloDerecho = {
        id = "PasilloDerecho",
        nombreVisible = "PASILLO DER.",
        anchoMetros = 12.5,
        altoMetros = 7.5,
        rect = { x1 = 19, y1 = 12, x2 = 23, y2 = 14 },
        colorPiso = Color3.fromRGB(108, 128, 144),
        spawn = { x = 21, y = 13 },
        labelPos = { x = 21, y = 13 },
        tieneCamara = true,
    },
    Oficina = {
        id = "Oficina",
        nombreVisible = "OFICINA",
        anchoMetros = 12.5,
        altoMetros = 10,
        rect = { x1 = 13, y1 = 13, x2 = 17, y2 = 16 },
        colorPiso = Color3.fromRGB(106, 134, 114),
        spawn = { x = 15, y = 14 },
        labelPos = { x = 15, y = 14 },
        tieneCamara = false,
    },
    Banos = {
        id = "Banos",
        nombreVisible = "BAÑOS",
        anchoMetros = 12.5,
        altoMetros = 22.5,
        rect = { x1 = 25, y1 = 6, x2 = 29, y2 = 14 },
        colorPiso = Color3.fromRGB(106, 132, 114),
        colorPisoAlt = Color3.fromRGB(224, 216, 182),
        spawn = { x = 26, y = 10 },
        labelPos = { x = 27, y = 9 },
        tieneCamara = true,
    },
} :: { [string]: RoomConfig }

-- Rectángulos adicionales para habitaciones en forma de L (PasilloIzquierdo)
local RECTANGULOS_EXTRA: { { sala: string, x1: number, y1: number, x2: number, y2: number } } = {
    { sala = "PasilloIzquierdo", x1 = 9, y1 = 12, x2 = 11, y2 = 12 },
    { sala = "PasilloIzquierdo", x1 = 7, y1 = 13, x2 = 11, y2 = 15 },
}

-- Puertas que conectan habitaciones (aristas del grafo)
RoomSpaceConfig.PUERTAS = {
    { x = 8,  y = 4,  salaA = "Backstage",        salaB = "Escenario" },
    { x = 11, y = 6,  salaA = "Escenario",        salaB = "PasilloIzquierdo" },
    { x = 8,  y = 9,  salaA = "CuevaPirata",      salaB = "PasilloIzquierdo" },
    { x = 6,  y = 14, salaA = "FuenteEnergia",    salaB = "PasilloIzquierdo" },
    { x = 15, y = 9,  salaA = "Comedor",          salaB = "PasilloIzquierdo" },
    { x = 20, y = 11, salaA = "Comedor",          salaB = "PasilloDerecho" },
    { x = 24, y = 7,  salaA = "Comedor",          salaB = "Banos" },
    { x = 24, y = 13, salaA = "Banos",            salaB = "PasilloDerecho" },
    { x = 12, y = 14, salaA = "PasilloIzquierdo", salaB = "Oficina", ladoSeguridad = "Izquierda" },
    { x = 18, y = 14, salaA = "PasilloDerecho",   salaB = "Oficina", ladoSeguridad = "Derecha" },
} :: { { x: number, y: number, salaA: string, salaB: string, ladoSeguridad: ("Izquierda" | "Derecha")? } }

-- Obstáculos / muebles internos (estilo Pac-Man: rodeables con espacio de 2+ bloques)
local PROPS_INTERNOS: { { x: number, y: number, propTipo: string } } = {
    -- Escenario (tarima)
    { x = 11, y = 2, propTipo = "Stage" },
    { x = 12, y = 2, propTipo = "Stage" },
    -- Backstage (estantes)
    { x = 3, y = 2, propTipo = "Shelf" },
    { x = 4, y = 2, propTipo = "Shelf" },
    -- Comedor (mesas centrales rodeables)
    { x = 18, y = 4, propTipo = "Table" },
    { x = 21, y = 4, propTipo = "Table" },
    { x = 18, y = 8, propTipo = "Table" },
    { x = 21, y = 8, propTipo = "Table" },
    -- Cueva Pirata (tarima pequeña)
    { x = 4, y = 7, propTipo = "Stage" },
    { x = 5, y = 7, propTipo = "Stage" },
    -- Fuente de Energía (generadores)
    { x = 2, y = 12, propTipo = "Generator" },
    { x = 2, y = 13, propTipo = "Generator" },
    -- Oficina (escritorio central rodeable)
    { x = 15, y = 15, propTipo = "Desk" },
    -- Baños (división parcial dejando pasillo)
    { x = 27, y = 10, propTipo = "WallProp" },
    { x = 28, y = 10, propTipo = "WallProp" },
}

-- Construcción de la grilla maestra
local grilla: { { CeldaMapa } } = {}

local function construirGrilla()
    for y = 1, RoomSpaceConfig.GRID_ROWS do
        grilla[y] = {}
        for x = 1, RoomSpaceConfig.GRID_COLS do
            grilla[y][x] = {
                x = x,
                y = y,
                tipo = "VOID",
                sala = nil,
                propTipo = nil,
                puerta = nil,
            }
        end
    end

    local function rellenarSala(salaId: string, x1: number, y1: number, x2: number, y2: number)
        for y = y1, y2 do
            for x = x1, x2 do
                if grilla[y] and grilla[y][x] then
                    grilla[y][x].tipo = "FLOOR"
                    grilla[y][x].sala = salaId
                end
            end
        end
    end

    for salaId, cfg in pairs(RoomSpaceConfig.SALAS) do
        rellenarSala(salaId, cfg.rect.x1, cfg.rect.y1, cfg.rect.x2, cfg.rect.y2)
    end
    for _, extra in ipairs(RECTANGULOS_EXTRA) do
        rellenarSala(extra.sala, extra.x1, extra.y1, extra.x2, extra.y2)
    end

    -- Colocar muros alrededor de cualquier celda FLOOR que toque VOID
    for y = 1, RoomSpaceConfig.GRID_ROWS do
        for x = 1, RoomSpaceConfig.GRID_COLS do
            if grilla[y][x].tipo == "VOID" then
                local tocaPiso = false
                for dy = -1, 1 do
                    for dx = -1, 1 do
                        local ny, nx = y + dy, x + dx
                        if grilla[ny] and grilla[ny][nx] and grilla[ny][nx].tipo == "FLOOR" then
                            tocaPiso = true
                            break
                        end
                    end
                    if tocaPiso then break end
                end
                if tocaPiso then
                    grilla[y][x].tipo = "WALL"
                end
            end
        end
    end

    -- Colocar muros separadores entre salas distintas adyacentes y abrir puertas
    for _, p in ipairs(RoomSpaceConfig.PUERTAS) do
        if grilla[p.y] and grilla[p.y][p.x] then
            grilla[p.y][p.x].tipo = "DOOR"
            grilla[p.y][p.x].sala = p.salaA
            grilla[p.y][p.x].puerta = {
                salaA = p.salaA,
                salaB = p.salaB,
                ladoSeguridad = p.ladoSeguridad,
            }
        end
    end

    -- Colocar muebles/obstáculos internos
    for _, prop in ipairs(PROPS_INTERNOS) do
        if grilla[prop.y] and grilla[prop.y][prop.x] and grilla[prop.y][prop.x].tipo == "FLOOR" then
            grilla[prop.y][prop.x].tipo = "PROP"
            grilla[prop.y][prop.x].propTipo = prop.propTipo
        end
    end
end

construirGrilla()

function RoomSpaceConfig.obtenerCelda(x: number, y: number): CeldaMapa?
    if y < 1 or y > RoomSpaceConfig.GRID_ROWS or x < 1 or x > RoomSpaceConfig.GRID_COLS then
        return nil
    end
    return grilla[y][x]
end

function RoomSpaceConfig.celdaEsTransitable(x: number, y: number, estadoEscenario: any?): boolean
    local celda = RoomSpaceConfig.obtenerCelda(x, y)
    if not celda then
        return false
    end
    if celda.tipo == "FLOOR" then
        return true
    end
    if celda.tipo == "DOOR" then
        if celda.puerta and celda.puerta.ladoSeguridad and estadoEscenario then
            if celda.puerta.ladoSeguridad == "Izquierda" and estadoEscenario.puertaIzquierdaCerrada == true then
                return false
            end
            if celda.puerta.ladoSeguridad == "Derecha" and estadoEscenario.puertaDerechaCerrada == true then
                return false
            end
        end
        return true
    end
    return false
end

-- Retorna un punto de spawn seguro dentro de la sala
function RoomSpaceConfig.obtenerSpawnSala(salaId: string): (number, number)
    local cfg = RoomSpaceConfig.SALAS[salaId]
    if cfg then
        return cfg.spawn.x, cfg.spawn.y
    end
    return 15, 14
end

-- Convierte un tamaño en metros de una sala a Studs de Roblox (para futuro 3D)
function RoomSpaceConfig.metrosAStuds(metros: number): number
    return metros * RoomSpaceConfig.STUDS_POR_METRO
end

-- Convierte una celda (gx, gy) a coordenadas normalizadas (u, v) dentro de su sala (0..1)
function RoomSpaceConfig.celdaANormalizadoEnSala(salaId: string, gx: number, gy: number): (number, number)
    local cfg = RoomSpaceConfig.SALAS[salaId]
    if not cfg then
        return 0.5, 0.5
    end
    local ancho = math.max(1, cfg.rect.x2 - cfg.rect.x1)
    local alto = math.max(1, cfg.rect.y2 - cfg.rect.y1)
    local u = math.clamp((gx - cfg.rect.x1) / ancho, 0, 1)
    local v = math.clamp((gy - cfg.rect.y1) / alto, 0, 1)
    return u, v
end

-- Pathfinding A* Manhattan 4-direccional sobre la grilla 30x17 (delegado a GridPathfinder)
function RoomSpaceConfig.encontrarCaminoPacMan(
    origenX: number,
    origenY: number,
    destinoX: number,
    destinoY: number,
    estadoEscenario: any?
): { { x: number, y: number, sala: string? } }
    local rutaBase = GridPathfinder.encontrarCamino(
        origenX,
        origenY,
        destinoX,
        destinoY,
        function(nx: number, ny: number): boolean
            return RoomSpaceConfig.celdaEsTransitable(nx, ny, estadoEscenario)
        end
    )

    local camino: { { x: number, y: number, sala: string? } } = {}
    for _, paso in ipairs(rutaBase) do
        local celda = RoomSpaceConfig.obtenerCelda(paso.x, paso.y)
        table.insert(camino, {
            x = paso.x,
            y = paso.y,
            sala = if celda then celda.sala else nil,
        })
    end

    return camino
end

-- Retorna el portal (puerta) entre dos salas adyacentes si existe
function RoomSpaceConfig.obtenerPuertaEntre(salaA: string, salaB: string): { x: number, y: number, ladoSeguridad: ("Izquierda" | "Derecha")? }?
    for _, p in ipairs(RoomSpaceConfig.PUERTAS) do
        if (p.salaA == salaA and p.salaB == salaB) or (p.salaA == salaB and p.salaB == salaA) then
            return { x = p.x, y = p.y, ladoSeguridad = p.ladoSeguridad }
        end
    end
    return nil
end

return RoomSpaceConfig
