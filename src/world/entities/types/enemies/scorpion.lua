-- El ESCORPIÓN (types/enemies/scorpion.lua): enemigo del VOLCÁN; una sola cola. Su gigante es el Escorpión Triple Aguijón
-- (types/bosses/giantscorpion.lua; diseño del usuario, docs/bosses/future-secret-bosses.md).
--   · Anda (patrulla). Si ve a un jugador delante a media distancia: clic de matraca y la cola se echa atrás (aviso,
--     WIND_T), la clava donde estaba el jugador ('sting') y se queda clavada un momento ('stuck'): quieto, buen momento
--     para pisarlo. Muy cerca, en vez de eso, cierra la PINZA ('pinch_wind' → 'pinch').
--   · Lo que hace daño: el aguijón al llegar, la pinza al cerrarse y tocarlo de lado. Pisarlo lo mata, como siempre.
-- La cola es una cadena de segmentos animada al momento (base/SegmentChain: solo dibujo); lo que golpea sale del
-- estado, deadTimer y la marca (netPack): online se ve y se decide igual.
local Entity = require 'src/world/entities/base/Entity'
local Kit    = require 'src/world/entities/base/ScorpionKit'
local Chain  = require 'src/world/entities/base/SegmentChain'
local Anim   = require 'src/fx/Anim'

local Scorpion = Entity.extend(Entity, {
    walkFps = 10, walkFrames = 4,
    idleEvery = { 3.0, 6.0 }, idleFor = { 0.6, 1.2 },
    debugColor = { 0.5, 0.4, 0.8 },
    hitbox = { outerW = 0.7, outerH = 0.58, innerW = 0.55, innerH = 0.45 },
})

local S = 3                              -- (0.5.118, el usuario: a ×4 era demasiado grande para ser el pequeño)
local FW, FH = Kit.FW, Kit.FH
local N, GAP = 12, 3.2 * S
local STING_STRETCH = 1.7                -- (clavando, la cola se estira lo justo para llegar: por delante de las pinzas)
local REACH   = 95                       -- px por delante de su centro hasta donde llega el aguijón
local PINCH_R = 65                       -- más cerca que esto: pinza
local SEE     = REACH + 15               -- a qué distancia ataca: solo donde de verdad llega
local SEE_Y   = 1.5 * TILE_PX
local WIND_T, SWING_T, STUCK_T = 0.45, 0.13, 0.75
local PINCH_WIND, PINCH_T = 0.32, 0.16
local COOLDOWN = 1.3
local SKITTER_EVERY = 1.1
local STING_BOX, PINCH_BOX = 14, 20      -- px: medio lado de lo que golpea (el pincho y la pinza, no más)

Scorpion.animId = 'enemies/scorpion'
Scorpion.wantsLevel = true
Scorpion.ownStunLook = true
function Scorpion.sizePx() return FW * S, FH * S end

local BUSY = { sting_wind = true, sting = true, stuck = true, pinch_wind = true, pinch = true }

function Scorpion:init()
    self.cd, self.markX, self.markY = 0, 0, 0
    self.props.stompable, self.props.onTouch = true, 'hurt'
end
function Scorpion:freeOfRoute() return BUSY[self.state] == true end

local function overlap(a, b) return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y end

-- El jugador delante, a su altura, sin pared en medio (→ jugador, distancia)
function Scorpion:sees(level)
    local f = self.facing or 1
    local feet = self.y + self.outerH / 2
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false and not pa.gulped then
            local pb = pa:getOuterBounds()
            local dx = (pa.x - self.x) * f
            if dx > 0 and dx < SEE and math.abs(pb.y + pb.h - feet) < SEE_Y then
                local clear = true
                for x = self.x, pa.x, f * 16 do
                    if level:collisionAt(x, self.y, true) then clear = false; break end
                end
                if clear then return pa, dx end
            end
        end
    end
    return nil
end

-- Golpea a los jugadores en la caja cuadrada de medio lado r alrededor de (x, y)
function Scorpion:hitAt(level, x, y, r)
    local box = { x = x - r, y = y - r, w = r * 2, h = r * 2 }
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false and not pa.peaceful and not pa:isInvulnerable() and overlap(box, pa:getOuterBounds()) then
            if not pa:hurt(1) and pa.recoil then pa:recoil((pa.x >= self.x) and 1 or -1) end
        end
    end
end

-- Vuelve a andar con su velocidad (0.5.118: sin ella movía las patas sin moverse)
function Scorpion:walkAgain()
    self.cd = COOLDOWN
    self.vx = (self.facing or 1) * (self.speed or 55)
    self:startWalk()
end

function Scorpion:handX() return self.x + (self.facing or 1) * Kit.HAND[1] * S end
function Scorpion:handY() return self.y + self.outerH / 2 + Kit.HAND[2] * S end

function Scorpion:updateCustom(dt, level)
    local st = self.state
    if self.cd > 0 then self.cd = math.max(0, self.cd - dt) end
    if st == 'walk' or st == 'idle' then
        if self.onGround and self.cd <= 0 and self.props.movement ~= 'static' then
            local pa, dx = self:sees(level)
            if pa then
                self.vx = 0
                if dx < PINCH_R then
                    self.state, self.deadTimer = 'pinch_wind', 0
                else
                    local f = self.facing or 1
                    self.markX = self.x + f * math.min(dx, REACH)
                    self.markY = self.y + self.outerH / 2          -- (se clava en el SUELO, delante de sus pies)
                    self.state, self.deadTimer = 'sting_wind', 0
                    Sound.playAt('scorpionClick', self.x, self.y)
                end
                return true
            end
        end
        if st == 'walk' then
            self.skitT = (self.skitT or SKITTER_EVERY) - dt
            if self.skitT <= 0 then
                self.skitT = SKITTER_EVERY
                Sound.playAt('scorpionSkitter', self.x, self.y, 1.2, 0.35)
            end
        end
        return false                                                  -- (andar: lo normal de Entity)
    end
    if not BUSY[st] then return false end

    self.deadTimer = self.deadTimer + dt
    local t = self.deadTimer
    self.vx = 0
    self:fall(level, dt)
    if self:fellOut(level) or self:inVoid(level) then self:dieBurst(); return true end
    if st == 'sting_wind' then
        if t >= WIND_T then self.state, self.deadTimer = 'sting', 0 end
    elseif st == 'sting' then
        if t >= SWING_T then
            Sound.playAt('scorpionSting', self.markX, self.markY)
            Entity.emitFx('gp_land', self.markX, self.markY)
            self:hitAt(level, self.markX, self.markY - STING_BOX, STING_BOX)
            self.state, self.deadTimer = 'stuck', 0
        end
    elseif st == 'stuck' then
        if t >= STUCK_T then self:walkAgain() end
    elseif st == 'pinch_wind' then
        if t >= PINCH_WIND then
            self.state, self.deadTimer = 'pinch', 0
            Sound.playAt('scorpionSnap', self.x, self.y)
            self:hitAt(level, self:handX(), self:handY(), PINCH_BOX)
        end
    elseif st == 'pinch' then
        if t >= PINCH_T then self:walkAgain() end
    end
    return true
end

-- ── Red: state, deadTimer, frame y facing ya viajan; esto, la marca del aguijón ──
function Scorpion:netPack() return { math.floor(self.markX or 0), math.floor(self.markY or 0) } end
function Scorpion:netApply(a, b, f)
    if b and type(b[1]) == 'number' then self.markX, self.markY = b[1], b[2] end
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
local parts
function Scorpion.loadAssets() parts = parts or Anim.load('enemies/scorpion_parts') end

local function fillIdle(tg, n, bx, by, f, wob)
    local k = S
    Chain.bez(tg, n, bx, by, bx - 7 * k * f, by - 9 * k, bx - 5 * k * f, by - 24 * k + wob, bx + 8 * k * f, by - 27 * k)   -- (curva del largo de la cadena: la punta, hacia delante)
end
local function fillWind(tg, n, bx, by, f)
    local k = S
    Chain.bez(tg, n, bx, by, bx - 8 * k * f, by - 8 * k, bx - 10 * k * f, by - 22 * k, bx - 3 * k * f, by - 28 * k)
end

function Scorpion:render(camX, camY)
    parts = parts or Anim.load('enemies/scorpion_parts')
    local st, t = self.state, self.deadTimer or 0
    local set = self:anims()
    local f = self.facing or 1
    local fr
    if st == 'walk' then fr = set:frameN('walk', self.frame or 1)
    elseif st == 'sting_wind' or st == 'pinch_wind' then fr = set:frameAt('windup', 0)
    elseif st == 'dead' or st == 'dead_fling' then fr = set:frameAt('dead', 0)
    else fr = set:frameAt('idle', 0) end
    local air = not self.onGround or st == 'dead_fling'
    local feetW = self.y + self.outerH / 2
    local gap = air and 0 or set:footGap(fr)
    local x = math.floor(self.x - camX)
    local feet = math.floor(feetW - camY) + gap * S
    local a = 1
    if st == 'dead' then a = math.max(0, 1 - t / self.tuning.deadDuration) end
    local r = (st == 'dead_fling') and t * 10 * f or 0
    love.graphics.setColor(1, 1, 1, a)
    if st == 'dead' or st == 'dead_fling' or st == 'dead_burst' then    -- (panza arriba: sin cola ni pinzas sueltas)
        set:drawFrame(fr, x, feet, r, S * f, S, 0.5, 1)
        love.graphics.setColor(1, 1, 1, 1)
        return
    end
    -- La pinza de atrás, el cuerpo, la de delante y ENCIMA la cola (el usuario)
    local wx, fy = self.x, feetW
    local closed = st == 'pinch'
    local reach = st == 'pinch' and 4 * S or (st == 'pinch_wind' and -2 * S or 0)
    Kit.drawArm(parts, wx + Kit.FAR[1] * S * f, fy + Kit.FAR[2] * S, wx + (Kit.HAND_FAR[1] * S + reach) * f, fy + Kit.HAND_FAR[2] * S,
                f > 0 and -0.35 or math.pi + 0.35, not closed, S, camX, camY, 0.65, a)
    love.graphics.setColor(1, 1, 1, a)
    set:drawFrame(fr, x, feet, r, S * f, S, 0.5, 1)
    Kit.drawArm(parts, wx + Kit.NEAR[1] * S * f, fy + Kit.NEAR[2] * S, wx + (Kit.HAND[1] * S + reach) * f, fy + Kit.HAND[2] * S,
                f > 0 and 0 or math.pi, not closed, S, camX, camY, nil, a)
    -- La cola
    self.tail = self.tail or Chain.new(N, GAP)
    local now = love.timer.getTime()
    local dt = math.min(0.1, now - (self.tailT or now))
    self.tailT = now
    local bx, by = wx + Kit.TAIL[1] * S * f, fy + Kit.TAIL[2] * S
    if st == 'sting' or st == 'stuck' then
        self.tail:advance(dt, Kit.FAST_K, Kit.FAST_DAMP, STING_STRETCH, Kit.strike, bx, by, S, f, self.markX, self.markY)
    elseif st == 'sting_wind' then
        self.tail:advance(dt, Kit.COIL_K, Kit.COIL_DAMP, nil, fillWind, bx, by, f)
    else
        self.tail:advance(dt, Kit.CALM_K, Kit.CALM_DAMP, nil, fillIdle, bx, by, f, math.sin(now * 1.5) * S * 0.5)
    end
    Kit.drawTail(parts, self.tail, 'stinger', st == 'sting_wind' and t < 0.1, S, camX, camY, nil, a)
    love.graphics.setColor(1, 1, 1, 1)
end

function Scorpion:debugBoxes()
    local out = {}
    if self.state == 'sting' then
        out[1] = { x = self.markX - STING_BOX, y = self.markY - STING_BOX * 2, w = STING_BOX * 2, h = STING_BOX * 2, kind = 'hazard' }
    elseif self.state == 'pinch' then
        out[1] = { x = self:handX() - PINCH_BOX, y = self:handY() - PINCH_BOX, w = PINCH_BOX * 2, h = PINCH_BOX * 2, kind = 'hazard' }
    end
    return out
end

return {
    name = 'scorpion', label = 'Escorpión', category = 'Enemigos',
    description = 'Del volcán. Anda; si te ve a media distancia, clic de matraca y clava la cola donde estabas (se queda '
               .. 'clavada un momento). Muy cerca, cierra la pinza. Pisarlo lo mata.',
    class = Scorpion,
    defaults = { speed = 55, points = 20, onTouch = 'hurt' },
    hide = { 'movement', 'attach', 'dropOnSight', 'detectRange', 'flyMode', 'flyRange', 'bobAmp', 'stompable', 'onTouch' },
    editor = { sprite = 'assets/images/enemies/scorpion/body-Sheet.png', frameW = FW },
}
