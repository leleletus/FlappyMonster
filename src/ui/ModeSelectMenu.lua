-- src/ui/ModeSelectMenu.lua
-- Menú "MODO DE JUEGO" del lobby de la sala (solo el host).
--   * Arriba, una pestaña por modo (src/world/Modes.lua).
--   * Debajo, el objetivo del modo elegido.
--   * Tarjetas con miniatura de los niveles que admite ese modo; flechas si
--     hay más de las que caben.
-- El catálogo de niveles (con miniaturas) lo envía el servidor ('get_levels'
-- → 'level_catalog'); mientras llega se usa la lista de room_update.

local NC         = require 'src/network/NetworkClient'
local Modes      = require 'src/world/Modes'
local PixelIcons = require 'src/ui/PixelIcons'
local fitText    = require('src/ui/TextUtil').fit

local ModeSelectMenu = {}
ModeSelectMenu.__index = ModeSelectMenu

-- Geometría (resolución lógica 1280x720)
local PX, PY, PW, PH = 50, 36, 1180, 648
local TAB_Y, TAB_H, TAB_GAP = 104, 56, 30
local INFO_Y, INFO_H, INFO_W = 184, 78, 780
local CARD_Y, CARD_W, CARD_H, CARD_GAP = 290, 320, 312, 40
local VISIBLE = 3
local PREV_H  = 206
local ARROW_W, ARROW_H = 36, 110
local PREVIEW_CELL = 6          -- px por celda al cachear la miniatura

local function clamp01(x) return x < 0 and 0 or (x > 1 and 1 or x) end

local function cardsX()
    local total = VISIBLE * CARD_W + (VISIBLE - 1) * CARD_GAP
    return math.floor(WINDOW_W / 2 - total / 2)
end

local function tabRects()
    local n    = #Modes.list
    local w    = math.min(420, math.floor((PW - 80 - (n - 1) * TAB_GAP) / n))
    local x0   = math.floor(WINDOW_W / 2 - (n * w + (n - 1) * TAB_GAP) / 2)
    local list = {}
    for i = 1, n do list[i] = { x = x0 + (i - 1) * (w + TAB_GAP), y = TAB_Y, w = w, h = TAB_H } end
    return list
end

local function inRect(x, y, r) return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end

-- ── Miniaturas ────────────────────────────────────────────────────────────────

local CELL_COLORS = {
    ['#'] = { 0.30, 0.30, 0.36 }, B = { 0.42, 0.30, 0.12 }, X = { 0.85, 0.15, 0.15 },
}
local previewCache = {}   -- [path .. tamaño] = Canvas

local function buildPreviewCanvas(prev)
    local rows = prev.rows
    local nr, nc = #rows, #(rows[1] or '')
    if nr == 0 or nc == 0 then return nil end
    local S = PREVIEW_CELL
    local ok, canvas = pcall(love.graphics.newCanvas, nc * S, nr * S)
    if not ok then return nil end
    canvas:setFilter('nearest', 'nearest')
    love.graphics.push('all')
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    for r = 1, nr do
        local line = rows[r]
        for c = 1, nc do
            local ch = line:sub(c, c)
            local x, y = (c - 1) * S, (r - 1) * S
            local col = CELL_COLORS[ch]
            if col then
                love.graphics.setColor(col)
                love.graphics.rectangle('fill', x, y, S, S)
                -- Borde superior claro donde el terreno da al aire
                if ch == '#' and r > 1 and not CELL_COLORS[rows[r - 1]:sub(c, c)] then
                    love.graphics.setColor(0.62, 0.62, 0.68)
                    love.graphics.rectangle('fill', x, y, S, 1)
                end
            elseif ch == '=' then
                love.graphics.setColor(0.75, 0.72, 0.68)
                love.graphics.rectangle('fill', x, y, S, math.ceil(S / 3))
            elseif ch == '~' then
                love.graphics.setColor(0.20, 0.45, 0.95, 0.75)
                love.graphics.rectangle('fill', x, y, S, S)
            elseif ch == '^' then
                love.graphics.setColor(0.95, 0.95, 0.95)
                love.graphics.polygon('fill', x, y + S, x + S / 2, y + S / 2, x + S, y + S)
            elseif ch == 'F' then
                local h = S / 2
                for i = 0, 1 do for j = 0, 1 do
                    if (i + j) % 2 == 0 then love.graphics.setColor(1, 1, 1) else love.graphics.setColor(0.08, 0.08, 0.1) end
                    love.graphics.rectangle('fill', x + i * h, y + j * h, h, h)
                end end
            end
        end
    end
    -- Entidades (rojo) e inicio (verde)
    for _, e in ipairs(prev.ents or {}) do
        love.graphics.setColor(1, 0.35, 0.35)
        love.graphics.circle('fill', (e[1] - 0.5) * S, (e[2] - 0.5) * S, S * 0.45)
    end
    if prev.start then
        local sx, sy = (prev.start[1] - 0.5) * S, (prev.start[2] - 0.5) * S
        love.graphics.setColor(0.3, 1, 0.45)
        love.graphics.rectangle('fill', sx - S / 2, sy - S / 2, S, S * 1.4)
    end
    love.graphics.pop()
    return canvas
end

-- Dibuja la miniatura dentro de (x,y,w,h): encaja por alto y, si el nivel es
-- más ancho que la tarjeta, se desplaza lentamente de lado a lado.
local function drawPreview(level, x, y, w, h, t, tint)
    -- Cielo
    for i = 0, 7 do
        local f = i / 7
        love.graphics.setColor((0.30 + 0.15 * f) * tint, (0.48 + 0.15 * f) * tint, (0.78 + 0.1 * f) * tint, 1)
        love.graphics.rectangle('fill', x, y + i * h / 8, w, h / 8 + 1)
    end
    local prev = level.preview
    if type(prev) ~= 'table' or type(prev.rows) ~= 'table' then
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(1, 1, 1, 0.5 * tint)
        love.graphics.printf('sin vista previa', x, y + h / 2 - 5, w, 'center')
        return
    end
    local canvas = previewCache[level.path]
    if canvas == nil then
        canvas = buildPreviewCanvas(prev) or false
        previewCache[level.path] = canvas
    end
    if not canvas then return end
    local cw, ch = canvas:getDimensions()
    -- Tamaño de celda en pantalla: que quepa en alto; mínimo 9 px aunque
    -- desborde en ancho (los niveles largos se recorren con desplazamiento)
    local cols, rows = cw / PREVIEW_CELL, ch / PREVIEW_CELL
    local cell = math.min(h / rows, math.max(w / cols, 9))
    local sc   = cell / PREVIEW_CELL
    local lw, lh = cw * sc, ch * sc
    local ox = x + (w - lw) / 2
    if lw > w then
        local span = lw - w
        ox = x - span * (0.5 - 0.5 * math.cos(t * (2 * math.pi) / math.max(6, span / 45)))
    end
    local oy = y + h - lh
    love.graphics.setScissor(x, y, w, h)
    love.graphics.setColor(tint, tint, tint, 1)
    love.graphics.draw(canvas, math.floor(ox), math.floor(oy), 0, sc, sc)
    love.graphics.setScissor()
end

-- ── Ciclo de vida ─────────────────────────────────────────────────────────────

function ModeSelectMenu.new(room)
    local self = setmetatable({}, ModeSelectMenu)
    self.room    = room or {}
    self.catalog = nil
    self.focus   = 'levels'
    self.t       = 0
    self.tab     = 1
    for i, m in ipairs(Modes.list) do if m.id == self.room.mode then self.tab = i end end
    self.tabAnim = self.tab
    self:_resetSelection()
    NC:send('get_levels', {})
    return self
end

function ModeSelectMenu:setCatalog(data)
    if type(data) ~= 'table' or type(data.levels) ~= 'table' then return end
    self.catalog = data.levels
    previewCache = {}         -- el servidor pudo cambiar los niveles
    self:_resetSelection()
end

function ModeSelectMenu:setRoom(room) self.room = room or self.room end

function ModeSelectMenu:mode() return Modes.list[self.tab] end

-- Niveles del modo de la pestaña actual
function ModeSelectMenu:levels()
    local id = self:mode().id
    if self.catalog then
        local out = {}
        for _, l in ipairs(self.catalog) do
            for _, m in ipairs(l.modes or {}) do if m == id then out[#out + 1] = l; break end end
        end
        return out
    end
    -- Sin catálogo aún: la lista de la sala solo vale para su modo actual
    if id == self.room.mode then return self.room.levels or {} end
    return {}
end

function ModeSelectMenu:_resetSelection()
    local list = self:levels()
    self.sel = 1
    for i, l in ipairs(list) do if l.path == self.room.level then self.sel = i end end
    self.first = math.max(1, math.min(self.sel - 1, #list - VISIBLE + 1))
    self.selAnim = {}
end

function ModeSelectMenu:_moveSel(d)
    local n = #self:levels()
    if n == 0 then return end
    self.sel = math.max(1, math.min(n, self.sel + d))
    if self.sel < self.first then self.first = self.sel end
    if self.sel > self.first + VISIBLE - 1 then self.first = self.sel - VISIBLE + 1 end
    Sound.play('select')
end

function ModeSelectMenu:_setTab(i)
    local n = #Modes.list
    i = ((i - 1) % n) + 1
    if i == self.tab then return end
    self.tab = i
    self:_resetSelection()
    Sound.play('select')
end

-- Elige modo + nivel y cierra
function ModeSelectMenu:_confirm()
    local lvl = self:levels()[self.sel]
    if not lvl then return nil end
    NC:send('set_mode', { mode = self:mode().id, level = lvl.path })
    Sound.play('select')
    return 'close'
end

-- Devuelve 'close' cuando el menú debe cerrarse.
function ModeSelectMenu:update(dt)
    self.t = self.t + dt
    self.tabAnim = self.tabAnim + (self.tab - self.tabAnim) * math.min(1, dt * 14)

    if Input.pressed('back') or Input.pressed('pause') then
        if self.focus == 'levels' then self.focus = 'tabs'; Sound.play('select'); return nil end
        Sound.play('select'); return 'close'
    end
    if self.focus == 'tabs' then
        if Input.pressed('nav_left')  then self:_setTab(self.tab - 1) end
        if Input.pressed('nav_right') then self:_setTab(self.tab + 1) end
        if Input.pressed('nav_down') or Input.pressed('confirm') then
            self.focus = 'levels'; Sound.play('select')
        end
    else
        if Input.pressed('nav_left')  then self:_moveSel(-1) end
        if Input.pressed('nav_right') then self:_moveSel(1) end
        if Input.pressed('nav_up')    then self.focus = 'tabs'; Sound.play('select') end
        if Input.pressed('confirm')   then return self:_confirm() end
    end
    return nil
end

-- Toque / clic. Devuelve 'close' si se cierra.
function ModeSelectMenu:touch(x, y)
    for i, r in ipairs(tabRects()) do
        if inRect(x, y, r) then self.focus = 'tabs'; self:_setTab(i); return nil end
    end
    local list = self:levels()
    local cx0  = cardsX()
    for k = 0, VISIBLE - 1 do
        local i = self.first + k
        if list[i] then
            local r = { x = cx0 + k * (CARD_W + CARD_GAP), y = CARD_Y, w = CARD_W, h = CARD_H }
            if inRect(x, y, r) then
                self.focus = 'levels'
                if self.sel == i then return self:_confirm() end
                self.sel = i; Sound.play('select'); return nil
            end
        end
    end
    local ay = CARD_Y + CARD_H / 2 - ARROW_H / 2
    if inRect(x, y, { x = PX + 12, y = ay, w = ARROW_W, h = ARROW_H }) then self:_moveSel(-1); return nil end
    if inRect(x, y, { x = PX + PW - 12 - ARROW_W, y = ay, w = ARROW_W, h = ARROW_H }) then self:_moveSel(1); return nil end
    if not inRect(x, y, { x = PX, y = PY, w = PW, h = PH }) then return 'close' end
    return nil
end

-- ── Render ────────────────────────────────────────────────────────────────────

local function arrow(x, y, w, h, dir, enabled, col)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle('fill', x, y, w, h)
    love.graphics.setColor(col[1], col[2], col[3], enabled and 0.9 or 0.2)
    love.graphics.rectangle('line', x, y, w, h)
    local cx, cy, s = x + w / 2, y + h / 2, 10
    if dir < 0 then
        love.graphics.polygon('fill', cx + s / 2, cy - s, cx - s / 2, cy, cx + s / 2, cy + s)
    else
        love.graphics.polygon('fill', cx - s / 2, cy - s, cx + s / 2, cy, cx - s / 2, cy + s)
    end
end

function ModeSelectMenu:render()
    local t    = self.t
    local mode = self:mode()
    local col  = mode.color
    local appear = clamp01(t / 0.2)

    love.graphics.setColor(0, 0, 0, 0.7 * appear)
    love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)
    love.graphics.setColor(0.04, 0.04, 0.07, 0.96)
    love.graphics.rectangle('fill', PX, PY, PW, PH)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.rectangle('line', PX, PY, PW, PH)
    love.graphics.setColor(col[1], col[2], col[3], 0.35)
    love.graphics.rectangle('line', PX + 3, PY + 3, PW - 6, PH - 6)

    -- Título
    love.graphics.setFont(FONT_BIG)
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.printf('MODO DE JUEGO', 3, PY + 18 + 3, WINDOW_W, 'center')
    love.graphics.setColor(1, 0.95, 0.15, 1)
    love.graphics.printf('MODO DE JUEGO', 0, PY + 18, WINDOW_W, 'center')

    -- Pestañas
    local tabs = tabRects()
    local lineY = TAB_Y + TAB_H
    love.graphics.setColor(col[1], col[2], col[3], 0.6)
    love.graphics.rectangle('fill', PX + 20, lineY, PW - 40, 2)
    for i, r in ipairs(tabs) do
        local m   = Modes.list[i]
        local mc  = m.color
        local on  = (i == self.tab)
        local foc = on and self.focus == 'tabs'
        if on then
            love.graphics.setColor(mc[1] * 0.25, mc[2] * 0.25, mc[3] * 0.25, 1)
            love.graphics.rectangle('fill', r.x, r.y, r.w, r.h + 2)
            love.graphics.setColor(mc[1], mc[2], mc[3], 1)
            love.graphics.rectangle('line', r.x, r.y, r.w, r.h)
            love.graphics.rectangle('fill', r.x, r.y, r.w, 4)
            if foc then
                local p = 0.5 + 0.5 * math.sin(t * 6)
                love.graphics.setColor(1, 1, 1, 0.35 + 0.4 * p)
                love.graphics.rectangle('line', r.x - 4, r.y - 4, r.w + 8, r.h + 8)
            end
        else
            love.graphics.setColor(0, 0, 0, 0.6)
            love.graphics.rectangle('fill', r.x, r.y + 6, r.w, r.h - 6)
            love.graphics.setColor(1, 1, 1, 0.3)
            love.graphics.rectangle('line', r.x, r.y + 6, r.w, r.h - 6)
        end
        local iw, ih = PixelIcons.size(m.icon or '')
        love.graphics.setFont(FONT_MED)
        local label = fitText(FONT_MED, m.label, r.w - 40 - iw * 2)
        local tw = FONT_MED:getWidth(label) + (iw > 0 and iw * 2 + 12 or 0)
        local tx = r.x + r.w / 2 - tw / 2
        local ty = r.y + (on and 0 or 3) + r.h / 2
        if iw > 0 then
            PixelIcons.draw(m.icon, tx, ty - ih, 2, on and 1 or 0.5)
            tx = tx + iw * 2 + 12
        end
        love.graphics.setColor(mc[1], mc[2], mc[3], on and 1 or 0.45)
        love.graphics.print(label, tx, ty - FONT_MED:getHeight() / 2)
    end

    -- Objetivo del modo
    local ix = WINDOW_W / 2 - INFO_W / 2
    love.graphics.setColor(col[1] * 0.12, col[2] * 0.12, col[3] * 0.12, 1)
    love.graphics.rectangle('fill', ix, INFO_Y, INFO_W, INFO_H)
    love.graphics.setColor(col[1], col[2], col[3], 0.7)
    love.graphics.rectangle('line', ix, INFO_Y, INFO_W, INFO_H)
    love.graphics.rectangle('fill', ix, INFO_Y, 4, INFO_H)
    love.graphics.setFont(FONT_MED)
    love.graphics.setColor(col[1], col[2], col[3], 1)
    love.graphics.print('MODO: ' .. mode.label, ix + 20, INFO_Y + 14)
    love.graphics.setFont(FONT_SMALL)
    love.graphics.setColor(1, 1, 1, 0.75)
    local _, lines = FONT_SMALL:getWrap(mode.tagline, INFO_W - 40)
    for li, line in ipairs(lines) do
        love.graphics.print(line, ix + 20, INFO_Y + 38 + (li - 1) * (FONT_SMALL:getHeight() + 6))
    end

    -- Tarjetas de nivel
    local list = self:levels()
    local cx0  = cardsX()
    if #list == 0 then
        love.graphics.setFont(FONT_MED)
        love.graphics.setColor(1, 1, 1, 0.5)
        local msg = self.catalog and 'No hay niveles para este modo' or 'Cargando niveles...'
        love.graphics.printf(msg, 0, CARD_Y + CARD_H / 2 - 10, WINDOW_W, 'center')
        if self.catalog and mode.id == 'race' then
            love.graphics.setFont(FONT_SMALL)
            love.graphics.printf('Crea uno en el editor con el tile "Meta"', 0, CARD_Y + CARD_H / 2 + 20, WINDOW_W, 'center')
        end
    end
    for k = 0, VISIBLE - 1 do
        local i   = self.first + k
        local lvl = list[i]
        if lvl then
            local sel = (i == self.sel)
            local a   = self.selAnim[i] or 0
            a = a + ((sel and 1 or 0) - a) * math.min(1, love.timer.getDelta() * 12)
            self.selAnim[i] = a
            local x = cx0 + k * (CARD_W + CARD_GAP)
            local y = CARD_Y - 8 * a
            local focused = sel and self.focus == 'levels'

            -- Sombra y fondo
            love.graphics.setColor(0, 0, 0, 0.5)
            love.graphics.rectangle('fill', x + 6, y + 8, CARD_W, CARD_H)
            love.graphics.setColor(0.09, 0.09, 0.13, 1)
            love.graphics.rectangle('fill', x, y, CARD_W, CARD_H)

            drawPreview(lvl, x + 10, y + 10, CARD_W - 20, PREV_H, t + i * 1.7, sel and 1 or 0.6)

            -- Nombre y datos
            love.graphics.setFont(FONT_MED)
            love.graphics.setColor(sel and 1 or 0.7, sel and 1 or 0.7, sel and 1 or 0.7, 1)
            love.graphics.print(fitText(FONT_MED, lvl.name or '?', CARD_W - 24), x + 12, y + PREV_H + 26)
            love.graphics.setFont(FONT_SMALL)
            love.graphics.setColor(1, 1, 1, 0.5)
            local info = {}
            if lvl.w and lvl.h then info[#info + 1] = lvl.w .. 'x' .. lvl.h end
            if lvl.enemies then info[#info + 1] = lvl.enemies .. (lvl.enemies == 1 and ' monstruo' or ' monstruos') end
            if (lvl.finish or 0) > 0 then info[#info + 1] = 'meta' end
            love.graphics.print(fitText(FONT_SMALL, table.concat(info, ' · '), CARD_W - 24), x + 12, y + PREV_H + 58)

            -- Nivel en uso
            if lvl.path == self.room.level and mode.id == self.room.mode then
                local bw = FONT_SMALL:getWidth('EN USO') + 16
                love.graphics.setColor(0.3, 1, 0.45, 0.95)
                love.graphics.rectangle('fill', x + CARD_W - bw - 14, y + 16, bw, 20)
                love.graphics.setColor(0, 0, 0, 1)
                love.graphics.print('EN USO', x + CARD_W - bw - 6, y + 21)
            end

            -- Borde
            if sel then
                love.graphics.setColor(col[1], col[2], col[3], 1)
                love.graphics.setLineWidth(3)
                love.graphics.rectangle('line', x, y, CARD_W, CARD_H)
                love.graphics.setLineWidth(1)
                if focused then
                    local p = 0.5 + 0.5 * math.sin(t * 6)
                    love.graphics.setColor(1, 1, 1, 0.3 + 0.5 * p)
                    love.graphics.rectangle('line', x - 5, y - 5, CARD_W + 10, CARD_H + 10)
                end
            else
                love.graphics.setColor(1, 1, 1, 0.25)
                love.graphics.rectangle('line', x, y, CARD_W, CARD_H)
            end
        end
    end

    -- Flechas
    local ay = CARD_Y + CARD_H / 2 - ARROW_H / 2
    if #list > VISIBLE then
        arrow(PX + 12, ay, ARROW_W, ARROW_H, -1, self.first > 1, col)
        arrow(PX + PW - 12 - ARROW_W, ay, ARROW_W, ARROW_H, 1, self.first + VISIBLE - 1 < #list, col)
    end

    -- Ayuda
    love.graphics.setFont(FONT_SMALL)
    love.graphics.setColor(1, 1, 1, 0.4)
    local hint = self.focus == 'tabs'
        and '[<][>] cambiar modo    [ABAJO] elegir nivel    [ESC] cerrar'
        or  '[<][>] elegir nivel    [ARRIBA] cambiar modo    [ENTER] confirmar    [ESC] volver'
    love.graphics.printf(hint, 0, PY + PH - 26, WINDOW_W, 'center')
    love.graphics.setColor(1, 1, 1, 1)
end

return ModeSelectMenu
