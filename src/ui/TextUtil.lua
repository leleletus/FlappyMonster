-- src/ui/TextUtil.lua
-- Utilidades de texto para la UI.

local TextUtil = {}

-- Recorta `text` (respetando UTF-8) para que quepa en `w` px con `font`,
-- añadiendo '..' si hizo falta recortar.
function TextUtil.fit(font, text, w)
    if font:getWidth(text) <= w then return text end
    while #text > 1 and font:getWidth(text .. '..') > w do
        text = text:sub(1, -2)
        -- no dejar un carácter UTF-8 a medias
        while #text > 0 and text:byte(-1) >= 0x80 and text:byte(-1) < 0xC0 do text = text:sub(1, -2) end
        if #text > 0 and text:byte(-1) >= 0xC0 then text = text:sub(1, -2) end
    end
    return text .. '..'
end

-- BUSCAR (Juego Libre, "Abrir" del editor): el texto en minúsculas y sin tildes (á → a, ñ → n, ü → u…), para que
-- "Escarabajo" encuentre "ESCARABAJO" y "jardin" encuentre "Jardín"
local FOLD = { ['á'] = 'a', ['é'] = 'e', ['í'] = 'i', ['ó'] = 'o', ['ú'] = 'u', ['ü'] = 'u', ['ñ'] = 'n', ['à'] = 'a',
               ['è'] = 'e', ['ì'] = 'i', ['ò'] = 'o', ['ù'] = 'u', ['ç'] = 'c',
               ['Á'] = 'a', ['É'] = 'e', ['Í'] = 'i', ['Ó'] = 'o', ['Ú'] = 'u', ['Ü'] = 'u', ['Ñ'] = 'n', ['Ç'] = 'c' }
function TextUtil.fold(s)
    s = tostring(s or ''):gsub('[\xC3][\x80-\xBF]', function(c) return FOLD[c] or c end)
    return (s:lower():gsub('_', ' '))
end

-- ¿Encaja la búsqueda `query` con estos textos? Cada palabra de la búsqueda tiene que estar en alguno (vacía: sí)
function TextUtil.matches(query, ...)
    local q = TextUtil.fold(query)
    if not q:find('%S') then return true end
    local hay = TextUtil.fold(table.concat({ ... }, ' '))
    for word in q:gmatch('%S+') do
        if not hay:find(word, 1, true) then return false end
    end
    return true
end

return TextUtil
