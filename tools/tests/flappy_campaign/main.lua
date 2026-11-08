-- tools/tests/flappy_campaign — la CAMPAÑA FLAPPY a nivel de módulos (docs/design/flappy-plan-3-campaign-frame.md):
--   archivo    SaveFile: escribir y leer una tabla; un archivo roto se lee como nil + dañado y NO se sobrescribe
--   progreso   RunCore con un catálogo de mentira (2 mundos x 2 nodos): orden de los nodos, el mundo siguiente tras el
--              jefe, frontier, score (mejor nota, puntos), restartWorld (borra lo superado del mundo y guarda los récords)
--   (los casos de pantallas — mapa, partidas, CONTINUAR — van en menu_flow, que corre el juego de verdad)
--
--   tools/tests/run.sh flappy_campaign   (CASE=nombre: solo ese)
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
require 'settings'
Sound = setmetatable({ play = function() end }, { __index = function() return function() end end })

local fails = 0
local function check(case, ok, msg)
    print(('%-10s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end
local function deepEq(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return a == b end
    for k, v in pairs(a) do if not deepEq(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

local cases = {}

function cases.archivo()
    local SaveFile = require 'src/core/SaveFile'
    local data = { a = 1, t = { 'x' }, s = 'hola "q"' }
    local wrote = SaveFile.write('prueba.sav', data)
    local back, dmg = SaveFile.read('prueba.sav')
    local roundOk = wrote and deepEq(back, data) and not dmg
    local garbage = 'esto no es Lua {{{'
    love.filesystem.write('flappy9.sav', garbage)
    love.filesystem.remove('flappy9.sav.bak')
    local d2, dmg2 = SaveFile.read('flappy9.sav')
    local kept = love.filesystem.read('flappy9.sav') == garbage
    local mt = SaveFile.modtime('prueba.sav')
    SaveFile.remove('prueba.sav')
    local gone = love.filesystem.getInfo('prueba.sav') == nil and love.filesystem.getInfo('prueba.sav.bak') == nil
    love.filesystem.remove('flappy9.sav'); love.filesystem.remove('flappy9.sav.damaged')
    check('archivo', roundOk and d2 == nil and dmg2 == true and kept and type(mt) == 'number' and gone,
          ('ida y vuelta=%s; roto → nil=%s, dañado=%s, intacto=%s; modtime=%s; borrar=%s'):format(
           tostring(roundOk), tostring(d2 == nil), tostring(dmg2), tostring(kept), tostring(mt), tostring(gone)))
end

function cases.progreso()
    local RunCore = require 'src/story/RunCore'
    local store = {}
    local saves = { SLOTS = 3,
        new = function(diff) return { difficulty = diff or 'normal', world = 1, node = 1, lives = 3, done = {}, best = {},
                                      playTime = 0, points = 0, gameOvers = 0 } end,
        load = function(i) return store[i] end,
        write = function(i, d) store[i] = d; return true end }
    local W = { { id = 'a', levels = { 'a1' }, boss = 'a2' }, { id = 'b', levels = { 'b1' }, boss = 'b2' } }
    local worlds = { count = function() return #W end, get = function(w) return W[w] end,
        nodes = function(w) local n = {}; for _, id in ipairs(W[w].levels) do n[#n + 1] = { id = id } end
                            n[#n + 1] = { id = W[w].boss }; return n end }
    local R = {}
    RunCore.install(R, saves, worlds)
    R.open(1, 'normal')
    local s0 = R.state(1, 1) == 'open' and R.state(1, 2) == 'locked' and not R.worldOpen(2)
    local sum = R.score('a1', { time = 10, width = 40, score = 500 })
    local s1 = R.state(1, 2) == 'open' and sum and sum.grade ~= nil and R.data.best.a1 ~= nil and R.data.points > 0
    R.score('a2', { time = 10, width = 40 })
    local s2 = R.worldOpen(2) and R.state(2, 1) == 'open'
    local fw, fk = R.frontier()
    local done, total = R.progress()
    R.restartWorld(1)
    local s3 = not R.isDone('a1') and not R.isDone('a2') and R.data.best.a1 ~= nil and store[1] == R.data
    R.setLives(0)
    check('progreso', s0 and s1 and s2 and fw == 2 and fk == 1 and done == 2 and total == 4 and s3 and R.data.lives == 1,
          ('al empezar=%s; tras a1=%s; tras el jefe, mundo 2=%s; frontier %s,%s; progreso %d/%d; reiniciar el mundo 1=%s; vidas mínimas %d'):format(
           tostring(s0), tostring(s1), tostring(s2), tostring(fw), tostring(fk), done, total, tostring(s3), R.data.lives))
end

local ORDER = { 'archivo', 'progreso' }
function love.load()
    local only = os.getenv('CASE')
    for _, name in ipairs(ORDER) do
        if not only or only == name then
            local ok, err = pcall(cases[name])
            if not ok then check(name, false, 'error de Lua: ' .. tostring(err)) end
        end
    end
    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
