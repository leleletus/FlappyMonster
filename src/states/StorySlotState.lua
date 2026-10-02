-- src/states/StorySlotState.lua
-- MODO HISTORIA: elegir PARTIDA. Tres huecos (src/story/Save.lua); uno vacío empieza una
-- aventura nueva, uno usado continúa donde iba (mundo, progreso, vidas). BORRAR pide confirmar.
-- Flechas / ratón / toque; ENTER entra; SUPR (o el botón) borra; ESC vuelve.
local BaseState     = require 'src/BaseState'
local CornerButtons = require 'src/ui/CornerButtons'
local PixelFont     = require 'src/ui/PixelFont'
local Save          = require 'src/story/Save'
local Run           = require 'src/story/Run'
local Worlds        = require 'src/story/Worlds'
local L = require 'src/Lang'

local StorySlotState = BaseState:new()

local CARD_W, CARD_H, GAP = 760, 124, 22
local DEL_W = 150

local imgBg
local function loadAssets()
    if imgBg then return end
    imgBg = love.graphics.newImage('assets/images/menus/MenuDif.png')
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

function StorySlotState:_open(i)
    Sound.play('select')
    Run.open(i, 'normal')                    -- (la dificultad se elegirá aquí: etapa 2)
    gStateMachine:change('story_map')
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
    for i = 1, Save.SLOTS do
        if inside(x, y, cardRect(i)) and self.sel ~= i then self.sel = i; self.confirm = nil end
    end
end

function StorySlotState:touchpressed(id, x, y)
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
    PixelFont.draw(title, math.floor((WINDOW_W - PixelFont.width(title, ts)) / 2), 52, ts, 1, { 1, 0.95, 0.15 })
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
        PixelFont.draw(L('story.slot', { n = i }), x + 18, y + 16, 4, 1, sel and { 1, 0.95, 0.15 } or nil)   -- (PixelFont: letras sobre negro)
        love.graphics.setFont(FONT_MED)
        local s = self.slots[i]
        if s then
            local W = Worlds.get(s.world)
            love.graphics.setColor(ink[1], ink[2], ink[3], 0.9)
            love.graphics.print(L('story.slot_world', { n = s.world, name = L('story.world.' .. W.id) }), x + 18, y + 58)
            love.graphics.print(L('story.slot_progress', { done = s.done, total = s.total, lives = s.data.lives }), x + 18, y + 86)
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
    love.graphics.setFont(FONT_SMALL)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.printf(L('story.slot_hint'), 0, WINDOW_H - 34, WINDOW_W, 'center')
    love.graphics.setFont(FONT_MED)
    love.graphics.setColor(1, 1, 1, 1)
    CornerButtons.drawBack(self.backHover)
end

return StorySlotState
