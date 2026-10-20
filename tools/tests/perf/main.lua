-- tools/tests/perf — RENDIMIENTO Y MEMORIA (docs/testing/performance.md) con el juego real, a pasos fijos de 1/60 s.
-- Por cada escena: calienta WARM fotogramas y mide N:
--   · ms de CPU de update y de dibujo (media, p95, máximo)
--   · BASURA: KB de Lua que se crean por fotograma (con el recolector parado en una ventana de fotogramas)
--   · llamadas de dibujo, cambios de textura y memoria de texturas (love.graphics.getStats)
--   · RECURSOS creados DESPUÉS de cargar (newImage, newQuad, newCanvas, newFont, newSource, newShader...): deberían
--     ser 0 en régimen; se listan los sitios que los crean
--   · memoria de Lua tras una recolección completa al acabar
--   · PERFIL (jit.profile): las funciones donde más tiempo se va
-- Y FUGAS (fugas): entra en el mismo nivel varias veces seguidas (RELOADS=6): la memoria de Lua y de texturas tiene que estabilizarse.
--
--   tools/tests/run.sh perf                          todas las escenas
--   SCENES=menu,level:assets/levels/x.json,boss,map,flappy,fugas   las que se digan
--   N=600 WARM=120 TOP=25                           fotogramas medidos, de calentamiento, funciones del perfil
--   PROFILE=0                                       sin perfil
--   SHOTS=1                                         captura al final de cada escena: <save>/perf_<escena>.png
--   CALLERS=src/player/PlayerAdventure:getOuterBounds   quién llama a esa función y cuántas veces por fotograma
--   GARB=1                                          BASURA POR FUNCIÓN: envuelve las funciones de los módulos de src/ y
--                                                   cuenta los KB que crea cada una (sin contar las que llama)
-- Límites (FALLA si se pasan, con margen para máquinas lentas): basura por fotograma, recursos creados en régimen y
-- crecimiento de memoria entre recargas. Los ms solo se informan (dependen de la máquina).
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
love.filesystem.load('game_main.lua')()
local gameLoad, gameUpdate, gameDraw = love.load, love.update, love.draw

local DT = 1 / 60
local N, WARM = tonumber(os.getenv('N')) or 600, tonumber(os.getenv('WARM')) or 120
local TOP = tonumber(os.getenv('TOP')) or 25
local LIMIT_GARBAGE = tonumber(os.getenv('LIMIT_KB')) or 64       -- KB por fotograma
local LIMIT_LEAK = tonumber(os.getenv('LIMIT_LEAK')) or 64        -- KB de Lua que puede crecer por recarga (ya caliente)
local fails = 0
local function check(name, ok, msg)
    print(('%-12s %s  %s'):format(name, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end

local realInput, co, frameHook
local held = {}
local measuring, created = false, {}
local profiler = (os.getenv('PROFILE') ~= '0') and select(2, pcall(require, 'jit.profile')) or nil
if type(profiler) ~= 'table' then profiler = nil end
local samples = {}

-- ── Recursos creados: se envuelven los constructores de LÖVE ──────────────
local function wrap(mod, name)
    local orig = mod[name]
    if not orig then return end
    mod[name] = function(...)
        if measuring then
            local info = debug.getinfo(2, 'Sl')
            local key = name .. '  ' .. (info and (info.short_src .. ':' .. info.currentline) or '?')
            created[key] = (created[key] or 0) + 1
        end
        return orig(...)
    end
end
for _, n in ipairs({ 'newImage', 'newQuad', 'newCanvas', 'newFont', 'newImageFont', 'newShader', 'newMesh', 'newSpriteBatch',
                     'newParticleSystem', 'newText' }) do wrap(love.graphics, n) end
wrap(love.audio, 'newSource')
wrap(love.image, 'newImageData')
wrap(love.sound, 'newSoundData')
wrap(love.filesystem, 'read')

-- ── Basura por función (GARB=1): tools/tests/lib/garbage_profile.lua ──────
local GP = os.getenv('GARB') and require('tools/tests/lib/garbage_profile') or nil
local callers

-- ── Pasos ─────────────────────────────────────────────────────────────────
local function top() return gStateMachine:_top() end
local stats = nil
local function tick()
    Input = setmetatable({ pressed = function(x) return held[x] == 'press' end,
                           down = function(x) return held[x] ~= nil end }, { __index = realInput })
    for k, v in pairs(held) do if v == 'press' then held[k] = true end end
    local t0 = love.timer.getTime()
    gameUpdate(DT)
    local t1 = love.timer.getTime()
    Input = realInput
    if frameHook then frameHook() end
    if stats then stats.upd[#stats.upd + 1] = (t1 - t0) * 1000 end
end
local function wait(n) for i = 1, n do tick(); coroutine.yield() end end

local function pct(t, p)
    local c = {}
    for i, v in ipairs(t) do c[i] = v end
    table.sort(c)
    return c[math.max(1, math.floor(#c * p + 0.5))] or 0
end
local function avg(t) local s = 0; for _, v in ipairs(t) do s = s + v end; return #t > 0 and s / #t or 0 end
local function mem() collectgarbage('collect'); collectgarbage('collect'); return collectgarbage('count') end

-- Mide la escena que ya está en pantalla
local function measure(name, lazyOk)
    wait(WARM)
    stats = { upd = {}, draw = {}, calls = {}, switches = {} }
    created = {}
    if GP then GP.reset() end
    measuring = true
    samples = {}
    if profiler then
        profiler.start('fl', function(th, n, vm)
            local k = profiler.dumpstack(th, 'pF|', 1):gsub('|$', '')
            samples[k] = (samples[k] or 0) + n
        end)
    end
    -- basura: el recolector parado en ventanas de 60 fotogramas
    local garbage = {}
    local done = 0
    while done < N do
        collectgarbage('collect')
        collectgarbage('stop')
        local k0 = collectgarbage('count')
        local w = math.min(60, N - done)
        wait(w)
        garbage[#garbage + 1] = (collectgarbage('count') - k0) / w
        collectgarbage('restart')
        done = done + w
    end
    if profiler then profiler.stop() end
    measuring = false
    if callers then
        local cl = {}
        for k, v in pairs(callers) do cl[#cl + 1] = { k, v } end
        table.sort(cl, function(a, b) return a[2] > b[2] end)
        print('   llamadas a ' .. os.getenv('CALLERS') .. ' por fotograma, por quién llama:')
        for i = 1, math.min(TOP, #cl) do print(('      %7.1f  %s'):format(cl[i][2] / N, cl[i][1])) end
        callers = {}
    end
    if GP then
        print('   basura por función (KB por fotograma, sin las que llama):')
        for _, e in ipairs(GP.top(TOP, N)) do print(('      %7.2f  %s'):format(e[2], e[1])) end
    end
    local st = stats
    stats = nil
    if os.getenv('SHOTS') then
        local fn = 'perf_' .. name:gsub('[^%w]+', '_') .. '.png'
        love.graphics.captureScreenshot(function(img) img:encode('png', fn) end)
        wait(2)
    end
    local g = avg(garbage)
    local tex = love.graphics.getStats()
    print(('── %s'):format(name))
    print(('   update  %.2f ms (p95 %.2f, máx %.2f)   dibujo %.2f ms (p95 %.2f, máx %.2f)'):format(
        avg(st.upd), pct(st.upd, 0.95), pct(st.upd, 1), avg(st.draw), pct(st.draw, 0.95), pct(st.draw, 1)))
    print(('   basura %.1f KB/fotograma (máx %.1f)   llamadas de dibujo %.0f (máx %d)   cambios de textura %.0f   texturas %.1f MB (%d imágenes, %d canvases)'):format(
        g, pct(garbage, 1), avg(st.calls), pct(st.calls, 1), avg(st.switches), tex.texturememory / 1048576, tex.images, tex.canvases))
    print(('   Lua %.0f KB tras recolectar'):format(mem()))
    local list, total = {}, 0
    for k, v in pairs(created) do list[#list + 1] = { k, v }; total = total + v end
    table.sort(list, function(a, b) return a[2] > b[2] end)
    print(('   recursos creados en régimen: %d'):format(total))
    for i = 1, math.min(12, #list) do print(('      %5d  %s'):format(list[i][2], list[i][1])) end
    if profiler then
        local pl, ps = {}, 0
        for k, v in pairs(samples) do pl[#pl + 1] = { k, v }; ps = ps + v end
        table.sort(pl, function(a, b) return a[2] > b[2] end)
        print('   perfil (muestras, función):')
        for i = 1, math.min(TOP, #pl) do print(('      %5.1f%%  %s'):format(100 * pl[i][2] / ps, pl[i][1])) end
    end
    check('basura', g <= LIMIT_GARBAGE, ('%s: %.1f KB por fotograma (límite %d)'):format(name, g, LIMIT_GARBAGE))
    -- (los archivos que se leen en régimen cuentan como recursos: deberían leerse al cargar)
    if lazyOk then
        print(('   (recursos: solo se informa; esta escena carga cosas nuevas sobre la marcha: %d)'):format(total))
    else
        -- (un sitio que crea algo UNA o dos veces es una carga perezosa la primera vez que hace falta: un efecto que
        -- aparece; lo que se crea en cada fotograma sale decenas de veces)
        local worst = list[1] and list[1][2] or 0
        check('recursos', worst < 3, ('%s: %d recursos creados en régimen (el sitio que más: %d)'):format(name, total, worst))
    end
    return { garbage = g, created = total }
end

-- ── Escenas ───────────────────────────────────────────────────────────────
local SC = {}

function SC.menu()
    gStateMachine:change('title')
    wait(120); held.confirm = 'press'; wait(2); held.confirm = nil
    -- (el fondo cambia de carrera: cada nivel nuevo llena sus cachés)
    measure('menú (fondo vivo + botones)', true)
end

local function playLevel(path, name, place)
    gStateMachine:change('adventure', { level = path })
    local st = top()
    if place then place(st) end
    -- el jugador corre a la derecha y salta de vez en cuando
    local f = 0
    frameHook = function()
        f = f + 1
        held.right = true
        if f % 50 == 0 then held.jump = 'press' elseif f % 50 == 12 then held.jump = nil end
    end
    measure(name)
    frameHook = nil; held = {}
end

SC.level = function(arg)
    local path = arg or 'assets/levels/laberinto_submarino.json'
    playLevel(path, 'nivel ' .. path:match('[^/]+$'))
end

function SC.boss()
    playLevel('assets/levels/guarida_cangrejo_rey.json', 'jefe (guarida_cangrejo_rey)', function(st)
        for _, e in ipairs(st.enemies) do
            if e.def.boss and e.zone then st.player.x, st.player.y = e.zone.x0 + 2 * TILE_PX, e.zone.y1 - 60 end
        end
    end)
end

-- El MAPA del modo historia (una partida de prueba en memoria; el monstruo anda de parada en parada)
function SC.map()
    local Run, Save = require 'src/story/Run', require 'src/story/Save'
    Run.slot, Run.data = nil, Save.new('normal')                 -- (sin hueco: no se escribe nada)
    gStateMachine:change('story_map', { world = 1, node = 1 })
    local f = 0
    frameHook = function()
        f = f + 1
        if f % 70 == 0 then held.right = 'press' elseif f % 70 == 2 then held.right = nil end
    end
    measure('mapa de la historia', true)                     -- (anda: entra en zonas nuevas y llena sus cachés)
    frameHook = nil; held = {}
    gStateMachine:change('title')                                -- (antes de soltar la partida: el mapa la dibuja)
    Run.slot, Run.data = nil, nil
end

function SC.flappy()
    gStateMachine:change('play', { difficulty = 'normal' })
    local f = 0
    frameHook = function() f = f + 1; if f % 22 == 0 then held.flap = 'press' else held.flap = nil end end
    measure('flappy')
    frameHook = nil; held = {}
end

-- Censo de la memoria: tamaño de cada tabla alcanzable desde los globales y los módulos, por su camino
local function census()
    local seen, out = {}, {}
    local walk
    local function walkFn(f, path, depth)
        if seen[f] or depth > 12 then return end
        seen[f] = true
        for i = 1, 200 do
            local nm, v = debug.getupvalue(f, i)
            if not nm then break end
            if type(v) == 'table' then walk(v, path .. '^' .. nm, depth + 1)
            elseif type(v) == 'function' then walkFn(v, path .. '^' .. nm, depth + 1) end
        end
    end
    walk = function(t, path, depth)
        if seen[t] or depth > 12 then return end
        seen[t] = true
        local n = 0
        for k, v in pairs(t) do
            n = n + 1
            local kk = type(k) == 'string' and k or ('[' .. type(k) .. ']')
            if type(v) == 'table' then walk(v, path .. '.' .. kk, depth + 1)
            elseif type(v) == 'function' then walkFn(v, path .. '.' .. kk .. '()', depth + 1) end
            if type(k) == 'table' then walk(k, path .. '.<clave>', depth + 1) end
        end
        local mt = getmetatable(t)
        if type(mt) == 'table' then walk(mt, path .. '.<mt>', depth + 1) end
        out[path] = n
    end
    walk(package.loaded, 'package.loaded', 0)
    walk(_G, '_G', 0)
    return out
end

-- Fugas: entrar varias veces seguidas en el mismo nivel
function SC.fugas()
    local path = 'assets/levels/laberinto_submarino.json'
    local m, tex = {}, {}
    local cens
    local R = math.max(6, tonumber(os.getenv('RELOADS')) or 8)
    for i = 1, R do
        -- (seguidas, sin el menú entre medias: su fondo cambia de nivel y la memoria sube y baja con él)
        created, measuring = {}, true
        gStateMachine:change('adventure', { level = path })
        wait(90)
        measuring = false
        if os.getenv('LEAKS') and i > 1 and love.graphics.getStats().texturememory / 1048576 - tex[i - 1] > 0.5 then
            print(('   la recarga %d sube las texturas: lo que se creó'):format(i))
            for k, v in pairs(created) do if k:match('^newImage') or k:match('^newCanvas') then print('      ', v, k) end end
        end
        m[i] = mem()
        tex[i] = love.graphics.getStats().texturememory / 1048576
        if os.getenv('LEAKS') and (i == 4 or i == R) then cens = cens or {}; cens[i] = census() end
    end
    local line = {}
    for i = 1, #m do line[#line + 1] = ('%.0f KB / %.1f MB'):format(m[i], tex[i]) end
    print('── fugas (Lua / texturas tras cada recarga): ' .. table.concat(line, '  ·  '))
    if cens then
        local g = {}
        for k, n in pairs(cens[R]) do
            local d = n - (cens[4][k] or 0)
            if d > 0 then g[#g + 1] = { k, d, n } end
        end
        table.sort(g, function(a, b) return a[2] > b[2] end)
        print('   tablas que crecen de la 4ª a la última recarga (camino, +entradas, entradas):')
        for i = 1, math.min(TOP, #g) do print(('      %+6d %6d  %s'):format(g[i][2], g[i][3], g[i][1])) end
    end
    -- (las tres primeras cargan cosas una vez: cachés, texturas que se piden más tarde)
    local grow = (m[R] - m[4]) / (R - 4)
    check('fugas', grow <= LIMIT_LEAK and tex[R] - tex[4] <= 0.01,
          ('de la 4ª a la %dª recarga: Lua %+.0f KB por recarga (límite %d), texturas %+.1f MB'):format(R, grow, LIMIT_LEAK, tex[R] - tex[4]))
end

local function run()
    local list = os.getenv('SCENES') or 'menu,level,level:assets/levels/caldera_roja.json,boss,map,flappy,fugas'
    for item in list:gmatch('[^,]+') do
        local nm, arg = item:match('^([^:]+):?(.*)$')
        if SC[nm] then SC[nm](arg ~= '' and arg or nil) else print('escena desconocida: ' .. nm); fails = fails + 1 end
    end
    print(fails == 0 and 'TODO OK' or ('FALLAN %d'):format(fails))
    love.event.quit(fails == 0 and 0 or 1)
end

function love.load(a)
    gameLoad(a)
    for _, cb in ipairs({ 'mousemoved', 'mousepressed', 'mousereleased', 'wheelmoved', 'touchpressed', 'touchmoved', 'touchreleased', 'focus' }) do love[cb] = function() end end
    love.audio.setVolume(0)
    realInput = Input
    if os.getenv('CALLERS') then
        local mod, sep, fn = os.getenv('CALLERS'):match('^(.-)([.:])([%w_]+)$')
        local M = require(mod)
        local T = (sep == ':' and getmetatable(M) and type(getmetatable(M).__index) == 'table' and not rawget(M, fn)) and getmetatable(M).__index or M
        local f = T[fn]
        callers = {}
        T[fn] = function(...)
            if measuring then
                local i = debug.getinfo(2, 'Sln')
                local k = i and (i.short_src .. ':' .. (i.currentline or 0) .. ' ' .. (i.name or '?')) or '?'
                callers[k] = (callers[k] or 0) + 1
            end
            return f(...)
        end
    end
    if os.getenv('GARB') then
        -- (todos los módulos cargados: se piden antes las escenas para que estén)
        for _, m in ipairs({ 'src/states/adventure/AdventureState', 'src/world/level/Level', 'src/fx/Darkness', 'src/fx/Sky' }) do require(m) end
        GP.wrap()
    end
    co = coroutine.create(run)
end

function love.update()
    if not co or coroutine.status(co) == 'dead' then return end
    local ok, err = coroutine.resume(co)
    if not ok then print('Error: ' .. tostring(err)); print(debug.traceback(co)); love.event.quit(1) end
end

function love.draw()
    local t0 = love.timer.getTime()
    gameDraw()
    if stats then
        stats.draw[#stats.draw + 1] = (love.timer.getTime() - t0) * 1000
        local s = love.graphics.getStats()
        stats.calls[#stats.calls + 1] = s.drawcalls
        stats.switches[#stats.switches + 1] = s.shaderswitches + (s.canvasswitches or 0)
    end
end
