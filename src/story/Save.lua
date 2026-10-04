-- src/story/Save.lua
-- PARTIDAS del modo historia: 3 huecos, cada uno una aventura con su dificultad, sus vidas y lo
-- que lleva superado. En la carpeta de guardado de LÖVE: story1.sav, story2.sav, story3.sav y
-- story.sav (lo GLOBAL: dificultades desbloqueadas). OJO: nunca nombres .lua del juego (ver
-- src/Settings.lua: la carpeta de guardado tapa los módulos).
-- El archivo es una tabla de Lua (`return { ... }`) que se carga sin entorno: no puede ejecutar nada.
local Save = { SLOTS = 3, VERSION = 1 }

local function file(i) return 'story' .. i .. '.sav' end
local GLOBAL = 'story.sav'

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

local function read(name)
    if not love.filesystem.getInfo(name) then return nil end
    local ok, src = pcall(love.filesystem.read, name)
    local chunk = ok and src and loadstring(src, '@' .. name)
    if not chunk then return nil end
    setfenv(chunk, {})
    local ok2, data = pcall(chunk)
    return (ok2 and type(data) == 'table') and data or nil
end

local function write(name, data)
    return pcall(love.filesystem.write, name, 'return ' .. ser(data, '') .. '\n')
end

-- Una partida nueva (sin guardar todavía)
function Save.new(difficulty)
    difficulty = difficulty or 'normal'
    return { version = Save.VERSION, difficulty = difficulty, world = 1, node = 1,
             lives = require('src/Difficulty').of(difficulty, 'livesStart', 3),     -- (3; Extremo 4; Xtra extremo 6)
             done = {}, best = {}, playTime = 0, gameOvers = 0, points = 0, worldReward = {}, bonus = {},
             shards = {} }                                     -- (fragmentos del espejo: src/story/Shards.lua)
end

function Save.load(i)
    local d = read(file(i))
    if not d or type(d.done) ~= 'table' then return nil end
    d.best = type(d.best) == 'table' and d.best or {}
    d.difficulty = type(d.difficulty) == 'string' and d.difficulty or 'normal'
    d.lives = tonumber(d.lives) or 3
    d.world, d.node = tonumber(d.world) or 1, tonumber(d.node) or 1
    d.playTime = tonumber(d.playTime) or 0
    d.gameOvers = tonumber(d.gameOvers) or 0
    d.points = tonumber(d.points) or 0
    d.worldReward = type(d.worldReward) == 'table' and d.worldReward or {}
    d.bonus = type(d.bonus) == 'table' and d.bonus or {}
    require('src/story/Shards').migrate(d)                    -- (partidas de antes de los fragmentos)
    return d
end

function Save.write(i, data) return write(file(i), data) end
function Save.delete(i) pcall(love.filesystem.remove, file(i)) end

-- Lo global (desbloqueos): { unlocked = { extreme = true, ... } }
function Save.global()
    local g = read(GLOBAL) or {}
    g.unlocked = type(g.unlocked) == 'table' and g.unlocked or {}
    return g
end
function Save.writeGlobal(g) return write(GLOBAL, g) end

return Save
