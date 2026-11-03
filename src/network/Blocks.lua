-- src/network/Blocks.lua
-- JUGADORES BLOQUEADOS (modo online): una lista de nombres en este aparato (src/core/Settings.lua: options.cfg). El nombre
-- de un bloqueado no se ve en ninguna pantalla (sala, partida, resultados, el ranking del Mega Mashup): sale
-- `room.blocked_name`. Bloquear no avisa a nadie ni lo saca de la sala (eso es del admin: expulsar / banear); para lo
-- grave está DENUNCIAR (el servidor lo apunta: server/srv/lobby.lua `report_player`).
local Settings = require 'src/core/Settings'
local L        = require 'src/core/Lang'

local Blocks = {}

local function key(name) return tostring(name or ''):lower() end

function Blocks.has(name)
    local k = key(name)
    for _, b in ipairs(Settings.blocked or {}) do if b == k then return true end end
    return false
end

-- Bloquea o desbloquea; devuelve si queda bloqueado
function Blocks.toggle(name)
    local k, list = key(name), Settings.blocked
    for i, b in ipairs(list) do
        if b == k then table.remove(list, i); Settings.save(); return false end
    end
    list[#list + 1] = k
    Settings.save()
    return true
end

-- El nombre que se enseña
function Blocks.show(name)
    if name and Blocks.has(name) then return L('room.blocked_name') end
    return name
end

return Blocks
