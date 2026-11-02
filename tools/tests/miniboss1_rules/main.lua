-- tools/tests/miniboss1_rules — reglas de la NAVE DEL MONSTRUO MALVADO (types/bosses/miniboss1.lua) caso a caso, en una
-- sala hecha aquí:
--   picado     con un jugador debajo: se para, saca los pinchos, cae; quien está debajo muere; se queda clavada y sube
--   ventana    patrullando caerle encima solo rebota (sin daño); clavada, un pisotón -1; un golpe por noqueo
--   rompe      al chocar rompe los bloques rompibles a lo ancho de la nave
--   suelo      nunca baja del suelo de la sala: se clava en él
--   muerte     sin vida: explota, expulsa al monstruo, explosión final y queda 'dead'; ya no hace daño
--   red        netPackExtra → otra nave (cliente): pinchos y monstruo iguales
--
--   tools/tests/run.sh miniboss1_rules   (CASE=nombre)
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
require 'settings'
Sound = setmetatable({}, { __index = function() return function() end end })
local P = require 'src/network/Protocol'
Input = P.newInputStub()
local Level = require 'src/world/level/Level'
local Entities = require 'src/world/entities/Entities'
local Interactions = require 'src/world/entities/base/Interactions'
local PlayerAdventure = require 'src/player/PlayerAdventure'
local T = TILE_PX
local DT = 1 / 60
local W, H, FLOOR = 30, 16, 15        -- (fila 15: el suelo; 16: el borde)
local BREAK = 12

local fails = 0
local function check(case, ok, msg)
    print(('%-10s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end

-- La sala; `blocks` = { {col, fila, tile} }. La nave, en la columna 15, en lo alto
local function room(blocks, props)
    local tiles = {}
    for r = 1, H do
        tiles[r] = {}
        for c = 1, W do tiles[r][c] = (r >= FLOOR or c == 1 or c == W) and 1 or 0 end
    end
    for _, b in ipairs(blocks or {}) do tiles[b[2]][b[1]] = b[3] end
    local pr = { hp = 3, detectionTime = 0.2, stuckTime = 1.5 }
    for k, v in pairs(props or {}) do pr[k] = v end
    local level = Level.fromData({ name = 'nave', width = W, height = H, playerStart = { 3, FLOOR - 1 }, tiles = tiles,
        entities = { { type = 'miniboss1', col = 15, row = 4, props = pr } } })
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    level.liveEntities = es
    level.players = {}
    es[1].levelRef = level
    es[1]:startFight(1)
    return level, es, es[1]
end
local function player(level, col)
    local pa = PlayerAdventure:new((col - 0.5) * T, (FLOOR - 1) * T - 60)
    for _ = 1, 30 do pa:update(DT, level) end
    level.players = { pa }
    return pa
end
local function steps(level, es, secs, stop, pa, hold)
    for _ = 1, math.floor(secs * 60) do
        if pa and hold then hold() end
        if pa then pa:update(DT, level) end
        for _, e in ipairs(es) do e:update(DT, level) end
        if pa then Interactions.run(pa, es, {}) end
        if stop and stop() then return true end
    end
    return stop == nil
end
local function state(b, ...) for _, s in ipairs({ ... }) do if b.state == s then return true end end return false end

local cases = {}

-- Hasta que empieza a patrullar, con el jugador lejos
local function ready(level, es, b)
    return steps(level, es, 8, function() return b.state == 'patrol' end)
end

function cases.picado()
    local level, es, b = room()
    local patrolled = ready(level, es, b)
    local pa = player(level, 15)
    pa.x, pa.lives = b.x, 5
    local seen, died = {}, false
    steps(level, es, 25, function()
        pa.x = b.x; pa.vx = 0                 -- (siempre debajo)
        seen[b.state] = true
        if pa.dying then died = true end
        return seen.rise and b.state == 'patrol'
    end, pa)
    check('picado', patrolled and seen.prep and seen.slam and seen.stuck and seen.rise and died,
        ('patrulla=%s · se para=%s · cae=%s · clavada=%s · sube=%s · el de debajo muere=%s'):format(tostring(patrolled),
        tostring(seen.prep), tostring(seen.slam), tostring(seen.stuck), tostring(seen.rise), tostring(died)))
end

-- Le cae encima desde arriba: lo que pasa
local function dropOn(level, es, b)
    local pa = player(level, 3)
    local ob = b:getOuterBounds()
    pa.x, pa.y, pa.vy, pa.prevY = b.x, ob.y - 40, 500, ob.y - 60
    pa.onGround = false
    local hp0 = b.hp
    local bounced = false
    for _ = 1, 30 do
        pa:update(DT, level)
        Interactions.run(pa, es, {})
        if pa.vy < 0 then bounced = true; break end
    end
    return hp0 - b.hp, bounced
end

function cases.ventana()
    local level, es, b = room(nil, { detectionTime = 99 })
    ready(level, es, b)
    local d0, b0 = dropOn(level, es, b)
    -- clavada
    local level2, es2, b2 = room()
    ready(level2, es2, b2)
    local pa = player(level2, 15)
    pa.x = b2.x
    pa.invT = 99
    steps(level2, es2, 15, function() pa.x = b2.x; return b2.state == 'stuck' end, pa)
    level2.players = {}
    local d1, b1 = dropOn(level2, es2, b2)
    local inv = b2.inv > 0
    local d2 = dropOn(level2, es2, b2)
    check('ventana', d0 == 0 and b0 and d1 == 1 and b1 and inv and d2 == 0,
        ('patrullando: daño %d, rebota=%s · clavada: daño %d, rebota=%s · un golpe por noqueo: el siguiente, %d'):format(d0, tostring(b0), d1, tostring(b1), d2))
end

function cases.rompe()
    local blocks = {}
    for c = 13, 17 do blocks[#blocks + 1] = { c, 10, BREAK } end
    local level, es, b = room(blocks)
    ready(level, es, b)
    local pa = player(level, 15)
    pa.invT = 99
    steps(level, es, 15, function() pa.x = b.x; pa.invT = 99; return b.state == 'stuck' end, pa)
    local c = math.floor(b.x / T) + 1
    local gone = level:getDef(c, 10).name ~= level:getDef(1, 1).name and level:getDef(c, 10).collision ~= 'solid'
    local left = 0
    for x = 13, 17 do if level:getDef(x, 10).collision == 'solid' then left = left + 1 end end
    -- (se para en ese golpe; el siguiente picado cae por el agujero)
    check('rompe', b.state == 'stuck' and gone and left < 5,
        ('clavada=%s · el bloque de debajo roto=%s · quedan %d de 5 (a lo ancho de la nave)'):format(tostring(b.state == 'stuck'), tostring(gone), left))
end

function cases.suelo()
    local level, es, b = room()
    ready(level, es, b)
    local pa = player(level, 15)
    pa.invT = 99
    steps(level, es, 15, function() pa.x = b.x; pa.invT = 99; return b.state == 'stuck' end, pa)
    local bottom = b:bottomY()
    check('suelo', b.state == 'stuck' and bottom <= (FLOOR - 1) * T + 2 and bottom >= (FLOOR - 1) * T - 8,
        ('se clava con los pinchos en el suelo: %.0f (el suelo, %.0f)'):format(bottom, (FLOOR - 1) * T))
end

function cases.muerte()
    local level, es, b = room()
    ready(level, es, b)
    b.state, b.deadTimer = 'stuck', 0
    b.inv, b.hp = 0, 1
    b:damage(1, 'stomp')
    local seen = { [b.state] = true }
    steps(level, es, 12, function() seen[b.state] = true; return b.state == 'dead' or not b.alive end)
    local pa = player(level, 15)
    pa.x = b.x
    local hp0, lives0 = pa.hp, pa.lives
    steps(level, es, 0.5, nil, pa)
    check('muerte', seen.dying_hold and seen.dying_eject and seen.dying_boom and (b.state == 'dead' or not b.alive)
        and pa.hp == hp0 and pa.lives == lives0 and not pa.dying,
        ('explota=%s · expulsa=%s · final=%s · acabada=%s · ya no hace daño=%s'):format(tostring(seen.dying_hold), tostring(seen.dying_eject),
        tostring(seen.dying_boom), tostring(b.state == 'dead' or not b.alive), tostring(pa.hp == hp0 and not pa.dying)))
end

function cases.red()
    local level, es, b = room()
    ready(level, es, b)
    b.spike, b.mx, b.my = 0.5, 12, 34
    local _, _, c = room()
    local pack = b:netPackExtra()
    c:netApplyExtra(pack, pack, 1)
    check('red', math.abs(c.spike - 0.5) < 0.02 and c.mx == 12 and c.my == 34,
        ('pinchos %.2f, monstruo en %s,%s'):format(c.spike, tostring(c.mx), tostring(c.my)))
end

function love.load()
    local only = os.getenv('CASE')
    for _, n in ipairs({ 'picado', 'ventana', 'rompe', 'suelo', 'muerte', 'red' }) do
        if not only or only == n then
            local ok, err = xpcall(cases[n], debug.traceback)
            if not ok then check(n, false, 'error: ' .. tostring(err)) end
        end
    end
    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
