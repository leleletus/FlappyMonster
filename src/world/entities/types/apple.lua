-- COMIDA que cura (el tipo se sigue llamando `apple`: ya está en niveles): devuelve 1 de VIDA (PS) al cogerla;
-- con la vida llena no hay nada que curar y da puntos. (La regla está en Interactions.pickupEffect:
-- `pickup = { heal = n, score = puntos si no cura }`.)
-- ASPECTO por isla (prop `skin`; 'auto' = según el fondo del nivel, como el Saltarín): pradera = la MANZANA (dibujo
-- del usuario), costa = piña, fortaleza = muslo asado, nieve = polo de hielo, cueva = bayas luminosas (dan un poco
-- de luz en lo oscuro), volcán = guindilla. assets/images/items/apple.png y food_<isla>.png
-- (tools/ui/make_food_sprites.py). Uno nuevo = un PNG + una línea en FILES.
local Entity = require 'src/world/entities/Entity'
local Hopper = require('src/world/entities/types/hopper').class

local Apple = Entity.extend(Entity, { deadDuration = 0.35, debugColor = { 1, 0.3, 0.3 } })
local SCALE = 4
local FILES = {
    pradera = 'assets/images/items/apple.png', costa = 'assets/images/items/food_costa.png',
    fortaleza = 'assets/images/items/food_fortaleza.png', nieve = 'assets/images/items/food_nieve.png',
    cueva = 'assets/images/items/food_cueva.png', volcan = 'assets/images/items/food_volcan.png',
}
local GLOW = { cueva = { 0.4, 1, 0.9 } }             -- (las que brillan: color de su luz)
local imgs
function Apple.loadAssets()
    if imgs then return end
    imgs = {}
    for id, f in pairs(FILES) do
        imgs[id] = love.graphics.newImage(f)
        if imgs[id].setFilter then imgs[id]:setFilter('nearest', 'nearest') end
    end
end
function Apple.sizePx() return 16 * SCALE, 16 * SCALE end

-- Qué comida toca en ese nivel (la misma regla de isla que el Saltarín: Hopper.skinFor)
function Apple.skinFor(props, level)
    local id = props and props.skin or 'auto'
    if id == 'auto' then
        id = level and (((level.spikeSkin == 'ice' or level.snow) and 'nieve') or Hopper.BY_BG[level.background or 'meadow']) or 'pradera'
    end
    return FILES[id] and id or 'pradera'
end

function Apple:init()
    self.moving, self.flying = false, true
    self.vx, self.vy = 0, 0
    self.state = 'idle'
    self.phase = (self.col * 0.41 + self.row * 0.63) % (math.pi * 2)
end

function Apple:updateCustom(dt) return true end
function Apple:canBeStomped() return false end

-- (en lo oscuro, las bayas de la cueva dan una luz pequeña: src/fx/Darkness.lua)
function Apple:lights()
    local c = GLOW[Apple.skinFor(self.props, self.levelRef)]
    if not c or self.state == 'dead' then return nil end
    return { { x = self.x, y = self.y, r = 70, color = c, a = 0.35, pulse = 2 } }
end

function Apple:render(camX, camY)
    local img = imgs[Apple.skinFor(self.props, self.levelRef)] or imgs.pradera
    local t = love.timer.getTime() + (self.phase or 0)
    -- se mece y sube y baja un poco
    local x = math.floor(self.x - camX)
    local y = math.floor(self.y - camY + math.sin(t * 2.2) * 4)
    local rot = math.sin(t * 2.2 + 1) * 0.16
    local a, s = 1, 1
    if self.state == 'dead' then
        local k = math.min(1, self.deadTimer / 0.35)
        a, s = 1 - k, 1 + k * 0.7
    end
    love.graphics.setColor(1, 1, 1, a)
    love.graphics.draw(img, x, y, rot, SCALE * s, SCALE * s, img:getWidth() / 2, img:getHeight() / 2)
    love.graphics.setColor(1, 1, 1, 1)
end

local skinOpts = { { value = 'auto', label = 'Auto' }, { value = 'pradera', label = 'Manzana' }, { value = 'costa', label = 'Piña' },
                   { value = 'fortaleza', label = 'Muslo' }, { value = 'nieve', label = 'Polo' }, { value = 'cueva', label = 'Bayas' },
                   { value = 'volcan', label = 'Guindilla' } }
return {
    name = 'apple', label = 'Comida', category = 'Objetos',
    description = 'Coleccionable: devuelve 1 de vida (PS); con la vida llena, +20 puntos. Su aspecto sale de la isla del nivel '
               .. '(manzana, piña, muslo, polo, bayas, guindilla) o se elige a mano.',
    class = Apple,
    pickup = { heal = 1, score = 20 },
    traits = { wantsLevel = true },
    hide = { 'movement', 'attach', 'speed', 'startDir', 'patrol', 'turnAtEdges', 'bobAmp', 'pauses',
             'onTouch', 'stompable', 'points', 'dropOnSight', 'detectRange' },
    props = {
        { key='skin', kind='enum', label='Aspecto', group='Comida', default='auto', options=skinOpts,
          help='Auto = la comida de la isla del nivel (por su fondo)' },
    },
    editor = { sprite = 'assets/images/items/apple.png' },
}
