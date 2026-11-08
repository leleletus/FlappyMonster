-- src/flappy/Zones.lua
-- LA CAMPAÑA FLAPPY, como datos (docs/design/flappy-prequel.md): las ZONAS en orden y, dentro de cada una, sus
-- etapas en orden con su JEFE (una máquina del Evil Monster) al final. Reordenar o añadir = tocar esta tabla.
--   id      identificador de la zona (su nombre: clave de idioma `flappy.zone.<id>`)
--   stages  etapas (nombre del archivo de assets/levels sin .json; niveles con "flappy": true), en orden
--   boss    la etapa del jefe (falta mientras no exista: la zona acaba en su última etapa)
--   food    la COMIDA de la zona (types/items/apple.lua: el aspecto 'auto' en sus etapas)
-- Los ids de las etapas van en las partidas: nunca se renombran.
local Zones = {}

Zones.LIST = {
    -- 1 El Valle de los Pilares: el hogar; las tuberías de siempre son sus pilares (Plan 3: dos etapas provisionales)
    { id = 'valle', stages = { 'valle_pilares_1', 'valle_pilares_2' }, food = 'valle' },
}

function Zones.count() return #Zones.LIST end
function Zones.get(z) return Zones.LIST[z] end

-- Los nodos de la zona en orden: sus etapas y, al final, su jefe → { { id = etapa }, ... }
function Zones.nodes(z)
    local Z = Zones.LIST[z]
    if not Z then return {} end
    local out = {}
    for _, id in ipairs(Z.stages) do out[#out + 1] = { id = id } end
    if Z.boss then out[#out + 1] = { id = Z.boss, boss = true } end
    return out
end

function Zones.path(id) return 'assets/levels/' .. id .. '.json' end

-- La zona y el índice del nodo de una etapa (nil si no es de la campaña)
function Zones.find(id)
    for z = 1, #Zones.LIST do
        for k, n in ipairs(Zones.nodes(z)) do if n.id == id then return z, k end end
    end
end

return Zones
