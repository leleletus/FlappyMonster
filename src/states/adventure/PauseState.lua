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
    self.confirm = false                          -- (la pregunta de reintentar: SÍ / NO)
    self.a = 0
    Sound.pauseAll()
end

function PauseState:update(dt)
    self.a = math.min(1, self.a + dt * 6)
    if Input.pressed('nav_up') then
        self.selected = self.selected - 1
        if self.selected < 1 then self.selected = #self:_options() end
        Sound.play('select')
    end
    if Input.pressed('nav_down') then
        self.selected = self.selected + 1
        if self.selected > #self:_options() then self.selected = 1 end
        Sound.play('select')
    end

    -- (cancelar —Esc, Start, el botón de volver— SIEMPRE reanuda; antes ejecutaba lo elegido y con MENÚ salía del nivel)
    if Input.pressed('pause') or Input.pressed('back') then
        if self.confirm then self.confirm, self.selected = false, 2; Sound.play('select', 0.85); return end
        gStateMachine:pop()
        return
    end
    if Input.pressed('confirm') then self:_choose(self.selected) end
end

local CONFIRM_OPTIONS, CONFIRM_COLORS = { 'pause.retry_yes', 'common.cancel' }, { 'yellow', 'green' }
function PauseState:_options() return self.confirm and CONFIRM_OPTIONS or PAUSE_OPTIONS end

function PauseState:_choose(i)
    if self.confirm then
        if CONFIRM_OPTIONS[i] == 'pause.retry_yes' then
            local u = under()
            Sound.play('select')
            Sound.resumeAll(); Sound.stopMusic(); Sound.stopTracked('drowning')
            gStateMachine:pop()
            u:retryNow()
        else
            Sound.play('select', 0.85)
            self.confirm, self.selected = false, 2
        end
        return
    end
    local key = PAUSE_OPTIONS[i]
    if key == 'common.resume' then gStateMachine:pop(); return end
    Sound.play('select')
    Sound.resumeAll(); Sound.stopMusic(); Sound.stopTracked('drowning')
    if key == 'common.retry' then
        local u = under()
        -- (si cuesta una vida, antes se pregunta: la ventana cambia a SÍ / NO con el aviso)
        if u.retryCostsLife and u:retryCostsLife() and not self.confirm then
            self.confirm, self.selected = true, 2
            return
        end
        gStateMachine:pop()
        u:retryNow()
    else
        gStateMachine:change(exitTarget())
    end
end

local function labels(list)
    local l = {}
    for i, k in ipairs(list) do l[i] = L(k):upper() end
    return l
end

function PauseState:render()
    if self.confirm then
        local u = under()
        local left = u and u.player and (u.player.lives - 1) or 0
        MenuKit.optionsWindow(L('pause.retry_title'), labels(CONFIRM_OPTIONS), CONFIRM_COLORS, self.selected, self.a,
                              { note = L('pause.retry_note', { n = left }) })
        love.graphics.setColor(COLOR_WHITE)
        return
    end
    MenuKit.optionsWindow(L('pause.title'), labels(PAUSE_OPTIONS), self.colors, self.selected, self.a)
    love.graphics.setColor(COLOR_WHITE)
end

-- Hover del mouse: mueve la selección real al botón bajo el cursor
function PauseState:mousemoved(tx, ty)
    local i = MenuKit.optionAt(#self:_options(), tx, ty, self.confirm and { note = true } or nil)
    if i and self.selected ~= i then self.selected = i; Sound.play('select') end
end

-- Táctil Switch: tap en el botón
function PauseState:touchpressed(id, tx, ty, dx, dy, pressure)
    local i = MenuKit.optionAt(#self:_options(), tx, ty, self.confirm and { note = true } or nil)
    if not i then return end
    self:_choose(i)
end

return PauseState
