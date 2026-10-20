-- src/states/adventure/PauseState.lua
local BaseState  = require 'src/core/BaseState'
local L = require 'src/core/Lang'
local MenuKit = require 'src/ui/menu/MenuKit'
local PauseState = BaseState:new()

local PAUSE_OPTIONS = { 'common.resume', 'common.menu' }   -- claves de idioma
local PAUSE_COLORS  = { 'green', 'red' }

-- Salir: al estado del que vino el juego pausado (p. ej. un nivel del Juego
-- libre vuelve al Juego libre); si no dice nada, al menú principal
local function exitTarget()
    local st = gStateMachine.stack
    local under = st[#st - 1]
    return (under and under.returnTo) or 'main_menu'
end

function PauseState:enter(args)
    self.selected = 1
    self.a = 0
    Sound.pauseAll()
end

function PauseState:update(dt)
    self.a = math.min(1, self.a + dt * 6)
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

    -- (cancelar —Esc, Start, el botón de volver— SIEMPRE reanuda; antes ejecutaba lo elegido y con MENÚ salía del nivel)
    if Input.pressed('pause') or Input.pressed('back') then
        gStateMachine:pop()
        return
    end
    if Input.pressed('confirm') then
        if self.selected == 1 then
            gStateMachine:pop()
        else
            Sound.play('select')
            Sound.resumeAll(); Sound.stopMusic(); Sound.stopTracked('drowning')
            gStateMachine:change(exitTarget())
        end
    end
end

local function labels()
    local l = {}
    for i, k in ipairs(PAUSE_OPTIONS) do l[i] = L(k):upper() end
    return l
end

function PauseState:render()
    MenuKit.optionsWindow(L('pause.title'), labels(), PAUSE_COLORS, self.selected, self.a)
    love.graphics.setColor(COLOR_WHITE)
end

-- Hover del mouse: mueve la selección real al botón bajo el cursor
function PauseState:mousemoved(tx, ty)
    local i = MenuKit.optionAt(#PAUSE_OPTIONS, tx, ty)
    if i and self.selected ~= i then self.selected = i; Sound.play('select') end
end

-- Táctil Switch: tap en el botón
function PauseState:touchpressed(id, tx, ty, dx, dy, pressure)
    local i = MenuKit.optionAt(#PAUSE_OPTIONS, tx, ty)
    if not i then return end
    if i == 1 then
        gStateMachine:pop()
    else
        Sound.play('select')
        Sound.resumeAll(); Sound.stopMusic(); Sound.stopTracked('drowning')
        gStateMachine:change(exitTarget())
    end
end

return PauseState
