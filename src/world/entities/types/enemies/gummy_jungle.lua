-- Gummy DE LA JUNGLA (isla de la jungla): el MISMO Gummy (movimiento, pausas, alas, casco, reglas) con su arte de rana
-- de árbol — verde hoja, ojos saltones encima de la cabeza, motas en el lomo y patitas naranjas —:
-- assets/images/enemies/gummy_jungle/ (tools/art/enemies/make_jungle_skins.py --apply; propuesta aprobada por el usuario).
local Entity = require 'src/world/entities/base/Entity'
local base   = require 'src/world/entities/types/enemies/gummy'
local Gummy  = base.class

local GummyJungle = Entity.extend(Gummy, { debugColor = { 0.4, 0.8, 0.3 } })
GummyJungle.artDir = 'assets/images/enemies/gummy_jungle/'
function GummyJungle.loadAssets() Gummy.loadAssets(); Gummy.loadArt(GummyJungle.artDir) end

local def = {}
for k, v in pairs(base) do def[k] = v end
def.name, def.label = 'gummy_jungle', 'Gummy de la jungla'
def.description = 'Gummy rana de árbol para la isla de la jungla: igual que el Gummy (camina, vuela, casco...).'
def.class = GummyJungle
def.editor = { sprite = 'assets/images/enemies/gummy_jungle/gummy.png' }
return def
