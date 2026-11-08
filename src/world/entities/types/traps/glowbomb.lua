-- BOMBA LUMINOSA (solo niveles Flappy: la suelta el Redcóptero, docs/design/flappy-plan-5-netcopter.md): cae despacio
-- con la mecha encendida. Estados:
--   'falling'    cae `fall` px/s; explota si toca un jugador (de lado, por encima, quieto), un tile sólido o se le acaba la
--                mecha (`fuse` s): la explosión (Explosions.blast, 1 casilla) quita 1 de vida al que esté cerca
--   'returning'  DEVUELTA AL REMITENTE (rasgo `reflectable`: un jugador que vuela SUBIENDO la toca — Interactions): sale
--                hacia donde estaba el centro de su `owner` al devolverla, en línea recta a 700 px/s. Si le da, el jefe
--                pierde 2 (`owner:damage(2, 'reflect')`); un tile sólido o salir del nivel la revienta sin dañar a nadie
--   'exploding'  fogonazo breve y desaparece. Una bomba devuelta NO hace daño a ningún jugador al explotar
-- Arte: assets/images/bosses/netcopter/bomb-Sheet.png (2 cuadros 14x18: la mecha; tools/art/bosses/make_netcopter.py).
local Entity     = require 'src/world/entities/base/Entity'
local Explosions = require 'src/world/systems/Explosions'

local GlowBomb = Entity.extend(Entity, { debugColor = { 1, 0.7, 0.2 },
    hitbox = { outerW = 0.8, outerH = 0.7, innerW = 0.6, innerH = 0.5 } })

GlowBomb.reflectable = true
local SCALE = 6
local FW, FH = 14, 18
local RETURN_SPD = 700         -- px/s de la bomba devuelta
local BLAST_T = 0.45           -- s que dura el fogonazo
local BLAST_R = 1              -- casillas del radio de la explosión
local img, quads
function GlowBomb.loadAssets()
    if img then return end
    img = love.graphics.newImage('assets/images/bosses/netcopter/bomb-Sheet.png')
    img:setFilter('nearest', 'nearest')
    quads = {}
    for i = 1, 2 do quads[i] = love.graphics.newQuad((i - 1) * FW, 0, FW, FH, img:getDimensions()) end
end
function GlowBomb.sizePx() return FW * SCALE, FH * SCALE end

function GlowBomb:init()
    self.moving, self.flying = false, true
    self.vx, self.vy = 0, 0
    self.state = 'falling'
    self.fuseT = 0
    self.owner = nil               -- el jefe que la soltó (lo pone él al crearla)
end

function GlowBomb:canBeStomped() return false end
function GlowBomb:canBeKnocked() return false end
function GlowBomb:isGhost() return self.state == 'exploding' or Entity.isGhost(self) end
-- Sin efectos de contacto propios: explotar al tocarla lo hace updateCustom y devolverla, Interactions ('reflect')
function GlowBomb:interact(pa) return nil end

-- Una bomba que cae solo se devuelve estando entera
function GlowBomb:canReflect() return self.alive and self.state == 'falling' end

-- La devuelve un jugador que vuela subiendo (Interactions.run): apunta al centro actual del dueño y sale en línea recta
-- (si el jefe se mueve después, falla: se esquiva)
function GlowBomb:onReflect(pa)
    if not self:canReflect() then return end
    local o = self.owner
    local tx, ty = self.x, self.y + 1
    if o then tx, ty = o.x, o.y end
    local dx, dy = tx - self.x, ty - self.y
    local d = math.sqrt(dx * dx + dy * dy)
    if d < 1 then dx, dy, d = 0, 1, 1 end
    self.vx, self.vy = dx / d * RETURN_SPD, dy / d * RETURN_SPD
    self.state, self.reflectedBy = 'returning', pa
    Sound.play('headBump')
    Entity.emitFx('collect', self.x, self.y)
end

function GlowBomb:explode(level, harmless)
    if self.state == 'exploding' then return end
    self.state, self.deadTimer, self.vx, self.vy = 'exploding', 0, 0, 0
    Sound.play('bombBlast')
    Entity.emitFx('bomb_blast', self.x, self.y)
    -- (devuelta: no daña a nadie; si no, 1 de vida a quien esté a una casilla — sin matar de golpe ni romper bloques)
    if not harmless then
        Explosions.blast(level, self.x, self.y, { kill = -1, hurt = BLAST_R, push = BLAST_R }, self)
    end
end

local function solidAt(level, x, y)
    return level:isEnemySolidAt(x, y) or y >= level.heightPx
end
local function overlap(a, b)
    return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y
end

function GlowBomb:updateCustom(dt, level)
    local st = self.state
    if st == 'exploding' then
        self.deadTimer = self.deadTimer + dt
        if self.deadTimer >= BLAST_T then self.alive = false end
        return true
    end
    if not level then return true end
    if st == 'falling' then
        self.fuseT = self.fuseT + dt
        self.vy = self.props.fall or 90
        self.y = self.y + self.vy * dt
        local hit = self.fuseT >= (self.props.fuse or 2.5) or solidAt(level, self.x, self.y + self.outerH / 2)
        if not hit then
            local b = self:getOuterBounds()
            for _, pa in ipairs(level.players or {}) do
                -- (subiendo y volando: es la devolución, no el choque; lo decide Interactions.run con este mismo criterio)
                if not pa.dying and pa.alive ~= false and not (pa.flight and (pa.vy or 0) < 0)
                   and overlap(b, pa:getOuterBounds()) then
                    hit = true
                    break
                end
            end
        end
        if hit then self:explode(level) end
    elseif st == 'returning' then
        self.x, self.y = self.x + self.vx * dt, self.y + self.vy * dt
        local o = self.owner
        if o and o.alive and overlap(self:getOuterBounds(), o:getOuterBounds()) then
            o:damage(2, 'reflect')
            self:explode(level, true)
        elseif solidAt(level, self.x, self.y) or self.x < 0 or self.x > level.widthPx or self.y < -TILE_PX * 2 then
            self:explode(level, true)
        end
    end
    return true
end

-- Red: el estado y el rumbo viajan; el cliente solo dibuja
function GlowBomb:netPack() return { self.state == 'returning' and 1 or (self.state == 'exploding' and 2 or 0) } end
function GlowBomb:netApply(a)
    self.state = (a == 1) and 'returning' or ((a == 2) and 'exploding' or 'falling')
end

function GlowBomb:render(camX, camY)
    local x, y = math.floor(self.x - camX), math.floor(self.y - camY)
    love.graphics.setColor(1, 1, 1, 1)
    if self.state == 'exploding' then
        local k = math.min(1, (self.deadTimer or 0) / BLAST_T)
        local r = TILE_PX * BLAST_R * (0.4 + 0.6 * k)
        love.graphics.setColor(1, 0.85, 0.35, 1 - k)
        love.graphics.rectangle('fill', x - r, y - r, r * 2, r * 2)
        love.graphics.setColor(1, 1, 1, 1)
        return
    end
    local f = (math.floor((self.fuseT or 0) * 8) % 2) + 1
    love.graphics.draw(img, quads[f], x, y, 0, SCALE, SCALE, FW / 2, FH / 2)
end

return {
    name = 'glowbomb', label = 'Bomba luminosa', category = 'Flappy', flappyOnly = true,
    description = 'Solo niveles Flappy: la suelta el Redcóptero. Cae y explota; subiendo contra ella se devuelve al jefe.',
    class = GlowBomb,
    defaults = { movement = 'static' }, hide = 'all',
    props = {
        { key = 'fuse', kind = 'number', label = 'Mecha (s)', group = 'Bomba', default = 2.5, min = 0.5, max = 8, step = 0.5,
          help = 'Segundos hasta explotar si nadie la toca' },
        { key = 'fall', kind = 'number', label = 'Caída (px/s)', group = 'Bomba', default = 90, min = 20, max = 400, step = 10,
          help = 'Velocidad a la que cae' },
    },
    editor = { draw = function(x, y, s)
        GlowBomb.loadAssets()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, quads[1], x, y, 0, s / FH, s / FH)
    end },
}
