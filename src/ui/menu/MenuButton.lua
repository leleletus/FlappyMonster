-- src/ui/menu/MenuButton.lua
-- Los BOTONES de colores de los menús (docs/architecture/menus.md): un 9-slice de assets/images/ui/menus/button.png (una
-- columna por color, fila 1 normal y fila 2 seleccionado; tools/art/ui/make_menu_ui.py) con el texto en la fuente
-- pixel de los menús (src/ui/PixelFont) y su sombra del color del botón. Y el PANEL (panel.png) de las pantallas
-- con contenido.
--   MenuButton.draw(text, x, y, w, h, color, selected, o)   o: alpha, scale (texto), icon (función(x, y, s))
--   MenuButton.panel(x, y, w, h, alpha)
--   MenuButton.textScale(text, w, max)   escala entera para que el texto quepa en w
local json      = require 'libs/json'
local PixelFont = require 'src/ui/PixelFont'

local MenuButton = {}

MenuButton.S = 4            -- escala del arte (1 px del botón = 4 px de pantalla)
MenuButton.TEXT = 6         -- escala del texto por defecto
local SHADOW = 4            -- px de la sombra negra del botón

local sheet, panelImg, meta, quads = nil, nil, nil, {}
local function load()
    if sheet then return end
    sheet = love.graphics.newImage('assets/images/ui/menus/button.png')
    panelImg = love.graphics.newImage('assets/images/ui/menus/panel.png')
    meta = json.decode(love.filesystem.read('assets/images/ui/menus/button.json'))
    meta.index = {}
    for i, c in ipairs(meta.colors) do meta.index[c] = i end
end

-- Quads de las 9 piezas de una celda (ox, oy = esquina de la celda en la imagen)
local function pieces(im, ox, oy, cell, cut)
    local key = tostring(im) .. ox .. ':' .. oy
    if quads[key] then return quads[key] end
    local W, H = im:getDimensions()
    local xs = { 0, cut.l, cell - cut.r, cell }
    local ys = { 0, cut.t, cell - cut.b, cell }
    local q = {}
    for r = 1, 3 do
        for c = 1, 3 do
            q[#q + 1] = love.graphics.newQuad(ox + xs[c], oy + ys[r], xs[c + 1] - xs[c], ys[r + 1] - ys[r], W, H)
        end
    end
    quads[key] = q
    return q
end

-- Dibuja un 9-slice en (x, y, w, h) a escala s (los bordes a escala s, el centro estirado)
local function slice(im, q, x, y, w, h, cell, cut, s)
    local l, r, t, b = cut.l * s, cut.r * s, cut.t * s, cut.b * s
    local cw, ch = math.max(0, w - l - r), math.max(0, h - t - b)
    local mw, mh = cell - cut.l - cut.r, cell - cut.t - cut.b
    local xs, ws = { x, x + l, x + w - r }, { s, cw / mw, s }
    local ys, hs = { y, y + t, y + h - b }, { s, ch / mh, s }
    for rr = 1, 3 do
        for cc = 1, 3 do
            love.graphics.draw(im, q[(rr - 1) * 3 + cc], xs[cc], ys[rr], 0, ws[cc], hs[rr])
        end
    end
end

-- Escala entera del texto (como mucho `max`) para que quepa en el ancho w
function MenuButton.textScale(text, w, max)
    local s = max or MenuButton.TEXT
    while s > 2 and PixelFont.width(text, s) > w do s = s - 1 end
    return s
end

function MenuButton.draw(text, x, y, w, h, color, selected, o)
    load()
    o = o or {}
    x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h)
    local a = o.alpha or 1
    local i = meta.index[color] or 1
    local cell = meta.cell
    local q = pieces(sheet, (i - 1) * cell, selected and cell or 0, cell, meta.cut)
    -- sombra negra (el mismo botón, en negro, desplazado)
    love.graphics.setColor(0, 0, 0, 0.45 * a)
    slice(sheet, q, x + SHADOW, y + SHADOW, w, h, cell, meta.cut, MenuButton.S)
    love.graphics.setColor(1, 1, 1, a)
    slice(sheet, q, x, y, w, h, cell, meta.cut, MenuButton.S)
    if text and text ~= '' then
        local inner = w - (meta.cut.l + meta.cut.r + 4) * MenuButton.S
        local iconW = o.icon and (o.iconW or 0) or 0
        local s = o.scale or MenuButton.textScale(text, inner - iconW)
        local tw = PixelFont.width(text, s)
        -- (centrado en la cara del botón: el labio de abajo no cuenta)
        local face = h - (meta.cut.b - meta.cut.t) * MenuButton.S
        local tx = math.floor(x + (w - tw + iconW) / 2)
        local ty = math.floor(y + (face - PixelFont.height(s)) / 2)
        local sc = meta.text[color] and meta.text[color][selected and 'shadow_sel' or 'shadow'] or { 0, 0, 0 }
        PixelFont.draw(text, tx + math.max(2, math.floor(s / 2)), ty + math.max(2, math.floor(s / 2)), s, a,
                       { sc[1] / 255, sc[2] / 255, sc[3] / 255 })
        PixelFont.draw(text, tx, ty, s, a)
        if o.icon then o.icon(tx - iconW, ty, s) end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function MenuButton.panel(x, y, w, h, alpha)
    load()
    local q = pieces(panelImg, 0, 0, meta.cell, { l = 2, r = 2, t = 2, b = 2 })
    love.graphics.setColor(1, 1, 1, alpha or 1)
    slice(panelImg, q, math.floor(x), math.floor(y), math.floor(w), math.floor(h), meta.cell, { l = 2, r = 2, t = 2, b = 2 }, MenuButton.S)
    love.graphics.setColor(1, 1, 1, 1)
end

return MenuButton
