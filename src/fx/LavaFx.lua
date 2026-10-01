-- src/fx/LavaFx.lua
-- Burbujas y salpicaduras de la lava (tile 'danger' = Lava) con la superficie al
-- aire. SOLO dibujo (cada cliente las suyas; no afectan al juego) y solo en las
-- casillas que se ven: una burbuja crece, revienta y suelta unas gotitas que
-- saltan y vuelven a caer en la lava; encima de la superficie, un brillo suave.
-- Sprites: assets/images/fx/lava_fx.png (4 cuadros de 5x5: burbuja, burbuja
-- grande, estallido, gota), de tools/ui/make_world_art.py.
--   LavaFx.render(level, camX, camY)   (justo después de dibujar el nivel)
local SpriteStrip = require 'src/fx/SpriteStrip'

local LavaFx = {}
local sheet, glow
local RATE     = 0.35      -- burbujas por segundo y casilla de superficie
local MAX      = 60
local SCALE    = 3
local GROW_T   = 0.5

local function isLava(def) return def and (def.lava or def.mimics == 'danger') end

local function surface(level, c, r)
    if not isLava(level:getDef(c, r)) then return false end
    local up = level:getDef(c, r - 1)
    return not isLava(up) and up.collision ~= 'solid'
end

function LavaFx.render(level, camX, camY)
    sheet = sheet or SpriteStrip.load('assets/images/fx/lava_fx.png', 5)
    if glow == nil then
        local ok, s = pcall(SpriteStrip.load, 'assets/images/decorations/fx/glow.png', 32)
        glow = ok and s or false
    end
    local dt = math.min(0.05, love.timer.getDelta())
    local T = TILE_PX
    local list = level._lavaFx or {}
    level._lavaFx = list
    local c0, c1 = math.max(1, math.floor(camX / T) + 1), math.min(level.tileW, math.floor((camX + WINDOW_W) / T) + 1)
    local r0, r1 = math.max(1, math.floor(camY / T) + 1), math.min(level.tileH, math.floor((camY + WINDOW_H) / T) + 1)
    local now = love.timer.getTime()
    local mode, am = love.graphics.getBlendMode()
    for r = r0, r1 do
        for c = c0, c1 do
            if surface(level, c, r) then
                -- Brillo sobre la superficie (aditivo, respira despacio)
                if glow then
                    love.graphics.setBlendMode('add')
                    love.graphics.setColor(1, 0.45, 0.12, 0.13 + 0.04 * math.sin(now * 2 + c * 1.7))
                    glow:draw(1, math.floor((c - 0.5) * T - camX), math.floor((r - 1) * T - camY + 6), 0, 3, 1.6)
                    love.graphics.setBlendMode(mode, am)
                end
                if #list < MAX and math.random() < RATE * dt then
                    list[#list + 1] = { kind = 'bubble', x = (c - 1) * T + 8 + math.random() * (T - 16),
                                        y = (r - 1) * T + 8, t = 0, big = math.random() < 0.4 }
                end
            end
        end
    end
    for i = #list, 1, -1 do
        local p = list[i]
        p.t = p.t + dt
        local frame, alive = 1, true
        if p.kind == 'bubble' then
            if p.t < GROW_T then
                frame = p.big and 2 or 1
            elseif p.t < GROW_T + 0.1 then
                frame = 3
                if not p.popped then
                    p.popped = true
                    for _ = 1, p.big and 4 or 2 do
                        list[#list + 1] = { kind = 'drop', x = p.x, y = p.y - 4, y0 = p.y, t = 0,
                                            vx = (math.random() - 0.5) * 140, vy = -200 - math.random() * 140 }
                    end
                end
            else
                alive = false
            end
        else
            p.vy = p.vy + 900 * dt
            p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
            frame = 4
            if p.vy > 0 and p.y > p.y0 then alive = false end           -- (vuelve a la lava)
        end
        if not alive then
            table.remove(list, i)
        else
            love.graphics.setColor(1, 1, 1, 1)
            sheet:draw(frame, math.floor(p.x - camX), math.floor(p.y - camY), 0, SCALE)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return LavaFx
