-- Bomba objeto: la misma bomba sin patitas. No anda: solo física (cae, rebota
-- en las paredes, frena en el suelo, la lanzan los trampolines). Se enciende
-- al tocarla (jugador o enemigo), al pisarla (sale pateada) o con otra
-- explosión, y explota igual que la bomba viva (entities/BombCore.lua).
--   * Quieta NO hace daño al tocarla.
--   * Cayendo o lanzada (en el aire y rápida): 1 de vida y aturde un momento
--     a quien golpee.
-- Para un jefe futuro: BombObject:throw(vx, vy, lit, fuse) la lanza (ya
-- encendida si lit).
-- Sprites: assets/images/enemies/bomb/bombObject-Sheet.png (+ bombObject-fuse-Sheet.png).
local Entity       = require 'src/world/entities/base/Entity'
local Interactions = require 'src/world/entities/base/Interactions'
local Core         = require 'src/world/entities/base/BombCore'
local SpriteStrip  = require 'src/fx/SpriteStrip'

local BombObject = Entity.extend(Entity, { debugColor = { 1, 0.5, 0.2 },
    hitbox = { outerW = 0.8, outerH = 0.8, innerW = 0.7, innerH = 0.7 } })

local HIT_SPEED = 260          -- px/s: más rápido que esto (en el aire) golpea

function BombObject.loadAssets() Core.set() end
function BombObject.sizePx() return Core.FW * GUMMY_SCALE, Core.FH * GUMMY_SCALE end

function BombObject:init()
    self.moving, self.flying = false, false
    self.vx, self.vy, self.kicked = 0, 0, false
    self.state = 'rest'
end

-- Lanzarla (jefe futuro): con velocidad, y encendida si `lit`
function BombObject:throw(vx, vy, lit, fuse)
    self.vx, self.vy, self.onGround = vx, vy, false
    self.kicked, self.thrown = true, true
    if lit then Core.light(self, fuse) end
end

-- ¿Golpea? Solo CAYENDO (hacia abajo y rápida) o LANZADA (throw) por el aire.
-- Una patada (pisarla) no: si no, golpeaba al mismo que la pisó
function BombObject:isFlyingHit()
    if self.onGround then return false end
    if (self.vy or 0) > HIT_SPEED then return true end
    return self.thrown == true and (math.abs(self.vx or 0) > HIT_SPEED or math.abs(self.vy or 0) > HIT_SPEED)
end

-- (De reserva — bombas de un jefe —: Entity:makeReserve, genérico; al explotar vuelven a la reserva)

-- ── Reglas ────────────────────────────────────────────────────────────────────
function BombObject:canBeStomped() return false end
function BombObject:canBeKnocked() return self.alive and self.state ~= 'exploding' end
function BombObject:isGhost() return self.state == 'exploding' or Entity.isGhost(self) end
function BombObject:isObstacle() return self.alive and self.state ~= 'exploding' end

-- Sin efectos (el cliente lo usa para predecir)
-- F1: con la mecha encendida, los tres radios de su explosión (mata / hiere / empuja)
function BombObject:debugBoxes()
    if self.state ~= 'lit' and self.state ~= 'exploding' then return nil end
    local r = Core.radii(self)
    return { { cx = self.x, cy = self.y, r = r.kill * TILE_PX }, { cx = self.x, cy = self.y, r = r.hurt * TILE_PX, kind = 'weak' },
             { cx = self.x, cy = self.y, r = r.push * TILE_PX, kind = 'area' } }
end

function BombObject:interact(pa)
    if self.state == 'exploding' then return nil end
    local pob, b = pa:getOuterBounds(), self:getOuterBounds()
    local over = pob.x < b.x + b.w and pob.x + pob.w > b.x and pob.y < b.y + b.h and pob.y + pob.h > b.y
    if not over then return nil end
    -- Caerle encima: rebote (onBounced la patea)
    if (pa.vy or 0) >= 0 and pob.y + pob.h <= self.y + 4 then
        return 'bounce', -math.abs(ADV_JUMP_VEL) * Interactions.BOUNCE
    end
    -- Cayendo o lanzada: golpea (1 de vida; onHurtPlayer aturde)
    if self:isFlyingHit() then return 'hurt' end
    return nil
end
function BombObject:onBounced(pa) Core.kick(self, (self.x >= pa.x) and 1 or -1, 0.8) end
function BombObject:onHurtPlayer(pa)
    pa:knockback((pa.x >= self.x) and 1 or -1)
    self.vx = -self.vx * 0.3                        -- (rebota en él)
    Core.light(self)
end
function BombObject:knockback(dir) Core.kick(self, dir, 1) end
function BombObject:onBlast(x, y, d, pushR) Core.onBlast(self, x, y, d, pushR) end
function BombObject:dieBurst()
    if self.state == 'exploding' then return end
    Core.light(self, 0.05)
end

-- ── Update ────────────────────────────────────────────────────────────────────
function BombObject:updateCustom(dt, level)
    if Core.update(self, dt, level) then return true end
    -- Suelta: física y, si algo la toca, se enciende
    Core.physics(self, level, dt)
    if self.onGround then self.thrown = false end
    if Core.touched(self, level) and not self:isFlyingHit() then Core.light(self) end
    return true
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
function BombObject:render(camX, camY)
    local fx = self.x - camX
    local fy = self.y - camY + self.outerH / 2          -- (la base de su caja: lo que toca el suelo)
    Core.draw(self, 'object_', fx, fy, GUMMY_SCALE, 'idle', nil, 1, camX, camY)
end

function BombObject.drawEditorOverlay(props, cx, cy, zoom)
    Core.drawRadii(props, cx, cy, zoom, false)
end

return {
    name = 'bombobject', label = 'Bomba (objeto)', category = 'Objetos',
    description = 'Bomba sin patitas: solo física. Se enciende al tocarla y explota como la bomba viva. '
               .. 'Quieta no hace daño; cayendo o lanzada, 1 de vida y aturde.',
    class = BombObject,
    hide = 'all',
    defaults = { movement = 'static' },
    props = Core.props(),
    editor = { sprite = 'assets/images/enemies/bomb/bombObject-Sheet.png', frameW = Core.FW },
}
