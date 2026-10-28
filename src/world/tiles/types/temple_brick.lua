-- Sillar del templo (isla de la jungla, 0.5.83): piedra gris verdosa en sillares grandes con tallas; su dibujo cubre
-- 4x4 casillas (así las tallas no se repiten cada dos bloques) y, con la cara de arriba al aire, lleva una capa de
-- MUSGO encima. Texturas (tools/art/world/make_jungle_sky.py): temple_brick.png y temple_moss.png. Se une con 'ground'.
local TileTypes = require 'src/world/tiles/TileTypes'

local TEX  = { image = 'assets/images/world/tiles/temple_brick.png', span = 4 }
local MOSS = { image = 'assets/images/world/tiles/temple_moss.png' }

return {
    id = 42, name = 'temple_brick', label = 'Sillar del templo', category = 'Terreno',
    collision = 'solid', material = 'temple_stone', joinGroup = 'ground',
    editorColor = { 0.37, 0.43, 0.35 },
    texture = TEX,
    draw = function(t, ctx)
        local x, y, s = ctx.x, ctx.y, ctx.size
        local e = TileTypes.edges(t, ctx)
        TileTypes.drawTexture(TEX, ctx)
        if e.top then TileTypes.drawTexture(MOSS, ctx, 1, 0) end
        love.graphics.setColor(0.54, 0.6, 0.49, 1)
        TileTypes.drawEdges(ctx, e, 2, e.top and true or nil)
        if e.top then
            local cap = math.floor(s * (ctx.quarter and 4 / 8 or 4 / 16))
            love.graphics.setColor(0.53, 0.69, 0.24, 1)
            if TileTypes.half(e.left, 1) then love.graphics.rectangle('fill', x, y, 2, cap) end
            if TileTypes.half(e.right, 1) then love.graphics.rectangle('fill', x + s - 2, y, 2, cap) end
        end
    end,
}
