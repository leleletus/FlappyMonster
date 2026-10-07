-- GUMMY DE CUEVA: el MISMO Gummy (movimiento, pausas, alas, casco, reglas) con OTRA FORMA — una especie distinta, no
-- un cambio de color —: assets/images/enemies/gummy_cave/ (tools/ui/make_variant_skins.py --apply; mapas de píxeles en
-- tools/ui/make_enemy_designs.py, 3ª ronda, versión elegida por el usuario).
local Entity = require 'src/world/entities/base/Entity'
local base   = require 'src/world/entities/types/enemies/gummy'
local Gummy  = base.class

local GummyCave = Entity.extend(Gummy, { debugColor = { 0.8, 0.7, 0.9 } })
GummyCave.artDir = 'assets/images/enemies/gummy_cave/'
GummyCave.helmetDy = 5           -- (su cabeza queda 5 px de arte más abajo que la del Gummy: el casco baja con ella)
function GummyCave.loadAssets() Gummy.loadAssets(); Gummy.loadArt(GummyCave.artDir) end

local def = {}
for k, v in pairs(base) do def[k] = v end
def.name, def.label = 'gummy_cave', 'Gummy de cueva'
def.description = 'Gummy de las cuevas, ancho y bajito, con un cristal en la cabeza: igual que el Gummy (camina, vuela, casco...).'
def.class = GummyCave
def.editor = { sprite = 'assets/images/enemies/gummy_cave/gummy.png' }
return def
