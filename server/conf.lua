function love.conf(t)
    -- Detectar si se pide modo headless (solo consola, sin ventana).
    -- Uso:  love --console server --headless
    -- Sin --headless se abre la ventana gráfica de monitoreo.
    local headless = false
    for _, a in ipairs(arg or {}) do
        if a == "--headless" then headless = true; break end
    end

    if headless then
        -- Modo solo-consola: desactivar ventana y módulos gráficos
        t.window = false
        t.modules.graphics = false
        t.modules.audio    = false
        t.modules.sound    = false
        t.modules.video    = false
        t.modules.joystick = false
    else
        -- Modo ventana: UI visual de monitoreo
        t.window.title  = "FlappyMonster Online Server"
        t.window.width  = 860
        t.window.height = 640
        t.modules.audio    = false
        t.modules.sound    = false
        t.modules.video    = false
        t.modules.joystick = false
    end
end