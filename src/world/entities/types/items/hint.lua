-- El CARTEL de ayuda (`hint`, 0.5.190: el nivel tutorial, docs/design/tutorial-level.md): un poste con un «?». Con el
-- jugador de este aparato a menos de `radius` casillas, encima sale un BOCADILLO con su texto: una clave de
-- assets/lang/translations.csv (`text`), en el idioma del jugador y con los botones del aparato que usa ({jump},
-- {run}, {crouch}, {grab}, {light}, {left}, {right}, {special}: Input.label; src/ui/HintBubble.lua). Solo dibujo: no choca, no se pisa, no hace daño,
-- no viaja por la red (cada cliente mira a su jugador). El bocadillo va POR ENCIMA de la oscuridad
-- (Entity:renderOverlay, que los estados dibujan después de Darkness).
-- Arte: assets/images/items/hint/sign-Sheet.png (12x16 ×2: el «?» encendido y ya leído), de
-- tools/art/items/make_hint_sign.py.
local Entity = require 'src/world/entities/base/Entity'
local Bubble = require 'src/ui/HintBubble'

local Hint = Entity.extend(Entity, { debugColor = { 1, 0.85, 0.4 },
    hitbox = { outerW = 0.6, outerH = 1, innerW = 0.01, innerH = 0.01 } })

local S = GUMMY_SCALE

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

-- Por encima de todo (y de la oscuridad): el bocadillo, si el jugador de este aparato está cerca. `viewer` = ese
-- jugador (lo pasa el estado). El bocadillo y sus botones: src/ui/HintBubble.lua (lo comparten las jaulas Flappy)
function Hint:renderOverlay(camX, camY, viewer, dt)
    local near = false
    if viewer and not viewer.dying then
        local r = (self.props.radius or 3) * TILE_PX
        near = math.abs(viewer.x - self.x) < r and math.abs(viewer.y - self.y) < r * 1.2
    end
    if near then self.read = true end
    self.show = Bubble.fade(self.show, near, dt)
    Bubble.draw(self, self.props.text or 'tut.missing', nil, nil, self.x - camX,
        self.y - self.outerH / 2 - camY, self.y + self.outerH / 2 - camY, self.show, near)
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
