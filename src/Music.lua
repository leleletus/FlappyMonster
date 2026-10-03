-- src/Music.lua
-- Catálogo de la música del juego, leído de assets/music/index.json (ver la
-- ayuda dentro de ese archivo). Lo usan Sound (para cargar y reproducir), el
-- editor (lista de músicas de nivel) y los niveles (campo "music" = un id).
--
-- Cada pista: { id, name, file | intro+loop, volume, loop, level, boss, pending, fallback }
-- Carpetas: menus/, map/, worlds/<mundo>/ (2-3 de nivel por mundo), bosses/, jingles/. Los huecos (`pending`) son
-- pistas que aún no existen: su ruta ya está puesta y, mientras, suena su `fallback` (Music.playable).
--   file        una sola pista que se repite
--   intro/loop  intro que suena una vez y luego el bucle para siempre
--   level=false no se ofrece como música de nivel (jefes, menús...)
--   boss=true   se ofrece como música de pelea en las zonas de jefe

local json = require 'libs/json'

local Music = { list = {}, byId = {}, levelList = {}, bossList = {}, aliases = {} }

Music.DIR     = 'assets/music/'
Music.INDEX   = Music.DIR .. 'index.json'
Music.DEFAULT = 'pradera_1'    -- la de siempre (niveles sin "music")

local function load()
    local data = love.filesystem.read(Music.INDEX)
    local ok, idx = pcall(json.decode, data or '')
    if not ok or type(idx) ~= 'table' or type(idx.tracks) ~= 'table' then
        print('[Music] No se pudo leer ' .. Music.INDEX)
        idx = { tracks = { { id = 'pradera_1', name = 'Pradera 1', file = 'worlds/pradera/pradera_1.ogg' } } }
    end
    for _, t in ipairs(idx.tracks) do
        if type(t) == 'table' and type(t.id) == 'string' and (t.file or (t.intro and t.loop) or t.loop) then
            local tr = {
                id     = t.id,
                name   = t.name or t.id,
                file   = t.file and (Music.DIR .. t.file) or nil,
                intro  = t.intro and (Music.DIR .. t.intro) or nil,
                loopFile = (not t.file and type(t.loop) == 'string') and (Music.DIR .. t.loop) or nil,
                volume = tonumber(t.volume) or 0.7,
                loops  = t.loop ~= false,
                level  = t.level ~= false,
                boss   = t.boss == true,
                -- HUECO: la pista aún no existe (o su archivo falta): no se carga; suena `fallback` mientras
                pending  = t.pending == true,
                fallback = type(t.fallback) == 'string' and t.fallback or nil,
            }
            for _, f in ipairs({ tr.file, tr.intro, tr.loopFile }) do
                if not love.filesystem.getInfo(f) then tr.pending = true end
            end
            if Music.byId[tr.id] then print('[Music] id repetido: ' .. tr.id) else
                Music.byId[tr.id] = tr
                table.insert(Music.list, tr)
                if tr.level then table.insert(Music.levelList, tr) end
                if tr.boss then table.insert(Music.bossList, tr) end
            end
        end
    end
    -- ids antiguos → id de ahora
    for old, new in pairs(type(idx.aliases) == 'table' and idx.aliases or {}) do
        if type(old) == 'string' and type(new) == 'string' then Music.aliases[old] = new end
    end
end
load()

-- El id de ahora de un id (los antiguos siguen valiendo: "aliases" del índice)
function Music.id(id)
    if id and not Music.byId[id] and Music.aliases[id] then return Music.aliases[id] end
    return id
end

function Music.get(id) return id and Music.byId[Music.id(id)] or nil end

-- El id que SUENA de verdad: sigue los alias y, si la pista es un hueco (pendiente), su `fallback`
function Music.playable(id)
    id = Music.id(id)
    for _ = 1, 4 do
        local t = Music.byId[id or '']
        if not (t and t.pending and t.fallback) then break end
        id = Music.id(t.fallback)
    end
    return id
end

-- Id válido de música de nivel (o el de por defecto)
function Music.levelTrack(id)
    local t = Music.get(id)
    if t and t.level then return t.id end
    return Music.DEFAULT
end

return Music
