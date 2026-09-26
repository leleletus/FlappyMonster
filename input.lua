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
    back      = {'key:escape', 'button:back'},
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
}

local labelsConsole = {
    flap       = "[A]",    pause     = "[+]",     resume    = "[B]",
    back       = "[-]",    nav_up    = "[^]",     nav_down  = "[v]",
    nav_left   = "[<]",    nav_right = "[>]",     confirm   = "[A]",
    move_left  = "[<]",    move_right= "[>]",     jump      = "[A]",
    crouch     = "[v]",
}
local labelsPC = {
    flap       = "[Space]", pause  = "[Esc]",   resume = "[Enter]",
    back       = "[Esc]",   nav_up  = "[^]",    nav_down  = "[v]",
    nav_left   = "[<]",     nav_right= "[>]",   confirm   = "[Enter]",
    move_left  = "[<]",     move_right= "[>]",  jump      = "[Space]",
    crouch     = "[Down]",
}

function Input.label(action)
    local t = Input.isPC and labelsPC or labelsConsole
    return t[action] or ("[" .. action .. "]")
end

Input.VirtualPad = { pressed = {}, down = {}, _pressedThisFrame = {} }

local player

function Input.load()
    player = baton.new({
        controls = controls,
        joystick = love.joystick.getJoysticks()[1]
    })
end

function Input.update(dt)
    if not player.joystick then
        local js = love.joystick.getJoysticks()[1]
        if js then player.joystick = js end
    end
    player:update()

    -- Procesar toques virtuales del frame actual. Duran SOLO este frame: si
    -- nadie los consume no deben quedar pendientes (un clic suelto disparaba
    -- un CONFIRMAR segundos después en otra pantalla).
    Input.VirtualPad.pressed = {}
    for action, _ in pairs(Input.VirtualPad._pressedThisFrame) do
        Input.VirtualPad.pressed[action] = true
    end
    Input.VirtualPad._pressedThisFrame = {}
end

function Input.joystickadded(joystick)
    if not player.joystick then player.joystick = joystick end
end

function Input.pressed(action)
    if Input.VirtualPad.pressed[action] then
        Input.VirtualPad.pressed[action] = false -- consumir
        return true
    end
    return player:pressed(action) 
end

function Input.down(action)
    return Input.VirtualPad.down[action] or player:down(action)
end

return Input