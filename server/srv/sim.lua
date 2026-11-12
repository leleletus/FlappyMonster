-- server/srv/sim.lua
-- PARTE de server/main.lua: la SIMULACIÓN de cada sala: crearla, compensación del retardo, jugadores, entidades, un tick.
-- La carga server/main.lua con require(...)(S): S = el estado y las funciones que comparten las partes (los
-- módulos del juego, que se cargan en love.load, también: S.Level, S.Entities...).

return function(S)
local Protocol, Modes, Lang, TICK_DT, band, round = S.Protocol, S.Modes, S.Lang, S.TICK_DT, S.band, S.round
local MAX_BUDGET, MAX_STEPS_TICK, TARGET_QUEUE, TRIM_AFTER, MAX_QUEUE, STARVE_TICKS = S.MAX_BUDGET, S.MAX_STEPS_TICK, S.TARGET_QUEUE, S.TRIM_AFTER, S.MAX_QUEUE, S.STARVE_TICKS
local _inp, PLAYER_LIVES, TEST_BOSSDMG, SPAWN_STAGGER, players = S._inp, S.PLAYER_LIVES, S.TEST_BOSSDMG, S.SPAWN_STAGGER, S.players
local buildResults
local function initRoomSim(room)
    local level = S.Level.new(room.level, room.difficulty)
    level.difficulty = room.difficulty               -- (src/core/Difficulty.lua; nil = el juego de siempre)
    S.Difficulty.bind(level)
    local sx, sy = level:getSpawnPx()
    local N = #room.playerIds

    local sim = { level=level, tick=0, playerSims={}, enemies={}, events={}, enemyHist={},
                  ended=nil, levelTime=0, timeLimitKilled=false,
                  nextBubbleId=0,
                  levelRaw = love.filesystem.read(room.level),   -- se envía a los clientes
                  mode = Modes.get(room.mode),
                  startPlayers = #room.playerIds,
                  -- INICIO (src/world/systems/StartCountdown.lua): tarjeta + cuenta atrás, todo congelado. Antes, la ESPERA a
                  -- que carguen todos (0.5.202): startTicks = nil hasta entonces (stepRoom: S.startWaitOver)
                  startTicks = nil, loaded = {}, firstLoadedTick = nil,
                  waitFor = {} }

    -- Crear instancias de las entidades del nivel (enemigos, NPCs)
    for _, placement in ipairs(level.entities) do
        local e = S.Entities.create(placement)
        if e then table.insert(sim.enemies, e) end
    end

    for _, pid in ipairs(room.playerIds) do sim.waitFor[pid] = true end
    -- Crear simulaciones de jugadores con spawn escalonado
    for i, pid in ipairs(room.playerIds) do
        local c = S.findClientById(pid)
        if c then
            local spawnX = sx + (i - 1 - (N - 1) / 2) * SPAWN_STAGGER
            S.addPlayerSim(sim, pid, i, spawnX, sy, players[c])
        end
    end

    -- Zonas de jefe (world/BossZones.lua): el servidor decide cuándo empieza
    -- y termina cada pelea; los clientes reciben el estado en cada snapshot
    sim.bossCtl = S.BossZones.newController(level, sim.enemies)

    -- Estado de la ronda para el modo de juego (ver src/world/modes/)
    sim.match = { players = sim.playerSims, enemies = sim.enemies, time = 0, data = {}, level = level,
                  event = function(ev) ev.t = sim.tick; table.insert(sim.events, ev) end }
    sim.mode.start(sim.match)

    S.log("Simulacion iniciada para sala '" .. room.name .. "' — " .. sim.mode.label .. " en "
        .. room.level .. " — " .. #sim.enemies .. " enemigos, " .. N .. " jugadores.")
    return sim
end

-- El jugador `pid` en la partida (al empezar, o entrando con ella en marcha: `late` = mira hasta la próxima ronda, sin
-- vidas). `token`: para VOLVER A ENTRAR si se le corta la conexión (lobby: hello con `rejoin`).
local function addPlayerSim(sim, pid, idx, x, y, player, late)
    local pa = S.PlayerAdventure:new(x, y)
    pa:settle(sim.level)        -- (de pie sobre el suelo ya en la cuenta atrás; el cliente lo recibe en game_init)
    pa:applyDifficulty()
    pa.lives = late and 0 or PLAYER_LIVES
    pa.netId = pid              -- a quién atribuir sus sonidos (golpes de jefe)
    local ps = {
        id          = pid,
        idx         = idx,
        pa          = pa,
        name        = player.name, color = player.color,      -- (siguen aunque se le corte la conexión)
        token       = string.format('%08x%08x', math.random(0, 0x7fffffff), math.random(0, 0x7fffffff)),
        queue       = {},     -- { {seq, bits}, ... } pendientes
        lastRecvSeq = 0,
        lastProcSeq = 0,      -- confirmado al cliente en cada snapshot
        lastBits    = 0,
        budget      = 0,
        starve      = 0,
        highQueue   = 0,
        bounceSeq   = 0,
        isSpectator = late or false,
        late        = late or nil,     -- (no sale en los resultados de esta ronda)
        score       = 0,
    }
    sim.playerSims[pid] = ps
    return ps
end

-- Vuelve a entrar quien se fue (mismo jugador, otra conexión): sus inputs vuelven a contar desde 0
local function resumePlayerSim(ps)
    ps.away = nil
    ps.queue, ps.lastRecvSeq, ps.lastProcSeq, ps.lastBits = {}, 0, 0, 0
    ps.budget, ps.starve, ps.highQueue, ps.viewTick = 0, 0, 0, nil
end

local function pushEvent(sim, ev)
    ev.t = sim.tick
    table.insert(sim.events, ev)
end

-- Colisiones de UN jugador contra los enemigos (lógica portada de AdventureState).
-- Se llama tras cada paso del jugador y tras mover a los enemigos, así una
-- ráfaga de inputs procesada en un solo tick no atraviesa enemigos.
-- ── Compensación de latencia ────────────────────────────────────────────────
-- El cliente ve a los enemigos interpolados en el PASADO (su tick de render),
-- mientras su propio jugador va predicho en el presente. Para que pisotones,
-- pinchos y golpes coincidan con lo que el jugador VIO, el servidor guarda el
-- estado de los enemigos de los últimos ticks y evalúa las interacciones de
-- cada jugador contra el estado del tick que ese jugador tenía en pantalla
-- (limitado a REWIND_MAX para que un cliente no pueda abusar).
local REWIND_MAX = 20       -- ticks (~333 ms)
local HIST_SIZE  = 32

-- Copia los campos simples (números, booleanos, textos, imágenes) de una entidad
-- Copia los campos simples (no tablas ni funciones) de e en `into` (vaciándola antes) o en una tabla nueva
local function scalarState(e, into)
    local st = into or {}
    if into then for k in pairs(st) do st[k] = nil end end
    for k, v in pairs(e) do
        local tv = type(v)
        if tv ~= 'table' and tv ~= 'function' then st[k] = v end
    end
    return st
end
local function applyState(e, st)
    for k, v in pairs(st) do e[k] = v end
end

-- (el anillo de la historia REUTILIZA sus tablas: antes, cada tick, una tabla nueva por entidad con todos sus campos
-- = la mayor parte de la basura del servidor)
local function recordEnemyHistory(sim)
    local idx = sim.tick % HIST_SIZE
    local slot = sim.enemyHist[idx]
    if not slot then slot = { states = {} }; sim.enemyHist[idx] = slot end
    slot.tick = sim.tick
    local states = slot.states
    local n = #sim.enemies
    for i = 1, n do states[i] = scalarState(sim.enemies[i], states[i] or {}) end
    for i = #states, n + 1, -1 do states[i] = nil end
end

-- Estado histórico de los enemigos que vio el jugador (o nil = el actual)
local function viewedHistory(sim, ps)
    local vt = ps.viewTick
    if not vt then return nil end
    vt = math.max(sim.tick - REWIND_MAX, math.min(sim.tick - 1, vt))
    local h = sim.enemyHist[vt % HIST_SIZE]
    if h and h.tick == vt then return h end
end

-- Compensación del retardo: a más de REWIND_FAR px del jugador (ahora y en lo que veía) no se rebobina
local REWIND_FAR = 640
local REWIND_NOW = {}         -- (el estado actual de la entidad mientras se rebobina: una tabla para todas)
local function checkPlayerEnemyCollisions(sim, pid, ps, seq)
    local pa = ps.pa
    if ps.isSpectator or pa.dying or not pa.alive then return end

    -- Evaluar contra el estado de cada enemigo que el jugador veía
    local hist = viewedHistory(sim, ps)
    local rewind = hist and function(i, g, check)
        local old = hist.states[i]
        if not (old and g.alive and g.state ~= 'dead') then return check(pa, g) end
        -- (lejos del jugador ahora y en lo que veía: nada que compensar; se comprueba tal cual, sin copiar nada)
        local ox, oy = old.x or g.x, old.y or g.y
        if math.abs(g.x - pa.x) > REWIND_FAR and math.abs(ox - pa.x) > REWIND_FAR
           or math.abs(g.y - pa.y) > REWIND_FAR and math.abs(oy - pa.y) > REWIND_FAR then
            return check(pa, g)
        end
        local now = scalarState(g, REWIND_NOW)
        applyState(g, old)
        local r, a, b, c = check(pa, g)
        applyState(g, now)
        -- (lo que ahora es nil, p. ej. turnT al acabar un giro, vuelve a nil)
        for k in pairs(old) do if now[k] == nil then g[k] = nil end end
        return r, a, b, c                       -- (4º valor: los saltos que deja un 'launch', el lado de un pisotón)
    end

    -- Reglas compartidas con el modo un jugador (entities/Interactions.lua).
    -- Los sonidos se etiquetan con quien los causa: su cliente ya los predijo.
    S.soundOwner = pid
    S.emitX, S.emitY = pa.x, pa.y
    S.Entities.interactions.run(pa, sim.enemies, {
        stomp = function(g, pts)
            pts = pts or 0
            ps.score = ps.score + pts
            ps.scoreT = sim.levelTime          -- para desempatar: quién llegó antes
            ps.bounceSeq = seq
            sim.mode.onStomp(sim.match, ps, g)
            pushEvent(sim, { type='score', playerId=pid, delta=pts, x=round(g.x), y=round(g.y) })
        end,
        pickup = function(e, pk)
            pk = S.Entities.interactions.pickupEffect(pa, pk)
            if pk.heal then pa.hp = pa.hp + pk.heal end                 -- (manzana: la vida va en el estado propio)
            if pk.score then
                ps.score = ps.score + pk.score
                ps.scoreT = sim.levelTime
            end
            if pk.lives then pa.lives = math.min(99, pa.lives + pk.lives) end
            pushEvent(sim, { type='pickup', playerId=pid, kind = (pk.heal and 'heal') or (pk.lives and 'life') or 'star',
                             delta = pk.score, x=round(e.x), y=round(e.y) })
        end,
        checkpoint = function(e, i)
            if ps.checkpointIdx == i then return end
            ps.checkpointIdx = i
            pa.spawnX, pa.spawnY = e:respawnPoint()
            pushEvent(sim, { type='checkpoint', playerId=pid, idx=i, x=round(e.x), y=round(e.y) })
        end,
    }, rewind)
    S.soundOwner = nil

    -- Ground pound: empuja y aturde a los jugadores cercanos
    if pa.gpLanded and ps.gpPushTick ~= sim.tick then
        ps.gpPushTick = sim.tick                -- una vez por impacto (hay 2 pasadas por tick)
        local others = {}
        for opid, ops in pairs(sim.playerSims) do
            if opid ~= pid and not ops.isSpectator then others[#others + 1] = ops.pa end
        end
        S.Sim.poundPlayers(pa, others, function(o, push)
            S.soundOwner = nil
            S.emitX, S.emitY = o.x, o.y
            push()
        end)
    end
end

-- Un paso fijo (TICK_DT) de un jugador con el input `bits`.
local function stepPlayer(sim, pid, ps, bits, seq)
    local pa = ps.pa
    Protocol.decodeInput(bits, _inp)
    S.soundOwner = pid
    S.emitX, S.emitY = pa.x, pa.y
    pa:update(TICK_DT, sim.level)
    S.soundOwner = nil
    -- Bloques que rompió ESTE jugador: con su id, para que su cliente los aplique ya (los de los demás esperan al
    -- tick que se dibuja); su predicción ya no choca con un bloque que en el servidor no existe
    local bq = sim.level.brokenQueue
    if bq and #bq > 0 then
        for _, b in ipairs(bq) do pushEvent(sim, { type='tile', c=b[1], r=b[2], v=b[3], k=b[4], from=b[5], playerId=pid }) end
        sim.level.brokenQueue = {}
    end

    -- Fin de animación de muerte → restar vida y respawn/espectador
    if pa.dying and not pa.alive then
        pa.lives = pa.lives - 1
        if pa.lives <= 0 then
            ps.isSpectator = true
            pushEvent(sim, { type='spectate', playerId=pid })
        else
            -- Cámara automática: se reaparece en el centro de lo que se ve
            S.Sim.respawnPoint(sim.level, pa)
            S.soundOwner = pid
            pa:respawn()
            S.soundOwner = nil
        end
        return
    end

    -- Colisión con burbuja de oxígeno (reinicia ahogamiento)
    if not pa.dying then
        local ob  = pa:getOuterBounds()
        local hit = sim.level:checkVentOxyCollision(ob.x, ob.y, ob.w, ob.h)
        if hit and (pa.drownPhase == 'warning' or pa.drownPhase == 'drowning') then
            pa.drownTimer=0; pa.drownChime=0
            pa.drownAudT=0;  pa.drownDead=false
            pa.drownPhase='none'
            pa.airBarAlpha=0; pa.airBarBobOn=false
            table.insert(S.soundEvents, { sound='airGasp', playerId=pid, x=round(pa.x), y=round(pa.y) })
            -- Evento autoritativo: el cliente resetea sonido/música del ahogamiento
            pushEvent(sim, { type='air_collected', playerId=pid })
        end
    end

    checkPlayerEnemyCollisions(sim, pid, ps, seq)

    -- Triggers de tiles que le interesan al modo (p. ej. la meta)
    if not ps.isSpectator and not pa.dying then
        local ob = pa:getOuterBounds()
        for _, tr in ipairs(sim.mode.triggers) do
            if sim.level:triggerInBox(ob.x, ob.y, ob.w, ob.h, tr) then
                sim.match.time = sim.levelTime
                sim.mode.onTrigger(sim.match, ps, tr)
            end
        end
    end
end

-- Consume los inputs en cola de un jugador para este tick.
local function processPlayerInputs(sim, pid, ps)
    ps.budget = math.min(ps.budget + 1, MAX_BUDGET)

    -- Recortar la cola si crece: evita latencia de input acumulada tras un
    -- pico de lag. Los flags de "recién presionado" se conservan.
    local q = ps.queue
    if #q > TARGET_QUEUE then ps.highQueue = ps.highQueue + 1 else ps.highQueue = 0 end
    local keep = (#q > MAX_QUEUE or ps.highQueue > TRIM_AFTER) and TARGET_QUEUE or #q
    while #q > keep do
        local old = table.remove(q, 1)
        local pressed = old.bits - band(old.bits, Protocol.IN_HELD_MASK)
        if pressed > 0 then q[1].bits = Protocol.bor(q[1].bits, pressed) end
        ps.lastProcSeq = old.seq
        ps.highQueue   = 0
    end

    local steps = 0
    while steps < MAX_STEPS_TICK and ps.budget >= 1 and #q > 0 and not ps.isSpectator do
        local cmd = table.remove(q, 1)
        ps.lastProcSeq = cmd.seq
        ps.lastBits    = cmd.bits
        if cmd.v then ps.viewTick = cmd.v end
        stepPlayer(sim, pid, ps, cmd.bits, cmd.seq)
        ps.budget = ps.budget - 1
        steps = steps + 1
    end

    if steps > 0 then
        ps.starve = 0
    else
        -- Sin input (lag o cliente que dejó de enviar): tras un margen, el
        -- jugador sigue con su último input mantenido para que el mundo no
        -- lo "congele" (evita usar el lag como escudo contra la física).
        -- (No antes del primer input: al empezar, el game_init aún viaja hacia
        -- el cliente y extrapolar crearía un desfase inicial.)
        ps.starve = ps.starve + 1
        if ps.starve >= STARVE_TICKS and ps.budget >= 1 and ps.lastRecvSeq > 0 then
            stepPlayer(sim, pid, ps, band(ps.lastBits, Protocol.IN_HELD_MASK), ps.lastProcSeq)
            ps.budget = ps.budget - 1
        end
    end
end

-- Clasificación final de la ronda: la ordena el modo y marca ganadores.
buildResults = function(room, reason)
    local sim = room.sim
    local entries = {}
    for _, pid in ipairs(room.playerIds) do
        local ps = sim.playerSims[pid]
        if ps and not ps.late then
            entries[#entries+1] = {
                id = pid, name = ps.name, color = ps.color or {1,1,1},
                score = ps.score, finished = ps.finished or false, place = ps.place,
                time = ps.finishTime and round(ps.finishTime * 100) / 100 or nil,
                out = ps.isSpectator and not ps.finished, order = ps.idx, winner = false,
                lives = ps.isSpectator and 0 or ps.pa.lives, scoreT = ps.scoreT or 0,
            }
        end
    end
    local note, tie = sim.mode.rank(sim.match, entries, reason)
    -- Último superviviente: gana él, sea cual sea el modo
    if reason == 'last_standing' then
        note, tie = nil, false
        for i, e in ipairs(entries) do
            e.winner = (e.id == sim.survivor)
            if e.winner and i > 1 then table.remove(entries, i); table.insert(entries, 1, e) end
        end
    end
    S.log("Ronda terminada (" .. sim.mode.id .. ", " .. reason .. ") en '" .. room.name .. "'")
    return { type = 'round_end', mode = sim.mode.id, reason = reason,
             -- textos en español (clientes antiguos); los nuevos traducen reason/noteKey
             reasonText = Modes.reasonText(sim.mode, reason),
             note = note and Lang(note), noteKey = note, tie = tie or false, entries = entries }
end

-- Cuenta atrás del principio: los inputs se consumen y se confirman (el cliente los predice quietos, ver
-- Predictor:tick) pero nadie se mueve
local function drainFrozenInputs(ps)
    local q = ps.queue
    while #q > 0 do
        local cmd = table.remove(q, 1)
        ps.lastProcSeq = cmd.seq
        ps.lastBits    = cmd.bits
        if cmd.v then ps.viewTick = cmd.v end
    end
    ps.budget, ps.starve, ps.highQueue = 0, 0, 0
end

-- Los GANCHOS del servidor para el paso compartido (Sim.step: el orden está allí). Uno por sala.
local function makeSimHooks(room, sim)
    local h = {}
    h.floods = function()
        -- Inundaciones: el nivel del agua es función del tick (el cliente lo estima igual; empieza al acabar la cuenta
        -- atrás); las controladas (jefe / ON-OFF) cambian aquí y van en el snapshot
        S.Floods.control(sim.level, sim.floodT)
        S.Floods.setTime(sim.level, sim.floodT)
    end
    h.players = function()
        -- Jugadores (orden estable: el de la sala); cada uno, al moverse, choca con lo que veía (stepPlayer)
        for _, pid in ipairs(room.playerIds) do
            local ps = sim.playerSims[pid]
            if ps and not ps.isSpectator then processPlayerInputs(sim, pid, ps) end
        end
        -- Restaurar input neutral
        Protocol.decodeInput(0, _inp)
        S.soundOwner = nil
        S.emitX, S.emitY = nil, nil
        -- Las trampas y entidades de techo "ven" a los jugadores activos
        local active = sim.active or {}
        for i = #active, 1, -1 do active[i] = nil end
        sim.active = active
        for _, pid in ipairs(room.playerIds) do
            local ps = sim.playerSims[pid]
            if ps and not ps.isSpectator then active[#active+1] = ps.pa; ps.pa.ownerIdx = ps.idx end   -- (ownerIdx: el ranking del Mega Mashup)
        end
        sim.level.players = active
    end
    -- (sin quitar las muertas: el índice de cada entidad es el de las fotos)
    h.emit, h.prune = function(x, y) S.emitX, S.emitY = x, y end, false
    h.afterEntities = function()
        if TEST_BOSSDMG then
            sim.testDmgT = (sim.testDmgT or 0) + TICK_DT
            if sim.testDmgT >= TEST_BOSSDMG then
                sim.testDmgT = 0
                for _, e in ipairs(sim.enemies) do
                    local ev = e.eventRef
                    if ev then                                 -- (evento: acaba el turno del que pelea, sea cual sea su ventana)
                        if not e.eventFrozen and e:isActive() and ev:isTurnOf(e) then ev:crabDown(e) end
                    elseif e.def and e.def.boss and e.state ~= 'parts' then e:damage(1, 'stomp') end   -- (los trozos: que peguen de verdad)
                end
            end
        end
        recordEnemyHistory(sim)
    end
    -- Zonas de puntos: quien está dentro suma cada cierto tiempo
    h.zonePlayers = function() return sim.active end
    h.zonePoints = function(pa, pts)
        local pid
        for _, id in ipairs(room.playerIds) do
            local ps = sim.playerSims[id]
            if ps and ps.pa == pa then pid = id; break end
        end
        local ps = pid and sim.playerSims[pid]
        if not ps then return end
        ps.score = ps.score + pts
        ps.scoreT = sim.levelTime
        pushEvent(sim, { type='score', playerId=pid, delta=pts, x=round(pa.x), y=round(pa.y - 40), kind='zone' })
        pushEvent(sim, { type='fx', kind='points', x=round(pa.x), y=round(pa.y) })
        S.emitX, S.emitY = pa.x, pa.y
        Sound.play('pointGain')
        S.emitX, S.emitY = nil, nil
    end
    -- Zonas de jefe: llegada de los jugadores, inicio y fin de la pelea
    h.bosses = function()
        for _, ev in ipairs(sim.bossCtl:update(TICK_DT)) do pushEvent(sim, ev) end
    end
    -- Cámara automática: espera a todos, avanza y mata a quien se queda atrás. Se para en cuanto alguien llega a la meta.
    h.autoScroll = function()
        if not sim.level.autoScroll then return end
        for _, ps in pairs(sim.playerSims) do if ps.finished then sim.level.finishReached = true end end
        local evs = S.AutoScroll.update(sim.level, TICK_DT, function(pa)
            S.PlayerAdventure.asOwner(pa, function() pa:die(nil, true) end)
        end)
        for _, ev in ipairs(evs) do pushEvent(sim, ev) end
    end
    -- Colisiones tras mover enemigos (un enemigo puede alcanzar a un jugador quieto)
    h.interactions = function()
        for _, pid in ipairs(room.playerIds) do
            local ps = sim.playerSims[pid]
            if ps then checkPlayerEnemyCollisions(sim, pid, ps, ps.lastProcSeq) end
        end
    end
    return h
end

-- Avanzar la simulación de una sala un tick fijo

-- ¿Se acabó la espera del principio? Todos los que empezaban y siguen conectados avisaron de que cargaron el nivel
-- (`level_loaded`), o pasó el límite: LOAD_WAIT s desde el primero que cargó, LOAD_WAIT_MAX s desde el game_init
local LOAD_WAIT, LOAD_WAIT_MAX = 8, 20
function S.startWaitOver(room)
    local sim = room.sim
    local all = true
    for pid in pairs(sim.waitFor) do
        -- (sigue en la partida: conectado y con su jugador — salir o ser expulsado se lo quita —)
        if not sim.loaded[pid] and S.findClientById(pid) and sim.playerSims[pid] then all = false; break end
    end
    if all then return true end
    if sim.firstLoadedTick and (sim.tick - sim.firstLoadedTick) * TICK_DT >= LOAD_WAIT then return true end
    return sim.tick * TICK_DT >= LOAD_WAIT_MAX
end

local function stepRoom(room)
    local sim = room.sim
    if not sim then return end
    S.currentSim = sim
    require('src/world/systems/Noise').bind(sim.level)        -- (los ruidos de este paso, a este nivel)
    S.Difficulty.bind(sim.level)                        -- (… y su dificultad)

    sim.tick = sim.tick + 1
    S.soundEvents = {}
    S.emitX, S.emitY = nil, nil

    -- ── La ESPERA a que carguen todos y luego tarjeta + cuenta atrás (StartCountdown): el mundo entero congelado ─
    if not sim.startTicks and S.startWaitOver(room) then
        sim.startTicks = sim.tick + S.StartCountdown.ticks(TICK_DT, true)
        for _, pid in ipairs(room.playerIds) do
            local c = S.findClientById(pid)
            if c then c:send("round_start", { start = sim.startTicks }) end
        end
    end
    if not sim.startTicks or sim.tick <= sim.startTicks then
        for _, pid in ipairs(room.playerIds) do
            local ps = sim.playerSims[pid]
            if ps then drainFrozenInputs(ps) end
        end
        recordEnemyHistory(sim)               -- (la compensación de latencia mira ticks pasados)
        return
    end

    -- ── Reloj de nivel (autoritativo) ────────────────────────────────────────
    sim.levelTime = math.min(sim.levelTime + TICK_DT, S.Sim.TIME_LIMIT)
    -- Inundaciones: el nivel del agua es función del tick (el cliente lo estima
    -- igual; empieza al acabar la cuenta atrás); las controladas (jefe / ON-OFF)
    -- cambian aquí y van en el snapshot
    local floodT = (sim.tick - sim.startTicks) * TICK_DT       -- (se aplica en el paso: gancho floods)

    -- Límite de 10 minutos: matar a todos los jugadores activos (igual que modo solo)
    if sim.levelTime >= S.Sim.TIME_LIMIT and not sim.timeLimitKilled then
        sim.timeLimitKilled = true
        for pid, ps in pairs(sim.playerSims) do
            if not ps.isSpectator and not ps.pa.dying then
                ps.pa.lives = 1   -- die() restará 1 → 0 vidas → espectador → game over
                S.soundOwner = pid
                ps.pa:die(nil, true)
                S.soundOwner = nil
            end
        end
    end

    -- ── EL PASO: el mismo orden que un jugador (src/world/systems/Sim.lua, Sim.step); aquí, los ganchos del servidor ──
    sim.floodT = floodT
    sim.hooks = sim.hooks or makeSimHooks(room, sim)
    S.Sim.step(sim.level, sim.enemies, TICK_DT, sim.hooks)

    -- Bloques rotos este tick → a todos los clientes
    local bq = sim.level.brokenQueue
    if bq and #bq > 0 then
        for _, b in ipairs(bq) do pushEvent(sim, { type='tile', c=b[1], r=b[2], v=b[3], k=b[4], from=b[5] }) end
        sim.level.brokenQueue = {}
    end

    -- ── Fusionar eventos de sonido ────────────────────────────────────────────
    for _, se in ipairs(S.soundEvents) do
        pushEvent(sim, { type='sound', sound=se.sound, playerId=se.playerId, pitch=se.pitch, x=se.x, y=se.y })
    end
    S.soundEvents = {}

    -- ── ¿Termina la ronda? (reglas del modo + fin genérico) ─────────────────
    if not sim.ended then
        sim.match.time = sim.levelTime
        local reason = sim.mode.tick(sim.match, TICK_DT)
        if not reason then
            local anyActive, anyPlayer = false, false
            for _, ps in pairs(sim.playerSims) do
                anyPlayer = true
                if not ps.isSpectator then anyActive = true; break end
            end
            if anyPlayer and not anyActive then
                reason = sim.timeLimitKilled and 'time_limit' or 'all_out'
            end
        end
        -- Se quedó uno solo (los demás eliminados o se fueron) y nadie ha
        -- cumplido aún el objetivo → gana el superviviente
        if not reason and sim.startPlayers >= 2 then
            local active, finished = {}, 0
            for pid, ps in pairs(sim.playerSims) do
                if ps.finished then finished = finished + 1
                elseif not ps.isSpectator then active[#active+1] = pid end
            end
            if #active == 1 and finished == 0 then
                local ps = sim.playerSims[active[1]]
                -- Si está muriendo con su última vida, aún no es superviviente
                if not (ps.pa.dying and ps.pa.lives <= 1) then
                    sim.survivor = active[1]
                    reason = 'last_standing'
                end
            end
        end
        if reason then
            sim.ended = reason
            local ev = buildResults(room, reason)
            ev.t = sim.tick
            if S.recordRound then pcall(S.recordRound, room, ev) end        -- (récords y desafío del día: records.lua)
            table.insert(sim.events, ev)
        end
    end
end


-- (lo que usan las demás partes)
S.addPlayerSim, S.resumePlayerSim = addPlayerSim, resumePlayerSim
S.initRoomSim = initRoomSim
S.pushEvent = pushEvent
S.scalarState = scalarState
S.applyState = applyState
S.recordEnemyHistory = recordEnemyHistory
S.viewedHistory = viewedHistory
S.checkPlayerEnemyCollisions = checkPlayerEnemyCollisions
S.stepPlayer = stepPlayer
S.processPlayerInputs = processPlayerInputs
S.drainFrozenInputs = drainFrozenInputs
S.stepRoom = stepRoom
end
