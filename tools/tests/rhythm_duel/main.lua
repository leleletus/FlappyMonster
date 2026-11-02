-- tools/tests/rhythm_duel — EL DUELO DE RITMO (src/ui/RhythmDuel.lua; assets/charts/groove.json), sin ventana:
--   chart      cada dificultad tiene notas en todo compás de bajo; Difícil y más, el mismo chart 1:1 ordenado; carriles válidos
--   facil      Fácil tiene menos notas que Normal y Normal menos que el 1:1; más margen en las dificultades bajas
--   perfecto   pulsar todas justo a tiempo: 100 %, noquea
--   nada       no pulsar nada: se vacía el medidor antes de acabar (hacia 1/3) y da fallo
--   margen     una pulsación fuera de su margen no cuenta; dentro, sí
--   vacio      pulsar sin nota no castiga
--   revive     muerto o reapareciendo al empezar: en cuanto vive, salen las notas y juega
--   sinchart   sin notas: acaba enseguida, sin castigo (nadie se queda esperando)
--   poses      el monstruo: acertar pone la pose de su flecha, dejarla pasar la de fallo; cada una se avisa (online:
--              rhythm_pose) y la de otro jugador se guarda (R.remotePose)
--   jugadores  (informa) jugadores simulados con distinto error de tiempo: % que falla y % que noquea por dificultad
--   tools/tests/run.sh rhythm_duel   (CASE=nombre)
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
require 'settings'
Sound = setmetatable({}, { __index = function() return function() end end })
local P = require 'src/network/Protocol'
Input = P.newInputStub()
local json = require 'libs/json'
local R = require 'src/ui/RhythmDuel'
local Entities = require 'src/world/entities/Entities'
local GC
for _, t in pairs({ require 'src/world/entities/types/bosses/groovecrab' }) do GC = t.class end
local fails = 0
local function check(case, ok, msg)
    print(('%-10s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end
local DT = 1 / 60
local BAR = 8 + 16                                    -- (compás 24: el comienzo de la B)
local function setup(diff, bar, bars)
    local d = { bar = bar or BAR, bars = bars or 8 }
    local boss = setmetatable({ songT = (d.bar - 1) * GC.BAR, props = {} }, { __index = GC })
    boss.duelInfo = function() return d end
    return boss, { bossZones = { { bosses = { boss } } }, difficulty = diff }
end
-- Una partida. pressFor(note) → cuándo se pulsa (nil: no se pulsa). → la partida
local function play(diff, pressFor, bar, bars)
    R.reset()
    local boss, level = setup(diff, bar, bars)
    local result
    local who = { alive = true }
    local c
    local presses
    local function step()
        boss.songT = boss.songT + DT
        R.update(DT, level, who, function(b, acc, failed) result = { acc = acc, failed = failed } end, function()
            c = R.current()
            if not presses then
                presses = {}
                for _, n in ipairs(c.notes) do
                    local t = pressFor(n)
                    if t then presses[#presses + 1] = { t, n.lane } end
                end
                table.sort(presses, function(a, b) return a[1] < b[1] end)
                presses.i = 1
            end
            while presses[presses.i] and presses[presses.i][1] <= c.clock do
                R.press(presses[presses.i][2])
                presses.i = presses.i + 1
            end
        end)
    end
    for _ = 1, 60 * 60 do
        step()
        if result then break end
    end
    return result, R.current()
end
local CASES = {}
function CASES.poses()
    R.reset()
    local boss, level = setup('normal')
    local who, sent = { alive = true }, {}
    local onPose = function(l, ok) sent[#sent + 1] = { l, ok } end
    boss.songT = boss.songT + GC.BAR                                    -- (ya en el duelo)
    R.update(DT, level, who, nil, function() end, onPose)
    local c = R.current()
    local n1 = c.notes[c.first]
    c.clock = n1.t
    R.press(n1.lane)
    local hitPose = c.pose and c.pose.lane == n1.lane and c.pose.ok
    -- la siguiente se deja pasar
    local n2 = c.notes[c.first + 1] or c.notes[c.first]
    for _ = 1, 600 do
        boss.songT = boss.songT + DT
        R.update(DT, level, who, nil, function() end, onPose)
        if c.misses > 0 then break end
    end
    local missPose = c.pose and c.pose.ok == false and c.pose.lane >= 1
    R.remotePose(42, 3, true)
    local rem = c.remote[42]
    check('poses', hitPose and missPose and #sent >= 2 and sent[1][2] == true and rem and rem.lane == 3 and rem.ok,
        ('acierto → pose %s=%s · fallo → pose de fallo=%s · avisos %d · otro jugador: carril %s'):format(n1.lane,
            tostring(hitPose), tostring(missPose), #sent, tostring(rem and rem.lane)))
end
function CASES.chart()
    local data = json.decode(love.filesystem.read('assets/charts/groove.json'))
    check('chart', data.bars == GC.INTRO_BARS + GC.LOOP, 'compases: ' .. data.bars)
    for name, c in pairs(data.charts) do
        local n, ok, bars = 0, true, 0
        for b, row in pairs(c) do
            bars = bars + 1
            local prev = -1
            for i = 1, #row, 2 do
                n = n + 1
                if row[i] <= prev or row[i] < 0 or row[i] > 15 or row[i + 1] < 0 or row[i + 1] > 3 then ok = false end
                prev = row[i]
            end
        end
        check('chart', ok and bars >= data.bars - 1, ('%s: %d notas en %d compases'):format(name, n, bars))
    end
end
function CASES.facil()
    local data = json.decode(love.filesystem.read('assets/charts/groove.json'))
    local function count(name) local n = 0; for _, r in pairs(data.charts[name]) do n = n + #r / 2 end; return n end
    check('facil', count('easy') < count('normal') and count('normal') < count('full'),
          ('fácil %d < normal %d < 1:1 %d'):format(count('easy'), count('normal'), count('full')))
    local D = GC.DUEL
    check('facil', D.easy.window > D.normal.window and D.normal.window > D.hard.window and D.hard.window > D.extreme.window
          and D.extreme.window > D.xtra.window and D.hard.chart == 'full' and D.xtra.chart == 'full',
          'el margen se estrecha por dificultad; Difícil y más, 1:1')
end
function CASES.perfecto()
    for _, d in ipairs({ 'easy', 'normal', 'hard', 'extreme', 'xtra' }) do
        local r, c = play(d, function(n) return n.t end)
        check('perfecto', r and not r.failed and r.acc > 0.99 and c.ko, ('%s: %.0f %% de %d'):format(d, (r and r.acc or 0) * 100, c.n))
    end
end
function CASES.nada()
    for _, d in ipairs({ 'easy', 'xtra' }) do
        local r, c = play(d, function() return nil end)
        check('nada', r and r.failed and c.first < #c.notes * 0.5, ('%s: acaba en la nota %d de %d'):format(d, c.first, #c.notes))
    end
end
function CASES.margen()
    local W = GC.DUEL.normal.window
    local _, c = play('normal', function(n) return n.t + W + 0.05 end)
    check('margen', c.hits == 0 or c.hits < c.n * 0.5, ('tarde, fuera del margen: %d de %d (las que aciertan, con la nota de después)'):format(c.hits, c.n))
    local r2, c2 = play('normal', function(n) return n.t + W * 0.6 end)
    check('margen', c2.hits > c2.n * 0.9, ('dentro del margen: %d de %d'):format(c2.hits, c2.n))
end
function CASES.revive()
    R.reset()
    local boss, level = setup('normal')
    local who = { alive = true, dying = true }
    R.update(DT, level, who, nil, function() end)
    local c = R.current()
    check('revive', c and not c.playing, 'muriendo al empezar: aún no juega')
    who.dying = false
    boss.songT = boss.songT + 3
    R.update(DT, level, who, nil, function() end)
    check('revive', c.playing and c.n < #c.notes, ('reaparece: juega las %d notas que faltan de %d'):format(c.n, #c.notes))
    local r
    for _ = 1, 60 * 30 do
        boss.songT = boss.songT + DT
        R.update(DT, level, who, function(b, a, f) r = { a, f } end, function()
            for i = c.first, math.min(c.first + 6, #c.notes) do
                local n = c.notes[i]
                if not n.judged and math.abs(n.t - c.clock) < 0.02 then R.press(n.lane) end
            end
        end)
        if r then break end
    end
    check('revive', r and not r[2] and r[1] > 0.9, ('y puede ganar: %.0f %%'):format((r and r[1] or 0) * 100))
end
function CASES.sinchart()
    R.reset()
    local boss, level = setup('normal')
    boss.DUEL = { normal = setmetatable({ chart = 'no_existe' }, { __index = GC.DUEL.normal }) }
    local r
    R.update(DT, level, { alive = true }, function(b, a, f) r = { a, f } end, function() end)
    check('sinchart', r and r[2] == false, 'acaba al momento, sin castigo')
end
function CASES.vacio()
    R.reset()
    local boss, level = setup('normal')
    R.update(DT, level, { alive = true }, nil, function() end)
    local c = R.current()
    local m = c.meter
    for l = 1, 4 do R.press(l) end
    check('vacio', c.meter == m and c.misses == 0, 'pulsar sin nota no castiga')
end
local function gauss(s) return s * math.sqrt(-2 * math.log(1 - math.random())) * math.cos(2 * math.pi * math.random()) end
function CASES.jugadores()
    math.randomseed(1101)
    print('jugador con error de tiempo (ms) y notas que se le escapan: % falla / % noquea, 40 duelos de 8 compases')
    local players = { { 30, 0.01 }, { 50, 0.03 }, { 70, 0.06 }, { 100, 0.12 }, { 140, 0.25 } }
    for _, d in ipairs({ 'easy', 'normal', 'hard', 'extreme', 'xtra' }) do
        local row = {}
        for _, p in ipairs(players) do
            local F, K = 0, 0
            for i = 1, 40 do
                local bar = ({ 8, 24, 40, 48, 56, 72 })[i % 6 + 1]
                local r, c = play(d, function(n) if math.random() < p[2] then return nil end; return n.t + gauss(p[1] / 1000) end, bar)
                if r and r.failed then F = F + 1 elseif c.ko then K = K + 1 end
            end
            row[#row + 1] = ('%3dms %3d/%3d'):format(p[1], F * 100 / 40, K * 100 / 40)
        end
        print(('  %-8s %s'):format(d, table.concat(row, '   ')))
    end
end
-- SHOT=1: el duelo dibujado de verdad, en una imagen
function CASES.shot()
    FONT_MED = love.graphics.newFont('assets/fonts/PressStart2P.ttf', 16)
    WINDOW_W, WINDOW_H = 1280, 720
    package.loaded['src/core/Lang'].set('es')
    local boss, level = setup('hard', 48)
    R.reset()
    local who = { alive = true }
    boss.songT = 48 * GC.BAR + 2
    R.update(DT, level, who, nil, function() end)
    local c = R.current()
    c.clock = boss.songT; c.lit[3] = 0.1; c.hit[3] = 0.1; c.text, c.textT = 'rhythm.perfect', 0.5; c.meter = 72
    local cv = love.graphics.newCanvas(1280, 720)
    love.graphics.setCanvas(cv)
    love.graphics.clear(0.35, 0.5, 0.7, 1)
    R.drawDim()
    R.draw({ { me = true }, { id = 2, color = { 1, 0.3, 0.3 } }, { id = 3, color = { 0.3, 1, 0.4 } } })
    love.graphics.setCanvas()
    cv:newImageData():encode('png', 'duelo.png')
    print('imagen en ' .. love.filesystem.getSaveDirectory() .. '/duelo.png')
end
function love.load()
    if os.getenv('SHOT') then CASES.shot(); love.event.quit(0); return end
    local only = os.getenv('CASE')
    for _, name in ipairs({ 'chart', 'facil', 'perfecto', 'nada', 'margen', 'vacio', 'revive', 'sinchart', 'poses', 'jugadores' }) do
        if not only or only == name then CASES[name]() end
    end
    print(fails == 0 and 'RESULTADO: OK' or ('RESULTADO: ' .. fails .. ' FALLOS'))
    love.event.quit(fails == 0 and 0 or 1)
end
