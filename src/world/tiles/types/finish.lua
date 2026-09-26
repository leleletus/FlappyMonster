-- Meta: bandera de cuadros. No colisiona; al tocarla se dispara el trigger
-- 'finish' (lo usa el modo Carrera Relámpago, ver src/world/modes/race.lua).
return {
    id = 11, name = 'finish', label = 'Meta', category = 'Objetivos',
    collision = 'none', trigger = 'finish',
    editorColor = { 0.95, 0.95, 0.95 },
    draw = function(t, ctx)
        local x, y, s = ctx.x, ctx.y, ctx.size
        local n  = 4
        local c  = s / n
        local tm = ctx.time or 0
        local col0 = ctx.col or 0
        for i = 0, n - 1 do
            -- Ondea: cada columna de cuadros sube/baja un poco
            local off = math.floor(math.sin(tm * 3 + (col0 * n + i) * 0.7) * 2)
            for j = 0, n - 1 do
                if (i + j) % 2 == 0 then love.graphics.setColor(0.07, 0.07, 0.09, 0.9)
                else love.graphics.setColor(0.97, 0.97, 0.97, 0.9) end
                love.graphics.rectangle('fill', x + i * c, y + j * c + off, c, c)
            end
        end
        love.graphics.setColor(1, 0.80, 0.20, 0.95)
        love.graphics.rectangle('line', x + 1, y + 1, s - 2, s - 2)
    end,
}
