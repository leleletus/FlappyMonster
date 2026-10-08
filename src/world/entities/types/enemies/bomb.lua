-- Bomba (viva): anda como un Gummy (a los lados, con o sin ruta, o volando),
-- sin casco. NO hace daño al tocarla y SOLO se enciende si la pisan o la
-- patean (nunca por cercanía): tocarla andando = patada hacia donde iba el
-- jugador; pisarla = rebote + patada; el empujón de un ground pound también.
-- Pateada sale despedida (también fuera de su ruta) y se enciende. Encendida parpadea cada vez más deprisa, se pone roja y explota
-- (ver entities/BombCore.lua y world/Explosions.lua).
-- Sprites: assets/images/enemies/bomb/bomb-Sheet.png (4 cuadros 15x16: quieta, andar
-- 1-2, a punto de explotar) + bomb-fuse-Sheet.png (mecha encendida) +
-- explosion-Sheet.png. Sonidos bomb_* (tools/sounds/bomb.py).
local Entity       = require 'src/world/entities/base/Entity'
local Interactions = require 'src/world/entities/base/Interactions'
local Core         = require 'src/world/entities/base/BombCore'
local SpriteStrip  = require 'src/fx/SpriteStrip'

local Bomb = Entity.extend(Entity, {
    walkFps = 7, walkFrames = 2,
    idleEvery = { 3.0, 7.0 }, idleFor = { 1.0, 2.2 },
    debugColor = { 1, 0.3, 0.2 },
    -- (el cuerpo redondo mide 9 de los 15 píxeles del cuadro: la caja se ajusta
    -- a él, así el contacto es el que se ve y las alas salen DEL cuerpo)
    hitbox = { outerW = 0.6, outerH = 0.8, innerW = 0.44, innerH = 0.5 },
})

local KICK_CD = 0.35          -- s entre patadas (un empujón no cuenta como varias)

Bomb.animId = Core.ANIM            -- (sus animaciones: por nombre; el ciclo de andar, el de `walk`)
function Bomb.loadAssets() Core.set() end
function Bomb.sizePx() return Core.FW * GUMMY_SCALE, Core.FH * GUMMY_SCALE end

function Bomb:init() self.kicked, self.kickCd = false, 0 end

-- ── Reglas ────────────────────────────────────────────────────────────────────
function Bomb:canBeStomped() return false end
function Bomb:canBeKnocked() return self.alive and self.state ~= 'exploding' end
function Bomb:isGhost() return self.state == 'exploding' or Entity.isGhost(self) end
function Bomb:isObstacle() return self.alive and self.state ~= 'exploding' and self.state ~= 'dead' end

-- Sin efectos (el cliente lo usa para predecir): caerle encima = rebote (la
-- patada y el encendido los hace el servidor en onBounced). De lado: nada.
-- F1: con la mecha encendida, los tres radios de su explosión (mata / hiere / empuja)
function Bomb:debugBoxes()
    if self.state ~= 'lit' and self.state ~= 'exploding' then return nil end
    local r = Core.radii(self)
    return { { cx = self.x, cy = self.y, r = r.kill * TILE_PX }, { cx = self.x, cy = self.y, r = r.hurt * TILE_PX, kind = 'weak' },
             { cx = self.x, cy = self.y, r = r.push * TILE_PX, kind = 'area' } }
end

function Bomb:interact(pa)
    if self.state == 'exploding' then return nil end
    local pob, b = pa:getOuterBounds(), self:getOuterBounds()
    local over = pob.x < b.x + b.w and pob.x + pob.w > b.x and pob.y < b.y + b.h and pob.y + pob.h > b.y
    if over and (pa.vy or 0) >= 0 and pob.y + pob.h <= self.y + 4 then
        return 'bounce', -math.abs(ADV_JUMP_VEL) * Interactions.BOUNCE
    end
    return nil
end
-- Pisada: sale pateada (lejos del jugador) y se enciende
function Bomb:onBounced(pa)
    self.kickCd = KICK_CD
    Core.kick(self, (self.x >= pa.x) and 1 or -1, 0.8)
end
-- Empujón de un ground pound cercano: igual
function Bomb:knockback(dir) Core.kick(self, dir, 1) end
-- Otra explosión cerca
function Bomb:onBlast(x, y, d, pushR) Core.onBlast(self, x, y, d, pushR) end
-- Lanzada a unos pinchos: explota ahí mismo (no revienta como un enemigo)
function Bomb:dieBurst()
    if self.state == 'exploding' then return end
    Core.light(self, 0.05)
end

-- ── Update ────────────────────────────────────────────────────────────────────
-- Un jugador la toca (sin caerle encima): la patea hacia donde iba
function Bomb:touchKick(level)
    if self.kickCd > 0 or self.state == 'exploding' then return false end
    local b = self:getOuterBounds()
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false then
            local o = pa:getOuterBounds()
            if b.x < o.x + o.w and b.x + b.w > o.x and b.y < o.y + o.h and b.y + b.h > o.y
               and not ((pa.vy or 0) >= 0 and o.y + o.h <= self.y + 4) then          -- (encima = pisotón)
                local dir = (math.abs(pa.vx or 0) > 20) and ((pa.vx > 0) and 1 or -1)
                            or ((self.x >= pa.x) and 1 or -1)
                self.kickCd = KICK_CD
                Core.kick(self, dir, 0.7)
                return true
            end
        end
    end
    return false
end

function Bomb:updateCustom(dt, level)
    if self.kickCd > 0 then self.kickCd = math.max(0, self.kickCd - dt) end
    if self:touchKick(level) then return true end
    if Core.update(self, dt, level) then return true end
    return false                       -- (andar / volar: lo normal de Entity)
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
function Bomb:render(camX, camY)
    local name, k = 'idle', nil
    if self.state == 'walk' then name, k = 'walk', self.frame or 1 end
    local s = GUMMY_SCALE
    local fx = self.x - camX
    -- (pies = la base de su CAJA, que es lo que pisa el suelo: las bombas llegan hasta la última fila de su cuadro;
    -- con sprH se hundían un píxel y medio en el suelo)
    local fy = self.y - camY + self.outerH / 2
    local bx, by = 1, 1
    if self.state == 'idle' or self.state == 'walk' then bx, by = self:breatheScale() end   -- (como el Gummy)
    Core.draw(self, '', fx, fy, s, name, k, 1, camX, camY, bx, by)
end

function Bomb.drawEditorOverlay(props, cx, cy, zoom)
    Core.drawRadii(props, cx, cy, zoom, false)
end

local props = Core.props()

return {
    name = 'bomb', label = 'Bomba', category = 'Enemigos',
    description = 'Anda como un Gummy (o vuela). No hace daño al tocarla: solo se enciende si la pisan o la patean '
               .. '(tocarla la patea) y explota (muerte cerca, daño y empujón más lejos; rompe bloques, cambia activadores).',
    class = Bomb,
    defaults = { speed = 55, points = 0 },
    hide = { 'onTouch', 'stompable', 'points', 'dropOnSight', 'detectRange' },
    props = props,
    editor = { sprite = 'assets/images/enemies/bomb/bomb-Sheet.png', frameW = Core.FW },
}
