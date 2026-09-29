-- tools/tests/editor_open — el editor de niveles real con el diálogo "Abrir
-- nivel" (Ctrl+O): captura la lista arriba y tras bajar con las flechas
-- (<save>/editor_open_1.png, _2.png), cierra el diálogo y captura la capa
-- Mini bloques (tecla 7, _3.png); comprueba que no hay errores.
--
--   tools/tests/run.sh editor_open
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
arg = arg or {}
arg[#arg + 1] = '--editor'
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
