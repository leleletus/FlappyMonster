-- main.lua
lovesize     = require 'libs/lovesize'
Timer        = require 'libs/timer'

require 'settings'
Input        = require 'input'
Sound        = require 'src/Sound'
StateMachine = require 'src/StateMachine'

-- NetworkClient: singleton global para el modo online
NC = require 'src/network/NetworkClient'

local TitleState                  = require 'src/states/TitleState'
local MainMenuState               = require 'src/states/MainMenuState'
local DifficultySelectionState    = require 'src/states/DifficultySelectionState'
local PlayState                   = require 'src/states/PlayState'
local PauseState                  = require 'src/states/PauseState'
local AdventureState              = require 'src/states/AdventureState'
local AdventureModeSelectState    = require 'src/states/AdventureModeSelectState'
local OnlineLoginState            = require 'src/states/OnlineLoginState'
local OnlineHubState              = require 'src/states/OnlineHubState'
local OnlineRoomState             = require 'src/states/OnlineRoomState'
local OnlineAdventureState        = require 'src/states/OnlineAdventureState'
local OnlineErrorState            = require 'src/states/OnlineErrorState'

DEBUG_HITBOX = false   -- F1 para activar/desactivar hitboxes

function love.load()
    -- Autoadaptar la resolución lógica para móviles y tablets (Evitar Zoom excesivo)
    local sw, sh = love.graphics.getDimensions()
    local aspect = sw / sh
    aspect = math.max(4/3, math.min(21/9, aspect)) -- Limitar para no deformar UI
    WINDOW_W = math.floor(720 * aspect)

    love.graphics.setDefaultFilter('nearest', 'nearest')
    lovesize.set(WINDOW_W, WINDOW_H)

    -- Fuentes pixel art globales (Press Start 2P)
    -- Archivo: assets/fonts/PressStart2P.ttf
    FONT_SMALL = love.graphics.newFont('assets/fonts/PressStart2P.ttf', 10)
    FONT_MED   = love.graphics.newFont('assets/fonts/PressStart2P.ttf', 16)
    FONT_BIG   = love.graphics.newFont('assets/fonts/PressStart2P.ttf', 28)
    love.graphics.setFont(FONT_MED)

    Input.load()
    Input.lastDevice = Input.isMobile and 'touch' or 'keyboard'
    Sound.load()

    gStateMachine = StateMachine:new({
        title              = function() return TitleState:new() end,
        main_menu          = function() return MainMenuState:new() end,
        difficulty         = function() return DifficultySelectionState:new() end,
        play               = function() return PlayState:new() end,
        pause              = function() return PauseState:new() end,
        adventure          = function() return AdventureState:new() end,
        -- Modo online
        adv_mode_select    = function() return AdventureModeSelectState:new() end,
        online_login       = function() return OnlineLoginState:new() end,
        online_hub         = function() return OnlineHubState:new() end,
        online_room        = function() return OnlineRoomState:new() end,
        online_adventure   = function() return OnlineAdventureState:new() end,
        online_error       = function() return OnlineErrorState:new() end,
    })
    gStateMachine:change('title')
end

function love.update(dt)
    dt = math.min(dt, 0.05)
    Timer.update(dt)
    Input.update(dt)
    NC:update(dt)
    gStateMachine:update(dt)
end

function love.draw()
    lovesize.begin()
        gStateMachine:render()
    lovesize.finish()
end

function love.joystickadded(joystick)
    Input.joystickadded(joystick)
end

-- Actualizar lovesize cuando Android rota o cambia el tamaño real de la ventana
function love.resize(w, h)
    local aspect = w / h
    aspect = math.max(4/3, math.min(21/9, aspect))
    WINDOW_W = math.floor(720 * aspect)
    
    if lovesize and lovesize.set then
        lovesize.set(WINDOW_W, WINDOW_H)
    end
end

-- Táctil (Switch / Android / iOS): reenviar al estado del tope de la pila
function love.touchpressed(id, x, y, dx, dy, pressure)
    if not gStateMachine then return end

    -- Convertir coordenadas de pantalla (Android) a lógicas (1280x720) para los botones
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local scale = math.min(sw / WINDOW_W, sh / WINDOW_H)
    local offX = (sw - WINDOW_W * scale) / 2
    local offY = (sh - WINDOW_H * scale) / 2
    local lx = (x - offX) / scale
    local ly = (y - offY) / scale

    local state = gStateMachine:_top()
    if state and state.touchpressed then
        state:touchpressed(id, lx, ly, dx, dy, pressure)
        else
            -- Fallback global para menús: dividir la pantalla en 3 zonas
            local sh = love.graphics.getHeight()
            if y < sh * 0.33 then
                Input.VirtualPad._pressedThisFrame['nav_up'] = true
            elseif y > sh * 0.66 then
                Input.VirtualPad._pressedThisFrame['nav_down'] = true
            else
                Input.VirtualPad._pressedThisFrame['confirm'] = true
            end
    end
end

function love.focus(f)
    if not f then
        if gStateMachine then
            local state = gStateMachine:_top()
            if state and state.pauseGame then state:pauseGame() end
        end
        love.audio.setVolume(0)
    else
        love.audio.setVolume(1)
    end
end

function love.keypressed(k)
    if k == 'f1' then DEBUG_HITBOX = not DEBUG_HITBOX end
    Input.lastDevice = 'keyboard'
    -- Reenviar al estado actual (para campos de texto en menús online)
    local state = gStateMachine:_top()
    if state and state.keypressed then state:keypressed(k) end
    if k == 'escape' then return true end -- Evita que Android cierre el juego abruptamente
end

-- Reenviar entrada de texto al estado actual (menús online)
function love.textinput(t)
    local state = gStateMachine:_top()
    if state and state.textinput then state:textinput(t) end
end

function love.joystickpressed(joystick, button)
    Input.lastDevice = 'gamepad'
end

-- Registrar cuando se toca la pantalla
local oldTouchpressed = love.touchpressed
function love.touchpressed(id, x, y, dx, dy, pressure)
    Input.lastDevice = 'touch'
    oldTouchpressed(id, x, y, dx, dy, pressure)
end

-- Movimiento del mouse: actualiza hover en el estado actual
function love.mousemoved(x, y, dx, dy, istouch)
    if istouch then return end
    if not gStateMachine then return end
    Input.lastDevice = 'mouse'
    local sw, sh  = love.graphics.getWidth(), love.graphics.getHeight()
    local scale   = math.min(sw / WINDOW_W, sh / WINDOW_H)
    local offX    = (sw - WINDOW_W * scale) / 2
    local offY    = (sh - WINDOW_H * scale) / 2
    local lx      = (x - offX) / scale
    local ly      = (y - offY) / scale
    local state   = gStateMachine:_top()
    if state and state.mousemoved then
        state:mousemoved(lx, ly)
    end
end

-- Clic del mouse (PC / pantalla táctil de escritorio): redirige al mismo manejador que el toque
function love.mousepressed(x, y, button, istouch, presses)
    if istouch then return end          -- ya lo maneja love.touchpressed (evita doble disparo)
    if button ~= 1 then return end      -- solo botón izquierdo
    if not gStateMachine then return end
    Input.lastDevice = 'mouse'

    local sw, sh  = love.graphics.getWidth(), love.graphics.getHeight()
    local scale   = math.min(sw / WINDOW_W, sh / WINDOW_H)
    local offX    = (sw - WINDOW_W * scale) / 2
    local offY    = (sh - WINDOW_H * scale) / 2
    local lx      = (x - offX) / scale
    local ly      = (y - offY) / scale

    local state = gStateMachine:_top()
    if state and state.touchpressed then
        state:touchpressed('mouse', lx, ly, 0, 0, 1)
    else
        -- Fallback: dividir la pantalla en 3 zonas (igual que touchpressed)
        if y < sh * 0.33 then
            Input.VirtualPad._pressedThisFrame['nav_up'] = true
        elseif y > sh * 0.66 then
            Input.VirtualPad._pressedThisFrame['nav_down'] = true
        else
            Input.VirtualPad._pressedThisFrame['confirm'] = true
        end
    end
end

function love.quit() end