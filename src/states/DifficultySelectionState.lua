-- src/states/DifficultySelectionState.lua
local BaseState = require 'src/BaseState'
local DifficultySelectionState = BaseState:new()

local imgBg    = nil
local imgDiffs = {}

local function loadAssets()
    if imgBg then return end
    imgBg = love.graphics.newImage('assets/images/menus/MenuDif.png')
    imgDiffs = {
        easy   = love.graphics.newImage('assets/images/menus/diff/easy.png'),
        normal = love.graphics.newImage('assets/images/menus/diff/normal.png'),
        hard   = love.graphics.newImage('assets/images/menus/diff/hard.png'),
    }
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
        gStateMachine:change('title')
    end
end

function DifficultySelectionState:render()
    local bx = WINDOW_W / imgBg:getWidth()
    local by = WINDOW_H / imgBg:getHeight()
    love.graphics.setColor(COLOR_WHITE)
    love.graphics.draw(imgBg, 0, 0, 0, bx, by)

    local totalW = 0
    local gap    = 60
    local widths = {}
    for i, key in ipairs(DIFFICULTY_ORDER) do
        widths[i] = imgDiffs[key]:getWidth() * DIFF_IMG_SCALE
        totalW    = totalW + widths[i]
    end
    totalW = totalW + gap * (#DIFFICULTY_ORDER - 1)

    local startX = math.floor((WINDOW_W - totalW) / 2)
    local imgY   = math.floor(WINDOW_H * 0.52)
    local curX   = startX

    for i, key in ipairs(DIFFICULTY_ORDER) do
        local img = imgDiffs[key]
        local iw  = img:getWidth()  * DIFF_IMG_SCALE
        local ih  = img:getHeight() * DIFF_IMG_SCALE

        if i == self.selectedIdx then
            love.graphics.setColor(1, 0.85, 0, 0.25)
            love.graphics.rectangle('fill', curX - 10, imgY - 10, iw + 20, ih + 20)
            love.graphics.setColor(COLOR_WHITE)
            local s  = DIFF_IMG_SCALE * 1.15
            local ox = math.floor((iw - img:getWidth()  * s) / 2)
            local oy = math.floor((ih - img:getHeight() * s) / 2)
            love.graphics.draw(img, curX + ox, imgY + oy, 0, s, s)
        else
            love.graphics.setColor(1, 1, 1, 0.45)
            love.graphics.draw(img, curX, imgY, 0, DIFF_IMG_SCALE, DIFF_IMG_SCALE)
        end

        curX = curX + iw + gap
    end
end

-- Hover del mouse: mueve la selección real al botón bajo el cursor
function DifficultySelectionState:mousemoved(tx, ty)
    local gap    = 60
    local imgY   = math.floor(WINDOW_H * 0.52)
    local totalW = 0
    for i, key in ipairs(DIFFICULTY_ORDER) do
        totalW = totalW + imgDiffs[key]:getWidth() * DIFF_IMG_SCALE
    end
    totalW = totalW + gap * (#DIFFICULTY_ORDER - 1)
    local curX = math.floor((WINDOW_W - totalW) / 2)
    for i, key in ipairs(DIFFICULTY_ORDER) do
        local img = imgDiffs[key]
        local iw  = img:getWidth()  * DIFF_IMG_SCALE
        local ih  = img:getHeight() * DIFF_IMG_SCALE
        if tx >= curX-10 and tx <= curX+iw+10 and ty >= imgY-10 and ty <= imgY+ih+10 then
            if self.selectedIdx ~= i then self.selectedIdx = i; Sound.play('select') end
            return
        end
        curX = curX + iw + gap
    end
end

-- Táctil Switch: tap en la imagen de dificultad
function DifficultySelectionState:touchpressed(id, tx, ty, dx, dy, pressure)
    local gap    = 60
    local imgY   = math.floor(WINDOW_H * 0.52)
    local totalW = 0
    for i, key in ipairs(DIFFICULTY_ORDER) do
        totalW = totalW + imgDiffs[key]:getWidth() * DIFF_IMG_SCALE
    end
    totalW = totalW + gap * (#DIFFICULTY_ORDER - 1)
    local curX = math.floor((WINDOW_W - totalW) / 2)
    for i, key in ipairs(DIFFICULTY_ORDER) do
        local img = imgDiffs[key]
        local iw  = img:getWidth()  * DIFF_IMG_SCALE
        local ih  = img:getHeight() * DIFF_IMG_SCALE
        if tx >= curX-10 and tx <= curX+iw+10 and ty >= imgY-10 and ty <= imgY+ih+10 then
            Sound.play('select')
            if i == self.selectedIdx then
                -- Segundo tap en el ya seleccionado = confirmar
                gStateMachine:change('play', { difficulty = key })
            else
                -- Primer tap = seleccionar
                self.selectedIdx = i
            end
            return
        end
        curX = curX + iw + gap
    end
end

return DifficultySelectionState