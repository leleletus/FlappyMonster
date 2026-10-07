-- Gummy HELADO (niveles helados): el MISMO Gummy (movimiento, pausas, alas, casco, reglas) con
-- su arte de hielo: assets/images/gummy_ice/ (tools/ui/make_gummy_variants.py --apply-helado,
-- opción A "Escarcha" sin carámbanos: la forma exacta del Gummy en hielo con nieve en la cabeza).
local Entity = require 'src/world/entities/base/Entity'
local base   = require 'src/world/entities/types/enemies/gummy'
local Gummy  = base.class

local GummyIce = Entity.extend(Gummy, { debugColor = { 0.5, 0.8, 1 } })
GummyIce.artDir = 'assets/images/gummy_ice/'
function GummyIce.loadAssets() Gummy.loadAssets(); Gummy.loadArt(GummyIce.artDir) end

local def = {}
for k, v in pairs(base) do def[k] = v end
def.name, def.label = 'gummy_ice', 'Gummy helado'
def.description = 'Gummy de hielo para los niveles helados: igual que el Gummy (camina, vuela, casco...).'
def.class = GummyIce
def.editor = { sprite = 'assets/images/gummy_ice/gummy.png' }
return def
