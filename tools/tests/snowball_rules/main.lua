-- tools/tests/snowball_rules — la BOLA DE NIEVE (`snowball`, enemigo de datos assets/enemies/snowball.json) y el
-- comportamiento genérico LANZARSE Y EMPUJAR (`ram`, src/world/entities/behaviors/ram.lua), caso a caso en salas hechas
-- a mano y sin ventana:
--   ve            ve a un jugador → aviso ('windup', su tiempo) → se lanza ('charge') hacia él
--   borde         en una repisa: el empujón lo TIRA por el borde hacia donde iba la bola (de lado y un poco arriba),
--                 a ≥ 2,5 casillas, sin quitarle vida; la bola frena en el borde (no se tira)
--   una_vez       un solo empujón por choque (ya lanzado no se repite) y la bola rebota y se ríe ('recoil')
--   invulnerable  recién golpeado (invulnerable) también se le empuja: no es daño
--   repisa        el jugador en una repisa 2 casillas más alta: salta hasta ella y lo empuja
--   hueco         a su altura al otro lado de un hueco de 2 casillas: lo cruza de un salto
--   pared         lanzada contra una pared: rebota mareada ('dazed') y luego vuelve a andar
--   pisoton       caerle encima la deshace (también lanzada: encima no empuja) y da sus puntos
--   ground_pound  un ground pound la deshace
--   tocar         tocarla andando quita 1 (onTouch 'hurt'); lanzada, por delante, empuja sin daño
--   arrolla       lanzada derriba a un Gummy que pilla delante (Entity:sweepAhead) y sigue
--   ruta          los límites de su ruta no la frenan lanzada (freeOfRoute)
--   red           lo que viaja (estado, reloj, x, y, mirada) basta: el cliente ve la MISMA caja de empujón y predice el
--                 MISMO lanzamiento (vx, vy) que el servidor; su sonido (`launchSound`) es el del empujón
--   escarabajo    el Escarabajo sigue arrollando enemigos con el arrollar común (Entity:sweepAhead)
--
--   LOOK=1        además guarda <save>/snowball_look.png (sus poses en una sala nevada junto al jugador)
--
--   tools/tests/run.sh snowball_rules   (CASE=nombre: solo ese; LOOK=1)
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
require 'settings'
local played = {}
Sound = setmetatable({ play = function(n) played[n] = (played[n] or 0) + 1 end },
                     { __index = function() return function() end end })
local P = require 'src/network/Protocol'
local stub = P.newInputStub()
Input = stub
local Level = require 'src/world/level/Level'
local Entities = require 'src/world/entities/Entities'
local Interactions = require 'src/world/entities/base/Interactions'
local PlayerAdventure = require 'src/player/PlayerAdventure'
local T = TILE_PX

local fails = 0
local function check(case, ok, msg)
    print(('%-13s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end

-- Sala W x H: suelo (fila H), techo (fila 1) y paredes; `blocks` = { {c, r}, ... } más bloques; `holes` = { c, ... }
-- columnas sin suelo (el fondo del nivel es la fila H: un hueco ahí es el vacío)
local function room(W, H, ents, blocks, holes)
    local tiles = {}
    for r = 1, H do
        local row = {}
        for c = 1, W do row[c] = (r == 1 or r == H or c == 1 or c == W) and 1 or 0 end
        tiles[r] = row
    end
    for _, b in ipairs(blocks or {}) do tiles[b[2]][b[1]] = 1 end
    for _, c in ipairs(holes or {}) do tiles[H][c] = 0 end
    local level = Level.fromData({ name = 't', width = W, height = H, playerStart = { 2, H - 1 },
                                   tiles = tiles, entities = ents or {} })
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    level.liveEntities, level.players = es, {}
    return level, es, es[1]
end

local function clearInput() for k in pairs(stub.state) do stub.state[k] = false end end

local function player(level, x, feetY)
    clearInput()
    local pa = PlayerAdventure:new(x, feetY - 50)
    level.players = { pa }
    return pa
end

-- Simula `secs` s: jugadores, nivel, entidades, interacciones (`each()` → true para parar)
local function step(level, es, secs, each)
    for _ = 1, math.floor(secs * 60) do
        for _, pa in ipairs(level.players) do pa:update(1 / 60, level) end
        level.solidBodies = Entities.solidBodies(es)
        level:update(1 / 60)
        for _, e in ipairs(es) do if e.alive then e:update(1 / 60, level) end end
        for _, pa in ipairs(level.players) do Interactions.run(pa, es, {}) end
        if each and each() then return true end
    end
end

local function ent(type, col, row, props)
    local p = { movement = 'walk', pauses = false, startDir = 'right' }
    for k, v in pairs(props or {}) do p[k] = v end
    return { type = type, col = col, row = row, props = p }
end

-- Cuenta los lanzamientos que recibe un jugador (y con qué velocidad)
local function spyLaunch(pa)
    local log = {}
    local orig = pa.launch
    pa.launch = function(self, vx, vy, j) log[#log + 1] = { vx = vx, vy = vy, x = self.x, t = love.timer.getTime() }; return orig(self, vx, vy, j) end
    return log
end

local cases = {}

function cases.ve()
    local level, es, e = room(20, 8, { ent('snowball', 4, 7) })
    local pa = player(level, 9.5 * T, 7 * T)
    local tWind, tCharge, t = nil, nil, 0
    step(level, es, 3, function()
        t = t + 1 / 60
        if e.state == 'windup' and not tWind then tWind = t end
        if e.state == 'charge' and not tCharge then tCharge = t end
        return tCharge ~= nil
    end)
    local gap = (tWind and tCharge) and (tCharge - tWind) or -1
    check('ve', tWind ~= nil and tCharge ~= nil and math.abs(gap - 0.55) < 0.05 and e.facing == 1 and e.vx > 0,
        ('aviso a %.2f s, lanzada %.2f s después (0,55), hacia %d'):format(tWind or -1, gap, e.facing or 0))
end

-- Repisa de la columna 2 a la 11 en la fila 6; el resto es un hueco hasta el suelo (fila 10)
local function ledgeRoom(extra)
    local blocks = {}
    for c = 2, 11 do blocks[#blocks + 1] = { c, 6 } end
    local ents = { ent('snowball', 4, 5) }
    for _, x in ipairs(extra or {}) do ents[#ents + 1] = x end
    return room(22, 10, ents, blocks)
end

function cases.borde()
    local level, es, e = ledgeRoom()
    local pa = player(level, 10.6 * T, 5 * T)                     -- a media casilla del borde (el borde: x = 11 T)
    local log = spyLaunch(pa)
    local hp0 = pa.hp
    step(level, es, 3)
    local l = log[1]
    local fell = pa.y > 6 * T and pa.x > 11 * T
    local dx = l and (pa.x - l.x) or 0
    check('borde', l ~= nil and l.vx > 0 and l.vy < 0 and fell and pa.hp == hp0 and dx > 2.5 * T and e.alive
        and e.y < 6 * T and e.x < 11 * T,
        ('empujón vx %d vy %d; jugador cayó del borde a x %.1f casillas (%.1f desde el golpe), vida %d→%d; bola en la repisa (x %.1f)')
        :format(l and l.vx or 0, l and l.vy or 0, pa.x / T, dx / T, hp0, pa.hp, e.x / T))
end

function cases.una_vez()
    local level, es, e = room(24, 8, { ent('snowball', 4, 7) })
    local pa = player(level, 9.5 * T, 7 * T)
    local log = spyLaunch(pa)
    local sawRecoil = false
    step(level, es, 2.5, function() sawRecoil = sawRecoil or e.state == 'recoil' end)
    check('una_vez', #log == 1 and sawRecoil and (played.snowballShove or 0) >= 1,
        ('lanzamientos %d (1), la bola se rió (recoil) %s, sonido del empujón %d'):format(#log, tostring(sawRecoil), played.snowballShove or 0))
end

function cases.invulnerable()
    local level, es = room(20, 8, { ent('snowball', 4, 7) })
    local pa = player(level, 9.5 * T, 7 * T)
    pa:grantInvulnerability(5)
    local log = spyLaunch(pa)
    step(level, es, 2)
    check('invulnerable', #log == 1, ('invulnerable: lanzamientos %d (1)'):format(#log))
end

function cases.repisa()
    -- repisa alta (fila 5) de la columna 9 a la 14: 2 casillas más alta que el suelo de la bola (fila 7)
    local blocks = {}
    for c = 9, 14 do blocks[#blocks + 1] = { c, 6 } end
    local level, es, e = room(20, 8, { ent('snowball', 4, 7) }, blocks)
    local pa = player(level, 10 * T, 5 * T)
    local log = spyLaunch(pa)
    local top = math.huge
    step(level, es, 3, function() if e.state == 'charge' then top = math.min(top, e.y + e.outerH / 2) end end)
    check('repisa', #log >= 1 and log[1].vx > 0 and top <= 5 * T + 2,
        ('pies de la bola subieron a %.2f casillas (repisa 5), empujones %d'):format(top / T, #log))
end

function cases.hueco()
    -- suelo de la fila 8 con un hueco en las columnas 8 y 9 (al vacío): el jugador al otro lado
    local level, es, e = room(22, 8, { ent('snowball', 5, 7) }, nil, { 8, 9 })
    local pa = player(level, 11.5 * T, 7 * T)
    local log = spyLaunch(pa)
    step(level, es, 2.5)
    check('hueco', #log >= 1 and e.alive and e.state ~= 'dead_burst' and e.x > 10 * T,
        ('cruzó el hueco: bola en x %.1f casillas (%s), empujones %d'):format(e.x / T, e.state, #log))
end

function cases.pared()
    -- pared (columna 9) tras el jugador; el jugador ya va lanzado (ctrlLockT) y la bola lo atraviesa hasta la pared
    local level, es, e = room(20, 8, { ent('snowball', 4, 7, { startDir = 'right' }) }, { { 9, 7 }, { 9, 6 } })
    local pa = player(level, 7 * T, 7 * T)
    pa.update = function(self) self.ctrlLockT = 1 end
    local sawDazed, back = false, false
    local b0 = played.snowballBonk or 0
    step(level, es, 4, function()
        if e.state == 'dazed' then sawDazed = true end
        if sawDazed and e.state == 'walk' then back = true; return true end
    end)
    check('pared', sawDazed and back and (played.snowballBonk or 0) > b0,
        ('contra la pared: mareada %s, vuelve a andar %s, sonido %s'):format(tostring(sawDazed), tostring(back), tostring((played.snowballBonk or 0) > b0)))
end

function cases.pisoton()
    local level, es, e = room(20, 8, { ent('snowball', 8, 7) })
    local pa = player(level, e.x, 3 * T)
    pa.vy = 300
    local pts = 0
    local died = false
    for _ = 1, 90 do
        pa:update(1 / 60, level); e:update(1 / 60, level)
        Interactions.run(pa, es, { stomp = function(_, p) pts = pts + (p or 0) end })
        if e.state == 'dead' then died = true; break end
    end
    -- lanzada: caerle encima tampoco empuja, la pisa
    local level2, es2, e2 = room(30, 8, { ent('snowball', 4, 7) })
    local pa2 = player(level2, 20 * T, 7 * T)
    step(level2, es2, 3, function() return e2.state == 'charge' end)
    local log = spyLaunch(pa2)
    pa2.x, pa2.y, pa2.vy = e2.x + e2.facing * 4, e2.y - e2.outerH / 2 - 52, 420
    local died2 = false
    for _ = 1, 30 do
        pa2:update(1 / 60, level2); e2:update(1 / 60, level2)
        Interactions.run(pa2, es2, {})
        if e2.state == 'dead' then died2 = true; break end
    end
    check('pisoton', died and pts == 20 and died2 and #log == 0,
        ('andando: deshecha %s (%d puntos); lanzada: deshecha %s, empujones %d (0)'):format(tostring(died), pts, tostring(died2), #log))
end

function cases.ground_pound()
    local level, es, e = room(20, 8, { ent('snowball', 8, 7) })
    local pa = player(level, e.x, 3 * T)
    pa.gpPhase, pa.vy = 'fall', 900
    step(level, es, 0.6)
    check('ground_pound', e.state == 'dead' or not e.alive, ('ground pound encima: bola %s'):format(e.state))
end

function cases.tocar()
    local level, es, e = room(20, 8, { ent('snowball', 8, 7, { speed = 0 }) })
    local pa = player(level, e.x - 30, 7 * T)
    e.cd_ram = 99                                                  -- (que no se lance: solo tocarla)
    local hp0 = pa.hp
    step(level, es, 0.2)
    check('tocar', pa.hp == hp0 - 1, ('tocarla quieta/andando: vida %d→%d'):format(hp0, pa.hp))
end

function cases.arrolla()
    local level, es, e = room(24, 8, { ent('snowball', 4, 7), ent('gummy', 6, 7, { speed = 0 }) })
    local pa = player(level, 9 * T, 7 * T)
    local g = es[2]
    local knocked = false
    step(level, es, 2, function() knocked = knocked or g.state == 'stunned' end)
    check('arrolla', knocked and g.alive, ('Gummy delante de la bola lanzada: aturdido %s'):format(tostring(knocked)))
end

function cases.ruta()
    local level, es, e = room(24, 8, { ent('snowball', 4, 7, { patrol = { 3, 6 } }) })
    local pa = player(level, 10 * T, 7 * T)
    local maxX = 0
    local log = spyLaunch(pa)
    step(level, es, 2.5, function() maxX = math.max(maxX, e.x) end)
    check('ruta', maxX > 7 * T and #log >= 1, ('ruta 3-6: lanzada llegó a x %.1f casillas, empujones %d'):format(maxX / T, #log))
end

-- Lo que viaja en una instantánea (como server/main.lua y OnlineAdventureState): campos comunes + netPack
local function snapshotTo(srv, cli)
    cli.x, cli.y, cli.facing, cli.state, cli.frame, cli.alive = srv.x, srv.y, srv.facing, srv.state, srv.frame, srv.alive
    cli.deadTimer, cli.flipped = math.floor(srv.deadTimer * 100 + 0.5) / 100, srv.flipped
    local pk = srv:netPack()
    if pk then cli:netApply(pk, pk, 1) end
end

function cases.red()
    local level, es, srv = room(24, 8, { ent('snowball', 4, 7) })
    local cli = Entities.create(level.entities[1])
    local pa = player(level, 9.5 * T, 7 * T)
    pa.update = function() end                                    -- (quieto: una sonda)
    local same, n, tried = true, 0, 0
    local msg = ''
    step(level, es, 2.5, function()
        snapshotTo(srv, cli)
        if srv.state == 'charge' then
            n = n + 1
            for _, dx in ipairs({ -40, 0, 30, 60 }) do
                local probe = PlayerAdventure:new(srv.x + srv.facing * (srv.outerW / 2 + dx), srv.y - 20)
                local r1, a1, b1 = Interactions.check(probe, srv)
                local r2, a2, b2 = Interactions.check(probe, cli)
                tried = tried + 1
                if r1 ~= r2 or a1 ~= a2 or b1 ~= b2 then same = false; msg = ('%s/%s'):format(tostring(r1), tostring(r2)) end
            end
        end
    end)
    -- (misma respuesta = mismo 'launch' con el mismo vx, vy: lo que predice el cliente — OnlineAdventureState —)
    local ok = same and n > 0 and cli.launchSound == 'snowballShove'
    check('red', ok, ('%d pasos lanzada, %d sondas: misma respuesta en cliente y servidor %s %s; sonido predicho %s')
        :format(n, tried, tostring(same), msg, tostring(cli.launchSound)))
end

function cases.escarabajo()
    local level, es, b = room(24, 8, { ent('beetle', 4, 7), ent('gummy', 7, 7, { speed = 0 }) })
    local pa = player(level, 9.5 * T, 7 * T)
    local g = es[2]
    local knocked = false
    step(level, es, 2.5, function() knocked = knocked or g.state == 'stunned' end)
    check('escarabajo', knocked, ('Escarabajo embistiendo arrolla al Gummy: %s'):format(tostring(knocked)))
end

-- LOOK=1: <save>/snowball_look.png — en una sala nevada, junto al jugador: rodando, aviso, lanzada, riéndose, mareada,
-- aplastada y el montón de nieve (lo que se ve en el juego, con el render de verdad)
local function look()
    local level, es = room(16, 5, { ent('snowball', 4, 4), ent('snowball', 6, 4), ent('snowball', 8, 4), ent('snowball', 10, 4),
                                    ent('snowball', 12, 4), ent('snowball', 13, 4), ent('snowball', 15, 4) })
    level.background = 'snow'
    local pa = player(level, 2 * T, 4 * T)
    pa.update = function() end
    step(level, es, 0.05)
    local poses = { { 'walk' }, { 'windup', 0.1 }, { 'charge', 0.1 }, { 'recoil', 0.1 }, { 'dazed', 0.1 }, { 'dead', 0.05 }, { 'dead', 0.6 } }
    for i, e in ipairs(es) do e.state, e.deadTimer = poses[i][1], poses[i][2] or 0 end
    local cv = love.graphics.newCanvas(16 * T, 5 * T)
    love.graphics.setCanvas(cv)
    love.graphics.clear(0.62, 0.74, 0.88, 1)
    level:render(0, 0)
    pa:render(0, 0)
    for _, e in ipairs(es) do e:render(0, 0) end
    love.graphics.setCanvas()
    cv:newImageData():encode('png', 'snowball_look.png')
    print('guardado ' .. love.filesystem.getSaveDirectory() .. '/snowball_look.png')
end

function love.load()
    if os.getenv('LOOK') then look() end
    local only = os.getenv('CASE')
    for _, n in ipairs({ 've', 'borde', 'una_vez', 'invulnerable', 'repisa', 'hueco', 'pared', 'pisoton', 'ground_pound',
                         'tocar', 'arrolla', 'ruta', 'red', 'escarabajo' }) do
        if not only or only == n then
            local ok, err = pcall(cases[n])
            if not ok then check(n, false, 'error: ' .. tostring(err)) end
        end
    end
    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
