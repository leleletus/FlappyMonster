-- tools/tests/boss_sim — simulación en solitario (sin humano) de una pelea de
-- jefe con las clases reales del juego. Un jugador quieto dentro de la zona;
-- se registran los estados del jefe y el daño al jugador. Cuando el jefe
-- queda vulnerable ('stuck') el arnés le golpea: pisotón y ground pound
-- alternos, dos veces seguidas (solo debe contar la primera).
--
-- Espejo (LEVEL=assets/levels/ruta_del_espejo.json): se le golpea aturdido
-- tras caer ('recover') y se comprueban sus ataques de arena: los dos tipos
-- (espejo flotante y plataforma), su ground pound quita 2, el salto cae donde
-- marcó y encadena ataques en las fases de poca vida.
--
--   LEVEL=assets/levels/guarida_cangrejo_rey.json love tools/tests/boss_sim
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
    local data = json.decode(love.filesystem.read(os.getenv('LEVEL') or 'assets/levels/guarida_cangrejo_rey.json'))
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
    local mirror = boss.def.name == 'mirror'
    local VULN = { stuck = true, recover = mirror }
    local seen, gpDmg, chain, maxChain, leapOff = {}, {}, 0, 0, {}
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
        if pa.hp < lastHp then
            if not pa.dying then hurts = hurts + 1 end
            print(('%6.1fs   jugador: -%d vida (%d) jefe=%s'):format(t, lastHp - pa.hp, pa.hp, boss.state))
            if mirror and (boss.state == 'dive' or boss.state == 'recover') and boss.gpHit ~= nil then
                gpDmg[#gpDmg + 1] = lastHp - pa.hp
            end
        end
        lastHp = pa.hp
        if pa.dying and not pa._counted then
            pa._counted = true; deaths = deaths + 1
            print(('%6.1fs   jugador MUERE (jefe en %s)'):format(t, boss.state))
        end
        if not pa.alive or (pa.dying and pa.deathPhase == 'fall') then
            pa:respawn(); pa._counted = false; pa.hp = pa.hpMax; lastHp = pa.hp
        end
        -- seguimiento al apuntar (DEBUG_AIM=1): jefe/marca vs jugador
        if os.getenv('DEBUG_AIM') and (boss.state == 'aim' or boss.state == 'wallaim') then
            boss._aimLog = (boss._aimLog or 0) + dt
            if boss._aimLog >= 0.2 then
                boss._aimLog = 0
                print(('      %s t=%.1f  marca x=%.0f  jugador x=%.0f'):format(boss.state, boss.deadTimer,
                    boss.state == 'aim' and boss.x or boss.markerX, pa.x))
            end
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
            seen[boss.state] = true
            if mirror then
                if boss.state == 'warp_out' then chain = chain + 1; maxChain = math.max(maxChain, chain) end
                if boss.state == 'fight' then chain = 0 end
                if boss.state == 'recover' and boss.leapTX and lastState == 'dive' and boss.prevAttack == 'perch'
                   and not boss.gpHit then                     -- (si le cayó encima a alguien, rebota)
                    leapOff[#leapOff + 1] = math.abs(boss.x - boss.leapTX)
                end
                if boss.state == 'warp_out' then boss.prevAttack = boss.nextAttack end
            end
            lastState = boss.state
            -- (Espejo: solo al final de una ristra de ataques, para verla entera)
            if VULN[boss.state] and not (mirror and (boss.chainLeft or 1) > 1) then attack = { t0 = t, n = 0, kind = (attacksDone % 2 == 0) and 'stomp' or 'pound' } end
        end
        -- esquivar la caída: al ver la marca (estado 'aim') se aparta 5 casillas
        if boss.state == 'aim' and not pa.dying and math.abs(pa.x - boss.x) < 3 * TILE_PX then
            local dir = (boss.x - z.x0 > z.x1 - boss.x) and -1 or 1
            pa.x, pa.vx = boss.x + dir * 5 * TILE_PX, 0
        end
        -- golpear al jefe clavado: dos intentos (0.3 s y 1.2 s después)
        if attack and VULN[boss.state] or (attack and attack.n == 1 and t - attack.t0 < 1.4) then
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
    local fails = 0
    if mirror then
        local function check(name, ok, msg)
            print(('%-10s %s  %s'):format(name, ok and 'OK   ' or 'FALLA', msg))
            if not ok then fails = fails + 1 end
        end
        check('ataques', seen.portal and seen.perch and seen.leap and seen.dive and seen.recover,
            'espejo=' .. tostring(seen.portal) .. ' plataforma=' .. tostring(seen.perch) .. ' salto=' .. tostring(seen.leap))
        local ok2 = true
        for _, d in ipairs(gpDmg) do if d ~= 2 then ok2 = false end end
        check('gp 2', ok2, ('golpes de su ground pound: %s'):format(#gpDmg > 0 and table.concat(gpDmg, ',') or 'ninguno'))
        local worst = 0
        for _, d in ipairs(leapOff) do worst = math.max(worst, d) end
        check('salto', #leapOff > 0 and worst <= 24, ('%d saltos; el que más lejos de su marca: %.0f px'):format(#leapOff, worst))
        check('fases', maxChain >= 2 or not boss.alive and maxChain >= 2, ('ataques seguidos (máx.): %d'):format(maxChain))
    end
    local ks = {}
    for k, v in pairs(sounds) do ks[#ks + 1] = k .. '=' .. v end
    table.sort(ks)
    print('Sonidos: ' .. table.concat(ks, ' '))
    love.event.quit(fails == 0 and 0 or 1)
end
