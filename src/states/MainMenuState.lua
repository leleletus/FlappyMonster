-- src/states/MainMenuState.lua
-- Menú principal: Adventure / regular.
-- Navegar con nav_up/nav_down, confirmar con confirm/flap.

local CornerButtons = require 'src/ui/CornerButtons'
local BaseState     = require 'src/BaseState'
local MainMenuState = BaseState:new()

local imgBg        = nil
local imgAdventure = nil
local imgregular    = nil

-- adventure.png = 39x5 px,  regular.png = 25x5 px
local MENU_BTN_SCALE = 8   -- misma escala entera que los diff imgs

local OPTIONS = { 'adventure', 'regular' }

local function loadAssets()
    if imgBg then return end
    imgBg        = love.graphics.newImage('assets/images/menus/MenuDif.png')
    imgAdventure = love.graphics.newImage('assets/images/menus/adventure.png')
    imgregular    = love.graphics.newImage('assets/images/menus/regular.png')
end

function MainMenuState:enter(args)
    loadAssets()
    self.selected = 1
    Sound.playMusic('menus')
end

function MainMenuState:update(dt)
    if Input.pressed('nav_up') then
        self.selected = self.selected - 1
        if self.selected < 1 then self.selected = #OPTIONS end
        Sound.play('select')
    end
    if Input.pressed('nav_down') then
        self.selected = self.selected + 1
        if self.selected > #OPTIONS then self.selected = 1 end
        Sound.play('select')
    end

    if Input.pressed('confirm') or Input.pressed('flap') then
        Sound.play('select')
        if self.selected == 1 then
            gStateMachine:change('adv_mode_select')
        else
            gStateMachine:change('difficulty')
        end
    end

    if Input.pressed('back') then
        Sound.play('select')
        gStateMachine:change('title')
    end
end

function MainMenuState:render()
    -- Fondo (mismo que TitleState: Menu.png escalado a pantalla)
    local bx = WINDOW_W / imgBg:getWidth()
    local by = WINDOW_H / imgBg:getHeight()
    love.graphics.setColor(COLOR_WHITE)
    love.graphics.draw(imgBg, 0, 0, 0, bx, by)

    -- Dimensiones de cada botón escalado
    local imgs = { imgAdventure, imgregular }
    local gap  = 24   -- px entre botones

    -- Altura total del bloque para centrarlo verticalmente
    local totalH = 0
    for _, img in ipairs(imgs) do
        totalH = totalH + img:getHeight() * MENU_BTN_SCALE
    end
    totalH = totalH + gap * (#imgs - 1)

    local startY = math.floor((WINDOW_H - totalH) / 2)
    local curY   = startY

    for i, img in ipairs(imgs) do
        local iw = img:getWidth()  * MENU_BTN_SCALE
        local ih = img:getHeight() * MENU_BTN_SCALE
        local ix = math.floor((WINDOW_W - iw) / 2)

        if i == self.selected then

            -- Sprite ligeramente agrandado
            local s  = MENU_BTN_SCALE * 1.12
            local ox = math.floor((iw - img:getWidth()  * s) / 2)
            local oy = math.floor((ih - img:getHeight() * s) / 2)
            love.graphics.setColor(COLOR_WHITE)
            love.graphics.draw(img, ix + ox, curY + oy, 0, s, s)
        else
            love.graphics.setColor(1, 1, 1, 0.45)
            love.graphics.draw(img, ix, curY, 0, MENU_BTN_SCALE, MENU_BTN_SCALE)
        end

        curY = curY + ih + gap
    end
    CornerButtons.drawBack(self.backHover)
end

-- Hover del mouse: mueve la selección real al botón bajo el cursor
function MainMenuState:mousemoved(tx, ty)
    self.backHover = CornerButtons.hitBack(tx, ty)
    if self.backHover then return end
    local imgs   = { imgAdventure, imgregular }
    local gap    = 24
    local totalH = 0
    for _, img in ipairs(imgs) do totalH = totalH + img:getHeight() * MENU_BTN_SCALE end
    totalH = totalH + gap * (#imgs - 1)
    local curY = math.floor((WINDOW_H - totalH) / 2)
    for i, img in ipairs(imgs) do
        local iw = img:getWidth()  * MENU_BTN_SCALE
        local ih = img:getHeight() * MENU_BTN_SCALE
        local ix = math.floor((WINDOW_W - iw) / 2)
        if tx >= ix-20 and tx <= ix+iw+20 and ty >= curY-10 and ty <= curY+ih+10 then
            if self.selected ~= i then self.selected = i; Sound.play('select') end
            return
        end
        curY = curY + ih + gap
    end
end

-- Táctil Switch: tap directo en el botón
function MainMenuState:touchpressed(id, tx, ty, dx, dy, pressure)
    if CornerButtons.hitBack(tx, ty) then
        Sound.play('select')
        gStateMachine:change('title')
        return
    end
    local imgs  = { imgAdventure, imgregular }
    local gap   = 24
    local totalH = 0
    for _, img in ipairs(imgs) do totalH = totalH + img:getHeight() * MENU_BTN_SCALE end
    totalH = totalH + gap * (#imgs - 1)
    local curY = math.floor((WINDOW_H - totalH) / 2)
    for i, img in ipairs(imgs) do
        local iw = img:getWidth()  * MENU_BTN_SCALE
        local ih = img:getHeight() * MENU_BTN_SCALE
        local ix = math.floor((WINDOW_W - iw) / 2)
        -- Área del botón con un margen generoso (+20px cada lado)
        if tx >= ix-20 and tx <= ix+iw+20 and ty >= curY-10 and ty <= curY+ih+10 then
            Sound.play('select')
            if i == 1 then
                gStateMachine:change('adv_mode_select')
            else
                gStateMachine:change('difficulty')
            end
            return
        end
        curY = curY + ih + gap
    end
end

return MainMenuState