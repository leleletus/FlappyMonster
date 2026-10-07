-- src/states/story/StorySlotState.lua
-- MODO HISTORIA: elegir PARTIDA. Tres huecos (src/story/Save.lua); uno vacío empieza una
-- aventura nueva, uno usado continúa donde iba (mundo, progreso, vidas). BORRAR pide confirmar.
-- Flechas / ratón / toque; ENTER entra; SUPR (o el botón) borra; ESC vuelve.
local BaseState     = require 'src/core/BaseState'
local CornerButtons = require 'src/ui/CornerButtons'
local PixelFont     = require 'src/ui/PixelFont'
local Save          = require 'src/story/Save'
local Run           = require 'src/story/Run'
local Worlds        = require 'src/story/Worlds'
local Difficulty    = require 'src/core/Difficulty'
local L = require 'src/core/Lang'

local StorySlotState = BaseState:new()

local CARD_W, CARD_H, GAP = 760, 124, 22
local DEL_W = 150

local imgBg
local function loadAssets()
    if imgBg then return end
    imgBg = love.graphics.newImage('assets/images/ui/menus/MenuDif.png')
end

local function cardRect(i)
    local w = math.min(CARD_W, WINDOW_W - 48)
    local total = Save.SLOTS * CARD_H + (Save.SLOTS - 1) * GAP
    local y0 = math.floor(WINDOW_H / 2 - total / 2 + 50)
    return math.floor((WINDOW_W - w) / 2), y0 + (i - 1) * (CARD_H + GAP), w, CARD_H
end
local function delRect(i)
    local x, y, w, h = cardRect(i)
    return x + w - DEL_W - 14, y + h - 44, DEL_W, 32
end
local function inside(px, py, x, y, w, h) return px >= x and px <= x + w and py >= y and py <= y + h end

function StorySlotState:enter()
    loadAssets()
    Run.close()
    self.sel = self.sel or 1
    self.confirm = nil                       -- hueco que se está a punto de borrar
    self:reload()
    Sound.playMusic('menus')
end

function StorySlotState:reload()
    self.slots = {}
    for i = 1, Save.SLOTS do
        local d = Save.load(i)
        if d then
            local saved, run = Run.slot, Run.data
            Run.slot, Run.data = i, d
            local done, total = Run.progress()
            local w = Run.frontier()
            Run.slot, Run.data = saved, run
            self.slots[i] = { data = d, done = done, total = total, world = w }
        else
            self.slots[i] = false
        end
    end
end

-- Un hueco usado continúa; uno vacío pregunta antes la DIFICULTAD (src/core/Difficulty.lua): Fácil,
-- Normal y Difícil desde el principio; Extremo y Xtra extremo, cerradas hasta desbloquearlas
function StorySlotState:_open(i)
    Sound.play('select')
    if not self.slots[i] and not self.pick then
        self.unlocked = Save.global().unlocked
        self.pick = { slot = i, sel = 2 }
        return
    end
    local new = not self.slots[i]
    Run.open(i, self.pick and Difficulty.ORDER[self.pick.sel] or nil)
    self.pick = nil
    -- una partida NUEVA empieza con la intro de la historia (se puede saltar manteniendo pulsado)
    if new then
        gStateMachine:change('story_film', { film = 'intro', onDone = function() gStateMachine:change('story_map') end })
    else
        gStateMachine:change('story_map')
    end
end

function StorySlotState:_diffOpen(k)
    local id = Difficulty.ORDER[k]
    return Difficulty.START[id] == true or (self.unlocked and self.unlocked[id] == true)
end

local function pickRect(k)
    local w, h, gap = math.min(620, WINDOW_W - 60), 58, 12
    local total = #Difficulty.ORDER * h + (#Difficulty.ORDER - 1) * gap
    return math.floor((WINDOW_W - w) / 2), math.floor(WINDOW_H / 2 - total / 2 + 40) + (k - 1) * (h + gap), w, h
end

function StorySlotState:_pickConfirm()
    if not self:_diffOpen(self.pick.sel) then Sound.play('headBump'); return end
    self:_open(self.pick.slot)
end

function StorySlotState:_delete(i)
    if not self.slots[i] then return end
    if self.confirm ~= i then self.confirm = i; Sound.play('select'); return end
    Save.delete(i)
    self.confirm = nil
    Sound.play('select')
    self:reload()
end

function StorySlotState:update(dt)
    if self.pick then
        local n = #Difficulty.ORDER
        if Input.pressed('nav_up') then self.pick.sel = (self.pick.sel - 2) % n + 1; Sound.play('select') end
        if Input.pressed('nav_down') then self.pick.sel = self.pick.sel % n + 1; Sound.play('select') end
        if Input.pressed('confirm') or Input.pressed('flap') then self:_pickConfirm(); return end
        if Input.pressed('back') then self.pick = nil; Sound.play('select') end
        return
    end
    if Input.pressed('nav_up') then self.sel = (self.sel - 2) % Save.SLOTS + 1; self.confirm = nil; Sound.play('select') end
    if Input.pressed('nav_down') then self.sel = self.sel % Save.SLOTS + 1; self.confirm = nil; Sound.play('select') end
    if Input.pressed('confirm') or Input.pressed('flap') then
        if self.confirm == self.sel then self:_delete(self.sel) else self:_open(self.sel) end
        return
    end
    if Input.pressed('back') then
        Sound.play('select')
        if self.confirm then self.confirm = nil else gStateMachine:change('adv_mode_select') end
    end
end

function StorySlotState:keypressed(key)
    if key == 'delete' or key == 'backspace' then self:_delete(self.sel) end
end

function StorySlotState:mousemoved(x, y)
    self.backHover = CornerButtons.hitBack(x, y)
    if self.pick then
        for k = 1, #Difficulty.ORDER do if inside(x, y, pickRect(k)) then self.pick.sel = k end end
        return
    end
    for i = 1, Save.SLOTS do
        if inside(x, y, cardRect(i)) and self.sel ~= i then self.sel = i; self.confirm = nil end
    end
end

function StorySlotState:touchpressed(id, x, y)
    if self.pick then
        if CornerButtons.hitBack(x, y) then self.pick = nil; Sound.play('select'); return end
        for k = 1, #Difficulty.ORDER do
            if inside(x, y, pickRect(k)) then self.pick.sel = k; self:_pickConfirm(); return end
        end
        return
    end
    if CornerButtons.hitBack(x, y) then Sound.play('select'); gStateMachine:change('adv_mode_select'); return end
    for i = 1, Save.SLOTS do
        if self.slots[i] and inside(x, y, delRect(i)) then self.sel = i; self:_delete(i); return end
        if inside(x, y, cardRect(i)) then
            self.sel = i
            if self.confirm == i then self.confirm = nil else self:_open(i) end
            return
        end
    end
end

function StorySlotState:render()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(imgBg, 0, 0, 0, WINDOW_W / imgBg:getWidth(), WINDOW_H / imgBg:getHeight())
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)

    local title = L('story.title')
    local ts = 6
    PixelFont.shadow(title, math.floor((WINDOW_W - PixelFont.width(title, ts)) / 2), 52, ts, 1, { 1, 0.95, 0.15 })
    local sub = L('story.pick_slot')
    love.graphics.setFont(FONT_MED)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.printf(sub, 0, 118, WINDOW_W, 'center')

    for i = 1, Save.SLOTS do
        local x, y, w, h = cardRect(i)
        local sel = i == self.sel
        love.graphics.setColor(0, 0, 0, 0.55); love.graphics.rectangle('fill', x + 4, y + 4, w, h)
        if sel then love.graphics.setColor(1, 1, 1, 1) else love.graphics.setColor(0.1, 0.1, 0.14, 0.92) end
        love.graphics.rectangle('fill', x, y, w, h)
        love.graphics.setColor(sel and 1 or 0.6, sel and 0.85 or 0.6, sel and 0 or 0.65, 1)
        love.graphics.setLineWidth(sel and 4 or 2)
        love.graphics.rectangle('line', x, y, w, h)
        love.graphics.setLineWidth(1)
        local ink = sel and { 0, 0, 0 } or { 1, 1, 1 }
        PixelFont.shadow(L('story.slot', { n = i }), x + 18, y + 16, 4, 1, sel and { 1, 0.95, 0.15 } or nil)   -- (PixelFont: letras sobre negro)
        love.graphics.setFont(FONT_MED)
        local s = self.slots[i]
        if s then
            local W = Worlds.get(s.world)
            love.graphics.setColor(ink[1], ink[2], ink[3], 0.9)
            love.graphics.print(L('story.slot_world', { n = s.world, name = L('story.world.' .. W.id) }), x + 18, y + 58)
            love.graphics.print(L('story.slot_progress', { done = s.done, total = s.total, lives = s.data.lives })
                .. '   ·   ' .. L('difficulty.' .. s.data.difficulty), x + 18, y + 86)
            -- BORRAR (segunda pulsación = confirmar)
            local dx, dy, dw, dh = delRect(i)
            local ask = self.confirm == i
            love.graphics.setColor(ask and 0.85 or 0.25, ask and 0.15 or 0.25, ask and 0.15 or 0.3, 1)
            love.graphics.rectangle('fill', dx, dy, dw, dh)
            love.graphics.setFont(FONT_SMALL)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf(L(ask and 'story.delete_sure' or 'story.delete'), dx, dy + dh / 2 - FONT_SMALL:getHeight() / 2, dw, 'center')
        else
            love.graphics.setColor(ink[1], ink[2], ink[3], 0.6)
            love.graphics.print(L('story.slot_empty'), x + 18, y + 66)
        end
    end
    -- Elegir dificultad (partida nueva)
    if self.pick then
        love.graphics.setColor(0, 0, 0, 0.78)
        love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)
        local t2 = L('difficulty.title')
        PixelFont.shadow(t2, math.floor((WINDOW_W - PixelFont.width(t2, 5)) / 2), 70, 5, 1, { 1, 0.95, 0.15 })
        for k, id in ipairs(Difficulty.ORDER) do
            local x, y, w, h = pickRect(k)
            local sel, open = k == self.pick.sel, self:_diffOpen(k)
            love.graphics.setColor(0, 0, 0, 0.6); love.graphics.rectangle('fill', x + 4, y + 4, w, h)
            if sel then love.graphics.setColor(1, 1, 1, 1) else love.graphics.setColor(0.1, 0.1, 0.14, 1) end
            love.graphics.rectangle('fill', x, y, w, h)
            love.graphics.setColor(sel and 1 or 0.6, sel and 0.85 or 0.6, sel and 0 or 0.65, 1)
            love.graphics.setLineWidth(sel and 4 or 2); love.graphics.rectangle('line', x, y, w, h); love.graphics.setLineWidth(1)
            local c = sel and 0 or 1
            PixelFont.draw(L('difficulty.' .. id), x + 16, y + 10, 3, open and 1 or 0.45, { c, c, c })   -- (fuente pixel: con tildes)
            love.graphics.setFont(FONT_SMALL)
            love.graphics.setColor(c, c, c, open and 0.8 or 0.45)
            love.graphics.print(open and L('difficulty.desc.' .. id) or L('difficulty.locked.' .. id), x + 16, y + 36)
            if not open then
                local PixelIcons = require 'src/ui/PixelIcons'
                PixelIcons.draw('lock', x + w - 42, y + h / 2 - 15, 3)
            end
        end
    end
    love.graphics.setFont(FONT_SMALL)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.printf(L(self.pick and 'difficulty.hint' or 'story.slot_hint'), 0, WINDOW_H - 34, WINDOW_W, 'center')
    love.graphics.setFont(FONT_MED)
    love.graphics.setColor(1, 1, 1, 1)
    CornerButtons.drawBack(self.backHover)
end

return StorySlotState
