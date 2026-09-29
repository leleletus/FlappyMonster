-- tools/tests/editor_open — el editor de niveles real con el diálogo "Abrir
-- nivel" (Ctrl+O): captura la lista arriba y tras bajar con las flechas
-- (<save>/editor_open_1.png, _2.png), cierra el diálogo y captura la capa
-- Mini bloques (tecla 7, _3.png); comprueba que no hay errores.
-- LINKS=1: abre links.json (un bloque ON/OFF conectado a una inundación),
-- elige Bloques → Conectar (K), hace clic en el bloque y captura el
-- inspector y la línea de la conexión (_links.png).
--
--   tools/tests/run.sh editor_open
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
arg = arg or {}
arg[#arg + 1] = '--editor'
local LINKS = os.getenv('LINKS')
if LINKS then arg[#arg + 1] = 'links.json' end
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
