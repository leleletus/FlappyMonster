-- Borde del nivel: sólido, material distinto (tierra). Se une con 'ground'.
local TileTypes = require 'src/world/tiles/TileTypes'

return {
    id = 4, name = 'border', label = 'Borde', category = 'Terreno',
    collision = 'solid', material = 'stone', joinGroup = 'ground',
    editorColor = { 0.42, 0.30, 0.10 },
    draw = function(t, ctx)
        local x, y, s = ctx.x, ctx.y, ctx.size
        love.graphics.setColor(0.42, 0.30, 0.10, 1)
        love.graphics.rectangle('fill', x, y, s, s)
        local e = TileTypes.edges(t, ctx)
        love.graphics.setColor(0.62, 0.48, 0.20, 1)
        TileTypes.drawEdges(ctx, e, 2)
        -- Detalle interior solo en tiles aislados (todas las caras expuestas)
        if e.top and e.bottom and e.left and e.right then
            love.graphics.setColor(0.28, 0.18, 0.04, 0.35)
            love.graphics.line(x+s/2, y+2, x+s/2, y+s-2)
            love.graphics.line(x+2, y+s/2, x+s-2, y+s/2)
        end
    end,
}
