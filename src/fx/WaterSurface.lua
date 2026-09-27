-- src/fx/WaterSurface.lua
-- Superficie del agua con olas (pixel art, columnas de 4 px). Lo usan el agua
-- normal (Level:renderWaterEffect) y las inundaciones (world/Floods.lua).
--
-- El tinte de la franja de la superficie se dibuja por columnas cuya parte de
-- arriba SIGUE a la ola: así no queda ningún borde recto de agua "seca"
-- detrás de la ola (antes el tinte era un rectángulo plano y asomaba donde la
-- ola bajaba). La ola depende de la X del mundo: celdas vecinas empalman.

local WaterSurface = {}

WaterSurface.STEP   = 4        -- px por columna
WaterSurface.MARGIN = 4        -- px bajo la superficie sin distorsión (la ola la tapa)

-- Desplazamiento vertical de la ola en la X del mundo `wx`
function WaterSurface.offset(wx, t, amp)
    return math.floor(math.sin(wx * 0.045 + t * 2.2) * amp + math.sin(wx * 0.11 - t * 1.3))
end

-- Franja de superficie entre wx0 y wx1 (mundo): tinte desde la ola hasta
-- `bottomY` y, encima, la línea clara de la ola.
--   surfY, bottomY en px de mundo; tint = color del material
function WaterSurface.draw(wx0, wx1, surfY, bottomY, camX, camY, tint, amp, t)
    local S = WaterSurface.STEP
    local sy = math.floor(surfY - camY)
    local by = math.floor(bottomY - camY)
    for wx = wx0, wx1 - S, S do
        local o = WaterSurface.offset(wx, t, amp)
        local px = math.floor(wx - camX)
        local top = sy + o
        if by > top then
            love.graphics.setColor(tint)
            love.graphics.rectangle('fill', px, top, S, by - top)
        end
        love.graphics.setColor(0.55, 0.8, 1, 0.55)
        love.graphics.rectangle('fill', px, top, S, 4)
        love.graphics.setColor(0.85, 0.95, 1, 0.7)
        love.graphics.rectangle('fill', px, top, S, 2)
    end
end

return WaterSurface
