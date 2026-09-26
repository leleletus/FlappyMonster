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

return TextUtil
