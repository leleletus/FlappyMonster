-- server/main.lua
-- Servidor multijugador de FlappyMonster Adventure — Arquitectura autoritativa.
-- El servidor corre toda la simulación (física, enemigos, colisiones) a un paso
-- fijo de 60 Hz y retransmite el estado autorizado a los clientes. Los clientes
-- solo envían inputs numerados; su predicción local se reconcilia con el
-- último input que el servidor confirma haber procesado.

local sock   = require "libs.sock"
local bitser = require "libs.bitser"

-- Los datos de red vienen de clientes no confiables: nunca reconstruir
-- metatablas a partir de ellos.
bitser.includeMetatables(false)

-- Detectar modo headless (sin gráficos)
local HEADLESS = (love.graphics == nil)

io.stdout:setvbuf("no")
math.randomseed(os.time())

-- Directorio del juego (padre de server/): permite requerir src/ y leer assets.
local parentDir = love.filesystem.getSourceBaseDirectory():gsub("\\", "/")
package.path = parentDir .. "/?.lua;" .. package.path

local Protocol = require 'src/network/Protocol'
local Modes    = require 'src/world/Modes'
local json     = require 'libs/json'
local TICK_DT        = Protocol.TICK_DT
local SNAPSHOT_EVERY = Protocol.SNAPSHOT_EVERY
local band           = Protocol.band
local round          = Protocol.round

-- ─────────────────────────────────────────────────────────────────────────────
--  Constantes de red
-- ─────────────────────────────────────────────────────────────────────────────

local PORT       = 22122
local MAX_PEERS  = 64
local PING_TICK  = 3      -- segundos entre room_update
local LOG_MAX    = 22

-- Anti-abuso
local MSG_RATE        = 120   -- mensajes/s sostenidos por conexión
local MSG_BURST       = 240   -- ráfaga máxima
local FLOOD_LIMIT     = 300   -- mensajes descartados (ventana de 10 s) antes de expulsar
local INVALID_LIMIT   = 10    -- paquetes malformados antes de expulsar
local MAX_CONN_PER_IP = 4
local HELLO_TIMEOUT   = 6     -- s para identificarse tras conectar
local JOIN_FAIL_MAX   = 5     -- contraseñas erróneas antes de bloqueo temporal
local JOIN_FAIL_LOCK  = 30    -- s de bloqueo
local PASSWORD_MAX    = 20
local ROOM_NAME_MAX   = 30

-- Cola de inputs por jugador
local MAX_BUDGET      = 10    -- pasos "adelantados" permitidos (anti speed-hack)
local MAX_STEPS_TICK  = 3     -- pasos de un jugador por tick al ponerse al día
local TARGET_QUEUE    = 4     -- cola sana; por encima se recorta si persiste
local TRIM_AFTER      = 30    -- ticks con cola alta antes de recortar
local MAX_QUEUE       = 20    -- recorte inmediato
local STARVE_TICKS    = 8     -- ticks sin input antes de extrapolar el último
local MAX_SEQ_AHEAD   = 180   -- un seq más adelantado que esto es falso
local MAX_FRAME_TICKS = 8     -- ticks máximos simulados por frame del servidor

local PLAYER_COLORS = {
    {1.00,0.30,0.30}, {0.30,0.60,1.00}, {0.30,1.00,0.30}, {1.00,1.00,0.20},
    {1.00,0.55,0.05}, {0.80,0.30,1.00}, {0.05,0.90,0.85}, {1.00,0.40,0.80},
    {0.50,1.00,0.50}, {0.90,0.65,0.15}, {0.60,0.80,1.00}, {1.00,0.70,0.70},
    {0.35,1.00,1.00}, {1.00,0.90,0.50}, {0.70,0.40,0.95}, {0.50,0.95,0.55},
}

-- ─────────────────────────────────────────────────────────────────────────────
--  Stubs de sistema (deben definirse ANTES de hacer require de entidades)
-- ─────────────────────────────────────────────────────────────────────────────

-- Buffer de eventos de sonido recopilados durante la simulación de cada sala.
local _soundEvents           = {}
local _currentSoundPlayerId  = nil   -- nil = sonido global (enemigos, etc.)

Sound = {
    play        = function(name)
        if name then
            table.insert(_soundEvents, { sound = name, playerId = _currentSoundPlayerId })
        end
    end,
    stopTracked = function() end,
    playTracked = function() end,
    stopMusic   = function() end,
    playMusic   = function() end,
}

-- Input stub: se carga con el input del tick antes de cada pa:update().
Input = Protocol.newInputStub()
local _inp = Input.state

-- Clases de entidades (cargadas en love.load).
local Level, PlayerAdventure, Entities
local buildResults   -- definida más abajo

-- Constantes que deben coincidir con PlayerAdventure.lua
local DROWN_TOTAL     = 20
local LEVELS_DIR      = 'assets/levels'
local DEFAULT_LEVEL   = 'assets/levels/nivel01.json'
local PLAYER_LIVES    = 3
local SPAWN_STAGGER   = 48   -- px de separación horizontal entre jugadores al spawn
local LEVEL_TIME_MAX  = 600

-- ─────────────────────────────────────────────────────────────────────────────
--  Estructuras de datos de red
-- ─────────────────────────────────────────────────────────────────────────────

local server = sock.newServer("*", PORT, MAX_PEERS, Protocol.CHANNELS)
server:setSerialization(bitser.dumps, bitser.loads)

-- players[clientObj] = { id, name, verified, roomId, isReady, color, ip,
--                        tokens, lastT, dropped, dropWindow, invalid, kicked,
--                        connectedAt, joinFails, joinLockUntil }
local players    = {}
-- rooms[roomId]    = { id, name, isPublic, password, maxPlayers,
--                      playerIds, adminId, state, bannedNames, bannedIPs,
--                      sim (o nil si no está en partida) }
local rooms      = {}
local nextRoomId = 1
local nextPlayerSerial = 1

local serverLog  = {}
local pingTimer  = 0
local simAccum   = 0

-- ─────────────────────────────────────────────────────────────────────────────
--  Utilidades
-- ─────────────────────────────────────────────────────────────────────────────

local function log(msg)
    print(msg)
    table.insert(serverLog, msg)
    if #serverLog > LOG_MAX then table.remove(serverLog, 1) end
end

local function newRoomId()
    local id = tostring(nextRoomId); nextRoomId = nextRoomId + 1; return id
end

-- ID único (contador) + sufijo aleatorio para que no sea adivinable.
local function newPlayerId()
    local id = string.format("%x%06x", nextPlayerSerial, math.random(0, 0xffffff))
    nextPlayerSerial = nextPlayerSerial + 1
    return id
end

local function findClientById(playerId)
    for c, p in pairs(players) do
        if p.id == playerId then return c end
    end
end

local function findPlayerNameById(playerId)
    local c = findClientById(playerId)
    return (c and players[c]) and players[c].name or "?"
end

local function countPlayers()
    local n=0; for _, p in pairs(players) do if p.verified then n=n+1 end end; return n
end
local function countRooms()   local n=0; for _ in pairs(rooms)   do n=n+1 end; return n end

local function peerIP(client)
    local s = client and client.connection and tostring(client.connection) or ""
    return s:match("^(.*):%d+$") or s
end

local function isInt(v, lo, hi)
    return type(v) == "number" and v == math.floor(v) and v >= lo and v <= hi
end

-- Texto libre (contraseñas): sin caracteres de control, longitud acotada.
local function cleanText(s, maxLen)
    if type(s) ~= "string" then return "" end
    return (s:gsub("%c", "")):sub(1, maxLen)
end

local function sendState(c, event, data)
    c:setSendChannel(Protocol.CH_STATE)
    c:setSendMode("unreliable")
    c:send(event, data)
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Simulación de juego
-- ─────────────────────────────────────────────────────────────────────────────

-- ── Catálogo de niveles del servidor ────────────────────────────────────────
-- Se escanea assets/levels (caché de 10 s: un nivel nuevo aparece sin
-- reiniciar). Para cada nivel se calcula qué modos admite. Los clientes no
-- necesitan tener el archivo: el nivel se les envía al empezar la partida.
local levelCache, levelCacheT = nil, -1e9

local function listLevelFiles()
    local dir = parentDir .. '/' .. LEVELS_DIR
    local cmd = (love.system.getOS() == 'Windows') and ('dir /b "' .. dir:gsub('/', '\\') .. '"')
                or ('ls -1 "' .. dir .. '"')
    local out = {}
    local p = io.popen(cmd)
    if p then
        for line in p:lines() do
            line = line:gsub('%s+$', '')
            if line:match('^[%w%-_%.]+%.json$') and not line:match('^_') then out[#out+1] = line end
        end
        p:close()
    end
    table.sort(out)
    return out
end

-- Miniatura del nivel para el selector del lobby: un carácter por celda
-- ('.' vacío, '#' sólido, 'B' borde, '=' plataforma, '~' agua, 'X' peligro,
-- 'F' meta, '^' pinchos) + entidades y punto de inicio.
local PREVIEW_MAX_CELLS = 20000
local function buildPreview(lv)
    if lv.tileW * lv.tileH > PREVIEW_MAX_CELLS then return nil end
    local Tiles = require 'src/world/Tiles'
    local rows = {}
    for r = 1, lv.tileH do
        local line = {}
        for c = 1, lv.tileW do
            local raw = lv.tiles[r][c]
            local t   = lv:getDef(c, r)
            local ch  = '.'
            if t.trigger == 'finish' then ch = 'F'
            elseif t.mat.contact == 'kill' then ch = 'X'
            elseif t.name == 'border' then ch = 'B'
            elseif t.collision == 'solid' then ch = '#'
            elseif t.collision == 'oneway' then ch = '='
            elseif t.mat.liquid or Tiles.codec.isWaterlogged(raw) then ch = '~'
            end
            if ch == '.' and Tiles.codec.hasSpikes(raw) then ch = '^' end
            line[c] = ch
        end
        rows[r] = table.concat(line)
    end
    local ents = {}
    for _, e in ipairs(lv.entities) do ents[#ents+1] = { e.col, e.row } end
    return { rows = rows, ents = ents, start = lv.playerStart }
end

local function scanLevels(force)
    local now = love.timer.getTime()
    if levelCache and not force and now - levelCacheT < 10 then return levelCache end
    local list = {}
    for _, f in ipairs(listLevelFiles()) do
        local path = LEVELS_DIR .. '/' .. f
        local ok, lv = pcall(Level.new, path)
        if ok then
            local killable = 0
            for _, e in ipairs(lv.entities) do if e.props.stompable then killable = killable + 1 end end
            local info = { path = path, name = (lv.name and lv.name ~= '?') and lv.name or f:gsub('%.json$', ''),
                           enemies = #lv.entities, killable = killable, finish = lv:countTrigger('finish'),
                           modes = {} }
            for _, m in ipairs(Modes.list) do
                if m.requires(info) then info.modes[m.id] = true end
            end
            info.w, info.h = lv.tileW, lv.tileH
            info.preview   = buildPreview(lv)
            list[#list+1] = info
        else
            log('Nivel invalido ' .. path .. ': ' .. tostring(lv))
        end
    end
    levelCache, levelCacheT = list, now
    return list
end

local function levelsForMode(modeId)
    local out = {}
    for _, info in ipairs(scanLevels()) do if info.modes[modeId] then out[#out+1] = info end end
    return out
end

local function levelInfo(path)
    for _, info in ipairs(scanLevels()) do if info.path == path then return info end end
end

-- Asegura que la sala tenga un nivel válido para su modo (o nil si no hay).
local function ensureRoomLevel(room)
    local info = room.level and levelInfo(room.level)
    if info and info.modes[room.mode] then return end
    local cands = levelsForMode(room.mode)
    room.level = nil
    for _, c in ipairs(cands) do if c.path == DEFAULT_LEVEL then room.level = c.path end end
    room.level = room.level or (cands[1] and cands[1].path)
end

local function initRoomSim(room)
    local level = Level.new(room.level)
    local sx, sy = level:getSpawnPx()
    local N = #room.playerIds

    local sim = { level=level, tick=0, playerSims={}, enemies={}, events={}, enemyHist={},
                  ended=nil, levelTime=0, timeLimitKilled=false,
                  nextBubbleId=0,
                  levelRaw = love.filesystem.read(room.level),   -- se envía a los clientes
                  mode = Modes.get(room.mode),
                  startPlayers = #room.playerIds }

    -- Crear instancias de las entidades del nivel (enemigos, NPCs)
    for _, placement in ipairs(level.entities) do
        local e = Entities.create(placement)
        if e then table.insert(sim.enemies, e) end
    end

    -- Crear simulaciones de jugadores con spawn escalonado
    for i, pid in ipairs(room.playerIds) do
        local c = findClientById(pid)
        if c then
            local spawnX = sx + (i - 1 - (N - 1) / 2) * SPAWN_STAGGER
            local pa = PlayerAdventure:new(spawnX, sy)
            pa.lives = PLAYER_LIVES
            sim.playerSims[pid] = {
                id          = pid,
                idx         = i,
                pa          = pa,
                queue       = {},     -- { {seq, bits}, ... } pendientes
                lastRecvSeq = 0,
                lastProcSeq = 0,      -- confirmado al cliente en cada snapshot
                lastBits    = 0,
                budget      = 0,
                starve      = 0,
                highQueue   = 0,
                bounceSeq   = 0,
                isSpectator = false,
                score       = 0,
            }
        end
    end

    -- Estado de la ronda para el modo de juego (ver src/world/modes/)
    sim.match = { players = sim.playerSims, enemies = sim.enemies, time = 0, data = {},
                  event = function(ev) ev.t = sim.tick; table.insert(sim.events, ev) end }
    sim.mode.start(sim.match)

    log("Simulacion iniciada para sala '" .. room.name .. "' — " .. sim.mode.label .. " en "
        .. room.level .. " — " .. #sim.enemies .. " enemigos, " .. N .. " jugadores.")
    return sim
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
local function scalarState(e)
    local st = {}
    for k, v in pairs(e) do
        local tv = type(v)
        if tv ~= 'table' and tv ~= 'function' then st[k] = v end
    end
    return st
end
local function applyState(e, st)
    for k, v in pairs(st) do e[k] = v end
end

local function recordEnemyHistory(sim)
    local states = {}
    for i, e in ipairs(sim.enemies) do states[i] = scalarState(e) end
    sim.enemyHist[sim.tick % HIST_SIZE] = { tick = sim.tick, states = states }
end

-- Estado histórico de los enemigos que vio el jugador (o nil = el actual)
local function viewedHistory(sim, ps)
    local vt = ps.viewTick
    if not vt then return nil end
    vt = math.max(sim.tick - REWIND_MAX, math.min(sim.tick - 1, vt))
    local h = sim.enemyHist[vt % HIST_SIZE]
    if h and h.tick == vt then return h end
end

local function checkPlayerEnemyCollisions(sim, pid, ps, seq)
    local pa = ps.pa
    if ps.isSpectator or pa.dying or not pa.alive then return end

    local hist = viewedHistory(sim, ps)
    for i, g in ipairs(sim.enemies) do
        -- Reglas compartidas con el modo un jugador (entities/Interactions.lua),
        -- evaluadas contra el estado del enemigo que el jugador veía
        local result, bvy, pts
        local old = hist and hist.states[i]
        if old and g.alive and g.state ~= 'dead' then
            local now = scalarState(g)
            applyState(g, old)
            result, bvy, pts = Entities.interactions.check(pa, g)
            applyState(g, now)
        else
            result, bvy, pts = Entities.interactions.check(pa, g)
        end
        if result == 'kill' then
            _currentSoundPlayerId = pid; pa:die(); _currentSoundPlayerId = nil
            return
        elseif result == 'hurt' then
            _currentSoundPlayerId = pid
            local died = pa:hurt()
            _currentSoundPlayerId = nil
            if died then return end
        elseif result == 'stomp' then
            -- El sonido del pisotón se etiqueta con quien lo hizo:
            -- ese cliente ya lo reprodujo al predecir el rebote.
            _currentSoundPlayerId = pid; g:stomp(); _currentSoundPlayerId = nil
            pa.vy = bvy; pa.jumpsLeft = 2
            ps.score = ps.score + pts
            ps.scoreT = sim.levelTime          -- para desempatar: quién llegó antes
            ps.bounceSeq = seq
            sim.mode.onStomp(sim.match, ps, g)
            pushEvent(sim, { type='score', playerId=pid, delta=pts, x=round(g.x), y=round(g.y) })
        end
    end
end

-- Un paso fijo (TICK_DT) de un jugador con el input `bits`.
local function stepPlayer(sim, pid, ps, bits, seq)
    local pa = ps.pa
    Protocol.decodeInput(bits, _inp)
    _currentSoundPlayerId = pid
    pa:update(TICK_DT, sim.level)
    _currentSoundPlayerId = nil

    -- Fin de animación de muerte → restar vida y respawn/espectador
    if pa.dying and not pa.alive then
        pa.lives = pa.lives - 1
        if pa.lives <= 0 then
            ps.isSpectator = true
            pushEvent(sim, { type='spectate', playerId=pid })
        else
            _currentSoundPlayerId = pid
            pa:respawn()
            _currentSoundPlayerId = nil
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
            table.insert(_soundEvents, { sound='airGasp', playerId=pid })
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
        local c  = findClientById(pid)
        if ps and c then
            entries[#entries+1] = {
                id = pid, name = players[c].name, color = players[c].color or {1,1,1},
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
    log("Ronda terminada (" .. sim.mode.id .. ", " .. reason .. ") en '" .. room.name .. "'")
    return { type = 'round_end', mode = sim.mode.id, reason = reason,
             reasonText = sim.mode.reasonText(reason) or Modes.GENERIC_REASONS[reason] or '',
             note = note, tie = tie or false, entries = entries }
end

-- Avanzar la simulación de una sala un tick fijo
local function stepRoom(room)
    local sim = room.sim
    if not sim then return end

    sim.tick = sim.tick + 1
    _soundEvents = {}

    -- ── Reloj de nivel (autoritativo) ────────────────────────────────────────
    sim.levelTime = math.min(sim.levelTime + TICK_DT, LEVEL_TIME_MAX)

    -- Límite de 10 minutos: matar a todos los jugadores activos (igual que modo solo)
    if sim.levelTime >= LEVEL_TIME_MAX and not sim.timeLimitKilled then
        sim.timeLimitKilled = true
        for pid, ps in pairs(sim.playerSims) do
            if not ps.isSpectator and not ps.pa.dying then
                ps.pa.lives = 1   -- die() restará 1 → 0 vidas → espectador → game over
                _currentSoundPlayerId = pid
                ps.pa:die()
                _currentSoundPlayerId = nil
            end
        end
    end

    -- ── Jugadores (orden estable: el de la sala) ──────────────────────────────
    for _, pid in ipairs(room.playerIds) do
        local ps = sim.playerSims[pid]
        if ps and not ps.isSpectator then
            processPlayerInputs(sim, pid, ps)
        end
    end

    -- Restaurar input neutral
    Protocol.decodeInput(0, _inp)
    _currentSoundPlayerId = nil

    -- ── Nivel (burbujas de oxígeno en vents) y enemigos ──────────────────────
    sim.level:update(TICK_DT)
    for _, e in ipairs(sim.enemies) do
        e:update(TICK_DT, sim.level)
    end
    recordEnemyHistory(sim)

    -- ── Colisiones tras mover enemigos (un enemigo puede alcanzar a un jugador quieto)
    for _, pid in ipairs(room.playerIds) do
        local ps = sim.playerSims[pid]
        if ps then checkPlayerEnemyCollisions(sim, pid, ps, ps.lastProcSeq) end
    end

    -- ── Fusionar eventos de sonido ────────────────────────────────────────────
    for _, se in ipairs(_soundEvents) do
        pushEvent(sim, { type='sound', sound=se.sound, playerId=se.playerId })
    end
    _soundEvents = {}

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
            table.insert(sim.events, ev)
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Broadcasts
-- ─────────────────────────────────────────────────────────────────────────────

local function broadcastRoomUpdate(room)
    local playerList = {}
    for _, pid in ipairs(room.playerIds) do
        local c = findClientById(pid)
        if c then
            local ping = 0
            if c.connection then
                local ok, rtt = pcall(function() return c.connection:round_trip_time() end)
                if ok and type(rtt) == "number" then ping = rtt end
            end
            table.insert(playerList, {
                id      = pid,
                name    = players[c].name,
                isAdmin = (pid == room.adminId),
                isReady = players[c].isReady,
                ping    = ping,
                color   = players[c].color,
            })
        end
    end
    ensureRoomLevel(room)
    local levels = {}
    for _, info in ipairs(levelsForMode(room.mode)) do levels[#levels+1] = { path = info.path, name = info.name } end
    local cur = room.level and levelInfo(room.level)
    local payload = {
        id=room.id, name=room.name, isPublic=room.isPublic,
        hasPassword=(room.password~=""), maxPlayers=room.maxPlayers,
        state=room.state, adminId=room.adminId, players=playerList,
        mode=room.mode, level=room.level, levelName=cur and cur.name or nil, levels=levels,
    }
    for _, pid in ipairs(room.playerIds) do
        local c = findClientById(pid)
        if c then c:send("room_update", payload) end
    end
end

-- kind: 'join' | 'leave' | 'kick' | 'ban' | 'admin' | 'game' (el cliente lo colorea)
local function announceToRoom(room, msg, kind)
    for _, pid in ipairs(room.playerIds) do
        local c = findClientById(pid)
        if c then c:send("room_announce", { msg=msg, kind=kind or 'info' }) end
    end
end

local function buildPublicRoomList()
    local list = {}
    for _, room in pairs(rooms) do
        table.insert(list, {
            id=room.id, name=room.name,
            isPublic=room.isPublic,
            hasPassword=(room.password~=""),
            currentPlayers=#room.playerIds,
            maxPlayers=room.maxPlayers,
            state=room.state,
        })
    end
    return list
end

-- Datos estáticos de la partida: se envían UNA vez (fiable) al empezar, así
-- los snapshots no repiten nombres, colores ni IDs largos.
local function sendGameInit(room)
    local sim = room.sim
    local roster = {}
    for _, pid in ipairs(room.playerIds) do
        local c  = findClientById(pid)
        local ps = sim.playerSims[pid]
        if c and ps then
            table.insert(roster, { idx=ps.idx, id=pid, name=players[c].name,
                                   color=players[c].color or {1,1,1} })
        end
    end
    for _, pid in ipairs(room.playerIds) do
        local c  = findClientById(pid)
        local ps = sim.playerSims[pid]
        if c and ps then
            c:send("game_init", {
                tick     = sim.tick,
                idx      = ps.idx,
                roster   = roster,
                own      = Protocol.packOwnState(ps.pa),
                tickRate = Protocol.TICK_RATE,
                snapEvery= SNAPSHOT_EVERY,
                mode     = room.mode,
                level    = sim.levelRaw,        -- el nivel viaja al cliente
            })
        end
    end
end

-- Eventos de juego (puntos, sonidos, game over...): canal fiable, marcados con
-- el tick en que ocurrieron para que el cliente los sincronice con lo que ve.
local function flushEvents(room)
    local sim = room.sim
    if not sim or #sim.events == 0 then return end
    local payload = { list = sim.events }
    for _, pid in ipairs(room.playerIds) do
        local c = findClientById(pid)
        if c then c:send("ev", payload) end
    end
    sim.events = {}
end

-- Snapshot compacto (no fiable, canal de estado). La parte común se arma una
-- vez; cada cliente recibe además su estado completo y el último input
-- procesado (`a`) para reconciliar su predicción.
local function broadcastSnapshot(room)
    local sim = room.sim
    if not sim then return end

    local plist = {}
    for _, pid in ipairs(room.playerIds) do
        local ps = sim.playerSims[pid]
        if ps then
            local pa = ps.pa
            local flags = 0
            if pa.dying       then flags = flags + Protocol.PF_DYING     end
            if ps.isSpectator then flags = flags + Protocol.PF_SPECTATOR end
            if ps.finished    then flags = flags + Protocol.PF_FINISHED  end
            table.insert(plist, {
                ps.idx, round(pa.x), round(pa.y), pa.facing, pa.frame, flags,
                pa.lives, pa.hp, ps.score, Protocol.drownCode(pa.drownPhase),
                round(math.max(0, 1 - pa.drownTimer / DROWN_TOTAL) * 100),
                ps.place or 0,
            })
        end
    end

    local elist = {}
    for i, e in ipairs(sim.enemies) do
        local entry = {
            round(e.x), round(e.y), e.facing, e.state, e.frame, e.alive,
            round((e.deadTimer or 0) * 100), round((e.breatheT or 0) * 100),
        }
        -- Datos propios del tipo (p. ej. pincho y sprite del Crabby)
        local extra = e:netPack()
        if extra then for k, v in ipairs(extra) do entry[8 + k] = v end end
        elist[i] = entry
    end

    -- Burbujas de oxígeno con ID estable para interpolarlas en el cliente
    local vb = {}
    for vi, vent in ipairs(sim.level.vents) do
        local flat = {}
        for _, b in ipairs(vent.oxyBubbles) do
            if b.alive then
                if not b.nid then sim.nextBubbleId = sim.nextBubbleId + 1; b.nid = sim.nextBubbleId end
                flat[#flat+1] = b.nid; flat[#flat+1] = round(b.x); flat[#flat+1] = round(b.y)
            end
        end
        vb[vi] = flat
    end

    local lt = round(sim.levelTime * 100)
    local md = sim.mode.hud(sim.match)
    for _, pid in ipairs(room.playerIds) do
        local c  = findClientById(pid)
        local ps = sim.playerSims[pid]
        if c then
            local snap = { t=sim.tick, lt=lt, p=plist, e=elist, vb=vb, md=md }
            if ps and not ps.isSpectator then
                snap.a  = ps.lastProcSeq
                snap.o  = Protocol.packOwnState(ps.pa)
                snap.bs = ps.bounceSeq
            end
            sendState(c, "s", snap)
        end
    end
end

local function endGame(room, reason)
    room.state = "WAITING"
    room.sim   = nil
    for _, pid in ipairs(room.playerIds) do
        local c = findClientById(pid)
        if c then players[c].isReady = false end
    end
    broadcastRoomUpdate(room)
    log("Partida terminada en sala '" .. room.name .. "' — " .. reason .. ".")
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Gestión de salas
-- ─────────────────────────────────────────────────────────────────────────────

local function removePlayerFromRoom(player, room, silent)
    for i, pid in ipairs(room.playerIds) do
        if pid == player.id then table.remove(room.playerIds, i); break end
    end
    player.isReady = false
    player.roomId  = nil
    player.color   = nil

    -- Eliminar simulación del jugador si hay partida en curso
    if room.sim then room.sim.playerSims[player.id] = nil end

    if not silent then
        announceToRoom(room, player.name .. " ha salido de la sala.", 'leave')
    end

    if #room.playerIds == 0 then
        rooms[room.id] = nil
        log("Sala '" .. room.name .. "' eliminada (vacia).")
        return true
    end

    if room.adminId == player.id then
        room.adminId = room.playerIds[1]
        local newName = findPlayerNameById(room.adminId)
        announceToRoom(room, newName .. " es el nuevo host.", 'admin')
        log("Nuevo admin de '" .. room.name .. "': " .. newName)
    end

    broadcastRoomUpdate(room)
    return false
end

-- Expulsa una conexión (abuso, versión, timeout). La desconexión es "graceful":
-- ENet dispara luego el evento disconnect y ahí se limpia `players`.
local function dropClient(client, reason)
    local p = players[client]
    if not p or p.kicked then return end
    p.kicked = true
    log("Expulsando " .. (p.name or peerIP(client)) .. ": " .. reason)
    if p.roomId and rooms[p.roomId] then
        removePlayerFromRoom(p, rooms[p.roomId], false)
    end
    pcall(function() client.connection:disconnect(0) end)
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Eventos de red (todos pasan por `on`, que aplica rate limit y exige login)
-- ─────────────────────────────────────────────────────────────────────────────

local function rateOk(p, client)
    local now = love.timer.getTime()
    p.tokens = math.min(MSG_BURST, p.tokens + (now - p.lastT) * MSG_RATE)
    p.lastT  = now
    if now - p.dropWindow > 10 then p.dropWindow = now; p.dropped = 0 end
    if p.tokens < 1 then
        p.dropped = p.dropped + 1
        if p.dropped > FLOOD_LIMIT then dropClient(client, "flood de mensajes") end
        return false
    end
    p.tokens = p.tokens - 1
    return true
end

local function on(event, handler, allowAnonymous)
    server:on(event, function(data, client)
        local p = players[client]
        if not p or p.kicked then return end
        if not rateOk(p, client) then return end
        if not p.verified and not allowAnonymous then return end
        handler(data, client, p)
    end)
end

server.onInvalidPacket = function(client, size)
    local p = client and players[client]
    if not p or p.kicked then return end
    p.invalid = p.invalid + 1
    if p.invalid >= INVALID_LIMIT then dropClient(client, "paquetes malformados") end
end

server.onHandlerError = function(client, eventName, err)
    log("ERROR en handler '" .. tostring(eventName) .. "': " .. tostring(err))
end

log("FlappyMonster Online Server (autoritativo) — Puerto " .. PORT
    .. " — protocolo v" .. Protocol.VERSION)

server:on("connect", function(data, client)
    local ip  = peerIP(client)
    local now = love.timer.getTime()
    players[client] = {
        id=nil, name=nil, verified=false, roomId=nil, isReady=false, color=nil,
        ip=ip, tokens=MSG_BURST, lastT=now, dropped=0, dropWindow=now, invalid=0,
        kicked=false, connectedAt=now, joinFails=0, joinLockUntil=0,
    }
    -- Detectar desconexiones en 3-10 s en vez de ~30 s
    pcall(function() client.connection:timeout(32, 3000, 10000) end)

    local n = 0
    for _, p in pairs(players) do if p.ip == ip and not p.kicked then n = n + 1 end end
    if n > MAX_CONN_PER_IP then
        dropClient(client, "demasiadas conexiones desde " .. ip)
        return
    end
    log("Cliente conectando desde " .. ip)
end)

-- Handshake: versión de protocolo + nickname.
on("hello", function(data, client, p)
    if p.verified then return end
    if type(data) ~= "table" or data.v ~= Protocol.VERSION then
        client:send("login_error", { msg="Version incompatible. Actualiza el juego." })
        return
    end
    local name = Protocol.sanitizeName(data.name)
    if not name then
        client:send("login_error", { msg="Nombre invalido." }); return
    end
    local lname = name:lower()
    for _, other in pairs(players) do
        if other.verified and not other.kicked and other.name:lower() == lname then
            client:send("login_error", { msg="Ese nombre ya esta en uso." }); return
        end
    end
    p.id, p.name, p.verified = newPlayerId(), name, true
    log("Registrado: '" .. name .. "' (" .. p.ip .. ")")
    client:send("login_success", { name=name, id=p.id })
end, true)

-- Clientes antiguos (protocolo v1): avisar en su pantalla de login.
on("set_nickname", function(data, client, p)
    client:send("room_error", { msg="Versión desactualizada. Actualiza el juego." })
end, true)

on("get_rooms", function(data, client, p)
    client:send("room_list", buildPublicRoomList())
end)

on("create_room", function(data, client, player)
    if type(data) ~= "table" then return end
    if player.roomId then client:send("room_error",{msg="Ya estás en una sala."}); return end
    local name = Protocol.sanitizeName(data.name, ROOM_NAME_MAX) or ("Sala de " .. player.name)
    local isPublic   = (data.isPublic ~= false)
    local password   = cleanText(data.password, PASSWORD_MAX)
    local maxPlayers = tonumber(data.maxPlayers) or 4
    if not isInt(maxPlayers, 1, 8) then client:send("room_error",{msg="Máximo de jugadores: 1-8."}); return end
    local roomId = newRoomId()
    rooms[roomId] = { id=roomId, name=name, isPublic=isPublic, password=password,
                      maxPlayers=maxPlayers, playerIds={player.id},
                      adminId=player.id, state="WAITING", bannedNames={}, bannedIPs={}, sim=nil,
                      mode=Modes.DEFAULT, level=nil }
    player.roomId  = roomId
    player.isReady = false
    player.color   = PLAYER_COLORS[1]
    log("Sala '" .. name .. "' creada por " .. player.name)
    broadcastRoomUpdate(rooms[roomId])
end)

on("join_room", function(data, client, player)
    if type(data) ~= "table" then return end
    if player.roomId then client:send("room_error",{msg="Ya estás en una sala."}); return end
    local now = love.timer.getTime()
    if now < player.joinLockUntil then
        client:send("room_error",{msg="Demasiados intentos. Espera unos segundos."}); return
    end
    local room = rooms[tostring(data.id or ""):sub(1, 12)]
    if not room then client:send("room_error",{msg="Sala no encontrada."}); return end
    if room.state ~= "WAITING" then client:send("room_error",{msg="Esa sala ya está en partida."}); return end
    if #room.playerIds >= room.maxPlayers then client:send("room_error",{msg="La sala está llena."}); return end
    if room.bannedNames[player.name:lower()] or room.bannedIPs[player.ip] then
        client:send("room_error",{ msg = "El host de esta sala te baneó. No puedes volver a entrar.",
                                   kind = "banned", room = room.name }); return
    end
    if room.password ~= "" and room.password ~= cleanText(data.password, PASSWORD_MAX) then
        player.joinFails = player.joinFails + 1
        if player.joinFails >= JOIN_FAIL_MAX then
            player.joinFails = 0
            player.joinLockUntil = now + JOIN_FAIL_LOCK
            log(player.name .. " bloqueado " .. JOIN_FAIL_LOCK .. "s por contrasenas erroneas")
        end
        client:send("room_error",{msg="Contraseña incorrecta."}); return
    end
    player.joinFails = 0
    table.insert(room.playerIds, player.id)
    player.roomId  = room.id
    player.isReady = false
    player.color   = PLAYER_COLORS[#room.playerIds] or {1,1,1}
    log(player.name .. " se unio a '" .. room.name .. "'")
    broadcastRoomUpdate(room)
    announceToRoom(room, player.name .. " se ha unido.", 'join')
end)

on("leave_room", function(data, client, player)
    if not player.roomId then return end
    local room = rooms[player.roomId]
    if not room then player.roomId=nil; return end
    removePlayerFromRoom(player, room, false)
    client:send("room_left", {})
end)

on("set_ready", function(data, client, player)
    if type(data) ~= "table" or not player.roomId then return end
    local room = rooms[player.roomId]
    if not room or room.state ~= "WAITING" then return end
    player.isReady = (data.ready == true)
    log(player.name .. (player.isReady and " → LISTO" or " → no listo"))
    broadcastRoomUpdate(room)
end)

on("start_game", function(data, client, player)
    if not player.roomId then return end
    local room = rooms[player.roomId]
    if not room then return end
    if room.adminId ~= player.id then client:send("room_error",{msg="Solo el host puede iniciar la partida."}); return end
    if room.state == "IN_GAME"   then client:send("room_error",{msg="La partida ya está en curso."}); return end
    if #room.playerIds < 2       then client:send("room_error",{msg="Se necesitan al menos 2 jugadores para empezar."}); return end

    for _, pid in ipairs(room.playerIds) do
        local c = findClientById(pid)
        if c and not players[c].isReady then
            client:send("room_error",{msg="No todos los jugadores están listos."}); return
        end
    end

    -- Asignar colores
    for i, pid in ipairs(room.playerIds) do
        local c = findClientById(pid)
        if c then players[c].color = PLAYER_COLORS[i] or {1,1,1} end
    end

    scanLevels(true)
    ensureRoomLevel(room)
    if not room.level then
        client:send("room_error",{msg="No hay ningún mapa compatible con este modo."}); return
    end

    room.state = "IN_GAME"
    room.sim   = initRoomSim(room)

    log("Partida iniciada en '" .. room.name .. "'!")
    announceToRoom(room, "¡La partida ha comenzado!", 'game')
    broadcastRoomUpdate(room)   -- el cliente cambia a OnlineAdventureState...
    sendGameInit(room)          -- ...y recibe los datos iniciales (mismo canal, en orden)
end)

on("stop_game", function(data, client, player)
    if not player.roomId then return end
    local room = rooms[player.roomId]
    if not room then return end
    if room.adminId ~= player.id then client:send("room_error",{msg="Solo el host puede detener la partida."}); return end
    if room.state ~= "IN_GAME" then return end
    announceToRoom(room, "El host detuvo la partida.", 'game')
    endGame(room, "detenida por el admin")
end)

-- El host elige modo de juego y nivel (solo en la sala de espera)
local function adminRoom(client, player)
    local room = player.roomId and rooms[player.roomId]
    if not room then return nil end
    if room.adminId ~= player.id then client:send("room_error",{msg="Solo el host puede cambiar esto."}); return nil end
    if room.state ~= "WAITING" then return nil end
    return room
end

on("set_mode", function(data, client, player)
    if type(data) ~= "table" or type(data.mode) ~= "string" then return end
    local room = adminRoom(client, player)
    if not room or not Modes.get(data.mode) then return end
    room.mode = data.mode
    -- Nivel elegido junto al modo (menú del lobby); si no sirve, uno compatible
    local info = type(data.level) == "string" and levelInfo(data.level)
    if info and info.modes[room.mode] then room.level = info.path end
    ensureRoomLevel(room)
    log(player.name .. " cambio el modo a " .. Modes.get(room.mode).label)
    broadcastRoomUpdate(room)
end)

-- Catálogo de niveles con miniaturas (lo pide el menú de modos del lobby)
on("get_levels", function(data, client, player)
    local room = player.roomId and rooms[player.roomId]
    if not room then return end
    local list = {}
    for _, info in ipairs(scanLevels()) do
        local modes = {}
        for id in pairs(info.modes) do modes[#modes+1] = id end
        list[#list+1] = { path = info.path, name = info.name, w = info.w, h = info.h,
                          enemies = info.enemies, finish = info.finish, modes = modes,
                          preview = info.preview }
    end
    client:send("level_catalog", { levels = list })
end)

on("set_level", function(data, client, player)
    if type(data) ~= "table" or type(data.level) ~= "string" then return end
    local room = adminRoom(client, player)
    if not room then return end
    local info = levelInfo(data.level)
    if not info or not info.modes[room.mode] then
        client:send("room_error",{msg="Ese mapa no sirve para este modo."}); return
    end
    room.level = info.path
    broadcastRoomUpdate(room)
end)

local function adminTarget(data, client, admin, verb)
    if type(data) ~= "table" or not admin.roomId then return end
    local room = rooms[admin.roomId]
    if not room or room.adminId ~= admin.id then client:send("room_error",{msg="No eres el host de la sala."}); return end
    local targetId = tostring(data.playerId or ""):sub(1, 32)
    if targetId == admin.id then client:send("room_error",{msg="No puedes " .. verb .. "te."}); return end
    local tc = findClientById(targetId)
    if not tc or players[tc].roomId ~= room.id then client:send("room_error",{msg="Ese jugador ya no está en la sala."}); return end
    return room, tc
end

on("kick_player", function(data, client, admin)
    local room, tc = adminTarget(data, client, admin, "kickear")
    if not room then return end
    local tname = players[tc].name
    tc:send("kicked", { msg = admin.name .. " (host) te expulsó de la sala.", room = room.name, by = admin.name })
    removePlayerFromRoom(players[tc], room, true)
    announceToRoom(room, tname .. " fue expulsado por el host.", 'kick')
    log(admin.name .. " kickeo a " .. tname)
end)

on("ban_player", function(data, client, admin)
    local room, tc = adminTarget(data, client, admin, "banear")
    if not room then return end
    local target = players[tc]
    local tname  = target.name
    -- Por nombre Y por IP: cambiarse el nick ya no evita el baneo.
    room.bannedNames[tname:lower()] = true
    room.bannedIPs[target.ip] = true
    tc:send("banned", { msg = admin.name .. " (host) te baneó de la sala. No podrás volver a entrar.",
                        room = room.name, by = admin.name })
    removePlayerFromRoom(target, room, true)
    announceToRoom(room, tname .. " fue baneado por el host.", 'ban')
    log(admin.name .. " baneo a " .. tname)
end)

-- Inputs numerados: { s = seq del primero, b = {bits, bits, ...} }.
-- Cada paquete repite los últimos inputs no confirmados, así una pérdida de
-- paquetes no pierde inputs. Los ya recibidos se ignoran.
on("in", function(data, client, player)
    if type(data) ~= "table" or not player.roomId then return end
    local room = rooms[player.roomId]
    if not room or room.state ~= "IN_GAME" or not room.sim then return end
    local ps = room.sim.playerSims[player.id]
    if not ps or ps.isSpectator then return end

    local first, list = data.s, data.b
    if not isInt(first, 1, 2^31) or type(list) ~= "table" then return end
    -- Tick del mundo que el cliente tenía en pantalla al generar el último input
    local view = data.v
    if view ~= nil and not isInt(view, 0, 2^31) then return end
    local n = #list
    if n < 1 or n > Protocol.INPUT_REDUNDANCY * 2 then return end
    if first + n - 1 > ps.lastProcSeq + MAX_SEQ_AHEAD then return end   -- seq falso

    for i = 1, n do
        local bits = list[i]
        if not isInt(bits, 0, Protocol.IN_MAX) then return end
    end
    for i = 1, n do
        local seq = first + i - 1
        if seq > ps.lastRecvSeq then
            -- inputs anteriores del paquete se vieron ~1 tick antes cada uno
            table.insert(ps.queue, { seq=seq, bits=list[i], v = view and (view - (n - i)) or nil })
            ps.lastRecvSeq = seq
        end
    end
end)

on("close_room", function(data, client, admin)
    if not admin.roomId then return end
    local room = rooms[admin.roomId]
    if not room or room.adminId ~= admin.id then
        client:send("room_error",{msg="No eres el host de la sala."}); return
    end
    log("Sala '" .. room.name .. "' cerrada por " .. admin.name)
    for _, pid in ipairs(room.playerIds) do
        local c = findClientById(pid)
        if c then
            c:send("room_closed", { msg = admin.name .. " (host) cerró la sala.", room = room.name, by = admin.name })
            players[c].roomId=nil; players[c].isReady=false; players[c].color=nil
        end
    end
    rooms[room.id] = nil
end)

server:on("disconnect", function(data, client)
    local player = players[client]
    if not player then return end
    log("Desconectado: '" .. (player.name or player.ip) .. "'")
    if player.roomId then
        local room = rooms[player.roomId]
        if room then removePlayerFromRoom(player, room, false) end
    end
    players[client] = nil
end)


-- ─────────────────────────────────────────────────────────────────────────────
--  UI del servidor (consola visual)
-- ─────────────────────────────────────────────────────────────────────────────

function love.load()
    if not HEADLESS then
        love.window.setTitle("FlappyMonster Online Server (autoritativo) — Puerto " .. PORT)
        love.window.setMode(860, 640)
    end

    -- Acceder a los assets del juego via io.open (love.filesystem no puede montar rutas OS arbitrarias)
    -- (package.path ya se extendió con parentDir al inicio del archivo)
    log("Directorio del juego: " .. parentDir)

    -- Override love.filesystem.read para leer assets (JSON de niveles, etc.)
    local _lfsRead = love.filesystem.read
    love.filesystem.read = function(name, size)
        if love.filesystem.getInfo(name) then return _lfsRead(name, size) end
        local f = io.open(parentDir .. "/" .. name, "rb")
        if f then
            local data = size and f:read(size) or f:read("*a")
            f:close()
            return data, #data
        end
        return _lfsRead(name, size)
    end

    -- 3. Override love.graphics.newImage solo si graphics está disponible
    if not HEADLESS then
        local _lgNewImage = love.graphics.newImage
        love.graphics.newImage = function(filename, settings)
            if type(filename) ~= 'string' or love.filesystem.getInfo(filename) then
                return _lgNewImage(filename, settings)
            end
            local f = io.open(parentDir .. "/" .. filename, "rb")
            if f then
                local bytes = f:read("*a"); f:close()
                local fd = love.filesystem.newFileData(bytes, filename)
                return _lgNewImage(fd, settings)
            end
            return _lgNewImage(filename, settings)
        end
    else
        -- En modo headless, love.graphics no existe.
        -- Crear un stub para que los require de entidades no exploten
        -- al llamar love.graphics.newImage durante la carga.
        -- IMPORTANTE: usamos love.image.newImageData para leer las dimensiones
        -- reales de cada sprite, así la física/colisiones funcionan correctamente.
        love.graphics = {
            newImage = function(filename, settings)
                -- Intentar obtener dimensiones reales del archivo de imagen
                local w, h = 1, 1
                local imgData = nil

                -- Intentar cargar via love.filesystem primero
                if type(filename) == "string" then
                    local ok, data = pcall(function()
                        -- love.filesystem.read ya está parcheado para buscar en parentDir
                        local bytes, sz = love.filesystem.read(filename)
                        if bytes then
                            local fd = love.filesystem.newFileData(bytes, filename)
                            return love.image.newImageData(fd)
                        end
                        return nil
                    end)
                    if ok and data then imgData = data end
                elseif type(filename) == "userdata" then
                    -- FileData pasado directamente
                    local ok, data = pcall(love.image.newImageData, filename)
                    if ok and data then imgData = data end
                end

                if imgData then
                    w, h = imgData:getDimensions()
                end

                return {
                    getWidth      = function() return w end,
                    getHeight     = function() return h end,
                    getDimensions = function() return w, h end,
                    setFilter     = function() end,
                    setWrap       = function() end,
                    typeOf        = function(_, t) return t == "Image" or t == "Texture" or t == "Object" end,
                }
            end,
            newQuad = function(x, y, qw, qh, sw, sh)
                return {
                    getViewport = function() return x, y, qw, qh end,
                    setViewport = function() end,
                    typeOf      = function(_, t) return t == "Quad" or t == "Object" end,
                }
            end,
            newFont       = function() return { getWidth=function() return 0 end, getHeight=function() return 0 end, setFilter=function() end } end,
            newSpriteBatch = function() return { add=function() end, set=function() end, clear=function() end, flush=function() end, bind=function() end, getCount=function() return 0 end } end,
            newCanvas     = function() return { renderTo=function() end, getDimensions=function() return 1,1 end } end,
            setColor      = function() end,
            setBackgroundColor = function() end,
            getDimensions = function() return 860, 640 end,
            getWidth      = function() return 860 end,
            getHeight     = function() return 640 end,
            rectangle     = function() end,
            line          = function() end,
            print         = function() end,
            draw          = function() end,
            push          = function() end,
            pop           = function() end,
            translate     = function() end,
            scale         = function() end,
            origin        = function() end,
            clear         = function() end,
            setCanvas     = function() end,
            getCanvas     = function() end,
            reset         = function() end,
            setFont       = function() end,
            setDefaultFilter = function() end,
            setLineWidth  = function() end,
            isActive      = function() return false end,
            isCreated     = function() return false end,
            present       = function() end,
            setScissor    = function() end,
            getScissor    = function() return 0,0,0,0 end,
            setBlendMode  = function() end,
            getBlendMode  = function() return "alpha" end,
            setShader     = function() end,
            getShader     = function() return nil end,
            getStats      = function() return {} end,
            setLineStyle  = function() end,
            getFont       = function() return { getWidth=function() return 0 end, getHeight=function() return 0 end } end,
            getBackgroundColor = function() return 0,0,0,1 end,
            getColor      = function() return 1,1,1,1 end,
        }
    end

    -- Cargar constantes del juego
    require 'settings'

    -- Cargar entidades (en modo ventana usa graphics real; en headless usa stubs)
    Level           = require 'src/world/Level'
    PlayerAdventure = require 'src/entities/PlayerAdventure'
    Entities        = require 'src/world/Entities'

    log("Entidades de simulacion cargadas.")
    if HEADLESS then
        log("Modo HEADLESS activo — sin ventana grafica.")
    end
end

-- Solo definir love.draw si hay gráficos disponibles
if not HEADLESS then
function love.draw()
    local W, H = love.graphics.getDimensions()
    love.graphics.setBackgroundColor(0.07, 0.09, 0.11)

    love.graphics.setColor(0.12, 0.15, 0.18)
    love.graphics.rectangle("fill", 0, 0, W, 28)
    love.graphics.setColor(0.95, 0.80, 0.15)
    love.graphics.print(
        "  FLAPPYMONSTER SERVER (AUTORITATIVO)   Puerto:" .. PORT ..
        "   Jugadores:" .. countPlayers() ..
        "   Salas:" .. countRooms(), 8, 6)
    love.graphics.setColor(0.25, 0.30, 0.35)
    love.graphics.line(0, 28, W, 28)

    local y = 36
    if countRooms() == 0 then
        love.graphics.setColor(0.40, 0.42, 0.45)
        love.graphics.print("  (sin salas activas)", 10, y); y = y + 20
    else
        for _, room in pairs(rooms) do
            if y > 370 then break end
            love.graphics.setColor(room.state=="IN_GAME" and {1,0.75,0.15} or {0.25,1,0.50})
            love.graphics.print(
                string.format("  [%s] %-22s %s  %d/%d  [%s]%s",
                    room.id, room.name,
                    room.isPublic and "Publica" or "Privada",
                    #room.playerIds, room.maxPlayers, room.state,
                    room.sim and "  SIM" or ""), 10, y)
            y = y + 18
            for _, pid in ipairs(room.playerIds) do
                local c = findClientById(pid)
                if c then
                    local p    = players[c]
                    local atag = (pid == room.adminId) and "[A]" or "   "
                    local rtag = p.isReady and "[LISTO]" or "[     ]"
                    local spec = ""
                    if room.sim and room.sim.playerSims[pid] then
                        spec = room.sim.playerSims[pid].isSpectator and "[SPEC]" or ""
                    end
                    local col = p.color or {0.65, 0.70, 0.80}
                    love.graphics.setColor(col[1], col[2], col[3])
                    love.graphics.print(
                        string.format("       %s  %-16s  %s %s", atag, p.name, rtag, spec), 10, y)
                    y = y + 17
                end
            end
            y = y + 6
        end
    end

    local logTop = H - (LOG_MAX * 16) - 26
    if logTop < y + 6 then logTop = y + 6 end
    love.graphics.setColor(0.25, 0.30, 0.35); love.graphics.line(0, logTop, W, logTop)
    love.graphics.setColor(0.95, 0.80, 0.15); love.graphics.print("  LOG", 8, logTop+4)
    love.graphics.setColor(0.25, 0.30, 0.35); love.graphics.line(0, logTop+20, W, logTop+20)
    love.graphics.setColor(0.55, 0.75, 0.55)
    local ly = logTop + 24
    for _, entry in ipairs(serverLog) do
        love.graphics.print("  > " .. entry, 10, ly); ly = ly + 16
        if ly > H - 4 then break end
    end
    love.graphics.setColor(1, 1, 1)
end
end -- if not HEADLESS

-- ─────────────────────────────────────────────────────────────────────────────
--  Loop principal
-- ─────────────────────────────────────────────────────────────────────────────

-- Expulsar conexiones que no completan el handshake a tiempo.
local function checkHelloTimeouts()
    local now = love.timer.getTime()
    for c, p in pairs(players) do
        if not p.verified and not p.kicked and now - p.connectedAt > HELLO_TIMEOUT then
            dropClient(c, "sin handshake")
        end
    end
end

function love.update(dt)
    server:update()
    checkHelloTimeouts()

    -- Paso fijo: la simulación avanza exactamente TICK_DT por tick sin importar
    -- los FPS del servidor (headless corre a ~1000 FPS, con ventana a 60).
    simAccum = simAccum + dt
    local ticks = 0
    while simAccum >= TICK_DT and ticks < MAX_FRAME_TICKS do
        simAccum = simAccum - TICK_DT
        ticks = ticks + 1
        for _, room in pairs(rooms) do
            if room.state == "IN_GAME" and room.sim then
                stepRoom(room)
                local sim = room.sim
                if sim.ended or sim.tick % SNAPSHOT_EVERY == 0 then
                    broadcastSnapshot(room)
                    flushEvents(room)
                end
                if sim.ended then endGame(room, "ronda terminada (" .. sim.ended .. ")") end
            end
        end
    end
    -- El servidor se atrasó demasiado (freeze): descartar en vez de acelerar.
    if ticks >= MAX_FRAME_TICKS then simAccum = 0 end

    pingTimer = pingTimer + dt
    if pingTimer >= PING_TICK then
        pingTimer = 0
        for _, room in pairs(rooms) do
            if #room.playerIds > 0 then broadcastRoomUpdate(room) end
        end
    end
end
