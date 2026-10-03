-- Ceniza: basalto con una capa de ceniza gris (y alguna brasa) cuando su cara de arriba da al aire; tapado
-- por otro bloque se ve como basalto (como el césped sobre la tierra). Texturas (tools/ui/make_biome_art.py):
-- assets/images/tiles/ash.png y basalt.png. Se une con 'ground'. Se comporta como la tierra.
local TileTypes = require 'src/world/tiles/TileTypes'

local TOP  = { image = 'assets/images/tiles/ash.png' }
local BODY = { image = 'assets/images/tiles/basalt.png', span = 2 }

return {
    id = 39, name = 'ash', label = 'Ceniza', category = 'Terreno',
    collision = 'solid', material = 'ash', joinGroup = 'ground',
    editorColor = { 0.52, 0.5, 0.54 },
    texture = TOP,
    draw = function(t, ctx)
        local x, y, s = ctx.x, ctx.y, ctx.size
        local e = TileTypes.edges(t, ctx)
        TileTypes.drawTexture(e.top and TOP or BODY, ctx, 1, e.top and 0 or nil)
        love.graphics.setColor(0.32, 0.29, 0.36, 1)
        TileTypes.drawEdges(ctx, { left = e.left, right = e.right, bottom = e.bottom }, 2)
        if e.top then
            -- (junto a la capa de ceniza, el borde de los lados es gris claro)
            local cap = math.floor(s * (ctx.quarter and 5 / 8 or 5 / 16))
            love.graphics.setColor(0.72, 0.7, 0.74, 1)
            if TileTypes.half(e.left, 1) then love.graphics.rectangle('fill', x, y, 2, cap) end
            if TileTypes.half(e.right, 1) then love.graphics.rectangle('fill', x + s - 2, y, 2, cap) end
            if TileTypes.half(e.top, 1) then love.graphics.rectangle('fill', x, y, s / 2, 2) end
            if TileTypes.half(e.top, 2) then love.graphics.rectangle('fill', x + s / 2, y, s / 2, 2) end
        end
    end,
}
