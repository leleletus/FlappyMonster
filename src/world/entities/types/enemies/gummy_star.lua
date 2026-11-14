-- Gummy ESTELAR (isla estelar: la Vía Estelar): el MISMO Gummy (movimiento, pausas, alas, casco, reglas) en lavanda
-- pálido: assets/images/enemies/gummy_star/ (tools/art/enemies/make_star_isle.py --apply).
local Entity = require 'src/world/entities/base/Entity'
local base   = require 'src/world/entities/types/enemies/gummy'
local Gummy  = base.class

local GummyStar = Entity.extend(Gummy, { debugColor = { 0.75, 0.7, 0.95 } })
GummyStar.artDir = 'assets/images/enemies/gummy_star/'
function GummyStar.loadAssets() Gummy.loadAssets(); Gummy.loadArt(GummyStar.artDir) end

local def = {}
for k, v in pairs(base) do def[k] = v end
def.name, def.label = 'gummy_star', 'Gummy estelar'
def.description = 'Gummy lavanda para la isla estelar (Vía Estelar): igual que el Gummy (camina, vuela, casco...).'
def.class = GummyStar
def.editor = { sprite = 'assets/images/enemies/gummy_star/gummy.png' }
return def
