-- MEGA CRABBY LÚGUBRE (jefe de los niveles A OSCURAS). Ciego: no te ve. Es sobre todo de TIERRA,
-- como los Crabbies de fuera: anda por el suelo de su arena buscándote. Toda la pelea sale de una
-- regla que se ve en pantalla:
--
--     SOLO ATACA SI HAY UN "!" ROJO, Y ATACA ESE "!".   (y solo se le daña alumbrándolo cuando
--                                                         se queda agotado tras un ataque)
--
-- Hay DOS maneras de que salga un "!":
--   ECOLOCALIZACIÓN ('ping'): cada `pingEvery` s se para, alza las pinzas y las chasquea: sale un
--     ARO desde su cuerpo. A quien el aro TOCA lo detecta, aunque esté quieto y en silencio (es
--     ecolocalización: no hace falta que suenes) → "!" donde estás → SALTA ahí ('pounce').
--   RUIDOS del jugador (src/world/systems/Noise.lua: dar un golpe < recibirlo < matar a un enemigo < ground
--     pound; andar y saltar NO): un sitio que investigar → EMBISTE hacia él ('charge').
--   Si el "!" queda al alcance de sus pinzas, en vez de eso da una ESTOCADA ('claw').
-- SIN "!" reciente solo ronda ('prowl'). CON uno APUNTA ('aim': ojos que parpadean, su aviso, y
-- la marca del ataque) y ataca:
--   PINZAS    ('claw')   la pinza más cercana APUNTA al jugador desde su unión (la línea roja y la
--                        pinza lo siguen, arriba o abajo; fija los últimos CLAW_LOCK s) y sale
--                        recta hacia ahí: da donde se ve que da.
--   EMBESTIDA ('charge') una línea por el suelo hasta la pared → corre hasta ella. Se esquiva
--                        AGACHÁNDOSE (pasa por encima: sus patas no cuentan) o saltándolo.
--   SALTO     ('pounce') una diana en el suelo → salta ahí y cae de golpe.
--   TECHO     ('climb' → 'ceil_ping' → 'ceil_wait' → 'aim' → 'dive') cada `ceilingEvery` s: corre a
--                        la pared, la trepa, va por el techo, suelta un aro GRANDE desde arriba y
--                        se LANZA a donde te haya detectado (diana en el suelo). Su ataque de
--                        siempre: es de tierra, pero sigue siendo un cangrejo de cueva.
--   Tras embestida, salto o techo queda AGOTADO ('tired'). Tocarlo en un ataque = 1 de vida +
--   empujón. Si mientras apunta en el suelo le da una LINTERNA, se asusta y cancela ("…").
-- CÓMO SE LE DAÑA: AGOTADO (`TIRED_T` s) es inmune sin luz (rebotas); alumbrado → DESLUMBRADO
--   ('dazzled': se tapa con las pinzas y le salen ESTRELLITAS: ahora sí es vulnerable): pisotón 1 /
--   ground pound 2 (un golpe).
-- FASE 2 (vida ≤ `phase2`): más rápido.
-- RABIA (vida ≤ `rageAt`): RUGE ('roar', pinzas en alto), le salen CRISTALES que brillan en las
--   PINZAS (no en el lomo: ahí parecerían pinchos y es donde se le pisa; hojas claw_rage_left /
--   claw_rage_glow), todo va × `rageSpeed` (como los Mega Crabby de fuera), y se le NOTA igual que
--   a ellos: temblor leve, pulso rojizo y símbolos de enfado. Cada `shriekEvery` s GRITA: las
--   linternas alcanzan la mitad `dimTime` s (level.lightScale) y llama a Crabbies lúgubres.
-- BURLA ('taunt'): si un ataque le da a alguien, se queda un momento chasqueando las pinzas.
-- MUERTE de cangrejo (sin explosiones): se encoge temblando ('dying_curl') y se apaga ('dying_out').
--
-- PINZAS: largas y afiladas, en hoz (las de los otros Megas son robustas); en reposo miran hacia
-- DENTRO ("C Ↄ"); en una hoja aparte (claw_left-Sheet: abierta / cerrada; la derecha es su espejo)
-- y con su pose en cada momento (MG:clawPose). Solo dibujo: sale de state + deadTimer + la marca.
-- Posición = el centro de su CAPARAZÓN (su caja: lo que se ve; las patas no cuentan); `ang` = giro
-- del cuerpo (0 en el suelo, ±90° en la pared, 180° en el techo).
-- Arte: assets/images/bosses/megagloomy/ (el MISMO píxel que el pequeño, a escala 10; tools/ui/
-- make_gloomy_sprites.py); sonidos: tools/sounds/gloomy.py (MEGA).

local Entity      = require 'src/world/entities/base/Entity'
local Boss        = require 'src/world/entities/base/Boss'
local Lights      = require 'src/world/level/Lights'
local Noise       = require 'src/world/systems/Noise'
local SpriteStrip = require 'src/fx/SpriteStrip'
local BossFx      = require 'src/fx/BossFx'
local strike      = Boss.strike

local T = TILE_PX
local MS = 10                              -- escala (el pequeño: 4)
local FW, FH = 38, 21                      -- cuadro (px de arte)
local BODY_ROW = 11                        -- fila del centro del CAPARAZÓN en el cuadro
local BW, BH = 11 * MS, 6 * MS             -- caja: el caparazón
local REST = (FH - BODY_ROW) * MS          -- del centro del caparazón al suelo
local CLAW_W, CLAW_H = 14, 7               -- cuadro de la pinza
local F_IDLE, F_CROUCH, F_LEAP, F_SCARED, F_DEAD = 5, 6, 7, 8, 9

local MG = Entity.extend(Boss, {
    -- (aliados en Xtra extremo: qué estados son atacar)
    ATTACKS = { aim = true, charge = true, claw = true, pounce = true, climb = true, ceil_ping = true, ceil_wait = true,
                dive = true, ping = true },
    debugColor = { 0.6, 0.8, 1 },
    hitbox = { outerW = 1, outerH = 1, innerW = 0.9, innerH = 0.9 },
})
MG.hurtSound   = 'mgloomyHurt'
MG.introLength = 3.4
MG.wantsLevel  = true

local KIND = { charge = 1, claw = 2, pounce = 3, dive = 4 }
-- Ritmo por fase (1, 2); la rabia lo multiplica todo por `rageSpeed`
local WALK       = { 95, 115 }             -- px/s rondando
local CHARGE     = { 640, 730 }            -- px/s embistiendo
local AIM_T      = { 0.9, 0.8 }           -- s apuntando (con la marca puesta)
local TIRED_T    = { 2.3, 2.0 }            -- s agotado (hay que alumbrarlo aquí)
local ATTACK_CD  = { 1.3, 1.0 }            -- s entre ataques
local FRESH      = 4.0                     -- s que un "!" sirve para atacar
local CLAW_REACH = 240                     -- px que alcanza la estocada desde la unión de la pinza (lo que se ve)
local CLAW_PICK  = 4.0 * T                 -- un "!" a menos de esto del cuerpo: estocada
local CLAW_LOCK  = 0.2                     -- s finales de apuntar en que la pinza ya no sigue al jugador
local CLIMB_SPD  = 520                     -- px/s corriendo a la pared, trepando y por el techo
local DIVE_SPD   = 1250                    -- px/s lanzándose desde el techo
local RING_CEIL  = 13 * T                  -- el aro que suelta desde el techo llega más lejos
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
local EDGE       = BW / 2 + 70             -- hasta dónde se acerca a las paredes
local HIT_AIR    = { 1, 620, -460, 0.25, 0 }
local HIT_SLAM   = { 1, 900, -560, 0.3, 0.3 }
local GLOW       = { 1, 0.77, 0.35 }
local RING       = { 0.55, 0.95, 1 }
local WARN       = { 1, 0.28, 0.2 }
local CLAW_DY    = 2                        -- unión de las pinzas, en px de arte bajo el centro (bajas: salen de debajo del caparazón)
local CRYS       = { 0.85, 0.66, 1 }        -- cristales de la rabia

local clawS, clawR, clawRG, icons
-- Sus animaciones del cuerpo (assets/anim/bosses/megagloomy.json), pedidas por nombre
MG.animId = 'bosses/megagloomy'
function MG.loadAssets()
    if clawS then return end
    local D = 'assets/images/bosses/megagloomy/'
    clawS = SpriteStrip.load(D .. 'claw_left-Sheet.png', CLAW_W)
    clawR = SpriteStrip.load(D .. 'claw_rage_left-Sheet.png', CLAW_W)        -- (rabia: con cristales en el dorso)
    clawRG = SpriteStrip.load(D .. 'claw_rage_glow-Sheet.png', CLAW_W)       -- (… y sus puntas, que brillan a oscuras)
    icons = SpriteStrip.load('assets/images/enemies/gloomy/icons-Sheet.png', 7)
end
function MG.sizePx() return BW, BH end

function MG:initBoss()
    self.phase, self.rage = 1, false
    self.face, self.dir = 1, 1
    self.pings, self.nextPing = {}, 0
    self.pingT, self.cdT, self.shriekT, self.dimT, self.flinchCd, self.ceilT = 0, 0, 0, 0, 0, 0
    self.ang = 0
    self.tx, self.ty, self.tAge = nil, nil, 99
    self.markX, self.markY, self.endX, self.kind = 0, 0, 0, 0
    self.hitOnce, self.gloat = false, false
    self.attackN = 0
    self.frame, self.animT = 1, 0
    self.icon, self.iconT = 0, 0
    self.summonKey = 'gl' .. self.col .. ',' .. self.row
end

function MG:bossPhase() return self.phase or 1 end
-- Ritmo: la fila de las tablas (1, 2) y el multiplicador de la rabia
function MG:pace() return math.min(2, self.phase or 1), self.rage and (self.props.rageSpeed or 1.45) or 1 end
-- (enter, zoneBounds, minions, strike: los de Boss)
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
    -- (los golpes de un jefe no cuentan: con un aliado — Xtra extremo — iba a por el otro jefe)
    local z, seq = Noise.heard(level, self.x, self.y, self.heardSeq, HEAR_K, 'boss')
    self.heardSeq = seq
    if z then
        local zx0, zx1, zy0, zy1 = self:zoneBounds()
        if z.x > zx0 and z.x < zx1 and z.y > zy0 - T and z.y < zy1 + T then
            self.tx, self.ty, self.tAge, self.tEcho = z.x, z.y, 0, false
            -- (quién lo ha hecho, si está ahí: la estocada le apunta a él)
            self.tPa = nil
            for _, pa in ipairs(level.players or {}) do
                if math.abs(pa.x - z.x) < 2.5 * T and math.abs(pa.y - z.y) < 2.5 * T then self.tPa = pa end
            end
        end
    end
end

function MG:lit(level) return (Lights.lit(level, self.x, self.y)) end

-- ── Ecolocalización: el aro detecta a quien TOCA (aunque esté quieto y callado) ─
function MG:ping(max)
    self.nextPing = self.nextPing % 999 + 1
    self.pings[#self.pings + 1] = { id = self.nextPing, x = math.floor(self.x), y = math.floor(self.y), t = 0, hit = {},
                                  max = max or RING_MAX }
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
                        -- ¡detectado!: su "!" rojo ahí, y ahí va a saltar
                        self.tx, self.ty, self.tAge, self.tEcho, self.tPa = pa.x, pa.y, 0, true, pa
                        self.echoHit = true
                        Noise.emit(pa.x, pa.y, Noise.R.faint)
                        self.heardSeq = (level.noises and level.noises.seq) or self.heardSeq     -- (no es un ruido: es su marca)
                    end
                end
            end
        end
        if r1 >= (p.max or RING_MAX) then table.remove(self.pings, i) end
    end
end

-- ── Súbditos (Crabbies lúgubres de reserva: Boss:minions) ───────────────────
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
    Noise.emit(self.x, self.y, Noise.R.boss, true, 'boss')         -- (los Crabbies lúgubres lo oyen y vienen; sin marca)
    self.heardSeq = (level.noises and level.noises.seq) or self.heardSeq     -- (su propio golpe no cuenta)
    self:hitBox(level, { x = self.x - BW / 2 - 50, y = self.y - BH / 2, w = BW + 100, h = REST + BH / 2 + 8 }, HIT_SLAM, self.x)
end

-- La estocada: de la UNIÓN de la pinza de ese lado (la más cercana a la marca) hacia la marca
-- (el jugador). Devuelve la unión y la dirección; la usan la sim, la línea roja y el dibujo
function MG:clawAim()
    local side = self.face or 1
    local px, py = self.x + side * 5.5 * MS, self.y + CLAW_DY * MS
    local dx, dy = (self.markX or px) - px, (self.markY or py) - py
    local d = math.sqrt(dx * dx + dy * dy)
    if d < 1 then return px, py, side, 0 end
    return px, py, dx / d, dy / d
end

-- F1: lo que golpea en cada ataque (el caparazón con margen en la embestida, el salto y el picado; la pinza estirada)
function MG:debugBoxes()
    local st, out = self.state, {}
    if st == 'dive' or st == 'charge' or st == 'pounce' then
        local ob = self:getOuterBounds()
        out[1] = { x = ob.x - 30, y = ob.y - 12, w = ob.w + 60, h = ob.h + 20 }
    elseif st == 'claw' or st == 'aim' then
        local px, py, ux, uy = self:clawAim()
        for d = 40, CLAW_REACH, 30 do
            out[#out + 1] = { x = px + ux * d - 20, y = py + uy * d - 20, w = 40, h = 40, kind = (st == 'aim') and 'area' or nil }
        end
    end
    return out
end

-- Da a lo largo de la pinza, hasta donde ha salido (k 0..1)
function MG:clawHit(level, k)
    local px, py, ux, uy = self:clawAim()
    for d = 40, CLAW_REACH * k, 30 do
        self:hitBox(level, { x = px + ux * d - 20, y = py + uy * d - 20, w = 40, h = 40 }, HIT_AIR, self.x)
    end
end

-- ── El techo: corre a la pared más cercana, la trepa y va por el techo ───────
-- Camino = suelo (a) + pared (b) + techo (c), siempre con el caparazón a REST de la superficie
function MG:startClimb(level)
    local zx0, zx1, zy0 = self:zoneBounds()
    local s = (self.x - zx0 < zx1 - self.x) and -1 or 1
    local wx = (s < 0) and (zx0 + REST) or (zx1 - REST)
    local cx = math.max(zx0 + EDGE, math.min(zx1 - EDGE, self.tx or (zx0 + zx1) / 2))     -- (sobre lo último que sabe)
    self.path = { s = s, x0 = self.x, wx = wx, fy = self.y, cy = zy0 + REST, cx = cx,
                  a = math.abs(self.x - wx), b = self.y - (zy0 + REST), c = math.abs(cx - wx) }
    self.pathU, self.kind, self.ceilT = 0, 0, 0
    self:enter('climb')
end
function MG:pathAt(u)
    local P = self.path
    local x, y
    if u <= P.a then x, y = P.x0 + P.s * u, P.fy
    elseif u <= P.a + P.b then x, y = P.wx, P.fy - (u - P.a)
    else x, y = P.wx - P.s * math.min(P.c, u - P.a - P.b), P.cy end
    local W = 60                                            -- (px en los que gira al doblar cada esquina)
    local q1 = math.max(0, math.min(1, (u - (P.a - W / 2)) / W))
    local q2 = math.max(0, math.min(1, (u - (P.a + P.b - W / 2)) / W))
    return x, y, -P.s * (q1 + q2) * math.pi / 2
end

-- ── Reglas con el jugador (sin efectos: el cliente predice el rebote) ────────
local DEATH = { dying_curl = true, dying_out = true }
function MG:isDying() return DEATH[self.state] == true or Boss.isDying(self) end
function MG:releasesZone() return self.state == 'dying_out' or self.state == 'dead' end
function MG:isVulnerable() return self.state == 'dazzled' and not self.hitOnce end
local SOLID = { prowl = true, ping = true, tired = true, dazzled = true, aim = true, flinch = true, taunt = true, recover = true }
function MG:isSolidBody() return Boss.isSolidBody(self) and SOLID[self.state] == true and self.kind ~= KIND.dive end
function MG:interact(pa)
    local st = self.state
    if st == 'charge' or st == 'pounce' or st == 'claw' or st == 'roar' or st == 'shriek' or st == 'climb' or st == 'ceil_ping'
       or st == 'ceil_wait' or st == 'dive' or self.kind == KIND.dive then return nil end   -- (touch / nada)
    return Boss.interact(self, pa)
end
function MG:onDamaged(n, kind)
    self.hitOnce = true
    local n = self.levelRef and self.levelRef.noises
    if n then self.heardSeq = n.seq end                     -- (el golpe que le dan no es un sitio que investigar)
    self:enter('recover')
end

-- Muerte de CANGREJO (sin explosiones): se encoge y se apaga
function MG:defeat()
    self.hp, self.inv = 0, 0
    self.vx, self.vy = 0, 0
    self.pings, self.dimT, self.icon, self.kind, self.ang = {}, 0, 0, 0, 0
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
    self.pingT, self.cdT, self.ceilT = 1.2, 1.0, (self.props.ceilingEvery or 14) * 0.5     -- (el primero del techo, antes)
end
function MG:onIntroStart(level)
    local zx0, zx1, zy0 = self:zoneBounds()
    -- (cae DONDE lo ha puesto el editor: antes caía siempre en el centro de la zona, estuviera donde estuviera)
    self:stand(level, self.x)
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
    -- (ritmo y nº de pasos: los de su animación `walk`, o `run` cuando va deprisa)
    local set = self:anims()
    local step = 1 / set:fps(fast and 'run' or 'walk')
    if self.animT >= step then
        self.animT = self.animT - step
        self.frame = self.frame % set:count('walk') + 1
        -- (un roce de vez en cuando, no cada paso: el silencio es la tensión)
        self.stepN = (self.stepN or 0) + 1
        if self.stepN % (fast and 3 or 8) == 0 then Sound.play('mgloomyStep') end
    end
end

-- Vuelve a rondar (o se burla, si acaba de darle a alguien)
function MG:afterAttack()
    self.kind = 0
    local ph, k = self:pace()
    self.cdT = ATTACK_CD[ph] / k
    if self.gloat then self.gloat = false; self:enter('taunt') else self:enter('prowl') end
end

-- Apunta al último "!": elige el ataque y pone su marca
function MG:startAim(level)
    local zx0, zx1 = self:zoneBounds()
    local tx = math.max(zx0 + EDGE, math.min(zx1 - EDGE, self.tx))
    self.face = (self.tx >= self.x) and 1 or -1
    local d = math.sqrt((self.tx - self.x) ^ 2 + (self.ty - self.y) ^ 2)
    local kind
    if d <= CLAW_PICK then
        kind = 'claw'                                       -- al alcance: estocada, apuntando ahí
        self.markX, self.markY = math.floor(self.tx), math.floor(self.ty)
    else
        kind = self.tEcho and 'pounce' or 'charge'          -- lo detectó su aro: SALTA ahí; un ruido: embiste hacia él
        self.markX, self.markY = math.floor(tx), math.floor(self:floorY(level, tx))
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
    local ph, k = self:pace()
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
        self.ceilT = self.ceilT + dt
        -- la luz lo asusta un momento
        if self.flinchCd <= 0 and self:lit(level) then
            self.flinchCd = 2.5
            self:enter('flinch')
            return
        end
        -- un "!" reciente: a por él
        local may = self:mayAttack(level)                       -- (con un aliado: por turnos, Boss:mayAttack)
        if may and self.tx and self.tAge <= FRESH and self.cdT <= 0 then
            self:startAim(level)
            return
        end
        if self.rage and self.shriekT >= (p.shriekEvery or 13) then
            self.shriekT = 0
            self:enter('shriek')
            Sound.play('mgloomyShriek')
            return
        end
        -- al techo, a lanzarse desde arriba
        if may and self.ceilT >= (p.ceilingEvery or 14) / k and self.cdT <= 0 then
            self:startClimb(level)
            return
        end
        if may and self.pingT >= (p.pingEvery or 2.4) then
            self.pingT = 0
            self:enter('ping')
            return
        end
        -- ronda: de un lado a otro de su arena, buscando
        local nx = self.x + self.dir * WALK[ph] * k * dt
        if nx <= zx0 + EDGE then nx, self.dir = zx0 + EDGE, 1 elseif nx >= zx1 - EDGE then nx, self.dir = zx1 - EDGE, -1 end
        self.face = self.dir
        self:stand(level, nx)
        self:walkAnim(dt)

    elseif st == 'ping' then
        if t >= 0.2 and not self.pinged then self.pinged = true; self:ping() end
        if t >= PING_T then self.pinged = nil; self:enter('prowl') end

    elseif st == 'climb' then
        local P = self.path
        self.pathU = self.pathU + CLIMB_SPD * k * dt
        self.x, self.y, self.ang = self:pathAt(self.pathU)
        self.face = (self.pathU <= P.a + P.b) and P.s or -P.s
        self:walkAnim(dt, true)
        if self.pathU >= P.a + P.b + P.c then
            self.echoHit, self.pinged = false, nil
            self:enter('ceil_ping')
        end

    elseif st == 'ceil_ping' then                           -- desde el techo: un aro grande
        if t >= 0.2 and not self.pinged then self.pinged = true; self.echoHit = false; self:ping(RING_CEIL) end
        if t >= PING_T then self.pinged = nil; self:enter('ceil_wait') end

    elseif st == 'ceil_wait' then                           -- espera a que el aro toque a alguien
        if self.echoHit or t >= 1.1 then
            local tx = self.echoHit and self.tx or self.x   -- (a nadie: se deja caer donde está)
            tx = math.max(zx0 + EDGE, math.min(zx1 - EDGE, tx))
            self.markX, self.markY = math.floor(tx), math.floor(self:floorY(level, tx))
            self.kind, self.gloat, self.tAge = KIND.dive, false, FRESH + 1
            self:enter('aim')
            Sound.play('mgloomyListen')
        end

    elseif st == 'dive' then
        local q = math.min(1, t * DIVE_SPD * k / self.jd)
        local y1 = self.markY - REST
        self.x = self.jx0 + (self.markX - self.jx0) * q
        self.y = self.jy0 + (y1 - self.jy0) * q * q
        self.ang = self.jang * (1 - q)                      -- (se da la vuelta en el aire: cae de pie)
        self:touch(level)
        if q >= 1 then
            self.x, self.y, self.ang = self.markX, y1, 0
            self:slam(level)
            self.hitOnce, self.kind = false, 0
            self:enter('tired')
        end

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
        if self.kind == KIND.claw and t < AIM_T[ph] / k - CLAW_LOCK then
            -- la pinza SIGUE al jugador (con la más cercana) hasta casi el final
            local pa = self.tPa
            if pa and not pa.dying and pa.alive ~= false then self.markX, self.markY = math.floor(pa.x), math.floor(pa.y) end
            self.face = (self.markX >= self.x) and 1 or -1
        end
        if self.kind ~= KIND.dive and self:lit(level) and t > 0.1 then                 -- la luz lo asusta: cancela (en el techo ya no)
            self.icon, self.iconT, self.kind = 3, 1.4, 0
            self.cdT = 0.8
            self:enter('flinch')
            return
        end
        if t >= AIM_T[ph] / k then
            if self.kind == KIND.claw then
                self:enter('claw')
                Sound.play('megaClack', 1.3)
            elseif self.kind == KIND.charge then
                self:enter('charge')
                Sound.play('mgloomyDrop')
            elseif self.kind == KIND.dive then
                self.jx0, self.jy0, self.jang = self.x, self.y, self.ang
                self.jd = math.max(60, math.sqrt((self.markX - self.x) ^ 2 + (self.markY - REST - self.y) ^ 2))
                self:enter('dive')
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
        if t <= 0.22 then self:clawHit(level, math.min(1, t / 0.07)) end
        if t >= CLAW_T + 0.35 then self:afterAttack() end

    elseif st == 'charge' then
        local nx = self.x + self.face * CHARGE[ph] * k * dt
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
        local q = math.min(1, t / (JUMP_T / math.sqrt(k)))
        local y1 = self.markY - REST
        self.x = self.jx0 + (self.markX - self.jx0) * q
        self.y = self.jy0 + (y1 - self.jy0) * q - math.sin(q * math.pi) * 300
        self:touch(level)
        if q >= 1 then
            self.x, self.y = self.markX, y1
            self:slam(level)
            self.hitOnce, self.kind = false, 0
            self:enter('tired')
        end

    elseif st == 'tired' then
        if self:lit(level) then
            Sound.play('mgloomyDazzled')
            self:enter('dazzled')
        elseif t >= TIRED_T[ph] * (self.rage and 0.8 or 1) then
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
--   2 pinzas, 3 salto, 4 desde el techo), luz·100 (0 = normal), icono, rabia, giro·100, nAros,
--   {id, x, y, t·100, alcance}… }   (en la estocada la marca es adonde apunta la pinza)
local NB = 11
function MG:netPackExtra()
    local out = { self.phase, self.frame, self.face, self.markX, self.markY, self.endX, self.kind,
                  (self.dimT > 0) and math.floor((self.props.dimScale or 0.5) * 100) or 0, self.icon or 0,
                  self.rage and 1 or 0, math.floor((self.ang or 0) * 100 + 0.5), #self.pings }
    for _, p in ipairs(self.pings) do
        out[#out + 1] = p.id; out[#out + 1] = p.x; out[#out + 1] = p.y; out[#out + 1] = math.floor(p.t * 100)
        out[#out + 1] = math.floor(p.max or RING_MAX)
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
    self.ang = (b[11] or 0) / 100
    self.pings = {}
    for i = 0, (b[NB + 1] or 0) - 1 do
        local j = NB + 2 + i * 5
        self.pings[#self.pings + 1] = { id = b[j], x = b[j + 1], y = b[j + 2], t = (b[j + 3] or 0) / 100, max = b[j + 4] }
    end
end

-- ── Dibujo ───────────────────────────────────────────────────────────────────
-- QUÉ ANIMACIÓN toca (nombre, segundos dentro de ella y, andando, el paso): cuadros y ritmo los pone su conjunto
function MG:animNow()
    local st, t = self.state, self.deadTimer or 0
    if st == 'dying_out' or st == 'dead' then return 'dead', t end
    if st == 'dying_curl' then return 'scared', t end
    if st == 'pounce' or st == 'dive' then return 'leap', t end
    if st == 'taunt' then return 'taunt', t end
    if st == 'aim' or st == 'dazzled' or st == 'recover' or st == 'tired' or st == 'flinch' then return 'crouch', t end
    if st == 'roar' or st == 'shriek' then return 'scared', t end              -- (patas abiertas, cuerpo en alto)
    if st == 'intro' or st == 'ready' then
        if t >= 1.5 and t < 2.9 then return 'scared', t - 1.5 end
        return 'idle', t
    end
    if st == 'ping' or st == 'claw' or st == 'dormant' or st == 'ceil_ping' or st == 'ceil_wait' then return 'idle', t end
    return 'walk', nil, self.frame or 1
end
function MG:frameNow(pre)
    local set = self:anims()
    local name, t, k = self:animNow()
    name = (pre or '') .. name
    return k and set:frameN(name, k) or (set:frameAt(name, t))
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
    elseif st == 'ping' or st == 'taunt' or st == 'ceil_ping' then
        raised, dy = true, -1
        fr = (math.floor(t * 9) % 2 == 0) and 2 or 1                    -- chasquea
    elseif st == 'aim' then
        fr = 2
        if self.kind == KIND.claw then out, outward = facing and (-3 + math.sin(now * 45) * 0.3) or 0, facing   -- la de ese lado, atrás y apuntando
        else out, dy = 0, -0.5 + math.sin(now * 40) * 0.3 end
    elseif st == 'claw' then
        if facing then
            local k = math.min(1, t / 0.07)
            if t > CLAW_T then k = math.max(0, 1 - (t - CLAW_T) / 0.2) end
            out, fr, outward = 9 * k, (t < 0.22) and 1 or 2, true            -- estocada (hacia donde apunta: MG:clawAim)
        else out = -1 end
    elseif st == 'charge' then
        out, fr, outward = facing and 2.5 or 0, facing and 1 or 2, facing
    elseif st == 'pounce' or st == 'dive' then
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
        elseif outward and self.kind == KIND.claw and (st == 'aim' or st == 'claw') then
            -- la estocada: girada hacia donde apunta, desde su unión
            local px, py, ux, uy = self:clawAim()
            local th = math.atan2(uy, ux)
            local jx, jy = math.floor(px + ux * out * MS - camX), math.floor(py + uy * out * MS - camY)
            if side > 0 then love.graphics.draw(sheet.image, sheet.quads[fr], jx, jy, th, -MS, MS, CLAW_W, oy)
            else love.graphics.draw(sheet.image, sheet.quads[fr], jx, jy, th - math.pi, MS, MS, CLAW_W, oy) end
        elseif outward then
            love.graphics.draw(sheet.image, sheet.quads[fr], math.floor(ax), math.floor(ay), 0, -side * MS, MS, CLAW_W, oy)
        else
            love.graphics.draw(sheet.image, sheet.quads[fr], math.floor(ax), math.floor(ay), 0, side * MS, MS, 0, oy)
        end
    end
end

function MG:drawSheet(pre, camX, camY, ox, oy)
    local sx, sy = math.floor(self.x - camX + (ox or 0)), math.floor(self.y - camY + (oy or 0))
    local st = self.state
    if st == 'dazzled' or st == 'dying_curl' or self:roaring() then sx = sx + math.floor(math.sin(love.timer.getTime() * 50) * 2) end
    self:anims():drawFrame(self:frameNow(pre), sx, sy, 0, MS, MS, 0.5, BODY_ROW / FH)
end

-- ¿Se le nota la RABIA? (como al Mega Crabby: temblor leve, pulso rojizo y símbolos de enfado)
function MG:angry()
    return self.rage and not self:isDying() and self.state ~= 'roar' and self.state ~= 'dormant' and not EDITOR_VIEW
end

-- Gira el dibujo con el cuerpo (pared, techo, la voltereta al lanzarse). Devuelve si hay que hacer pop
function MG:pushTurn(camX, camY)
    local a = self.ang or 0
    if a == 0 then return false end
    local sx, sy = math.floor(self.x - camX), math.floor(self.y - camY)
    love.graphics.push()
    love.graphics.translate(sx, sy); love.graphics.rotate(a); love.graphics.translate(-sx, -sy)
    return true
end

function MG:visible() return self.state ~= 'dormant' and self.state ~= 'dead' end

function MG:render(camX, camY)
    if not self:visible() then return end
    local a = self:ghostAlpha()
    if self.state == 'dying_out' then a = math.max(0, 1 - math.max(0, (self.deadTimer or 0) - (OUT_T - 0.7)) / 0.7) end
    local now = love.timer.getTime()
    if self:flashRed() then love.graphics.setColor(1, 0.4, 0.4, a)
    elseif self:angry() then
        local q = 0.8 + 0.1 * math.sin(now * 6)             -- (rojizo que late, suave)
        love.graphics.setColor(1, q, q, a)
        camX = camX - math.floor(math.sin(now * 41) * 0.9 + 0.5)        -- (temblor leve: 1 px de vez en cuando)
    else love.graphics.setColor(1, 1, 1, a) end
    local turned = self:pushTurn(camX, camY)
    self:drawSheet('', camX, camY)
    self:drawClaws(camX, camY, now)
    if turned then love.graphics.pop() end
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
        love.graphics.setColor(RING[1], RING[2], RING[3], 0.85 * math.max(0, 1 - r / (p.max or RING_MAX)))
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
        -- de la unión de la pinza hacia donde apunta (sigue al jugador), hasta donde alcanza
        local px, py, ux, uy = self:clawAim()
        love.graphics.setColor(WARN[1], WARN[2], WARN[3], blink)
        for d = 30, CLAW_REACH, 30 do
            love.graphics.rectangle('fill', math.floor(px + ux * d - camX) - 5, math.floor(py + uy * d - camY) - 5, 10, 10)
        end
    elseif ((st == 'aim' or st == 'pounce') and self.kind == KIND.pounce) or ((st == 'aim' or st == 'dive') and self.kind == KIND.dive) then
        love.graphics.setColor(WARN[1], WARN[2], WARN[3], blink)
        BossFx.target((math.floor(now * 12) % 2) + 1, math.floor(self.markX - camX), math.floor(self.markY - camY - 16), 8, 8)
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
        local turned = self:pushTurn(camX, camY)
        love.graphics.setColor(GLOW[1], GLOW[2], GLOW[3], a)
        self:drawSheet('glow_', camX, camY)
        love.graphics.setBlendMode('add')
        love.graphics.setColor(GLOW[1], GLOW[2], GLOW[3], 0.22 * a)
        for _, o in ipairs({ { MS, 0 }, { -MS, 0 }, { 0, MS }, { 0, -MS } }) do self:drawSheet('glow_', camX, camY, o[1], o[2]) end
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
        if turned then love.graphics.pop() end
    end
    -- DESLUMBRADO: estrellitas girando sobre él (ahora es vulnerable)
    if st == 'dazzled' then BossFx.stars(self.x - camX, self.y - camY - 7 * MS, 8 * MS, 1.5 * MS, 7) end
    -- RABIA: símbolos de enfado alrededor de su cabeza (los de todos los jefes: BossFx)
    BossFx.anger(self, self:angry(), self.x - camX, self.y - camY - 40)
    if (self.icon or 0) > 0 then                          -- ("…": la luz lo ha asustado)
        love.graphics.setColor(0.8, 0.85, 1, 0.95)
        love.graphics.draw(icons.image, icons.quads[self.icon], math.floor(self.x - camX), math.floor(self.y - camY - 90), 0, 6, 6, 3.5, 9)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local G = 'Mega Crabby lúgubre'
return {
    name = 'megagloomy', label = 'Mega Crabby lúgubre', category = 'Jefes',
    description = 'Jefe de los niveles A OSCURAS, sobre todo de tierra. Ciego: ronda buscándote y SOLO ataca si hay un "!" ROJO: '
               .. 'su aro te detecta aunque estés quieto (→ SALTA ahí) o haces un ruido fuerte (→ EMBISTE hacia él); de cerca, '
               .. 'estocada con la pinza, que te apunta. Cada cierto tiempo trepa al techo y se lanza desde arriba. Solo se le '
               .. 'daña alumbrándolo cuando queda agotado (estrellitas). Con poca vida se enfada: mucho más rápido, oscurece y llama súbditos.',
    class = MG,
    boss = { title = 'MEGA CRABBY LÚGUBRE' },
    hide = Boss.HIDE,
    defaults = { points = 60 },
    props = Boss.props({ hp = 8, hpPerPlayer = 3 }, {
        { key='pingEvery', kind='number', label='Ecolocalización cada (s)', group=G, default=2.4, min=0.8, max=8, step=0.1,
          help='Alza las pinzas y suelta un aro: detecta ("!" rojo) a los jugadores que toca, aunque estén quietos, y salta ahí' },
        { key='ceilingEvery', kind='number', label='Al techo cada (s)', group=G, default=14, min=4, max=60, step=0.5,
          help='Trepa por la pared, va por el techo, suelta un aro grande y se lanza a donde te detecte' },
        { key='phase2', kind='number', label='Fase 2 con vida ≤', group=G, default=0.66, min=0.1, max=0.95, step=0.01,
          help='Va más rápido y apunta menos tiempo' },
        { key='rageAt', kind='number', label='Rabia con vida ≤', group=G, default=0.4, min=0.05, max=0.9, step=0.01,
          help='Ruge, le salen cristales en las pinzas, tiembla, se pone rojizo y grita' },
        { key='rageSpeed', kind='number', label='Rabia: velocidad ×', group=G, default=1.45, min=1, max=2.5, step=0.05,
          help='Todo va así de rápido: andar, embestir, apuntar, trepar (como el enfado de los Mega Crabby)' },
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
