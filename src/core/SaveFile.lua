-- src/core/SaveFile.lua
-- ARCHIVOS DE GUARDADO como tablas de Lua (`return { ... }`, cargadas SIN entorno: no pueden ejecutar nada), con su
-- copia `.bak`. Lo usan las partidas de la historia (src/story/Save.lua) y las de la campaña Flappy
-- (src/flappy/FlappySave.lua). OJO: nunca nombres de .lua del juego (la carpeta de guardado tapa los módulos).
--   SaveFile.read(name)        → tabla | nil, dañado (existe pero no se puede leer)
--   SaveFile.write(name, data) → true si se escribió (primero la copia .bak, luego el archivo)
--   SaveFile.remove(name)      borra el archivo y su copia
--   SaveFile.modtime(name)     fecha de la última escritura (nil si no existe)
local SaveFile = {}

local function ser(v, ind)
    local t = type(v)
    if t == 'number' or t == 'boolean' then return tostring(v) end
    if t == 'string' then return string.format('%q', v) end
    if t ~= 'table' then return 'nil' end
    local keys = {}
    for k in pairs(v) do if type(k) == 'string' or type(k) == 'number' then keys[#keys + 1] = k end end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local out, pad = {}, ind .. '  '
    for _, k in ipairs(keys) do
        local ks = type(k) == 'number' and ('[' .. k .. ']') or ('[' .. string.format('%q', k) .. ']')
        out[#out + 1] = pad .. ks .. ' = ' .. ser(v[k], pad)
    end
    return '{\n' .. table.concat(out, ',\n') .. (#out > 0 and '\n' or '') .. ind .. '}'
end

local function parse(name)
    if not love.filesystem.getInfo(name) then return nil end
    local ok, src = pcall(love.filesystem.read, name)
    local chunk = ok and src and loadstring(src, '@' .. name)
    if not chunk then return nil end
    setfenv(chunk, {})
    local ok2, data = pcall(chunk)
    return (ok2 and type(data) == 'table') and data or nil
end

-- Cada archivo tiene su COPIA (`.bak`), escrita ANTES que él con lo mismo: si el juego se cierra a mitad de una
-- escritura, uno de los dos queda entero. Al leer, si el principal está roto, vale la copia. Si los dos lo están,
-- el principal se aparta a `.damaged` (no se pierde al empezar una partida nueva en ese hueco).
function SaveFile.read(name)
    local d = parse(name) or parse(name .. '.bak')
    if not d and love.filesystem.getInfo(name) and not love.filesystem.getInfo(name .. '.damaged') then
        local ok, src = pcall(love.filesystem.read, name)
        if ok and src then pcall(love.filesystem.write, name .. '.damaged', src) end
    end
    -- (dañado: el archivo existe pero ni él ni su copia se pueden leer)
    return d, d == nil and love.filesystem.getInfo(name) ~= nil
end

-- true si se escribió (love.filesystem.write devuelve false, no lanza error)
function SaveFile.write(name, data)
    local src = 'return ' .. ser(data, '') .. '\n'
    pcall(love.filesystem.write, name .. '.bak', src)
    local ok, res = pcall(love.filesystem.write, name, src)
    return ok and res == true
end

function SaveFile.remove(name)
    pcall(love.filesystem.remove, name)
    pcall(love.filesystem.remove, name .. '.bak')
end

function SaveFile.modtime(name)
    local info = love.filesystem.getInfo(name)
    return info and info.modtime or nil
end

return SaveFile
