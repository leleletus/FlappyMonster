-- tools/tests/project_check — el PROYECTO está entero (lo que se rompe al mover o borrar archivos):
--   modulos     todo .lua de src/ carga con require (ninguna ruta de módulo rota)
--   catalogos   cada tipo de entidad, tile, decoración y modo se registra, y cada entidad se crea
--   rutas       toda ruta 'assets/...' escrita en el código (src/, server/, game.lua) existe
--   cargas      nada de lo que se carga de verdad (imágenes, sonidos, música del catálogo) falta en disco
--   idiomas     es.lua y en.lua tienen las mismas claves
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
        for _, k in ipairs({ 'file', 'intro', 'loop' }) do
            if tr[k] and not love.filesystem.getInfo(tr[k]) and not tr.pending then missing[#missing + 1] = tr[k] end
        end
    end
    local uniq, m2 = {}, {}
    for _, p in ipairs(missing) do if not uniq[p] then uniq[p] = true; m2[#m2 + 1] = p end end
    check('cargas', #m2 == 0, ('%d pistas de música; faltan en disco: %s'):format(#Music.list, #m2 > 0 and list(m2, 8) or 'nada'))

    -- idiomas
    local function flat(t, pre, out)
        for k, v in pairs(t) do
            local key = pre .. tostring(k)
            if type(v) == 'table' then flat(v, key .. '.', out) else out[key] = true end
        end
        return out
    end
    local es = flat(love.filesystem.load('assets/lang/es.lua')(), '', {})
    local en = flat(love.filesystem.load('assets/lang/en.lua')(), '', {})
    local diff, n = {}, 0
    for k in pairs(es) do n = n + 1; if not en[k] then diff[#diff + 1] = 'en:' .. k end end
    for k in pairs(en) do if not es[k] then diff[#diff + 1] = 'es:' .. k end end
    check('idiomas', #diff == 0, ('%d claves; faltan: %s'):format(n, #diff > 0 and list(diff, 10) or 'ninguna'))

    print(fails == 0 and 'RESULTADO: OK' or ('RESULTADO: ' .. fails .. ' FALLOS'))
    love.event.quit(fails == 0 and 0 or 1)
end
