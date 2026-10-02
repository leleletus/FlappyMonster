-- src/states/FreePlayState.lua
-- JUEGO LIBRE (Aventura → SOLO): todos los niveles del juego en una rejilla
-- de tarjetas con scroll (miniatura, nombre, tamaño, monstruos, jefe, agua,
-- objetos, música y los modos online que lo admiten). Se elige uno y se juega
-- en solitario; al salir del nivel se vuelve aquí. Nada se guarda ni se
-- desbloquea: es para probar niveles (beta testers) hasta que exista el mapa
-- del modo historia.
--
-- Escala a muchos niveles: las fichas (src/world/LevelCatalog.lua) se cargan
-- poco a poco (un presupuesto de tiempo por fotograma) y se guardan para la
-- próxima vez; solo se dibujan las tarjetas visibles.
local BaseState     = require 'src/BaseState'
local CornerButtons = require 'src/ui/CornerButtons'
local Clip          = require 'src/ui/Clip'
local PixelIcons    = require 'src/ui/PixelIcons'
local ModeSelectMenu = require 'src/ui/ModeSelectMenu'
local LevelCatalog  = require 'src/world/LevelCatalog'
local Modes         = require 'src/world/Modes'
local fitText       = require('src/ui/TextUtil').fit
local L = require 'src/Lang'

local FreePlayState = BaseState:new()

-- Geometría (alto lógico 720; el ancho cambia según la pantalla: columnas y
-- márgenes se calculan al dibujar, nunca al cargar el archivo)
local TOP, BOTTOM_PAD = 104, 40
local CARD_W, CARD_H, GAP = 372, 318, 24
local PREV_H = 150
local LOAD_BUDGET = 0.008          -- s por fotograma cargando fichas

-- Fichas ya cargadas (entre visitas) y selección recordada
local cache = {}                   -- [archivo] = ficha | { broken = error }
local last = { sel = 1, scroll = 0 }

local imgBg
local function loadAssets()
    if imgBg then return end
    imgBg = love.graphics.newImage('assets/images/menus/MenuDif.png')
end

local function layout()
    local cols = math.max(1, math.floor((WINDOW_W - 48 + GAP) / (CARD_W + GAP)))
    local gridW = cols * CARD_W + (cols - 1) * GAP
    local x0 = math.floor((WINDOW_W - gridW) / 2)
    local viewH = WINDOW_H - TOP - BOTTOM_PAD
    return cols, x0, viewH
end

-- ── Ciclo de vida ─────────────────────────────────────────────────────────────
function FreePlayState:enter()
    loadAssets()
    self.files = LevelCatalog.files()
    self.sel = math.max(1, math.min(#self.files, last.sel))
    self.scroll, self.scrollTarget = last.scroll, last.scroll
    self.t = 0
    self.selAnim = {}
    self.touch = nil
    self:_keepVisible(true)
    Sound.playMusic('menus')
end

function FreePlayState:exit()
    last.sel, last.scroll = self.sel, self.scrollTarget
end

-- Ficha del nivel i (nil mientras se carga)
function FreePlayState:info(i)
    return cache[self.files[i]]
end

-- ── Scroll y selección ────────────────────────────────────────────────────────
function FreePlayState:_maxScroll()
    local cols, _, viewH = layout()
    local rows = math.ceil(#self.files / cols)
    return math.max(0, rows * (CARD_H + GAP) - GAP - viewH + 16)
end

function FreePlayState:_clampScroll()
    self.scrollTarget = math.max(0, math.min(self:_maxScroll(), self.scrollTarget))
end

-- Que la tarjeta elegida se vea entera
function FreePlayState:_keepVisible(instant)
    local cols, _, viewH = layout()
    local row = math.floor((self.sel - 1) / cols)
    local y = row * (CARD_H + GAP)
    if y < self.scrollTarget + 8 then self.scrollTarget = y - 8 end
    if y + CARD_H > self.scrollTarget + viewH - 8 then self.scrollTarget = y + CARD_H - viewH + 8 end
    self:_clampScroll()
    if instant then self.scroll = self.scrollTarget end
end

function FreePlayState:_move(d)
    local n = #self.files
    if n == 0 then return end
    local s = math.max(1, math.min(n, self.sel + d))
    if s ~= self.sel then
        self.sel = s
        Sound.play('select')
        self:_keepVisible()
    end
end

function FreePlayState:_play(i)
    local info = self:info(i)
    if not info or info.broken then return end
    Sound.play('select')
    self.sel = i
    last.sel, last.scroll = self.sel, self.scrollTarget
    gStateMachine:change('adventure', { level = info.path, returnTo = 'free_play' })
end

function FreePlayState:_back()
    Sound.play('select')
    gStateMachine:change('adv_mode_select')
end

-- Tarjeta en el punto (coordenadas lógicas), o nil
function FreePlayState:_cardAt(x, y)
    local cols, x0, viewH = layout()
    if y < TOP or y > TOP + viewH then return nil end
    local cy = y - TOP + self.scroll
    local row = math.floor(cy / (CARD_H + GAP))
    local col = math.floor((x - x0) / (CARD_W + GAP))
    if col < 0 or col >= cols then return nil end
    local lx, ly = x - x0 - col * (CARD_W + GAP), cy - row * (CARD_H + GAP)
    if lx > CARD_W or ly > CARD_H then return nil end
    local i = row * cols + col + 1
    return (i >= 1 and i <= #self.files) and i or nil
end

-- ── Update ────────────────────────────────────────────────────────────────────
function FreePlayState:update(dt)
    self.t = self.t + dt
    -- Cargar fichas pendientes (primero la elegida y las visibles)
    local t0 = love.timer.getTime()
    local cols, _, viewH = layout()
    local firstVis = math.floor(self.scroll / (CARD_H + GAP)) * cols + 1
    local order = { self.sel }
    for i = firstVis, firstVis + cols * (math.ceil(viewH / (CARD_H + GAP)) + 1) do order[#order + 1] = i end
    for i = 1, #self.files do order[#order + 1] = i end
    for _, i in ipairs(order) do
        local f = self.files[i]
        if f and not cache[f] then
            local info, err = LevelCatalog.load(LevelCatalog.DIR .. '/' .. f, f)
            cache[f] = info or { broken = tostring(err), file = f }
            if love.timer.getTime() - t0 > LOAD_BUDGET then break end
        end
    end

    local cols2 = layout()
    if Input.pressed('nav_left')  then self:_move(-1) end
    if Input.pressed('nav_right') then self:_move(1) end
    if Input.pressed('nav_up')    then self:_move(-cols2) end
    if Input.pressed('nav_down')  then self:_move(cols2) end
    if Input.pressed('confirm') or Input.pressed('flap') then self:_play(self.sel) end
    if Input.pressed('back') then self:_back() end

    self:_clampScroll()
    self.scroll = self.scroll + (self.scrollTarget - self.scroll) * math.min(1, dt * 14)
end

-- ── Ratón / táctil ────────────────────────────────────────────────────────────
function FreePlayState:wheelmoved(dx, dy)
    self.scrollTarget = self.scrollTarget - dy * 110
    self:_clampScroll()
end

function FreePlayState:mousemoved(x, y)
    self.backHover = CornerButtons.hitBack(x, y)
    local i = self:_cardAt(x, y)
    if i and i ~= self.sel then self.sel = i; Sound.play('select') end
end

function FreePlayState:touchpressed(id, x, y)
    if CornerButtons.hitBack(x, y) then self:_back(); return end
    if id == 'mouse' then                         -- ratón: clic = jugar (pasar por encima ya elige)
        local i = self:_cardAt(x, y)
        if i then self:_play(i) end
        return
    end
    -- Dedo: se decide al soltar (tocar = elegir / jugar; arrastrar = desplazar)
    self.touch = { id = id, x = x, y = y, lastY = y, dragged = false }
end

function FreePlayState:touchmoved(id, x, y)
    local tc = self.touch
    if not tc or tc.id ~= id then return end
    if math.abs(y - tc.y) > 12 then tc.dragged = true end
    if tc.dragged then
        self.scrollTarget = self.scrollTarget - (y - tc.lastY)
        self.scroll = self.scrollTarget
        self:_clampScroll()
    end
    tc.lastY = y
end

function FreePlayState:touchreleased(id, x, y)
    local tc = self.touch
    if not tc or tc.id ~= id then return end
    self.touch = nil
    if tc.dragged then return end
    local i = self:_cardAt(x, y)
    if not i then return end
    if i == self.sel then self:_play(i) else self.sel = i; Sound.play('select') end
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
local function shadowText(font, s, x, y, col)
    love.graphics.setFont(font)
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.print(s, x + 2, y + 2)
    love.graphics.setColor(col)
    love.graphics.print(s, x, y)
end

local function plural(key, n) return L(n == 1 and (key .. '_one') or key, { n = n }) end

function FreePlayState:drawCard(i, x, y)
    local info = self:info(i)
    local sel = (i == self.sel)
    local a = self.selAnim[i] or 0
    a = a + ((sel and 1 or 0) - a) * math.min(1, love.timer.getDelta() * 12)
    self.selAnim[i] = a
    y = y - math.floor(6 * a)

    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle('fill', x + 6, y + 8, CARD_W, CARD_H)
    love.graphics.setColor(0.08, 0.09, 0.13, 0.97)
    love.graphics.rectangle('fill', x, y, CARD_W, CARD_H)

    local tx, w = x + 12, CARD_W - 24
    if not info then
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.printf(L('free.loading'), x, y + CARD_H / 2 - 5, CARD_W, 'center')
    elseif info.broken then
        shadowText(FONT_MED, fitText(FONT_MED, info.file, w), tx, y + 20, { 1, 0.5, 0.5, 1 })
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(1, 0.6, 0.6, 0.8)
        love.graphics.printf(L('free.broken'), tx, y + 60, w)
    else
        ModeSelectMenu.drawPreview(info, x + 10, y + 10, CARD_W - 20, PREV_H, self.t + i * 1.7, sel and 1 or 0.65)
        local ty = y + PREV_H + 22
        shadowText(FONT_MED, fitText(FONT_MED, L.localName(info), w), tx, ty, sel and { 1, 0.95, 0.3, 1 } or { 0.9, 0.9, 0.9, 1 })
        -- Datos (letra pequeña)
        local lines = {}
        local l1 = { info.w .. 'x' .. info.h, L(info.monsters == 1 and 'msm.monster' or 'msm.monsters', { n = info.monsters }) }
        if info.finish > 0 then l1[#l1 + 1] = L('msm.finish') end
        lines[#lines + 1] = table.concat(l1, ' · ')
        local l2 = {}
        for _, b in ipairs(info.bossNames or {}) do
            l2[#l2 + 1] = L('free.boss', { name = L.bossName(b.type, b.props) or b.type })
        end
        if info.water then l2[#l2 + 1] = L('free.water') end
        if info.floods > 0 then l2[#l2 + 1] = L('free.floods') end
        if info.autoScroll then l2[#l2 + 1] = L('free.autoscroll') end
        if info.pointAreas > 0 then l2[#l2 + 1] = L('free.zones') end
        lines[#lines + 1] = #l2 > 0 and table.concat(l2, ' · ') or L('free.plain')
        local l3 = {}
        if info.stars > 0 then l3[#l3 + 1] = plural('free.stars', info.stars) end
        if info.lives > 0 then l3[#l3 + 1] = plural('free.lives', info.lives) end
        if info.checkpoints > 0 then l3[#l3 + 1] = plural('free.checkpoints', info.checkpoints) end
        if #l3 > 0 then lines[#lines + 1] = table.concat(l3, ' · ') end
        if info.music then lines[#lines + 1] = L('free.music', { name = info.music }) end
        love.graphics.setFont(FONT_SMALL)
        for k, s in ipairs(lines) do
            love.graphics.setColor(1, 1, 1, sel and 0.8 or 0.55)
            love.graphics.print(fitText(FONT_SMALL, s, w), tx, ty + 30 + (k - 1) * 17)
        end
        -- Modos online que lo admiten (icono + nombre, en su color)
        local my = y + CARD_H - 30
        local mx = tx
        if #info.modeList == 0 then
            love.graphics.setColor(1, 1, 1, 0.35)
            love.graphics.print(L('free.no_modes'), mx, my + 6)
        end
        for _, id in ipairs(info.modeList) do
            local m = Modes.get(id)
            local iw, ih = PixelIcons.size(m.icon or '')
            local label = m.label
            local bw = iw * 2 + 10 + FONT_SMALL:getWidth(label) + 12
            if mx + bw > x + CARD_W - 10 then break end
            local c = m.color
            love.graphics.setColor(c[1] * 0.22, c[2] * 0.22, c[3] * 0.22, 1)
            love.graphics.rectangle('fill', mx, my, bw, 24)
            love.graphics.setColor(c[1], c[2], c[3], sel and 1 or 0.6)
            love.graphics.rectangle('line', mx, my, bw, 24)
            if iw > 0 then PixelIcons.draw(m.icon, mx + 6, my + 12 - ih, 2, sel and 1 or 0.6) end
            love.graphics.print(label, mx + 6 + iw * 2 + 6, my + 7)
            mx = mx + bw + 8
        end
    end

    -- Borde
    if sel then
        love.graphics.setColor(1, 0.85, 0, 1)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle('line', x, y, CARD_W, CARD_H)
        love.graphics.setLineWidth(1)
        local p = 0.5 + 0.5 * math.sin(self.t * 6)
        love.graphics.setColor(1, 1, 1, 0.25 + 0.45 * p)
        love.graphics.rectangle('line', x - 5, y - 5, CARD_W + 10, CARD_H + 10)
    else
        love.graphics.setColor(1, 1, 1, 0.22)
        love.graphics.rectangle('line', x, y, CARD_W, CARD_H)
    end
end

function FreePlayState:render()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(imgBg, 0, 0, 0, WINDOW_W / imgBg:getWidth(), WINDOW_H / imgBg:getHeight())
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)

    -- Título
    love.graphics.setFont(FONT_BIG)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.printf(L('free.title'), 3, 25, WINDOW_W, 'center')
    love.graphics.setColor(1, 0.95, 0.15, 1)
    love.graphics.printf(L('free.title'), 0, 22, WINDOW_W, 'center')
    love.graphics.setFont(FONT_SMALL)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.printf(L('free.subtitle', { n = #self.files }), 0, 68, WINDOW_W, 'center')

    local cols, x0, viewH = layout()
    if #self.files == 0 then
        love.graphics.setFont(FONT_MED)
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.printf(L('free.empty'), 0, WINDOW_H / 2, WINDOW_W, 'center')
    end
    -- Tarjetas visibles (recortadas a la zona de la lista)
    Clip.push(0, TOP - 12, WINDOW_W, viewH + 16)
    local rowH = CARD_H + GAP
    local r0 = math.max(0, math.floor((self.scroll - 16) / rowH))
    local r1 = math.floor((self.scroll + viewH) / rowH)
    for row = r0, r1 do
        for col = 0, cols - 1 do
            local i = row * cols + col + 1
            if i <= #self.files then
                self:drawCard(i, x0 + col * (CARD_W + GAP), math.floor(TOP + row * rowH - self.scroll))
            end
        end
    end
    Clip.pop()

    -- Barra de scroll
    local maxS = self:_maxScroll()
    if maxS > 0 then
        local bx = WINDOW_W - 14
        love.graphics.setColor(1, 1, 1, 0.12)
        love.graphics.rectangle('fill', bx, TOP, 6, viewH)
        local bh = math.max(30, viewH * viewH / (viewH + maxS))
        local by = TOP + (viewH - bh) * (self.scroll / maxS)
        love.graphics.setColor(1, 0.85, 0, 0.8)
        love.graphics.rectangle('fill', bx, math.floor(by), 6, math.floor(bh))
    end

    -- Ayuda
    love.graphics.setFont(FONT_SMALL)
    love.graphics.setColor(1, 1, 1, 0.45)
    love.graphics.printf(L('free.hint'), 0, WINDOW_H - 26, WINDOW_W, 'center')
    love.graphics.setColor(1, 1, 1, 1)
    CornerButtons.drawBack(self.backHover)
end

return FreePlayState
