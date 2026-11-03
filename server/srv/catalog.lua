-- server/srv/catalog.lua
-- PARTE de server/main.lua: el catálogo de niveles del servidor.
-- La carga server/main.lua con require(...)(S): S = el estado y las funciones que comparten las partes (los
-- módulos del juego, que se cargan en love.load, también: S.Level, S.Entities...).

return function(S)
local parentDir, LEVELS_DIR, DEFAULT_LEVEL = S.parentDir, S.LEVELS_DIR, S.DEFAULT_LEVEL
-- ─────────────────────────────────────────────────────────────────────────────
--  Simulación de juego
-- ─────────────────────────────────────────────────────────────────────────────

-- ── Catálogo de niveles del servidor ────────────────────────────────────────
-- Se escanea assets/levels (caché de 10 s: un nivel nuevo aparece sin
-- reiniciar). Para cada nivel se calcula qué modos admite. Los clientes no
-- necesitan tener el archivo: el nivel se les envía al empezar la partida.
local levelCache, levelCacheT = nil, -1e9

local function listLevelFiles()
    local dir = parentDir .. '/' .. LEVELS_DIR
    local cmd = (love.system.getOS() == 'Windows') and ('dir /b "' .. dir:gsub('/', '\\') .. '"')
                or ('ls -1 "' .. dir .. '"')
    local out = {}
    local p = io.popen(cmd)
    if p then
        for line in p:lines() do
            line = line:gsub('%s+$', '')
            if line:match('^[%w%-_%.]+%.json$') and not line:match('^_') then out[#out+1] = line end
        end
        p:close()
    end
    table.sort(out)
    return out
end

-- Ficha de cada nivel (modos, monstruos, miniatura...): src/world/level/LevelCatalog.lua
-- (la misma que usa el Juego libre del cliente)
-- (cada ficha se guarda con la fecha de su archivo: al re-escanear solo se cargan los niveles nuevos o cambiados —
-- antes, cada 10 s, Level.new + miniatura de TODOS, en el hilo de las partidas: tirones en todas las salas)
local infoByFile = {}
S.levelCatalogMsg = nil              -- (la lista para `level_catalog`, hecha una vez por escaneo)
local function scanLevels(force)
    local now = love.timer.getTime()
    if levelCache and not force and now - levelCacheT < 10 then return levelCache end
    -- (se carga aquí: necesita Level y los stubs del servidor ya puestos)
    local LevelCatalog = require 'src/world/level/LevelCatalog'
    local list = {}
    for _, f in ipairs(listLevelFiles()) do
        if LevelCatalog.isListed(f) then
            local path = LEVELS_DIR .. '/' .. f
            local fi = love.filesystem.getInfo(path)
            local mod = fi and fi.modtime or 0
            local c = infoByFile[f]
            if not (c and c.mod == mod) then
                local info, err = LevelCatalog.load(path, f)
                if not info then S.log('Nivel invalido ' .. path .. ': ' .. tostring(err)) end
                c = { mod = mod, info = info }
                infoByFile[f] = c
                S.levelCatalogMsg = nil
            end
            if c.info then list[#list+1] = c.info end
        end
    end
    if levelCache and #list ~= #levelCache then S.levelCatalogMsg = nil end
    levelCache, levelCacheT = list, now
    return list
end

local function levelsForMode(modeId)
    local out = {}
    for _, info in ipairs(scanLevels()) do if info.modes[modeId] then out[#out+1] = info end end
    return out
end

local function levelInfo(path)
    for _, info in ipairs(scanLevels()) do if info.path == path then return info end end
end

-- Asegura que la sala tenga un nivel válido para su modo (o nil si no hay).
local function ensureRoomLevel(room)
    local info = room.level and levelInfo(room.level)
    if info and info.modes[room.mode] then return end
    local cands = levelsForMode(room.mode)
    room.level = nil
    for _, c in ipairs(cands) do if c.path == DEFAULT_LEVEL then room.level = c.path end end
    room.level = room.level or (cands[1] and cands[1].path)
end


-- (lo que usan las demás partes)
S.listLevelFiles = listLevelFiles
S.scanLevels = scanLevels
S.levelsForMode = levelsForMode
S.levelInfo = levelInfo
S.ensureRoomLevel = ensureRoomLevel
end
