-- src/story/Collect.lua
-- LOS COLECCIONABLES de la historia (los secretos: las astillas del espejo que llevan los cangrejos secretos y la
-- bola de discoteca), como DATOS: assets/story/collectibles.json (la única lista; ver su "_").
--   Collect.LIST, Collect.BY_ID[id]                 el catálogo
--   Collect.ofKind(kind) → { entradas }             p. ej. todas las 'splinter' (la puerta del Groove)
--   Collect.has(data, id) · Collect.hasAll(data, kind) · Collect.count(data[, kind]) → tengo, total
--   Collect.forLevel(level) → { entradas }          las que se ganan en ese nivel
--   Collect.drops(level, data) → { { id, boss }, … } las que SUELTA un jefe de ese nivel y la partida aún no tiene
--   Collect.onFinish(level, data) → { ids }         las que se ganan al TERMINAR ese nivel (sin jefe que las suelte)
--   Collect.stateDef(id, estado) · Collect.iconPath(id[, estado]) · Collect.image(id[, estado])   lo de un estado
--                                                   ('stolen'…: collectibles.json `states`) y su imagen
-- Como los fragmentos (src/story/Shards.lua), solo se GUARDAN al terminar el nivel (regla de oro 7): el nivel las
-- apunta y la historia las pasa a `data.collect` en su onFinish (Run.addCollect).
local Collect = {}

Collect.LIST = require('libs/json').decode(love.filesystem.read('assets/story/collectibles.json')).collectibles
Collect.BY_ID = {}
for _, c in ipairs(Collect.LIST) do
    c.source = c.source or {}
    Collect.BY_ID[c.id] = c
end

function Collect.ofKind(kind)
    local out = {}
    for _, c in ipairs(Collect.LIST) do if c.kind == kind then out[#out + 1] = c end end
    return out
end

-- EL ESTADO de uno en la partida (`data.collect[id]`): nil = aún no; true = lo tiene; otro valor = un estado que le
-- dé la historia más adelante (p. ej. 'stolen'). Cualquier estado cuenta como GANADO (ya no se vuelve a soltar y
-- cuenta para la puerta del Groove): un estado nuevo no necesita tocar esto
function Collect.state(data, id)
    local v = data ~= nil and type(data.collect) == 'table' and data.collect[id] or nil
    return (v ~= nil and v ~= false) and v or nil
end
function Collect.has(data, id) return Collect.state(data, id) ~= nil end

-- ¿Tiene todas las de ese tipo? (sin ninguna en el catálogo: no hay nada que pedir)
function Collect.hasAll(data, kind)
    for _, c in ipairs(Collect.ofKind(kind)) do if not Collect.has(data, c.id) then return false end end
    return true
end

function Collect.count(data, kind)
    local have, total = 0, 0
    for _, c in ipairs(Collect.LIST) do
        if not kind or c.kind == kind then
            total = total + 1
            if Collect.has(data, c.id) then have = have + 1 end
        end
    end
    return have, total
end

function Collect.forLevel(level)
    local out = {}
    for _, c in ipairs(Collect.LIST) do if c.source.level == level then out[#out + 1] = c end end
    return out
end

-- Lo que suelta un jefe de este nivel (y aún falta): { id, boss = tipo del jefe que lo suelta }
function Collect.drops(level, data)
    local out = {}
    for _, c in ipairs(Collect.forLevel(level)) do
        if c.source.boss and not Collect.has(data, c.id) then out[#out + 1] = { id = c.id, boss = c.source.boss } end
    end
    return out
end

-- ¿Lo da un JEFE de ese nivel? (entonces el nivel acaba solo al vencerlo, como los de fragmento)
function Collect.bossLevel(level)
    for _, c in ipairs(Collect.forLevel(level)) do if c.source.boss then return true end end
    return false
end

-- Lo que da el nivel al terminarlo (las que no suelta ningún jefe) y aún falta
function Collect.onFinish(level, data)
    local out = {}
    for _, c in ipairs(Collect.forLevel(level)) do
        if not c.source.boss and not Collect.has(data, c.id) then out[#out + 1] = c.id end
    end
    return out
end

-- Lo que cambia en un ESTADO de la partida que no es `true` (collectibles.json `states[estado]`: p. ej. el icono vacío de
-- 'stolen'); nil si ese estado no cambia nada
function Collect.stateDef(id, state)
    local c = Collect.BY_ID[id]
    return c and state ~= nil and state ~= true and type(c.states) == 'table' and c.states[state] or nil
end

-- (la imagen de uno, para dibujarlo — en ese ESTADO si se da y tiene la suya —: nil si aún no existe el archivo)
local imgs = {}
function Collect.iconPath(id, state)
    local c = Collect.BY_ID[id]
    local sd = Collect.stateDef(id, state)
    return (sd and sd.icon) or (c and c.icon) or nil
end
function Collect.image(id, state)
    local path = Collect.iconPath(id, state)
    if not path then return nil end
    if imgs[path] == nil then
        imgs[path] = love.filesystem.getInfo(path) and love.graphics.newImage(path) or false
        if imgs[path] then imgs[path]:setFilter('nearest', 'nearest') end
    end
    return imgs[path] or nil
end

return Collect
