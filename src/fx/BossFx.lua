-- src/fx/BossFx.lua
-- Efectos de dibujo que COMPARTEN los jefes (sprites en assets/images/bosses/common/): antes cada
-- jefe cargaba los de otro y repetía el código.
--   BossFx.stars(cx, cy, rx, ry, scale[, alpha])   estrellitas de ATURDIDO girando (= "ahora es vulnerable")
--   BossFx.anger(holder, on, x, y[, opts])         símbolos de ENFADO que saltan alrededor de (x, y): vena,
--                                                  vapor, garabato. `holder` guarda los que hay (el jefe);
--                                                  `on` = si salen nuevos. opts: r (radio), kinds, scale
--   BossFx.target(frame, x, y, sx, sy)             la DIANA de "voy a caer aquí" (2 cuadros 16x4)
-- Solo dibujo (cada cliente a su aire): nada de esto es simulación.
local SpriteStrip = require 'src/fx/SpriteStrip'

local BossFx = {}
local D = 'assets/images/bosses/common/'
local starsS, targetS, anger

local function load()
    if starsS then return end
    starsS  = SpriteStrip.load(D .. 'stars-Sheet.png', 5)
    targetS = SpriteStrip.load(D .. 'target-Sheet.png', 16)
    anger = { vein = SpriteStrip.load(D .. 'anger_vein.png', 11),
              steam = SpriteStrip.load(D .. 'anger_steam.png', 9),
              scribble = SpriteStrip.load(D .. 'anger_scribble.png', 9) }
end

function BossFx.stars(cx, cy, rx, ry, scale, alpha)
    load()
    local now = love.timer.getTime()
    love.graphics.setColor(1, 1, 1, alpha or 1)
    for i = 0, 2 do
        local a = now * 5 + i * (math.pi * 2 / 3)
        starsS:draw((math.floor(now * 8) + i) % 2 + 1, math.floor(cx + math.cos(a) * rx), math.floor(cy + math.sin(a) * ry),
                    0, scale, scale, 2.5, 2.5)
    end
end

function BossFx.target(frame, x, y, sx, sy)
    load()
    targetS:draw(frame, x, y, 0, sx, sy)
end

local KINDS = { 'vein', 'vein', 'steam', 'scribble', 'vein', 'steam' }
local LIFE = { vein = 0.8, steam = 0.6, scribble = 0.7 }
function BossFx.anger(holder, on, x, y, opts)
    load()
    opts = opts or {}
    local now = love.timer.getTime()
    local list = holder._anger or {}
    holder._anger = list
    if on and now >= (holder._angerNext or 0) and #list < 3 then
        holder._angerNext = now + 0.3 + math.random() * 0.55
        holder._angerSide = -(holder._angerSide or 1)       -- (a un lado y a otro, nunca dos seguidos en el mismo)
        local a = holder._angerSide * (0.35 + math.random() * 0.8)
        local r = (opts.r or 90) * (0.85 + math.random() * 0.3)
        local kinds = opts.kinds or KINDS
        list[#list + 1] = { kind = kinds[math.random(#kinds)], born = now, ox = math.sin(a) * r, oy = -math.cos(a) * r * 0.5 }
    end
    local S = opts.scale or 3
    for i = #list, 1, -1 do
        local q = list[i]
        local age, life = now - q.born, LIFE[q.kind]
        if age >= life then
            table.remove(list, i)
        else
            local px, py = x + q.ox, y + q.oy
            local k, frame = S, 1
            local alpha = math.min(1, (life - age) / 0.15)
            if q.kind == 'vein' then
                k = S * ((age < 0.1) and (0.5 + age / 0.1 * 0.75) or 1)          -- aparece de golpe y late
                frame = (math.floor(age * 7) % 2 == 0) and 1 or 2
            elseif q.kind == 'steam' then
                frame = math.min(3, math.floor(age / life * 3) + 1)
                py, px = py - age * 60, px + math.sin(age * 12) * 3
            else
                frame = math.floor(age * 12) % 2 + 1
                px = px + math.floor(math.sin(age * 40) * 2)
            end
            k = math.floor(k + 0.5)
            px, py = math.floor(px + 0.5), math.floor(py + 0.5)
            love.graphics.setColor(0, 0, 0, 0.5 * alpha)
            anger[q.kind]:draw(frame, px + 3, py + 3, 0, k, k)
            love.graphics.setColor(1, 1, 1, alpha)
            anger[q.kind]:draw(frame, px, py, 0, k, k)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return BossFx
