-- Aspectos de los pinchos (solo dibujo): el nivel elige uno con "spikeSkin" en su JSON
-- (editor: Nivel → Fondo y clima → Pinchos). Lo usan los pinchos de casilla (Level) y los
-- pinchos que caen (spikefall / rainspike). Un aspecto nuevo = un PNG + una línea en LIST.
local SpikeSkins = {}

SpikeSkins.LIST = {
    { id = 'normal', label = 'Normales', file = 'assets/images/spikes/spike.png' },
    { id = 'ice',    label = 'De hielo', file = 'assets/images/spikes/spike_ice.png' },  -- (tools/ui/make_ice_spikes.py)
}
local byId = {}
for _, s in ipairs(SpikeSkins.LIST) do byId[s.id] = s end

local cache = {}
-- Imagen de la púa (hacia arriba) del aspecto `id` (nil o desconocido = normal)
function SpikeSkins.image(id)
    local s = byId[id or 'normal'] or byId.normal
    local img = cache[s.id]
    if not img then
        img = love.graphics.newImage(s.file)
        if img.setFilter then img:setFilter('nearest', 'nearest') end
        cache[s.id] = img
    end
    return img
end

-- Aspecto de un nivel (nil = normal)
function SpikeSkins.of(level) return level and byId[level.spikeSkin or ''] and level.spikeSkin or nil end

return SpikeSkins
