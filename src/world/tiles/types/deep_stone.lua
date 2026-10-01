-- Roca abisal: bloque sólido de terreno, rojo oscuro, para las zonas hondas bajo
-- el agua. Como la piedra, su dibujo cubre 2x2 casillas y se repite (las grietas
-- siguen de un bloque al de al lado): assets/images/tiles/deep_stone.png
-- (tools/ui/make_world_art.py). Se une con 'ground'.
local TileTypes = require 'src/world/tiles/TileTypes'

local TEX = { image = 'assets/images/tiles/deep_stone.png', span = 2 }

return {
    id = 36, name = 'deep_stone', label = 'Roca abisal', category = 'Terreno',
    collision = 'solid', material = 'deep_stone', joinGroup = 'ground',
    editorColor = { 0.35, 0.16, 0.2 },
    texture = TEX,
    draw = function(t, ctx)
        TileTypes.drawTexture(TEX, ctx)
        love.graphics.setColor(0.52, 0.27, 0.3, 1)
        TileTypes.drawEdges(ctx, TileTypes.edges(t, ctx), 2)
    end,
}
