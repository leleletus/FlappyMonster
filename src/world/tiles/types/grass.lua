-- Césped: bloque sólido verde; con la cara de arriba al aire le crecen unos
-- tallitos de hierba por encima (fijos por celda). Se une con 'ground'.
local TileTypes = require 'src/world/tiles/TileTypes'

-- Tallos: { x en píxeles de 16, alto en píxeles }
local BLADES = { { 1, 2 }, { 4, 3 }, { 6, 1 }, { 9, 2 }, { 12, 3 }, { 14, 2 }, { 3, 1 }, { 11, 1 } }

return {
    id = 17, name = 'grass', label = 'Césped', category = 'Terreno',
    collision = 'solid', material = 'grass', joinGroup = 'ground',
    editorColor = { 0.3, 0.62, 0.24 },
    draw = function(t, ctx)
        local x, y, s = ctx.x, ctx.y, ctx.size
        local p = math.max(2, math.floor(s / 16))           -- un píxel del arte
        love.graphics.setColor(0.3, 0.62, 0.24, 1)
        love.graphics.rectangle('fill', x, y, s, s)
        -- (algún brote más oscuro por dentro)
        local h = ((ctx.col or 1) * 5 + (ctx.row or 1) * 11) % 7
        love.graphics.setColor(0.24, 0.52, 0.19, 1)
        love.graphics.rectangle('fill', x + math.floor((3 + h) * s / 16), y + math.floor((6 + h % 3 * 3) * s / 16), p, p * 2)
        love.graphics.rectangle('fill', x + math.floor((10 - h % 4) * s / 16), y + math.floor((10 + h % 2 * 2) * s / 16), p, p * 2)
        local e = TileTypes.edges(t, ctx)
        love.graphics.setColor(0.46, 0.78, 0.32, 1)
        TileTypes.drawEdges(ctx, e, 2)
        if e.top then
            -- Tallitos de hierba asomando por arriba (unos pocos, al azar fijo)
            local n = 2 + (((ctx.col or 1) * 3 + (ctx.row or 1)) % 3)
            for i = 1, n do
                local b = BLADES[((ctx.col or 1) * 5 + i * 3) % #BLADES + 1]
                local bx = x + math.floor(b[1] * s / 16)
                -- (solo en la mitad de arriba que da al aire: la otra la tapa un mini bloque)
                if TileTypes.half(e.top, b[1] < 8 and 1 or 2) then
                    love.graphics.setColor(0.24, 0.52, 0.19, 1)
                    love.graphics.rectangle('fill', bx, y - b[2] * p, p, b[2] * p)
                    love.graphics.setColor(0.46, 0.78, 0.32, 1)
                    love.graphics.rectangle('fill', bx, y - b[2] * p, p, p)
                end
            end
        end
    end,
}
