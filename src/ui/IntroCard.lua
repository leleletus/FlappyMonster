-- src/ui/IntroCard.lua
-- La TARJETA DE PRESENTACIÓN del nivel (0.5.202, docs/design/level-intro-card.md): antes de la cuenta atrás, ~5 s,
-- no se salta. Dos BANDAS del color de la isla entran por lados opuestos (el nombre del nivel desde la izquierda, la
-- isla desde la derecha); una PLACA pequeña con el número («1-3», «1-B», «1-?», «1-» + el castillo) cae en el hueco a
-- la izquierda de la banda de la isla. DEBAJO, la ESCENA de verdad (0.5.203, src/ui/IntroScene.lua: el fondo del
-- nivel, el monstruo cruzando y el enemigo de la isla); sin escena, negro. Mientras el servidor espera a los que cargan
-- (online) las bandas brillan y, pasado un rato, «Esperando jugadores...» abajo a la izquierda. Solo dibujo (el tiempo
-- lo lleva StartCountdown). Datos: Worlds.plate / Worlds.introOf; arte: tools/art/ui/make_intro_card.py.
--   local card = IntroCard.new(level, id)       id = el archivo sin .json (nil: sin isla ni número); nil en niveles Flappy
--   IntroCard.draw(card, t, o)                  t = s desde que salió; o.scene = la escena de debajo; o.waiting = s de
--                                               espera de más (nil: no espera); o.left = s que le quedan (el fundido)
--   IntroCard.drawFadeIn(since)                 el nivel saliendo del negro (bajo el HUD), `since` s tras la tarjeta
--   IntroCard.rects(card) → { name, island, plate, stage }   {x,y,w,h} a la medida de ahora (stage: donde pasa la escena)
local L         = require 'src/core/Lang'
local PixelFont = require 'src/ui/PixelFont'

local IntroCard = {}
-- FUNDIDO al pasar al nivel (0.5.203, el usuario: «que no se sienta tan brusco»): la tarjeta se va a negro en sus
-- últimos FADE_OUT s y el nivel sale del negro en sus primeros FADE_IN s — por DEBAJO del HUD: el ¡YA! y el inicio
-- del nivel se ven enteros —
IntroCard.FADE_OUT, IntroCard.FADE_IN = 0.35, 0.4

-- El velo negro del nivel tras la tarjeta: `since` = s desde que acabó la tarjeta (nil: nada)
function IntroCard.drawFadeIn(since)
    if not since or since >= IntroCard.FADE_IN then return end
    love.graphics.setColor(0, 0, 0, 1 - math.max(0, since) / IntroCard.FADE_IN)
    love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)
    love.graphics.setColor(1, 1, 1, 1)
end

local cache = {}
local function img(path)
    local im = cache[path]
    if im == nil then
        local ok, res = pcall(love.graphics.newImage, path)
        im = ok and res or false
        if im then im:setFilter('nearest', 'nearest') end
        cache[path] = im
    end
    return im or nil
end
local function art(name) return img('assets/images/ui/intro/' .. name) end

local quads = {}
local function quad(im, x, y, w, h)
    local k = tostring(im) .. x .. ',' .. y .. ',' .. w .. ',' .. h
    if not quads[k] then quads[k] = love.graphics.newQuad(x, y, w, h, im:getDimensions()) end
    return quads[k]
end

local NAME_S, ISLE_S, PLATE_S = 6, 4, 4     -- escalas de la fuente pixel
local SLIDE, DROP_AT, DROP = 0.4, 0.45, 0.2  -- s: entrada de las bandas, cuándo cae la placa y cuánto tarda

function IntroCard.new(level, id)
    if not level or level.flappy then return nil end
    local Worlds = require 'src/story/Worlds'
    local card = { name = L.localName(level) or '', look = Worlds.introOf(id), plate = Worlds.plate(id) }
    local w = id and Worlds.worldOf(id)
    if w and L.has('story.world.' .. w) then card.island = L('story.world.' .. w) end
    return card
end

-- El texto de la placa ('1-3'…; el jefe: '1-' y el castillo aparte)
local function plateText(p)
    if not p then return nil end
    if p.kind == 'boss' then return p.w .. '-' end
    if p.kind == 'bonus' then return p.w .. '-B' end
    if p.kind == 'secret' then return p.w .. '-?' end
    return p.w .. '-' .. p.n
end

-- El nombre en una o dos líneas que quepan en `maxW`
local function nameLines(name, maxW)
    name = PixelFont.upper(name)
    if PixelFont.width(name, NAME_S) <= maxW then return { name } end
    local words, best = {}, nil
    for wd in name:gmatch('%S+') do words[#words + 1] = wd end
    for cut = 1, #words - 1 do
        local a = table.concat(words, ' ', 1, cut)
        local b = table.concat(words, ' ', cut + 1)
        local m = math.max(PixelFont.width(a, NAME_S), PixelFont.width(b, NAME_S))
        if not best or m < best.m then best = { a, b, m = m } end
    end
    return best and { best[1], best[2] } or { name }
end

-- Dónde va cada cosa (al final de su entrada), a la medida de la pantalla de ahora
local function layout(card)
    local W, H = WINDOW_W, WINDOW_H
    local Ly = {}
    -- banda del nombre: arriba, desde la izquierda, ~3/4 del ancho
    local nameMax = math.floor(W * 0.86) - 80
    Ly.lines = nameLines(card.name, nameMax)
    local tw = 0
    for _, l in ipairs(Ly.lines) do tw = math.max(tw, PixelFont.width(l, NAME_S)) end
    local lineH = PixelFont.height(NAME_S) + 14
    local nh = #Ly.lines * lineH - 14 + 48
    local nw = math.min(W - 24, math.max(math.floor(W * 0.72), tw + 96))
    Ly.name = { x = 0, y = math.floor(H * 0.12), w = nw, h = nh }
    -- placa (si hay número): a la izquierda de la banda de la isla
    local pt = plateText(card.plate)
    local castle = card.plate and card.plate.kind == 'boss' and img('assets/images/story/castle-Sheet.png')
    local pw = pt and (PixelFont.width(pt, PLATE_S) + (castle and 16 * 3 + 6 or 0) + 36) or 0
    local ph = 60
    -- banda de la isla: debajo, desde la derecha
    local iy = Ly.name.y + nh + 8 + 30
    local itw = card.island and PixelFont.width(card.island, ISLE_S) or 0
    local iw = math.max(math.floor(W * 0.5), itw + 96)
    iw = math.min(iw, W - (pt and (pw + 72) or 24))
    Ly.island = { x = W - iw, y = iy, w = iw, h = 64 }
    if pt then Ly.plate = { x = math.max(24, Ly.island.x - pw - 32), y = iy + 2, w = pw, h = ph, text = pt, castle = castle } end
    -- la escena: el suelo (dos casillas abajo) y lo que anda por él (el monstruo, el enemigo, un salto)
    Ly.ground = H - 2 * TILE_PX
    local top = Ly.ground - 200
    Ly.stage = { x = 0, y = top, w = W, h = H - top }
    return Ly
end

function IntroCard.rects(card)
    local Ly = layout(card)
    return { name = Ly.name, island = Ly.island, plate = Ly.plate, stage = Ly.stage }
end

-- Una banda teñida con su sombra y su punta; `fromLeft`: la punta a la derecha
local function band(r, col, shade, fromLeft, t)
    local b, cap = art('band.png'), art('band_cap.png')
    local s = r.h / 16
    -- sombra (más oscura, 6 px por debajo)
    love.graphics.setColor(shade[1], shade[2], shade[3], 1)
    love.graphics.rectangle('fill', r.x, r.y + 6, r.w, r.h)
    love.graphics.setColor(col[1], col[2], col[3], 1)
    if b then
        local n = math.ceil(r.w / (16 * s))
        for i = 0, n - 1 do
            local x = r.x + i * 16 * s
            local w = math.min(16, math.ceil((r.x + r.w - x) / s))
            if w > 0 then love.graphics.draw(b, quad(b, 0, 0, w, 16), math.floor(x), r.y, 0, s, s) end
        end
    else
        love.graphics.rectangle('fill', r.x, r.y, r.w, r.h)
    end
    if cap then
        if fromLeft then love.graphics.draw(cap, r.x + r.w, r.y, 0, s, s)
        else love.graphics.draw(cap, r.x, r.y, 0, -s, s) end
    end
    -- brillo que recorre la banda despacio (sigue viva mientras se espera)
    local sweep = ((t * 0.5) % 1.6) / 1.6
    local sx = r.x + math.floor(sweep * (r.w + 120) / 8) * 8 - 60
    love.graphics.setColor(1, 1, 1, 0.35)
    love.graphics.rectangle('fill', math.max(r.x, sx), r.y, math.max(0, math.min(48, r.x + r.w - sx)), s)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Avance escalonado 0..1 de una entrada (pasos de 8 px en `dist`)
local function stepped(t, t0, dur, dist)
    local p = math.max(0, math.min(1, (t - t0) / dur))
    return math.floor(p * dist / 8) * 8
end

function IntroCard.draw(card, t, o)
    if not card or not t then return end
    o = o or {}
    local W, H = WINDOW_W, WINDOW_H
    local Ly = layout(card)
    local look = card.look
    if o.scene then o.scene:draw()
    else love.graphics.setColor(0, 0, 0, 1); love.graphics.rectangle('fill', 0, 0, W, H) end

    -- bandas
    local n = Ly.name
    local nx = n.x - (n.w + 8) + stepped(t, 0, SLIDE, n.w + 8)
    band({ x = nx, y = n.y, w = n.w, h = n.h }, look.bands[1], look.shade[1], true, t)
    local lineH = PixelFont.height(NAME_S) + 14
    for i, l in ipairs(Ly.lines) do
        PixelFont.shadow(l, nx + 40, n.y + 24 + (i - 1) * lineH, NAME_S, 1)
    end
    local isl = Ly.island
    local ix = isl.x + (isl.w + 8) - stepped(t, 0.1, SLIDE, isl.w + 8)
    band({ x = ix, y = isl.y, w = isl.w, h = isl.h }, look.bands[2], look.shade[2], false, t)
    if card.island then
        local dark = { look.shade[2][1] * 0.35, look.shade[2][2] * 0.35, look.shade[2][3] * 0.35 }
        PixelFont.draw(card.island, ix + isl.w - 40 - PixelFont.width(card.island, ISLE_S),
                       isl.y + math.floor((isl.h - PixelFont.height(ISLE_S)) / 2), ISLE_S, 1, dark)
    end

    -- placa
    local p = Ly.plate
    if p and t >= DROP_AT then
        local py = p.y - (p.y + p.h) + stepped(t, DROP_AT, DROP, p.y + p.h)
        local pl = art('plate.png')
        love.graphics.setColor(0.35, 0.35, 0.38, 1)
        love.graphics.rectangle('fill', p.x + 6, py + 6, p.w, p.h)            -- (sombra)
        love.graphics.setColor(1, 1, 1, 1)
        if pl then
            local c = 4 * 3
            local qs = function(qx, qy, qw, qh) return quad(pl, qx, qy, qw, qh) end
            local mw, mh = p.w - 2 * c, p.h - 2 * c
            love.graphics.draw(pl, qs(0, 0, 4, 4), p.x, py, 0, 3, 3)
            love.graphics.draw(pl, qs(8, 0, 4, 4), p.x + p.w - c, py, 0, 3, 3)
            love.graphics.draw(pl, qs(0, 8, 4, 4), p.x, py + p.h - c, 0, 3, 3)
            love.graphics.draw(pl, qs(8, 8, 4, 4), p.x + p.w - c, py + p.h - c, 0, 3, 3)
            love.graphics.draw(pl, qs(4, 0, 4, 4), p.x + c, py, 0, mw / 4, 3)
            love.graphics.draw(pl, qs(4, 8, 4, 4), p.x + c, py + p.h - c, 0, mw / 4, 3)
            love.graphics.draw(pl, qs(0, 4, 4, 4), p.x, py + c, 0, 3, mh / 4)
            love.graphics.draw(pl, qs(8, 4, 4, 4), p.x + p.w - c, py + c, 0, 3, mh / 4)
            love.graphics.draw(pl, qs(4, 4, 4, 4), p.x + c, py + c, 0, mw / 4, mh / 4)
        else
            love.graphics.rectangle('fill', p.x, py, p.w, p.h)
        end
        local tx = p.x + 18
        local ty = py + math.floor((p.h - PixelFont.height(PLATE_S)) / 2)
        PixelFont.draw(p.text, tx, ty, PLATE_S, 1, { 0.08, 0.08, 0.12 })
        if p.castle then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(p.castle, quad(p.castle, 0, 0, 16, 16), tx + PixelFont.width(p.text, PLATE_S) + 6,
                               py + math.floor((p.h - 48) / 2), 0, 3, 3)
        end
    end

    -- a negro al acabar (o.left = s que le quedan a la tarjeta)
    if o.left and o.left < IntroCard.FADE_OUT then
        love.graphics.setColor(0, 0, 0, 1 - math.max(0, o.left) / IntroCard.FADE_OUT)
        love.graphics.rectangle('fill', 0, 0, W, H)
    end
    -- esperando a los demás (online): abajo a la izquierda, con puntos que se mueven
    if o.waiting and o.waiting > 1 then
        local dots = string.rep('.', 1 + math.floor(t * 2) % 3)
        local txt = L('intro.waiting') .. dots
        love.graphics.setFont(FONT_SMALL)
        local y = H - 24 - FONT_SMALL:getHeight()
        love.graphics.setColor(0, 0, 0, 0.75)                 -- (fondo oscuro: se lee sobre cualquier suelo)
        love.graphics.rectangle('fill', 14, y - 8, FONT_SMALL:getWidth(L('intro.waiting') .. '...') + 20, FONT_SMALL:getHeight() + 16)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.print(txt, 26, y + 2)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(txt, 24, y)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return IntroCard
