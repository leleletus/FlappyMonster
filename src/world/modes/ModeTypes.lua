-- src/world/modes/ModeTypes.lua
-- Registro de MODOS DE JUEGO (objetivos de una ronda online). Cada modo es un
-- archivo en src/world/modes/ listado en src/world/Modes.lua. El servidor
-- ejecuta sus reglas (autoritativo); el cliente usa sus textos y colores.
--
-- Definición de un modo:
--   id, label, tagline         identificador, nombre visible y objetivo en una línea
--   color                      color de acento en menús/HUD
--   icon                       icono pixel art (PixelIcons) para menús
--   emptyHint                  ayuda si no hay niveles para el modo (menú de la sala)
--   objective                  objetivo en una frase: panel fijo arriba durante la partida
--   hudLine(md) -> texto, urgente, grande
--                              línea de estado de ese panel a partir del hud del servidor
--                              (urgente = en rojo; grande = número gigante debajo)
--   requires(info) -> ok, why  ¿el nivel sirve? info = { enemies, killable, finish, bosses,
--                              autoScroll, pointAreas }. Un nivel puede además limitar sus
--                              modos con "modes": [...] en su JSON (editor: pestaña Nivel).
--   triggers                   lista de triggers de tile que le interesan ('finish'...)
--   start(m)                   al empezar la ronda
--   onTrigger(m, ps, name)     un jugador tocó un tile con ese trigger
--   onStomp(m, ps, enemy)      un jugador pisoteó a una entidad
--   tick(m, dt) -> reason|nil  devuelve un motivo para terminar la ronda
--   rank(m, entries, reason)   ordena la clasificación y marca .winner.
--                              Puede devolver (nota, empate): nota = texto
--                              de desempate para la pantalla final; empate =
--                              true si varios comparten la victoria.
--   reasonText(reason)         texto del motivo de fin para la pantalla final
--   hud(m) -> tabla            datos extra que el servidor manda cada snapshot
--
-- `m` (match) lo crea el servidor: m.players (playerSims), m.enemies, m.time,
-- m.level, m.event(ev) para emitir eventos, m.data (estado libre del modo).

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

-- ¿El modo usa los bloques con este trigger (p. ej. 'finish')? Los que no,
-- no se dibujan en la partida ni en las miniaturas (una meta en Cacería
-- confundía: parece el objetivo y no hace nada).
function ModeTypes.usesTrigger(mode, name)
    for _, tr in ipairs(mode and mode.triggers or {}) do if tr == name then return true end end
    return false
end

-- Triggers de tile que un modo NO usa: { finish = true, ... }
function ModeTypes.hiddenTriggers(mode)
    local hide = {}
    for _, name in ipairs({ 'finish' }) do
        if not ModeTypes.usesTrigger(mode, name) then hide[name] = true end
    end
    return hide
end

-- Motivos genéricos de fin (los modos pueden añadir los suyos)
ModeTypes.GENERIC_REASONS = {
    all_out    = 'Todos los jugadores quedaron fuera',
    time_limit = 'Se acabó el tiempo del nivel',
    last_standing = '¡El último superviviente en pie!',
}

return ModeTypes
