-- Gummy DE MAGMA (isla del volcán): el MISMO Gummy (movimiento, pausas, alas, casco, reglas) con su arte de roca
-- encendida: assets/images/gummy_magma/ (tools/ui/make_variant_skins.py --apply; opción A "Brasa" elegida por el
-- usuario: roca oscura con grietas, ojos y boca al rojo).
local Entity = require 'src/world/entities/base/Entity'
local base   = require 'src/world/entities/types/enemies/gummy'
local Gummy  = base.class

local GummyMagma = Entity.extend(Gummy, { debugColor = { 1, 0.5, 0.2 } })
GummyMagma.artDir = 'assets/images/gummy_magma/'
GummyMagma.darkEdge = { 1, 0.8, 0.55, 0.9 }      -- (roca oscura: en lo oscuro lleva un filo fino; EntityTypes / Silhouette)
function GummyMagma.loadAssets() Gummy.loadAssets(); Gummy.loadArt(GummyMagma.artDir) end

local def = {}
for k, v in pairs(base) do def[k] = v end
def.name, def.label = 'gummy_magma', 'Gummy de magma'
def.description = 'Gummy de roca encendida para la isla del volcán: igual que el Gummy (camina, vuela, casco...).'
def.class = GummyMagma
def.editor = { sprite = 'assets/images/gummy_magma/gummy.png' }
return def
