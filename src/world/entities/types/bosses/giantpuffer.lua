-- Jefe PEZ GLOBO GIGANTE (types/giantpuffer.lua): el jefe de la COSTA (sustituye al Mega Crabby, que pasa a ser jefe
-- secreto: docs/bosses/new-bosses-plan.md). Es el pez globo normal en grande: su MISMA hoja 16x16 (diseño A "Arena",
-- tools/art/enemies/make_pufferfish.py) a escala 13 (MS), con sus mismas animaciones (assets/anim/enemies/pufferfish.json).
--
-- La pelea va con la MAREA: la arena es una cala con una inundación conectada a la zona (`flood`, control 'boss'),
-- que sube y baja sola durante la pelea (un ciclo puro del tiempo: igual online). Al bajar, el agua ARRASTRA hacia un
-- lado (la RESACA: prop `undertow` de la inundación, Floods.currentAt) y se ve espuma corriendo hacia allí.
-- El pez hace lo que le deja el agua EN SU SITIO:
--   · MAREA ALTA (con agua): NADA hacia el jugador (contacto = 1 de vida y empujón) y ataca, siempre avisando:
--       (cerca se hincha, lejos dispara; nunca se hincha dos veces seguidas)
--       1. SE HINCHA cerca de ti ('puff_warn' tiembla a medio hinchar → 'puffed' con las púas fuera: tocarlo = 1 de
--          vida y empujón fuerte → 'deflate').
--       2. RÁFAGA DE PÚAS ('spines_warn' parpadea a medio hinchar → 'spines'): tres ráfagas en corro, a golpe de
--          3+3+2 (como "Resaca", su música); cada púa 1 de vida y un empujón; se paran en la pared.
--   · MAREA BAJA (sin agua): VARADO. Va hacia el jugador a COLETAZOS ('flop_wind' → 'flop': un salto hacia ti, en el
--     aire con las púas fuera = 1 de vida) y al caer se queda BOQUEANDO ('gasp', estrellitas): es lo ÚNICO vulnerable
--     → pisotón 1 / ground pound 2, un golpe por ocasión (después se hincha de golpe y se aparta: 'hurt_puff').
--     Encima de él, si no está boqueando, solo se rebota.
--   · ENFADADO (por debajo de `rageAt`): ráfagas de más púas, se hincha más rato, coletazos más seguidos, nada más
--     rápido; símbolos de enfado sobre la cabeza.
-- Entrada: cae del cielo en la cala (la marea empieza baja), se hincha y se deshincha. Derrota: se deshincha del todo
-- ('dying_deflate'), queda aturdido ('dying_daze') y se va a coletazos por el terreno ('dying_flee'), soltando el
-- fragmento 2. La inundación baja sola al morir (Floods: control 'boss').
-- Todo lo que se dibuja sale de state + deadTimer + x, y (+ netPackExtra): igual online.
-- Física (choques, saltos a una marca, zona): la de la Gran Bola de Nieve (types/snowboss.lua), reutilizada; nadando,
-- la misma sin gravedad.

local Entity = require 'src/world/entities/base/Entity'
local Boss   = require 'src/world/entities/base/Boss'
local Snow   = require('src/world/entities/types/bosses/snowboss').class
local BossFx = require 'src/fx/BossFx'

local GP = Entity.extend(Boss, {
    ATTACKS  = { puff_warn = true, puffed = true, spines_warn = true, spines = true, flop_wind = true, flop = true },
    OPENINGS = { gasp = true },
    debugColor = { 1, 0.85, 0.35 },
    hitbox = { outerW = 11 / 16, outerH = 8 / 16, innerW = 10 / 16, innerH = 7 / 16 },
})
GP.hurtSound   = 'pufferDeflate'
GP.introLength = 3.4
GP.wantsLevel  = true
GP.animId      = 'enemies/pufferfish'          -- (las animaciones del pez pequeño, a escala MS)

GP.move, GP.physics, GP.friction, GP.groundDecel = Snow.move, Snow.physics, Snow.friction, Snow.groundDecel
GP.zoneBounds, GP.target, GP.jumpTo, GP.groundBelow = Snow.zoneBounds, Snow.target, Snow.jumpTo, Snow.groundBelow
local strike = Boss.strike
local overlap = Boss.overlap

local T  = TILE_PX
local MS = 13                                   -- escala del cuerpo (16x16 → 208 px: el pez llena ~10 de los 16 px
                                                -- del cuadro; a 10, como los Mega, se veía pequeño para un jefe)
GP.MS = MS

-- Ritmo: { normal, enfadado }
local SWIM_SPD   = { 150, 200 }                -- px/s nadando hacia el jugador
local SWIM_ACC   = 2.2                          -- (cuánto tarda en coger su velocidad)
local ATK_EVERY  = { 3.0, 2.2 }                 -- s nadando entre ataques
local PUFF_NEAR  = 4.5 * T                        -- más cerca que esto: se hincha; más lejos: púas
local WARN_T     = { 0.75, 0.6 }                -- aviso (tiembla a medio hinchar)
local PUFF_T     = { 1.4, 2.0 }                 -- hinchado
local DEFLATE_T  = 0.45
local SPINE_WARN = { 0.7, 0.55 }
local BURSTS     = { 0, 0.249, 0.497 }          -- ráfagas a golpe de 3+3+2 semicorcheas a 181 BPM
local SPINES_N   = { 8, 12 }                    -- púas por ráfaga
local SPINES_T   = 0.95                         -- lo que dura el estado (la última ráfaga + un respiro)
local SPINE_SPD  = 470
local SPINE_LIFE = 1.7
local GASP_T     = { 1.7, 1.25 }                -- boqueando (vulnerable)
local FLOP_WIND  = { 0.45, 0.35 }
local FLOP_LOCK  = 0.15                         -- últimos s del aviso: la marca ya no sigue al jugador
local FLOP_REACH = 3.5 * T                      -- lo más lejos que llega de un coletazo
local FLOP_UP    = 2                            -- casillas que sube por encima de lo más alto
local HURT_T     = 0.8
local GRACE      = 0.8                          -- s sin daño por contacto tras un golpe de contacto
local PUFF_R     = 7.2 * MS                     -- radio que pincha hinchado (cuerpo + púas, px)

-- Golpes a los jugadores: { vida, vx, vy, s sin control, s aturdido }
local HIT_TOUCH = { 1, 480, -380, 0.2, 0 }
local HIT_PUFF  = { 1, 640, -520, 0.3, 0 }
local HIT_SPINE = { 1, 380, -300, 0.15, 0 }
local HIT_FLOP  = { 1, 560, -480, 0.25, 0 }
local HIT_SHOVE = { 0, 520, -420, 0.2, 0 }      -- (al hincharse de golpe tras un golpe: solo aparta)

-- Muerte
local DEFLATE_D = 1.1
local DAZE_D    = 2.2
local THROW_T   = 0.8                           -- s huyendo: suelta el fragmento
local FLEE_MIN  = 1.6
local DEATH = { dying_deflate = true, dying_daze = true, dying_flee = true }

local SPINE_IMG = 'assets/images/bosses/giantpuffer/spine.png'
local spineImg
function GP.loadAssets()
    GP.anims(GP)
    if love and love.graphics and not spineImg then spineImg = love.graphics.newImage(SPINE_IMG) end
end
function GP.sizePx() return 16 * MS, 16 * MS end

local function rand(a, b) return a + math.random() * (b - a) end

function GP:feetY() return self.y + self.outerH / 2 end
function GP:ph() return self.rage and 2 or 1 end

function GP:initBoss()
    self.y = self.row * T - self.outerH / 2          -- (de pie en el suelo de su celda)
    self.vx, self.vy, self.onGround = 0, 0, true
    self.facing = -1
    self.rage = false
    self.spines, self.nextId = {}, 0
    self.atkT, self.graceT, self.burst = 0, 0, 0
    self.markX, self.markY = math.floor(self.x), math.floor(self:feetY())
end

function GP:onFightStart(n) self:enter('fight') end
function GP:angryPhase() return self.rage end

-- ¿Agua en su sitio? (el centro del cuerpo)
function GP:wet(level) return level:liquidAt(self.x, self.y) ~= nil end

-- ── Golpes a los jugadores ────────────────────────────────────────────────────
local function onTop(pa, box)
    local pob = pa:getOuterBounds()
    return pob.y + pob.h < box.y + box.h * 0.35 + 10
end

-- Contacto con el cuerpo (de lado; encima decide interact): `hit`; true si dio a alguien
function GP:touch(level, hit)
    local box = self:getOuterBounds()
    local any = false
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false and not pa:isInvulnerable() and overlap(pa:getOuterBounds(), box)
           and not onTop(pa, box) then
            if strike(pa, hit, (pa.x >= self.x) and 1 or -1) then any = true end
        end
    end
    return any
end

-- Hinchado: pincha todo lo que entra en su corro de púas (también desde arriba)
function GP:prick(level, hit)
    local any = false
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false and not pa:isInvulnerable() then
            local b = pa:getOuterBounds()
            local nx = math.max(b.x, math.min(self.x, b.x + b.w))
            local ny = math.max(b.y, math.min(self.y, b.y + b.h))
            if (nx - self.x) ^ 2 + (ny - self.y) ^ 2 <= PUFF_R * PUFF_R then
                if strike(pa, hit, (pa.x >= self.x) and 1 or -1) then
                    any = true
                    Sound.play('pufferPrick', 0.7)
                end
            end
        end
    end
    return any
end

-- ── Púas ──────────────────────────────────────────────────────────────────────
function GP:spineBox(s) return { x = s.x - 12, y = s.y - 12, w = 24, h = 24 } end

function GP:fireBurst(level, k)
    local n = SPINES_N[self:ph()]
    local off = (k % 2 == 1) and (math.pi / n) or 0           -- (ráfagas alternas, desfasadas: no hay hueco fijo)
    for i = 0, n - 1 do
        local a = off + i * (2 * math.pi / n)
        self.nextId = self.nextId % 999 + 1
        self.spines[#self.spines + 1] = { id = self.nextId, x = self.x + math.cos(a) * 6 * MS, y = self.y + math.sin(a) * 5 * MS,
                                          a = a, t = 0, hit = {} }
    end
    Sound.play('pufferPrick', 0.55)
    Entity.emitFx('puffer_pop', self.x, self.y)
end

function GP:updateSpines(level, dt)
    for i = #self.spines, 1, -1 do
        local s = self.spines[i]
        s.t = s.t + dt
        s.x, s.y = s.x + math.cos(s.a) * SPINE_SPD * dt, s.y + math.sin(s.a) * SPINE_SPD * dt
        local zx0, zx1, zy0, zy1 = self:zoneBounds()
        if s.t >= SPINE_LIFE or level:collisionAt(s.x, s.y) or s.x < zx0 or s.x > zx1 or s.y < zy0 or s.y > zy1 + T then
            table.remove(self.spines, i)
        else
            local box = self:spineBox(s)
            for _, pa in ipairs(level.players or {}) do
                if not s.hit[pa] and overlap(pa:getOuterBounds(), box) then
                    if strike(pa, HIT_SPINE, (math.cos(s.a) >= 0) and 1 or -1) then
                        s.hit[pa] = true
                        Sound.play('pufferPrick', 0.8)
                    end
                end
            end
        end
    end
end

-- ── Coletazo (varado) ─────────────────────────────────────────────────────────
-- Dónde cae: hacia el jugador, como mucho FLOP_REACH, sobre la primera superficie
function GP:aimFlop(level)
    local pa = self:target(level)
    local zx0, zx1, _, zy1 = self:zoneBounds()
    local hw = self.outerW / 2
    local tx = pa and pa.x or self.x
    tx = math.max(self.x - FLOP_REACH, math.min(self.x + FLOP_REACH, tx))
    tx = math.max(zx0 + hw, math.min(zx1 - hw, tx))
    local top
    for _, px in ipairs({ tx - hw + 6, tx, tx + hw - 6 }) do
        local _, t = level:landingCross(px, self.y - self.outerH, zy1 + T)
        if t and (not top or t < top) then top = t end
    end
    return math.floor(tx), math.floor(top or zy1)
end

-- ── Estados que sabe hacer el cuerpo ─────────────────────────────────────────
local SPIKY = { puffed = true, spines = true, flop = true, hurt_puff = true }   -- (con las púas fuera)
function GP:isActive() return Boss.isActive(self) and not DEATH[self.state] end
function GP:isDying() return DEATH[self.state] == true or Boss.isDying(self) end
function GP:isVulnerable() return self:isActive() and self.state == 'gasp' end
function GP:releasesZone() return self.state == 'dying_flee' or self.state == 'dead' end
function GP:shardDrop() return not self.alive or (self.state == 'dying_flee' and self.deadTimer >= THROW_T) end
function GP:isSolidBody() return Boss.isSolidBody(self) and not DEATH[self.state] end
function GP:canBeKnocked() return false end

-- Tras un golpe: se hincha de golpe y aparta a quien tenga al lado (sin daño)
function GP:onDamaged(n, kind)
    if self:isDying() then return end
    if not self.rage and self.hp <= self.hpMax * (self.props.rageAt or 0.5) then
        self.rage = true
        Entity.emitFx('shake_roar', self.x, self.y)
    end
    self.vx = 0
    self:enter('hurt_puff')
    Sound.play('pufferInflate', 0.5)
    Entity.emitFx('puffer_pop', self.x, self.y)
    for _, pa in ipairs((self.levelRef or {}).players or {}) do
        if math.abs(pa.x - self.x) < 3 * T and math.abs(pa.y - self.y) < 2.5 * T then
            strike(pa, HIT_SHOVE, (pa.x >= self.x) and 1 or -1)
        end
    end
end

function GP:defeat()
    self.hp, self.inv, self.ghost = 0, 0, false
    self.spines = {}
    self.vx = 0
    self:enter('dying_deflate')
    Sound.play('pufferDeflate', 0.45)
    self:onDefeat()
end

-- Vuelve a lo que le toque según el agua
function GP:resume(level)
    self.atkT = 0
    if self:wet(level) then self:enter('swim')
    elseif self.onGround then self:enter('flop_wind'); self.markX, self.markY = self:aimFlop(level)
    else self:enter('fall') end
end

-- ── Update ────────────────────────────────────────────────────────────────────
function GP:updateBoss(dt, level)
    if self.state == 'dormant' then return end
    self.levelRef = self.levelRef or level
    self.deadTimer = self.deadTimer + dt
    if self.graceT > 0 then self.graceT = math.max(0, self.graceT - dt) end
    self:updateSpines(level, dt)
    local st, t, ph = self.state, self.deadTimer, self:ph()

    if st == 'fight' then self:resume(level); return end

    if st == 'swim' then
        if not self:wet(level) then self:enter('fall'); return end
        local pa = self:target(level)
        local tx, ty = pa and pa.x or self.x, pa and pa.y or self.y
        -- (no asoma del agua: si la parte de arriba sale, baja)
        if level:liquidAt(self.x, self.y - self.outerH * 0.45) == nil then ty = math.max(ty, self.y + T) end
        local dx, dy = tx - self.x, ty - self.y
        local d = math.max(1, math.sqrt(dx * dx + dy * dy))
        local sp = (d > 30) and SWIM_SPD[ph] or 0
        self.vx = self.vx + (dx / d * sp - self.vx) * SWIM_ACC * dt
        self.vy = self.vy + (dy / d * sp * 0.8 - self.vy) * SWIM_ACC * dt
        self:physics(level, dt, false)
        if math.abs(self.vx) > 20 then self.facing = (self.vx > 0) and 1 or -1 end
        self.atkT = self.atkT + dt
        if self.graceT <= 0 and self:touch(level, HIT_TOUCH) then self.graceT = GRACE end
        if self.atkT >= ATK_EVERY[ph] and self:mayAttack(level) then
            self.atkT = 0
            -- (cerca: se hincha; lejos: púas — y nunca dos hinchazones seguidas: si te pegas a él, también púas)
            local near = pa and math.abs(pa.x - self.x) + math.abs(pa.y - self.y) < PUFF_NEAR
            local puff = near and self.lastAtk ~= 'puff'
            self.lastAtk = puff and 'puff' or 'spines'
            self:enter(puff and 'puff_warn' or 'spines_warn')
            Sound.play('pufferWarn', 0.55)
        end

    elseif st == 'puff_warn' or st == 'spines_warn' then
        self.vx, self.vy = self.vx * (1 - 4 * dt), self.vy * (1 - 4 * dt)
        local wet = self:wet(level)
        self:physics(level, dt, not wet)
        local len = (st == 'puff_warn') and WARN_T[ph] or SPINE_WARN[ph]
        if t >= len then
            if st == 'puff_warn' then
                self:enter('puffed')
                Sound.play('pufferInflate', 0.5)
                Entity.emitFx('puffer_pop', self.x, self.y)
            else
                self.burst = 0
                self:enter('spines')
            end
        end

    elseif st == 'puffed' then
        self.vx, self.vy = self.vx * (1 - 3 * dt), self.vy * (1 - 3 * dt)
        self:physics(level, dt, not self:wet(level))
        self:prick(level, HIT_PUFF)
        if t >= PUFF_T[ph] then self:enter('deflate'); Sound.play('pufferDeflate', 0.5) end

    elseif st == 'spines' then
        self:physics(level, dt, not self:wet(level))
        while self.burst < #BURSTS and t >= BURSTS[self.burst + 1] do
            self:fireBurst(level, self.burst)
            self.burst = self.burst + 1
        end
        self:prick(level, HIT_PUFF)
        if t >= SPINES_T then self:enter('deflate'); Sound.play('pufferDeflate', 0.5) end

    elseif st == 'deflate' or st == 'hurt_puff' then
        self.vx, self.vy = self.vx * (1 - 3 * dt), self.vy * (1 - 3 * dt)
        local wet = self:wet(level)
        self:physics(level, dt, not wet)
        if not wet then self:friction(level, dt) end
        if st == 'hurt_puff' then self:prick(level, HIT_SHOVE) end
        if t >= ((st == 'deflate') and DEFLATE_T or HURT_T) and (wet or self.onGround) then self:resume(level) end

    elseif st == 'fall' then
        self:physics(level, dt)
        if self:wet(level) then self:enter('swim')
        elseif self.onGround then
            self.vx = 0
            Sound.play('kingFlop', 1.4)
            Entity.emitFx('gp_land', self.x, self:feetY())
            self:enter('gasp')
            Sound.play('stunned')
        end

    elseif st == 'gasp' then
        self:physics(level, dt); self:friction(level, dt)
        if self:wet(level) then self:enter('swim'); self.atkT = 0
        elseif t >= GASP_T[ph] then
            self.markX, self.markY = self:aimFlop(level)
            self:enter('flop_wind')
        end

    elseif st == 'flop_wind' then
        self:physics(level, dt); self:friction(level, dt)
        if self:wet(level) then self:enter('swim'); self.atkT = 0; return end
        if t < FLOP_WIND[ph] - FLOP_LOCK then self.markX, self.markY = self:aimFlop(level) end
        self.facing = (self.markX >= self.x) and 1 or ((self.markX < self.x) and -1 or self.facing)
        if t >= FLOP_WIND[ph] and self:mayAttack(level) then
            self.passY = self.markY
            self:jumpTo(self.markX, self.markY, FLOP_UP)
            self:enter('flop')
            self.passY = self.markY
            Sound.play('kingJump', 1.5)
        end

    elseif st == 'flop' then
        self:physics(level, dt)
        if self.graceT <= 0 and self:prick(level, HIT_FLOP) then self.graceT = GRACE end
        if self:wet(level) then self.passY = nil; self:enter('swim'); self.atkT = 0
        elseif self.onGround and self.vy >= 0 and t > 0.1 then
            self.passY, self.vx = nil, 0
            Sound.play('kingFlop', 1.4)
            Entity.emitFx('gp_land', self.x, self:feetY())
            Entity.emitFx('shake_small', self.x, self.y)
            self:enter('gasp')
            Sound.play('stunned')
        end

    elseif st == 'dying_deflate' then
        self:physics(level, dt, not self:wet(level)); self:friction(level, dt)
        self.vy = self:wet(level) and math.min(self.vy + 900 * dt, 260) or self.vy    -- (deshinchado: se hunde)
        if t >= DEFLATE_D and (self.onGround or t >= DEFLATE_D + 2) then
            self:enter('dying_daze')
            Sound.play('stunned')
        end

    elseif st == 'dying_daze' then
        self:physics(level, dt); self:friction(level, dt)
        if t >= DAZE_D then
            self.fleeDir = self:fleeSide(level)
            self.facing, self.fleeing, self.hopT = self.fleeDir, true, 0
            self:enter('dying_flee')
        end

    elseif st == 'dying_flee' then
        -- a coletazos por el terreno, hacia el lado más cercano de la zona (como el Rey Gummy)
        local was = self.onGround
        local hit = self:physics(level, dt)
        if self.onGround then
            if not was then self.vx = 0 end
            self.hopT = (self.hopT or 0) + dt
            if self.hopT >= 0.4 then
                self.hopT = 0
                self.vx, self.vy = self.fleeDir * 320, (self.blocked and -1250 or -760)
                self.onGround, self.blocked = false, false
                Sound.play('kingHop', 1.4)
            end
        elseif hit == 'wall' then
            self.blocked = true
        end
        if self:fleeOver(level, dt, t, FLEE_MIN) then self.state, self.alive = 'dead', false end
    end
end

-- ── Entrada: cae del cielo en la cala, se hincha y se deshincha ──────────────
local FALL_AT, LAND_AT, PUFF_AT, DEFL_AT = 0.4, 1.0, 1.7, 2.7
GP.LAND_AT, GP.PUFF_AT = LAND_AT, PUFF_AT
function GP:introFocus()
    local zx0, zx1, zy0, zy1 = self:zoneBounds()
    return (zx0 + zx1) / 2, (zy0 + zy1) / 2
end
function GP:onIntroStart(level, players)
    self.introStep = 0
    self.levelRef = self.levelRef or level
end
function GP:updateIntro(dt, level, t)
    local hx, hy = self.home.x, self.home.y
    local _, _, zy0 = self:zoneBounds()
    self.x = hx
    if t < LAND_AT then
        local y0 = zy0 - self.outerH
        local u = math.max(0, (t - FALL_AT) / (LAND_AT - FALL_AT))
        self.y = (t < FALL_AT) and y0 or (y0 + (hy - y0) * u * u)
        if t >= FALL_AT and self.introStep < 1 then self.introStep = 1; Sound.play('kingJump', 1.3) end
        return
    end
    self.y = hy
    if self.introStep < 2 then
        self.introStep = 2
        Sound.play('kingFlop', 1.3)
        Entity.emitFx('gp_land', self.x, self:feetY())
        Entity.emitFx('shake_big', self.x, self.y)
    end
    if t >= PUFF_AT and self.introStep < 3 then
        self.introStep = 3
        Sound.play('pufferInflate', 0.45)
        Entity.emitFx('puffer_pop', self.x, self.y)
    end
    if t >= DEFL_AT and self.introStep < 4 then self.introStep = 4; Sound.play('pufferDeflate', 0.5) end
end

-- ── Red ───────────────────────────────────────────────────────────────────────
-- { enfadado 0/1, marca x, y, ráfaga, nPúas, {id, x, y, ángulo·1000, t·100}… }
local NB = 4
function GP:netPackExtra()
    local out = { self.rage and 1 or 0, self.markX or 0, self.markY or 0, self.burst or 0, #self.spines }
    for _, s in ipairs(self.spines) do
        out[#out + 1] = s.id; out[#out + 1] = math.floor(s.x); out[#out + 1] = math.floor(s.y)
        out[#out + 1] = math.floor(s.a * 1000); out[#out + 1] = math.floor(s.t * 100)
    end
    return out
end

local function readList(b, k, stride)
    local n = b[k] or 0
    local list = {}
    for i = 0, n - 1 do
        local e = {}
        for j = 1, stride do e[j] = b[k + 1 + i * stride + j - 1] end
        list[#list + 1] = e
    end
    return list
end

function GP:netApplyExtra(a, b, f)
    if type(b[1]) ~= 'number' then return end
    self.rage, self.markX, self.markY, self.burst = b[1] == 1, b[2], b[3], b[4]
    local prev = {}
    if type(a[NB + 1]) == 'number' then
        for _, e in ipairs(readList(a, NB + 1, 5)) do if e[1] then prev[e[1]] = e end end
    end
    self.spines = {}
    for _, e in ipairs(readList(b, NB + 1, 5)) do
        local x, y = e[2], e[3]
        local o = prev[e[1]]
        if o and type(o[2]) == 'number' and type(o[3]) == 'number' then x, y = o[2] + (x - o[2]) * f, o[3] + (y - o[3]) * f end
        self.spines[#self.spines + 1] = { id = e[1], x = x, y = y, a = e[4] / 1000, t = e[5] / 100, hit = {} }
    end
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
-- (animación del pez pequeño, cuadro por tiempo, escala, giro, aplastamiento) según el estado
function GP:pose()
    local st, t = self.state, self.deadTimer or 0
    local now = love.timer.getTime()
    local name, at, k, rot, sy, shake = 'swim', now, 1, 0, 1, 0
    if st == 'intro' or st == 'ready' then
        local it = (st == 'ready') and (self:introTime() + t) or t
        if it >= PUFF_AT and it < DEFL_AT then name, at = 'puffed', it - PUFF_AT; k = 1 + 0.15 * math.max(0, 1 - (it - PUFF_AT) / 0.2)
        elseif it >= DEFL_AT then name, at = 'deflate', it - DEFL_AT
        else name, at = 'half', it end
    elseif st == 'puff_warn' or st == 'spines_warn' then
        name, at, shake = 'warn', t, 3
        if t > 0.36 then name = 'half' end
    elseif SPIKY[st] then
        name, at = 'puffed', t
        if t < 0.15 then k = 1 + 0.15 * math.sin(t / 0.15 * math.pi) end
    elseif st == 'deflate' or st == 'dying_deflate' then
        name, at = 'deflate', t
        if st == 'dying_deflate' then sy = math.max(0.55, 1 - 0.45 * math.min(1, t / DEFLATE_D)) end
    elseif st == 'gasp' or st == 'dying_daze' then
        -- varado de lado: boquea (se infla un poco y se desinfla) y da coletazos en el sitio
        name, at = 'swim', 0
        rot = math.sin(now * 9) * 0.12
        sy = 0.92 + 0.06 * math.sin(now * 4.5)
    elseif st == 'flop_wind' then
        name, at, shake = 'half', t, 2
    elseif st == 'fall' then
        name, at = 'half', t
    elseif st == 'dying_flee' then
        name, at = self.onGround and 'swim' or 'half', now
    end
    return name, at, k, rot, sy, shake
end

function GP:render(camX, camY)
    if self.state == 'dormant' and not EDITOR_VIEW then return end
    if self.state == 'dead' then return end
    local st = self.state
    local now = love.timer.getTime()
    local name, at, k, rot, sy, shake = self:pose()
    local x, y = math.floor(self.x - camX), math.floor(self.y - camY)
    if shake > 0 then x = x + math.floor(math.sin(now * 60) * shake + 0.5) end
    local alpha = self:ghostAlpha()
    if st == 'dying_flee' then alpha = alpha * self:fleeAlpha(self.deadTimer) end
    local f = self.facing or 1
    -- Marca del coletazo (dónde caerá)
    if st == 'flop_wind' and not EDITOR_VIEW then
        local blink = (math.floor(now * 12) % 2 == 0) and 0.95 or 0.55
        love.graphics.setColor(1, 0.85, 0.3, blink * alpha)
        BossFx.target(now * 1.2, math.floor(self.markX - camX), math.floor(self.markY - camY - 16), 8, 8)
    end
    -- Estrellitas (boqueando / vencido): las de detrás, antes del cuerpo
    local dizzy = (st == 'gasp' or st == 'dying_daze') and not EDITOR_VIEW
    local hx, hy = x + f * 3 * MS, y - math.floor(4.8 * MS)
    if dizzy then BossFx.stars(hx, hy, 6 * MS, 1.4 * MS, 5, alpha, 'back') end
    -- Cuerpo
    if self:flashRed() then love.graphics.setColor(1, 0.35, 0.35, alpha)
    elseif self.rage and self:isActive() then
        local q = 0.82 + 0.1 * math.sin(now * 6)
        love.graphics.setColor(1, q, q, alpha)
    else love.graphics.setColor(1, 1, 1, alpha) end
    -- (el cuadro tiene el cuerpo centrado en x = 8,6 px: se corrige para que el centro del cuerpo caiga en x)
    self:anims():draw(name, at, x - math.floor(f * 0.6 * MS), y + math.floor((1 - sy) * 4 * MS), rot,
                      MS * k * f, MS * k * sy, 0.5, 0.5)
    if dizzy then BossFx.stars(hx, hy, 6 * MS, 1.4 * MS, 5, alpha, 'front') end
    -- Enfadado: los símbolos de enfado de todos los jefes
    BossFx.anger(self, self.rage and self:isActive(), self.x - camX, self.y - camY - 7 * MS)
    -- Púas
    if spineImg then
        love.graphics.setColor(1, 1, 1, 1)
        for _, s in ipairs(self.spines or {}) do
            love.graphics.draw(spineImg, math.floor(s.x - camX), math.floor(s.y - camY), s.a, 4, 4,
                               spineImg:getWidth() / 2, spineImg:getHeight() / 2)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Cajas de depuración (F1): el corro que pincha hinchado y las púas
function GP:debugBoxes()
    local out = {}
    if SPIKY[self.state] then
        out[#out + 1] = { x = self.x - PUFF_R, y = self.y - PUFF_R, w = 2 * PUFF_R, h = 2 * PUFF_R, kind = 'hazard' }
    end
    for _, s in ipairs(self.spines or {}) do
        local b = self:spineBox(s); b.kind = 'hazard'; out[#out + 1] = b
    end
    return out
end

local G = 'Pez Globo Gigante'
return {
    name = 'giantpuffer', label = 'Pez Globo Gigante', category = 'Jefes',
    description = 'El pez globo en grande, con la marea: nadando se hincha y dispara púas; varado da coletazos '
               .. 'y, al caer, boquea: solo entonces se le puede golpear (pisotón 1, ground pound 2).',
    class = GP,
    boss = { title = 'PEZ GLOBO GIGANTE' },
    hide = Boss.HIDE,
    defaults = { points = 30 },
    props = Boss.props({ hp = 10, hpPerPlayer = 4 }, {
        { key = 'rageAt', kind = 'number', label = 'Se enfada con (fracción de vida)', group = G, default = 0.5,
          min = 0.1, max = 0.9, step = 0.05 },
    }),
    editor = { sprite = 'assets/images/enemies/pufferfish/puffer_fish-Sheet.png', frameW = 16 },
}
