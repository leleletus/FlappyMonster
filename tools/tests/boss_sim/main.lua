-- tools/tests/boss_sim — simulación en solitario (sin humano) de una pelea de
-- jefe con las clases reales del juego. Un jugador quieto dentro de la zona;
-- se registran los estados del jefe y el daño al jugador. Cuando el jefe
-- queda vulnerable ('stuck') el arnés le golpea: pisotón y ground pound
-- alternos, dos veces seguidas (solo debe contar la primera).
--
-- Espejo (LEVEL=assets/levels/ruta_del_espejo.json): se le golpea aturdido
-- tras caer ('recover') y se comprueban sus ataques de arena: los dos tipos
-- (espejo flotante y plataforma), su ground pound quita 2, el salto cae donde
-- marcó y encadena ataques en las fases de poca vida. Con cristal roto de
-- jefe (bossglass) en la arena: el evento salta, tocarlo lanza hacia arriba
-- con 2 saltos y quita como mucho 1, el Espejo no copia en el suelo mientras
-- dura (si lo toca, recibe 1 y vuelve a una plataforma) y luego vuelve a copiar.
--
-- Gran Bola de Nieve (LEVEL=tools/levelgen/arenas/jefe_nieve.json): se le golpea
-- MAREADA o CONGELADA; el arnés cambia un Activador (dispara su Congelador) cuando el
-- jefe está a tiro de él y patea las bombas encendidas hacia el jefe. Comprueba: todos
-- sus ataques, mareada al chocar con una compuerta, congelada por el chorro (ground pound
-- = 3), bomba devuelta = 1 + mareada, las 3 fases, nieve prensada bajo los Activadores
-- en la fase 3, hielo fino vuelto a congelar (si la arena tiene), muerte en orden y
-- zona superada.
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
    math.randomseed(tonumber(os.getenv('SEED')) or 3)
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
    local snow = boss.def.name == 'snowboss'
    if snow then VULN = { dizzy = true, frozen = true } end
    local sn = { phases = {}, frozenHits = {}, blastHits = 0, crashDizzy = 0, kicks = 0, toggles = 0, lakeBroken = 0,
                 refrozen = 0, packed = 0, deathOrder = {} }
    if snow then
        local orig = boss.onBlastHit
        boss.onBlastHit = function(self, ...)
            local h0 = self.hp
            orig(self, ...)
            if self.hp < h0 then sn.blastHits = sn.blastHits + 1; print(('%6.1fs     ¡bomba devuelta! hp %d -> %d'):format(t, h0, self.hp)) end
        end
    end
    local seen, gpDmg, chain, maxChain, leapOff = {}, {}, 0, 0, {}
    local laughWait, laughs, laughLate = {}, 0, 0
    lastAliveT = nil
    lastHitT = nil
    local glass
    for _, e in ipairs(ents) do if e.def.name == 'bossglass' then glass = e end end
    local gl = { events = 0, launches = 0, badJumps = 0, maxDmg = 0, fightInDanger = 0, bossHits = 0, backAfter = nil,
                 lastSt = 'idle', endT = nil }
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
        -- Cristal roto
        if glass then
            if glass.state ~= gl.lastSt then
                print(('%6.1fs   cristal: %s'):format(t, glass.state))
                if glass.state == 'active' then gl.events = gl.events + 1 end
                if glass.state == 'idle' then gl.endT = t end
                if glass.state == 'warn' and not gl.backAfter then gl.endT = nil end   -- (otro evento seguido)
                gl.lastSt = glass.state
            end
            -- Prueba: con el cristal recién activo se deja caer al Espejo al suelo
            -- (encima de los cristales): debe recibir 1 y volver a una plataforma
            if glass.state == 'active' and glass.deadTimer > 0.6 and not gl.dropped and boss.state == 'perch' then
                gl.dropped = { t = t, hp = boss.hp }
                local b = boss.body
                b.x, b.y, b.vy, b.onGround = (z.x0 + z.x1) / 2, z.y1 - 100, 200, false
                boss.state, boss.deadTimer, boss.inv = 'fight', 0, 0
                boss:syncFromBody()
            end
            if gl.dropped and not gl.escaped and t - gl.dropped.t < 3 and boss:platformUnder(level) then
                gl.escaped = { dt = t - gl.dropped.t, dmg = gl.dropped.hp - boss.hp }
            end
            if gl.endT and boss.state == 'fight' and not gl.backAfter then gl.backAfter = t - gl.endT end
            if glass:isDanger() and glass.deadTimer > 0.5 and boss.state == 'fight' and boss.body.onGround then
                gl.fightInDanger = gl.fightInDanger + 1
            end
            if (pa.jumpsLeft or 0) == 2 and pa.vy < -700 and not gl.inLaunch then
                gl.inLaunch = true; gl.launches = gl.launches + 1
                gl.maxDmg = math.max(gl.maxDmg, lastHp - pa.hp)
            elseif pa.vy >= 0 then gl.inLaunch = false end
        end
        -- daño al jugador
        if pa.hp < lastHp then
            if not pa.dying then hurts = hurts + 1 end
            print(('%6.1fs   jugador: -%d vida (%d) jefe=%s'):format(t, lastHp - pa.hp, pa.hp, boss.state))
            local byGlass = glass and glass:isActiveGlass() and pa.vy < -700     -- (lo lanzó el cristal)
            if mirror and (boss.state == 'dive' or boss.state == 'recover') and boss.gpHit ~= nil and not byGlass then
                gpDmg[#gpDmg + 1] = lastHp - pa.hp
            end
        end
        lastHp = pa.hp
        if pa.dying and not pa._counted then
            pa._counted = true; deaths = deaths + 1
            if mirror and boss.alive and not boss:isDying() and z.state == 'fight' then
                laughWait[#laughWait + 1] = t
                if os.getenv('DEBUG_LAUGH') then print(('      (muerte con el jefe en %s, pendiente=%s)'):format(boss.state, tostring(boss.laughPending))) end
            end
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
            if boss.state == 'dying_hold' then lastAliveT = t end
            if boss.state == 'laugh' and #laughWait > 0 then
                laughs = laughs + 1
                if t - table.remove(laughWait, 1) > 3 then laughLate = laughLate + 1 end
                laughWait = {}                  -- (una risa vale por las muertes seguidas)
            end
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
            -- (Espejo: como mucho un golpe cada 10 s, para ver sus fases y el evento)
            if VULN[boss.state] and not (mirror and ((boss.chainLeft or 1) > 1 or t - (lastHitT or -99) < 10)) then
                if mirror then lastHitT = t end
                attack = { t0 = t, n = 0, kind = (attacksDone % 2 == 0) and 'stomp' or 'pound' } end
        end
        -- Gran Bola de Nieve: Activadores (Congeladores), bombas devueltas, registro
        if snow and z.state == 'fight' then
            sn.phases[boss.phase] = true
            if boss.state == 'dizzy' and sn.prev ~= 'dizzy' then sn.crashDizzy = sn.crashDizzy + 1 end
            sn.prev = boss.state
            -- Activador del lado del jefe si está a tiro de su Congelador (cada 6 s como mucho)
            -- (el lago: se rompen 2 celdas al empezar, como si las rompiera un jugador; al cambiar
            -- de fase el jefe debe volver a congelarlas)
            if not sn.broke and boss.lake and #boss.lake >= 2 then
                sn.broke = true
                for i = 1, 2 do level:crackIce(boss.lake[i][1], boss.lake[i][2], 4, 'pound') end
            end
            if (boss.state == 'idle' or boss.state == 'recover' or boss.state == 'shoot') and t - (sn.lastToggle or -99) > 14 then
                for _, e in ipairs(ents) do
                    if e.def.name == 'cryo' and e.state == 'idle' and math.abs(e.x - boss.x) < 6 * TILE_PX then
                        local cells = level:linkedCells(e.props.id or 1)
                        if cells[1] then
                            level:hitTile(cells[1][1], cells[1][2], 'head')
                            sn.lastToggle, sn.toggles = t, sn.toggles + 1
                            print(('%6.1fs     Activador (%d,%d) → %s'):format(t, cells[1][1], cells[1][2], level:getDef(cells[1][1], cells[1][2]).name))
                            break
                        end
                    end
                end
            end
            -- bombas encendidas: patada hacia el jefe
            for _, e in ipairs(ents) do
                if e.summonOf and e.alive and e.state == 'lit' and e.onGround and not e._kicked then
                    e._kicked = true
                    e.x = boss.x + ((e.x < boss.x) and -1 or 1) * (boss.outerW / 2 + 40)
                    e:knockback((e.x < boss.x) and 1 or -1)
                    sn.kicks = sn.kicks + 1
                end
            end
            local np = 0
            for r = 1, level.tileH do for c = 1, level.tileW do
                if level:getDef(c, r).name == 'packed_snow' then np = np + 1 end
            end end
            sn.packed = math.max(sn.packed, np)
            for _, c in ipairs(boss.lake or {}) do
                if not level:getDef(c[1], c[2]).thinIce then c.broken = true
                elseif c.broken then c.broken = nil; sn.refrozen = sn.refrozen + 1 end
            end
        end
        if snow then
            if boss.state ~= sn.prevD and boss.state:match('^dying_') then sn.deathOrder[#sn.deathOrder + 1] = boss.state end
            sn.prevD = boss.state
        end
        -- esquivar la caída: al ver la marca (estado 'aim') se aparta 5 casillas
        if boss.state == 'aim' and not pa.dying and math.abs(pa.x - boss.x) < 3 * TILE_PX then
            local dir = (boss.x - z.x0 > z.x1 - boss.x) and -1 or 1
            pa.x, pa.vx = boss.x + dir * 5 * TILE_PX, 0
        end
        -- golpear al jefe clavado: dos intentos (0.3 s y 1.2 s después)
        if attack and VULN[boss.state] or (attack and attack.n == 1 and t - attack.t0 < 1.4) then
            local due = attack.n == 0 and 0.3 or 1.2
            if mirror then due = attack.n == 0 and 0.05 or 0.2 end     -- (su pausa al aterrizar es corta)
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
                if snow and lastState == 'frozen' and attack.kind == 'pound' and boss.hp > 0 then sn.frozenHits[#sn.frozenHits + 1] = hp0 - boss.hp end
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
        if glass then
            check('cristal', gl.events >= 1 and gl.launches >= 1 and gl.maxDmg <= 1,
                ('eventos %d; lanzamientos del jugador %d (daño máx. por toque %d)'):format(gl.events, gl.launches, gl.maxDmg))
            check('arriba', gl.fightInDanger == 0,
                ('pasos copiando en el suelo con el cristal: %d'):format(gl.fightInDanger))
            check('escapa', gl.escaped ~= nil and gl.escaped.dmg == 1,
                gl.escaped and ('cayó al cristal: -%d y en una plataforma a los %.1f s'):format(gl.escaped.dmg, gl.escaped.dt)
                or ('no volvió a una plataforma (%s)'):format(gl.dropped and 'dejado caer' or 'no se probó'))
            check('vuelve', gl.backAfter ~= nil and gl.backAfter < 8,
                ('vuelve a copiar %.1f s después del evento'):format(gl.backAfter or -1))
        end
        -- (una muerte justo antes de vencerlo no tiene risa: ya está muriendo)
        local dieT = boss.alive and math.huge or (lastAliveT or math.huge)
        for i = #laughWait, 1, -1 do if laughWait[i] > dieT - 3 then table.remove(laughWait, i) end end
        check('risa', deaths > 0 and laughs >= 1 and #laughWait == 0 and laughLate == 0,
            ('muertes en la pelea con risa: %d risas; sin risa %d; tarde (>3 s) %d'):format(laughs, #laughWait, laughLate))
        check('fases', maxChain >= 2 or not boss.alive and maxChain >= 2, ('ataques seguidos (máx.): %d'):format(maxChain))
    end
    if snow then
        local function check(name, ok, msg)
            print(('%-10s %s  %s'):format(name, ok and 'OK   ' or 'FALLA', msg))
            if not ok then fails = fails + 1 end
        end
        local need = { 'hop', 'shoot', 'windup', 'roll', 'dizzy', 'frozen', 'slam_up', 'slam_land', 'phase_up' }
        local miss = {}
        for _, n in ipairs(need) do if not seen[n] then miss[#miss + 1] = n end end
        check('ataques', #miss == 0, #miss == 0 and 'todos vistos' or ('faltan: ' .. table.concat(miss, ',')))
        check('mareada', sn.crashDizzy > 0, ('mareada %d veces (choque o bomba)'):format(sn.crashDizzy))
        local f3 = #sn.frozenHits > 0
        for _, d in ipairs(sn.frozenHits) do if d ~= 3 then f3 = false end end
        check('congelada', f3, ('ground pound congelada: %s (Activadores cambiados %d)'):format(table.concat(sn.frozenHits, ','), sn.toggles))
        check('bomba', sn.blastHits > 0, ('bombas pateadas %d, golpes de bomba al jefe %d'):format(sn.kicks, sn.blastHits))
        check('fases', sn.phases[1] and sn.phases[2] and sn.phases[3], ('fases vistas: %s%s%s'):format(
            sn.phases[1] and '1' or '', sn.phases[2] and '2' or '', sn.phases[3] and '3' or ''))
        check('enterrado', sn.packed > 0, ('nieve prensada en la arena: %d'):format(sn.packed))
        if #(boss.lake or {}) > 0 then        -- (solo si la arena tiene hielo fino)
            check('lago', sn.refrozen > 0, ('celdas de hielo fino vueltas a congelar: %d'):format(sn.refrozen))
        end
        check('muerte', not boss.alive and table.concat(sn.deathOrder, ',') == 'dying_crack,dying_burst,dying_flee' and z.state == 'cleared',
            ('vivo=%s orden %s, zona %s'):format(tostring(boss.alive), table.concat(sn.deathOrder, ','), z.state))
    end
    local ks = {}
    for k, v in pairs(sounds) do ks[#ks + 1] = k .. '=' .. v end
    table.sort(ks)
    print('Sonidos: ' .. table.concat(ks, ' '))
    love.event.quit(fails == 0 and 0 or 1)
end
