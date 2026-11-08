-- RED DEL REDCÓPTERO (solo niveles Flappy: la dispara su cañón, docs/design/flappy-plan-5-netcopter.md). Es un súbdito de
-- RESERVA del jefe (def.summons de types/bosses/netcopter.lua): él la saca con Entity:appearAt en la boca del cañón y le
-- pone el rumbo. Estados:
--   'fly'    vuela hacia `facing` (−1 izquierda, 1 derecha: hacia donde mira el jefe) a `speed` px/s; en los primeros
--            NET_SETTLE s baja / sube hasta `ty` (la altura del
--            jugador al disparar) y luego sigue recta con su deriva `drift` (px/s; el abanico de 3 de la fase 2). Al
--            tocar a un jugador: −1 de vida y ctrlLock 0,4 s (Boss.strike, la red le enreda) → 'wrap'. Toca un bloque
--            sólido (los pilares también: enemySolid) → 'snag'. Sale de la zona (`boundPx`, por delante) o del nivel →
--            desaparece.
--   'wrap'   le dio a un jugador: la red abierta le envuelve mientras dura su ctrlLock (WRAP_T s, sigue su x, y) y no
--            vuelve a herir; luego 'spent'
--   'snag'   se enganchó en un sólido (un pilar): se deshace en hebras SNAG_T s en ese sitio, sin herir; luego 'spent'
--   'spent'  ya no está (alive = false: vuelve a la reserva del jefe)
-- Arte: assets/images/bosses/netcopter/net-Sheet.png (5 cuadros 24x24, ×6: ovillo, a medias, abierta, abierta girada
-- 30° y 60°) y puff-Sheet.png (las hebras: cuadros 4-6); tools/art/bosses/make_netcopter.py. Volando se DESPLIEGA en
-- UNFURL_T s (cuadros 1-3) y luego GIRA (3-4-5, al revés si va a la derecha). Todo lo que se dibuja sale de state,
-- deadTimer, facing y x, y.
local Entity = require 'src/world/entities/base/Entity'
local Boss   = require 'src/world/entities/base/Boss'

local Net = Entity.extend(Entity, { debugColor = { 0.95, 0.9, 0.6 },
    hitbox = { outerW = 0.8, outerH = 0.8, innerW = 0.7, innerH = 0.7 } })

local SCALE = 6
local FW = 16                                         -- (la caja: la red abierta, sin los plomos)
local NF = 24                                         -- cuadro de net-Sheet
local PF = 8                                          -- cuadro de puff-Sheet
local NET_SETTLE = 0.3                                -- s para llegar a la altura del disparo
local HIT = { 1, 220, -120, 0.4, 0 }                  -- vida, empujón (vx, vy), s sin control, s aturdido
Net.HIT = HIT
local WRAP_T = HIT[4]                                 -- s que envuelve al jugador (su ctrlLock)
local SNAG_T = 0.3                                    -- s deshaciéndose en un pilar
local UNFURL_T = 0.25                                 -- s desplegándose (ovillo → a medias → abierta)
local SPIN_FPS = 14                                   -- cuadros por segundo girando
Net.WRAP_T, Net.SNAG_T = WRAP_T, SNAG_T
local img, quads, puffImg, puffQuads
local function strip(name, fw)
    local im = love.graphics.newImage('assets/images/bosses/netcopter/' .. name .. '.png')
    im:setFilter('nearest', 'nearest')
    local q = {}
    for i = 1, math.floor(im:getWidth() / fw) do q[i] = love.graphics.newQuad((i - 1) * fw, 0, fw, im:getHeight(), im:getDimensions()) end
    return im, q
end
function Net.loadAssets()
    if img then return end
    img, quads = strip('net-Sheet', NF)
    puffImg, puffQuads = strip('puff-Sheet', PF)
end
function Net.sizePx() return FW * SCALE, FW * SCALE end

function Net:init()
    self.moving, self.flying = false, true
    self.vx, self.vy = 0, 0
    self.state = 'fly'
    self.ty, self.y0, self.drift = nil, nil, 0
    self.settled = nil
end

-- La lanza el jefe (ya en su sitio con appearAt): hacia `dir` (−1 izquierda, por defecto; 1 derecha), a la altura `ty`,
-- con deriva `drift`; desaparece al pasar `boundPx` (el borde de la zona por delante)
function Net:launch(ty, drift, boundPx, dir)
    dir = (dir == 1) and 1 or -1
    self.state, self.deadTimer, self.settled, self.wrapPa = 'fly', 0, nil, nil
    self.y0, self.ty, self.drift = self.y, ty or self.y, drift or 0
    self.facing = dir
    self.boundPx = boundPx or (dir < 0 and -math.huge or math.huge)
end

function Net:canBeStomped() return false end
function Net:canBeKnocked() return false end
function Net:isObstacle() return false end
function Net:interact(pa) return nil end          -- (el golpe lo da updateCustom: lleva ctrlLock, Boss.strike)

local overlap = Boss.overlap

function Net:spend()
    self.state, self.alive = 'spent', false
end

-- Le dio a `pa`: le envuelve (sin volver a herir) mientras dura su ctrlLock
function Net:wrap(pa)
    self.state, self.deadTimer, self.wrapPa = 'wrap', 0, pa
    self.x, self.y = pa.x, pa.y
end
-- Se engancha en un sólido: se deshace allí
function Net:snag()
    self.state, self.deadTimer = 'snag', 0
end

function Net:updateCustom(dt, level)
    local st = self.state
    if st == 'wrap' or st == 'snag' then
        self.deadTimer = self.deadTimer + dt
        local p = self.wrapPa
        if st == 'wrap' and p then self.x, self.y = p.x, p.y end
        if self.deadTimer >= ((st == 'wrap') and WRAP_T or SNAG_T) or (p and (p.dying or p.alive == false)) then
            self.wrapPa = nil
            self:spend()
        end
        return true
    end
    if st ~= 'fly' then return true end
    self.deadTimer = self.deadTimer + dt
    local t = self.deadTimer
    local dir = (self.facing == 1) and 1 or -1
    self.x = self.x + dir * (self.props.speed or 520) * dt
    if t < NET_SETTLE and self.ty then
        local k = t / NET_SETTLE
        self.y = self.y0 + (self.ty - self.y0) * (1 - (1 - k) * (1 - k))
    else
        if self.ty and not self.settled then self.y, self.settled = self.ty, true end
        self.y = self.y + (self.drift or 0) * dt
    end
    if not level then return true end
    local past = (dir < 0) and self.x < (self.boundPx or -math.huge) or (dir > 0 and self.x > (self.boundPx or math.huge))
    if past or self.x < 0 or self.x > level.widthPx or self.y < -TILE_PX or self.y > level.heightPx then
        self:spend()
        return true
    end
    if level:isEnemySolidAt(self.x + dir * self.outerW / 2, self.y) then
        self:snag()
        return true
    end
    local b = self:getOuterBounds()
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false and overlap(b, pa:getOuterBounds()) then
            if Boss.strike(pa, HIT, dir) then
                Entity.emitFx('collect', self.x, self.y)
                self:wrap(pa)
                return true
            end
        end
    end
    return true
end

-- El cuadro de net-Sheet que toca: desplegándose, y luego girando (al revés hacia la derecha)
function Net:netFrame()
    local t, st = self.deadTimer or 0, self.state
    if st == 'wrap' then return 3 end
    if st == 'snag' then return 2 end
    if t < UNFURL_T then return 1 + math.floor(t / UNFURL_T * 3) end
    local k = math.floor((t - UNFURL_T) * SPIN_FPS) % 3
    if self.facing == 1 then k = (3 - k) % 3 end
    return 3 + k
end

function Net:render(camX, camY)
    if not self.alive then return end
    local x, y = math.floor(self.x - camX), math.floor(self.y - camY)
    local st = self.state
    if st == 'snag' and self.deadTimer >= SNAG_T / 2 then
        -- (se deshace: solo hebras)
    else
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, quads[self:netFrame()], x, y, 0, SCALE, SCALE, NF / 2, NF / 2)
    end
    if st == 'snag' then
        -- hebras que saltan del enganche: tres bocanadas (cuadros 4-6 de puff-Sheet) que se abren
        local k = math.min(2, math.floor(self.deadTimer / SNAG_T * 3))
        local o = math.floor(self.deadTimer / SNAG_T * 4) * SCALE
        love.graphics.setColor(1, 1, 1, 1)
        for i, d in ipairs({ { -1, -1 }, { 1, -1 }, { 0, 1 } }) do
            love.graphics.draw(puffImg, puffQuads[4 + k], x + d[1] * (o + 3 * SCALE), y + d[2] * (o + 2 * SCALE) + (i - 2) * SCALE,
                0, SCALE, SCALE, PF / 2, PF / 2)
        end
    end
end

return {
    name = 'netshot', label = 'Red del Redcóptero', category = 'Flappy', flappyOnly = true, pace = 'bossPace',
    description = 'Solo niveles Flappy: la dispara el Redcóptero hacia donde mira; te quita 1 y te enreda un momento.',
    class = Net,
    defaults = { movement = 'static' }, hide = 'all',
    props = {
        { key = 'speed', kind = 'number', label = 'Velocidad (px/s)', group = 'Red', default = 520, min = 100, max = 1200,
          step = 20, help = 'Hacia donde mira el jefe' },
    },
    editor = { sprite = 'assets/images/bosses/netcopter/net.png' },   -- (la red quieta, abierta)
}
