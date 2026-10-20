-- src/states/online/OnlineErrorState.lua
-- Pantalla de error de red.  Se muestra cuando la conexión falla o se pierde
-- por cualquier motivo.  Única opción: volver al menú de selección de modo.

local BaseState        = require 'src/core/BaseState'
local MenuScene = require 'src/ui/menu/MenuScene'
local NC               = require 'src/network/NetworkClient'
local L = require 'src/core/Lang'
local MenuAnim   = require 'src/ui/menu/MenuAnim'
local MenuButton = require 'src/ui/menu/MenuButton'
local MenuKit    = require 'src/ui/menu/MenuKit'
local OnlineErrorState = BaseState:new()

function OnlineErrorState:enter(args)
    args         = args or {}
    self.code    = args.code or "ERR_NETWORK"
    self.msg     = args.msg  or L('err.lost')
    self.anim, self.t = MenuAnim.new(), 0
    NC:disconnect()
    Sound.playMusic('menus')
end

function OnlineErrorState:_back()
    if self.anim:busy() then return end
    Sound.play('select', 1.25)
    self.anim:leave(function() gStateMachine:change('adv_mode_select') end)
end

function OnlineErrorState:update(dt)
    MenuScene.update(dt)
    self.anim:update(dt)
    self.t = self.t + dt
    if Input.pressed('confirm') or Input.pressed('back') then self:_back() end
end

-- Geometría (dibujo, ratón y táctil)
local function layout(msg)
    local w = math.min(680, WINDOW_W - 120)
    local x = math.floor((WINDOW_W - w) / 2)
    love.graphics.setFont(FONT_MED)
    local _, lines = FONT_MED:getWrap(msg or '', w - 64)
    local card = { x = x, y = math.floor(WINDOW_H * 0.30), w = w, h = 112 + math.min(4, #lines) * (FONT_MED:getHeight() + 12) }
    local bw = math.min(360, w - 80)
    return card, { x = math.floor((WINDOW_W - bw) / 2) + 26, y = card.y + card.h + 32, w = bw, h = 56 }
end

function OnlineErrorState:render()
    MenuScene.backdrop()                 -- (el fondo vivo de los menús: src/ui/menu/MenuScene)
    local A = self.anim
    MenuKit.title(L('err.title'), 'red', A, 1)
    local c, b = layout(self.msg)
    local ox, oy, a = A:slide(2, 0, 220)
    MenuKit.box('card', c.x + ox, c.y + oy, c.w, c.h, a)
    -- lo importante es el mensaje; el código, pequeño y apagado debajo (para avisar de un fallo)
    love.graphics.setFont(FONT_MED)
    local _, lines = FONT_MED:getWrap(self.msg, c.w - 64)
    local ty = c.y + 40 + oy
    for i = 1, math.min(4, #lines) do
        MenuKit.text(FONT_MED, lines[i], c.x + ox, ty, c.w, 'center', nil, a)
        ty = ty + FONT_MED:getHeight() + 12
    end
    MenuKit.text(FONT_SMALL, self.code, c.x + ox, c.y + c.h - 40 + oy, c.w, 'center', { 0.85, 0.5, 0.5 }, 0.8 * a)
    local bx, by, ba = A:slide(3, 0, 220)
    local bob = (math.floor(self.t * 3) % 2 == 0) and -4 or 0
    MenuButton.draw(L('err.back_menu'), b.x + bx, b.y + by + bob, b.w, b.h, 'grey', true,
                    { alpha = ba, scale = MenuButton.textScale(L('err.back_menu'), b.w - 48, 4) })
    MenuKit.marker(b.x + bx, b.y + by + bob, b.w, b.h, self.t, ba)
    love.graphics.setColor(COLOR_WHITE)
end

function OnlineErrorState:mousemoved(tx, ty) end

function OnlineErrorState:touchpressed(id, tx, ty)
    self:_back()
end

return OnlineErrorState
