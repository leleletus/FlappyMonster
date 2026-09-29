-- Bloque invisible: un bloque entero que no se ve hasta que un jugador lo toca.
-- Aparece con una animación, sigue visible mientras alguien lo toca y, cuando
-- nadie lo toca, parpadea un momento y vuelve a desaparecer (solo dibujo: el
-- estado vive en Level:updateHiddenBlocks, cada cliente con sus jugadores).
-- Físicamente es una plataforma NO traspasable de una casilla entera: se
-- atraviesa subiendo (y de lado), se apoya encima y no se puede bajar
-- agachándose. Para las entidades es un bloque (enemySolid).
local TileTypes = require 'src/world/tiles/TileTypes'

local APPEAR = 0.22         -- s de la animación de aparición
local function drawBlock(x, y, s, flash)
    love.graphics.setColor(0.27, 0.33, 0.48, 1)
    love.graphics.rectangle('fill', x, y, s, s)
    love.graphics.setColor(0.60, 0.70, 0.88, 1)
    TileTypes.drawEdges({ x = x, y = y, size = s }, { top = true, bottom = true, left = true, right = true }, 2)
    -- remaches: se distingue de un bloque normal
    local k = math.max(1, math.floor(s / 16))
    love.graphics.setColor(0.16, 0.20, 0.30, 1)
    for _, p in ipairs({ { 3, 3 }, { 12, 3 }, { 3, 12 }, { 12, 12 } }) do
        love.graphics.rectangle('fill', x + p[1] * k, y + p[2] * k, k, k)
    end
    if flash and flash > 0 then
        love.graphics.setColor(1, 1, 1, flash)
        love.graphics.rectangle('fill', x, y, s, s)
    end
end

-- Contorno a trazos (editor y miniaturas: ahí no se ve el bloque)
local function drawGhost(x, y, s)
    love.graphics.setColor(0.46, 0.54, 0.68, 0.25)
    love.graphics.rectangle('fill', x, y, s, s)
    love.graphics.setColor(0.75, 0.85, 1, 0.9)
    local d = math.max(2, math.floor(s / 8))
    local w = math.max(1, math.floor(s / 32))
    for i = 0, s - 1, d * 2 do
        local l = math.min(d, s - i)
        love.graphics.rectangle('fill', x + i, y, l, w); love.graphics.rectangle('fill', x + i, y + s - w, l, w)
        love.graphics.rectangle('fill', x, y + i, w, l); love.graphics.rectangle('fill', x + s - w, y + i, w, l)
    end
end

return {
    id = 15, name = 'hidden_block', label = 'Bloque invisible', category = 'Plataformas',
    collision = 'oneway', dropThrough = false, material = 'stone', hidden = true,
    editorColor = { 0.27, 0.33, 0.48 },
    draw = function(t, ctx)
        local x, y, s = ctx.x, ctx.y, ctx.size
        if EDITOR_VIEW or not ctx.level then drawGhost(x, y, s); return end
        local st = ctx.level.hiddenVis and ctx.level.hiddenVis[ctx.row * 65536 + ctx.col]
        if not st then return end
        -- Aparición: crece desde el centro con un pequeño rebote y un destello
        if st.age < APPEAR then
            local k = st.age / APPEAR
            local sc = 0.55 + 0.45 * k + math.sin(k * math.pi) * 0.12
            local sz = math.floor(s * sc + 0.5)
            drawBlock(math.floor(x + (s - sz) / 2), math.floor(y + (s - sz) / 2), sz, 1 - k)
            return
        end
        -- Nadie lo toca: parpadea (cada vez más rápido) antes de desaparecer
        if st.left > st.hold then
            local b = st.left - st.hold
            local rate = 8 + 14 * (b / st.blink)
            if math.floor(b * rate) % 2 == 1 then return end
        end
        drawBlock(x, y, s)
    end,
}
