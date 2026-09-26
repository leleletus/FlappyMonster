-- src/world/modes/ModeTypes.lua
-- Registro de MODOS DE JUEGO (objetivos de una ronda online). Cada modo es un
-- archivo en src/world/modes/ listado en src/world/Modes.lua. El servidor
-- ejecuta sus reglas (autoritativo); el cliente usa sus textos y colores.
--
-- Definición de un modo:
--   id, label, tagline         identificador, nombre visible y objetivo en una línea
--   color                      color de acento en menús/HUD
--   icon                       icono pixel art (PixelIcons) para menús
--   requires(info) -> ok, why  ¿el nivel sirve? info = { enemies, killable, finish }
--   triggers                   lista de triggers de tile que le interesan ('finish'...)
--   start(m)                   al empezar la ronda
--   onTrigger(m, ps, name)     un jugador tocó un tile con ese trigger
--   onStomp(m, ps, enemy)      un jugador pisoteó a una entidad
--   tick(m, dt) -> reason|nil  devuelve un motivo para terminar la ronda
--   rank(m, entries, reason)   ordena la clasificación y marca .winner
--   reasonText(reason)         texto del motivo de fin para la pantalla final
--   hud(m) -> tabla            datos extra que el servidor manda cada snapshot
--
-- `m` (match) lo crea el servidor: m.players (playerSims), m.enemies, m.time,
-- m.event(ev) para emitir eventos, m.data (estado libre del modo).

local ModeTypes = { byId = {}, list = {} }

local function noop() end

function ModeTypes.register(def)
    assert(type(def) == 'table' and type(def.id) == 'string', "modo sin id")
    assert(not ModeTypes.byId[def.id], "modo duplicado: " .. def.id)
    local m = {}
    for k, v in pairs(def) do m[k] = v end
    m.label      = m.label or m.id
    m.tagline    = m.tagline or ''
    m.color      = m.color or { 1, 0.85, 0.2 }
    m.triggers   = m.triggers or {}
    m.requires   = m.requires or function() return true end
    m.start      = m.start or noop
    m.onTrigger  = m.onTrigger or noop
    m.onStomp    = m.onStomp or noop
    m.tick       = m.tick or noop
    m.hud        = m.hud or function() return nil end
    m.reasonText = m.reasonText or function() return '' end
    m.rank       = m.rank or function(_, entries)
        table.sort(entries, function(a, b) return a.score > b.score end)
    end
    ModeTypes.byId[m.id] = m
    table.insert(ModeTypes.list, m)
    return m
end

function ModeTypes.get(id) return ModeTypes.byId[id] end

-- Motivos genéricos de fin (los modos pueden añadir los suyos)
ModeTypes.GENERIC_REASONS = {
    all_out    = 'Todos los jugadores quedaron fuera',
    time_limit = 'Se acabó el tiempo del nivel',
}

return ModeTypes
