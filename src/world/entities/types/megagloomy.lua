-- MEGA CRABBY LÚGUBRE (jefe de los niveles A OSCURAS). Ciego: no te ve, te OYE. Toda la pelea
-- sale de UNA regla, la misma de los Crabbies lúgubres, y se ve en pantalla:
--
--     ATACA EL ÚLTIMO "!" ROJO.   (y solo se le daña alumbrándolo cuando está en el suelo)
--
-- Un "!" rojo (src/fx/NoiseMarks.lua) aparece donde algo hace ruido: saltar, un ground pound,
-- recibir un golpe, matar a un enemigo. ANDAR no hace ruido. Ese sitio es el que el jefe conoce.
--
-- ECOLOCALIZACIÓN (para qué son los aros): cada `pingEvery` s suelta un ARO que crece desde su
-- cuerpo (así se sabe dónde está). Si el aro pasa por un jugador que SE MUEVE, lo detecta: sale
-- un "!" encima de él. Quieto mientras pasa el aro = no te encuentra. (Un aro por vez, siempre
-- desde él: sin aros falsos.)
--
-- ATAQUES. Antes de cada uno APUNTA ('aim'): los ojos parpadean, suena su aviso y se dibuja,
-- desde el primer momento y ya fijo, DÓNDE va a dar — cada ataque con su marca:
--   CAÍDA   ('drop')   una diana en el suelo → salta ahí. Al caer queda EN EL SUELO ('grounded').
--   PATAS   ('stab')   tres líneas verticales → se coloca en el techo y clava tres patas, una
--                      tras otra, de arriba abajo. Refugio: cualquier sitio entre las líneas.
--   EMBESTIDA ('lunge', fase 2+)   una línea horizontal a la altura del "!" → se pone en una
--                      pared a esa altura y cruza la arena hasta la otra. Se salta o se agacha.
--   Tocarlo en cualquier ataque = 1 de vida + empujón. Van siempre en el mismo orden (SEQ).
--   Si mientras apunta le da una LINTERNA, se asusta y cancela el ataque ("…").
-- CÓMO SE LE DAÑA: tras la CAÍDA se queda en el suelo `GROUND_T` s. Sin luz es inmune (rebotas).
--   Alumbrado ahí → DESLUMBRADO ('dazzled', se encoge): pisotón 1 / ground pound 2 (un golpe).
-- FASE 2 (vida ≤ 66 %): añade la embestida y va más rápido.
-- FASE 3 (≤ 33 %): GRITO ('shriek', cada `shriekEvery` s): las linternas alcanzan la mitad
--   `dimTime` s (level.lightScale) y llama a Crabbies lúgubres por las paredes.
-- BURLA ('taunt'): si un ataque le da a alguien, luego se queda un momento haciendo flexiones.
-- MUERTE (es un cangrejo, no un robot: nada de explosiones): cae, se encoge temblando
--   ('dying_curl'), se queda patas arriba y sus luces se apagan ('dying_out').
--
-- Posición = el centro de su CAPARAZÓN (su caja: el cuerpo que se ve; las patas no cuentan).
-- Todo lo que se dibuja sale de state + deadTimer + x, y + netPackExtra (igual online).
-- Arte: assets/images/bosses/megagloomy/ (el MISMO píxel que el pequeño, a escala 10; tools/ui/
-- make_gloomy_sprites.py); sonidos: tools/sounds/gloomy.py (MEGA).

local Entity      = require 'src/world/entities/Entity'
local Boss        = require 'src/world/entities/Boss'
local Lights      = require 'src/world/Lights'
local Noise       = require 'src/world/Noise'
local SpriteStrip = require 'src/fx/SpriteStrip'
local strike      = require('src/world/entities/types/snowboss').class.strike

local T = TILE_PX
local MS = 10                              -- escala (el pequeño: 4)
local FW, FH = 38, 21                      -- cuadro (px de arte)
local BODY_ROW = 11                        -- fila del centro del CAPARAZÓN en el cuadro (las pinzas van encima)
local BW, BH = 11 * MS, 6 * MS             -- caja: el caparazón
local REST = (FH - BODY_ROW) * MS          -- del centro del caparazón a la superficie en la que se apoya
local F_IDLE, F_CROUCH, F_LEAP, F_SCARED, F_DEAD = 5, 6, 7, 8, 9

local MG = Entity.extend(Boss, {
    debugColor = { 0.6, 0.8, 1 },
    hitbox = { outerW = 1, outerH = 1, innerW = 0.9, innerH = 0.9 },
})
MG.hurtSound   = 'mgloomyHurt'
MG.introLength = 3.2
MG.wantsLevel  = true

-- Orden de los ataques por fase (siempre el mismo: se aprende)
local SEQ = { { 'drop', 'stab' }, { 'drop', 'lunge', 'stab' }, { 'drop', 'stab', 'lunge' } }
local KIND = { drop = 1, stab = 2, lunge = 3 }
-- Ritmo por fase
local SPEED      = { 260, 320, 380 }       -- px/s por el borde de la zona
local STALK_T    = { 2.4, 2.0, 1.6 }       -- s rondando entre ataques
local AIM_T      = { 1.0, 0.85, 0.7 }      -- s apuntando (con la marca puesta) como mínimo
local AIM_MAX    = 2.6                     -- … y como máximo (si tiene que colocarse)
local GROUND_T   = { 2.2, 1.9, 1.6 }       -- s en el suelo tras la caída (hay que alumbrarlo aquí)
local JUMP_T     = 0.7
local LUNGE_T    = 0.75
local CLIMB_T    = 0.5
local DAZZLE_T   = 2.6
local FLINCH_T   = 0.6
local TAUNT_T    = 0.9
local STAB_GAP   = 0.24                    -- s entre pata y pata
local STAB_HIT   = 0.2                     -- s que cada pata hace daño
local STAB_DX    = 1.6 * T                 -- separación de las tres
local STAB_W     = 36                      -- ancho de la zona de daño de cada pata
local CURL_T, OUT_T = 1.5, 1.8             -- muerte
local HEAR_K     = 4                       -- oído: × el radio de cada ruido (oye toda la arena)
local RING_SPD   = 560                     -- px/s a los que crece el aro
local RING_MAX   = 9 * T
local STILL_SPD  = 30
local HIT_AIR    = { 1, 620, -460, 0.25, 0 }
local HIT_SLAM   = { 1, 900, -560, 0.3, 0.3 }
local GLOW       = { 1, 0.77, 0.35 }
local RING       = { 0.55, 0.95, 1 }
local WARN       = { 1, 0.28, 0.2 }

local body, glow, markS, icons, legImg, tipImg
function MG.loadAssets()
    if body then return end
    body  = SpriteStrip.load('assets/images/bosses/megagloomy/body-Sheet.png', FW)
    glow  = SpriteStrip.load('assets/images/bosses/megagloomy/glow-Sheet.png', FW)
    markS = SpriteStrip.load('assets/images/bosses/megagummy/target-Sheet.png', 16)
    icons = SpriteStrip.load('assets/images/gloomy/icons-Sheet.png', 7)
    legImg = love.graphics.newImage('assets/images/bosses/megagloomy/leg.png')
    tipImg = love.graphics.newImage('assets/images/bosses/megagloomy/leg_tip.png')
    for _, i in ipairs({ legImg, tipImg }) do if i.setFilter then i:setFilter('nearest', 'nearest') end end
end
function MG.sizePx() return BW, BH end

function MG:initBoss()
    self.phase = 1
    self.ang = 0
    self.u, self.dir = 0, 1
    self.pings, self.nextPing = {}, 0
    self.pingT, self.stalkT, self.shriekT, self.dimT = 0, 0, 0, 0
    self.tx, self.ty, self.tAge = nil, nil, 99
    self.markX, self.markY, self.lockY, self.kind = 0, 0, 0, 0
    self.hitOnce, self.gloat = false, false
    self.attackN = 0
    self.frame, self.animT = 1, 0
    self.icon, self.iconT = 0, 0
    self.summonKey = 'gl' .. self.col .. ',' .. self.row
end

function MG:bossPhase() return self.phase or 1 end
function MG:enter(st) self.state, self.deadTimer = st, 0 end
function MG:zoneBounds()
    local z = self.zone
    if z then return z.x0, z.x1, z.y0, z.y1 end
    return self.x - 12 * T, self.x + 12 * T, self.y - 8 * T, self.y + 2 * T
end

-- ── El camino por el borde de la zona: pared izquierda ↑, techo →, pared derecha ↓ ───────
function MG:path(u)
    local zx0, zx1, zy0, zy1 = self:zoneBounds()
    local x0, x1, y0, y1 = zx0 + REST, zx1 - REST, zy0 + REST, zy1 - REST
    local h, w = math.max(1, y1 - y0), math.max(1, x1 - x0)
    local total = 2 * h + w
    u = math.max(0, math.min(total, u))
    local C = 90                                           -- px de camino en los que gira en cada esquina
    local function turn(d) return math.max(0, math.min(1, 0.5 + d / (2 * C))) end
    if u <= h then
        return x0, y1 - u, math.pi / 2 + (math.pi / 2) * turn(u - h) * ((u > h - C) and 1 or 0), total
    elseif u <= h + w then
        local v = u - h
        local a = math.pi
        if v < C then a = math.pi / 2 + (math.pi / 2) * turn(v) end
        if v > w - C then a = math.pi + (math.pi / 2) * turn(v - w) end
        return x0 + v, y0, a, total
    end
    local v = u - h - w
    local a = 1.5 * math.pi
    if v < C then a = math.pi + (math.pi / 2) * turn(v) end
    return x1, y0 + v, a, total
end

function MG:nearestU(x, y)
    local _, _, _, total = self:path(0)
    local best, bd = 0, nil
    for u = 0, total, 16 do
        local px, py = self:path(u)
        local d = (px - x) ^ 2 + (py - y) ^ 2
        if not bd or d < bd then best, bd = u, d end
    end
    return best
end

-- Anda por el borde hacia `goal` (px de camino). true si ya está
function MG:walkTo(goal, dt, speed)
    local d = goal - self.u
    if math.abs(d) <= speed * dt then
        self.u = goal
        self.x, self.y, self.ang = self:path(self.u)
        return true
    end
    self.dir = (d > 0) and 1 or -1
    self.u = self.u + self.dir * speed * dt
    self.x, self.y, self.ang = self:path(self.u)
    self:walkAnim(dt)
    return false
end

function MG:floorY(level, x)
    local _, _, zy0, zy1 = self:zoneBounds()
    local _, top = level:landingCross(x, zy0 + T, zy1 + T)
    return top or zy1
end

-- ── Sentidos: el último "!" ──────────────────────────────────────────────────
function MG:hear(level, dt)
    self.tAge = self.tAge + dt
    if not self.heardSeq then self.heardSeq = (level.noises and level.noises.seq) or 0; return end
    local z, seq = Noise.heard(level, self.x, self.y, self.heardSeq, HEAR_K)
    self.heardSeq = seq
    if z then
        local zx0, zx1, zy0, zy1 = self:zoneBounds()
        if z.x > zx0 and z.x < zx1 and z.y > zy0 - T and z.y < zy1 + T then
            self.tx, self.ty, self.tAge = z.x, z.y, 0
        end
    end
end

function MG:lit(level) return (Lights.lit(level, self.x, self.y)) end

-- ── Ecolocalización: el aro detecta a quien se mueve ─────────────────────────
function MG:ping()
    self.nextPing = self.nextPing % 999 + 1
    self.pings[#self.pings + 1] = { id = self.nextPing, x = math.floor(self.x), y = math.floor(self.y), t = 0, hit = {} }
    Sound.play('mgloomyPing')
end

function MG:updatePings(level, dt)
    for i = #self.pings, 1, -1 do
        local p = self.pings[i]
        local r0 = RING_SPD * p.t
        p.t = p.t + dt
        local r1 = RING_SPD * p.t
        if p.hit and level and level.canBreak ~= false then
            for _, pa in ipairs(level.players or {}) do
                if not p.hit[pa] and not pa.dying and pa.alive ~= false then
                    local d = math.sqrt((pa.x - p.x) ^ 2 + (pa.y - p.y) ^ 2)
                    if d >= r0 - 4 and d <= r1 + 4 then
                        p.hit[pa] = true
                        if math.abs(pa.vx or 0) > STILL_SPD or math.abs(pa.vy or 0) > STILL_SPD then
                            Noise.emit(pa.x, pa.y, Noise.R.jump)        -- (¡detectado!: su "!" rojo)
                        end
                    end
                end
            end
        end
        if r1 >= RING_MAX then table.remove(self.pings, i) end
    end
end

-- ── Súbditos (Crabbies lúgubres de reserva) ──────────────────────────────────
function MG:minions(level)
    local out = {}
    for _, e in ipairs(level.liveEntities or {}) do
        if e.summonOf == self.summonKey then out[#out + 1] = e end
    end
    return out
end

function MG:summon(level)
    local zx0, zx1, zy0, zy1 = self:zoneBounds()
    local alive, free = 0, {}
    for _, e in ipairs(self:minions(level)) do
        if e.alive then alive = alive + 1 else free[#free + 1] = e end
    end
    local n = math.min(#free, self.props.summonCount or 2, math.max(0, (self.props.summonMax or 2) - alive))
    for i = 1, n do
        local e = free[i]
        local side = (i % 2 == 1) and -1 or 1
        local h = e.home
        h.x = (side < 0) and (zx0 + e.outerH / 2 + 2) or (zx1 - e.outerH / 2 - 2)
        h.y = zy0 + (zy1 - zy0) * 0.35
        h.facing, h.flipped, h.state, h.vx = -side, false, 'walk', 0
        e:resetToHome()
        e.cnx, e.cny, e.cattached = -side, 0, nil          -- (en la pared: se agarra al empezar)
        e.state, e.deadTimer = 'spawning', 0
        Entity.emitFx('spawn', h.x, h.y)
    end
end

-- ── Golpes ───────────────────────────────────────────────────────────────────
local function overlap(a, b) return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y end

function MG:hitBox(level, box, hit, cx)
    for _, pa in ipairs(level.players or {}) do
        if overlap(pa:getOuterBounds(), box) and strike(pa, hit, (pa.x >= cx) and 1 or -1) then self.gloat = true end
    end
end

function MG:touch(level)
    local ob = self:getOuterBounds()
    self:hitBox(level, { x = ob.x - 14, y = ob.y - 14, w = ob.w + 28, h = ob.h + 28 }, HIT_AIR, self.x)
end

function MG:slam(level)
    Sound.play('mgloomySlam')
    Entity.emitFx('gp_land', self.x, self.y + REST)
    Entity.emitFx('shake_big', self.x, self.y)
    Noise.emit(self.x, self.y, Noise.R.boss, true)         -- (los Crabbies lúgubres lo oyen y vienen; sin marca)
    self.heardSeq = (level.noises and level.noises.seq) or self.heardSeq     -- (su propio golpe no cuenta)
    self:hitBox(level, { x = self.x - BW / 2 - 50, y = self.y - BH / 2, w = BW + 100, h = REST + BH / 2 + 8 }, HIT_SLAM, self.x)
end

-- Las tres patas: x de cada una (función pura de la marca: igual en el cliente)
function MG:stabXs()
    local zx0, zx1 = self:zoneBounds()
    local out = {}
    for i = -1, 1 do out[#out + 1] = math.max(zx0 + 24, math.min(zx1 - 24, self.markX + i * STAB_DX)) end
    return out
end

-- ── Reglas con el jugador (sin efectos: el cliente predice el rebote) ────────
local DEATH = { dying_curl = true, dying_out = true }
function MG:isDying() return DEATH[self.state] == true or Boss.isDying(self) end
function MG:releasesZone() return self.state == 'dying_out' or self.state == 'dead' end
function MG:isVulnerable() return self.state == 'dazzled' and not self.hitOnce end
function MG:isSolidBody()
    return Boss.isSolidBody(self) and (self.state == 'grounded' or self.state == 'dazzled')
end
function MG:interact(pa)
    local st = self.state
    if st ~= 'grounded' and st ~= 'dazzled' and st ~= 'recover' then return nil end   -- (en paredes / aire: touch)
    return Boss.interact(self, pa)
end
function MG:onDamaged(n, kind)
    self.hitOnce = true
    self:enter('recover')
end

-- Muerte de CANGREJO (sin explosiones): se encoge y se apaga
function MG:defeat()
    self.hp, self.inv = 0, 0
    self.vx, self.vy = 0, 0
    self.pings, self.dimT, self.icon, self.kind = {}, 0, 0, 0
    local level = self.levelRef
    if level then level.lightScale = nil end
    for _, e in ipairs(level and self:minions(level) or {}) do
        if e.alive and e.state ~= 'dead' then e.state, e.deadTimer, e.vx, e.vy = 'dead', 0, 0, 0 end
    end
    -- (si estaba en una pared o en el techo, cae al suelo)
    local _, _, _, zy1 = self:zoneBounds()
    local fy = level and self:floorY(level, self.x) or zy1
    self.dieY0, self.dieY1, self.dieA0, self.dieLanded = self.y, fy - REST, self.ang, false
    self:enter('dying_curl')
    Sound.play('mgloomyDazzled', 0.7)
    self:onDefeat()
end

-- ── Saltos (paramétricos: van de un punto suyo a otro) ───────────────────────
function MG:jump(tx, ty, dur, ang1, flat)
    self.jx0, self.jy0, self.jx1, self.jy1 = self.x, self.y, tx, ty
    self.jDur, self.jFlat = dur, flat
    self.jAng0, self.jAng1 = self.ang, ang1
end
function MG:jumpStep(t)
    local k = math.min(1, t / self.jDur)
    self.x = self.jx0 + (self.jx1 - self.jx0) * k
    if self.jFlat then
        self.y = self.jy0 + (self.jy1 - self.jy0) * k
    else
        local arc = math.sin(k * math.pi) * math.min(140, math.abs(self.jx1 - self.jx0) * 0.25 + 40)
        self.y = self.jy0 + (self.jy1 - self.jy0) * (k * k) - arc * (1 - k)
    end
    local da = (self.jAng1 - self.jAng0 + math.pi) % (2 * math.pi) - math.pi
    self.ang = self.jAng0 + da * k
    return k >= 1
end

-- ── Update ───────────────────────────────────────────────────────────────────
function MG:onFightStart()
    self.u = self:nearestU(self.x, self.y)
    self.x, self.y, self.ang = self:path(self.u)
    self.stalkT, self.pingT = 0, 1.2
end

function MG:onIntroStart(level)
    local zx0, zx1 = self:zoneBounds()
    self.u = self:nearestU((zx0 + zx1) / 2, -1e9)             -- en el techo, en el centro
    self.x, self.y, self.ang = self:path(self.u)
    self.introStep = 0
end
function MG:updateIntro(dt, level, t)
    self:updatePings(nil, dt)
    if t >= 0.9 and self.introStep < 1 then self.introStep = 1; self:ping(); self.pings[#self.pings].hit = nil end
    if t >= 1.8 and self.introStep < 2 then
        self.introStep = 2
        Sound.play('mgloomyRoar')
        Entity.emitFx('shake_small', self.x, self.y)
    end
end

function MG:walkAnim(dt)
    self.animT = self.animT + dt
    if self.animT >= 0.09 then
        self.animT = self.animT - 0.09
        self.frame = self.frame % 4 + 1
        -- (un roce de vez en cuando, no cada paso: el silencio es la tensión)
        self.stepN = (self.stepN or 0) + 1
        if self.stepN % 8 == 0 then Sound.play('mgloomyStep') end
    end
end

-- Vuelve a rondar (o se burla, si acaba de darle a alguien)
function MG:afterAttack()
    self.kind = 0
    if self.gloat then self.gloat = false; self:enter('taunt') else self:enter('stalk') end
end

function MG:startAim(level)
    local ph = math.max(1, math.min(3, self.phase))
    local seq = SEQ[ph]
    self.attackN = self.attackN + 1
    local kind = seq[(self.attackN - 1) % #seq + 1]
    local zx0, zx1, zy0, zy1 = self:zoneBounds()
    -- FIJA el objetivo: el último "!" (si no ha oído nada, el centro de la arena)
    local tx = self.tx or (zx0 + zx1) / 2
    local ty = self.ty or (zy1 - 40)
    tx = math.max(zx0 + BW / 2 + 12, math.min(zx1 - BW / 2 - 12, tx))
    self.markX, self.markY = math.floor(tx), math.floor(self:floorY(level, tx))
    self.lockY = math.floor(math.max(zy0 + REST, math.min(zy1 - REST, ty - 10)))
    self.kind = KIND[kind]
    self.aimGoal = nil
    if kind == 'stab' then
        self.aimGoal = self:nearestU(self.markX, -1e9)                       -- en el techo, encima
    elseif kind == 'lunge' then
        local left = self.x < (zx0 + zx1) / 2
        self.aimGoal = self:nearestU(left and -1e9 or 1e9, self.lockY)       -- en su pared, a esa altura
        local _, gy = self:path(self.aimGoal)
        self.lockY = math.floor(gy)                                          -- (la línea, justo por donde va a cruzar)
    end
    self.aimed = self.aimGoal == nil
    self.gloat = false
    self:enter('aim')
    Sound.play('mgloomyListen')
end

function MG:updateBoss(dt, level)
    if self.state == 'dormant' then return end
    self.levelRef = self.levelRef or level
    self.deadTimer = self.deadTimer + dt
    local st, t = self.state, self.deadTimer
    local ph = math.max(1, math.min(3, self.phase))
    local p = self.props

    -- Muerte: cae al suelo encogiéndose y se apaga
    if st == 'dying_curl' then
        local k = math.min(1, t / 0.5)
        self.y = self.dieY0 + (self.dieY1 - self.dieY0) * k * k
        local da = (0 - self.dieA0 + math.pi) % (2 * math.pi) - math.pi
        self.ang = self.dieA0 + da * k
        if k >= 1 and not self.dieLanded then
            self.dieLanded = true
            Sound.play('mgloomySlam', 0.8)
            Entity.emitFx('gp_land', self.x, self.y + REST)
            Entity.emitFx('shake_small', self.x, self.y)
        end
        if t >= CURL_T then self:enter('dying_out') end
        return
    elseif st == 'dying_out' then
        if t >= OUT_T then self.state = 'dead'; self.alive = false end
        return
    end

    self:updatePings(level, dt)
    self:hear(level, dt)
    if (self.iconT or 0) > 0 then
        self.iconT = self.iconT - dt
        if self.iconT <= 0 then self.icon = 0 end
    end
    local frac = self.hp / math.max(1, self.hpMax)
    local want = (frac <= (p.phase3 or 0.33)) and 3 or ((frac <= (p.phase2 or 0.66)) and 2 or 1)
    if want > self.phase then self.phase = want end
    if self.dimT > 0 then
        self.dimT = self.dimT - dt
        if self.dimT <= 0 then level.lightScale = nil end
    end

    if st == 'fight' then self:enter('stalk'); return end

    if st == 'stalk' then
        self.stalkT = self.stalkT + dt
        self.pingT = self.pingT + dt
        if self.phase >= 3 then self.shriekT = self.shriekT + dt end
        if self.pingT >= (p.pingEvery or 2.4) then self.pingT = 0; self:ping() end
        -- ronda hacia el punto del borde que queda encima del último "!"
        local _, _, _, total = self:path(0)
        if self.tx and self.tAge < 8 then
            self:walkTo(self:nearestU(self.tx, self.ty - 4 * T), dt, SPEED[ph])
        else
            self.u = self.u + self.dir * SPEED[ph] * 0.6 * dt
            if self.u <= 0 then self.u, self.dir = 0, 1 elseif self.u >= total then self.u, self.dir = total, -1 end
            self.x, self.y, self.ang = self:path(self.u)
            self:walkAnim(dt)
        end
        if self.phase >= 3 and self.shriekT >= (p.shriekEvery or 13) then
            self.shriekT = 0
            self:enter('shriek')
            Sound.play('mgloomyShriek')
        elseif self.stalkT >= STALK_T[ph] then
            self.stalkT = 0
            self:startAim(level)
        end

    elseif st == 'aim' then
        if self:lit(level) and t > 0.1 then                 -- la luz lo asusta: cancela
            self.icon, self.iconT, self.kind = 3, 1.4, 0
            self.attackN = self.attackN - 1                 -- (repetirá este mismo ataque)
            self:enter('flinch')
            return
        end
        if not self.aimed then self.aimed = self:walkTo(self.aimGoal, dt, SPEED[ph] * 1.6) end
        if (self.aimed and t >= AIM_T[ph]) or t >= AIM_MAX then
            if not self.aimed then                          -- (no llegó: se coloca de un salto)
                self.u = self.aimGoal
                self.x, self.y, self.ang = self:path(self.u)
            end
            local zx0, zx1 = self:zoneBounds()
            if self.kind == KIND.drop then
                self:jump(self.markX, self.markY - REST, JUMP_T, 0)
                self:enter('drop')
                Sound.play('mgloomyDrop')
            elseif self.kind == KIND.stab then
                self.stabDone = 0
                self:enter('stab')
            else
                local left = self.x < (zx0 + zx1) / 2
                self:jump(left and (zx1 - REST) or (zx0 + REST), self.y, LUNGE_T, left and 1.5 * math.pi or math.pi / 2, true)
                self:enter('lunge')
                Sound.play('mgloomyDrop')
            end
        end

    elseif st == 'flinch' then
        if t >= FLINCH_T then self.stalkT = STALK_T[ph] * 0.3; self:enter('stalk') end

    elseif st == 'drop' then
        local done = self:jumpStep(t)
        self:touch(level)
        if done then
            self.ang = 0
            self:slam(level)
            self.hitOnce, self.kind = false, 0
            self:enter('grounded')
        end

    elseif st == 'lunge' then
        local done = self:jumpStep(t)
        self:touch(level)
        if done then
            self.u = self:nearestU(self.x, self.y)
            self.x, self.y, self.ang = self:path(self.u)
            self:afterAttack()
        end

    elseif st == 'stab' then
        -- tres patas, una tras otra; cada una daña STAB_HIT s en su columna
        local xs = self:stabXs()
        for i, x in ipairs(xs) do
            local t0 = (i - 1) * STAB_GAP
            if t >= t0 and self.stabDone < i then
                self.stabDone = i
                Sound.play('mgloomyStep', 0.7)
                Entity.emitFx('shake_small', x, self.markY)
                Entity.emitFx('gp_land', x, self.markY)
            end
            if t >= t0 and t < t0 + STAB_HIT then
                self:hitBox(level, { x = x - STAB_W / 2, y = self.y, w = STAB_W, h = self.markY - self.y }, HIT_AIR, x)
            end
        end
        if t >= 2 * STAB_GAP + STAB_HIT + 0.35 then self:afterAttack() end

    elseif st == 'grounded' then
        if self:lit(level) then
            Sound.play('mgloomyDazzled')
            self:enter('dazzled')
        elseif t >= GROUND_T[ph] then
            self:enter('climb_wind')
        end

    elseif st == 'dazzled' then
        if t >= DAZZLE_T then self:enter('climb_wind') end

    elseif st == 'recover' then
        if t >= 0.5 then self:enter('climb_wind') end

    elseif st == 'climb_wind' then
        if t >= 0.2 then
            local u = self:nearestU(self.x, self.y - 3 * T)
            local tx, ty, ang = self:path(u)
            self.u = u
            self:jump(tx, ty, CLIMB_T, ang)
            self:enter('climb')
            Sound.play('mgloomyDrop', 1.3)
        end

    elseif st == 'climb' then
        if self:jumpStep(t) then
            self.x, self.y, self.ang = self:path(self.u)
            self:afterAttack()
        end

    elseif st == 'taunt' then
        if t >= TAUNT_T then self:enter('stalk') end

    elseif st == 'shriek' then
        if t >= 0.5 and self.dimT <= 0 then
            self.dimT = p.dimTime or 6
            level.lightScale = p.dimScale or 0.5
            self:summon(level)
            Entity.emitFx('shake_roar', self.x, self.y)
        end
        if t >= 1.1 then self:enter('stalk') end
    end
end

-- ── Red ──────────────────────────────────────────────────────────────────────
-- { fase, ángulo·100, cuadro, marca x, y, altura de la embestida, ataque (0 ninguno, 1 caída,
--   2 patas, 3 embestida), luz·100 (0 = normal), icono, nAros, {id, x, y, t·100}… }
local NB = 9
function MG:netPackExtra()
    local out = { self.phase, math.floor(self.ang * 100), self.frame, self.markX, self.markY, self.lockY, self.kind,
                  (self.dimT > 0) and math.floor((self.props.dimScale or 0.5) * 100) or 0, self.icon or 0, #self.pings }
    for _, p in ipairs(self.pings) do
        out[#out + 1] = p.id; out[#out + 1] = p.x; out[#out + 1] = p.y; out[#out + 1] = math.floor(p.t * 100)
    end
    return out
end
function MG:netApplyExtra(a, b, f)
    if type(b[1]) ~= 'number' then return end
    self.phase, self.frame, self.markX, self.markY, self.lockY, self.kind = b[1], b[3], b[4], b[5], b[6], b[7]
    local a0, a1 = (type(a[2]) == 'number' and a[2] or b[2]) / 100, b[2] / 100
    local da = (a1 - a0 + math.pi) % (2 * math.pi) - math.pi
    self.ang = a0 + da * f
    if self.levelRef then self.levelRef.lightScale = (b[8] > 0) and (b[8] / 100) or nil end
    self.dimT = (b[8] > 0) and 1 or 0
    self.icon = b[9] or 0
    self.pings = {}
    for i = 0, (b[NB + 1] or 0) - 1 do
        local j = NB + 2 + i * 4
        self.pings[#self.pings + 1] = { id = b[j], x = b[j + 1], y = b[j + 2], t = (b[j + 3] or 0) / 100 }
    end
end

-- ── Dibujo ───────────────────────────────────────────────────────────────────
function MG:frameNow()
    local st, t = self.state, self.deadTimer or 0
    if st == 'dying_out' or st == 'dead' then return F_DEAD end
    if st == 'dying_curl' then return F_SCARED end
    if st == 'drop' or st == 'lunge' or st == 'climb' then return F_LEAP end
    if st == 'taunt' then return (math.floor(t * 8) % 2 == 0) and F_CROUCH or F_IDLE end      -- flexiones
    if st == 'aim' or st == 'dazzled' or st == 'climb_wind' or st == 'recover' or st == 'stab' then return F_CROUCH end
    if st == 'flinch' or st == 'shriek' then return F_SCARED end
    if st == 'grounded' or st == 'intro' or st == 'ready' or st == 'dormant' then return F_IDLE end
    return math.max(1, math.min(4, self.frame or 1))
end

function MG:drawSheet(sheet, camX, camY, ox, oy)
    local sx, sy = math.floor(self.x - camX + (ox or 0)), math.floor(self.y - camY + (oy or 0))
    local st = self.state
    if st == 'dazzled' or st == 'dying_curl' then sx = sx + math.floor(math.sin(love.timer.getTime() * 50) * 2) end
    love.graphics.draw(sheet.image, sheet.quads[self:frameNow()], sx, sy, self.ang or 0, MS, MS, FW / 2, BODY_ROW)
end

function MG:visible() return self.state ~= 'dormant' and self.state ~= 'dead' end

-- Una pata clavándose: del cuerpo al suelo, en la columna x; k = cuánto ha bajado (0..1)
local function drawLeg(x, y0, y1, k, camX, camY)
    local len = (y1 - y0) * k
    if len < 30 then return end
    local sx = math.floor(x - camX)
    love.graphics.draw(legImg, sx, math.floor(y0 - camY), 0, 4, (len - 24) / 4, 2.5, 0)
    love.graphics.draw(tipImg, sx, math.floor(y0 - camY + len - 24), 0, 4, 4, 2.5, 0)
end

function MG:drawLegs(camX, camY)
    if self.state ~= 'stab' then return end
    local t = self.deadTimer or 0
    for i, x in ipairs(self:stabXs()) do
        local lt = t - (i - 1) * STAB_GAP
        if lt >= 0 then
            local k = math.min(1, lt / 0.07)
            local out = lt - (STAB_HIT + 0.25)
            if out > 0 then k = math.max(0, 1 - out / 0.12) end
            drawLeg(x, self.y, self.markY, k, camX, camY)
        end
    end
end

function MG:render(camX, camY)
    if not self:visible() then return end
    local a = self:ghostAlpha()
    if self.state == 'dying_out' then a = math.max(0, 1 - math.max(0, (self.deadTimer or 0) - (OUT_T - 0.7)) / 0.7) end
    if self:flashRed() then love.graphics.setColor(1, 0.4, 0.4, a) else love.graphics.setColor(1, 1, 1, a) end
    self:drawLegs(camX, camY)
    self:drawSheet(body, camX, camY)
    love.graphics.setColor(1, 1, 1, 1)
end

local function dashV(x, y0, y1, a)
    love.graphics.setColor(WARN[1], WARN[2], WARN[3], a)
    for y = y0, y1 - 1, 28 do love.graphics.rectangle('fill', x - 3, y, 6, math.min(16, y1 - y)) end
end
local function dashH(x0, x1, y, a)
    love.graphics.setColor(WARN[1], WARN[2], WARN[3], a)
    for x = x0, x1 - 1, 28 do love.graphics.rectangle('fill', x, y - 3, math.min(16, x1 - x), 6) end
end

-- Lo que se ve a oscuras: el aro de la ecolocalización, la marca del ataque, sus patas y sus ojos
function MG:renderGlow(camX, camY)
    if not self:visible() then return end
    local now = love.timer.getTime()
    local st, t = self.state, self.deadTimer or 0
    for _, p in ipairs(self.pings or {}) do
        local r = RING_SPD * p.t
        love.graphics.setColor(RING[1], RING[2], RING[3], 0.85 * math.max(0, 1 - r / RING_MAX))
        love.graphics.setLineWidth(4)
        love.graphics.setLineStyle('rough')
        love.graphics.circle('line', math.floor(p.x - camX), math.floor(p.y - camY), 16 + r, 32)
    end
    love.graphics.setLineWidth(1)
    -- la marca del ataque (desde que empieza a apuntar)
    local blink = (math.floor(now * 12) % 2 == 0) and 0.95 or 0.55
    local zx0, zx1, zy0 = self:zoneBounds()
    if (st == 'aim' or st == 'drop') and self.kind == KIND.drop then
        love.graphics.setColor(WARN[1], WARN[2], WARN[3], blink)
        markS:draw((math.floor(now * 12) % 2) + 1, math.floor(self.markX - camX), math.floor(self.markY - camY - 16), 0, 8, 8)
    elseif (st == 'aim' or st == 'stab') and self.kind == KIND.stab then
        for i, x in ipairs(self:stabXs()) do
            if st == 'aim' or t < (i - 1) * STAB_GAP then
                dashV(math.floor(x - camX), math.floor(zy0 - camY), math.floor(self.markY - camY), blink)
            end
        end
    elseif (st == 'aim' or st == 'lunge') and self.kind == KIND.lunge then
        dashH(math.floor(zx0 - camX), math.floor(zx1 - camX), math.floor(self.lockY - camY), blink)
    end
    -- las patas clavándose también se ven a oscuras (tenues)
    love.graphics.setColor(1, 1, 1, 0.55)
    self:drawLegs(camX, camY)
    -- ojos: parpadean al apuntar y al burlarse; se apagan al morir
    local a = 0.95
    if st == 'aim' then a = (math.floor(now * 20) % 2 == 0) and 1 or 0.3
    elseif st == 'taunt' then a = (math.floor(now * 8) % 2 == 0) and 1 or 0.5
    elseif st == 'dazzled' then a = 0.35 + 0.2 * math.sin(now * 30)
    elseif st == 'dying_curl' then a = 0.5 + 0.4 * math.sin(now * 40)
    elseif st == 'dying_out' then a = math.max(0, 0.7 * (1 - t / (OUT_T * 0.7)))
    elseif st == 'intro' then a = math.min(1, t / 0.8) end
    if a > 0.01 then
        love.graphics.setColor(GLOW[1], GLOW[2], GLOW[3], a)
        self:drawSheet(glow, camX, camY)
        love.graphics.setBlendMode('add')
        love.graphics.setColor(GLOW[1], GLOW[2], GLOW[3], 0.22 * a)
        for _, o in ipairs({ { MS, 0 }, { -MS, 0 }, { 0, MS }, { 0, -MS } }) do self:drawSheet(glow, camX, camY, o[1], o[2]) end
        love.graphics.setBlendMode('alpha')
    end
    if (self.icon or 0) > 0 then                          -- ("…": la luz lo ha asustado)
        love.graphics.setColor(0.8, 0.85, 1, 0.95)
        love.graphics.draw(icons.image, icons.quads[self.icon], math.floor(self.x - camX), math.floor(self.y - camY - 80), 0, 6, 6, 3.5, 9)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local G = 'Mega Crabby lúgubre'
return {
    name = 'megagloomy', label = 'Mega Crabby lúgubre', category = 'Jefes',
    description = 'Jefe de los niveles A OSCURAS. Ciego: ATACA EL ÚLTIMO "!" ROJO (el último ruido). Sus aros detectan '
               .. 'a quien se mueve. Antes de atacar marca dónde: diana = cae ahí; tres líneas = clava las patas; línea '
               .. 'horizontal = cruza de pared a pared. Solo se le daña alumbrándolo cuando queda en el suelo tras caer. '
               .. 'Al final grita (oscurece) y llama a Crabbies lúgubres.',
    class = MG,
    boss = { title = 'MEGA CRABBY LÚGUBRE' },
    hide = Boss.HIDE,
    defaults = { points = 60 },
    props = Boss.props({ hp = 8, hpPerPlayer = 3 }, {
        { key='pingEvery', kind='number', label='Ecolocalización cada (s)', group=G, default=2.4, min=0.8, max=8, step=0.1,
          help='Un aro que crece desde él: detecta ("!" rojo) a los jugadores que se mueven cuando les pasa por encima' },
        { key='phase2', kind='number', label='Fase 2 con vida ≤', group=G, default=0.66, min=0.1, max=0.95, step=0.01,
          help='Añade la embestida de pared a pared y va más rápido' },
        { key='phase3', kind='number', label='Fase 3 con vida ≤', group=G, default=0.33, min=0.05, max=0.9, step=0.01,
          help='Grito que acorta las linternas y llama a Crabbies lúgubres' },
        { key='shriekEvery', kind='number', label='Grita cada (s)', group=G, default=13, min=4, max=60, step=0.5 },
        { key='dimTime', kind='number', label='El grito oscurece (s)', group=G, default=6, min=1, max=20, step=0.5 },
        { key='dimScale', kind='number', label='… linternas a (× alcance)', group=G, default=0.5, min=0.2, max=1, step=0.05 },
        { key='summonCount', kind='int', label='Crabbies lúgubres por grito', group=G, default=2, min=0, max=4, step=1 },
        { key='summonMax', kind='int', label='… a la vez (máximo)', group=G, default=2, min=0, max=6, step=1 },
    }),
    editor = { sprite = 'assets/images/bosses/megagloomy/body-Sheet.png', frameW = FW },
    summons = function(pl)
        local out = {}
        for _ = 1, 4 do
            out[#out + 1] = { type = 'gloomy', col = pl.col, row = pl.row, summonKey = 'gl' .. pl.col .. ',' .. pl.row,
                              props = { speed = 80, points = 5, respawn = 0, pauses = false } }
        end
        return out
    end,
}
