-- input.lua
local baton = require 'libs/baton'
local Input = {}

local osName   = love.system.getOS()
Input.isSwitch = (osName == "Horizon") or (osName == "NX")
Input.isMobile = (osName == "Android") or (osName == "iOS")
Input.isPC     = not (Input.isSwitch or Input.isMobile)

local controls = {
    -- Flappy: solo space y button:b (NO dpup ni key:w para no chocar con nav_up)
    flap      = {'key:space', 'button:b'},
    pause     = {'key:escape', 'button:start'},
    -- resume y confirm separados: resume solo en pausa, confirm solo en menús
    resume    = {'key:return', 'button:a'},
    back      = {'key:escape', 'button:back', 'button:a'},
    -- Menús
    nav_up    = {'key:up',    'button:dpup',    'axis:lefty-'},
    nav_down  = {'key:down',  'button:dpdown',  'axis:lefty+'},
    nav_left  = {'key:left',  'button:dpleft',  'axis:leftx-'},
    nav_right = {'key:right', 'button:dpright', 'axis:leftx+'},
    confirm   = {'key:return', 'button:b'},
    -- Aventura
    move_left  = {'key:left',  'key:a', 'button:dpleft',  'axis:leftx-'},
    move_right = {'key:right', 'key:d', 'button:dpright', 'axis:leftx+'},
    jump       = {'key:space', 'key:up', 'key:w',
                   'button:b', 'button:dpup'},
    crouch     = {'key:down', 'key:s', 'button:dpdown', 'axis:lefty+'},
    -- Linterna (niveles a oscuras): encender / apagar
    light      = {'key:f', 'key:lshift', 'button:x', 'button:y'},
}

-- (mando, distribución Nintendo: confirmar = A, a la derecha; volver = B, abajo — `button:a` de SDL)
local labelsConsole = {
    flap       = "[A]",    pause     = "[+]",     resume    = "[B]",
    back       = "[B]",    nav_up    = "[^]",     nav_down  = "[v]",
    nav_left   = "[<]",    nav_right = "[>]",     confirm   = "[A]",
    move_left  = "[<]",    move_right= "[>]",     jump      = "[A]",
    crouch     = "[v]",    light     = "[Y]",
}
local labelsPC = {
    flap       = "[Space]", pause  = "[Esc]",   resume = "[Enter]",
    back       = "[Esc]",   nav_up  = "[^]",    nav_down  = "[v]",
    nav_left   = "[<]",     nav_right= "[>]",   confirm   = "[Enter]",
    move_left  = "[<]",     move_right= "[>]",  jump      = "[Space]",
    crouch     = "[Down]",  light = "[F]",
}

-- ¿Se está usando un mando? (el último aparato tocado; en la Switch, siempre que no sea el táctil)
function Input.usingPad()
    if Input.lastDevice == 'gamepad' then return true end
    if Input.lastDevice == 'keyboard' or Input.lastDevice == 'mouse' then return false end
    return not Input.isPC and not Input.isMobile
end

-- La tecla / el botón de una acción, según el aparato que se está usando (antes solo según la plataforma: un PC con
-- mando veía [Enter] y la Switch o Android veían las teclas del PC en las ayudas)
function Input.label(action)
    local t = Input.usingPad() and labelsConsole or labelsPC
    return t[action] or ("[" .. action .. "]")
end

-- Las teclas de las AYUDAS de los menús ({ok}, {back}, {arrows}...: src/core/Lang.lua las rellena solas). Se rehace
-- solo al cambiar de aparato o de idioma (se dibuja cada fotograma: sin basura)
local hintCache, hintPad, hintLang
function Input.hints()
    local L = require 'src/core/Lang'
    local pad, lang = Input.usingPad(), L.current()
    if hintCache and hintPad == pad and hintLang == lang then return hintCache end
    hintPad, hintLang = pad, lang
    if pad then
        hintCache = { ok = labelsConsole.confirm, back = labelsConsole.back, arrows = L('keys.dpad'), lr = '[<][>]',
                      ud = '[^][v]', up = '[^]', down = '[v]', diff = labelsConsole.light, del = labelsConsole.light }
    else
        hintCache = { ok = '[ENTER]', back = '[ESC]', arrows = L('keys.arrows'), lr = L('keys.lr'), ud = L('keys.ud'),
                      up = L('keys.up'), down = L('keys.down'), diff = labelsPC.light, del = L('keys.del') }
    end
    return hintCache
end

Input.VirtualPad = { pressed = {}, down = {}, _pressedThisFrame = {} }

local player

-- REPETICIÓN de las flechas de los menús al mantenerlas (antes, una pulsación por paso: 44 niveles del Juego libre
-- eran 44 toques): tras REPEAT_DELAY s, una cada REPEAT_EVERY s
local REPEAT_DELAY, REPEAT_EVERY = 0.38, 0.09
local NAV = { 'nav_up', 'nav_down', 'nav_left', 'nav_right' }
local heldT, nextT, repeatNow = {}, {}, {}

function Input.load()
    player = baton.new({
        controls = controls,
        joystick = love.joystick.getJoysticks()[1]
    })
end

function Input.update(dt)
    if not player.joystick or not player.joystick:isConnected() then
        player.joystick = nil
        for _, js in ipairs(love.joystick.getJoysticks()) do
            if js:isConnected() then player.joystick = js; break end
        end
    end
    player:update()
    for _, a in ipairs(NAV) do
        repeatNow[a] = false
        if player:down(a) then
            if player:pressed(a) or not heldT[a] then heldT[a], nextT[a] = 0, REPEAT_DELAY
            else
                heldT[a] = heldT[a] + (dt or 0)
                if heldT[a] >= nextT[a] then repeatNow[a] = true; nextT[a] = nextT[a] + REPEAT_EVERY end
            end
        else
            heldT[a] = nil
        end
    end

    -- Procesar toques virtuales del frame actual. Duran SOLO este frame: si
    -- nadie los consume no deben quedar pendientes (un clic suelto disparaba
    -- un CONFIRMAR segundos después en otra pantalla).
    Input.VirtualPad.pressed = {}
    for action, _ in pairs(Input.VirtualPad._pressedThisFrame) do
        Input.VirtualPad.pressed[action] = true
    end
    Input.VirtualPad._pressedThisFrame = {}
end

-- Mandos que se conectan / desconectan: el nuevo se usa si no hay ninguno (o el de antes ya no está); el que se
-- desconecta se suelta (antes el objeto viejo se quedaba y un mando vuelto a enchufar no hacía nada)
function Input.joystickadded(joystick)
    if not player.joystick or not player.joystick:isConnected() then player.joystick = joystick end
end
function Input.joystickremoved(joystick)
    if player.joystick == joystick then
        player.joystick = nil
        for _, js in ipairs(love.joystick.getJoysticks()) do
            if js ~= joystick and js:isConnected() then player.joystick = js; break end
        end
    end
end

function Input.pressed(action)
    if Input.VirtualPad.pressed[action] then
        Input.VirtualPad.pressed[action] = false -- consumir
        return true
    end
    return player:pressed(action) or repeatNow[action] == true
end

function Input.down(action)
    return Input.VirtualPad.down[action] or player:down(action)
end

return Input