-- src/states/OnlineErrorState.lua
-- Pantalla de error de red.  Se muestra cuando la conexión falla o se pierde
-- por cualquier motivo.  Única opción: volver al menú de selección de modo.

local BaseState        = require 'src/BaseState'
local NC               = require 'src/network/NetworkClient'
local OnlineErrorState = BaseState:new()

local imgBg = nil
local function loadAssets()
    if imgBg then return end
    imgBg = love.graphics.newImage('assets/images/menus/MenuDif.png')
end

function OnlineErrorState:enter(args)
    loadAssets()
    args         = args or {}
    self.code    = args.code or "ERR_NETWORK"
    self.msg     = args.msg  or "Se perdio la conexion con el servidor."
    self.alpha   = 0
    self.hovered = false
    NC:disconnect()
    Sound.playMusic('menus')
end

function OnlineErrorState:update(dt)
    self.alpha = math.min(1, self.alpha + dt * 4)
    if Input.pressed('confirm') or Input.pressed('back') then
        gStateMachine:change('adv_mode_select')
    end
end

function OnlineErrorState:render()
    local bx = WINDOW_W / imgBg:getWidth()
    local by = WINDOW_H / imgBg:getHeight()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(imgBg, 0, 0, 0, bx, by)

    local a = self.alpha

    love.graphics.setColor(0, 0, 0, 0.72 * a)
    love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)

    local panelW = math.min(620, WINDOW_W - 80)
    local panelH = 310
    local panelX = math.floor((WINDOW_W - panelW) / 2)
    local panelY = math.floor((WINDOW_H - panelH) / 2)

    love.graphics.setColor(0.06, 0.02, 0.02, 0.97 * a)
    love.graphics.rectangle('fill', panelX, panelY, panelW, panelH)
    love.graphics.setColor(1, 1, 1, 0.8 * a)
    love.graphics.rectangle('line', panelX, panelY, panelW, panelH)
    love.graphics.setColor(0, 0, 0, 0.6 * a)
    love.graphics.rectangle('line', panelX+2, panelY+2, panelW-4, panelH-4)

    love.graphics.setFont(FONT_BIG)
    love.graphics.setColor(1, 0.22, 0.22, a)
    love.graphics.printf('ERROR DE RED', 0, panelY + 20, WINDOW_W, 'center')

    love.graphics.setColor(1, 0.22, 0.22, 0.3 * a)
    love.graphics.line(panelX + 24, panelY + 66, panelX + panelW - 24, panelY + 66)

    love.graphics.setFont(FONT_SMALL)
    love.graphics.setColor(1, 0.5, 0.5, 0.85 * a)
    love.graphics.printf(self.code, panelX + 20, panelY + 80, panelW - 40, 'center')

    love.graphics.setFont(FONT_SMALL)
    love.graphics.setColor(1, 1, 1, 0.7 * a)
    love.graphics.printf(self.msg, panelX + 28, panelY + 112, panelW - 56, 'center')

    local btnW = 320
    local btnH = 52
    local btnX = math.floor(WINDOW_W / 2 - btnW / 2)
    local btnY = panelY + panelH - 74

    local isHov = self.hovered and Input.lastDevice == 'mouse'
    love.graphics.setColor(isHov and {1,1,1,a} or {0,0,0,a})
    love.graphics.rectangle('fill', btnX, btnY, btnW, btnH)
    love.graphics.setColor(isHov and {0,0,0,a} or {1,1,1,a})
    love.graphics.rectangle('line', btnX, btnY, btnW, btnH)
    love.graphics.setFont(FONT_MED)
    love.graphics.setColor(isHov and {0,0,0,a} or {1,1,1,a})
    love.graphics.printf('VOLVER AL MENU', btnX, btnY + btnH/2 - FONT_MED:getHeight()/2, btnW, 'center')

    love.graphics.setColor(COLOR_WHITE)
end

-- Hover del mouse
function OnlineErrorState:mousemoved(tx, ty)
    local panelH = 310
    local panelY = math.floor((WINDOW_H - panelH) / 2)
    local btnW   = 320
    local btnH   = 52
    local btnX   = math.floor(WINDOW_W / 2 - btnW / 2)
    local bY     = panelY + panelH - 74
    local prev   = self.hovered
    self.hovered = tx >= btnX-8 and tx <= btnX+btnW+8 and ty >= bY-5 and ty <= bY+btnH+5
    if self.hovered and not prev then Sound.play('select') end
end

function OnlineErrorState:touchpressed(id, tx, ty)
    gStateMachine:change('adv_mode_select')
end

return OnlineErrorState
