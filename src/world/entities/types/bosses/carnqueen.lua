-- Jefa secreta REINA CARNÍVORA (types/bosses/carnqueen.lua): la Planta carnívora de la jungla, tumbada y enorme (diseño A
-- «Cepo Real», sin cara: el usuario, 2026-11-01; docs/bosses/carnqueen.md). Enraizada en el centro de la sala del templo.
--   · LAS LANZAS (el usuario las llama así; en el código, `mouths`) brotan del suelo, las paredes y el techo a unas casillas de ti,
--     nunca debajo ni amontonadas: el agujero se abre (aviso), asoman, te apuntan y se lanzan rectas como una lanza. Al contacto
--     te TRAGAN al instante: machacar botones para salir (PlayerGulp). Si fallan, ya no: algunas se quedan cerradas e inofensivas un rato.
--     Si estás arriba o hay enredaderas, salen muchas más, del techo y las paredes.
--   · ELLA MISMA COME (el usuario): si te quedas muy cerca abre las hojas (aviso) y se cierra; pillado, a machacar como siempre.
--   · LAS ENREDADERAS (el usuario): aviso largo y se llena el piso de enredaderas con espinas: hay que subir a las plataformas.
--     Ella salta a la plataforma que tenga encima para salvarse; sus plantas del suelo mueren.
--   · ESCUPE SEMILLAS en arco que brotan en plantas carnívoras normales (súbditas de reserva): más cuanta menos vida le queda
--     y cuanto más alta la dificultad (SEEDS, PLANTS, DIFF_*).
--   · AL MORDER se dibuja como la planta chiquita (el usuario): se encoge, se estira hacia ti, se inclina y rebota (pose).
--   · LA VENTANA: una bomba LANZADA que cae en ella: se cierra, se la traga ('bomb'), le explota dentro y queda ATURDIDA ('stun'),
--     con la flor abierta y en alto: pisotón 1 / ground pound 2 EN LA FLOR, un solo golpe por noqueo (Boss.damage).
--   · Su cuerpo se atraviesa y no hace daño, como el del Escorpión: lo que importa son sus bocas.
-- Las bocas son un tallo de discos animado al momento (base/SegmentChain: solo dibujo); lo que atrapa sale del estado de cada
-- boca (netPackExtra): online se ve y se decide igual.

local Entity = require 'src/world/entities/base/Entity'
local Boss   = require 'src/world/entities/base/Boss'
local BossFx = require 'src/fx/BossFx'
local Chain  = require 'src/world/entities/base/SegmentChain'
local Anim   = require 'src/fx/Anim'

local Q = Entity.extend(Boss, {
    ATTACKS  = { spit_wind = true, spit = true, bite_wind = true, chomp_snap = true, hold = true, vine_wind = true, vines = true },
    OPENINGS = { stun = true },
    debugColor = { 0.3, 0.8, 0.4 },
    hitbox = { outerW = 0.8, outerH = 0.4, innerW = 0.7, innerH = 0.34 },
})
Q.hurtSound   = 'megaHurt'
Q.introLength = 3.0
Q.wantsLevel  = true
Q.animId      = 'bosses/carnqueen'

local T  = TILE_PX
local MS = 5
local FW, FH = 56, 38
local SINK = 1                                  -- px de arte bajo el suelo
-- Dónde cae en la hoja (px de arte, frente a los pies del centro: la fila 37 es el suelo)
local FLOWER_BUD, FLOWER_OPEN = -22, -26        -- alto del centro de la flor
local BOMB_Y    = -60                           -- px: donde se queda la bomba tragada
local FLOWER_R  = 42                            -- px: el radio de la flor (lo que se pisa)
local EAT_W, EAT_H = 120, 130                   -- px: medio ancho y alto de lo que se traga

-- Ritmo por fase (1, 2, 3)
local MOUTHS   = { 2, 3, 4 }                    -- Lanzas a la vez
local BURST    = { 1, 2, 3 }                    -- cuántas pueden brotar de golpe
local MOUTH_CD = { 2.4, 1.9, 1.5 }              -- s entre una tanda y la siguiente
local UP_MOUTHS = { 3, 4, 5 }                   -- ...si estás arriba o hay enredaderas (el usuario: más; con 6-8, demasiadas)
local UP_CD     = { 1.1, 0.9, 0.75 }
local WARN_T   = { 0.7, 0.6, 0.5 }              -- s con el agujero abriéndose
local OUT_T    = 0.2                            -- s asomando
local SEEK_T   = { 0.8, 0.68, 0.56 }            -- s de amago: te apunta, se encoge y tiembla antes de lanzarse
local SEEK_LOCK = 0.24                          -- s antes de lanzarse en que deja de apuntar: lo que hay para esquivarla
local LUNGE_V  = { 1300, 1500, 1700 }           -- px/s: se lanza como una lanza
local OVERSHOOT = 1.5 * T                       -- se pasa de donde estabas
local BACK_T   = 0.3
local SHUT_T   = 0.3                            -- s cerrada tras fallar, antes de volver
local CAMP     = 0.4                            -- cuántas se quedan campeando
local CAMP_T   = { 2.5, 4 }                     -- s quieta y cerrada: ya falló, no te mira ni te come (el usuario)
local TURN_V   = { 3.0, 3.5, 4.0 }              -- rad/s que gira al apuntar (el usuario: suave)
local PEEK     = 1.3 * T                        -- lo que asoma antes de lanzarse
local RECOIL   = 0.55                           -- cuánto se encoge en el amago
local CAUGHT_PAUSE = 1.5                        -- s sin sacar más tras soltarte
local LONG     = 10 * T                         -- lo más largo de un tallo
local SITE_MIN, SITE_NEAR, SITE_FAR = 2.4 * T, 5.5 * T, 9.5 * T   -- a qué distancia de ti puede brotar
local UNDER    = 2.2 * T                        -- en el suelo: tan lejos en horizontal (el usuario: nunca debajo)
local ON_HOLE  = 1.5 * T                        -- si al abrirse te has puesto encima, se cierra sin salir
local SPACING  = 2.5 * T                        -- entre una y otra (el usuario: no varias en un solo lugar)
local HIGH     = 1.5 * T                        -- sobre el suelo: "estás arriba"
-- Ella misma come (si estás encima)
local CHOMP_R, CHOMP_H = 2.3 * T, 2.2 * T       -- px: te tiene a tiro
local CHOMP_WIND = { 0.16, 0.13, 0.1 }          -- (el usuario: mucho más rápida que la pequeña, que avisa 0,3 s)
local CHOMP_BOX = 2.6 * T
local CHOMP_CD  = 1.2
local CHOMP_EXTRA = 0.3                         -- s cerrada si falla
local CHOMP_SNAP = 0.08                         -- s cerrándose: lo que dura el mordisco
-- Squash & stretch del mordisco (lo mismo que la planta chiquita: Plant:pose), a su tamaño
local STRETCH_MIN, STRETCH_MAX = 0.2, 0.45      -- estirón (fracción de su alto)
local LEAN_MAX  = 110                           -- px que se inclina la punta hacia ti
local RECOIL_T  = 0.7                           -- s del rebote
-- Las enredaderas del piso
local VINE_CD   = { 13, 11, 9 }
local VINE_WARN = { 1.6, 1.4, 1.2 }             -- s asomando, sin hacer daño: para subir
local VINE_T    = { 3.2, 3.8, 4.4 }
local VINE_BACK = 0.5
local VINE_H    = 42                            -- px de alto: lo que pincha
local HIT_VINE  = { 1, 240, -760, 0.2, 0 }      -- (te lanza hacia arriba: hacia las plataformas)
local HEAD_BOX = 34
local HOP_DELAY, HOP_T, HOP_ARC = 0.2, 0.6, 70  -- el salto a su plataforma
local SPIT_CD  = { 7.5, 6, 5 }
local SPIT_WIND, SPIT_T = 0.5, 0.35
local SEED_G, SEED_FLY, SPROUT_T = 1500, 1.0, 0.7
local PLANTS   = { 2, 3, 4 }                    -- plantas de semilla a la vez, por fase (cuanta menos vida, más)...
local SEEDS    = { 1, 2, 3 }                    -- ...y semillas de cada vez
local DIFF_PLANTS = { easy = -1, normal = 0, hard = 1, extreme = 1, xtra = 2 }     -- ...y según la dificultad
local DIFF_CD  = { easy = 1.25, normal = 1, hard = 0.9, extreme = 0.8, xtra = 0.7 }
local PLANT_POOL = 6                            -- (lo más que puede llegar a pedir: 4 + 2)
local BLAST_T, RECOVER_T = 0.35, 0.7
local STUN_T   = { easy = 6, normal = 5, hard = 4.2, extreme = 3.8, xtra = 3.5 }
-- Muerte
local OUT_D, FLEE_T = 2.0, 1.6
local DEATH = { dying_out = true, dying_flee = true }

local function rand(a, b) return a + math.random() * (b - a) end
function Q.sizePx() return FW * MS, FH * MS end
function Q:feetY() return self.y + self.outerH / 2 end
function Q:ph() return self.phase or 1 end
function Q:bossPhase() return self:ph() end
function Q:angryPhase() return self:ph() == 3 end
function Q:podCenter() return self.x, self:feetY() + BOMB_Y end
function Q:flowerPos()
    local a = (self.state == 'stun') and FLOWER_OPEN or FLOWER_BUD
    return self.x, self:feetY() + a * MS
end

function Q:initBoss()
    self.y = self.row * T - self.outerH / 2
    self.vx, self.vy, self.onGround = 0, 0, true
    self.phase = 1
    self.mouths, self.seeds, self.nextId = {}, {}, 0
    self.mouthT, self.spitT, self.chompCd, self.vineT = 1.5, SPIT_CD[1], 0, VINE_CD[1]
    self.vx0, self.vx1, self.vy0 = 0, 0, 0
    self.groundY = self.row * T
    self.aimT, self.aimN = 0, 0
    self.hopT = nil
    self.summonKey = 'cq' .. self.col .. ',' .. self.row
end

function Q:onFightStart(n) self:enter('fight') end
function Q:rollStart(r) self.mouthT, self.spitT, self.vineT = r(0.8, 2.2), r(3, SPIT_CD[1]), r(6, VINE_CD[1]) end

function Q:isActive() return Boss.isActive(self) and not DEATH[self.state] end
function Q:isDying() return DEATH[self.state] == true or Boss.isDying(self) end
function Q:isVulnerable() return self:isActive() and self.state == 'stun' end
function Q:releasesZone() return self.state == 'dying_flee' or self.state == 'dead' end
function Q:isSolidBody() return false end
function Q:isObstacle() return false end
function Q:canBeKnocked() return false end
function Q:physicsFixed() return true end

-- ── La flor es lo único que se pisa (pura: el cliente predice igual) ─────────
function Q:interact(pa)
    if not self:isVulnerable() or (self.ghost and self.inv > 0) then return nil end
    if pa.vy <= 0 and pa.gpPhase ~= 'fall' then return nil end
    local fx, fy = self:flowerPos()
    local ob = pa:getOuterBounds()
    local foot = ob.y + ob.h
    if ob.x > fx + FLOWER_R or ob.x + ob.w < fx - FLOWER_R or foot < fy - FLOWER_R - 6 or foot > fy + FLOWER_R then return nil end
    local bvy = -math.abs(ADV_JUMP_VEL) * self.BOUNCE
    if self.inv > 0 then return 'bounce', bvy, (pa.x >= self.x) and 1 or -1 end
    return (pa.gpPhase == 'fall') and 'pound' or 'stomp', bvy, self.props.points or 0
end

-- ── Las bocas ─────────────────────────────────────────────────────────────────
local function ext(m)
    if m.state == 'warn' then return 0 end
    if m.state == 'out' then return math.min(1, m.t / m.outT) end
    if m.state == 'back' then return math.max(0, 1 - m.t / BACK_T) end
    return 1
end
Q.mouthExt = ext
function Q.headPos(m)
    local e = ext(m)
    return m.bx + (m.tx - m.bx) * e, m.by + (m.ty - m.by) * e
end

function Q:nid() self.nextId = self.nextId % 999 + 1; return self.nextId end

function Q:floorBelow(level, x, y)
    local _, _, _, zy1 = self:zoneBounds()
    for yy = y, zy1 + 4 * T, 8 do
        if level:collisionAt(x, yy, true) then return math.floor(yy / T) * T end
    end
    return self:feetY()
end

-- Apunta: la cabeza asoma hacia el jugador
local function aim(m, pa, pull, maxTurn)
    local dx, dy = pa.x - m.bx, pa.y - m.by
    if dx * dx + dy * dy < 1 then return end
    local want = math.atan2(dy, dx)
    if maxTurn then                                  -- (gira poco a poco; sin maxTurn, de golpe: aún no se ve)
        local cur = math.atan2(m.ay, m.ax)
        local da = (want - cur + math.pi) % (2 * math.pi) - math.pi
        want = cur + math.max(-maxTurn, math.min(maxTurn, da))
    end
    m.ax, m.ay = math.cos(want), math.sin(want)
    local len = PEEK * (1 - RECOIL * (pull or 0))
    m.tx, m.ty = m.bx + m.ax * len, m.by + m.ay * len
end

-- Dónde brotar: al azar en una superficie a su alcance; ni debajo, ni junto a otra, ni donde vas a estar. nil = ninguna vale
function Q:pickSite(level, pa, up)
    local zx0, zx1, zy0 = self:zoneBounds()
    local floor = self.groundY
    local px, py = pa.x, pa.y
    local qx = px + (pa.vx or 0) * WARN_T[self:ph()]
    local function far(x, y, cx)
        local dx, dy = x - cx, y - py
        return dx * dx + dy * dy >= SITE_MIN * SITE_MIN
    end
    for _, maxD in ipairs({ SITE_NEAR, SITE_FAR }) do
        for _ = 1, 28 do
            local kind = math.random(up and 2 or 1, 4)
            local x, y, nx, ny
            local side = (math.random() < 0.5) and -1 or 1
            if kind == 1 then x, y, nx, ny = px + side * rand(UNDER, SITE_NEAR), floor, 0, -1
            elseif kind == 2 then x, y, nx, ny = px + side * rand(0.5 * T, 5 * T), zy0, 0, 1
            elseif kind == 3 then x, y, nx, ny = zx0, rand(zy0 + T, floor - 2 * T), 1, 0
            else x, y, nx, ny = zx1, rand(zy0 + T, floor - 2 * T), -1, 0 end
            local dx, dy = x - px, y - py
            local ok = dx * dx + dy * dy <= maxD * maxD and far(x, y, px) and far(x, y, qx)
            if kind <= 2 then ok = ok and x >= zx0 + T and x <= zx1 - T end
            if kind == 1 then ok = ok and math.abs(x - px) >= UNDER and math.abs(x - qx) >= UNDER end
            if kind == 1 and ok then ok = level:collisionAt(x, y + 4, true) ~= nil end
            if kind == 2 and ok then ok = level:collisionAt(x, y - 4, true) ~= nil end
            for _, o in ipairs(self.mouths) do
                local ax, ay = o.bx - x, o.by - y
                if ax * ax + ay * ay < SPACING * SPACING then ok = false end
            end
            if ok then return x, y, nx, ny end
        end
    end
end

-- Una Lanza nueva cerca del jugador
function Q:spawnMouth(level, pa, up)
    local x, y, nx, ny = self:pickSite(level, pa, up)
    if not x then return end
    local ph = self:ph()
    local m = { id = self:nid(), state = 'warn', alive = true, t = 0, bx = math.floor(x), by = math.floor(y), nx = nx, ny = ny,
                warnT = WARN_T[ph], outT = OUT_T, ax = nx, ay = ny }
    if math.random() < CAMP then m.campT = rand(CAMP_T[1], CAMP_T[2]) end
    m.tx, m.ty = m.bx + nx * PEEK, m.by + ny * PEEK
    aim(m, pa)
    self.mouths[#self.mouths + 1] = m
    Sound.play('plantRustle', 0.8, 0.8)
    return m
end

-- Al contacto, te traga al instante (el usuario: como una lanza, sin esperar)
function Q:mouthEats(m, level)
    local hx, hy = Q.headPos(m)
    for _, q in ipairs(level.players or {}) do
        local b = q:getOuterBounds()
        if q.canBeSwallowed and q:canBeSwallowed()
           and hx + HEAD_BOX > b.x and hx - HEAD_BOX < b.x + b.w and hy + HEAD_BOX > b.y and hy - HEAD_BOX < b.y + b.h
           and q:swallow(hx, hy + q.h / 2, 0, -1) then
            q.gulpBy, m.held = m, q
            m.tx, m.ty = hx, hy
            m.state, m.t = 'hold', 0
            Sound.play('plantBite')
            Sound.play('plantCrunch', 0.9, 0.6)
            Entity.emitFx('shake_small', hx, hy)
            return true
        end
    end
end

-- El paso de una Lanza. true = se acabó
function Q:updateMouth(m, level, dt)
    m.t = m.t + dt
    local ph = self:ph()
    local pa = self:freePlayer(level)
    if m.state == 'out' or m.state == 'seek' or m.state == 'lunge' then
        if self:mouthEats(m, level) then return false end
    end
    if m.state == 'warn' then
        if pa then aim(m, pa) end
        if m.t >= m.warnT then
            if pa and math.abs(pa.x - m.bx) < ON_HOLE and math.abs(pa.y - m.by) < ON_HOLE then return true end    -- (te has puesto encima)
            m.state, m.t = 'out', 0
            Sound.play('plantRustle', 1.4, 0.5)
        end
    elseif m.state == 'out' then
        if pa then aim(m, pa, 0, TURN_V[ph] * dt) end
        if m.t >= m.outT then
            m.state, m.t = 'seek', 0
            Sound.play('plantRustle', 1.6, 0.7)
        end
    elseif m.state == 'seek' then
        -- el amago: se encoge apuntándote; el último tramo, fija: es cuando hay que apartarse
        if pa and m.t < SEEK_T[ph] - SEEK_LOCK then aim(m, pa, m.t / (SEEK_T[ph] - SEEK_LOCK), TURN_V[ph] * dt) end
        if m.t >= SEEK_T[ph] then
            local d = pa and math.sqrt((pa.x - m.bx) ^ 2 + (pa.y - m.by) ^ 2) or PEEK
            m.reach = math.min(LONG, d + OVERSHOOT)
            m.state, m.t = 'lunge', 0
            Sound.play('plantRustle', 1.9, 0.7)
        end
    elseif m.state == 'lunge' then
        m.tx, m.ty = m.tx + m.ax * LUNGE_V[ph] * dt, m.ty + m.ay * LUNGE_V[ph] * dt
        local dx, dy = m.tx - m.bx, m.ty - m.by
        -- (fallar: hasta su largo, o hasta chocar con el suelo o una pared: no atraviesa la sala)
        local hit = dx * dx + dy * dy > PEEK * PEEK and level:collisionAt(m.tx + m.ax * HEAD_BOX, m.ty + m.ay * HEAD_BOX, false) ~= nil
        if hit or dx * dx + dy * dy >= m.reach * m.reach then
            if m.campT then m.state, m.t = 'camp', 0 else m.state, m.t = 'shut', 0 end
            Sound.play('plantBite')
        end
    elseif m.state == 'camp' then
        -- ya falló: quieta y cerrada, ni te mira ni te come
        if m.t >= m.campT then m.state, m.t = 'back', 0 end
    elseif m.state == 'hold' then
        local q, here = m.held, false
        for _, o in ipairs(level.players or {}) do if o == q then here = true end end
        if not q or not here or q.gulpBy ~= m or not q.gulped or q.dying or q.alive == false then
            if q and q.gulpBy == m then q.gulpBy = nil end
            m.held, m.state, m.t = nil, 'back', 0
        end
    elseif m.state == 'shut' then
        if m.t >= SHUT_T then m.state, m.t = 'back', 0 end
    elseif m.state == 'back' then
        if m.t >= BACK_T then return true end
    end
    return false
end

-- El jugador libre más cercano: a quien ya está tragado ni se le apunta
function Q:freePlayer(level)
    local best, bd
    for _, pa in ipairs(level.players or {}) do
        if not pa.gulped and not pa.dying and pa.alive ~= false then
            local d = (pa.x - self.x) ^ 2 + (pa.y - self.y) ^ 2
            if not bd or d < bd then best, bd = pa, d end
        end
    end
    return best
end

-- Te han atrapado y no queda nadie libre (el usuario): las demás se van y no salen más; la que te tiene, sigue
function Q:withdrawMouths()
    self.mouthT = math.max(self.mouthT, CAUGHT_PAUSE)
    for i = #self.mouths, 1, -1 do
        local m = self.mouths[i]
        if m.state == 'warn' then table.remove(self.mouths, i)
        elseif m.state ~= 'hold' and m.state ~= 'back' then m.state, m.t = 'back', 0 end
    end
end

-- Saca Lanzas según toque (→ en idle y durante las enredaderas). `up`: solo del techo y las paredes, y muchas más
function Q:tickMouths(level, dt, up)
    local ph = self:ph()
    self.mouthT = self.mouthT - dt
    local pa = self:freePlayer(level)
    if not pa or self.mouthT > 0 or not self:mayAttack(level) then return end
    up = up or pa.y < self.groundY - HIGH
    local most = up and UP_MOUTHS[ph] or MOUTHS[ph]
    for _ = 1, math.random(1, BURST[ph]) do                          -- (varias a la vez)
        if #self.mouths < most then self:spawnMouth(level, pa, up) end
    end
    self.mouthT = (up and UP_CD[ph] or MOUTH_CD[ph]) * rand(0.85, 1.15)
end

-- El salto a su plataforma, y de vuelta
function Q:platformAbove(level)
    local _, _, zy0 = self:zoneBounds()
    for yy = self.groundY - T, zy0, -4 do
        if level:collisionAt(self.x, yy, true) then return math.floor(yy / T) * T end
    end
end
function Q:hopTo(feet)
    self.hopT, self.hopA, self.hopB = 0, self:feetY(), feet
    Sound.play('plantRustle', 1.4, 0.8)
end
function Q:updateHop(dt)
    if not self.hopT then return end
    self.hopT = self.hopT + dt
    local u = math.min(1, self.hopT / HOP_T)
    self.y = self.hopA + (self.hopB - self.hopA) * u - 4 * HOP_ARC * u * (1 - u) - self.outerH / 2
    if u >= 1 then
        self.hopT = nil
        Sound.play('boxLand', 0.6, 0.8)
        Entity.emitFx('shake_small', self.x, self.y)
    end
end

-- ¿Te tiene encima? (→ jugador)
function Q:playerClose(level)
    local fy = self:feetY()
    for _, pa in ipairs(level.players or {}) do
        if pa.canBeSwallowed and pa:canBeSwallowed() and math.abs(pa.x - self.x) < CHOMP_R and pa.y > fy - CHOMP_H then return pa end
    end
end

-- Hacia dónde muerde (para el dibujo: de lado y de alto, desde sus pies)
function Q:aimAt(px, py)
    self.aimT = math.max(-160, math.min(160, px - self.x))
    self.aimN = math.max(0, math.min(240, self:feetY() - py))
end

-- Se cierra: ella misma traga a quien siga a tiro. `held` y el estado 'hold' son lo que mira PlayerGulp. true = alguien
function Q:chomp(level)
    local fy = self:feetY()
    for _, pa in ipairs(level.players or {}) do
        if pa.canBeSwallowed and pa:canBeSwallowed() and math.abs(pa.x - self.x) < CHOMP_BOX and pa.y > fy - CHOMP_H
           and pa:swallow(self.x, fy, 0, -1) then
            pa.gulpBy, self.held = self, pa
            Sound.play('plantCrunch', 0.8, 0.9)
            self:enter('hold')                                   -- (aimT sigue el de antes de tragar: tragado, ya está en su centro)
            return true
        end
    end
end

-- Aturdida o derrotada: se retiran; las que tienen a alguien, lo sueltan
function Q:retractMouths()
    for _, m in ipairs(self.mouths) do
        if m.state ~= 'back' then
            m.held = nil                                 -- (el tragado ve que ya no lo tiene y sale: PlayerGulp)
            m.state, m.t = 'back', 0
        end
    end
end

-- ── Las semillas ──────────────────────────────────────────────────────────────
-- Cuántas plantas puede tener a la vez: por fase y dificultad
function Q:plantLimit(level)
    return math.max(1, math.min(PLANT_POOL, PLANTS[self:ph()] + (DIFF_PLANTS[level.difficulty or ''] or 0)))
end

function Q:spitSeed(level, i)
    local zx0, zx1 = self:zoneBounds()
    local pa = self:nearestPlayer(level)
    local x
    for _ = 1, 8 do                                                  -- (la 1ª, hacia ti; las demás, a cualquier lado y separadas)
        local dir = (i == 1 and pa) and ((pa.x >= self.x) and 1 or -1) or ((math.random() < 0.5) and -1 or 1)
        x = math.max(zx0 + T, math.min(zx1 - T, self.x + dir * rand(3, 11) * T))
        local ok = true
        for _, s in ipairs(self.seeds) do if math.abs(s.x1 - x) < 1.5 * T then ok = false end end
        if ok then break end
    end
    local x0, y0 = self:podCenter()
    local floor = self:floorBelow(level, x, y0)
    self.seeds[#self.seeds + 1] = { id = self:nid(), x = x0, y = y0, x0 = x0, y0 = y0, x1 = x, y1 = floor, t = 0, sprout = false }
    Sound.play('plantRustle', 1.7, 0.6)
end

function Q:activePlants(level)
    local free, active = nil, 0
    for _, e in ipairs(self:minions(level)) do
        if e.alive and e.state ~= 'dead' and not Entity.SPECIAL_DEATH[e.state] then active = active + 1
        elseif not free and not e.alive then free = e end
    end
    return free, active
end

function Q:updateSeeds(level, dt)
    for i = #self.seeds, 1, -1 do
        local s = self.seeds[i]
        s.t = s.t + dt
        if not s.sprout then
            local u = math.min(1, s.t / SEED_FLY)
            s.x = s.x0 + (s.x1 - s.x0) * u
            s.y = s.y0 + (s.y1 - s.y0) * u - 4 * 170 * u * (1 - u)
            if u >= 1 then
                s.sprout, s.t = true, 0
                Sound.play('boxLand', 1.4, 0.5)
                Entity.emitFx('crab_dig', s.x, s.y1)
            end
        elseif s.t >= SPROUT_T then
            local free = self:activePlants(level)
            if free then
                local h = free.home
                h.x, h.y = s.x1, s.y1 - free.outerH / 2
                free:resetToHome()
                free:init()
                Sound.play('plantRustle', 1.2, 0.7)
            end
            table.remove(self.seeds, i)
        end
    end
end

-- ── Bombas: una lanzada que cae en ella ───────────────────────────────────────
function Q:bombToEat(level)
    local fy = self:feetY()
    for _, e in ipairs(level.liveEntities or {}) do
        if e.onEaten and e.canBeEaten and e:canBeEaten() and math.abs(e.x - self.x) < EAT_W and e.y > fy - EAT_H and e.y < fy then
            return e
        end
    end
end

-- ── Golpes y derrota ──────────────────────────────────────────────────────────
function Q:onDamaged(n, kind)
    if self:isDying() then return end
    local frac = self.hp / self.hpMax
    local ph = (frac <= (self.props.rageAt or 1 / 3)) and 3 or ((frac <= (self.props.angerAt or 2 / 3)) and 2 or 1)
    if ph > self:ph() then
        self.phase = ph
        Entity.emitFx('shake_small', self.x, self.y)
        Sound.play('plantRustle', 0.6, 1)
    end
end

function Q:defeat()
    self.hp, self.inv, self.ghost = 0, 0, false
    self.held = nil
    self:retractMouths()
    self.seeds = {}
    for _, e in ipairs(self.levelRef and self:minions(self.levelRef) or {}) do
        if e.alive and e.state ~= 'dead' then e:dieBurst() end
    end
    self:enter('dying_out')
    Sound.play('megaHurt', 0.7, 0.9)
    Sound.play('stunned')
    self:onDefeat()
end

-- ── Update ────────────────────────────────────────────────────────────────────
function Q:updateBoss(dt, level)
    if self.state == 'dormant' then return end
    self.levelRef = self.levelRef or level
    self.deadTimer = self.deadTimer + dt
    self.vx, self.vy = 0, 0
    if #(level.players or {}) > 0 and not self:freePlayer(level) then self:withdrawMouths() end
    if self.chompCd > 0 then self.chompCd = math.max(0, self.chompCd - dt) end
    for i = #self.mouths, 1, -1 do
        if self:updateMouth(self.mouths[i], level, dt) then table.remove(self.mouths, i) end
    end
    self:updateSeeds(level, dt)
    self:updateHop(dt)
    local st, t, ph = self.state, self.deadTimer, self:ph()
    if st == 'fight' then self:enter('idle'); return end

    -- (la bomba, en cuanto cae en ella, salvo si ya está con otra o aturdida)
    if st == 'idle' or st == 'spit_wind' or st == 'spit' or st == 'recover' or st == 'vine_wind' or st == 'vines' then
        local b = self:bombToEat(level)
        if b then
            self.inside = b
            b:onEaten(self)
            self:aimAt(b.x, b.y)
            self.hopped = false                                  -- (también en su plataforma: las enredaderas acaban ahí)
            self:enter('bomb')
            Sound.play('queenBite')
            return
        end
    end

    if st == 'idle' then
        -- (si la aturdieron en su plataforma, primero baja)
        if self:feetY() < self.groundY - 1 or self.hopT then
            if not self.hopT then self:hopTo(self.groundY) end
            return
        end
        self.spitT = self.spitT - dt
        self.vineT = self.vineT - dt
        local pa = self:nearestPlayer(level)
        if self.chompCd <= 0 and self:playerClose(level) then
            self.chompCd = CHOMP_CD
            self:enter('bite_wind')
            Sound.play('plantRustle', 1.3, 0.9)
            return
        end
        if self.vineT <= 0 then
            self.vineT = VINE_CD[ph] * rand(0.9, 1.1)
            local zx0, zx1 = self:zoneBounds()
            self.vx0, self.vx1, self.vy0 = math.floor(zx0), math.floor(zx1), math.floor(self:feetY())
            self:enter('vine_wind')
            Sound.play('plantRustle', 0.6, 1)
            return
        end
        self:tickMouths(level, dt, false)
        if self.spitT <= 0 then
            local free, active = self:activePlants(level)
            self.spitT = SPIT_CD[ph] * (DIFF_CD[level.difficulty or ''] or 1) * rand(0.9, 1.1)
            if free and active + #self.seeds < self:plantLimit(level) then
                self:enter('spit_wind')
                Sound.play('plantRustle', 1.1, 0.7)
            end
        end
    elseif st == 'bite_wind' then
        local pa = self:freePlayer(level)
        if pa then self:aimAt(pa.x, pa.y) end
        if t >= CHOMP_WIND[ph] then
            self:enter('chomp_snap')
            Sound.play('queenBite')
            Entity.emitFx('shake_small', self.x, self.y)
        end
    elseif st == 'chomp_snap' then
        if self:chomp(level) then return end
        if t >= CHOMP_SNAP then self:enter('chomp_miss') end
    elseif st == 'chomp_miss' then
        if t >= CHOMP_EXTRA then self:enter('recover') end
    elseif st == 'hold' then
        local q, here = self.held, false
        for _, o in ipairs(level.players or {}) do if o == q then here = true end end
        if not q or not here or q.gulpBy ~= self or not q.gulped or q.dying or q.alive == false then
            if q and q.gulpBy == self then q.gulpBy = nil end
            self.held = nil
            self:enter('recover')
        end
    elseif st == 'vine_wind' then
        self:tickMouths(level, dt, true)
        if t >= HOP_DELAY and not self.hopped then
            self.hopped = true
            local top = self:platformAbove(level)
            if top then self:hopTo(top) end
        end
        if t >= VINE_WARN[ph] then
            self:enter('vines')
            -- (sus plantas del suelo mueren con ellas, y lo que venía en el aire no brota)
            self.seeds = {}
            for _, e in ipairs(self:minions(level)) do
                if e.alive and e.state ~= 'dead' and not Entity.SPECIAL_DEATH[e.state] then e:dieBurst() end
            end
            Sound.play('plantSnap', 0.6, 1)
            Entity.emitFx('shake_small', self.x, self.y)
        end
    elseif st == 'vines' then
        self:tickMouths(level, dt, true)
        -- quien pise el suelo de la sala: pincha y lo lanza hacia arriba
        for _, pa in ipairs(level.players or {}) do
            local b = pa:getOuterBounds()
            if not pa.dying and pa.alive ~= false and not pa.gulped and not pa:isInvulnerable() and b.x + b.w > self.vx0 and b.x < self.vx1
               and b.y + b.h > self.vy0 - VINE_H and b.y < self.vy0 + 4 then
                Boss.strike(pa, HIT_VINE, (pa.x >= self.x) and 1 or -1)
            end
        end
        if t >= VINE_T[ph] then
            self:enter('vine_back')
            Sound.play('plantRustle', 1, 0.7)
            self.hopped = false
            if self:feetY() < self.groundY - 1 then self:hopTo(self.groundY) end
        end
    elseif st == 'vine_back' then
        if t >= VINE_BACK and not self.hopT then self:enter('idle') end
    elseif st == 'spit_wind' then
        if t >= SPIT_WIND then
            local _, active = self:activePlants(level)
            local room = self:plantLimit(level) - active - #self.seeds
            for i = 1, math.max(1, math.min(SEEDS[ph], room)) do self:spitSeed(level, i) end
            self:enter('spit')
        end
    elseif st == 'spit' then
        if t >= SPIT_T then self:enter('idle') end
    elseif st == 'bomb' then
        local b = self.inside
        if not b or not b.alive or b.state ~= 'eaten' then
            self.inside = nil
            self:retractMouths()
            Sound.play('stunned')
            Entity.emitFx('shake_small', self.x, self.y)
            self:enter('blast')
        end
    elseif st == 'blast' then
        if t >= BLAST_T then
            self.stunLen = STUN_T[level.difficulty or ''] or STUN_T.normal
            self:enter('stun')
        end
    elseif st == 'stun' then
        if t >= self:downTime(self.stunLen or STUN_T.normal) then
            Sound.play('plantRustle', 0.9, 0.8)
            self:enter('recover')
        end
    elseif st == 'recover' then
        if t >= RECOVER_T then self.mouthT = MOUTH_CD[ph] * 0.7; self:enter('idle') end
    elseif st == 'dying_out' then
        if t >= OUT_D then self:enter('dying_flee'); Sound.play('plantCrunch', 0.7, 0.8) end
    elseif st == 'dying_flee' then
        if t >= FLEE_T then self.state, self.alive = 'dead', false end
    end
end

-- ── Entrada: cerrada, se abre y estira las hojas ─────────────────────────────
local OPEN_AT = 1.3
function Q:introFocus()
    local zx0, zx1, zy0, zy1 = self:zoneBounds()
    return (zx0 + zx1) / 2, (zy0 + zy1) / 2
end
function Q:onIntroStart(level, players)
    self.introStep = 0
    self.levelRef = self.levelRef or level
end
function Q:updateIntro(dt, level, t)
    self.x, self.y = self.home.x, self.home.y
    if t >= 0.4 and self.introStep < 1 then self.introStep = 1; Sound.play('plantRustle', 0.7, 0.9) end
    if t >= OPEN_AT and self.introStep < 2 then
        self.introStep = 2
        Sound.play('plantSnap', 0.7, 1)
        Entity.emitFx('shake_small', self.x, self.y)
    end
end

-- ── Red ───────────────────────────────────────────────────────────────────────
local MSTATE = { warn = 1, out = 2, lunge = 3, hold = 4, shut = 5, back = 6, seek = 7, camp = 8 }
local MNAME = { 'warn', 'out', 'lunge', 'hold', 'shut', 'back', 'seek', 'camp' }
function Q:netPackExtra()
    local out = { self:ph(), self.vx0, self.vx1, self.vy0, math.floor(self.aimT or 0), math.floor(self.aimN or 0), #self.mouths }
    for _, m in ipairs(self.mouths) do
        local n = #out
        out[n + 1], out[n + 2], out[n + 3], out[n + 4], out[n + 5] = m.id, MSTATE[m.state], math.floor(m.t * 100), m.bx, m.by
        out[n + 6], out[n + 7], out[n + 8], out[n + 9] = m.nx, m.ny, math.floor(m.tx), math.floor(m.ty)
        out[n + 10], out[n + 11] = math.floor(m.outT * 100), math.floor(m.warnT * 100)
        out[n + 12], out[n + 13] = math.floor(m.ax * 100), math.floor(m.ay * 100)
    end
    out[#out + 1] = #self.seeds
    for _, s in ipairs(self.seeds) do
        local n = #out
        out[n + 1], out[n + 2], out[n + 3], out[n + 4], out[n + 5] = s.id, math.floor(s.x), math.floor(s.y), math.floor(s.t * 100), s.sprout and 1 or 0
    end
    return out
end

function Q:netApplyExtra(a, b, f)
    if type(b[1]) ~= 'number' then return end
    self.phase = b[1]
    self.vx0, self.vx1, self.vy0 = b[2], b[3], b[4]
    self.aimT, self.aimN = b[5], b[6]
    local k = 8
    local ms = {}
    for _ = 1, b[7] or 0 do
        ms[#ms + 1] = { id = b[k], state = MNAME[b[k + 1]], t = b[k + 2] / 100, bx = b[k + 3], by = b[k + 4], nx = b[k + 5], ny = b[k + 6],
                        tx = b[k + 7], ty = b[k + 8], outT = b[k + 9] / 100, warnT = b[k + 10] / 100,
                        ax = b[k + 11] / 100, ay = b[k + 12] / 100 }
        k = k + 13
    end
    self.mouths = ms
    local ss = {}
    local ns = b[k] or 0
    k = k + 1
    for _ = 1, ns do
        ss[#ss + 1] = { id = b[k], x = b[k + 1], y = b[k + 2], t = b[k + 3] / 100, sprout = b[k + 4] == 1 }
        k = k + 5
    end
    self.seeds = ss
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
local parts, seedSet, vineSet
function Q.loadAssets()
    parts = parts or Anim.load('bosses/carnqueen_parts')
    seedSet = seedSet or Anim.load('bosses/carnqueen_seed')
    vineSet = vineSet or Anim.load('bosses/carnqueen_vine')
end

local GAP = 14                                  -- px entre discos del tallo más largo
local CHAIN_N = math.ceil(LONG / GAP) + 1       -- (de largo fijo: se estira de golpe al lanzarse)
local LAYERS = { 'stalk_line', 'stalk_shade', 'stalk_light' }

-- La curva del tallo: sale de su superficie y llega por detrás de hacia donde mira; larga, casi recta
local function fillStalk(tg, n, bx, by, nx, ny, hx, hy, ax, ay, len)
    Chain.bez(tg, n, bx, by, bx + nx * len * 0.22, by + ny * len * 0.22, hx - ax * len * 0.3, hy - ay * len * 0.3, hx, hy)
end

function Q:drawMouth(m, camX, camY, dt, r, g, b, alpha)
    -- el agujero: se abre con el aviso; girado según la superficie
    local stage = 3
    if m.state == 'warn' then stage = (m.t < m.warnT * 0.5) and 1 or 2 end
    local rot = (m.ny < 0) and 0 or ((m.ny > 0) and math.pi or ((m.nx > 0) and math.pi / 2 or -math.pi / 2))
    love.graphics.setColor(r, g, b, alpha)
    parts:drawFrame(parts:frameN('socket', stage), math.floor(m.bx - camX), math.floor(m.by - camY), rot, MS, MS, 0.5, 0.8)
    if m.state == 'warn' then return end
    self.chains = self.chains or {}
    local c = self.chains[m.id]
    if not c then
        c = Chain.new(CHAIN_N, 0.1)
        self.chains[m.id] = c
    end
    local hx, hy = Q.headPos(m)
    local len = math.sqrt((hx - m.bx) ^ 2 + (hy - m.by) ^ 2)
    -- El amago tiembla más cuanto más cerca está de lanzarse, y parpadea en el tramo final
    local tr, tg, tb = r, g, b
    if m.state == 'seek' then
        local seek = SEEK_T[self:ph()]
        local u = math.min(1, m.t / seek)
        local sh = math.floor(1 + u * 3)
        if math.floor(m.t * 30) % 2 == 1 then sh = -sh end
        hx, hy = hx - m.ay * sh, hy + m.ax * sh
        if m.t >= seek - SEEK_LOCK and math.floor(m.t * 16) % 2 == 0 then tr, tg, tb = r, g * 0.45, b * 0.45 end
    end
    -- (sin muelle: el tallo es siempre la curva exacta hasta la cabeza. Con él, y su largo medido en línea recta, la punta se
    -- quedaba corta de la curva y la cabeza parecía suelta)
    local want = math.atan2(m.ay, m.ax)                    -- (lo que llega por red va a saltos: lo dibujado gira suave)
    c.ang = c.ang or want
    local da = (want - c.ang + math.pi) % (2 * math.pi) - math.pi
    local turn = 9 * dt
    c.ang = c.ang + math.max(-turn, math.min(turn, da))
    local ax, ay = math.cos(c.ang), math.sin(c.ang)
    c:place(fillStalk, m.bx, m.by, m.nx, m.ny, hx, hy, ax, ay, len)
    local gap = len / (c.n - 1)
    local stride = math.max(1, math.floor(8 / math.max(0.5, gap)))    -- (corto, sin dibujar discos unos encima de otros)
    for _, name in ipairs(LAYERS) do                       -- (contornos, sombras y luces: un tubo liso de 3 tonos)
        for j = 1, c.n - 1, stride do
            local x, y = c:pos(j)
            parts:drawFrame(parts:frameN(name, math.min(5, math.floor((j - 1) * 5 / c.n) + 1)), math.floor(x - camX), math.floor(y - camY), 0, MS, MS, 0.5, 0.5)
        end
    end
    -- (el usuario: fauces abiertas del todo al cargar y al lanzarse; solo se cierra al morder: con presa o al fallar)
    local name = 'head_closed'
    if m.state == 'hold' then name = 'head_prey'
    elseif m.state == 'out' then name = 'head_half'
    elseif m.state == 'seek' or m.state == 'lunge' then name = 'head_wide' end
    local d = math.floor(c.ang / (math.pi * 2) * 16 + 0.5) % 16 + 1
    love.graphics.setColor(tr, tg, tb, alpha)
    parts:drawFrame(parts:frameN(name, d), math.floor(hx - camX), math.floor(hy - camY), 0, MS, MS, 0.5, 0.5)
end

-- El mordisco (como Plant:pose): → sx, sy, inclinación de la punta (px) y temblor. Avisando se encoge y se echa atrás; cerrándose
-- se estira hacia ti; al morder rebota (estirada → aplastada → en reposo)
local function spring(rt)
    if rt < 0.04 then return 0.6 + 0.4 * rt / 0.04 end
    rt = rt - 0.04
    return math.exp(-rt * 6) * math.cos(rt * 18)
end
function Q:pose(st, t)
    local aimN = self.aimN or 0
    local str = math.max(STRETCH_MIN, math.min(STRETCH_MAX, STRETCH_MIN + aimN / 500))
    local lean = math.max(-LEAN_MAX, math.min(LEAN_MAX, (self.aimT or 0) * 0.9))
    local shake = (math.floor(t * 30) % 2 == 0) and 1 or -1
    if st == 'bite_wind' then
        local q = math.min(1, t / CHOMP_WIND[self:ph()])
        return 1 + 0.08 * q, 1 - 0.14 * q, -lean * 0.2 * q, shake * MS
    elseif st == 'chomp_snap' then
        local p = math.sin(math.pi / 2 * math.min(1, t / (CHOMP_SNAP * 0.6)))
        return 1 - 0.35 * str * p, 1 + str * p, lean * p, 0
    elseif st == 'hold' or st == 'chomp_miss' or st == 'bomb' then
        if t < RECOIL_T then
            local v = spring(t) * (1 - t / RECOIL_T)
            return 1 - 0.35 * str * v, 1 + str * v, lean * v, 0
        end
        if st ~= 'chomp_miss' then return 1, 1, 0, ((math.floor(t * 16) % 2 == 0) and 1 or -1) * MS end     -- (masticando)
    end
    return 1, 1, 0, 0
end

function Q:render(camX, camY)
    if self.state == 'dormant' and not EDITOR_VIEW then return end
    if self.state == 'dead' then return end
    self.loadAssets()
    local st, t = self.state, self.deadTimer or 0
    local now = love.timer.getTime()
    local dt = math.min(0.1, now - (self.lastDraw or now))
    self.lastDraw = now
    local set = self:anims()
    local alpha = self:ghostAlpha()
    local sinkPx = 0
    if st == 'dying_flee' then
        alpha = alpha * math.max(0, 1 - t / FLEE_T)        -- (se hunde en la tierra, ya sin la flor)
        sinkPx = math.floor(t * 50)
    end
    local name = 'idle'
    if self.hopT then name = 'closed'                      -- (en el aire)
    elseif st == 'vines' then name = 'idle'
    elseif st == 'spit_wind' then name = 'spit1'
    elseif st == 'spit' then name = 'spit2'
    elseif st == 'bomb' then name = (t < 0.15) and 'closed' or 'gulp'
    elseif st == 'blast' then name = 'blast'
    elseif st == 'stun' or st == 'dying_out' then name = 'stun'
    elseif st == 'recover' or st == 'vine_back' then name = 'tell'
    elseif st == 'bite_wind' or st == 'vine_wind' then name = 'blast'
    elseif st == 'hold' then name = 'gulp'
    elseif st == 'chomp_miss' then name = 'closed'
    elseif st == 'chomp_snap' then name = (t < CHOMP_SNAP * 0.4) and 'tell' or 'closed'
    elseif st == 'dying_flee' then name = 'closed'
    elseif st == 'intro' or st == 'ready' then
        if st == 'intro' and t < OPEN_AT then name = 'closed' elseif st == 'intro' and t < OPEN_AT + 0.3 then name = 'tell' end
    end
    local fr = (name == 'idle' or name == 'stun') and set:frameAt(name, now) or set:frameAt(name, 0)
    local x = math.floor(self.x - camX)
    local feet = math.floor(self:feetY() - camY) + set:footGap(fr) * MS + SINK * MS + sinkPx
    local r, g, b = 1, 1, 1
    if self:flashRed() then r, g, b = 1, 0.35, 0.35 end
    love.graphics.setColor(r, g, b, alpha)
    local px, py, lean, shakeX = self:pose(st, t)
    x = x + shakeX
    local sx, sy = MS * px, MS * py
    -- (inclinación: la punta — FH px por encima de la base — se corre `lean` px; la base, quieta)
    local kx = (lean ~= 0) and (-lean / (FH * sx)) or 0
    set:drawFrame(fr, x, feet, 0, sx, sy, 0.5, 1, kx, 0)
    -- La flor y su gota (capas sueltas; al soltar la pieza, sin gota)
    if name ~= 'closed' and name ~= 'gulp' then
        local open = name == 'stun'
        local fh = -(open and FLOWER_OPEN or FLOWER_BUD)     -- (la flor sigue a la pose: a su altura, estirada e inclinada)
        local fx = math.floor(x + lean * fh / FH) + ((math.floor(now * 2) % 2 == 1 and not open) and MS or 0)
        local fy = math.floor(self:feetY() - camY - fh * sy) + SINK * MS
        parts:drawFrame(parts:frameN(open and 'flower_open' or 'flower_bud', 1), fx, fy, 0, MS, MS, 0.5, 0.5)
        if not self:shardDrop() and self.props.wear ~= false then
            parts:drawFrame(parts:frameN(open and 'dew_open' or 'dew_bud', 1), fx, fy, 0, MS, MS, 0.5, 0.5)
        end
        if open then BossFx.stars(fx, fy - 12 * MS, 8 * MS, 1.2 * MS, 5, alpha, 'back') end
    end
    -- Las enredaderas del piso: asoman (el aviso), con espinas (pinchan) y se retiran; un tramo cada casilla
    if st == 'vine_wind' or st == 'vines' or st == 'vine_back' then
        local i = (st == 'vines') and 3 or ((st == 'vine_back') and 2 or ((t < (self.vineWarnShow or 0.6)) and 1 or 2))
        love.graphics.setColor(1, 1, 1, alpha)
        local fr2 = vineSet:frameN('grow', i)
        for vx = self.vx0, self.vx1 - 4 * T, 4 * T do       -- (cada tramo, 4 casillas)
            vineSet:drawFrame(fr2, math.floor(vx - camX), math.floor(self.vy0 - camY) + 4, 0, 4, 4, 0, 1)
        end
    end
    -- Las bocas y las semillas
    local seen = {}
    for _, m in ipairs(self.mouths or {}) do
        seen[m.id] = true
        self:drawMouth(m, camX, camY, dt, r, g, b, alpha)
    end
    if self.chains then for id in pairs(self.chains) do if not seen[id] then self.chains[id] = nil end end end
    love.graphics.setColor(1, 1, 1, alpha)
    for _, s in ipairs(self.seeds or {}) do
        if s.sprout then
            seedSet:drawFrame(seedSet:frameAt('sprout', s.t), math.floor(s.x - camX), math.floor(s.y - camY) - 28, 0, 4, 4, 0.5, 0.5)
        else
            seedSet:drawFrame(seedSet:frameAt('seed', s.t), math.floor(s.x - camX), math.floor(s.y - camY), 0, 4, 4, 0.5, 0.5)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Q:debugBoxes()
    local out = {}
    for _, m in ipairs(self.mouths or {}) do
        if m.state == 'out' or m.state == 'seek' or m.state == 'lunge' then
            local hx, hy = Q.headPos(m)
            out[#out + 1] = { x = hx - HEAD_BOX, y = hy - HEAD_BOX, w = HEAD_BOX * 2, h = HEAD_BOX * 2, kind = 'hazard' }
        end
    end
    if self.state == 'stun' then
        local fx, fy = self:flowerPos()
        out[#out + 1] = { x = fx - FLOWER_R, y = fy - FLOWER_R, w = FLOWER_R * 2, h = FLOWER_R * 2, kind = 'area' }
    end
    return out
end

local G = 'Reina Carnívora'
return {
    name = 'carnqueen', label = 'Reina Carnívora', category = 'Jefes',
    description = 'Jefa secreta de la jungla, enraizada. Lanzas que brotan del suelo, las paredes y el techo y te tragan; escupe '
               .. 'semillas que brotan en plantas. Lánzale una bomba: le explota dentro y puedes pisar su flor.',
    class = Q,
    boss = { title = 'REINA CARNÍVORA' },
    hide = Boss.HIDE,
    defaults = { points = 30 },
    props = Boss.props({ hp = 8, hpPerPlayer = 3 }, {
        Boss.WEAR_PROP,
        { key = 'angerAt', kind = 'number', label = 'Fase 2 con (fracción de vida)', group = G, default = 2 / 3,
          min = 0.2, max = 0.95, step = 0.05 },
        { key = 'rageAt', kind = 'number', label = 'Fase 3 con (fracción de vida)', group = G, default = 1 / 3,
          min = 0.1, max = 0.9, step = 0.05 },
    }),
    editor = { sprite = 'assets/images/bosses/carnqueen/body-Sheet.png', frameW = FW },
    -- Las plantas de sus semillas: de reserva; brotan donde cae cada semilla (Q:updateSeeds)
    summons = function(pl)
        local out = {}
        for _ = 1, PLANT_POOL do
            out[#out + 1] = { type = 'carnivoreplant', col = pl.col, row = pl.row, summonKey = 'cq' .. pl.col .. ',' .. pl.row,
                              props = { points = 5, respawn = 0 } }
        end
        return out
    end,
}
