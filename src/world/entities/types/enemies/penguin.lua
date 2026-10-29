-- El PINGÜINO (types/enemies/penguin.lua): enemigo de la COSTA HELADA (aprobado por el usuario, 2026-10-29;
-- docs/entities/enemies.md § Pingüino).
--   · ANDA como un pato (el andar de siempre de Entity). Se tira DE BARRIGA ('dive' → 'slide') cuando pisa HIELO
--     (material que resbala), cuando llega a un borde con suelo más abajo (cuesta abajo: escalones) o cuando VE a un
--     jugador delante a su altura. Deslizándose va rápido, rebota en las paredes, se tira por los bordes y quita 1 de
--     vida al tocarlo; al frenarse se levanta ('getup') y sigue andando.
--   · PISARLO (andando o deslizándose) lo deja DE BARRIGA, ATURDIDO ('dazed'): inofensivo y es un TRINEO
--     (base/Sled.lua): de pie encima echa a correr ('sled') hacia donde mira, rápido, llevando al jugador, cruzando
--     huecos pequeños por el impulso y rebotando en las paredes. Saltar (bajarse) acaba el viaje; al rato se levanta
--     (y tira a quien siga encima).
--   · Un GROUND POUND lo mata (andando, deslizándose, aturdido o montado). El empujón de un ground pound cercano o de
--     una explosión lo tumba de barriga (aturdido). Lava, pinchos, el vacío: revienta.
-- Arte: assets/anim/enemies/penguin.json (cuadros 24x20 a escala 4, mira a la DERECHA; tools/art/enemies/
-- make_penguin.py, diseño B «Zancos»). Red: nada propio — todo sale de state / deadTimer / frame / facing.
local Entity       = require 'src/world/entities/base/Entity'
local Interactions = require 'src/world/entities/base/Interactions'
local Sled         = require 'src/world/entities/base/Sled'
local BossFx

local S        = GUMMY_SCALE
local FW, FH   = 24, 20
local Penguin = Entity.extend(Entity, {
    walkFps = 8, walkFrames = 4,
    idleEvery = { 3.0, 6.0 }, idleFor = { 0.8, 1.6 },
    debugColor = { 0.3, 0.35, 0.7 },
    -- de pie: el cuerpo fino (10 de los 24 px de ancho) y la altura entera menos un poco (cabe por un túnel de 1)
    hitbox = { outerW = 0.42, outerH = 0.78, innerW = 0.32, innerH = 0.6 },
})

local SEE       = 6                    -- casillas: ve a un jugador delante hasta aquí (× sense)
local DIVE_T    = 0.3                  -- s inclinándose antes de tirarse
local DIVE_HOP  = 160                  -- px/s: el saltito al tirarse
local SLIDE_V   = 320                  -- px/s deslizándose (el jugador corre a 240)
local SLIDE_KEEP = 0.9                 -- s sin frenar al principio
local SLIDE_FRIC = 1.6                 -- rozamiento por segundo después (× el del material: en el hielo casi nada)
local SLIDE_MAX = 4.0                  -- s como mucho deslizándose
local GETUP_T   = 0.35                 -- s levantándose
local COOLDOWN  = 1.5                  -- s andando antes de volver a tirarse
local DAZE_T    = 3.5                  -- s aturdido (sin jinete) antes de levantarse
local DAZE_HOP  = 220                  -- px/s: el saltito al quedar tumbado
local DAZE_FRIC = 2.5                  -- frena así tumbado (× el material)
local RIDE_T    = 4.0                  -- s como mucho montado
local RIDE_GRACE = 0.12                -- s sin nadie encima: se acabó el viaje
local AFTER_RIDE = 1.0                 -- s tumbado tras el viaje antes de levantarse
local DOWN_MAX  = 2                    -- casillas: un borde con suelo hasta aquí abajo es "cuesta abajo"
local ICE_F     = 0.5                  -- material con friction por debajo de esto = hielo: se tira
-- De barriga: la caja es baja y larga (el dibujo tumbado mide ~15 x 9 px)
local BELLY_W, BELLY_H = 15 * S, 9 * S
local BELLY_IW, BELLY_IH = 13 * S, 9 * S
local RIDE_TOP  = 8.5 * S              -- px sobre los pies: la cara de arriba del trineo (la espalda en el dibujo)

local BELLY    = { slide = true, dazed = true, sled = true, dead = true }
local HARMLESS = { dazed = true, sled = true }
local FREE     = { dive = true, slide = true, dazed = true, sled = true, getup = true }

Penguin.animId     = 'enemies/penguin'
Penguin.ownStunLook = true
Sled.mixin(Penguin, { states = HARMLESS, top = RIDE_TOP, w = BELLY_W })
function Penguin.sizePx() return FW * S, FH * S end

function Penguin:init()
    self.cd = 0
    self.standW = self.outerW
    self.props.stompable, self.props.onTouch = true, 'hurt'     -- (reglas fijas: ocultas en el editor)
end

-- ── Cajas: de pie o de barriga (sale del estado: igual en el cliente) ─────────
function Penguin:belly() return BELLY[self.state] == true end
function Penguin:getOuterBounds(into)
    if not self:belly() then return Entity.getOuterBounds(self, into) end
    local feet = self.y + self.outerH / 2
    return Entity.box(into, self.x - BELLY_W / 2, feet - BELLY_H, BELLY_W, BELLY_H)
end
function Penguin:getInnerBounds(into)
    if not self:belly() then return Entity.getInnerBounds(self, into) end
    local feet = self.y + self.outerH / 2
    return Entity.box(into, self.x - BELLY_IW / 2, feet - BELLY_IH, BELLY_IW, BELLY_IH)
end
-- (la caja con la que se MUEVE: más ancha tumbado; la altura no cambia — los pies son y + outerH/2 —). En cualquier
-- estado, también si lo cambió la base (lanzado por un trampolín, congelado, reaparecer)
function Penguin:stepAlways()
    self.outerW = self:belly() and BELLY_W or (self.standW or self.outerW)
end
function Penguin:freeOfRoute() return FREE[self.state] == true end

-- ── Reglas con el jugador (sin efectos: el cliente las usa para predecir) ─────
-- Tumbado (aturdido o montado): solo cuenta el ground pound (lo mata); pisarlo es subirse (la pieza del trineo).
-- Levantándose: inofensivo (pisarlo lo vuelve a tumbar). Si no: pisotón = tumbado, ground pound = muerto, tocarlo = 1
function Penguin:interact(pa)
    local r, a, b, c = Interactions.defaultCheck(pa, self)
    if r == 'stomp' and pa.gpPhase == 'fall' then return 'pound', a, b end
    if HARMLESS[self.state] then return nil end
    if self.state == 'getup' and (r == 'hurt' or r == 'kill') then return nil end
    return r, a, b, c
end

function Penguin:stomp()
    local st = self.state
    if st == 'dead' then return end
    if self.pounded or st == 'frozen' or HARMLESS[st] then           -- (el impacto de un ground pound: muere)
        self.pounded = nil
        return Entity.stomp(self)
    end
    self:daze(self.vx * 0.4)
end
function Penguin:pound(pa) self.pounded = nil; Entity.stomp(self) end

-- El impacto de un ground pound justo encima (Interactions.run): de pie, el pisotón que sigue lo MATA (no lo tumba)
local function overlap(a, b) return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y end
-- (tumbado: también quien cae en picado DE PIE en el trineo)
function Penguin:onPound(pa, z)
    if self.alive and (overlap(z, self:getInnerBounds()) or (self.sledPart and pa.standBody == self.sledPart)) then
        self.pounded = true
    end
    return false
end

-- El empujón de un ground pound cercano o de una explosión: lo tumba de barriga hacia ese lado
function Penguin:canBeKnocked() return self.alive and self.state ~= 'dead' and Entity.canBeKnocked(self) end
function Penguin:knockback(dirX)
    if HARMLESS[self.state] then self.vx = dirX * 220; return end
    self:daze(dirX * 220)
end

function Penguin:daze(vx)
    if not HARMLESS[self.state] then Sound.play('stunned') end
    self.state, self.deadTimer = 'dazed', 0
    self.vx, self.vy, self.onGround = vx or 0, -DAZE_HOP, false
    self.rideGone = 0
    self:stepAlways()
end

-- ── Cuándo se tira de barriga ─────────────────────────────────────────────────
-- ¿Cuesta abajo? Un borde delante con suelo un poco más abajo (1..DOWN_MAX casillas)
function Penguin:downhill(level)
    local f, T = self.facing or 1, TILE_PX
    if self:groundAhead(level, f) then return false end
    local x, feet = self.x + f * (self.outerW / 2 + T / 2), self.y + self.outerH / 2
    for y = feet + 8, feet + DOWN_MAX * T, 8 do
        if level:isEnemySolidAt(x, y) then return true end
    end
    return false
end

function Penguin:startDive(squawk)
    self.state, self.deadTimer, self.vx = 'dive', 0, 0
    if squawk then Sound.play('penguinSquawk') end
end

function Penguin:getUp(level)
    Sled.buck(self, level)
    self.state, self.deadTimer, self.vx = 'getup', 0, 0
    self:stepAlways()
end

-- ── Update ────────────────────────────────────────────────────────────────────
function Penguin:updateCustom(dt, level)
    local st = self.state
    if self.cd > 0 then self.cd = math.max(0, self.cd - dt) end

    if st == 'walk' or st == 'idle' then
        if self:burstIfDoomed(level) then return true end
        if self.onGround and self.cd <= 0 and self.props.movement ~= 'static' then
            local m = self:groundMat(level)
            if m and (m.friction or 1) < ICE_F then self:startDive(false); return true end
            if st == 'walk' and self.moving and self:downhill(level) then self:startDive(false); return true end
            if self:seesAhead(level, self.props.range or SEE) then self:startDive(true); return true end
        end
        return false                                                -- (andar: lo normal de Entity)
    end

    self.deadTimer = self.deadTimer + dt
    local t = self.deadTimer

    if st == 'dive' then
        self:fall(level, dt)
        if t >= DIVE_T then
            self.state, self.deadTimer = 'slide', 0
            self.vx, self.vy, self.onGround = (self.facing or 1) * SLIDE_V, -DIVE_HOP, false
            self:stepAlways()
            Sound.play('penguinSlide')
        end
        return true

    elseif st == 'slide' then
        Sled.move(self, level, dt, t < SLIDE_KEEP and 0 or SLIDE_FRIC)
        if self:burstIfDoomed(level) then return true end
        if (self.onGround and self.vx == 0) or t >= SLIDE_MAX then self:getUp(level) end
        return true

    elseif st == 'dazed' then
        Sled.move(self, level, dt, DAZE_FRIC)
        if self:burstIfDoomed(level) then return true end
        if Sled.rider(self, level) and self.onGround then             -- (alguien se sube: ¡arre!)
            self.state, self.deadTimer, self.rideGone = 'sled', 0, 0
            self.vx = (self.facing or 1) * Sled.V
            Sound.play('penguinSlide', 1.1)
            return true
        end
        if t >= DAZE_T and self.onGround then self:getUp(level) end
        return true

    elseif st == 'sled' then
        if self.onGround then self.vx = (self.facing or 1) * Sled.V end
        Sled.move(self, level, dt, 0)
        if self:burstIfDoomed(level) then return true end
        if Sled.rider(self, level) then self.rideGone = 0 else self.rideGone = (self.rideGone or 0) + dt end
        if self.rideGone >= RIDE_GRACE then                            -- (se bajó: frena y al rato se levanta)
            self.state, self.deadTimer = 'dazed', math.max(0, DAZE_T - AFTER_RIDE)
        elseif t >= RIDE_T and self.onGround then
            self:getUp(level)
        end
        return true

    elseif st == 'getup' then
        self.vx = 0
        self:fall(level, dt)
        if t >= GETUP_T then
            self.cd = COOLDOWN
            self.vx = (self.facing or 1) * (self.speed or 45)
            self:startWalk()
        end
        return true
    end
    return false
end

-- ── Dibujo (de state / deadTimer / frame / facing: igual online) ──────────────
function Penguin:pose()
    local st, t, set = self.state, self.deadTimer or 0, self:anims()
    if st == 'walk' then return set:frameN('walk', self.frame or 1) end
    if st == 'dive' then return set:frameAt('dive', t) end
    if st == 'slide' then return set:frameAt('slide', t) end
    if st == 'dazed' then return set:frameAt('dazed', t) end
    if st == 'sled' then return set:frameAt('ridden', t) end
    if st == 'getup' then return set:frameAt('getup', t) end
    if st == 'dead' or st == 'dead_fling' then return set:frameAt('dead', t) end
    if st == 'stunned' then return set:frameAt('dazed', t) end
    return set:frameAt('idle', st == 'idle' and (self.breatheT or t) or 0)
end

function Penguin:render(camX, camY)
    local st = self.state
    if st == 'reserve' or st == 'dead_burst' or st == 'gone' then return end
    local fr, f = self:pose(), self.facing or 1
    local x = math.floor(self.x - camX)
    local feet = math.floor(self.y + self.outerH / 2 - camY)
    local a = 1
    if st == 'dead' then a = math.max(0, 1 - (self.deadTimer or 0) / self.tuning.deadDuration) end
    local dazed = st == 'dazed'
    BossFx = BossFx or require 'src/fx/BossFx'
    local hx, hy = x + f * 5 * S, feet - 13 * S
    if dazed then BossFx.stars(hx, hy, 4 * S, 1.5 * S, 2, 1, 'back') end
    love.graphics.setColor(1, 1, 1, a)
    local r = (st == 'dead_fling') and (self.deadTimer or 0) * 10 * f or 0
    self:anims():drawFrame(fr, x, feet, r, S * f, S, 0.5, 1)
    love.graphics.setColor(1, 1, 1, 1)
    if dazed then BossFx.stars(hx, hy, 4 * S, 1.5 * S, 2, 1, 'front') end
end

-- (F1) la cara de arriba del trineo, cuando lo es
function Penguin:debugBoxes()
    if not HARMLESS[self.state] then return nil end
    local b = Sled.part(self):getOuterBounds()
    return { { x = b.x, y = b.y, w = b.w, h = 4, kind = 'area' } }
end

local G = 'Pingüino'
return {
    name = 'penguin', label = 'Pingüino', category = 'Enemigos', class = Penguin,
    description = 'De la Costa Helada. Anda como un pato; en el HIELO, cuesta abajo o si te ve delante se tira DE '
               .. 'BARRIGA y se desliza rápido (rebota en las paredes, se tira por los bordes): tocarlo quita 1. PISADO se '
               .. 'queda aturdido de barriga y es un TRINEO: súbete y te lleva deslizando (cruza huecos pequeños); saltar '
               .. 'te baja; al rato se levanta. Ground pound: muere. Revienta en lava, pinchos y al vacío.',
    defaults = { speed = 45, points = 20, onTouch = 'hurt' },
    hide = { 'movement', 'attach', 'dropOnSight', 'detectRange', 'flyMode', 'flyRange', 'bobAmp', 'stompable', 'onTouch' },
    props = {
        { key = 'range', kind = 'int', label = 'Te ve a (casillas)', group = G, default = SEE, min = 1, max = 30,
          help = 'Delante y a su altura: a esa distancia se tira de barriga hacia ti (además del hielo y las cuestas abajo)' },
    },
    editor = { sprite = 'assets/images/enemies/penguin/penguin-Sheet.png', frameW = FW },
}
