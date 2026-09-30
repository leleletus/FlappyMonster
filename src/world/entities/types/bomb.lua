-- Bomba (viva): anda como un Gummy (a los lados, con o sin ruta, o volando),
-- sin casco. NO hace daño al tocarla: se la puede atravesar. Se enciende al
-- acercarse un jugador (triggerRange) o al tocarla; pisarla o el empujón de un
-- ground pound la patean (sale despedida, también fuera de su ruta) y se
-- enciende. Encendida parpadea cada vez más deprisa, se pone roja y explota
-- (ver entities/BombCore.lua y world/Explosions.lua).
-- Sprites: assets/images/bomb/bomb-Sheet.png (4 cuadros 15x16: quieta, andar
-- 1-2, a punto de explotar) + bomb-fuse-Sheet.png (mecha encendida) +
-- explosion-Sheet.png. Sonidos bomb_* (tools/sounds/bomb.py).
local Entity       = require 'src/world/entities/Entity'
local Interactions = require 'src/world/entities/Interactions'
local Core         = require 'src/world/entities/BombCore'
local SpriteStrip  = require 'src/fx/SpriteStrip'

local Bomb = Entity.extend(Entity, {
    walkFps = 7, walkFrames = 2,
    idleEvery = { 3.0, 7.0 }, idleFor = { 1.0, 2.2 },
    debugColor = { 1, 0.3, 0.2 },
    -- (el cuerpo redondo mide 9 de los 15 píxeles del cuadro: la caja se ajusta
    -- a él, así el contacto es el que se ve y las alas salen DEL cuerpo)
    hitbox = { outerW = 0.6, outerH = 0.8, innerW = 0.44, innerH = 0.5 },
})

local sheet, fuseSheet
function Bomb.loadAssets()
    if sheet then return end
    sheet = SpriteStrip.load('assets/images/bomb/bomb-Sheet.png', Core.FW)
    fuseSheet = SpriteStrip.load('assets/images/bomb/bomb-fuse-Sheet.png', Core.FW)
    Core.loadExplosion()
end
function Bomb.sizePx() return Core.FW * GUMMY_SCALE, Core.FH * GUMMY_SCALE end

function Bomb:init() self.kicked = false end

-- ── Reglas ────────────────────────────────────────────────────────────────────
function Bomb:canBeStomped() return false end
function Bomb:canBeKnocked() return self.alive and self.state ~= 'exploding' end
function Bomb:isGhost() return self.state == 'exploding' or Entity.isGhost(self) end
function Bomb:isObstacle() return self.alive and self.state ~= 'exploding' and self.state ~= 'dead' end

-- Sin efectos (el cliente lo usa para predecir): caerle encima = rebote (la
-- patada y el encendido los hace el servidor en onBounced). De lado: nada.
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
function Bomb:updateCustom(dt, level)
    if Core.update(self, dt, level) then return true end
    if self.state == 'walk' or self.state == 'idle' then
        -- Se enciende al tocarla o con un jugador cerca
        local r = (self.props.triggerRange or 1.6) * TILE_PX
        local near = false
        if r > 0 then
            for _, pa in ipairs(level.players or {}) do
                if not pa.dying and pa.alive ~= false then
                    local dx, dy = pa.x - self.x, pa.y - self.y
                    if dx * dx + dy * dy <= r * r then near = true end
                end
            end
        end
        if near or Core.touched(self, level) then
            Core.light(self)
            return true
        end
    end
    return false                       -- (andar / volar: lo normal de Entity)
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
function Bomb:render(camX, camY)
    local frame = 1
    if self.state == 'walk' then frame = 1 + (self.frame or 1) end    -- andar: cuadros 2 y 3
    local s = GUMMY_SCALE
    local fx = self.x - camX
    local fy = self.y - camY + self.sprH / 2                           -- pies
    if self.flipped then fy = self.y - camY + self.sprH / 2 end
    Core.draw(self, sheet, fuseSheet, Core.TIPS.bomb, fx, fy, s, frame, 1, camX, camY)
end

function Bomb.drawEditorOverlay(props, cx, cy, zoom)
    Core.drawRadii(props, cx, cy, zoom, true)
end

local props = Core.props()
table.insert(props, 1, { key='triggerRange', kind='number', label='Se enciende a (casillas)', group='Explosión',
    default=1.6, min=0, max=8, step=0.1, help='Un jugador a esta distancia la enciende. 0 = solo al tocarla' })

return {
    name = 'bomb', label = 'Bomba', category = 'Enemigos',
    description = 'Anda como un Gummy (o vuela). No hace daño al tocarla: se enciende al acercarse o tocarla y '
               .. 'explota (muerte cerca, daño y empujón más lejos; rompe bloques, cambia activadores).',
    class = Bomb,
    defaults = { speed = 55, points = 0 },
    hide = { 'onTouch', 'stompable', 'points', 'dropOnSight', 'detectRange' },
    props = props,
    editor = { sprite = 'assets/images/bomb/bomb-Sheet.png', frameW = Core.FW },
}
