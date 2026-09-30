-- Piedra: bloque sólido de terreno. Textura assets/images/tiles/stone.png
-- (tools/ui/make_terrain.py); bordes claros solo en las caras al aire.
local TileTypes = require 'src/world/tiles/TileTypes'

local TEX = { image = 'assets/images/tiles/stone.png' }

return {
    id = 1, name = 'solid', label = 'Piedra', category = 'Terreno',
    collision = 'solid', material = 'stone', joinGroup = 'ground',
    editorColor = { 0.28, 0.28, 0.32 },
    texture = TEX,
    draw = function(t, ctx)
        TileTypes.drawTexture(TEX, ctx)
        love.graphics.setColor(0.46, 0.46, 0.52, 1)
        TileTypes.drawEdges(ctx, TileTypes.edges(t, ctx), 2)
    end,
}
