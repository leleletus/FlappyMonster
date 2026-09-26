-- conf.lua
-- LÖVE configuration. En Switch el tamaño real lo impone el sistema,
-- pero declaramos 1280x720 como resolución lógica de trabajo.

function love.conf(t)
    t.identity    = "FlappyMonster"
    t.version     = "11.4"
    t.console     = false   -- en Switch no hay consola, en PC útil para debug

    t.window.title   = "FlappyMonster"
    t.window.width   = 1280
    t.window.height  = 720
    t.window.vsync   = 1
    t.window.resizable = false
    t.window.fullscreen = false   -- lovesize lo maneja por nosotros
    t.window.usedpiscale = false  -- Evita descuadres de resolución en Android

    -- Módulos que no usamos (ahorra memoria en Switch)
    t.modules.joystick  = true   -- NECESARIO para joycons
    t.modules.keyboard  = true   -- útil en debug PC
    t.modules.mouse     = false
    -- El editor de niveles (love . --editor) necesita el ratón
    for _, a in ipairs(arg or {}) do
        if a == '--editor' then t.modules.mouse = true end
    end
    t.modules.touch     = true    -- táctil Switch
    t.modules.video     = false
    t.modules.physics   = false
end