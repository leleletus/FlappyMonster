-- src/ui/PixelIcons.lua
-- Iconos pixel art dibujados por código (sin archivos de imagen).
-- Cada icono es una matriz de caracteres; cada carácter es un color.

local PixelIcons = {}

-- Corona del host de la sala (11x9)
local CROWN = {
    "....o......",
    "...oYo.....",
    "o...o...o..",
    "Yo.oYo.oYo.",
    "YYoYYYoYYo.",
    "YYYYYYYYYo.",
    "YRYYBYYRYo.",
    "YYYYYYYYYo.",
    "ooooooooo..",
}
local CROWN_COLORS = {
    Y = { 1.00, 0.80, 0.18 },   -- oro
    o = { 0.62, 0.40, 0.05 },   -- sombra / contorno
    R = { 0.90, 0.15, 0.20 },   -- rubí
    B = { 0.25, 0.55, 1.00 },   -- zafiro
}

local function drawMatrix(m, colors, x, y, px, alpha)
    for r, row in ipairs(m) do
        for c = 1, #row do
            local col = colors[row:sub(c, c)]
            if col then
                love.graphics.setColor(col[1], col[2], col[3], alpha or 1)
                love.graphics.rectangle('fill', x + (c - 1) * px, y + (r - 1) * px, px, px)
            end
        end
    end
end

-- Otros iconos (modos de juego, resultados)
local ICONS = {
    crown = { m = CROWN, colors = CROWN_COLORS },
    flag = {   -- bandera a cuadros (Carrera)
        m = {
            "PKWKWKWKW",
            "PWKWKWKWK",
            "PKWKWKWKW",
            "PWKWKWKWK",
            "P........",
            "P........",
            "P........",
            "P........",
            "p........",
        },
        colors = { P = {0.75,0.75,0.8}, p = {0.45,0.45,0.5}, K = {0.1,0.1,0.12}, W = {1,1,1} },
    },
    skull = {  -- calavera (Cazamonstruos)
        m = {
            "..WWWWW..",
            ".WWWWWWW.",
            "WWWWWWWWW",
            "WKKWWWKKW",
            "WKKWWWKKW",
            "WWWWKWWWW",
            ".WWWWWWW.",
            "..WKWKW..",
            "..sssss..",
        },
        colors = { W = {0.95,0.93,0.86}, K = {0.12,0.08,0.1}, s = {0.7,0.66,0.6} },
    },
}

PixelIcons.CROWN_W, PixelIcons.CROWN_H = #CROWN[1], #CROWN

-- Tamaño (en píxeles del icono) de un icono por nombre.
function PixelIcons.size(name)
    local ic = ICONS[name]
    if not ic then return 0, 0 end
    return #ic.m[1], #ic.m
end

-- Dibuja el icono `name` con su esquina superior izquierda en (x, y); px =
-- tamaño de cada píxel del icono. Lleva sombra para leerse sobre cualquier fondo.
function PixelIcons.draw(name, x, y, px, alpha)
    local ic = ICONS[name]
    if not ic then return end
    px = px or 2
    x, y = math.floor(x), math.floor(y)
    for r, row in ipairs(ic.m) do
        for c = 1, #row do
            if row:sub(c, c) ~= '.' then
                love.graphics.setColor(0, 0, 0, 0.45 * (alpha or 1))
                love.graphics.rectangle('fill', x + c * px, y + r * px, px, px)
            end
        end
    end
    drawMatrix(ic.m, ic.colors, x, y, px, alpha)
    love.graphics.setColor(1, 1, 1, 1)
end

function PixelIcons.crown(x, y, px, alpha)
    PixelIcons.draw('crown', x, y, px, alpha)
end

return PixelIcons
