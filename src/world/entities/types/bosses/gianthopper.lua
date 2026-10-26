-- Jefe SALTARÍN GIGANTE (types/gianthopper.lua): el jefe de las CUEVAS (sustituye al Mega Crabby lúgubre en el mapa,
-- que pasa a ser jefe secreto: docs/bosses/new-bosses-plan.md). Es el Saltarín de cueva en grande: su MISMA hoja 16x21
-- (variante cueva de assets/anim/enemies/hopper.json) a escala 12 (MS), con su farolillo. Se pelea A OSCURAS.
--
-- Es la POLILLA del Saltarín de cueva (types/enemies/hopper.lua) en jefe — al revés que el Crabby lúgubre, que caza de
-- oído: CAZA POR LA LUZ y el RUIDO lo asusta.
--   · VE a quien tiene luz, con la línea despejada desde su farol (las rocas tapan: Lights.clear): un jugador con la
--     LINTERNA encendida (en toda la arena) o cualquiera dentro de la luz de su FAROL (LAMP_R). Si te pierde, va a
--     donde te vio por última vez (MEMORY s).
--   · Viéndote: se AGACHA ('crouch': la diana en el suelo te sigue, fija los últimos LOCK s) y SALTA encima ('hop').
--     Al caer suelta dos ONDAS DE ROCA por el suelo, una a cada lado (se saltan). Tocarlo = 1 de vida y empujón.
--   · Sin verte: se pasea a saltitos y cada FLARE_EVERY s hace un FOGONAZO ('flare_wind': el farol se hincha, parpadea
--     y zumba → 'flare': luz en toda la arena, cortada por las rocas). A quien alumbre, lo ha visto → a por él. Detrás
--     de una roca no te ve.
--   · RUIDO FUERTE CERCA (≥ LOUD casillas de radio, a menos de SCARE_NEAR: un ground pound, matar a un saltarín, un
--     golpe...; no el de un jugador herido) mientras está en el suelo → se ASUSTA ('scared'): apaga el farol, se
--     encoge temblando y le salen estrellitas: lo ÚNICO vulnerable (pisotón 1 / ground pound 2, un golpe por ocasión;
--     luego se aparta de un respingo, 'hurt', y tarda SCARE_CD s en volver a asustarse). Encima de él, si no, rebotas.
--     La linterna es el cebo; el ruido, el arma.
--   · ENFADADO (por debajo de `rageAt`): todo más rápido, fogonazos más seguidos y suelta SALTARINES de cueva (súbditos
--     de reserva, def.summons; más cuanto más difícil): ven tu luz como él y matarlos hace ruido (lo asusta si está cerca).
-- Entrada: cae de la oscuridad en su sitio, enciende el farol y se agacha. Derrota: el farol se apaga parpadeando, se
-- queda aturdido ('dying_out') y se va de un SALTO enorme hacia arriba, atravesando el techo ('dying_flee'; sin choques,
-- pura función del tiempo), soltando el fragmento 6. Sus saltarines se mueren.
-- Todo lo que se dibuja sale de state + deadTimer + x, y (+ netPackExtra): igual online. La luz (lights) también.
-- Física (choques, saltos a una marca, zona): la de la Gran Bola de Nieve (types/snowboss.lua), reutilizada.

local Entity = require 'src/world/entities/base/Entity'
local Boss   = require 'src/world/entities/base/Boss'
local Snow   = require('src/world/entities/types/bosses/snowboss').class
local BossFx = require 'src/fx/BossFx'
local Lights = require 'src/world/level/Lights'
local SpriteStrip = require 'src/fx/SpriteStrip'

local GH = Entity.extend(Boss, {
    ATTACKS  = { crouch = true, hop = true, flare_wind = true, flare = true },
    OPENINGS = { scared = true },
    debugColor = { 0.8, 0.7, 1 },
    -- (como el pequeño: la bola mide 9 de los 16 px de ancho; de alto, bola + muelle = 13 px)
    hitbox = { outerW = 0.56, outerH = 1.0, innerW = 0.4, innerH = 0.62 },
})
GH.hurtSound   = 'hopLand'
GH.introLength = 3.4
GH.wantsLevel  = true
GH.animId, GH.animVariant = 'enemies/hopper', 'cueva'      -- (la hoja del Saltarín de cueva, a escala MS)

GH.move, GH.physics, GH.friction, GH.groundDecel = Snow.move, Snow.physics, Snow.friction, Snow.groundDecel
GH.zoneBounds, GH.jumpTo, GH.groundBelow = Snow.zoneBounds, Snow.jumpTo, Snow.groundBelow
local strike = Boss.strike
local overlap = Boss.overlap

local T  = TILE_PX
local MS = 12                                   -- escala (el pequeño: 4)
local FW, BODY_H = 16, 13                       -- cuadro 16 de ancho; la caja = bola + muelle (13 filas)
GH.MS = MS

-- Ritmo: { normal, enfadado }
local REST_T      = { 1.3, 0.85 }               -- s quieto entre saltos
local WIND_T      = { 0.8, 0.6 }                -- s agachado (el aviso: la diana)
local LOCK        = 0.2                         -- últimos s del aviso: la diana ya no te sigue
local HOP_REACH   = 11 * T                      -- lo más lejos que llega de un salto (de punta a punta de la sima)
local HOP_UP      = 2.5                         -- casillas por encima de lo más alto
local PROWL_REACH = 3.5 * T                     -- paseando (sin verte): saltitos
local PROWL_UP    = 1.2
local FLARE_EVERY = { 7, 5 }                    -- s sin verte hasta el fogonazo
local FLARE_WIND  = { 1.0, 0.8 }
local FLARE_T     = 0.45
local SCARE_T     = { 2.6, 2.0 }                -- s asustado (vulnerable)
local SCARE_CD    = 2.5                         -- s sin poder asustarse otra vez
local HURT_T      = 0.7
local MEMORY      = 4                           -- s yendo a donde te vio
local GRACE       = 0.8                         -- s sin volver a dar a nadie tras un golpe

local LAMP_R     = 4.5 * T                      -- lo que alumbra su farol
local FLARE_R    = 12 * T                       -- el fogonazo
local SEE_R      = 16 * T                       -- a quien lleva la linterna encendida lo ve desde aquí
local LOUD       = 6 * T                        -- radio mínimo de un ruido que lo asusta
local SCARE_NEAR = 7 * T                        -- ... y tiene que sonar así de cerca
GH.LAMP_R, GH.FLARE_R, GH.SCARE_NEAR = LAMP_R, FLARE_R, SCARE_NEAR

-- Ondas de roca (al caer de un salto de caza)
local WAVE_SPD, WAVE_LIFE = 430, 2.2
local WAVE_W, WAVE_H = 40, 36

-- Golpes a los jugadores: { vida, vx, vy, s sin control, s aturdido }
local HIT_TOUCH = { 1, 480, -420, 0.2, 0 }
local HIT_WAVE  = { 1, 300, -440, 0.15, 0 }
local HIT_SHOVE = { 0, 520, -420, 0.2, 0 }      -- (el respingo tras un golpe: solo aparta)

-- Muerte
local OUT_D     = 2.4                           -- s aturdido con el farol apagándose
local THROW_T   = 0.8                           -- s huyendo: suelta el fragmento
local FLEE_MIN  = 1.6
local FLEE_WIND = 0.4
local FLEE_VX, FLEE_VY, FLEE_G = 260, -1900, 2400   -- el salto de la huida (sin choques: atraviesa el techo)

-- Saltarines de la segunda fase: cuántos a la vez según la dificultad (sin dificultad, como Normal)
local MOTHS      = { easy = 1, normal = 2, hard = 2, extreme = 3, xtra = 3 }
local MOTH_POOL  = 3
local SPAWN_EVERY = 6.0
local DEATH = { dying_out = true, dying_flee = true }
local DARK  = { scared = true, dying_out = true, dying_flee = true, dormant = true, dead = true }   -- (farol apagado)

local LAMP = { 1, 0.85, 0.5 }                   -- color de su luz (el del pequeño)
local WAVE_IMG = 'assets/images/bosses/gianthopper/wave-Sheet.png'
local waveStrip
function GH.loadAssets()
    GH.anims(GH)
    if love and love.graphics and not waveStrip then waveStrip = SpriteStrip.load(WAVE_IMG, 12) end
end
function GH.sizePx() return FW * MS, BODY_H * MS end

local function rand(a, b) return a + math.random() * (b - a) end

function GH:feetY() return self.y + self.outerH / 2 end
function GH:ph() return self.rage and 2 or 1 end
function GH:bossPhase() return self.rage and 2 or 1 end

function GH:initBoss()
    self.y = self.row * T - self.outerH / 2          -- (de pie en el suelo de su celda)
    self.vx, self.vy, self.onGround = 0, 0, true
    self.facing = -1
    self.rage, self.hunting = false, false
    self.waves, self.nextId = {}, 0
    self.flareT, self.memT, self.graceT, self.scareCd, self.spawnT = 0, 0, 0, 0, 0
    self.restLen = REST_T[1]
    self.markX, self.markY = math.floor(self.x), math.floor(self:feetY())
    self.summonKey = 'gh' .. self.col .. ',' .. self.row
end

function GH:onFightStart(n) self:enter('fight') end
function GH:angryPhase() return self.rage end

-- La punta del farol (2 px de arte hacia su cara, 16,5 por encima de los pies: el dibujo mira a la izquierda)
function GH:lamp()
    return self.x - 2 * MS * (self.facing or 1), self:feetY() - 16.5 * MS
end
function GH:lampOn() return not DARK[self.state] and not self:inIntro() end

-- ── Qué ve y qué oye ─────────────────────────────────────────────────────────
function GH:sees(level, pa)
    local lx, ly = self:lamp()
    local px, py = pa.x, pa.y - 10
    local d = math.sqrt((px - lx) ^ 2 + (py - ly) ^ 2)
    local lit = (pa.lightOn and d <= SEE_R) or (self:lampOn() and d <= LAMP_R)
    return lit and Lights.clear(level, lx, ly, px, py)
end

-- El jugador más cercano que VE (y se apunta dónde y cuándo)
function GH:target(level)
    local best, bd
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false and self:sees(level, pa) then
            local d = math.abs(pa.x - self.x) + math.abs(pa.y - self.y) * 0.3
            if not bd or d < bd then best, bd = pa, d end
        end
    end
    if best then self.seenX, self.seenY, self.memT = best.x, best.y, MEMORY end
    return best
end

-- Un ruido FUERTE, CERCA y nuevo (no el de un jugador herido). Siempre se pone al día (lo que suena mientras salta
-- o con la espera, no cuenta luego)
function GH:hearsLoud(level, listen)
    local n = level.noises
    if not n then self.heardSeq = 0; return false end
    local since = self.heardSeq or n.seq
    self.heardSeq = n.seq
    if not listen then return false end
    local k = require('src/core/Difficulty').k('sense')
    for _, z in ipairs(n.list) do
        if z.seq > since and z.from ~= 'hurt' and z.from ~= 'boss' and z.r >= LOUD then
            local d = math.sqrt((z.x - self.x) ^ 2 + (z.y - self.y) ^ 2)
            if d <= math.min(z.r * k, SCARE_NEAR) then return true end
        end
    end
    return false
end

-- ── Golpes a los jugadores ────────────────────────────────────────────────────
-- Tocarlo (no desde arriba: eso es pisarlo o rebotar)
function GH:touch(level)
    if self.graceT > 0 then return end
    local b = self:getOuterBounds()
    local box = { x = b.x - 6, y = b.y, w = b.w + 12, h = b.h + 4 }
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false and not pa:isInvulnerable() then
            local pb = pa:getOuterBounds()
            local onTop = pb.y + pb.h <= b.y + 14 and (pa.vy or 0) >= -50
            if not onTop and overlap(pb, box) and strike(pa, HIT_TOUCH, (pa.x >= self.x) and 1 or -1) then
                self.graceT = GRACE
            end
        end
    end
end

-- ── Ondas de roca ─────────────────────────────────────────────────────────────
function GH:spawnWaves()
    local fy = math.floor(self:feetY())
    for _, d in ipairs({ -1, 1 }) do
        self.nextId = self.nextId % 999 + 1
        self.waves[#self.waves + 1] = { id = self.nextId, x = math.floor(self.x + d * (self.outerW / 2 + 4)), y = fy,
                                        dir = d, t = 0, hit = {} }
    end
end
function GH:waveBox(w) return { x = w.x - WAVE_W / 2, y = w.y - WAVE_H, w = WAVE_W, h = WAVE_H } end
function GH:updateWaves(level, dt)
    local zx0, zx1 = self:zoneBounds()
    for i = #self.waves, 1, -1 do
        local w = self.waves[i]
        w.t = w.t + dt
        w.x = w.x + w.dir * WAVE_SPD * dt
        local ahead = w.x + w.dir * WAVE_W / 2
        local gone = w.t >= WAVE_LIFE or ahead < zx0 or ahead > zx1
            or level:entitySolidAt(ahead, w.y - 12)                       -- (pared o escalón)
            or not level:collisionAt(w.x, w.y + 6, true)                  -- (se acaba el suelo)
        if gone then
            table.remove(self.waves, i)
        else
            local box = self:waveBox(w)
            for _, pa in ipairs(level.players or {}) do
                if not w.hit[pa] and overlap(pa:getOuterBounds(), box) and strike(pa, HIT_WAVE, w.dir) then
                    w.hit[pa] = true
                end
            end
        end
    end
end

-- ── Saltarines de la segunda fase (súbditos de reserva) ─────────────────────
function GH:mothMax(level)
    return math.min(MOTH_POOL, MOTHS[level.difficulty or ''] or MOTHS.normal)
end
function GH:spawnMoths(level, dt)
    self.spawnT = self.spawnT + dt
    if self.spawnT < SPAWN_EVERY then return end
    local free, active = nil, 0
    for _, e in ipairs(self:minions(level)) do
        if e.alive then active = active + 1 elseif not free then free = e end
    end
    if not free or active >= self:mothMax(level) then return end
    self.spawnT = 0
    local zx0, zx1 = self:zoneBounds()
    local f = self.facing or 1
    local h = free.home
    h.x = math.max(zx0 + T, math.min(zx1 - T, self.x + f * 2 * T))
    h.y, h.facing, h.flipped, h.state, h.vx = self:feetY() - free.outerH / 2 - 4, f, false, 'idle', 0
    free:resetToHome()
    free.leftBoundPx, free.rightBoundPx = zx0, zx1
    Sound.play('hopJump', 1.3)
    Entity.emitFx('spawn', h.x, h.y)
end

-- ── Saltos ────────────────────────────────────────────────────────────────────
-- Dónde cae: hacia `tx`, como mucho `reach`, sobre la primera superficie que haya a la altura del objetivo (si está
-- más abajo, atraviesa las plataformas para bajar a por él; si se subió a una, salta a ella). Solo donde le cabe el
-- cuerpo bajo el techo de la zona
function GH:aim(level, tx, ty, reach)
    local zx0, zx1, zy0, zy1 = self:zoneBounds()
    local hw = self.outerW / 2
    tx = math.max(self.x - reach, math.min(self.x + reach, tx))
    tx = math.max(zx0 + hw, math.min(zx1 - hw, tx))
    local y0 = self.y - self.outerH
    if ty then y0 = math.max(zy0 + self.outerH, ty - T) end
    local top
    for _, px in ipairs({ tx - hw + 6, tx, tx + hw - 6 }) do
        local _, t = level:landingCross(px, y0, zy1 + T)
        if t and (not top or t < top) then top = t end
    end
    return math.floor(tx), math.floor(top or zy1)
end

-- Se agacha para saltar: a por alguien (hunting: diana) o de paseo
function GH:startCrouch(level, hunting)
    self.hunting = hunting
    if hunting then
        self.markX, self.markY = self:aim(level, self.seenX or self.x, self.seenY, HOP_REACH)
        Sound.play('hopWind', 0.55)
    else
        local zx0, zx1 = self:zoneBounds()
        local d = rand(0.4, 1) * PROWL_REACH * ((math.random() < 0.5) and -1 or 1)
        if self.x + d < zx0 + 2 * T or self.x + d > zx1 - 2 * T then d = -d end
        self.markX, self.markY = self:aim(level, self.x + d, nil, PROWL_REACH)
    end
    self:enter('crouch')
end

-- ── Estados que sabe hacer el cuerpo ─────────────────────────────────────────
function GH:isActive() return Boss.isActive(self) and not DEATH[self.state] end
function GH:isDying() return DEATH[self.state] == true or Boss.isDying(self) end
function GH:isVulnerable() return self:isActive() and self.state == 'scared' end
function GH:releasesZone() return self.state == 'dying_flee' or self.state == 'dead' end
function GH:shardDrop() return not self.alive or (self.state == 'dying_flee' and self.deadTimer >= THROW_T) end
function GH:isSolidBody() return Boss.isSolidBody(self) and not DEATH[self.state] end
function GH:canBeKnocked() return false end

-- Tras un golpe: respingo (aparta a quien tenga al lado, sin daño) y vuelve a encender el farol
function GH:onDamaged(n, kind)
    if self:isDying() then return end
    if not self.rage and self.hp <= self.hpMax * (self.props.rageAt or 0.5) then
        self.rage = true
        Entity.emitFx('shake_roar', self.x, self.y)
    end
    self.vx = 0
    self:enter('hurt')
    Sound.play('lightOn', 0.6)
    for _, pa in ipairs((self.levelRef or {}).players or {}) do
        if math.abs(pa.x - self.x) < 3 * T and math.abs(pa.y - self.y) < 3 * T then
            strike(pa, HIT_SHOVE, (pa.x >= self.x) and 1 or -1)
        end
    end
end

function GH:defeat()
    self.hp, self.inv, self.ghost = 0, 0, false
    self.waves = {}
    for _, e in ipairs(self.levelRef and self:minions(self.levelRef) or {}) do
        if e.alive and e.state ~= 'dead' then e:dieBurst() end
    end
    self.vx = 0
    self:enter('dying_out')
    Sound.play('lightOff', 0.5)
    Sound.play('stunned')
    self:onDefeat()
end

function GH:rest(len)
    self.restLen = len or REST_T[self:ph()]
    self:enter('rest')
end

-- ── Update ────────────────────────────────────────────────────────────────────
local LISTEN = { rest = true, crouch = true, flare_wind = true, flare = true }
function GH:updateBoss(dt, level)
    if self.state == 'dormant' then return end
    self.levelRef = self.levelRef or level
    self.deadTimer = self.deadTimer + dt
    if self.graceT > 0 then self.graceT = math.max(0, self.graceT - dt) end
    if self.scareCd > 0 then self.scareCd = math.max(0, self.scareCd - dt) end
    if self.memT > 0 then self.memT = math.max(0, self.memT - dt) end
    self:updateWaves(level, dt)
    local st, t, ph = self.state, self.deadTimer, self:ph()

    if st == 'fight' then self:rest(); return end

    -- Un ruido fuerte cerca, en el suelo: se asusta (lo que sonó saltando o con la espera no cuenta)
    local listen = LISTEN[st] and self.onGround and self.scareCd <= 0
    if self:hearsLoud(level, listen) then
        self.vx, self.hunting = 0, false
        self:enter('scared')
        Sound.play('lightOff', 0.6)
        Sound.play('stunned')
        Entity.emitFx('shake_small', self.x, self.y)
        return
    end

    if st == 'rest' then
        self:physics(level, dt); self:friction(level, dt)
        self:touch(level)
        if self.rage then self:spawnMoths(level, dt) end
        local pa = self:target(level)
        if pa and math.abs(pa.x - self.x) > 8 then self.facing = (pa.x > self.x) and 1 or -1 end
        if not pa and self.memT <= 0 then self.flareT = self.flareT + dt end
        if t >= self.restLen and self.onGround and self:mayAttack(level) then
            if pa or self.memT > 0 then self:startCrouch(level, true)
            elseif self.flareT >= FLARE_EVERY[ph] then
                self:enter('flare_wind')
                Sound.play('hopWind', 0.4)
            else self:startCrouch(level, false) end
        end

    elseif st == 'crouch' then
        self:physics(level, dt); self:friction(level, dt)
        self:touch(level)
        if self.hunting and t < WIND_T[ph] - LOCK then
            local pa = self:target(level)
            self.markX, self.markY = self:aim(level, self.seenX or self.x, pa and pa.y or self.seenY, HOP_REACH)
        end
        if math.abs(self.markX - self.x) > 4 then self.facing = (self.markX > self.x) and 1 or -1 end
        if t >= (self.hunting and WIND_T[ph] or WIND_T[ph] * 0.6) then
            self.passY = self.markY
            self:jumpTo(self.markX, self.markY, self.hunting and HOP_UP or PROWL_UP)
            self:enter('hop')
            self.passY = self.markY
            Sound.play('hopJump', self.hunting and 0.55 or 0.7, self.hunting and 1 or 0.6)
        end

    elseif st == 'hop' then
        self:physics(level, dt)
        self:touch(level)
        if self.onGround and self.vy >= 0 and t > 0.1 then
            self.passY, self.vx = nil, 0
            Entity.emitFx('gp_land', self.x, self:feetY())
            if self.hunting then
                self:spawnWaves()
                Sound.play('hopLand', 0.5)
                Sound.play('gpImpact', 0.7)
                Entity.emitFx('shake_big', self.x, self.y)
            else
                Sound.play('hopLand', 0.65, 0.7)
                Entity.emitFx('shake_small', self.x, self.y)
            end
            self:rest()
        end

    elseif st == 'flare_wind' then
        self:physics(level, dt); self:friction(level, dt)
        self:touch(level)
        if t >= FLARE_WIND[ph] then
            self:enter('flare')
            self.flareT = 0
            Sound.play('lightOn', 0.45)
            -- a quien alumbra el fogonazo (despejado desde el farol), lo ha visto
            local lx, ly = self:lamp()
            local best, bd
            for _, pa in ipairs(level.players or {}) do
                if not pa.dying and pa.alive ~= false then
                    local d = math.sqrt((pa.x - lx) ^ 2 + (pa.y - 10 - ly) ^ 2)
                    if d <= FLARE_R and Lights.clear(level, lx, ly, pa.x, pa.y - 10) and (not bd or d < bd) then best, bd = pa, d end
                end
            end
            if best then self.seenX, self.seenY, self.memT = best.x, best.y, MEMORY end
        end

    elseif st == 'flare' then
        self:physics(level, dt); self:friction(level, dt)
        self:touch(level)
        if t >= FLARE_T then self:rest(0.25) end

    elseif st == 'scared' then
        self:physics(level, dt); self:friction(level, dt)
        if t >= SCARE_T[ph] then
            self.scareCd = SCARE_CD
            Sound.play('lightOn', 0.6)
            self:rest(0.4)
        end

    elseif st == 'hurt' then
        self:physics(level, dt); self:friction(level, dt)
        if t >= HURT_T and self.onGround then
            self.scareCd = SCARE_CD
            self:rest(0.5)
        end

    elseif st == 'dying_out' then
        self:physics(level, dt); self:friction(level, dt)
        if t >= OUT_D and self.onGround then
            self.fleeDir = self:fleeSide(level)
            self.facing, self.fleeing = self.fleeDir, true
            self.fleeX0, self.fleeY0, self.broke = self.x, self.y, false
            self:enter('dying_flee')
        end

    elseif st == 'dying_flee' then
        -- agachado y un SALTO enorme hacia arriba sin choques (pura función del tiempo): atraviesa el techo
        local tj = t - FLEE_WIND
        if tj >= 0 then
            if tj - dt < 0 then
                Sound.play('hopJump', 0.45)
                Entity.emitFx('gp_land', self.x, self:feetY())
            end
            self.x = self.fleeX0 + self.fleeDir * FLEE_VX * tj
            self.y = self.fleeY0 + FLEE_VY * tj + 0.5 * FLEE_G * tj * tj
            self.vx, self.vy = self.fleeDir * FLEE_VX, FLEE_VY + FLEE_G * tj
            local _, _, zy0 = Boss.zoneBounds(self)
            if not self.broke and self.y - self.outerH / 2 < zy0 then           -- (rompe el techo al pasar)
                self.broke = true
                Sound.play('gpImpact', 0.6)
                Entity.emitFx('block_break', self.x - T / 2, zy0 - T)
                Entity.emitFx('shake_small', self.x, zy0)
            end
        end
        if self:fleeOver(level, dt, t, FLEE_MIN) then self.state, self.alive = 'dead', false end
    end
end

-- ── Entrada: cae de la oscuridad en su sitio, enciende el farol y se agacha ──
local FALL_AT, LAND_AT, LIGHT_AT, CROUCH_AT = 0.3, 0.9, 1.7, 2.5
GH.LAND_AT, GH.LIGHT_AT = LAND_AT, LIGHT_AT
function GH:introFocus()
    local zx0, zx1, zy0, zy1 = self:zoneBounds()
    return (zx0 + zx1) / 2, (zy0 + zy1) / 2
end
function GH:onIntroStart(level, players)
    self.introStep = 0
    self.levelRef = self.levelRef or level
end
function GH:updateIntro(dt, level, t)
    local hx, hy = self.home.x, self.home.y
    local _, _, zy0 = self:zoneBounds()
    self.x = hx
    if t < LAND_AT then
        local y0 = zy0 - self.outerH
        local u = math.max(0, (t - FALL_AT) / (LAND_AT - FALL_AT))
        self.y = (t < FALL_AT) and y0 or (y0 + (hy - y0) * u * u)
        return
    end
    self.y = hy
    if self.introStep < 1 then
        self.introStep = 1
        Sound.play('hopLand', 0.5)
        Sound.play('gpImpact', 0.6)
        Entity.emitFx('gp_land', self.x, self:feetY())
        Entity.emitFx('shake_big', self.x, self.y)
    end
    if t >= LIGHT_AT and self.introStep < 2 then self.introStep = 2; Sound.play('lightOn', 0.5) end
    if t >= CROUCH_AT and self.introStep < 3 then self.introStep = 3; Sound.play('hopWind', 0.5) end
end

-- ── Red ───────────────────────────────────────────────────────────────────────
-- { enfadado 0/1, de caza 0/1, diana x, y, nOndas, {id, x, y, dir, t·100}… }
local NB = 4
function GH:netPackExtra()
    local out = { self.rage and 1 or 0, self.hunting and 1 or 0, self.markX or 0, self.markY or 0, #self.waves }
    for _, w in ipairs(self.waves) do
        out[#out + 1] = w.id; out[#out + 1] = math.floor(w.x); out[#out + 1] = w.y
        out[#out + 1] = w.dir; out[#out + 1] = math.floor(w.t * 100)
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

function GH:netApplyExtra(a, b, f)
    if type(b[1]) ~= 'number' then return end
    self.rage, self.hunting, self.markX, self.markY = b[1] == 1, b[2] == 1, b[3], b[4]
    local prev = {}
    if type(a[NB + 1]) == 'number' then
        for _, e in ipairs(readList(a, NB + 1, 5)) do if e[1] then prev[e[1]] = e end end
    end
    self.waves = {}
    for _, e in ipairs(readList(b, NB + 1, 5)) do
        local x = e[2]
        local o = prev[e[1]]
        if o and type(o[2]) == 'number' then x = o[2] + (x - o[2]) * f end
        self.waves[#self.waves + 1] = { id = e[1], x = x, y = e[3], dir = e[4], t = e[5] / 100, hit = {} }
    end
end

-- ── Luz (src/fx/Darkness.lua): su farol, en redondo y cortado por las rocas ──
function GH:lights()
    local st, t = self.state, self.deadTimer or 0
    if st == 'dead' or (st == 'dormant' and not EDITOR_VIEW) then return nil end
    local now = love.timer.getTime()
    local r, a = LAMP_R, 0.6
    if st == 'intro' or st == 'ready' then
        local it = (st == 'ready') and (self:introTime() + t) or t
        if it < LIGHT_AT then return nil end
        local k = math.min(1, (it - LIGHT_AT) / 0.4)
        a = 0.6 * k * ((math.floor(now * 16) % 3 == 0 and it < LIGHT_AT + 0.4) and 0.3 or 1)
    elseif st == 'scared' or st == 'dying_flee' then return nil
    elseif st == 'dying_out' then
        if t > 1.2 or math.floor(now * 14) % 2 == 0 then return nil end          -- (se apaga parpadeando)
        a = 0.5 * (1 - t / 1.2)
    elseif st == 'crouch' then
        if self.hunting then a = (math.floor(now * 18) % 2 == 0) and 0.75 or 0.35 end
    elseif st == 'flare_wind' then
        local k = math.min(1, t / FLARE_WIND[self:ph()])
        r = LAMP_R * (1 + 0.35 * k)
        a = 0.6 + 0.3 * k * ((math.floor(now * (10 + 20 * k)) % 2 == 0) and 1 or 0.4)
    elseif st == 'flare' then
        r, a = FLARE_R, 0.95 * (1 - 0.5 * t / FLARE_T)
    end
    local lx, ly = self:lamp()
    return { { x = lx, y = ly, r = r, color = LAMP, a = a, pulse = 3, cast = true } }
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
-- (cuadro de su hoja, escala x/y, desvío x) según el estado
function GH:pose()
    local st, t = self.state, self.deadTimer or 0
    local now = love.timer.getTime()
    local name, sx, sy, ox = 'idle', 1, 1, 0
    if st == 'intro' or st == 'ready' then
        local it = (st == 'ready') and (self:introTime() + t) or t
        if it < LAND_AT then name = 'air'
        elseif it < LAND_AT + 0.2 then name, sx, sy = 'crouch', 1.16, 0.84
        elseif it >= CROUCH_AT and it < CROUCH_AT + 0.5 then name, sx, sy = 'crouch', 1.08, 0.92 end
    elseif st == 'crouch' then
        local k = math.min(1, t / WIND_T[self:ph()])
        name, sx, sy = 'crouch', 1 + 0.1 * k, 1 - 0.1 * k
        if self.hunting then ox = (math.floor(now * 30) % 2 == 0) and 1 or 0 end
    elseif st == 'hop' then name = 'air'
    elseif st == 'rest' and t < 0.16 then
        local k = 1 - t / 0.16
        name, sx, sy = 'crouch', 1 + 0.16 * k, 1 - 0.16 * k                -- el aplastón al caer
    elseif st == 'scared' or st == 'dying_out' then
        name, sx, sy = 'crouch', 1.08, 0.86                                  -- encogido, temblando
        ox = (math.floor(t * 20) % 2 == 0) and 1 or -1
    elseif st == 'hurt' then
        name, sx, sy = 'air', 1 - 0.08 * math.max(0, 1 - t / 0.3), 1 + 0.12 * math.max(0, 1 - t / 0.3)   -- el respingo
    elseif st == 'flare_wind' then
        local k = math.min(1, t / FLARE_WIND[self:ph()])
        sx, sy = 1 - 0.06 * k, 1 + 0.08 * k                                  -- se estira: el farol arriba
        ox = (k > 0.6 and math.floor(now * 40) % 2 == 0) and 1 or 0
    elseif st == 'flare' then sx, sy = 0.95, 1.1
    elseif st == 'dying_flee' then
        if t < FLEE_WIND then name, sx, sy = 'crouch', 1.12, 0.84 else name = 'air' end
    else
        local b = math.sin(now * 4) * 0.03                                   -- quieto: el muelle le mece
        sx, sy = 1 - b, 1 + b
    end
    return name, sx, sy, ox
end

-- ¿Dibuja aquí (render) lo que a oscuras va encima de la oscuridad (renderGlow)?
function GH:inDark() return self.levelRef ~= nil and self.levelRef.dark == true end

function GH:render(camX, camY)
    if self.state == 'dormant' and not EDITOR_VIEW then return end
    if self.state == 'dead' then return end
    local st = self.state
    local now = love.timer.getTime()
    local name, sx, sy, ox = self:pose()
    local x, feet = math.floor(self.x - camX) + ox * MS / 3, math.floor(self:feetY() - camY)
    local alpha = self:ghostAlpha()
    if st == 'dying_flee' then alpha = alpha * self:fleeAlpha(self.deadTimer) end
    local f = self.facing or 1
    local dizzy = (st == 'scared' or st == 'dying_out') and not EDITOR_VIEW
    local hx, hy = math.floor(self.x - camX), feet - 11 * MS
    if dizzy then BossFx.stars(hx, hy, 6 * MS, 1.4 * MS, 5, alpha, 'back') end
    if self:flashRed() then love.graphics.setColor(1, 0.35, 0.35, alpha)
    elseif self.rage and self:isActive() then
        local q = 0.82 + 0.1 * math.sin(now * 6)
        love.graphics.setColor(1, q, q, alpha)
    else love.graphics.setColor(1, 1, 1, alpha) end
    local set = self:anims()
    -- (el dibujo mira a la IZQUIERDA: mirando a la derecha va espejado)
    set:drawFrame(set:frameN(name, 1), x, feet, 0, -MS * f * sx, MS * sy, 0.5, 1)
    if not self:inDark() then self:drawOver(camX, camY) end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Lo que tiene que verse aunque esté oscuro: la diana, las ondas, las estrellitas de delante, el enfado
function GH:drawOver(camX, camY)
    local st = self.state
    local now = love.timer.getTime()
    if st == 'crouch' and self.hunting and not EDITOR_VIEW then
        local blink = (math.floor(now * 12) % 2 == 0) and 0.95 or 0.55
        love.graphics.setColor(1, 0.85, 0.3, blink)
        BossFx.target(now * 1.2, math.floor(self.markX - camX), math.floor(self.markY - camY - 16), 8, 8)
    end
    if waveStrip then
        love.graphics.setColor(1, 1, 1, 1)
        for _, w in ipairs(self.waves or {}) do
            local fr = math.floor((w.t or 0) * 12) % 3 + 1
            waveStrip:draw(fr, math.floor(w.x - camX), math.floor(w.y - camY) - 18, 0, 4 * w.dir, 4)    -- (centrada: los pies en el suelo)
        end
    end
    if (st == 'scared' or st == 'dying_out') and not EDITOR_VIEW then
        local feet = math.floor(self:feetY() - camY)
        BossFx.stars(math.floor(self.x - camX), feet - 11 * MS, 6 * MS, 1.4 * MS, 5, self:ghostAlpha(), 'front')
    end
    BossFx.anger(self, self.rage and self:isActive(), self.x - camX, self:feetY() - camY - 14 * MS)
    love.graphics.setColor(1, 1, 1, 1)
end

function GH:renderGlow(camX, camY)
    if self.state == 'dead' or (self.state == 'dormant' and not EDITOR_VIEW) then return end
    self:drawOver(camX, camY)
end

-- Cajas de depuración (F1): las ondas
function GH:debugBoxes()
    local out = {}
    for _, w in ipairs(self.waves or {}) do
        local b = self:waveBox(w); b.kind = 'hazard'; out[#out + 1] = b
    end
    return out
end

local G = 'Saltarín Gigante'
return {
    name = 'gianthopper', label = 'Saltarín Gigante', category = 'Jefes',
    description = 'El Saltarín de cueva en grande, A OSCURAS: solo ve la luz (tu linterna, su farol, su fogonazo) y salta '
               .. 'encima soltando ondas de roca. Un ruido fuerte cerca lo asusta: solo entonces se le puede golpear '
               .. '(pisotón 1, ground pound 2).',
    class = GH,
    boss = { title = 'SALTARÍN GIGANTE' },
    hide = Boss.HIDE,
    defaults = { points = 30 },
    props = Boss.props({ hp = 10, hpPerPlayer = 4 }, {
        { key = 'rageAt', kind = 'number', label = 'Se enfada con (fracción de vida)', group = G, default = 0.5,
          min = 0.1, max = 0.9, step = 0.05 },
    }),
    editor = { sprite = 'assets/images/enemies/hopper/cueva-Sheet.png', frameW = FW },
    -- Saltarines de la segunda fase: de reserva, los crea el nivel al cargar (Level.fromData), detrás de las entidades
    -- del JSON (mismos índices en servidor y clientes). El jefe los suelta (GH:spawnMoths).
    summons = function(pl)
        local out = {}
        for _ = 1, MOTH_POOL do
            out[#out + 1] = { type = 'hopper', col = pl.col, row = pl.row, summonKey = 'gh' .. pl.col .. ',' .. pl.row,
                              props = { skin = 'cueva', jumpEvery = 1.1, range = 12, patrol = false, points = 5 } }
        end
        return out
    end,
}
