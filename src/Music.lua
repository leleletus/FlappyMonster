-- src/Music.lua
-- Catálogo de la música del juego, leído de assets/music/index.json (ver la
-- ayuda dentro de ese archivo). Lo usan Sound (para cargar y reproducir), el
-- editor (lista de músicas de nivel) y los niveles (campo "music" = un id).
--
-- Cada pista: { id, name, file | intro+loop, volume, loop, level, boss }
--   file        una sola pista que se repite
--   intro/loop  intro que suena una vez y luego el bucle para siempre
--   level=false no se ofrece como música de nivel (jefes, menús...)
--   boss=true   se ofrece como música de pelea en las zonas de jefe

local json = require 'libs/json'

local Music = { list = {}, byId = {}, levelList = {}, bossList = {} }

Music.DIR     = 'assets/music/'
Music.INDEX   = Music.DIR .. 'index.json'
Music.DEFAULT = 'classic'      -- la de siempre (niveles sin "music")

local function load()
    local data = love.filesystem.read(Music.INDEX)
    local ok, idx = pcall(json.decode, data or '')
    if not ok or type(idx) ~= 'table' or type(idx.tracks) ~= 'table' then
        print('[Music] No se pudo leer ' .. Music.INDEX)
        idx = { tracks = { { id = 'classic', name = 'Clásica', file = 'level.ogg' } } }
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
            }
            if Music.byId[tr.id] then print('[Music] id repetido: ' .. tr.id) else
                Music.byId[tr.id] = tr
                table.insert(Music.list, tr)
                if tr.level then table.insert(Music.levelList, tr) end
                if tr.boss then table.insert(Music.bossList, tr) end
            end
        end
    end
end
load()

function Music.get(id) return id and Music.byId[id] or nil end

-- Id válido de música de nivel (o el de por defecto)
function Music.levelTrack(id)
    local t = Music.byId[id or '']
    if t and t.level then return t.id end
    return Music.DEFAULT
end

return Music
