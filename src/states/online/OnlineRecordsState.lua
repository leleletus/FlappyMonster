-- src/states/online/OnlineRecordsState.lua
-- RÉCORDS del modo online (server/srv/records.lua): a la izquierda, el DESAFÍO DEL DÍA y cada nivel con marcas (con la
-- mejor); a la derecha, los 10 mejores tiempos de Carrera del elegido. Se abre desde el menú online (OnlineMenuState) y
-- ATRÁS vuelve a él. Pide al servidor `get_records` (el índice al entrar; la lista de un nivel al elegirlo).
-- Teclado / mando: arriba / abajo eligen, ATRÁS vuelve. Ratón / táctil: tocar un nivel lo elige; VOLVER arriba a la
-- izquierda. Una sola función de geometría (layout) para dibujo y toques.
local BaseState     = require 'src/core/BaseState'
local MenuScene     = require 'src/ui/menu/MenuScene'
local NC            = require 'src/network/NetworkClient'
local L             = require 'src/core/Lang'
local MenuAnim      = require 'src/ui/menu/MenuAnim'
local MenuKit       = require 'src/ui/menu/MenuKit'
local CornerButtons = require 'src/ui/CornerButtons'
local Blocks        = require 'src/network/Blocks'
local fitText       = require('src/ui/TextUtil').fit

local OnlineRecordsState = BaseState:new()

local ROW_H, ROW_GAP = 48, 8

local function mmss(t) return string.format('%d:%05.2f', math.floor(t / 60), t % 60) end
local function nameOf(e) return L.localName and L.localName(e) or e.name end

function OnlineRecordsState:enter()
    self.anim, self.t = MenuAnim.new({ n = 4 }), 0
    self.items, self.sel, self.lists = nil, 1, {}
    NC:on("records", function(d) self:_onRecords(d) end)
    NC:on("connection_lost", function(data)
        gStateMachine:change('online_error', { code = "ERR_CONNECTION_LOST", msg = data.msg or L('err.lost') })
    end)
    NC:send("get_records", {})
end

function OnlineRecordsState:exit() NC:off("records") end

function OnlineRecordsState:_onRecords(d)
    if type(d) ~= 'table' then return end
    if d.index then
        -- (el desafío del día, primero; luego cada nivel con marcas)
        local items = {}
        local dy = d.daily or {}
        if dy.level then
            items[1] = { daily = true, level = dy.level, name = dy.name, name_en = dy.name_en, date = dy.date }
            self.lists['daily'] = dy.list or {}
        end
        for _, e in ipairs(d.index) do items[#items + 1] = { level = e.level, name = e.name, name_en = e.name_en, best = e.best } end
        self.items = items
        self:_pick(1)
    elseif d.level then
        self.lists[d.level] = d.list or {}
    end
end

function OnlineRecordsState:_pick(i)
    if not self.items or not self.items[i] then return end
    self.sel = i
    local it = self.items[i]
    if not it.daily and not self.lists[it.level] then NC:send("get_records", { level = it.level }) end
end

function OnlineRecordsState:_list()
    local it = self.items and self.items[self.sel]
    if not it then return nil end
    return self.lists[it.daily and 'daily' or it.level]
end

function OnlineRecordsState:_back()
    if self.anim:busy() then return end
    Sound.play('select', 0.85)
    self.anim:leave(function() gStateMachine:change('online_menu', { selected = 3 }) end, 4)
end

function OnlineRecordsState:update(dt)
    MenuScene.update(dt)
    self.anim:update(dt)
    self.t = self.t + dt
    if self.anim:busy() then return end
    local n = self.items and #self.items or 0
    if n > 0 then
        if Input.pressed('nav_down') then self:_pick(self.sel % n + 1); Sound.play('select') end
        if Input.pressed('nav_up') then self:_pick((self.sel + n - 2) % n + 1); Sound.play('select') end
    end
    if Input.pressed('back') then self:_back() end
end

-- Geometría: la columna de niveles (con las filas que caben, desplazada para que se vea la elegida) y la tabla
local function layout(self)
    local mx = math.max(40, math.floor(WINDOW_W * 0.06))
    local top, bottom = 168, WINDOW_H - 60
    local lw = math.floor((WINDOW_W - 2 * mx) * 0.42)
    local G = { left = { x = mx, y = top, w = lw, h = bottom - top },
                right = { x = mx + lw + 24, y = top, w = WINDOW_W - 2 * mx - lw - 24, h = bottom - top }, rows = {} }
    local fit = math.max(1, math.floor((G.left.h - 16 + ROW_GAP) / (ROW_H + ROW_GAP)))
    local n = self.items and #self.items or 0
    local first = math.max(1, math.min(self.sel - fit + 1, n - fit + 1))
    first = math.max(1, math.min(first, self.sel))
    for i = first, math.min(n, first + fit - 1) do
        G.rows[i] = { x = G.left.x + 8, y = G.left.y + 8 + (i - first) * (ROW_H + ROW_GAP), w = G.left.w - 16, h = ROW_H }
    end
    return G
end

function OnlineRecordsState:render()
    MenuScene.backdrop('online')
    local A = self.anim
    MenuKit.title(L('records.title'), 'yellow', A, 1)
    local G = layout(self)
    local ox, oy, a = A:slide(2, 0, 220)
    MenuKit.box('well', G.left.x + ox, G.left.y + oy, G.left.w, G.left.h, a)
    if not self.items then
        MenuKit.text(FONT_MED, L('records.loading'), G.left.x + ox, G.left.y + 40 + oy, G.left.w, 'center', { 0.6, 0.66, 0.85 }, a)
    end
    for i, r in pairs(G.rows) do
        local it, on = self.items[i], i == self.sel
        MenuKit.box(on and 'card_sel' or 'card', r.x + ox, r.y + oy, r.w, r.h, a)
        local title = it.daily and L('records.daily') or nameOf(it)
        local col = it.daily and { 1, 0.86, 0.36 } or { 0.9, 0.92, 1 }
        MenuKit.text(FONT_MED, fitText(FONT_MED, title, r.w - 24), r.x + 12 + ox, r.y + 6 + oy, r.w - 24, 'left', col, a)
        local sub = it.daily and nameOf(it) or (it.best and (Blocks.show(it.best.name) .. '  ' .. mmss(it.best.time)) or '')
        MenuKit.text(FONT_SMALL, fitText(FONT_SMALL, sub, r.w - 24), r.x + 12 + ox, r.y + 28 + oy, r.w - 24, 'left', { 0.7, 0.75, 0.92 }, a)
    end
    -- la tabla del elegido
    local rx, ry, ra = A:slide(3, 0, 220)
    local R = G.right
    MenuKit.box('card', R.x + rx, R.y + ry, R.w, R.h, ra)
    local it = self.items and self.items[self.sel]
    if it then
        -- (el desafío: su nombre y la fecha arriba, el nivel debajo)
        local head = it.daily and (L('records.daily') .. '  ' .. (it.date or '')) or nameOf(it)
        MenuKit.text(FONT_MED, fitText(FONT_MED, head, R.w - 32), R.x + 16 + rx, R.y + 16 + ry, R.w - 32, 'center', { 1, 0.86, 0.36 }, ra)
        if it.daily then
            MenuKit.text(FONT_SMALL, fitText(FONT_SMALL, nameOf(it), R.w - 32), R.x + 16 + rx, R.y + 40 + ry, R.w - 32, 'center', { 0.75, 0.8, 0.95 }, ra)
        end
        local list = self:_list()
        if not list then
            MenuKit.text(FONT_SMALL, L('records.loading'), R.x + rx, R.y + 64 + ry, R.w, 'center', { 0.6, 0.66, 0.85 }, ra)
        elseif #list == 0 then
            MenuKit.text(FONT_SMALL, L(it.daily and 'records.daily_empty' or 'records.empty'), R.x + 16 + rx, R.y + 64 + ry, R.w - 32, 'center', { 0.6, 0.66, 0.85 }, ra)
        end
        for k, e in ipairs(list or {}) do
            local y = R.y + 72 + (k - 1) * 30 + ry
            local col = (k == 1) and { 1, 0.86, 0.36 } or ((e.name == NC.myName) and { 0.6, 0.9, 1 } or { 0.9, 0.92, 1 })
            MenuKit.text(FONT_MED, k .. '.', R.x + 16 + rx, y, 48, 'right', col, ra)
            MenuKit.text(FONT_MED, fitText(FONT_MED, Blocks.show(e.name) or '?', R.w - 260), R.x + 76 + rx, y, R.w - 260, 'left', col, ra)
            MenuKit.text(FONT_MED, mmss(e.time or 0), R.x + rx, y, R.w - 20, 'right', col, ra)
        end
    end
    MenuKit.hint(L('records.hint', { move = Input.label('nav_up') .. Input.label('nav_down'), back = Input.label('back') }), A, 4)
    love.graphics.setColor(COLOR_WHITE)
    CornerButtons.drawBack(self.backHover)
end

function OnlineRecordsState:mousemoved(tx, ty) self.backHover = CornerButtons.hitBack(tx, ty) end

function OnlineRecordsState:touchpressed(id, tx, ty)
    if CornerButtons.hitBack(tx, ty) then return self:_back() end
    for i, r in pairs(layout(self).rows) do
        if tx >= r.x and tx <= r.x + r.w and ty >= r.y and ty <= r.y + r.h then self:_pick(i); Sound.play('select'); return end
    end
end

return OnlineRecordsState
