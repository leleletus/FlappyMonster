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
-- MAREADA, EMPAPADA o CONGELADA. El jugador juega como se espera: en la fase 2 se pone
-- bajo un carámbano para que la bola salte allí y se aparta al ver la marca; en la fase 3
-- se pone sobre una bolsa de hielo fino para que el gran golpe la rompa, se aparta, y con
-- la bola empapada golpea el Activador de esa bolsa (su Congelador la congela). Comprueba:
-- todos sus ataques, mareada al chocar y por un carámbano, empapada, congelada (ground
-- pound = 3), las 3 fases (escalas 10 → 8 → 6), los Activadores y Congeladores solo en la
-- fase 3, hielo fino que se rehace, muerte en orden y zona superada.
--
-- Rey Gummy (LEVEL=tools/levelgen/arenas/jefe_gummy.json): se le golpea MAREADO tras el
-- panzazo; el jugador se aparta de la marca cuando ya salta y salta las olas de gelatina; con
-- los trozos, ground pound a cada uno. Comprueba: todos sus estados (fanfarria, guardia, se
-- divide, trozos, revienta), las 3 fases, que la guardia entra, que cae en su marca (≤ 24 px),
-- que ninguna ola le da al jugador (las salta), y muerte + zona superada.
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
    if snow then VULN = { dizzy = true, frozen = true, soaked = true } end
    local king = boss.def.name == 'megagummy'
    if king then VULN = { dazed = true } end
    local kg = { phases = {}, maxGuards = 0, flopOff = {}, waveHits = 0, partHits = 0, lastPartT = -9 }
    local sn = { phases = {}, scales = {}, frozenHits = {}, crashDizzy = 0, bonks = 0, toggles = 0, refrozen = 0,
                 deathOrder = {}, early = {}, shown = {} }
    if snow then
        local orig = boss.bonk
        boss.bonk = function(self, ...)
            sn.bonks = sn.bonks + 1
            print(('%6.1fs     ¡carámbano en la bola! (%s)'):format(t, self.state))
            return orig(self, ...)
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
            if king then
                for _, w in ipairs(boss.waves or {}) do
                    local b = boss:waveBox(w)
                    local o = pa:getOuterBounds()
                    if o.x < b.x + b.w + 30 and o.x + o.w > b.x - 30 and o.y + o.h > b.y - 10 then kg.waveHits = kg.waveHits + 1 end
                end
            end
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
            local waitFreeze = false
            if snow and boss.state == 'soaked' and boss.phase == 3 and (boss.frostT or 0) <= 0 then
                for _, e in ipairs(ents) do
                    if e.def.name == 'cryo' and e:isSolidBody() and math.abs(e.x - boss.x) < 2 * TILE_PX then waitFreeze = true end
                end
            end
            if VULN[boss.state] and not waitFreeze and not (mirror and ((boss.chainLeft or 1) > 1 or t - (lastHitT or -99) < 10)) then
                if mirror then lastHitT = t end
                attack = { t0 = t, n = 0, kind = (attacksDone % 2 == 0) and 'stomp' or 'pound' } end
        end
        -- Gran Bola de Nieve: el jugador juega como se espera (ver la cabecera) y se registra
        if snow and z.state == 'fight' then
            sn.phases[boss.phase] = true
            sn.scales[boss.sc] = true
            if boss.state == 'dizzy' and sn.prev ~= 'dizzy' and (sn.prev == 'roll' or sn.prev == 'slide') then
                sn.crashDizzy = sn.crashDizzy + 1
            end
            sn.prev = boss.state
            local T = TILE_PX
            local floorY = z.y1
            local function standAt(x)
                if pa.dying then return end
                pa.x, pa.y, pa.vx, pa.vy = x, floorY - 50, 0, 0
            end
            -- Activadores / Congeladores con fase: no deben estar antes de su fase
            for _, e in ipairs(ents) do
                if e.def.name == 'cryo' and (e.props.phase or 0) > 0 then
                    if boss.phase < e.props.phase and e:isSolidBody() then sn.early[#sn.early + 1] = 'congelador' end
                    if e:isSolidBody() then sn.shown.cryo = true end
                end
            end
            for _, l in ipairs(level.links or {}) do
                local n = level:getDef(l.col, l.row).name
                local isSw = n == 'switch_on' or n == 'switch_off'
                if isSw and boss.phase < 3 and (z.phase or 1) < 3 then sn.early[#sn.early + 1] = 'activador' end
                if isSw then sn.shown.switch = true end
            end
            local idle = boss.state == 'idle' or boss.state == 'rest' or boss.state == 'recover'
            -- fase 2: en la superficie de debajo de un carámbano listo (una plataforma: para que
            -- salte allí); al ver la marca, se aparta
            if boss.phase == 2 and idle then
                for _, c in ipairs(boss.icicles or {}) do
                    if c.st == boss.IC.ready and math.abs(c.x - boss.x) > 3 * T then
                        local gy = boss:groundBelow(c.x, c.top + 70)
                        if not pa.dying then pa.x, pa.y, pa.vx, pa.vy = c.x, gy - 50, 0, 0 end
                        break
                    end
                end
            end
            -- fase 3: sobre el centro de una bolsa de hielo fino (el gran golpe la rompe)
            if boss.phase == 3 and idle and boss.lake and boss.lake[1] then
                local best
                for _, cr in ipairs(boss.lake) do
                    local x = (cr[1] - 0.5) * T
                    if level:getDef(cr[1], cr[2]).thinIce and level:getDef(cr[1] - 1, cr[2]).thinIce
                       and level:getDef(cr[1] + 1, cr[2]).thinIce and (not best or math.abs(x - boss.x) > math.abs(best - boss.x)) then
                        best = x
                    end
                end
                if best then standAt(best) end
            end
            -- se aparta del salto / del gran golpe (a 5 casillas, hacia donde haya sitio)
            if (boss.state == 'leap_wind' and math.abs(pa.x - boss.landX) < 3 * T)
               or ((boss.state == 'slam_up' or boss.state == 'slam_hold') and math.abs(pa.x - boss.x) < 5 * T) then
                local cx = (boss.state == 'leap_wind') and boss.landX or boss.x
                local dir = (cx - z.x0 > z.x1 - cx) and -1 or 1
                standAt(math.max(z.x0 + T, math.min(z.x1 - T, cx + dir * 6 * T)))
            end
            -- empapada en la fase 3: golpea el Activador de la bolsa (su Congelador la congela)
            if boss.state == 'soaked' and boss.phase == 3 and boss.deadTimer > 0.2 and t - (sn.lastToggle or -99) > 3 then
                for _, e in ipairs(ents) do
                    if e.def.name == 'cryo' and e:isSolidBody() and e.state == 'idle' and math.abs(e.x - boss.x) < 2 * T then
                        local cells = level:linkedCells(e.props.id or 1)
                        if cells[1] and level:hitTile(cells[1][1], cells[1][2], 'pound') == 'toggle' then
                            sn.lastToggle, sn.toggles = t, sn.toggles + 1
                            print(('%6.1fs     Activador (%d,%d) → %s'):format(t, cells[1][1], cells[1][2], level:getDef(cells[1][1], cells[1][2]).name))
                        end
                        break
                    end
                end
            end
            for _, c in ipairs(boss.lake or {}) do
                if not level:getDef(c[1], c[2]).thinIce then c.broken = true
                elseif c.broken then c.broken = nil; sn.refrozen = sn.refrozen + 1 end
            end
        end
        -- Rey Gummy: el jugador juega como se espera (ver la cabecera) y se registra
        if king and z.state == 'fight' then
            local T = TILE_PX
            kg.phases[boss.phase or 1] = true
            local nm = 0
            for _, e in ipairs(ents) do if e.summonOf and e.alive then nm = nm + 1 end end
            kg.maxGuards = math.max(kg.maxGuards, nm)
            if (boss.state == 'dazed' or boss.state == 'flop_land') and kg.prev == 'flop_air' then
                kg.flopOff[#kg.flopOff + 1] = math.abs(boss.x - boss.landX)
            end
            kg.prev = boss.state
            -- se aparta de la marca cuando ya ha saltado (la marca está fija)
            if boss.state == 'flop_air' and not pa.dying and math.abs(pa.x - boss.landX) < boss.outerW / 2 + 60 then
                local dir = (boss.landX - z.x0 > z.x1 - boss.landX) and -1 or 1
                pa.x, pa.vx = math.max(z.x0 + T, math.min(z.x1 - T, boss.landX + dir * 6 * T)), 0
            end
            -- salta las olas que se le acercan
            for _, w in ipairs(boss.waves or {}) do
                local d = (pa.x - w.x) * w.dir
                if d > 0 and d < 90 and pa.onGround and not pa.dying then
                    pa.vy, pa.onGround = -math.abs(ADV_JUMP_VEL), false
                end
            end
            -- trozos: ground pound a uno que esté en el suelo cada 0.7 s
            if boss.state == 'parts' and t - kg.lastPartT > 0.7 and not pa.dying then
                for _, pt in ipairs(boss.parts) do
                    if pt.st == 1 and pt.inv <= 0 then
                        kg.lastPartT = t
                        local ob = pt:box()
                        local ph = pa:getOuterBounds().h
                        pa.x, pa.y, pa.vx, pa.vy = pt.x, ob.y - ph / 2 + 4, 0, 400
                        pa.onGround, pa.gpPhase, pa.hurtT = false, 'fall', 0
                        local hp0 = pt.hp
                        Entities.interactions.run(pa, ents, {})
                        if pt.hp < hp0 then kg.partHits = kg.partHits + 1 end
                        print(('%6.1fs     ground pound a un trozo: %d -> %d (barra %d)'):format(t, hp0, pt.hp, boss.hp))
                        break
                    end
                end
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
        -- ('rest' no: con el ritmo rápido el arnés la golpea antes de acabar una tanda; lo
        -- comprueba snowboss_rules, caso descansa)
        local need = { 'hop', 'shoot', 'windup', 'roll', 'dizzy', 'leap_wind', 'leap', 'leap_land',
                       'slam_up', 'slam_land', 'soaked', 'frozen', 'phase_up' }
        local miss = {}
        for _, n in ipairs(need) do if not seen[n] then miss[#miss + 1] = n end end
        check('ataques', #miss == 0, #miss == 0 and 'todos vistos' or ('faltan: ' .. table.concat(miss, ',')))
        check('mareada', sn.crashDizzy > 0 and sn.bonks > 0,
            ('mareada al chocar rodando %d veces; carámbanos en la bola %d'):format(sn.crashDizzy, sn.bonks))
        local f3 = #sn.frozenHits > 0
        for _, d in ipairs(sn.frozenHits) do if d ~= 3 then f3 = false end end
        check('congelada', f3, ('ground pound congelada: %s (Activadores pulsados %d)'):format(table.concat(sn.frozenHits, ','), sn.toggles))
        check('fases', sn.phases[1] and sn.phases[2] and sn.phases[3] and sn.scales[10] and sn.scales[8] and sn.scales[6],
            ('fases vistas: %s%s%s; escalas 10/8/6: %s/%s/%s'):format(sn.phases[1] and '1' or '', sn.phases[2] and '2' or '',
            sn.phases[3] and '3' or '', tostring(sn.scales[10] or false), tostring(sn.scales[8] or false), tostring(sn.scales[6] or false)))
        local anyPhase = false
        for _, e in ipairs(ents) do if e.def.name == 'cryo' and (e.props.phase or 0) > 0 then anyPhase = true end end
        if anyPhase then
            check('aparecen', #sn.early == 0 and sn.shown.cryo and sn.shown.switch,
                ('antes de la fase 3: %s; en la fase 3: Congelador %s, Activador %s'):format(
                    #sn.early == 0 and 'nada' or table.concat(sn.early, ','), tostring(sn.shown.cryo or false), tostring(sn.shown.switch or false)))
        end
        if #(boss.lake or {}) > 0 then        -- (solo si la arena tiene hielo fino)
            check('lago', sn.refrozen > 0, ('celdas de hielo fino rehechas: %d'):format(sn.refrozen))
        end
        check('muerte', not boss.alive and table.concat(sn.deathOrder, ',') == 'dying_crack,dying_burst,dying_flee' and z.state == 'cleared',
            ('vivo=%s orden %s, zona %s'):format(tostring(boss.alive), table.concat(sn.deathOrder, ','), z.state))
    end
    if king then
        local function check(name, ok, msg)
            print(('%-10s %s  %s'):format(name, ok and 'OK   ' or 'FALLA', msg))
            if not ok then fails = fails + 1 end
        end
        local need = { 'chase', 'flop_wind', 'flop_air', 'dazed', 'recover', 'phase_up', 'flop_land', 'split', 'parts',
                       'dying_pop' }
        local miss = {}
        for _, n in ipairs(need) do if not seen[n] then miss[#miss + 1] = n end end
        check('estados', #miss == 0, #miss == 0 and 'todos vistos' or ('faltan: ' .. table.concat(miss, ',')))
        check('fases', kg.phases[1] and kg.phases[2] and kg.phases[3], ('fases vistas: %s%s%s'):format(
            kg.phases[1] and '1' or '', kg.phases[2] and '2' or '', kg.phases[3] and '3' or ''))
        check('guardia', kg.maxGuards > 0 and kg.maxGuards <= (boss.props.guardMax or 3),
            ('guardias a la vez (máx.): %d'):format(kg.maxGuards))
        local worst = 0
        for _, d in ipairs(kg.flopOff) do worst = math.max(worst, d) end
        check('marca', #kg.flopOff > 0 and worst <= 24, ('%d panzazos; el más lejos de su marca: %.0f px'):format(#kg.flopOff, worst))
        check('olas', kg.waveHits == 0, ('golpes de ola al jugador (saltándolas): %d'):format(kg.waveHits))
        check('muerte', not boss.alive and kg.partHits >= 3 and z.state == 'cleared',
            ('vivo=%s, golpes a trozos %d, zona %s'):format(tostring(boss.alive), kg.partHits, z.state))
    end
    local ks = {}
    for k, v in pairs(sounds) do ks[#ks + 1] = k .. '=' .. v end
    table.sort(ks)
    print('Sonidos: ' .. table.concat(ks, ' '))
    love.event.quit(fails == 0 and 0 or 1)
end
