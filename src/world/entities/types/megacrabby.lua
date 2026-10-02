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
--  * Entrada (BossZones 'intro'): hasta que llegan todos no está (ni se ve ni
--    choca). Con los jugadores congelados y sin música cae del cielo en el
--    sitio de la zona más lejos de ellos (fall_in → land_in), ruge (roar_in) y
--    espera (ready) a que la zona empiece la pelea.
--  * Descansos = "emotes" (rest + restKind, en orden fijo): rugido, amenaza
--    con las pinzas o sacar pecho con el pincho.
--
-- Sprites: assets/images/MegaCrabby/ (crab1-3 como el Crabby, claw_left-Sheet
-- = pinza izquierda 11x10 abierta/cerrada (tools/ui/make_enemy_extras.py); la derecha es la misma volteada;
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
-- Entrada: silencio antes de caer, aplastado al aterrizar, rugido
local FALL_WAIT, LAND_T, ROAR_T = 0.7, 0.7, 1.9
local INTRO_SAFE = 2.5                           -- casillas libres entre él y un jugador al caer
-- Descansos: qué emote toca en cada uno (1 rugido, 2 pinzas, 3 pincho)
local REST_KINDS = { 1, 2, 1, 3 }

-- Pinzas: más pequeñas que el cuerpo (CLAW_K de su escala) y saliendo del
-- costado, a la altura del arranque de las patas (CLAW_X, CLAW_Y en píxeles
-- del sprite desde los pies, el punto donde se unen); se solapan CLAW_IN
-- píxeles de pinza con el cuerpo. La derecha es la izquierda volteada.
-- (con las pinzas grandes 11x10: algo más pequeñas de escala y más afuera, para que no tapen el cuerpo)
local CLAW_K, CLAW_X, CLAW_Y, CLAW_IN = 0.75, 6.8, -1.6, 1.5
local CS = MS * CLAW_K

-- ARTE por clase (Mega.art; el Mega Crabby helado, megacrabby_ice.lua, pone el suyo):
-- cuerpo (3 cuadros), pinza (strip de 2), pincho, medidas del arte y dónde van las pinzas
local anger
function Mega.loadArt(dir, w, h, cw, ch, k, cx, cy, cin, spikeDy)
    local function load(p)
        local i = love.graphics.newImage(p)
        if i.setFilter then i:setFilter('nearest', 'nearest') end
        return i
    end
    return { imgs = { load(dir .. 'crab1.png'), load(dir .. 'crab2.png'), load(dir .. 'crab3.png') },
             claw = SpriteStrip.load(dir .. 'claw_left-Sheet.png', cw), spike = load(dir .. 'spike.png'),
             w = w, h = h, clawW = cw, clawH = ch, clawK = k, clawX = cx, clawY = cy, clawIn = cin,
             spikeDy = spikeDy or 0 }     -- (px de arte que la púa baja hacia el caparazón)
end
function Mega.loadAssets()
    if Mega.art then return end
    -- (pinzas 11x10, tools/ui/make_enemy_extras.py: grandes, de ermitaño; antes 7x6, "deditos")
    Mega.art = Mega.loadArt('assets/images/MegaCrabby/', 16, 9, 11, 10, CLAW_K, CLAW_X, CLAW_Y, CLAW_IN)
    -- Enfado (solo dibujo): vena 💢, vapor y garabato
    anger = { vein = SpriteStrip.load('assets/images/MegaCrabby/anger_vein.png', 11),
              steam = SpriteStrip.load('assets/images/MegaCrabby/anger_steam.png', 9),
              scribble = SpriteStrip.load('assets/images/MegaCrabby/anger_scribble.png', 9) }
end
function Mega.sizePx() return 16 * MS, 9 * MS end
Mega.MS = MS

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
    self.sprW, self.sprH = self.art.w * MS * k, self.art.h * MS * k
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
    -- (tras su entrada ya ha rugido: ataca directamente)
    self.state, self.deadTimer = self.introPlayed and 'chase' or 'intro', 0
    self.ceilT, self.chargeCd = 0, self.props.chargeEvery or 2.5
    -- (desfasados: los ataques especiales se van alternando)
    self.pounceT = (self.props.pounceEvery or 9) * 0.45
    self.restT = 0
    self.summonT = (self.props.summonEvery or 12) * 0.3
    if not self.introPlayed then Sound.play('megaClack') end
end

-- ── Entrada ───────────────────────────────────────────────────────────────────
-- Antes de la entrada no está (dormant) y mientras cae no se le puede tocar
local HIDDEN = { dormant = true, fall_in = true }
local INTRO  = { fall_in = true, land_in = true, roar_in = true, ready = true }
function Mega:isActive() return not INTRO[self.state] and Boss.isActive(self) end
function Mega:isSolidBody() return not HIDDEN[self.state] and Boss.isSolidBody(self) end

function Mega:hasIntro() return self.zone ~= nil end
-- Cámara de la entrada: sobre su sitio, con el suelo de la zona abajo (cae ahí)
function Mega:introFocus()
    local z = self.zone
    return self.home.x, z and (z.y1 - WINDOW_H * 0.3) or self.home.y
end
function Mega:introDone() return self.state == 'ready' end

-- Dónde cae: su sitio del editor si está lejos de todos; si no, el punto del
-- suelo de la zona más alejado de los jugadores (nunca encima de nadie)
function Mega:introSpot(level, players)
    local z, T, hw = self.zone, TILE_PX, self.outerW / 2
    local x0, x1 = z.x0 + hw, z.x1 - hw
    if x0 > x1 then return (z.x0 + z.x1) / 2 end
    local function clearance(x)
        local d = math.huge
        for _, pa in ipairs(players) do d = math.min(d, math.abs(pa.x - x)) end
        return d
    end
    -- (solo el suelo de verdad: lo más bajo que haya, no una plataforma)
    local cands, lowest = {}, -math.huge
    for x = x0, x1, T / 2 do
        local f = self:floorBelow(level, x, z.y0)
        cands[#cands + 1] = { x = x, f = f }
        lowest = math.max(lowest, f)
    end
    local home = math.max(x0, math.min(x1, self.home and self.home.x or self.x))
    local safe = hw + INTRO_SAFE * T
    if clearance(home) >= safe and self:floorBelow(level, home, z.y0) >= lowest - T then return home end
    local best, bc
    for _, c in ipairs(cands) do
        if c.f >= lowest - T then
            local cl = clearance(c.x)
            if not bc or cl > bc + 0.5 or (math.abs(cl - bc) <= 0.5 and math.abs(c.x - home) < math.abs(best - home)) then
                best, bc = c.x, cl
            end
        end
    end
    return best or home
end

function Mega:startIntro(level, players, z)
    self.zone = self.zone or z
    z = self.zone
    Crawler.detach(self)
    self.crawl, self.flipped = false, false
    self.x = self:introSpot(level, players)
    self.y = z.y0 - self.sprH                    -- del cielo (sobre la zona)
    self.vx, self.vy, self.onGround = 0, 0, false
    self.floorY = self:floorBelow(level, self.x, z.y0)
    local near
    for _, pa in ipairs(players) do
        if not near or math.abs(pa.x - self.x) < math.abs(near.x - self.x) then near = pa end
    end
    if near then self.facing = (near.x >= self.x) and 1 or -1 end
    self.state, self.deadTimer = 'fall_in', 0
end

-- ¿Pasó el instante `s` en este paso? (sonidos y efectos a su tiempo)
local function at(t, dt, s) return t >= s and t - dt < s end

function Mega:updateMegaIntro(dt, level, st, t)
    local z = self.zone
    if st == 'fall_in' then
        if t < FALL_WAIT then return end              -- (un momento de silencio)
        if at(t, dt, FALL_WAIT) then Sound.play('megaFall') end
        self.vy = math.min(self.vy + ADV_GRAVITY * dt, self.props.dropSpeed or 1600)
        local feet0 = self.y + self.outerH / 2
        self.y = self.y + self.vy * dt
        local feet1 = self.y + self.outerH / 2
        local floorLine = z and z.y1 or level.heightPx
        -- (atraviesa lo que haya encima de la zona: viene del cielo)
        local top0 = z and z.y0 or 0
        if feet1 <= top0 then return end
        local hit, top = level:landingCross(self.x, math.max(feet0, top0), math.min(feet1, floorLine))
        if not hit and feet1 >= floorLine then hit, top = true, floorLine end
        if hit then
            self.y, self.vy, self.onGround = top - self.outerH / 2, 0, true
            self.floorY = top
            self.state, self.deadTimer = 'land_in', 0
            Sound.play('megaSlam', 0.8)
            Sound.play('gpImpact', 0.6)
            Entity.emitFx('mega_slam', self.x, top)
            Entity.emitFx('mega_land', self.x, top)
            Entity.emitFx('shake_big', self.x, top)
        end
    elseif st == 'land_in' then
        self:walk(level, dt, 0)
        if t >= LAND_T then
            self.state, self.deadTimer = 'roar_in', 0
            self:roar(1)
        end
    elseif st == 'roar_in' then
        self:walk(level, dt, 0)
        self:roarTick(dt, t)
        if at(t, dt, 1.35) then Sound.play('megaClack', 1.0) end
        if at(t, dt, 1.55) then Sound.play('megaClack', 1.15) end
        if t >= ROAR_T then
            self.state, self.deadTimer = 'ready', 0
            self.introPlayed = true
        end
    else                                              -- ready: espera a la zona
        self:walk(level, dt, 0)
    end
end

-- Rugido (entrada y descansos): sonido, onda y temblor
function Mega:roar(pitch)
    Sound.play('megaRoar', pitch or 1)
    Entity.emitFx('mega_roar', self.x + self.facing * self.sprW * 0.15, self.y - self.sprH * 0.2)
    Entity.emitFx('shake_roar', self.x, self.y)
end
-- (durante el rugido: más ondas y rayos, y el temblor suave sigue)
function Mega:roarTick(dt, t)
    for _, s in ipairs({ 0.4, 0.8 }) do
        if at(t, dt, s) then
            Entity.emitFx('mega_roar', self.x + self.facing * self.sprW * 0.15, self.y - self.sprH * 0.2)
            Entity.emitFx('shake_roar', self.x, self.y)
        end
    end
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
    return (self.hpMax or 1) > 0 and self.hp / self.hpMax <= (p.rageAt or 0.6)
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
        if not pa.dying and pa.alive ~= false and not pa:isInvulnerable() then
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

-- Quita `n` de vida de un golpe (luego queda invulnerable: ver PlayerAdventure)
local function hurtN(pa, n)
    Boss.withPlayer(pa, function() pa:hurt(n) end)
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
    if pa:isPushProtected() then return end        -- (invulnerable: ni empujones)
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

-- Dónde salen los súbditos: se eligen al EMPEZAR a invocar (un jugador y el
-- servidor) y van en el snapshot (el cliente dibuja las marcas ahí mismo).
-- Cada sitio: con suelo, sin pared, fuera del cuerpo del Mega, lejos de los
-- otros sitios, de los súbditos vivos y de los jugadores (antes se calculaban
-- a los lados alternando y, al pegar con el borde de la zona, dos salían en
-- el mismo sitio, uno encima del otro)
local SPOT_GAP = 1.3                             -- casillas entre sitios / súbditos
function Mega:pickSummonSpots(level, n)
    local T, z = TILE_PX, self.zone
    local floorY = self.y + self.outerH / 2
    local x0, x1 = (z and z.x0 or 0) + T * 0.6, (z and z.x1 or level.widthPx) - T * 0.6
    local taken = {}
    for _, e in ipairs(self:minions(level)) do if e.alive then taken[#taken + 1] = e.x end end
    local spots = {}
    local d0 = self.outerW / 2 + T * 0.9           -- (fuera de su cuerpo, con margen)
    for d = d0, (x1 - x0) + d0, T / 2 do
        for _, dir in ipairs({ -1, 1 }) do
            local x = math.floor(self.x + dir * d)
            if #spots < n and x >= x0 and x <= x1 then
                local fy = self:floorBelow(level, x, floorY - 2 * T)
                local ok = math.abs(fy - floorY) <= 2 * T
                    and not level:entitySolidAt(x, fy - T * 0.3) and not level:entitySolidAt(x, fy - T * 0.9)
                for _, o in ipairs(taken) do if math.abs(o - x) < SPOT_GAP * T then ok = false end end
                for _, pa in ipairs(level.players or {}) do
                    if math.abs(pa.x - x) < T and math.abs(pa.y - (fy - T / 2)) < 1.5 * T then ok = false end
                end
                if ok then
                    spots[#spots + 1] = { x = x, y = math.floor(fy), dir = dir }
                    taken[#taken + 1] = x
                end
            end
        end
    end
    return spots
end

function Mega:summonSpot(i)
    local sp = self.spots and self.spots[i]
    if sp then return sp.x, sp.dir, sp.y end
    return self.x, 1, self.y + self.outerH / 2
end

function Mega:summonMinions(level)
    local n, free = self:summonable(level)
    n = math.min(n, self.summonN or n)
    -- (durante el aviso otro súbdito pudo meterse en un sitio marcado — p. ej.
    -- empujado por un ground pound —: se vuelven a comprobar con donde están
    -- AHORA; si alguno ya no vale, sitios nuevos libres)
    local T = TILE_PX
    local clash = false
    for i = 1, n do
        local sp = self.spots and self.spots[i]
        for _, e in ipairs(self:minions(level)) do
            if sp and e.alive and math.abs(e.x - sp.x) < T and math.abs(e.y - (sp.y - e.outerH / 2)) < 1.5 * T then clash = true end
        end
    end
    if clash then
        self.spots = self:pickSummonSpots(level, n)
        n = math.min(n, #self.spots)
    end
    for i = 1, n do
        local e = free[i]
        local x, dir, floorY = self:summonSpot(i)
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
    elseif INTRO[st] then
        return self:updateMegaIntro(dt, level, st, t)
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
        self.restT = (self.restT or 0) + dt
        local summonsOn = (p.summonCount or 2) > 0 and (p.summonPool or 4) > 0
        if self.onGround and (p.restEvery or 5) > 0 and self.restT >= (p.restEvery or 5) then
            -- Descanso: se queda quieto respirando (un respiro para él y para el
            -- jugador); mientras tanto no cuentan los tiempos de los ataques
            self.restT = 0
            local rt = p.restTime or 1.8
            self.restFor = rt * (0.8 + math.random() * 0.5)
            self.restN = (self.restN or 0) + 1
            self.restKind = REST_KINDS[(self.restN - 1) % #REST_KINDS + 1]
            if self.restKind == 1 then self.restFor = math.max(self.restFor, 1.4) end
            self.state, self.deadTimer = 'rest', 0
            if self.restKind == 1 then self:roar(1.1)
            elseif self.restKind == 3 then Sound.play('spikeShake', 0.8) end
        elseif self.onGround and self.ceilT >= (p.ceilingEvery or 7) then
            if self:startClimb(level) then self.ceilT = 0 else self.ceilT = 0 end
        elseif self.onGround and (p.pounceEvery or 9) > 0 and self.pounceT >= (p.pounceEvery or 9) then
            self.pounceT = 0
            self:startClimb(level, 'wallclimb')
        elseif self.onGround and summonsOn and self.summonT >= (p.summonEvery or 12) then
            -- Solo si puede sacar alguno (con el máximo vivo no lo intenta:
            -- lo vuelve a mirar un poco después)
            local n = self:summonable(level)
            self.spots = (n > 0) and self:pickSummonSpots(level, n) or nil
            n = math.min(n, self.spots and #self.spots or 0)
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
    elseif st == 'rest' then
        self:walk(level, dt, 0)
        -- Emote del descanso
        if self.restKind == 1 then
            self:roarTick(dt, t)
        elseif self.restKind == 2 then
            for i, s in ipairs({ 0.15, 0.4, 0.65, 0.9 }) do
                if at(t, dt, s) then Sound.play('megaClack', 0.95 + i * 0.07) end
            end
        elseif self.restKind == 3 then
            if at(t, dt, 0.55) then
                Sound.play('crabPop', 0.75)
                Entity.emitFx('sparks', self.x, self.y - self.sprH / 2 - SPIKE_H * 0.8)
            end
        end
        if t >= (self.restFor or 1.8) then self.state, self.deadTimer = 'chase', 0 end
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
             math.floor(self.markerX + 0.5), self.summonN or 0, self.restKind or 0, self:spotsPack() }
end

-- Sitios de invocación en el snapshot: "x,y,dir;x,y,dir;..."
function Mega:spotsPack()
    if self.state ~= 'summon' or not self.spots then return '' end
    local t = {}
    for _, sp in ipairs(self.spots) do t[#t + 1] = sp.x .. ',' .. sp.y .. ',' .. sp.dir end
    return table.concat(t, ';')
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
    self.restKind = tonumber(b[8]) or 0
    local sp = type(b[9]) == 'string' and b[9] or ''
    if sp ~= '' then
        self.spots = {}
        for x, y, d in sp:gmatch('(-?%d+),(-?%d+),(-?%d+)') do
            self.spots[#self.spots + 1] = { x = tonumber(x), y = tonumber(y), dir = tonumber(d) }
        end
    end
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
-- Todo lo "secundario" (squash & stretch, balanceo de pinzas, forcejeo,
-- partículas continuas) sale del estado y su tiempo (deadTimer), que llegan
-- por red: se ve igual en un jugador y online. Nada de esto toca la física.
local Particles
local TAU = math.pi * 2

local function spring(t, amp, freq, damp) return amp * math.exp(-t * damp) * math.cos(t * freq) end

-- Chasquidos del sonido megaWindup (= WINDUP_SNAPS de tools/sounds/megacrabby.py;
-- el último, las dos a la vez). ¿Está una pinza cerrada en `t`? → true, cuál (0 = las dos)
local WINDUP_SNAPS = { 0.02, 0.16, 0.27, 0.35, 0.41, 0.46, 0.50, 0.53 }
local function windupSnap(t)
    for i, s in ipairs(WINDUP_SNAPS) do
        if t >= s + 0.02 and t < s + 0.075 then
            return true, (i == #WINDUP_SNAPS) and 0 or ((i % 2 == 1) and 1 or 2)
        end
    end
    return false
end

-- Pinzas: cada una se cierra y abre sola cada cierto tiempo (más a menudo
-- cuando está nervioso). Solo es dibujo (cada cliente a su aire).
local function clawFrame(self, i, now, nervous)
    if self._clawForce then return self._clawForce[i] end   -- (al compás del sonido)
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
    local spikeK = 1
    -- Rugido: se echa atrás, se estira hacia arriba temblando con las pinzas
    -- en alto y abiertas, y vuelve a su sitio
    local function roarPose(rt)
        if rt < 0.25 then
            local k = rt / 0.25
            sx, sy = 1 + 0.08 * k, 1 - 0.1 * k
            for i = 1, 2 do claws[i][2] = 1.0 * k end
        elseif rt < 1.15 then
            local k = math.min(1, (rt - 0.25) / 0.12)
            local tr = math.sin(now * 48) * 0.025
            sx, sy = 1 - 0.07 * k - tr, 1 + 0.16 * k + tr
            shx = math.floor(math.sin(now * 61) * 2 * MS / 4)
            spikeK = 1 + 0.1 * k + math.sin(now * 40) * 0.04
            for i, side in ipairs({ -1, 1 }) do
                claws[i][1] = side * 1.4 * k
                claws[i][2] = -3.4 * k + math.sin(now * 34 + i * 2) * 0.6
            end
        else
            local q = spring(rt - 1.15, 0.12, 16, 6)
            sx, sy = 1 + q, 1 - q
        end
    end
    if st == 'dormant' or st == 'recover' or st == 'ready' or ((st == 'chase' or st == 'intro') and not moving) then
        sy, sx = 1 + 0.025 * breath, 1 - 0.015 * breath
        swing(0.8, 2.1)
    elseif st == 'rest' then
        -- Descansando: respira hondo y despacio, pinzas caídas meciéndose...
        local deep = math.sin(now * 1.9)
        sy, sx = 1 + 0.04 * deep, 1 - 0.025 * deep
        swing(1.1, 1.3, 0.3)
        -- ...tras su emote
        local kind = self.restKind or 0
        if kind == 1 and t < 1.4 then
            roarPose(t)
        elseif kind == 2 and t < 1.15 then
            -- Amenaza: puñetazos al aire alternando las pinzas, botando
            local k = math.min(1, t / 0.12) * math.min(1, (1.15 - t) / 0.15)
            sy, sx = 1 + 0.05 * math.abs(math.sin(t * 16)) * k, 1 - 0.03 * math.abs(math.sin(t * 16)) * k
            for i, side in ipairs({ -1, 1 }) do
                local ph = math.max(0, math.sin(t * 16 + (i == 1 and 0 or math.pi)))
                claws[i][1] = side * (0.4 + 1.2 * ph) * k
                claws[i][2] = (-1.0 - 2.6 * ph) * k
            end
        elseif kind == 3 and t < 1.2 then
            -- Saca pecho: se encoge, el pincho crece de golpe y vibra
            if t < 0.5 then
                local k = t / 0.5
                sx, sy = 1 + 0.1 * k, 1 - 0.12 * k
                spikeK = 1 - 0.1 * k
                for i = 1, 2 do claws[i][2] = 1.2 * k end
            else
                local q = spring(t - 0.5, 0.18, 18, 5)
                sx, sy = 1 - 0.05 - q * 0.5, 1 + 0.1 + q
                spikeK = 1.35 + spring(t - 0.5, 0.25, 30, 5)
                for i, side in ipairs({ -1, 1 }) do claws[i][1] = side * 1.0; claws[i][2] = -1.6 end
            end
        end
    elseif st == 'roar_in' then
        roarPose(t)
    elseif st == 'land_in' then
        -- Aterriza del cielo: aplastado y rebotando
        local q = spring(t, 0.32, 17, 5)
        sx, sy = 1 + q, 1 - q
        for i, side in ipairs({ -1, 1 }) do claws[i][1] = side * 1.2 * math.max(0, q * 3); claws[i][2] = 1.2 end
    elseif st == 'fall_in' then
        -- Cayendo: estirado, patas y pinzas arriba agitándose
        sx, sy = 0.9, 1.14
        for i, side in ipairs({ -1, 1 }) do
            claws[i][1] = side * 0.8
            claws[i][2] = -2.4 + math.sin(now * 26 + i * 2) * 0.8
        end
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
        -- Anticipación de cangrejo: agachado, escarbando en el sitio (se mece
        -- de lado a lado) con las pinzas en alto; cada chasquido del sonido
        -- (WINDUP_SNAPS) la pinza que toca da un tirón hacia delante
        local k = math.min(1, t / 0.2)
        sx, sy = 1 + 0.10 * k, 1 - 0.14 * k
        shx = math.floor(math.sin(t * 38) * 2 * MS / 4)
        local snap, which = windupSnap(t)
        for i, side in ipairs({ -1, 1 }) do
            local jab = (snap and (which == 0 or which == i)) and 1 or 0
            claws[i][1] = side * 0.6 * k + self.facing * 0.9 * jab
            claws[i][2] = -2.2 * k + 0.8 * jab + math.sin(now * 42 + i) * 0.3
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
    return sx, sy, shx, claws, spikeK
end

-- Dibuja el cangrejo "como en el suelo" con los pies en (px, py) de pantalla,
-- girado `ang`, a escala de píxel `s`, deformado (sx, sy) desde los pies
function Mega:drawLocal(px, py, ang, s, img, withSpike, alpha, nervous, sx, sy, claws, noClaws, spikeK)
    local now = love.timer.getTime()
    local red = self:flashRed()
    if red then love.graphics.setColor(1, 0.3, 0.3, alpha)
    elseif self._angry then
        -- Enfadado: se le sube el color (rojizo que late)
        local k = 0.07 + 0.05 * math.sin(now * 9)
        love.graphics.setColor(1, 1 - k, 1 - k * 1.2, alpha)
    else love.graphics.setColor(1, 1, 1, alpha) end
    love.graphics.push()
    love.graphics.translate(px, py)
    love.graphics.rotate(ang)
    love.graphics.scale(sx or 1, sy or 1)
    local A = self.art
    local ih = img:getHeight()
    local cs = s * A.clawK
    if withSpike then                             -- detrás del cuerpo, sobre la cabeza
        local k = spikeK or 1                     -- (los emotes lo hinchan)
        love.graphics.draw(A.spike, 0, -(ih - A.spikeDy) * s, 0, s / 4 * (0.85 + 0.15 * k), s / 4 * k,
                           A.spike:getWidth() / 2, A.spike:getHeight() - 1)
    end
    love.graphics.draw(img, 0, 0, 0, s * self.facing, s, img:getWidth() / 2, ih)
    if self.drawBodyOverlay then self:drawBodyOverlay(s, now) end      -- (capas de otras variantes)
    -- Pinzas delante del cuerpo, saliendo del costado junto a las patas
    for i, side in ipairs(noClaws and {} or { -1, 1 }) do
        local off = claws and claws[i] or { 0, 0 }
        local cx = side * (A.clawX * s + A.clawW * cs / 2 - A.clawIn * cs) + math.floor(off[1] * cs + 0.5)
        local cy = A.clawY * s - A.clawH * cs / 2 + math.floor(off[2] * cs + 0.5)
        A.claw:draw(clawFrame(self, i, now, nervous), cx, cy, 0, -side * cs, cs)
        if self.drawClawOverlay then self:drawClawOverlay(i, side, cx, cy, cs, now) end
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
    -- Pegado a pared/techo: la normal de la superficie (las piedrecitas salen
    -- de ella, del material que sea, y no nacen metidas en el bloque)
    local nx, ny = 0, -1
    if self.crawl and self.cattached then nx, ny = self.cnx or 0, self.cny or -1 end
    local srf = { nx = nx, ny = ny }
    if (walking or crawling) and moved > 0 then
        f.acc = f.acc + moved
        if f.acc >= STEP_DIST then
            f.acc, f.foot = 0, -f.foot
            if walking then Particles.emit('mega_step', fx + f.foot * self.sprW * 0.3, fy)
            else Particles.emit('mega_debris', fx, fy, srf) end
        end
    end
    local every = (st == 'charge') and 0.04 or (st == 'stuck' or st == 'dying_kick') and 0.16
                  or (st == 'aim' or st == 'wallaim') and 0.12 or (st == 'windup') and 0.09 or nil
    if every and now - f.t >= every then
        f.t = now
        if st == 'charge' then Particles.emit('mega_trail', fx - self.facing * self.sprW * 0.3, fy, { dir = self.facing })
        elseif st == 'windup' then Particles.emit('mega_trail', fx - self.facing * self.sprW * 0.35, fy, { dir = -self.facing })
        elseif st == 'aim' or st == 'wallaim' then
            -- (repartidas a lo largo de la superficie: horizontal en el techo, vertical en la pared)
            local k = (math.random() - 0.5) * self.sprW * 0.6
            Particles.emit('mega_debris', fx - ny * k, fy + nx * k, srf)
        else Particles.emit('mega_dirt', self.x + (math.random() - 0.5) * SPIKE_HW, self.floorY) end
    end
end

-- Enfadado (rage): símbolos de enfado que salen al azar alrededor de la cabeza
-- (vena 💢 que late, nube de vapor que sube, garabato). Solo dibujo: cada
-- cliente los saca a su aire; la vida (y por tanto el enfado) llega por red.
local ANGER_S = 3                                  -- escala de píxel de los símbolos
local ANGER_KINDS = { 'vein', 'vein', 'steam', 'scribble', 'vein', 'steam' }
local ANGER_LIFE = { vein = 0.8, steam = 0.6, scribble = 0.7 }
function Mega:renderAnger(now, fx, fy, ang, camX, camY)
    local list = self._anger or {}
    self._anger = list
    local st = self.state
    local on = self:rage() and not self:isDying() and not INTRO[st] and st ~= 'dormant' and not EDITOR_VIEW
    if on and now >= (self._angerNext or 0) and #list < 3 then
        self._angerNext = now + 0.3 + math.random() * 0.55
        local kinds = self.angerKinds or ANGER_KINDS
        local kind = kinds[math.random(#kinds)]
        -- (arriba, a un lado u otro de la cabeza; nunca dos seguidos en el mismo lado)
        self._angerSide = -(self._angerSide or 1)
        local a = self._angerSide * (0.35 + math.random() * 0.8)
        local r = self.sprW * (0.32 + math.random() * 0.14)
        list[#list + 1] = { kind = kind, born = now, ox = math.sin(a) * r, oy = -math.cos(a) * r * 0.4 + self.sprH * 0.1 }
    end
    if #list == 0 then return end
    -- Cabeza = pies + (0, -alto) girado con el cuerpo
    local ca, sa = math.cos(ang), math.sin(ang)
    local hx, hy = fx + sa * self.sprH, fy - ca * self.sprH
    for i = #list, 1, -1 do
        local p = list[i]
        local age, life = now - p.born, ANGER_LIFE[p.kind]
        if age >= life then
            table.remove(list, i)
        else
            local ox, oy = p.ox * ca - p.oy * sa, p.ox * sa + p.oy * ca
            local x, y = hx + ox - camX, hy + oy - camY
            local k, frame = ANGER_S, 1
            local alpha = math.min(1, (life - age) / 0.15)
            if p.kind == 'vein' then
                -- Aparece de golpe (con rebote) y late
                k = ANGER_S * ((age < 0.1) and (0.5 + age / 0.1 * 0.75) or 1)
                frame = (math.floor(age * 7) % 2 == 0) and 1 or 2
            elseif p.kind == 'steam' then
                frame = math.min(3, math.floor(age / life * 3) + 1)
                y = y - age * 60
                x = x + math.sin(age * 12) * 3
            else
                frame = math.floor(age * 12) % 2 + 1
                x = x + math.floor(math.sin(age * 40) * 2)
            end
            k = math.floor(k + 0.5)
            x, y = math.floor(x + 0.5), math.floor(y + 0.5)
            love.graphics.setColor(0, 0, 0, 0.5 * alpha)
            anger[p.kind]:draw(frame, x + 3, y + 3, 0, k, k)
            love.graphics.setColor(1, 1, 1, alpha)
            anger[p.kind]:draw(frame, x, y, 0, k, k)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Mega:render(camX, camY)
    local st, t = self.state, self.deadTimer or 0
    local now = love.timer.getTime()
    -- Antes de su entrada no está; cayendo, su sombra crece en el suelo
    if not EDITOR_VIEW and (st == 'dormant' or (st == 'fall_in' and t < FALL_WAIT)) then
        self._lx = nil
        return
    end
    if st == 'fall_in' and not EDITOR_VIEW and (self.floorY or 0) > 0 then
        local k = math.max(0, math.min(1, 1 - (self.floorY - (self.y + self.outerH / 2)) / 900))
        local w = math.floor(self.sprW * (0.25 + 0.6 * k))
        love.graphics.setColor(0, 0, 0, 0.2 + 0.35 * k)
        love.graphics.rectangle('fill', math.floor(self.x - camX - w / 2), math.floor(self.floorY - camY - 6), w, 6)
        love.graphics.setColor(1, 1, 1, 1)
    end
    local s, alpha = MS, 1
    local emote = st == 'rest' and t < 1.2 and (self.restKind or 0) or 0
    local nervous = st == 'windup' or st == 'aim' or st == 'stuck' or st == 'dying_kick' or st == 'intro'
                    or st == 'charge' or st == 'summon' or st == 'wallaim' or st == 'pounce'
                    or st == 'roar_in' or st == 'fall_in' or emote == 1 or emote == 2
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
    elseif st == 'fall_in' or (emote == 2 and t < 1.15) or st == 'windup' then
        frame = math.floor(now * (st == 'windup' and 18 or 14)) % 3 + 1   -- (patalea / escarba)
    elseif not moving and (st == 'dormant' or st == 'windup' or st == 'aim' or st == 'recover' or st == 'chase' or st == 'rest'
                           or st == 'intro' or st == 'summon' or st == 'wallaim' or st == 'land_in' or st == 'roar_in'
                           or st == 'ready') then
        frame = 2
    end
    local img = self.art.imgs[frame] or self.art.imgs[2]
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
        for i = 1, (self.summonN or 0) do
            local x, _, fy0 = self:summonSpot(i)
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

    local sx, sy, shx, claws, spikeK = self:pose2d(now, moving, walkPhase)
    -- ENFADADO (rage): solo rojizo y un temblor LEVE (1 px de vez en cuando),
    -- además de los símbolos de enfado. Pinzas y rebote, los de siempre (el
    -- usuario quitó el resto: demasiado)
    local angry = self:rage() and not self:isDying() and not INTRO[st] and st ~= 'dormant' and not EDITOR_VIEW
    self._angry = angry
    if angry then shx = shx + math.floor(math.sin(now * 41) * 0.9 + 0.5) end
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
            H = self.art.h * s
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
    self._clawForce = nil
    if st == 'windup' and not EDITOR_VIEW then
        local snap, which = windupSnap(t)
        self._clawForce = { (snap and which ~= 2) and 2 or 1, (snap and which ~= 1) and 2 or 1 }
    end
    self:renderFx(now, fx, fy, moved)
    self:drawLocal(math.floor(fx - camX + 0.5) + jx + shx, math.floor(fy - camY + 0.5) + jy, ang, s, img,
                   withSpike, alpha * self:ghostAlpha(), nervous, sx, sy, claws, noClaws, spikeK)
    self:renderAnger(now, fx + jx + shx, fy + jy, ang, camX, camY)
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
        { key='restEvery', kind='number', label='Descansa cada (s)', group='Descanso', default=5,
          min=0, max=60, step=0.5, help='Tiempo persiguiendo antes de pararse a descansar. 0 = nunca' },
        { key='restTime', kind='number', label='Descanso (s)', group='Descanso', default=1.8,
          min=0.3, max=8, step=0.1, help='Cuánto dura cada descanso (varía un poco)' },
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
        { key='rageAt', kind='number', label='Se enfada con vida por debajo de', group='Enfado', default=0.6,
          min=0, max=1, step=0.05, help='Fracción de vida (0.5 = la mitad). 0 = nunca. Enfadado le salen venas de enfado y vapor' },
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
