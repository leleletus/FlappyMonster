-- Jefa secreta REINA CARNÍVORA (types/bosses/carnqueen.lua): la Planta carnívora de la jungla, tumbada y enorme (diseño A
-- «Cepo Real», sin cara: el usuario, 2026-11-01; docs/bosses/carnqueen.md). Enraizada en el centro de la sala del templo.
--   · LAS BOCAS brotan del suelo, las paredes y el techo cerca de ti: el agujero se abre (el aviso), la boca sale hacia donde
--     estás y se cierra. Si te pilla, te TRAGA: machacar botones para salir, como la Planta (PlayerGulp). Solo traga: no hay
--     más daño que ese. Más bocas a la vez en cada fase; desde la 2ª siguen al jugador mientras salen.
--   · ESCUPE SEMILLAS en arco que brotan en plantas carnívoras normales (súbditas de reserva).
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
    ATTACKS  = { spit_wind = true, spit = true },
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
local MOUTHS   = { 1, 2, 3 }                    -- bocas a la vez
local MOUTH_CD = { 2.2, 1.6, 1.1 }              -- s entre una boca y la siguiente
local WARN_T   = { 0.8, 0.65, 0.55 }            -- s con el agujero abriéndose
local OUT_T    = { 0.32, 0.28, 0.24 }           -- s saliendo
local BITE_T   = 0.14
local BACK_T   = 0.32
local SHUT_T   = 0.5                            -- s cerrada tras fallar, antes de volver
local LOCK_T   = 0.22                           -- s antes de salir en que deja de apuntar: lo que hay para esquivarla
local TRACK    = { 0, 0.5, 0.8 }                -- cuánto la sigue mientras sale
local REACH    = 4.6 * T                        -- lo más largo de un tallo
local NEAR     = 4.2 * T                        -- a cuánto de una pared o del techo puede salir de ahí
local HEAD_BOX = 34
local SPIT_CD  = { 7.5, 6, 5 }
local SPIT_WIND, SPIT_T = 0.5, 0.35
local SEED_G, SEED_FLY, SPROUT_T = 1500, 1.0, 0.7
local PLANTS   = { 1, 2, 2 }                    -- plantas de semilla a la vez
local PLANT_POOL = 2
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
    self.mouthT, self.spitT = 1.5, SPIT_CD[1]
    self.summonKey = 'cq' .. self.col .. ',' .. self.row
end

function Q:onFightStart(n) self:enter('fight') end
function Q:rollStart(r) self.mouthT, self.spitT = r(0.8, 2.2), r(3, SPIT_CD[1]) end

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

-- Limita el objetivo al largo del tallo
local function clampReach(m, x, y)
    local dx, dy = x - m.bx, y - m.by
    local d = math.sqrt(dx * dx + dy * dy)
    if d > REACH then dx, dy = dx / d * REACH, dy / d * REACH end
    return m.bx + dx, m.by + dy
end

-- Una boca nueva cerca del jugador: del suelo bajo él, de una pared o del techo si los tiene a mano
function Q:spawnMouth(level, pa)
    local zx0, zx1, zy0 = self:zoneBounds()
    local px, py = pa.x, pa.y
    local opts = {}
    local side = (math.random() < 0.5) and -1 or 1
    local fx = math.max(zx0 + T, math.min(zx1 - T, px + side * rand(1.2, 2.4) * T))
    opts[#opts + 1] = { fx, self:floorBelow(level, fx, py), 0, -1 }
    if px - zx0 < NEAR then opts[#opts + 1] = { zx0, math.max(zy0 + T, py + rand(-1, 1) * T), 1, 0 } end
    if zx1 - px < NEAR then opts[#opts + 1] = { zx1, math.max(zy0 + T, py + rand(-1, 1) * T), -1, 0 } end
    if py - zy0 < NEAR + T then opts[#opts + 1] = { math.max(zx0 + T, math.min(zx1 - T, px + side * rand(0.5, 1.5) * T)), zy0, 0, 1 } end
    local o = opts[math.random(#opts)]
    local ph = self:ph()
    local m = { id = self:nid(), state = 'warn', alive = true, t = 0, bx = math.floor(o[1]), by = math.floor(o[2]), nx = o[3], ny = o[4],
                warnT = WARN_T[ph], outT = OUT_T[ph] }
    m.tx, m.ty = clampReach(m, px, py)
    self.mouths[#self.mouths + 1] = m
    Sound.play('plantRustle', 0.8, 0.8)
end

-- El paso de una boca. true = se acabó
function Q:updateMouth(m, level, dt)
    m.t = m.t + dt
    local ph = self:ph()
    local pa = self:nearestPlayer(level)
    if m.state == 'warn' then
        if pa and m.t < m.warnT - LOCK_T then m.tx, m.ty = clampReach(m, pa.x, pa.y) end
        if m.t >= m.warnT then m.state, m.t = 'out', 0; Sound.play('plantSnap', 1.3, 0.5) end
    elseif m.state == 'out' then
        if pa and TRACK[ph] > 0 then
            local x, y = clampReach(m, pa.x, pa.y)
            local k = math.min(1, TRACK[ph] * dt * 6)
            m.tx, m.ty = m.tx + (x - m.tx) * k, m.ty + (y - m.ty) * k
        end
        if m.t >= m.outT then m.state, m.t = 'bite', 0 end
    elseif m.state == 'bite' then
        if m.t >= BITE_T then
            Sound.play('plantSnap')
            local hx, hy = m.tx, m.ty
            for _, q in ipairs(level.players or {}) do
                local b = q:getOuterBounds()
                if q.canBeSwallowed and q:canBeSwallowed()
                   and hx + HEAD_BOX > b.x and hx - HEAD_BOX < b.x + b.w and hy + HEAD_BOX > b.y and hy - HEAD_BOX < b.y + b.h
                   and q:swallow(hx, hy + q.h / 2, 0, -1) then
                    q.gulpBy, m.held = m, q
                    m.state, m.t = 'hold', 0
                    Sound.play('plantCrunch', 0.9, 0.8)
                    return false
                end
            end
            m.state, m.t = 'shut', 0
        end
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
function Q:spitSeed(level)
    local zx0, zx1 = self:zoneBounds()
    local pa = self:nearestPlayer(level)
    local dir = (pa and pa.x >= self.x) and 1 or -1
    local x = math.max(zx0 + T, math.min(zx1 - T, self.x + dir * rand(3, 8) * T))
    local x0, y0 = self:podCenter()
    local floor = self:floorBelow(level, x, y0)
    self.seeds[#self.seeds + 1] = { id = self:nid(), x = x0, y = y0, x0 = x0, y0 = y0, x1 = x, y1 = floor, t = 0, sprout = false }
    Sound.play('plantSnap', 1.7, 0.6)
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
    for i = #self.mouths, 1, -1 do
        if self:updateMouth(self.mouths[i], level, dt) then table.remove(self.mouths, i) end
    end
    self:updateSeeds(level, dt)
    local st, t, ph = self.state, self.deadTimer, self:ph()
    if st == 'fight' then self:enter('idle'); return end

    -- (la bomba, en cuanto cae en ella, salvo si ya está con otra o aturdida)
    if st == 'idle' or st == 'spit_wind' or st == 'spit' or st == 'recover' then
        local b = self:bombToEat(level)
        if b then
            self.inside = b
            b:onEaten(self)
            self:enter('bomb')
            Sound.play('plantSnap', 0.8, 1)
            return
        end
    end

    if st == 'idle' then
        self.mouthT, self.spitT = self.mouthT - dt, self.spitT - dt
        local pa = self:nearestPlayer(level)
        if pa and self.mouthT <= 0 and #self.mouths < MOUTHS[ph] and self:mayAttack(level) then
            self:spawnMouth(level, pa)
            self.mouthT = MOUTH_CD[ph] * rand(0.85, 1.15)
        end
        if self.spitT <= 0 then
            local free, active = self:activePlants(level)
            self.spitT = SPIT_CD[ph] * rand(0.9, 1.1)
            if free and active + #self.seeds < PLANTS[ph] then
                self:enter('spit_wind')
                Sound.play('plantRustle', 1.1, 0.7)
            end
        end
    elseif st == 'spit_wind' then
        if t >= SPIT_WIND then self:spitSeed(level); self:enter('spit') end
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
local MSTATE = { warn = 1, out = 2, bite = 3, hold = 4, shut = 5, back = 6 }
local MNAME = { 'warn', 'out', 'bite', 'hold', 'shut', 'back' }
function Q:netPackExtra()
    local out = { self:ph(), #self.mouths }
    for _, m in ipairs(self.mouths) do
        local n = #out
        out[n + 1], out[n + 2], out[n + 3], out[n + 4], out[n + 5] = m.id, MSTATE[m.state], math.floor(m.t * 100), m.bx, m.by
        out[n + 6], out[n + 7], out[n + 8], out[n + 9] = m.nx, m.ny, math.floor(m.tx), math.floor(m.ty)
        out[n + 10], out[n + 11] = math.floor(m.outT * 100), math.floor(m.warnT * 100)
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
    local k = 3
    local ms = {}
    for _ = 1, b[2] or 0 do
        ms[#ms + 1] = { id = b[k], state = MNAME[b[k + 1]], t = b[k + 2] / 100, bx = b[k + 3], by = b[k + 4], nx = b[k + 5], ny = b[k + 6],
                        tx = b[k + 7], ty = b[k + 8], outT = b[k + 9] / 100, warnT = b[k + 10] / 100 }
        k = k + 11
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
local parts, seedSet
function Q.loadAssets()
    parts = parts or Anim.load('bosses/carnqueen_parts')
    seedSet = seedSet or Anim.load('bosses/carnqueen_seed')
end

local GAP = 2 * MS
local HEAD_OUT = 44
local LAYERS = { 'stalk_line', 'stalk_shade', 'stalk_light' }

-- La curva del tallo: en S, de su base a la cabeza
local function fillStalk(tg, n, bx, by, nx, ny, hx, hy, e)
    local px, py = -ny, nx
    Chain.bez(tg, n, bx, by, bx + nx * 70 * e + px * 46 * e, by + ny * 70 * e + py * 46 * e,
              hx - nx * 40 * e - px * 40 * e, hy - ny * 40 * e - py * 40 * e, hx, hy)
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
        local dx, dy = m.tx - m.bx, m.ty - m.by
        local n = math.max(6, math.floor(math.sqrt(dx * dx + dy * dy) * 1.2 / GAP) + 1)
        c = Chain.new(n, 0.1)
        self.chains[m.id] = c
    end
    local e = ext(m)
    local hx, hy = Q.headPos(m)
    c.gap = math.max(0.1, GAP * e)
    c:advance(dt, 0.7, 0.42, 1.6, fillStalk, m.bx, m.by, m.nx, m.ny, hx, hy, e)
    for _, name in ipairs(LAYERS) do                       -- (contornos, sombras y luces: un tubo liso de 3 tonos)
        for j = 1, c.n - 1 do
            local x, y = c:pos(j)
            parts:drawFrame(parts:frameN(name, math.min(5, math.floor((j - 1) * 5 / c.n) + 1)), math.floor(x - camX), math.floor(y - camY), 0, MS, MS, 0.5, 0.5)
        end
    end
    local name = 'head_wide'
    if m.state == 'hold' then name = 'head_prey'
    elseif m.state == 'bite' or m.state == 'shut' or m.state == 'back' then name = 'head_closed'
    elseif m.t < m.outT * 0.3 then name = 'head_half' end
    local x, y = c:pos(c.n)
    x, y = x + m.nx * (1 - e) * HEAD_OUT, y + m.ny * (1 - e) * HEAD_OUT          -- (al asomar, ya fuera de la superficie)
    local d = math.floor(c:tipAngle() / (math.pi * 2) * 16 + 0.5) % 16 + 1
    parts:drawFrame(parts:frameN(name, d), math.floor(x - camX), math.floor(y - camY), 0, MS, MS, 0.5, 0.5)
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
    if st == 'spit_wind' then name = 'spit1'
    elseif st == 'spit' then name = 'spit2'
    elseif st == 'bomb' then name = (t < 0.15) and 'closed' or 'gulp'
    elseif st == 'blast' then name = 'blast'
    elseif st == 'stun' or st == 'dying_out' then name = 'stun'
    elseif st == 'recover' then name = 'tell'
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
    set:drawFrame(fr, x, feet, 0, MS, MS, 0.5, 1)
    -- La flor y su gota (capas sueltas; al soltar la pieza, sin gota)
    if name ~= 'closed' and name ~= 'gulp' then
        local open = name == 'stun'
        local fx = x + ((math.floor(now * 2) % 2 == 1 and not open) and MS or 0)
        local fy = math.floor(self:feetY() - camY) + (open and FLOWER_OPEN or FLOWER_BUD) * MS + SINK * MS
        parts:drawFrame(parts:frameN(open and 'flower_open' or 'flower_bud', 1), fx, fy, 0, MS, MS, 0.5, 0.5)
        if not self:shardDrop() and self.props.wear ~= false then
            parts:drawFrame(parts:frameN(open and 'dew_open' or 'dew_bud', 1), fx, fy, 0, MS, MS, 0.5, 0.5)
        end
        if open then BossFx.stars(fx, fy - 12 * MS, 8 * MS, 1.2 * MS, 5, alpha, 'back') end
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
        if m.state == 'bite' then
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
    description = 'Jefa secreta de la jungla, enraizada. Bocas que brotan del suelo, las paredes y el techo y te tragan; escupe '
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
