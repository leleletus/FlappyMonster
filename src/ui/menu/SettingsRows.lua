-- src/ui/menu/SettingsRows.lua
-- Las OPCIONES de la pantalla de configuración como DATOS (0.5.197, docs/design/settings-menu-rework.md): pestañas con
-- filas; SettingsState las coloca y las dibuja. Una opción nueva = una fila en su pestaña (y sus textos en
-- translations.csv: settings.row_<id>, settings.desc_<id>).
--   fila = { id, kind = 'volume' | 'switch' | 'choice' | 'number' | 'action', label = clave, desc = clave,
--            value() → número (volume / number: 0..10, ms) | booleano (switch) | texto (choice),
--            step(d)  (d = -1 / +1: volume 0..10, number ±10 ms en -300..300, choice da la vuelta, switch: -1 apaga, +1 enciende),
--            go(state) (confirmar: switch cambia, choice avanza, action la hace; volume / number: nil) }
-- Todo se guarda como siempre: src/core/Settings.lua (mismas claves, mismo options.cfg).
local Settings = require 'src/core/Settings'
local L        = require 'src/core/Lang'

local R = {}

local function beep(d) Sound.play('select', d > 0 and 1.08 or 0.94) end

local function volume(key)
    return { id = key, kind = 'volume', label = 'settings.row_' .. key, desc = 'settings.desc_' .. key,
             value = function() return Settings[key] end,
             step = function(d) Settings.set(key, math.max(0, math.min(10, Settings[key] + d))); beep(d) end }
end
-- (izquierda = apagado, derecha = encendido; confirmar lo cambia)
local function switch(key, set)
    local put = function(v)
        if (Settings[key] == true) == v then return end
        if set then set(v) else Settings.set(key, v) end
        beep(v and 1 or -1)
    end
    return { id = key, kind = 'switch', label = 'settings.row_' .. key, desc = 'settings.desc_' .. key,
             value = function() return Settings[key] == true end,
             step = function(d) put(d > 0) end, go = function() put(not (Settings[key] == true)) end }
end

local function langIndex()
    for i, l in ipairs(L.LANGUAGES) do if l.id == L.current() then return i end end
    return 1
end
local language = { id = 'language', kind = 'choice', label = 'settings.row_language', desc = 'settings.desc_language',
    value = function() return L.LANGUAGES[langIndex()].name end,
    step = function(d)
        local n = #L.LANGUAGES
        Settings.setLanguage(L.LANGUAGES[(langIndex() - 1 + d) % n + 1].id); beep(d)
    end }
language.go = function() language.step(1) end

local wheel = { id = 'wheelToggle', kind = 'choice', label = 'settings.row_wheelToggle', desc = 'settings.desc_wheelToggle',
    value = function() return L(Settings.wheelToggle and 'settings.val_press' or 'settings.val_hold') end,
    step = function(d) Settings.set('wheelToggle', not Settings.wheelToggle); beep(d) end }
wheel.go = function() wheel.step(1) end

local rhythm = { id = 'rhythmOffset', kind = 'number', label = 'settings.row_rhythmOffset', desc = 'settings.desc_rhythmOffset',
    value = function() return Settings.rhythmOffset or 0 end,
    step = function(d) Settings.setRhythmOffset((Settings.rhythmOffset or 0) + d * 10); beep(d) end }

local credits = { id = 'credits', kind = 'action', label = 'settings.row_credits', desc = 'settings.desc_credits',
    value = function() return nil end, go = function(state) return state:_credits() end }

R.TABS = {
    { id = 'audio',    label = 'settings.tab_audio',    rows = { volume('musicVol'), volume('sfxVol'), switch('muted'), rhythm } },
    { id = 'controls', label = 'settings.tab_controls', rows = { switch('swapAB'), switch('rumble'), wheel } },
    { id = 'game',     label = 'settings.tab_game',     rows = { language, switch('hitStop'), switch('deathCause'),
                                                               switch('showPerf', function(v) Settings.setShowPerf(v) end) } },
    { id = 'other',    label = 'settings.tab_other',    rows = { credits } },
}

return R
