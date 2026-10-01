-- tools/tests/flappy_hud — el HUD del modo Flappy (clásico) con el juego real:
--  1. jugando, récord sin superar (puntuación grande + corona + placa de dificultad)
--  2. jugando, récord superado (¡nuevo récord! parpadeando) y destello de 10 puntos
--  3. fin de partida (tarjeta con la puntuación y el récord + botones)
--  capturas <save>/flappy_hud_{1,2,3}.png; falla si hay errores de Lua
-- BOT=1: un piloto automático juega fácil, normal y difícil con la física real
--  (apunta al centro del hueco siguiente) hasta 150 tuberías o morir: demuestra que
--  los saltos entre huecos se alcanzan aun a la velocidad máxima (FALLA si muere
--  antes de 150 en fácil o normal); da tuberías pasadas y velocidad final
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
    if os.getenv('BOT') then return end
    gStateMachine:change('play', { difficulty = 'hard' })
    st = gStateMachine:_top()
    st.highScore = 12
end

local function shot(n)
    love.graphics.captureScreenshot(function(img) img:encode('png', 'flappy_hud_' .. n .. '.png') end)
end

local BOT = os.getenv('BOT')
local botDiffs, botI, botFlap = { 'easy', 'normal', 'hard' }, 0, false
local realInput
local function nextBot()
    botI = botI + 1
    if botI > #botDiffs then love.event.quit(fails == 0 and 0 or 1); return end
    gStateMachine:change('play', { difficulty = botDiffs[botI] })
    st = gStateMachine:_top()
end
fails = 0

function love.update(dt)
    if BOT then
        realInput = realInput or Input
        for _ = 1, 8 do                                          -- (8 pasos por fotograma)
            if not st or st.diffKey ~= botDiffs[botI] then nextBot(); if not st then return end end
            -- Piloto: el centro del hueco de la tubería más cercana que aún no ha pasado
            local target = WINDOW_H / 2
            for _, p in ipairs(st.pipes) do
                if p.x + p.w > st.player.x - 10 then target = p.gapY; break end
            end
            local flap = st.player.y > target + 18 and st.player.vy > -60
            Input = setmetatable({ pressed = function(a) return a == 'flap' and flap end, down = function() return false end },
                                 { __index = realInput })
            gameUpdate(1 / 60)
            Input = realInput
            if st.dead or st.passed >= 150 then
                local ok = st.passed >= 150 or botDiffs[botI] == 'hard'
                if not ok then fails = fails + 1 end
                print(('%-7s %s  tuberías %d · velocidad %d → %d px/s · hueco %d · separación %d'):format(botDiffs[botI],
                    ok and 'OK   ' or 'FALLA', st.passed, st.baseSpeed, st.pipeSpeed, st.pipeGap, st.pipeSpacing))
                st = nil
                return
            end
        end
        return
    end
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
