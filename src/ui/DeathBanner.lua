-- src/ui/DeathBanner.lua
-- La línea de la CAUSA DE MUERTE al reaparecer (0.5.200; src/player/DeathCause.lua): una calavera y el porqué, arriba en
-- el centro, 1,5 s, sin parar el juego.
--   DeathBanner.draw(cause, t)   t = segundos desde que reapareció
local L = require 'src/core/Lang'
local PixelIcons = require 'src/ui/PixelIcons'
local DB = {}
DB.SHOW = 1.8

function DB.text(cause)
    if not cause then return nil end
    if cause.kind == 'enemy' then
        return cause.name and L('death.enemy', { name = cause.name }) or L('death.enemy_any')
    end
    return L('death.' .. cause.kind)
end

function DB.draw(cause, t)
    if not cause or not t or t > DB.SHOW then return end
    local a = math.min(1, t / 0.15, (DB.SHOW - t) / 0.4)
    local text = DB.text(cause)
    love.graphics.setFont(FONT_MED)
    local px = 4
    local iw = 9 * px
    local w = iw + 14 + FONT_MED:getWidth(text) + 40
    local h = 52
    -- (a la IZQUIERDA, bajo todo lo de arriba — puntos, barras de los jefes y de vida —: el usuario, 0.5.204: pegado a
    --  los puntos estorbaba; src/ui/HudRects.lua)
    local HudRects = require 'src/ui/HudRects'
    local x, y = 20, HudRects.below()
    HudRects.add('death', x, y, w, h)
    require('src/ui/menu/MenuButton').panel(x, y, w, h, 0.9 * a)
    PixelIcons.draw('skull', x + 20, y + math.floor((h - iw) / 2), px, a)
    love.graphics.setColor(1, 0.86, 0.8, a)
    love.graphics.print(text, x + 20 + iw + 14, y + math.floor((h - FONT_MED:getHeight()) / 2) + 2)
    love.graphics.setColor(1, 1, 1, 1)
end

return DB
