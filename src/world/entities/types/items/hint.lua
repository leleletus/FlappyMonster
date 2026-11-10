-- El CARTEL de ayuda (`hint`, 0.5.190: el nivel tutorial, docs/design/tutorial-level.md): un poste con un «?». Con el
-- jugador de este aparato a menos de `radius` casillas, encima sale un BOCADILLO con su texto: una clave de
-- assets/lang/translations.csv (`text`), en el idioma del jugador y con los botones del aparato que usa ({jump},
-- {run}, {crouch}, {grab}, {light}, {left}, {right}: Input.label). Solo dibujo: no choca, no se pisa, no hace daño,
-- no viaja por la red (cada cliente mira a su jugador). El bocadillo va POR ENCIMA de la oscuridad
-- (Entity:renderOverlay, que los estados dibujan después de Darkness).
-- Arte: assets/images/items/hint/sign-Sheet.png (12x16 ×2: el «?» encendido y ya leído), de
-- tools/art/items/make_hint_sign.py.
local Entity = require 'src/world/entities/base/Entity'
local L = require 'src/core/Lang'

local Hint = Entity.extend(Entity, { debugColor = { 1, 0.85, 0.4 },
    hitbox = { outerW = 0.6, outerH = 1, innerW = 0.01, innerH = 0.01 } })

local S = GUMMY_SCALE
local FADE = 6                 -- 1/s: lo que tarda en aparecer / irse el bocadillo
local PAD = 10                 -- px de margen dentro del bocadillo
local MAXW = 380               -- px de ancho como mucho (luego parte en líneas)

function Hint.sizePx() return 12 * S, 16 * S end
function Hint:init() self.moving, self.flying, self.vx, self.vy, self.state = false, true, 0, 0, 'idle'; self.show = 0 end
function Hint:isObstacle() return false end
function Hint:canBeStomped() return false end
function Hint:canBeKnocked() return false end
function Hint:canFreeze() return false end
function Hint:canBeEaten() return false end
function Hint:interact() return nil end
function Hint:updateCustom(dt) return true end
function Hint:netAtRest() return true end           -- (nunca cambia: no se envía)
function Hint:netRest() end

local strip
local function art()
    strip = strip or require('src/fx/SpriteStrip').load('assets/images/items/hint/sign-Sheet.png', 12)
    return strip
end

function Hint:render(camX, camY)
    local x = math.floor(self.x - camX + 0.5)
    local y = math.floor(self.y + self.outerH / 2 - camY + 0.5)      -- (los pies del poste en el suelo)
    love.graphics.setColor(1, 1, 1, 1)
    art():draw(self.read and 2 or 1, x, y - 8 * S, 0, S, S)
end

-- El texto con los botones del aparato que se usa (se rehace al cambiar de idioma o de aparato)
local ARGS = {}
local function text(self)
    local dev, lang = Input.lastDevice, L.current()
    if self._txt and self._dev == dev and self._lang == lang then return self._txt end
    ARGS.jump, ARGS.run, ARGS.crouch = Input.label('jump'), Input.label('run'), Input.label('crouch')
    ARGS.grab, ARGS.light = Input.label('grab'), Input.label('light')
    ARGS.left, ARGS.right = Input.label('move_left'), Input.label('move_right')
    self._txt, self._dev, self._lang = L(self.props.text or 'tut.missing', ARGS), dev, lang
    return self._txt
end

-- Por encima de todo (y de la oscuridad): el bocadillo, si el jugador de este aparato está cerca. `viewer` = ese
-- jugador (lo pasa el estado)
function Hint:renderOverlay(camX, camY, viewer, dt)
    local near = false
    if viewer and not viewer.dying then
        local r = (self.props.radius or 3) * TILE_PX
        near = math.abs(viewer.x - self.x) < r and math.abs(viewer.y - self.y) < r * 1.2
    end
    if near then self.read = true end
    self.show = math.max(0, math.min(1, (self.show or 0) + (near and 1 or -1) * FADE * (dt or 1 / 60)))
    if self.show <= 0 then return end
    local font = FONT_SMALL
    local msg = text(self)
    local _, lines = font:getWrap(msg, MAXW)
    local w = 0
    for _, l in ipairs(lines) do w = math.max(w, font:getWidth(l)) end
    local lh = font:getHeight() + 4
    local bw, bh = w + PAD * 2, #lines * lh + PAD * 2 - 4
    local cx = math.floor(self.x - camX + 0.5)
    local top = math.floor(self.y - self.outerH / 2 - camY - 18 - bh + (1 - self.show) * 10 + 0.5)
    local bx = math.max(8, math.min(WINDOW_W - 8 - bw, cx - math.floor(bw / 2)))
    local a = self.show
    love.graphics.setColor(0.07, 0.07, 0.11, 0.88 * a)                     -- (bocadillo: rectángulo duro, sin curvas)
    love.graphics.rectangle('fill', bx, top, bw, bh)
    love.graphics.setColor(1, 0.85, 0.4, a)
    love.graphics.rectangle('fill', bx, top, bw, 2)
    love.graphics.rectangle('fill', cx - 4, top + bh, 8, 6)               -- (la punta hacia el cartel)
    love.graphics.setFont(font)
    for i, l in ipairs(lines) do
        love.graphics.setColor(0, 0, 0, 0.75 * a)
        love.graphics.print(l, bx + PAD + 2, top + PAD + (i - 1) * lh + 2)
        love.graphics.setColor(1, 1, 1, a)
        love.graphics.print(l, bx + PAD, top + PAD + (i - 1) * lh)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawIcon(x, y, s)
    art():draw(1, x + s / 2, y + s / 2, 0, s / 16, s / 16)
end

return {
    name = 'hint', label = 'Cartel de ayuda', category = 'Objetos', class = Hint,
    description = 'Un poste con un «?»: cerca del jugador muestra un texto (una clave de translations.csv) con los '
               .. 'botones del aparato que usa ({jump}, {run}, {crouch}, {grab}, {light}).',
    defaults = { movement = 'static' },
    hide = 'all',
    props = {
        { key = 'text', kind = 'text', label = 'Texto (clave de traducción)', group = 'Cartel', default = 'tut.missing',
          help = 'Una fila de assets/lang/translations.csv (p. ej. tut.run); {jump}, {run}, {crouch}, {grab}, {light} = los botones' },
        { key = 'radius', kind = 'int', label = 'Se lee a (casillas)', group = 'Cartel', default = 3, min = 1, max = 10, step = 1 },
    },
    editor = { sprite = 'assets/images/items/hint/sign-Sheet.png', frameW = 12, draw = drawIcon },
}
