-- src/story/Worlds.lua
-- EL MODO HISTORIA, como datos: los MUNDOS en orden y, dentro de cada uno, sus niveles en orden
-- (del más fácil al más difícil) con su JEFE al final. Reordenar el juego = tocar esta tabla.
--   id      identificador del mundo (su nombre: clave de idioma `story.world.<id>`)
--   levels  niveles (nombre del archivo sin .json), en orden
--   boss    el nivel del jefe: el último nodo del mundo; al superarlo se abre el mundo siguiente
--   bonus   nivel OPCIONAL del mundo: una arena de Rey de la Colina contra el bot (src/story/BonusMatch.lua); se
--           abre al vencer al jefe; no cuenta para el progreso ni para abrir el mundo siguiente
--   outros  CARRERAS QUE ENLAZAN (solo en la historia): { [nivel] = columna }: ese nivel no acaba en la meta sino en una
--           escena dentro de él a partir de esa columna de la cámara (src/story/RunOut.lua) y pasa directamente al nodo
--           siguiente (su película, si tiene, y él), sin resultados ni mapa por medio
--   secrets NIVELES SECRETOS del mundo, en orden: { { level, from, exit, after, collect }, ... }. En el mapa, un nodo
--           ROJO con cerradura y un camino que sale del nodo `from` (un nivel del mundo, 'bonus' u otro secreto; el
--           dibujo del camino: assets/story/overworld.json `secrets`, tools/art/story/make_overworld.py). Cerrado NO
--           EXISTE en el mapa (ni nodo ni camino ni parada). Se abre con TODO lo que pida:
--             exit = true    haber usado la SALIDA SECRETA del nivel `from` (tile `secret_exit`; la partida lo apunta en
--                            `found[level]` al terminar el nivel por ella: Run.findSecret)
--             after = { … }  esos niveles superados
--             collect = kind tener (en cualquier estado) todos los coleccionables de ese tipo (src/story/Collect.lua)
--             scene = id     haber visto esa ESCENA del mapa, que se pone sola cuando todo lo demás se cumple
--                            (src/states/story/StoryMapScenes.lua: el robo de las astillas, los tres que crecen)
--           Son OPCIONALES: no cuentan para el progreso ni para abrir el mundo siguiente; se pueden repetir. Su jefe suelta
--           su coleccionable (assets/story/collectibles.json). Un secreto nuevo = una línea aquí, su camino en el
--           generador del mapa y, si da algo, su entrada en collectibles.json
--   epilogue { after = nivel, scene = id }: la ESCENA del mapa que se ve al volver tras superar ese nivel (el final
--           de verdad, tras el Mega Mashup: StoryMapScenes)
--   films   CINEMÁTICAS de antes de un nivel: { [nivel] = película (assets/story/films.json) }; se ven la
--           primera vez que se entra en él (la partida apunta las vistas: `films`)
-- Todo nivel de la historia necesita META (los de solo Cazamonstruos no la tienen).
-- Orden (etapa 7): cada mundo agrupa los niveles de SU ambiente (las islas del mapa) y dentro van del más fácil al
-- más difícil, según los datos (enemigos y pinchos por casilla de ancho, mecánicas nuevas primero; cámara
-- automática, laberintos, a oscuras y muy altos al final) y lo que diga el usuario al jugarlos.
local Worlds = {}

Worlds.LIST = {
    -- 1 La Pradera: lo básico; luego bombas e interruptores
    { id = 'pradera',   levels = { 'valle_soleado', 'pradera_explosiva', 'bosque_interruptores' },                           boss = 'reino_gummy', bonus = 'isla_flotante' },
    -- 2 La Costa: trampolines y agua; del más suelto al más denso, y el arrecife (bucear) al final
    { id = 'costa',     levels = { 'playa_rebotes', 'jungla_colgante', 'canon_trampolines', 'arrecife_globo' },              boss = 'cala_resaca', bonus = 'cala_de_los_muelles',     -- (Pez Globo Gigante)
      secrets = { { level = 'guarida_cangrejo_rey', from = 'arrecife_globo', exit = true } } },   -- (el Mega Crabby, jefe secreto: por la salida secreta del arrecife)
    -- 3 La Jungla (0.5.99): dos pisos a la vez, el río que se cruza dos veces, el templo de tres alas y la estampida
    -- (cámara automática) hasta el templo del Escarabajo Gigante
    { id = 'jungla',    levels = { 'senda_del_dosel', 'rio_revuelto', 'templo_de_los_pesos', 'la_estampida' },        boss = 'templo_escarabajo', bonus = 'claro_de_la_balanza' },
    -- 4 La Fortaleza: morteros y bombas primero; luego el taller denso y el tren (cámara automática)
    { id = 'fortaleza', levels = { 'fabrica_morteros', 'cantera_dinamita', 'taller_trampas', 'tren_fugaz' },               boss = 'fortaleza_malvada', bonus = 'ciudadela_alterna' },
    -- 5 Las Montañas Heladas: las cumbres, el teleférico, la torre (subir) y la ladera del alud (bajar) hasta el lago de
    -- la Gran Bola de Nieve (0.5.100: la isla helada partida en dos; 0.5.102: sus niveles nuevos y el bonus)
    { id = 'nieve',     levels = { 'cumbres_escarcha', 'el_teleferico', 'torre_viento', 'ladera_del_alud' },          boss = 'lago_helado', bonus = 'la_cima' },
    -- 6 La Costa Helada: la fábrica que congela el mar, los témpanos, la bahía de las mareas y bajo el hielo hasta el
    -- glaciar del Mega Crabby helado
    { id = 'costa_helada', levels = { 'fabrica_criogenica', 'tempanos_a_la_deriva', 'bahia_de_las_mareas', 'bajo_el_hielo' }, boss = 'glaciar_cangrejo', bonus = 'lago_de_cristal' },
    -- 7 Las Cuevas: cristal, los dos laberintos de agua y el templo a oscuras justo antes del jefe a oscuras
    { id = 'cuevas',    levels = { 'cavernas_cristal', 'nivel01', 'laberinto_submarino', 'templo_del_eco' },             boss = 'gruta_del_farol', bonus = 'cripta_del_silencio',   -- (Saltarín Gigante)
      secrets = { { level = 'gruta_lugubre', from = 'templo_del_eco', exit = true } } },       -- (el Mega Crabby lúgubre: por la salida secreta del templo)
    -- 8 El Final (el volcán): lava; la lluvia de pinchos (cámara automática) es la erupción, antes del Espejo
    { id = 'final',     levels = { 'carrera01', 'caldera_roja', 'lluvia_pinchos', 'huida_del_espejo' },                                       boss = 'ruta_del_espejo', bonus = 'cantera_real',
      -- (el Groove: vencido el Espejo y con TODAS las astillas; luego el Mega Mashup, el final de verdad, en su isla)
      -- (los dos se abren con su escena del mapa: el robo de las astillas, los tres cangrejos que crecen; y tras el
      --  Mashup, el final de verdad)
      secrets = { { level = 'isla_del_groove', from = 'bonus', after = { 'ruta_del_espejo' }, collect = 'splinter', scene = 'groove' },
                  { level = 'mashup_cangrejos', from = 'isla_del_groove', after = { 'isla_del_groove' }, scene = 'regrow' } },
      epilogue = { after = 'mashup_cangrejos', scene = 'disco' },
      -- (un nivel secreto también puede tener la suya: `mashup_cangrejos = '<película>'` — pendiente de la decisión
      --  del usuario sobre la escena de antes del Mega Mashup —; la ve la primera vez que entra, como cualquier otro)
      films = { huida_del_espejo = 'chase', ruta_del_espejo = 'lair' },      -- (la emboscada; la guarida)
      outros = { huida_del_espejo = 182 } },                                  -- (la huida sigue en la guarida)
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

-- Los nodos SECRETOS de un mundo, en orden: { { id, secret = true, def = su entrada de `secrets` }, ... }
function Worlds.secrets(w)
    local W = Worlds.LIST[w]
    if not W then return {} end
    if not W._secrets then
        W._secrets = {}
        for _, e in ipairs(W.secrets or {}) do W._secrets[#W._secrets + 1] = { id = e.level, secret = true, def = e } end
    end
    return W._secrets
end

-- Todas las entradas `secrets` del juego (con `world` = su mundo)
function Worlds.allSecrets()
    local out = {}
    for w, W in ipairs(Worlds.LIST) do
        for _, e in ipairs(W.secrets or {}) do e.world = w; out[#out + 1] = e end
    end
    return out
end

-- El secreto al que lleva la SALIDA SECRETA del nivel `id` (su entrada de `secrets`, con `exit`) o nil
function Worlds.secretExitOf(id)
    for _, e in ipairs(Worlds.allSecrets()) do
        if e.exit and e.from == id then return e end
    end
    return nil
end

-- ¿Es `id` un nivel secreto? → su entrada (o nil)
function Worlds.secretOf(id)
    for _, e in ipairs(Worlds.allSecrets()) do if e.level == id then return e end end
    return nil
end

-- La película de antes del nivel `id` (o nil)
function Worlds.film(id)
    for _, W in ipairs(Worlds.LIST) do
        if W.films and W.films[id] then return W.films[id] end
    end
    return nil
end

-- La escena final de un nivel que enlaza con el siguiente: { col } (o nil)
function Worlds.outro(id)
    for _, W in ipairs(Worlds.LIST) do
        if W.outros and W.outros[id] then return { col = W.outros[id] } end
    end
    return nil
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
    return names[id] and require('src/core/Lang').localName(names[id]) or id
end

return Worlds
