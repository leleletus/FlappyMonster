-- src/world/powerups/Powerups.lua
-- El CATÁLOGO de POWER-UPS (docs/design/powerups.md; sistema: docs/gameplay/powerups.md), como datos: un archivo por
-- power-up en esta carpeta y su nombre en LIST (ese orden es el de la rueda rápida y el de los iconos de
-- assets/images/ui/powerups/icons-Sheet.png, tools/art/ui/make_powerups.py). Los ids van en las partidas: nunca se
-- renombran. Cada uno: { id, modes = { 'flappy', 'adventure' }, duration = s (los que duran) | nil, icon = cuadro }.
-- Lo que HACEN vive en el jugador (src/player/PlayerAdventure.lua: usePowerup / canUse / effects).
local Powerups = { LIST = {}, byId = {} }

local NAMES = { 'shield', 'heart', 'strength', 'magnet_points', 'magnet_items', 'magnet_all', 'small', 'ghost' }

for i, name in ipairs(NAMES) do
    local def = require('src/world/powerups/' .. name)
    def.icon = def.icon or i
    Powerups.LIST[#Powerups.LIST + 1] = def
    Powerups.byId[def.id] = def
end

function Powerups.get(id) return Powerups.byId[id] end

-- Los de un modo ('flappy' | 'adventure'), en el orden del catálogo
function Powerups.forMode(mode)
    local out = {}
    for _, p in ipairs(Powerups.LIST) do
        for _, m in ipairs(p.modes) do if m == mode then out[#out + 1] = p; break end end
    end
    return out
end

return Powerups
