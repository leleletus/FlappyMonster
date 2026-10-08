-- src/fx/BossFx.lua
-- Efectos de dibujo que COMPARTEN los jefes (sprites en assets/images/bosses/common/): antes cada
-- jefe cargaba los de otro y repetía el código.
--   BossFx.stars(cx, cy, rx, ry, scale[, alpha])   estrellitas de ATURDIDO girando (= "ahora es vulnerable")
--   BossFx.anger(holder, on, x, y[, opts])         símbolos de ENFADO que saltan alrededor de (x, y): vena,
--                                                  vapor, garabato. `holder` guarda los que hay (el jefe);
--                                                  `on` = si salen nuevos. opts: r (radio), kinds, scale
--   BossFx.target(t, x, y, sx, sy)    (t = reloj: parpadea a su ritmo)             la DIANA de "voy a caer aquí" (2 cuadros 16x4)
-- Solo dibujo (cada cliente a su aire): nada de esto es simulación.
local Anim = require 'src/fx/Anim'

local BossFx = {}
-- Animaciones compartidas de los jefes (assets/anim/bosses/common.json), por nombre: `stars`, `target` y las marcas
-- de enfado `anger_vein` (late), `anger_steam` (una pasada en lo que dura) y `anger_scribble`.
local function clip(name) return Anim.clip('bosses/common', name) end
local function load() end
-- La marca de enfado `kind` y el paso que le toca a los `age` s de salir (de `life` que dura)
function BossFx.angerClip(kind) return clip('anger_' .. kind) end
function BossFx.angerStep(kind, age, life)
    local c = clip('anger_' .. kind)
    if kind == 'steam' then return c:atProgress(age / life) end        -- (el vapor: una pasada en su vida)
    return c:at(age)
end

function BossFx.stars(cx, cy, rx, ry, scale, alpha)
    load()
    local now = love.timer.getTime()
    love.graphics.setColor(1, 1, 1, alpha or 1)
    for i = 0, 2 do
        local a = now * 5 + i * (math.pi * 2 / 3)
        clip('stars'):play(now + i / 8, math.floor(cx + math.cos(a) * rx), math.floor(cy + math.sin(a) * ry), 0, scale, scale)
    end
end

function BossFx.target(t, x, y, sx, sy)
    clip('target'):play(t, x, y, 0, sx, sy)
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
            local k, frame = S, BossFx.angerStep(q.kind, age, life)
            local alpha = math.min(1, (life - age) / 0.15)
            if q.kind == 'vein' then
                k = S * ((age < 0.1) and (0.5 + age / 0.1 * 0.75) or 1)          -- aparece de golpe y late
            elseif q.kind == 'steam' then
                py, px = py - age * 60, px + math.sin(age * 12) * 3
            else
                px = px + math.floor(math.sin(age * 40) * 2)
            end
            k = math.floor(k + 0.5)
            px, py = math.floor(px + 0.5), math.floor(py + 0.5)
            love.graphics.setColor(0, 0, 0, 0.5 * alpha)
            BossFx.angerClip(q.kind):draw(frame, px + 3, py + 3, 0, k, k)
            love.graphics.setColor(1, 1, 1, alpha)
            BossFx.angerClip(q.kind):draw(frame, px, py, 0, k, k)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return BossFx
