-- Carámbano: decoración (no choca ni hace daño) que cuelga del techo de su
-- casilla. Imagen del usuario: assets/images/tiles/icespike.png (16x16, x4).
local SCALE = 4

local img

return {
    name = 'icicle', label = 'Carámbano', placement = 'cell', category = 'Hielo y nieve',
    editor = { icon = 'assets/images/tiles/icespike.png' },
    loadAssets = function()
        if img == nil then
            local ok, i = pcall(love.graphics.newImage, 'assets/images/tiles/icespike.png')
            img = ok and i or false
            if img then img:setFilter('nearest', 'nearest') end
        end
    end,
    -- (sx, sy) = centro-abajo de la casilla: se dibuja colgando desde su borde de arriba
    draw = function(d, sx, sy)
        if not img then return end
        love.graphics.setColor(1, 1, 1, 0.92)
        love.graphics.draw(img, math.floor(sx), math.floor(sy - TILE_PX), 0, SCALE * d.flip, SCALE, img:getWidth() / 2, 0)
        love.graphics.setColor(1, 1, 1, 1)
    end,
}
