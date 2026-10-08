-- MirrorEnemy (jefe espejo): port de MirrorEnemy.cs del juego original.
--
-- Es el monstruito con los colores invertidos. Graba lo que PULSA el jugador
-- (izquierda/derecha, salto, agacharse) y lo repite `delay` segundos después
-- con un cuerpo de jugador de verdad (PlayerAdventure): mismas animaciones,
-- doble salto, ground pound... y los mismos sonidos, más graves. Como en el
-- original es un 20% más rápido y salta más alto que el jugador.
--
-- Como en Unity:
--  * cada 1-3 s invierte los controles (se mueve en espejo) para confundir;
--  * si el jugador se le pone justo encima, salta apartándose (evasión);
--  * si el jugador lleva un rato sin moverse, da unos pasos al azar;
--  * su cuerpo es sólido: de lado jugador y jefe se chocan y se paran;
--  * cuando muere un jugador se RÍE (Laugh.anim: cabeza y cuerpo separados,
--    ojos de alegría, 5 carcajadas en 1,68 s) y vuelve a empezar a grabar;
--  * los pinchos le hacen daño (en Unity lo mataban: aquí es un jefe con vida).
-- Además (nuevo): si cae sobre la cabeza de un jugador le quita 1 de vida y
-- rebota un poco; su ground pound empuja/aturde a los jugadores cercanos y
-- daña al que pilla debajo; el ground pound de un jugador lo deja KO.
--
-- ATAQUES DE ARENA (rework): cada `attackEvery` s de copia usa la arena:
--  * PICADO DESDE EL ESPEJO ('warp_out' → 'portal' → 'dive'): se rompe en
--    cristales, reaparece en un espejo flotando sobre el objetivo (lo sigue y
--    se fija el último instante; una marca en el suelo avisa) y cae en ground
--    pound. Las plataformas lo paran: debajo de una se está a salvo.
--  * SALTO DESDE UNA PLATAFORMA ('warp_out' → 'perch' → 'leap' → 'dive'):
--    reaparece de pie en una plataforma de la arena, se agacha, salta hacia el
--    jugador y en lo alto del salto hace el ground pound sobre él.
--  Su ground pound quita 2 de vida al que pilla debajo (como el del jugador a
--  él). Tras caer hace una pausa corta 'recover' (NO se aturde con sus propios
--  ataques: solo el ground pound de un jugador lo aturde) y sigue.
--  Fases por vida: más a menudo, encadena 1 / 2 / 3 ataques y copia más rápido.
--  CRISTAL ROTO (entidad bossglass de su zona, evento): mientras avisa o está
--  activo deja de copiar y pelea desde las plataformas (salta de plataforma en
--  plataforma cayendo en ground pound sobre la del objetivo). Si toca los
--  cristales recibe 1 y vuelve de un salto a la plataforma alcanzable más
--  cercana. Al acabar el evento vuelve a lo de siempre.
--
-- Con varios jugadores copia a uno solo: al más cercano, pero sin cambiar a
-- lo loco (tiempo mínimo por objetivo, histéresis de distancia y solo cuando
-- está en el suelo). Graba a TODOS a la vez, así al cambiar de objetivo sigue
-- el retardo del nuevo sin saltos.

local Entity          = require 'src/world/entities/base/Entity'
local Boss            = require 'src/world/entities/base/Boss'
local PlayerAdventure = require 'src/player/PlayerAdventure'
local Interactions    = require 'src/world/entities/base/Interactions'
local DeadEyes        = require 'src/player/DeadEyes'
local BossZones       = require 'src/world/systems/BossZones'

local Mirror = Entity.extend(Boss, {
    -- (aliados en Xtra extremo: qué estados son atacar)
    -- (posarse en una plataforma es SITUARSE, no atacar — con el cristal roto los dos se suben —: el ataque
    -- es el salto; si no le toca, espera posado)
    ATTACKS = { portal = true, leap = true, dive = true },
    debugColor = { 0.75, 0.35, 1 },
    hitbox = { outerW = 0.72, outerH = 1.0, innerW = 0.43, innerH = 0.5 },
})

-- ── Ajustes ──────────────────────────────────────────────────────────────────
-- Las físicas de Unity y las de aquí son distintas: no se copian sus números.
-- Solo se conserva la idea: un poco más rápido y un poco más saltarín que el
-- jugador. Los tiempos (retardo 1,5 s, invertir cada 1-3 s) sí son los del
-- inspector del original (Level1.unity, objeto "COPIER").
local SPEED_MULT     = 1.12          -- un poco más rápido que el jugador
local JUMP_MULT      = 1.08          -- salta un poco más (~17% más alto)
local PITCH          = 0.84          -- el resto de sus sonidos, algo más graves
local JUMP_PITCH     = { 0.6, 0.8 }  -- minPitch/maxPitch del COPIER (jugador: 0,8-1,2)
local STEP_PITCH     = { 0.8, 1.0 }  -- (en Unity 1,5-2: se pidieron más graves)
local IDLE_TO_RANDOM = 2.0           -- idleTimeToRandomMove
local RANDOM_MOVE    = { 1.0, 1.0 }  -- randomMoveDurationRange
local EVADE_ABOVE    = 200           -- jugador justo encima (≈2 alturas)
local EVADE_DX       = 70
local EVADE_JUMP     = ADV_JUMP_VEL * 1.15    -- salto de evasión, algo más alto que el normal
local EVADE_PUSH     = 300           -- se aparta hacia un lado
local EVADE_CD       = 1.4           -- (nuevo) para que se le pueda pisar
local EVADE_CHANCE   = 0.65
local HEAD_BOUNCE    = ADV_JUMP_VEL * 0.5    -- rebote al caer en la cabeza de alguien
local HEAD_PUSH      = 220
local LAUGH_FRAME    = 1 / 6         -- Laugh.anim: un cuadro cada 10/60 s
local LAUGH_DUR      = 1.6833        -- m_StopTime
local KO_POUND       = 1.4           -- s KO tras un ground pound encima
local KO_KNOCK       = 0.9           -- s aturdido por un ground pound cercano
local KNOCK_VX, KNOCK_VY = 520, -360
local LOCK_MIN       = 2.5           -- s mínimos copiando al mismo jugador
local SWITCH_RATIO   = 0.7           -- el nuevo tiene que estar bastante más cerca...
local SWITCH_MARGIN  = 64            -- ...y al menos esto
local SWITCH_PAUSE   = 0.3           -- s de duda al cambiar de objetivo
local FALL_FPS       = 6             -- animación de caída del jugador (brazos arriba/abajo)
-- Ataques de arena
local WARP_OUT_T     = 0.3           -- s rompiéndose antes de desaparecer
local PORTAL_IN_T    = 0.25          -- s apareciendo en el espejo
local PORTAL_LOCK    = 0.35          -- s fijo (sin seguir) antes de caer
local PORTAL_FOLLOW  = 420           -- px/s siguiendo al objetivo desde el espejo
local PORTAL_UP      = 4.5           -- casillas por encima del objetivo (mín.: techo de la zona)
local PERCH_T        = 0.75          -- s en la plataforma antes de saltar
local LEAP_VY        = -760          -- salto desde la plataforma (px/s)
local RECOVER_T      = 0.3           -- s de pausa al aterrizar (NO aturdido: sus ataques no le aturden)
local GP_DAMAGE      = 2             -- su ground pound encima de alguien
-- Fases (fracción de vida → cada cuánto ataca, ataques seguidos, retardo x)
local PHASES = { { at = 1.0, every = 7.0, chain = 1, delay = 1.0 },
                 { at = 0.66, every = 5.5, chain = 2, delay = 0.85 },
                 { at = 0.33, every = 4.5, chain = 3, delay = 0.7 } }

local function rand(a, b) return a + math.random() * (b - a) end

-- ── Sprites (los del jugador, dibujados con los colores invertidos) ──────────
local sprites, spriteDead, spriteCrouch
local bodyDown, bodyUp, headUp, headDown, joyEyes
local invShader

function Mirror.loadAssets()
    if sprites then return end
    sprites = {
        require('src/fx/Anim').image('assets/images/player/monstrito1.png'),
        require('src/fx/Anim').image('assets/images/player/monstrito2.png'),
        require('src/fx/Anim').image('assets/images/player/monstrito3.png'),
    }
    spriteDead   = require('src/fx/Anim').image('assets/images/player/monstrito4.png')
    spriteCrouch = require('src/fx/Anim').image('assets/images/player/monstrito5.png')
    bodyDown = require('src/fx/Anim').image('assets/images/bosses/mirror/Body_ArmsDown.png')
    bodyUp   = require('src/fx/Anim').image('assets/images/bosses/mirror/Body_ArmsUp.png')
    headUp   = require('src/fx/Anim').image('assets/images/bosses/mirror/Head_Up.png')
    headDown = require('src/fx/Anim').image('assets/images/bosses/mirror/Head_Down.png')
    joyEyes  = require('src/fx/Anim').image('assets/images/bosses/mirror/JoyEyes.png')
end

function Mirror.sizePx() return 9 * PLAYER_SCALE, 16 * PLAYER_SCALE end

-- Hitboxes: exactamente las del jugador (x, y, w, h, crouching son campos
-- simples de la entidad: la compensación de latencia del servidor los rebobina)
Mirror.getOuterBounds = PlayerAdventure.getOuterBounds
Mirror.getInnerBounds = PlayerAdventure.getInnerBounds

-- ── Cuerpo: un PlayerAdventure con input de mentira y sonidos graves ─────────
local stub = { left = false, right = false, crouch = false, jumpP = false, crouchP = false }
local StubInput = {
    pressed = function(a)
        if a == 'jump'   then local v = stub.jumpP;   stub.jumpP   = false; return v end
        if a == 'crouch' then local v = stub.crouchP; stub.crouchP = false; return v end
        return false
    end,
    down = function(a)
        if a == 'move_left'  then return stub.left  end
        if a == 'move_right' then return stub.right end
        if a == 'crouch'     then return stub.crouch end
        return false
    end,
}

local function noop() end
local realSound
local BodySound = {
    play = function(name, pitch, vol)
        local r = (name == 'jump' and rand(JUMP_PITCH[1], JUMP_PITCH[2]))
               or (name == 'step' and rand(STEP_PITCH[1], STEP_PITCH[2])) or PITCH
        realSound.play(name, (pitch or 1) * r, vol)
    end,
    stopTracked = noop, playTracked = noop, stopMusic = noop, playMusic = noop,
    isPlaying = function() return false end,
}

function Mirror:initBoss()
    local b = PlayerAdventure:new(self.x, self.y)
    b.updateDrowning = noop            -- no se ahoga (ni toca la música)
    b.lives = 99
    b.speedMult, b.jumpMult = SPEED_MULT, JUMP_MULT
    -- Los jugadores son sólidos para él (y él para ellos: level.solidBodies),
    -- salvo mientras él o ellos son invulnerables: entonces se atraviesan
    local me = self
    b.solidAgainst = function(level)
        local out = {}
        for _, pa in ipairs(level.players or {}) do
            if me.inv <= 0 and not pa:isInvulnerable() then out[#out+1] = pa end
        end
        -- y los objetos sólidos (morteros...)
        for _, o in ipairs(level.solidBodies or {}) do
            if o.solidFull then out[#out+1] = o end
        end
        return out
    end
    self.body = b
    self.w, self.h, self.crouching = b.w, b.h, false
    self.frame, self.puff, self.facing = 3, 1, self.facing or 1
    self.clock      = 0
    self.hist       = setmetatable({}, { __mode = 'k' })  -- [pa] = { {t, mx, jp, cr, cp}, ... }
    self.seen       = setmetatable({}, { __mode = 'k' })  -- [pa] = { jumpN, crouchN }
    self.replayT    = 0                 -- hasta dónde se ha reproducido
    self.memoryFrom = 0                 -- no reproducir nada anterior (InitializeQueues)
    self.lastMx, self.lastCr = 0, false
    self.mirrored   = false
    self.nextFlip   = rand(1, 3)
    self.target, self.targetT, self.switchPause = nil, 0, 0
    self.idleT, self.randDir, self.randT = 0, 0, 0
    self.evadeCD    = 0
    self.koDur      = 0
    self.laughN     = 0
end

function Mirror:phase()
    local r = (self.hpMax or 1) > 0 and (self.hp or 0) / self.hpMax or 1
    local ph = PHASES[1]
    for _, p in ipairs(PHASES) do if r <= p.at then ph = p end end
    return ph
end
function Mirror:delay() return (self.props.delay or 1) * self:phase().delay end

-- Un paso del cuerpo con el input dado
function Mirror:runBody(dt, level, mx, jumpP, crouch, crouchP)
    local b = self.body
    stub.left, stub.right = mx < 0, mx > 0
    stub.crouch, stub.jumpP, stub.crouchP = crouch or false, jumpP or false, crouchP or false
    local rI, rS = Input, Sound
    realSound = rS
    Input, Sound = StubInput, BodySound
    local ok, err = pcall(b.update, b, dt, level)
    Input, Sound = rI, rS
    if not ok then error(err, 0) end

    -- Pinchos / peligros: en vez de morir, se lleva un golpe y sale despedido
    if b.dying then
        b.dying, b.deathPhase, b.alive = false, nil, true
        b.vy, b.onGround = ADV_JUMP_VEL * 0.9, false
        self:damage(1, 'hazard')
    end
    -- Se cayó del mapa: vuelve a su sitio
    if b.y > level.heightPx + TILE_PX * 3 then
        b.x, b.y, b.vx, b.vy = self.home.x, self.home.y, 0, 0
    end
    self:syncFromBody()
end

function Mirror:syncFromBody()
    local b = self.body
    self.x, self.y = b.x, b.y
    self.facing, self.frame, self.puff = b.facing, b.frame, b.puff
    self.crouching = b.crouching
end

-- ── Grabación de los jugadores ────────────────────────────────────────────────
function Mirror:record(level)
    local keep = self:delay() + 1
    for _, pa in ipairs(level.players or {}) do
        local h, s = self.hist[pa], self.seen[pa]
        if not h then
            h, s = {}, { pa.inJumpN or 0, pa.inCrouchN or 0 }
            self.hist[pa], self.seen[pa] = h, s
        end
        local jn, cn = pa.inJumpN or 0, pa.inCrouchN or 0
        local live = not pa.dying and pa.alive ~= false
        h[#h+1] = { t = self.clock, mx = live and (pa.inMoveX or 0) or 0,
                    jp = live and jn > s[1], cr = live and (pa.inCrouch or false),
                    cp = live and cn > s[2] }
        s[1], s[2] = jn, cn
        while h[1] and h[1].t < self.clock - keep do table.remove(h, 1) end
    end
end

-- Input del objetivo de hace `delay` s (lo que Unity sacaba de sus colas)
function Mirror:replay()
    local rt = self.clock - self:delay()
    local from = math.max(self.replayT, self.memoryFrom)
    self.replayT = rt
    local h = self.target and self.hist[self.target]
    local mx, jp, cr, cp, got = 0, false, false, false, false
    if h then
        for _, smp in ipairs(h) do
            if smp.t > rt then break end
            if smp.t > from then
                mx, cr, got = smp.mx, smp.cr, true
                jp = jp or smp.jp
                cp = cp or smp.cp
            end
        end
    end
    if not got then mx, cr = self.lastMx, self.lastCr end
    if self.memoryFrom > rt then mx, cr = 0, false end        -- aún sin memoria
    self.lastMx, self.lastCr = mx, cr
    return mx, jp, cr, cp
end

-- ── Objetivo ──────────────────────────────────────────────────────────────────
function Mirror:candidates(level)
    local out = {}
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false
           and (not self.zone or BossZones.contains(self.zone, pa.x, pa.y)) then
            out[#out+1] = pa
        end
    end
    return out
end

local function dist(a, b) local dx, dy = a.x - b.x, a.y - b.y; return math.sqrt(dx * dx + dy * dy) end

function Mirror:chooseTarget(level, dt)
    local cands = self:candidates(level)
    local best, bestD
    for _, pa in ipairs(cands) do
        local d = dist(pa, self)
        if not bestD or d < bestD then best, bestD = pa, d end
    end
    local cur = self.target
    local valid = false
    for _, pa in ipairs(cands) do if pa == cur then valid = true end end
    if not valid then
        if best ~= cur then self.switchPause = cur and SWITCH_PAUSE or 0 end
        self.target, self.targetT = best, 0
        return
    end
    self.targetT = self.targetT + dt
    local b = self.body
    if best and best ~= cur and self.targetT >= LOCK_MIN and b.onGround and not b.gpPhase
       and bestD < dist(cur, self) * SWITCH_RATIO - SWITCH_MARGIN then
        self.target, self.targetT, self.switchPause = best, 0, SWITCH_PAUSE
    end
end

-- ── Entrada (cinemática genérica de Boss.lua) ────────────────────────────────
-- Sale de debajo de la pantalla de un salto enorme, atravesando el suelo (que
-- revienta hacia arriba), cae en su sitio del editor y se ríe de los jugadores.
-- El plan (de dónde sale, cuánto dura) sale solo de la zona y de su sitio:
-- igual en el servidor y en cada cliente (el dibujo de la risa lo necesita).
local INTRO_WAIT, INTRO_APEX, INTRO_LAUGH_GAP = 0.45, 150, 0.25
-- Dónde queda DE PIE al caer: el suelo bajo su sitio del editor (su centro
-- está en mitad de la casilla, no apoyado: antes se quedaba medio enterrado
-- hasta empezar la pelea). Mismo cálculo en el servidor y en los clientes.
function Mirror:introLandY()
    local level, hx, hy = self.levelRef, self.home.x, self.home.y
    if self._landY then return self._landY end
    if not level then return hy end
    local ob = self.body:getOuterBounds()
    local feet = ob.y + ob.h - self.body.y                  -- (del centro a los pies, de pie)
    local z = self.zone
    local hit, top = level:landingCross(hx, hy - TILE_PX, z and z.y1 + TILE_PX or level.heightPx)
    self._landY = hit and (top - feet) or hy
    return self._landY
end
Mirror.wantsLevel = true                                     -- (BossZones.link le da el nivel)

function Mirror:introPlan()
    local z, hx, hy = self.zone, self.home.x, self:introLandY()
    local viewBottom = z and math.max(z.y1, (z.y0 + z.y1) / 2 + WINDOW_H / 2) or hy + WINDOW_H / 2
    local y0 = viewBottom + self.sprH
    local g = ADV_GRAVITY
    local vy = -math.sqrt(2 * g * (y0 - hy + INTRO_APEX))
    local jumpT = (-vy + math.sqrt(2 * g * INTRO_APEX)) / g
    return y0, vy, jumpT, INTRO_WAIT + jumpT + INTRO_LAUGH_GAP
end
function Mirror:introLength()
    local _, _, _, laughAt = self:introPlan()
    return laughAt + LAUGH_DUR + 0.15
end
function Mirror:onIntroStart(level, players)
    local y0 = self:introPlan()
    self.x, self.y, self.frame, self.puff = self.home.x, y0, 2, 1
    self.laughN, self.popped = 0, false
    local near
    for _, pa in ipairs(players or {}) do
        if not near or dist(pa, self) < dist(near, self) then near = pa end
    end
    if near then self.facing = near.x < self.x and -1 or 1 end
end
function Mirror:updateIntro(dt, level, t)
    local y0, vy, jumpT, laughAt = self:introPlan()
    local hy = self:introLandY()
    local floorY = hy + self.sprH / 2
    local tj = t - INTRO_WAIT
    if tj < 0 then
        self.y = y0
    elseif tj < jumpT then
        if tj - dt < 0 then Sound.play('jump', 0.55) end
        self.y = y0 + vy * tj + 0.5 * ADV_GRAVITY * tj * tj
        local rising = vy + ADV_GRAVITY * tj < 0
        self.frame = rising and 2 or 3
        -- Atraviesa el suelo: revienta hacia arriba
        if rising and not self.popped and self.y - self.sprH / 2 <= floorY then
            self.popped = true
            Sound.play('gpImpact', 0.6)
            Entity.emitFx('spike_pop', self.x, floorY)
            Entity.emitFx('block_break', self.x - TILE_PX / 2, floorY)
            Entity.emitFx('shake_small', self.x, floorY)
        end
    else
        if self.y ~= hy then
            -- Aterriza
            self.y, self.frame = hy, 3
            Sound.play('gpImpact', 0.8)
            Entity.emitFx('gp_land', self.x, floorY)
        end
        local lt = t - laughAt
        -- Aplastado al caer y rebote
        self.puff = 1 + 0.18 * math.exp(-(tj - jumpT) * 9) * math.cos((tj - jumpT) * 22)
        while lt >= 0 and self.laughN < 5 and lt >= LAUGH_FRAME + self.laughN * 2 * LAUGH_FRAME do
            Sound.play('mirrorLaugh', rand(0.92, 1.08))
            self.laughN = self.laughN + 1
        end
    end
end
-- Tiempo de la risa que toca dibujar (estado 'laugh', o el final de la entrada)
function Mirror:laughTime()
    if self.state == 'laugh' then return self.deadTimer or 0 end
    if self.state == 'intro' and self.zone then
        local _, _, _, laughAt = self:introPlan()
        local lt = (self.deadTimer or 0) - laughAt
        if lt >= 0 and lt < LAUGH_DUR then return lt end
    end
    return nil
end

-- ── Pelea ─────────────────────────────────────────────────────────────────────
function Mirror:onFightStart(n)
    -- (tras la entrada: el cuerpo de verdad, de pie en su sitio)
    local b = self.body
    b.x, b.y, b.vx, b.vy, b.onGround, b.facing = self.x, self.y, 0, 0, true, self.facing
    self.puff, b.puff = 1, 1
    self.memoryFrom = self.clock
    self.replayT = self.clock
    self.nextFlip = self.clock + rand(self.props.flipMin or 1, self.props.flipMax or 3)
end

function Mirror:updateBoss(dt, level)
    self.clock = self.clock + dt
    self:record(level)
    local b, st = self.body, self.state

    -- Cristal roto: tocarlo duele y lo devuelve a una plataforma
    local g = st ~= 'dormant' and self:glass(level)
    if g and g:isActiveGlass() and b.vy >= -120 and st ~= 'warp_out' and st ~= 'portal' and st ~= 'leap'
       and Boss.overlap(self:getOuterBounds(), g:glassBox()) then
        self:glassEscape(level)
        return
    end

    if st == 'dormant' then
        self:runBody(dt, level, 0)
        local near
        for _, pa in ipairs(level.players or {}) do
            if not near or dist(pa, self) < dist(near, self) then near = pa end
        end
        if near then b.facing = near.x < self.x and -1 or 1; self.facing = b.facing end
        return
    elseif st == 'laugh' then
        -- HandlePlayerDeath: se para y se ríe (5 "risas" en la animación)
        self.deadTimer = self.deadTimer + dt
        while self.laughN < 5 and self.deadTimer >= LAUGH_FRAME + self.laughN * 2 * LAUGH_FRAME do
            Sound.play('mirrorLaugh', rand(0.92, 1.08))
            self.laughN = self.laughN + 1
        end
        b.vx = 0
        self:runBody(dt, level, 0)
        if self.deadTimer >= LAUGH_DUR then
            -- HandlePlayerRevive: InitializeQueues (vuelve a grabar desde cero)
            self.state, self.deadTimer = 'fight', 0
            self.memoryFrom = self.clock
            if self:glassDanger(level) then self:toPlatforms(level) end
        end
        return
    elseif st == 'ko' then
        self.deadTimer = self.deadTimer + dt
        self:runBody(dt, level, 0)
        if self.deadTimer >= self.koDur and b.onGround then
            self.state, self.deadTimer = 'fight', 0
            if self:glassDanger(level) then self:toPlatforms(level) end
        end
        return
    end

    -- (risa pendiente de una muerte durante un ataque: en cuanto pisa suelo)
    if self.laughPending and (st == 'fight' or st == 'recover' or st == 'perch') and b.onGround and not b.gpPhase then
        self:startLaugh()
        return
    end
    if self:updateAttack(dt, level) then return end
    -- Aviso o cristales: deja de copiar y se va a las plataformas
    if st == 'fight' and self:glassDanger(level) and b.onGround and not b.gpPhase then
        self:chooseTarget(level, 0)
        return self:toPlatforms(level)          -- (aunque no haya objetivo: nunca en el suelo)
    end

    -- ── 'fight' ──────────────────────────────────────────────────────────────
    self:chooseTarget(level, dt)
    -- Ataque de arena cada cierto tiempo (solo desde el suelo, sin nada raro)
    self.attackT = (self.attackT or 0) + dt
    if self.props.arenaAttacks ~= false and self.zone and self.attackT >= self:phase().every * (self.props.attackEvery or 7) / 7
       and b.onGround and not b.gpPhase and self.target and self:mayAttack(level) then   -- (aliado: por turnos)
        self.attackT, self.chainLeft = 0, self:phase().chain
        return self:startWarp(level)
    end
    if self.clock > self.nextFlip then           -- HandleDirectionChanges
        self.mirrored = not self.mirrored
        self.nextFlip = self.clock + rand(self.props.flipMin or 1, self.props.flipMax or 3)
    end

    local mx, jp, cr, cp = self:replay()
    if self.switchPause > 0 then
        self.switchPause = self.switchPause - dt
        mx, jp, cr, cp = 0, false, false, false
    end
    if self.mirrored then mx = -mx end

    -- Comportamiento aleatorio: el jugador lleva rato quieto → unos pasos
    if self.props.randomMove ~= false then
        if mx == 0 and not jp then self.idleT = self.idleT + dt else self.idleT = 0 end
        if self.randT > 0 then
            self.randT = self.randT - dt
            mx = self.randDir
        elseif self.idleT >= IDLE_TO_RANDOM then
            self.idleT = 0
            self.randT = rand(RANDOM_MOVE[1], RANDOM_MOVE[2])
            self.randDir = math.random() < 0.5 and -1 or 1
        end
    end

    -- Evitar explotación: jugador justo encima → salto apartándose
    self.evadeCD = math.max(0, self.evadeCD - dt)
    local t = self.target
    if t and self.props.evade ~= false and b.onGround and not b.gpPhase and self.evadeCD <= 0 then
        local dy, dx = self.y - t.y, math.abs(t.x - self.x)
        if dy > 0 and dy < EVADE_ABOVE and dx < EVADE_DX then
            self.evadeCD = EVADE_CD
            if math.random() < EVADE_CHANCE then
                b.vy, b.onGround, b.jumpsLeft = EVADE_JUMP, false, 1
                b.vx = (t.x > self.x and -1 or 1) * EVADE_PUSH
                b.puff = 1.15
                realSound = Sound; BodySound.play('jump')
            end
        end
    end

    self:runBody(dt, level, mx, jp, cr, cp)
    self:hitPlayers(level)
end

-- ── Ataques de arena ─────────────────────────────────────────────────────────
-- Plataformas de su arena: tramos de ≥ 2 casillas con suelo y 2 libres encima,
-- al menos 2 casillas por encima del suelo de la zona (se calculan una vez)
function Mirror:arenaPlatforms(level)
    if self._plats then return self._plats end
    local z, T = self.zone, TILE_PX
    local out = {}
    local floorRow = z.row + z.h - 1
    local function solid(c, r) return level:getDef(c, r).collision ~= 'none' end
    for r = z.row + 2, floorRow - 2 do
        local run = nil
        for c = z.col, z.col + z.w do
            local ok = c < z.col + z.w and solid(c, r) and not solid(c, r - 1) and not solid(c, r - 2)
            if ok then run = run or { c0 = c }; run.c1 = c
            elseif run then
                if run.c1 - run.c0 >= 1 then
                    local def = level:getDef(run.c0, r)
                    out[#out + 1] = { x = ((run.c0 + run.c1) / 2 - 0.5) * T,
                                      top = (r - 1) * T + (def.hitbox and def.hitbox.y or 0) * T,
                                      x0 = (run.c0 - 1) * T, x1 = run.c1 * T }
                end
                run = nil
            end
        end
    end
    self._plats = out
    return out
end

-- Del centro del cuerpo a los pies (de pie)
function Mirror:feetOff()
    local ob = self.body:getOuterBounds()
    return ob.y + ob.h - self.body.y
end

-- Primer suelo (o plataforma) debajo de x desde y
function Mirror:groundBelow(level, x, y)
    local z = self.zone
    local hit, top = level:landingCross(x, y, z.y1 + TILE_PX)
    return hit and top or z.y1
end

-- ── Cristal roto (evento de su zona) ─────────────────────────────────────────
function Mirror:glass(level)
    if self._glass == nil and self.zone then
        self._glass = false
        for _, e in ipairs(level.liveEntities or {}) do
            if e.def and e.def.name == 'bossglass' and e.alive and e:findZone(level) == self.zone then self._glass = e end
        end
    end
    return self._glass or nil
end
function Mirror:glassDanger(level)
    local g = self:glass(level)
    return g ~= nil and g:isDanger()
end

-- Plataforma sobre la que está de pie (o nil)
function Mirror:platformUnder(level)
    local b = self.body
    if not b.onGround then return nil end
    local ob = b:getOuterBounds()
    local feet = ob.y + ob.h
    for _, p in ipairs(self:arenaPlatforms(level)) do
        if math.abs(feet - p.top) <= 4 and self.x >= p.x0 - 8 and self.x <= p.x1 + 8 then return p end
    end
    return nil
end

-- x sobre una plataforma a la que saltar: la más cercana al objetivo (justo
-- encima de él si está en ella)
function Mirror:platformTargetX(level)
    local tx, best, bd = self:targetX(level), nil, nil
    local b = self.body
    for _, p in ipairs(self:arenaPlatforms(level)) do
        local d = math.max(0, p.x0 - tx, tx - p.x1)
        if not bd or d < bd then best, bd = p, d end
    end
    if not best then return tx end
    return math.max(best.x0 + b.w, math.min(best.x1 - b.w, tx))
end

-- Toca los cristales: 1 de vida y de un salto a la plataforma alcanzable más cercana
function Mirror:glassEscape(level)
    local b, g = self.body, ADV_GRAVITY
    self:damage(1, 'hazard')
    if self:isDying() then return end
    Sound.play('glassHit', 0.85)
    Entity.emitFx('mirror_shards', self.x, self.y + self.sprH / 2)
    local vy = -(self.props.glassJump or 950)
    local rise = vy * vy / (2 * g)
    local ob = b:getOuterBounds()
    local feet = ob.y + ob.h
    local best, bd
    for _, p in ipairs(self:arenaPlatforms(level)) do
        if p.top > feet - rise + 16 then                   -- (llega por encima de ella)
            local d = math.max(0, p.x0 - self.x, self.x - p.x1)
            if not bd or d < bd then best, bd = p, d end
        end
    end
    local tx = best and math.max(best.x0 + b.w, math.min(best.x1 - b.w, self.x)) or self.x
    self.leapTX, self.leapVX = tx, (tx - self.x) / (-vy / g)
    b.vy, b.onGround, b.gpPhase, b.crouching = vy, false, nil, false
    self.state, self.deadTimer, self.chainLeft = 'leap', 0, 0
end

function Mirror:startWarp(level)
    self.state, self.deadTimer = 'warp_out', 0
    self.body.vx, self.body.vy = 0, 0
    Sound.play('mirrorWarp')
    Entity.emitFx('mirror_shards', self.x, self.y)
    -- ¿Qué ataque? Desde plataforma si hay alguna, alternando; si no, espejo
    local plats = self:arenaPlatforms(level)
    self.attackN = (self.attackN or 0) + 1
    self.nextAttack = (#plats > 0 and self.attackN % 2 == 0) and 'perch' or 'portal'
    -- (con el cristal roto, solo desde las plataformas)
    if #plats > 0 and self:glassDanger(level) then self.nextAttack = 'perch' end
end

-- Cristal roto: a las plataformas. Si ya está en una, salta desde ahí; si no,
-- se rompe y aparece en una
function Mirror:toPlatforms(level)
    self.chainLeft = 1
    if self:platformUnder(level) then
        self.state, self.deadTimer = 'perch', 0
        return true
    end
    self:startWarp(level)
    return true
end

function Mirror:targetX(level)
    local t, z, T = self.target, self.zone, TILE_PX
    local x = t and t.x or self.x
    return math.max(z.x0 + T, math.min(z.x1 - T, x))
end

-- Estados de ataque (true = ya está hecho este paso)
function Mirror:updateAttack(dt, level)
    local st, b, z, T = self.state, self.body, self.zone, TILE_PX
    if st == 'warp_out' then
        self.deadTimer = self.deadTimer + dt
        if self.deadTimer >= WARP_OUT_T then
            self:chooseTarget(level, 0)
            if self.nextAttack == 'perch' then self:startPerch(level) else self:startPortal(level) end
        end
        return true
    elseif st == 'portal' then
        -- En el espejo, sobre el objetivo: lo sigue y el último instante se fija
        self.deadTimer = self.deadTimer + dt
        local aimT = (self.props.portalAim or 1.0) * (self:phase().chain > 1 and 0.85 or 1)
        self:chooseTarget(level, dt)
        if self.deadTimer < aimT - PORTAL_LOCK then
            local dx = self:targetX(level) - self.x
            local step = PORTAL_FOLLOW * dt
            self.x = self.x + math.max(-step, math.min(step, dx))
            b.x = self.x
        end
        self.markX, self.markY = self.x, self:groundBelow(level, self.x, self.y)
        if self.deadTimer >= aimT then
            -- ¡Cae! (el ground pound del cuerpo de verdad)
            self.state, self.deadTimer = 'dive', 0
            b.gpPhase, b.gpT, b.vx, b.vy, b.onGround = 'fall', 0, 0, 0, false
            self.gpHit = false
        end
        return true
    elseif st == 'perch' then
        -- De pie en la plataforma, mirando al objetivo, agachándose para saltar
        self.deadTimer = self.deadTimer + dt
        self:chooseTarget(level, dt)
        local tx = self:glassDanger(level) and self:platformTargetX(level) or self:targetX(level)
        b.facing = (tx < self.x) and -1 or 1
        self.markX, self.markY = tx, self:groundBelow(level, tx, self.y - 3 * T)
        -- (agachado solo de dibujo: agacharse de verdad en una plataforma
        -- traspasable la atraviesa)
        self:runBody(dt, level, 0)
        self.crouching = self.deadTimer > PERCH_T * 0.5
        if self.deadTimer >= PERCH_T and not self:mayAttack(level) then
            self.deadTimer = PERCH_T                       -- (aliado atacando: espera su turno, posado)
        elseif self.deadTimer >= PERCH_T then
            -- Salto hacia él: en lo alto, ground pound (cae justo encima)
            -- (sin chocar con el techo de la zona: si no, cortaba el salto a medias)
            local ob = b:getOuterBounds()
            local room = ob.y - (self.zone.y0 + 8)
            local rise = math.max(40, math.min(LEAP_VY * LEAP_VY / (2 * ADV_GRAVITY), room))
            local vy = -math.sqrt(2 * ADV_GRAVITY * rise)
            local apexT = -vy / ADV_GRAVITY
            self.leapTX = tx
            self.leapVX = (tx - self.x) / apexT
            b.vy, b.onGround, b.crouching = vy, false, false
            b.puff = 1.15
            realSound = Sound; BodySound.play('jump')
            self.state, self.deadTimer = 'leap', 0
        end
        return true
    elseif st == 'leap' then
        -- Vuelo balístico (a mano: más rápido que su control en el aire)
        self.deadTimer = self.deadTimer + dt
        b.vy = b.vy + ADV_GRAVITY * dt
        b:moveAndCollide(level, self.leapVX * dt, b.vy * dt)
        b.facing = self.leapVX < 0 and -1 or 1
        b.frame = 2
        self:syncFromBody()
        self.markX, self.markY = self.leapTX, self:groundBelow(level, self.leapTX, self.y)
        if b.vy >= 0 or b.onGround or self.deadTimer > 1.5 then
            b.gpPhase, b.gpT, b.vx, b.vy = 'windup', 0, 0, 0
            b.puff = 1.15
            realSound = Sound; BodySound.play('gpStart')
            Entity.emitFx('gp_start', self.x, self.y)
            self.state, self.deadTimer, self.gpHit = 'dive', 0, false
        end
        return true
    elseif st == 'dive' then
        self.deadTimer = self.deadTimer + dt
        self:runBody(dt, level, 0)
        self:hitPlayers(level)
        if b.gpLanded or (not b.gpPhase and b.onGround) or self.deadTimer > 3 then
            Entity.emitFx('shake_small', self.x, self.y)
            self.markX, self.markY = nil, nil
            self.state, self.deadTimer = 'recover', 0
        end
        return true
    elseif st == 'recover' then
        -- Aterriza de su ataque: una pausa corta y sigue (sin aturdirse: solo
        -- el ground pound de un JUGADOR lo aturde)
        self.deadTimer = self.deadTimer + dt
        self:runBody(dt, level, 0)
        if self.deadTimer >= (self.props.recoverTime or RECOVER_T) then
            self.chainLeft = (self.chainLeft or 1) - 1
            if self:glassDanger(level) then return self:toPlatforms(level) end
            if self.chainLeft > 0 and not self:mayAttack(level) then self.chainLeft = 0 end   -- (aliado: por turnos)
            if self.chainLeft > 0 and self.target then return self:startWarp(level) or true end
            self.state, self.deadTimer = 'fight', 0
            self.memoryFrom = self.clock          -- (vuelve a copiar desde ahora)
            self.attackT = 0
        end
        return true
    end
    return false
end

function Mirror:startPortal(level)
    local z, T = self.zone, TILE_PX
    local t = self.target
    local x = self:targetX(level)
    local y = math.max(z.y0 + T * 1.2, (t and t.y or self.y) - PORTAL_UP * T)
    self.x, self.y = x, y
    local b = self.body
    b.x, b.y, b.vx, b.vy, b.gpPhase, b.onGround, b.crouching = x, y, 0, 0, nil, false, false
    b.frame, b.puff = 2, 1
    self.frame, self.crouching = 2, false
    self.state, self.deadTimer = 'portal', 0
    Sound.play('mirrorAppear')
    Sound.play('mirrorPortal')
    Entity.emitFx('mirror_glint', x, y)
end

function Mirror:startPerch(level)
    local plats, T = self:arenaPlatforms(level), TILE_PX
    local tx = self:targetX(level)
    -- La plataforma más lejos del objetivo en horizontal (pero a menos de 9
    -- casillas: tiene que llegar de un salto); entre las dos mejores, al azar
    table.sort(plats, function(a, c) return math.abs(a.x - tx) > math.abs(c.x - tx) end)
    local cands = {}
    for _, p in ipairs(plats) do if math.abs(p.x - tx) <= 9 * T and math.abs(p.x - tx) >= 1.5 * T then cands[#cands + 1] = p end end
    local p = cands[math.random(math.min(2, math.max(1, #cands)))] or plats[1]
    if not p or #cands == 0 then return self:startPortal(level) end
    local b = self.body
    local x = math.max(p.x0 + b.w, math.min(p.x1 - b.w, p.x))
    local y = p.top - self:feetOff()
    b.x, b.y, b.vx, b.vy, b.gpPhase, b.onGround, b.crouching = x, y, 0, 0, nil, true, false
    b.facing = (tx < x) and -1 or 1
    self:syncFromBody()
    self.state, self.deadTimer = 'perch', 0
    Sound.play('mirrorAppear')
    Entity.emitFx('mirror_glint', x, y)
end

-- Cae sobre la cabeza de un jugador / su ground pound impacta
-- F1: el CUERPO que copia al jugador (sus dos cajas, las de un jugador)
function Mirror:debugBoxes()
    local b = self.body
    if not (b and b.getOuterBounds) then return nil end
    local o, i = b:getOuterBounds(), b:getInnerBounds()
    return { { x = o.x, y = o.y, w = o.w, h = o.h, kind = 'area' }, { x = i.x, y = i.y, w = i.w, h = i.h } }
end

function Mirror:hitPlayers(level)
    local b = self.body
    local gob = self:getOuterBounds()
    local falling = b.vy > 0 or b.gpPhase == 'fall'
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false and not pa:isInvulnerable() then
            local pob = pa:getOuterBounds()
            if falling and Boss.overlap(gob, pob) and gob.y + gob.h < pob.y + pob.h * 0.35 + 10
               and gob.y + gob.h * 0.5 < pob.y then
                -- (en pleno ground pound le cae encima: 2, como el del jugador a él)
                local n = (b.gpPhase == 'fall') and GP_DAMAGE or 1
                Boss.withPlayer(pa, function() pa:hurt(n) end)
                if b.gpPhase == 'fall' then self.gpHit = true end
                b.vy, b.onGround, b.jumpsLeft = HEAD_BOUNCE, false, 2
                b.vx = (self.x < pa.x and -1 or 1) * HEAD_PUSH
                b.gpPhase, b.gpT = nil, 0
                b.puff = 1.15
                self:syncFromBody()
                gob = self:getOuterBounds()
                falling = false
            end
        end
    end
    -- Copia también el ground pound: aplasta al de debajo, empuja al resto
    if b.gpLanded then
        local z = Interactions.poundZone(b)
        for _, pa in ipairs(level.players or {}) do
            if not pa.dying and pa.alive ~= false then
                local dx, dy = pa.x - self.x, pa.y - self.y
                if Boss.overlap(z, pa:getInnerBounds()) then
                    Boss.withPlayer(pa, function() pa:hurt(GP_DAMAGE) end)
                elseif math.abs(dx) <= PlayerAdventure.GP_RADIUS_X and math.abs(dy) <= PlayerAdventure.GP_RADIUS_Y then
                    pa:knockback(dx >= 0 and 1 or -1)
                end
            end
        end
    end
end

-- Roto (desapareciendo): ni se le toca ni es sólido
function Mirror:isActive() return self.state ~= 'warp_out' and Boss.isActive(self) end
function Mirror:isSolidBody() return self.state ~= 'warp_out' and self.state ~= 'portal' and Boss.isSolidBody(self) end

-- Aturdido (KO): solo admite un golpe (ver Boss.damage)
Mirror.stunnable = true
function Mirror:isStunned() return self.state == 'ko' end
function Mirror:endStun()
    self.state, self.deadTimer = 'fight', 0
    self.memoryFrom = self.clock      -- se despierta y vuelve a copiar desde cero
end

-- Muere un jugador: se ríe SIEMPRE. Si está a medias de un ataque (roto, en
-- el espejo, saltando, cayendo) se ríe en cuanto vuelve a tener los pies en
-- el suelo (laughPending). Antes solo se reía si estaba copiando: con los
-- ataques de arena casi nunca lo estaba.
local LAUGH_NOW = { fight = true, recover = true, perch = true }
function Mirror:onPlayerDeath(pa)
    if self:isDying() or Boss.INTRO[self.state] then return end
    if LAUGH_NOW[self.state] and self.body.onGround then self:startLaugh()
    else self.laughPending = true end
end
function Mirror:startLaugh()
    self.laughPending = false
    self.chainLeft = 0
    self.state, self.deadTimer, self.laughN = 'laugh', 0, 0
    self.markX, self.markY = nil, nil
    self.body.vx, self.body.gpPhase, self.crouching = 0, nil, false
end

function Mirror:onDamaged(n, kind)
    if self.state == 'laugh' then
        self.state, self.deadTimer = 'fight', 0
        -- (con el cristal roto, directo a las plataformas: ni un paso copiando en el suelo)
        if self.levelRef and self:glassDanger(self.levelRef) then self:toPlatforms(self.levelRef) end
    end
    self.chainLeft = 0                      -- (golpeado: se acaba la ristra de ataques)
end

-- Ground pound encima: KO
function Mirror:onPounded(pa)
    local b = self.body
    self.chainLeft = 0
    self.state, self.deadTimer, self.koDur = 'ko', 0, KO_POUND
    b.gpPhase, b.vx, b.vy = nil, 0, -200
    b.onGround = false
    Sound.play('stunned', 0.85)
end

-- Ground pound cerca: sale despedido y aturdido
function Mirror:onKnocked(dir)
    local b = self.body
    if self.state == 'fight' or self.state == 'laugh' or self.state == 'recover' or self.state == 'perch' then
        self.state, self.deadTimer, self.koDur = 'ko', 0, KO_KNOCK
        self.chainLeft = 0
    end
    b.gpPhase = nil
    b.vx, b.vy, b.onGround = dir * KNOCK_VX, KNOCK_VY, false
    Sound.play('stunned', 0.85)
end


-- Muerte: primero se queda donde murió con la animación de caída, en rojo,
-- entre explosiones (Boss 'dying_hold'); luego el sonido de muerte del
-- jugador y su muerte normal (salta y cae con los ojos en X).
function Mirror:onDefeat()
    self.body.vx, self.body.vy, self.body.gpPhase = 0, 0, nil
end
function Mirror:onDeathFall() Sound.play('dies2', PITCH) end

-- ── Red ───────────────────────────────────────────────────────────────────────
function Mirror:netPackExtra()
    return { math.floor(self.puff * 100 + 0.5), self.crouching and 1 or 0,
             self.markX and math.floor(self.markX + 0.5) or 0, self.markY and math.floor(self.markY + 0.5) or 0 }
end
function Mirror:netApplyExtra(a, b, f)
    if type(b[1]) == 'number' then self.puff = b[1] / 100 end
    self.crouching = b[2] == 1
    local mx, my = tonumber(b[3]) or 0, tonumber(b[4]) or 0
    if mx ~= 0 or my ~= 0 then self.markX, self.markY = mx, my else self.markX, self.markY = nil, nil end
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
local INVERT_GLSL = [[
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec4 c = Texel(tex, tc);
    return vec4(1.0 - c.rgb, c.a) * color;
}]]

local function useInvert()
    if invShader == nil then
        local ok, sh = pcall(love.graphics.newShader, INVERT_GLSL)
        invShader = ok and sh or false
    end
    if invShader then love.graphics.setShader(invShader) end
end

-- Marca en el suelo de dónde caerá (parpadea)
local function drawMark(x, y, t)
    local on = math.floor(t * 8) % 2 == 0
    local w = 72
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle('fill', x - w / 2, y - 6, w, 6)
    love.graphics.setColor(0.6, 0.9, 1, on and 0.95 or 0.5)
    for i = 0, 5, 2 do love.graphics.rectangle('fill', x - w / 2 + i * 12, y - 4, 12, 4) end
end

-- El espejo flotante (marco de cristal pixelado) donde aparece para caer
local function drawPortal(x, y, k, now)
    local w, h = math.floor(88 * k / 4) * 4, math.floor(128 * k / 4) * 4
    if w < 8 then return end
    local x0, y0 = math.floor(x - w / 2), math.floor(y - h / 2)
    love.graphics.setColor(0, 0, 0, 0.5)                                   -- sombra
    love.graphics.rectangle('fill', x0 + 4, y0 + 4, w, h)
    love.graphics.setColor(0.55, 0.8, 0.95, 1)                             -- marco
    love.graphics.rectangle('fill', x0, y0 + 8, w, h - 16)
    love.graphics.rectangle('fill', x0 + 8, y0, w - 16, h)
    love.graphics.setColor(0.08, 0.12, 0.25, 0.85)                         -- cristal
    love.graphics.rectangle('fill', x0 + 6, y0 + 12, w - 12, h - 24)
    love.graphics.rectangle('fill', x0 + 12, y0 + 6, w - 24, h - 12)
    -- Brillo diagonal que recorre el cristal
    local p = (now * 0.9) % 1.6 - 0.3
    love.graphics.setColor(0.8, 0.95, 1, 0.35)
    for i = 0, 3 do
        local sx = math.floor(x0 + 12 + (w - 24) * p + i * 4 - (h - 24) * 0.3)
        local sy = y0 + 12 + i * math.floor((h - 24) / 4)
        if sx > x0 + 10 and sx < x0 + w - 14 then love.graphics.rectangle('fill', sx, sy, 4, math.floor((h - 24) / 4)) end
    end
end

-- (el Espejo perseguidor — types/mirrorchase.lua — dibuja el mismo espejo flotante y la misma marca)
Mirror.drawPortal, Mirror.drawMark = drawPortal, drawMark

function Mirror:render(camX, camY)
    local x, y = math.floor(self.x - camX), math.floor(self.y - camY)
    local st   = self.state
    local now0 = love.timer.getTime()
    -- Marca del sitio donde caerá y espejo flotante (sin colores invertidos)
    if self.markX and not EDITOR_VIEW then drawMark(math.floor(self.markX - camX), math.floor(self.markY - camY), now0) end
    if st == 'portal' and not EDITOR_VIEW then
        drawPortal(x, y, math.min(1, (self.deadTimer or 0) / PORTAL_IN_T), now0)
    end
    local s    = PLAYER_SCALE * (self.puff or 1)
    local f    = self.facing or 1
    local r, g, bb = 1, 1, 1
    if self:flashRed() then r, g, bb = 1, 0.2, 0.2 end
    useInvert()
    local ga = self:ghostAlpha()
    love.graphics.setColor(r, g, bb, ga)

    -- Antes de su entrada no está (sale de debajo de la pantalla)
    if st == 'dormant' and self.zone and not EDITOR_VIEW then
        love.graphics.setShader(); love.graphics.setColor(1, 1, 1, 1)
        return
    end
    local laughT = self:laughTime()
    if laughT then
        -- Laugh.anim: cuadro A = cabeza arriba + brazos abajo, cuadro B =
        -- cabeza abajo (baja un poco, con los ojos) + brazos arriba
        local k   = math.floor(laughT / LAUGH_FRAME) % 2
        local bob = (k == 1) and math.floor(PLAYER_SCALE / 2) or 0
        local body, head = (k == 1) and bodyUp or bodyDown, (k == 1) and headDown or headUp
        local iw, ih = body:getWidth(), body:getHeight()
        love.graphics.draw(body, x, y, 0, s * f, s, iw / 2, ih / 2)
        love.graphics.draw(head, x, y + bob, 0, s * f, s, iw / 2, ih / 2)
        -- Ojos de alegría, donde van los ojos en X
        local cell = math.max(1, math.floor(s / 2 + 0.5))
        local ew, eh = joyEyes:getDimensions()
        for _, side in ipairs({ -1, 1 }) do
            local cx = math.floor(x + side * 1.2 * s * f + 0.5)
            local cy = math.floor(y + bob - 2.5 * s + 0.5)
            love.graphics.draw(joyEyes, cx - math.floor(ew * cell / 2), cy - math.floor(eh * cell / 2), 0, cell, cell)
        end
    else
        local img
        if st == 'dying_fall' then
            img = spriteDead
        elseif st == 'dying_hold' then
            -- Animación de caída del jugador: brazos arriba / abajo
            img = sprites[(math.floor((self.deadTimer or 0) * FALL_FPS) % 2 == 0) and 1 or 3]
        elseif self.crouching or self.frame == 5 then
            img = spriteCrouch
        else
            img = sprites[self.frame] or sprites[3]
        end
        local iw, ih = img:getWidth(), img:getHeight()
        local sx = s * f
        if st == 'warp_out' then
            -- Se rompe: se estrecha hasta desaparecer, blanco
            local k = math.min(1, (self.deadTimer or 0) / WARP_OUT_T)
            sx = sx * (1 - k)
            love.graphics.setColor(1, 1, 1, ga * (1 - k * 0.5))
        elseif st == 'portal' then
            local k = math.min(1, (self.deadTimer or 0) / PORTAL_IN_T)
            sx, s = sx * k, s * k
        end
        love.graphics.draw(img, x, y, 0, sx, s, iw / 2, ih / 2)
        if st == 'dying_fall' then DeadEyes.draw(x, y, s, f, r, g, bb, 1) end
    end
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
    if st == 'ko' then PlayerAdventure.drawStunStars(self.x - camX, self.y - camY) end
end

return {
    name = 'mirror', label = 'Jefe Espejo', category = 'Jefes',
    description = 'Jefe que copia los movimientos de los jugadores con retraso, con los colores invertidos.',
    class = Mirror,
    boss = { title = 'ESPEJO' },
    hide = Boss.HIDE,
    defaults = { points = 25 },
    props = Boss.props({ hp = 8, hpPerPlayer = 4 }, {
        { key='delay', kind='number', label='Retardo de la copia', group='Espejo', default=1.5,
          min=0.2, max=3, step=0.1, help='Segundos que tarda en repetir lo que hace el jugador' },
        { key='flipMin', kind='number', label='Invierte controles (mín. s)', group='Espejo', default=1,
          min=0.5, max=30, step=0.5, help='Cada cuánto se pone a moverse en espejo (s, mínimo)' },
        { key='flipMax', kind='number', label='Invierte controles (máx. s)', group='Espejo', default=3,
          min=0.5, max=30, step=0.5 },
        { key='evade', kind='bool', label='Esquiva desde abajo', group='Espejo', default=true,
          help='Salta apartándose cuando un jugador se le pone justo encima' },
        { key='randomMove', kind='bool', label='Pasos al azar', group='Espejo', default=true,
          help='Si el jugador se queda quieto, da unos pasos al azar' },
        { key='arenaAttacks', kind='bool', label='Ataques de arena', group='Ataques', default=true,
          help='Se rompe en cristales y ataca desde un espejo flotante o desde una plataforma de la zona' },
        { key='attackEvery', kind='number', label='Ataca cada (s, fase 1)', group='Ataques', default=7,
          min=2, max=30, step=0.5, help='Copiando este tiempo antes de un ataque de arena (luego, más a menudo)' },
        { key='portalAim', kind='number', label='Apuntando desde el espejo (s)', group='Ataques', default=1.0,
          min=0.4, max=3, step=0.05, help='Sigue al jugador desde el espejo y se fija el último instante' },
        { key='glassJump', kind='number', label='Salto al tocar el cristal', group='Ataques', default=950,
          min=500, max=1600, step=20, help='Si cae en el cristal roto de su zona, vuelve a una plataforma de este salto (px/s)' },
        { key='recoverTime', kind='number', label='Pausa tras caer (s)', group='Ataques', default=0.3,
          min=0, max=4, step=0.05, help='Al aterrizar de su ground pound se para este tiempo y sigue (no se aturde)' },
    }),
    editor = { sprite = 'assets/images/player/monstrito3.png', invert = true },
}
