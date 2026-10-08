-- src/editor/ui.lua
-- Mini toolkit de interfaz "inmediata" para el editor: cada frame se dibujan
-- los widgets y devuelven si se interactuó con ellos. Tema oscuro moderno.

local ui = {}

ui.theme = {
    bg       = { 0.110, 0.122, 0.145 },
    panel    = { 0.145, 0.160, 0.188 },
    panel2   = { 0.180, 0.196, 0.228 },
    border   = { 0.235, 0.255, 0.294 },
    hover    = { 0.235, 0.262, 0.310 },
    accent   = { 0.306, 0.631, 1.000 },
    accentDk = { 0.180, 0.380, 0.640 },
    text     = { 0.870, 0.894, 0.925 },
    muted    = { 0.560, 0.600, 0.660 },
    danger   = { 1.000, 0.420, 0.420 },
    warn     = { 1.000, 0.780, 0.330 },
    ok       = { 0.353, 0.820, 0.541 },
    canvas   = { 0.070, 0.078, 0.094 },
}
local th = ui.theme

local st = {
    mx = 0, my = 0, down = false, pressed = false, released = false,
    rpressed = false, wheel = 0, hot = nil, active = nil, focus = nil,
    tooltip = nil, keys = {}, text = '', scroll = {}, clip = nil,
    consumed = false, sections = {},
}
ui.state = st

function ui.load()
    ui.font   = love.graphics.newFont(13)
    ui.fontSm = love.graphics.newFont(11)
    ui.fontLg = love.graphics.newFont(16)
    ui.fontXl = love.graphics.newFont(22)
end

-- ── Entrada (la alimenta Editor) ─────────────────────────────────────────────
function ui.beginFrame()
    st.mx, st.my = love.mouse.getPosition()
    st.down = love.mouse.isDown(1)
    st.tooltip = nil
    st.consumed = false
end

function ui.endFrame()
    st.pressed, st.released, st.rpressed = false, false, false
    st.wheel = 0
    st.keys = {}
    st.text = ''
    if not st.down then st.active = nil end
end

-- BLOQUEAR la entrada mientras se dibuja lo que queda DETRÁS de una ventana (un menú, un diálogo): lo de detrás se
-- sigue viendo pero no recibe NADA — ni clics, ni rueda, ni arrastres, ni el ratón encima, ni teclas ni texto —, y
-- al desbloquear la ventana se encuentra la entrada intacta. Siempre en pareja: ui.block() … ui.unblock().
local blocks = {}
function ui.block()
    blocks[#blocks + 1] = { st.mx, st.my, st.down, st.pressed, st.released, st.rpressed, st.wheel, st.keys, st.text, st.tooltip }
    st.mx, st.my = -1e6, -1e6
    st.down, st.pressed, st.released, st.rpressed, st.wheel, st.keys, st.text = false, false, false, false, 0, {}, ''
end
function ui.unblock()
    local b = table.remove(blocks)
    if not b then return end
    st.mx, st.my, st.down, st.pressed, st.released, st.rpressed, st.wheel, st.keys, st.text, st.tooltip =
        b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8], b[9], b[10]
end

function ui.mousepressed(b)  if b == 1 then st.pressed = true elseif b == 2 then st.rpressed = true end end
function ui.mousereleased(b) if b == 1 then st.released = true end end
function ui.wheelmoved(y)    st.wheel = st.wheel + y end
function ui.keypressed(k)    st.keys[k] = true end
function ui.textinput(t)     st.text = st.text .. t end

-- ── Utilidades ────────────────────────────────────────────────────────────────
local function inside(x, y, w, h)
    local mx, my = st.mx, st.my
    if st.clip then
        local c = st.clip
        if mx < c[1] or my < c[2] or mx >= c[1] + c[3] or my >= c[2] + c[4] then return false end
    end
    return mx >= x and my >= y and mx < x + w and my < y + h
end
ui.inside = inside

function ui.setColor(c, a) love.graphics.setColor(c[1], c[2], c[3], a or c[4] or 1) end

function ui.rect(x, y, w, h, c, r, mode)
    ui.setColor(c)
    love.graphics.rectangle(mode or 'fill', x, y, w, h, r or 4, r or 4)
end

function ui.text(s, x, y, c, font, w, align)
    love.graphics.setFont(font or ui.font)
    ui.setColor(c or th.text)
    if w then love.graphics.printf(s, math.floor(x), math.floor(y), w, align or 'left')
    else love.graphics.print(s, math.floor(x), math.floor(y)) end
end

function ui.tooltip(s) st.tooltip = s end

-- Etiqueta en una sola línea que quepa en `w`: primero con la letra normal,
-- si no cabe con la pequeña y, si aún no, recortada con "…"
function ui.label(s, x, y, w, c, h)
    h = h or 24
    local f = ui.font
    if f:getWidth(s) > w then f = ui.fontSm end
    local t = s
    if f:getWidth(t) > w then
        while #t > 1 and f:getWidth(t .. '…') > w do
            t = t:sub(1, -2)
            while #t > 0 and t:byte(#t) >= 128 and t:byte(#t) < 192 do t = t:sub(1, -2) end   -- (no partir UTF-8)
            if #t > 0 and t:byte(#t) >= 192 then t = t:sub(1, -2) end
        end
        t = t .. '…'
        if ui.inside(x, y, w, h) and not st.tooltip then st.tooltip = s end
    end
    ui.text(t, x, y + (h - f:getHeight()) / 2, c or th.text, f)
end

-- ¿El ratón está sobre algún área de UI? (para no pintar en el lienzo)
function ui.over(x, y, w, h) return inside(x, y, w, h) end

-- ── Widgets ───────────────────────────────────────────────────────────────────
-- Botón. opts: active, disabled, tooltip, icon(x,y,w,h), color, align,
--        hint (atajo de teclado, a la derecha en pequeño), textColor, font
function ui.button(label, x, y, w, h, opts)
    opts = opts or {}
    local hov = not opts.disabled and inside(x, y, w, h)
    local bg = opts.active and th.accentDk or (hov and th.hover or (opts.color or th.panel2))
    ui.rect(x, y, w, h, bg, 5)
    if opts.active then ui.rect(x, y, w, h, th.accent, 5, 'line') end
    local tx = x
    if opts.icon then
        opts.icon(x + 4, y + 4, h - 8, h - 8)
        tx = x + h
    end
    local hintW = 0
    if opts.hint then
        hintW = ui.fontSm:getWidth(opts.hint) + 10
        ui.text(opts.hint, x + w - hintW + 2, y + (h - ui.fontSm:getHeight()) / 2, th.muted, ui.fontSm)
    end
    if label and label ~= '' then
        local f = opts.font or ui.font
        local c = opts.disabled and th.muted or (opts.textColor or th.text)
        local align = opts.align or ((opts.icon or opts.hint) and 'left' or 'center')
        local pad = (align == 'left' and not opts.icon) and 8 or 0
        ui.text(label, tx + (opts.icon and 2 or 0) + pad, y + (h - f:getHeight()) / 2, c, f,
                w - (tx - x) - (opts.icon and 6 or 0) - hintW - pad, align)
    end
    if hov and opts.tooltip then ui.tooltip(opts.tooltip) end
    if hov and st.pressed then st.consumed = true; return true end
    return false
end

-- Interruptor sí/no
function ui.toggle(label, value, x, y, w)
    local h = 24
    local hov = inside(x, y, w, h)
    ui.label(label, x, y, w - 50, th.text, h)
    local sx = x + w - 42
    ui.rect(sx, y + 3, 40, 18, value and th.accent or th.border, 9)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle('fill', value and (sx + 31) or (sx + 9), y + 12, 7)
    if hov and st.pressed then st.consumed = true; return not value, true end
    return value, false
end

-- Número con - / +, rueda del ratón y shift para pasos x10
function ui.number(label, value, x, y, w, p)
    local h = 24
    local step = p.step or 1
    if love.keyboard.isDown('lshift', 'rshift') then step = step * 10 end
    ui.label(label, x, y, w - 130, th.text, h)
    local bx = x + w - 124
    local changed, nv = false, value
    if ui.button('-', bx, y, 24, h) then nv = value - step; changed = true end
    ui.rect(bx + 26, y, 70, h, th.bg, 4)
    local s = (math.floor(value) == value) and tostring(value) or string.format('%.2f', value)
    ui.text(s, bx + 26, y + 5, th.text, ui.font, 70, 'center')
    if inside(bx + 26, y, 70, h) and st.wheel ~= 0 then nv = value + step * (st.wheel > 0 and 1 or -1); changed = true; st.wheel = 0 end
    if ui.button('+', bx + 98, y, 24, h) then nv = value + step; changed = true end
    if changed then
        if p.min then nv = math.max(p.min, nv) end
        if p.max then nv = math.min(p.max, nv) end
        nv = math.floor(nv / (p.step or 1) + 0.5) * (p.step or 1)
        if p.kind == 'int' then nv = math.floor(nv + 0.5) end
        if nv ~= value then return nv, true end
    end
    if p.help and inside(x, y, w, h) then ui.tooltip(p.help) end
    return value, false
end

-- Selector de opciones: botones segmentados (si caben) o < valor >
function ui.enum(label, value, options, x, y, w)
    local h = 24
    ui.label(label, x, y, w, th.text, h)
    local oy = y + 22
    local fits = #options <= 4
    if fits then
        local bw = (w - (#options - 1) * 4) / #options
        for _, o in ipairs(options) do if ui.fontSm:getWidth(o.label) > bw - 6 then fits = false end end
    end
    if fits then
        local bw = (w - (#options - 1) * 4) / #options
        for i, o in ipairs(options) do
            if ui.button(o.label, x + (i - 1) * (bw + 4), oy, bw, h, { active = o.value == value, font = ui.fontSm }) then
                if o.value ~= value then return o.value, true end
            end
        end
    else
        local idx = 1
        for i, o in ipairs(options) do if o.value == value then idx = i end end
        if ui.button('<', x, oy, 24, h) then return options[(idx - 2) % #options + 1].value, true end
        ui.rect(x + 26, oy, w - 52, h, th.bg, 4)
        ui.text(options[idx].label, x + 26, oy + 5, th.text, ui.font, w - 52, 'center')
        if ui.button('>', x + w - 24, oy, 24, h) then return options[idx % #options + 1].value, true end
    end
    return value, false
end
ui.ENUM_H = 50

-- Campo de texto de una línea
function ui.textField(id, value, x, y, w, maxLen, placeholder)
    local h = 26
    local hov = inside(x, y, w, h)
    if hov and st.pressed then st.focus = id; st.consumed = true
    elseif st.pressed and st.focus == id and not hov then st.focus = nil end
    local focused = st.focus == id
    ui.rect(x, y, w, h, th.bg, 4)
    ui.rect(x, y, w, h, focused and th.accent or th.border, 4, 'line')
    local changed = false
    if focused then
        if st.text ~= '' then value = (value .. st.text):sub(1, maxLen or 64); changed = true end
        if st.keys['backspace'] and #value > 0 then value = value:sub(1, -2); changed = true end
        if st.keys['return'] or st.keys['escape'] then st.focus = nil end
    end
    local caret = (focused and (love.timer.getTime() % 1 < 0.5)) and '|' or ''
    if value == '' and not focused and placeholder then
        ui.text(placeholder, x + 6, y + 6, th.muted)
    else
        ui.text(value .. caret, x + 6, y + 6, th.text)
    end
    return value, changed
end

function ui.hasFocus() return st.focus ~= nil end

-- Alto de un texto envuelto
function ui.textHeight(s, w, font)
    font = font or ui.font
    local _, lines = font:getWrap(s, w)
    return #lines * font:getHeight()
end

-- Cabecera de sección plegable. Devuelve (y siguiente, abierta). El estado
-- (plegada o no) se recuerda por `id`. `right` = texto a la derecha (p. ej.
-- cuántas propiedades tiene).
ui.SECTION_H = 26
function ui.section(id, title, x, y, w, right, defaultOpen)
    local open = st.sections[id]
    if open == nil then open = (defaultOpen ~= false) end
    local h = ui.SECTION_H
    local hov = inside(x - 4, y, w + 8, h)
    ui.rect(x - 4, y, w + 8, h, hov and th.hover or th.panel2, 4)
    -- flecha (triángulo) abierta ▾ / cerrada ▸
    ui.setColor(th.muted)
    local ax, ay = x + 6, y + h / 2
    if open then love.graphics.polygon('fill', ax - 4, ay - 2, ax + 4, ay - 2, ax, ay + 3)
    else love.graphics.polygon('fill', ax - 2, ay - 4, ax - 2, ay + 4, ax + 3, ay) end
    ui.text(title, x + 16, y + (h - ui.font:getHeight()) / 2, th.text, ui.font)
    if right then ui.text(right, x, y + (h - ui.fontSm:getHeight()) / 2, th.muted, ui.fontSm, w - 4, 'right') end
    if hov and st.pressed then open = not open; st.consumed = true end
    st.sections[id] = open
    return y + h + 6, open
end

-- Pestañas: devuelve la elegida. tabs = { {id, label, badge?, badgeColor?} }
function ui.tabs(tabs, value, x, y, w, h)
    h = h or 30
    local tw = w / #tabs
    ui.rect(x, y + h - 1, w, 1, th.border, 0)
    for i, t in ipairs(tabs) do
        local tx = x + (i - 1) * tw
        local sel = t.id == value
        local hov = inside(tx, y, tw, h)
        if sel or hov then ui.rect(tx + 2, y, tw - 4, h - 1, sel and th.panel2 or th.hover, 4) end
        if sel then ui.rect(tx + 2, y + h - 3, tw - 4, 3, th.accent, 1) end
        local label = t.label
        local f = ui.font
        local lw = f:getWidth(label)
        local bw = t.badge and (ui.fontSm:getWidth(tostring(t.badge)) + 10) or 0
        local lx = tx + (tw - lw - (bw > 0 and bw + 4 or 0)) / 2
        ui.text(label, lx, y + (h - f:getHeight()) / 2, sel and th.text or th.muted, f)
        if t.badge then
            ui.rect(lx + lw + 4, y + h / 2 - 8, bw, 16, t.badgeColor or th.border, 8)
            ui.text(tostring(t.badge), lx + lw + 4, y + h / 2 - 7, th.bg, ui.fontSm, bw, 'center')
        end
        if hov and st.pressed then value = t.id; st.consumed = true end
    end
    return value
end

-- Tarjeta de ayuda (texto apagado con un borde a la izquierda). Devuelve el alto.
function ui.hint(s, x, y, w, color)
    local hgt = ui.textHeight(s, w - 14, ui.fontSm) + 10
    ui.rect(x, y, w, hgt, th.panel2, 4)
    ui.rect(x, y, 3, hgt, color or th.accentDk, 1)
    ui.text(s, x + 10, y + 5, th.muted, ui.fontSm, w - 14)
    return hgt
end

-- Separador con título pequeño en mayúsculas
function ui.caption(s, x, y, w)
    ui.text(s:upper(), x, y, th.muted, ui.fontSm)
    ui.rect(x, y + 16, w, 1, th.border, 0)
    return y + 24
end

-- Región con scroll: devuelve y desplazado. Llamar ui.endScroll() al final.
function ui.beginScroll(id, x, y, w, h, contentH)
    local off = st.scroll[id] or 0
    if inside(x, y, w, h) and st.wheel ~= 0 then
        off = off - st.wheel * 40; st.wheel = 0
    end
    -- barra: se arrastra con el ratón (o un clic en su carril lleva ahí)
    local sid = 'scrollbar:' .. id
    local BW = 12
    if contentH > h then
        local bh = math.max(24, h * h / contentH)
        if st.pressed and not st.consumed and inside(x + w - BW, y, BW, h) then st.active = sid; st.consumed = true end
        if st.active == sid and st.down then
            off = (st.my - y - bh / 2) / math.max(1, h - bh) * (contentH - h)
        end
    end
    off = math.max(0, math.min(off, math.max(0, contentH - h)))
    st.scroll[id] = off
    st.clip = { x, y, w, h }
    love.graphics.setScissor(x, y, w, h)
    if contentH > h then
        local bh = math.max(24, h * h / contentH)
        local by = y + (h - bh) * (off / (contentH - h))
        local hot = st.active == sid or inside(x + w - BW, y, BW, h)
        ui.rect(x + w - BW + 2, y, BW - 4, h, { 0, 0, 0, 0.18 }, 3)
        ui.rect(x + w - BW + 2, by, BW - 4, bh, hot and th.accent or th.border, 3)
    end
    return y - off
end

function ui.endScroll()
    st.clip = nil
    love.graphics.setScissor()
end

function ui.drawTooltip()
    if not st.tooltip then return end
    local f = ui.fontSm
    local w = math.min(320, f:getWidth(st.tooltip) + 16)
    local _, lines = f:getWrap(st.tooltip, w - 16)
    local h = #lines * f:getHeight() + 10
    local x = math.min(st.mx + 14, love.graphics.getWidth() - w - 4)
    local y = math.min(st.my + 18, love.graphics.getHeight() - h - 4)
    ui.rect(x, y, w, h, { 0.05, 0.06, 0.07, 0.95 }, 4)
    ui.rect(x, y, w, h, th.border, 4, 'line')
    ui.text(st.tooltip, x + 8, y + 5, th.text, f, w - 16)
end

return ui
