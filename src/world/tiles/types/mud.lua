-- Barro (isla de la jungla, 0.5.83): bloque sólido de terreno, como la tierra pero oscuro y húmedo. Textura
-- assets/images/world/tiles/mud.png (tools/art/world/make_jungle_sky.py). Se une con 'ground'.
local TileTypes = require 'src/world/tiles/TileTypes'

local TEX = { image = 'assets/images/world/tiles/mud.png' }

return {
    id = 40, name = 'mud', label = 'Barro', category = 'Terreno',
    collision = 'solid', material = 'mud', joinGroup = 'ground',
    editorColor = { 0.35, 0.23, 0.13 },
    texture = TEX,
    draw = function(t, ctx)
        TileTypes.drawTexture(TEX, ctx)
        love.graphics.setColor(0.62, 0.45, 0.28, 1)
        TileTypes.drawEdges(ctx, TileTypes.edges(t, ctx), 2)
    end,
}
