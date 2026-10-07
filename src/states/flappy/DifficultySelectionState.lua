-- src/states/flappy/DifficultySelectionState.lua
-- Elegir la dificultad del modo clásico (Flappy). Los nombres son TEXTO en
-- la fuente pixel de los menús (src/ui/PixelFont), traducidos (diff.*).
local CornerButtons = require 'src/ui/CornerButtons'
local BaseState = require 'src/core/BaseState'
local PixelFont = require 'src/ui/PixelFont'
local L         = require 'src/core/Lang'
local DifficultySelectionState = BaseState:new()

local imgBg = nil
local GAP   = 60

local function loadAssets()
    if imgBg then return end
    imgBg = love.graphics.newImage('assets/images/ui/menus/MenuDif.png')
end

-- Rectángulos de las dificultades (dibujo, ratón y táctil)
local function layout()
    local list, totalW = {}, 0
    for i, key in ipairs(DIFFICULTY_ORDER) do
        local text = L('diff.' .. key)
        list[i] = { key = key, text = text, w = PixelFont.width(text, DIFF_IMG_SCALE), h = PixelFont.height(DIFF_IMG_SCALE) }
        totalW = totalW + list[i].w
    end
    totalW = totalW + GAP * (#list - 1)
    -- Si no caben (pantallas estrechas / textos largos), se reduce la escala
    local s = DIFF_IMG_SCALE
    if totalW > WINDOW_W - 80 then
        s = math.max(4, math.floor(DIFF_IMG_SCALE * (WINDOW_W - 80) / totalW))
        totalW = GAP * (#list - 1)
        for _, r in ipairs(list) do r.w, r.h = PixelFont.width(r.text, s), PixelFont.height(s); totalW = totalW + r.w end
    end
    local x = math.floor((WINDOW_W - totalW) / 2)
    local y = math.floor(WINDOW_H * 0.52)
    for _, r in ipairs(list) do r.x, r.y, r.s = x, y, s; x = x + r.w + GAP end
    return list
end

function DifficultySelectionState:enter(args)
    loadAssets()
    self.selectedIdx = 2
    Sound.playMusic('menus')
end

function DifficultySelectionState:update(dt)
    if Input.pressed('nav_left') then
        self.selectedIdx = math.max(1, self.selectedIdx - 1)
        Sound.play('select')
    end
    if Input.pressed('nav_right') then
        self.selectedIdx = math.min(#DIFFICULTY_ORDER, self.selectedIdx + 1)
        Sound.play('select')
    end
    if Input.pressed('confirm') or Input.pressed('flap') then
        Sound.play('select')
        local key = DIFFICULTY_ORDER[self.selectedIdx]
        gStateMachine:change('play', { difficulty = key })
    end
    if Input.pressed('back') then
        Sound.play('select')
        gStateMachine:change('main_menu', { selected = 2 })
    end
end

function DifficultySelectionState:render()
    local bx = WINDOW_W / imgBg:getWidth()
    local by = WINDOW_H / imgBg:getHeight()
    love.graphics.setColor(COLOR_WHITE)
    love.graphics.draw(imgBg, 0, 0, 0, bx, by)

    for i, r in ipairs(layout()) do
        if i == self.selectedIdx then
            local s = r.s * 1.15
            local w = PixelFont.width(r.text, s)
            PixelFont.draw(r.text, math.floor(r.x + (r.w - w) / 2), math.floor(r.y + (r.h - PixelFont.height(s)) / 2), s, 1)
        else
            PixelFont.draw(r.text, r.x, r.y, r.s, 0.45)
        end
    end
    love.graphics.setColor(COLOR_WHITE)
    CornerButtons.drawBack(self.backHover)
end

-- Hover del mouse: mueve la selección real al botón bajo el cursor
function DifficultySelectionState:mousemoved(tx, ty)
    self.backHover = CornerButtons.hitBack(tx, ty)
    if self.backHover then return end
    for i, r in ipairs(layout()) do
        if tx >= r.x - 10 and tx <= r.x + r.w + 10 and ty >= r.y - 10 and ty <= r.y + r.h + 10 then
            if self.selectedIdx ~= i then self.selectedIdx = i; Sound.play('select') end
            return
        end
    end
end

-- Táctil: primer toque selecciona, segundo toque (en la misma) confirma
function DifficultySelectionState:touchpressed(id, tx, ty, dx, dy, pressure)
    if CornerButtons.hitBack(tx, ty) then
        Sound.play('select')
        gStateMachine:change('main_menu', { selected = 2 })
        return
    end
    for i, r in ipairs(layout()) do
        if tx >= r.x - 10 and tx <= r.x + r.w + 10 and ty >= r.y - 10 and ty <= r.y + r.h + 10 then
            Sound.play('select')
            if i == self.selectedIdx then
                gStateMachine:change('play', { difficulty = r.key })
            else
                self.selectedIdx = i
            end
            return
        end
    end
end

return DifficultySelectionState
