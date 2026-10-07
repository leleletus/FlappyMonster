-- src/world/decorations/Decorations.lua
-- Catálogo de decoraciones (plantas, árboles, adornos). Juego y editor hacen
-- require de este módulo.
--
-- ── Añadir una decoración nueva (receta) ─────────────────────────────────────
--  1. Crea src/world/decorations/types/<nombre>.lua:
--       return { name='rock', label='Roca', placement='cell',   -- o 'sub'
--                editor = { icon='assets/...png' },
--                loadAssets = function() ... end,
--                init = function(d) ... end,            -- opcional
--                update = function(d, dt) ... end,      -- opcional
--                draw = function(d, sx, sy) ... end }   -- d.flip, d.animT, d.phase
--     Un archivo puede devolver una LISTA de decoraciones (los juegos
--     temáticos: ice_set, cave_set, water_set, tropical_set; ayudas de dibujo,
--     animación y partículas en decorations/DecoFx.lua).
--  2. Añade su nombre a TYPES abajo.
--  Listo: aparece en la capa Decoracion del editor (con Espejar y Capa
--  delante/detras) y el juego la dibuja y anima.
-- Campos completos: src/world/decorations/DecorationTypes.lua

local DecorationTypes = require 'src/world/decorations/DecorationTypes'

local TYPES = { 'tulip', 'stretch', 'palmtree', 'icicle', 'ice_set', 'cave_set', 'water_set', 'tropical_set', 'meadow_set', 'volcano_set' }

for _, name in ipairs(TYPES) do
    local def = require('src/world/decorations/types/' .. name)
    if def[1] then for _, d in ipairs(def) do DecorationTypes.register(d) end else DecorationTypes.register(def) end
end

return { types = DecorationTypes }
