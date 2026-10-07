-- Meta: bandera de cuadros. No colisiona; al tocarla se dispara el trigger
-- 'finish' (lo usa el modo Carrera Relámpago, ver src/world/modes/race.lua).
local COLS = 4           -- columnas que ondean por separado (las del ajedrez)
local img, quads = nil, {}

return {
    id = 11, name = 'finish', label = 'Meta', category = 'Objetivos',
    collision = 'none', trigger = 'finish',
    editorColor = { 0.95, 0.95, 0.95 },
    draw = function(t, ctx)
        -- Ajedrez (assets/images/world/tiles/finish.png) que ondea: cada columna de
        -- cuadros sube/baja un poco. El marco dorado no ondea.
        if not img then
            img = love.graphics.newImage('assets/images/world/tiles/finish.png')
            img:setFilter('nearest', 'nearest')
        end
        local x, y, s = ctx.x, ctx.y, ctx.size
        local iw, ih = img:getDimensions()
        local k  = s / iw
        local tm = ctx.time or 0
        local col0 = ctx.col or 0
        love.graphics.setColor(1, 1, 1, 1)
        for i = 0, COLS - 1 do
            local off = math.floor(math.sin(tm * 3 + (col0 * COLS + i) * 0.7) * 2)
            quads[i] = quads[i] or love.graphics.newQuad(i * iw / COLS, 0, iw / COLS, ih, iw, ih)
            love.graphics.draw(img, quads[i], x + i * s / COLS, y + off, 0, k, k)
        end
        love.graphics.setColor(1, 0.80, 0.20, 0.95)
        love.graphics.rectangle('line', x + 1, y + 1, s - 2, s - 2)
    end,
}
