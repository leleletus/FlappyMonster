-- tools/tests/snowboss_rules — reglas de la Gran Bola de Nieve contra los jugadores y el
-- escenario, caso a caso (salas hechas a mano + la arena real de lago_helado):
--   bola          una bola de nieve que le da: -1 de vida y empujón fuerte en su dirección;
--                 la bola desaparece. Invulnerable: ni daño ni empujón
--   bola_bomba    la bola-bomba que le da: -1, empujón y se convierte en bomba encendida
--   carambano     un carámbano cayendo encima: -2
--   ola           la ola de nieve del gran golpe: -1 y empujón hacia donde va la ola
--   onda_golpe    al aterrizar el gran golpe: cerca y a ras de suelo -1 y empujón MUY
--                 fuerte hacia fuera (y aturdido); lejos o en lo alto, nada
--   rueda_activa  rodando contra un Activador ON/OFF lo cambia (sus Congeladores disparan)
--   rueda_rompe   rodando contra bloques rompibles / nieve prensada / hielo: NO los rompe
--   lago_activa   la arena de lago_helado: rodando hacia la pared, el Activador cambia
--   enterrar      fase 3: nieve prensada en las 8 casillas alrededor de cada Activador,
--                 solo en las vacías (no toca bloques, agua ni la casilla de un jugador)
--
--   tools/tests/run.sh snowboss_rules
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
require 'settings'
Sound = setmetatable({}, { __index = function() return function() end end })
local P = require 'src/network/Protocol'
local stub = P.newInputStub()
Input = stub
local json = require 'libs/json'
local Level = require 'src/world/Level'
local Entities = require 'src/world/Entities'
local BossZones = require 'src/world/BossZones'
local PlayerAdventure = require 'src/entities/PlayerAdventure'
local TileCodec = require 'src/world/tiles/TileCodec'
local T = TILE_PX

local fails = 0
local function check(case, ok, msg)
    print(('%-13s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end

-- Sala W x H (suelo y paredes de piedra); `put` = { {col,row,tileName}, ... }
local function room(W, H, put, ents)
    local tiles = {}
    for r = 1, H do
        local row = {}
        for c = 1, W do row[c] = (r == H or c == 1 or c == W) and 1 or 0 end
        tiles[r] = row
    end
    for _, p in ipairs(put or {}) do tiles[p[2]][p[1]] = TileCodec.encode(_G['TILE_' .. p[3]:upper()]) end
    local level = Level.fromData({ name = 'test', width = W, height = H, playerStart = { 2, H - 1 },
                                   tiles = tiles, entities = ents or {} })
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    level.liveEntities = es
    level.players = {}
    local boss
    for _, e in ipairs(es) do if e.def.name == 'snowboss' then boss = e end end
    return level, es, boss
end

local function playerAt(level, col, row)
    local pa = PlayerAdventure:new((col - 0.5) * T, row * T - 60)
    for k in pairs(stub.state) do stub.state[k] = false end
    for _ = 1, 30 do pa:update(1 / 60, level) end
    level.players = { pa }
    return pa
end

-- Recorrido horizontal del jugador en `secs` s tras el golpe (sin pulsar nada)
local function travel(level, pa, secs)
    local x0 = pa.x
    for _ = 1, math.floor(secs * 60) do pa:update(1 / 60, level) end
    return pa.x - x0
end

local function fight(boss)
    boss.state, boss.deadTimer, boss.phase = 'idle', 0, 1
    boss.lake = {}
end

local cases = {}

function cases.bola()
    local level, es, boss = room(24, 10, nil, { { type = 'snowboss', col = 4, row = 9 } })
    fight(boss)
    local pa = playerAt(level, 14, 9)
    local hp0 = pa.hp
    boss.proj = { { id = 1, x = pa.x - 10, y = pa.y, vx = 500, vy = 0, kind = 1, t = 0 } }
    boss:hitWithShots(level)
    local vx, dx = pa.vx, travel(level, pa, 0.6)
    local okHit = pa.hp == hp0 - 1 and vx >= 500 and dx > 3 * T and #boss.proj == 0
    -- invulnerable: nada
    local pb = playerAt(level, 14, 9)
    pb:grantInvulnerability(2)
    boss.proj = { { id = 2, x = pb.x - 10, y = pb.y, vx = 500, vy = 0, kind = 1, t = 0 } }
    boss:hitWithShots(level)
    check('bola', okHit and pb.hp == pb.hpMax and math.abs(pb.vx) < 50 and #boss.proj == 1,
        ('vida %d→%d, vx %d, recorre %.1f casillas; invulnerable: vida %d vx %d'):format(
            hp0, pa.hp, vx, dx / T, pb.hp, pb.vx))
end

function cases.bola_bomba()
    local level, es, boss = room(24, 10, nil, { { type = 'snowboss', col = 4, row = 9 } })
    fight(boss)
    local pa = playerAt(level, 14, 9)
    boss.proj = { { id = 1, x = pa.x + 10, y = pa.y, vx = -500, vy = 0, kind = 2, t = 0 } }
    boss:hitWithShots(level)
    local lit = 0
    for _, e in ipairs(es) do if e.def.name == 'bombobject' and e.alive then lit = lit + 1 end end
    check('bola_bomba', pa.hp == pa.hpMax - 1 and pa.vx <= -500 and lit == 1,
        ('vida %d, vx %d, bombas encendidas %d'):format(pa.hp, pa.vx, lit))
end

function cases.carambano()
    local level, es, boss = room(24, 10, nil, { { type = 'snowboss', col = 4, row = 9 } })
    fight(boss)
    local pa = playerAt(level, 14, 9)
    boss.icicles = { { id = 1, x = math.floor(pa.x), y = pa.y - 60, vy = 400, t = 0, stage = 2 } }
    boss:hitWithShots(level)
    check('carambano', pa.hp == pa.hpMax - 2 and #boss.icicles == 0,
        ('vida %d/%d, carámbanos %d'):format(pa.hp, pa.hpMax, #boss.icicles))
end

function cases.ola()
    local level, es, boss = room(30, 10, nil, { { type = 'snowboss', col = 4, row = 9 } })
    fight(boss)
    local pa = playerAt(level, 14, 9)
    boss.shockX, boss.shockY = math.floor(pa.x - 0.3 * 560), 9 * T
    boss.shockT = 0.3
    boss:hitWithShots(level)
    local vx, dx = pa.vx, travel(level, pa, 0.8)
    check('ola', pa.hp == pa.hpMax - 1 and vx >= 900 and dx > 5 * T,
        ('vida %d, vx %d, recorre %.1f casillas'):format(pa.hp, vx, dx / T))
end

function cases.onda_golpe()
    local level, es, boss = room(40, 12, { { 30, 8, 'solid' }, { 31, 8, 'solid' }, { 32, 8, 'solid' } },
                                 { { type = 'snowboss', col = 15, row = 11 } })
    fight(boss)
    local near = PlayerAdventure:new((17.5) * T, 11 * T - 60)     -- 3 casillas a la derecha, en el suelo
    local far  = PlayerAdventure:new((5.5) * T, 11 * T - 60)      -- a 10 casillas
    local high = PlayerAdventure:new((31.5) * T, 7 * T - 60)      -- encima de un bloque alto (lejos)
    level.players = { near, far, high }
    for _ = 1, 30 do for _, p in ipairs(level.players) do p:update(1 / 60, level) end end
    boss:slamWave(level)
    local vx, stun = near.vx, near.stunT
    local dx = travel(level, near, 1.0)
    check('onda_golpe', near.hp == near.hpMax - 1 and vx >= 1300 and dx > 8 * T and stun > 0
                        and far.hp == far.hpMax and far.vx == 0 and high.hp == high.hpMax,
        ('cerca: vida %d vx %d recorre %.1f casillas; lejos: vida %d; en alto: vida %d'):format(
            near.hp, vx, dx / T, far.hp, high.hp))
end

-- Hace rodar al jefe hacia `dir` hasta que choque (o 3 s)
local function rollInto(level, boss, dir)
    boss.state, boss.deadTimer = 'roll', 0
    boss.dir, boss.vx, boss.bounces, boss.phase = dir, dir * 500, 0, boss.phase or 1
    for _ = 1, 180 do
        boss:update(1 / 60, level)
        if boss.state ~= 'roll' then break end
    end
end

function cases.rueda_activa()
    local level, es, boss = room(20, 10, { { 1, 9, 'switch_off' }, { 1, 8, 'switch_off' } },
                                 { { type = 'snowboss', col = 8, row = 9 } })
    fight(boss)
    level.players = {}
    rollInto(level, boss, -1)
    local a, b = level:getDef(1, 9).name, level:getDef(1, 8).name
    check('rueda_activa', a == 'switch_on' or b == 'switch_on',
        ('activadores tras el choque: (1,9)=%s (1,8)=%s; jefe en %s'):format(a, b, boss.state))
end

function cases.rueda_rompe()
    local level, es, boss = room(20, 10, { { 19, 9, 'breakable' }, { 19, 8, 'breakable' }, { 19, 7, 'thin_ice' },
                                           { 17, 9, 'packed_snow' } },
                                 { { type = 'snowboss', col = 8, row = 9 } })
    fight(boss)
    level.players = {}
    rollInto(level, boss, 1)
    local n = {}
    for _, cr in ipairs({ { 19, 9 }, { 19, 8 }, { 19, 7 }, { 17, 9 } }) do n[#n + 1] = level:getDef(cr[1], cr[2]).name end
    check('rueda_rompe', n[1] == 'breakable' and n[2] == 'breakable' and n[3] == 'thin_ice' and n[4] == 'packed_snow',
        ('tras chocar: %s'):format(table.concat(n, ', ')))
end

local function lago()
    local data = json.decode(love.filesystem.read('assets/levels/lago_helado.json'))
    local level = Level.fromData(data)
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    level.liveEntities = es
    BossZones.link(level, es)
    local boss
    for _, e in ipairs(es) do if e.def.name == 'snowboss' then boss = e end end
    level.players = {}
    return level, es, boss
end

function cases.lago_activa()
    local level, es, boss = lago()
    fight(boss)
    local acts = {}
    for r = 1, level.tileH do for c = 1, level.tileW do
        local n = level:getDef(c, r).name
        if n == 'switch_on' or n == 'switch_off' then acts[#acts + 1] = { c, r, n } end
    end end
    local out = {}
    for _, dir in ipairs({ -1, 1 }) do
        local before = {}
        for i, a in ipairs(acts) do before[i] = level:getDef(a[1], a[2]).name end
        rollInto(level, boss, dir)
        local changed = 0
        for i, a in ipairs(acts) do if level:getDef(a[1], a[2]).name ~= before[i] then changed = changed + 1 end end
        out[#out + 1] = changed
        boss.state = 'idle'
    end
    check('lago_activa', out[1] == 1 and out[2] == 1,
        ('rodando a la izquierda cambia %d activador(es), a la derecha %d'):format(out[1], out[2] or -1))
end

function cases.enterrar()
    -- Activador en medio de la sala: a su izquierda un bloque, abajo-derecha agua y
    -- arriba a la derecha un jugador de pie (encima de un bloque)
    local level, es, boss = room(16, 12, { { 8, 6, 'switch_on' }, { 7, 6, 'solid' }, { 9, 7, 'water' },
                                           { 9, 6, 'solid' } },
                                 { { type = 'snowboss', col = 3, row = 11 } })
    fight(boss)
    local pa = PlayerAdventure:new(7.5 * T, 5 * T - 32)
    level.players = { pa }
    for _ = 1, 20 do pa:update(1 / 60, level) end
    local pc, pr = math.floor(pa.x / T) + 1, math.floor(pa.y / T) + 1
    boss:bury(level)
    local got = {}
    for dr = -1, 1 do
        local line = ''
        for dc = -1, 1 do line = line .. (({ packed_snow = 'p', solid = '#', water = '~', switch_on = 'A', empty = '.' })[level:getDef(8 + dc, 6 + dr).name] or '?') end
        got[#got + 1] = line
    end
    -- esperado: arriba fila 5: (7,5) p, (8,5) jugador → vacío, (9,5) p; fila 6: # A #; fila 7: p p ~
    local want = { 'p.p', '#A#', 'pp~' }
    local ok = got[1] == want[1] and got[2] == want[2] and got[3] == want[3]
    check('enterrar', ok, ('alrededor: %s | %s | %s (jugador en %d,%d)'):format(got[1], got[2], got[3], pc, pr))
end

function love.load(arg)
    local only = os.getenv('CASE')
    for _, n in ipairs({ 'bola', 'bola_bomba', 'carambano', 'ola', 'onda_golpe', 'rueda_activa', 'rueda_rompe',
                         'lago_activa', 'enterrar' }) do
        if not only or only == n then
            local ok, err = pcall(cases[n])
            if not ok then check(n, false, 'error: ' .. tostring(err)) end
        end
    end
    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
