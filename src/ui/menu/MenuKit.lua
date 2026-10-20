-- src/ui/menu/MenuKit.lua
-- Las PIEZAS COMUNES de las pantallas con contenido (online, docs/architecture/menus.md) en el estilo de los menús:
-- cajas 9-slice (assets/images/ui/menus/box.png, tools/art/ui/make_menu_ui.py), campos de texto, rótulos de sección,
-- selectores ◀ valor ▶, el monstruito que marca lo elegido y la línea de ayuda. Solo dibujan: la geometría la pone
-- cada pantalla (una sola tabla para dibujo, ratón y táctil).
--   MenuKit.box(kind, x, y, w, h, alpha)          kind: 'well' (hundido) | 'card' | 'card_sel' | 'window'
--   MenuKit.field(x, y, w, h, text, active, o)    campo de texto (o.placeholder, o.mask, o.alpha)
--   MenuKit.section(text, x, y, w, active, a)     rótulo de sección (fuente pixel) con su raya
--   MenuKit.stepper(label, value, r, color, selected, o)   botón con ◀ ▶ (o.alpha, o.bob)
--   MenuKit.stepperSide(r, x)                     -1 / 1: qué flecha de un selector se tocó
--   MenuKit.arrow(cx, cy, h, dir, a, col)         flecha pixel (dir -1 izquierda, 1 derecha) con sombra
--   MenuKit.marker(x, y, h, t, a)                 el monstruito saltando a la izquierda de (x, y..y+h)
--   MenuKit.title(text, color, A, i)              el rótulo de arriba (MenuList.header; texto libre si la fuente pixel
--                                                 no tiene sus letras: nombres de sala)
--   MenuKit.hint(text, A, i)                      la línea de ayuda de abajo
--   MenuKit.dim(a)                                oscurece la pantalla (bajo una ventana)
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

-- El monstruito que marca lo elegido (el mismo que el de las listas de botones)
local icon
function MenuKit.marker(x, y, h, t, a)
    if not icon then icon = love.graphics.newImage('assets/images/player/icon.png') end
    a = a or 1
    local s = 4
    local hop = math.floor(math.abs(math.sin((t or 0) * 6)) * 3) * 4
    local ix = math.floor(x - icon:getWidth() * s - 20)
    local iy = math.floor(y + (h - icon:getHeight() * s) / 2) - hop - 4
    love.graphics.setColor(0, 0, 0, 0.4 * a)
    love.graphics.draw(icon, ix + 4, iy + 4 + hop, 0, s, s)
    love.graphics.setColor(1, 1, 1, a)
    love.graphics.draw(icon, ix, iy, 0, s, s)
end
function MenuKit.markerW() return 8 * 4 + 20 end

-- El rótulo de arriba. Con letras que la fuente pixel no tiene (nombres de sala), el texto va en la fuente normal
-- sobre el mismo botón
function MenuKit.title(text, color, A, i)
    if PixelFont.has(text) then
        local MenuList = require 'src/ui/menu/MenuList'
        return MenuList.header(text, color, A, i)
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
    require('src/ui/menu/MenuList').footer(nil, A, i, text)
end

function MenuKit.dim(a)
    love.graphics.setColor(0.03, 0.04, 0.1, a or 0.6)
    love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)
    love.graphics.setColor(1, 1, 1, 1)
end

return MenuKit
