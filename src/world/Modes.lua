-- src/world/Modes.lua
-- Catálogo de modos de juego online (objetivos de la ronda).
--
-- ── Añadir un modo nuevo (receta) ────────────────────────────────────────────
--  1. Crea src/world/modes/<id>.lua con sus reglas (ver modes/ModeTypes.lua):
--     qué necesita el nivel, cuándo termina la ronda y cómo se clasifica.
--  2. Añade su id a TYPES abajo.
--  Listo: el host lo puede elegir en la sala, el servidor aplica sus reglas y
--  al terminar se muestra la pantalla de resultados genérica.

local ModeTypes = require 'src/world/modes/ModeTypes'

local TYPES = { 'hunt', 'race' }

for _, id in ipairs(TYPES) do
    ModeTypes.register(require('src/world/modes/' .. id))
end

ModeTypes.DEFAULT = 'hunt'
return ModeTypes
