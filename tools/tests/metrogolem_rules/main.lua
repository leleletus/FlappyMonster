-- tools/tests/metrogolem_rules — reglas del GÓLEM METRÓNOMO (types/bosses/metrogolem.lua) caso a caso, en su nivel
-- real (assets/levels/santuario_del_compas.json), con el reloj de compás del nivel (150 BPM):
--   pendulo   en cada pulso la pesa está en un extremo y a mitad de pulso abajo, a la altura de quien está de pie;
--             tocarla daña (hurt); lejos, nada; en la fase 3 va dos lados por pulso
--   golpe     con las frases cumplidas, en el pulso 5 carga (la diana sigue al jugador), en el pulso 1 de la frase
--             siguiente cae EN la diana (≤ 24 px) justo en el cambio de los Bloques Beep; aplasta (-2) al de debajo y
--             queda ATURDIDO
--   inmune    flotando, caerle encima solo rebota; aturdido, el pisotón le quita 1 y se levanta (un golpe por ocasión)
--   ondas     desde la fase 2, al caer salen dos ondas por el suelo que se separan y dañan a ras de suelo
--   fases     la vida a 2/3 → fase 2, a 1/3 → fase 3
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
    local feet = g:floorY()
    want(ym + 30 > feet - 64 and ym - 30 < feet, ('abajo, a la altura de la cabeza (pesa %d, suelo %d)'):format(ym, feet))
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
    local q = PlayerAdventure:new(a, g:floorY() - 30)
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
    for _, n in ipairs({ 'pendulo', 'golpe', 'inmune', 'ondas', 'fases', 'red' }) do
        if not only or only == n then
            local ok, err = xpcall(cases[n], debug.traceback)
            if not ok then check(n, false, 'error: ' .. tostring(err)) end
        end
    end
    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
