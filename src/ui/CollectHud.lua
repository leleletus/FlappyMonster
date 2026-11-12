-- src/ui/CollectHud.lua
-- LO RECOGIDO EN EL NIVEL, mientras se juega (0.5.200, docs/design/ux-round-2026-11.md): estrellas «★ 2/5» y, en las
-- etapas Flappy, flappies liberados «jaula 1/3», arriba en el centro (las esquinas son de la puntuación, las vidas, la
-- pausa y la vida del jefe). Solo dibujo; nada se guarda hasta terminar el nivel (regla 7).
--   CollectHud.draw(stars, starsTotal, cages, cagesTotal)   (lo que sea 0 de total no sale)
local CollectHud = {}
local star, cage, cageQ
local S = 3

local function art()
    if star then return end
    star = love.graphics.newImage('assets/images/items/star.png'); star:setFilter('nearest', 'nearest')
    cage = love.graphics.newImage('assets/images/items/cage/cage-Sheet.png'); cage:setFilter('nearest', 'nearest')
    cageQ = love.graphics.newQuad(0, 0, 23, 24, cage:getDimensions())
end

local function piece(img, q, iw, ih, sc, text)
    return { img = img, q = q, w = iw * sc, h = ih * sc, sc = sc, text = text }
end

function CollectHud.draw(stars, starsTotal, cages, cagesTotal)
    local parts = {}
    art()
    if (starsTotal or 0) > 0 then parts[#parts + 1] = piece(star, nil, 13, 13, S, stars .. '/' .. starsTotal) end
    if (cagesTotal or 0) > 0 then parts[#parts + 1] = piece(cage, cageQ, 23, 24, 2, cages .. '/' .. cagesTotal) end
    if #parts == 0 then return end
    local font = FONT_MED
    love.graphics.setFont(font)
    local gap, w = 28, 0
    for i, p in ipairs(parts) do w = w + p.w + 8 + font:getWidth(p.text) + (i > 1 and gap or 0) end
    local x, y = math.floor((WINDOW_W - w) / 2), 18
    for _, p in ipairs(parts) do
        local iy = y + math.floor((48 - p.h) / 2)
        love.graphics.setColor(0, 0, 0, 0.5)
        if p.q then love.graphics.draw(p.img, p.q, x + 3, iy + 3, 0, p.sc, p.sc) else love.graphics.draw(p.img, x + 3, iy + 3, 0, p.sc, p.sc) end
        love.graphics.setColor(1, 1, 1, 1)
        if p.q then love.graphics.draw(p.img, p.q, x, iy, 0, p.sc, p.sc) else love.graphics.draw(p.img, x, iy, 0, p.sc, p.sc) end
        x = x + p.w + 8
        local ty = y + math.floor((48 - font:getHeight()) / 2)
        love.graphics.setColor(0, 0, 0, 0.7); love.graphics.print(p.text, x + 2, ty + 2)
        love.graphics.setColor(1, 1, 1, 1); love.graphics.print(p.text, x, ty)
        x = x + font:getWidth(p.text) + gap
    end
end

return CollectHud
