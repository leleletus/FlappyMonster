-- src/story/Worlds.lua
-- EL MODO HISTORIA, como datos: los MUNDOS en orden y, dentro de cada uno, sus niveles en orden
-- (del más fácil al más difícil) con su JEFE al final. Reordenar el juego = tocar esta tabla.
--   id      identificador del mundo (su nombre: clave de idioma `story.world.<id>`)
--   levels  niveles (nombre del archivo sin .json), en orden
--   boss    el nivel del jefe: el último nodo del mundo; al superarlo se abre el mundo siguiente
--   bonus   nivel OPCIONAL del mundo: una arena de Rey de la Colina contra el bot (src/story/BonusMatch.lua); se
--           abre al vencer al jefe; no cuenta para el progreso ni para abrir el mundo siguiente
-- Todo nivel de la historia necesita META (los de solo Cazamonstruos no la tienen).
-- Orden (etapa 7): cada mundo agrupa los niveles de SU ambiente (las islas del mapa) y dentro van del más fácil al
-- más difícil, según los datos (enemigos y pinchos por casilla de ancho, mecánicas nuevas primero; cámara
-- automática, laberintos, a oscuras y muy altos al final) y lo que diga el usuario al jugarlos.
local Worlds = {}

Worlds.LIST = {
    -- 1 La Pradera: lo básico; luego bombas e interruptores
    { id = 'pradera',   levels = { 'valle_soleado', 'pradera_explosiva', 'bosque_interruptores' },                           boss = 'reino_gummy', bonus = 'isla_flotante' },
    -- 2 La Costa: trampolines y agua; del más suelto al más denso, y el arrecife (bucear) al final
    { id = 'costa',     levels = { 'playa_rebotes', 'jungla_colgante', 'canon_trampolines', 'arrecife_globo' },              boss = 'guarida_cangrejo_rey', bonus = 'cala_de_los_muelles' },
    -- 3 La Fortaleza: morteros y bombas primero; luego el taller denso y el tren (cámara automática)
    { id = 'fortaleza', levels = { 'fabrica_morteros', 'cantera_dinamita', 'taller_trampas', 'tren_fugaz' },               boss = 'fortaleza_malvada', bonus = 'ciudadela_alterna' },
    -- 4 Las Cumbres: nieve y congeladores; la Bola de Nieve a media isla; la torre (subir) antes del jefe
    { id = 'nieve',     levels = { 'cumbres_escarcha', 'fabrica_criogenica', 'lago_helado', 'torre_viento' },              boss = 'glaciar_cangrejo', bonus = 'lago_de_cristal' },
    -- 5 Las Cuevas: cristal, los dos laberintos de agua y el templo a oscuras justo antes del jefe a oscuras
    { id = 'cuevas',    levels = { 'cavernas_cristal', 'nivel01', 'laberinto_submarino', 'templo_del_eco' },             boss = 'gruta_lugubre', bonus = 'cripta_del_silencio' },
    -- 6 El Final (el volcán): lava; la lluvia de pinchos (cámara automática) es la erupción, antes del Espejo
    { id = 'final',     levels = { 'carrera01', 'caldera_roja', 'lluvia_pinchos' },                                       boss = 'ruta_del_espejo', bonus = 'cantera_real' },
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

-- El nodo bonus de un mundo ({ id, bonus = true }) o nil
function Worlds.bonus(w)
    local W = Worlds.LIST[w]
    if not (W and W.bonus) then return nil end
    W._bonus = W._bonus or { id = W.bonus, bonus = true }
    return W._bonus
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
