-- Bloque rompible: sólido, se rompe con un cabezazo desde abajo o con un
-- ground pound encima (nada más lo rompe). Textura de ladrillo marrón para
-- que se distinga de un bloque normal.
return {
    id = 12, name = 'breakable', label = 'Bloque rompible', category = 'Terreno',
    collision = 'solid', material = 'stone', breakable = true,
    editorColor = { 0.55, 0.42, 0.30 },
    draw = function(t, ctx)
        local x, y, s = ctx.x, ctx.y, ctx.size
        local u = s / 8
        -- ladrillos
        love.graphics.setColor(0.55, 0.40, 0.28, 1)
        love.graphics.rectangle('fill', x, y, s, s)
        love.graphics.setColor(0.36, 0.25, 0.17, 1)
        love.graphics.rectangle('fill', x, y + s / 2 - u / 2, s, u)          -- junta horizontal
        love.graphics.rectangle('fill', x + s / 2 - u / 2, y, u, s / 2)      -- juntas verticales
        love.graphics.rectangle('fill', x + s / 4 - u / 2, y + s / 2, u, s / 2)
        love.graphics.rectangle('fill', x + 3 * s / 4 - u / 2, y + s / 2, u, s / 2)
        -- borde claro arriba/izquierda y oscuro abajo/derecha
        love.graphics.setColor(0.75, 0.60, 0.45, 1)
        love.graphics.rectangle('fill', x, y, s, 2); love.graphics.rectangle('fill', x, y, 2, s)
        love.graphics.setColor(0.25, 0.17, 0.11, 1)
        love.graphics.rectangle('fill', x, y + s - 2, s, 2); love.graphics.rectangle('fill', x + s - 2, y, 2, s)
    end,
}
