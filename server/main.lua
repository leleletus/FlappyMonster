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
local NameFilter = require 'src/network/NameFilter'
local Modes    = require 'src/world/modes/Modes'
local Lang     = require 'src/core/Lang'
local json     = require 'libs/json'
local Updates  = require 'updates'            -- server/updates.lua
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
local UPDATE_IDLE     = 20    -- s sin pedir nada un cliente que se actualiza (ver updates.lua)
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
local NEAR_X, NEAR_Y  = Protocol.NEAR_X, Protocol.NEAR_Y   -- px: entidades que se le mandan a cada jugador (la vista es 1280x720 a lo sumo)
local MAX_SEQ_AHEAD   = 180   -- un seq más adelantado que esto: hubo un corte, se salta hasta él
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

-- El SONIDO del servidor: cada Sound.play se apunta como evento (S.soundEvents) con quién lo causó (S.soundOwner) y de
-- dónde sale (S.emitX / S.emitY); los clientes lo reproducen.
local S = {}                 -- (el estado que comparten las partes de server/srv/: ver abajo)

Sound = {
    play        = function(name, pitch)
        -- (los privados de un jugador no se mandan: su cliente ya los predijo)
        if name and not (S.soundOwner and Protocol.PRIVATE_SOUNDS[name]) then
            -- El tono viaja con 2 decimales (p. ej. los sonidos graves del jefe espejo)
            pitch = (pitch and pitch ~= 1) and math.floor(pitch * 100 + 0.5) / 100 or nil
            local owner = (not Protocol.SHARED_SOUNDS[name]) and S.soundOwner or nil
            table.insert(S.soundEvents, { sound = name, playerId = owner, pitch = pitch,
                                         x = S.emitX and math.floor(S.emitX + 0.5), y = S.emitY and math.floor(S.emitY + 0.5) })
        end
    end,
    -- Emisor del sonido: cada cliente atenúa según SU distancia (ver src/audio/Sound.lua)
    setEmitter   = function(x, y) S.emitX, S.emitY = x, y end,
    clearEmitter = function() S.emitX, S.emitY = nil, nil end,
    getEmitter   = function() return S.emitX, S.emitY end,
    withEmitter  = function(x, y, fn, ...)
        local ox, oy = S.emitX, S.emitY
        S.emitX, S.emitY = x, y
        local ok, err = pcall(fn, ...)
        S.emitX, S.emitY = ox, oy
        if not ok then error(err, 0) end
    end,
    -- (un sonido en un punto del mundo: como play con ese emisor — la ayuda del jefe, src/…/directors/bossdrops.lua)
    playAt       = function(name, x, y, pitch)
        local ox, oy = S.emitX, S.emitY
        S.emitX, S.emitY = x, y
        Sound.play(name, pitch)
        S.emitX, S.emitY = ox, oy
    end,
    setListener  = function() end,
    isPlaying    = function() return false end,
    stopTracked = function() end,
    playTracked = function() end,
    stopMusic   = function() end,
    playMusic   = function() end,
}

-- Input stub: se carga con el input del tick antes de cada pa:update().
Input = Protocol.newInputStub()
local _inp = Input.state

-- Constantes que deben coincidir con PlayerAdventure.lua
local DROWN_TOTAL     = 20
local LEVELS_DIR      = 'assets/levels'
local DEFAULT_LEVEL   = 'assets/levels/nivel01.json'
local PLAYER_LIVES    = tonumber(os.getenv('FM_TEST_LIVES')) or 3      -- (FM_TEST_*: solo los arneses, tools/tests/run.sh)
local TEST_BOSSDMG    = tonumber(os.getenv('FM_TEST_BOSSDMG'))         -- (cada tantos s, 1 de daño a los jefes que se dejen)
local SPAWN_STAGGER   = 48   -- px de separación horizontal entre jugadores al spawn

-- ─────────────────────────────────────────────────────────────────────────────
--  Estructuras de datos de red
-- ─────────────────────────────────────────────────────────────────────────────

local server = sock.newServer("*", PORT, MAX_PEERS, Protocol.CHANNELS)
server:setSerialization(bitser.dumps, bitser.loads)

-- players[clientObj] = { id, name, verified, roomId, isReady, color, ip,
--                        tokens, lastT, dropped, dropWindow, invalid, kicked,
--                        connectedAt }
local players    = {}
-- rooms[roomId]    = { id, name, isPublic, password, maxPlayers,
--                      playerIds, adminId, state, bannedNames, bannedIPs,
--                      sim (o nil si no está en partida) }
local rooms      = {}

local serverLog  = {}
local pingTimer  = 0
local simAccum   = 0


-- ─────────────────────────────────────────────────────────────────────────────
--  Las PARTES (server/srv/): comparten el estado y las funciones a través de S
-- ─────────────────────────────────────────────────────────────────────────────
S.soundEvents, S.soundOwner, S.emitX, S.emitY, S.currentSim = {}, nil, nil, nil, nil
S.bitser, S.HEADLESS, S.parentDir, S.Protocol, S.NameFilter, S.Modes = bitser, HEADLESS, parentDir, Protocol, NameFilter, Modes
S.Lang, S.json, S.Updates, S.TICK_DT, S.SNAPSHOT_EVERY, S.band = Lang, json, Updates, TICK_DT, SNAPSHOT_EVERY, band
S.round, S.PORT, S.MAX_PEERS, S.PING_TICK, S.LOG_MAX, S.MSG_RATE = round, PORT, MAX_PEERS, PING_TICK, LOG_MAX, MSG_RATE
S.MSG_BURST, S.FLOOD_LIMIT, S.INVALID_LIMIT, S.MAX_CONN_PER_IP, S.HELLO_TIMEOUT, S.UPDATE_IDLE = MSG_BURST, FLOOD_LIMIT, INVALID_LIMIT, MAX_CONN_PER_IP, HELLO_TIMEOUT, UPDATE_IDLE
S.JOIN_FAIL_MAX, S.JOIN_FAIL_LOCK, S.PASSWORD_MAX, S.ROOM_NAME_MAX, S.MAX_BUDGET, S.MAX_STEPS_TICK = JOIN_FAIL_MAX, JOIN_FAIL_LOCK, PASSWORD_MAX, ROOM_NAME_MAX, MAX_BUDGET, MAX_STEPS_TICK
S.TARGET_QUEUE, S.TRIM_AFTER, S.MAX_QUEUE, S.STARVE_TICKS, S.NEAR_X, S.NEAR_Y = TARGET_QUEUE, TRIM_AFTER, MAX_QUEUE, STARVE_TICKS, NEAR_X, NEAR_Y
S.MAX_SEQ_AHEAD, S.MAX_FRAME_TICKS, S.PLAYER_COLORS, S._inp, S.DROWN_TOTAL, S.LEVELS_DIR = MAX_SEQ_AHEAD, MAX_FRAME_TICKS, PLAYER_COLORS, _inp, DROWN_TOTAL, LEVELS_DIR
S.DEFAULT_LEVEL, S.PLAYER_LIVES, S.TEST_BOSSDMG, S.SPAWN_STAGGER, S.server = DEFAULT_LEVEL, PLAYER_LIVES, TEST_BOSSDMG, SPAWN_STAGGER, server
S.players, S.rooms, S.serverLog = players, rooms, serverLog
for _, part in ipairs({ 'util', 'catalog', 'sim', 'broadcast', 'lobby' }) do require('srv.' .. part)(S) end

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
    S.log("Directorio del juego: " .. parentDir)
    Updates.init(parentDir, S.log)                  -- actualizaciones automáticas (updates.lua)

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
    S.Level           = require 'src/world/level/Level'
    S.PlayerAdventure = require 'src/player/PlayerAdventure'
    -- Efectos visuales del jugador (ground pound, bloques rotos): el servidor
    -- no dibuja; los reenvía a los clientes para que pongan las partículas
    S.PlayerAdventure.fx = function(kind, x, y)
        if S.currentSim then
            S.pushEvent(S.currentSim, { type='fx', kind=kind, x=round(x), y=round(y), playerId=S.soundOwner })
        end
    end
    S.Entities        = require 'src/world/entities/Entities'
    S.BossZones       = require 'src/world/systems/BossZones'
    S.AutoScroll      = require 'src/world/systems/AutoScroll'
    S.StartCountdown  = require 'src/world/systems/StartCountdown'
    S.Floods          = require 'src/world/systems/Floods'
    S.PointAreas      = require 'src/world/systems/PointAreas'
    S.Push            = require 'src/world/systems/Push'
    S.Carry           = require 'src/world/systems/Carry'
    S.Difficulty      = require 'src/core/Difficulty'
    S.Sim             = require 'src/world/systems/Sim'
    -- Lo que un jefe le hace a un jugador (daño, muerte) suena como suyo:
    -- su cliente lo reproduce al ver bajar su vida en la reconciliación
    S.PlayerAdventure.soundOwner = function(pa, fn)
        local prev, px, py = S.soundOwner, S.emitX, S.emitY
        S.soundOwner = pa.netId
        S.emitX, S.emitY = pa.x, pa.y
        local ok, err = pcall(fn)
        S.soundOwner, S.emitX, S.emitY = prev, px, py
        if not ok then error(err, 0) end
    end
    -- Lo que hace un jefe al recibir un golpe: para todos, también para quien se lo dio (Interactions.hit)
    S.Entities.interactions.asWorld = function(fn, ...)
        local prev = S.soundOwner
        S.soundOwner = nil
        local ok, err = pcall(fn, ...)
        S.soundOwner = prev
        if not ok then error(err, 0) end
    end
    -- Efectos de las entidades (pinchos que se clavan...): para todos
    require('src/world/entities/base/Entity').fx = function(kind, x, y, opts)
        if S.currentSim then
            S.pushEvent(S.currentSim, { type='fx', kind=kind, x=round(x), y=round(y), tile=opts and opts.tile or nil })
        end
    end

    S.log("Entidades de simulacion cargadas.")
    if HEADLESS then
        S.log("Modo HEADLESS activo — sin ventana grafica.")
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
        "   Jugadores:" .. S.countPlayers() ..
        "   Salas:" .. S.countRooms(), 8, 6)
    love.graphics.setColor(0.25, 0.30, 0.35)
    love.graphics.line(0, 28, W, 28)

    local y = 36
    if S.countRooms() == 0 then
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
                local c = S.findClientById(pid)
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
        -- (quien se está actualizando no se identifica: basta con que siga pidiendo)
        local since = p.updT and (now - p.updT > UPDATE_IDLE) or (not p.updT and now - p.connectedAt > HELLO_TIMEOUT)
        if not p.verified and not p.kicked and since then
            S.dropClient(c, p.updT and "actualización inactiva" or "sin handshake")
        end
    end
end

-- FM_PERF=1: cada 10 s, lo que cuesta simular y mandar (docs/testing/performance.md): ms por paso de sala y por
-- foto, KB de Lua creados por paso (subidas del contador: aproximado) y memoria
-- FM_PERF=2: además, la BASURA POR FUNCIÓN (tools/tests/lib/garbage_profile.lua; con el recolector parado mientras
-- se simula y se manda: las cifras son exactas, el rendimiento no)
local PERF = os.getenv('FM_PERF') and { t = 0, steps = 0, stepT = 0, snaps = 0, snapT = 0, alloc = 0 } or nil
PERF_SNAP = PERF and { max = 0, sum = 0, n = 0, big = 0 } or nil
local GPROF
local function perfAlloc(k0)
    local d = collectgarbage('count') - k0
    if d > 0 then PERF.alloc = PERF.alloc + d end
end

-- Un paso de una sala (simular, y cada SNAPSHOT_EVERY mandar la foto y los eventos)
local function stepAndSend(room)
    if GPROF then collectgarbage('stop') end
    local t0, k0 = PERF and love.timer.getTime(), PERF and collectgarbage('count')
    S.stepRoom(room)
    if PERF then
        PERF.steps, PERF.stepT = PERF.steps + 1, PERF.stepT + love.timer.getTime() - t0
        perfAlloc(k0)
    end
    local sim = room.sim
    if sim.ended or sim.tick % SNAPSHOT_EVERY == 0 then
        local t1, k1 = PERF and love.timer.getTime(), PERF and collectgarbage('count')
        S.broadcastSnapshot(room)
        S.flushEvents(room)
        if PERF then
            PERF.snaps, PERF.snapT = PERF.snaps + 1, PERF.snapT + love.timer.getTime() - t1
            perfAlloc(k1)
        end
    end
    if sim.ended then S.endGame(room, "ronda terminada (" .. sim.ended .. ")") end
end

-- Un error de Lua en UNA sala (un enemigo, un jefe, un modo...) no tira el servidor entero: se apunta con su traza,
-- esa partida se termina y las demás salas siguen
local function guarded(room, what, fn, ...)
    local ok, err = xpcall(fn, debug.traceback, ...)
    S.currentSim = nil                    -- (los efectos de fuera de un paso no van a la última sala simulada)
    if ok then return end
    S.log("ERROR en la sala '" .. tostring(room.name) .. "' (" .. what .. "): " .. tostring(err))
    if room.sim then pcall(S.endGame, room, "error del servidor") end
end

function love.update(dt)
    server:update()
    checkHelloTimeouts()
    Updates.update(dt)

    -- Paso fijo: la simulación avanza exactamente TICK_DT por tick sin importar
    -- los FPS del servidor (headless corre a ~1000 FPS, con ventana a 60).
    simAccum = simAccum + dt
    local ticks = 0
    while simAccum >= TICK_DT and ticks < MAX_FRAME_TICKS do
        simAccum = simAccum - TICK_DT
        ticks = ticks + 1
        for _, room in pairs(rooms) do
            if room.state == "IN_GAME" and room.sim then guarded(room, 'paso', stepAndSend, room) end
        end
    end
    -- El servidor se atrasó demasiado (freeze): descartar en vez de acelerar.
    if ticks >= MAX_FRAME_TICKS then simAccum = 0 end
    if PERF and os.getenv('FM_PERF') == '2' and not GPROF then
        GPROF = require('tools/tests/lib/garbage_profile')
        GPROF.wrap()
    end
    if GPROF then collectgarbage('restart'); collectgarbage('step', 200) end
    if PERF then
        PERF.t = PERF.t + dt
        if PERF.t >= 10 then
            S.log(string.format("perf: %d pasos de sala %.3f ms · %d fotos %.3f ms · %.1f KB creados por paso · Lua %.0f KB",
                PERF.steps, PERF.steps > 0 and PERF.stepT / PERF.steps * 1000 or 0, PERF.snaps,
                PERF.snaps > 0 and PERF.snapT / PERF.snaps * 1000 or 0, PERF.steps > 0 and PERF.alloc / PERF.steps or 0,
                collectgarbage('count')))
            if GPROF and PERF.steps > 0 then
                for _, e in ipairs(GPROF.top(15, PERF.steps)) do S.log(string.format("perf:   %7.2f KB/paso  %s", e[2], e[1])) end
                GPROF.reset()
            end
            if PERF_SNAP.n > 0 then
                S.log(string.format("perf: fotos por jugador: media %d B, máxima %d B, %d de más de 1200 B (van en trozos fiables)",
                    math.floor(PERF_SNAP.sum / PERF_SNAP.n), PERF_SNAP.max, PERF_SNAP.big))
            end
            PERF_SNAP.max, PERF_SNAP.sum, PERF_SNAP.n, PERF_SNAP.big = 0, 0, 0, 0
            PERF.t, PERF.steps, PERF.stepT, PERF.snaps, PERF.snapT, PERF.alloc = 0, 0, 0, 0, 0, 0
        end
    end

    pingTimer = pingTimer + dt
    if pingTimer >= PING_TICK then
        pingTimer = 0
        S.checkAway()                    -- (los que se fueron en plena partida: ¿volvieron? server/srv/lobby.lua)
        for _, room in pairs(rooms) do
            if #room.playerIds > 0 then guarded(room, 'estado de la sala', S.broadcastRoomUpdate, room) end
        end
    end
end
