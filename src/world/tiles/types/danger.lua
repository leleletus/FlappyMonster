-- Bloque de peligro: se atraviesa, pero tocarlo con la hitbox interna mata.
return {
    id = 3, name = 'danger', label = 'Peligro', category = 'Peligros',
    collision = 'none', material = 'deadly', enemySolid = false,
    editorColor = { 0.80, 0.08, 0.08 },
    draw = function(t, ctx)
        local x, y, s = ctx.x, ctx.y, ctx.size
        love.graphics.setColor(0.80, 0.08, 0.08, 1)
        love.graphics.rectangle('fill', x, y, s, s)
        love.graphics.setColor(1.0, 0.28, 0.28, 0.55)
        love.graphics.line(x+3, y+3, x+s-3, y+s-3)
        love.graphics.line(x+s-3, y+3, x+3, y+s-3)
    end,
}
