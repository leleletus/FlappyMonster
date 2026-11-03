-- src/states/online/OnlineErrorState.lua
-- Pantalla de error de red.  Se muestra cuando la conexión falla o se pierde
-- por cualquier motivo.  Volver al menú de selección de modo; si se cortó en plena partida (NC.rejoin), también VOLVER A
-- LA PARTIDA: entra otra vez con el mismo nombre y el servidor lo devuelve a su jugador (60 s: server/srv/lobby.lua).

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
    local rejoin = NC.rejoin                -- (NC:disconnect lo olvida todo: se guarda)
    NC:disconnect()
    NC.rejoin = rejoin
    self.canRejoin = rejoin ~= nil and self.code == "ERR_CONNECTION_LOST"
    self.sel = self.canRejoin and 1 or 2
    Sound.playMusic('menus')
end

function OnlineErrorState:_rejoin()
    if self.anim:busy() then return end
    Sound.play('select', 1.25)
    self.anim:leave(function() gStateMachine:change('online_login', { auto = true }) end)
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
    if self.canRejoin and (Input.pressed('nav_up') or Input.pressed('nav_down')) then self.sel = 3 - self.sel; Sound.play('select') end
    if Input.pressed('back') then self:_back()
    elseif Input.pressed('confirm') then if self.sel == 1 then self:_rejoin() else self:_back() end end
end

-- Geometría (dibujo, ratón y táctil)
local function layout(msg)
    local w = math.min(680, WINDOW_W - 120)
    local x = math.floor((WINDOW_W - w) / 2)
    love.graphics.setFont(FONT_MED)
    local _, lines = FONT_MED:getWrap(msg or '', w - 64)
    local card = { x = x, y = math.floor(WINDOW_H * 0.30), w = w, h = 112 + math.min(4, #lines) * (FONT_MED:getHeight() + 12) }
    local bw = math.min(360, w - 80)
    local back = { x = math.floor((WINDOW_W - bw) / 2), y = card.y + card.h + 32, w = bw, h = 56 }
    return card, back, { x = back.x, y = back.y + 72, w = bw, h = 56 }
end

function OnlineErrorState:render()
    MenuScene.backdrop('error')                 -- (ladrillos del Flappy: src/ui/menu/MenuScene)
    local A = self.anim
    MenuKit.title(L('err.title'), 'red', A, 1)
    local c, b, b2 = layout(self.msg)
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
    -- (con VOLVER A LA PARTIDA: ella arriba, el menú debajo)
    local items = self.canRejoin and { { 'err.rejoin', 'green', b }, { 'err.back_menu', 'grey', b2 } } or { nil, { 'err.back_menu', 'grey', b } }
    for i = 1, 2 do
        local it = items[i]
        if it then
            local r, on = it[3], i == self.sel
            local yb = on and bob or 0
            MenuButton.draw(L(it[1]), r.x + bx, r.y + by + yb, r.w, r.h, it[2], on, { alpha = ba, scale = MenuButton.textScale(L(it[1]), r.w - 48, 4) })
            if on then MenuKit.marker(r.x + bx, r.y + by + yb, r.w, r.h, self.t, ba) end
        end
    end
    love.graphics.setColor(COLOR_WHITE)
end

function OnlineErrorState:mousemoved(tx, ty) end

function OnlineErrorState:touchpressed(id, tx, ty)
    local _, b = layout(self.msg)
    if self.canRejoin and tx >= b.x and tx <= b.x + b.w and ty >= b.y and ty <= b.y + b.h then return self:_rejoin() end
    self:_back()
end

return OnlineErrorState
