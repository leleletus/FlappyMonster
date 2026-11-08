-- RED DEL REDCÓPTERO (solo niveles Flappy: la dispara su cañón, docs/design/flappy-plan-5-netcopter.md). Es un súbdito de
-- RESERVA del jefe (def.summons de types/bosses/netcopter.lua): él la saca con Entity:appearAt en la boca del cañón y le
-- pone el rumbo. Estados:
--   'fly'    vuela a la izquierda a `speed` px/s; en los primeros NET_SETTLE s baja / sube hasta `ty` (la altura del
--            jugador al disparar) y luego sigue recta con su deriva `drift` (px/s; el abanico de 3 de la fase 2). Al
--            tocar a un jugador: −1 de vida y ctrlLock 0,4 s (Boss.strike, la red le enreda) y desaparece. Sale de la
--            zona (`leftBoundPx`), toca un bloque sólido (los pilares también: enemySolid) o el borde del nivel → desaparece.
--   'spent'  ya no está (alive = false: vuelve a la reserva del jefe)
-- Arte: assets/images/bosses/netcopter/net.png (16x16, ×6; tools/art/bosses/make_netcopter.py). Todo lo que se dibuja
-- sale de x, y.
local Entity = require 'src/world/entities/base/Entity'
local Boss   = require 'src/world/entities/base/Boss'

local Net = Entity.extend(Entity, { debugColor = { 0.95, 0.9, 0.6 },
    hitbox = { outerW = 0.8, outerH = 0.8, innerW = 0.7, innerH = 0.7 } })

local SCALE = 6
local FW = 16
local NET_SETTLE = 0.3                                -- s para llegar a la altura del disparo
local HIT = { 1, 220, -120, 0.4, 0 }                  -- vida, empujón (vx, vy), s sin control, s aturdido
Net.HIT = HIT
local img
function Net.loadAssets()
    if img then return end
    img = love.graphics.newImage('assets/images/bosses/netcopter/net.png')
    img:setFilter('nearest', 'nearest')
end
function Net.sizePx() return FW * SCALE, FW * SCALE end

function Net:init()
    self.moving, self.flying = false, true
    self.vx, self.vy = 0, 0
    self.state = 'fly'
    self.ty, self.y0, self.drift = nil, nil, 0
    self.settled = nil
end

-- La lanza el jefe (ya en su sitio con appearAt): hacia la izquierda, a la altura `ty`, con deriva `drift`
function Net:launch(ty, drift, leftPx)
    self.state, self.deadTimer, self.settled = 'fly', 0, nil
    self.y0, self.ty, self.drift = self.y, ty or self.y, drift or 0
    self.leftBoundPx = leftPx or -math.huge
end

function Net:canBeStomped() return false end
function Net:canBeKnocked() return false end
function Net:isObstacle() return false end
function Net:interact(pa) return nil end          -- (el golpe lo da updateCustom: lleva ctrlLock, Boss.strike)

local overlap = Boss.overlap

function Net:spend()
    self.state, self.alive = 'spent', false
end

function Net:updateCustom(dt, level)
    if self.state ~= 'fly' then return true end
    self.deadTimer = self.deadTimer + dt
    local t = self.deadTimer
    self.x = self.x - (self.props.speed or 520) * dt
    if t < NET_SETTLE and self.ty then
        local k = t / NET_SETTLE
        self.y = self.y0 + (self.ty - self.y0) * (1 - (1 - k) * (1 - k))
    else
        if self.ty and not self.settled then self.y, self.settled = self.ty, true end
        self.y = self.y + (self.drift or 0) * dt
    end
    if not level then return true end
    if self.x < (self.leftBoundPx or -math.huge) or self.x < 0 or self.y < -TILE_PX or self.y > level.heightPx
       or level:isEnemySolidAt(self.x - self.outerW / 2, self.y) then
        self:spend()
        return true
    end
    local b = self:getOuterBounds()
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false and overlap(b, pa:getOuterBounds()) then
            if Boss.strike(pa, HIT, -1) then
                Entity.emitFx('collect', self.x, self.y)
                self:spend()
                return true
            end
        end
    end
    return true
end

function Net:render(camX, camY)
    if not self.alive then return end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, math.floor(self.x - camX), math.floor(self.y - camY), 0, SCALE, SCALE, FW / 2, FW / 2)
end

return {
    name = 'netshot', label = 'Red del Redcóptero', category = 'Flappy', flappyOnly = true, pace = 'bossPace',
    description = 'Solo niveles Flappy: la dispara el Redcóptero. Vuela a la izquierda; te quita 1 y te enreda un momento.',
    class = Net,
    defaults = { movement = 'static' }, hide = 'all',
    props = {
        { key = 'speed', kind = 'number', label = 'Velocidad (px/s)', group = 'Red', default = 520, min = 100, max = 1200,
          step = 20, help = 'Hacia la izquierda' },
    },
    editor = { sprite = 'assets/images/bosses/netcopter/net.png' },
}
