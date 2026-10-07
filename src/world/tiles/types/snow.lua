-- Nieve: bloque sólido de terreno (se une con 'ground' como la tierra y el
-- césped). Textura: assets/images/world/tiles/snow.png (arte 16x16 x4; ver
-- tools/ui/make_snow_sprites.py; el original del usuario, snow-orig.png).
local TileTypes = require 'src/world/tiles/TileTypes'

local TEX = { image = 'assets/images/world/tiles/snow.png' }

return {
    id = 29, name = 'snow', label = 'Nieve', category = 'Terreno',
    collision = 'solid', material = 'snow', joinGroup = 'ground',
    editorColor = { 0.86, 0.91, 1 },
    texture = TEX,
    draw = function(t, ctx)
        TileTypes.drawTexture(TEX, ctx)
        love.graphics.setColor(1, 1, 1, 1)
        TileTypes.drawEdges(ctx, TileTypes.edges(t, ctx), 2)
    end,
}
