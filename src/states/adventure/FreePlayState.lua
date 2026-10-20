-- src/states/adventure/FreePlayState.lua
-- JUEGO LIBRE (Aventura → SOLO): todos los niveles del juego en una rejilla
-- de tarjetas con scroll (miniatura, nombre, tamaño, monstruos, jefe, agua,
-- objetos, música y los modos online que lo admiten). Se elige uno y se juega
-- en solitario; al salir del nivel se vuelve aquí. Nada se guarda ni se
-- desbloquea: es para probar niveles (beta testers) hasta que exista el mapa
-- del modo historia.
--
-- Escala a muchos niveles: las fichas (src/world/level/LevelCatalog.lua) se cargan
-- poco a poco (un presupuesto de tiempo por fotograma) y se guardan para la
-- próxima vez; solo se dibujan las tarjetas visibles.
local BaseState     = require 'src/core/BaseState'
local MenuScene = require 'src/ui/menu/MenuScene'
local CornerButtons = require 'src/ui/CornerButtons'
local Clip          = require 'src/ui/Clip'
local PixelIcons    = require 'src/ui/PixelIcons'
local ModeSelectMenu = require 'src/ui/ModeSelectMenu'
local LevelCatalog  = require 'src/world/level/LevelCatalog'
local Modes         = require 'src/world/modes/Modes'
local fitText       = require('src/ui/TextUtil').fit
local L = require 'src/core/Lang'
local MenuButton    = require 'src/ui/menu/MenuButton'
local MenuKit       = require 'src/ui/menu/MenuKit'
local MenuAnim      = require 'src/ui/menu/MenuAnim'
local PixelFont     = require 'src/ui/PixelFont'

local FreePlayState = BaseState:new()

-- Geometría (alto lógico 720; el ancho cambia según la pantalla: columnas y
-- márgenes se calculan al dibujar, nunca al cargar el archivo)
local TOP_WIDE, TOP_NARROW, BOTTOM_PAD = 152, 204, 56   -- (estrecha: el selector de dificultad va bajo el rótulo)
local CARD_W, CARD_H, GAP = 372, 318, 24
local PREV_H = 150
local LOAD_BUDGET = 0.008          -- s por fotograma cargando fichas

-- Fichas ya cargadas (entre visitas) y selección recordada
local cache = {}                   -- [archivo] = ficha | { broken = error }
local last = { sel = 1, scroll = 0 }

local TOP = TOP_WIDE
local function wide() return WINDOW_W >= 1200 end
local function layout()
    TOP = wide() and TOP_WIDE or TOP_NARROW
    local cols = math.max(1, math.floor((WINDOW_W - 48 + GAP) / (CARD_W + GAP)))
    local gridW = cols * CARD_W + (cols - 1) * GAP
    local x0 = math.floor((WINDOW_W - gridW) / 2)
    local viewH = WINDOW_H - TOP - BOTTOM_PAD
    return cols, x0, viewH
end

-- ── Ciclo de vida ─────────────────────────────────────────────────────────────
function FreePlayState:enter()
    self.files = LevelCatalog.files()
    self.sel = math.max(1, math.min(#self.files, last.sel))
    self.scroll, self.scrollTarget = last.scroll, last.scroll
    self.t, self.diffT = 0, 1
    self.anim = MenuAnim.new()
    self.selAnim = {}
    self.touch = nil
    self.diffFocus = false             -- el selector de dificultad tiene el foco (teclado / mando)
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
    -- (arena de Rey de la Colina: contra el BOT, como los bonus de la historia — src/story/BonusMatch.lua)
    local bonus = (info.pointAreas or 0) > 0 and (info.finish or 0) == 0
                  and { onEnd = function() gStateMachine:change('free_play') end } or nil
    gStateMachine:change('adventure', { level = info.path, returnTo = 'free_play', bonus = bonus, difficulty = last.diff })
end

-- DIFICULTAD con la que se prueban los niveles (src/core/Difficulty.lua): ORIGINAL (ninguna: el juego de siempre) →
-- fácil → normal → difícil → extremo → xtra extremo. Se recuerda entre visitas. Tecla de la linterna (F), tocar
-- la etiqueta de arriba a la derecha, o subir desde la primera fila (foco en el selector: ◀ ▶ la cambian).
local Difficulty = require 'src/core/Difficulty'
local DIFFS = { false }
for _, d in ipairs(Difficulty.ORDER) do DIFFS[#DIFFS + 1] = d end
function FreePlayState:_cycleDifficulty(d)
    d = d or 1
    local cur = last.diff or false
    for i, id in ipairs(DIFFS) do
        if id == cur then last.diff = DIFFS[(i - 1 + d) % #DIFFS + 1]; break end
    end
    if last.diff == false then last.diff = nil end
    self.diffT = 0
    Sound.play('select', d > 0 and 1.08 or 0.94)
end
-- El selector ◀ DIFICULTAD X ▶: arriba a la derecha (o bajo el rótulo, en pantallas estrechas)
function FreePlayState:_diffRect()
    local cols, x0 = layout()
    local w, h = wide() and 340 or 300, 56
    if wide() then return WINDOW_W - 48 - w, 56, w, h end
    return x0 + cols * CARD_W + (cols - 1) * GAP - w, 140, w, h
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
    MenuScene.update(dt)
    self.anim:update(dt)
    self.t, self.diffT = self.t + dt, self.diffT + dt
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
    if self.diffFocus then                        -- foco en el selector: ◀ ▶ la cambian; abajo / confirmar vuelve a la lista
        if Input.pressed('nav_left')  then self:_cycleDifficulty(-1) end
        if Input.pressed('nav_right') then self:_cycleDifficulty(1) end
        if Input.pressed('nav_down') or Input.pressed('confirm') or Input.pressed('flap') then
            self.diffFocus = false; Sound.play('select')
        end
    else
        if Input.pressed('nav_left')  then self:_move(-1) end
        if Input.pressed('nav_right') then self:_move(1) end
        if Input.pressed('nav_up') then
            if self.sel <= cols2 then self.diffFocus = true; Sound.play('select') else self:_move(-cols2) end
        end
        if Input.pressed('nav_down')  then self:_move(cols2) end
        if Input.pressed('confirm') or Input.pressed('flap') then self:_play(self.sel) end
    end
    if Input.pressed('light') then self:_cycleDifficulty() end
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
    local dx, dy, dw, dh = self:_diffRect()
    if x >= dx and x <= dx + dw and y >= dy and y <= dy + dh then self.diffFocus = true; return end
    local i = self:_cardAt(x, y)
    if i then self.diffFocus = false end
    if i and i ~= self.sel then self.sel = i; Sound.play('select') end
end

function FreePlayState:touchpressed(id, x, y)
    if CornerButtons.hitBack(x, y) then self:_back(); return end
    do                                            -- la etiqueta de la dificultad: tocarla pasa a la siguiente
        local dx, dy, dw, dh = self:_diffRect()
        if x >= dx and x <= dx + dw and y >= dy and y <= dy + dh then
            self:_cycleDifficulty(MenuKit.stepperSide({ x = dx, w = dw }, x)); return
        end
    end
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
local function plural(key, n) return L(n == 1 and (key .. '_one') or key, { n = n }) end

-- Pastilla de un modo online: su icono y su nombre sobre su color (como la dificultad en la sala)
local function modePill(m, x, y, a)
    local iw, ih = PixelIcons.size(m.icon or '')
    local label = m.label
    local w = (iw > 0 and iw * 2 + 8 or 0) + FONT_SMALL:getWidth(label) + 16
    local c = m.color
    love.graphics.setColor(0, 0, 0, 0.45 * a)
    love.graphics.rectangle('fill', x + 2, y + 2, w, 24)
    love.graphics.setColor(c[1] * 0.35, c[2] * 0.35, c[3] * 0.35, a)
    love.graphics.rectangle('fill', x, y, w, 24)
    love.graphics.setColor(c[1], c[2], c[3], a)
    love.graphics.rectangle('fill', x, y, w, 2)
    if iw > 0 then PixelIcons.draw(m.icon, x + 8, y + 12 - ih, 2, a) end
    MenuKit.text(FONT_SMALL, label, x + 8 + (iw > 0 and iw * 2 + 8 or 0), y + 7, 400, 'left', { 1, 1, 1 }, a)
    return w
end

function FreePlayState:drawCard(i, x, y)
    local info = self:info(i)
    local sel = (i == self.sel) and not self.diffFocus
    local a = self.selAnim[i] or 0
    a = a + ((sel and 1 or 0) - a) * math.min(1, love.timer.getDelta() * 12)
    self.selAnim[i] = a
    y = y - math.floor(8 * a / 4) * 4

    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle('fill', x + 8, y + 8, CARD_W, CARD_H)
    MenuKit.box(sel and 'card_sel' or 'card', x, y, CARD_W, CARD_H)

    local tx, w = x + 18, CARD_W - 36
    if not info then
        MenuKit.text(FONT_SMALL, L('free.loading'), x, y + CARD_H / 2 - 5, CARD_W, 'center', { 0.6, 0.66, 0.85 })
    elseif info.broken then
        MenuKit.text(FONT_MED, fitText(FONT_MED, info.file, w), tx, y + 20, w, 'left', { 1, 0.5, 0.45 })
        MenuKit.text(FONT_SMALL, L('free.broken'), tx, y + 60, w, 'left', { 1, 0.65, 0.6 })
    else
        MenuKit.box('well', x + 12, y + 12, CARD_W - 24, PREV_H + 8)
        ModeSelectMenu.drawPreview(info, x + 16, y + 16, CARD_W - 32, PREV_H, self.t + i * 1.7, sel and 1 or 0.65)
        local ty = y + PREV_H + 34
        MenuKit.text(FONT_MED, fitText(FONT_MED, L.localName(info), w), tx, ty, w, 'left', sel and { 1, 0.86, 0.36 } or { 0.9, 0.92, 1 })
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
        for k, s in ipairs(lines) do
            MenuKit.text(FONT_SMALL, fitText(FONT_SMALL, s, w), tx, ty + 30 + (k - 1) * 17, w, 'left',
                         sel and { 0.86, 0.9, 1 } or { 0.62, 0.68, 0.86 })
        end
        -- Modos online que lo admiten
        local my, mx = y + CARD_H - 38, tx
        if #info.modeList == 0 then
            MenuKit.text(FONT_SMALL, L('free.no_modes'), mx, my + 7, w, 'left', { 0.5, 0.56, 0.75 })
        end
        for _, id in ipairs(info.modeList) do
            local m = Modes.get(id)
            local iw = PixelIcons.size(m.icon or '')
            if mx + (iw * 2 + 8) + FONT_SMALL:getWidth(m.label) + 16 > x + CARD_W - 14 then break end
            mx = mx + modePill(m, mx, my, sel and 1 or 0.7) + 8
        end
    end
end

function FreePlayState:render()
    MenuScene.backdrop()                 -- (el fondo vivo de los menús: src/ui/menu/MenuScene)
    MenuKit.dim(0.3)
    local A = self.anim

    local cols, x0, viewH = layout()
    -- Rótulo (a la izquierda en pantallas anchas: a la derecha va la dificultad) y el número de niveles
    local hy = MenuKit.title(L('free.title'), 'teal', A, 1, 5)
    local _, soy, sa = A:slide(1, 0, -200, 0, -200)
    local sub = L('free.subtitle', { n = #self.files })
    if wide() then
        MenuKit.text(FONT_SMALL, sub, 0, hy + 14 + soy, WINDOW_W, 'center', { 0.8, 0.85, 1 }, sa)
    else                                          -- (estrecha: a la izquierda, con el selector a la derecha)
        MenuKit.text(FONT_SMALL, sub, x0, 162 + soy, WINDOW_W, 'left', { 0.8, 0.85, 1 }, sa)
    end

    -- Dificultad con la que se probará el nivel: ◀ DIFICULTAD X ▶ (tocar una mitad = esa flecha; [F] = la siguiente)
    do
        local dx, dy, dw, dh = self:_diffRect()
        local _, doy, da = A:slide(2, 0, -200, 0, -200)
        local d = last.diff or 'none'
        local push = (self.diffT < 0.12) and 4 or 0
        local lbl = L('room.difficulty_label')
        PixelFont.shadow(lbl, math.floor(dx + (dw - PixelFont.width(lbl, 2)) / 2), dy - 18 + doy, 2, da, { 1, 0.86, 0.36 })
        MenuKit.stepper(nil, L('difficulty.' .. d), { x = dx, y = dy + doy + push, w = dw, h = dh },
                        Difficulty.COLORS[d] or 'teal', self.diffFocus, { alpha = da, scale = 4 })
        MenuKit.occupy(dx, dy + doy + push, dw, dh)
        if self.diffFocus then MenuKit.marker(dx, dy + doy + push, dw, dh, self.t, da) end
    end

    if #self.files == 0 then
        MenuKit.text(FONT_MED, L('free.empty'), 0, WINDOW_H / 2, WINDOW_W, 'center', { 0.75, 0.8, 0.95 })
    end
    -- Tarjetas visibles (recortadas a la zona de la lista)
    local _, goy = A:slide(3, 0, 220)
    Clip.push(0, TOP - 12, WINDOW_W, viewH + 16)
    local rowH = CARD_H + GAP
    local r0 = math.max(0, math.floor((self.scroll - 16) / rowH))
    local r1 = math.floor((self.scroll + viewH) / rowH)
    for row = r0, r1 do
        for col = 0, cols - 1 do
            local i = row * cols + col + 1
            if i <= #self.files then
                self:drawCard(i, x0 + col * (CARD_W + GAP), math.floor(TOP + row * rowH - self.scroll) + goy)
            end
        end
    end
    Clip.pop()

    -- Barra de scroll: un hueco y su tirador
    local maxS = self:_maxScroll()
    if maxS > 0 then
        local bx = WINDOW_W - 30
        MenuKit.box('well', bx, TOP, 16, viewH)
        local bh = math.max(40, (viewH - 8) * viewH / (viewH + maxS))
        local by = TOP + 4 + (viewH - 8 - bh) * (self.scroll / maxS)
        love.graphics.setColor(1, 0.86, 0.36, 0.95)
        love.graphics.rectangle('fill', bx + 4, math.floor(by / 4) * 4, 8, math.floor(bh))
        love.graphics.setColor(1, 1, 1, 1)
    end

    MenuKit.hint(L('free.hint'), A, 4)
    CornerButtons.drawBack(self.backHover)
end

return FreePlayState
