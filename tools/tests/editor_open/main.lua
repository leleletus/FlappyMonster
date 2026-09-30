-- tools/tests/editor_open — el editor de niveles real con el diálogo "Abrir
-- nivel" (Ctrl+O): captura la lista arriba y tras bajar con las flechas
-- (<save>/editor_open_1.png, _2.png), cierra el diálogo y captura la capa
-- Mini bloques (tecla 7, _3.png); comprueba que no hay errores.
-- LINKS=1: abre links.json (un bloque ON/OFF conectado a una inundación),
-- elige Bloques → Conectar (K), hace clic en el bloque y captura el
-- inspector y la línea de la conexión (_links.png).
--
-- PLAY=assets/levels/x.json: abre ese nivel en el editor, pulsa F5 (probar, como
-- el usuario), mete al jugador en la zona de jefe y captura 1.5 s después de
-- empezar la pelea (_play.png): lo que se ve jugando desde el editor.
-- Si el nivel no tiene zona de jefe: captura el editor en la capa Decoración (_play_ed.png) y el juego
-- quieto a los 0.5 / 1.2 / 2.0 / 2.8 / 3.8 s (_play_1.._5.png), p. ej. el hielo
-- fino agrietándose bajo el jugador (tools/levelgen/arenas/hielo.json). AT=col,fila:
-- pone ahí al jugador (ver cualquier parte de un nivel).
--
--   tools/tests/run.sh editor_open
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
arg = arg or {}
arg[#arg + 1] = '--editor'
local LINKS = os.getenv('LINKS')
if LINKS then arg[#arg + 1] = 'links.json' end
local PLAY = os.getenv('PLAY')
if PLAY then arg[#arg + 1] = PLAY end
love.filesystem.load('game_main.lua')()
local frame, realDown = 0, love.keyboard.isDown
local function key(k, ctrl)
    if ctrl then love.keyboard.isDown = function(...) return true end end
    love.keypressed(k)
    love.keyboard.isDown = realDown
end
local function shot(n)
    love.graphics.captureScreenshot(function(img) img:encode('png', 'editor_open_' .. n .. '.png') end)
end
local gameUpdate = love.update
function love.update(dt)
    frame = frame + 1
    gameUpdate(dt)
    if PLAY then
        -- (WIN=1813x1014: tamaño de ventana, p. ej. el del usuario)
        if frame == 2 and os.getenv('WIN') == 'full' then
            love.window.setFullscreen(true, 'desktop')
            if love.resize then love.resize(love.graphics.getDimensions()) end
            print('ventana: ' .. table.concat({ love.graphics.getDimensions() }, 'x') .. ' dpi ' .. love.window.getDPIScale())
        elseif frame == 2 and os.getenv('WIN') then
            local w, h = os.getenv('WIN'):match('(%d+)x(%d+)')
            love.window.updateMode(tonumber(w), tonumber(h), { resizable = true })
            print('ventana: ' .. table.concat({ love.graphics.getDimensions() }, 'x'))
            if love.resize then love.resize(tonumber(w), tonumber(h)) end
        end
        if frame == 2 then key('5') end            -- (capa Decoración: la paleta sale en la captura)
        if frame == 4 then love.graphics.captureScreenshot(function(img) img:encode('png', 'editor_open_play_ed.png') end) end
        if frame == 6 then key('f5') end
        local st = gStateMachine and gStateMachine:_top()
        if frame > 8 and st and st.player and st.level then
            local z = (st.level.bossZones or {})[1]
            if z and not PLAY_placed then
                PLAY_placed = true
                st.player.x, st.player.y = z.x0 + 2 * TILE_PX, z.y1 - 2 * TILE_PX
            end
            if not z then
                if not PLAY_t0 and os.getenv('AT') then
                    -- AT=col,fila: pone al jugador ahí (capturas de cualquier parte del nivel)
                    local c, r = os.getenv('AT'):match('(%d+),(%d+)')
                    st.player.x, st.player.y = (tonumber(c) - 0.5) * TILE_PX, (tonumber(r) - 0.5) * TILE_PX
                    st.player.spawnX, st.player.spawnY = st.player.x, st.player.y
                end
                PLAY_t0 = PLAY_t0 or frame
                for i, sec in ipairs({ 0.5, 1.2, 2.0, 2.8, 3.8 }) do
                    if frame == PLAY_t0 + math.floor(sec * 60) then
                        love.graphics.captureScreenshot(function(img) img:encode('png', 'editor_open_play_' .. i .. '.png') end)
                    end
                end
                if frame == PLAY_t0 + 240 then
                    print('capturas en ' .. love.filesystem.getSaveDirectory() .. '/editor_open_play_*.png')
                    print('TODO OK'); love.event.quit(0)
                end
            end
            if z and z.state == 'fight' then
                PLAY_fight = PLAY_fight or frame
                if frame == PLAY_fight + 90 then
                    love.graphics.captureScreenshot(function(img) img:encode('png', 'editor_open_play.png') end)
                end
                if frame == PLAY_fight + 96 then
                    print('captura en ' .. love.filesystem.getSaveDirectory() .. '/editor_open_play.png')
                    print('TODO OK'); love.event.quit(0)
                end
            end
        end
        if frame > 3000 then print('FALLA: la pelea no empezó'); love.event.quit(1) end
        return
    end
    if LINKS then
        if frame == 5 then key('1') end
        if frame == 8 then key('k') end
        if frame == 12 then
            -- clic en la casilla (3,3): cámara inicial (-40,-40) al 75 %
            local mx, my = 292 + (2.5 * 64 + 40) * 0.75, 46 + (2.5 * 64 + 40) * 0.75
            local realPos = love.mouse.getPosition
            love.mouse.getPosition = function() return mx, my end
            love.mousepressed(mx, my, 1); love.mousereleased(mx, my, 1)
            love.mouse.getPosition = realPos
        end
        if frame == 20 then love.graphics.captureScreenshot(function(img) img:encode('png', 'editor_open_links.png') end) end
        if frame == 26 then
            print('captura en ' .. love.filesystem.getSaveDirectory() .. '/editor_open_links.png')
            print('TODO OK'); love.event.quit(0)
        end
        return
    end
    if frame == 5 then key('o', true) end
    if frame == 10 then shot(1) end
    if frame >= 12 and frame < 42 then key('down') end
    if frame == 50 then shot(2) end
    if frame == 55 then key('escape') end
    if frame == 60 then key('7') end                    -- capa Mini bloques
    if frame == 66 then shot(3) end
    if frame == 72 then
        print('capturas en ' .. love.filesystem.getSaveDirectory() .. '/editor_open_{1,2,3}.png')
        print('TODO OK'); love.event.quit(0)
    end
end
