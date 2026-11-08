-- BOMBA LUMINOSA (solo niveles Flappy: la LANZA el Redcóptero, docs/design/flappy-plan-5-netcopter.md y
-- flappy-plan-5c-netcopter-polish.md): sale de la góndola EN ARCO (balística, gravedad `g`) hacia donde estaba el
-- jugador al lanzarla (`tx`, `ty`: la MARCA que parpadea allí desde el lanzamiento; lob). Sin lanzar, cae a plomo con
-- esa gravedad. Estados:
--   'falling'    en el aire (subiendo o bajando); explota si toca un jugador que no sube (de lado, por encima, quieto),
--                un tile sólido (los pilares también: por delante, por abajo o por arriba) o el suelo; la mecha (`fuse`
--                s) solo es un respaldo. La explosión (Explosions.blast, 1 casilla) quita 1 de vida al que esté cerca
--   'returning'  DEVUELTA AL REMITENTE (rasgo `reflectable`: un jugador que vuela SUBIENDO la toca — Interactions): sale
--                hacia el `aimPoint` de su `owner` al devolverla (el Redcóptero: la góndola), en línea recta a 700 px/s.
--                Si le da (en toda su caja), el jefe pierde 2 (`owner:damage(2, 'reflect')`); un tile sólido o salir
--                del nivel la revienta sin dañar a nadie
--   'exploding'  fogonazo breve y desaparece. Una bomba devuelta NO hace daño a ningún jugador al explotar
-- Arte: assets/images/bosses/netcopter/bomb-Sheet.png (2 cuadros 14x18: la mecha) y mark-Sheet.png (la marca, 2 cuadros
-- 12x12: cuatro esquinas de mira que laten); tools/art/bosses/make_netcopter.py. Lo que se dibuja sale de x, y, state,
-- deadTimer (corre en el aire y de vuelta: la mecha nunca se congela) y la marca.
local Entity     = require 'src/world/entities/base/Entity'
local Boss       = require 'src/world/entities/base/Boss'
local Explosions = require 'src/world/systems/Explosions'

local GlowBomb = Entity.extend(Entity, { debugColor = { 1, 0.7, 0.2 },
    hitbox = { outerW = 0.8, outerH = 0.7, innerW = 0.6, innerH = 0.5 } })

GlowBomb.reflectable = true
local SCALE = 6
local FW, FH = 14, 18
local RETURN_SPD = 700         -- px/s de la bomba devuelta
local BLAST_T = 0.45           -- s que dura el fogonazo
local BLAST_R = 1              -- casillas del radio de la explosión
local G = 900                  -- px/s² de la gravedad si nadie le da otra (lob)
local MIN_FLIGHT = 0.35        -- s de vuelo como mínimo (un objetivo casi encima)
local MW = 12                  -- la marca: 12x12
local img, quads, markImg, markQuads
function GlowBomb.loadAssets()
    if img then return end
    img = love.graphics.newImage('assets/images/bosses/netcopter/bomb-Sheet.png')
    img:setFilter('nearest', 'nearest')
    quads = {}
    for i = 1, 2 do quads[i] = love.graphics.newQuad((i - 1) * FW, 0, FW, FH, img:getDimensions()) end
    markImg = love.graphics.newImage('assets/images/bosses/netcopter/mark-Sheet.png')
    markImg:setFilter('nearest', 'nearest')
    markQuads = {}
    for i = 1, 2 do markQuads[i] = love.graphics.newQuad((i - 1) * MW, 0, MW, MW, markImg:getDimensions()) end
end
function GlowBomb.sizePx() return FW * SCALE, FH * SCALE end

function GlowBomb:init()
    self.moving, self.flying = false, true
    self.vx, self.vy = 0, 0
    self.state = 'falling'
    self.fuseT = 0
    self.g = G
    self.tx, self.ty = nil, nil    -- la marca: adónde va (nil = sin lanzar)
    self.owner = nil               -- el jefe que la lanzó (lo pone él al crearla)
end

-- La lanza (ya en su sitio con appearAt) en arco hasta (tx, ty) pasando por la altura `apexY` (si queda por debajo de
-- la salida o del objetivo, sale plana): el tiempo de vuelo sale de la geometría, con gravedad `g`
function GlowBomb:lob(tx, ty, apexY, g)
    g = g or G
    local apex = math.min(apexY or self.y, self.y, ty)
    local tf = math.sqrt(2 * (self.y - apex) / g) + math.sqrt(2 * (ty - apex) / g)
    tf = math.max(tf, MIN_FLIGHT)
    self.g, self.tx, self.ty = g, tx, ty
    self.vx = (tx - self.x) / tf
    self.vy = (ty - self.y) / tf - g * tf / 2
end

function GlowBomb:canBeStomped() return false end
function GlowBomb:canBeKnocked() return false end
function GlowBomb:isGhost() return self.state == 'exploding' or Entity.isGhost(self) end
-- Sin efectos de contacto propios: explotar al tocarla lo hace updateCustom y devolverla, Interactions ('reflect')
function GlowBomb:interact(pa) return nil end

-- Una bomba en el aire solo se devuelve estando entera
function GlowBomb:canReflect() return self.alive and self.state == 'falling' end

-- La devuelve un jugador que vuela subiendo (Interactions.run): apunta a donde está AHORA el dueño (su aimPoint: el
-- Redcóptero, la góndola) y sale en línea recta (si el jefe se mueve después, falla: se esquiva)
function GlowBomb:onReflect(pa)
    if not self:canReflect() then return end
    local o = self.owner
    local tx, ty = self.x, self.y + 1
    if o then tx, ty = o:aimPoint() end
    local dx, dy = tx - self.x, ty - self.y
    local d = math.sqrt(dx * dx + dy * dy)
    if d < 1 then dx, dy, d = 0, 1, 1 end
    self.vx, self.vy = dx / d * RETURN_SPD, dy / d * RETURN_SPD
    self.state, self.reflectedBy, self.tx, self.ty = 'returning', pa, nil, nil
    Sound.play('headBump')
    Entity.emitFx('collect', self.x, self.y)
    Entity.emitFx('sparks', self.x, self.y)               -- (chispas al devolverla)
end

-- Gastada sin explotar (el jefe cae): vuelve a su reserva sin hacer daño
function GlowBomb:spend()
    self.state, self.alive = 'spent', false
end

function GlowBomb:explode(level, harmless)
    if self.state == 'exploding' then return end
    self.state, self.deadTimer, self.vx, self.vy, self.tx, self.ty = 'exploding', 0, 0, 0, nil, nil
    Sound.play('bombBlast')
    Entity.emitFx('bomb_blast', self.x, self.y)
    -- (devuelta: no daña a nadie; si no, 1 de vida a quien esté a una casilla — sin matar de golpe; Explosions.blast rompe los bloques rompibles a 1 casilla)
    if not harmless then
        Explosions.blast(level, self.x, self.y, { kill = -1, hurt = BLAST_R, push = BLAST_R }, self)
    end
end

local function solidAt(level, x, y)
    return level:isEnemySolidAt(x, y) or y >= level.heightPx
end
local overlap = Boss.overlap

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
        self.deadTimer = self.deadTimer + dt
        self.vy = self.vy + (self.g or G) * dt
        self.x, self.y = self.x + self.vx * dt, self.y + self.vy * dt
        local hw, hh = self.outerW / 2, self.outerH / 2
        local hit = self.fuseT >= (self.props.fuse or 4) or solidAt(level, self.x, self.y + hh)
            or (self.vy < 0 and self.y - hh > 0 and solidAt(level, self.x, self.y - hh))   -- (por encima del nivel: cielo)
            or (self.vx ~= 0 and solidAt(level, self.x + (self.vx > 0 and hw or -hw), self.y))
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
        self.deadTimer = self.deadTimer + dt                -- (la mecha sigue chisporroteando de vuelta)
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

-- Red: el estado y la marca (adónde va) viajan; el cliente solo dibuja
function GlowBomb:netPack()
    return { self.state == 'returning' and 1 or (self.state == 'exploding' and 2 or 0),
             self.tx and math.floor(self.tx) or 0, self.ty and math.floor(self.ty) or 0 }
end
function GlowBomb:netApply(a, b, f)
    b = b or a
    if type(b) ~= 'table' or type(b[1]) ~= 'number' then return end
    self.state = (b[1] == 1) and 'returning' or ((b[1] == 2) and 'exploding' or 'falling')
    local lobbed = b[1] == 0 and ((b[2] or 0) ~= 0 or (b[3] or 0) ~= 0)
    self.tx, self.ty = lobbed and b[2] or nil, lobbed and b[3] or nil
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
    -- la marca: donde caerá (parpadea desde el lanzamiento)
    local blink = math.floor((self.deadTimer or 0) * 8) % 2 + 1
    if self.state == 'falling' and self.tx then
        love.graphics.draw(markImg, markQuads[blink], math.floor(self.tx - camX), math.floor(self.ty - camY), 0,
            SCALE, SCALE, MW / 2, MW / 2)
    end
    love.graphics.draw(img, quads[blink], x, y, 0, SCALE, SCALE, FW / 2, FH / 2)
end

return {
    name = 'glowbomb', label = 'Bomba luminosa', category = 'Flappy', flappyOnly = true,
    description = 'Solo niveles Flappy: la lanza el Redcóptero en arco. Explota al caer; subiendo contra ella se devuelve al jefe.',
    class = GlowBomb,
    defaults = { movement = 'static' }, hide = 'all',
    props = {
        { key = 'fuse', kind = 'number', label = 'Mecha (s)', group = 'Bomba', default = 4, min = 0.5, max = 8, step = 0.5,
          help = 'Respaldo: segundos hasta explotar si no ha tocado nada' },
    },
    editor = { draw = function(x, y, s)
        GlowBomb.loadAssets()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, quads[1], x, y, 0, s / FH, s / FH)
    end },
}
