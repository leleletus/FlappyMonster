-- src/states/MainMenuState.lua
-- Menú principal: AVENTURA / CLÁSICO / CONFIGURACIÓN.
-- Navegar con nav_up/nav_down, confirmar con confirm/flap.
-- Los botones son TEXTO en la fuente pixel de los menús (src/ui/PixelFont):
-- se ven como las antiguas imágenes pero se traducen (assets/lang/).

local CornerButtons = require 'src/ui/CornerButtons'
local BaseState     = require 'src/BaseState'
local PixelFont     = require 'src/ui/PixelFont'
local L             = require 'src/Lang'
local MainMenuState = BaseState:new()

local imgBg = nil

local MENU_BTN_SCALE = 8     -- misma escala entera que las dificultades
local GAP            = 24    -- px entre botones

-- { clave de texto, estado al que lleva }
local OPTIONS = {
    { 'menu.adventure', 'adv_mode_select' },
    { 'menu.classic',   'difficulty' },
    { 'menu.settings',  'settings' },
}

local function loadAssets()
    if imgBg then return end
    imgBg = love.graphics.newImage('assets/images/menus/MenuDif.png')
end

-- Rectángulos de los botones (única fuente de geometría: dibujo, ratón, táctil)
local function layout()
    local h = PixelFont.height(MENU_BTN_SCALE)
    local totalH = #OPTIONS * h + GAP * (#OPTIONS - 1)
    local y = math.floor((WINDOW_H - totalH) / 2)
    local list = {}
    for i, o in ipairs(OPTIONS) do
        local text = L(o[1])
        local w = PixelFont.width(text, MENU_BTN_SCALE)
        list[i] = { x = math.floor((WINDOW_W - w) / 2), y = y, w = w, h = h, text = text }
        y = y + h + GAP
    end
    return list
end

function MainMenuState:enter(args)
    loadAssets()
    self.selected = (args and args.selected) or 1
    Sound.playMusic('menus')
end

function MainMenuState:_go(i)
    Sound.play('select')
    gStateMachine:change(OPTIONS[i][2])
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
    if Input.pressed('confirm') or Input.pressed('flap') then self:_go(self.selected) end
    if Input.pressed('back') then
        Sound.play('select')
        gStateMachine:change('title')
    end
end

function MainMenuState:render()
    local bx = WINDOW_W / imgBg:getWidth()
    local by = WINDOW_H / imgBg:getHeight()
    love.graphics.setColor(COLOR_WHITE)
    love.graphics.draw(imgBg, 0, 0, 0, bx, by)

    for i, r in ipairs(layout()) do
        if i == self.selected then
            -- Ligeramente agrandado (como las antiguas imágenes)
            local s  = MENU_BTN_SCALE * 1.12
            local w  = PixelFont.width(r.text, s)
            PixelFont.draw(r.text, math.floor(r.x + (r.w - w) / 2), math.floor(r.y + (r.h - PixelFont.height(s)) / 2), s, 1)
        else
            PixelFont.draw(r.text, r.x, r.y, MENU_BTN_SCALE, 0.45)
        end
    end
    love.graphics.setColor(COLOR_WHITE)
    CornerButtons.drawBack(self.backHover)
end

-- Hover del mouse: mueve la selección real al botón bajo el cursor
function MainMenuState:mousemoved(tx, ty)
    self.backHover = CornerButtons.hitBack(tx, ty)
    if self.backHover then return end
    for i, r in ipairs(layout()) do
        if tx >= r.x - 20 and tx <= r.x + r.w + 20 and ty >= r.y - 10 and ty <= r.y + r.h + 10 then
            if self.selected ~= i then self.selected = i; Sound.play('select') end
            return
        end
    end
end

-- Táctil: tap directo en el botón
function MainMenuState:touchpressed(id, tx, ty, dx, dy, pressure)
    if CornerButtons.hitBack(tx, ty) then
        Sound.play('select')
        gStateMachine:change('title')
        return
    end
    for i, r in ipairs(layout()) do
        if tx >= r.x - 20 and tx <= r.x + r.w + 20 and ty >= r.y - 10 and ty <= r.y + r.h + 10 then
            self.selected = i
            self:_go(i)
            return
        end
    end
end

return MainMenuState
