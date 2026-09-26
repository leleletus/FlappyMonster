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

PixelIcons.CROWN_W, PixelIcons.CROWN_H = #CROWN[1], #CROWN

-- Dibuja la corona con su esquina superior izquierda en (x, y); px = tamaño
-- de cada píxel del icono.
function PixelIcons.crown(x, y, px, alpha)
    px = px or 2
    -- Sombra desplazada para que se lea sobre cualquier fondo
    for r, row in ipairs(CROWN) do
        for c = 1, #row do
            if row:sub(c, c) ~= '.' then
                love.graphics.setColor(0, 0, 0, 0.45 * (alpha or 1))
                love.graphics.rectangle('fill', math.floor(x) + c * px, math.floor(y) + r * px, px, px)
            end
        end
    end
    drawMatrix(CROWN, CROWN_COLORS, math.floor(x), math.floor(y), px, alpha)
    love.graphics.setColor(1, 1, 1, 1)
end

return PixelIcons
