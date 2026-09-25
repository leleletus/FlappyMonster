-- Plataforma NO traspasable: se atraviesa subiendo, pero no se puede bajar
-- agachándose. Losa gris-pizarra gruesa (≈¾ del alto).
return {
    id = 2, name = 'platform', label = 'Plataforma', category = 'Plataformas',
    collision = 'oneway', dropThrough = false, material = 'stone',
    editorColor = { 0.52, 0.52, 0.60 },
    draw = function(t, ctx)
        local x, y, s = ctx.x, ctx.y, ctx.size
        local visH  = math.floor(s * 0.72)
        local surfH = math.max(3, math.floor(s * 0.18))
        love.graphics.setColor(0.30, 0.30, 0.36, 1)          -- cuerpo
        love.graphics.rectangle('fill', x, y, s, visH)
        love.graphics.setColor(0.52, 0.52, 0.60, 1)          -- franja de superficie
        love.graphics.rectangle('fill', x, y, s, surfH)
        love.graphics.setColor(0.78, 0.78, 0.90, 1)          -- canto superior brillante
        love.graphics.rectangle('fill', x, y, s, 2)
        love.graphics.setColor(0.46, 0.46, 0.54, 1)          -- bordes laterales
        love.graphics.rectangle('fill', x,       y, 2, visH)
        love.graphics.rectangle('fill', x+s-2,   y, 2, visH)
        love.graphics.setColor(0.20, 0.20, 0.24, 1)          -- sombra inferior
        love.graphics.rectangle('fill', x, y+visH-2, s, 2)
    end,
}
