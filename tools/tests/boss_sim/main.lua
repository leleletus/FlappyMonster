-- tools/tests/boss_sim — simulación en solitario (sin humano) de una pelea de
-- jefe con las clases reales del juego. Un jugador quieto dentro de la zona;
-- se registran los estados del jefe y el daño al jugador. Cuando el jefe
-- queda vulnerable ('stuck') el arnés le golpea: pisotón y ground pound
-- alternos, dos veces seguidas (solo debe contar la primera).
--
--   LEVEL=assets/levels/jefe_cangrejo.json love tools/tests/boss_sim
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
require 'settings'
local sounds = {}
Sound = setmetatable({ play = function(n) sounds[n] = (sounds[n] or 0) + 1 end },
                     { __index = function() return function() end end })
local P = require 'src/network/Protocol'
local stub = P.newInputStub()
Input = stub
local json = require 'libs/json'
local Level = require 'src/world/Level'
local Entities = require 'src/world/Entities'
local BossZones = require 'src/world/BossZones'
local PlayerAdventure = require 'src/entities/PlayerAdventure'

function love.load()
    math.randomseed(3)
    local data = json.decode(love.filesystem.read(os.getenv('LEVEL') or 'assets/levels/jefe_cangrejo.json'))
    local level = Level.fromData(data)
    local ents = {}
    for _, pl in ipairs(level.entities) do ents[#ents + 1] = Entities.create(pl) end
    level.liveEntities = ents
    local ctrl = BossZones.newController(level, ents)
    local boss
    for _, e in ipairs(ents) do if e.def.boss then boss = e end end
    local z = boss.zone
    if os.getenv('HP') then boss.props.hp, boss.props.hpPerPlayer = tonumber(os.getenv('HP')), 0 end
    local pa = PlayerAdventure:new(z.x0 + 3 * TILE_PX, z.y1 - 60)
    pa.spawnX, pa.spawnY = pa.x, pa.y
    level.players = { pa }
    local dt, t = 1 / 60, 0
    local lastState, hits, deaths, hurts = nil, {}, 0, 0
    local attack, attacksDone = nil, 0
    local lastHp = pa.hp
    -- Registro extra: bloques de jefe, súbditos y eventos del jefe (si los tiene)
    local walls, wallSt, lastMinions = {}, {}, -1
    for _, e in ipairs(ents) do if e.def.name == 'bosswall' then walls[#walls + 1] = e end end
    if boss.def.class.onEvent ~= nil or boss.def.class.onEvent == nil then
        boss.def.class.onEvent = function(name) print(('%6.1fs     evento: %s'):format(t, name)) end
    end
    while t < (tonumber(os.getenv('SECS')) or 240) do
        t = t + dt
        pa:update(dt, level)
        level.solidBodies = Entities.solidBodies(ents)
        ctrl:update(dt)
        for _, e in ipairs(ents) do if e.alive then e:update(dt, level) end end
        Entities.interactions.run(pa, ents, {})
        -- daño al jugador
        if pa.hp < lastHp and not pa.dying then hurts = hurts + 1; print(('%6.1fs   jugador: -1 vida (%d)'):format(t, pa.hp)) end
        lastHp = pa.hp
        if pa.dying and not pa._counted then
            pa._counted = true; deaths = deaths + 1
            print(('%6.1fs   jugador MUERE (jefe en %s)'):format(t, boss.state))
        end
        if not pa.alive or (pa.dying and pa.deathPhase == 'fall') then
            pa:respawn(); pa._counted = false; pa.hp = pa.hpMax; lastHp = pa.hp
        end
        -- continuidad del dibujo al trepar (DEBUG_POSE=1)
        if os.getenv('DEBUG_POSE') and boss.crawl and boss.cattached then
            local Crawler = require 'src/world/entities/Crawler'
            local fx, fy = Crawler.pose(boss)
            if boss._pfx then
                local j = math.sqrt((fx - boss._pfx) ^ 2 + (fy - boss._pfy) ^ 2)
                if j > 6 then print(('  paso de %.1f px (%s, giro=%s)'):format(j, boss.state, tostring(Crawler.turning(boss)))) end
                boss._maxj = math.max(boss._maxj or 0, j)
            end
            boss._pfx, boss._pfy = fx, fy
        elseif boss._pfx then boss._pfx = nil end
        for i, w in ipairs(walls) do
            if w.state ~= wallSt[i] then wallSt[i] = w.state; print(('%6.1fs   bloque de jefe %d: %s'):format(t, i, w.state)) end
        end
        local nm = 0
        for _, e in ipairs(ents) do if e.summonOf and e.alive then nm = nm + 1 end end
        if nm ~= lastMinions then lastMinions = nm; print(('%6.1fs   súbditos activos: %d'):format(t, nm)) end
        if os.getenv('DEBUG_POUNCE') and boss.state == 'pounce' then
            print(('      salto t=%.2f x=%.0f y=%.0f vx=%.0f vy=%.0f suelo=%s'):format(boss.deadTimer, boss.x, boss.y, boss.vx, boss.vy, tostring(boss.onGround)))
        end
        -- cambios de estado del jefe
        if boss.state ~= lastState then
            print(('%6.1fs jefe: %-12s  hp %s/%s  x=%d y=%d'):format(t, boss.state, boss.hp, boss.hpMax, boss.x, boss.y))
            lastState = boss.state
            if boss.state == 'stuck' then attack = { t0 = t, n = 0, kind = (attacksDone % 2 == 0) and 'stomp' or 'pound' } end
        end
        -- esquivar la caída: al ver la marca (estado 'aim') se aparta 5 casillas
        if boss.state == 'aim' and not pa.dying and math.abs(pa.x - boss.x) < 3 * TILE_PX then
            local dir = (boss.x - z.x0 > z.x1 - boss.x) and -1 or 1
            pa.x, pa.vx = boss.x + dir * 5 * TILE_PX, 0
        end
        -- golpear al jefe clavado: dos intentos (0.3 s y 1.2 s después)
        if attack and boss.state == 'stuck' or (attack and attack.n == 1 and t - attack.t0 < 1.4) then
            local due = attack.n == 0 and 0.3 or 1.2
            if t - attack.t0 >= due and attack.n < 2 then
                local ob = boss:getOuterBounds()
                local hp0 = boss.hp
                local ph = pa:getOuterBounds().h
                pa.x, pa.y, pa.vx, pa.vy = boss.x, ob.y - ph / 2 + 4, 0, 400
                pa.onGround = false
                pa.gpPhase = (attack.kind == 'pound') and 'fall' or nil
                pa.hurtT = 0
                Entities.interactions.run(pa, ents, {})
                print(('%6.1fs     %s #%d al jefe (%s): hp %d -> %d'):format(t, attack.kind, attack.n + 1, boss.state, hp0, boss.hp))
                attack.n = attack.n + 1
                if attack.n == 2 then attacksDone = attacksDone + 1; attack = nil end
            end
        end
        if not boss.alive then print(('%6.1fs JEFE DERROTADO (zona: %s)'):format(t, z.state)); break end
    end
    -- un paso más para que la zona se entere
    ctrl:update(dt)
    if boss._maxj then print(('Paso máximo del dibujo trepando: %.1f px (a 60 pasos/s)'):format(boss._maxj)) end
    print(('Resumen: jugador -1 vida %d veces, muertes %d; zona %s'):format(hurts, deaths, z.state))
    local ks = {}
    for k, v in pairs(sounds) do ks[#ks + 1] = k .. '=' .. v end
    table.sort(ks)
    print('Sonidos: ' .. table.concat(ks, ' '))
    love.event.quit()
end
