-- Arnés: MEGA CRABBY LÚGUBRE caso a caso, en su arena (tools/levelgen/arenas/jefe_lugubre.json).
--   ronda         anda por el SUELO de su arena buscando, suelta aros con las pinzas en alto y, sin "!", no ataca
--   aro_detecta   el aro detecta (le sale su "!") al jugador que se mueve; al que está quieto, no
--   embestida     con un "!" lejos apunta (línea fija hasta la pared), corre hasta ella y queda agotado; de pie
--                 te da, agachado pasa por encima
--   pinzas        con el "!" cerca, estocada con la pinza de ese lado: delante da; detrás y agachado, no
--   salto         fase 2: alterna el salto con la embestida; cae en su diana y queda agotado
--   luz           alumbrarlo mientras apunta lo asusta y cancela; agotado sin luz es inmune y con luz queda
--                 deslumbrado (se tapa con las pinzas): un golpe
--   caja          la caja es el caparazón que se ve
--   rabia         con poca vida ruge (pinzas en alto, otro cuadro), le salen cristales; luego grita: las
--                 linternas alcanzan la mitad un rato y llama a Crabbies lúgubres
--   muerte        de cangrejo: se encoge y se apaga, sin explosiones; libera la zona
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

local function floorPos(boss) local zx0, zx1, zy0, zy1 = boss:zoneBounds(); return zx0, zx1, zy0, zy1 end

-- Ronda por el SUELO (nunca paredes ni techo), suelta aros con las pinzas en alto, y SIN "!" no ataca
function cases.ronda()
    local level, es, boss = arena()
    local zx0, zx1, zy0, zy1 = floorPos(boss)
    local onFloor, seen, pings, raised, x0, x1 = true, {}, {}, false, 1e9, -1e9
    stepAll(level, es, {}, 14, function()
        seen[boss.state] = true
        if boss.state ~= 'fight' and math.abs((boss.y + 100) - zy1) > 2 then onFloor = false end
        for _, p in ipairs(boss.pings) do pings[p.id] = true end
        if boss.state == 'ping' then
            local _, _, r = boss:clawPose(-1, 0)
            if r then raised = true end
        end
        x0, x1 = math.min(x0, boss.x), math.max(x1, boss.x)
    end)
    local n = 0
    for _ in pairs(pings) do n = n + 1 end
    check('ronda', onFloor and n >= 3 and raised and (x1 - x0) > 5 * T and not seen.aim and not seen.charge and not seen.pounce and not seen.claw,
        ('siempre en el suelo=%s; aros %d (pinzas en alto=%s); recorre %.0f casillas; sin "!": apunta=%s'):format(tostring(onFloor),
         n, tostring(raised), (x1 - x0) / T, tostring(seen.aim)))
end

-- El aro detecta al que se mueve (le sale su "!") y no al que está quieto
function cases.aro_detecta()
    local function try(moving)
        local level, es, boss = arena()
        stepAll(level, es, {}, 0.3)
        local pa = playerAt(level, 20)
        boss.pingT, boss.cdT = 0, 99
        boss.tx = nil
        boss:ping()
        local n0 = level.noises and level.noises.seq or 0
        stepAll(level, es, { pa }, 1.6, function()
            boss.pingT, boss.cdT = 0, 99
            stub.state.right = moving
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

-- EMBESTIDA: con un "!" lejos apunta (línea fija hasta la pared), corre hasta ella y queda agotado;
-- de pie te da, AGACHADO pasa por encima
function cases.embestida()
    local function try(crouch)
        local level, es, boss = arena()
        stepAll(level, es, {}, 0.3)
        local zx0, zx1, zy0, zy1 = floorPos(boss)
        boss:stand(level, zx0 + 3 * T); boss.cdT, boss.pingT = 0, -99
        local pa = playerAt(level, 1)
        pa.x = zx0 + 12 * T
        for _ = 1, 20 do pa:update(DT, level) end
        local hp0 = pa.hp
        Noise.emit(pa.x, pa.y, Noise.R.jump)
        local seen, endX, stable, aimT = {}, nil, true, 0
        stepAll(level, es, { pa }, 6, function()
            boss.pingT = -99
            stub.state.crouch = crouch
            pa.vx = 0
            seen[boss.state] = true
            if boss.state == 'aim' then
                aimT = aimT + DT
                endX = endX or boss.endX
                if boss.endX ~= endX or boss.kind ~= 1 then stable = false end
            end
            return boss.state == 'tired'
        end)
        stub.state.crouch = false
        return hp0 - pa.hp, seen, stable, aimT, math.abs(boss.x - (endX or 0)), boss.state
    end
    local hitStand, seen, stable, aimT, off, st = try(false)
    local hitCrouch = try(true)
    check('embestida', seen.aim and seen.charge and not seen.pounce and stable and aimT >= 0.8 and off < 2 and st == 'tired'
        and hitStand == 1 and hitCrouch == 0,
        ('apunta %.1f s con la línea fija=%s; corre hasta la pared (a %.0f px de la marca) y queda %s; de pie -%d, agachado -%d'):format(
         aimT, tostring(stable), off, st, hitStand, hitCrouch))
end

-- PINZAS: con el "!" cerca, estocada hacia ese lado; delante te da, detrás no, agachado no
function cases.pinzas()
    local function try(dx, crouch)
        local level, es, boss = arena()
        stepAll(level, es, {}, 0.3)
        local zx0, zx1 = floorPos(boss)
        boss:stand(level, (zx0 + zx1) / 2); boss.cdT, boss.pingT = 0, -99
        local bx = boss.x
        local pa = playerAt(level, 1)
        pa.x = bx + dx
        for _ = 1, 20 do pa:update(DT, level) end
        local hp0 = pa.hp
        Noise.emit(bx + 2.5 * T, pa.y, Noise.R.jump)           -- el "!" a la DERECHA, cerca
        local seen, out = {}, 0
        stepAll(level, es, { pa }, 4, function()
            boss.pingT = -99
            stub.state.crouch = crouch or false
            pa.vx = 0
            seen[boss.state] = true
            if boss.state == 'claw' then out = math.max(out, (boss:clawPose(1, 0))) end
            return boss.state == 'prowl' or boss.state == 'taunt'
        end)
        stub.state.crouch = false
        return hp0 - pa.hp, seen, out, boss.kind
    end
    local front, seen, out = try(2.5 * T)
    local behind = try(-2.5 * T)
    local crouched = try(2.5 * T, true)
    check('pinzas', seen.claw and not seen.charge and out > 6 and front == 1 and behind == 0 and crouched == 0,
        ('estocada=%s (la pinza sale %.0f px de arte); delante -%d, detrás -%d, agachado -%d'):format(tostring(seen.claw), out, front,
         behind, crouched))
end

-- SALTO (fase 2): alterna con la embestida; cae en su diana y queda agotado
function cases.salto()
    local level, es, boss = arena()
    stepAll(level, es, {}, 0.3)
    local zx0, zx1 = floorPos(boss)
    boss.phase, boss.attackN = 2, 1                        -- (el siguiente lejano: salto)
    boss:stand(level, zx0 + 3 * T); boss.cdT, boss.pingT = 0, -99
    local nx = zx0 + 13 * T
    Noise.emit(nx, boss.y + 60, Noise.R.jump)
    local seen, top = {}, 1e9
    stepAll(level, es, {}, 5, function()
        boss.pingT = -99
        seen[boss.state] = true
        top = math.min(top, boss.y)
        return boss.state == 'tired'
    end)
    check('salto', seen.pounce and not seen.charge and boss.kind == 0 and math.abs(boss.x - nx) < 2 and boss.state == 'tired'
        and top < boss.y - 150,
        ('salta=%s (sube %.0f px), cae a %.0f px de la diana, queda %s'):format(tostring(seen.pounce), boss.y - top,
         math.abs(boss.x - nx), boss.state))
end

function cases.luz()
    local level, es, boss = arena()
    stepAll(level, es, {}, 0.3)
    local zx0, zx1 = floorPos(boss)
    boss:stand(level, (zx0 + zx1) / 2); boss.cdT, boss.pingT = 0, -99
    local pa = playerAt(level, 1)
    pa.x = boss.x - 4.5 * T
    for _ = 1, 20 do pa:update(DT, level) end
    pa.facing = 1
    -- apuntando + luz → se asusta y cancela
    Noise.emit(boss.x + 8 * T, pa.y, Noise.R.jump)
    local seen, icon = {}, 0
    stepAll(level, es, { pa }, 2.5, function()
        boss.pingT = -99
        pa.vx = 0
        if boss.state == 'aim' then pa.lightOn = true end
        seen[boss.state] = true
        icon = math.max(icon, boss.icon or 0)
    end)
    local cancelled = seen.aim and seen.flinch and not seen.charge and not seen.pounce and icon == 3
    -- agotado SIN luz: inmune (rebote); con luz: deslumbrado, un golpe
    pa.lightOn = false
    boss:stand(level, pa.x + 4.5 * T)
    boss:enter('tired'); boss.hitOnce = false
    local p2 = playerAt(level, 1)
    p2.x, p2.y, p2.vy, p2.onGround = boss.x, boss.y - 140, 300, false
    local r1
    for _ = 1, 40 do p2.y = p2.y + 4; r1 = Interactions.check(p2, boss); if r1 then break end end
    boss:stand(level, pa.x + 4.5 * T)                      -- (a tiro de la linterna)
    pa.lightOn = true
    level.players = { pa }
    boss:enter('tired')
    for _ = 1, 10 do boss:update(DT, level) end
    local st1, hp0 = boss.state, boss.hp
    p2.x, p2.y, p2.vy, p2.onGround = boss.x, boss.y - 140, 300, false
    local r2
    for _ = 1, 40 do p2.y = p2.y + 4; r2 = Interactions.check(p2, boss); if r2 then break end end
    boss:stomp()
    local hp1 = boss.hp
    boss:stomp()
    local covered = false
    boss:enter('dazzled')
    covered = (boss:clawPose(-1, 0)) < -3
    check('luz', cancelled and r1 == 'bounce' and st1 == 'dazzled' and r2 == 'stomp' and hp1 == hp0 - 1 and boss.hp == hp1 and covered,
        ('apuntando + luz: cancela=%s (icono %d); agotado sin luz: %s; con luz: %s, %s, vida %d→%d (otro golpe: %d); se tapa con las pinzas=%s'):format(
         tostring(cancelled), icon, tostring(r1), st1, tostring(r2), hp0, hp1, boss.hp, tostring(covered)))
end

-- La caja es el caparazón que se ve
function cases.caja()
    local level, es, boss = arena()
    stepAll(level, es, {}, 0.5)
    local zx0, zx1, zy0, zy1 = floorPos(boss)
    boss:stand(level, (zx0 + zx1) / 2)
    local b = boss:getOuterBounds()
    local top, bottom = zy1 - b.y, zy1 - (b.y + b.h)
    check('caja', b.w == 110 and b.h == 60 and math.abs(top - 130) <= 12 and math.abs(bottom - 70) <= 12,
        ('caja %dx%d; de %.0f a %.0f px sobre el suelo (el caparazón dibujado: de 70 a 120)'):format(b.w, b.h, bottom, top))
end

-- RABIA: ruge (pinzas en alto), le salen cristales, luego grita: oscurece y llama súbditos
function cases.rabia()
    local level, es, boss = arena()
    stepAll(level, es, {}, 0.5)
    local pa = playerAt(level, 24)
    boss.hp = math.floor(boss.hpMax * 0.35)
    local seen, roarClaws, dim, minions, range = {}, false, false, 0, Lights.range(level)
    played = {}
    stepAll(level, es, { pa }, 4, function()
        pa.invT, pa.vx = 9, 0
        seen[boss.state] = true
        if boss.state == 'roar' then
            local _, _, r = boss:clawPose(1, 0)
            if r and boss:frameNow() == 8 then roarClaws = true end
        end
    end)
    local rage = boss.rage
    boss.shriekT = 99
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
    check('rabia', seen.roar and roarClaws and rage and (played.mgloomyRoar or 0) >= 1 and seen.shriek and dim and minions >= 1
        and range < Lights.RANGE * 0.6 and back,
        ('ruge=%s con las pinzas en alto y otro cuadro=%s; rabia=%s; grito=%s: linterna %.1f → %.1f casillas, súbditos %d; la luz vuelve=%s'):format(
         tostring(seen.roar), tostring(roarClaws), tostring(rage), tostring(seen.shriek), Lights.RANGE / T, range / T, minions, tostring(back)))
end

-- Muerte de cangrejo: sin explosiones; se encoge y se apaga; libera la zona
function cases.muerte()
    local level, es, boss = arena()
    stepAll(level, es, {}, 0.5)
    boss.hp, boss.rage, boss.phase = 2, true, 3
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
    boss.phase, boss.markX, boss.markY, boss.endX, boss.kind, boss.dimT, boss.rage, boss.face = 2, 1234, 800, 555, 3, 3, true, -1
    boss:ping()
    local pk = boss:netPackExtra()
    local l2, es2, r = arena()
    r:netApplyExtra(pk, pk, 1)
    check('red', r.phase == 2 and r.markX == 1234 and r.endX == 555 and r.kind == 3 and r.rage == true and r.face == -1
        and #r.pings == #boss.pings and l2.lightScale == 0.5,
        ('fase %d, marca %d, fin %d, ataque %d, rabia %s, mira %d, aros %d/%d, luz ×%s'):format(r.phase, r.markX, r.endX,
         r.kind, tostring(r.rage), r.face, #r.pings, #boss.pings, tostring(l2.lightScale)))
end

local function look()
    local Darkness = require 'src/fx/Darkness'
    WINDOW_W, WINDOW_H = 1280, 720
    -- arriba (A LA LUZ, para ver las poses): rondar · ecolocalización · rugido con cristales
    -- abajo (a oscuras, como en el juego): embestida apuntando · estocada · deslumbrado
    local shots = { { 'prowl', 0.3, false }, { 'ping', 0.3, false }, { 'roar', 0.5, false, true },
                    { 'aim', 0.5, true, false, 1 }, { 'claw', 0.1, true, false, 2 }, { 'dazzled', 0.5, true } }
    local cv = love.graphics.newCanvas(1280 * 3, 720 * 2)
    for i, sh in ipairs(shots) do
        local level, es, boss = arena()
        stepAll(level, es, {}, 0.5)
        local zx0, zx1 = floorPos(boss)
        boss:stand(level, zx0 + 13 * T)
        local pa = playerAt(level, 1)
        pa.x = boss.x - 4.5 * T
        for _ = 1, 20 do pa:update(DT, level) end
        pa.facing = 1
        pa.lightOn = sh[1] == 'dazzled'
        boss.state, boss.deadTimer, boss.rage, boss.kind, boss.face = sh[1], sh[2], sh[4] == true, sh[5] or 0, 1
        boss.endX = zx1 - 125
        if sh[1] == 'ping' then boss:ping(); boss.pings[1].t = 0.3 end
        level.dark = sh[3]
        local camX, camY = 9 * T, 1.5 * T
        local sub = love.graphics.newCanvas(1280, 720)
        love.graphics.setCanvas(sub)
        love.graphics.clear(0.16, 0.18, 0.26, 1)
        level:render(camX, camY)
        for _, e in ipairs(es) do if e.alive then e:render(camX, camY) end end
        pa:render(camX, camY)
        Darkness.render(level, camX, camY, { { x = pa.x, y = pa.y, facing = 1, on = pa.lightOn } })
        level.dark = true
        Darkness.renderGlow(level, es, camX, camY)
        local b = boss:getOuterBounds()
        love.graphics.setColor(0.3, 1, 0.4, 0.8)
        love.graphics.rectangle('line', b.x - camX, b.y - camY, b.w, b.h)
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
    for _, n in ipairs({ 'ronda', 'aro_detecta', 'embestida', 'pinzas', 'salto', 'luz', 'caja', 'rabia', 'muerte', 'red' }) do
        if not only or only == n then
            local ok, err = pcall(cases[n])
            if not ok then check(n, false, 'ERROR ' .. tostring(err)) end
        end
    end
    if os.getenv('LOOK') then look() end
    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
