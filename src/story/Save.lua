-- src/story/Save.lua
-- PARTIDAS del modo historia: 3 huecos, cada uno una aventura con su dificultad, sus vidas y lo
-- que lleva superado. En la carpeta de guardado de LÖVE: story1.sav, story2.sav, story3.sav y
-- story.sav (lo GLOBAL: dificultades desbloqueadas). OJO: nunca nombres .lua del juego (ver
-- src/core/Settings.lua: la carpeta de guardado tapa los módulos).
-- El archivo es una tabla de Lua (`return { ... }`) que se carga sin entorno: no puede ejecutar nada.
local Save = { SLOTS = 3, VERSION = 2 }

-- Los MUNDOS de cada versión de las partidas (Worlds.LIST por sus ids, en orden). La partida guarda el mundo por su
-- POSICIÓN: al cargar una de una versión anterior se traduce a la lista de hoy, y un mundo NUEVO metido en medio
-- (una expansión) queda ABIERTO para quien ya había pasado el de antes, sin cerrarle lo que ya tenía (el usuario,
-- 0.5.99: "mantener su progreso, la jungla abierta"). Para añadir mundos: VERSION + 1 y su lista aquí.
Save.WORLDS = {
    [1] = { 'pradera', 'costa', 'fortaleza', 'nieve', 'cuevas', 'final' },
    [2] = { 'pradera', 'costa', 'jungla', 'fortaleza', 'nieve', 'cuevas', 'final' },          -- (0.5.99: la jungla)
}

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
local function read(name)
    local d = parse(name) or parse(name .. '.bak')
    if not d and love.filesystem.getInfo(name) and not love.filesystem.getInfo(name .. '.damaged') then
        local ok, src = pcall(love.filesystem.read, name)
        if ok and src then pcall(love.filesystem.write, name .. '.damaged', src) end
    end
    return d
end

-- true si se escribió (love.filesystem.write devuelve false, no lanza error)
local function write(name, data)
    local src = 'return ' .. ser(data, '') .. '\n'
    pcall(love.filesystem.write, name .. '.bak', src)
    local ok, res = pcall(love.filesystem.write, name, src)
    return ok and res == true
end

-- Una partida nueva (sin guardar todavía)
function Save.new(difficulty)
    difficulty = difficulty or 'normal'
    return { version = Save.VERSION, difficulty = difficulty, world = 1, node = 1,
             lives = require('src/core/Difficulty').of(difficulty, 'livesStart', 3),     -- (3; Extremo 4; Xtra extremo 6)
             done = {}, best = {}, playTime = 0, gameOvers = 0, points = 0, worldReward = {}, bonus = {},
             open = {},                                        -- (mundos abiertos sin su jefe anterior: Save.migrate)
             shards = {},                                      -- (fragmentos del espejo: src/story/Shards.lua)
             films = {},                                       -- (cinemáticas de antes de un nivel ya vistas: Worlds films)
             taken = {} }                                      -- (vidas extra ya cogidas, por nivel: no se repiten)
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
    d.films = type(d.films) == 'table' and d.films or {}
    d.taken = type(d.taken) == 'table' and d.taken or {}         -- (vidas extra cogidas por nivel: [id] = { [colocación] = true })
    d.open = type(d.open) == 'table' and d.open or {}
    Save.migrate(d)
    require('src/story/Shards').migrate(d)                    -- (partidas de antes de los fragmentos)
    return d
end

-- Una partida de una versión anterior, a la de hoy (ver Save.WORLDS): el mundo actual y las notas de mundo pasan de su
-- posición de entonces a la de hoy; cada mundo nuevo queda abierto, y el de DESPUÉS de él también si la partida ya
-- había llegado a él (`open`: Run.worldOpen)
function Save.migrate(d)
    local v = tonumber(d.version) or 1
    local Worlds = require 'src/story/Worlds'
    while v < Save.VERSION do
        local old, new = Save.WORLDS[v], Save.WORLDS[v + 1]
        if not (old and new) then break end
        local pos = {}
        for i, id in ipairs(new) do pos[id] = i end
        local was = {}
        for _, id in ipairs(old) do was[id] = true end
        d.world = pos[old[d.world] or ''] or d.world
        local rw = {}
        for k, g in pairs(d.worldReward) do
            local i = type(k) == 'number' and pos[old[k] or ''] or nil
            if i then rw[i] = g end
        end
        d.worldReward = rw
        for i, id in ipairs(new) do
            local prev, nxt = new[i - 1], new[i + 1]
            local W = Worlds.LIST[pos[prev or ''] or 0]
            if not was[id] and prev and nxt and W and d.done[W.boss] then d.open[nxt] = true end
        end
        v = v + 1
    end
    d.version = Save.VERSION
end

function Save.write(i, data) return write(file(i), data) end
function Save.delete(i)
    pcall(love.filesystem.remove, file(i))
    pcall(love.filesystem.remove, file(i) .. '.bak')
end

-- Lo global (desbloqueos): { unlocked = { extreme = true, ... } }
function Save.global()
    local g = read(GLOBAL) or {}
    g.unlocked = type(g.unlocked) == 'table' and g.unlocked or {}
    return g
end
function Save.writeGlobal(g) return write(GLOBAL, g) end

return Save
