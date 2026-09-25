-- Plataforma TRASPASABLE: se atraviesa subiendo y se baja manteniendo
-- agachado. Pasarela de madera delgada con tablones y flechas hacia abajo.
return {
    id = 10, name = 'platform_drop', label = 'Plataforma traspasable', category = 'Plataformas',
    collision = 'oneway', dropThrough = true, material = 'wood',
    editorColor = { 0.86, 0.52, 0.12 },
    draw = function(t, ctx)
        local x, y, s = ctx.x, ctx.y, ctx.size
        local visH  = math.floor(s * 0.36)
        local plank = s / 4
        for i = 0, 3 do                                       -- tablones con rendija
            local shade = (i % 2 == 0) and 0 or 0.07
            love.graphics.setColor(0.86 + shade, 0.52 + shade, 0.12, 1)
            love.graphics.rectangle('fill', x + i*plank, y, plank - 2, visH)
        end
        love.graphics.setColor(1.00, 0.86, 0.45, 1)          -- canto superior
        love.graphics.rectangle('fill', x, y, s, 3)
        love.graphics.setColor(0.45, 0.24, 0.05, 1)          -- sombra inferior
        love.graphics.rectangle('fill', x, y+visH-3, s, 3)
        love.graphics.setColor(1.00, 0.80, 0.30, 0.85)       -- flechas "se puede bajar"
        local ay = y + visH + 6
        for _, cx in ipairs({ x + s*0.25, x + s*0.75 }) do
            love.graphics.polygon('fill', cx-8, ay, cx+8, ay, cx, ay+8)
        end
    end,
}
