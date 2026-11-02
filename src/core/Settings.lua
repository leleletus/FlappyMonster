-- src/core/Settings.lua
-- Configuración del jugador guardada en su carpeta de datos (options.cfg en
-- el directorio de guardado de LÖVE: PC, Switch y Android): el idioma y el
-- último nombre usado en el modo online (para no tener que escribirlo cada vez). OJO: nunca un nombre .lua del juego (p. ej. settings.lua): LÖVE busca
-- primero en la carpeta de guardado y require 'settings' cargaría este archivo.

local Lang = require 'src/core/Lang'

local Settings = { language = Lang.DEFAULT, onlineName = '', rhythmOffset = 0, showPerf = false,
                   musicVol = 10, sfxVol = 10, muted = false, swapAB = false }   -- (volúmenes 0..10; swapAB: A / B al revés, mandos de Xbox; (rhythmOffset: ms de retardo del audio, duelo de ritmo; showPerf: src/ui/PerfOverlay.lua)
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
            end
        end
    end
    Lang.set(Settings.language)
    Settings.apply()
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
    local s = string.format('return { language = %q, onlineName = %q, rhythmOffset = %d, showPerf = %s, musicVol = %d, sfxVol = %d, muted = %s, swapAB = %s }\n',
        Settings.language, Settings.onlineName, Settings.rhythmOffset or 0, tostring(Settings.showPerf == true),
        Settings.musicVol, Settings.sfxVol, tostring(Settings.muted == true), tostring(Settings.swapAB == true))
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
