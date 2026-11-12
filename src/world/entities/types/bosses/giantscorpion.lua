-- Jefe secreto ESCORPIÓN TRIPLE AGUIJÓN (types/bosses/giantscorpion.lua): idea del usuario (2026-10-31), diseño C
-- «Obsidiana» (docs/bosses/giantscorpion.md). Es el Escorpión del volcán (types/enemies/scorpion.lua) en grande: su
-- astilla le partió la cola en tres.
--   · LA MATRACA es su firma: 3 clics de madera JUSTO mientras las colas se enrollan o se desenrollan (0,2 s), un destello
--     por clic. Los clics no mienten: enrollarse anuncia el golpe; desenrollarse, los aguijones.
--   · ENROLLADAS ('join_coil' → 'join_wind' → 'join_hit' → 'stuck'): una sola cola gruesa, una marca grande en el suelo y
--     UN golpe fuerte que se queda CLAVADO: la ventana. Pisotón 1 / ground pound 2, en el cuerpo o en la cola clavada. Al
--     arrancarla ('pull') se desenrolla con su matraca.
--   · SEPARADAS ('split_coil' → 'split_aim' → 'sting'): una marca por cola alrededor del jugador y cada una golpea por
--     turno, en un orden que cambia. En su última fase, dos a la vez y luego la tercera (2 + 1).
--   · PINZA ('claw_wind' → 'claw' → 'hold'): abre la pinza y la lanza a donde estabas. Si te pilla, te ATRAPA:
--     machacar botones para salir, como la Planta carnívora (PlayerGulp); otro jugador lo libera golpeándolo.
--   · SE MUEVE POR TODA LA ARENA (el usuario): corre, salta a las plataformas donde estés y de vuelta al suelo ('leap_wind' →
--     'leap' → 'land'), da saltos largos si estás lejos, y trepa las paredes ('to_wall' → 'climb'): desde ahí lanza sus aguijones y
--     luego se deja caer ('wall_drop'). Apunta a donde VAS a estar, con las marcas más repartidas.
--   · Su cuerpo se ATRAVIESA, como el del Lúgubre, y no hace daño (el usuario): solo golpean las colas al lanzarlas y atrapa
--     la pinza al lanzarla. Fuera de su ventana, caerle encima tampoco hace nada.
-- Las colas y los brazos son piezas animadas al momento (base/SegmentChain: solo dibujo); lo que golpea sale del estado,
-- deadTimer y las marcas (netPackExtra): online se ve y se decide igual.

local Entity = require 'src/world/entities/base/Entity'
local Boss   = require 'src/world/entities/base/Boss'
local Snow   = require('src/world/entities/types/bosses/snowboss').class
local BossFx = require 'src/fx/BossFx'
local Kit    = require 'src/world/entities/base/ScorpionKit'
local Chain  = require 'src/world/entities/base/SegmentChain'
local Anim   = require 'src/fx/Anim'

local GS = Entity.extend(Boss, {
    ATTACKS  = { join_coil = true, join_wind = true, join_hit = true, split_coil = true, split_aim = true, sting = true,
                 claw_wind = true, claw = true, hold = true },
    OPENINGS = { stuck = true },
    debugColor = { 0.55, 0.45, 0.9 },
    hitbox = { outerW = 0.8, outerH = 0.58, innerW = 0.7, innerH = 0.46 },
})
GS.hurtSound   = 'megaHurt'
GS.introLength = 3.2
GS.wantsLevel  = true
GS.animId      = 'bosses/giantscorpion'
GS.WEAR = { { image = 'assets/images/bosses/giantscorpion/wear_clasp.png', anchor = 'tail', ax = 4.5, ay = 4.5 } }

GS.move, GS.physics, GS.friction, GS.groundDecel = Snow.move, Snow.physics, Snow.friction, Snow.groundDecel
GS.zoneBounds, GS.jumpTo = Snow.zoneBounds, Snow.jumpTo
local strike, overlap = Boss.strike, Boss.overlap

local T  = TILE_PX
local MS = 7                                    -- (0.5.118, el usuario: a ×10 no dejaba sitio para esquivar ni para moverse)
local FW, FH = Kit.FW, Kit.FH
local N, GAP = 19, 3.4 * MS
local REACH = 520                               -- px desde la base de las colas hasta donde llega un aguijón
local STRETCH = 1.4                             -- (clavando, las colas se estiran lo justo para llegar a su marca)

-- Ritmo por fase (1, 2, 3)
local REST_T    = { 1.1, 0.85, 0.6 }
local WALK_V    = { 200, 240, 290 }
local LEAP_WIND = { 0.35, 0.28, 0.22 }
local LEAP_UP   = 2.5                           -- casillas por encima de lo más alto del salto
local LAND_T    = 0.18
local LEAP_CD   = 2.2                           -- s sin volver a saltar
local LONG_D    = 8 * T                         -- más lejos que esto: salto largo
local LONG_MAX  = 11 * T                        -- lo más lejos que salta de una vez
local CLIMB_CD  = { 14, 22 }                    -- s entre dos subidas a la pared
local RUN_V     = { 340, 390, 440 }             -- corriendo hacia la pared
local RUN_MAX   = 4.0
local CLIMB_V   = 420
local CLIMB_UP  = { 3, 6 }                      -- casillas que sube
local LEAD      = { 0.6, 0.8, 1.0 }             -- cuánto se adelanta a tu movimiento al apuntar (1 = donde estarás si sigues igual)
local SPREAD    = { { 90, 170 }, { 100, 210 }, { 110, 260 } }    -- px: las marcas de los otros dos aguijones, a los lados
local COIL_T    = 0.21                          -- s enrollándose o desenrollándose: lo que dura la matraca
local CLICKS    = { 0, 0.09, 0.18 }             -- (make_scorpion.py RATTLE_F, tools/sounds/scorpion.py GAP)
local CLICK_LEN = 0.06
local JOIN_WIND = { 0.75, 0.6, 0.45 }           -- s de pausa con la marca grande antes del golpe
local SWING_T   = 0.13                          -- s que tarda un aguijón en llegar a su marca
local PULL_T    = 0.62                          -- (el sonido scorpionPull dura eso)
local AIM_T     = { 0.55, 0.45, 0.35 }
local STING_GAP = { 0.42, 0.33, 0.26 }
local AFTER_STING = 0.45
local BACK_T    = 0.4
local CLAW_WIND = { 0.65, 0.5, 0.42 }
local CLAW_T    = 0.2
local CLAW_BACK = 0.4
local CLAW_CD   = 4.5                           -- s sin volver a usar la pinza
local CLAW_RANGE = 4.5 * T                      -- desde su centro: te tiene a tiro
local CLAW_MAX   = 5 * T                        -- hasta dónde llega la mano
local CLAW_BOX   = 36
local HOLD_LIFT, HOLD_FWD = 40, 48              -- px: lo levanta y lo sujeta por delante de la pinza
local STING_BOX, HEAVY_BOX = 34, 72             -- medio ancho de lo que golpea
local BOX_H     = 56
-- s clavada (vulnerable), según la dificultad; tras el primer golpe se levanta en Boss.GETUP_T, como todos
local STUCK_T   = { easy = 4.4, normal = 3.6, hard = 2.9, extreme = 2.5, xtra = 2.3 }

-- Golpes a los jugadores: { vida, vx, vy, s sin control, s aturdido }
local HIT_STING = { 1, 420, -460, 0.2, 0 }
local HIT_HEAVY = { 2, 620, -560, 0.3, 0 }

-- Muerte
local OUT_D    = 2.2
local FLEE_MIN = 1.6
local FLEE_V   = 300
local DEATH = { dying_out = true, dying_flee = true }

-- Órdenes en que golpean las colas (el jugador los aprende por el destello)
local ORDERS = { { 1, 2, 3 }, { 3, 2, 1 }, { 2, 3, 1 }, { 1, 3, 2 }, { 2, 1, 3 }, { 3, 1, 2 } }

function GS.sizePx() return FW * MS, FH * MS end
local function rand(a, b) return a + math.random() * (b - a) end

function GS:feetY() return self.y + self.outerH / 2 end
function GS:ph() return self.phase or 1 end
function GS:bossPhase() return self:ph() end
function GS:angryPhase() return self:ph() == 3 end
-- Un punto del cuerpo (px de arte desde los pies: ax hacia delante, ay hacia abajo) en el mundo; en la pared, girado.
-- Pura (la usan simulación y dibujo)
function GS:pt(ax, ay)
    local f = self.facing or 1
    if self.wall then
        local s = (self.wall < 0) and 1 or -1                       -- (sin / cos de ±90°: los pies, hacia la pared)
        return self.x + self.wall * self.outerH / 2 - s * ay * MS, self.y + s * ax * MS * f
    end
    return self.x + ax * MS * f, self:feetY() + ay * MS
end
function GS:tailX() local x = self:pt(Kit.TAIL[1], Kit.TAIL[2]); return x end
function GS:tailY() local _, y = self:pt(Kit.TAIL[1], Kit.TAIL[2]); return y end
function GS:restHandX() local x = self:pt(Kit.HAND[1], Kit.HAND[2]); return x end
function GS:restHandY() local _, y = self:pt(Kit.HAND[1], Kit.HAND[2]); return y end
-- La física de siempre, salvo agarrado a la pared: ahí no cae
function GS:phys(level, dt)
    if self.wall then self.vx, self.vy = 0, 0; return end
    return self:physics(level, dt)
end

function GS:initBoss()
    self.y = self.row * T - self.outerH / 2
    self.vx, self.vy, self.onGround = 0, 0, true
    self.facing = -1
    self.phase = 1
    self.clawCd, self.leapCd, self.climbCd, self.wall = 0, 0, 0, nil
    self.marks = { { x = self.x, y = self:feetY() }, { x = self.x, y = self:feetY() }, { x = self.x, y = self:feetY() } }
    self.order, self.two, self.gapT, self.uncoilOnly = 1, false, STING_GAP[1], false
    self.handX, self.handY, self.held, self.last = self:restHandX(), self:restHandY(), nil, nil
end

function GS:onFightStart(n) self:enter('fight') end
function GS:rollStart(r) self.clawCd, self.climbCd = r(0, CLAW_CD), r(CLIMB_CD[1] * 0.4, CLIMB_CD[2] * 0.7); self.last = r(0, 1) < 0.5 and 'join' or 'split' end

function GS:isActive() return Boss.isActive(self) and not DEATH[self.state] end
function GS:isDying() return DEATH[self.state] == true or Boss.isDying(self) end
-- (clavada: la ventana; con alguien atrapado: otro jugador lo libera golpeándolo)
function GS:isVulnerable() return self:isActive() and (self.state == 'stuck' or self.state == 'hold') end
function GS:releasesZone() return self.state == 'dying_flee' or self.state == 'dead' end
function GS:isSolidBody() return false end
function GS:isObstacle() return false end
function GS:canBeKnocked() return false end

-- ── La cola clavada también se pisa (pura: la usa el cliente para predecir) ──
local line = {}
function GS:overTail(pob)
    local mk = self.marks[1]
    Kit.strikeLine(line, 10, self:tailX(), self:tailY(), MS, self.facing or 1, mk.x, mk.y)
    local foot = pob.y + pob.h
    for j = 2, 10 do
        local p = line[j]
        if pob.x < p.x + 34 and pob.x + pob.w > p.x - 34 and foot > p.y - 34 and foot < p.y + 44 then return true end
    end
    return false
end

function GS:interact(pa)
    if not self:isVulnerable() then return nil end                 -- (se atraviesa: encima tampoco pasa nada)
    local r, a, b = Boss.interact(self, pa)
    if r or self.state ~= 'stuck' or not self:isActive() then return r, a, b end
    if self.ghost and self.inv > 0 then return nil end
    if pa.vy <= 0 and pa.gpPhase ~= 'fall' then return nil end
    if not self:overTail(pa:getOuterBounds()) then return nil end
    local bvy = -math.abs(ADV_JUMP_VEL) * self.BOUNCE
    if self.inv > 0 then return 'bounce', bvy, (pa.x >= self.x) and 1 or -1 end
    return (pa.gpPhase == 'fall') and 'pound' or 'stomp', bvy, self.props.points or 0
end

-- ── Golpes a jugadores ────────────────────────────────────────────────────────
function GS:floorBelow(level, x, y)
    local _, _, _, zy1 = self:zoneBounds()
    for yy = y, zy1 + 4 * T, 8 do
        if level:collisionAt(x, yy, true) then return math.floor(yy / T) * T end
    end
    return zy1
end

-- Una marca al alcance de la cola y dentro de la zona, sobre lo que haya debajo
function GS:markAt(level, x, y)
    local zx0, zx1 = self:zoneBounds()
    local bx = self:tailX()
    x = math.max(zx0 + 20, math.min(zx1 - 20, math.max(bx - REACH, math.min(bx + REACH, x))))
    return math.floor(x), self:floorBelow(level, x, y)
end

function GS:hitBox(level, x, y, halfW, hit)
    local box = { x = x - halfW, y = y - BOX_H, w = halfW * 2, h = BOX_H + 8 }
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false and not pa:isInvulnerable() and overlap(box, pa:getOuterBounds()) then
            strike(pa, hit, (pa.x >= x) and 1 or -1, require('src/player/DamageSource').of(self, 'spike'))
        end
    end
end

-- Cuándo llega el aguijón de la cola i a su marca (s desde que empieza 'sting'). Pura: también la dibuja el cliente
function GS:stingAt(i)
    local o = ORDERS[self.order or 1]
    local pos = (o[1] == i) and 1 or ((o[2] == i) and 2 or 3)
    local g = self.gapT or STING_GAP[1]
    local start = self.two and ((pos <= 2) and 0 or g * 1.6) or (pos - 1) * g
    return start + SWING_T
end
function GS:stingEnd()
    local m = 0
    for i = 1, 3 do m = math.max(m, self:stingAt(i)) end
    return m + AFTER_STING
end

-- ── Elegir ────────────────────────────────────────────────────────────────────
function GS:rest()
    if self.wall then return self:enter('wall_drop') end
    self.restLen = REST_T[self:ph()] * rand(0.85, 1.15)
    self:enter('rest')
end

function GS:startJoin(level, pa)
    self.last = 'join'
    self.facing = (pa.x >= self.x) and 1 or -1
    self:enter('join_coil')
    self.vx = 0
    Sound.play('scorpionRattleJoin')
end

-- Salta a (x, y): a una plataforma, de vuelta al suelo o lejos
function GS:startLeap(x, y)
    self.leapCd = LEAP_CD
    self.leapX, self.leapY = x, y
    self.vx = 0
    self.facing = (x >= self.x) and 1 or -1
    self:enter('leap_wind')
    Sound.play('scorpionSkitter', 0.7, 0.7)
end

-- Se mueve antes de atacar? true si ha empezado a moverse
function GS:chooseMove(level, pa, d)
    if not self.onGround then return false end
    local zx0, zx1 = self:zoneBounds()
    local hw = self.outerW / 2 + 8
    if self.climbCd <= 0 and math.random() < 0.3 + 0.1 * self:ph() then
        self.climbCd = rand(CLIMB_CD[1], CLIMB_CD[2])
        self.toWall = (self.x - zx0 < zx1 - self.x) and -1 or 1
        self.facing = self.toWall
        self:enter('to_wall')
        return true
    end
    if self.leapCd > 0 then return false end
    local ob = pa:getOuterBounds()
    local pFeet = ob.y + ob.h
    local dy = self:feetY() - pFeet
    -- a otra altura y de pie sobre algo: a su plataforma, o de vuelta al suelo
    if pa.onGround and math.abs(dy) >= 1.5 * T then
        self:startLeap(math.max(zx0 + hw, math.min(zx1 - hw, pa.x)), pFeet)
        return true
    end
    -- lejos: salto largo, sin caerle justo encima
    if d > LONG_D and math.random() < 0.7 then
        local dir = (pa.x >= self.x) and 1 or -1
        local x = self.x + dir * math.min(LONG_MAX, d - 3 * T)
        self:startLeap(math.max(zx0 + hw, math.min(zx1 - hw, x)), self:floorBelow(level, x, self:feetY() - 8))
        return true
    end
    -- encima de él: a veces se aparta de un salto para poder usar la cola
    if d < 2.5 * T and math.random() < 0.3 then
        local dir = (self.x - zx0 < zx1 - self.x) and 1 or -1
        local x = self.x + dir * 6 * T
        self:startLeap(math.max(zx0 + hw, math.min(zx1 - hw, x)), self:floorBelow(level, x, self:feetY() - 8))
        return true
    end
    return false
end

-- Dónde estará el jugador dentro de `secs` si sigue igual (según la fase, más o menos adelantado)
function GS:predictX(pa, secs)
    return pa.x + (pa.vx or 0) * secs * LEAD[self:ph()]
end

function GS:startSplit(uncoilOnly)
    self.uncoilOnly = uncoilOnly == true
    self:enter('split_coil')
    self.vx = 0
    Sound.play('scorpionRattleSplit')
end

function GS:choose(level)
    local pa = self:nearestPlayer(level)
    if not pa then return self:rest() end
    local d = math.abs(pa.x - self.x)
    self.facing = (pa.x >= self.x) and 1 or -1
    if self:chooseMove(level, pa, d) then return end
    if self.clawCd <= 0 and d < CLAW_RANGE and pa.canBeSwallowed and pa:canBeSwallowed() then
        self.clawCd = CLAW_CD
        self.vx = 0
        self.lockX, self.lockY = pa.x, pa.y
        self:enter('claw_wind')
        Sound.play('scorpionHiss', 1.2, 0.5)
        return
    end
    -- (se alternan, con una de cada tres repitiendo: que no se pueda contar con el orden)
    local nextOne = (self.last == 'join') and 'split' or 'join'
    if math.random() < 0.33 then nextOne = self.last end
    if nextOne == 'join' then return self:startJoin(level, pa) end
    self.last = 'split'
    self:startSplit(false)
end

-- ── Golpes y derrota ──────────────────────────────────────────────────────────
function GS:onDamaged(n, kind)
    if self:isDying() then return end
    local frac = self.hp / self.hpMax
    local ph = (frac <= (self.props.rageAt or 1 / 3)) and 3 or ((frac <= (self.props.angerAt or 2 / 3)) and 2 or 1)
    if ph > self:ph() then
        self.phase = ph
        Entity.emitFx('shake_small', self.x, self.y)
        Sound.play('scorpionHiss', 0.85, 0.9)
    end
    if self.state == 'hold' then self:letGo() end
end

-- Atrapa al jugador y lo levanta: la pinza le coge por delante y se le VE (el usuario), asomando de sus dedos
function GS:grab(pa)
    local f = self.facing or 1
    self.handY = self.handY - HOLD_LIFT
    return pa:swallow(self.handX + f * HOLD_FWD - f * (pa.w / 2 + 1), self.handY, f, 0, 1)
end

function GS:letGo()
    self.held = nil                                    -- (el atrapado ve que ya no lo tiene y sale: PlayerGulp)
    if self.state == 'hold' then self:enter('claw_back') end
end

function GS:defeat()
    self.hp, self.inv, self.ghost = 0, 0, false
    if self.wall then
        self.x = self.x + self.wall * (self.outerH - self.outerW) / 2
        self.wall, self.vy, self.onGround = nil, 0, false
    end
    self:letGo()
    self.vx = 0
    self:enter('dying_out')
    Sound.play('scorpionHiss', 0.7, 1)
    Sound.play('stunned')
    self:onDefeat()
end

-- ── Update ────────────────────────────────────────────────────────────────────
function GS:updateBoss(dt, level)
    if self.state == 'dormant' then return end
    self.levelRef = self.levelRef or level
    self.deadTimer = self.deadTimer + dt
    if self.clawCd > 0 then self.clawCd = math.max(0, self.clawCd - dt) end
    if self.leapCd > 0 then self.leapCd = math.max(0, self.leapCd - dt) end
    if self.climbCd > 0 then self.climbCd = math.max(0, self.climbCd - dt) end
    local st, t, ph = self.state, self.deadTimer, self:ph()

    if st == 'fight' then self:rest(); return end

    if st == 'rest' then
        local pa = self:nearestPlayer(level)
        -- (se acerca hasta tener al jugador a tiro de cola; de cerca se queda: pelea con las colas, no con el cuerpo)
        if pa then
            local dx = pa.x - self.x
            if math.abs(dx) > 8 then self.facing = (dx > 0) and 1 or -1 end
            local far = math.abs(pa.x - self:tailX()) > REACH * 0.8 or math.abs(dx) > 5 * T
            self.vx = far and self.facing * WALK_V[ph] or 0
        end
        self:phys(level, dt)
        if self.vx ~= 0 and math.floor(t / 0.42) ~= math.floor((t - dt) / 0.42) then Sound.play('scorpionSkitter', 0.8, 0.45) end
        if t >= (self.restLen or REST_T[ph]) and self.onGround and self:mayAttack(level) then self:choose(level) end

    elseif st == 'join_coil' then
        self.vx = 0; self:phys(level, dt)
        if t >= COIL_T then
            local pa = self:nearestPlayer(level)
            local px = pa and self:predictX(pa, JOIN_WIND[ph] + SWING_T) or self.x
            local mx, my = self:markAt(level, px, (pa and pa.y or self.y))
            self.marks[1].x, self.marks[1].y = mx, my
            self:enter('join_wind')
        end

    elseif st == 'join_wind' then
        self.vx = 0; self:phys(level, dt)
        if t >= JOIN_WIND[ph] then self:enter('join_hit') end

    elseif st == 'join_hit' then
        self.vx = 0; self:phys(level, dt)
        if t >= SWING_T then
            local mk = self.marks[1]
            Sound.play('scorpionStrike')
            Entity.emitFx('shake_small', mk.x, mk.y)
            Entity.emitFx('gp_land', mk.x, mk.y)
            self:hitBox(level, mk.x, mk.y, HEAVY_BOX, HIT_HEAVY)
            self.stuckLen = STUCK_T[level.difficulty or ''] or STUCK_T.normal
            self:enter('stuck')
        end

    elseif st == 'stuck' then
        self.vx = 0; self:phys(level, dt)
        if t >= self:downTime(self.stuckLen or STUCK_T.normal) then
            self:enter('pull')
            Sound.play('scorpionPull')
        end

    elseif st == 'pull' then
        self.vx = 0; self:phys(level, dt)
        if t >= PULL_T then self:startSplit(true) end

    elseif st == 'split_coil' then
        self.vx = 0; self:phys(level, dt)
        if t >= COIL_T then
            if self.uncoilOnly then self:rest(); return end
            local pa = self:nearestPlayer(level)
            local py = pa and pa.y or self.y
            -- la primera en golpear, a donde estará el jugador; las otras dos, a los lados de donde estará entonces
            self.order = math.random(1, #ORDERS)
            self.two = ph == 3 and math.random() < 0.5
            self.gapT = STING_GAP[ph]
            local o = ORDERS[self.order]
            local side = (math.random() < 0.5) and 1 or -1
            local sp = SPREAD[ph]
            for pos, off in ipairs({ 0, side * rand(sp[1], sp[2]), -side * rand(sp[1], sp[2]) }) do
                local i = o[pos]
                local px = pa and self:predictX(pa, AIM_T[ph] + self:stingAt(i)) or self.x
                local mk = self.marks[i]
                mk.x, mk.y = self:markAt(level, px + off, py)
            end
            self:enter('split_aim')
        end

    elseif st == 'split_aim' then
        self.vx = 0; self:phys(level, dt)
        if t >= AIM_T[ph] then self:enter('sting') end

    elseif st == 'sting' then
        self.vx = 0; self:phys(level, dt)
        for i = 1, 3 do
            local at = self:stingAt(i)
            if t >= at and t - dt < at then
                local mk = self.marks[i]
                Sound.play('scorpionSting')
                Entity.emitFx('gp_land', mk.x, mk.y)
                self:hitBox(level, mk.x, mk.y, STING_BOX, HIT_STING)
            end
        end
        if t >= self:stingEnd() then self:enter('split_back') end

    elseif st == 'split_back' then
        self.vx = 0; self:phys(level, dt)
        if t >= BACK_T then self:rest() end

    elseif st == 'claw_wind' then
        self.vx = 0; self:phys(level, dt)
        local pa = self:nearestPlayer(level)
        if pa and t < CLAW_WIND[ph] * 0.7 then self.lockX, self.lockY = pa.x, pa.y end   -- (el último tramo, fijo: se esquiva)
        if t >= CLAW_WIND[ph] then
            local hx, hy = self:restHandX(), self:restHandY()
            local dx, dy = (self.lockX or hx) - hx, (self.lockY or hy) - hy
            local d = math.sqrt(dx * dx + dy * dy)
            if d > CLAW_MAX then dx, dy = dx / d * CLAW_MAX, dy / d * CLAW_MAX end
            self.handX, self.handY = math.floor(hx + dx), math.floor(hy + dy)
            self:enter('claw')
        end

    elseif st == 'claw' then
        self.vx = 0; self:phys(level, dt)
        if t >= CLAW_T then
            Sound.play('scorpionSnap')
            local box = { x = self.handX - CLAW_BOX, y = self.handY - CLAW_BOX, w = CLAW_BOX * 2, h = CLAW_BOX * 2 }
            for _, pa in ipairs(level.players or {}) do
                if pa.canBeSwallowed and pa:canBeSwallowed() and overlap(box, pa:getOuterBounds())
                   and self:grab(pa) then
                    pa.gulpBy = self
                    self.held = pa
                    self:enter('hold')
                    Sound.play('scorpionHiss', 1, 0.7)
                    return
                end
            end
            self:enter('claw_back')
        end

    elseif st == 'hold' then
        self.vx = 0; self:phys(level, dt)
        local pa = self.held
        local here = false                             -- (sigue en la partida: online se puede ir)
        for _, q in ipairs(level.players or {}) do if q == pa then here = true end end
        if not pa or not here or pa.gulpBy ~= self or not pa.gulped or pa.dying or pa.alive == false then
            if pa and pa.gulpBy == self then pa.gulpBy = nil end
            self:letGo()
        end

    elseif st == 'claw_back' then
        self.vx = 0; self:phys(level, dt)
        if t >= CLAW_BACK then self:rest() end

    elseif st == 'leap_wind' then
        self.vx = 0; self:phys(level, dt)
        if t >= LEAP_WIND[ph] then
            self.passY = self.leapY
            self:jumpTo(self.leapX, self.leapY, LEAP_UP)
            self:enter('leap')
            Sound.play('scorpionSkitter', 1.3, 0.8)
        end

    elseif st == 'leap' then
        self:phys(level, dt)
        if self.onGround and self.vy >= 0 and t > 0.1 then
            self.passY, self.vx = nil, 0
            Sound.play('gpImpact', 1, 0.6)
            Entity.emitFx('gp_land', self.x, self:feetY())
            self:enter('land')
        end

    elseif st == 'land' then
        self.vx = 0; self:phys(level, dt)
        if t >= LAND_T then self:rest() end

    elseif st == 'to_wall' then
        self.facing = self.toWall
        self.vx = self.toWall * RUN_V[ph]
        local hit = self:phys(level, dt)
        if math.floor(t / 0.3) ~= math.floor((t - dt) / 0.3) then Sound.play('scorpionSkitter', 1, 0.5) end
        if hit == 'wall' then
            local zx0, zx1 = self:zoneBounds()
            self.wall = self.toWall
            self.facing = self.wall
            self.vx, self.vy, self.onGround = 0, 0, false
            self.x = ((self.wall < 0) and zx0 or zx1) - self.wall * self.outerH / 2
            local _, _, zy0 = self:zoneBounds()
            self.climbTo = math.max(zy0 + self.outerW / 2 + 8, self.y - rand(CLIMB_UP[1], CLIMB_UP[2]) * T)
            self:enter('climb')
        elseif t >= RUN_MAX then self:rest() end

    elseif st == 'climb' then
        self.y = self.y - CLIMB_V * dt
        if math.floor(t / 0.22) ~= math.floor((t - dt) / 0.22) then Sound.play('scorpionSkitter', 1.1, 0.5) end
        if self.y <= self.climbTo then
            self.y = self.climbTo
            self.last = 'split'
            self:startSplit(false)
        end

    elseif st == 'wall_drop' then
        if self.wall then
            -- se suelta: del sitio de la pared al de andar, sin saltos
            self.x = self.x + self.wall * (self.outerH - self.outerW) / 2
            self.wall, self.vy, self.onGround = nil, 0, false
            local zx0, zx1 = self:zoneBounds()
            self.facing = ((self.x - zx0) < (zx1 - self.x)) and 1 or -1
        end
        self:phys(level, dt)
        if self.onGround and t > 0.1 then
            Sound.play('gpImpact', 1, 0.6)
            Entity.emitFx('gp_land', self.x, self:feetY())
            self:enter('land')
        end

    elseif st == 'dying_out' then
        self.vx = 0; self:phys(level, dt)
        if t >= OUT_D and self.onGround then
            self.fleeDir = self:fleeSide(level)
            self.facing, self.fleeing = self.fleeDir, true
            self.fleeX0 = self.x
            self:enter('dying_flee')
        end

    elseif st == 'dying_flee' then
        -- se va corriendo y atraviesa la pared, aún grande, sin el broche (pura función del tiempo)
        self.x = self.fleeX0 + self.fleeDir * FLEE_V * t
        if self:fleeOver(level, dt, t, FLEE_MIN) then self.state, self.alive = 'dead', false end
    end
end

-- ── Entrada: quieto, abre las colas con su matraca y sisea ───────────────────
local OPEN_AT, HISS_AT = 1.0, 1.7
function GS:introFocus()
    local zx0, zx1, zy0, zy1 = self:zoneBounds()
    return (zx0 + zx1) / 2, (zy0 + zy1) / 2
end
function GS:onIntroStart(level, players)
    self.introStep = 0
    self.levelRef = self.levelRef or level
end
function GS:updateIntro(dt, level, t)
    self.x, self.y = self.home.x, self.home.y
    if t >= 0.3 and self.introStep < 1 then self.introStep = 1; Sound.play('scorpionSkitter', 0.8, 0.7) end
    if t >= OPEN_AT and self.introStep < 2 then self.introStep = 2; Sound.play('scorpionRattleSplit') end
    if t >= HISS_AT and self.introStep < 3 then
        self.introStep = 3
        Sound.play('scorpionHiss')
        Entity.emitFx('shake_small', self.x, self.y)
    end
end

-- ── Red ───────────────────────────────────────────────────────────────────────
function GS:netPackExtra()
    local m = self.marks
    return { self:ph(), m[1].x, m[1].y, m[2].x, m[2].y, m[3].x, m[3].y, self.order or 1, self.two and 1 or 0,
             math.floor((self.gapT or 0) * 100), self.uncoilOnly and 1 or 0, math.floor(self.handX or 0), math.floor(self.handY or 0),
             math.floor(self.lockX or 0), math.floor(self.lockY or 0), (self.fleeDir or 1), self.wall or 0 }
end

function GS:netApplyExtra(a, b, f)
    if type(b[1]) ~= 'number' then return end
    self.phase = b[1]
    local m = self.marks
    m[1].x, m[1].y, m[2].x, m[2].y, m[3].x, m[3].y = b[2], b[3], b[4], b[5], b[6], b[7]
    self.order, self.two, self.gapT, self.uncoilOnly = b[8], b[9] == 1, b[10] / 100, b[11] == 1
    self.handX, self.handY, self.lockX, self.lockY, self.fleeDir = b[12], b[13], b[14], b[15], b[16]
    self.wall = (b[17] ~= 0) and b[17] or nil
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
local parts, fx
function GS.loadAssets()
    parts = parts or Anim.load('bosses/giantscorpion_parts')
    fx = fx or Anim.load('bosses/giantscorpion_fx')
end

local BRAIDED = { join_coil = true, join_wind = true, join_hit = true, stuck = true, pull = true }
local FLASH_COIL = { join_coil = true, split_coil = true }
local items = {}

-- ¿Brilla el aguijón de la cola i? (un destello por clic; o justo antes de lanzarse)
function GS:flashing(i, t)
    if FLASH_COIL[self.state] then return t >= CLICKS[i] and t < CLICKS[i] + CLICK_LEN end
    if self.state == 'sting' then
        local at = self:stingAt(i) - SWING_T
        return t >= at - 0.08 and t < at + 0.03
    end
    return false
end

-- Mueve las 3 colas hacia lo que toca en este estado (solo dibujo)
function GS:moveTails(dt, bx, by, f, st, t, now)
    self.tails = self.tails or { Chain.new(N, GAP), Chain.new(N, GAP), Chain.new(N, GAP) }
    local ct, cd = Kit.CALM_K, Kit.CALM_DAMP
    if self.wall then f = -self.wall end                 -- (agarrado a la pared: las colas salen hacia la arena)
    for i, c in ipairs(self.tails) do
        local b2x, b2y = bx + (i - 2) * MS, by
        if BRAIDED[st] then
            local tipX, tipY, up, amp = bx + 19 * MS * f, by - 37 * MS, 1, 1.5
            local kk, dd = Kit.COIL_K, Kit.COIL_DAMP
            if st == 'join_wind' then tipX, tipY, up = bx - 4 * MS * f, by - 30 * MS, 1.2; kk, dd = ct, cd
            elseif st == 'join_hit' or st == 'stuck' then
                f = (self.marks[1].x >= bx) and 1 or -1      -- (la curva, hacia donde esté la marca: también a su espalda)
                tipX, tipY, up, amp = self.marks[1].x - Kit.TIP_D * MS * f, self.marks[1].y - Kit.TIP_D * MS, 0.45, 1
                kk, dd = Kit.FAST_K, Kit.FAST_DAMP
            elseif st == 'pull' then
                tipX, tipY, up, amp = self.marks[1].x - Kit.TIP_D * MS * f, self.marks[1].y - Kit.TIP_D * MS, 0.45, 1
                kk, dd = Kit.FAST_K, Kit.FAST_DAMP
                if t >= PULL_T * 0.55 then tipX, tipY, up, kk, dd = bx + 19 * MS * f, by - 37 * MS, 1, Kit.COIL_K, Kit.COIL_DAMP; amp = 1.5 end
            end
            c:advance(dt, kk, dd, (st == 'join_hit' or st == 'stuck' or st == 'pull') and STRETCH or nil, Kit.braid, b2x, b2y, MS, f, i, now, tipX, tipY, up, amp)
        elseif st == 'sting' and t >= self:stingAt(i) - SWING_T then
            local mk = self.marks[i]
            c:advance(dt, Kit.FAST_K, Kit.FAST_DAMP, STRETCH, Kit.strike, b2x, b2y, MS, (mk.x >= b2x) and 1 or -1, mk.x, mk.y)
        elseif DEATH[st] then
            -- (derrotado: las colas caen, lacias, hacia atrás)
            c:advance(dt, ct, cd, nil, Kit.strike, b2x, b2y, MS, f, bx - (12 + i * 11) * MS * f, self:feetY() + 1)
        elseif st == 'split_coil' then
            c:advance(dt, Kit.COIL_K, Kit.COIL_DAMP, nil, Kit.fan, b2x, b2y, MS, f, i, now, 1.1)
        elseif st == 'intro' or st == 'dormant' then
            -- (entrada: recogidas hasta que se abren con la matraca)
            local open = (self.deadTimer or 0) >= OPEN_AT
            c:advance(dt, open and Kit.COIL_K or ct, open and Kit.COIL_DAMP or cd, nil, Kit.fan, b2x, b2y, MS, f, i, now, open and 1 or 0.3)
        else
            c:advance(dt, ct, cd, nil, Kit.fan, b2x, b2y, MS, f, i, now, (st == 'split_aim' or st == 'sting') and 1.1 or 1)
        end
    end
end

function GS:drawTails(camX, camY, st, t, alpha, now)
    if BRAIDED[st] then
        local n = 0
        for i, c in ipairs(self.tails) do
            for j = 1, N - 1 do
                n = n + 1
                local it = items[n] or {}
                items[n] = it
                it.z, it.j, it.i = math.cos(Kit.braidPhase(j, N, i, now)), j, i
            end
        end
        for k = n + 1, #items do items[k] = nil end
        table.sort(items, function(a, b)
            if a.z ~= b.z then return a.z < b.z end
            if a.j ~= b.j then return a.j < b.j end
            return a.i < b.i
        end)
        for _, it in ipairs(items) do
            Kit.drawSeg(parts, self.tails[it.i], it.j, MS, camX, camY, 0.72 + 0.28 * (it.z + 1) / 2, alpha)
        end
        for i, c in ipairs(self.tails) do Kit.drawStinger(parts, c, 'stinger' .. i, self:flashing(i, t), MS, camX, camY, alpha) end
    else
        Kit.drawTail(parts, self.tails[1], 'stinger1', self:flashing(1, t), MS, camX, camY, 0.62, alpha)
        Kit.drawTail(parts, self.tails[3], 'stinger3', self:flashing(3, t), MS, camX, camY, 0.8, alpha)
        Kit.drawTail(parts, self.tails[2], 'stinger2', self:flashing(2, t), MS, camX, camY, nil, alpha)
    end
end

-- La posición de la mano de delante (pura): reposo, encogida avisando, lanzada, sujetando, volviendo
function GS:handPos(st, t, now)
    local hx, hy = self:restHandX(), self:restHandY()
    local f = self.facing or 1
    if st == 'claw_wind' then
        return hx - f * 4 * MS, hy - 3 * MS, true                                        -- (encogida y abierta: el aviso)
    elseif st == 'claw' then
        local u = math.min(1, t / CLAW_T)
        return hx + (self.handX - hx) * u, hy + (self.handY - hy) * u, u < 0.8
    elseif st == 'hold' then
        return self.handX, self.handY, false
    elseif st == 'claw_back' then
        local u = math.min(1, t / CLAW_BACK)
        return self.handX + (hx - self.handX) * u, self.handY + (hy - self.handY) * u, true
    end
    local moving = (st == 'rest' and self.vx ~= 0) or st == 'to_wall' or st == 'climb' or st == 'dying_flee'
    local sx, sy = Kit.swing(now, 1, moving, MS)
    return hx + sx, hy + sy, true
end

function GS:render(camX, camY)
    if self.state == 'dormant' and not EDITOR_VIEW then return end
    if self.state == 'dead' then return end
    self.loadAssets()
    local st, t = self.state, self.deadTimer or 0
    local now = love.timer.getTime()
    local set = self:anims()
    local f = self.facing or 1
    local alpha = self:ghostAlpha()
    if st == 'dying_flee' then alpha = alpha * self:fleeAlpha(t) end
    -- Lo del suelo, antes que nada: marcas y grietas
    self:drawMarks(camX, camY, st, t, now, alpha)
    local fr
    local running = (st == 'rest' and self.vx ~= 0) or st == 'to_wall' or st == 'climb' or st == 'dying_flee'
    if running then fr = set:frameAt('walk', now * 1.8)
    elseif st == 'join_wind' or st == 'claw_wind' or st == 'split_aim' or st == 'join_coil' or st == 'leap_wind' or st == 'land' then fr = set:frameAt('windup', 0)
    elseif st == 'stuck' or st == 'pull' or st == 'dying_out' then fr = set:frameAt('hurt', 0)
    else fr = set:frameAt('idle', 0) end
    local sink = Kit.SINK
    local function P(ax, ay) return self:pt(ax, ay + sink) end
    local gap = set:footGap(fr)
    local bodyX, bodyY = self:pt(0, gap + sink)
    local bx, by = P(Kit.TAIL[1], Kit.TAIL[2])
    local dt = math.min(0.1, now - (self.tailT or now))
    self.tailT = now
    self:moveTails(dt, bx, by, f, st, t, now)
    local rot = self.wall and ((self.wall < 0) and math.pi / 2 or -math.pi / 2) or 0
    if st == 'stuck' or st == 'dying_out' then
        local sx, sy = P(0, -16)
        BossFx.stars(math.floor(sx - camX), math.floor(sy - camY), 8 * MS, 1.2 * MS, 5, alpha, 'back')
    end
    -- TODO EL CUERPO parpadea al recibir un golpe: colas, segmentos, pinzas y broche también (el usuario)
    local r, g, b = 1, 1, 1
    if self:flashRed() then r, g, b = 1, 0.35, 0.35 end
    Kit.tint(r, g, b)
    -- Pinza de atrás, cuerpo, pinza de delante y ENCIMA las colas y el broche (el usuario)
    local hx, hy, opened = self:handPos(st, t, now)
    local nearX, nearY = P(Kit.NEAR[1], Kit.NEAR[2])
    local farX, farY = P(Kit.FAR[1], Kit.FAR[2])
    local fhx, fhy = P(Kit.HAND_FAR[1], Kit.HAND_FAR[2])
    local moving = running
    local sx, sy = Kit.swing(now, 0, moving, MS)
    fhx, fhy = fhx + sx, fhy + sy
    local ang = math.atan2(hy - nearY, hx - nearX)
    local fang = (f > 0) and -0.35 or math.pi + 0.35
    if self.wall then fang = math.atan2(fhy - farY, fhx - farX)
    elseif st == 'rest' or st == 'dying_out' or st == 'dying_flee' or st == 'stuck' or st == 'pull' or st == 'leap' or st == 'to_wall' then
        ang = (f > 0) and 0 or math.pi
    end
    Kit.drawArm(parts, farX, farY, fhx, fhy, fang, st ~= 'hold', MS, camX, camY, 0.65, alpha)
    love.graphics.setColor(r, g, b, alpha)
    set:drawFrame(fr, math.floor(bodyX - camX), math.floor(bodyY - camY), rot, MS * f, MS, 0.5, 1)
    Kit.drawArm(parts, nearX, nearY, hx, hy, ang, opened, MS, camX, camY, nil, alpha)
    self:drawTails(camX, camY, st, t, alpha, now)
    love.graphics.setColor(r, g, b, alpha)
    self:drawWear('tail', math.floor(bx - camX), math.floor(by - camY), MS)
    Kit.tint()
    love.graphics.setColor(1, 1, 1, 1)
end

function GS:drawMarks(camX, camY, st, t, now, alpha)
    local blink = (math.floor(now * 12) % 2 == 0) and 1 or 0.6
    local function drawFx(name, mk, tt, a)
        love.graphics.setColor(1, 1, 1, a * alpha)
        fx:drawFrame(fx:frameAt(name, tt), math.floor(mk.x - camX), math.floor(mk.y - camY) + 1, 0, 4, 4, 0.5, 1)
    end
    if st == 'join_wind' or st == 'join_hit' then
        love.graphics.setColor(1, 1, 1, blink * alpha)
        fx:drawFrame(fx:frameAt('mark_heavy', 0), math.floor(self.marks[1].x - camX), math.floor(self.marks[1].y - camY) + 1, 0, 8, 4, 0.5, 1)
    elseif st == 'stuck' or st == 'pull' then
        drawFx('crack', self.marks[1], 0, 1)
        if st == 'stuck' and t < 0.4 then drawFx('impact', self.marks[1], t, 1) end
    elseif st == 'split_aim' then
        for i = 1, 3 do drawFx('mark' .. i, self.marks[i], 0, blink) end
    elseif st == 'sting' then
        for i = 1, 3 do
            local at = self:stingAt(i)
            if t < at then drawFx('mark' .. i, self.marks[i], 0, blink)
            else
                drawFx('crack', self.marks[i], 0, 1)
                if t - at < 0.3 then drawFx('impact', self.marks[i], t - at, 1) end
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function GS:debugBoxes()
    local out = {}
    local st = self.state
    local function box(mk, hw, kind) out[#out + 1] = { x = mk.x - hw, y = mk.y - BOX_H, w = hw * 2, h = BOX_H + 8, kind = kind } end
    if st == 'join_wind' or st == 'join_hit' then box(self.marks[1], HEAVY_BOX, 'hazard')
    elseif st == 'split_aim' or st == 'sting' then for i = 1, 3 do box(self.marks[i], STING_BOX, 'hazard') end
    elseif st == 'claw' then
        out[#out + 1] = { x = self.handX - CLAW_BOX, y = self.handY - CLAW_BOX, w = CLAW_BOX * 2, h = CLAW_BOX * 2, kind = 'hazard' }
    end
    return out
end

local G = 'Escorpión Triple Aguijón'
return {
    name = 'giantscorpion', label = 'Escorpión Triple Aguijón', category = 'Jefes',
    description = 'Jefe secreto del volcán. Tres clics de matraca: se enrollan (un golpe fuerte que se queda CLAVADO, la '
               .. 'ventana) o se separan (tres aguijones por turno). Su pinza atrapa: machacar botones para salir.',
    class = GS,
    boss = { title = 'ESCORPIÓN TRIPLE AGUIJÓN' },
    hide = Boss.HIDE,
    defaults = { points = 30 },
    props = Boss.props({ hp = 12, hpPerPlayer = 4 }, {
        Boss.WEAR_PROP,
        { key = 'angerAt', kind = 'number', label = 'Fase 2 con (fracción de vida)', group = G, default = 2 / 3,
          min = 0.2, max = 0.95, step = 0.05 },
        { key = 'rageAt', kind = 'number', label = 'Fase 3 con (fracción de vida)', group = G, default = 1 / 3,
          min = 0.1, max = 0.9, step = 0.05 },
    }),
    editor = { sprite = 'assets/images/bosses/giantscorpion/body-Sheet.png', frameW = FW },
}
