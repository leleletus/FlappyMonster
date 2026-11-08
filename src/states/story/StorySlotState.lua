-- src/states/story/StorySlotState.lua
-- Elegir PARTIDA de una campaña: la historia de Aventura (src/story/Save.lua) o la campaña Flappy
-- (src/flappy/FlappySave.lua) — `args.campaign` ('story' por defecto); lo propio de cada una sale de su descriptor
-- (src/story/Campaigns.lua) —. Tres huecos; uno vacío empieza una partida nueva, uno usado continúa donde iba (mundo,
-- progreso, vidas). BORRAR pide confirmar.
-- Cada partida es un CARTUCHO (assets/images/ui/menus/cartridge.png, tools/art/ui/make_menu_ui.py; docs/architecture/
-- menus.md): en fila, con su etiqueta — la isla donde va (cart_labels.png), el mundo, el progreso, la dificultad, las
-- vidas y el tiempo — y el número arriba; el elegido sube y bota. Al jugar, el cartucho "se mete" (baja) y se pasa
-- con el iris. BORRAR es un botón DEBAJO del cartucho elegido (nunca encima de su información).
-- Flechas / ratón / toque; ENTER entra; SUPR (o el botón) borra; ESC vuelve.
local BaseState     = require 'src/core/BaseState'
local MenuKit = require 'src/ui/menu/MenuKit'
local MenuScene     = require 'src/ui/menu/MenuScene'
local MenuAnim      = require 'src/ui/menu/MenuAnim'
local MenuList      = require 'src/ui/menu/MenuList'
local MenuButton    = require 'src/ui/menu/MenuButton'
local Transition    = require 'src/ui/menu/Transition'
local CornerButtons = require 'src/ui/CornerButtons'
local PixelFont     = require 'src/ui/PixelFont'
local Campaigns     = require 'src/story/Campaigns'
local SLOTS         = 3                  -- (huecos de cada campaña: SLOTS = FlappySLOTS)
local Difficulty    = require 'src/core/Difficulty'
local json          = require 'libs/json'
local L = require 'src/core/Lang'

local StorySlotState = BaseState:new()

local CART_S = 4                         -- escala del cartucho (60 x 72 → 240 x 288)
local GAP = 36                           -- px entre cartuchos
local LIFT = 20                          -- px que sube el elegido
local INSERT_T = 0.28                    -- s que tarda en "meterse" al jugar
local DIFF_COLORS = require('src/core/Difficulty').COLORS

local art
local function loadArt()
    if art then return art end
    local im = love.graphics.newImage('assets/images/ui/menus/cartridge.png')
    local lb = love.graphics.newImage('assets/images/ui/menus/cart_labels.png')
    local m = json.decode(love.filesystem.read('assets/images/ui/menus/cartridge.json'))
    art = { img = im, labels = lb, m = m, shells = {}, scenes = {} }
    for i, n in ipairs(m.shells) do
        art.shells[n] = { love.graphics.newQuad((i - 1) * m.w, 0, m.w, m.h, im:getDimensions()),
                          love.graphics.newQuad((i - 1) * m.w, m.h, m.w, m.h, im:getDimensions()) }
    end
    for i, k in ipairs(m.scenes) do
        art.scenes[k] = love.graphics.newQuad((i - 1) * m.window[3], 0, m.window[3], m.window[4], lb:getDimensions())
    end
    return art
end
local SHELL = { 'red', 'blue', 'green' }

-- Geometría (dibujo, ratón y táctil): el cartucho i y su botón BORRAR debajo
local function cartRect(i)
    local a = loadArt()
    local w, h = a.m.w * CART_S, a.m.h * CART_S
    local s = CART_S
    -- (en pantallas estrechas, una escala menos)
    if SLOTS * w + (SLOTS - 1) * GAP > WINDOW_W - 40 then s = CART_S - 1; w, h = a.m.w * s, a.m.h * s end
    local total = SLOTS * w + (SLOTS - 1) * GAP
    local x0 = math.floor((WINDOW_W - total) / 2)
    return x0 + (i - 1) * (w + GAP), math.floor(WINDOW_H * 0.24), w, h, s
end
-- (bajo el cartucho elegido, dos botones: COPIAR a la izquierda y BORRAR a la derecha)
local function delRect(i)
    local x, y, w, h = cartRect(i)
    local bw, bh = math.floor(math.min(w, 320) / 2) - 6, 52
    return math.floor(x + w / 2 + 6), y + h + 22, bw, bh
end
local function copyRect(i)
    local x, y, w, h = cartRect(i)
    local bw, bh = math.floor(math.min(w, 320) / 2) - 6, 52
    return math.floor(x + w / 2 - 6 - bw), y + h + 22, bw, bh
end
local function inside(px, py, x, y, w, h) return px >= x and px <= x + w and py >= y and py <= y + h end

local function pickRect(k)
    local w, h, gap = math.min(560, WINDOW_W - 160), 60, 12
    local total = #Difficulty.ORDER * h + (#Difficulty.ORDER - 1) * gap
    return math.floor((WINDOW_W - w) / 2), math.floor(WINDOW_H * 0.27) + (k - 1) * (h + gap), w, h
end

function StorySlotState:enter(args)
    self.c = Campaigns.get(args and args.campaign)
    self.c.run.close()
    self.sel = self.sel or 1
    self.confirm = nil                       -- hueco que se está a punto de borrar
    self.t = 0
    self.anim = MenuAnim.new({ n = 6 })
    self:reload()
    Sound.playMusic('menus')
end

function StorySlotState:reload()
    self.slots = {}
    for i = 1, SLOTS do
        local R = self.c.run
        local d = self.c.saves.load(i)
        if d then
            local saved, run = R.slot, R.data
            R.slot, R.data = i, d
            local done, total = R.progress()
            local w = R.frontier()
            R.slot, R.data = saved, run
            local sh, shT
            if self.c.shards then sh, shT = self.c.shards(d) end
            self.slots[i] = { data = d, done = done, total = total, world = w, shards = sh, shardsTotal = shT }
        else
            self.slots[i] = false
        end
    end
end

-- Un hueco usado continúa; uno vacío pregunta antes la DIFICULTAD (src/core/Difficulty.lua): Fácil,
-- Normal y Difícil desde el principio; Extremo y Xtra extremo, cerradas hasta desbloquearlas
function StorySlotState:_open(i)
    if self.inserting then return end
    Sound.play('select', 1.2)
    if not self.slots[i] and not self.pick then
        self.unlocked = self.c.unlocked()
        self.pick = { slot = i, sel = 2, t = 0 }
        return
    end
    local new = not self.slots[i]
    self.c.run.open(i, self.pick and self.c.difficulties[self.pick.sel] or nil)
    self.pick = nil
    -- el cartucho se mete (baja) y se pasa con el iris; una partida NUEVA empieza con la intro de la historia
    -- (se puede saltar manteniendo pulsado)
    self.inserting = { slot = i, t = 0, new = new }
end

function StorySlotState:_go()
    local cx, cy = self:_cartCenter(self.inserting.slot)
    local map = self.c.map
    if self.inserting.new and self.c.introFilm then
        Transition.go('story_film', { film = self.c.introFilm, onDone = function() gStateMachine:change(map) end }, cx, cy)
    else
        Transition.go(map, nil, cx, cy)
    end
end

function StorySlotState:_cartCenter(i)
    local x, y, w, h = cartRect(i)
    return x + w / 2, y + h / 2
end

function StorySlotState:_diffOpen(k)
    local id = self.c.difficulties[k]
    return Difficulty.START[id] == true or (self.unlocked and self.unlocked[id] == true)
end


function StorySlotState:_pickConfirm()
    if not self:_diffOpen(self.pick.sel) then Sound.play('headBump'); return end
    self:_open(self.pick.slot)
end

function StorySlotState:_delete(i)
    if not self.slots[i] then return end
    if self.confirm ~= i then self.confirm = i; Sound.play('select'); return end
    self.c.saves.delete(i)
    self.confirm = nil
    Sound.play('select')
    self:reload()
end

-- COPIAR (el usuario, 2026-11-02): la partida elegida a un hueco VACÍO (se elige después: solo los vacíos; ATRÁS
-- cancela). Sin hueco vacío, un aviso.
function StorySlotState:_copyStart(i)
    if not self.slots[i] then return end
    local empty
    for k = 1, SLOTS do if not self.slots[k] then empty = empty or k end end
    if not empty then Notify.toast(L('story.copy_none'), 'error'); Sound.play('headBump'); return end
    self.copyFrom, self.confirm, self.btnRow = i, nil, nil
    self.sel = empty
    Sound.play('select', 1.1)
end
function StorySlotState:_copyTo(k)
    if not self.copyFrom or self.slots[k] then Sound.play('headBump'); return end
    self.c.saves.write(k, self.slots[self.copyFrom].data)
    self.copyFrom = nil
    self.sel = k
    Sound.play('checkpoint')
    self:reload()
end

function StorySlotState:_back()
    if self.anim:busy() then return end
    Sound.play('select', 0.85)
    local b = self.c.back
    self.anim:leave(function() gStateMachine:change(b[1], b[2]) end)
end

function StorySlotState:update(dt)
    self.t = self.t + dt
    MenuScene.update(dt)
    self.anim:update(dt)
    if self.inserting then
        self.inserting.t = self.inserting.t + dt
        if self.inserting.t >= INSERT_T and not self.inserting.sent then self.inserting.sent = true; self:_go() end
        return
    end
    if self.anim:busy() then return end
    if self.pick then
        self.pick.t = self.pick.t + dt
        local n = #self.c.difficulties
        if Input.pressed('nav_up') then self.pick.sel = (self.pick.sel - 2) % n + 1; Sound.play('select', 0.94) end
        if Input.pressed('nav_down') then self.pick.sel = self.pick.sel % n + 1; Sound.play('select', 1.08) end
        if Input.pressed('confirm') or Input.pressed('flap') then self:_pickConfirm(); return end
        if Input.pressed('back') then self.pick = nil; Sound.play('select', 0.85) end
        return
    end
    -- (copiando: el cursor solo va por los huecos vacíos; confirmar copia, ATRÁS cancela)
    if self.copyFrom then
        local function moveEmpty(d)
            for step = 1, SLOTS do
                local k = (self.sel - 1 + d * step) % SLOTS + 1
                if not self.slots[k] then self.sel = k; Sound.play('select', d > 0 and 1.08 or 0.94); return end
            end
        end
        if Input.pressed('nav_left') then moveEmpty(-1) end
        if Input.pressed('nav_right') then moveEmpty(1) end
        if Input.pressed('confirm') or Input.pressed('flap') then self:_copyTo(self.sel) end
        if Input.pressed('back') then self.sel, self.copyFrom = self.copyFrom, nil; Sound.play('select', 0.85) end
        return
    end
    -- (ABAJO, en un cartucho usado: sus botones COPIAR / BORRAR; ◀ ▶ eligen, confirmar, ARRIBA vuelve)
    if self.btnRow then
        if Input.pressed('nav_left') or Input.pressed('nav_right') then self.btnRow = 3 - self.btnRow; self.confirm = nil; Sound.play('select') end
        if Input.pressed('nav_up') or Input.pressed('back') then self.btnRow, self.confirm = nil, nil; Sound.play('select', 0.85); return end
        if Input.pressed('confirm') or Input.pressed('flap') then
            if self.btnRow == 1 then self:_copyStart(self.sel) else self:_delete(self.sel) end
        end
        return
    end
    if Input.pressed('nav_down') and self.slots[self.sel] then self.btnRow = 1; Sound.play('select'); return end
    local function move(d) self.sel = (self.sel - 1 + d) % SLOTS + 1; self.confirm = nil; self.selT = 0; Sound.play('select', d > 0 and 1.08 or 0.94) end
    if Input.pressed('nav_left') or Input.pressed('nav_up') then move(-1) end
    if Input.pressed('nav_right') or (Input.pressed('nav_down') and not self.slots[self.sel]) then move(1) end
    if Input.pressed('confirm') or Input.pressed('flap') then
        if self.confirm == self.sel then self:_delete(self.sel) else self:_open(self.sel) end
        return
    end
    if Input.pressed('back') then
        if self.confirm then self.confirm = nil; Sound.play('select', 0.85) else self:_back() end
    end
    -- con MANDO se borra con el botón de la linterna (Y; dos veces, como Supr): antes no había forma
    if Input.pressed('light') and Input.usingPad() then self:_delete(self.sel) end
end

function StorySlotState:keypressed(key)
    if self.pick or self.inserting or self.copyFrom then return end
    if key == 'delete' or key == 'backspace' then self:_delete(self.sel) end
    if key == 'c' then self:_copyStart(self.sel) end                  -- (C: copiar)
end

function StorySlotState:mousemoved(x, y)
    self.backHover = CornerButtons.hitBack(x, y)
    if self.inserting then return end
    if self.pick then
        for k = 1, #self.c.difficulties do if inside(x, y, pickRect(k)) then self.pick.sel = k end end
        return
    end
    for i = 1, SLOTS do
        if inside(x, y, cartRect(i)) and self.sel ~= i then self.sel = i; self.confirm = nil; self.selT = 0; Sound.play('select') end
    end
end

function StorySlotState:touchpressed(id, x, y)
    if self.inserting or self.anim:busy() then return end
    if self.pick then
        if CornerButtons.hitBack(x, y) then self.pick = nil; Sound.play('select'); return end
        for k = 1, #self.c.difficulties do
            if inside(x, y, pickRect(k)) then self.pick.sel = k; self:_pickConfirm(); return end
        end
        return
    end
    if CornerButtons.hitBack(x, y) then return self:_back() end
    for i = 1, SLOTS do
        if self.copyFrom then
            if inside(x, y, cartRect(i)) then self.sel = i; self:_copyTo(i) end
        else
        if self.slots[i] and i == self.sel and inside(x, y, delRect(i)) then self:_delete(i); return end
        if self.slots[i] and i == self.sel and inside(x, y, copyRect(i)) then self:_copyStart(i); return end
        if inside(x, y, cartRect(i)) then
            self.sel = i
            if self.confirm == i then self.confirm = nil else self:_open(i) end
            return
        end
        end
    end
end

-- ── Dibujo ──────────────────────────────────────────────────────────────────
local function fmtTime(sec)
    sec = math.floor(sec or 0)
    local h, m = math.floor(sec / 3600), math.floor(sec / 60) % 60
    return h > 0 and string.format('%d:%02d:%02d', h, m, sec % 60) or string.format('%d:%02d', m, sec % 60)
end

-- Un cartucho en (x, y) a escala s
function StorySlotState:_drawCart(i, x, y, s, sel, a)
    local A = loadArt()
    local m = A.m
    local slot = self.slots[i]
    local shell = slot and SHELL[(i - 1) % #SHELL + 1] or 'grey'
    -- sombra negra y la carcasa
    love.graphics.setColor(0, 0, 0, 0.45 * a)
    love.graphics.draw(A.img, A.shells[shell][1], x + 6, y + 6, 0, s, s)
    love.graphics.setColor(1, 1, 1, a * ((sel or not slot) and 1 or 0.85))
    love.graphics.draw(A.img, A.shells[shell][sel and 2 or 1], x, y, 0, s, s)
    -- el número, en las estrías de arriba
    local num = tostring(i)
    PixelFont.shadow(num, x + 3 * s, y + 3 * s, math.max(2, s - 1), a, { 1, 1, 1 })
    -- la ventanita: la isla donde va (o la de la partida nueva)
    local win = m.window
    local scene = 'new'
    if slot then local W = self.c.worlds.get(slot.world); scene = W and self.c.scene(W) or 'new' end
    love.graphics.setColor(1, 1, 1, a)
    love.graphics.draw(A.labels, A.scenes[scene] or A.scenes.new, x + win[1] * s, y + win[2] * s, 0, s, s)
    -- el texto de la etiqueta (debajo de la ventanita)
    local lb = m.label
    local tx, tw = x + (lb[1] + 2) * s, (lb[3] - 4) * s
    local ty = y + (win[2] + win[4] + 2) * s
    local ink = { 0.16, 0.14, 0.2 }
    love.graphics.setFont(FONT_SMALL)
    if not slot then
        local plus = '+'
        PixelFont.shadow(plus, math.floor(x + (win[1] + win[3] / 2) * s - PixelFont.width(plus, s * 2) / 2), y + (win[2] + 6) * s, s * 2, a, { 1, 1, 1 })
        local t = L('story.slot_new')
        local ts = MenuButton.textScale(t, tw, 3)
        PixelFont.draw(t, math.floor(tx + (tw - PixelFont.width(t, ts)) / 2), ty + 2 * s, ts, a, ink)
        love.graphics.setColor(ink[1], ink[2], ink[3], 0.75 * a)
        love.graphics.printf(L(self.c.newHint), tx, ty + 2 * s + PixelFont.height(ts) + 10, tw, 'center')
        return
    end
    local d = slot.data
    local W = self.c.worlds.get(slot.world)
    local name = W and self.c.worldName(W) or ''
    local ns = MenuButton.textScale(name, tw, 3)
    PixelFont.draw(name, math.floor(tx + (tw - PixelFont.width(name, ns)) / 2), ty, ns, a, ink)
    local ly = ty + PixelFont.height(ns) + 8
    -- la barra del progreso (a bloques)
    local bw, bh = tw, 3 * s
    local k = slot.total > 0 and slot.done / slot.total or 0
    love.graphics.setColor(ink[1], ink[2], ink[3], a)
    love.graphics.rectangle('fill', tx, ly, bw, bh)
    local fillW = math.floor((bw - 4) * k / s) * s
    love.graphics.setColor(0.36, 0.72, 0.36, a)
    if fillW > 0 then love.graphics.rectangle('fill', tx + 2, ly + 2, fillW, bh - 4) end
    ly = ly + bh + 6
    love.graphics.setColor(ink[1], ink[2], ink[3], a)
    love.graphics.printf(L('story.slot_levels', { done = slot.done, total = slot.total }), tx, ly, tw, 'left')
    love.graphics.printf(fmtTime(d.playTime), tx, ly, tw, 'right')
    ly = ly + FONT_SMALL:getHeight() + 6
    -- (la dificultad, en la fuente pixel: tiene las tildes en mayúscula que a la otra le faltan)
    PixelFont.draw(L('difficulty.' .. d.difficulty), tx, ly + 1, 2, a, ink)
    love.graphics.setColor(ink[1], ink[2], ink[3], a)
    love.graphics.printf(L('story.slot_lives', { n = d.lives }), tx, ly, tw, 'right')
end

function StorySlotState:render()
    -- (Flappy: el fondo del infinito; Aventura: ladrillos dorados — src/ui/menu/MenuScene)
    if self.c.id == 'flappy' then MenuScene.flappyBg() else MenuScene.bricks('story') end
    local A = self.anim
    if not self.pick then MenuList.header(L(self.c.title), self.c.id == 'flappy' and 'orange' or 'yellow', A, 1) end
    for i = 1, SLOTS do
        local x, y, w, h, s = cartRect(i)
        local sel = i == self.sel and not self.pick
        local ox, oy, a = A:slide(i + 1, 0, 300)
        local lift = 0
        if sel then
            lift = -LIFT + ((math.floor(self.t * 2.5) % 2 == 0) and -4 or 0)
        end
        if self.inserting and self.inserting.slot == i then
            -- se mete: sube un poco y baja de golpe
            local k = self.inserting.t / INSERT_T
            lift = -LIFT - 12 + math.floor(k * k * (h * 0.6) / 4) * 4
        end
        self:_drawCart(i, x + ox, y + oy + lift, s, sel, a * ((self.pick and 0.5) or 1))
        -- COPIAR y BORRAR, debajo del elegido (BORRAR: segunda pulsación = confirmar)
        if sel and self.slots[i] and not self.inserting and not self.copyFrom then
            local cx, cy, cw, ch = copyRect(i)
            local onC = self.btnRow == 1
            MenuButton.draw(L('story.copy'), cx + ox, cy + oy, cw, ch, onC and 'blue' or 'grey', onC, { alpha = a, scale = 3 })
            if onC then MenuKit.marker(cx + ox, cy + oy, cw, ch, self.t, a) end
            local dx, dy, dw, dh = delRect(i)
            local ask = self.confirm == i
            local onD = self.btnRow == 2
            MenuButton.draw(L(ask and 'story.delete_sure' or 'story.delete'), dx + ox, dy + oy, dw, dh, ask and 'red' or 'grey', ask or onD,
                            { alpha = a, scale = 3 })
            if onD then MenuKit.marker(dx + ox, dy + oy, dw, dh, self.t, a) end
        end
    end
    -- Elegir dificultad (partida nueva)
    if self.pick then
        MenuScene.dim(0.55)
        MenuList.header(L('difficulty.title'), 'orange')
        for k, id in ipairs(self.c.difficulties) do
            local x, y, w, h = pickRect(k)
            local sel, open = k == self.pick.sel, self:_diffOpen(k)
            local kin = math.min(1, math.max(0, (self.pick.t - (k - 1) * 0.05) / 0.25))
            local oy = math.floor((1 - kin) * 60 / 4) * 4
            local bob = (sel and math.floor(self.t * 3) % 2 == 0) and -4 or 0
            MenuButton.draw(L('difficulty.' .. id), x, y + oy + bob, w, h, open and (DIFF_COLORS[id] or 'blue') or 'grey', sel,
                            { alpha = kin, scale = 4 })
            if not open then
                local PixelIcons = require 'src/ui/PixelIcons'
                PixelIcons.draw('lock', x + w - 48, y + oy + h / 2 - 18, 3)
            end
        end
        local id = self.c.difficulties[self.pick.sel]
        MenuList.footer(self:_diffOpen(self.pick.sel) and L('difficulty.desc.' .. id) or L('difficulty.locked.' .. id), nil, nil,
                        L('difficulty.hint'))
    else
        local s = self.slots[self.sel]
        if self.copyFrom then
            MenuList.footer(L('story.copy_pick', { n = self.copyFrom }), A, SLOTS + 2, L('story.copy_hint'))
            love.graphics.setColor(1, 1, 1, 1)
            CornerButtons.drawBack(self.backHover)
            return
        end
        MenuList.footer(s and self.c.slotDesc(s) or L(self.c.emptyDesc),
                        A, SLOTS + 2, L('story.slot_hint'))
    end
    love.graphics.setColor(1, 1, 1, 1)
    CornerButtons.drawBack(self.backHover)
end

return StorySlotState
