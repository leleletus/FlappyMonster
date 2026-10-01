-- tools/tests/flappy_hud — el HUD del modo Flappy (clásico) con el juego real:
--  1. jugando, récord sin superar (puntuación grande + corona + placa de dificultad)
--  2. jugando, récord superado (¡nuevo récord! parpadeando) y destello de 10 puntos
--  3. fin de partida (tarjeta con la puntuación y el récord + botones)
--  capturas <save>/flappy_hud_{1,2,3}.png; falla si hay errores de Lua
--
--   tools/tests/run.sh flappy_hud
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
love.filesystem.load('game_main.lua')()
local gameLoad, gameUpdate, gameDraw = love.load, love.update, love.draw
local frame, st = 0, nil

function love.load(a)
    gameLoad(a)
    for _, cb in ipairs({ 'mousemoved', 'mousepressed', 'mousereleased', 'wheelmoved', 'touchpressed',
                          'touchmoved', 'touchreleased', 'focus' }) do love[cb] = function() end end
    love.audio.setVolume(0)
    gStateMachine:change('play', { difficulty = 'hard' })
    st = gStateMachine:_top()
    st.highScore = 12
end

local function shot(n)
    love.graphics.captureScreenshot(function(img) img:encode('png', 'flappy_hud_' .. n .. '.png') end)
end

function love.update(dt)
    frame = frame + 1
    -- (el jugador no se cae: se queda quieto en el centro)
    if st.player then st.player.y, st.player.vy = WINDOW_H / 2, 0 end
    gameUpdate(dt)
    if frame == 20 then st.score = 7; st.popT = 0.12 end
    if frame == 24 then shot(1) end
    if frame == 30 then st.score = 20; st.flashT = 0.6 end
    if frame == 33 then shot(2) end
    if frame == 40 then st:die() end
    if frame == 110 then shot(3) end
    if frame == 116 then
        print('capturas en ' .. love.filesystem.getSaveDirectory() .. '/flappy_hud_{1,2,3}.png')
        print('TODO OK'); love.event.quit(0)
    end
end
