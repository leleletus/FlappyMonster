-- src/states/adventure/PauseState.lua
local BaseState  = require 'src/core/BaseState'
local L = require 'src/core/Lang'
local MenuKit = require 'src/ui/menu/MenuKit'
local PauseState = BaseState:new()

-- (REINTENTAR, si el nivel de debajo lo permite: AdventureState:canRetry)
local PAUSE_OPTIONS = { 'common.resume', 'common.retry', 'common.menu' }   -- claves de idioma
local PAUSE_COLORS  = { 'green', 'yellow', 'red' }
local RETRY_OPTIONS = PAUSE_OPTIONS
local PLAIN_OPTIONS = { 'common.resume', 'common.menu' }
local PLAIN_COLORS  = { 'green', 'red' }

-- Salir: al estado del que vino el juego pausado (p. ej. un nivel del Juego
-- libre vuelve al Juego libre); si no dice nada, al menú principal
local function exitTarget()
    local st = gStateMachine.stack
    local under = st[#st - 1]
    return (under and under.returnTo) or 'main_menu'
end

local function under()
    local st = gStateMachine.stack
    return st[#st - 1]
end

function PauseState:enter(args)
    local st = gStateMachine.stack
    local u = st[#st]                             -- (al entrar la pausa aún no está en la pila: el nivel es el de arriba)
    self.retry = u and u.canRetry and u:canRetry() or false
    PAUSE_OPTIONS = self.retry and RETRY_OPTIONS or PLAIN_OPTIONS
    self.colors = self.retry and PAUSE_COLORS or PLAIN_COLORS
    self.options = PAUSE_OPTIONS                  -- (para los arneses: la última es salir)
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
    if Input.pressed('confirm') then self:_choose(self.selected) end
end

function PauseState:_choose(i)
    local key = PAUSE_OPTIONS[i]
    if key == 'common.resume' then gStateMachine:pop(); return end
    Sound.play('select')
    Sound.resumeAll(); Sound.stopMusic(); Sound.stopTracked('drowning')
    if key == 'common.retry' then
        local u = under()
        gStateMachine:pop()
        u:retryNow()
    else
        gStateMachine:change(exitTarget())
    end
end

local function labels()
    local l = {}
    for i, k in ipairs(PAUSE_OPTIONS) do l[i] = L(k):upper() end
    return l
end

function PauseState:render()
    MenuKit.optionsWindow(L('pause.title'), labels(), self.colors, self.selected, self.a)
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
    self:_choose(i)
end

return PauseState
