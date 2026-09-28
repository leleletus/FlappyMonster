-- Mega Crabby: un Crabby gigante (el doble), siempre con el pincho en la
-- cabeza y dos pinzas que se abren y cierran a su aire. Nunca se esconde.
--
-- Pelea (todo configurable en el editor):
--  * Persigue por el suelo al jugador más cercano. Si lo tiene cerca, avisa
--    (se para castañeteando las pinzas) y EMBISTE. Tocarlo quita 1 de vida
--    y empuja (también su pincho de la cabeza).
--  * Cada cierto tiempo hace el ATAQUE FUERTE: va a la pared más cercana, trepa
--    hasta el techo (como los Crabbies escaladores; los bordes de su zona de
--    jefe cuentan como paredes y techo), se coloca encima del jugador, tiembla
--    un momento (una marca en el suelo avisa de dónde caerá) y se deja caer de
--    cabeza. El pincho MATA a quien pille debajo.
--  * Al caer se queda CLAVADO de cabeza, pataleando: es el ÚNICO momento en que
--    se le puede hacer daño, y solo UN golpe por caída (pisotón 1, ground
--    pound 2). Con el golpe se levanta durante su invulnerabilidad.
--  * Con poca vida (rageAt) se enfada: más rápido y menos tiempo clavado.
--  * Muerte: patalea desesperado, se desinfla en una nube de humo hasta ser un
--    Crabby normal y huye trepando por la pared.
--
-- Sprites: assets/images/MegaCrabby/ (crab1-3 como el Crabby, claw_left-Sheet
-- = pinza izquierda 7x6 abierta/cerrada; la derecha es la misma volteada;
-- spike.png = el pincho del Crabby, al doble). Sonidos: bosses/megacrabby/.

local Entity      = require 'src/world/entities/Entity'
local Boss        = require 'src/world/entities/Boss'
local Crawler     = require 'src/world/entities/Crawler'
local SpriteStrip = require 'src/fx/SpriteStrip'

local Mega = Entity.extend(Boss, {
    walkFps = 6, walkFrames = 3,
    debugColor = { 1, 0.45, 0.2 },
    -- (alto completo: apoya las patas justo en el suelo y en las paredes)
    -- (ancho del caparazón y las patas, sin las pinzas: lo que se ve de lado)
    hitbox = { outerW = 0.66, outerH = 1.0, innerW = 0.55, innerH = 0.70 },
})
Mega.hurtSound = 'megaHurt'
Mega.onEvent = nil          -- (pruebas: function(name, pa) para registrar eventos)

local MS = 10                       -- escala del pixel art (el Crabby normal usa 4: ×2,5)
local SPIKE_H  = 36 * MS / 4        -- alto del pincho (el del Crabby a la misma escala)
-- Zona de peligro del pincho = la de un pincho de tile (Level._spikeHitbox):
-- un rectángulo en la BASE, 60% del ancho y 40% del alto (sin la punta)
local SPIKE_HW = SPIKE_H * 0.6
local SPIKE_HH = SPIKE_H * 0.4
local EMBED    = 0.5                -- fracción del pincho que se clava en el suelo
local GETUP_T  = 0.45               -- s del giro al levantarse
local WIGGLE_FPS = 12
local CONTACT_PAD = 0               -- px alrededor del cuerpo que ya cuentan como tocarlo
-- Muerte
local KICK_T, SHRINK_T, FLEE_T = 1.3, 1.0, 2.6
local FLEE_SPEED = 620              -- huye en línea recta atravesándolo todo
local FLEE_FADE  = 0.8              -- s del final en que se desvanece
local SMALL = GUMMY_SCALE / MS      -- al desinflarse queda del tamaño de un Crabby normal
-- Al aterrizar tras levantarse: empuja y aturde a los de alrededor
local SHOCK_RX, SHOCK_RY = 4.5, 1.8 -- casillas
local GETUP_MAX = 3.0               -- s: si no llega a aterrizar, sigue igual
local LAND_RECOVER = 1.0            -- s quieto tras aterrizar
local LAND_GRACE   = 1.4            -- s sin dañar por contacto tras aterrizar
local CONTACT_GRACE = 1.0           -- s sin dañar por contacto tras un golpe
local WALL_ESCAPE_VX, WALL_ESCAPE_VY = 560, -900   -- rebote para salir de una pared
-- Apuntar = SEGUIR al jugador (el techo: el cangrejo se mueve encima; la
-- pared: la marca del suelo le persigue) y, al final, un instante quieto
-- temblando para poder reaccionar
local AIM_LOCK_CEIL, AIM_LOCK_WALL = 0.35, 0.3   -- s fijos antes de lanzarse
local MARKER_SPEED = 520                         -- px/s de la marca desde la pared
local SUMMON_WARN  = 1.0                         -- s de aviso (marcas) antes de que salgan

-- Pinzas: más pequeñas que el cuerpo (CLAW_K de su escala) y saliendo del
-- costado, a la altura del arranque de las patas (CLAW_X, CLAW_Y en píxeles
-- del sprite desde los pies, el punto donde se unen); se solapan CLAW_IN
-- píxeles de pinza con el cuerpo. La derecha es la izquierda volteada.
local CLAW_K, CLAW_X, CLAW_Y, CLAW_IN = 0.7, 4.6, -1.6, 1.5
local CS = MS * CLAW_K

local imgs, claw, spikeImg
function Mega.loadAssets()
    if imgs then return end
    local function load(p)
        local i = love.graphics.newImage(p)
        if i.setFilter then i:setFilter('nearest', 'nearest') end
        return i
    end
    imgs = { load('assets/images/MegaCrabby/crab1.png'), load('assets/images/MegaCrabby/crab2.png'),
             load('assets/images/MegaCrabby/crab3.png') }
    claw = SpriteStrip.load('assets/images/MegaCrabby/claw_left-Sheet.png', 7)
    spikeImg = load('assets/images/MegaCrabby/spike.png')
end
function Mega.sizePx() return 16 * MS, 9 * MS end

-- Estados en los que va pegado a una superficie (trepando)
local CRAWL = { climb = true, ceiling = true, aim = true, wallclimb = true, wallaim = true }
-- Estados en los que tocarlo quita vida
local CONTACT = { chase = true, windup = true, charge = true, recover = true, summon = true,
                  climb = true, ceiling = true, aim = true, wallclimb = true, wallaim = true }
-- (saltando desde la pared solo cuenta el aplastamiento: ver 'pounce')

-- ── Tamaño (el pequeño de la huida mide la mitad) ────────────────────────────
function Mega:setSmall(small)
    if self.small == small then return end
    self.small = small
    local k = small and SMALL or 1
    local tn = self.tuning.hitbox
    self.sprW, self.sprH = 16 * MS * k, 9 * MS * k
    self.outerW, self.outerH = self.sprW * tn.outerW, self.sprH * tn.outerH
    self.innerW, self.innerH = self.sprW * tn.innerW, self.sprH * tn.innerH
end

-- Giro de esquina a su tamaño (ver Crawler.turnDuration): más largo que el de
-- un Crabby, y frenando al doblar (TURN_SLOW) para que el dibujo no corra
Mega.turnLength, Mega.turnMax = 0.9, 0.6
local TURN_SLOW = 0.35

function Mega:initBoss()
    self.crawl, self.cattached = false, false
    self.cnx, self.cny, self.cdir = 0, -1, 1
    self.chargeCd, self.ceilT = self.props.chargeEvery or 2.5, 0
    self.pounceT, self.summonT = 0, 0
    self.travel, self.chargeDir = 0, 1
    self.landY, self.floorY, self.markerX = 0, 0, 0
    self.summonKey = 'mc' .. self.col .. ',' .. self.row
    self.hitDrop = false
    self.small = false
end

function Mega:onFightStart(n)
    self.state, self.deadTimer = 'intro', 0
    self.ceilT, self.chargeCd = 0, self.props.chargeEvery or 2.5
    -- (desfasados: los ataques especiales se van alternando)
    self.pounceT = (self.props.pounceEvery or 9) * 0.45
    self.summonT = (self.props.summonEvery or 12) * 0.3
    Sound.play('megaClack')
end

-- ── Reglas ────────────────────────────────────────────────────────────────────
function Mega:isDying()
    return self.state:sub(1, 6) == 'dying_' or self.state == 'dead' or not self.alive
end
function Mega:isVulnerable() return self.state == 'stuck' and not self.hitDrop end
-- Al huir (ya pequeño) la zona queda superada: se abren las paredes de jefe
-- y el cangrejo sale corriendo por ellas
function Mega:releasesZone() return self.state == 'dying_flee' end
function Mega:canBeKnocked() return false end

-- Enfadado (poca vida): multiplicadores
function Mega:rage()
    local p = self.props
    return (self.hpMax or 1) > 0 and self.hp / self.hpMax <= (p.rageAt or 0.5)
end
function Mega:speedMult() return self:rage() and (self.props.rageSpeed or 1.3) or 1 end

-- Trepa también por los bordes de su zona (paredes y techo invisibles)
function Mega:crawlSolidAt(level, x, y)
    if level:entitySolidAt(x, y) then return true end
    local z = self.zone
    return z ~= nil and (x < z.x0 or x > z.x1 or y < z.y0 or y > z.y1)
end

function Mega:clampToZone()
    local z = self.zone
    if not z then return end
    local hw = self.outerW / 2
    self.x = math.max(z.x0 + hw, math.min(z.x1 - hw, self.x))
end

local function inZone(z, x, y) return x >= z.x0 and x <= z.x1 and y >= z.y0 and y <= z.y1 end

-- Jugador más cercano (dentro de su zona), sin cambiar de objetivo por poco
function Mega:pickTarget(level)
    local z = self.zone
    local best, bd, cur
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false and (not z or inZone(z, pa.x, pa.y)) then
            local d = math.abs(pa.x - self.x) + math.abs(pa.y - self.y) * 0.5
            if pa == self.target then cur = d end
            if not bd or d < bd then best, bd = pa, d end
        end
    end
    if cur and cur <= bd * 1.25 then return self.target end
    self.target = best
    return best
end

-- ── Hitboxes (giradas al trepar, como el Crabby) ─────────────────────────────
function Mega:getOuterBounds()
    if self.crawl and self.cattached then
        return Crawler.poseBox(self, -self.outerW / 2, -self.outerH / 2, self.outerW, self.outerH)
    end
    return Entity.getOuterBounds(self)
end
function Mega:getInnerBounds()
    if self.crawl and self.cattached then
        return Crawler.poseBox(self, -self.innerW / 2, -self.innerH / 2, self.innerW, self.innerH)
    end
    return Entity.getInnerBounds(self)
end

-- Cayendo del techo: el pincho (hacia abajo) mata
function Mega:getHazardBoxes()
    if self.state ~= 'drop' then return nil end
    local b = self._hz or { {} }
    self._hz = b
    local box = b[1]
    box.x, box.w = self.x - SPIKE_HW / 2, SPIKE_HW
    box.y = self.y + self.sprH * 0.1                 -- media cabeza + base del pincho
    box.h = self.sprH * 0.4 + SPIKE_HH
    box.effect = 'kill'
    return b
end

function Mega:interact(pa)
    for _, hb in ipairs(self:getHazardBoxes() or {}) do
        if Boss.overlap(pa:getOuterBounds(), hb) then return 'kill' end
    end
    return Boss.interact(self, pa)
end

-- Caja local (marco de los pies) → mundo con la pose real
function Mega:footBox(lx, ly, w, h)
    return Crawler.poseBox(self, lx, ly + self.sprH / 2, w, h)
end

-- Tocarlo (cuerpo y base del pincho) quita 1 de vida y empuja.
-- Tras golpear a alguien se para un momento (no lo aplasta contra una pared).
function Mega:hitPlayers(level)
    if not CONTACT[self.state] or (self.graceT or 0) > 0 then return end
    local ob = self:getOuterBounds()
    -- (el cuerpo, sin las pinzas, y la base del pincho de la cabeza, con la
    -- caja de un pincho normal: se le puede saltar por encima)
    local boxes = {
        { x = ob.x - CONTACT_PAD, y = ob.y - CONTACT_PAD, w = ob.w + 2 * CONTACT_PAD, h = ob.h + 2 * CONTACT_PAD },
        self:footBox(-SPIKE_HW / 2, -self.sprH - SPIKE_HH, SPIKE_HW, SPIKE_HH),
    }
    self._dbgBoxes = boxes                    -- (para ver las cajas en las pruebas)
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false and (pa.hurtT or 0) <= 0 and not pa:isInvulnerable() then
            local pob = pa:getOuterBounds()
            for _, b in ipairs(boxes) do
                if Boss.overlap(pob, b) then
                    local dir = (pa.x >= self.x) and 1 or -1
                    Boss.withPlayer(pa, function() pa:hurt() end)
                    if not pa.dying then self:pushAway(level, pa, dir) end
                    self.graceT = CONTACT_GRACE           -- (no encadena golpes)
                    if self.state == 'chase' or self.state == 'charge' then
                        self.state, self.deadTimer, self.recoverFor = 'recover', 0, 0.6
                        self.chargeCd = math.max(self.chargeCd, 1.0)
                    end
                    break
                end
            end
        end
    end
end

-- Quita `n` de vida (con sus i-frames de después: n golpes seguidos)
local function hurtN(pa, n)
    if (pa.hurtT or 0) > 0 or pa:isInvulnerable() then return end
    Boss.withPlayer(pa, function()
        for i = 1, n do
            if pa.dying then break end
            pa.hurtT = 0
            if pa:hurt() then break end
        end
    end)
end

-- ¿Tiene el jugador una pared (o el borde de la zona) justo detrás, hacia `dir`?
function Mega:wallBehind(level, pa, dir)
    local b = pa:getOuterBounds()
    local px = (dir > 0) and (b.x + b.w + 14) or (b.x - 14)
    local z = self.zone
    if z and (px < z.x0 or px > z.x1) then return true end
    for _, py in ipairs({ b.y + 8, b.y + b.h / 2, b.y + b.h - 8 }) do
        if level:entitySolidAt(px, py) then return true end
    end
    return false
end

-- Empujón al tocarlo. Contra una pared no se queda atrapado: rebota en ella y
-- sale por encima del cangrejo hacia el otro lado
function Mega:pushAway(level, pa, dir)
    if pa:isHitProtected() or pa:isInvulnerable() then return end   -- (recién golpeado: nada)
    if self:wallBehind(level, pa, dir) then
        if Mega.onEvent then Mega.onEvent('escape_pared', pa) end
        pa:knockback(-dir)
        pa.vx, pa.vy = -dir * WALL_ESCAPE_VX, WALL_ESCAPE_VY
        Entity.emitFx('gp_start', pa.x + dir * 20, pa.y)
    else
        pa:knockback(dir)
    end
end

-- Aterriza (al levantarse o tras el salto desde la pared): aplasta al que
-- tenga justo debajo (`dmg` de vida) y empuja y aturde, sin daño, a los de
-- alrededor
function Mega:landShock(level, dmg)
    local ob, T = self:getOuterBounds(), TILE_PX
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false then
            local dx, dy = pa.x - self.x, pa.y - self.y
            local dir = (dx >= 0) and 1 or -1
            -- Solo le cae ENCIMA a quien está debajo de verdad (su centro por
            -- debajo del centro del cangrejo): el que está encima o al lado
            -- (p. ej. el que acaba de pisarlo) solo sale empujado
            if Boss.overlap(pa:getOuterBounds(), ob) and pa.y > self.y then
                hurtN(pa, dmg or 1)
                if not pa.dying then self:pushAway(level, pa, dir) end
            elseif Boss.overlap(pa:getOuterBounds(), ob) then
                pa:knockback(dir)
            elseif math.abs(dx) <= SHOCK_RX * T and math.abs(dy) <= SHOCK_RY * T then
                pa:knockback(dir)
            end
        end
    end
    Sound.play('megaSlam', 0.75)
    Entity.emitFx('mega_land', self.x, ob.y + ob.h)
    Entity.emitFx('shake_big', self.x, ob.y + ob.h)
end

-- ── Update ────────────────────────────────────────────────────────────────────
local function sign(v) return v > 0 and 1 or (v < 0 and -1 or 0) end

-- Anda por el suelo (sin trepar): gravedad, choque con el nivel y su zona
function Mega:walk(level, dt, vx)
    self.vy = self.vy + ADV_GRAVITY * dt
    local x0 = self.x
    self:moveAndCollide(level, vx * dt, self.vy * dt)
    self:clampToZone()
    return self.x - x0
end

-- Animación de andar + pisadas pesadas
function Mega:animWalk(dt, fps, silent)
    self.animT = self.animT + dt
    if self.animT >= 1 / fps then
        self.animT = self.animT - 1 / fps
        self.frame = self.frame % 3 + 1
        if not silent and (self.frame == 1 or self.frame == 3) and (self.onGround or self.cattached) then
            Sound.play('megaStep', 0.9 + math.random() * 0.2)
        end
    end
end

function Mega:startClimb(level, state)
    local z = self.zone
    self.crawl, self.cnx, self.cny, self.cattached = true, 0, -1, false
    if not Crawler.attach(self, level) then self.crawl = false; return false end
    -- Hacia la pared (o borde de la zona) más cercana; para saltar desde la
    -- pared, la del lado CONTRARIO al jugador (así se lanza cruzando hacia él)
    local tgt = (state == 'wallclimb') and self.target
    if z and tgt then self.cdir = (tgt.x - z.x0 < z.x1 - tgt.x) and 1 or -1
    elseif z then self.cdir = (self.x - z.x0 < z.x1 - self.x) and -1 or 1
    else self.cdir = self.facing end
    self.state, self.deadTimer = state or 'climb', 0
    self.climbFloorY = self.y + self.outerH / 2
    Sound.play('megaClack', 0.9)
    return true
end

-- No llegó al techo (sin paredes a las que agarrarse...): suelta y sigue
function Mega:abortClimb()
    Crawler.detach(self)
    self.crawl, self.flipped, self.vy = false, false, 0
    self.state, self.deadTimer = 'chase', 0
end

-- Orientación al trepar (como el Crabby)
function Mega:crawlFacing()
    if self.cnx ~= 0 then self.facing = self.cdir
    else self.facing = ((-self.cny * self.cdir) >= 0) and 1 or -1 end
end

-- x del objetivo ahora (sin salirse de la zona)
function Mega:targetX(level)
    local tgt = self:pickTarget(level)
    if not tgt then return self.x end
    local z, hw = self.zone, self.outerW / 2
    local x = tgt.x
    if z then x = math.max(z.x0 + hw, math.min(z.x1 - hw, x)) end
    return x
end

-- Suelo que hay debajo de x (la marca de dónde caerá)
function Mega:floorBelow(level, x, fromY)
    local floorLine = self.zone and self.zone.y1 or level.heightPx
    local hit, top = level:landingCross(x, fromY, floorLine)
    return hit and top or floorLine
end

-- Súbditos: los Crabbies de reserva que el nivel crea para él (ver `summons`)
function Mega:minions(level)
    local out = {}
    for _, e in ipairs(level.liveEntities or {}) do
        if e.summonOf == self.summonKey then out[#out + 1] = e end
    end
    return out
end

-- ¿Cuántos puede invocar ahora? (libres en la reserva, sin pasar del máximo)
function Mega:summonable(level)
    local p = self.props
    local free, active = {}, 0
    for _, e in ipairs(self:minions(level)) do
        if e.alive then active = active + 1 else free[#free + 1] = e end
    end
    return math.min(#free, p.summonCount or 2, math.max(0, (p.summonMax or 3) - active)), free
end

-- Dónde sale el súbdito i (a los lados, alternando). Solo depende de su x y
-- de i: el cliente dibuja las marcas en el mismo sitio
function Mega:summonSpot(i)
    local T = TILE_PX
    local dir = (i % 2 == 1) and -1 or 1
    local x = self.x + dir * (self.sprW * 0.5 + 24 + math.floor((i - 1) / 2) * T)
    if self.zone then x = math.max(self.zone.x0 + T, math.min(self.zone.x1 - T, x)) end
    return x, dir
end

function Mega:summonMinions(level)
    local n, free = self:summonable(level)
    n = math.min(n, self.summonN or n)
    local floorY = self.y + self.outerH / 2
    for i = 1, n do
        local e = free[i]
        local x, dir = self:summonSpot(i)
        local h = e.home
        h.x, h.y, h.facing, h.flipped, h.state = x, floorY - e.outerH / 2, dir, false, 'walk'
        h.vx = e.speed * dir
        e:resetToHome()
        e.state, e.deadTimer = 'spawning', 0
        e.leashZone = self.zone
        Entity.emitFx('spawn', x, floorY - e.outerH / 2)
        Entity.emitFx('mega_step', x, floorY)
    end
    if n > 0 then Sound.play('respawnFx', 0.8) end
end

function Mega:startPounce()
    -- De la caja girada (en la pared) a la de pie, más ancha: se separa de la
    -- pared lo justo para no quedar metido en ella
    local nx = self.cnx or 0
    if nx ~= 0 then self.x = self.x - nx * self.outerH / 2 + nx * (self.outerW / 2 + 2) end
    Crawler.detach(self)
    self.crawl, self.flipped = false, false
    local x0, y0 = self.x, self.y
    local tx, ty = self.markerX, self.landY - self.outerH / 2
    local T, g = self.props.pounceTime or 0.9, ADV_GRAVITY
    self.vx = (tx - x0) / T
    self.vy = (ty - y0 - 0.5 * g * T * T) / T
    self.facing = (self.vx >= 0) and 1 or -1
    self.speed = 0                        -- (al chocar con algo de lado, se para)
    self.crushed = {}
    self.state, self.deadTimer = 'pounce', 0
    Sound.play('megaWindup', 1.25)
    Sound.play('megaClack', 1.1)
end

function Mega:startGetup()
    self.state, self.deadTimer = 'getup', 0
    self.vy, self.onGround, self.flipped = -480, false, false
    Sound.play('crabPop', 0.7)
    Entity.emitFx('spike_pop', self.x, self.floorY - 8)
end

function Mega:updateBoss(dt, level)
    local p, T = self.props, TILE_PX
    Crawler.advanceTurn(self, dt)
    if (self.graceT or 0) > 0 then self.graceT = math.max(0, self.graceT - dt) end
    local st = self.state
    self.deadTimer = self.deadTimer + dt
    local t = self.deadTimer
    local k = self:speedMult()

    if st == 'dormant' then
        self:walk(level, dt, 0)
        return
    elseif st == 'intro' then
        -- Se presenta: castañetea las pinzas
        self:walk(level, dt, 0)
        if t >= 1.0 then self.state, self.deadTimer = 'chase', 0 end
    elseif st == 'chase' then
        local tgt = self:pickTarget(level)
        local dx = tgt and (tgt.x - self.x) or 0
        local dir = (math.abs(dx) > 20) and sign(dx) or 0
        if dir ~= 0 then self.facing = dir end
        self:walk(level, dt, dir * (p.chaseSpeed or 150) * k)
        if dir ~= 0 then self:animWalk(dt, self.tuning.walkFps * k) end
        self.chargeCd = self.chargeCd - dt
        self.ceilT = self.ceilT + dt
        self.pounceT = self.pounceT + dt
        self.summonT = self.summonT + dt
        local summonsOn = (p.summonCount or 2) > 0 and (p.summonPool or 4) > 0
        if self.onGround and self.ceilT >= (p.ceilingEvery or 7) then
            if self:startClimb(level) then self.ceilT = 0 else self.ceilT = 0 end
        elseif self.onGround and (p.pounceEvery or 9) > 0 and self.pounceT >= (p.pounceEvery or 9) then
            self.pounceT = 0
            self:startClimb(level, 'wallclimb')
        elseif self.onGround and summonsOn and self.summonT >= (p.summonEvery or 12) then
            -- Solo si puede sacar alguno (con el máximo vivo no lo intenta:
            -- lo vuelve a mirar un poco después)
            local n = self:summonable(level)
            if n > 0 then
                self.summonT, self.summonN = 0, n
                self.state, self.deadTimer, self.summoned = 'summon', 0, false
                Sound.play('megaWindup', 0.8)
                Sound.play('megaClack', 0.7)
            else
                self.summonT = (p.summonEvery or 12) * 0.8
            end
        elseif self.onGround and tgt and self.chargeCd <= 0 and math.abs(dx) <= (p.chargeRange or 5) * T
               and math.abs(tgt.y - self.y) <= 1.5 * T then
            self.state, self.deadTimer = 'windup', 0
            self.facing = sign(dx) ~= 0 and sign(dx) or self.facing
            Sound.play('megaWindup')
        end
    elseif st == 'windup' then
        -- Aviso: quieto, castañeteando, mirando al jugador
        self:walk(level, dt, 0)
        if t >= (p.windupTime or 0.6) / k then
            self.state, self.deadTimer = 'charge', 0
            self.chargeDir, self.travel = self.facing, 0
            Entity.emitFx('gp_start', self.x - self.facing * self.sprW * 0.4, self.y + self.outerH / 2)
        end
    elseif st == 'charge' then
        local want = self.chargeDir * (p.chargeSpeed or 520) * k
        local moved = self:walk(level, dt, want)
        self.facing = self.chargeDir
        self.travel = self.travel + math.abs(moved)
        self:animWalk(dt, self.tuning.walkFps * 2 * k)
        local blocked = math.abs(moved) < math.abs(want * dt) * 0.5
        if blocked or self.travel >= (p.chargeDist or 8) * T then
            self.state, self.deadTimer = 'recover', 0
            self.recoverFor = blocked and 0.9 or 0.45
            self.chargeCd = (p.chargeEvery or 2.5) / k
            if blocked then
                Sound.play('gpImpact', 0.7)
                Entity.emitFx('mega_land', self.x + self.chargeDir * self.sprW * 0.45, self.y + self.outerH / 2)
                Entity.emitFx('shake_small', self.x, self.y)
            end
        end
    elseif st == 'recover' then
        self:walk(level, dt, 0)
        if t >= (self.recoverFor or 0.5) then self.state, self.deadTimer = 'chase', 0 end
    elseif st == 'climb' then
        -- A la pared más cercana y hasta el techo
        self.speed = (p.climbSpeed or 280) * k
        local slow = Crawler.turning(self) and TURN_SLOW or 1
        if not Crawler.move(self, level, self.speed * slow * dt) then return self:abortClimb() end
        self:crawlFacing()
        self:animWalk(dt, self.tuning.walkFps * 1.5 * k)
        if self.cny == 1 and not Crawler.turning(self) then
            self.state, self.deadTimer = 'ceiling', 0
        elseif t > (p.climbMax or 6) then
            return self:abortClimb()
        end
    elseif st == 'ceiling' then
        -- Por el techo hasta ponerse encima del jugador
        local dx = self:targetX(level) - self.x
        local dir = sign(dx)
        local ahead = self.x + dir * (self.sprW * 0.45 + 6)
        if math.abs(dx) <= 10 or t > (p.ceilingMax or 3) or self:crawlSolidAt(level, ahead, self.y) then
            self:startAim(level)
        else
            self.cdir = -dir                              -- (en el techo, avanzar = -cdir)
            self.speed = (p.climbSpeed or 280) * k
            local slow = Crawler.turning(self) and TURN_SLOW or 1
            if not Crawler.move(self, level, math.min(math.abs(dx), self.speed * slow * dt)) then
                return self:abortClimb()
            end
            self:crawlFacing()
            self:animWalk(dt, self.tuning.walkFps * 1.5 * k)
        end
    elseif st == 'aim' then
        -- Tiembla en el techo (la marca del suelo avisa) y se deja caer. La
        -- primera parte del aviso sigue al jugador (adelantándose a dónde
        -- irá); la última, ya fijo
        local aimFor = (p.aimTime or 1.8) / k
        if t < aimFor - AIM_LOCK_CEIL then
            -- Le sigue por el techo (la marca va debajo)
            local dx = self:targetX(level) - self.x
            local dir = sign(dx)
            local ahead = self.x + dir * (self.sprW * 0.45 + 6)
            if math.abs(dx) > 4 and not self:crawlSolidAt(level, ahead, self.y) then
                self.cdir = -dir
                self.speed = (p.climbSpeed or 280) * k
                Crawler.move(self, level, math.min(math.abs(dx), self.speed * (p.trackSpeed or 1.0) * dt))
                self:crawlFacing()
                self:animWalk(dt, self.tuning.walkFps * 1.5 * k)
            end
        end
        self.markerX = self.x
        self.landY = self:floorBelow(level, self.x, self.y + self.sprH / 2 + SPIKE_H)
        if t >= aimFor then
            Crawler.detach(self)
            self.crawl, self.flipped = false, true             -- boca abajo: el pincho hacia abajo
            self.state, self.deadTimer, self.vy = 'drop', 0, 0
        end
    elseif st == 'summon' then
        -- Invoca súbditos: se alza castañeteando y salen de debajo
        self:walk(level, dt, 0)
        -- (antes, SUMMON_WARN s con las marcas de dónde saldrán)
        if not self.summoned and t >= SUMMON_WARN then self.summoned = true; self:summonMinions(level) end
        if t >= SUMMON_WARN + 0.5 then self.state, self.deadTimer = 'chase', 0 end
    elseif st == 'wallclimb' then
        -- A la pared más cercana y hasta media altura
        self.speed = (p.climbSpeed or 280) * k
        local slow = Crawler.turning(self) and TURN_SLOW or 1
        if not Crawler.move(self, level, self.speed * slow * dt) then return self:abortClimb() end
        self:crawlFacing()
        self:animWalk(dt, self.tuning.walkFps * 1.5 * k)
        local high = (self.climbFloorY or self.y) - self.y
        if not Crawler.turning(self) and self.cnx ~= 0 and high >= (p.pounceHeight or 3) * T then
            self.state, self.deadTimer, self.markerSet = 'wallaim', 0, false
            Sound.play('megaClack', 0.8)
        elseif self.cny == 1 and not Crawler.turning(self) then
            self.state, self.deadTimer, self.markerSet = 'wallaim', 0, false   -- (zona baja: salta desde el techo)
        elseif t > (p.climbMax or 6) then
            return self:abortClimb()
        end
    elseif st == 'wallaim' then
        -- Agarrado a la pared apuntando (marca en el suelo), y salta
        local aimFor = (p.pounceAim or 1.4) / k
        if self.markerX == 0 or not self.markerSet then
            self.markerX, self.markerSet = self:targetX(level), true     -- (empieza en el jugador)
        end
        if t < aimFor - AIM_LOCK_WALL then
            -- La marca del suelo persigue al jugador
            local dx = self:targetX(level) - self.markerX
            local step = MARKER_SPEED * k * dt
            self.markerX = self.markerX + math.max(-step, math.min(step, dx))
        end
        self.landY = self:floorBelow(level, self.markerX, self.y)
        if t >= aimFor then self:startPounce() end
    elseif st == 'pounce' then
        -- En el aire (sin caer de cabeza: después no queda vulnerable).
        -- Aplasta a quien le caiga encima: pounceDamage de vida
        self.vy = self.vy + ADV_GRAVITY * dt
        self:moveAndCollide(level, self.vx * dt, self.vy * dt)
        self:clampToZone()
        if self.vy > 0 then
            local ob = self:getOuterBounds()
            for _, pa in ipairs(level.players or {}) do
                if not pa.dying and pa.alive ~= false and not self.crushed[pa] and pa.y > self.y
                   and Boss.overlap(pa:getOuterBounds(), ob) then
                    self.crushed[pa] = true
                    if Mega.onEvent then Mega.onEvent('aplasta', pa) end
                    hurtN(pa, p.pounceDamage or 2)
                    if not pa.dying then self:pushAway(level, pa, (pa.x >= self.x) and 1 or -1) end
                end
            end
        end
        if (self.onGround and t > 0.1) or t > 3 then
            self.speed = 0
            self.state, self.deadTimer, self.recoverFor = 'recover', 0, LAND_RECOVER
            self.graceT = LAND_GRACE
            self.chargeCd = math.max(self.chargeCd, 1.2)
            self:landShock(level, p.pounceDamage or 2)
        end
    elseif st == 'drop' then
        self.vy = math.min(self.vy + ADV_GRAVITY * 1.4 * dt, p.dropSpeed or 1600)
        local tip0 = self.y + self.sprH / 2 + SPIKE_H
        self.y = self.y + self.vy * dt
        local tip = self.y + self.sprH / 2 + SPIKE_H
        local floorLine = self.zone and self.zone.y1 or level.heightPx
        local hit, top = level:landingCross(self.x, tip0, tip)
        if not hit and tip >= floorLine then hit, top = true, floorLine end
        if hit then
            self.y = top + SPIKE_H * EMBED - SPIKE_H - self.sprH / 2
            self.floorY = top
            self.state, self.deadTimer, self.vy = 'stuck', 0, 0
            self.hitDrop = false
            Sound.play('megaSlam')
            Entity.emitFx('mega_slam', self.x, top)
            Entity.emitFx('spike_land', self.x, top)
            Entity.emitFx('shake_big', self.x, top)
        elseif self.y > level.heightPx + T * 4 then
            -- (se salió del nivel: vuelve a su sitio)
            self.x, self.y, self.flipped, self.vy = self.home.x, self.home.y, false, 0
            self.state, self.deadTimer = 'chase', 0
        end
    elseif st == 'stuck' then
        -- Clavado de cabeza, pataleando: vulnerable (un golpe)
        local stuckFor = (p.stuckTime or 3) * ((self:rage() and (p.rageStuck or 0.75)) or 1)
        if t >= stuckFor then self:startGetup() end
    elseif st == 'getup' then
        self.vy = self.vy + ADV_GRAVITY * dt
        self:moveAndCollide(level, 0, self.vy * dt)
        self:clampToZone()
        if (self.onGround and t >= GETUP_T * 0.6) or t >= GETUP_MAX then
            -- Se recupera un momento sin dañar por contacto: los empujados
            -- (aturdidos GP_STUN) tienen tiempo de reponerse y apartarse
            self.state, self.deadTimer, self.recoverFor = 'recover', 0, LAND_RECOVER
            self.graceT = LAND_GRACE
            self.chargeCd, self.ceilT = math.max(self.chargeCd, 1.5), 0
            self:landShock(level)
        end
    end
    self:hitPlayers(level)
end

function Mega:startAim(level)
    self.state, self.deadTimer = 'aim', 0
    -- Dónde caerá (la marca del suelo): lo primero que cruce el pincho
    local tip = self.y + self.sprH / 2 + SPIKE_H
    local floorLine = self.zone and self.zone.y1 or level.heightPx
    local hit, top = level:landingCross(self.x, tip, floorLine)
    self.landY = hit and top or floorLine
    self.markerX = self.x
    Sound.play('spikeShake', 0.7)
    Sound.play('megaClack', 0.8)
end

function Mega:onDamaged(n, kind)
    self.hitDrop = true                   -- un solo golpe por caída
    self:startGetup()
end

-- ── Muerte: patalea, se desinfla y huye ──────────────────────────────────────
function Mega:onDefeat()
    self.state, self.deadTimer = 'dying_kick', 0
    self.nextSqueak = 0
    self.defeatedMinions = false
end

function Mega:update(dt, level)
    if self.state:sub(1, 6) == 'dying_' then return self:updateDeath(dt, level) end
    return Boss.update(self, dt, level)
end

function Mega:updateDeath(dt, level)
    self.deadTimer = self.deadTimer + dt
    local st, t = self.state, self.deadTimer
    if st == 'dying_kick' then
        -- Sus súbditos desaparecen con él
        if not self.defeatedMinions then
            self.defeatedMinions = true
            for _, e in ipairs(self:minions(level)) do
                if e.alive and e.state ~= 'dead' then
                    e.state, e.deadTimer, e.vx, e.vy = 'dead', 0, 0, 0
                    if e.onStomp then e:onStomp() end
                    Entity.emitFx('smoke', e.x, e.y)
                    Entity.emitFx('spawn', e.x, e.y)
                end
            end
        end
        if t >= self.nextSqueak then
            self.nextSqueak = t + 0.28
            Sound.play('megaClack', 0.9 + math.random() * 0.4)
        end
        if t >= KICK_T then
            self.state, self.deadTimer = 'dying_shrink', 0
            Sound.play('megaShrink')
            Entity.emitFx('spike_pop', self.x, self.floorY - 8)
            Entity.emitFx('mega_poof', self.x, self.y)
        end
    elseif st == 'dying_shrink' then
        if t >= SHRINK_T then
            -- Ya es un Crabby normal (sin pinzas): huye por el lado más cercano
            -- de la zona (sus paredes ya desaparecen), atravesándolo todo
            self:setSmall(true)
            self.flipped, self.vy, self.crawl = false, 0, false
            self.y = self.floorY - self.outerH / 2
            local z = self.zone
            self.facing = (z and (self.x - z.x0 < z.x1 - self.x)) and -1 or 1
            self.state, self.deadTimer, self.nextSqueak = 'dying_flee', 0, 0
        end
    elseif st == 'dying_flee' then
        self.x = self.x + self.facing * FLEE_SPEED * dt
        self:animWalk(dt, 16, true)                    -- (ya no pisa fuerte)
        if t >= self.nextSqueak then
            self.nextSqueak = t + 0.45
            Sound.play('megaFlee', 0.9 + math.random() * 0.25)
        end
        if t >= FLEE_T then self.state, self.alive = 'dead', false end
    end
end

-- ── Red ───────────────────────────────────────────────────────────────────────
function Mega:netPackExtra()
    local surf, turn = Crawler.netPack(self)
    return { surf, turn, math.floor(self.landY + 0.5), math.floor(self.floorY + 0.5), self.hitDrop and 1 or 0,
             math.floor(self.markerX + 0.5), self.summonN or 0 }
end

function Mega:netApplyExtra(a, b, f)
    a = a or b
    self:setSmall(self.state == 'dying_flee')
    Crawler.netApply(self, b[1], a[2], b[2], f, not CRAWL[self.state])
    if not CRAWL[self.state] then self.crawl = false end
    self.landY = tonumber(b[3]) or 0
    self.floorY = tonumber(b[4]) or 0
    self.hitDrop = b[5] == 1
    self.markerX = tonumber(b[6]) or self.x
    self.summonN = tonumber(b[7]) or 0
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
-- Todo lo "secundario" (squash & stretch, balanceo de pinzas, forcejeo,
-- partículas continuas) sale del estado y su tiempo (deadTimer), que llegan
-- por red: se ve igual en un jugador y online. Nada de esto toca la física.
local Particles
local TAU = math.pi * 2

local function spring(t, amp, freq, damp) return amp * math.exp(-t * damp) * math.cos(t * freq) end

-- Pinzas: cada una se cierra y abre sola cada cierto tiempo (más a menudo
-- cuando está nervioso). Solo es dibujo (cada cliente a su aire).
local function clawFrame(self, i, now, nervous)
    self._claws = self._claws or { { next = now + math.random() }, { next = now + math.random() } }
    local c = self._claws[i]
    if now >= c.next then
        c.closedUntil = now + 0.12
        c.next = now + (nervous and (0.12 + math.random() * 0.3) or (0.7 + math.random() * 1.8))
    end
    return (c.closedUntil and now < c.closedUntil) and 2 or 1
end

-- Deformación del cuerpo (sx, sy desde los pies), temblor y balanceo de las
-- pinzas (en píxeles de pinza) según lo que esté haciendo
function Mega:pose2d(now, moving, walkPhase)
    local st, t = self.state, self.deadTimer or 0
    local sx, sy, shx = 1, 1, 0
    local claws = { { 0, 0 }, { 0, 0 } }                 -- izquierda, derecha: dx, dy
    local function swing(amp, speed, spread)
        for i, side in ipairs({ -1, 1 }) do
            local ph = (i == 1) and 0 or 1.9
            claws[i][2] = math.sin(now * speed + ph) * amp
            claws[i][1] = side * (spread or 0)
        end
    end
    local breath = math.sin(now * 3)
    if st == 'dormant' or st == 'recover' or ((st == 'chase' or st == 'intro') and not moving) then
        sy, sx = 1 + 0.025 * breath, 1 - 0.015 * breath
        swing(0.8, 2.1)
    end
    if (st == 'chase' or st == 'climb' or st == 'ceiling' or st == 'wallclimb' or st == 'charge') and moving then
        -- Andando: rebota con cada paso y las pinzas se mecen a contrapaso
        local b = math.sin(walkPhase * TAU)
        sy, sx = 1 + 0.045 * b, 1 - 0.03 * b
        for i, side in ipairs({ -1, 1 }) do
            local w = walkPhase * TAU + (i == 1 and 0 or math.pi)
            claws[i][1], claws[i][2] = math.cos(w) * 0.6, math.sin(w) * 1.3
        end
    end
    if (st == 'chase' or st == 'recover') and t < 0.6 and (self._prevState == 'getup' or self._prevState == 'pounce') then
        -- Aterriza del salto: se aplasta y rebota
        local q = spring(t, 0.24, 20, 7)
        sx, sy = sx * (1 + q), sy * (1 - q)
    elseif st == 'summon' then
        -- Invoca: se alza con las pinzas arriba, castañeteando
        local up = math.sin(math.min(1, t / 0.45) * math.pi * 0.5)
        sx, sy = 1 - 0.08 * up, 1 + 0.14 * up
        for i, side in ipairs({ -1, 1 }) do
            claws[i][1] = side * 0.8 * up
            claws[i][2] = -3.0 * up + math.sin(now * 30 + i) * 0.5
        end
    elseif st == 'wallaim' then
        -- En la pared, a punto de saltar: encogido, pinzas arriba temblando
        local k = math.min(1, t / 0.5)
        sx, sy = 1 + 0.08 * k, 1 - 0.12 * k
        for i, side in ipairs({ -1, 1 }) do
            claws[i][1] = side * 0.5
            claws[i][2] = -2 * k + math.sin(now * 38 + i * 2) * 0.5
        end
    elseif st == 'pounce' then
        -- Saltando: estirado, pinzas por delante
        sx, sy = 0.9, 1.14
        for i = 1, 2 do claws[i][1] = self.facing * 1.0; claws[i][2] = -1.4 end
    elseif st == 'intro' then
        local q = 0.09 * math.abs(math.sin(t * 9)) * math.max(0, 1 - t)
        sx, sy = 1 - q * 0.5, 1 + q
        for i = 1, 2 do claws[i][2] = -1.6 - math.abs(math.sin(t * 9 + i)) * 1.2 end
    elseif st == 'windup' then
        -- Anticipación: se agacha y levanta las pinzas temblando
        local k = math.min(1, t / math.max(0.1, self.props.windupTime or 0.6))
        sx, sy = 1 + 0.10 * k, 1 - 0.14 * k
        for i, side in ipairs({ -1, 1 }) do
            claws[i][1] = side * 0.6 * k
            claws[i][2] = -2.2 * k + math.sin(now * 42 + i) * 0.4
        end
    elseif st == 'charge' then
        -- Lanzado: estirado hacia delante, pinzas por delante
        local q = spring(t, 0.10, 16, 6)
        sx, sy = sx * (1.10 - q), sy * (0.93 + q)
        for i = 1, 2 do claws[i][1] = claws[i][1] + self.facing * 1.2; claws[i][2] = claws[i][2] - 0.6 end
    elseif st == 'recover' then
        local q = spring(t, -0.10, 18, 6)
        sx, sy = sx * (1 + q), sy * (1 - q)
    elseif st == 'aim' then
        -- Colgado, a punto de caer: vibra y abre las pinzas
        sx, sy = 1 + 0.03 * math.sin(now * 30), 1 - 0.03 * math.sin(now * 30)
        for i, side in ipairs({ -1, 1 }) do
            claws[i][1] = side * 0.8
            claws[i][2] = math.sin(now * 20 + i * 2) * 1.2
        end
    elseif st == 'drop' then
        -- Cayendo de cabeza: estirado, pinzas echadas hacia atrás (los pies)
        sx, sy = 0.88, 1.18
        for i = 1, 2 do claws[i][2] = 1.6 end
    elseif st == 'stuck' or st == 'dying_kick' then
        -- Clavado: aplastado por el golpe y luego forcejeando (como el Crabby)
        local q = spring(t, 0.28, 22, 7)
        local fury = (st == 'dying_kick') and 1.8 or 1
        sx, sy = 1 + q + 0.04 * math.sin(now * 13) * fury, 1 - q - 0.04 * math.sin(now * 13) * fury
        if t > 0.3 then shx = math.floor(math.sin(now * 45) * 2 * fury * MS / 4) end
        for i = 1, 2 do
            claws[i][1] = math.cos(now * 17 * fury + i * 2.3) * 1.0
            claws[i][2] = math.sin(now * 22 * fury + i * 3.1) * 2.0
        end
    elseif st == 'getup' then
        local k = math.min(1, t / GETUP_T)
        sy, sx = 1 + 0.12 * math.sin(k * math.pi), 1 - 0.08 * math.sin(k * math.pi)
        for i = 1, 2 do claws[i][2] = -1.5 * math.sin(k * math.pi) end
    end
    return sx, sy, shx, claws
end

-- Dibuja el cangrejo "como en el suelo" con los pies en (px, py) de pantalla,
-- girado `ang`, a escala de píxel `s`, deformado (sx, sy) desde los pies
function Mega:drawLocal(px, py, ang, s, img, withSpike, alpha, nervous, sx, sy, claws, noClaws)
    local now = love.timer.getTime()
    local red = self:flashRed()
    if red then love.graphics.setColor(1, 0.3, 0.3, alpha) else love.graphics.setColor(1, 1, 1, alpha) end
    love.graphics.push()
    love.graphics.translate(px, py)
    love.graphics.rotate(ang)
    love.graphics.scale(sx or 1, sy or 1)
    local ih = img:getHeight()
    local cs = s * CLAW_K
    if withSpike then                             -- detrás del cuerpo, sobre la cabeza
        love.graphics.draw(spikeImg, 0, -ih * s, 0, s / 4, s / 4, spikeImg:getWidth() / 2, spikeImg:getHeight() - 1)
    end
    love.graphics.draw(img, 0, 0, 0, s * self.facing, s, img:getWidth() / 2, ih)
    -- Pinzas delante del cuerpo, saliendo del costado junto a las patas
    for i, side in ipairs(noClaws and {} or { -1, 1 }) do
        local off = claws and claws[i] or { 0, 0 }
        local cx = side * (CLAW_X * s + 7 * cs / 2 - CLAW_IN * cs) + math.floor(off[1] * cs + 0.5)
        local cy = CLAW_Y * s - 6 * cs / 2 + math.floor(off[2] * cs + 0.5)
        claw:draw(clawFrame(self, i, now, nervous), cx, cy, 0, -side * cs, cs)
    end
    love.graphics.pop()
end

-- Marca en el suelo de donde va a caer (parpadea)
local function drawTarget(x, y, w, t, col)
    local on = math.floor(t * 8) % 2 == 0
    col = col or { 1, 0.2, 0.2 }
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle('fill', x - w / 2, y - 6, w, 6)
    love.graphics.setColor(col[1], col[2], col[3], on and 0.9 or 0.45)
    local seg = math.floor(w / 6)
    for i = 0, 5, 2 do love.graphics.rectangle('fill', x - w / 2 + i * seg, y - 4, seg, 4) end
end

-- Partículas continuas (solo dibujo): pisadas, estela, piedrecitas, tierra
local STEP_DIST = 7 * MS
function Mega:renderFx(now, fx, fy, moved)
    if EDITOR_VIEW then return end
    Particles = Particles or require 'src/fx/Particles'
    local st = self.state
    local f = self._fx or { acc = 0, t = 0, foot = 1 }
    self._fx = f
    local walking = st == 'chase' or st == 'charge'
    local crawling = st == 'climb' or st == 'ceiling' or st == 'wallclimb'
    if (walking or crawling) and moved > 0 then
        f.acc = f.acc + moved
        if f.acc >= STEP_DIST then
            f.acc, f.foot = 0, -f.foot
            if walking then Particles.emit('mega_step', fx + f.foot * self.sprW * 0.3, fy)
            else Particles.emit('mega_debris', fx, fy) end
        end
    end
    local every = (st == 'charge') and 0.04 or (st == 'stuck' or st == 'dying_kick') and 0.16
                  or (st == 'aim' or st == 'wallaim') and 0.12 or (st == 'windup') and 0.09 or nil
    if every and now - f.t >= every then
        f.t = now
        if st == 'charge' then Particles.emit('mega_trail', fx - self.facing * self.sprW * 0.3, fy, { dir = self.facing })
        elseif st == 'windup' then Particles.emit('mega_trail', fx - self.facing * self.sprW * 0.35, fy, { dir = -self.facing })
        elseif st == 'aim' or st == 'wallaim' then Particles.emit('mega_debris', fx + (math.random() - 0.5) * self.sprW * 0.6, fy)
        else Particles.emit('mega_dirt', self.x + (math.random() - 0.5) * SPIKE_HW, self.floorY) end
    end
end

function Mega:render(camX, camY)
    local st, t = self.state, self.deadTimer or 0
    local now = love.timer.getTime()
    local s, alpha = MS, 1
    local nervous = st == 'windup' or st == 'aim' or st == 'stuck' or st == 'dying_kick' or st == 'intro'
                    or st == 'charge' or st == 'summon' or st == 'wallaim' or st == 'pounce'
    if self._rstate ~= st then self._prevState, self._rstate = self._rstate, st end

    -- ¿Se mueve? (para el paso y el balanceo): lo que avanzó desde el dibujo anterior
    local moved = self._lx and math.sqrt((self.x - self._lx) ^ 2 + (self.y - self._ly) ^ 2) or 0
    self._lx, self._ly = self.x, self.y
    self._dist = (self._dist or 0) + moved
    local walkPhase = self._dist / (STEP_DIST * 2)
    local moving = moved > 0.05

    -- Sprite: andar, o patalear clavado
    local frame = self.frame or 1
    if st == 'stuck' or st == 'dying_kick' then
        frame = math.floor(t * (st == 'dying_kick' and WIGGLE_FPS * 2 or WIGGLE_FPS)) % 3 + 1
    elseif not moving and (st == 'dormant' or st == 'windup' or st == 'aim' or st == 'recover' or st == 'chase'
                           or st == 'intro' or st == 'summon' or st == 'wallaim') then
        frame = 2
    end
    local img = imgs[frame] or imgs[2]
    local withSpike = true

    -- Temblor (aviso de embestida, a punto de caer, pataleo final)
    local jx, jy = 0, 0
    -- (apuntando: solo al final, cuando ya se ha fijado y va a lanzarse)
    local k = self:speedMult()
    local locked = (st == 'aim' and t >= (self.props.aimTime or 1.8) / k - AIM_LOCK_CEIL)
                or (st == 'wallaim' and t >= (self.props.pounceAim or 1.4) / k - AIM_LOCK_WALL)
    if st == 'windup' or locked or st == 'dying_kick' then
        jx = math.floor(math.sin(now * 70) * 3)
        jy = math.floor(math.cos(now * 55) * 2)
    end

    if st == 'summon' and t < SUMMON_WARN and not EDITOR_VIEW then
        -- Dónde van a salir los súbditos (marca amarilla y tierra que burbujea)
        local fy0 = self.y + self.outerH / 2
        for i = 1, (self.summonN or 0) do
            local x = self:summonSpot(i)
            drawTarget(math.floor(x - camX), math.floor(fy0 - camY), TILE_PX, now, { 1, 0.85, 0.2 })
            self._sfx = self._sfx or {}
            if now - (self._sfx[i] or 0) > 0.15 then
                self._sfx[i] = now
                Particles = Particles or require 'src/fx/Particles'
                Particles.emit('mega_dirt', x, fy0)
            end
        end
    end
    if (st == 'aim' or st == 'wallaim') and not EDITOR_VIEW then
        local mx = (st == 'aim') and self.x or self.markerX
        drawTarget(math.floor(mx - camX), math.floor(self.landY - camY), self.sprW * 0.9, now)
    end

    local sx, sy, shx, claws = self:pose2d(now, moving, walkPhase)
    local fx, fy, ang
    if self.crawl and self.cattached and CRAWL[st] then
        fx, fy, ang = Crawler.pose(self)
    else
        local H = self.sprH
        ang = 0
        if st == 'drop' or st == 'stuck' or st == 'dying_kick' then ang = math.pi
        elseif st == 'getup' then ang = math.pi * (1 - math.min(1, t / GETUP_T))
        elseif st == 'pounce' then ang = self.facing * math.pi / 2 * (1 - math.min(1, t / 0.3))
        elseif st == 'dying_shrink' then
            -- Se desinfla: del tamaño colosal al de un Crabby con un temblor
            -- elástico, dándose la vuelta y posándose en el suelo
            local q = math.min(1, t / SHRINK_T)
            s = MS * (1 - (1 - SMALL) * q) * (1 + 0.12 * math.sin(q * math.pi * 7) * (1 - q))
            ang = math.pi * (1 - q)
            withSpike = q < 0.15
            H = 9 * s
            local cy = (1 - q) * self.y + q * (self.floorY - H / 2)
            fx, fy = self.x - math.sin(ang) * H / 2, cy + math.cos(ang) * H / 2
            sx, sy = 1 + 0.15 * math.sin(q * math.pi * 9) * (1 - q), 1 - 0.15 * math.sin(q * math.pi * 9) * (1 - q)
        end
        if not fx then fx, fy = self.x - math.sin(ang) * H / 2, self.y + math.cos(ang) * H / 2 end
    end
    local noClaws = false
    if st == 'dying_flee' then
        s, withSpike, noClaws = MS * SMALL, false, true
        alpha = math.max(0, math.min(1, (FLEE_T - t) / FLEE_FADE))
    elseif st == 'dying_shrink' and t > SHRINK_T * 0.4 then
        noClaws = true                            -- (las pierde al desinflarse)
    end
    if noClaws and not self._clawsGone and not EDITOR_VIEW then
        self._clawsGone = true
        Particles = Particles or require 'src/fx/Particles'
        for _, side in ipairs({ -1, 1 }) do
            Particles.emit('smoke', self.x + side * self.sprW * 0.4, self.y)
            Particles.emit('spawn', self.x + side * self.sprW * 0.4, self.y)
        end
    end
    if EDITOR_VIEW then nervous = false end
    self:renderFx(now, fx, fy, moved)
    self:drawLocal(math.floor(fx - camX + 0.5) + jx + shx, math.floor(fy - camY + 0.5) + jy, ang, s, img,
                   withSpike, alpha * self:ghostAlpha(), nervous, sx, sy, claws, noClaws)
    love.graphics.setColor(1, 1, 1, 1)
end

return {
    name = 'megacrabby', label = 'Mega Crabby', category = 'Jefes',
    description = 'Crabby gigante: persigue y embiste; trepa al techo y cae de cabeza (su pincho mata). '
               .. 'Solo es vulnerable clavado en el suelo: un golpe por caída.',
    class = Mega,
    boss = { title = 'MEGA CRABBY' },
    hide = Boss.HIDE,
    defaults = { points = 60 },
    props = Boss.props({ hp = 10, hpPerPlayer = 4 }, {
        { key='chaseSpeed', kind='number', label='Velocidad persiguiendo', group='Persecución', default=150,
          min=20, max=600, step=10, help='px/s (el jugador anda a 240)' },
        { key='chargeRange', kind='number', label='Distancia para embestir (casillas)', group='Persecución',
          default=5, min=1, max=20, step=0.5 },
        { key='windupTime', kind='number', label='Aviso antes de embestir (s)', group='Persecución', default=0.6,
          min=0.1, max=3, step=0.05 },
        { key='chargeSpeed', kind='number', label='Velocidad de la embestida', group='Persecución', default=520,
          min=100, max=1500, step=10 },
        { key='chargeDist', kind='number', label='Largo de la embestida (casillas)', group='Persecución', default=8,
          min=1, max=30, step=0.5 },
        { key='chargeEvery', kind='number', label='Espera entre embestidas (s)', group='Persecución', default=2.5,
          min=0, max=20, step=0.25 },
        { key='ceilingEvery', kind='number', label='Ataque desde el techo cada (s)', group='Ataque del techo',
          default=7, min=1, max=60, step=0.5, help='Tiempo persiguiendo antes de subir al techo' },
        { key='climbSpeed', kind='number', label='Velocidad trepando', group='Ataque del techo', default=280,
          min=40, max=900, step=10 },
        { key='climbMax', kind='number', label='Tiempo máximo para llegar al techo (s)', group='Ataque del techo',
          default=6, min=1, max=20, step=0.5, help='Si no lo consigue (sin paredes), se suelta y sigue' },
        { key='ceilingMax', kind='number', label='Tiempo buscando por el techo (s)', group='Ataque del techo',
          default=3, min=0.5, max=15, step=0.25 },
        { key='aimTime', kind='number', label='Siguiendo antes de caer (s)', group='Ataque del techo', default=1.8,
          min=0.5, max=6, step=0.1, help='Sigue al jugador por el techo con la marca debajo; se queda quieto el último instante' },
        { key='dropSpeed', kind='number', label='Velocidad máxima de caída', group='Ataque del techo', default=1600,
          min=300, max=3000, step=50 },
        { key='stuckTime', kind='number', label='Clavado en el suelo (s)', group='Ataque del techo', default=3,
          min=0.5, max=10, step=0.25, help='El momento de golpearlo (un golpe por caída)' },
        { key='trackSpeed', kind='number', label='Velocidad siguiendo (x trepar)', group='Ataque del techo',
          default=1.0, min=0.2, max=1.5, step=0.05, help='Mientras apunta desde el techo sigue al jugador a esta velocidad' },
        { key='pounceEvery', kind='number', label='Salto desde la pared cada (s)', group='Salto desde la pared',
          default=9, min=0, max=60, step=0.5, help='0 = nunca. No cae de cabeza: después no queda vulnerable' },
        { key='pounceHeight', kind='number', label='Altura a la que trepa (casillas)', group='Salto desde la pared',
          default=3, min=1, max=10, step=0.5 },
        { key='pounceAim', kind='number', label='Apuntando antes de saltar (s)', group='Salto desde la pared', default=1.4,
          min=0.5, max=5, step=0.1, help='La marca del suelo persigue al jugador; se fija el último instante' },
        { key='pounceTime', kind='number', label='Duración del salto (s)', group='Salto desde la pared', default=0.9,
          min=0.4, max=2, step=0.05 },
        { key='pounceDamage', kind='int', label='Daño al aplastar', group='Salto desde la pared', default=2,
          min=1, max=3, step=1 },
        { key='summonEvery', kind='number', label='Invocar súbditos cada (s)', group='Súbditos', default=12,
          min=1, max=60, step=0.5 },
        { key='summonCount', kind='int', label='Súbditos por invocación', group='Súbditos', default=2,
          min=0, max=4, step=1, help='0 = nunca invoca' },
        { key='summonMax', kind='int', label='Súbditos a la vez (máximo)', group='Súbditos', default=3,
          min=1, max=6, step=1 },
        { key='summonPool', kind='int', label='Reserva de súbditos', group='Súbditos', default=4,
          min=0, max=6, step=1, help='Cuántos Crabbies prepara el nivel para él (reutiliza los que mueren)' },
        { key='summonType', kind='enum', label='Tipo de súbditos', group='Súbditos', default='mix',
          options={ { value='mix', label='Pincho y trampolín' }, { value='spike', label='De pincho' },
                    { value='tramp', label='Trampolín' } } },
        { key='summonSpeed', kind='number', label='Velocidad de los súbditos', group='Súbditos', default=110,
          min=20, max=400, step=10 },
        { key='rageAt', kind='number', label='Se enfada con vida por debajo de', group='Enfado', default=0.5,
          min=0, max=1, step=0.05, help='Fracción de vida (0.5 = la mitad). 0 = nunca' },
        { key='rageSpeed', kind='number', label='Enfadado: velocidad x', group='Enfado', default=1.3,
          min=1, max=3, step=0.05 },
        { key='rageStuck', kind='number', label='Enfadado: tiempo clavado x', group='Enfado', default=0.75,
          min=0.2, max=1, step=0.05 },
    }),
    editor = { sprite = 'assets/images/MegaCrabby/crab1.png' },
    -- Súbditos: Crabbies escaladores de reserva que el nivel crea al cargar
    -- (Level.fromData), después de las entidades del JSON: así el servidor y
    -- los clientes tienen la misma lista. Empiezan fuera de juego y el jefe
    -- los activa al invocar; al morir vuelven a la reserva.
    summons = function(pl)
        local p, out = pl.props or {}, {}
        for i = 1, math.max(0, math.floor(p.summonPool or 4)) do
            local tramp = p.summonType == 'tramp' or (p.summonType ~= 'spike' and i % 2 == 0)
            out[#out + 1] = {
                type = tramp and 'crabbytramp' or 'crabby', col = pl.col, row = pl.row,
                summonKey = 'mc' .. pl.col .. ',' .. pl.row,
                props = { movement = 'walk', speed = p.summonSpeed or 110, wallWalk = true,
                          dropOnSight = true, detectRange = 10, respawn = 0, points = 5 },
            }
        end
        return out
    end,
}
