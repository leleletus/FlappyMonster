-- Salida SECRETA: una placa roja con cerradura (assets/images/world/tiles/secret_exit.png, de
-- tools/art/world/make_secret_exit.py). No colisiona; al tocarla se dispara el trigger 'secret_exit': el nivel termina
-- como en la meta y, en la historia, se abre el camino secreto de ese nivel (src/story/Worlds.lua `secrets`, el nodo
-- rojo del mapa). Los modos online no la usan (ModeTypes.hiddenTriggers: no se dibuja ni hace nada). Puede ir con
-- agua (waterlogged), bajo el mar. Va escondida (tras paredes falsas, un pasadizo), pero se ve al llegar: brilla.
local img

return {
    id = 44, name = 'secret_exit', label = 'Salida secreta', category = 'Objetivos',
    collision = 'none', trigger = 'secret_exit',
    editorColor = { 0.85, 0.2, 0.25 },
    draw = function(t, ctx)
        if not img then
            img = require('src/fx/Anim').image('assets/images/world/tiles/secret_exit.png')
            img:setFilter('nearest', 'nearest')
        end
        local x, y, s = ctx.x, ctx.y, ctx.size
        local tm = ctx.time or 0
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, x, y, 0, s / img:getWidth(), s / img:getHeight())
        -- (un latido de luz encima: se ve que es algo)
        local a = 0.18 + 0.14 * math.sin(tm * 3)
        love.graphics.setBlendMode('add')
        love.graphics.setColor(1, 0.85, 0.5, a)
        love.graphics.rectangle('fill', x + s / 8, y + s / 8, s * 3 / 4, s * 3 / 4)
        love.graphics.setBlendMode('alpha')
        love.graphics.setColor(1, 1, 1, 1)
    end,
}
