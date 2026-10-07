-- src/core/Settings.lua
-- Configuración del jugador guardada en su carpeta de datos (options.cfg en
-- el directorio de guardado de LÖVE: PC, Switch y Android): el idioma y el
-- último nombre usado en el modo online (para no tener que escribirlo cada vez). OJO: nunca un nombre .lua del juego (p. ej. settings.lua): LÖVE busca
-- primero en la carpeta de guardado y require 'settings' cargaría este archivo.

local Lang = require 'src/core/Lang'

local Settings = { language = Lang.DEFAULT, onlineName = '' }
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
            end
        end
    end
    Lang.set(Settings.language)
end

function Settings.save()
    local s = string.format('return { language = %q, onlineName = %q }\n', Settings.language, Settings.onlineName or '')
    pcall(love.filesystem.write, FILE, s)
end

-- El nombre con el que se entró al modo online (el servidor lo aceptó): la próxima vez sale ya escrito
function Settings.setOnlineName(name)
    if type(name) ~= 'string' or name == '' or name == Settings.onlineName then return end
    Settings.onlineName = name
    Settings.save()
end

function Settings.setLanguage(id)
    Settings.language = id
    Lang.set(id)
    Settings.save()
end

return Settings
