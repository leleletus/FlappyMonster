-- Hielo: bloque sólido SEMITRANSPARENTE (se ve lo de detrás). Se une con otros
-- bloques de hielo. Si debajo no hay nada, gotea (src/fx/IceDrips.lua, solo
-- dibujo). Textura: assets/images/tiles/ice.png (original: ice-orig.png).
local TileTypes = require 'src/world/tiles/TileTypes'

local TEX = { image = 'assets/images/tiles/ice.png' }
local ALPHA = 0.78

return {
    id = 30, name = 'ice', label = 'Hielo', category = 'Terreno',
    collision = 'solid', material = 'ice', joinGroup = 'ice', iceDrip = true,
    editorColor = { 0.65, 0.77, 1 },
    texture = TEX,
    draw = function(t, ctx)
        TileTypes.drawTexture(TEX, ctx, ALPHA)
        love.graphics.setColor(0.88, 0.94, 1, 0.9)
        TileTypes.drawEdges(ctx, TileTypes.edges(t, ctx), 2)
    end,
}
