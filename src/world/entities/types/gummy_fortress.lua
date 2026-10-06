-- GUMMY DE LA FORTALEZA: el MISMO Gummy (movimiento, pausas, alas, casco, reglas) con OTRA FORMA — una especie distinta, no
-- un cambio de color —: assets/images/gummy_fortress/ (tools/ui/make_variant_skins.py --apply; mapas de píxeles en
-- tools/ui/make_enemy_designs.py, 3ª ronda, versión elegida por el usuario).
local Entity = require 'src/world/entities/Entity'
local base   = require 'src/world/entities/types/gummy'
local Gummy  = base.class

local GummyFortress = Entity.extend(Gummy, { debugColor = { 0.7, 0.75, 0.8 } })
GummyFortress.artDir = 'assets/images/gummy_fortress/'
function GummyFortress.loadAssets() Gummy.loadAssets(); Gummy.loadArt(GummyFortress.artDir) end

local def = {}
for k, v in pairs(base) do def[k] = v end
def.name, def.label = 'gummy_fortress', 'Gummy de la fortaleza'
def.description = 'Gummy de cuerda (acero con remaches y una llave de latón que gira al andar) para la isla de la fortaleza: igual que el Gummy.'
def.class = GummyFortress
def.editor = { sprite = 'assets/images/gummy_fortress/gummy.png' }
return def
