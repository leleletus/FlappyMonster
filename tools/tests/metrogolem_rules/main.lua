-- tools/tests/metrogolem_rules — reglas del GÓLEM METRÓNOMO (types/bosses/metrogolem.lua) caso a caso, en su nivel
-- real (assets/levels/santuario_del_compas.json), con el reloj de compás del nivel (150 BPM):
--   pendulo   en cada pulso la pesa está en un extremo y a mitad de pulso abajo; tocarla daña (hurt); lejos, nada; en
--             la fase 3 va dos lados por pulso
--   persigue  flotando va a por el jugador por toda la arena: en 7 s se le pone encima (en x) y la pesa, abajo, le pasa
--             a la altura del cuerpo — en el suelo y subido a una repisa —
--   plataforma  cae donde está el jugador: en la repisa, en el suelo (también debajo de una repisa) o en la plataforma
--             alta de Bloques Beep — nunca al fondo de la zona —
--   golpe     con las frases cumplidas, en el pulso 5 carga (la diana sigue al jugador), en el pulso 1 de la frase
--             siguiente cae EN la diana (≤ 24 px) justo en el cambio de los Bloques Beep; aplasta (-2) al de debajo y
--             queda ATURDIDO
--   inmune    flotando, caerle encima solo rebota; aturdido, el pisotón le quita 1 y se levanta (un golpe por ocasión)
--   ondas     desde la fase 2, al caer salen dos ondas por el suelo que se separan y dañan a ras de suelo
--   fases     la vida a 2/3 → fase 2, a 1/3 → fase 3
--   tempo     el reloj de compás va al tempo de la música de la pelea mientras pelea (150) y vuelve al del nivel (140)
--   red       netPackExtra → otro Gólem (cliente): misma fase, diana, ángulo guardado; con el mismo reloj, la misma
--             pesa y las mismas zonas de peligro
--
--   tools/tests/run.sh metrogolem_rules   (CASE=nombre)
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
require 'settings'
Sound = setmetatable({}, { __index = function() return function() end end })
local P = require 'src/network/Protocol'
local stub = P.newInputStub()
Input = stub
local json = require 'libs/json'
local Level = require 'src/world/level/Level'
local Entities = require 'src/world/entities/Entities'
local BossZones = require 'src/world/systems/BossZones'
local BeatClock = require 'src/world/systems/BeatClock'
local Interactions = require 'src/world/entities/base/Interactions'
local PlayerAdventure = require 'src/player/PlayerAdventure'
local T = TILE_PX
local DT = 1 / 60

local fails = 0
local function check(case, ok, msg)
    print(('%-10s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end

local LEVEL = 'assets/levels/santuario_del_compas.json'
local function arena()
    local f = assert(io.open(LEVEL, 'r'))
    local data = json.decode(f:read('*a')); f:close()
    local level = Level.fromData(data)
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    level.liveEntities = es
    BossZones.link(level, es)
    local boss
    for _, e in ipairs(es) do if e.def.name == 'metrogolem' then boss = e end end
    boss.levelRef = level
    level.players = {}
    boss:startFight(1)
    return level, es, boss
end

local BEAT = function(level) return level.beat.period / 8 end
local function at(level, beats) level.beat.t = beats * BEAT(level) end

local function playerAt(level, col)
    local pa = PlayerAdventure:new((col - 0.5) * T, 25 * T - 60)
    for k in pairs(stub.state) do stub.state[k] = false end
    level.players = { pa }
    for _ = 1, 30 do pa:update(DT, level) end
    return pa
end

local function step(level, es, players, secs, each)
    for _ = 1, math.floor(secs * 60 + 0.5) do
        level.players = players
        BeatClock.update(level, DT, nil)
        level.solidBodies = Entities.solidBodies(es)
        for k in pairs(stub.state) do stub.state[k] = false end
        for _, pa in ipairs(players) do pa:update(DT, level) end
        for _, e in ipairs(es) do if e.alive then e:update(DT, level) end end
        if each and each() then return true end
    end
end

local cases = {}

function cases.pendulo()
    local level, es, g = arena()
    local parts, ok = {}, true
    local function want(c, m) parts[#parts + 1] = m .. (c and '' or ' ✗'); ok = ok and c end
    local px, py = g:pivot()
    at(level, 8); local x0, y0 = g:bobPos()
    at(level, 9); local x1 = g:bobPos()
    at(level, 8.5); local xm, ym = g:bobPos()
    want(x0 > px + 3 * T and x1 < px - 3 * T, ('extremos en el pulso (%d, %d)'):format(x0 - px, x1 - px))
    want(math.abs(xm - px) < 2 and ym > y0 + T, 'a mitad de pulso, abajo')
    -- daña al tocarla
    local pa = PlayerAdventure:new(xm, ym)
    level.players = { pa }
    local r = Interactions.check(pa, g)
    want(r == 'hurt', 'la pesa daña (' .. tostring(r) .. ')')
    pa.x, pa.y = xm + 7 * T, ym
    want(Interactions.check(pa, g) == nil, 'lejos, nada')
    g.phase = 3
    at(level, 8.5); local x3 = g:bobPos()
    want(x3 < px - 3 * T, 'fase 3: dos lados por pulso (a mitad de pulso, en el otro extremo)')
    check('pendulo', ok, table.concat(parts, ' · '))
end

function cases.golpe()
    local level, es, g = arena()
    local pa = playerAt(level, 123)                            -- (en el ladrillo de la derecha: no se cae al cambiar)
    local hp0 = pa.hp
    at(level, 8 * 3 + 3.9)                                     -- (justo antes del pulso 5 de una frase)
    g.lastBeats = BeatClock.beats(level)
    g.phr = 9
    local wind, slamBeats, landed
    step(level, es, { pa }, 6, function()
        if g.state == 'windup' then wind = true end
        if g.state == 'slam' and not slamBeats then slamBeats = BeatClock.beats(level) end
        if g.state == 'dazed' then landed = true; return true end
    end)
    local frac = slamBeats and (slamBeats % 8) or -1
    check('golpe', wind and landed and math.abs(g.x - g.landX) < 1 and math.abs(g.landX - pa.x) < 48
        and (frac < 0.2 or frac > 7.9) and pa.hp == hp0 - 2,
        ('carga=%s, cae en el pulso %.2f de la frase (0 = el cambio), diana-jugador %d px, aturdido=%s, vida %d → %d')
        :format(tostring(wind), frac, math.floor(math.abs((g.landX or 0) - pa.x)), tostring(landed), hp0, pa.hp))
end

function cases.persigue()
    local parts, ok = {}, true
    local function want(c, m) parts[#parts + 1] = m .. (c and '' or ' ✗'); ok = ok and c end
    for _, spot in ipairs({ { 92, nil, 'suelo' }, { 88, 20, 'repisa' } }) do
        local level, es, g = arena()
        g.x, g.y = (104 - 0.5) * T, g:hoverY()
        local pa = PlayerAdventure:new((spot[1] - 0.5) * T, (spot[2] or 25) * T - 60)
        level.players = { pa }
        for _ = 1, 30 do pa:update(DT, level) end
        local px, py = pa.x, pa.y
        g.phr = -99                                                -- (sin golpes: solo persigue)
        for _ = 1, 420 do
            level.players = { pa }
            BeatClock.update(level, DT, nil)
            pa.x, pa.y, pa.vx, pa.vy, pa.invT = px, py, 0, 0, 5
            g:update(DT, level)
        end
        local pvx, pvy = g:pivot()
        local bottom = pvy + g.ROD
        want(math.abs(g.x - px) < T and math.abs(bottom - py) < 40,
             ('%s: encima a %d px, la pesa abajo a %d px de su cuerpo'):format(spot[3], math.floor(math.abs(g.x - px)), math.floor(bottom - py)))
    end
    check('persigue', ok, table.concat(parts, ' · '))
end

function cases.plataforma()
    -- elige DÓNDE caer según dónde esté el jugador (como el panzazo del Rey Gummy): la repisa de cristal, el suelo de
    -- verdad (también debajo de una repisa: la atraviesa) o el otro "suelo", la plataforma alta de Bloques Beep
    local parts, ok = {}, true
    for _, spot in ipairs({ { 88, 20, 'repisa' }, { 122, 25, 'suelo bajo la repisa' }, { 104, 13, 'plataforma alta' } }) do
        local level, es, g = arena()
        local pa = PlayerAdventure:new((spot[1] - 0.5) * T, spot[2] * T - 60)
        level.players = { pa }
        for _ = 1, 30 do pa:update(DT, level) end
        local px, py = pa.x, pa.y
        at(level, 8 * 3 + 3.9); g.lastBeats = BeatClock.beats(level); g.phr = 9
        local landed
        for _ = 1, 360 do
            level.players = { pa }
            BeatClock.update(level, DT, nil)
            pa.x, pa.y, pa.vx, pa.vy, pa.invT = px, py, 0, 0, 5       -- (quieto: la prueba es dónde cae)
            g:update(DT, level)
            if g.state == 'dazed' then landed = true; break end
        end
        local feet = g.y + g.outerH / 2
        local want = spot[2] * T
        local good = landed and math.abs(feet - want) < 2
        ok = ok and good
        parts[#parts + 1] = ('%s: pies %d / cara %d%s'):format(spot[3], math.floor(feet), want, good and '' or ' ✗')
    end
    check('plataforma', ok, table.concat(parts, ' · '))
end

function cases.inmune()
    local level, es, g = arena()
    local parts, ok = {}, true
    local function want(c, m) parts[#parts + 1] = m .. (c and '' or ' ✗'); ok = ok and c end
    local ob = g:getOuterBounds()
    local pa = PlayerAdventure:new(g.x, ob.y - 30)
    pa.vy = 300; pa.prevY = pa.y - 8
    level.players = { pa }
    local r = g:interact(pa)
    want(r == 'bounce', 'flotando: rebota (' .. tostring(r) .. ')')
    g:enter('dazed'); g.y = g:landY()
    ob = g:getOuterBounds()
    pa.x, pa.y = g.x, ob.y - 30
    r = g:interact(pa)
    want(r == 'stomp', 'aturdido: pisotón (' .. tostring(r) .. ')')
    local hp = g.hp
    g:stomp()
    want(g.hp == hp - 1 and g.state == 'rise', ('-1 y se levanta (%d → %d, %s)'):format(hp, g.hp, g.state))
    check('inmune', ok, table.concat(parts, ' · '))
end

function cases.ondas()
    local level, es, g = arena()
    g.phase = 2
    local pa = playerAt(level, 85)
    at(level, 8 * 5 + 3.9); g.lastBeats = BeatClock.beats(level); g.phr = 9
    local n0, n1, hurt
    step(level, es, { pa }, 6, function()
        if g.state == 'dazed' and not n0 then n0 = #(g:getHazardBoxes() or {}) end
        if g.state == 'dazed' and g.deadTimer > 0.5 then
            local a, b = g:waveXs()
            n1 = a and (b - a) or 0
            return true
        end
    end)
    -- una onda a ras de suelo daña
    local a = g:waveXs()
    local q = PlayerAdventure:new(a, g.landSurf - 30)
    level.players = { q }
    hurt = a and Interactions.check(q, g)
    check('ondas', n0 == 2 and n1 and n1 > 300 and hurt == 'hurt',
        ('al caer: %s cajas (2 ondas), separadas %s px a los 0,5 s, a ras de suelo: %s'):format(tostring(n0), tostring(n1), tostring(hurt)))
end

function cases.fases()
    local level, es, g = arena()
    local seen = {}
    for _ = 1, g.hpMax - 1 do
        g:enter('dazed'); g.inv = 0
        g:damage(1, 'stomp')
        seen[#seen + 1] = g.phase
    end
    local s = table.concat(seen, ',')
    check('fases', seen[1] == 1 and seen[#seen] == 3 and s:find('2') ~= nil, ('vida %d: fases %s'):format(g.hpMax, s))
end

-- El TEMPO: el nivel va a 140 (su música, estelar_pulsar); con la zona en pelea, el reloj va al de la pista de la pelea
-- (estelar_boss, 150: `bpm` del índice de música) y vuelve a 0; al acabar, otra vez el del nivel
function cases.tempo()
    local level, es, g = arena()
    local z = level.bossZones[1]
    local p0 = level.beat.period
    level.beat.t = 5
    BeatClock.update(level, DT, nil)
    z.state = 'fight'
    BeatClock.update(level, DT, nil)
    local p1, t1 = level.beat.period, level.beat.t
    z.state = 'cleared'
    BeatClock.update(level, DT, nil)
    local p2 = level.beat.period
    check('tempo', math.abs(p0 - 8 * 60 / 140) < 1e-4 and math.abs(p1 - 3.2) < 1e-6 and t1 < 0.05 and math.abs(p2 - p0) < 1e-6,
        ('nivel %.4f s/frase → pelea %.4f (t %.3f) → después %.4f'):format(p0, p1, t1, p2))
end

function cases.red()
    local level, es, g = arena()
    g.phase, g.landX, g.theta0, g.wavesOn = 2, 7000, 0.81, 1
    g:enter('windup'); g.deadTimer = 0.1
    local pack = g:netPackExtra()
    local level2 = Level.fromData(json.decode(io.open(LEVEL):read('*a')))
    local c
    for _, pl in ipairs(level2.entities) do if pl.type == 'metrogolem' then c = Entities.create(pl) end end
    BossZones.link(level2, { c })
    c.levelRef = level2
    c:netApplyExtra(pack, pack, 1)
    c.x, c.y, c.state, c.deadTimer = g.x, g.y, g.state, g.deadTimer
    level2.beat.t = level.beat.t
    local bx, by = g:bobPos()
    local cx, cy = c:bobPos()
    local same = c.phase == 2 and c.landX == 7000 and math.abs(c.theta0 - 0.81) < 0.002
    local hb, hc = g:getHazardBoxes() or {}, c:getHazardBoxes() or {}
    check('red', same and bx and cx and math.abs(bx - cx) < 1 and math.abs(by - cy) < 1 and #hb == #hc,
        ('fase/diana/ángulo=%s; pesa servidor %d,%d / cliente %d,%d; cajas %d / %d'):format(tostring(same),
            bx or -1, by or -1, cx or -1, cy or -1, #hb, #hc))
end

function love.load(arg)
    local only = os.getenv('CASE')
    for _, n in ipairs({ 'pendulo', 'persigue', 'golpe', 'plataforma', 'inmune', 'ondas', 'fases', 'tempo', 'red' }) do
        if not only or only == n then
            local ok, err = xpcall(cases[n], debug.traceback)
            if not ok then check(n, false, 'error: ' .. tostring(err)) end
        end
    end
    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
