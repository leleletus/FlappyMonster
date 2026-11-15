-- Jefe GÓLEM METRÓNOMO (types/bosses/metrogolem.lua; docs/bosses/metrogolem.md): el jefe de El Santuario del Compás,
-- elegido por el usuario entre las ideas de docs/design/estelar-levels-2.md (2026-11-15). Un metrónomo de piedra
-- estelar que FLOTA sobre la arena; todo va al compás de la música (el reloj de compás: src/world/systems/BeatClock.lua).
--   1. EL PÉNDULO: de su base cuelga una varilla con una PESA que va de un lado al otro, UN LADO POR PULSO (en cada
--      pulso está en un extremo; a mitad de pulso pasa por abajo). La pesa daña (1 + empujón). Es FUNCIÓN del reloj:
--      igual en un jugador, servidor y cliente. FLOTANDO ('hover') PERSIGUE al jugador más cercano por TODA la arena,
--      en x y en altura, para que la pesa le pase por encima de la cabeza a la altura de su cuerpo (el usuario,
--      2026-11-15: «la arena es gigante y el boss casi ni se mueve», «debe intentar darle con su péndulo, con
--      determinación»): va algo más despacio que el jugador corriendo, así que se le escapa corriendo o saltando la pesa.
--   2. EL GOLPE (cada `SLAM_EVERY` frases): en el pulso 5 de la frase guarda el péndulo y sube ('windup': lámpara en
--      rojo, una DIANA sobre lo que tenga debajo el jugador — suelo, repisa o plataforma — que le sigue hasta el pulso
--      8); en el pulso 1 — justo cuando cambian los Bloques Beep — cae ('slam') SOBRE LA SUPERFICIE de verdad que hay
--      debajo (Bloques Beep incluidos, estén como estén: cae en el suelo de cristal, nunca en el foso; antes caía al
--      borde de abajo de la zona: con la zona más alta acababa en los pinchos y subido a una repisa no te alcanzaba —
--      el usuario —). Aplasta (2) a quien esté debajo. Desde la fase 2, dos ONDAS de cristal por esa superficie (se
--      saltan; 1 + empujón) que se acaban en sus bordes.
--   3. ATURDIDO ('dazed', 6 pulsos; fase 3, 5): lámpara rajada y estrellitas: lo ÚNICO vulnerable → pisotón 1 /
--      ground pound 2, un golpe por ocasión; luego se levanta ('rise') y vuelve a perseguir.
--   Fases por vida (2/3, 1/3): 2 = el péndulo más abierto, las ondas y un golpe por frase; 3 = el péndulo DOS lados por
--      pulso (corcheas) y más rápido.
-- Entrada (genérica): baja del techo despacio, se le enciende la lámpara y despierta. Muerte: la genérica de Boss.
-- Encima flotando o cayendo: solo se rebota (la base). Su cuerpo es sólido de lado.
-- Arte: tools/art/bosses/make_metrogolem.py (assets/images/bosses/metrogolem/); sonidos: tools/sounds/metrogolem.py.
local Entity    = require 'src/world/entities/base/Entity'
local Boss      = require 'src/world/entities/base/Boss'
local BeatClock = require 'src/world/systems/BeatClock'
local BossFx    = require 'src/fx/BossFx'

local T  = TILE_PX
local S  = 8                                  -- escala del arte (24x28 → 192x224)
local BW, BH = 24, 28
local OX, OY = 12, 16                         -- (el punto del arte que va en x, y: el centro de la piedra)

local G = Entity.extend(Boss, {
    ATTACKS  = { windup = true, slam = true },
    OPENINGS = { dazed = true },
    debugColor = { 0.75, 0.7, 1 },
    hitbox = { outerW = 18 / BW, outerH = 23 / BH, innerW = 16 / BW, innerH = 22 / BH },
})
G.hurtSound   = 'golemHurt'
G.introLength = 3.4
G.wantsLevel  = true

-- Ritmo por fase
local AMP        = { 0.75, 0.92, 0.92 }       -- radianes del péndulo a cada lado
local RATE       = { 1, 1, 2 }                -- lados por pulso
local SLAM_EVERY = { 2, 1, 1 }                -- frases flotando entre golpes
local DAZE_BEATS = { 6, 6, 5 }
local CHASE      = { 175, 215, 250 }          -- px/s que persigue flotando (el jugador corre a ~266)
local CHASE_Y    = 170                        -- px/s en altura
local AIM_SPD    = 380                        -- px/s que sigue la diana mientras carga
local ROD        = 6.5 * T                    -- largo del péndulo (centro de la pesa)
local BOB        = 60                         -- caja de la pesa
local SLAM_G     = 5200                       -- px/s² de la caída
local RISE_BEATS = 1.5
local WIND_UP    = T                          -- lo que sube al cargar
local WAVE_SPD, WAVE_LIFE, WAVE_W, WAVE_H = 430, 1.7, 40, 34
G.AMP, G.RATE, G.ROD = AMP, RATE, ROD

local imgs = {}
local function img(n)
    local i = imgs[n]
    if not i then
        i = love.graphics.newImage('assets/images/bosses/metrogolem/' .. n .. '.png')
        i:setFilter('nearest', 'nearest')
        imgs[n] = i
    end
    return i
end
function G.loadAssets() for _, n in ipairs({ 'body_idle', 'body_lit', 'body_wind', 'body_dazed', 'rod', 'bob', 'wave' }) do img(n) end end
function G.sizePx() return BW * S, BH * S end

-- ── Datos de la arena ─────────────────────────────────────────────────────────
local function clamp(v, a, b) return math.max(a, math.min(b, v)) end
function G:zoneFloor() local _, _, _, y1 = self:zoneBounds(); return y1 end
-- ¿Se cae encima de esa casilla? Sólido, traspasable o Bloque Beep — esté como esté: cae en el suelo de cristal —
local function landable(level, c, r)
    local d = level:getDef(c, r)
    return d.collision == 'solid' or d.collision == 'oneway' or d.switchBlock ~= nil
end
-- La cara de arriba de lo primero que hay DEBAJO de su cuerpo (por debajo de `feet`) en x; sin nada, el borde de abajo
-- de la zona. También devuelve la fila.
function G:surfaceBelow(level, x, feet)
    local hw = self.outerW / 2 - 8
    local c0, c1 = math.floor((x - hw) / T) + 1, math.floor((x + hw) / T) + 1
    local r1 = math.floor(self:zoneFloor() / T) + 1
    for r = math.max(1, math.floor((feet - 8) / T) + 1), r1 do
        local top = (r - 1) * T
        if top >= feet - 8 then
            for c = c0, c1 do
                if landable(level, c, r) and not landable(level, c, r - 1) then return top, r end
            end
        end
    end
    return self:zoneFloor(), r1
end
-- Hasta dónde corre una onda por la superficie de la fila r (desde la columna de x): sus bordes en px
local function runOf(level, x, r)
    local c = math.floor(x / T) + 1
    local a, b = c, c
    while landable(level, a - 1, r) and not landable(level, a - 1, r - 1) do a = a - 1 end
    while landable(level, b + 1, r) and not landable(level, b + 1, r - 1) do b = b + 1 end
    return (a - 1) * T, b * T
end
function G:landY() return (self.landSurf or self:zoneFloor()) - self.outerH / 2 end
function G:pivot() return self.x, self.y + self.outerH / 2 end
-- Adónde quiere ir flotando: encima del jugador más cercano, a la altura justa para que la pesa le pase por el cuerpo
function G:chaseTarget(level)
    local x0, x1, y0, y1 = self:zoneBounds()
    local pa = self:nearestPlayer(level)
    local tx = pa and pa.x or self.x
    local ty = pa and (pa.y + 6 - ROD - self.outerH / 2) or self.y
    return clamp(tx, x0 + 2.5 * T, x1 - 2.5 * T), clamp(ty, y0 + self.outerH / 2 + 8, y1 - self.outerH / 2 - ROD * 0.6)
end
local function beatSec(level) return (level and level.beat and level.beat.period or 4) / BeatClock.BEATS end
function G:beats() return BeatClock.beats(self.levelRef) end
function G:ph() return math.max(1, math.min(3, self.phase or 1)) end

-- El péndulo ahora: ángulo (0 = abajo; + = hacia la derecha) y cuánto ha salido (0..1)
function G:swingAngle(beats)
    local p = self:ph()
    return AMP[p] * math.cos(math.pi * RATE[p] * (beats or self:beats()))
end
function G:pendulum()
    local st, t = self.state, self.deadTimer or 0
    local bs = beatSec(self.levelRef)
    if st == 'hover' then return self:swingAngle(), 1 end
    if st == 'windup' then
        local u = math.min(1, t / bs)                                      -- (en un pulso lo guarda)
        return (self.theta0 or 0) * (1 - u), 1 - u
    end
    if st == 'rise' then
        local u = math.min(1, t / (RISE_BEATS * bs))
        return self:swingAngle() * u, u
    end
    return 0, 0
end
function G:bobPos()
    local a, k = self:pendulum()
    if k <= 0 then return nil end
    local px, py = self:pivot()
    return px + math.sin(a) * ROD * k, py + math.cos(a) * ROD * k, a, k
end

-- ── Vida, fases ───────────────────────────────────────────────────────────────
function G:initBoss()
    self.phase = 1
    self.vx, self.vy = 0, 0
    self.landX, self.theta0, self.phr = self.x, 0, 0
end
function G:bossPhase() return self.phase or 1 end
function G:phaseFor(hp)
    local f = hp / math.max(1, self.hpMax)
    if f > 2 / 3 then return 1 elseif f > 1 / 3 then return 2 end
    return 3
end
function G:rollStart(r) self.phr = math.floor(r(0, 1.99)) end
function G:onFightStart(n)
    self.phase = 1
    self:enter('hover')
end
-- Donde acaba la entrada: en la mitad de arriba de la arena, sobre su sitio (luego persigue)
function G:hoverY()
    local _, _, y0, y1 = self:zoneBounds()
    return (y0 + y1) / 2 - 2 * T
end
function G:isVulnerable() return self:isActive() and self.state == 'dazed' end
function G:canBeKnocked() return false end
function G:onDamaged(n, kind)
    self.phase = self:phaseFor(self.hp)
    if self.state == 'dazed' and not self:isDying() then self:enter('rise'); Sound.play('golemRise') end
end

-- ── Golpes a los jugadores ────────────────────────────────────────────────────
local function overlap(a, b) return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h end
local DS
local function src(self, part) DS = DS or require 'src/player/DamageSource'; return DS.of(self, part) end

function G:crush(level)
    local ob = self:getOuterBounds()
    local box = { x = ob.x - 4, y = ob.y, w = ob.w + 8, h = ob.h + 6 }
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false and not pa:isInvulnerable() and overlap(pa:getOuterBounds(), box) then
            local dir = (pa.x >= self.x) and 1 or -1
            Boss.withPlayer(pa, function()
                pa:hurt(2, src(self, 'slam'))
                if not pa.dying then pa:squash(dir) end
            end)
        end
    end
end

-- La pesa y las ondas, como zonas de peligro (Interactions.defaultCheck: 1 de vida; el empujón, el de todos los
-- golpes: src/player/Knockback.lua)
-- (cada onda, nil cuando se sale de su superficie: waveL / waveR)
function G:waveXs()
    if self.state ~= 'dazed' or (self.wavesOn or 0) == 0 then return nil end
    local t = self.deadTimer or 0
    if t >= WAVE_LIFE then return nil end
    local a, b = self.landX - WAVE_SPD * t, self.landX + WAVE_SPD * t
    if a < (self.waveL or -math.huge) + WAVE_W / 2 then a = nil end
    if b > (self.waveR or math.huge) - WAVE_W / 2 then b = nil end
    if not a and not b then return nil end
    return a, b
end
function G:getHazardBoxes()
    if not self:isActive() then return nil end
    local out = {}
    local bx, by = self:bobPos()
    if bx then out[#out + 1] = { x = bx - BOB / 2, y = by - BOB / 2, w = BOB, h = BOB, effect = 'hurt', dmg = 1, part = 'pendulum' } end
    local a, b = self:waveXs()
    local fy = self.landSurf or self:zoneFloor()
    for _, x in ipairs({ a or false, b or false }) do
        if x then out[#out + 1] = { x = x - WAVE_W / 2, y = fy - WAVE_H, w = WAVE_W, h = WAVE_H, effect = 'hurt', dmg = 1, part = 'wave' } end
    end
    return out
end
-- Contacto: primero la pesa y las ondas (como cualquier peligro: 'hurt' de 1, la fuente es su parte); luego lo de
-- todos los jefes (encima: pisotón si está aturdido, si no rebote). Sin efectos: el cliente lo usa para predecir.
-- (Boss.interact no mira getHazardBoxes: sin esto la pesa no dañaba — la primera prueba lo cazó —)
function G:interact(pa)
    if self:isActive() then
        local pob = pa:getOuterBounds()
        for _, hb in ipairs(self:getHazardBoxes() or {}) do
            if overlap(pob, hb) then return 'hurt', hb.dmg or 1, 'hazard', hb end
        end
    end
    return Boss.interact(self, pa)
end

-- ── Simulación (un jugador y servidor) ────────────────────────────────────────
function G:nearestX(level)
    local pa = self:nearestPlayer(level)
    return pa and pa.x or self.x
end
local function toward(v, target, maxStep) return v + clamp(target - v, -maxStep, maxStep) end

function G:updateBoss(dt, level)
    self.levelRef = self.levelRef or level
    local st = self.state
    if st == 'fight' then self:onFightStart(1); st = self.state end
    if not self:isActive() then return end
    self.deadTimer = (self.deadTimer or 0) + dt
    local t = self.deadTimer
    local bs = beatSec(level)
    local beats = self:beats()
    local prevBeats = self.lastBeats or beats
    self.lastBeats = beats
    local p = self:ph()
    local x0, x1 = self:zoneBounds()
    local function crossed(k)              -- ¿cruzó el pulso k (0..7) de la frase en este paso?
        local a, b = math.floor(prevBeats), math.floor(beats)
        for n = a + 1, b do if n % BeatClock.BEATS == k then return true end end
        return false
    end
    local function aimSurf()               -- la diana: en la superficie que tiene el jugador bajo los pies (atraviesa
        local pa = self:nearestPlayer(level)  -- lo que haya por encima: debajo de una repisa tampoco se libra uno)
        local ref = self.y + self.outerH / 2
        if pa then local ob = pa:getOuterBounds(); ref = math.max(ref, ob.y + ob.h - 16) end
        self.landSurf = self:surfaceBelow(level, self.landX, ref)
    end
    if st == 'hover' then
        local tx, ty = self:chaseTarget(level)
        self.x = toward(self.x, tx, CHASE[p] * dt)
        self.y = toward(self.y, ty, CHASE_Y * dt)
        if crossed(0) then self.phr = (self.phr or 0) + 1 end
        if (self.phr or 0) >= SLAM_EVERY[p] and crossed(4) and self:mayAttack(level) then
            self.phr = 0
            self.theta0 = self:swingAngle(beats)
            self.landX = clamp(self:nearestX(level), x0 + 2.5 * T, x1 - 2.5 * T)    -- (la diana sale donde está uno)
            self.yWind = self.y
            aimSurf()
            self:enter('windup')
            Sound.play('golemWind')
        end
    elseif st == 'windup' then
        -- sube y le sigue a uno (la diana) hasta el pulso 8; en el 1 cae
        local u = math.min(1, t / bs)
        self.y = (self.yWind or self.y) - WIND_UP * u
        if t < 3 * bs - 0.05 then
            self.landX = toward(self.landX, clamp(self:nearestX(level), x0 + 2.5 * T, x1 - 2.5 * T), AIM_SPD * dt)
        end
        self.x = toward(self.x, self.landX, 1300 * dt)                  -- (vuela hasta encima de la diana)
        aimSurf()
        if crossed(0) or t > 5 * bs then
            self.x = self.landX
            aimSurf()
            self.vy = 0
            self:enter('slam')
        end
    elseif st == 'slam' then
        self.vy = (self.vy or 0) + SLAM_G * dt
        self.y = self.y + self.vy * dt
        if self.y >= self:landY() then
            self.y, self.vy = self:landY(), 0
            self:crush(level)
            Sound.play('golemSlam')
            Entity.emitFx('shake_big', self.x, self.y)
            Entity.emitFx('gp_start', self.x, self.landSurf)
            local _, r = self:surfaceBelow(level, self.x, self.landSurf - 4)
            self.waveL, self.waveR = runOf(level, self.x, r)
            self.wavesOn = (p >= 2) and 1 or 0
            if self.wavesOn == 1 then Sound.play('golemWave') end
            self:enter('dazed')
        end
    elseif st == 'dazed' then
        self.y = self:landY()
        if t >= self:downTime(DAZE_BEATS[p] * bs) then self:enter('rise'); Sound.play('golemRise') end
    elseif st == 'rise' then
        local tx, ty = self:chaseTarget(level)
        self.x = toward(self.x, tx, CHASE[p] * dt)
        self.y = toward(self.y, math.min(ty, self:landY() - 2 * T), CHASE_Y * 3 * dt)
        if t >= RISE_BEATS * bs then self:enter('hover'); self.phr = 0 end
    end
end

-- ── Entrada ───────────────────────────────────────────────────────────────────
function G:introFocus() return self.home.x, self:hoverY() end
function G:onIntroStart(level, players)
    self.levelRef = self.levelRef or level
    self.introStep = 0
end
function G:updateIntro(dt, level, t)
    self.levelRef = self.levelRef or level
    local _, _, zy0 = self:zoneBounds()
    local y0, y1 = zy0 - self.outerH, self:hoverY()
    local u = math.min(1, t / 2.2)
    self.x = self.home.x
    self.y = y0 + (y1 - y0) * (1 - (1 - u) * (1 - u))
    if self.introStep < 1 then self.introStep = 1; Sound.play('golemWake') end
    if t >= 2.3 and self.introStep < 2 then
        self.introStep = 2
        Entity.emitFx('shake_small', self.x, self.y)
    end
end

-- ── Red ───────────────────────────────────────────────────────────────────────
-- { fase, x de la caída, ángulo al guardar el péndulo ·1000, ondas, superficie de la caída, bordes de las ondas }
function G:netPackExtra()
    return { self.phase or 1, math.floor(self.landX or self.x), math.floor((self.theta0 or 0) * 1000), self.wavesOn or 0,
             math.floor(self.landSurf or self:zoneFloor()), math.floor(self.waveL or 0), math.floor(self.waveR or 0) }
end
function G:netApplyExtra(a, b, f)
    if type(b[1]) ~= 'number' then return end
    self.phase, self.landX, self.theta0, self.wavesOn = b[1], b[2], b[3] / 1000, b[4]
    self.landSurf, self.waveL, self.waveR = b[5], b[6], b[7]
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
function G:debugBoxes()
    local out = {}
    for _, hb in ipairs(self:getHazardBoxes() or {}) do out[#out + 1] = { x = hb.x, y = hb.y, w = hb.w, h = hb.h } end
    return out
end

function G:render(camX, camY)
    local st, t = self.state, self.deadTimer or 0
    if st == 'dormant' and not EDITOR_VIEW then return end
    local alpha = self:ghostAlpha()
    local beats = self:beats()
    local lit = self.levelRef and self.levelRef.beat and (beats - math.floor(beats)) < 0.3
    -- la diana del golpe
    if st == 'windup' then
        local now = love.timer.getTime()
        love.graphics.setColor(1, 0.45, 0.5, 0.6 + 0.4 * math.min(1, t / 0.4))
        BossFx.target(now, math.floor(self.landX - camX), math.floor((self.landSurf or self:zoneFloor()) - camY - 16), 8, 8)
    end
    -- el péndulo (detrás del cuerpo)
    local bx, by, a, k = self:bobPos()
    if bx then
        local px, py = self:pivot()
        love.graphics.setColor(1, 1, 1, alpha)
        local rod = img('rod')
        love.graphics.draw(rod, math.floor(px - camX), math.floor(py - camY), -a, S / 2, ROD * k / rod:getHeight(), rod:getWidth() / 2, 0)
        local bob = img('bob')
        love.graphics.draw(bob, math.floor(bx - camX), math.floor(by - camY), 0, S, S, bob:getWidth() / 2, bob:getHeight() / 2)
    end
    -- las ondas
    local w1, w2 = self:waveXs()
    if w1 or w2 then
        local wv = img('wave')
        local fade = 1 - math.max(0, (t - WAVE_LIFE + 0.3) / 0.3)
        love.graphics.setColor(1, 1, 1, fade)
        for _, x in ipairs({ w1 or false, w2 or false }) do
            if x then love.graphics.draw(wv, math.floor(x - camX), math.floor((self.landSurf or self:zoneFloor()) - camY), 0, 5, 5, wv:getWidth() / 2, wv:getHeight()) end
        end
    end
    -- el cuerpo
    local pose = 'body_idle'
    if st == 'windup' or st == 'slam' then pose = 'body_wind'
    elseif st == 'dazed' or self:isDying() then pose = 'body_dazed'
    elseif lit then pose = 'body_lit' end
    local r, g, b = 1, 1, 1
    if self:flashRed() then r, g, b = 1, 0.35, 0.35 end
    love.graphics.setColor(r, g, b, alpha)
    local sx = 0
    if st == 'windup' then sx = (math.floor(t * 30) % 2 == 0) and 2 or -2 end
    love.graphics.draw(img(pose), math.floor(self.x - camX) + sx, math.floor(self.y - camY), 0, S, S, OX, OY)
    if st == 'dazed' then
        BossFx.stars(self.x - camX, self.y - camY - self.outerH / 2 - 40, 70, 14, 4)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return {
    name = 'metrogolem', label = 'Gólem Metrónomo', category = 'Jefes',
    description = 'Un metrónomo de piedra que flota: su PÉNDULO barre la arena un lado por pulso; cada pocas frases '
               .. 'carga (diana) y CAE justo en el cambio de los Bloques Beep: aplasta y, desde la fase 2, suelta ondas. '
               .. 'Aturdido en el suelo una frase: solo entonces se le daña. Va con el reloj de compás del nivel.',
    class = G,
    boss = { title = 'GÓLEM METRÓNOMO' },
    hide = Boss.HIDE,
    defaults = { points = 30 },
    props = Boss.props({ hp = 9, hpPerPlayer = 3 }, {}),
    editor = { sprite = 'assets/images/bosses/metrogolem/body_idle.png' },
}
