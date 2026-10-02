-- src/world/LevelCatalog.lua
-- Ficha de un nivel para los menús: nombre, tamaño, qué modos lo admiten,
-- cuántos monstruos, jefes, objetos, agua... y su miniatura (`preview`).
-- La usan el servidor (catálogo del lobby online) y el cliente (Juego libre:
-- src/states/FreePlayState.lua): un solo cálculo para los dos.
local Level       = require 'src/world/Level'
local Modes       = require 'src/world/Modes'
local EntityTypes = require 'src/world/entities/EntityTypes'
local Tiles       = require 'src/world/Tiles'

local LevelCatalog = {}
LevelCatalog.DIR = 'assets/levels'

-- Archivos de assets/levels que NO se ofrecen: los de "Probar" del editor y
-- los niveles de prueba que se sacaron del juego (una instalación antigua
-- aún los tiene en su carpeta: las actualizaciones no pueden borrarlos).
LevelCatalog.RETIRED = {
    ['editor_playtest.json'] = true,
    ['jefe_cangrejo.json'] = true, ['jefe_espejo.json'] = true, ['MiniBossArena.json'] = true,
}

function LevelCatalog.isListed(file)
    return file:match('%.json$') ~= nil and not file:match('^_') and not LevelCatalog.RETIRED[file]
end

-- Archivos de nivel que ve el juego (carpeta montada: instalación +
-- actualización), ordenados
function LevelCatalog.files()
    local out = {}
    for _, f in ipairs(love.filesystem.getDirectoryItems(LevelCatalog.DIR)) do
        if LevelCatalog.isListed(f) then out[#out + 1] = f end
    end
    table.sort(out, function(a, b) return a:lower() < b:lower() end)
    return out
end

-- Miniatura: un carácter por celda ('.' vacío, '#' sólido, 'B' borde, 'D'
-- tierra, 'G' césped, '=' plataforma, '~' agua, 'X' peligro, 'F' meta, '^'
-- pinchos, 'm' mini bloques, 'P' zona de puntos) + entidades y punto de inicio. La dibuja ModeSelectMenu.drawPreview.
LevelCatalog.PREVIEW_MAX_CELLS = 20000
function LevelCatalog.buildPreview(lv)
    if lv.tileW * lv.tileH > LevelCatalog.PREVIEW_MAX_CELLS then return nil end
    local rows = {}
    for r = 1, lv.tileH do
        local line = {}
        for c = 1, lv.tileW do
            local raw = lv.tiles[r][c]
            local t   = lv:getDef(c, r)
            local ch  = '.'
            if t.trigger == 'finish' then ch = 'F'
            elseif t.mat.contact == 'kill' then ch = 'X'
            elseif t.name == 'border' then ch = 'B'
            elseif t.name == 'dirt' then ch = 'D'
            elseif t.name == 'grass' then ch = 'G'
            elseif t.name == 'snow' then ch = 'S'
            elseif t.name == 'sand' then ch = 'A'
            elseif t.name == 'deep_stone' then ch = 'R'
            elseif t.mat.name == 'ice' then ch = 'I'
            elseif t.collision == 'solid' then ch = '#'
            elseif t.collision == 'oneway' then ch = '='
            elseif t.mat.liquid or Tiles.codec.isWaterlogged(raw) then ch = '~'
            end
            if ch == '.' and Tiles.codec.hasSpikes(raw) then ch = '^' end
            if (ch == '.' or ch == '~') and lv.subCells and lv.subCells[r * 65536 + c] then ch = 'm' end
            line[c] = ch
        end
        rows[r] = table.concat(line)
    end
    -- Zonas de puntos ('P' donde no hay nada sólido)
    for _, a in ipairs(lv.pointAreas or {}) do
        for r = math.max(1, a.row0), math.min(lv.tileH, a.row1) do
            local line = rows[r]
            local chars = {}
            for c = 1, #line do chars[c] = line:sub(c, c) end
            for c = math.max(1, a.col0), math.min(lv.tileW, a.col1) do
                if chars[c] == '.' then chars[c] = 'P' end
            end
            rows[r] = table.concat(chars)
        end
    end
    local ents = {}
    for _, e in ipairs(lv.entities) do
        if e.type ~= 'pointarea' and e.type ~= 'flood' then ents[#ents + 1] = { e.col, e.row } end
    end
    return { rows = rows, ents = ents, start = lv.playerStart }
end

-- Ficha de un nivel ya cargado. Campos (además de los de Modes.entityInfo:
-- enemies = entidades, killable, bosses, pointAreas, respawning):
--   path, file, name, w, h, finish, autoScroll, modes = {id=true}, modeList
--   (en el orden de Modes.list), monsters (Enemigos + Jefes), bossTypes,
--   stars, lives, checkpoints, water, floods, music (nombre), preview
function LevelCatalog.info(lv, path, file)
    local info = Modes.entityInfo(lv.entities)
    file = file or path:match('([^/]+)$')
    info.path, info.file = path, file
    info.name = (lv.name and lv.name ~= '?') and lv.name or file:gsub('%.json$', '')
    info.name_en = lv.name_en                       -- (Lang.localName elige según el idioma)
    info.finish = lv:countTrigger('finish')
    info.autoScroll = lv.autoScroll ~= nil
    info.pointAreas = #(lv.pointAreas or {})
    info.floods = #(lv.floods or {})
    info.w, info.h = lv.tileW, lv.tileH
    -- Modos que lo admiten (el nivel puede limitarlos con "modes")
    info.modes, info.modeList = {}, {}
    local allowed
    if lv.modes then allowed = {}; for _, id in ipairs(lv.modes) do allowed[id] = true end end
    for _, m in ipairs(Modes.list) do
        if (not allowed or allowed[m.id]) and m.requires(info) then
            info.modes[m.id] = true
            info.modeList[#info.modeList + 1] = m.id
        end
    end
    -- Contenido
    info.monsters, info.bossTypes, info.stars, info.lives, info.checkpoints = 0, {}, 0, 0, 0
    info.bossNames = {}
    local seenBoss = {}
    for _, e in ipairs(lv.entities) do
        local d = EntityTypes.get(e.type)
        if d then
            if d.category == 'Enemigos' or d.category == 'Jefes' then info.monsters = info.monsters + 1 end
            -- (bossNames: tipo + nombres propios del nivel, para Lang.bossName; uno por nombre distinto)
            local p = e.props or {}
            local nk = e.type .. '|' .. tostring(p.title or '')
            if d.boss and not seenBoss[nk] then
                if not seenBoss[e.type] then info.bossTypes[#info.bossTypes + 1] = e.type end
                seenBoss[nk], seenBoss[e.type] = true, true
                local names = {}
                for k, v in pairs(p) do if type(k) == 'string' and k:match('^title') then names[k] = v end end
                info.bossNames[#info.bossNames + 1] = { type = e.type, props = names }
            end
        end
        if e.type == 'star' then info.stars = info.stars + 1
        elseif e.type == 'extralife' then info.lives = info.lives + 1
        elseif e.type == 'checkpoint' then info.checkpoints = info.checkpoints + 1 end
    end
    info.water = info.floods > 0
    for r = 1, lv.tileH do
        if info.water then break end
        for c = 1, lv.tileW do
            if lv:getDef(c, r).mat.liquid or Tiles.codec.isWaterlogged(lv.tiles[r][c]) then info.water = true; break end
        end
    end
    local Music = require 'src/Music'
    local tr = Music.get(lv.music or Music.DEFAULT)
    info.music = tr and tr.name or nil
    info.preview = LevelCatalog.buildPreview(lv)
    return info
end

-- Carga un nivel y devuelve su ficha, o nil + error
function LevelCatalog.load(path, file)
    local ok, lv = pcall(Level.new, path)
    if not ok then return nil, lv end
    return LevelCatalog.info(lv, path, file)
end

return LevelCatalog
