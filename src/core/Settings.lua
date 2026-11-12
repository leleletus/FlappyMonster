-- src/core/Settings.lua
-- Configuración del jugador guardada en su carpeta de datos (options.cfg en
-- el directorio de guardado de LÖVE: PC, Switch y Android): el idioma y el
-- último nombre usado en el modo online (para no tener que escribirlo cada vez). OJO: nunca un nombre .lua del juego (p. ej. settings.lua): LÖVE busca
-- primero en la carpeta de guardado y require 'settings' cargaría este archivo.

local Lang = require 'src/core/Lang'

local Settings = { language = Lang.DEFAULT, onlineName = '', rhythmOffset = 0, showPerf = false,
                   musicVol = 10, sfxVol = 10, muted = false, swapAB = false, wheelToggle = false, rumble = true, hitStop = true, deathCause = true, shake = true, flashes = true, signText = 'normal', cbSymbols = false, tutorialOffered = false,
                   blocked = {} }   -- (volúmenes 0..10; swapAB: A / B al revés, mandos de Xbox; (rhythmOffset: ms de retardo del audio, duelo de ritmo; showPerf: src/ui/PerfOverlay.lua)
local FILE = 'options.cfg'

function Settings.load()
    if love.filesystem.getInfo(FILE) then
        local ok, src = pcall(love.filesystem.read, FILE)
        local chunk = ok and src and loadstring(src, '@' .. FILE)
        if chunk then
            setfenv(chunk, {})
            local ok2, data = pcall(chunk)
            if ok2 and type(data) == 'table' then
                if type(data.language) == 'string' then Settings.language = data.language end
                if type(data.onlineName) == 'string' then Settings.onlineName = data.onlineName:sub(1, 32) end
                if type(data.rhythmOffset) == 'number' then Settings.rhythmOffset = math.max(-300, math.min(300, data.rhythmOffset)) end
                Settings.showPerf = data.showPerf == true
                if type(data.musicVol) == 'number' then Settings.musicVol = math.max(0, math.min(10, math.floor(data.musicVol))) end
                if type(data.sfxVol) == 'number' then Settings.sfxVol = math.max(0, math.min(10, math.floor(data.sfxVol))) end
                Settings.muted, Settings.swapAB = data.muted == true, data.swapAB == true
                Settings.wheelToggle = data.wheelToggle == true      -- (la rueda de power-ups: pulsar en vez de mantener)
                Settings.rumble = data.rumble ~= false                -- (vibración del mando / del móvil: src/core/Rumble.lua)
                Settings.tutorialOffered = data.tutorialOffered == true  -- (la oferta del tutorial, una vez: TutorialOfferState)
                Settings.hitStop = data.hitStop ~= false              -- (congelar los golpes fuertes: src/ui/HitStop.lua)
                Settings.deathCause = data.deathCause ~= false        -- (el aviso de la muerte: src/ui/DeathBanner.lua)
                Settings.touchLayout = Settings.cleanTouch(data.touchLayout)   -- (los controles táctiles a su gusto: el editor)
                -- (ACCESIBILIDAD: temblor de pantalla, destellos — src/fx/Flash.lua —, letras de los carteles, símbolos ON/OFF)
                Settings.shake = data.shake ~= false
                Settings.flashes = data.flashes ~= false
                Settings.signText = (data.signText == 'large') and 'large' or 'normal'
                Settings.cbSymbols = data.cbSymbols == true
                -- (jugadores bloqueados, en minúsculas: src/network/Blocks.lua)
                if type(data.blocked) == 'table' then
                    for _, n in ipairs(data.blocked) do
                        if type(n) == 'string' and #n <= 32 and #Settings.blocked < 200 then Settings.blocked[#Settings.blocked + 1] = n end
                    end
                end
            end
        end
    end
    Lang.set(Settings.language)
    Settings.apply()
end

-- LA DISPOSICIÓN PROPIA de los controles táctiles (0.5.207, src/states/menu/TouchEditorState.lua): solo números en su
-- sitio; lo raro se descarta (nil = la de siempre)
local TOUCH_KEYS = { 'pad', 'jump', 'run', 'extra' }
function Settings.cleanTouch(t)
    if type(t) ~= 'table' then return nil end
    local out = { moved = t.moved == true, alpha = math.max(0.2, math.min(1, tonumber(t.alpha) or 1)) }
    for _, k in ipairs(TOUCH_KEYS) do
        local v = t[k]
        if type(v) == 'table' and tonumber(v[1]) and tonumber(v[2]) and tonumber(v[3]) then
            out[k] = { math.max(0, math.min(1, v[1])), math.max(0, math.min(1, v[2])), math.max(0.6, math.min(1.6, v[3])) }
        elseif out.moved then return nil end
    end
    return out
end
local function touchString(t)
    t = Settings.cleanTouch(t)
    if not t then return 'nil' end
    local parts = { ('moved = %s, alpha = %.3f'):format(tostring(t.moved), t.alpha) }
    for _, k in ipairs(TOUCH_KEYS) do
        if t[k] then parts[#parts + 1] = ('%s = { %.4f, %.4f, %.3f }'):format(k, t[k][1], t[k][2], t[k][3]) end
    end
    return '{ ' .. table.concat(parts, ', ') .. ' }'
end

-- Lo guardado, a lo que suena y a los botones (también al arrancar: game.lua, tras cargar Sound e Input)
function Settings.apply()
    local S, I = rawget(_G, 'Sound'), rawget(_G, 'Input')
    if S and S.setVolumes then S.setVolumes(Settings.musicVol / 10, Settings.sfxVol / 10) end
    if I and I.setSwapAB then I.setSwapAB(Settings.swapAB) end
    love.audio.setVolume(Settings.muted and 0 or 1)
end
function Settings.set(key, value)
    Settings[key] = value
    Settings.apply()
    Settings.save()
end

function Settings.save()
    local bl = {}
    for _, n in ipairs(Settings.blocked or {}) do bl[#bl + 1] = string.format('%q', n) end
    local s = string.format('return { language = %q, onlineName = %q, rhythmOffset = %d, showPerf = %s, musicVol = %d, sfxVol = %d, muted = %s, swapAB = %s, wheelToggle = %s, rumble = %s, hitStop = %s, deathCause = %s, shake = %s, flashes = %s, signText = %q, cbSymbols = %s, tutorialOffered = %s, touchLayout = %s, blocked = { %s } }\n',
        Settings.language, Settings.onlineName, Settings.rhythmOffset or 0, tostring(Settings.showPerf == true),
        Settings.musicVol, Settings.sfxVol, tostring(Settings.muted == true), tostring(Settings.swapAB == true), tostring(Settings.wheelToggle == true), tostring(Settings.rumble ~= false), tostring(Settings.hitStop ~= false), tostring(Settings.deathCause ~= false), tostring(Settings.shake ~= false), tostring(Settings.flashes ~= false), Settings.signText == 'large' and 'large' or 'normal', tostring(Settings.cbSymbols == true), tostring(Settings.tutorialOffered == true), touchString(Settings.touchLayout), table.concat(bl, ', '))
    pcall(love.filesystem.write, FILE, s)
end

-- El nombre con el que se entró al modo online (el servidor lo aceptó): la próxima vez sale ya escrito
function Settings.setOnlineName(name)
    if type(name) ~= 'string' or name == '' or name == Settings.onlineName then return end
    Settings.onlineName = name
    Settings.save()
end

function Settings.setRhythmOffset(ms)
    Settings.rhythmOffset = math.max(-300, math.min(300, ms))
    Settings.save()
end

function Settings.setShowPerf(on)
    Settings.showPerf = on == true
    Settings.save()
end

function Settings.setLanguage(id)
    Settings.language = id
    Lang.set(id)
    Settings.save()
end

return Settings
