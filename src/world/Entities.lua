-- src/world/Entities.lua
-- Catálogo de entidades del nivel (enemigos, NPCs...). Juego, servidor y
-- editor hacen require de este módulo.
--
-- ── Añadir una entidad nueva (receta) ────────────────────────────────────────
--  1. Crea src/world/entities/types/<nombre>.lua:
--       local Entity = require 'src/world/entities/Entity'
--       local Bat = Entity.extend(Entity, { walkFps = 8, walkFrames = 2 })
--       function Bat.loadAssets() ... end        -- sprites
--       function Bat.sizeImage() return img end  -- tamaño de la hitbox
--       function Bat:render(camX, camY) ... end
--       return { name='bat', label='Murcielago', category='Enemigos', class=Bat,
--                defaults = { movement='fly', speed=90 },    -- props comunes
--                props = { ... },                            -- props propias
--                editor = { sprite='assets/...png' } }
--  2. Añade su nombre a TYPES abajo.
--  Listo: se puede colocar en el editor con todas sus propiedades (movimiento,
--  ruta, hostilidad, puntos...) y funciona en un jugador y online.
--
-- JEFES: heredan de entities/Boss.lua (vida, golpes, muerte, red) y se
-- colocan dentro de una zona de jefe (world/BossZones.lua). Ver types/mirror.lua.
--
-- Propiedades comunes a todas: EntityTypes.COMMON. Comportamiento común y
-- hooks para comportamiento propio: entities/Entity.lua. Reglas de combate:
-- entities/Interactions.lua.

local EntityTypes  = require 'src/world/entities/EntityTypes'
local Interactions = require 'src/world/entities/Interactions'
local Props        = require 'src/world/entities/Props'

local TYPES = { 'gummy', 'crabby', 'spikefall', 'star', 'extralife', 'checkpoint',
                'mortar', 'rainspike', 'spikerain', 'trampoline', 'crabbytramp',
                'flood', 'pointarea', 'bosswall', 'mirror', 'miniboss1', 'megacrabby', 'pufferfish', 'bossglass', 'bomb', 'bombobject',
                'cryo', 'snowboss', 'phaseblock', 'crabby_ice', 'megacrabby_ice', 'gummy_ice', 'megagummy', 'gloomy', 'megagloomy', 'hopper',
                'gummy_magma', 'crabby_fortress', 'gummy_cave', 'gummy_fortress',
                'crabby_river', 'crabby_lava', 'crabby_cave' }

-- Un archivo puede definir varios tipos (p. ej. el trampolín en sus 4 direcciones)
for _, name in ipairs(TYPES) do
    local d = require('src/world/entities/types/' .. name)
    if d[1] then for _, def in ipairs(d) do EntityTypes.register(def) end
    else EntityTypes.register(d) end
end

local Entities = {
    types        = EntityTypes,
    interactions = Interactions,
    props        = Props,
}

-- Entidades con cuerpo sólido para los jugadores (p. ej. jefes): el juego lo
-- pone en level.solidBodies antes de mover a los jugadores.
function Entities.solidBodies(list)
    local out = {}
    for _, e in pairs(list) do
        if e.isSolidBody and e:isSolidBody() then out[#out+1] = e end
    end
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
