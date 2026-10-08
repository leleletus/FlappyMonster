-- src/player/DeadEyes.lua
-- Ojos en X (assets/images/player/dedais.png) sobre la cara vacía del sprite
-- de muerte del monstruito (monstrito4.png). Cada píxel de la X mide medio
-- píxel del sprite, como en el juego original.

local DeadEyes = {}
local img

-- Centro de cada ojo relativo al centro del sprite, en píxeles del sprite
-- (el sprite mide 9x16; la cara blanca ocupa x 2..7, y 4..7)
local EYE_DX, EYE_DY = 1.2, -2.5

-- Dos X en posiciones concretas. mx, my: punto medio entre los ojos en
-- pantalla; sep: distancia de cada ojo a ese punto, en píxeles del sprite;
-- s: escala del sprite. Sirve para cualquier personaje (cada uno sabe dónde
-- tiene los ojos, p. ej. el Monstruo Malvado de la Nave Malvada).
function DeadEyes.drawPair(mx, my, sep, s, r, g, b, a)
    img = require('src/player/PlayerSprite').rec('dead_eyes')
    if not img then return end
    local cell = math.max(1, math.floor(s / 2 + 0.5))      -- píxel de la X en pantalla
    local iw, ih = img.w, img.h
    love.graphics.setColor(r or 1, g or 1, b or 1, a or 1)
    for _, side in ipairs({ -1, 1 }) do
        local cx = math.floor(mx + side * sep * s + 0.5)
        local cy = math.floor(my + 0.5)
        require('src/player/PlayerSprite').draw(img, cx - math.floor(iw * cell / 2), cy - math.floor(ih * cell / 2), 0, cell, cell)
    end
end

-- Ojos del monstruito (sprite del jugador 9x16). x, y: centro del sprite en
-- pantalla; s: escala con la que se dibujó; facing: 1 / -1.
function DeadEyes.draw(x, y, s, facing, r, g, b, a)
    DeadEyes.drawPair(x, y + EYE_DY * s, EYE_DX, s, r, g, b, a)
end

return DeadEyes
