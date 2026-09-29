-- tools/tests/flood_control — inundaciones CONECTADAS (src/world/Floods.lua):
--   jefe_antes   (fortaleza_malvada, su inundación con control 'boss' y el jefe
--                real) antes de la pelea está en su mínimo
--   jefe_ciclo   durante la pelea hace su ciclo: llega al máximo y vuelve al mínimo,
--                igual que Floods.levelAt desde el inicio de la pelea
--   jefe_muerte  al entrar el jefe en su secuencia de muerte se apaga, baja al
--                mínimo y se queda; el agua nunca da saltos
--   switch_on    un jugador real da un cabezazo al bloque OFF conectado → ON: la
--                inundación sube hasta el máximo y se queda
--   switch_off   otro cabezazo → OFF: baja hasta el mínimo y se queda
--   switch_step  subida por escalones (riseStep/risePause): hay pausas y llega igual
--   red          un "cliente" que solo recibe Floods.netPack del servidor (como
--                el snapshot 'fc') ve exactamente la misma agua en cada tick
--   editor       conexiones guardadas y cargadas, números de inundación únicos y
--                aviso de una conexión a una inundación que no existe
--
--   tools/tests/run.sh flood_control
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
local Floods = require 'src/world/Floods'
local PlayerAdventure = require 'src/entities/PlayerAdventure'
local TileTypes = require 'src/world/tiles/TileTypes'
local T = TILE_PX
local DT = 1 / 60

local fails = 0
local function check(case, ok, msg)
    print(('%-12s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end
local function clear() for k in pairs(stub.state) do stub.state[k] = false end end

local cases = {}

function cases.jefe()
    local data = json.decode(love.filesystem.read('assets/levels/fortaleza_malvada.json'))
    local level = Level.fromData(data)
    local ents = {}
    for _, pl in ipairs(level.entities) do ents[#ents + 1] = Entities.create(pl) end
    level.liveEntities = ents
    local ctrl = BossZones.newController(level, ents)
    local boss
    for _, e in ipairs(ents) do if e.def.boss then boss = e end end
    local f
    for _, ff in ipairs(level.floods) do if ff.control == 'boss' then f = ff end end
    if not f then check('jefe_antes', false, 'fortaleza_malvada no tiene inundación con control "boss"'); return end
    local z = boss.zone
    -- Jugador fuera de la zona 3 s; luego dentro (empieza la pelea)
    local pa = PlayerAdventure:new(z.x0 - 4 * T, z.y1 - 60)
    level.players = { pa }
    local t, preMax, fightT, killT = 0, 0, nil, nil
    local maxLv, minAfterMax, maxStep, last = 0, math.huge, 0, f.level
    local cycleErr, endLv, endActive = 0, nil, nil
    local reachedHi = false
    while t < 120 do
        t = t + DT
        if t > 3 and not fightT and not pa.dying then
            local gx, gy = level:findGround(z.col + 3, z.col, z.col + z.w - 1, z.row, z.row + z.h - 1)
            pa.x, pa.y, pa.vx, pa.vy = gx, gy, 0, 0
        end
        clear()
        pa:update(DT, level)
        level.solidBodies = Entities.solidBodies(ents)
        for _, ev in ipairs(ctrl:update(DT)) do if ev.type == 'boss_start' then fightT = t end end
        Floods.advance(level, DT)
        for _, e in ipairs(ents) do if e.alive then e:update(DT, level) end end
        pa.invT = 99                                    -- (el jugador no importa aquí: que no muera)
        if not fightT then preMax = math.max(preMax, math.abs(f.level - f.lo)) end
        maxStep = math.max(maxStep, math.abs(f.level - last)); last = f.level
        if fightT and not killT then
            maxLv = math.max(maxLv, f.level)
            if f.level >= f.hi - 1e-3 then reachedHi = true end
            if reachedHi then minAfterMax = math.min(minAfterMax, f.level) end
            -- (mismo ciclo que el de siempre, contado desde que se activó)
            cycleErr = math.max(cycleErr, math.abs(f.level - Floods.levelAt(f, level.floodTime - f.t0)))
            if t - fightT > f.startDelay + f.cycle * 1.3 then
                killT = t; boss.hp = 0; boss:defeat()
            end
        end
        if killT and t - killT > (f.hi - f.lo) / f.fallSpeed + 8 then endLv, endActive = f.level, f.active; break end
    end
    check('jefe_antes', preMax < 1e-6, ('antes de la pelea: se separa del mínimo %.4f casillas'):format(preMax))
    check('jefe_ciclo', fightT and reachedHi and minAfterMax <= f.lo + 1e-3 and cycleErr < 1e-6,
        ('pelea a los %s s: máximo %.2f (hi %.2f), vuelve a %.2f (lo %.2f), error frente al ciclo %.6f'):format(
            tostring(fightT and ('%.1f'):format(fightT)), maxLv, f.hi, minAfterMax, f.lo, cycleErr))
    local lim = math.max(f.riseSpeed, f.fallSpeed) * DT + 1e-6
    check('jefe_muerte', killT and endLv and math.abs(endLv - f.lo) < 1e-6 and endActive == false and maxStep <= lim,
        ('jefe muerto a los %s s → nivel final %.3f (lo %.2f), activa=%s; salto máximo %.4f (límite %.4f)'):format(
            tostring(killT and ('%.1f'):format(killT)), endLv or -1, f.lo, tostring(endActive), maxStep, lim))
end

-- Sala con una inundación conectada a un bloque ON/OFF (encima del jugador)
local function switchRoom(props)
    local W, H = 14, 10
    local tiles = {}
    for r = 1, H do
        local row = {}
        for c = 1, W do row[c] = (r == H or c == 1 or c == W) and 1 or 0 end
        tiles[r] = row
    end
    tiles[7][4] = TileTypes.byName.switch_off.id
    local p = { id = 3, control = 'switch', corner = { col = 13, row = 9 }, startLevel = 1, maxLevel = 5 }
    for k, v in pairs(props or {}) do p[k] = v end
    local data = { name = 'test', width = W, height = H, playerStart = { 4, 9 }, tiles = tiles,
                   entities = { { type = 'flood', col = 8, row = 2, props = p } },
                   links = { { col = 4, row = 7, flood = 3 } } }
    return Level.fromData(json.decode(json.encode(data))), data
end
local function bump(level, pa, run)
    clear(); stub.state.jump_pressed, stub.state.jump = true, true
    for _ = 1, 50 do pa:update(DT, level); run(); stub.state.jump_pressed = false end
    clear(); stub.state.jump = false
    for _ = 1, 40 do pa:update(DT, level); run() end
end

function cases.switch()
    local level = switchRoom()
    local f = level.floods[1]
    local pa = PlayerAdventure:new(3.5 * T, 9 * T - 60)
    level.players = { pa }
    local maxStep, last = 0, f.level
    local function run()
        Floods.advance(level, DT)
        maxStep = math.max(maxStep, math.abs(f.level - last)); last = f.level
    end
    for _ = 1, 120 do pa:update(DT, level); run() end
    local lv0 = f.level
    bump(level, pa, run)
    local on = level:getDef(4, 7).name
    for _ = 1, 60 * ((f.hi - f.lo) / f.riseSpeed + 3) do run() end
    local up, act = f.level, f.active
    check('switch_on', math.abs(lv0 - f.lo) < 1e-6 and on == 'switch_on' and act and math.abs(up - f.hi) < 1e-6,
        ('antes %.2f (lo %.2f) → bloque %s → activa=%s, nivel %.3f (hi %.2f)'):format(lv0, f.lo, on, tostring(act), up, f.hi))
    bump(level, pa, run)
    local off = level:getDef(4, 7).name
    for _ = 1, 60 * ((f.hi - f.lo) / f.fallSpeed + 3) do run() end
    local lim = math.max(f.riseSpeed, f.fallSpeed) * DT + 1e-6
    check('switch_off', off == 'switch_off' and not f.active and math.abs(f.level - f.lo) < 1e-6 and maxStep <= lim,
        ('bloque %s → activa=%s, nivel %.3f (lo %.2f); salto máximo %.4f (límite %.4f)'):format(off, tostring(f.active),
            f.level, f.lo, maxStep, lim))
end

function cases.switch_step()
    local level = switchRoom({ riseStep = 1, risePause = 1, riseSpeed = 1 })
    local f = level.floods[1]
    level:setTileRaw(4, 7, TileTypes.byName.switch_on.id)
    local still, t, reached = 0, 0, nil
    local last = f.level
    while t < 20 do
        t = t + DT
        Floods.advance(level, DT)
        if f.level > f.lo + 0.01 and f.level < f.hi - 0.01 and math.abs(f.level - last) < 1e-9 then still = still + DT end
        if not reached and f.level >= f.hi - 1e-6 then reached = t end
        last = f.level
    end
    -- 4 casillas a 1 casilla/s con 3 pausas de 1 s = 7 s
    check('switch_step', reached and math.abs(reached - 7) < 0.1 and still > 2.5,
        ('llega al máximo a los %s s (esperado 7), %.2f s quieta entre escalones'):format(tostring(reached and ('%.2f'):format(reached)), still))
end

function cases.red()
    local server = switchRoom()
    local _, data = switchRoom()
    local client = Level.fromData(json.decode(json.encode(data)))
    local sf, cf = server.floods[1], client.floods[1]
    local TICK = P.TICK_DT
    local maxErr, changes, lastA = 0, 0, false
    for tick = 1, math.floor(40 / TICK) do
        local t = tick * TICK
        -- el servidor enciende y apaga el bloque a ratos
        if tick == math.floor(3 / TICK) or tick == math.floor(20 / TICK) then server:setTileRaw(4, 7, TileTypes.byName.switch_on.id) end
        if tick == math.floor(9 / TICK) or tick == math.floor(26 / TICK) then server:setTileRaw(4, 7, TileTypes.byName.switch_off.id) end
        Floods.control(server, t); Floods.setTime(server, t)
        local pk = json.decode(json.encode(Floods.netPack(server, TICK)))   -- (por la red)
        Floods.netApply(client, pk, TICK); Floods.setTime(client, t)
        maxErr = math.max(maxErr, math.abs(sf.level - cf.level))
        if cf.active ~= lastA then changes = changes + 1; lastA = cf.active end
    end
    check('red', maxErr < 2e-3 and changes == 4,
        ('diferencia máxima servidor/cliente %.5f casillas; cambios vistos en el cliente %d (esperados 4)'):format(maxErr, changes))
end

function cases.editor()
    local Model = require 'src/editor/EditorModel'
    local m = Model.new(20, 10, 'links')
    m:setId(5, 5, TileTypes.byName.switch_off.id)
    m:setId(7, 5, TileTypes.byName.switch_on.id)
    m:addEntity('flood', 10, 3); m:addEntity('flood', 14, 3)
    local fl = m:floods()
    fl[1].props.control, fl[2].props.control = 'switch', 'switch'
    m:setLink(5, 5, fl[2].props.id); m:setLink(7, 5, 42)
    local m2 = Model.fromData(json.decode(m:encode()))
    local ids = {}
    for _, f in ipairs(m2:floods()) do ids[#ids + 1] = f.props.id end
    local l1, l2 = m2:linkAt(5, 5), m2:linkAt(7, 5)
    local warn = false
    for _, w in ipairs(m2:validate()) do if w[2]:find('#42') then warn = true end end
    local lv = Level.fromData(json.decode(m:encode()))
    local linked = lv.floods[2] and #lv.floods[2].switches == 1
    check('editor', #ids == 2 and ids[1] ~= ids[2] and l1 and l1.flood == ids[2] and l2 and warn and linked,
        ('ids %s; (5,5) → #%s; aviso de la #42=%s; el juego la enlaza=%s'):format(table.concat(ids, ','),
            tostring(l1 and l1.flood), tostring(warn), tostring(linked)))
end

function love.load()
    for _, n in ipairs({ 'jefe', 'switch', 'switch_step', 'red', 'editor' }) do cases[n]() end
    print(fails == 0 and 'TODO OK' or (fails .. ' FALLOS'))
    love.event.quit(fails == 0 and 0 or 1)
end
