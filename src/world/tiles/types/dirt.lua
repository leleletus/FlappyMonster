-- Tierra: bloque sólido de terreno. Textura assets/images/world/tiles/dirt.png
-- (tools/ui/make_terrain.py); bordes claros solo en las caras al aire.
local TileTypes = require 'src/world/tiles/TileTypes'

local TEX = { image = 'assets/images/world/tiles/dirt.png' }

return {
    id = 16, name = 'dirt', label = 'Tierra', category = 'Terreno',
    collision = 'solid', material = 'dirt', joinGroup = 'ground',
    editorColor = { 0.47, 0.32, 0.19 },
    texture = TEX,
    draw = function(t, ctx)
        TileTypes.drawTexture(TEX, ctx)
        love.graphics.setColor(0.62, 0.45, 0.28, 1)
        TileTypes.drawEdges(ctx, TileTypes.edges(t, ctx), 2)
    end,
}
