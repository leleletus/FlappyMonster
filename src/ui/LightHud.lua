-- src/ui/LightHud.lua
-- Linterna en el HUD (niveles a oscuras): icono (encendida / apagada / agotada) + batería en
-- 8 segmentos. assets/images/ui/flashlight-Sheet.png (3 cuadros 12x8, tools/ui/make_gloomy_sprites.py)
local SpriteStrip = require 'src/fx/SpriteStrip'

local LightHud = {}
local icon
local SEG, SCALE = 8, 4

function LightHud.draw(pa, x, y)
    icon = icon or SpriteStrip.load('assets/images/ui/flashlight-Sheet.png', 12)
    local bat, cd = pa.lightBat or 1, pa.lightCd or 0
    local fr = (cd > 0) and 3 or (pa.lightOn and 1 or 2)
    local blink = cd > 0 and math.floor(love.timer.getTime() * 6) % 2 == 0
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.draw(icon.image, icon.quads[fr], x + 3, y + 3, 0, SCALE, SCALE)
    love.graphics.setColor(1, 1, 1, blink and 0.5 or 1)
    love.graphics.draw(icon.image, icon.quads[fr], x, y, 0, SCALE, SCALE)
    local bx, by = x + 12 * SCALE + 10, y + 4
    local on = math.ceil(bat * SEG - 0.001)
    for i = 1, SEG do
        local sx = bx + (i - 1) * 16
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.rectangle('fill', sx + 3, by + 3, 12, 24)
        if cd > 0 then love.graphics.setColor(0.45, 0.2, 0.18, 1)
        elseif i <= on then
            if bat < 0.3 then love.graphics.setColor(0.95, 0.38, 0.24, 1) else love.graphics.setColor(1, 0.89, 0.48, 1) end
        else love.graphics.setColor(0.24, 0.25, 0.32, 1) end
        love.graphics.rectangle('fill', sx, by, 12, 24)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return LightHud
