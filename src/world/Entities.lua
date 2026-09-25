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
-- Propiedades comunes a todas: EntityTypes.COMMON. Comportamiento común y
-- hooks para comportamiento propio: entities/Entity.lua. Reglas de combate:
-- entities/Interactions.lua.

local EntityTypes  = require 'src/world/entities/EntityTypes'
local Interactions = require 'src/world/entities/Interactions'
local Props        = require 'src/world/entities/Props'

local TYPES = { 'gummy', 'crabby' }

for _, name in ipairs(TYPES) do
    EntityTypes.register(require('src/world/entities/types/' .. name))
end

local Entities = {
    types        = EntityTypes,
    interactions = Interactions,
    props        = Props,
}

-- Crea la instancia de una colocación ya normalizada (Level la normaliza).
function Entities.create(placement)
    local t = EntityTypes.get(placement.type)
    if not t then return nil end
    return t.class.create(t.class, placement)
end

return Entities
