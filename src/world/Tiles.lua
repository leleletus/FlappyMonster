-- src/world/Tiles.lua
-- Punto de entrada del sistema de tiles: carga el catálogo de materiales y de
-- tipos de tile. Motor, servidor y editor hacen require de este módulo.
--
-- ── Añadir un tile nuevo (receta) ────────────────────────────────────────────
--  1. (Si hace falta) crea src/world/tiles/materials/<material>.lua y añade su
--     nombre a MATERIALS abajo. Ver campos en tiles/Materials.lua.
--  2. Crea src/world/tiles/types/<nombre>.lua con un id NUEVO (nunca reutilices
--     uno) y sus campos (ver tiles/TileTypes.lua): colisión, hitbox, material,
--     aspecto (draw / texture / color).
--  3. Añade su nombre a TYPES abajo.
--  Listo: el motor, el servidor y el editor de niveles lo reconocen solos.

local TileCodec = require 'src/world/tiles/TileCodec'
local Materials = require 'src/world/tiles/Materials'
local TileTypes = require 'src/world/tiles/TileTypes'

local MATERIALS = { 'default', 'stone', 'wood', 'deadly', 'water' }

local TYPES = {
    'empty',          -- 0
    'solid',          -- 1
    'platform',       -- 2
    'danger',         -- 3
    'border',         -- 4
    'water',          -- 9
    'platform_drop',  -- 10
    'finish',         -- 11
}

-- Ids 5-8 fueron pinchos por tile; hoy los pinchos son subceldas (TileCodec).
for id = 5, 8 do TileTypes.reserve(id, 'antiguos pinchos por tile') end

for _, name in ipairs(MATERIALS) do
    Materials.register(require('src/world/tiles/materials/' .. name))
end
for _, name in ipairs(TYPES) do
    TileTypes.register(require('src/world/tiles/types/' .. name))
end

return {
    codec     = TileCodec,
    materials = Materials,
    types     = TileTypes,
    get       = TileTypes.get,
}
