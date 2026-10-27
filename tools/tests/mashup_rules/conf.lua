function love.conf(t)
    t.identity = "fm_test_mashup"
    -- (GAME=1: el juego de verdad, a su tamaño)
    if os.getenv('GAME') then t.window.width, t.window.height, t.window.vsync = 1280, 720, 0
    else t.window.width, t.window.height = 64, 64 end
end
