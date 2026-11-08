-- REDCÓPTERO (Net-Copter), jefe del Valle: el primero de la campaña Flappy (docs/design/flappy-plan-5-netcopter.md,
-- docs/bosses/netcopter.md). Una máquina de chatarra — globo remendado, góndola de madera y hélice de pedal — que el
-- Monstruo Malvado pedalea entre los pilares. Solo niveles Flappy (el jugador vuela: src/player/PlayerFlight.lua).
-- El diseño (10 líneas):
--   1. Se mueve: PATRULLA (Plan 5c). Guarda un LADO (el tercio derecho o el izquierdo de la zona) `HOLD` s atacando,
--      siguiendo la altura del jugador sin prisa (retraso ~0,8 s); luego CRUZA al otro lado por la franja de arriba
--      ('cross', `CROSS_T` s, sin atacar; su cuerpo sigue haciendo daño) y se gira: `facing` mira al centro de la zona.
--      Empieza a la derecha (la entrada). Nunca sale de la zona. Fase 2: más abajo y más rápido.
--   2. RED (fase 1+): el cañón brilla 0,6 s ('aim_net', aviso + sonido) y dispara una red hacia donde mira, a la
--      altura del jugador en ese momento (traps/netshot.lua). Si da: −1 y ctrlLock 0,4 s (Boss.strike). Fase 2: abanico.
--   3. BOMBA LUMINOSA (cada ~6 s a Normal, con su propio reloj; no cruzando): la LANZA la góndola en arco hacia donde
--      está el jugador al lanzarla, con la cima ~2,5 casillas sobre su cabeza (traps/glowbomb.lua: la marca parpadea
--      allí). Un jugador que vuela SUBIENDO la toca → vuelve a la máquina: 2 de daño. Si no → explota (−1 a una casilla).
--   4. GARRA (fase 2): una línea que parpadea marca una franja de filas 0,8 s ('sweep_warn': la garra asoma de la
--      góndola y se ABRE, clawOpen), luego el brazo cruza la zona por ella hacia donde mira ('sweep', −2) y al llegar al
--      final se CIERRA de golpe (clawSnap) y vuelve cerrada. Se esquiva cambiando de altura.
--   5. Vulnerable SIEMPRE en la pelea (no hay ventanas: aquí no se pisa). Boss.INV_TIME tras cada golpe. Tocar la
--      CABINA (la góndola y el piloto de pie en ella: contactBoxes; el globo y las cuerdas no hacen daño — el usuario,
--      2026-11-08): −1 y empujón hacia donde mira (al centro; cruzando: hacia abajo y lejos de él); nunca se le pisa
--      (`interact` → nil; el contacto, con Boss.strike). La ráfaga y la bomba devuelta le dan en toda su caja; la
--      devuelta apunta a la góndola (aimPoint).
--   6. Vida: `hp` 12 con un jugador (la dificultad la escala: `bossHp`). Fase 2 con ≤ 50 %: revienta el globo.
--   7. Entrada (~3,5 s): llega pedaleando por la derecha, se ríe y despliega el cañón de redes.
--   8. Muerte: explosiones (la espera genérica, 'dying_hold'), el globo y el cañón se caen a trozos y el Monstruo
--      Malvado HUYE por la derecha ('fleeing') pedaleando una hélice rota: NO muere (vuelve en cada zona).
--   9. rollStart(r): al azar la primera red, la primera bomba, cuánto guarda el primer lado y la altura con la que empieza.
--  10. Daño a los jugadores: red 1, bomba 1, garra 2, cuerpo 1.
-- Vivo (Plan 5c): la hélice gira (4 cuadros, más deprisa cruzando), el globo se mece (±1 px de arte), las piernas
-- pedalean a su ritmo; al final del cruce se GIRA de golpe a mitad de TURN_T (drawFace: sin estrecharse); el cañón
-- cuelga de su BRAZO de hierro atornillado a la góndola y retrocede 1 px al disparar (humo y hebras en la boca:
-- `shotT`); tras un golpe, chispas, le duele HURT_T s y luego se ENFADA (puño en alto) ANGRY_T s; se RÍE como el
-- Espejo (cabeza en blanco + ojos de risa, la cabeza sube y baja cada LAUGH_F s) en la entrada y cuando cae un
-- jugador, sin parar la pelea; fase 2: humo saliendo del globo roto.
-- Estados: dormant → intro → ready → hover ↔ aim_net (la bomba sale con su reloj) → [fase 2] sweep_warn → sweep → … ↔
-- cross (cambia de lado) … → dying_hold → fleeing → dead. Todo lo que se dibuja sale de state + deadTimer + x, y +
-- facing + netPackExtra (la fase sale de hp / hpMax, que ya viajan). El arte mira a la IZQUIERDA; mirando a la derecha
-- se dibuja la máquina entera en espejo alrededor de x.
-- Arte: assets/images/bosses/netcopter/ (tools/art/bosses/make_netcopter.py), todo a ×6. Anclas en el cuadro de la
-- máquina (44x54, centro = la entidad): globo y 0..25; góndola x 12..32, y 43..52; piloto 9x16 (el cuerpo del jugador
-- con la cabeza del Monstruo Malvado) de pie sobre la góndola con su esquina en (18, 27); hélice (12x18) en (32, 37);
-- cañón a la izquierda de la góndola (esquina en (-12, 42), plegado detrás de ella en (14, 42)) con su brazo: la
-- abrazadera a 12 px de la esquina del cañón, la barra y la placa atornillada en x 9..11.

local Entity = require 'src/world/entities/base/Entity'
local Boss   = require 'src/world/entities/base/Boss'
local BossFx = require 'src/fx/BossFx'

local NC = Entity.extend(Boss, {
    ATTACKS = { aim_net = true, sweep_warn = true, sweep = true },
    debugColor = { 0.9, 0.3, 0.25 },
    hitbox = { outerW = 0.75, outerH = 0.9, innerW = 0.6, innerH = 0.75 },
})
NC.hurtSound   = 'bossHurt'
NC.wantsLevel  = true

local TP = TILE_PX
-- ── Tuning: todos los números del diseño ──────────────────────────────────────
-- (pares { fase 1, fase 2 }; tiempos en s, distancias en casillas salvo que diga px)
local T = {
    HP = 12, HP_PER_PLAYER = 4,
    PHASE2_AT = 0.5,                -- fracción de vida: el globo revienta
    LAG = { 0.8, 0.5 },             -- retraso siguiendo la altura del jugador
    LOWER2 = 0.75,                  -- fase 2: tantas casillas más abajo
    X_FRAC = 1 / 6,                 -- su x: el centro de su tercio (fracción del ancho de la zona, desde su borde)
    HOLD = { 7, 5 },                -- s que guarda un lado atacando antes de cruzar
    HOLD_FIRST = { 5, 8 },          -- rollStart: el primer lado
    CROSS_T = 1.8,                  -- s que tarda en cruzar al otro lado (por la franja de arriba)
    CROSS_RISE = 0.35,              -- fracción del cruce en que sube a la franja de arriba
    AFTER_CROSS = 0.6,              -- s como mínimo hasta la red tras cruzar
    SWAY = 0.5, SWAY_W = 0.8,       -- vaivén de lado (casillas, rad/s)
    START_OFF = 1.5,                -- rollStart: altura inicial ± esto (casillas) que se va soltando
    START_FADE = 2.0,
    NET_FIRST = { 1.2, 2.8 },       -- rollStart: la primera red
    NET_EVERY = { { 2.2, 3.2 }, { 1.5, 2.3 } },
    AIM_T = 0.6,                    -- el cañón brilla antes de disparar
    NET_SPD = 520,                  -- px/s de la red
    NET_SPREAD = 150,               -- px/s de deriva de las redes de los lados (fase 2)
    BOMB_FIRST = { 2.5, 5.0 },      -- rollStart: la primera bomba
    BOMB_EVERY = { 6.0, 5.0 }, BOMB_JITTER = 1.0,
    BOMB_G = 900,                   -- px/s² de la bomba lanzada
    BOMB_APEX = 2.5,                -- la cima del arco: tantas casillas sobre la cabeza del jugador
    SWEEP_EACH = 2,                 -- fase 2: uno de cada tantos ataques es la garra
    WARN_T = 0.8, SWEEP_OUT = 1.0, SWEEP_BACK = 0.6,
    CLAW_OUT_T = 0.2,               -- aviso: lo que tarda la garra en salir de detrás de la góndola (hasta CLAW_REST)
    CLAW_OPEN_AT = 0.3, CLAW_OPEN_T = 0.1,  -- aviso: cuándo se abre (clawOpen) y cuánto dura el cuadro a medio abrir
    SNAP_T = 0.08,                  -- barrido: el cuadro a medio cerrar antes de cerrarse de golpe al final (clawSnap)
    HIT_CLAW = { 2, 300, -220, 0.4, 0 },
    HIT_BODY = { 1, 420, -200, 0.3, 0 },
    HIT_CROSS = { 1, 160, 380, 0.3, 0 },  -- cruzando: hacia abajo, fuera de su camino (nunca contra una pared)
    INTRO = 3.5, ENTER_T = 2.0, LAUGH_AT = 2.1, LAUGH_T = 0.8, UNFOLD_AT = 2.6, UNFOLD_T = 0.5,
    PEDAL_EVERY = { 0.7, 0.4 },     -- s entre chirridos de pedal: [hover/ataque], [cruzando] (limite de ruido)
    WHIR_EVERY = { 0.55, 0.35 },    -- s entre tics de hélice: [hover/ataque], [cruzando]
    LEAK_EVERY = 1.8,               -- fase 2: s entre siseos de la fuga del globo
    LAUGH_DEATH = 1.2,              -- se ríe cuando cae un jugador
    LAUGH_F = 1 / 6,                -- s por cuadro de la risa (cabeza arriba / abajo, como el Espejo)
    TURN_T = 0.2,                   -- s que tarda en girarse al final del cruce
    HURT_T = 0.2, ANGRY_T = 0.6,    -- tras un golpe: le duele, luego se enfada (puño en alto)
    RECOIL_T = 0.12, SHOT_FX_T = 0.3,  -- el cañón retrocede / humo y hebras en la boca tras disparar
    FLEE_SPD = 240,                 -- px/s huyendo
    NET_POOL = 6, BOMB_POOL = 3,    -- súbditos de reserva
}
NC.T = T
NC.introLength = T.INTRO

-- Medidas del arte (×6)
local S = 6
local FW, FH = 44, 54
local CX, CY = 22, 27                                      -- centro del cuadro de la máquina (= x, y)
local GONDOLA_L, GONDOLA_B = (12 - CX) * S, (53 - CY) * S  -- borde izquierdo y fondo de la góndola
local FRONT = (CX - 12) * S                                -- de x al borde DELANTERO de la góndola (hacia donde mira)
local THROW_DY = (43 - CY) * S                             -- la bomba sale del borde de arriba de la góndola
local CANNON_OUT, CANNON_IN, CANNON_Y = -12, 14, 42        -- esquina del cañón (desplegado / plegado)
local CANNON_W, CANNON_H = 18, 12
local COLLAR_DX, PLATE_X, ARM_W = 12, 9, 3                 -- el brazo: abrazadera (desde el cañón), placa (fija)
local PROP_X, PROP_Y, PROP_W, PROP_H = 32, 37, 12, 18      -- la hélice
local JOY_X, JOY_Y = 2, 4                                  -- los ojos de risa, en el cuadro del piloto
local ANGRY_DX, ANGRY_W = 2, 11                            -- el piloto enfadado: 2 columnas más a la izquierda
local PUFF, SPARK = 8, 7
local MOUTH_DY = (CANNON_Y + CANNON_H / 2 - CY) * S        -- altura de la boca del cañón (y la de la red)
local CLAW_W, CLAW_H, CLAW_HEAD = 54, 14, 20               -- la garra: cabeza a la izquierda, brazo a la derecha
-- La garra PREPARADA (el aviso; y de donde sale el barrido): la cabeza asoma por delante de la boca del cañón (que está a
-- su misma altura), no detrás de él — px desde el borde delantero de la góndola hasta la punta de la garra
local CLAW_REST = (12 - CANNON_OUT + 1 + CLAW_HEAD) * S
local CLAW_DY = (47.5 - CY) * S                            -- la garra sale a la altura del centro de la góndola
local ARM_Q0, ARM_QW = 36, 9                               -- trozo del brazo que se repite para alargarlo
local PILOT_X, PILOT_Y = 18, 27
local PILOT_W, PILOT_H = 9, 16
local FLEE_W, FLEE_H = 36, 30
local PART = 14
-- Trozos que se caen al huir: { dx, dy (px desde x, y), vx, vy, giro (rad/s) } — globo, tabla, pala, cañón
local PARTS = { { 0, -112, 60, -260, 2 }, { -40, 138, -90, -120, -3 }, { 96, 108, 160, -300, 6 }, { -150, 126, -140, -180, -4 } }
local PART_G = 1400

local function rand(a, b) return a + math.random() * (b - a) end
local function clamp(v, a, b) return math.max(a, math.min(b, v)) end

local imgs = {}
local function strip(name, fw, fh)
    local im = love.graphics.newImage('assets/images/bosses/netcopter/' .. name .. '.png')
    im:setFilter('nearest', 'nearest')
    local q = {}
    for i = 1, math.floor(im:getWidth() / fw) do q[i] = love.graphics.newQuad((i - 1) * fw, 0, fw, fh, im:getDimensions()) end
    return { image = im, quads = q }
end
function NC.loadAssets()
    if imgs.machine then return end
    imgs.machine        = strip('machine-Sheet', FW, FH)
    imgs.machine_popped = strip('machine_popped-Sheet', FW, FH)
    imgs.cannon         = strip('cannon-Sheet', CANNON_W, CANNON_H)
    imgs.pilot          = strip('pilot-Sheet', PILOT_W, PILOT_H)
    imgs.pilot_flee     = strip('pilot_flee-Sheet', FLEE_W, FLEE_H)
    imgs.parts          = strip('parts', PART, PART)
    imgs.claw           = strip('claw-Sheet', CLAW_W, CLAW_H)                 -- (cerrada, a medio abrir, abierta)
    imgs.arm = love.graphics.newQuad(ARM_Q0, 0, ARM_QW, CLAW_H, imgs.claw.image:getDimensions())
    imgs.clawCut = love.graphics.newQuad(0, 0, CLAW_W, CLAW_H, imgs.claw.image:getDimensions())   -- (recortada: setViewport)
    imgs.cannon_arm     = strip('cannon_arm-Sheet', ARM_W, CANNON_H)
    imgs.armBar = love.graphics.newQuad(ARM_W, 0, 1, CANNON_H, imgs.cannon_arm.image:getDimensions())  -- (1 columna)
    imgs.prop           = strip('propeller-Sheet', PROP_W, PROP_H)
    imgs.laugh          = strip('pilot_laugh-Sheet', PILOT_W, PILOT_H)
    imgs.joy            = strip('joy_eyes', 5, 2)
    imgs.angry          = strip('pilot_angry', ANGRY_W, PILOT_H)
    imgs.puff           = strip('puff-Sheet', PUFF, PUFF)
    imgs.spark          = strip('spark-Sheet', SPARK, SPARK)
end
function NC.sizePx() return FW * S, FH * S end

function NC:initBoss()
    self.vx, self.vy, self.onGround, self.flying = 0, 0, false, true
    self.facing, self.side = -1, 1                         -- (empieza a la derecha mirando a la izquierda)
    self.holdT = T.HOLD[1]
    self.summonKey = 'nc' .. self.col .. ',' .. self.row      -- (sus redes y bombas de reserva: def.summons)
    self.netT, self.bombT, self.attackN = T.NET_FIRST[2], T.BOMB_FIRST[2], 0
    self.yOff, self.laughT, self.shotT = 0, 0, 9
    self.pedalT, self.whirT, self.leakT = 0.3, 0.1, 0.9           -- relojes de los sonidos de vida (solo sonido)
    self.bandY, self.reach = nil, 0
    self.fleeX0, self.fleeY0 = nil, nil
end

-- ── Fase, aspecto ─────────────────────────────────────────────────────────────
function NC:phase()
    local m = self.hpMax or 0
    if m > 0 and self.hp <= m * T.PHASE2_AT then return 2 end
    return 1
end
function NC:bossPhase() return self:phase() end
function NC:angryPhase() return self:phase() == 2 end
-- Lo que se dibuja como cuerpo: la máquina (con el globo entero o reventado) o el piloto huyendo en su tabla
function NC:look()
    local st = self.state
    if st == 'fleeing' or st == 'dead' then return 'pilot_flee' end
    return self:phase() == 2 and 'machine_popped' or 'machine'
end

-- ── Reglas de jefe ────────────────────────────────────────────────────────────
local FLEE = { fleeing = true }
function NC:isDying() return FLEE[self.state] == true or Boss.isDying(self) end
function NC:isActive() return Boss.isActive(self) and not FLEE[self.state] end
function NC:releasesZone() return self.state == 'fleeing' or self.state == 'dead' end
function NC:isSolidBody() return false end              -- (vuela: el contacto lo resuelve él, con daño y empujón)
function NC:isObstacle() return false end
function NC:canBeKnocked() return false end
function NC:canBeStomped() return false end
-- Nunca se le pisa: lo que toca su cuerpo lo hiere updateBoss (Boss.strike). Pura: el cliente predice igual
function NC:interact(pa) return nil end

-- La zona (o un recuadro alrededor si no tiene)
function NC:zb() return self:zoneBounds() end

-- El suelo de la zona bajo x (el primer sólido desde arriba), o el fondo de la zona
function NC:floorAt(level, x)
    local _, _, zy0, zy1 = self:zb()
    if level then
        for yy = zy0, zy1, 8 do
            if level:collisionAt(x, yy, true) then return math.floor(yy / TP) * TP end
        end
    end
    return zy1
end

-- La x de su lado (el centro del tercio derecho o del izquierdo), sin vaivén
function NC:sideX(side)
    local zx0, zx1 = self:zb()
    local w = zx1 - zx0
    return (side or self.side or 1) > 0 and (zx1 - w * T.X_FRAC) or (zx0 + w * T.X_FRAC)
end

-- Quien reaparece volando se aleja de su lado (Boss:respawnAvoidX); cruzando, del lado al que va
function NC:respawnAvoidX()
    if self.state == 'cross' and self.crossX1 then return self.crossX1 end
    return self:sideX()
end

-- La altura de la franja de arriba (por donde cruza): la más alta a la que flota
function NC:crossY(level)
    local _, _, zy0 = self:zb()
    return zy0 + self.sprH / 2 + 5 + ((self:phase() == 2) and T.LOWER2 * TP or 0)
end

-- Dónde quiere estar: x en su tercio (con vaivén), y siguiendo la altura del jugador (la boca del cañón a su altura),
-- dentro de la zona
function NC:hoverTarget(level, pa)
    local zx0, zx1, zy0 = self:zb()
    local ph = self:phase()
    local x = self:sideX() + math.sin((self.fightT or 0) * T.SWAY_W) * T.SWAY * TP
    local floor = self.floorY or self:floorAt(level, x)
    local low = (ph == 2) and T.LOWER2 * TP or 0
    local yMin, yMax = zy0 + self.sprH / 2 + 5 + low, floor - GONDOLA_B - 6
    local want = (pa and pa.y or (zy0 + floor) / 2) - MOUTH_DY + low + (self.yOff or 0)
    return x, clamp(want, yMin, math.max(yMin, yMax))
end

function NC:moveToward(dt, tx, ty, lag)
    self.x = self.x + (tx - self.x) * math.min(1, dt * 2)
    self.y = self.y + (ty - self.y) * math.min(1, dt / lag)
end

-- ── Súbditos de reserva: las redes y las bombas (def.summons) ─────────────────
function NC:fireNets(level, pa)
    local zx0, zx1, zy0 = self:zb()
    local f = self.facing
    local floor = self.floorY or self:floorAt(level, self.x)
    local mx, my = self.x + f * (CX - CANNON_OUT) * S, self.y + MOUTH_DY
    local ty = clamp(pa and pa.y or my, zy0 + TP / 2, floor - TP / 2)
    local drifts = (self:phase() == 2) and { -T.NET_SPREAD, 0, T.NET_SPREAD } or { 0 }
    for _, d in ipairs(drifts) do
        local n = self:freeMinion(level, 'netshot')
        if n then
            n:appearAt(mx, my)
            n.props.speed = T.NET_SPD
            n:launch(ty, d, f < 0 and zx0 or zx1, f)
        end
    end
    self.shotT = 0
    Sound.play('netFire')
    Entity.emitFx('sparks', mx, my)
end

-- La lanza en arco desde el borde delantero de la góndola hacia donde está el jugador AHORA (la marca), con la cima a
-- BOMB_APEX casillas sobre su cabeza (dentro de la zona; como poco, algo por encima de la salida)
function NC:throwBomb(level, pa)
    if not pa then return false end
    local b = self:freeMinion(level, 'glowbomb')
    if not b then return false end
    local _, _, zy0 = self:zb()
    local x0, y0 = self.x + self.facing * FRONT, self.y + THROW_DY
    b:appearAt(x0, y0)
    b.owner = self                                       -- (appearAt la reinicia: el dueño, después)
    local head = pa:getOuterBounds().h / 2
    local apex = math.max(zy0 + TP, pa.y - head - T.BOMB_APEX * TP)
    b:lob(pa.x, pa.y, math.min(apex, y0 - TP / 2), T.BOMB_G)
    Sound.play('bombLob')
    return true
end

-- Cambia de lado: por la franja de arriba hasta el centro del otro tercio (mirando hacia allí, que es el centro)
function NC:startCross()
    self.crossX0, self.crossY0 = self.x, self.y
    self.side = -(self.side or 1)
    self.crossX1 = self:sideX()
    self:enter('cross')
end

-- ── Pelea ─────────────────────────────────────────────────────────────────────
function NC:onFightStart(n)
    self:enter('hover')
    self.netT, self.bombT, self.attackN = T.NET_FIRST[2], T.BOMB_FIRST[2], 0
    -- (el lado, de dónde está AHORA: tras la entrada, el derecho; si la pelea vuelve a empezar con él a la izquierda,
    -- el izquierdo, mirando al centro)
    local zx0, zx1 = self:zb()
    self.side = (self.x < (zx0 + zx1) / 2) and -1 or 1
    self.facing, self.holdT = -self.side, T.HOLD[1]
    if self.levelRef then self.floorY = self:floorAt(self.levelRef, self.x) end
end
function NC:rollStart(r)
    self.netT = r(T.NET_FIRST[1], T.NET_FIRST[2])
    self.bombT = r(T.BOMB_FIRST[1], T.BOMB_FIRST[2])
    self.holdT = r(T.HOLD_FIRST[1], T.HOLD_FIRST[2])
    self.yOff = r(-T.START_OFF, T.START_OFF) * TP
    self.attackN = math.random(0, 1)
end

function NC:onDamaged(n, kind)
    if self:phase() == 2 and not self.popped then
        self.popped = true                                -- (el globo revienta: fase 2)
        Sound.play('balloonPop')
        Sound.play('bossExplode', 0.6)
        Entity.emitFx('boss_blast', self.x, self.y - 60)
        Entity.emitFx('shake_small', self.x, self.y)
    else
        Entity.emitFx('shake_tick', self.x, self.y)              -- (cada golpe: un temblor de 0,15 s)
    end
end

-- Cae un jugador: se ríe (como el Espejo) sin dejar de pelear; en la entrada o cayendo, no
function NC:onPlayerDeath(pa)
    if self:isDying() or Boss.INTRO[self.state] or self.state == 'dormant' then return end
    self.laughT = T.LAUGH_DEATH
    Sound.play('mirrorLaugh')
end

-- Lo que pega: la garra en su franja (sweep) y su cuerpo. La garra sale del borde delantero de la góndola hacia donde
-- mira: `left` = la caja como si mirara a la izquierda (para dibujar en espejo)
function NC:clawBox(left)
    if self.state ~= 'sweep' or not self.bandY then return nil end
    local t, k = self.deadTimer, 0
    if t < T.SWEEP_OUT then k = t / T.SWEEP_OUT
    else k = math.max(0, 1 - (t - T.SWEEP_OUT) / T.SWEEP_BACK) end
    local w = CLAW_REST + (self.reach or 0) * k
    local x = self.x - FRONT - w
    if not left and (self.facing or -1) > 0 then x = self.x + FRONT end
    return { x = x, y = self.bandY - CLAW_H * S / 2, w = w, h = CLAW_H * S }
end

-- Cuadro de la garra (1 cerrada, 2 a medio abrir, 3 abierta), de state + deadTimer: en el aviso asoma cerrada y se
-- abre; barriendo va abierta y se cierra de golpe al llegar al final (SWEEP_OUT); vuelve cerrada
function NC:clawFrame()
    local t = self.deadTimer or 0
    if self.state == 'sweep_warn' then
        if t < T.CLAW_OPEN_AT then return 1 end
        return (t < T.CLAW_OPEN_AT + T.CLAW_OPEN_T) and 2 or 3
    elseif self.state == 'sweep' then
        if t < T.SWEEP_OUT - T.SNAP_T then return 3 end
        return (t < T.SWEEP_OUT) and 2 or 1
    end
    return 1
end
-- Dónde se DIBUJA la garra (como si mirara a la izquierda): barriendo, su caja; en el aviso sale de detrás de la
-- góndola, a la altura de su centro, hasta quedar preparada (CLAW_REST: la cabeza por delante del cañón)
function NC:clawDrawBox()
    if self.state == 'sweep' then return self:clawBox(true) end
    if self.state ~= 'sweep_warn' then return nil end
    local w = math.floor(CLAW_REST * math.min(1, (self.deadTimer or 0) / T.CLAW_OUT_T))
    return { x = self.x - FRONT - w, y = self.y + CLAW_DY - CLAW_H * S / 2, w = w, h = CLAW_H * S }
end

local overlap = Boss.overlap

-- Lo que hace daño al tocarlo: la CABINA — la góndola y el piloto de pie en ella — (en px de arte del cuadro de la
-- máquina: x, y, ancho, alto, mirando a la izquierda); el globo, las cuerdas, la hélice y el cañón, no. Mirando a la
-- derecha (drawFace: lo que se VE), en espejo alrededor de x
local CABIN = { { 12, 43, 20, 10 }, { 18, 27, 9, 16 } }
function NC:contactBoxes()
    local out, f = self._cabin or {}, self:drawFace()
    self._cabin = out
    for i, c in ipairs(CABIN) do
        local b = out[i] or {}
        out[i] = b
        local dx, w = (c[1] - CX) * S, c[3] * S
        if f > 0 then dx = -dx - w end
        b.x, b.y, b.w, b.h = self.x + dx, self.y + (c[2] - CY) * S, w, c[4] * S
    end
    return out
end
-- Adónde apunta lo que se le devuelve (la bomba): el centro de la góndola
local AIM_DY = ((43 + 53) / 2 - CY) * S
function NC:aimPoint() return self.x, self.y + AIM_DY end

local function touches(ob, boxes)
    for _, b in ipairs(boxes) do if overlap(ob, b) then return true end end
    return false
end

function NC:hurtPlayers(level)
    local claw, cabin = self:clawBox(), self:contactBoxes()
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false and not pa:isInvulnerable() then
            local ob = pa:getOuterBounds()
            local f = self.facing or -1
            if claw and overlap(ob, claw) then Boss.strike(pa, T.HIT_CLAW, f)
            elseif touches(ob, cabin) then
                if self.state == 'cross' then Boss.strike(pa, T.HIT_CROSS, pa.x < self.x and -1 or 1)
                else Boss.strike(pa, T.HIT_BODY, f) end
            end
        end
    end
end

-- Los ruidos de la máquina viva: pedal, hélice y (fase 2) la fuga del globo. Cada uno con su reloj, para no sonar
-- cada cuadro (más seguidos cruzando)
function NC:lifeSounds(dt, k)
    self.pedalT, self.whirT, self.leakT = self.pedalT - dt, self.whirT - dt, self.leakT - dt
    if self.pedalT <= 0 then self.pedalT = T.PEDAL_EVERY[k]; Sound.play('pedalSqueak') end
    if self.whirT <= 0 then self.whirT = T.WHIR_EVERY[k]; Sound.play('propWhir') end
    if self.leakT <= 0 then
        self.leakT = T.LEAK_EVERY
        if self.popped then Sound.play('leakHiss') end
    end
end

function NC:updateBoss(dt, level)
    self.levelRef = self.levelRef or level
    local st = self.state
    if st == 'dormant' then return end
    self.deadTimer = self.deadTimer + dt
    local t = self.deadTimer
    if self.laughT > 0 then self.laughT = math.max(0, self.laughT - dt) end
    self.shotT = math.min(9, (self.shotT or 9) + dt)
    if st == 'fleeing' then return self:updateFlee(dt, level, t) end
    if not self:isActive() then return end
    self:lifeSounds(dt, st == 'cross' and 2 or 1)

    local ph = self:phase()
    local pa = self:nearestPlayer(level)
    if self.yOff ~= 0 then                                   -- (la altura del azar se va soltando)
        local d = TP * T.START_OFF * dt / T.START_FADE
        self.yOff = (math.abs(self.yOff) <= d) and 0 or (self.yOff - d * (self.yOff > 0 and 1 or -1))
    end
    -- La bomba, con su propio reloj (también mientras ataca; cruzando, nunca), y lo que le queda en este lado
    if st ~= 'cross' then
        self.bombT = self.bombT - dt
        if self.bombT <= 0 then
            self:throwBomb(level, pa)
            self.bombT = T.BOMB_EVERY[ph] + rand(-T.BOMB_JITTER, T.BOMB_JITTER)
        end
        self.holdT = (self.holdT or 0) - dt
    end

    if st == 'hover' or st == 'aim_net' then
        local tx, ty = self:hoverTarget(level, pa)
        self:moveToward(dt, tx, ty, T.LAG[ph])
    end
    if st == 'hover' and self.holdT <= 0 then
        self:startCross()
    elseif st == 'hover' then
        self.netT = self.netT - dt
        if self.netT <= 0 and self:mayAttack(level) then
            self.attackN = self.attackN + 1
            if ph == 2 and self.attackN % T.SWEEP_EACH == 0 then
                self:enter('sweep_warn')
            else
                self:enter('aim_net')
                Sound.play('cannonFuse')
            end
        end
    elseif st == 'aim_net' then
        if t >= T.AIM_T then
            self:fireNets(level, pa)
            self.netT = rand(T.NET_EVERY[ph][1], T.NET_EVERY[ph][2])
            self:enter('hover')
        end
    elseif st == 'sweep_warn' then
        if not self.bandY then
            -- la franja: a la altura del jugador AHORA; la garra llegará hasta el borde de la zona hacia donde mira
            local zx0, zx1, zy0 = self:zb()
            local floor = self.floorY or self:floorAt(level, self.x)
            self.bandY = math.floor(clamp(pa and pa.y or self.y, zy0 + 1.5 * TP, floor - 0.75 * TP) + 0.5)
            local reach = (self.facing or -1) < 0 and ((self.x - FRONT - CLAW_REST) - (zx0 + TP / 4))
                or ((zx1 - TP / 4) - (self.x + FRONT + CLAW_REST))
            self.reach = math.max(0, math.floor(reach))
            self.clawStep = 0
            Sound.play('clawServo')
        end
        if t >= T.CLAW_OPEN_AT and (self.clawStep or 0) < 1 then self.clawStep = 1; Sound.play('clawOpen') end
        self.y = self.y + ((self.bandY - CLAW_DY) - self.y) * math.min(1, dt * 6)
        if t >= T.WARN_T then
            self.y = self.bandY - CLAW_DY
            self:enter('sweep')
            Sound.play('gustBlow')
        end
    elseif st == 'sweep' then
        if t >= T.SWEEP_OUT and (self.clawStep or 0) < 2 then           -- (al final del barrido se cierra de golpe)
            self.clawStep = 2
            Sound.play('clawSnap')
            local cb = self:clawBox()
            if cb then Entity.emitFx('sparks', (self.facing or -1) < 0 and cb.x or (cb.x + cb.w), self.bandY) end
        end
        if t >= T.SWEEP_OUT + T.SWEEP_BACK then
            self.bandY, self.reach = nil, 0
            self.netT = rand(T.NET_EVERY[ph][1], T.NET_EVERY[ph][2])
            self:enter('hover')
        end
    elseif st == 'cross' then
        -- sube a la franja de arriba al principio y cruza (suave al salir y al llegar); al llegar, se gira al centro
        local k = math.min(1, t / T.CROSS_T)
        local ky = math.min(1, t / (T.CROSS_T * T.CROSS_RISE))
        self.x = self.crossX0 + (self.crossX1 - self.crossX0) * k * k * (3 - 2 * k)
        self.y = self.crossY0 + (self:crossY(level) - self.crossY0) * (1 - (1 - ky) * (1 - ky))
        if t >= T.CROSS_T then
            self.facing = -self.side
            self.holdT = T.HOLD[ph]
            self.netT = math.max(self.netT, T.AFTER_CROSS)
            self.floorY = self:floorAt(level, self.x)
            self:enter('hover')
        end
    end
    self:hurtPlayers(level)
end

-- ── Entrada: llega pedaleando por la derecha, se ríe, despliega el cañón ──────
function NC:introFocus()
    local zx0, zx1, zy0, zy1 = self:zb()
    return (zx0 + zx1) / 2, (zy0 + zy1) / 2
end
function NC:onIntroStart(level, players)
    self.levelRef = self.levelRef or level
    self.introStep = 0
    self.side, self.facing = 1, -1
    local _, zx1 = self:zb()
    self.floorY = self:floorAt(level, zx1 - TP)
    local hx, hy = self:hoverTarget(level, nil)
    self.introTo = { hx, hy }
    self.x, self.y = zx1 + self.sprW / 2 + 2 * TP, hy
    self.introX0 = self.x
end
function NC:updateIntro(dt, level, t)
    local to = self.introTo or { self.x, self.y }
    local k = math.min(1, t / T.ENTER_T)
    self.x = (self.introX0 or to[1]) + (to[1] - (self.introX0 or to[1])) * (1 - (1 - k) ^ 3)
    self.y = to[2]
    if self.introStep < 1 then self.introStep = 1; Sound.play('miniAppear') end
    if t >= T.LAUGH_AT and self.introStep < 2 then self.introStep = 2; Sound.play('mirrorLaugh') end
    if t >= T.UNFOLD_AT and self.introStep < 3 then self.introStep = 3; Sound.play('cannonLoad') end
end
-- Cuánto está desplegado el cañón (0..1): en la entrada, se despliega; luego, siempre
function NC:cannonK()
    local st = self.state
    if st == 'intro' then return clamp((self.deadTimer - T.UNFOLD_AT) / T.UNFOLD_T, 0, 1) end
    return 1
end
-- Cuánto lleva riéndose (nil = no se ríe): en la entrada, desde LAUGH_AT; si cae un jugador, desde que cayó
function NC:laughTime()
    if self.state == 'intro' then
        local lt = self.deadTimer - T.LAUGH_AT
        if lt >= 0 and lt < T.LAUGH_T then return lt end
        return nil
    end
    if (self.laughT or 0) > 0 then return math.max(0, T.LAUGH_DEATH - self.laughT) end
    return nil
end
function NC:laughing() return self:laughTime() ~= nil end
-- 1 = cabeza arriba (brazos arriba), 2 = cabeza abajo (brazos abajo)
function NC:laughFrame()
    return math.floor((self:laughTime() or 0) / T.LAUGH_F) % 2 + 1
end
-- Lo que lleva desde el último golpe (nil = ninguno reciente): sale de `inv`, que ya viaja
function NC:hitAge()
    if self.inv > 0 and not self.ghost then return Boss.INV_TIME - self.inv end
    return nil
end
-- Cómo está el Monstruo Malvado: 'hurt' (explotando o recién golpeado), 'angry', 'laugh' o 'pedal'
function NC:pilotPose()
    if self.state == 'dying_hold' then return 'hurt' end
    local a = self:hitAge()
    if a and a < T.HURT_T then return 'hurt' end
    if a and a < T.HURT_T + T.ANGRY_T then return 'angry' end
    if self:laughing() then return 'laugh' end
    return 'pedal'
end

-- ── Derrota: explosiones (genéricas), se rompe y huye por la derecha ──────────
function NC:onDefeat()
    self.bandY, self.reach = nil, 0
    local level = self.levelRef
    if level then
        for _, e in ipairs(self:minions(level)) do
            if e.alive and e.def.name == 'netshot' then e:spend()
            elseif e.alive and e.def.name == 'glowbomb' and e.state == 'falling' then e:spend() end   -- (sin daño: se gasta)
        end
    end
end
-- (al acabar la espera genérica, en vez de caer: huye)
function NC:onDeathFall()
    self.fleeX0, self.fleeY0 = math.floor(self.x), math.floor(self.y)
    self:enter('fleeing')
    Sound.play('bossExplode')
    Sound.play('megaFlee')
    Entity.emitFx('boss_big_blast', self.x, self.y)
end
function NC:updateFlee(dt, level, t)
    self.x = self.x + T.FLEE_SPD * dt
    self.y = (self.fleeY0 or self.y) - math.min(1, t) * 20 + math.floor(math.sin(t * 9) * 6)
    local _, zx1 = self:zb()
    if self.x - self.sprW / 2 > zx1 and self:fleeOver(level, dt, t) then
        self.state, self.alive = 'dead', false
    end
end

-- ── Red ───────────────────────────────────────────────────────────────────────
function NC:netPackExtra()
    return { math.floor((self.laughT or 0) * 100 + 0.5), self.bandY or 0, math.floor(self.reach or 0),
             self.fleeX0 or 0, self.fleeY0 or 0, (self.facing or -1) > 0 and 1 or -1,
             math.floor(math.min(9, self.shotT or 9) * 100 + 0.5) }
end
function NC:netApplyExtra(a, b, f)
    if type(b[1]) ~= 'number' then return end
    self.laughT = b[1] / 100
    if type(b[7]) == 'number' then self.shotT = b[7] / 100 end
    self.bandY = (b[2] ~= 0) and b[2] or nil
    self.reach = b[3] or 0
    self.fleeX0, self.fleeY0 = b[4], b[5]
    if b[6] == 1 or b[6] == -1 then self.facing = b[6] end
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
-- (la garra y el aviso se dibujan como si mirara a la izquierda: render los pone en espejo si mira a la derecha)
function NC:drawClaw(camX, camY)
    local box = self:clawDrawBox()
    if not box then return end
    local im = imgs.claw.image
    local x, y = math.floor(box.x - camX), math.floor(box.y - camY)
    -- (recortada al borde de atrás de la góndola: el brazo nunca asoma por detrás de la máquina)
    local back = math.floor(self.x + FRONT - camX)
    local cw = math.max(1, math.min(CLAW_W, math.floor((back - x) / S)))
    imgs.clawCut:setViewport((self:clawFrame() - 1) * CLAW_W, 0, cw, CLAW_H)
    love.graphics.draw(im, imgs.clawCut, x, y, 0, S, S)
    -- (más largo que el dibujo: se repite un trozo del brazo hasta la góndola)
    local gl = math.floor(self.x + GONDOLA_L - camX)
    local ax = x + CLAW_W * S
    while ax < gl do
        love.graphics.draw(im, imgs.arm, ax, y, 0, S, S)
        ax = ax + ARM_QW * S
    end
end

function NC:drawWarn(camX, camY)
    if self.state ~= 'sweep_warn' or not self.bandY then return end
    if math.floor(self.deadTimer * 8) % 2 == 1 then return end           -- (parpadea)
    local gl = self.x + GONDOLA_L
    local x0 = gl - CLAW_REST - (self.reach or 0)
    local h = CLAW_H * S / 2
    for x = x0 + 48, gl, 96 do
        BossFx.target(self.deadTimer * 4, math.floor(x - camX), math.floor(self.bandY - h - camY), S, S)
        BossFx.target(self.deadTimer * 4, math.floor(x - camX), math.floor(self.bandY + h - camY), S, S)
    end
end

function NC:drawParts(camX, camY)
    local t = self.deadTimer
    if not self.fleeX0 or t > 2.5 then return end
    for i, p in ipairs(PARTS) do
        local x = self.fleeX0 + p[1] + p[3] * t
        local y = self.fleeY0 + p[2] + p[4] * t + PART_G * t * t / 2
        love.graphics.draw(imgs.parts.image, imgs.parts.quads[i], math.floor(x - camX), math.floor(y - camY),
            math.floor(p[5] * t * 2) * math.pi / 2, S, S, PART / 2, PART / 2)        -- (gira a cuartos de vuelta)
    end
end

-- El cañón con su brazo (detrás de la góndola: plegado queda tapado). `cx` = esquina del cañón en px de arte
function NC:drawCannon(ox, oy, cx, glow)
    local c = imgs.cannon_arm
    love.graphics.draw(imgs.cannon.image, imgs.cannon.quads[glow and 2 or 1], ox + cx * S, oy + CANNON_Y * S, 0, S, S)
    local col = cx + COLLAR_DX                                          -- abrazadera, y la barra hasta la placa
    for ax = col + ARM_W, PLATE_X - 1 do
        love.graphics.draw(c.image, imgs.armBar, ox + ax * S, oy + CANNON_Y * S, 0, S, S)
    end
    love.graphics.draw(c.image, c.quads[1], ox + col * S, oy + CANNON_Y * S, 0, S, S)
    love.graphics.draw(c.image, c.quads[3], ox + PLATE_X * S, oy + CANNON_Y * S, 0, S, S)
end

-- Humo y hebras en la boca del cañón tras disparar (de shotT); chispas en la máquina tras un golpe (de inv)
function NC:drawShotFx(ox, oy, cx)
    local t = self.shotT or 9
    if t >= T.SHOT_FX_T then return end
    local k = math.min(2, math.floor(t / T.SHOT_FX_T * 3))
    local mx, my = ox + (cx - 1) * S, oy + (CANNON_Y + CANNON_H / 2) * S
    local rise = math.floor(t * 20) * S
    love.graphics.draw(imgs.puff.image, imgs.puff.quads[1 + k], mx, my - rise, 0, S, S, PUFF / 2, PUFF / 2)
    love.graphics.draw(imgs.puff.image, imgs.puff.quads[4 + k], mx - (4 + k * 2) * S, my + S, 0, S, S, PUFF / 2, PUFF / 2)
end
local SPARK_AT = { { 14, 41 }, { 31, 18 }, { 9, 10 } }
function NC:drawHitFx(ox, oy)
    local a = self:hitAge()
    if not a or a >= 0.24 then return end
    local k = math.floor(a / 0.08) + 1
    for i, p in ipairs(SPARK_AT) do
        local q = imgs.spark.quads[math.min(3, k + (i - 1) % 2)]
        love.graphics.draw(imgs.spark.image, q, ox + p[1] * S, oy + p[2] * S, 0, S, S, SPARK / 2, SPARK / 2)
    end
end
-- Fase 2: humo que sale del globo roto y se queda atrás (subiendo, hacia detrás de la máquina)
function NC:drawLeak(ox, oy, now)
    for i = 0, 2 do
        local u = (now * 0.8 + i / 3) % 1
        local q = imgs.puff.quads[1 + math.min(2, math.floor(u * 3))]
        local wob = math.floor(math.sin(u * 7 + i * 2.1) * 2.5 + 0.5)          -- (no sale en fila: se ondula)
        love.graphics.draw(imgs.puff.image, q, ox + math.floor(27 + u * 15 + wob) * S, oy + math.floor(13 - u * 15 - wob) * S,
            0, S, S, PUFF / 2, PUFF / 2)
    end
end

-- Hacia dónde se DIBUJA mirando (−1 izquierda, 1 derecha): `facing`, salvo al final del cruce, que se gira de golpe a
-- mitad de TURN_T (sin estrecharse: un píxel de arte es siempre del mismo tamaño). Cruzando mira hacia donde va, así que
-- girado mira al revés. Sale de state + deadTimer + facing, que viajan: el cliente lo dibuja igual
function NC:drawFace()
    local face = self.facing or -1
    if self.state == 'cross' and T.CROSS_T - (self.deadTimer or 0) < T.TURN_T / 2 then face = -face end
    return face
end

-- El Monstruo Malvado de pie en la góndola: pedalea, se ríe (cabeza en blanco + ojos de risa), le duele o se enfada
function NC:drawPilot(ox, oy, now, fast)
    local pose = self:pilotPose()
    local px, py = ox + PILOT_X * S, oy + PILOT_Y * S
    if pose == 'laugh' then
        local f = self:laughFrame()
        love.graphics.draw(imgs.laugh.image, imgs.laugh.quads[f], px, py, 0, S, S)
        love.graphics.draw(imgs.joy.image, imgs.joy.quads[1], px + JOY_X * S, py + (JOY_Y + (f == 2 and 1 or 0)) * S, 0, S, S)
    elseif pose == 'angry' then
        love.graphics.draw(imgs.angry.image, imgs.angry.quads[1], px - ANGRY_DX * S, py, 0, S, S)
    else
        local fr = (pose == 'hurt') and 4 or (math.floor(now * (fast and 12 or 6)) % 2 + 1)
        love.graphics.draw(imgs.pilot.image, imgs.pilot.quads[fr], px, py, 0, S, S)
    end
end

function NC:render(camX, camY)
    local st = self.state
    if st == 'dormant' and not EDITOR_VIEW then return end
    local x, y = math.floor(self.x - camX), math.floor(self.y - camY)
    local now = love.timer.getTime()
    local ox, oy = x - CX * S, y - CY * S                               -- esquina del cuadro de la máquina
    if st == 'fleeing' or st == 'dead' then
        love.graphics.setColor(1, 1, 1, 1)
        self:drawParts(camX, camY)
        local f = math.floor(now * 8) % 2 + 1
        love.graphics.draw(imgs.pilot_flee.image, imgs.pilot_flee.quads[f], x - FLEE_W / 2 * S,
            y + GONDOLA_B - FLEE_H * S, 0, S, S)
        return
    end
    if st == 'dying_hold' then
        x = x + math.floor((math.random() * 2 - 1) * 3)
        y = y + math.floor((math.random() * 2 - 1) * 3)
        ox, oy = x - CX * S, y - CY * S
    end
    -- mirando a la derecha: toda la máquina (garra, aviso, cañón, piloto) en espejo alrededor de x (drawFace)
    local xf = self:drawFace() > 0
    if xf then
        love.graphics.push()
        love.graphics.translate(x, 0)
        love.graphics.scale(-1, 1)
        love.graphics.translate(-x, 0)
    end
    self:drawWarn(camX, camY)
    local red = self:flashRed()
    local function tint()
        if red then love.graphics.setColor(1, 0.3, 0.3, 1) else love.graphics.setColor(1, 1, 1, self:ghostAlpha()) end
    end
    tint()
    -- la garra y el cañón con su brazo, DETRÁS de la góndola (plegados quedan tapados); retrocede 1 px al disparar
    self:drawClaw(camX, camY)
    local k = self:cannonK()
    local cx = math.floor(CANNON_IN + (CANNON_OUT - CANNON_IN) * k + 0.5) + (((self.shotT or 9) < T.RECOIL_T) and 1 or 0)
    local glow = st == 'aim_net' and math.floor(self.deadTimer * 10) % 2 == 0
    self:drawCannon(ox, oy, cx, glow)
    -- la máquina: el globo se mece (±1 px) o, reventado, aletea; la hélice gira (más deprisa cruzando)
    local fast = st == 'cross'
    local look = self:look()
    local m = imgs[look]
    local mf
    if look == 'machine' then
        local v = math.sin((self.deadTimer or 0) * 1.7)                -- (el vaivén sale del reloj del estado)
        mf = (v > 0.6) and 2 or ((v < -0.6) and 3 or 1)
    else
        mf = math.floor(now * 6) % 2 + 1
    end
    love.graphics.draw(m.image, m.quads[mf], ox, oy, 0, S, S)
    local pf = (st == 'dying_hold') and 1 or (math.floor(now * (fast and 24 or 12)) % 4 + 1)
    love.graphics.draw(imgs.prop.image, imgs.prop.quads[pf], ox + PROP_X * S, oy + PROP_Y * S, 0, S, S)
    love.graphics.setColor(1, 1, 1, self:ghostAlpha())
    self:drawPilot(ox, oy, now, fast)
    love.graphics.setColor(1, 1, 1, 1)
    self:drawShotFx(ox, oy, cx)
    if look == 'machine_popped' then self:drawLeak(ox, oy, now) end
    self:drawHitFx(ox, oy)
    if xf then love.graphics.pop() end
end

-- Lo que hiere y no son sus cajas: la cabina (lo único de su cuerpo que hace daño), la garra (y la franja avisada)
function NC:debugBoxes()
    local out = {}
    if self:isActive() then
        for _, b in ipairs(self:contactBoxes()) do out[#out + 1] = { x = b.x, y = b.y, w = b.w, h = b.h, kind = 'hurt' } end
    end
    local c = self:clawBox()
    if c then out[#out + 1] = { x = c.x, y = c.y, w = c.w, h = c.h, kind = 'hazard' } end
    if self.state == 'sweep_warn' and self.bandY then
        local w = CLAW_REST + (self.reach or 0)
        local x0 = ((self.facing or -1) > 0) and (self.x + FRONT) or (self.x - FRONT - w)
        out[#out + 1] = { x = x0, y = self.bandY - CLAW_H * S / 2, w = w, h = CLAW_H * S, kind = 'area' }
    end
    return out
end

return {
    name = 'netcopter', label = 'Redcóptero', category = 'Flappy', flappyOnly = true, pace = 'bossPace',
    description = 'Jefe del Valle (solo niveles Flappy): el Monstruo Malvado en su máquina de chatarra. Dispara redes, '
               .. 'lanza bombas luminosas en arco (devuélveselas subiendo), cruza la arena de lado a lado y, sin globo, '
               .. 'barre la zona con su garra.',
    class = NC,
    boss = { title = 'REDCÓPTERO' },
    hide = Boss.HIDE,
    defaults = { points = 50 },
    props = Boss.props({ hp = T.HP, hpPerPlayer = T.HP_PER_PLAYER }, {}),
    -- Sus redes y sus bombas: súbditos de RESERVA (Entity:makeReserve), los mismos índices en todas partes
    summons = function(pl)
        local key, out = 'nc' .. pl.col .. ',' .. pl.row, {}
        for _ = 1, T.NET_POOL do out[#out + 1] = { type = 'netshot', col = pl.col, row = pl.row, summonKey = key } end
        for _ = 1, T.BOMB_POOL do out[#out + 1] = { type = 'glowbomb', col = pl.col, row = pl.row, summonKey = key } end
        return out
    end,
    editor = { sprite = 'assets/images/bosses/netcopter/machine-Sheet.png', frameW = FW },
}
