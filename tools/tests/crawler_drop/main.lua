-- tools/tests/crawler_drop — Crabbies trepadores (wallWalk) que caen del techo
-- (dropOnSight), como los súbditos del Mega Crabby. Sala cerrada pequeña, las
-- clases reales y las reglas de Interactions. Casos:
--   stomp   Crabby de pincho clavado tras caer: saltarle encima lo mata
--   tramp   Crabby trampolín cayendo encima del jugador: lo aplasta (-1 vida,
--           aplastado), no lo mata
--   repeat  tras levantarse vuelve a subir al techo y cae OTRA vez (varias)
--   SUMMON=1  el Crabby es un súbdito de reserva activado como lo hace el jefe
--   NOWALL=1  Crabby de techo normal (sin wallWalk), para comparar
--   TRACE=1   imprime los cambios de estado · SPEED=px/s (110 por defecto)
--
--   love tools/tests/crawler_drop
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

local W, H = 16, 9
local function room()
    local tiles = {}
    for r = 1, H do
        local row = {}
        for c = 1, W do row[c] = (r == 1 or r == H or c == 1 or c == W) and 1 or 0 end
        tiles[r] = row
    end
    return tiles
end

local function setup(kind)
    local data = { name = 'test', width = W, height = H, playerStart = { 8, H - 1 }, tiles = room(),
        entities = { { type = kind, col = 5, row = 2,
            props = { movement = 'walk', attach = 'ceiling', speed = tonumber(os.getenv('SPEED')) or 110, wallWalk = not os.getenv('NOWALL'),
                      dropOnSight = true, detectRange = 10, respawn = 0, points = 5 } } } }
    local level = Level.fromData(data)
    local e = Entities.create(level.entities[1])
    if os.getenv('SUMMON') then
        -- Como el jefe: de la reserva, reaparece en el suelo andando
        e:makeReserve('test')
        local h = e.home
        h.x, h.y, h.facing, h.flipped, h.state = 4 * TILE_PX, (H - 1) * TILE_PX - e.outerH / 2, 1, false, 'walk'
        h.vx = e.speed
        e:resetToHome()
        e.state, e.deadTimer = 'spawning', 0
    end
    local pa = PlayerAdventure:new(8 * TILE_PX, (H - 1) * TILE_PX - 60)
    pa.spawnX, pa.spawnY = pa.x, pa.y
    level.players, level.liveEntities = { pa }, { e }
    return level, e, pa
end

local function step(level, e, pa, dt)
    if os.getenv('TRACE') and e.state ~= e._tr then
        e._tr = e.state
        print(('    %-10s x=%4d y=%4d cn=(%s,%s) att=%s flip=%s'):format(e.state, e.x, e.y, tostring(e.cnx), tostring(e.cny),
            tostring(e.cattached), tostring(e.flipped)))
    end
    level.solidBodies = Entities.solidBodies({ e })
    pa:update(dt, level)
    e:update(dt, level)
    Interactions.run(pa, { e }, {})
end

local fails = 0
local function report(name, ok, msg)
    print(('%-7s %s  %s'):format(name, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end

local cases = {}

function cases.stomp()
    local level, e, pa = setup('crabby')
    pa.invT = 0
    local dt, t, placed = 1 / 60, 0, false
    while t < 90 do
        t = t + dt
        -- Debajo e intocable hasta que se clava (que no le mate el pincho)
        if not placed then pa.invT, pa.hp = 99, pa.hpMax end
        if e.state == 'drop_stuck' and e.deadTimer > 1.5 and not placed then
            placed = true
            pa.x, pa.y, pa.vy, pa.onGround, pa.invT = e.x, e.y - 160, 400, false, 0
        end
        step(level, e, pa, dt)
        if placed and (e.state == 'dead' or pa.dying) then break end
    end
    report('stomp', placed and e.state == 'dead' and not pa.dying,
        ('clavado=%s crabby=%s jugador %s'):format(tostring(placed), e.state, pa.dying and 'MUERTO' or 'vivo'))
end

function cases.tramp()
    local level, e, pa = setup('crabbytramp')
    local dt, t, fell, after = 1 / 60, 0, false, nil
    local hp0, minHp, squashed = pa.hp, pa.hp, 0
    while t < 30 do
        t = t + dt
        -- Intocable hasta que empieza a caer (que no le mate al andar hacia él)
        if e.state == 'drop_shake' or e.state == 'drop_fall' then
            if not fell then pa.invT = 0 end
            fell = true
        elseif not fell then
            pa.invT, pa.x = 99, pa.x + (e.x - pa.x) * 0.2     -- (se queda debajo)
        end
        step(level, e, pa, dt)
        minHp, squashed = math.min(minHp, pa.hp), math.max(squashed, pa.squashT or 0)
        if pa.dying then print(('    muere: crabby=%s dt=%.2f img=%s cn=(%s,%s) att=%s flip=%s dx=%d dy=%d squashT=%.2f invT=%.2f'):format(e.state, e.deadTimer, tostring(e.getImgName and e:getImgName()), tostring(e.cnx), tostring(e.cny), tostring(e.cattached), tostring(e.flipped), e.x - pa.x, e.y - pa.y, pa.squashT or 0, pa.invT or 0)); break end
        if fell and not after and e.state ~= 'drop_fall' and e.state ~= 'drop_shake' then after = t end
        if after and t > after + 6 then break end         -- (y un rato después: no lo remata)
    end
    report('tramp', fell and not pa.dying and minHp == hp0 - 1 and squashed > 0,
        ('cayó=%s jugador %s vida %d→%d aplastado=%.2f'):format(tostring(fell), pa.dying and 'MUERTO' or 'vivo',
            hp0, minHp, squashed))
end

cases['repeat'] = function()
    if os.getenv('NOWALL') then print('repeat  (el Crabby de techo normal se queda en el suelo: no aplica)'); return end
    for _, kind in ipairs({ 'crabby', 'crabbytramp' }) do
        local level, e, pa = setup(kind)
        local dt, t, drops, prev = 1 / 60, 0, 0, nil
        while t < 90 do
            t = t + dt
            pa.invT = 99                           -- (que no muera: solo contamos caídas)
            if e.state == 'drop_fall' and prev ~= 'drop_fall' then drops = drops + 1 end
            prev = e.state
            step(level, e, pa, dt)
        end
        report('repeat', drops >= 2, ('%s: %d caídas en 90 s'):format(kind, drops))
    end
end

function love.load()
    for _, name in ipairs({ 'stomp', 'tramp', 'repeat' }) do cases[name]() end
    print(fails == 0 and 'TODO OK' or (fails .. ' FALLOS'))
    love.event.quit(fails == 0 and 0 or 1)
end
