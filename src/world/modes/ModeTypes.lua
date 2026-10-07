-- src/world/modes/ModeTypes.lua
-- Registro de MODOS DE JUEGO (objetivos de una ronda online). Cada modo es un
-- archivo en src/world/modes/ listado en src/world/modes/Modes.lua. El servidor
-- ejecuta sus reglas (autoritativo); el cliente usa sus textos y colores.
--
-- Definición de un modo:
--   id                         identificador
--   color                      color de acento en menús/HUD
--   icon                       icono pixel art (PixelIcons) para menús
--   Textos (en assets/lang, claves mode.<id>.<campo>; se leen como m.label etc.
--   y salen en el idioma actual):
--     label (mode.<id>.label)          nombre visible
--     tagline (.tagline)               objetivo en una línea (menús)
--     objective (.objective)           objetivo en una frase: panel fijo arriba en la partida
--     emptyHint (.empty_hint)          ayuda si no hay niveles para el modo (opcional)
--   hudLine(md) -> texto, urgente, grande
--                              línea de estado de ese panel a partir del hud del servidor
--                              (urgente = en rojo; grande = número gigante debajo)
--   requires(info) -> ok, why  ¿el nivel sirve? info = { enemies, killable, finish, bosses,
--                              autoScroll, pointAreas, respawning } (ver ModeTypes.entityInfo). Un nivel puede además limitar sus
--                              modos con "modes": [...] en su JSON (editor: pestaña Nivel).
--   triggers                   lista de triggers de tile que le interesan ('finish'...)
--   start(m)                   al empezar la ronda
--   onTrigger(m, ps, name)     un jugador tocó un tile con ese trigger
--   onStomp(m, ps, enemy)      un jugador pisoteó a una entidad
--   tick(m, dt) -> reason|nil  devuelve un motivo para terminar la ronda
--   rank(m, entries, reason)   ordena la clasificación y marca .winner.
--                              Puede devolver (nota, empate): nota = CLAVE de
--                              idioma del desempate para la pantalla final;
--                              empate = true si varios comparten la victoria.
--   reasonText(reason)         CLAVE de idioma del motivo de fin (pantalla final)
--   (los textos que dependen del jugador, hudLine y el `why` de requires, usan L())
--   hud(m) -> tabla            datos extra que el servidor manda cada snapshot
--
-- `m` (match) lo crea el servidor: m.players (playerSims), m.enemies, m.time,
-- m.level, m.event(ev) para emitir eventos, m.data (estado libre del modo).

local Lang = require 'src/core/Lang'

local ModeTypes = { byId = {}, list = {} }

-- Campos de texto -> sufijo de su clave de idioma (mode.<id>.<sufijo>)
local TEXT_FIELDS = { label = 'label', tagline = 'tagline', objective = 'objective',
                      emptyHint = 'empty_hint' }
local textMeta = { __index = function(m, k)
    local suffix = TEXT_FIELDS[k]
    if not suffix then return nil end
    local key = 'mode.' .. rawget(m, 'id') .. '.' .. suffix
    if Lang.has(key) then return Lang(key) end
    if k == 'label' then return rawget(m, 'id') end
    if k == 'tagline' then return '' end
end }

local function noop() end

function ModeTypes.register(def)
    assert(type(def) == 'table' and type(def.id) == 'string', "modo sin id")
    assert(not ModeTypes.byId[def.id], "modo duplicado: " .. def.id)
    local m = {}
    for k, v in pairs(def) do m[k] = v end
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
    setmetatable(m, textMeta)
    ModeTypes.byId[m.id] = m
    table.insert(ModeTypes.list, m)
    return m
end

function ModeTypes.get(id) return ModeTypes.byId[id] end

-- Recuento de las entidades de un nivel para `requires(info)` (lo usan el
-- servidor, el editor y las pruebas: un solo cálculo). `list` = colocaciones
-- normalizadas ({type, props}). respawning = enemigos pisoteables que reaparecen.
function ModeTypes.entityInfo(list)
    local ET = require 'src/world/entities/base/EntityTypes'
    local info = { enemies = #list, killable = 0, bosses = 0, pointAreas = 0, respawning = 0 }
    for _, e in ipairs(list) do
        local t, p = ET.get(e.type), e.props or {}
        if p.stompable then
            info.killable = info.killable + 1
            if (p.respawn or 0) > 0 then info.respawning = info.respawning + 1 end
        end
        if t and t.boss then info.bosses = info.bosses + 1 end
        if e.type == 'pointarea' then info.pointAreas = info.pointAreas + 1 end
    end
    return info
end

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

-- Motivos genéricos de fin (los modos pueden añadir los suyos): claves de idioma
ModeTypes.GENERIC_REASONS = {
    all_out       = 'mode.reason.all_out',
    time_limit    = 'mode.reason.time_limit',
    last_standing = 'mode.reason.last_standing',
}

-- Texto (idioma actual) del motivo de fin de ronda
function ModeTypes.reasonText(mode, reason)
    local key = (mode and mode.reasonText(reason)) or ModeTypes.GENERIC_REASONS[reason]
    return key and Lang(key) or ''
end

return ModeTypes
