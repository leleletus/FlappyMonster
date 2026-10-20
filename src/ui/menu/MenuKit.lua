-- src/ui/menu/MenuKit.lua
-- Las PIEZAS COMUNES de las pantallas con contenido (online, docs/architecture/menus.md) en el estilo de los menús:
-- cajas 9-slice (assets/images/ui/menus/box.png, tools/art/ui/make_menu_ui.py), campos de texto, rótulos de sección,
-- selectores ◀ valor ▶, el cursor que marca lo elegido y la línea de ayuda. Solo dibujan: la geometría la pone
-- cada pantalla (una sola tabla para dibujo, ratón y táctil).
--   MenuKit.box(kind, x, y, w, h, alpha)          kind: 'well' (hundido) | 'card' | 'card_sel' | 'window'
--   MenuKit.field(x, y, w, h, text, active, o)    campo de texto (o.placeholder, o.mask, o.alpha)
--   MenuKit.section(text, x, y, w, active, a)     rótulo de sección (fuente pixel) con su raya
--   MenuKit.stepper(label, value, r, color, selected, o)   botón con ◀ ▶ (o.alpha, o.bob)
--   MenuKit.stepperSide(r, x)                     -1 / 1: qué flecha de un selector se tocó
--   MenuKit.arrow(cx, cy, h, dir, a, col)         flecha pixel (dir -1 izquierda, 1 derecha) con sombra
--   MenuKit.marker(x, y, w, h, t, a)              el CURSOR del botón elegido (se coloca solo donde haya sitio; ver abajo)
--   MenuKit.occupy(x, y, w, h)                    apunta algo dibujado (los botones y las cajas lo hacen solos)
--   MenuKit.flush()                               dibuja los cursores del fotograma (game.lua, tras la pantalla)
--   MenuKit.title(text, color, A, i, maxS)            el rótulo de arriba (MenuList.header; texto libre si la fuente pixel
--                                                 no tiene sus letras: nombres de sala)
--   MenuKit.hint(text, A, i)                      la línea de ayuda de abajo
--   MenuKit.dim(a)                                oscurece la pantalla (bajo una ventana)
--   MenuKit.optionsWindow(title, labels, colors, sel, a, o) / optionsLayout(n, o) / optionAt(n, x, y, o)
--                                                 la ventana de opciones de las pausas y los fines de partida
--   MenuKit.text(font, text, x, y, w, align, color, a)   texto con sombra de 2 px
local PixelFont  = require 'src/ui/PixelFont'
local MenuButton = require 'src/ui/menu/MenuButton'

local MenuKit = {}

local S = MenuButton.S
local CELL, CUT = 8, 2
local KINDS = { well = 0, card = 1, card_sel = 2, window = 3 }
local sheet, quads = nil, {}

local function piecesOf(kind)
    if not sheet then
        sheet = love.graphics.newImage('assets/images/ui/menus/box.png')
        sheet:setFilter('nearest', 'nearest')
    end
    local i = KINDS[kind] or 1
    if quads[i] then return quads[i] end
    local W, H = sheet:getDimensions()
    local xs = { 0, CUT, CELL - CUT, CELL }
    local q = {}
    for r = 1, 3 do
        for c = 1, 3 do
            q[#q + 1] = love.graphics.newQuad(i * CELL + xs[c], xs[r], xs[c + 1] - xs[c], xs[r + 1] - xs[r], W, H)
        end
    end
    quads[i] = q
    return q
end

function MenuKit.box(kind, x, y, w, h, alpha)
    local q = piecesOf(kind)
    x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h)
    if (alpha or 1) > 0.05 then MenuKit.occupy(x, y, w, h) end
    local e = CUT * S
    local mw = CELL - 2 * CUT
    local cw, ch = math.max(0, w - 2 * e) / mw, math.max(0, h - 2 * e) / mw
    local xs, ws = { x, x + e, x + w - e }, { S, cw, S }
    local ys, hs = { y, y + e, y + h - e }, { S, ch, S }
    love.graphics.setColor(1, 1, 1, alpha or 1)
    for r = 1, 3 do
        for c = 1, 3 do love.graphics.draw(sheet, q[(r - 1) * 3 + c], xs[c], ys[r], 0, ws[c], hs[r]) end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function MenuKit.text(font, text, x, y, w, align, color, a)
    love.graphics.setFont(font)
    a = a or 1
    if a > 0.05 then                          -- (lo que ocupa de verdad: el cursor no se pone encima)
        local tw, lines = font:getWrap(text, w)
        local lx = (align == 'center' and (w - tw) / 2) or (align == 'right' and w - tw) or 0
        MenuKit.occupy(math.floor(x + lx), math.floor(y), tw, #lines * font:getHeight() * font:getLineHeight())
    end
    love.graphics.setColor(0, 0, 0, 0.7 * a)
    love.graphics.printf(text, math.floor(x) + 2, math.floor(y) + 2, w, align or 'left')
    local c = color or { 1, 1, 1 }
    love.graphics.setColor(c[1], c[2], c[3], (c[4] or 1) * a)
    love.graphics.printf(text, math.floor(x), math.floor(y), w, align or 'left')
    love.graphics.setColor(1, 1, 1, 1)
end

-- Campo de texto: hueco hundido, el texto en la fuente normal (los nombres pueden llevar cualquier letra) y el cursor
-- de bloque parpadeando cuando está activo
function MenuKit.field(x, y, w, h, text, active, o)
    o = o or {}
    local a = o.alpha or 1
    MenuKit.box('well', x, y, w, h, a)
    if active then
        love.graphics.setColor(1, 0.85, 0.3, 0.9 * a)
        love.graphics.rectangle('fill', x + S, y + h - 2 * S, w - 2 * S, S)
    end
    local f = FONT_MED
    local shown = text or ''
    if o.mask then shown = string.rep('*', #shown) end
    local ty = math.floor(y + (h - f:getHeight()) / 2)
    local tx = x + 5 * S
    if shown == '' and o.placeholder then
        MenuKit.text(f, o.placeholder, tx, ty, w - 10 * S, 'left', { 0.55, 0.62, 0.8 }, a)
    else
        -- (si no cabe, se ve el final: lo que se está escribiendo)
        while f:getWidth(shown) > w - 12 * S and #shown > 0 do shown = shown:sub(2) end
        MenuKit.text(f, shown, tx, ty, w - 10 * S, 'left', nil, a)
    end
    if active and math.floor(love.timer.getTime() * 2.5) % 2 == 0 then
        local cx = (shown == '' and o.placeholder) and tx or tx + f:getWidth(shown) + 4
        love.graphics.setColor(1, 0.85, 0.3, a)
        love.graphics.rectangle('fill', math.floor(cx), ty, 3 * S, f:getHeight())
        love.graphics.setColor(1, 1, 1, 1)
    end
end

-- Rótulo de sección: fuente pixel amarilla y una raya debajo; apagado si su columna no tiene el foco
function MenuKit.section(text, x, y, w, active, a)
    a = a or 1
    local s = 3
    PixelFont.shadow(text, x, y, s, (active == false and 0.55 or 1) * a, { 1, 0.86, 0.36 })
    love.graphics.setColor(1, 0.86, 0.36, (active == false and 0.18 or 0.45) * a)
    love.graphics.rectangle('fill', math.floor(x), math.floor(y + PixelFont.height(s) + 6), math.floor(w), S / 2)
    love.graphics.setColor(1, 1, 1, 1)
    return y + PixelFont.height(s) + 14
end

-- Flecha pixel (triángulo de escalones) apuntando a dir (-1 izquierda, 1 derecha), alto h
function MenuKit.arrow(cx, cy, h, dir, a, col)
    local n = math.max(2, math.floor((h / S + 1) / 2))
    love.graphics.setColor(0, 0, 0, 0.5 * a)
    for i = 0, n - 1 do
        local len = (n - i) * 2 - 1
        local x = dir > 0 and cx + i * S or cx - i * S - S
        love.graphics.rectangle('fill', x + S / 2, cy - len * S / 2 + S / 2, S, len * S)
    end
    love.graphics.setColor(col[1], col[2], col[3], a)
    for i = 0, n - 1 do
        local len = (n - i) * 2 - 1
        local x = dir > 0 and cx + i * S or cx - i * S - S
        love.graphics.rectangle('fill', x, cy - len * S / 2, S, len * S)
    end
end

-- Selector: un botón de color con "ETIQUETA: VALOR" y una flecha a cada lado (cuando está elegido, las flechas se
-- mueven hacia fuera a saltos)
function MenuKit.stepper(label, value, r, color, selected, o)
    o = o or {}
    local a = o.alpha or 1
    local y = r.y + (o.bob or 0)
    local text = label and (label .. ' ' .. value) or value
    local pad = 16 * S
    MenuButton.draw(text, r.x, y, r.w, r.h, color, selected, { alpha = a, scale = MenuButton.textScale(text, r.w - 2 * pad - 8 * S, o.scale) })
    local face = r.h - S
    local cy = math.floor(y + face / 2)
    local wob = selected and (math.floor(love.timer.getTime() * 3) % 2) * S or 0
    local ah = math.min(face - 4 * S, 8 * S)
    MenuKit.arrow(r.x + 9 * S - wob, cy, ah, -1, a, { 1, 1, 1 })
    MenuKit.arrow(r.x + r.w - 9 * S + wob, cy, ah, 1, a, { 1, 1, 1 })
end

-- Qué mitad de un selector se tocó: -1 izquierda, 1 derecha
function MenuKit.stepperSide(r, x) return x < r.x + r.w / 2 and -1 or 1 end

-- ── El CURSOR que marca lo elegido (assets/images/ui/menus/cursor.png) ────────
-- Inteligente: lo que se dibuja en el fotograma (botones, cajas, paneles) se apunta con MenuKit.occupy; el cursor se
-- pide con MenuKit.marker y se dibuja al FINAL del fotograma (MenuKit.flush, en game.lua), cuando ya se sabe qué hay
-- en pantalla. Prueba a la izquierda, a la derecha, arriba y abajo del botón y se queda con el primer sitio que cabe
-- en la pantalla (y dentro de la caja que contiene al botón, si la hay) sin pisar nada más; apunta hacia el botón. Si
-- no hay sitio, no sale.
local CUR_S, CUR_GAP = 4, 10            -- escala del dibujo; px entre el cursor y el botón
local cursorImg
local occupied, queued = {}, {}

function MenuKit.occupy(x, y, w, h)
    if #occupied > 512 then occupied = {} end            -- (pantallas que no llaman a flush: arneses sueltos)
    occupied[#occupied + 1] = { x = x, y = y, w = w, h = h }
end

local function overlaps(a, b) return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h end
local function inside(a, b) return a.x >= b.x and a.y >= b.y and a.x + a.w <= b.x + b.w and a.y + a.h <= b.y + b.h end

-- Pide el cursor junto al botón (x, y, w, h); t = tiempo (anima), a = transparencia
function MenuKit.marker(x, y, w, h, t, a)
    queued[#queued + 1] = { x = math.floor(x), y = math.floor(y), w = math.floor(w), h = math.floor(h), t = t or 0, a = a or 1 }
end

-- Dónde va el cursor de un botón: x, y (esquina del dibujo ya girado), lado ('left' = a su izquierda...) o nil
function MenuKit.place(r, rects)
    if not cursorImg then cursorImg = love.graphics.newImage('assets/images/ui/menus/cursor.png') end
    local iw, ih = cursorImg:getWidth() * CUR_S, cursorImg:getHeight() * CUR_S
    -- la caja más pequeña que contiene al botón (el cursor no se sale de ella)
    local box = { x = 0, y = 0, w = WINDOW_W, h = WINDOW_H }
    for _, o in ipairs(rects) do
        if inside(r, o) and not (o.x == r.x and o.y == r.y and o.w == r.w and o.h == r.h) and o.w * o.h < box.w * box.h then box = o end
    end
    local cx, cy = r.x + math.floor(r.w / 2), r.y + math.floor(r.h / 2)
    local cands = {
        { side = 'left',  x = r.x - CUR_GAP - iw, y = cy - math.floor(ih / 2), w = iw, h = ih },
        { side = 'right', x = r.x + r.w + CUR_GAP, y = cy - math.floor(ih / 2), w = iw, h = ih },
        { side = 'up',    x = cx - math.floor(ih / 2), y = r.y - CUR_GAP - iw, w = ih, h = iw },
        { side = 'down',  x = cx - math.floor(ih / 2), y = r.y + r.h + CUR_GAP, w = ih, h = iw },
    }
    for _, c in ipairs(cands) do
        -- (con el margen del vaivén de 4 px y su sombra)
        local probe = { x = c.x - 4, y = c.y - 4, w = c.w + 8, h = c.h + 8 }
        if inside(probe, box) then
            local free = true
            for _, o in ipairs(rects) do
                if not inside(r, o) and overlaps(probe, o) then free = false; break end
            end
            if free then return c end
        end
    end
    return nil
end

-- Dibuja los cursores pedidos en este fotograma y vacía la lista de lo dibujado (una vez por fotograma)
function MenuKit.flush()
    for _, m in ipairs(queued) do
        local c = MenuKit.place(m, occupied)
        if c then
            -- vaivén hacia el botón, a saltos de 4 px
            local nudge = (math.floor(m.t * 4) % 2 == 0) and 4 or 0
            local iw, ih = cursorImg:getWidth(), cursorImg:getHeight()
            local rot, dx, dy = 0, 0, 0
            local ox, oy = c.x, c.y
            if c.side == 'left' then dx = nudge
            elseif c.side == 'right' then rot, ox, oy, dx = math.pi, c.x + c.w, c.y + c.h, -nudge
            elseif c.side == 'up' then rot, ox, dy = math.pi / 2, c.x + c.w, nudge
            else rot, oy, dy = -math.pi / 2, c.y + c.h, -nudge end
            love.graphics.setColor(0, 0, 0, 0.45 * m.a)
            love.graphics.draw(cursorImg, ox + dx + CUR_S, oy + dy + CUR_S, rot, CUR_S, CUR_S)
            love.graphics.setColor(1, 1, 1, m.a)
            love.graphics.draw(cursorImg, ox + dx, oy + dy, rot, CUR_S, CUR_S)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
    queued, occupied = {}, {}
end

-- El rótulo de arriba. Con letras que la fuente pixel no tiene (nombres de sala), el texto va en la fuente normal
-- sobre el mismo botón
function MenuKit.title(text, color, A, i, maxS)
    if PixelFont.has(text) then
        local MenuList = require 'src/ui/menu/MenuList'
        return MenuList.header(text, color, A, i, maxS)
    end
    local f = FONT_BIG
    local w = math.min(WINDOW_W - 200, f:getWidth(text) + 26 * S)
    local h = f:getHeight() + 16 * S
    local x, y = math.floor((WINDOW_W - w) / 2), 36
    local ox, oy, a = 0, 0, 1
    if A then ox, oy, a = A:slide(i or 1, 0, -200, 0, -200) end
    MenuButton.draw(nil, x + ox, y + oy, w, h, color, false, { alpha = a })
    local shown = require('src/ui/TextUtil').fit(f, text, w - 20 * S)
    MenuKit.text(f, shown, x + ox, y + oy + math.floor((h - S - f:getHeight()) / 2), w, 'center', nil, a)
    return y + h
end

function MenuKit.hint(text, A, i)
    if Input.lastDevice == 'touch' then return end        -- (con el dedo no hay teclas que explicar)
    require('src/ui/menu/MenuList').footer(nil, A, i, text)
end

-- ── Ventana de opciones (pausas, fin de partida): una sola geometría para dibujo, ratón y táctil ────────
-- n = número de botones; o.note = texto bajo el título (deja sitio). → panel {x, y, w, h}, rects[i]
local OPT_W, OPT_H, OPT_GAP = 340, 56, 12
function MenuKit.optionsLayout(n, o)
    o = o or {}
    local noteH = o.note and 44 or 0
    local w = math.min(540, WINDOW_W - 80)
    local h = 116 + noteH + n * (OPT_H + OPT_GAP) + 24
    local P = { x = math.floor((WINDOW_W - w) / 2), y = math.floor((WINDOW_H - h) / 2), w = w, h = h }
    local rects = {}
    for i = 1, n do
        rects[i] = { x = math.floor((WINDOW_W - OPT_W) / 2), y = P.y + 108 + noteH + (i - 1) * (OPT_H + OPT_GAP),
                     w = OPT_W, h = OPT_H }
    end
    return P, rects
end
-- ¿Qué botón hay en (x, y)? (o nil)
function MenuKit.optionAt(n, x, y, o)
    local _, rects = MenuKit.optionsLayout(n, o)
    for i, r in ipairs(rects) do
        if x >= r.x - 10 and x <= r.x + r.w + 10 and y >= r.y - 5 and y <= r.y + r.h + 5 then return i end
    end
end
-- Dibuja la ventana: title (texto), labels[i] (textos ya traducidos), colors[i] (colores de botón), sel, a (0..1)
-- o.titleColor, o.note, o.dim (oscurecer debajo: 0.55 por defecto)
function MenuKit.optionsWindow(title, labels, colors, sel, a, o)
    o = o or {}
    a = a or 1
    local P, rects = MenuKit.optionsLayout(#labels, o)
    MenuKit.dim((o.dim or 0.55) * a)
    local oy = math.floor((1 - a) * 40 / 4) * 4          -- (entra subiendo, a saltos de píxel)
    MenuKit.box('window', P.x, P.y + oy, P.w, P.h, a)
    local s = 5
    while s > 3 and PixelFont.width(title, s) > P.w - 60 do s = s - 1 end
    if PixelFont.has(title) then
        PixelFont.shadow(title, math.floor(P.x + (P.w - PixelFont.width(title, s)) / 2), P.y + 30 + oy, s, a, o.titleColor or { 1, 0.86, 0.36 })
    else
        MenuKit.text(FONT_BIG, title, P.x, P.y + 26 + oy, P.w, 'center', o.titleColor or { 1, 0.86, 0.36 }, a)
    end
    if o.note then MenuKit.text(FONT_SMALL, o.note, P.x + 24, P.y + 98 + oy, P.w - 48, 'center', { 0.82, 0.86, 1 }, a) end
    local t = love.timer.getTime()
    for i, label in ipairs(labels) do
        local r, on = rects[i], i == sel
        local bob = on and ((math.floor(t * 3) % 2 == 0) and -4 or 0) or 0
        MenuButton.draw(label, r.x, r.y + oy + bob, r.w, r.h, colors[i] or 'grey', on,
                        { alpha = a, scale = MenuButton.textScale(label, r.w - 48, 4) })
        if on then MenuKit.marker(r.x, r.y + oy + bob, r.w, r.h, t, a) end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function MenuKit.dim(a)
    occupied = {}                 -- (lo de debajo queda tapado: ya no estorba al cursor; los cursores pedidos, tampoco salen)
    queued = {}
    love.graphics.setColor(0.03, 0.04, 0.1, a or 0.6)
    love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)
    love.graphics.setColor(1, 1, 1, 1)
end

return MenuKit
