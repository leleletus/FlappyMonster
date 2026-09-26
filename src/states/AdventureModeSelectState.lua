-- src/states/AdventureModeSelectState.lua
-- Menú intermedio: SOLO (singleplayer) u ONLINE (multijugador).
-- Se muestra al elegir Adventure en el menú principal.

local CornerButtons = require 'src/ui/CornerButtons'
local BaseState               = require 'src/BaseState'
local AdventureModeSelectState = BaseState:new()

local imgBg = nil
local function loadAssets()
    if imgBg then return end
    imgBg = love.graphics.newImage('assets/images/menus/MenuDif.png')
end

local OPTIONS = { 'SOLO', 'ONLINE' }
local BTN_W   = 320
local BTN_H   = 58
local BTN_GAP = 30

-- ── Helpers de dibujo ─────────────────────────────────────────────────────────

local function drawBtn(label, cx, y, w, h, selected)
    if selected then
        -- Sombra
        love.graphics.setColor(0.18, 0.18, 0.18, 1)
        love.graphics.rectangle('fill', cx - w/2 + 4, y + 4, w, h)
        -- Fondo blanco
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle('fill', cx - w/2, y, w, h)
        -- Borde amarillo brillante
        love.graphics.setColor(1, 0.85, 0, 1)
        love.graphics.rectangle('line', cx - w/2, y, w, h)
        -- Texto negro
        love.graphics.setFont(FONT_MED)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.printf(label, cx - w/2, y + h/2 - FONT_MED:getHeight()/2, w, 'center')
    else
        love.graphics.setColor(1, 1, 1, 0.38)
        love.graphics.rectangle('line', cx - w/2, y, w, h)
        love.graphics.setFont(FONT_MED)
        love.graphics.setColor(1, 1, 1, 0.48)
        love.graphics.printf(label, cx - w/2, y + h/2 - FONT_MED:getHeight()/2, w, 'center')
    end
end

local function btnY(i)
    local totalH = #OPTIONS * BTN_H + (#OPTIONS - 1) * BTN_GAP
    local startY = math.floor(WINDOW_H / 2 - totalH / 2 + 30)
    return startY + (i - 1) * (BTN_H + BTN_GAP)
end

-- ── Enter ─────────────────────────────────────────────────────────────────────

function AdventureModeSelectState:enter(args)
    loadAssets()
    self.selected = 1
    Sound.playMusic('menus')
end

-- ── Update ────────────────────────────────────────────────────────────────────

function AdventureModeSelectState:update(dt)
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
        self:_select(self.selected)
    end

    if Input.pressed('back') then
        Sound.play('select')
        gStateMachine:change('main_menu')
    end
end

function AdventureModeSelectState:_select(i)
    if i == 1 then
        gStateMachine:change('adventure', { level = 'assets/levels/nivel01.json' })
    else
        gStateMachine:change('online_login')
    end
end

-- ── Render ────────────────────────────────────────────────────────────────────

function AdventureModeSelectState:render()
    -- Fondo
    local bx = WINDOW_W / imgBg:getWidth()
    local by = WINDOW_H / imgBg:getHeight()
    love.graphics.setColor(COLOR_WHITE)
    love.graphics.draw(imgBg, 0, 0, 0, bx, by)

    -- Título
    love.graphics.setFont(FONT_BIG)
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.printf('ADVENTURE', 2, WINDOW_H/2 - 148, WINDOW_W, 'center')
    love.graphics.setColor(1, 0.95, 0.15, 1)
    love.graphics.printf('ADVENTURE', 0, WINDOW_H/2 - 150, WINDOW_W, 'center')

    -- Botones
    local cx = WINDOW_W / 2
    for i, opt in ipairs(OPTIONS) do
        drawBtn(opt, cx, btnY(i), BTN_W, BTN_H, i == self.selected)
    end

    love.graphics.setColor(COLOR_WHITE)
    CornerButtons.drawBack(self.backHover)
end

-- ── Hover del mouse: mueve la selección real al botón bajo el cursor ──────────

function AdventureModeSelectState:mousemoved(tx, ty)
    self.backHover = CornerButtons.hitBack(tx, ty)
    if self.backHover then return end
    local cx = WINDOW_W / 2
    for i = 1, #OPTIONS do
        local y  = btnY(i)
        local bx = cx - BTN_W / 2
        if tx >= bx-10 and tx <= bx+BTN_W+10 and ty >= y-5 and ty <= y+BTN_H+5 then
            if self.selected ~= i then self.selected = i; Sound.play('select') end
            return
        end
    end
end

-- ── Touch ─────────────────────────────────────────────────────────────────────

function AdventureModeSelectState:touchpressed(id, tx, ty)
    if CornerButtons.hitBack(tx, ty) then
        Sound.play('select')
        gStateMachine:change('main_menu')
        return
    end
    local cx = WINDOW_W / 2
    for i = 1, #OPTIONS do
        local y  = btnY(i)
        local bx = cx - BTN_W / 2
        if tx >= bx - 10 and tx <= bx + BTN_W + 10 and
           ty >= y - 5   and ty <= y + BTN_H + 5 then
            Sound.play('select')
            self:_select(i)
            return
        end
    end
end

return AdventureModeSelectState
