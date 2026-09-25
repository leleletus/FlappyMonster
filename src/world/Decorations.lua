-- src/world/Decorations.lua
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
--  2. Añade su nombre a TYPES abajo.
--  Listo: aparece en la capa Decoracion del editor (con Espejar y Capa
--  delante/detras) y el juego la dibuja y anima.
-- Campos completos: src/world/decorations/DecorationTypes.lua

local DecorationTypes = require 'src/world/decorations/DecorationTypes'

local TYPES = { 'tulip', 'stretch', 'palmtree' }

for _, name in ipairs(TYPES) do
    DecorationTypes.register(require('src/world/decorations/types/' .. name))
end

return { types = DecorationTypes }
