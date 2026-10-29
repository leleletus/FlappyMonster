-- Arena: bloque sólido de terreno (se une con 'ground'). Textura
-- assets/images/world/tiles/sand.png. Donde toca tierra, césped o piedra (bloque grande o
-- mini bloque, también siendo ella un mini bloque) no cambia de golpe: dibuja por
-- ese lado una franja tramada con los colores del vecino
-- (assets/images/world/tiles/sand_blend.png: cuadro 1 tierra —también bajo el césped—,
-- 2 piedra, 3 roca abisal, 4 borde; la franja está a la izquierda y se gira para
-- cada lado). sand.png: tools/art/world/make_terrain.py; sand_blend.png: make_world_art.py.
local TileTypes = require 'src/world/tiles/TileTypes'

local TEX = { image = 'assets/images/world/tiles/sand.png' }
-- (las franjas: TileTypes.drawBlend, la misma regla para todos los bloques que se funden con sus vecinos)
local BLEND = { image = 'assets/images/world/tiles/sand_blend.png',
                of = { dirt = 1, grass = 1, solid = 2, deep_stone = 3, border = 4, basalt = 4, ash = 4, mud = 1, jungle_grass = 1,
                       temple_brick = 2 } }

return {
    id = 35, name = 'sand', label = 'Arena', category = 'Terreno',
    collision = 'solid', material = 'sand', joinGroup = 'ground',
    editorColor = { 0.86, 0.74, 0.49 },
    texture = TEX,
    draw = function(t, ctx)
        TileTypes.drawTexture(TEX, ctx)
        -- Transiciones hacia los bloques vecinos, por medias casillas (así también
        -- hacia mini bloques, y en los mini bloques de arena)
        TileTypes.drawBlend(BLEND, ctx)
        love.graphics.setColor(0.95, 0.86, 0.64, 1)
        TileTypes.drawEdges(ctx, TileTypes.edges(t, ctx), 2)
    end,
}
