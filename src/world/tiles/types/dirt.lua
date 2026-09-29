-- Tierra: bloque sólido marrón con alguna piedrecita. Se une con 'ground'.
local TileTypes = require 'src/world/tiles/TileTypes'

-- Piedrecitas (en píxeles de 16 del tile, fijas por celda)
local PEBBLES = { { 3, 5 }, { 10, 3 }, { 6, 11 }, { 12, 12 }, { 2, 13 }, { 13, 7 } }

return {
    id = 16, name = 'dirt', label = 'Tierra', category = 'Terreno',
    collision = 'solid', material = 'dirt', joinGroup = 'ground',
    editorColor = { 0.47, 0.32, 0.19 },
    draw = function(t, ctx)
        local x, y, s = ctx.x, ctx.y, ctx.size
        local p = math.max(2, math.floor(s / 16))           -- un píxel del arte
        love.graphics.setColor(0.47, 0.32, 0.19, 1)
        love.graphics.rectangle('fill', x, y, s, s)
        local h = ((ctx.col or 1) * 7 + (ctx.row or 1) * 13) % #PEBBLES
        love.graphics.setColor(0.36, 0.24, 0.14, 1)
        for i = 1, 3 do
            local pb = PEBBLES[(h + i * 2) % #PEBBLES + 1]
            love.graphics.rectangle('fill', x + math.floor(pb[1] * s / 16), y + math.floor(pb[2] * s / 16), p, p)
        end
        love.graphics.setColor(0.62, 0.45, 0.28, 1)
        TileTypes.drawEdges(ctx, TileTypes.edges(t, ctx), 2)
    end,
}
