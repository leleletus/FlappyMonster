-- src/states/menu/SettingsState.lua
-- CONFIGURACIÓN (rehecha en 0.5.197; el diseño y lo que pidió el usuario: docs/design/settings-menu-rework.md).
-- Sobre un fondo A CUADROS que se desliza: el rótulo, cuatro PESTAÑAS (audio, controles, juego, otros) y un panel con
-- las FILAS de la pestaña — todas iguales: el nombre a la izquierda y su control a la derecha (barra de volumen,
-- interruptor, `< valor >`, o una acción) —; abajo, qué hace la elegida y los botones. Las opciones son DATOS
-- (src/ui/menu/SettingsRows.lua); se guardan como siempre (src/core/Settings.lua).
--   Teclado / mando: arriba / abajo las filas (arriba desde la primera = la barra de pestañas); izquierda / derecha
--   cambian el valor (en la barra, la pestaña); confirmar cambia un interruptor, avanza una elección o hace la acción;
--   tab_prev / tab_next (Q / E / Tab, L / R) cambian de pestaña desde donde sea; atrás vuelve al menú principal.
--   Ratón: pasar por encima elige la fila; clic en su control lo cambia. Táctil: tocar una fila sin elegir solo la
--   elige (sin cambiar nada); tocarla otra vez cambia su control (mitad izquierda baja / mitad derecha sube).
--   enter({ tab = id, row = id }) abre en esa fila (al volver de los créditos).
local CornerButtons = require 'src/ui/CornerButtons'
local BaseState     = require 'src/core/BaseState'
local MenuAnim      = require 'src/ui/menu/MenuAnim'
local MenuList      = require 'src/ui/menu/MenuList'
local MenuButton    = require 'src/ui/menu/MenuButton'
local Clip          = require 'src/ui/Clip'
local Rows          = require 'src/ui/menu/SettingsRows'
local L             = require 'src/core/Lang'
local SettingsState = BaseState:new()

local ART = 'assets/images/ui/settings/'
local SC = 4                                  -- escala del arte (píxeles del arte → de pantalla)
local ROW_H, ROW_GAP, TAB_H, PAD = 60, 6, 52, 16
local CTRL_W = 300                            -- ancho de la zona del control, a la derecha de la fila
local art

local function loadArt()
    if art then return art end
    local function im(n) local i = love.graphics.newImage(ART .. n); i:setFilter('nearest', 'nearest'); return i end
    art = { checker = im('checker.png'), switch = im('switch-Sheet.png'), bar = im('bar-Sheet.png') }
    art.checker:setWrap('repeat', 'repeat')
    local function quads(img, n)
        local w, h = img:getWidth() / n, img:getHeight()
        local q = {}
        for i = 1, n do q[i] = love.graphics.newQuad((i - 1) * w, 0, w, h, img:getDimensions()) end
        return q, w, h
    end
    art.swQ, art.swW, art.swH = quads(art.switch, 2)
    art.barQ, art.barW, art.barH = quads(art.bar, 2)
    art.bg = love.graphics.newQuad(0, 0, 1, 1, 32, 32)
    return art
end

SettingsState.ROWS = Rows.TABS              -- (los arneses miran las filas desde aquí)

local function tabOf(self) return Rows.TABS[self.tab] end
local function rowOf(self) local t = tabOf(self); return t and t.rows[self.row] end

-- Geometría (una para dibujo, ratón y táctil), calculada cada vez con el tamaño de ahora
function SettingsState:layout()
    local w = math.min(940, WINDOW_W - 80)
    local x = math.floor((WINDOW_W - w) / 2)
    local ty = MenuList.headerBottom(L('menu.settings')) + 28   -- (el hueco entre el rótulo y las pestañas: el usuario)
    local out = { tabs = {}, rows = {} }
    local n = #Rows.TABS
    local tw = math.floor((w - (n - 1) * 8) / n)
    for i = 1, n do out.tabs[i] = { x = x + (i - 1) * (tw + 8), y = ty, w = tw, h = TAB_H } end
    local py = ty + TAB_H + 12
    local rows = tabOf(self).rows
    -- (el panel, del alto de sus filas; como mucho hasta el pie)
    local want = 2 * PAD + #rows * ROW_H + (#rows - 1) * ROW_GAP
    local ph = math.max(ROW_H + 2 * PAD, math.min(want, WINDOW_H - 128 - py))
    out.panel = { x = x, y = py, w = w, h = ph }
    out.fit = math.max(1, math.floor((ph - 2 * PAD + ROW_GAP) / (ROW_H + ROW_GAP)))
    local first = self.first or 1
    local rw = w - 2 * PAD - ((#rows > out.fit) and 18 or 0)
    for i = first, math.min(#rows, first + out.fit - 1) do
        out.rows[i] = { x = x + PAD, y = py + PAD + (i - first) * (ROW_H + ROW_GAP), w = rw, h = ROW_H }
    end
    if #rows > out.fit then
        out.scroll = { x = x + w - PAD - 8, y = py + PAD, w = 8, h = ph - 2 * PAD }
    end
    out.first = first
    return out
end

-- La zona del control dentro de una fila
local function ctrlRect(r) return { x = r.x + r.w - CTRL_W - 12, y = r.y, w = CTRL_W, h = r.h } end

function SettingsState:enter(args)
    args = args or {}
    self.anim = MenuAnim.new({ n = 5 })
    self.t, self.tab, self.row, self.first, self.kick = 0, 1, 1, 1, nil
    for i, t in ipairs(Rows.TABS) do
        if t.id == args.tab then
            self.tab = i
            for j, r in ipairs(t.rows) do if r.id == args.row then self.row = j end end
        end
    end
    self:_keepVisible()
    Sound.playMusic('menus')
end

-- La fila elegida, siempre entera dentro del panel
function SettingsState:_keepVisible()
    local fit = self:layout().fit
    local n = #tabOf(self).rows
    if self.row > n then self.row = n end
    if self.row >= 1 then
        if self.row < self.first then self.first = self.row end
        if self.row >= self.first + fit then self.first = self.row - fit + 1 end
    end
    self.first = math.max(1, math.min(self.first, math.max(1, n - fit + 1)))
end

function SettingsState:_setTab(i)
    local n = #Rows.TABS
    i = (i - 1) % n + 1
    if i ~= self.tab then Sound.play('select') end
    self.tab, self.first = i, 1
    if self.row ~= 0 then self.row = 1 end
    self:_keepVisible()
end

function SettingsState:_selectRow(i)
    local n = #tabOf(self).rows
    i = math.max(0, math.min(n, i))
    if i ~= self.row then Sound.play('select') end
    self.row = i
    self:_keepVisible()
end

function SettingsState:_step(d)
    local r = rowOf(self)
    if not r then return end
    if r.step then r.step(d) elseif r.go then return r.go(self) end
    self.kick = { d = d, t = 0 }
end

function SettingsState:_go()
    local r = rowOf(self)
    if not r then return end
    if r.go then return r.go(self) end
    if r.step then self:_step(1) end
end

-- Los créditos (y de vuelta aquí, en su fila)
function SettingsState:_credits()
    Sound.play('select', 1.25)
    self.anim:leave(function() end, 5)
    require('src/ui/menu/Transition').go('story_film', { film = 'credits',
        onDone = function() gStateMachine:change('settings', { tab = 'other', row = 'credits' }) end })
end

function SettingsState:_back()
    if self.anim:busy() then return end
    Sound.play('select', 0.85)
    self.anim:leave(function() gStateMachine:change('main_menu', { select = 'settings' }) end, 5)
end

function SettingsState:update(dt)
    self.t = self.t + dt
    if self.kick then self.kick.t = self.kick.t + dt end
    self.anim:update(dt)
    if self.anim:busy() then return end
    if Input.pressed('back') then return self:_back() end
    if Input.pressed('tab_prev') then self:_setTab(self.tab - 1) end
    if Input.pressed('tab_next') then self:_setTab(self.tab + 1) end
    local n = #tabOf(self).rows
    if Input.pressed('nav_down') then
        if self.row >= n then self:_selectRow(0) else self:_selectRow(self.row + 1) end
    end
    if Input.pressed('nav_up') then
        if self.row == 0 then self:_selectRow(n) else self:_selectRow(self.row - 1) end
    end
    if self.row == 0 then
        if Input.pressed('nav_left') then self:_setTab(self.tab - 1) end
        if Input.pressed('nav_right') then self:_setTab(self.tab + 1) end
        if Input.pressed('confirm') then self:_selectRow(1) end
        return
    end
    if Input.pressed('nav_left') then self:_step(-1) end
    if Input.pressed('nav_right') then self:_step(1) end
    if Input.pressed('confirm') then return self:_go() end
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
local GOLD, INK, TEXT, DIM = { 1, 0.84, 0.38 }, { 0.13, 0.12, 0.2 }, { 0.93, 0.93, 0.97 }, { 0.6, 0.62, 0.74 }

local function drawBackground(A)
    local s = SC
    local off = math.floor(love.timer.getTime() * 12) % 32
    A.bg:setViewport(off, off, math.ceil(WINDOW_W / s) + 1, math.ceil(WINDOW_H / s) + 1, 32, 32)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(A.checker, A.bg, 0, 0, 0, s, s)
end

local function drawControl(self, r, row, sel, a)
    local A = art
    local c = ctrlRect(r)
    local cy = math.floor(c.y + c.h / 2)
    local v = row.value()
    love.graphics.setFont(FONT_MED)
    local fh = FONT_MED:getHeight()
    if row.kind == 'volume' then
        local bw, bh = A.barW * SC, A.barH * SC
        local gap = 2
        local num = tostring(v)
        local total = 10 * (bw + gap) - gap
        local bx = c.x + c.w - total - 56
        for i = 1, 10 do
            love.graphics.setColor(1, 1, 1, a)
            love.graphics.draw(A.bar, A.barQ[i <= v and 2 or 1], bx + (i - 1) * (bw + gap), cy - math.floor(bh / 2), 0, SC, SC)
        end
        love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], a)
        love.graphics.printf(num, c.x + c.w - 48, cy - math.floor(fh / 2), 48, 'right')
    elseif row.kind == 'switch' then
        local sw, sh = A.swW * SC, A.swH * SC
        love.graphics.setColor(1, 1, 1, a)
        love.graphics.draw(A.switch, A.swQ[v and 2 or 1], c.x + c.w - sw, cy - math.floor(sh / 2), 0, SC, SC)
    elseif row.kind == 'choice' or row.kind == 'number' then
        local txt = tostring(v)
        if row.kind == 'number' then txt = (v > 0 and '+' or '') .. txt end
        local aw = FONT_MED:getWidth('<')
        local col = sel and GOLD or DIM
        love.graphics.setColor(col[1], col[2], col[3], a)
        love.graphics.print('<', c.x, cy - math.floor(fh / 2))
        love.graphics.print('>', c.x + c.w - aw, cy - math.floor(fh / 2))
        love.graphics.setColor(TEXT[1], TEXT[2], TEXT[3], a)
        love.graphics.printf(txt, c.x + aw, cy - math.floor(fh / 2), c.w - 2 * aw, 'center')
    elseif row.kind == 'action' then
        local col = sel and GOLD or DIM
        love.graphics.setColor(col[1], col[2], col[3], a)
        love.graphics.printf('>', c.x, cy - math.floor(fh / 2), c.w, 'right')
    end
end

function SettingsState:render()
    loadArt()
    drawBackground(art)
    MenuList.header(L('menu.settings'), 'blue', self.anim, 1)
    local Lt = self:layout()
    local A = self.anim
    -- pestañas (la elegida, dorada y un poco más arriba; con la barra elegida, además con el borde dorado)
    local tx, tyo, ta = A:slide(2, 0, -160)
    for i, b in ipairs(Lt.tabs) do
        local on = i == self.tab
        local lift = on and -6 or 0
        MenuButton.draw(L(Rows.TABS[i].label), b.x + tx, b.y + tyo + lift, b.w, b.h, on and 'yellow' or 'blue',
                        on and self.row == 0, { alpha = ta, scale = MenuButton.textScale(L(Rows.TABS[i].label), b.w - 40, 4) })
    end
    -- el panel y sus filas
    local px, py, pa = A:slide(3, 0, 220)
    local P = Lt.panel
    MenuButton.panel(P.x + px, P.y + py, P.w, P.h, 0.96 * pa)
    Clip.push(P.x + px, P.y + py, P.w, P.h)
    local rows = tabOf(self).rows
    for i, r in pairs(Lt.rows) do
        local row = rows[i]
        local sel = i == self.row
        local kx = (sel and self.kick and self.kick.t < 0.12) and self.kick.d * 4 or 0
        local x, y = r.x + px, r.y + py
        local rr = { x = x + kx, y = y, w = r.w, h = r.h }
        if sel then
            love.graphics.setColor(0.26, 0.26, 0.42, pa)
            love.graphics.rectangle('fill', rr.x, rr.y, rr.w, rr.h)
            love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], pa)
            local b = 3
            love.graphics.rectangle('fill', rr.x, rr.y, rr.w, b)
            love.graphics.rectangle('fill', rr.x, rr.y + rr.h - b, rr.w, b)
            love.graphics.rectangle('fill', rr.x, rr.y, b, rr.h)
            love.graphics.rectangle('fill', rr.x + rr.w - b, rr.y, b, rr.h)
        else
            love.graphics.setColor(0.16, 0.16, 0.27, 0.9 * pa)
            love.graphics.rectangle('fill', rr.x, rr.y, rr.w, rr.h)
        end
        love.graphics.setFont(FONT_MED)
        local col = sel and { 1, 1, 1 } or TEXT
        love.graphics.setColor(col[1], col[2], col[3], pa)
        love.graphics.print(L(row.label), rr.x + 20, math.floor(rr.y + (rr.h - FONT_MED:getHeight()) / 2))
        drawControl(self, rr, row, sel, pa)
    end
    Clip.pop()
    -- barra de desplazamiento (solo si la pestaña no cabe)
    if Lt.scroll then
        local s = Lt.scroll
        love.graphics.setColor(0.16, 0.16, 0.27, pa)
        love.graphics.rectangle('fill', s.x + px, s.y + py, s.w, s.h)
        local n = #rows
        local th = math.max(24, math.floor(s.h * Lt.fit / n))
        local ty = s.y + math.floor((s.h - th) * (Lt.first - 1) / math.max(1, n - Lt.fit))
        love.graphics.setColor(DIM[1], DIM[2], DIM[3], pa)
        love.graphics.rectangle('fill', s.x + px, ty + py, s.w, th)
    end
    local r = rowOf(self)
    MenuList.footer(r and L(r.desc) or L('menu.desc_settings'), A, 4,
        L('settings.hint_tabs', { change = Input.label('nav_left') .. Input.label('nav_right'),
                                  tabs = Input.label('tab_prev') .. Input.label('tab_next'), back = Input.label('back') }))
    love.graphics.setColor(1, 1, 1, 1)
    CornerButtons.drawBack(self.backHover)
end

-- ── Ratón y táctil ──────────────────────────────────────────────────────────
local function inside(r, x, y) return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end

function SettingsState:mousemoved(x, y)
    self.backHover = CornerButtons.hitBack(x, y)
    local Lt = self:layout()
    for i, r in pairs(Lt.rows) do if inside(r, x, y) and i ~= self.row then self.row = i end end
end

-- Un toque (o un clic: game.lua manda el ratón como touchpressed 'mouse')
function SettingsState:touchpressed(id, x, y)
    if self.anim:busy() then return end
    if CornerButtons.hitBack(x, y) then return self:_back() end
    local Lt = self:layout()
    for i, b in ipairs(Lt.tabs) do
        if inside(b, x, y) then self:_setTab(i); if self.row == 0 then self.row = 1 end; return end
    end
    for i, r in pairs(Lt.rows) do
        if inside(r, x, y) then
            if i ~= self.row and id ~= 'mouse' then return self:_selectRow(i) end   -- (el 1er toque solo elige)
            self.row = i
            local row = rowOf(self)
            if row.kind == 'switch' or row.kind == 'action' then return self:_go() end
            local c = ctrlRect(r)
            return self:_step((x < c.x + c.w / 2) and -1 or 1)
        end
    end
end

return SettingsState
