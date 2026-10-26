-- src/world/entities/base/BossWaves.lua
-- ONDAS POR EL SUELO de los jefes (lo común): un jefe cae de un salto y suelta ondas que corren por el suelo, una a
-- cada lado; se saltan. Se acaban al llegar al borde de la zona, contra una pared o un escalón, donde se acaba el
-- suelo o pasado su tiempo. Dan una vez a cada jugador (`hit`: el golpe de Boss.strike). La usan el Saltarín Gigante
-- (ondas de roca) y El Groove (ondas de arena); cada uno con su `cfg` y su dibujo:
--   cfg = { spd = px/s, life = s, w = ancho, h = alto (de la caja, desde el suelo), hit = { vida, vx, vy, s, s } }
-- Las ondas del jefe van en `boss.waves` ({ id, x, y, dir, t, hit = {} }) con un `id` estable (boss.nextId) para
-- interpolar en red: BossWaves.pack / BossWaves.unpack van dentro de su netPackExtra / netApplyExtra.
local Boss = require 'src/world/entities/base/Boss'

local BossWaves = {}
local STRIDE = 5

-- Dos ondas, una a cada lado, saliendo de los costados del jefe (`halfW`) en la altura de sus pies `y`
function BossWaves.spawn(boss, y, halfW)
    boss.waves, boss.nextId = boss.waves or {}, boss.nextId or 0
    for _, d in ipairs({ -1, 1 }) do
        boss.nextId = boss.nextId % 999 + 1
        boss.waves[#boss.waves + 1] = { id = boss.nextId, x = math.floor(boss.x + d * (halfW + 4)), y = math.floor(y),
                                        dir = d, t = 0, hit = {} }
    end
end

function BossWaves.box(w, cfg) return { x = w.x - cfg.w / 2, y = w.y - cfg.h, w = cfg.w, h = cfg.h } end

function BossWaves.update(boss, level, dt, cfg)
    local zx0, zx1 = boss:zoneBounds()
    local list = boss.waves or {}
    for i = #list, 1, -1 do
        local w = list[i]
        w.t = w.t + dt
        w.x = w.x + w.dir * cfg.spd * dt
        local ahead = w.x + w.dir * cfg.w / 2
        local gone = w.t >= cfg.life or ahead < zx0 or ahead > zx1
            or level:entitySolidAt(ahead, w.y - 12)                       -- (pared o escalón)
            or not level:collisionAt(w.x, w.y + 6, true)                  -- (se acaba el suelo)
        if gone then
            table.remove(list, i)
        else
            local box = BossWaves.box(w, cfg)
            for _, pa in ipairs(level.players or {}) do
                if not w.hit[pa] and Boss.overlap(pa:getOuterBounds(), box) and Boss.strike(pa, cfg.hit, w.dir) then
                    w.hit[pa] = true
                end
            end
        end
    end
end

-- Red: añade a `out` n, {id, x, y, dir, t·100}×n
function BossWaves.pack(list, out)
    out[#out + 1] = #(list or {})
    for _, w in ipairs(list or {}) do
        out[#out + 1] = w.id; out[#out + 1] = math.floor(w.x); out[#out + 1] = w.y
        out[#out + 1] = w.dir; out[#out + 1] = math.floor(w.t * 100)
    end
    return out
end

local function read(b, k)
    local n = type(b[k]) == 'number' and b[k] or 0
    local list = {}
    for i = 0, n - 1 do
        local e = {}
        for j = 1, STRIDE do e[j] = b[k + 1 + i * STRIDE + j - 1] end
        list[#list + 1] = e
    end
    return list, k + 1 + n * STRIDE
end

-- Red: las ondas desde el índice `k` de `b` (interpoladas con las de `a`, la instantánea anterior, por `f`);
-- devuelve la lista y el índice siguiente
function BossWaves.unpack(a, b, k, f)
    local prev = {}
    if type(a[k]) == 'number' then
        for _, e in ipairs((read(a, k))) do if e[1] then prev[e[1]] = e end end
    end
    local items, nxt = read(b, k)
    local out = {}
    for _, e in ipairs(items) do
        local x = e[2]
        local o = prev[e[1]]
        if o and type(o[2]) == 'number' and type(x) == 'number' then x = o[2] + (x - o[2]) * f end
        out[#out + 1] = { id = e[1], x = x, y = e[3], dir = e[4], t = (e[5] or 0) / 100, hit = {} }
    end
    return out, nxt
end

return BossWaves
