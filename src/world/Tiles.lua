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

local MATERIALS = { 'default', 'stone', 'wood', 'deadly', 'water', 'dirt', 'grass', 'snow', 'ice', 'sand' }

local TYPES = {
    'empty',          -- 0
    'solid',          -- 1
    'platform',       -- 2
    'danger',         -- 3
    'border',         -- 4
    'water',          -- 9
    'platform_drop',  -- 10
    'finish',         -- 11
    'breakable',      -- 12
    'switch_on',      -- 13
    'switch_off',     -- 14
    'hidden_block',   -- 15
    'dirt',           -- 16
    'grass',          -- 17
    'switchblock_on', -- 18, 19, 27, 28 (Bloques ON / OFF, activo e inactivo)
    'snow',           -- 29
    'ice',            -- 30
    'thin_ice',       -- 31-34 (hielo fino: normal, dañado, muy dañado, a punto de romperse)
    'sand',           -- 35
}

-- Bloques TRAMPA ("mímicos"): se ven idénticos al tile original pero no tienen
-- colisión ni efectos (paredes, plataformas, peligros o pinchos falsos).
-- Los pinchos colocados sobre un tile trampa tampoco hacen daño.
-- { id nuevo, tile que imitan, nombre, etiqueta }
local FAKES = {
    { 20, 'solid',         'fake_solid',         'Pared falsa' },
    { 21, 'platform',      'fake_platform',      'Plataforma falsa' },
    { 22, 'platform_drop', 'fake_platform_drop', 'Plataforma atravesable falsa' },
    { 23, 'danger',        'fake_danger',        'Peligro falso' },
    { 24, 'border',        'fake_border',        'Borde falso' },
    { 25, 'breakable',     'fake_breakable',     'Bloque rompible falso' },
    { 26, 'empty',         'fake_spikes',        'Base para pinchos falsos' },
}

-- Ids 5-8 fueron pinchos por tile; hoy los pinchos son subceldas (TileCodec).
for id = 5, 8 do TileTypes.reserve(id, 'antiguos pinchos por tile') end

for _, name in ipairs(MATERIALS) do
    Materials.register(require('src/world/tiles/materials/' .. name))
end
for _, name in ipairs(TYPES) do
    local def = require('src/world/tiles/types/' .. name)
    -- (un archivo puede definir varios tiles: una lista)
    if def[1] then for _, d in ipairs(def) do TileTypes.register(d) end else TileTypes.register(def) end
end

for _, f in ipairs(FAKES) do
    local base = TileTypes.byName[f[2]]
    TileTypes.register({
        id = f[1], name = f[3], label = f[4], category = 'Trampas',
        collision = 'none', material = 'default', enemySolid = false,
        fake = true, mimics = base.name,
        joinGroup = base.joinGroup, hitbox = base.hitbox,
        draw = base.draw, texture = base.texture, color = base.color,
        editorColor = base.editorColor or { 0.5, 0.5, 0.5 },
        editorBadge = '?',
    })
end

return {
    codec     = TileCodec,
    materials = Materials,
    types     = TileTypes,
    get       = TileTypes.get,
}
