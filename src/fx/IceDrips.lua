-- src/fx/IceDrips.lua
-- Gotas que caen del hielo (tiles con `iceDrip`: hielo y hielo fino) cuando
-- debajo no hay nada. Solo dibujo (cada cliente las suyas; no afectan al
-- juego), y solo de las celdas que se ven. La gota se forma colgando bajo el
-- bloque, cae, y al tocar algo salpica.
-- Sprite: assets/images/fx/ice_drop.png (2 cuadros de 3x5: gota, salpicadura),
-- generado por tools/ui/make_snow_sprites.py.
--   IceDrips.render(level, camX, camY)   (Level:render lo llama)

local SpriteStrip = require 'src/fx/SpriteStrip'
local TileTypes   = require 'src/world/tiles/TileTypes'
local TileCodec   = require 'src/world/tiles/TileCodec'

local IceDrips = {}
local sheet
local SCALE     = 3
local RATE      = 0.22      -- gotas por segundo y celda que gotea
local FORM_T    = 0.45      -- s colgando antes de caer
local SPLASH_T  = 0.16
local MAX_DROPS = 70

local function drips(level, c, r)
    local d = TileTypes.get(TileCodec.id(level:getRaw(c, r)))
    if not d.iceDrip then return false end
    local below = level:getDefAt((c - 0.5) * TILE_PX, r * TILE_PX + 4)
    return below.collision == 'none' and not (below.mat and below.mat.liquid)
end

function IceDrips.render(level, camX, camY)
    sheet = sheet or SpriteStrip.load('assets/images/fx/ice_drop.png', 3)
    local dt = math.min(0.05, love.timer.getDelta())
    local T = TILE_PX
    local list = level._iceDrops or {}
    level._iceDrops = list
    -- Nuevas gotas en las celdas visibles que gotean
    if #list < MAX_DROPS then
        local c0, c1 = math.max(1, math.floor(camX / T) + 1), math.min(level.tileW, math.floor((camX + WINDOW_W) / T) + 1)
        local r0, r1 = math.max(1, math.floor(camY / T) + 1), math.min(level.tileH, math.floor((camY + WINDOW_H) / T) + 1)
        for r = r0, r1 do
            for c = c0, c1 do
                if math.random() < RATE * dt and drips(level, c, r) then
                    local d = TileTypes.get(TileCodec.id(level:getRaw(c, r)))
                    local hb = d.hitbox
                    local bottom = (r - 1) * T + (hb and (hb.y + hb.h) or 1) * T
                    list[#list + 1] = { x = (c - 1) * T + 8 + math.random() * (T - 16), y = bottom, vy = 0, t = 0,
                                        phase = 'form' }
                end
            end
        end
    end
    -- Avanzar y dibujar
    for i = #list, 1, -1 do
        local d = list[i]
        d.t = d.t + dt
        if d.phase == 'form' then
            if d.t >= FORM_T then
                d.phase, d.t = 'fall', 0
                if Sound.playAt then Sound.playAt('dripFall', d.x, d.y, 0.9 + math.random() * 0.4, 0.7) end
            end
        elseif d.phase == 'fall' then
            local y0 = d.y
            d.vy = math.min(d.vy + 1200 * dt, 900)
            d.y = d.y + d.vy * dt
            local hit, top = level:landingCross(d.x, y0 + 6, d.y + 6)
            if hit then
                d.y, d.phase, d.t = top - 2, 'splash', 0
                if Sound.playAt then Sound.playAt('dripSplash', d.x, d.y, 0.9 + math.random() * 0.4, 0.7) end
            elseif level:liquidAt(d.x, d.y) or d.y > level.heightPx then table.remove(list, i); d = nil end
        elseif d.t >= SPLASH_T then
            table.remove(list, i); d = nil
        end
        if d then
            local sx, sy = math.floor(d.x - camX), math.floor(d.y - camY)
            love.graphics.setColor(1, 1, 1, 0.9)
            if d.phase == 'splash' then
                sheet:draw(2, sx, sy - 2 * SCALE, 0, SCALE, SCALE)
            else
                -- (colgando: crece desde el borde de abajo del bloque)
                local k = (d.phase == 'form') and math.min(1, d.t / FORM_T) or 1
                sheet:draw(1, sx, sy + 2.5 * SCALE * k, 0, SCALE, SCALE * k)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return IceDrips
