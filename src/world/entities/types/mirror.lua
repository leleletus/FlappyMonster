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
-- Con varios jugadores copia a uno solo: al más cercano, pero sin cambiar a
-- lo loco (tiempo mínimo por objetivo, histéresis de distancia y solo cuando
-- está en el suelo). Graba a TODOS a la vez, así al cambiar de objetivo sigue
-- el retardo del nuevo sin saltos.

local Entity          = require 'src/world/entities/Entity'
local Boss            = require 'src/world/entities/Boss'
local PlayerAdventure = require 'src/entities/PlayerAdventure'
local Interactions    = require 'src/world/entities/Interactions'
local DeadEyes        = require 'src/entities/DeadEyes'
local BossZones       = require 'src/world/BossZones'

local Mirror = Entity.extend(Boss, {
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

local function rand(a, b) return a + math.random() * (b - a) end

-- ── Sprites (los del jugador, dibujados con los colores invertidos) ──────────
local sprites, spriteDead, spriteCrouch
local bodyDown, bodyUp, headUp, headDown, joyEyes
local invShader

function Mirror.loadAssets()
    if sprites then return end
    sprites = {
        love.graphics.newImage('assets/images/player/monstrito1.png'),
        love.graphics.newImage('assets/images/player/monstrito2.png'),
        love.graphics.newImage('assets/images/player/monstrito3.png'),
    }
    spriteDead   = love.graphics.newImage('assets/images/player/monstrito4.png')
    spriteCrouch = love.graphics.newImage('assets/images/player/monstrito5.png')
    bodyDown = love.graphics.newImage('assets/images/bosses/mirror/Body_ArmsDown.png')
    bodyUp   = love.graphics.newImage('assets/images/bosses/mirror/Body_ArmsUp.png')
    headUp   = love.graphics.newImage('assets/images/bosses/mirror/Head_Up.png')
    headDown = love.graphics.newImage('assets/images/bosses/mirror/Head_Down.png')
    joyEyes  = love.graphics.newImage('assets/images/bosses/mirror/JoyEyes.png')
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

function Mirror:delay() return self.props.delay or 1 end

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

-- ── Pelea ─────────────────────────────────────────────────────────────────────
function Mirror:onFightStart(n)
    self.memoryFrom = self.clock
    self.replayT = self.clock
    self.nextFlip = self.clock + rand(self.props.flipMin or 1, self.props.flipMax or 3)
end

function Mirror:updateBoss(dt, level)
    self.clock = self.clock + dt
    self:record(level)
    local b, st = self.body, self.state

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
        end
        return
    elseif st == 'ko' then
        self.deadTimer = self.deadTimer + dt
        self:runBody(dt, level, 0)
        if self.deadTimer >= self.koDur and b.onGround then
            self.state, self.deadTimer = 'fight', 0
        end
        return
    end

    -- ── 'fight' ──────────────────────────────────────────────────────────────
    self:chooseTarget(level, dt)
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

-- Cae sobre la cabeza de un jugador / su ground pound impacta
function Mirror:hitPlayers(level)
    local b = self.body
    local gob = self:getOuterBounds()
    local falling = b.vy > 0 or b.gpPhase == 'fall'
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false and not pa:isInvulnerable() then
            local pob = pa:getOuterBounds()
            if falling and Boss.overlap(gob, pob) and gob.y + gob.h < pob.y + pob.h * 0.35 + 10
               and gob.y + gob.h * 0.5 < pob.y then
                Boss.withPlayer(pa, function() pa:hurt() end)
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
                    Boss.withPlayer(pa, function() pa:hurt() end)
                elseif math.abs(dx) <= PlayerAdventure.GP_RADIUS_X and math.abs(dy) <= PlayerAdventure.GP_RADIUS_Y then
                    pa:knockback(dx >= 0 and 1 or -1)
                end
            end
        end
    end
end

-- Aturdido (KO): solo admite un golpe (ver Boss.damage)
Mirror.stunnable = true
function Mirror:isStunned() return self.state == 'ko' end
function Mirror:endStun()
    self.state, self.deadTimer = 'fight', 0
    self.memoryFrom = self.clock      -- se despierta y vuelve a copiar desde cero
end

function Mirror:onPlayerDeath(pa)
    if self.state ~= 'fight' then return end
    self.state, self.deadTimer, self.laughN = 'laugh', 0, 0
    self.body.vx = 0
end

function Mirror:onDamaged(n, kind)
    if self.state == 'laugh' then self.state, self.deadTimer = 'fight', 0 end
end

-- Ground pound encima: KO
function Mirror:onPounded(pa)
    local b = self.body
    self.state, self.deadTimer, self.koDur = 'ko', 0, KO_POUND
    b.gpPhase, b.vx, b.vy = nil, 0, -200
    b.onGround = false
    Sound.play('stunned', 0.85)
end

-- Ground pound cerca: sale despedido y aturdido
function Mirror:onKnocked(dir)
    local b = self.body
    if self.state == 'fight' or self.state == 'laugh' then
        self.state, self.deadTimer, self.koDur = 'ko', 0, KO_KNOCK
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
    return { math.floor(self.puff * 100 + 0.5), self.crouching and 1 or 0 }
end
function Mirror:netApplyExtra(a, b, f)
    if type(b[1]) == 'number' then self.puff = b[1] / 100 end
    self.crouching = b[2] == 1
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

function Mirror:render(camX, camY)
    local x, y = math.floor(self.x - camX), math.floor(self.y - camY)
    local st   = self.state
    local s    = PLAYER_SCALE * (self.puff or 1)
    local f    = self.facing or 1
    local r, g, bb = 1, 1, 1
    if self:flashRed() then r, g, bb = 1, 0.2, 0.2 end
    useInvert()
    local ga = self:ghostAlpha()
    love.graphics.setColor(r, g, bb, ga)

    if st == 'laugh' then
        -- Laugh.anim: cuadro A = cabeza arriba + brazos abajo, cuadro B =
        -- cabeza abajo (baja un poco, con los ojos) + brazos arriba
        local k   = math.floor((self.deadTimer or 0) / LAUGH_FRAME) % 2
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
        love.graphics.draw(img, x, y, 0, s * f, s, iw / 2, ih / 2)
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
    }),
    editor = { sprite = 'assets/images/player/monstrito3.png', invert = true },
}
