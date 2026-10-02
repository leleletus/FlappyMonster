-- src/story/Worlds.lua
-- EL MODO HISTORIA, como datos: los MUNDOS en orden y, dentro de cada uno, sus niveles en orden
-- (del más fácil al más difícil) con su JEFE al final. Reordenar el juego = tocar esta tabla.
--   id      identificador del mundo (su nombre: clave de idioma `story.world.<id>`)
--   levels  niveles (nombre del archivo sin .json), en orden
--   boss    el nivel del jefe: el último nodo del mundo; al superarlo se abre el mundo siguiente
--   bonus   (más adelante) niveles opcionales: arenas contra el bot
-- Todo nivel de la historia necesita META (los de solo Cazamonstruos no la tienen).
-- El orden de ahora es PROVISIONAL (por ambiente); el definitivo, por dificultad, es la etapa 7.
local Worlds = {}

Worlds.LIST = {
    { id = 'pradera',   levels = { 'valle_soleado', 'pradera_explosiva', 'bosque_interruptores' },                         boss = 'reino_gummy' },
    { id = 'costa',     levels = { 'canon_trampolines', 'playa_rebotes', 'jungla_colgante', 'arrecife_globo' },            boss = 'guarida_cangrejo_rey' },
    { id = 'fortaleza', levels = { 'taller_trampas', 'fabrica_morteros', 'cantera_dinamita', 'lluvia_pinchos', 'tren_fugaz' }, boss = 'fortaleza_malvada' },
    { id = 'nieve',     levels = { 'cumbres_escarcha', 'torre_viento', 'fabrica_criogenica', 'lago_helado' },              boss = 'glaciar_cangrejo' },
    { id = 'cuevas',    levels = { 'cavernas_cristal', 'laberinto_submarino', 'templo_del_eco' },                          boss = 'gruta_lugubre' },
    { id = 'final',     levels = { 'caldera_roja' },                                                                       boss = 'ruta_del_espejo' },
}

function Worlds.count() return #Worlds.LIST end
function Worlds.get(w) return Worlds.LIST[w] end

-- Los nodos de un mundo, en orden: { id, boss = true|nil }
function Worlds.nodes(w)
    local W = Worlds.LIST[w]
    if not W then return {} end
    if not W._nodes then
        W._nodes = {}
        for _, id in ipairs(W.levels) do W._nodes[#W._nodes + 1] = { id = id } end
        if W.boss then W._nodes[#W._nodes + 1] = { id = W.boss, boss = true } end
    end
    return W._nodes
end

function Worlds.path(id) return 'assets/levels/' .. id .. '.json' end

-- Nombre del nivel en el idioma actual (lee la cabecera de su JSON una vez)
local names = {}
function Worlds.levelName(id)
    if names[id] == nil then
        local ok, src = pcall(love.filesystem.read, Worlds.path(id))
        local data = ok and src and select(2, pcall(require('libs/json').decode, src))
        names[id] = type(data) == 'table' and { name = data.name, name_en = data.name_en } or false
    end
    return names[id] and require('src/Lang').localName(names[id]) or id
end

return Worlds
