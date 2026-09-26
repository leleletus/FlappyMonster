-- src/entities/DeadEyes.lua
-- Ojos en X (assets/images/player/dedais.png) sobre la cara vacía del sprite
-- de muerte del monstruito (monstrito4.png). Cada píxel de la X mide medio
-- píxel del sprite, como en el juego original.

local DeadEyes = {}
local img

-- Centro de cada ojo relativo al centro del sprite, en píxeles del sprite
-- (el sprite mide 9x16; la cara blanca ocupa x 2..7, y 4..7)
local EYE_DX, EYE_DY = 1.2, -2.5

-- x, y: centro del sprite en pantalla; s: escala con la que se dibujó el
-- sprite; facing: 1 / -1.
function DeadEyes.draw(x, y, s, facing, r, g, b, a)
    if not img then
        local ok, im = pcall(love.graphics.newImage, 'assets/images/player/dedais.png')
        img = ok and im or false
        if img then img:setFilter('nearest', 'nearest') end
    end
    if not img then return end
    local cell = math.max(1, math.floor(s / 2 + 0.5))      -- píxel de la X en pantalla
    local iw, ih = img:getDimensions()
    love.graphics.setColor(r or 1, g or 1, b or 1, a or 1)
    for _, side in ipairs({ -1, 1 }) do
        local cx = math.floor(x + side * EYE_DX * s * (facing or 1) + 0.5)
        local cy = math.floor(y + EYE_DY * s + 0.5)
        love.graphics.draw(img, cx - math.floor(iw * cell / 2), cy - math.floor(ih * cell / 2), 0, cell, cell)
    end
end

return DeadEyes
