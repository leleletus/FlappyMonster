-- Basalto: roca volcánica oscura (isla volcánica). Como la piedra: bloque sólido de terreno cuyo dibujo
-- cubre 2x2 casillas y se repite: assets/images/world/tiles/basalt.png (tools/art/world/make_biome_art.py). Se une con
-- 'ground'. Mismo comportamiento que la piedra: solo cambia el aspecto.
local TileTypes = require 'src/world/tiles/TileTypes'

local TEX = { image = 'assets/images/world/tiles/basalt.png', span = 2 }

return {
    id = 38, name = 'basalt', label = 'Basalto', category = 'Terreno',
    collision = 'solid', material = 'basalt', joinGroup = 'ground',
    editorColor = { 0.36, 0.16, 0.15 },
    texture = TEX,
    draw = function(t, ctx)
        TileTypes.drawTexture(TEX, ctx)
        love.graphics.setColor(0.5, 0.26, 0.22, 1)          -- (el filo, del tono claro de la roca: antes gris)
        TileTypes.drawEdges(ctx, TileTypes.edges(t, ctx), 2)
    end,
}
