-- Piedra: bloque sólido de terreno. Textura assets/images/world/tiles/stone.png
-- (tools/art/world/make_world_art.py): cubre 2x2 casillas y se repite, así las grietas
-- siguen de un bloque al de al lado; bordes claros solo en las caras al aire.
local TileTypes = require 'src/world/tiles/TileTypes'

local TEX = { image = 'assets/images/world/tiles/stone.png', span = 2 }

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
