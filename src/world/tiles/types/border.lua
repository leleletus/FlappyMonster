-- Borde: roca durísima y compacta (el marco del nivel). Su dibujo cubre 2x2
-- casillas y se repite sin costura: assets/images/tiles/border.png
-- (tools/ui/make_world_art.py). Se une con 'ground'.
local TileTypes = require 'src/world/tiles/TileTypes'

local TEX = { image = 'assets/images/tiles/border.png', span = 2 }

return {
    id = 4, name = 'border', label = 'Borde', category = 'Terreno',
    collision = 'solid', material = 'stone', joinGroup = 'ground',
    editorColor = { 0.21, 0.2, 0.24 },
    texture = TEX,
    draw = function(t, ctx)
        TileTypes.drawTexture(TEX, ctx)
        love.graphics.setColor(0.42, 0.41, 0.5, 1)
        TileTypes.drawEdges(ctx, TileTypes.edges(t, ctx), 2)
    end,
}
