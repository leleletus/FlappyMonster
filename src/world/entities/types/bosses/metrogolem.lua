-- Jefe GÓLEM METRÓNOMO (types/bosses/metrogolem.lua; docs/bosses/metrogolem.md): el jefe de El Santuario del Compás,
-- elegido por el usuario entre las ideas de docs/design/estelar-levels-2.md (2026-11-15). Un metrónomo de piedra
-- estelar que FLOTA sobre la arena; todo va al compás de la música (el reloj de compás: src/world/systems/BeatClock.lua).
--   1. EL PÉNDULO: de su base cuelga una varilla con una PESA que va de un lado al otro, UN LADO POR PULSO (en cada
--      pulso está en un extremo; a mitad de pulso pasa por abajo, a la altura de quien está de pie). La pesa daña
--      (1 + empujón). Se esquiva quedándose lejos de su vertical, o saltándola cuando sube. Es FUNCIÓN del reloj:
--      igual en un jugador, servidor y cliente.
--   2. EL GOLPE (cada `slamEvery` frases; en la fase 3, cada frase): en el pulso 5 de la frase guarda el péndulo y
--      sube ('windup': la lámpara en rojo, una DIANA en el suelo que le sigue a uno hasta el pulso 8 y se fija); en el
--      pulso 1 — justo cuando cambian los Bloques Beep — cae ('slam'): aplasta (2) a quien esté debajo. Desde la fase
--      2 salen dos ONDAS de cristal por el suelo (se saltan; 1 + empujón).
--   3. ATURDIDO ('dazed', una frase; en la fase 3, 6 pulsos): en el suelo, la lámpara rajada y estrellitas: lo ÚNICO
--      vulnerable → pisotón 1 / ground pound 2, un golpe por ocasión; luego se levanta ('rise', 2 pulsos) y vuelve a
--      flotar con el péndulo ('hover', se acerca despacio a quien tenga más cerca, sin salir del centro de la arena).
--   Fases por vida (2/3, 1/3): 2 = el péndulo más abierto y las ondas; 3 = el péndulo DOS lados por pulso (corcheas)
--      y un golpe por frase.
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
local SLAM_EVERY = { 2, 2, 1 }                -- frases flotando entre golpes
local DAZE_BEATS = { 8, 8, 6 }
local DRIFT      = { 38, 50, 64 }             -- px/s que se acerca flotando
local AIM_SPD    = 300                        -- px/s que sigue la diana mientras carga
local ROD        = 6.5 * T                    -- largo del péndulo (centro de la pesa)
local BOB        = 60                         -- caja de la pesa
local SLAM_T     = 0.14                       -- s de la caída
local RISE_BEATS = 2
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
function G:floorY() local _, _, _, y1 = self:zoneBounds(); return y1 end
function G:hoverY() return self:floorY() - 40 - ROD - self.outerH / 2 end      -- (la pesa, abajo, a la altura de la cabeza)
function G:landY() return self:floorY() - self.outerH / 2 end
function G:pivot() return self.x, self.y + self.outerH / 2 end
function G:xRange()
    local x0, x1 = self:zoneBounds()
    local c = (x0 + x1) / 2
    return c - 4 * T, c + 4 * T, x0 + 3 * T, x1 - 3 * T              -- (flotando: el centro; la diana: casi toda)
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
    self.x, self.y = self.home.x, self:hoverY()
    self:enter('hover')
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
function G:waveXs()
    if self.state ~= 'dazed' or (self.wavesOn or 0) == 0 then return nil end
    local t = self.deadTimer or 0
    if t >= WAVE_LIFE then return nil end
    return self.landX - WAVE_SPD * t, self.landX + WAVE_SPD * t
end
function G:getHazardBoxes()
    if not self:isActive() then return nil end
    local out = {}
    local bx, by = self:bobPos()
    if bx then out[#out + 1] = { x = bx - BOB / 2, y = by - BOB / 2, w = BOB, h = BOB, effect = 'hurt', dmg = 1, part = 'pendulum' } end
    local a, b = self:waveXs()
    if a then
        local fy = self:floorY()
        for _, x in ipairs({ a, b }) do
            out[#out + 1] = { x = x - WAVE_W / 2, y = fy - WAVE_H, w = WAVE_W, h = WAVE_H, effect = 'hurt', dmg = 1, part = 'wave' }
        end
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
    local hx0, hx1, ax0, ax1 = self:xRange()
    local function crossed(k)              -- ¿cruzó el pulso k (0..7) de la frase en este paso?
        local a, b = math.floor(prevBeats), math.floor(beats)
        for n = a + 1, b do if n % BeatClock.BEATS == k then return true end end
        return false
    end
    if st == 'hover' then
        local tx = math.max(hx0, math.min(hx1, self:nearestX(level)))
        local d = tx - self.x
        self.x = self.x + math.max(-DRIFT[p] * dt, math.min(DRIFT[p] * dt, d))
        self.y = self:hoverY() + math.sin(t * 2.2) * 6
        if crossed(0) then self.phr = (self.phr or 0) + 1 end
        if (self.phr or 0) >= SLAM_EVERY[p] and crossed(4) and self:mayAttack(level) then
            self.phr = 0
            self.theta0 = self:swingAngle(beats)
            self.landX = math.max(ax0, math.min(ax1, self:nearestX(level)))     -- (la diana sale donde está uno)
            self:enter('windup')
            Sound.play('golemWind')
        end
    elseif st == 'windup' then
        -- sube y le sigue a uno (la diana) hasta el pulso 8; en el 1 cae
        local u = math.min(1, t / bs)
        self.y = self:hoverY() - WIND_UP * u
        if t < 3 * bs - 0.05 then
            local tx = math.max(ax0, math.min(ax1, self:nearestX(level)))
            local d = tx - self.landX
            self.landX = self.landX + math.max(-AIM_SPD * dt, math.min(AIM_SPD * dt, d))
        end
        local d = self.landX - self.x
        self.x = self.x + math.max(-1100 * dt, math.min(1100 * dt, d))           -- (vuela hasta encima de la diana)
        if crossed(0) or t > 5 * bs then
            self.x = self.landX
            self.y0 = self.y
            self:enter('slam')
        end
    elseif st == 'slam' then
        local u = math.min(1, t / SLAM_T)
        self.y = (self.y0 or self.y) + (self:landY() - (self.y0 or self.y)) * u * u
        if u >= 1 then
            self.y = self:landY()
            self:crush(level)
            Sound.play('golemSlam')
            Entity.emitFx('shake_big', self.x, self.y)
            Entity.emitFx('gp_start', self.x, self:floorY())
            self.wavesOn = (p >= 2) and 1 or 0
            if self.wavesOn == 1 then Sound.play('golemWave') end
            self:enter('dazed')
        end
    elseif st == 'dazed' then
        self.y = self:landY()
        if t >= self:downTime(DAZE_BEATS[p] * bs) then self:enter('rise'); Sound.play('golemRise') end
    elseif st == 'rise' then
        local u = math.min(1, t / (RISE_BEATS * bs))
        self.y = self:landY() + (self:hoverY() - self:landY()) * (u * (2 - u))
        if u >= 1 then self:enter('hover'); self.phr = 0 end
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
-- { fase, x de la caída, ángulo al guardar el péndulo ·1000, ondas }
function G:netPackExtra()
    return { self.phase or 1, math.floor(self.landX or self.x), math.floor((self.theta0 or 0) * 1000), self.wavesOn or 0 }
end
function G:netApplyExtra(a, b, f)
    if type(b[1]) ~= 'number' then return end
    self.phase, self.landX, self.theta0, self.wavesOn = b[1], b[2], b[3] / 1000, b[4]
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
        BossFx.target(now, math.floor(self.landX - camX), math.floor(self:floorY() - camY - 16), 8, 8)
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
    if w1 then
        local wv = img('wave')
        local fade = 1 - math.max(0, (t - WAVE_LIFE + 0.3) / 0.3)
        love.graphics.setColor(1, 1, 1, fade)
        for _, x in ipairs({ w1, w2 }) do
            love.graphics.draw(wv, math.floor(x - camX), math.floor(self:floorY() - camY), 0, 5, 5, wv:getWidth() / 2, wv:getHeight())
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
