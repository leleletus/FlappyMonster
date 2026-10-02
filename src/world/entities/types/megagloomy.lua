-- MEGA CRABBY LÚGUBRE (jefe de los niveles A OSCURAS). No es un Crabby lúgubre grande: casi no
-- se le ve, y la pelea consiste en saber DÓNDE está por lo que hace. Usa el sonido y la oscuridad.
--
--   "No lo veo bien, pero sé dónde está porque voy aprendiendo cómo se comporta."
--
-- CÓMO SE LE LEE (todo se ve a oscuras: renderGlow, encima de la oscuridad):
--   · sus TRES puntos luminosos (los "ojos": siempre);
--   · ECOLOCALIZACIÓN: cada `pingEvery` s suelta un chasquido y un ARO que crece desde donde
--     está (sonido mgloomyPing). En las fases 2 y 3 salen además aros FALSOS desde otros sitios
--     (más tenues y sin ojos): hay que fijarse en cuál es el suyo;
--   · el aviso largo antes de atacar (mgloomyListen) y, de vez en cuando, un roce de sus patas.
--   POCOS SONIDOS (el silencio es la tensión): perder el rastro es un icono "…" sobre él, no un sonido.
--
-- QUÉ HACE:
--   'stalk'    recorre las PAREDES y el TECHO de su zona (un camino por su borde: pared izquierda,
--              techo, pared derecha) hacia donde oyó el último ruido (Noise: pasos, saltos...).
--   'listen'   se para a ESCUCHAR (`LISTEN_T` s: los ojos parpadean, siseo que sube). Al acabar
--              fija el sitio del ÚLTIMO RUIDO que oyó (si el jugador lleva un rato sin hacer
--              ruido, el de antes: falla) y lo MARCA en el suelo. Si en ese rato le da una
--              LINTERNA, pierde el rastro (icono "…") y sigue rondando: alumbrarlo a tiempo
--              cancela el ataque (pero gasta batería).
--   'drop'     se lanza sobre la marca. En el aire, tocarlo = 1 de vida + empujón.
--   'slam'     al caer: GOLPE. Apaga `blindTime` s las linternas a menos de `blindRange` casillas
--              (pa:blindLight) y es un ruido enorme (los Crabbies lúgubres vienen). A quien pille
--              debajo, 1 de vida + empujón fuerte.
--   'grounded' se queda en el suelo recuperándose. Así NO se le puede dañar (rebotas). Pero si le
--              da una linterna aquí → 'dazzled' (DESLUMBRADO, se encoge): el ÚNICO momento en que
--              es vulnerable (pisotón 1 / ground pound 2, un golpe). Para alumbrarlo hay que haber
--              esquivado el golpe LEJOS (si no, la linterna está apagada).
--   'climb'    salta de vuelta a la pared más cercana y sigue.
--   FASE 2 (vida ≤ 66 %): aros falsos y SALTO DE PARED A PARED ('lunge': cruza la arena a la altura
--              del ruido; tocarlo = 1 de vida + empujón) alternado con la caída.
--   FASE 3 (≤ 33 %): GRITO ('shriek', cada `shriekEvery` s): durante `dimTime` s las linternas
--              alcanzan la mitad (level.lightScale) y llama a Crabbies lúgubres (súbditos de
--              reserva, def.summons) que bajan por las paredes.
-- Posición = el centro de su CUERPO (la caja); las patas no cuentan. Todo lo que se dibuja sale de
-- state + deadTimer + x, y + netPackExtra (igual online).
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
local BODY_ROW = 6.5                       -- fila del centro del cuerpo en el cuadro
local BW, BH = 13 * MS, 9 * MS             -- caja del cuerpo
local REST = (FH - BODY_ROW) * MS          -- del centro del cuerpo a la superficie en la que se apoya
local F_IDLE, F_CROUCH, F_LEAP, F_SCARED = 5, 6, 7, 8

local MG = Entity.extend(Boss, {
    debugColor = { 0.6, 0.8, 1 },
    hitbox = { outerW = 1, outerH = 1, innerW = 0.9, innerH = 0.9 },
})
MG.hurtSound   = 'mgloomyHurt'
MG.introLength = 3.2
MG.wantsLevel  = true

-- Ritmo por fase
local SPEED      = { 230, 280, 330 }       -- px/s por el borde de la zona
local STALK_T    = { 3.6, 3.0, 2.4 }       -- s rondando entre ataques
local LISTEN_T   = { 1.0, 0.9, 0.8 }       -- s escuchando (el aviso)
local GROUND_T   = { 2.0, 1.7, 1.4 }       -- s en el suelo tras caer (hay que alumbrarlo aquí)
local MARK_SHOW  = 0.45                    -- s del final de la escucha con la marca ya puesta
local JUMP_T     = 0.72                    -- s de vuelo de la caída
local LUNGE_T    = 0.8                     -- s del salto de pared a pared
local CLIMB_T    = 0.55
local DAZZLE_T   = 2.6                     -- s deslumbrado (vulnerable)
local FLINCH_T   = 0.6
local HEAR_K     = 4                       -- oído: × el radio de cada ruido (oye toda la arena)
local HEARD_FOR  = 2.5                     -- s que "vale" un ruido para apuntar
local PING_LIFE  = 1.0
local PING_R     = 7 * T
local HIT_AIR    = { 1, 620, -460, 0.25, 0 }
local HIT_SLAM   = { 1, 900, -560, 0.3, 0.3 }
local GLOW       = { 1, 0.77, 0.35 }
local RING       = { 0.55, 0.95, 1 }

local body, glow, markS, icons
function MG.loadAssets()
    if body then return end
    body  = SpriteStrip.load('assets/images/bosses/megagloomy/body-Sheet.png', FW)
    glow  = SpriteStrip.load('assets/images/bosses/megagloomy/glow-Sheet.png', FW)
    markS = SpriteStrip.load('assets/images/bosses/megagummy/target-Sheet.png', 16)
    icons = SpriteStrip.load('assets/images/gloomy/icons-Sheet.png', 10)
end
function MG.sizePx() return BW, BH end

function MG:initBoss()
    self.phase = 1
    self.ang = 0
    self.u = 0                                  -- posición en el camino del borde
    self.dir = 1
    self.pings, self.nextPing = {}, 0
    self.pingT, self.stalkT, self.shriekT, self.dimT = 0, 0, 0, 0
    self.heardX, self.heardY, self.heardAge = nil, nil, 99
    self.markX, self.markY = 0, 0
    self.hitOnce = false
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
-- Devuelve x, y (centro del cuerpo) y ángulo de dibujo para la posición u (px)
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

-- Punto del camino más cercano a (x, y)
function MG:nearestU(x, y)
    local _, _, _, total = self:path(0)
    local best, bd = 0, nil
    for u = 0, total, 24 do
        local px, py = self:path(u)
        local d = (px - x) ^ 2 + (py - y) ^ 2
        if not bd or d < bd then best, bd = u, d end
    end
    return best
end

function MG:floorY(level, x)
    local _, _, zy0, zy1 = self:zoneBounds()
    local _, top = level:landingCross(x, zy0 + T, zy1 + T)
    return top or zy1
end

-- ── Sentidos ─────────────────────────────────────────────────────────────────
function MG:hear(level, dt)
    self.heardAge = self.heardAge + dt
    if not self.heardSeq then self.heardSeq = (level.noises and level.noises.seq) or 0; return end
    local z, seq = Noise.heard(level, self.x, self.y, self.heardSeq, HEAR_K)
    self.heardSeq = seq
    if z then
        local zx0, zx1, zy0, zy1 = self:zoneBounds()
        if z.x > zx0 and z.x < zx1 and z.y > zy0 - T and z.y < zy1 + T then
            self.heardX, self.heardY, self.heardAge = z.x, z.y, 0
        end
    end
end

function MG:lit(level)
    return (Lights.lit(level, self.x, self.y))
end

-- ── Ecolocalización ──────────────────────────────────────────────────────────
function MG:ping(level)
    self.nextPing = self.nextPing % 999 + 1
    self.pings[#self.pings + 1] = { id = self.nextPing, x = math.floor(self.x), y = math.floor(self.y), t = 0, fake = 0 }
    if self.phase >= 2 then                                -- aros falsos: desde otros puntos del borde
        local _, _, _, total = self:path(0)
        for _ = 1, self.phase - 1 do
            local fx, fy = self:path(math.random() * total)
            self.nextPing = self.nextPing % 999 + 1
            self.pings[#self.pings + 1] = { id = self.nextPing, x = math.floor(fx), y = math.floor(fy), t = 0, fake = 1 }
        end
    end
    Sound.play('mgloomyPing')
end

function MG:updatePings(dt)
    for i = #self.pings, 1, -1 do
        local p = self.pings[i]
        p.t = p.t + dt
        if p.t >= PING_LIFE then table.remove(self.pings, i) end
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

function MG:touch(level, hit)
    local ob = self:getOuterBounds()
    local box = { x = ob.x - 10, y = ob.y - 10, w = ob.w + 20, h = ob.h + 20 }
    for _, pa in ipairs(level.players or {}) do
        if overlap(pa:getOuterBounds(), box) then strike(pa, hit, (pa.x >= self.x) and 1 or -1) end
    end
end

function MG:slam(level)
    local p = self.props
    Sound.play('mgloomySlam')
    Entity.emitFx('gp_land', self.x, self.y + REST)
    Entity.emitFx('shake_big', self.x, self.y)
    Noise.emit(self.x, self.y, Noise.R.boss)               -- (los Crabbies lúgubres lo oyen y vienen)
    self.heardSeq = (level.noises and level.noises.seq) or self.heardSeq     -- (su propio golpe no cuenta)
    -- debajo / pegado: golpe
    local box = { x = self.x - BW / 2 - 40, y = self.y - BH / 2, w = BW + 80, h = REST + BH / 2 + 8 }
    for _, pa in ipairs(level.players or {}) do
        if overlap(pa:getOuterBounds(), box) then strike(pa, HIT_SLAM, (pa.x >= self.x) and 1 or -1) end
        -- el golpe apaga las linternas cercanas
        local d = math.sqrt((pa.x - self.x) ^ 2 + (pa.y - self.y) ^ 2)
        if d <= (p.blindRange or 4) * T and not pa.dying then
            Boss.withPlayer(pa, function() pa:blindLight(p.blindTime or 2.5) end)
        end
    end
    self:ping(level)
end

-- ── Reglas con el jugador (sin efectos: el cliente predice el rebote) ────────
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
function MG:onDefeat()
    self.pings = {}
    self.dimT = 0
    local level = self.levelRef
    if level then level.lightScale = nil end
    for _, e in ipairs(level and self:minions(level) or {}) do
        if e.alive and e.state ~= 'dead' then e.state, e.deadTimer, e.vx, e.vy = 'dead', 0, 0, 0 end
    end
end

-- ── Saltos (balísticos, sin chocar: van de un punto suyo a otro) ─────────────
function MG:jump(tx, ty, dur, nextState, ang1)
    self.jx0, self.jy0, self.jx1, self.jy1 = self.x, self.y, tx, ty
    self.jDur, self.jNext = dur, nextState
    self.jAng0, self.jAng1 = self.ang, ang1
end
function MG:jumpStep(t)
    local k = math.min(1, t / self.jDur)
    local arc = math.sin(k * math.pi) * math.min(140, math.abs(self.jx1 - self.jx0) * 0.25 + 40)
    self.x = self.jx0 + (self.jx1 - self.jx0) * k
    self.y = self.jy0 + (self.jy1 - self.jy0) * (k * k) - arc * (1 - k)
    local da = (self.jAng1 - self.jAng0 + math.pi) % (2 * math.pi) - math.pi
    self.ang = self.jAng0 + da * k
    return k >= 1
end

-- ── Update ───────────────────────────────────────────────────────────────────
function MG:onFightStart()
    self.u = self:nearestU(self.x, self.y)
    self.x, self.y, self.ang = self:path(self.u)
    self.stalkT, self.pingT = 0, 0
end

function MG:onIntroStart(level)
    local zx0, zx1 = self:zoneBounds()
    self.u = self:nearestU((zx0 + zx1) / 2, -1e9)             -- en el techo, en el centro
    self.x, self.y, self.ang = self:path(self.u)
    self.introStep = 0
end
function MG:updateIntro(dt, level, t)
    self:updatePings(dt)
    if t >= 0.9 and self.introStep < 1 then self.introStep = 1; self:ping(level) end
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

function MG:updateBoss(dt, level)
    if self.state == 'dormant' then return end
    self.levelRef = self.levelRef or level
    self.deadTimer = self.deadTimer + dt
    local st, t = self.state, self.deadTimer
    local ph = math.max(1, math.min(3, self.phase))
    local p = self.props
    self:updatePings(dt)
    self:hear(level, dt)
    if (self.iconT or 0) > 0 then
        self.iconT = self.iconT - dt
        if self.iconT <= 0 then self.icon = 0 end
    end
    -- fases
    local frac = self.hp / math.max(1, self.hpMax)
    local want = (frac <= (p.phase3 or 0.33)) and 3 or ((frac <= (p.phase2 or 0.66)) and 2 or 1)
    if want > self.phase then self.phase = want end
    -- el grito que oscurece se pasa solo
    if self.dimT > 0 then
        self.dimT = self.dimT - dt
        if self.dimT <= 0 then level.lightScale = nil end
    end

    if st == 'fight' then self:enter('stalk'); return end

    if st == 'stalk' then
        self.stalkT = self.stalkT + dt
        self.pingT = self.pingT + dt
        if self.phase >= 3 then self.shriekT = self.shriekT + dt end
        if self.pingT >= (p.pingEvery or 2.2) then self.pingT = 0; self:ping(level) end
        -- hacia el punto del borde más cercano al último ruido (si no, sigue su ronda)
        local _, _, _, total = self:path(0)
        local goal
        if self.heardX and self.heardAge < 6 then goal = self:nearestU(self.heardX, self.heardY - 4 * T) end
        if goal and math.abs(goal - self.u) > 30 then self.dir = (goal > self.u) and 1 or -1
        elseif goal then self.dir = 0 end
        if self.dir == 0 and not goal then self.dir = 1 end
        self.u = self.u + self.dir * SPEED[ph] * dt
        if self.u <= 0 then self.u, self.dir = 0, 1 elseif self.u >= total then self.u, self.dir = total, -1 end
        self.x, self.y, self.ang = self:path(self.u)
        if self.dir ~= 0 then self:walkAnim(dt) end
        if self.phase >= 3 and self.shriekT >= (p.shriekEvery or 13) then
            self.shriekT = 0
            self:enter('shriek')
            Sound.play('mgloomyShriek')
        elseif self.stalkT >= STALK_T[ph] then
            self.stalkT = 0
            self:enter('listen')
            Sound.play('mgloomyListen')
        end

    elseif st == 'listen' then
        if self:lit(level) and t > 0.1 then                 -- la luz lo interrumpe
            self.icon, self.iconT = 3, 1.4                  -- ("…" sobre él, sin sonido)
            self:enter('flinch')
            return
        end
        local len = LISTEN_T[ph]
        if t >= len - MARK_SHOW and not self.locked then
            -- FIJA el sitio: el último ruido reciente; si no hay, el de antes (o donde esté él)
            self.locked = true
            local zx0, zx1 = self:zoneBounds()
            local tx = self.heardX or self.x
            tx = math.max(zx0 + BW / 2 + 8, math.min(zx1 - BW / 2 - 8, tx))
            self.markX, self.markY = math.floor(tx), math.floor(self:floorY(level, tx))
            self.lockY = self.heardY
        end
        if t >= len then
            self.locked = nil
            self.attackN = self.attackN + 1
            local zx0, zx1, zy0, zy1 = self:zoneBounds()
            if self.phase >= 2 and self.attackN % 2 == 0 then
                -- hasta la pared del otro lado del ruido, a su altura (cruza por donde sonó)
                local left = self.x < (self.heardX or (zx0 + zx1) / 2)
                local ty = math.max(zy0 + REST, math.min(zy1 - REST, (self.lockY or self.y) - 20))
                self:jump(left and (zx1 - REST) or (zx0 + REST), ty, LUNGE_T, 'stalk', left and 1.5 * math.pi or math.pi / 2)
                self:enter('lunge')
            else
                self:jump(self.markX, self.markY - REST, JUMP_T, 'slam', 0)
                self:enter('drop')
            end
            Sound.play('mgloomyDrop')
        end

    elseif st == 'flinch' then
        if t >= FLINCH_T then self.stalkT = STALK_T[ph] * 0.4; self:enter('stalk') end

    elseif st == 'drop' or st == 'lunge' then
        local done = self:jumpStep(t)
        self:touch(level, HIT_AIR)
        if done then
            if st == 'drop' then
                self.ang = 0
                self:slam(level)
                self.hitOnce = false
                self:enter('grounded')
            else
                self.u = self:nearestU(self.x, self.y)
                self.x, self.y, self.ang = self:path(self.u)
                self:enter('stalk')
            end
        end

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
            self:jump(tx, ty, CLIMB_T, 'stalk', ang)
            self:enter('climb')
            Sound.play('mgloomyDrop', 1.3)
        end

    elseif st == 'climb' then
        if self:jumpStep(t) then
            self.x, self.y, self.ang = self:path(self.u)
            self:enter('stalk')
        end

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
-- { fase, ángulo·100, cuadro, marca x, y, luz·100 (0 = normal), icono, nAros, {id, x, y, t·100, falso}… }
local NB = 7
function MG:netPackExtra()
    local out = { self.phase, math.floor(self.ang * 100), self.frame, self.markX, self.markY,
                  (self.dimT > 0) and math.floor((self.props.dimScale or 0.5) * 100) or 0, self.icon or 0, #self.pings }
    for _, p in ipairs(self.pings) do
        out[#out + 1] = p.id; out[#out + 1] = p.x; out[#out + 1] = p.y
        out[#out + 1] = math.floor(p.t * 100); out[#out + 1] = p.fake
    end
    return out
end
function MG:netApplyExtra(a, b, f)
    if type(b[1]) ~= 'number' then return end
    self.phase, self.frame, self.markX, self.markY = b[1], b[3], b[4], b[5]
    local a0, a1 = (type(a[2]) == 'number' and a[2] or b[2]) / 100, b[2] / 100
    local da = (a1 - a0 + math.pi) % (2 * math.pi) - math.pi
    self.ang = a0 + da * f
    if self.levelRef then self.levelRef.lightScale = (b[6] > 0) and (b[6] / 100) or nil end
    self.dimT = (b[6] > 0) and 1 or 0
    self.icon = b[7] or 0
    self.pings = {}
    for i = 0, (b[NB + 1] or 0) - 1 do
        local j = NB + 2 + i * 5
        self.pings[#self.pings + 1] = { id = b[j], x = b[j + 1], y = b[j + 2], t = (b[j + 3] or 0) / 100, fake = b[j + 4] }
    end
end

-- ── Dibujo ───────────────────────────────────────────────────────────────────
function MG:frameNow()
    local st = self.state
    if st == 'drop' or st == 'lunge' or st == 'climb' then return F_LEAP end
    if st == 'listen' or st == 'dazzled' or st == 'climb_wind' or st == 'recover' then return F_CROUCH end
    if st == 'flinch' or st == 'shriek' or self:isDying() then return F_SCARED end
    if st == 'grounded' or st == 'intro' or st == 'ready' or st == 'dormant' then return F_IDLE end
    return math.max(1, math.min(4, self.frame or 1))
end

function MG:drawSheet(sheet, camX, camY, ox, oy)
    local sx, sy = math.floor(self.x - camX + (ox or 0)), math.floor(self.y - camY + (oy or 0))
    local st = self.state
    if st == 'dazzled' then sx = sx + math.floor(math.sin(love.timer.getTime() * 50) * 2) end
    love.graphics.draw(sheet.image, sheet.quads[self:frameNow()], sx, sy, self.ang or 0, MS, MS, FW / 2, BODY_ROW)
end

function MG:visible()
    return self.state ~= 'dormant' and self.state ~= 'dead'
end

function MG:render(camX, camY)
    if not self:visible() then return end
    local a = self:ghostAlpha()
    if self:flashRed() then love.graphics.setColor(1, 0.4, 0.4, a) else love.graphics.setColor(1, 1, 1, a) end
    self:drawSheet(body, camX, camY)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Lo que se ve a oscuras: aros de la ecolocalización, la marca de la caída y sus ojos
function MG:renderGlow(camX, camY)
    if not self:visible() then return end
    local now = love.timer.getTime()
    local st, t = self.state, self.deadTimer or 0
    for _, p in ipairs(self.pings or {}) do
        local k = p.t / PING_LIFE
        local a = (1 - k) * ((p.fake == 1) and 0.45 or 0.85)
        love.graphics.setColor(RING[1], RING[2], RING[3], a)
        love.graphics.setLineWidth(4)
        love.graphics.setLineStyle('rough')
        love.graphics.circle('line', math.floor(p.x - camX), math.floor(p.y - camY), 20 + PING_R * k, 28)
    end
    love.graphics.setLineWidth(1)
    -- marca en el suelo: donde va a caer
    local ph = math.max(1, math.min(3, self.phase or 1))
    if (st == 'listen' and t >= LISTEN_T[ph] - MARK_SHOW) or st == 'drop' then
        local fr = (math.floor(now * 12) % 2) + 1
        love.graphics.setColor(1, 0.4, 0.3, 0.9)
        markS:draw(fr, math.floor(self.markX - camX), math.floor(self.markY - camY - 16), 0, 8, 8)
    end
    -- ojos
    local a = 0.95
    if st == 'listen' then a = (math.floor(now * 20) % 2 == 0) and 1 or 0.3
    elseif st == 'dazzled' then a = 0.35 + 0.2 * math.sin(now * 30)
    elseif st == 'intro' then a = math.min(1, t / 0.8) end
    love.graphics.setColor(GLOW[1], GLOW[2], GLOW[3], a)
    self:drawSheet(glow, camX, camY)
    love.graphics.setBlendMode('add')
    love.graphics.setColor(GLOW[1], GLOW[2], GLOW[3], 0.22 * a)
    for _, o in ipairs({ { MS, 0 }, { -MS, 0 }, { 0, MS }, { 0, -MS } }) do self:drawSheet(glow, camX, camY, o[1], o[2]) end
    love.graphics.setBlendMode('alpha')
    if (self.icon or 0) > 0 then                          -- ("…": la luz le hizo perder el rastro)
        love.graphics.setColor(0.8, 0.85, 1, 0.95)
        local nx, ny = math.sin(self.ang or 0), -math.cos(self.ang or 0)         -- (hacia el aire, esté donde esté)
        love.graphics.draw(icons.image, icons.quads[self.icon], math.floor(self.x - camX + nx * 120),
                           math.floor(self.y - camY + ny * 120), 0, 7, 7, 5, 5.5)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local G = 'Mega Crabby lúgubre'
return {
    name = 'megagloomy', label = 'Mega Crabby lúgubre', category = 'Jefes',
    description = 'Jefe de los niveles A OSCURAS: recorre paredes y techo, se le sitúa por sus aros de ecolocalización '
               .. 'y sus ojos. Escucha, MARCA dónde sonó y se lanza: su golpe apaga las linternas cercanas. Solo es '
               .. 'vulnerable DESLUMBRADO (alumbrarlo mientras está en el suelo). Luego salta de pared a pared, '
               .. 'suelta aros falsos y oscurece la arena y llama a Crabbies lúgubres.',
    class = MG,
    boss = { title = 'MEGA CRABBY LÚGUBRE' },
    hide = Boss.HIDE,
    defaults = { points = 60 },
    props = Boss.props({ hp = 9, hpPerPlayer = 3 }, {
        { key='pingEvery', kind='number', label='Ecolocalización cada (s)', group=G, default=2.2, min=0.8, max=8, step=0.1,
          help='Un chasquido y un aro que crece desde donde está: así se sabe dónde anda' },
        { key='blindRange', kind='number', label='Su golpe apaga linternas a (casillas)', group=G, default=4, min=0, max=12, step=0.5 },
        { key='blindTime', kind='number', label='… durante (s)', group=G, default=2.5, min=0, max=10, step=0.1 },
        { key='phase2', kind='number', label='Fase 2 con vida ≤', group=G, default=0.66, min=0.1, max=0.95, step=0.01,
          help='Aros falsos y salto de pared a pared' },
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
