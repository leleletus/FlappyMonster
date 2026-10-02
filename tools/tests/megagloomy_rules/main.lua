-- Arnés: MEGA CRABBY LÚGUBRE caso a caso, en su arena (tools/levelgen/arenas/jefe_lugubre.json).
--   acecha        recorre paredes y techo, suelta aros de ecolocalización y va hacia donde suena algo
--   aro_detecta   el aro detecta (le sale su "!") al jugador que se mueve; al que está quieto, no
--   marca_y_ataque cada ataque con SU marca (diana / tres líneas / línea horizontal), fija desde que
--                 empieza a apuntar aunque suene otra cosa después, y hace justo ese ataque en ese sitio
--   patas         las tres patas dan en sus líneas y no entre ellas; si da a alguien, luego se burla
--   luz_cancela   alumbrarlo mientras apunta lo asusta: cancela (icono "…") y repetirá ese ataque
--   caja          la caja es el caparazón que se ve (antes quedaba más arriba, sobre las pinzas)
--   deslumbrado   en el suelo y SIN luz es inmune (rebotas); alumbrado desde el suelo queda deslumbrado:
--                 pisotón -1, y solo un golpe; luego trepa
--   fases         fase 1: caída y patas (sin embestida); fase 2: embestida; fase 3: grito que acorta las
--                 linternas y llama a Crabbies lúgubres
--   muerte        de cangrejo: cae, se encoge y se apaga, sin explosiones; libera la zona, vuelve la luz y
--                 se van los súbditos
--   red           netPackExtra → netApplyExtra
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

-- Pone al jefe a apuntar el ataque `kind` ('drop' | 'stab' | 'lunge') y devuelve lo que vio
local function forceAim(boss, level, phase, n)
    boss.phase = phase
    boss.attackN = n - 1
    boss:startAim(level)
end

function cases.acecha()
    local level, es, boss = arena()
    local zx0, zx1, zy0, zy1 = boss:zoneBounds()
    local onEdge, floor = true, false
    local seen = {}
    stepAll(level, es, {}, 1, function() boss.stalkT = -99 end)
    local x0 = boss.x
    Noise.emit(zx1 - 2 * T, zy1 - 40, Noise.R.pound)       -- suena a la derecha
    stepAll(level, es, {}, 6, function()
        boss.stalkT = -99                                  -- (que no ataque)
        local wall = math.abs(boss.x - zx0) < 110 or math.abs(boss.x - zx1) < 110
        local ceil = math.abs(boss.y - zy0) < 110
        if not (wall or ceil) then onEdge = false end
        for _, p in ipairs(boss.pings) do seen[p.id] = true end
    end)
    local pings = 0
    for _ in pairs(seen) do pings = pings + 1 end
    check('acecha', onEdge and pings >= 2 and boss.x > x0 + 3 * T,
        ('siempre en paredes/techo=%s; aros %d; hacia el ruido: x %.0f → %.0f'):format(tostring(onEdge), pings, x0, boss.x))
end

-- El aro detecta al que se mueve (le sale su "!") y no al que está quieto
function cases.aro_detecta()
    local function try(moving)
        local level, es, boss = arena()
        stepAll(level, es, {}, 0.3)
        local pa = playerAt(level, 20)
        boss.stalkT, boss.pingT = -99, 0
        boss.tx = nil
        boss:ping()
        local n0 = level.noises and level.noises.seq or 0
        stepAll(level, es, { pa }, 1.6, function()
            boss.stalkT, boss.pingT = -99, 0
            stub.state.right = moving and (math.floor(love.timer.getTime() * 0) == 0) or false
            if moving and pa.x > 22 * T then pa.x = 20 * T end
        end)
        stub.state.right = false
        return (level.noises and level.noises.seq or 0) - n0, boss.tx
    end
    local nMove, txMove = try(true)
    local nStill, txStill = try(false)
    check('aro_detecta', nMove == 1 and txMove ~= nil and nStill == 0 and txStill == nil,
        ('moviéndose: %d marca (el jefe ya sabe dónde=%s); quieto: %d (sabe dónde=%s)'):format(nMove, tostring(txMove ~= nil),
         nStill, tostring(txStill ~= nil)))
end

-- Cada ataque con SU marca, fija desde que empieza a apuntar, y da donde marcó (el último "!")
function cases.marca_y_ataque()
    local msg, ok = {}, true
    for i, kind in ipairs({ 'drop', 'stab', 'lunge' }) do
        local level, es, boss = arena()
        stepAll(level, es, {}, 0.4)
        local zx0, zx1, zy0, zy1 = boss:zoneBounds()
        local nx, ny = zx0 + 8 * T, zy1 - 40
        Noise.emit(nx, ny, Noise.R.jump)
        stepAll(level, es, {}, 0.1, function() boss.stalkT = -99 end)
        forceAim(boss, level, 2, ({ drop = 1, lunge = 2, stab = 3 })[kind])     -- (SEQ de la fase 2: caída, embestida, patas)
        local k0, mx0, my0, ly0 = boss.kind, boss.markX, boss.markY, boss.lockY
        Noise.emit(zx1 - 3 * T, ny, Noise.R.jump)           -- otro ruido DESPUÉS de apuntar: ya no cambia
        local stable, aimT, seen, landX, minY, maxY = true, 0, {}, nil, 1e9, -1e9
        stepAll(level, es, {}, 6, function()
            seen[boss.state] = true
            if boss.state == 'aim' then
                aimT = aimT + DT
                if boss.kind ~= k0 or boss.markX ~= mx0 or boss.lockY ~= ly0 then stable = false end
            end
            if boss.state == 'grounded' and not landX then landX = boss.x end
            if boss.state == 'lunge' then minY, maxY = math.min(minY, boss.y), math.max(maxY, boss.y) end
            return boss.state == 'stalk' or boss.state == 'grounded'
        end)
        local good = stable and aimT >= 0.75 and math.abs(mx0 - nx) < 2
        if kind == 'drop' then good = good and k0 == 1 and seen.drop and not seen.lunge and not seen.stab and landX and math.abs(landX - nx) < 4
        elseif kind == 'stab' then good = good and k0 == 2 and seen.stab and not seen.drop and not seen.lunge
        else good = good and k0 == 3 and seen.lunge and not seen.drop and not seen.stab and math.abs(minY - ly0) <= 16 and math.abs(maxY - ly0) <= 16 end
        ok = ok and good
        msg[#msg + 1] = ('%s: marca %d fija=%s (%.1f s apuntando), ataca %s'):format(kind, k0, tostring(stable), aimT,
            seen.drop and 'caída' or seen.stab and 'patas' or seen.lunge and 'embestida' or '?')
    end
    check('marca_y_ataque', ok, table.concat(msg, ' · '))
end

-- Patas: da en las tres columnas marcadas; entre ellas, no
function cases.patas()
    local function try(dx)
        local level, es, boss = arena()
        stepAll(level, es, {}, 0.4)
        local zx0, zx1, zy0, zy1 = boss:zoneBounds()
        local nx = zx0 + 10 * T
        Noise.emit(nx, zy1 - 40, Noise.R.jump)
        stepAll(level, es, {}, 0.1, function() boss.stalkT = -99 end)
        local pa = playerAt(level, 1)
        pa.x = nx + dx
        for _ = 1, 20 do pa:update(DT, level) end
        local hp0 = pa.hp
        forceAim(boss, level, 1, 2)
        stepAll(level, es, { pa }, 5, function() return boss.state == 'stalk' or boss.state == 'taunt' end)
        return hp0 - pa.hp, boss.state
    end
    local onMid, st1 = try(0)
    local onSide = try(1.6 * T)
    local between = try(0.8 * T)
    check('patas', onMid == 1 and onSide == 1 and between == 0 and st1 == 'taunt',
        ('en la línea del medio -%d (y se burla: %s), en la de un lado -%d, entre dos líneas -%d'):format(onMid, st1, onSide, between))
end

function cases.luz_cancela()
    local level, es, boss = arena()
    stepAll(level, es, {}, 0.5)
    local pa = playerAt(level, 20)
    boss.u = boss:nearestU(pa.x + 3 * T, -1e9); boss.x, boss.y, boss.ang = boss:path(boss.u)
    forceAim(boss, level, 1, 1)
    pa.facing, pa.lightOn = 1, true
    pa.y = boss.y + 30                                     -- (a su altura: el cono es horizontal)
    local seen = {}
    level.players = { pa }
    local lit = Lights.lit(level, boss.x, boss.y)
    local icon, n0 = 0, boss.attackN
    for _ = 1, 90 do
        level.players = { pa }
        boss:update(DT, level)
        seen[boss.state] = true
        icon = math.max(icon, boss.icon or 0)
    end
    check('luz_cancela', lit and seen.flinch and not seen.drop and icon == 3 and boss.attackN == n0 - 1,
        ('alumbrado=%s; se asusta=%s (icono %d); ataca=%s; repetirá ese ataque=%s'):format(tostring(lit), tostring(seen.flinch),
         icon, tostring(seen.drop), tostring(boss.attackN == n0 - 1)))
end

-- La caja es el caparazón que se ve (no más arriba): en el suelo, su borde de abajo queda REST − BH/2 sobre el suelo
function cases.caja()
    local level, es, boss = arena()
    stepAll(level, es, {}, 0.5)
    local zx0, zx1, zy0, zy1 = boss:zoneBounds()
    boss.x, boss.y, boss.ang = (zx0 + zx1) / 2, zy1 - 100, 0
    boss:enter('grounded')
    local b = boss:getOuterBounds()
    -- filas del caparazón en el cuadro: de la 9 a la 13 (de 21) → de 120 a 70 px sobre el suelo
    local top, bottom = zy1 - b.y, zy1 - (b.y + b.h)
    check('caja', b.w == 110 and b.h == 60 and math.abs(top - 130) <= 12 and math.abs(bottom - 70) <= 12,
        ('caja %dx%d; de %.0f a %.0f px sobre el suelo (el caparazón dibujado: de 70 a 120)'):format(b.w, b.h, bottom, top))
end

function cases.deslumbrado()
    local level, es, boss = arena()
    stepAll(level, es, {}, 0.5)
    local pa = playerAt(level, 18)
    boss.x, boss.y, boss.ang = pa.x + 4.5 * T, 12 * T - 100, 0
    boss:enter('grounded'); boss.hitOnce = false
    pa.x, pa.y, pa.vy, pa.onGround = boss.x, boss.y - 140, 300, false
    local r1
    for _ = 1, 40 do
        pa.y = pa.y + 4
        r1 = Interactions.check(pa, boss)
        if r1 then break end
    end
    local p2 = playerAt(level, 18)                         -- de pie en el suelo, a 4,5 casillas, con la linterna
    p2.facing, p2.lightOn = 1, true
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
    boss:stomp()
    local hp2 = boss.hp
    local seen = {}
    level.players = {}
    for _ = 1, 150 do boss:update(DT, level); seen[boss.state] = true end
    check('deslumbrado', r1 == 'bounce' and st1 == 'dazzled' and r2 == 'stomp' and hp1 == hp0 - 1 and hp2 == hp1
        and st2 == 'recover' and seen.climb and seen.stalk,
        ('sin luz: %s; alumbrado desde el suelo: %s, caerle encima %s, vida %d→%d (otro golpe: %d), luego %s y trepa=%s'):format(
         tostring(r1), st1, tostring(r2), hp0, hp1, hp2, st2, tostring(seen.climb)))
end

function cases.fases()
    local level, es, boss = arena()
    stepAll(level, es, {}, 0.5)
    local pa = playerAt(level, 24)
    local seen1 = {}
    stepAll(level, es, { pa }, 16, function() pa.invT, pa.vx = 9, 0; seen1[boss.state] = true end)
    boss.hp = math.floor(boss.hpMax * 0.6)
    local seen = {}
    stepAll(level, es, { pa }, 22, function() pa.invT, pa.vx = 9, 0; seen[boss.state] = true end)
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
    check('fases', seen1.drop and seen1.stab and not seen1.lunge and ph2 == 2 and seen.lunge and boss.phase == 3 and seen.shriek
        and dim and minions >= 1 and range < Lights.RANGE * 0.6 and back,
        ('fase 1: caída=%s patas=%s embestida=%s; fase 2: embestida=%s; fase 3: grito=%s, linterna %.1f → %.1f casillas, '
         .. 'súbditos %d; la luz vuelve=%s'):format(tostring(seen1.drop), tostring(seen1.stab), tostring(seen1.lunge),
         tostring(seen.lunge), tostring(seen.shriek), Lights.RANGE / T, range / T, minions, tostring(back)))
end

-- Muerte de cangrejo: sin explosiones; cae, se encoge y se apaga; libera la zona
function cases.muerte()
    local level, es, boss = arena()
    stepAll(level, es, {}, 0.5)
    boss.hp, boss.phase = 2, 3
    level.lightScale, boss.dimT = 0.5, 5
    boss:summon(level)
    local n0 = 0
    for _, e in ipairs(boss:minions(level)) do if e.alive then n0 = n0 + 1 end end
    boss:enter('dazzled'); boss.hitOnce = false
    played = {}
    boss:pound()
    local seen, released = {}, false
    stepAll(level, es, {}, 5, function()
        seen[boss.state] = true
        if boss:releasesZone() then released = true end
    end)
    local n1 = 0
    for _, e in ipairs(boss:minions(level)) do if e.alive and e.state ~= 'dead' then n1 = n1 + 1 end end
    check('muerte', not boss.alive and seen.dying_curl and seen.dying_out and not seen.dying_hold and released
        and (played.bossExplode or 0) == 0 and level.lightScale == nil and n0 > 0 and n1 == 0,
        ('vivo=%s; se encoge=%s y se apaga=%s (explosiones %d); libera la zona=%s; luz normal=%s; súbditos %d → %d'):format(
         tostring(boss.alive), tostring(seen.dying_curl), tostring(seen.dying_out), played.bossExplode or 0, tostring(released),
         tostring(level.lightScale == nil), n0, n1))
end

function cases.red()
    local level, es, boss = arena()
    stepAll(level, es, {}, 3)
    boss.phase, boss.markX, boss.markY, boss.lockY, boss.kind, boss.dimT = 2, 1234, 800, 555, 3, 3
    boss:ping()
    local pk = boss:netPackExtra()
    local l2, es2, r = arena()
    r:netApplyExtra(pk, pk, 1)
    check('red', r.phase == 2 and r.markX == 1234 and r.lockY == 555 and r.kind == 3 and math.abs(r.ang - boss.ang) < 0.02
        and #r.pings == #boss.pings and l2.lightScale == 0.5,
        ('fase %d, marca %d, altura %d, ataque %d, ángulo %.2f/%.2f, aros %d/%d, luz ×%s'):format(r.phase, r.markX, r.lockY,
         r.kind, r.ang, boss.ang, #r.pings, #boss.pings, tostring(l2.lightScale)))
end

local function look()
    local Darkness = require 'src/fx/Darkness'
    WINDOW_W, WINDOW_H = 1280, 720
    -- caída (apuntando) · patas (apuntando) · patas (clavando) · embestida (apuntando) · deslumbrado · muerte
    local shots = { { 1, 1, 'aim' }, { 1, 2, 'aim' }, { 1, 2, 'stab' }, { 2, 2, 'aim' }, { 1, 1, 'dazzled' }, { 1, 1, 'dying_out' } }
    local cv = love.graphics.newCanvas(1280 * 3, 720 * 2)
    for i, sh in ipairs(shots) do
        local level, es, boss = arena()
        stepAll(level, es, {}, 0.5)
        local pa = playerAt(level, 17)
        pa.facing = 1
        Noise.emit(pa.x + 4 * T, pa.y, Noise.R.jump)
        stepAll(level, es, {}, 0.1, function() boss.stalkT = -99 end)
        forceAim(boss, level, sh[1], sh[2])
        if sh[3] == 'aim' then
            stepAll(level, es, {}, 0.7)
        elseif sh[3] == 'stab' then
            stepAll(level, es, {}, 6, function() return boss.state == 'stab' and boss.deadTimer > 0.36 end)
        else
            boss.x, boss.y, boss.ang, boss.kind = pa.x + 4.5 * T, 12 * T - 100, 0, 0
            boss.state, boss.deadTimer = sh[3], 0.5
            pa.lightOn = sh[3] == 'dazzled'
        end
        local camX, camY = 9 * T, 1.5 * T
        local sub = love.graphics.newCanvas(1280, 720)
        love.graphics.setCanvas(sub)
        love.graphics.clear(0.1, 0.11, 0.16, 1)
        level:render(camX, camY)
        for _, e in ipairs(es) do if e.alive then e:render(camX, camY) end end
        pa:render(camX, camY)
        Darkness.render(level, camX, camY, { { x = pa.x, y = pa.y, facing = 1, on = pa.lightOn } })
        Darkness.renderGlow(level, es, camX, camY)
        if DEBUG_BOX ~= false then
            local b = boss:getOuterBounds()
            love.graphics.setColor(0.3, 1, 0.4, 0.8)
            love.graphics.rectangle('line', b.x - camX, b.y - camY, b.w, b.h)
        end
        love.graphics.setCanvas(cv)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(sub, ((i - 1) % 3) * 1280, math.floor((i - 1) / 3) * 720)
        love.graphics.setCanvas()
    end
    cv:newImageData():encode('png', 'megagloomy_look.png')
    print('guardado ' .. love.filesystem.getSaveDirectory() .. '/megagloomy_look.png')
end

function love.load()
    local only = os.getenv('CASE')
    for _, n in ipairs({ 'acecha', 'aro_detecta', 'marca_y_ataque', 'patas', 'luz_cancela', 'caja', 'deslumbrado', 'fases', 'muerte', 'red' }) do
        if not only or only == n then
            local ok, err = pcall(cases[n])
            if not ok then check(n, false, 'ERROR ' .. tostring(err)) end
        end
    end
    if os.getenv('LOOK') then look() end
    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
