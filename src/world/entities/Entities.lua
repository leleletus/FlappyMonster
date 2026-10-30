-- src/world/entities/Entities.lua
-- Catálogo de entidades del nivel (enemigos, NPCs...). Juego, servidor y
-- editor hacen require de este módulo.
--
-- ── Añadir una entidad nueva (receta) ────────────────────────────────────────
--  1. Crea src/world/entities/types/<categoría>/<nombre>.lua (enemies, bosses, traps, mechanisms, items, directors):
--       local Entity = require 'src/world/entities/base/Entity'
--       local Bat = Entity.extend(Entity, { walkFps = 8, walkFrames = 2 })
--       function Bat.loadAssets() ... end        -- sprites
--       function Bat.sizeImage() return img end  -- tamaño de la hitbox
--       function Bat:render(camX, camY) ... end
--       return { name='bat', label='Murcielago', category='Enemigos', class=Bat,
--                defaults = { movement='fly', speed=90 },    -- props comunes
--                props = { ... },                            -- props propias
--                editor = { sprite='assets/...png' } }
--  2. Añade "<categoría>/<nombre>" a TYPES abajo.
--  Listo: se puede colocar en el editor con todas sus propiedades (movimiento,
--  ruta, hostilidad, puntos...) y funciona en un jugador y online.
--
-- JEFES: heredan de entities/Boss.lua (vida, golpes, muerte, red) y se
-- colocan dentro de una zona de jefe (world/BossZones.lua). Ver types/mirror.lua.
--
-- Propiedades comunes a todas: EntityTypes.COMMON. Comportamiento común y
-- hooks para comportamiento propio: entities/Entity.lua. Reglas de combate:
-- entities/Interactions.lua.

local EntityTypes  = require 'src/world/entities/base/EntityTypes'
local Interactions = require 'src/world/entities/base/Interactions'
local Props        = require 'src/world/entities/base/Props'

local TYPES = { 'enemies/gummy', 'enemies/crabby', 'traps/spikefall', 'items/star', 'items/extralife', 'items/checkpoint',
                'enemies/mortar', 'traps/rainspike', 'directors/spikerain', 'mechanisms/trampoline', 'enemies/crabbytramp',
                'mechanisms/flood', 'mechanisms/pointarea', 'mechanisms/bosswall', 'bosses/mirror', 'bosses/miniboss1', 'bosses/megacrabby', 'enemies/pufferfish', 'mechanisms/bossglass', 'enemies/bomb', 'items/bombobject',
                'traps/cryo', 'bosses/snowboss', 'mechanisms/phaseblock', 'enemies/crabby_ice', 'bosses/megacrabby_ice', 'enemies/gummy_ice', 'bosses/megagummy', 'bosses/giantpuffer', 'bosses/gianthopper', 'bosses/groovecrab', 'enemies/gloomy', 'bosses/megagloomy', 'enemies/hopper',
                'enemies/gummy_magma', 'enemies/crabby_fortress', 'enemies/gummy_cave', 'enemies/gummy_fortress',
                'enemies/crabby_river', 'enemies/crabby_lava', 'enemies/crabby_cave', 'bosses/mirrorchase', 'items/apple',
                'directors/bossdrops', 'directors/crabmashup', 'items/box', 'mechanisms/scale', 'enemies/gust', 'items/seed', 'mechanisms/blizzard', 'mechanisms/geyser',
                'enemies/beetle', 'bosses/giantbeetle', 'enemies/gummy_jungle', 'enemies/crabby_jungle',
                'enemies/mole', 'enemies/piranha', 'enemies/carnivoreplant', 'enemies/penguin',
                'mechanisms/iceberg', 'traps/avalanche', 'mechanisms/cablecar', 'mechanisms/door' }

-- Un archivo puede definir varios tipos (p. ej. el trampolín en sus 4 direcciones)
for _, name in ipairs(TYPES) do
    local d = require('src/world/entities/types/' .. name)
    if d[1] then for _, def in ipairs(d) do EntityTypes.register(def) end
    else EntityTypes.register(d) end
end

-- Enemigos hechos con DATOS (assets/enemies/*.json, del editor de enemigos): se registran después, por el orden
-- de su índice. Ver entities/base/DataEnemy.lua.
require('src/world/entities/base/DataEnemy').registerAll(EntityTypes)

local Entities = {
    types        = EntityTypes,
    interactions = Interactions,
    props        = Props,
}

-- Entidades con cuerpo sólido para los jugadores (p. ej. jefes): el juego lo
-- pone en level.solidBodies antes de mover a los jugadores.
-- PLANO DE FONDO: lo que una entidad dibuja DETRÁS de los bloques del nivel (después del cielo), con
-- `renderBack(camX, camY)` — p. ej. el escenario y el público de El Groove. Solo dibujo (un jugador y cliente online)
function Entities.renderBack(list, camX, camY)
    for _, e in pairs(list or {}) do
        if e.alive and e.renderBack then e:renderBack(camX, camY) end
    end
end

-- PIEZAS: una entidad puede aportar varios cuerpos con `bodyParts()` (tablas con getOuterBounds, solidFull, alive,
-- owner y, si quiere, `oneway` = solo se pisa desde arriba): los platillos de la Balanza, las hojas de la Semilla.
-- CUERPOS QUE SE MUEVEN (`moves = true`): aquí se mide cuánto se movieron desde la vez anterior (`stepDx`, `stepDy`;
-- un jugador y servidor: una vez por paso; el cliente: una vez por fotograma, aproximado) y quien está de pie encima
-- se mueve con ellos (PlayerAdventure: `standBody`; las entidades, el que los mueve).
local TB = {}
local function track(o)
    local b = o:getOuterBounds(TB)
    local dx, dy = b.x - (o.lastBX or b.x), b.y - (o.lastBY or b.y)
    if math.abs(dx) > 48 or math.abs(dy) > 48 then dx, dy = 0, 0 end      -- (un salto de sitio no arrastra a nadie)
    o.stepDx, o.stepDy, o.lastBX, o.lastBY = dx, dy, b.x, b.y
end
function Entities.solidBodies(list)
    local out = {}
    for _, e in pairs(list) do
        if e.isSolidBody and e:isSolidBody() then out[#out+1] = e end
        if e.bodyParts and e.alive then
            for _, p in ipairs(e:bodyParts()) do if p.alive ~= false then out[#out+1] = p end end
        end
    end
    for _, o in ipairs(out) do if o.moves then track(o) end end
    return out
end

-- Crea la instancia de una colocación ya normalizada (Level la normaliza).
function Entities.create(placement)
    local t = EntityTypes.get(placement.type)
    if not t then return nil end
    local e = t.class.create(t.class, placement)
    -- De reserva (súbditos de un jefe): fuera de juego hasta que lo activen
    if e and placement.reserve and e.makeReserve then e:makeReserve(placement.summonKey) end
    return e
end

return Entities
