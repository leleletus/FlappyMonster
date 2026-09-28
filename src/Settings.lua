-- src/Settings.lua
-- Configuración del jugador guardada en su carpeta de datos (options.cfg en
-- el directorio de guardado de LÖVE: PC, Switch y Android). Por ahora solo el
-- idioma. OJO: nunca un nombre .lua del juego (p. ej. settings.lua): LÖVE busca
-- primero en la carpeta de guardado y require 'settings' cargaría este archivo.

local Lang = require 'src/Lang'

local Settings = { language = Lang.DEFAULT }
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
            end
        end
    end
    Lang.set(Settings.language)
end

function Settings.save()
    local s = string.format('return { language = %q }\n', Settings.language)
    pcall(love.filesystem.write, FILE, s)
end

function Settings.setLanguage(id)
    Settings.language = id
    Lang.set(id)
    Settings.save()
end

return Settings
