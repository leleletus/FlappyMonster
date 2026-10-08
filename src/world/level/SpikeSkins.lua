-- Aspectos de los pinchos (solo dibujo): el nivel elige uno con "spikeSkin" en su JSON
-- (editor: Nivel → Fondo y clima → Pinchos). Lo usan los pinchos de casilla (Level) y los
-- pinchos que caen (spikefall / rainspike). Un aspecto nuevo = una animación en el conjunto traps/spikes + una
-- línea en LIST (`file` = su imagen, para iconos).
local SpikeSkins = {}

SpikeSkins.LIST = {
    { id = 'normal', label = 'Normales', anim = 'spike',     file = 'assets/images/traps/spikes/spike.png' },
    { id = 'ice',    label = 'De hielo', anim = 'spike_ice', file = 'assets/images/traps/spikes/spike_ice.png' },  -- (tools/art/world/make_ice_spikes.py)
}
local byId = {}
for _, s in ipairs(SpikeSkins.LIST) do byId[s.id] = s end

local cache = {}
-- Imagen de la púa (hacia arriba) del aspecto `id` (nil o desconocido = normal)
function SpikeSkins.image(id)
    local s = byId[id or 'normal'] or byId.normal
    local img = cache[s.id]
    if not img then
        img = require('src/fx/Anim').image(s.file)
        if img.setFilter then img:setFilter('nearest', 'nearest') end
        cache[s.id] = img
    end
    return img
end

-- DIBUJAR la púa (hacia arriba) del aspecto `id`, como love.graphics.draw: sale de la animación de ese aspecto en
-- assets/anim/traps/spikes.json (`spike`, `spike_ice`…), al ritmo que diga (una púa animada = más cuadros ahí).
local Anim
local function set()
    Anim = Anim or require 'src/fx/Anim'
    return Anim.load('traps/spikes')
end
function SpikeSkins.draw(id, x, y, r, sx, sy)
    local s = byId[id or 'normal'] or byId.normal
    set():drawPx(s.anim, love.timer.getTime(), x, y, r, sx, sy)
end
-- Ancho (px de arte) de la púa de ese aspecto
function SpikeSkins.width(id)
    local s = byId[id or 'normal'] or byId.normal
    return (set():width(s.anim))
end

-- Aspecto de un nivel (nil = normal)
function SpikeSkins.of(level) return level and byId[level.spikeSkin or ''] and level.spikeSkin or nil end

return SpikeSkins
