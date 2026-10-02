-- Arnés: MEGA CRABBY LÚGUBRE caso a caso, en su arena (tools/levelgen/arenas/jefe_lugubre.json).
--   acecha        recorre paredes y techo (nunca el suelo), suelta aros de ecolocalización y va
--                 hacia el lado donde suena algo
--   luz_cancela   alumbrarlo mientras ESCUCHA le hace perder el rastro: no ataca (icono "…")
--   cae_donde_sono marca y cae donde sonó el último ruido (no donde está el jugador, que se fue
--                 sin hacer ruido): no le da
--   golpe         al caer apaga la linterna del que está cerca (y no la del que está lejos) y los
--                 Crabbies lúgubres lo oyen
--   deslumbrado   en el suelo y SIN luz es inmune (rebotas); alumbrado queda deslumbrado: pisotón
--                 -1, y solo un golpe; luego trepa
--   fases         fase 2: aros falsos y salto de pared a pared; fase 3: grita, las linternas alcanzan
--                 la mitad un rato y llama a Crabbies lúgubres
--   muerte        al morir vuelve la luz normal y se van los súbditos
--   red           netPackExtra → netApplyExtra: fase, ángulo, marca, aros y luz en el cliente
--   LOOK=1        <save>/megagloomy_look.png: la arena a oscuras en 4 momentos
--
--   tools/tests/run.sh megagloomy_rules   (CASE=nombre)
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
require 'settings'
local played = {}
Sound = setmetatable({ play = function(n) played[n] = (played[n] or 0) + 1 end },
                     { __index = function() return function() end end })
local P = require 'src/network/Protocol'
local stub = P.newInputStub()
Input = stub
local json = require 'libs/json'
local Level = require 'src/world/Level'
local Entities = require 'src/world/Entities'
local BossZones = require 'src/world/BossZones'
local Interactions = require 'src/world/entities/Interactions'
local PlayerAdventure = require 'src/entities/PlayerAdventure'
local Lights = require 'src/world/Lights'
local Noise = require 'src/world/Noise'
local T = TILE_PX
local DT = 1 / 60

local fails = 0
local function check(case, ok, msg)
    print(('%-15s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end

local ARENA = 'tools/levelgen/arenas/jefe_lugubre.json'
local function arena()
    local f = assert(io.open(ARENA, 'r'))
    local data = json.decode(f:read('*a')); f:close()
    local level = Level.fromData(data)
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    level.liveEntities = es
    BossZones.link(level, es)
    local boss
    for _, e in ipairs(es) do if e.def.name == 'megagloomy' then boss = e end end
    level.players = {}
    Noise.bind(level)
    boss:startFight(1)
    boss.levelRef = level
    return level, es, boss
end

local FLOOR = 13
local function playerAt(level, col)
    for k in pairs(stub.state) do stub.state[k] = false end
    local pa = PlayerAdventure:new((col - 0.5) * T, (FLOOR - 1) * T - 60)
    for _ = 1, 30 do pa:update(DT, level) end
    pa.invT = 0
    return pa
end

local function stepAll(level, es, players, secs, each)
    for _ = 1, math.floor(secs * 60) do
        level.players = players
        level.solidBodies = Entities.solidBodies(es)
        for _, pa in ipairs(players) do pa:update(DT, level) end
        for _, e in ipairs(es) do if e.alive or e.summonOf then e:update(DT, level) end end
        for _, pa in ipairs(players) do Interactions.run(pa, es, {}) end
        if each and each() then return true end
    end
end

local cases = {}

function cases.acecha()
    local level, es, boss = arena()
    local zx0, zx1, zy0, zy1 = boss:zoneBounds()
    local onEdge, pings, floor = true, 0, false
    local seen = {}
    boss.stalkT = -99                                      -- (que no ataque)
    local x0
    stepAll(level, es, {}, 1, function() end)
    x0 = boss.x
    Noise.emit(zx1 - 2 * T, zy1 - 40, Noise.R.pound)       -- suena a la derecha
    stepAll(level, es, {}, 6, function()
        boss.stalkT = -99
        local wall = math.abs(boss.x - zx0) < 160 or math.abs(boss.x - zx1) < 160
        local ceil = math.abs(boss.y - zy0) < 160
        if not (wall or ceil) then onEdge = false end
        if boss.y > zy1 - 150 and not wall then floor = true end
        for _, p in ipairs(boss.pings) do seen[p.id] = true end
    end)
    for _ in pairs(seen) do pings = pings + 1 end
    check('acecha', onEdge and not floor and pings >= 2 and boss.x > x0 + 3 * T,
        ('siempre en paredes/techo=%s; aros %d; hacia el ruido: x %.0f → %.0f'):format(tostring(onEdge), pings, x0, boss.x))
end

function cases.luz_cancela()
    local level, es, boss = arena()
    stepAll(level, es, {}, 0.5)
    local pa = playerAt(level, 20)
    -- el jefe, en el techo delante del jugador, escuchando; el jugador lo alumbra
    boss.u = boss:nearestU(pa.x + 3 * T, -1e9); boss.x, boss.y, boss.ang = boss:path(boss.u)
    boss:enter('listen')
    pa.facing, pa.lightOn = 1, true
    pa.y = boss.y + 30                                     -- (a su altura: el cono es horizontal)
    local seen = {}
    level.players = { pa }
    local lit = Lights.lit(level, boss.x, boss.y)
    local icon = 0
    for _ = 1, 90 do
        level.players = { pa }
        boss:update(DT, level)
        seen[boss.state] = true
        icon = math.max(icon, boss.icon or 0)
    end
    check('luz_cancela', lit and seen.flinch and not seen.drop and icon == 3,
        ('alumbrado=%s; pierde el rastro=%s (icono %d); ataca=%s'):format(tostring(lit), tostring(seen.flinch), icon,
         tostring(seen.drop)))
end

function cases.cae_donde_sono()
    local level, es, boss = arena()
    stepAll(level, es, {}, 0.5)
    local pa = playerAt(level, 16)
    local nx = pa.x
    Noise.emit(nx, pa.y, Noise.R.jump)                     -- hizo ruido aquí…
    stepAll(level, es, {}, 0.1)
    pa.x = pa.x + 9 * T                                    -- …y se fue sin hacer ruido
    local hp0 = pa.hp
    boss.stalkT = 99
    local landed
    stepAll(level, es, { pa }, 6, function()
        pa.vx = 0
        if boss.state == 'grounded' and not landed then landed = boss.x; return true end
    end)
    check('cae_donde_sono', landed and math.abs(landed - nx) < 40 and math.abs(boss.markX - nx) < 40 and pa.hp == hp0,
        ('sonó en x %.0f; marca %.0f; cae en %.0f; el jugador (en %.0f) vida %d→%d'):format(nx, boss.markX, landed or -1,
         pa.x, hp0, pa.hp))
end

function cases.golpe()
    local level, es, boss = arena()
    stepAll(level, es, {}, 0.5)
    local near, far = playerAt(level, 22), playerAt(level, 33)
    near.lightOn, far.lightOn = true, true
    near.invT, far.invT = 9, 9
    -- un Crabby lúgubre en la arena (un súbdito, despierto) para ver que lo oye
    local g
    for _, e in ipairs(boss:minions(level)) do g = g or e end
    g.home.x, g.home.y = 14 * T, 12 * T - 30
    g:resetToHome(); g.state = 'walk'
    stepAll(level, es, { near, far }, 0.3, function() near.vx, far.vx = 0, 0; near.lightOn, far.lightOn = true, true end)
    boss.x, boss.y = near.x + 2 * T, 12.5 * T - 145
    boss:slam(level)
    local nOff, nCd, fOn = not near.lightOn, near.lightCd, far.lightOn
    local st
    stepAll(level, es, { near, far }, 0.4, function() near.vx, far.vx = 0, 0; if g.state == 'hunt' then st = true end end)
    check('golpe', nOff and nCd > 2 and fOn and st,
        ('linterna del cercano apagada=%s (%.1f s); la del lejano encendida=%s; el Crabby lúgubre va hacia el golpe=%s'):format(
         tostring(nOff), nCd, tostring(fOn), tostring(st)))
end

function cases.deslumbrado()
    local level, es, boss = arena()
    stepAll(level, es, {}, 0.5)
    local pa = playerAt(level, 18)
    boss.x, boss.y, boss.ang = pa.x + 4.5 * T, 12 * T - 145, 0
    boss:enter('grounded'); boss.hitOnce = false
    -- sin luz: caerle encima rebota
    pa.x, pa.y, pa.vy, pa.onGround = boss.x, boss.y - 140, 300, false
    local r1
    for _ = 1, 40 do
        pa.y = pa.y + 4
        r1 = Interactions.check(pa, boss)
        if r1 then break end
    end
    -- con luz: deslumbrado
    local p2 = playerAt(level, 18)
    p2.facing, p2.lightOn = 1, true
    p2.y = boss.y + 22
    boss:enter('grounded')
    level.players = { p2 }
    for _ = 1, 10 do boss:update(DT, level) end
    local st1 = boss.state
    local hp0 = boss.hp
    pa.x, pa.y, pa.vy, pa.onGround = boss.x, boss.y - 140, 300, false
    local r2
    for _ = 1, 40 do
        pa.y = pa.y + 4
        r2 = Interactions.check(pa, boss)
        if r2 then break end
    end
    boss:stomp()
    local hp1, st2 = boss.hp, boss.state
    boss:stomp()                                           -- (un solo golpe por vez)
    local hp2 = boss.hp
    local seen = {}
    level.players = {}
    for _ = 1, 150 do boss:update(DT, level); seen[boss.state] = true end
    check('deslumbrado', r1 == 'bounce' and st1 == 'dazzled' and r2 == 'stomp' and hp1 == hp0 - 1 and hp2 == hp1
        and st2 == 'recover' and seen.climb and seen.stalk,
        ('sin luz: %s; con luz: %s, caerle encima %s, vida %d→%d (otro golpe: %d), luego %s y trepa=%s'):format(tostring(r1), st1,
         tostring(r2), hp0, hp1, hp2, st2, tostring(seen.climb)))
end

function cases.fases()
    local level, es, boss = arena()
    stepAll(level, es, {}, 0.5)
    local pa = playerAt(level, 24)
    boss.hp = math.floor(boss.hpMax * 0.6)
    local seen, fakes = {}, 0
    stepAll(level, es, { pa }, 22, function()
        pa.invT, pa.vx = 9, 0
        if math.random() < 0.05 then Noise.emit(pa.x, pa.y, Noise.R.jump) end
        seen[boss.state] = true
        for _, p in ipairs(boss.pings) do if p.fake == 1 then fakes = fakes + 1 end end
    end)
    local ph2 = boss.phase
    boss.hp = math.floor(boss.hpMax * 0.3)
    boss.shriekT = 99
    local dim, minions, range = false, 0, Lights.range(level)
    stepAll(level, es, { pa }, 9, function()
        pa.invT, pa.vx = 9, 0
        seen[boss.state] = true
        if level.lightScale then dim = true; range = math.min(range, Lights.range(level)) end
        local n = 0
        for _, e in ipairs(boss:minions(level)) do if e.alive then n = n + 1 end end
        minions = math.max(minions, n)
    end)
    local back
    stepAll(level, es, { pa }, 8, function() pa.invT, pa.vx = 9, 0; boss.shriekT = 0; if not level.lightScale then back = true end end)
    check('fases', ph2 == 2 and seen.lunge and fakes > 0 and boss.phase == 3 and seen.shriek and dim and minions >= 1
        and range < Lights.RANGE * 0.6 and back,
        ('fase 2: salto de pared a pared=%s, aros falsos=%s; fase 3: grito=%s, alcance de la linterna %.1f → %.1f casillas, '
         .. 'súbditos %d; la luz vuelve=%s'):format(tostring(seen.lunge), tostring(fakes > 0), tostring(seen.shriek),
         Lights.RANGE / T, range / T, minions, tostring(back)))
end

function cases.muerte()
    local level, es, boss = arena()
    stepAll(level, es, {}, 0.5)
    boss.hp = 2
    boss.phase = 3
    level.lightScale, boss.dimT = 0.5, 5
    boss:summon(level)
    local n0 = 0
    for _, e in ipairs(boss:minions(level)) do if e.alive then n0 = n0 + 1 end end
    boss:enter('dazzled'); boss.hitOnce = false
    boss:pound()
    stepAll(level, es, {}, 8)
    local n1 = 0
    for _, e in ipairs(boss:minions(level)) do if e.alive and e.state ~= 'dead' then n1 = n1 + 1 end end
    check('muerte', not boss.alive and level.lightScale == nil and n0 > 0 and n1 == 0,
        ('vivo=%s; luz normal=%s; súbditos %d → %d'):format(tostring(boss.alive), tostring(level.lightScale == nil), n0, n1))
end

function cases.red()
    local level, es, boss = arena()
    stepAll(level, es, {}, 3)
    boss.phase, boss.markX, boss.markY, boss.dimT = 2, 1234, 800, 3
    boss:ping(level)
    local pk = boss:netPackExtra()
    local l2, es2, r = arena()
    r:netApplyExtra(pk, pk, 1)
    check('red', r.phase == 2 and r.markX == 1234 and math.abs(r.ang - boss.ang) < 0.02 and #r.pings == #boss.pings
        and l2.lightScale == 0.5,
        ('fase %d, marca %d, ángulo %.2f/%.2f, aros %d/%d, luz ×%s'):format(r.phase, r.markX, r.ang, boss.ang, #r.pings,
         #boss.pings, tostring(l2.lightScale)))
end

local function look()
    local Darkness = require 'src/fx/Darkness'
    WINDOW_W, WINDOW_H = 1280, 720
    local shots = { { 'stalk', 0 }, { 'listen', 0.8 }, { 'grounded', 0.5 }, { 'dazzled', 0.5 } }
    local cv = love.graphics.newCanvas(1280 * 2, 720 * 2)
    for i, sh in ipairs(shots) do
        local level, es, boss = arena()
        stepAll(level, es, {}, 2.3)
        local pa = playerAt(level, 17)
        pa.facing, pa.lightOn = 1, (i >= 3)
        if i >= 3 then boss.x, boss.y, boss.ang = pa.x + 4.5 * T, 12 * T - 145, 0; pa.y = boss.y + 22 end
        if i == 2 then boss.markX, boss.markY = pa.x + 2 * T, 12 * T; boss:ping(level); boss.pings[1].t = 0.4 end
        boss.state, boss.deadTimer = sh[1], sh[2]
        local camX, camY = 9 * T, 1.5 * T
        local sub = love.graphics.newCanvas(1280, 720)
        love.graphics.setCanvas(sub)
        love.graphics.clear(0.1, 0.11, 0.16, 1)
        level:render(camX, camY)
        for _, e in ipairs(es) do if e.alive then e:render(camX, camY) end end
        pa:render(camX, camY)
        Darkness.render(level, camX, camY, { { x = pa.x, y = pa.y, facing = 1, on = pa.lightOn } })
        Darkness.renderGlow(level, es, camX, camY)
        love.graphics.setCanvas(cv)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(sub, ((i - 1) % 2) * 1280, math.floor((i - 1) / 2) * 720)
        love.graphics.setCanvas()
    end
    cv:newImageData():encode('png', 'megagloomy_look.png')
    print('guardado ' .. love.filesystem.getSaveDirectory() .. '/megagloomy_look.png')
end

function love.load()
    local only = os.getenv('CASE')
    for _, n in ipairs({ 'acecha', 'luz_cancela', 'cae_donde_sono', 'golpe', 'deslumbrado', 'fases', 'muerte', 'red' }) do
        if not only or only == n then
            local ok, err = pcall(cases[n])
            if not ok then check(n, false, 'ERROR ' .. tostring(err)) end
        end
    end
    if os.getenv('LOOK') then look() end
    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
