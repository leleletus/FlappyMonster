-- Arnés: MEGA CRABBY LÚGUBRE caso a caso, en su arena (tools/levelgen/arenas/jefe_lugubre.json).
--   ronda         anda por el SUELO de su arena buscando, suelta aros con las pinzas en alto y, sin "!", no ataca
--   aro_detecta   el aro detecta (le sale su "!") al jugador que se mueve; al que está quieto, no
--   embestida     con un "!" lejos apunta (línea fija hasta la pared), corre hasta ella y queda agotado; de pie
--                 te da, agachado pasa por encima
--   pinzas        con el "!" cerca, estocada con la pinza de ese lado: delante da; detrás y agachado, no
--   techo         trepa la pared, va por el techo, aro grande, se lanza a donde detecta y queda agotado
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
local Level = require 'src/world/level/Level'
local Entities = require 'src/world/entities/Entities'
local BossZones = require 'src/world/systems/BossZones'
local Interactions = require 'src/world/entities/base/Interactions'
local PlayerAdventure = require 'src/player/PlayerAdventure'
local Lights = require 'src/world/level/Lights'
local Noise = require 'src/world/systems/Noise'
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
        boss.ceilT = -99                                    -- (el techo: caso aparte)
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

-- El aro detecta a quien TOCA, aunque esté quieto y callado: le sale su "!" y el jefe SALTA ahí
-- (nunca embiste: eso es para los ruidos) y queda agotado
function cases.aro_detecta()
    local level, es, boss = arena()
    stepAll(level, es, {}, 0.3)
    local zx0, zx1 = floorPos(boss)
    boss:stand(level, zx0 + 3 * T)
    local pa = playerAt(level, 1)
    pa.x = zx0 + 10 * T
    for _ = 1, 20 do pa:update(DT, level) end
    local px = pa.x
    boss.pingT, boss.cdT, boss.tx = 99, 0, nil
    local n0 = level.noises and level.noises.seq or 0
    local seen, marks, top = {}, 0, 1e9
    stepAll(level, es, { pa }, 6, function()
        boss.ceilT = -99
        if boss.state ~= 'prowl' and boss.state ~= 'ping' then boss.pingT = -99 end
        pa.invT = 9
        seen[boss.state] = true
        if boss.state == 'aim' then marks = (level.noises and level.noises.seq or 0) - n0 end
        top = math.min(top, boss.y)
        return boss.state == 'tired'
    end)
    check('aro_detecta', marks == 1 and seen.ping and seen.pounce and not seen.charge and boss.state == 'tired'
        and math.abs(boss.x - px) < 3 and top < boss.y - 150,
        ('jugador quieto y callado: %d marca; salta=%s (sube %.0f px), embiste=%s; cae a %.0f px de donde lo detectó, queda %s'):format(
         marks, tostring(seen.pounce), boss.y - top, tostring(seen.charge), math.abs(boss.x - px), boss.state))
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
        Noise.emit(pa.x, pa.y, Noise.R.faint)
        local seen, endX, stable, aimT = {}, nil, true, 0
        stepAll(level, es, { pa }, 6, function()
            boss.pingT, boss.ceilT = -99, -99
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

-- PINZAS: con el "!" cerca, la pinza MÁS CERCANA apunta al jugador desde su unión y lo sigue
-- (también hacia arriba); da donde apunta; si el jugador se aparta tras fijarse, falla
function cases.pinzas()
    local function try(dx, mode)
        local level, es, boss = arena()
        stepAll(level, es, {}, 0.3)
        local zx0, zx1 = floorPos(boss)
        boss:stand(level, (zx0 + zx1) / 2); boss.cdT, boss.pingT = 0, -99
        local bx = boss.x
        local pa = playerAt(level, 1)
        pa.x = bx + dx
        for _ = 1, 20 do pa:update(DT, level) end
        local hp0, y0 = pa.hp, pa.y
        Noise.emit(pa.x, pa.y, Noise.R.hit)
        local seen, out, uyMin, face, follow = {}, 0, 1, 0, true
        stepAll(level, es, { pa }, 4, function()
            boss.pingT, boss.ceilT = -99, -99
            pa.vx = 0
            if mode == 'up' then pa.y, pa.vy = y0 - 150, 0 end               -- (en el aire, encima)
            if mode == 'away' and boss.state == 'claw' then pa.x = bx + dx * 4 end   -- (se aparta cuando ya ha fijado)
            seen[boss.state] = true
            if boss.state == 'aim' and boss.deadTimer > 0.1 and boss.deadTimer < 0.6 then
                local _, _, _, uy = boss:clawAim()
                uyMin = math.min(uyMin, uy)
                if math.abs(boss.markX - pa.x) > 2 or math.abs(boss.markY - pa.y) > 2 then follow = false end
            end
            if boss.state == 'claw' then face = boss.face; out = math.max(out, (boss:clawPose(boss.face, 0))) end
            return boss.state == 'prowl' or boss.state == 'taunt'
        end)
        return hp0 - pa.hp, seen, out, face, uyMin, follow
    end
    local right, seen, out, f1, _, follow = try(2.5 * T)
    local left, _, _, f2 = try(-2.5 * T)
    local up, _, _, _, uy = try(2.5 * T, 'up')
    local away = try(2.5 * T, 'away')
    check('pinzas', seen.claw and not seen.charge and out > 6 and right == 1 and f1 == 1 and left == 1 and f2 == -1 and follow
        and up == 1 and uy < -0.3 and away == 0,
        ('estocada=%s (sale %.0f px de arte); a la derecha -%d con la pinza %d, a la izquierda -%d con la %d; la marca sigue al jugador=%s; '
         .. 'arriba: apunta hacia arriba (uy %.2f) -%d; se aparta tras fijar: -%d'):format(tostring(seen.claw), out, right, f1, left, f2,
         tostring(follow), uy, up, away))
end

-- TECHO: corre a la pared, la trepa, va por el techo (girado), suelta su aro grande, marca donde
-- detecta al jugador y se LANZA ahí; queda agotado en el suelo, de pie
function cases.techo()
    local level, es, boss = arena()
    stepAll(level, es, {}, 0.3)
    local zx0, zx1, zy0, zy1 = floorPos(boss)
    boss:stand(level, zx0 + 5 * T); boss.cdT, boss.pingT = 0, -99
    local pa = playerAt(level, 1)
    pa.x = zx0 + 15 * T
    for _ = 1, 20 do pa:update(DT, level) end
    local px, hp0 = pa.x, pa.hp
    boss.ceilT = 99
    local seen, wall, ceil, mark, solid = {}, false, false, nil, false
    stepAll(level, es, { pa }, 12, function()
        boss.pingT = -99
        if boss.state ~= 'prowl' then boss.ceilT = -99 end
        seen[boss.state] = true
        if boss.state == 'climb' and math.abs(math.abs(boss.ang) - math.pi / 2) < 0.01 and boss.x < zx0 + 101 then wall = true end
        if boss.state == 'ceil_ping' and math.abs(math.abs(boss.ang) - math.pi) < 0.01 and math.abs(boss.y - (zy0 + 100)) < 2 then ceil = true end
        if boss.state == 'aim' and boss.kind == 4 then mark = boss.markX; if boss:isSolidBody() then solid = true end end
        if boss.state == 'dive' then pa.x = px + 6 * T end                  -- (el jugador se quita de la diana)
        return boss.state == 'tired'
    end)
    check('techo', seen.climb and wall and ceil and seen.ceil_wait and mark and math.abs(mark - px) < 3 and seen.dive and boss.state == 'tired'
        and math.abs(boss.x - px) < 3 and boss.ang == 0 and math.abs((boss.y + 100) - zy1) < 2 and not solid and pa.hp == hp0,
        ('trepa la pared=%s, por el techo=%s; diana a %.0f px del jugador; se lanza=%s y queda %s a %.0f px, de pie=%s; apartándose: -%d'):format(
         tostring(wall), tostring(ceil), math.abs((mark or 0) - px), tostring(seen.dive), boss.state, math.abs(boss.x - px),
         tostring(boss.ang == 0), hp0 - pa.hp))
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
    Noise.emit(boss.x + 8 * T, pa.y, Noise.R.hit)
    local seen, icon = {}, 0
    stepAll(level, es, { pa }, 2.5, function()
        boss.pingT, boss.ceilT = -99, -99
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
    local vuln = boss:isVulnerable() == false                  -- (ya recibió su golpe)
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
        boss.ceilT, boss.pingT = -99, -99
        seen[boss.state] = true
        if boss.state == 'roar' then
            local _, _, r = boss:clawPose(1, 0)
            if r and boss:frameNow() == 8 then roarClaws = true end
        end
    end)
    local rage = boss.rage
    local _, mult = boss:pace()
    local angry = boss:angry()
    boss.shriekT = 99
    stepAll(level, es, { pa }, 9, function()
        pa.invT, pa.vx = 9, 0
        boss.ceilT, boss.pingT = -99, -99
        seen[boss.state] = true
        if level.lightScale then dim = true; range = math.min(range, Lights.range(level)) end
        local n = 0
        for _, e in ipairs(boss:minions(level)) do if e.alive then n = n + 1 end end
        minions = math.max(minions, n)
    end)
    local back
    stepAll(level, es, { pa }, 8, function() pa.invT, pa.vx = 9, 0; boss.shriekT = 0; boss.ceilT, boss.pingT = -99, -99; if not level.lightScale then back = true end end)
    check('rabia', seen.roar and roarClaws and rage and (played.mgloomyRoar or 0) >= 1 and seen.shriek and dim and minions >= 1
        and range < Lights.RANGE * 0.6 and back and mult >= 1.4 and angry,
        ('ruge=%s con las pinzas en alto y otro cuadro=%s; rabia=%s (velocidad ×' .. mult .. ', se le nota=' .. tostring(angry) .. '); grito=%s: linterna %.1f → %.1f casillas, súbditos %d; la luz vuelve=%s'):format(
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
    boss.ang = math.pi
    boss:ping(); boss:ping(900)
    local pk = boss:netPackExtra()
    local l2, es2, r = arena()
    r:netApplyExtra(pk, pk, 1)
    check('red', r.phase == 2 and r.markX == 1234 and r.endX == 555 and r.kind == 3 and r.rage == true and r.face == -1
        and #r.pings == #boss.pings and r.pings[#r.pings].max == 900 and math.abs(r.ang - math.pi) < 0.01 and l2.lightScale == 0.5,
        ('fase %d, marca %d, fin %d, ataque %d, rabia %s, mira %d, aros %d/%d, luz ×%s'):format(r.phase, r.markX, r.endX,
         r.kind, tostring(r.rage), r.face, #r.pings, #boss.pings, tostring(l2.lightScale)))
end

local function look()
    local Darkness = require 'src/fx/Darkness'
    WINDOW_W, WINDOW_H = 1280, 720
    -- arriba (A LA LUZ, para ver las poses): rondar · ecolocalización · rugido con cristales
    -- abajo (a oscuras, como en el juego): embestida apuntando · estocada · deslumbrado
    local shots = { { 'aim', 0.5, false, false, 2, 'up' }, { 'claw', 0.1, false, true, 2, 'up' }, { 'prowl', 0.5, false, true },
                    { 'aim', 0.3, true, false, 4, 'ceil' }, { 'claw', 0.1, true, false, 2 }, { 'dazzled', 0.5, true } }
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
        boss.state, boss.deadTimer, boss.rage, boss.kind, boss.face = sh[1], sh[2], sh[4] == true, sh[5] or 0, -1
        boss.endX = zx1 - 125
        boss.markX, boss.markY = pa.x, pa.y
        if sh[6] == 'up' then boss.face, boss.markX, boss.markY = 1, boss.x + 2.2 * T, boss.y - 2 * T; pa.x, pa.y = boss.markX, boss.markY end
        if sh[6] == 'ceil' then
            local _, _, zy0 = floorPos(boss)
            boss.markX, boss.markY = pa.x, boss.y + 100
            boss.y, boss.ang = zy0 + 100, math.pi
        end
        if sh[1] ~= 'aim' or sh[5] ~= 2 then boss.face = (sh[6] == 'up') and 1 or -1 end
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
    for _, n in ipairs({ 'ronda', 'aro_detecta', 'embestida', 'pinzas', 'techo', 'luz', 'caja', 'rabia', 'muerte', 'red' }) do
        if not only or only == n then
            local ok, err = pcall(cases[n])
            if not ok then check(n, false, 'ERROR ' .. tostring(err)) end
        end
    end
    if os.getenv('LOOK') then look() end
    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
