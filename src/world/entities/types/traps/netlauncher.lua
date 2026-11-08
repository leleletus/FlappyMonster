-- LANZARREDES (solo niveles Flappy: docs/design/flappy-plan-5b-valley.md, tarea 2): una torreta de chatarra del Monstruo
-- Malvado posada en el suelo. Cada T.EVERY s (× el ritmo de `trapPace`) brilla T.AIM_T s (aviso: clawServo) y dispara UNA
-- red recta HACIA ARRIBA a T.NET_SPD px/s (netFire): la misma red del Redcóptero (traps/netshot.lua, `launch(..., up)`):
-- −1 de vida y ctrlLock 0,4 s al jugador que toca, se engancha en los sólidos (pilares) y sale por arriba. Las saca de su
-- reserva (def.summons + Entity:freeMinion), como el jefe. No dispara si ningún jugador está a más de T.RANGE casillas.
-- La RÁFAGA del ataque especial la revienta (`diesToSpecial`: Entity:onSpecialHit → dieBurst). Estados: 'idle' → 'aim' →
-- 'recoil' → 'idle'; todo lo que se dibuja sale de state + deadTimer (viajan en el snapshot).
-- Arte: assets/images/enemies/netlauncher/netlauncher-Sheet.png (3 cuadros 14x14, ×4: reposo, apunta, retroceso;
-- tools/art/enemies/make_netlauncher.py).
local Entity = require 'src/world/entities/base/Entity'

local NL = Entity.extend(Entity, { debugColor = { 0.8, 0.4, 0.2 },
    hitbox = { outerW = 0.8, outerH = 0.8, innerW = 0.7, innerH = 0.7 } })

local T = {
    EVERY = 3.5,           -- s entre disparos
    AIM_T = 0.6,           -- s que brilla antes de disparar
    RECOIL_T = 0.25,       -- s de retroceso tras disparar
    NET_SPD = 520,         -- px/s de la red
    NET_POOL = 2,          -- redes de reserva (la 1ª ya se fue cuando toca la 2ª, pero una sale por arriba tarde)
    RANGE = 20,            -- casillas (una pantalla): más lejos de todos los jugadores, no dispara
    FIRST = 1.5,           -- s hasta el primer disparo al ponerse a tiro
}
NL.T = T

local SCALE, FW = 4, 14
local MUZZLE_DY = -20      -- de la boca al centro de la casilla (px)
local img, quads
function NL.loadAssets()
    if img then return end
    img = love.graphics.newImage('assets/images/enemies/netlauncher/netlauncher-Sheet.png')
    img:setFilter('nearest', 'nearest')
    quads = {}
    for i = 1, 3 do quads[i] = love.graphics.newQuad((i - 1) * FW, 0, FW, FW, img:getDimensions()) end
end
function NL.sizePx() return FW * SCALE, FW * SCALE end

function NL:init()
    self.moving, self.flying = false, false
    self.vx, self.vy = 0, 0
    self.state, self.deadTimer = 'idle', 0
    self.summonKey = 'nl' .. self.col .. ',' .. self.row     -- (sus redes de reserva: def.summons)
    self.waitT = T.FIRST
end

function NL:canBeStomped() return false end
function NL:isObstacle() return false end
function NL:interact(pa) return nil end

-- ¿Hay algún jugador vivo a menos de una pantalla?
function NL:playerNear(level)
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false and math.abs(pa.x - self.x) <= T.RANGE * TILE_PX
           and math.abs(pa.y - self.y) <= T.RANGE * TILE_PX then return true end
    end
    return false
end

function NL:fire(level)
    local n = self:freeMinion(level, 'netshot')
    if not n then return end
    n:appearAt(self.x, self.y + MUZZLE_DY)
    n.props.speed = T.NET_SPD
    n:launch(nil, 0, nil, 1, true)
    Sound.play('netFire')
    Entity.emitFx('sparks', self.x, self.y + MUZZLE_DY)
end

function NL:updateCustom(dt, level)
    local st = self.state
    if st == 'idle' then
        if not level or not self:playerNear(level) then self.waitT = math.max(self.waitT, 0.1) return true end
        self.waitT = self.waitT - dt
        if self.waitT <= 0 then
            self.state, self.deadTimer = 'aim', 0
            Sound.play('clawServo')
        end
    elseif st == 'aim' then
        self.deadTimer = self.deadTimer + dt
        if self.deadTimer >= T.AIM_T then
            self:fire(level)
            self.state, self.deadTimer = 'recoil', 0
        end
    elseif st == 'recoil' then
        self.deadTimer = self.deadTimer + dt
        if self.deadTimer >= T.RECOIL_T then
            self.state, self.deadTimer, self.waitT = 'idle', 0, T.EVERY - T.AIM_T - T.RECOIL_T
        end
    end
    return true
end

function NL:render(camX, camY)
    if not self.alive or Entity.SPECIAL_DEATH[self.state] then return end
    local x, y = math.floor(self.x - camX), math.floor(self.y - camY)
    local f = (self.state == 'aim') and 2 or (self.state == 'recoil') and 3 or 1
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, quads[f], x, y + TILE_PX / 2, 0, SCALE, SCALE, FW / 2, FW)     -- (apoyada en el suelo de su casilla)
end

return {
    name = 'netlauncher', label = 'Lanzarredes', category = 'Flappy', flappyOnly = true, pace = 'trapPace',
    diesToSpecial = true,
    description = 'Solo niveles Flappy: torreta del Monstruo Malvado en el suelo; cada pocos segundos brilla y lanza una red recta hacia arriba (−1 y te enreda). La ráfaga del ataque especial la revienta.',
    class = NL,
    defaults = { movement = 'static' }, hide = 'all',
    props = {},
    summons = function(pl)
        local key, out = 'nl' .. pl.col .. ',' .. pl.row, {}
        for _ = 1, T.NET_POOL do out[#out + 1] = { type = 'netshot', col = pl.col, row = pl.row, summonKey = key } end
        return out
    end,
    editor = { sprite = 'assets/images/enemies/netlauncher/netlauncher-Sheet.png', frameW = FW },
}
