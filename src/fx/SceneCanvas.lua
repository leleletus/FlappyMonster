-- src/fx/SceneCanvas.lua
-- El LIENZO DE LA ESCENA de los niveles (AdventureState, OnlineAdventureState, el fondo de los menús): UNO para todos.
-- Cada uno dibuja en él su escena y la pasa a la pantalla dentro de su propio render, así que pueden compartirlo
-- aunque haya dos a la vez (el fondo del menú y un nivel). Antes cada entrada en un nivel creaba uno nuevo (3,5 MB a
-- 1280x720) y el viejo seguía en la memoria de vídeo hasta que el recolector de Lua pasaba (lo mide la memoria de
-- Lua, no la de vídeo): con el menú cambiando de carrera y reintentos, se acumulaban.
--   SceneCanvas.get()   el lienzo del tamaño de pantalla actual (se rehace si cambia: girar el móvil; el viejo NO se
--                       libera a mano: algún estado puede tenerlo aún y dibujar con él antes de su update)
local SceneCanvas = {}

local canvas
function SceneCanvas.get()
    if not canvas or canvas:getWidth() ~= WINDOW_W or canvas:getHeight() ~= WINDOW_H then
        canvas = love.graphics.newCanvas(WINDOW_W, WINDOW_H)
    end
    return canvas
end

return SceneCanvas
