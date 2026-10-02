-- MEGA CRABBY LÚGUBRE (jefe de los niveles A OSCURAS). Ciego: no te ve, te OYE. Es de TIERRA,
-- como los Crabbies de fuera: anda por el suelo de su arena buscándote y solo te EMBISTE si te
-- ha detectado. Toda la pelea sale de una regla que se ve en pantalla:
--
--     SOLO ATACA SI HAY UN "!" ROJO, Y ATACA ESE "!".   (y solo se le daña alumbrándolo cuando
--                                                         se queda agotado tras embestir o saltar)
--
-- El "!" rojo (src/fx/NoiseMarks.lua) sale donde algo hace ruido: saltar, un ground pound,
-- recibir un golpe, matar a un enemigo. ANDAR no hace ruido.
-- ECOLOCALIZACIÓN ('ping'): cada `pingEvery` s se para, alza las pinzas y las chasquea: sale un
-- ARO desde su cuerpo. Si el aro pasa por un jugador que SE MUEVE, lo detecta (su "!"). Quieto
-- mientras pasa = no te encuentra.
-- SIN "!" reciente solo ronda ('prowl'): anda hacia el último sitio que conoce y luego de un lado
-- a otro. CON un "!" nuevo APUNTA ('aim': ojos que parpadean, su aviso, y la marca del ataque,
-- fija desde el principio) y ataca:
--   PINZAS    ('claw')   si el "!" está cerca (≤ CLAW_REACH): una barra corta delante → estocada
--                        con la pinza larga de ese lado. Agachado no te da; detrás tampoco.
--   EMBESTIDA ('charge') si está lejos: una línea por el suelo hasta la pared → corre hasta ella.
--                        Se esquiva AGACHÁNDOSE (pasa por encima: sus patas no cuentan) o saltándolo
--                        con doble salto. Al llegar a la pared queda AGOTADO ('tired').
--   SALTO     ('pounce', desde la fase 2, alternando con la embestida): una diana en el suelo →
--                        salta ahí y cae de golpe. También queda agotado.
--   Tocarlo en un ataque = 1 de vida + empujón. Si mientras apunta le da una LINTERNA, se asusta
--   y cancela ("…").
-- CÓMO SE LE DAÑA: AGOTADO (`TIRED_T` s) es inmune sin luz (rebotas); alumbrado → DESLUMBRADO
--   ('dazzled': se tapa con las pinzas): pisotón 1 / ground pound 2 (un golpe).
-- FASE 2 (vida ≤ `phase2`): añade el salto y va más rápido.
-- RABIA (vida ≤ `rageAt`): RUGE ('roar', pinzas en alto), le salen CRISTALES que brillan en las
--   PINZAS (no en el lomo: ahí parecerían pinchos y es donde se le pisa; hojas claw_rage_left /
--   claw_rage_glow), va más rápido y cada `shriekEvery` s GRITA: las linternas
--   alcanzan la mitad `dimTime` s (level.lightScale) y llama a Crabbies lúgubres.
-- BURLA ('taunt'): si un ataque le da a alguien, se queda un momento chasqueando las pinzas.
-- MUERTE de cangrejo (sin explosiones): se encoge temblando ('dying_curl') y se apaga ('dying_out').
--
-- PINZAS: largas y afiladas, en hoz (las de los otros Megas son robustas); en reposo miran hacia
-- DENTRO ("C Ↄ"); en una hoja aparte
-- (claw_left-Sheet: abierta / cerrada; la derecha es su espejo) y con su pose en cada momento
-- (MG:clawPose: alzadas al rugir y en la ecolocalización, atrás al apuntar, estocada, caídas,
-- tapándose...). Solo dibujo: sale de state + deadTimer.
-- Posición = el centro de su CAPARAZÓN (su caja: lo que se ve; las patas no cuentan).
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
local BODY_ROW = 11                        -- fila del centro del CAPARAZÓN en el cuadro
local BW, BH = 11 * MS, 6 * MS             -- caja: el caparazón
local REST = (FH - BODY_ROW) * MS          -- del centro del caparazón al suelo
local CLAW_W, CLAW_H = 14, 7               -- cuadro de la pinza
local F_IDLE, F_CROUCH, F_LEAP, F_SCARED, F_DEAD = 5, 6, 7, 8, 9

local MG = Entity.extend(Boss, {
    debugColor = { 0.6, 0.8, 1 },
    hitbox = { outerW = 1, outerH = 1, innerW = 0.9, innerH = 0.9 },
})
MG.hurtSound   = 'mgloomyHurt'
MG.introLength = 3.4
MG.wantsLevel  = true

local KIND = { charge = 1, claw = 2, pounce = 3 }
-- Ritmo por fase (1, 2, rabia)
local WALK       = { 95, 115, 140 }        -- px/s rondando
local CHARGE     = { 640, 730, 820 }       -- px/s embistiendo
local AIM_T      = { 0.9, 0.8, 0.65 }      -- s apuntando (con la marca puesta)
local TIRED_T    = { 2.3, 2.0, 1.7 }       -- s agotado (hay que alumbrarlo aquí)
local ATTACK_CD  = { 1.3, 1.0, 0.7 }       -- s entre ataques
local FRESH      = 4.0                     -- s que un "!" sirve para atacar
local CLAW_REACH = 4.2 * T                 -- alcance de la estocada (y distancia para elegirla)
local CLAW_T     = 0.4                     -- s de la estocada (daña los primeros 0.22)
local JUMP_T     = 0.8
local PING_T     = 0.6                     -- s de la pose de la ecolocalización (el aro sale a los 0.2)
local ROAR_T     = 1.4
local DAZZLE_T   = 2.6
local FLINCH_T   = 0.6
local TAUNT_T    = 0.9
local CURL_T, OUT_T = 1.5, 1.8             -- muerte
local HEAR_K     = 4                       -- oído: × el radio de cada ruido (oye toda la arena)
local RING_SPD   = 560                     -- px/s a los que crece el aro
local RING_MAX   = 9 * T
local STILL_SPD  = 30
local EDGE       = BW / 2 + 70             -- hasta dónde se acerca a las paredes
local HIT_AIR    = { 1, 620, -460, 0.25, 0 }
local HIT_SLAM   = { 1, 900, -560, 0.3, 0.3 }
local GLOW       = { 1, 0.77, 0.35 }
local RING       = { 0.55, 0.95, 1 }
local WARN       = { 1, 0.28, 0.2 }
local CLAW_DY    = 2                        -- unión de las pinzas, en px de arte bajo el centro (bajas: salen de debajo del caparazón)
local CRYS       = { 0.85, 0.66, 1 }        -- cristales de la rabia

local body, glow, clawS, clawR, clawRG, markS, icons
function MG.loadAssets()
    if body then return end
    local D = 'assets/images/bosses/megagloomy/'
    body  = SpriteStrip.load(D .. 'body-Sheet.png', FW)
    glow  = SpriteStrip.load(D .. 'glow-Sheet.png', FW)
    clawS = SpriteStrip.load(D .. 'claw_left-Sheet.png', CLAW_W)
    clawR = SpriteStrip.load(D .. 'claw_rage_left-Sheet.png', CLAW_W)        -- (rabia: con cristales en el dorso)
    clawRG = SpriteStrip.load(D .. 'claw_rage_glow-Sheet.png', CLAW_W)       -- (… y sus puntas, que brillan a oscuras)
    markS = SpriteStrip.load('assets/images/bosses/megagummy/target-Sheet.png', 16)
    icons = SpriteStrip.load('assets/images/gloomy/icons-Sheet.png', 7)
end
function MG.sizePx() return BW, BH end

function MG:initBoss()
    self.phase, self.rage = 1, false
    self.face, self.dir = 1, 1
    self.pings, self.nextPing = {}, 0
    self.pingT, self.cdT, self.shriekT, self.dimT, self.flinchCd = 0, 0, 0, 0, 0
    self.tx, self.ty, self.tAge = nil, nil, 99
    self.markX, self.markY, self.endX, self.kind = 0, 0, 0, 0
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

function MG:floorY(level, x)
    local _, _, zy0, zy1 = self:zoneBounds()
    local _, top = level:landingCross(x, zy1 - T + 2, zy1 + T)       -- (el suelo de la zona, no una plataforma)
    return top or zy1
end
-- De pie en el suelo, en x (dentro de la zona)
function MG:stand(level, x)
    local zx0, zx1 = self:zoneBounds()
    self.x = math.max(zx0 + EDGE, math.min(zx1 - EDGE, x))
    self.y = self:floorY(level, self.x) - REST
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

-- Su cuerpo en un ataque (embestida, salto): el caparazón con un margen. Las patas no: agachado
-- se pasa por debajo
function MG:touch(level)
    local ob = self:getOuterBounds()
    self:hitBox(level, { x = ob.x - 30, y = ob.y - 12, w = ob.w + 60, h = ob.h + 20 }, HIT_AIR, self.x)
end

function MG:slam(level)
    Sound.play('mgloomySlam')
    Entity.emitFx('gp_land', self.x, self.y + REST)
    Entity.emitFx('shake_big', self.x, self.y)
    Noise.emit(self.x, self.y, Noise.R.boss, true)         -- (los Crabbies lúgubres lo oyen y vienen; sin marca)
    self.heardSeq = (level.noises and level.noises.seq) or self.heardSeq     -- (su propio golpe no cuenta)
    self:hitBox(level, { x = self.x - BW / 2 - 50, y = self.y - BH / 2, w = BW + 100, h = REST + BH / 2 + 8 }, HIT_SLAM, self.x)
end

-- Zona de la estocada: delante, a la altura de las pinzas (agachado no te da)
function MG:clawBox()
    local x0 = (self.face > 0) and self.x or (self.x - CLAW_REACH)
    return { x = x0, y = self.y - 20, w = CLAW_REACH, h = 68 }       -- (baja la pinza: de pie te da; agachado, no)
end

-- ── Reglas con el jugador (sin efectos: el cliente predice el rebote) ────────
local DEATH = { dying_curl = true, dying_out = true }
function MG:isDying() return DEATH[self.state] == true or Boss.isDying(self) end
function MG:releasesZone() return self.state == 'dying_out' or self.state == 'dead' end
function MG:isVulnerable() return self.state == 'dazzled' and not self.hitOnce end
local SOLID = { prowl = true, ping = true, tired = true, dazzled = true, aim = true, flinch = true, taunt = true, recover = true }
function MG:isSolidBody() return Boss.isSolidBody(self) and SOLID[self.state] == true end
function MG:interact(pa)
    local st = self.state
    if st == 'charge' or st == 'pounce' or st == 'claw' or st == 'roar' or st == 'shriek' then return nil end   -- (touch / nada)
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
    if level then
        level.lightScale = nil
        self.dieY0, self.dieY1 = self.y, self:floorY(level, self.x) - REST
    else
        self.dieY0, self.dieY1 = self.y, self.y
    end
    for _, e in ipairs(level and self:minions(level) or {}) do
        if e.alive and e.state ~= 'dead' then e.state, e.deadTimer, e.vx, e.vy = 'dead', 0, 0, 0 end
    end
    self.dieLanded = false
    self:enter('dying_curl')
    Sound.play('mgloomyDazzled', 0.7)
    self:onDefeat()
end

-- ── Entrada: cae de la oscuridad del techo, aterriza y RUGE ──────────────────
function MG:onFightStart()
    self.pingT, self.cdT = 1.2, 1.0
end
function MG:onIntroStart(level)
    local zx0, zx1, zy0 = self:zoneBounds()
    self:stand(level, (zx0 + zx1) / 2)
    self.introY1, self.introY0 = self.y, zy0 - 3 * T
    self.y = self.introY0
    self.introStep = 0
end
function MG:updateIntro(dt, level, t)
    self:updatePings(nil, dt)
    local k = math.max(0, math.min(1, (t - 0.3) / 0.6))
    self.y = self.introY0 + (self.introY1 - self.introY0) * k * k
    if k >= 1 and self.introStep < 1 then
        self.introStep = 1
        Sound.play('mgloomySlam')
        Entity.emitFx('gp_land', self.x, self.y + REST)
        Entity.emitFx('shake_big', self.x, self.y)
    end
    if t >= 1.5 and self.introStep < 2 then
        self.introStep = 2
        Sound.play('mgloomyRoar')
        Entity.emitFx('shake_roar', self.x, self.y)
    end
end

function MG:walkAnim(dt, fast)
    self.animT = self.animT + dt
    local step = fast and 0.05 or 0.11
    if self.animT >= step then
        self.animT = self.animT - step
        self.frame = self.frame % 4 + 1
        -- (un roce de vez en cuando, no cada paso: el silencio es la tensión)
        self.stepN = (self.stepN or 0) + 1
        if self.stepN % (fast and 3 or 8) == 0 then Sound.play('mgloomyStep') end
    end
end

-- Vuelve a rondar (o se burla, si acaba de darle a alguien)
function MG:afterAttack()
    self.kind = 0
    local ph = self.rage and 3 or self.phase
    self.cdT = ATTACK_CD[ph]
    if self.gloat then self.gloat = false; self:enter('taunt') else self:enter('prowl') end
end

-- Apunta al último "!": elige el ataque y pone su marca (fija)
function MG:startAim(level)
    local zx0, zx1 = self:zoneBounds()
    local tx = math.max(zx0 + EDGE, math.min(zx1 - EDGE, self.tx))
    self.face = (self.tx >= self.x) and 1 or -1
    self.markX, self.markY = math.floor(tx), math.floor(self:floorY(level, tx))
    local kind
    if math.abs(self.tx - self.x) <= CLAW_REACH then
        kind = 'claw'
    else
        self.attackN = self.attackN + 1
        kind = (self.phase >= 2 and self.attackN % 2 == 0) and 'pounce' or 'charge'
    end
    self.kind = KIND[kind]
    self.endX = math.floor((self.face > 0) and (zx1 - EDGE) or (zx0 + EDGE))      -- (la embestida llega hasta la pared)
    self.gloat = false
    self.tAge = FRESH + 1                                   -- (ese "!" ya está gastado: hace falta otro)
    self:enter('aim')
    Sound.play('mgloomyListen')
end

function MG:updateBoss(dt, level)
    if self.state == 'dormant' then return end
    self.levelRef = self.levelRef or level
    self.deadTimer = self.deadTimer + dt
    local st, t = self.state, self.deadTimer
    local p = self.props

    if st == 'dying_curl' then
        local k = math.min(1, t / 0.4)
        self.y = self.dieY0 + (self.dieY1 - self.dieY0) * k * k
        if k >= 1 and not self.dieLanded then
            self.dieLanded = true
            if math.abs(self.dieY1 - self.dieY0) > 20 then
                Sound.play('mgloomySlam', 0.8)
                Entity.emitFx('gp_land', self.x, self.y + REST)
            end
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
    if self.cdT > 0 then self.cdT = self.cdT - dt end
    if self.flinchCd > 0 then self.flinchCd = self.flinchCd - dt end
    if self.dimT > 0 then
        self.dimT = self.dimT - dt
        if self.dimT <= 0 then level.lightScale = nil end
    end
    local frac = self.hp / math.max(1, self.hpMax)
    if self.phase < 2 and frac <= (p.phase2 or 0.66) then self.phase = 2 end
    local ph = self.rage and 3 or self.phase
    local zx0, zx1 = self:zoneBounds()

    if st == 'fight' then self:stand(level, self.x); self:enter('prowl'); return end

    if st == 'prowl' then
        -- RABIA: la primera vez que baja de rageAt, ruge y le salen los cristales
        if not self.rage and frac <= (p.rageAt or 0.4) then
            self.rage, self.phase = true, 3
            self:enter('roar')
            Sound.play('mgloomyRoar')
            Entity.emitFx('shake_roar', self.x, self.y)
            return
        end
        if self.rage then self.shriekT = self.shriekT + dt end
        self.pingT = self.pingT + dt
        -- la luz lo asusta un momento
        if self.flinchCd <= 0 and self:lit(level) then
            self.flinchCd = 2.5
            self:enter('flinch')
            return
        end
        -- un "!" reciente: a por él
        if self.tx and self.tAge <= FRESH and self.cdT <= 0 then
            self:startAim(level)
            return
        end
        if self.rage and self.shriekT >= (p.shriekEvery or 13) then
            self.shriekT = 0
            self:enter('shriek')
            Sound.play('mgloomyShriek')
            return
        end
        if self.pingT >= (p.pingEvery or 2.4) then
            self.pingT = 0
            self:enter('ping')
            return
        end
        -- ronda: de un lado a otro de su arena, buscando
        local nx = self.x + self.dir * WALK[ph] * dt
        if nx <= zx0 + EDGE then nx, self.dir = zx0 + EDGE, 1 elseif nx >= zx1 - EDGE then nx, self.dir = zx1 - EDGE, -1 end
        self.face = self.dir
        self:stand(level, nx)
        self:walkAnim(dt)

    elseif st == 'ping' then
        if t >= 0.2 and not self.pinged then self.pinged = true; self:ping() end
        if t >= PING_T then self.pinged = nil; self:enter('prowl') end

    elseif st == 'roar' then
        if t >= ROAR_T then self:enter('prowl') end

    elseif st == 'shriek' then
        if t >= 0.5 and self.dimT <= 0 then
            self.dimT = p.dimTime or 6
            level.lightScale = p.dimScale or 0.5
            self:summon(level)
            Entity.emitFx('shake_roar', self.x, self.y)
        end
        if t >= ROAR_T then self:enter('prowl') end

    elseif st == 'aim' then
        if self:lit(level) and t > 0.1 then                 -- la luz lo asusta: cancela
            self.icon, self.iconT, self.kind = 3, 1.4, 0
            self.cdT = 0.8
            self:enter('flinch')
            return
        end
        if t >= AIM_T[ph] then
            if self.kind == KIND.claw then
                self:enter('claw')
                Sound.play('megaClack', 1.3)
            elseif self.kind == KIND.charge then
                self:enter('charge')
                Sound.play('mgloomyDrop')
            else
                self.jx0, self.jy0 = self.x, self.y
                self:enter('pounce')
                Sound.play('mgloomyDrop')
            end
        end

    elseif st == 'flinch' then
        if t >= FLINCH_T then self:enter('prowl') end

    elseif st == 'claw' then
        if t <= 0.22 then self:hitBox(level, self:clawBox(), HIT_AIR, self.x) end
        if t >= CLAW_T + 0.35 then self:afterAttack() end

    elseif st == 'charge' then
        local nx = self.x + self.face * CHARGE[ph] * dt
        local done = (self.face > 0 and nx >= self.endX) or (self.face < 0 and nx <= self.endX)
        if done then nx = self.endX end
        self:stand(level, nx)
        self:walkAnim(dt, true)
        self:touch(level)
        if done then
            Sound.play('mgloomySlam', 1.2)
            Entity.emitFx('shake_small', self.x, self.y)
            self.hitOnce, self.kind = false, 0
            self:enter('tired')
        end

    elseif st == 'pounce' then
        local k = math.min(1, t / JUMP_T)
        local y1 = self.markY - REST
        self.x = self.jx0 + (self.markX - self.jx0) * k
        self.y = self.jy0 + (y1 - self.jy0) * k - math.sin(k * math.pi) * 300
        self:touch(level)
        if k >= 1 then
            self.x, self.y = self.markX, y1
            self:slam(level)
            self.hitOnce, self.kind = false, 0
            self:enter('tired')
        end

    elseif st == 'tired' then
        if self:lit(level) then
            Sound.play('mgloomyDazzled')
            self:enter('dazzled')
        elseif t >= TIRED_T[ph] then
            self:afterAttack()
        end

    elseif st == 'dazzled' then
        if t >= DAZZLE_T then self:afterAttack() end

    elseif st == 'recover' then
        if t >= 0.6 then self:afterAttack() end

    elseif st == 'taunt' then
        if t >= TAUNT_T then self:enter('prowl') end
    end
end

-- ── Red ──────────────────────────────────────────────────────────────────────
-- { fase, cuadro, hacia dónde mira, marca x, y, fin de la embestida, ataque (0 ninguno, 1 embestida,
--   2 pinzas, 3 salto), luz·100 (0 = normal), icono, rabia, nAros, {id, x, y, t·100}… }
local NB = 10
function MG:netPackExtra()
    local out = { self.phase, self.frame, self.face, self.markX, self.markY, self.endX, self.kind,
                  (self.dimT > 0) and math.floor((self.props.dimScale or 0.5) * 100) or 0, self.icon or 0,
                  self.rage and 1 or 0, #self.pings }
    for _, p in ipairs(self.pings) do
        out[#out + 1] = p.id; out[#out + 1] = p.x; out[#out + 1] = p.y; out[#out + 1] = math.floor(p.t * 100)
    end
    return out
end
function MG:netApplyExtra(a, b, f)
    if type(b[1]) ~= 'number' then return end
    self.phase, self.frame, self.face, self.markX, self.markY, self.endX, self.kind = b[1], b[2], b[3], b[4], b[5], b[6], b[7]
    if self.levelRef then self.levelRef.lightScale = (b[8] > 0) and (b[8] / 100) or nil end
    self.dimT = (b[8] > 0) and 1 or 0
    self.icon = b[9] or 0
    self.rage = b[10] == 1
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
    if st == 'pounce' then return F_LEAP end
    if st == 'taunt' then return (math.floor(t * 8) % 2 == 0) and F_CROUCH or F_IDLE end
    if st == 'aim' or st == 'dazzled' or st == 'recover' or st == 'tired' or st == 'flinch' then return F_CROUCH end
    if st == 'roar' or st == 'shriek' then return F_SCARED end              -- (patas abiertas, cuerpo en alto)
    if st == 'intro' or st == 'ready' then return (t >= 1.5 and t < 2.9) and F_SCARED or F_IDLE end
    if st == 'ping' or st == 'claw' or st == 'dormant' then return F_IDLE end
    return math.max(1, math.min(4, self.frame or 1))
end

-- ¿Ruge ahora? (pinzas en alto temblando: el rugido de la rabia, el grito y el de la entrada)
function MG:roaring()
    local st, t = self.state, self.deadTimer or 0
    return st == 'roar' or st == 'shriek' or ((st == 'intro' or st == 'ready') and t >= 1.5 and t < 2.9)
end

-- Pose de la pinza de `side` (-1 izquierda, 1 derecha): cuánto sale hacia fuera y baja (px de
-- arte), si va alzada (punta arriba) y su cuadro (1 abierta, 2 cerrada)
function MG:clawPose(side, now)
    local st, t = self.state, self.deadTimer or 0
    local out, dy, raised, fr, outward = 0, 0, false, 1, false
    local facing = side == (self.face or 1)
    if self:roaring() then
        raised, out, dy = true, 1 + math.sin(now * 50 + side) * 0.5, -1 + math.sin(now * 43) * 0.4
    elseif st == 'ping' or st == 'taunt' then
        raised, dy = true, -1
        fr = (math.floor(t * 9) % 2 == 0) and 2 or 1                    -- chasquea
    elseif st == 'aim' then
        fr = 2
        if self.kind == KIND.claw then out, outward = facing and -3 or 0, facing      -- la pinza de ese lado, atrás y ya hacia fuera
        else out, dy = 0, -0.5 + math.sin(now * 40) * 0.3 end
    elseif st == 'claw' then
        if facing then
            local k = math.min(1, t / 0.07)
            if t > CLAW_T then k = math.max(0, 1 - (t - CLAW_T) / 0.2) end
            out, dy, fr, outward = 9 * k, 2.5 * k, (t < 0.22) and 1 or 2, true   -- estocada (baja a la altura del jugador)
        else out = -1 end
    elseif st == 'charge' then
        out, fr, outward = facing and 2.5 or 0, facing and 1 or 2, facing
    elseif st == 'pounce' then
        raised, out = true, 1
    elseif st == 'tired' then
        dy = 2 + math.sin(now * 5) * 0.4
    elseif st == 'dazzled' or st == 'flinch' then
        out, dy, fr = -4, -1.5, 2                                       -- se tapa
    elseif st == 'dying_curl' or st == 'dying_out' then
        dy, fr = 3, 2
    else
        dy = math.sin(now * 4 + side * 1.3) * 0.4
        if math.floor(now * 0.6 + side * 0.37) % 4 == 0 and (now * 0.6 + side * 0.37) % 1 < 0.15 then fr = 2 end
    end
    return out, dy, raised, fr, outward
end

-- Dibuja las pinzas con `sheet` (la normal, la de la rabia o el brillo de sus cristales). La hoja
-- es la pinza con la punta a la izquierda y la unión a la derecha. En reposo miran HACIA DENTRO
-- ("C Ↄ": la punta hacia el cuerpo, la palma fuera, como las de los otros Megas); al dar la
-- estocada y al embestir, la de ese lado se estira hacia FUERA; alzadas = giradas 90° exactos.
function MG:drawClaws(camX, camY, now, sheet)
    local st = self.state
    if st == 'dying_out' and (self.deadTimer or 0) > 0.4 then return end
    sheet = sheet or (self.rage and clawR or clawS)
    local oy = (sheet == clawS) and CLAW_H / 2 or (5 + CLAW_H / 2)      -- (las de la rabia llevan 5 filas de cristales encima)
    for _, side in ipairs({ -1, 1 }) do
        local out, dy, raised, fr, outward = self:clawPose(side, now)
        local ax = self.x - camX + side * (5.5 * MS + out * MS)
        local ay = self.y - camY + CLAW_DY * MS + dy * MS
        if raised then
            local rot = (side < 0) and (math.pi / 2) or (-math.pi / 2)
            -- (espejadas a lo largo: el dorso, con los cristales de la rabia, queda hacia FUERA y no sobre la cabeza)
            love.graphics.draw(sheet.image, sheet.quads[fr], math.floor(ax), math.floor(ay), -rot, side * MS, MS, CLAW_W, oy)
        elseif outward then
            love.graphics.draw(sheet.image, sheet.quads[fr], math.floor(ax), math.floor(ay), 0, -side * MS, MS, CLAW_W, oy)
        else
            love.graphics.draw(sheet.image, sheet.quads[fr], math.floor(ax), math.floor(ay), 0, side * MS, MS, 0, oy)
        end
    end
end

function MG:drawSheet(sheet, camX, camY, ox, oy)
    local sx, sy = math.floor(self.x - camX + (ox or 0)), math.floor(self.y - camY + (oy or 0))
    local st = self.state
    if st == 'dazzled' or st == 'dying_curl' or self:roaring() then sx = sx + math.floor(math.sin(love.timer.getTime() * 50) * 2) end
    love.graphics.draw(sheet.image, sheet.quads[self:frameNow()], sx, sy, 0, MS, MS, FW / 2, BODY_ROW)
end

function MG:visible() return self.state ~= 'dormant' and self.state ~= 'dead' end

function MG:render(camX, camY)
    if not self:visible() then return end
    local a = self:ghostAlpha()
    if self.state == 'dying_out' then a = math.max(0, 1 - math.max(0, (self.deadTimer or 0) - (OUT_T - 0.7)) / 0.7) end
    if self:flashRed() then love.graphics.setColor(1, 0.4, 0.4, a) else love.graphics.setColor(1, 1, 1, a) end
    self:drawSheet(body, camX, camY)
    self:drawClaws(camX, camY, love.timer.getTime())
    love.graphics.setColor(1, 1, 1, 1)
end

local function dashH(x0, x1, y, a, thick)
    if x1 < x0 then x0, x1 = x1, x0 end
    love.graphics.setColor(WARN[1], WARN[2], WARN[3], a)
    local h = thick or 6
    for x = x0, x1 - 1, 28 do love.graphics.rectangle('fill', x, y - h / 2, math.min(16, x1 - x), h) end
end

-- Lo que se ve a oscuras: el aro de la ecolocalización, la marca del ataque y sus ojos (y cristales)
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
    local fy = math.floor(self.y + REST - camY)
    if (st == 'aim' or st == 'charge') and self.kind == KIND.charge then
        dashH(math.floor(self.x - camX), math.floor(self.endX - camX), fy - 10, blink)
    elseif (st == 'aim' or st == 'claw') and self.kind == KIND.claw then
        dashH(math.floor(self.x - camX), math.floor(self.x + self.face * CLAW_REACH - camX), math.floor(self.y - camY + 16), blink, 10)
    elseif (st == 'aim' or st == 'pounce') and self.kind == KIND.pounce then
        love.graphics.setColor(WARN[1], WARN[2], WARN[3], blink)
        markS:draw((math.floor(now * 12) % 2) + 1, math.floor(self.markX - camX), math.floor(self.markY - camY - 16), 0, 8, 8)
    end
    -- ojos (y cristales de la rabia): parpadean al apuntar y al burlarse; se apagan al morir
    local a = 0.95
    if st == 'aim' then a = (math.floor(now * 20) % 2 == 0) and 1 or 0.3
    elseif st == 'taunt' or st == 'ping' then a = (math.floor(now * 9) % 2 == 0) and 1 or 0.55
    elseif st == 'dazzled' then a = 0.35 + 0.2 * math.sin(now * 30)
    elseif st == 'dying_curl' then a = 0.5 + 0.4 * math.sin(now * 40)
    elseif st == 'dying_out' then a = math.max(0, 0.7 * (1 - t / (OUT_T * 0.7)))
    elseif st == 'intro' then a = math.min(1, t / 0.6) end
    if a > 0.01 then
        love.graphics.setColor(GLOW[1], GLOW[2], GLOW[3], a)
        self:drawSheet(glow, camX, camY)
        love.graphics.setBlendMode('add')
        love.graphics.setColor(GLOW[1], GLOW[2], GLOW[3], 0.22 * a)
        for _, o in ipairs({ { MS, 0 }, { -MS, 0 }, { 0, MS }, { 0, -MS } }) do self:drawSheet(glow, camX, camY, o[1], o[2]) end
        love.graphics.setBlendMode('alpha')
        -- rabia: las puntas de los cristales de las pinzas brillan (a oscuras se ve por dónde andan)
        if self.rage then
            love.graphics.setColor(CRYS[1], CRYS[2], CRYS[3], a)
            self:drawClaws(camX, camY, now, clawRG)
            love.graphics.setBlendMode('add')
            love.graphics.setColor(CRYS[1], CRYS[2], CRYS[3], 0.3 * a)
            self:drawClaws(camX + MS, camY, now, clawRG); self:drawClaws(camX - MS, camY, now, clawRG)
            self:drawClaws(camX, camY + MS, now, clawRG); self:drawClaws(camX, camY - MS, now, clawRG)
            love.graphics.setBlendMode('alpha')
        end
    end
    if (self.icon or 0) > 0 then                          -- ("…": la luz lo ha asustado)
        love.graphics.setColor(0.8, 0.85, 1, 0.95)
        love.graphics.draw(icons.image, icons.quads[self.icon], math.floor(self.x - camX), math.floor(self.y - camY - 90), 0, 6, 6, 3.5, 9)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local G = 'Mega Crabby lúgubre'
return {
    name = 'megagloomy', label = 'Mega Crabby lúgubre', category = 'Jefes',
    description = 'Jefe de los niveles A OSCURAS, de tierra. Ciego: ronda buscándote y SOLO ataca si hay un "!" ROJO '
               .. '(un ruido, o su aro te pilla moviéndote). Marca cada ataque: línea por el suelo = embestida (agáchate), '
               .. 'barra corta = estocada con la pinza, diana = salto. Solo se le daña alumbrándolo cuando queda agotado. '
               .. 'Con poca vida ruge, le salen cristales, oscurece la arena y llama a Crabbies lúgubres.',
    class = MG,
    boss = { title = 'MEGA CRABBY LÚGUBRE' },
    hide = Boss.HIDE,
    defaults = { points = 60 },
    props = Boss.props({ hp = 8, hpPerPlayer = 3 }, {
        { key='pingEvery', kind='number', label='Ecolocalización cada (s)', group=G, default=2.4, min=0.8, max=8, step=0.1,
          help='Alza las pinzas y suelta un aro: detecta ("!" rojo) a los jugadores que se mueven cuando les pasa por encima' },
        { key='phase2', kind='number', label='Fase 2 con vida ≤', group=G, default=0.66, min=0.1, max=0.95, step=0.01,
          help='Añade el salto (alternando con la embestida) y va más rápido' },
        { key='rageAt', kind='number', label='Rabia con vida ≤', group=G, default=0.4, min=0.05, max=0.9, step=0.01,
          help='Ruge, le salen cristales, va más rápido y grita' },
        { key='shriekEvery', kind='number', label='Rabia: grita cada (s)', group=G, default=13, min=4, max=60, step=0.5 },
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
