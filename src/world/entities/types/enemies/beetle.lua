-- El ESCARABAJO RINOCERONTE (types/enemies/beetle.lua): enemigo EXCLUSIVO de la jungla (isla futura; diseño aprobado
-- por el usuario el 2026-10-28, docs/entities/enemies.md § Escarabajo Rinoceronte). Su gigante es el jefe del templo
-- (types/bosses/giantbeetle.lua).
--   · Anda (patrulla) y gira en paredes y bordes. Si ve a un jugador DELANTE y a su altura, escarba (aviso, WIND_T) y
--     EMBISTE en línea recta, mucho más rápido; contra una pared se queda aturdido un momento; en un borde frena.
--   · Tocarlo de lado quita 1 de vida (el cuerno y el caparazón).
--   · PISARLO lo pone PATAS ARRIBA (BACK_T s, pataleando): no hace daño y se puede COGER y LANZAR (systems/Carry: como
--     la caja pequeña). Pisado otra vez o con un ground pound, muere; si no, se da la vuelta solo y sigue.
--   · LANZADO derriba a los enemigos con los que choca y rompe las cajas; cae otra vez patas arriba.
--   · Cae en LAVA, en PINCHOS o al VACÍO (andando, patas arriba o lanzado): REVIENTA (el usuario).
--   · Un ground pound cerca (el empujón) también lo pone patas arriba.
-- Arte: assets/anim/enemies/beetle.json (hoja de 22x20 a escala 4, mira a la DERECHA; tools/art/enemies/
-- make_beetle.py — sus patas, retocadas a mano por el usuario). Todo lo que se dibuja sale del estado, deadTimer,
-- frame y facing (lo que viaja en las instantáneas): online se ve igual.
local Entity       = require 'src/world/entities/base/Entity'
local Interactions = require 'src/world/entities/base/Interactions'

local Beetle = Entity.extend(Entity, {
    walkFps = 8, walkFrames = 4,
    idleEvery = { 3.0, 6.0 }, idleFor = { 0.8, 1.6 },
    debugColor = { 0.55, 0.75, 0.3 },
    -- (el cuerpo mide ~16 de los 22 px del cuadro y ~12 de alto con las patas)
    hitbox = { outerW = 0.68, outerH = 0.6, innerW = 0.56, innerH = 0.46 },
})

local S         = GUMMY_SCALE
local FW, FH    = 22, 20
local SEE       = 6.5                  -- casillas: ve a un jugador delante hasta aquí
local WIND_T    = 0.45                 -- s escarbando antes de embestir
local CHARGE_V  = 380                  -- px/s embistiendo (anda a 50; el jugador, 240)
local CHARGE_MAX = 2.4                 -- s como mucho embistiendo
local DAZE_T    = 0.9                  -- s aturdido tras chocar con una pared
local COOLDOWN  = 1.2                  -- s sin volver a embestir
local BACK_T    = 3.0                  -- s patas arriba
local RIGHT_T   = 0.35                 -- s dándose la vuelta
local FLIP_HOP  = 300                  -- px/s: el saltito al volcarse
local THROWN_BOUNCE = 0.3

Beetle.animId    = 'enemies/beetle'
Beetle.carryable = true                -- (patas arriba: canBeCarried)
Beetle.weight    = 1
Beetle.wantsLevel = true
Beetle.ownStunLook = true
function Beetle.sizePx() return FW * S, FH * S end

local BACK = { onback = true, righting = true }

function Beetle:init()
    self.cd = 0
    -- (sus reglas de contacto son fijas: no se cambian en el editor — `hide` —, así que se ponen aquí)
    self.props.stompable, self.props.onTouch = true, 'hurt'
end

-- ── Reglas ────────────────────────────────────────────────────────────────────
function Beetle:onBack() return BACK[self.state] == true end
function Beetle:canBeCarried() return self.alive and self:onBack() and self.onGround ~= false end
function Beetle:isObstacle() return self.alive and not self:onBack() and self.state ~= 'thrown' and Entity.isObstacle(self) end

-- Sin efectos (el cliente la usa para predecir). Patas arriba: solo cuenta caerle encima (lo mata); de lado no hace
-- nada (se coge). Normal: encima = pisotón (lo vuelca) o ground pound (lo mata); de lado, 1 de vida.
function Beetle:interact(pa)
    local st = self.state
    if st == 'thrown' then return nil end
    local r, a, b, c = Interactions.defaultCheck(pa, self)
    if r == 'stomp' then
        if pa.gpPhase == 'fall' then return 'pound', a, b end
        return r, a, b, c
    end
    if self:onBack() then return nil end
    return r, a, b, c
end

-- Pisotón: de pie → patas arriba; patas arriba → muere
function Beetle:stomp()
    if self:onBack() or self.state == 'frozen' then return Entity.stomp(self) end
    if self.state == 'dead' then return end
    self:flipOver(0)
end
function Beetle:pound(pa) Entity.stomp(self) end

-- El empujón de un ground pound cercano: lo vuelca hacia ese lado
function Beetle:canBeKnocked() return self.alive and not self:onBack() and self.state ~= 'thrown' and Entity.canBeKnocked(self) end
function Beetle:knockback(dirX) self:flipOver(dirX * 220) end

function Beetle:flipOver(vx)
    self.state, self.deadTimer = 'onback', 0
    self.vx, self.vy, self.onGround = vx or 0, -FLIP_HOP, false
    Sound.play('stunned')
    Entity.emitFx('gp_start', self.x, self.y + self.outerH / 2)
end

function Beetle:onThrow(pa, vx, vy)
    self.state, self.deadTimer = 'thrown', 0
    self.vx, self.vy, self.onGround = vx, vy, false
end

-- ── Qué ve: un jugador DELANTE, a su altura, sin pared en medio ──────────────
function Beetle:sees(level)
    local f = self.facing or 1
    local feet = self.y + self.outerH / 2
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false then
            local pb = pa:getOuterBounds()
            local dx = (pa.x - self.x) * f
            if dx > 8 and dx < SEE * TILE_PX and math.abs(pb.y + pb.h - feet) < TILE_PX * 0.9 then
                local clear, y = true, self.y
                for x = self.x, pa.x, f * 16 do
                    if level:collisionAt(x, y, true) then clear = false; break end
                end
                if clear then return pa end
            end
        end
    end
    return nil
end

-- ── Lanzado: derriba enemigos y rompe cajas ───────────────────────────────────
local function overlap(a, b) return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y end
function Beetle:thrownHits(level)
    local ob = self:getOuterBounds()
    local b = { x = ob.x - 6, y = ob.y, w = ob.w + 12, h = ob.h }     -- (una caja lo para antes de tocarla: un poco más)
    local dir = (self.vx >= 0) and 1 or -1
    for _, e in ipairs(level.liveEntities or {}) do
        if e ~= self and e.alive and e.state ~= 'dead' and e.state ~= 'carried' and not (e.isGhost and e:isGhost()) then
            local cat = e.def and e.def.category
            if overlap(b, e:getOuterBounds()) then
                if cat == 'Enemigos' and e.dieFling and not Entity.SPECIAL_DEATH[e.state] then
                    e:dieFling(dir)
                    Sound.play('crabPop')
                    self.vx = -self.vx * THROWN_BOUNCE
                    return
                elseif e.breakApart and e.state == 'rest' then
                    e:breakApart()
                    self.vx = -self.vx * THROWN_BOUNCE
                    return
                end
            end
        end
    end
end

-- ── Update ────────────────────────────────────────────────────────────────────
local function fallBurst(self, level)
    if self:onDeadlyGround(level) or self:fellOut(level) or self:inVoid(level) then self:dieBurst(); return true end
    return false
end

function Beetle:updateCustom(dt, level)
    local st = self.state
    if self.cd > 0 then self.cd = math.max(0, self.cd - dt) end

    if st == 'walk' or st == 'idle' then
        if self.onGround and self.cd <= 0 and self.props.movement ~= 'static' then
            local pa = self:sees(level)
            if pa then
                self.state, self.deadTimer, self.vx = 'windup', 0, 0
                Sound.play('hopWind', 0.8, 1.3)
                Entity.emitFx('gp_land', self.x - (self.facing or 1) * self.outerW / 2, self.y + self.outerH / 2)
                return true
            end
        end
        if self:fellOut(level) or self:inVoid(level) then self:dieBurst(); return true end
        return false                                                   -- (andar: lo normal de Entity)
    end

    self.deadTimer = self.deadTimer + dt
    local t = self.deadTimer

    if st == 'windup' then
        self.vx = 0
        self:fall(level, dt)
        if t >= WIND_T then
            self.state, self.deadTimer = 'charge', 0
            self.vx = (self.facing or 1) * CHARGE_V
            Sound.play('crabPop', 0.7, 0.6)
        end
        return true

    elseif st == 'charge' then
        local f = self.facing or 1
        if self.onGround and not self:groundAhead(level, f) then           -- (en un borde frena: no se tira)
            self.state, self.deadTimer, self.vx, self.cd = 'daze', DAZE_T * 0.5, 0, COOLDOWN
            return true
        end
        local x0 = self.x
        self.vx = f * CHARGE_V
        self.vy = self.vy + ADV_GRAVITY * dt
        self:moveAndCollide(level, self.vx * dt, self.vy * dt)
        self.facing = f
        if math.abs(self.x - x0) < CHARGE_V * dt * 0.5 then                -- (contra una pared: aturdido)
            self.state, self.deadTimer, self.vx, self.cd = 'daze', 0, 0, COOLDOWN
            Sound.play('blockBreak', 0.6, 0.8)
            Entity.emitFx('shake_small', self.x, self.y)
            return true
        end
        if t >= CHARGE_MAX then self.vx = f * (self.speed or 50); self.cd = COOLDOWN; self:startWalk() end
        return fallBurst(self, level) or true

    elseif st == 'daze' then
        self.vx = 0
        self:fall(level, dt)
        if t >= DAZE_T then
            self.facing = -(self.facing or 1)
            self.vx = self.facing * (self.speed or 50)
            self:startWalk()
        end
        return fallBurst(self, level) or true

    elseif st == 'onback' or st == 'righting' then
        if self.onGround then self.vx = self.vx * math.max(0, 1 - 8 * dt) end
        local vx0 = self.vx
        self.vy = self.vy + ADV_GRAVITY * dt
        local f = self.facing
        self:moveAndCollide(level, self.vx * dt, self.vy * dt)
        self.facing = f
        if self.vx ~= vx0 then self.vx = 0 end
        if fallBurst(self, level) then return true end
        if st == 'onback' and t >= BACK_T and self.onGround then
            self.state, self.deadTimer = 'righting', 0
        elseif st == 'righting' and t >= RIGHT_T then
            self.vy, self.onGround = -FLIP_HOP * 0.6, false
            self.vx = self.facing * (self.speed or 50)
            self.cd = COOLDOWN
            self:startWalk()
        end
        return true

    elseif st == 'thrown' then
        local vx0 = self.vx
        self.vy = self.vy + ADV_GRAVITY * dt
        local f = self.facing
        self:moveAndCollide(level, self.vx * dt, self.vy * dt)
        self.facing = f
        if self.vx ~= vx0 then self.vx = -vx0 * THROWN_BOUNCE end
        if fallBurst(self, level) then return true end
        self:thrownHits(level)
        if self.onGround and t > 0.08 then
            self.state, self.deadTimer = 'onback', 0
            Sound.play('boxLand')
        end
        return true
    end
    return false
end

-- ── Red: todo sale de state / deadTimer / frame / facing (nada propio) ───────

-- ── Dibujo ────────────────────────────────────────────────────────────────────
function Beetle:pose()
    local st, t = self.state, self.deadTimer or 0
    local set = self:anims()
    if st == 'walk' then return set:frameN('walk', self.frame or 1), 0, 0 end
    if st == 'windup' then
        local ox = (math.floor(t * 30) % 2 == 0) and 1 or -1                -- (escarba: tiembla)
        return set:frameAt('charge', 0), ox, 0
    end
    if st == 'charge' then return set:frameAt('charge', t), 0, 0 end
    if st == 'daze' then return set:frameAt('idle', 0), (math.floor(t * 16) % 2 == 0) and 1 or 0, 0 end
    if st == 'onback' or st == 'carried' or st == 'thrown' then return set:frameAt('flip', t), 0, 0 end
    if st == 'righting' then return set:frameAt('flip', t * 3), 0, -math.floor(math.sin(t / RIGHT_T * math.pi) * 2) end
    if st == 'dead' then return set:frameAt('dead', t), 0, 0 end
    if st == 'dead_fling' then return set:frameAt('flip', t * 2), 0, 0 end
    return set:frameAt('idle', 0), 0, 0
end

function Beetle:render(camX, camY)
    local fr, ox, oy = self:pose()
    local f = self.facing or 1
    local x = math.floor(self.x - camX) + ox * S
    -- (cada cuadro con su último píxel en el suelo — Anim footGap —; lanzado o en las manos, tal cual)
    local air = self.state == 'thrown' or self.state == 'carried' or self.state == 'dead_fling' or not self.onGround
    -- (+1: las patas de delante son 1 px más largas: las de detrás tocan el suelo, las de delante lo atraviesan 1 px)
    local gap = air and 1 or (self:anims():footGap(fr) + 1)
    local feet = math.floor(self.y + self.outerH / 2 - camY) + gap * S + oy * S
    local bx, by = 1, 1
    if self.state == 'idle' then bx, by = self:breatheScale() end
    local a = 1
    if self.state == 'dead' then a = math.max(0, 1 - (self.deadTimer or 0) / self.tuning.deadDuration) end
    love.graphics.setColor(1, 1, 1, a)
    local r = (self.state == 'dead_fling') and (self.deadTimer or 0) * 10 * f or 0
    self:anims():drawFrame(fr, x, feet, r, S * f * bx, S * by, 0.5, 1)
    love.graphics.setColor(1, 1, 1, 1)
end

return {
    name = 'beetle', label = 'Escarabajo Rinoceronte', category = 'Enemigos',
    description = 'De la jungla. Anda; si te ve delante, escarba y EMBISTE. Pisarlo lo pone patas arriba: inofensivo, se '
               .. 'coge y se lanza (derriba enemigos, rompe cajas). Pisado otra vez o con ground pound, muere. Revienta en '
               .. 'lava, pinchos y al vacío.',
    class = Beetle,
    defaults = { speed = 50, points = 20, onTouch = 'hurt' },
    hide = { 'movement', 'attach', 'dropOnSight', 'detectRange', 'flyMode', 'flyRange', 'bobAmp', 'stompable', 'onTouch' },
    props = {},
    editor = { sprite = 'assets/images/enemies/beetle/beetle-Sheet.png', frameW = FW },
}
