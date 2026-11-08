-- tools/tests/project_check — el PROYECTO está entero (lo que se rompe al mover o borrar archivos):
--   modulos     todo .lua de src/ carga con require (ninguna ruta de módulo rota)
--   catalogos   cada tipo de entidad, tile, decoración y modo se registra, y cada entidad se crea
--   rutas       toda ruta 'assets/...' escrita en el código (src/, server/, game.lua) existe
--   cargas      nada de lo que se carga de verdad (imágenes, sonidos, música del catálogo) falta en disco
--   idiomas     la hoja assets/lang/translations.csv: cada clave con texto en todos los idiomas, sin repetidas
--   secretos    cada nivel secreto existe, tiene camino en el mapa y su salida secreta; cada astilla, en su nivel con su jefe
--   jefes       en los niveles con zona de jefe no hay nada más allá de la última zona (salvo sus bloques de jefe)
--   docs        toda ruta del repo escrita entre `comillas` en docs/, CLAUDE.md, README.md y tools/README.md existe,
--               y todo enlace entre páginas de docs/ lleva a una página que existe
--
--   tools/tests/run.sh project_check
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
local fails = 0
local function check(case, ok, msg)
    print(('%-10s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end
local function list(t, n)
    table.sort(t)
    local out = {}
    for i = 1, math.min(#t, n or 12) do out[i] = t[i] end
    return table.concat(out, ', ') .. (#t > (n or 12) and (' … (+' .. (#t - (n or 12)) .. ')') or '')
end
local function walk(dir, out)
    -- (una carpeta que es un enlace simbólico solo se lista como 'carpeta/.')
    for _, f in ipairs(love.filesystem.getDirectoryItems(dir .. '/.')) do
        local p = dir .. '/' .. f
        local info = love.filesystem.getInfo(p)
        if info and info.type == 'directory' then walk(p, out)
        elseif f:match('%.lua$') then out[#out + 1] = p end
    end
    return out
end

function love.load()
    -- Lo que se intenta cargar y no está en disco (Sound.load lo traga con pcall: aquí se apunta)
    local missing = {}
    local function guard(tbl, fn)
        local real = tbl[fn]
        tbl[fn] = function(a, ...)
            if type(a) == 'string' and not love.filesystem.getInfo(a) then missing[#missing + 1] = a end
            return real(a, ...)
        end
    end
    guard(love.graphics, 'newImage'); guard(love.audio, 'newSource'); guard(love.sound, 'newSoundData')
    guard(love.image, 'newImageData'); guard(love.graphics, 'newFont')

    require 'settings'
    FONT_SMALL = love.graphics.newFont(8); FONT_MED = FONT_SMALL; FONT_BIG = FONT_SMALL
    Input = require('src/network/Protocol').newInputStub()
    Sound = require 'src/audio/Sound'
    pcall(Sound.load)

    -- modulos
    local files, bad = walk('src', {}), {}
    for _, f in ipairs(files) do
        local ok, err = pcall(require, (f:gsub('%.lua$', '')))
        if not ok then bad[#bad + 1] = f .. ' → ' .. tostring(err):gsub('\n.*', '') end
    end
    check('modulos', #bad == 0, ('%d módulos; no cargan: %s'):format(#files, #bad > 0 and list(bad, 6) or 'ninguno'))

    -- catalogos
    local Entities = require 'src/world/entities/Entities'
    local EntityTypes = Entities.types
    local nE, badE = 0, {}
    for name in pairs(EntityTypes.byName) do
        nE = nE + 1
        local ok, err = pcall(Entities.create, { type = name, col = 5, row = 5, props = {} })
        if not ok then badE[#badE + 1] = name .. ' → ' .. tostring(err):gsub('\n.*', '') end
    end
    local Tiles = require 'src/world/tiles/Tiles'
    local Decorations = require 'src/world/decorations/Decorations'
    local Modes = require 'src/world/modes/Modes'
    local function count(t) local n = 0; for _ in pairs(t or {}) do n = n + 1 end; return n end
    local nT, nD, nM = count(Tiles.types.byName), count(Decorations.types.byName), count(Modes.types and Modes.types.byId or Modes.byId)
    for _, d in pairs(Decorations.types.byName or {}) do if d.loadAssets then pcall(d.loadAssets) end end
    check('catalogos', #badE == 0 and nE >= 50 and nT >= 35 and nD >= 40 and nM >= 3,
          ('%d entidades, %d tiles, %d decoraciones, %d modos; no se crean: %s'):format(nE, nT, nD, nM, #badE > 0 and list(badE, 5) or 'ninguna'))

    -- rutas escritas en el código
    local code = walk('src', {})
    for _, f in ipairs(walk('server_src', {})) do code[#code + 1] = f end
    code[#code + 1] = 'game_src.lua'
    local lost, nPaths, seen = {}, 0, {}
    for _, f in ipairs(code) do
        local text = love.filesystem.read(f) or ''
        for p in text:gmatch("['\"](assets/[%w_/%.%-]+%.%a+)['\"]") do
            if not seen[p] and not p:find("...", 1, true) then   -- ("assets/...png" = ejemplo en un comentario)
                seen[p] = true; nPaths = nPaths + 1
                if not love.filesystem.getInfo(p) then lost[#lost + 1] = p .. ' (' .. f .. ')' end
            end
        end
    end
    check('rutas', #lost == 0 and nPaths > 150, ('%d rutas escritas; no existen: %s'):format(nPaths, #lost > 0 and list(lost, 8) or 'ninguna'))

    -- música del catálogo + todo lo que se intentó cargar
    local Music = require 'src/audio/Music'
    for _, tr in ipairs(Music.list) do
        for _, k in ipairs({ 'file', 'intro', 'loopFile' }) do
            if tr[k] and not love.filesystem.getInfo(tr[k]) then missing[#missing + 1] = tr[k] end
        end
    end
    local uniq, m2 = {}, {}
    for _, p in ipairs(missing) do if not uniq[p] then uniq[p] = true; m2[#m2 + 1] = p end end
    -- (y los sonidos del catálogo assets/sounds/index.json: ids únicos y su archivo en disco)
    local snd = require('libs/json').decode(love.filesystem.read('assets/sounds/index.json')).sounds
    local seenId = {}
    for _, e in ipairs(snd) do
        if seenId[e.id] then m2[#m2 + 1] = 'id repetido: ' .. e.id end
        seenId[e.id] = true
        if not love.filesystem.getInfo(e.file) then m2[#m2 + 1] = e.file end
    end
    check('cargas', #m2 == 0, ('%d pistas de música, %d sonidos; faltan en disco: %s'):format(#Music.list, #snd, #m2 > 0 and list(m2, 8) or 'nada'))

    -- secretos (src/story/Worlds.lua + assets/story/collectibles.json): cada nivel secreto existe; el nivel de donde sale uno
    -- por salida secreta (`exit`) tiene la casilla `secret_exit`; cada coleccionable de jefe está en su nivel con su jefe
    -- y su icono existe; el mapa (overworld.json) tiene el camino de cada secreto
    do
        local Worlds = require 'src/story/Worlds'
        local bad, n = {}, 0
        local json = require 'libs/json'
        local function lvl(id) local ok, d = pcall(json.decode, love.filesystem.read('assets/levels/' .. id .. '.json') or ''); return ok and d or nil end
        local function tid(v) return (v % 16) + 16 * math.floor(v / 131072) end
        local ow = json.decode(love.filesystem.read('assets/story/overworld.json'))
        local owSecrets = {}
        for _, w in ipairs(ow.worlds) do for k in pairs(w.secrets or {}) do owSecrets[k] = true end end
        for _, W in ipairs(Worlds.LIST) do
            for _, e in ipairs(W.secrets or {}) do
                n = n + 1
                if not lvl(e.level) then bad[#bad + 1] = 'falta el nivel ' .. e.level end
                if not owSecrets[e.level] then bad[#bad + 1] = 'sin camino en el mapa: ' .. e.level end
                if e.exit then
                    local d, found = lvl(e.from), false
                    for _, row in ipairs(d and d.tiles or {}) do for _, v in ipairs(row) do if tid(v) == 44 then found = true end end end
                    if not found then bad[#bad + 1] = e.from .. ' sin salida secreta' end
                end
            end
        end
        for _, c in ipairs(require('src/story/Collect').LIST) do
            if not love.filesystem.getInfo(c.icon) then bad[#bad + 1] = 'falta el icono ' .. c.icon end
            local src = c.source or {}
            if src.boss then
                local d, has = lvl(src.level), false
                for _, e in ipairs(d and d.entities or {}) do if e.type == src.boss then has = true end end
                if not has then bad[#bad + 1] = c.id .. ': ' .. tostring(src.boss) .. ' no está en ' .. tostring(src.level) end
            end
        end
        check('secretos', #bad == 0, ('%d niveles secretos, %d coleccionables; problemas: %s'):format(n, #require('src/story/Collect').LIST,
            #bad == 0 and 'ninguno' or list(bad, 8)))
    end

    -- idiomas: la hoja assets/lang/translations.csv (src/core/Lang.lua) — cada clave con texto en TODOS los idiomas
    -- (salvo las que en español están vacías a propósito) y sin claves repetidas
    local Lang = require 'src/core/Lang'
    Lang.reload()
    local es = Lang.keys(Lang.DEFAULT)
    local diff, n, seen = {}, 0, {}
    for k, v in pairs(es) do
        n = n + 1
        for _, l in ipairs(Lang.LANGUAGES) do
            if l.id ~= Lang.DEFAULT and v ~= '' and Lang.keys(l.id)[k] == nil then diff[#diff + 1] = l.id .. ':' .. k end
        end
    end
    for _, row in ipairs(Lang.parseCSV(love.filesystem.read(Lang.FILE) or '')) do
        local k = row[1]
        if k and k ~= '' and k:sub(1, 1) ~= '#' then
            if seen[k] then diff[#diff + 1] = 'repetida:' .. k end
            seen[k] = true
        end
    end
    for _, l in ipairs(Lang.LANGUAGES) do if not next(Lang.keys(l.id)) then diff[#diff + 1] = 'sin columna:' .. l.id end end
    check('idiomas', #diff == 0, ('%d claves; faltan: %s'):format(n, #diff > 0 and list(diff, 10) or 'ninguna'))

    -- jefes: en un nivel con zona de jefe no hay nada (objetos, enemigos, mecanismos) más allá de la última zona —
    -- el nivel acaba al vencer al jefe —, salvo sus propios bloques de jefe (el usuario, 0.5.27)
    local json = require 'libs/json'
    local beyond, nB = {}, 0
    local files = {}
    local function levels(dir)
        for _, f in ipairs(love.filesystem.getDirectoryItems(dir)) do
            local p = dir .. '/' .. f
            if love.filesystem.getInfo(p, 'directory') then levels(p) elseif f:match('%.json$') then files[#files + 1] = p end
        end
    end
    levels('assets/levels')
    for _, p in ipairs(files) do
        local ok, d = pcall(json.decode, love.filesystem.read(p))
        if ok and type(d) == 'table' and type(d.bossZones) == 'table' and #d.bossZones > 0 then
            nB = nB + 1
            local last = 0
            for _, z in ipairs(d.bossZones) do last = math.max(last, (z.col or 1) + (z.w or 1) - 1) end
            for _, e in ipairs(d.entities or {}) do
                if (e.col or 0) > last and e.type ~= 'bosswall' then
                    beyond[#beyond + 1] = ('%s %s (col %d)'):format(p:match('([^/]+)%.json$'), e.type, e.col)
                end
            end
        end
    end
    check('jefes', #beyond == 0 and nB >= 7, ('%d niveles con zona de jefe; con algo más allá de la zona: %s'):format(
        nB, #beyond > 0 and list(beyond, 8) or 'ninguno'))

    -- docs: rutas y enlaces
    local ROOT = love.filesystem.getSource() .. '/../../../'
    local function exists(p) local f = io.open(ROOT .. p, 'rb'); if f then f:close(); return true end; return false end
    local pages = {}
    local function walkMd(dir)
        for _, f in ipairs(love.filesystem.getDirectoryItems(dir .. '/.')) do
            local p = dir .. '/' .. f
            local info = love.filesystem.getInfo(p)
            -- (docs/design/archive es historia: sus rutas son las de entonces)
            if info and info.type == 'directory' then if p ~= 'docs/design/archive' then walkMd(p) end
            elseif f:match('%.md$') then pages[#pages + 1] = p end
        end
    end
    walkMd('docs')
    for _, f in ipairs({ 'CLAUDE.md', 'README.md', 'tools/README.md' }) do pages[#pages + 1] = f end
    local broken, nRefs = {}, 0
    for _, page in ipairs(pages) do
        local fh = io.open(ROOT .. page, 'rb')
        local text = fh and fh:read('*a') or ''
        if fh then fh:close() end
        -- (un PLAN de implementación nombra archivos que aún no existen: con la marca `project_check: future-paths` en
        -- la página no se miran sus rutas entre comillas — los enlaces a otras páginas sí —)
        local future = text:find('project_check: future-paths', 1, true) ~= nil
        for p in (future and '' or text):gmatch('`([^`%s]+)`') do
            local root = p:match('^(%a+)/')
            if (root == 'src' or root == 'assets' or root == 'tools' or root == 'server' or root == 'libs' or root == 'docs')
               and not p:find('[<>*{}|$…]') and not p:find('...', 1, true) and not p:find('^server/published') then
                nRefs = nRefs + 1
                local q = p:gsub('[.,;:)]+$', ''):gsub('/$', '')
                if not exists(q) then broken[#broken + 1] = q .. ' (' .. page .. ')' end
            end
        end
        local dir = page:match('^(.*)/[^/]+$') or ''
        for link in text:gmatch('%]%(([^)#%s]+%.md)[^)]*%)') do
            if not link:match('^%a+://') then
                nRefs = nRefs + 1
                local parts = {}
                for seg in ((dir ~= '' and (dir .. '/') or '') .. link):gmatch('[^/]+') do
                    if seg == '..' then parts[#parts] = nil elseif seg ~= '.' then parts[#parts + 1] = seg end
                end
                local t = table.concat(parts, '/')
                if not exists(t) then broken[#broken + 1] = 'enlace ' .. link .. ' (' .. page .. ')' end
            end
        end
    end
    check('docs', #broken == 0 and #pages > 40, ('%d páginas, %d rutas y enlaces; rotos: %s'):format(#pages, nRefs, #broken > 0 and list(broken, 8) or 'ninguno'))

    print(fails == 0 and 'RESULTADO: OK' or ('RESULTADO: ' .. fails .. ' FALLOS'))
    love.event.quit(fails == 0 and 0 or 1)
end
