-- Bloque sólido de piedra. Se une visualmente con otros bloques del grupo 'ground'.
local TileTypes = require 'src/world/tiles/TileTypes'

return {
    id = 1, name = 'solid', label = 'Bloque', category = 'Terreno',
    collision = 'solid', material = 'stone', joinGroup = 'ground',
    editorColor = { 0.28, 0.28, 0.32 },
    draw = function(t, ctx)
        love.graphics.setColor(0.28, 0.28, 0.32, 1)
        love.graphics.rectangle('fill', ctx.x, ctx.y, ctx.size, ctx.size)
        love.graphics.setColor(0.46, 0.46, 0.52, 1)
        TileTypes.drawEdges(ctx, TileTypes.edges(t, ctx), 2)
    end,
}
