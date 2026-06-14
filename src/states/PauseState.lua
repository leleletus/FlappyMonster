-- src/states/PauseState.lua
local BaseState  = require 'src/BaseState'
local PauseState = BaseState:new()

local PAUSE_OPTIONS = { 'Reanudar', 'Menu' }

local function drawPixelButton(label, cx, y, w, h, selected)
    if selected then
        love.graphics.setColor(0.18, 0.18, 0.18, 1)
        love.graphics.rectangle('fill', cx - w/2 + 4, y + 4, w, h)   -- sombra
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle('fill', cx - w/2, y, w, h)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.printf(label, cx - w/2, y + h/2 - FONT_MED:getHeight()/2, w, 'center')
    else
        love.graphics.setColor(1, 1, 1, 0.45)
        love.graphics.rectangle('line', cx - w/2, y, w, h)
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.printf(label, cx - w/2, y + h/2 - FONT_MED:getHeight()/2, w, 'center')
    end
end

function PauseState:enter(args)
    self.selected = 1
    Sound.stopMusic()
end

function PauseState:update(dt)
    if Input.pressed('nav_up') then
        self.selected = self.selected - 1
        if self.selected < 1 then self.selected = #PAUSE_OPTIONS end
        Sound.play('select')
    end
    if Input.pressed('nav_down') then
        self.selected = self.selected + 1
        if self.selected > #PAUSE_OPTIONS then self.selected = 1 end
        Sound.play('select')
    end

    if Input.pressed('confirm') or Input.pressed('resume') or Input.pressed('pause') then
        if self.selected == 1 then
            gStateMachine:pop()
        else
            Sound.play('select')
            gStateMachine:change('main_menu')
        end
    end
end

function PauseState:render()
    -- Overlay oscuro
    love.graphics.setColor(0, 0, 0, 0.65)
    love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)

    -- Título PAUSA
    love.graphics.setFont(FONT_BIG)
    love.graphics.setColor(COLOR_WHITE)
    love.graphics.printf('PAUSA', 0, WINDOW_H/2 - 130, WINDOW_W, 'center')

    -- Botones
    love.graphics.setFont(FONT_MED)
    local btnW   = 260
    local btnH   = 48
    local gap    = 18
    local totalH = #PAUSE_OPTIONS * btnH + (#PAUSE_OPTIONS - 1) * gap
    local startY = WINDOW_H/2 - totalH/2
    local cx     = WINDOW_W / 2

    for i, opt in ipairs(PAUSE_OPTIONS) do
        local by = startY + (i - 1) * (btnH + gap)
        drawPixelButton(opt, cx, by, btnW, btnH, i == self.selected)
    end

    love.graphics.setColor(COLOR_WHITE)
end

-- Hover del mouse: mueve la selección real al botón bajo el cursor
function PauseState:mousemoved(tx, ty)
    local btnW   = 260
    local btnH   = 48
    local gap    = 18
    local totalH = #PAUSE_OPTIONS * btnH + (#PAUSE_OPTIONS - 1) * gap
    local startY = WINDOW_H/2 - totalH/2
    local cx     = WINDOW_W / 2
    for i = 1, #PAUSE_OPTIONS do
        local by = startY + (i-1) * (btnH + gap)
        local bx = cx - btnW/2
        if tx >= bx-10 and tx <= bx+btnW+10 and ty >= by-5 and ty <= by+btnH+5 then
            if self.selected ~= i then self.selected = i; Sound.play('select') end
            return
        end
    end
end

-- Táctil Switch: tap en el botón
function PauseState:touchpressed(id, tx, ty, dx, dy, pressure)
    local btnW   = 260
    local btnH   = 48
    local gap    = 18
    local totalH = #PAUSE_OPTIONS * btnH + (#PAUSE_OPTIONS - 1) * gap
    local startY = WINDOW_H/2 - totalH/2
    local cx     = WINDOW_W / 2
    for i, opt in ipairs(PAUSE_OPTIONS) do
        local by = startY + (i-1) * (btnH + gap)
        local bx = cx - btnW/2
        if tx >= bx-10 and tx <= bx+btnW+10 and ty >= by-5 and ty <= by+btnH+5 then
            if i == 1 then
                gStateMachine:pop()
            else
                Sound.play('select')
                gStateMachine:change('main_menu')
            end
            return
        end
    end
end

return PauseState