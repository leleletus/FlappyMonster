-- server/main.lua
-- Servidor multijugador de FlappyMonster Adventure — Arquitectura autoritativa.
-- El servidor corre toda la simulación (física, enemigos, colisiones) y
-- retransmite el estado autorizado a los clientes.  Los clientes solo envían
-- inputs y renderizan lo que el servidor dice.

local sock   = require "libs.sock"
local bitser = require "libs.bitser"

-- Detectar modo headless (sin gráficos)
local HEADLESS = (love.graphics == nil)

io.stdout:setvbuf("no")
math.randomseed(os.time())

-- ─────────────────────────────────────────────────────────────────────────────
--  Constantes de red
-- ─────────────────────────────────────────────────────────────────────────────

local PORT       = 22122
local PING_TICK  = 3      -- segundos entre room_update
local GAME_TICK  = 0.05   -- 20 Hz broadcast de estado de juego
local LOG_MAX    = 22

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

-- Input stub: se remplaza por los datos del jugador antes de cada pa:update().
local _inp = {
    left=false, right=false, jump=false, crouch=false,
    jump_pressed=false, crouch_pressed=false,
}

Input = {
    pressed = function(action)
        if action == 'jump'   then
            local v = _inp.jump_pressed; _inp.jump_pressed = false; return v
        end
        if action == 'crouch' then
            local v = _inp.crouch_pressed; _inp.crouch_pressed = false; return v
        end
        return false
    end,
    down = function(action)
        if action == 'move_left'  then return _inp.left   end
        if action == 'move_right' then return _inp.right  end
        if action == 'jump'       then return _inp.jump   end
        if action == 'crouch'     then return _inp.crouch end
        return false
    end,
}

-- Clases de entidades (cargadas en love.load tras montar el directorio padre).
local Level, PlayerAdventure, Gummy, Crabby

-- Constantes que deben coincidir con PlayerAdventure.lua
local DROWN_TOTAL     = 20
local DROWN_AUDIO_DUR = 12
local LEVEL_PATH      = 'assets/levels/nivel01.json'
local PLAYER_LIVES    = 3
local SPAWN_STAGGER   = 48   -- px de separación horizontal entre jugadores al spawn

-- ─────────────────────────────────────────────────────────────────────────────
--  Estructuras de datos de red
-- ─────────────────────────────────────────────────────────────────────────────

local server = sock.newServer("*", PORT)
server:setSerialization(bitser.dumps, bitser.loads)

-- players[clientObj] = { id, name, roomId, isReady, color }
local players    = {}
-- rooms[roomId]    = { id, name, isPublic, password, maxPlayers,
--                      playerIds, adminId, state, bannedNames,
--                      sim (o nil si no está en partida) }
local rooms      = {}
local nextRoomId = 1

local serverLog  = {}
local pingTimer  = 0
local gameTimer  = 0

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

local function findClientById(playerId)
    for c, p in pairs(players) do
        if p.id == playerId then return c end
    end
end

local function findPlayerNameById(playerId)
    local c = findClientById(playerId)
    return (c and players[c]) and players[c].name or "?"
end

local function countPlayers() local n=0; for _ in pairs(players) do n=n+1 end; return n end
local function countRooms()   local n=0; for _ in pairs(rooms)   do n=n+1 end; return n end

-- ─────────────────────────────────────────────────────────────────────────────
--  Simulación de juego
-- ─────────────────────────────────────────────────────────────────────────────

local function initRoomSim(room)
    local level = Level.new(LEVEL_PATH)
    local sx, sy = level:getSpawnPx()
    local N = #room.playerIds

    local sim = { level=level, playerSims={}, enemies={}, events={}, gameOverSent=false,
                  levelTime=0, timeLimitKilled=false }

    -- Crear instancias de enemigos del nivel
    for _, edata in ipairs(level.enemies) do
        local e
        if edata.type == 'gummy' then
            e = Gummy:new(edata); e._type = 'gummy'
        elseif edata.type == 'crabby' then
            e = Crabby:new(edata); e._type = 'crabby'
        end
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
                pa          = pa,
                input       = { left=false, right=false, jump=false, crouch=false,
                                jump_pressed=false, crouch_pressed=false },
                isSpectator = false,
                score       = 0,
            }
        end
    end

    log("Simulacion iniciada para sala '" .. room.name .. "' — "
        .. #sim.enemies .. " enemigos, " .. N .. " jugadores.")
    return sim
end

-- Colisiones jugador-enemigo (lógica portada de AdventureState)
local function checkSimEnemyCollisions(sim)
    for pid, ps in pairs(sim.playerSims) do
        if not ps.isSpectator then
            local pa = ps.pa
            if not pa.dying and pa.alive then
                local pob     = pa:getOuterBounds()
                local killed  = false   -- flag para salir del bucle de enemigos

                for _, g in ipairs(sim.enemies) do
                    if not killed and g.alive and g.state ~= 'dead' then
                        -- Pincho del Crabby
                        local spikeHit = false
                        if g.getSpikeHitbox then
                            local spk = g:getSpikeHitbox()
                            if spk and
                               pob.x < spk.x+spk.w and pob.x+pob.w > spk.x and
                               pob.y < spk.y+spk.h and pob.y+pob.h > spk.y then
                                spikeHit = true
                            end
                        end

                        if spikeHit then
                            _currentSoundPlayerId = pid; pa:die(); _currentSoundPlayerId = nil
                            killed = true
                        elseif not (g.isBodyDisabled and g:isBodyDisabled()) then
                            local gib = g:getInnerBounds()
                            local gob = g:getOuterBounds()
                            local overlap = pob.x < gib.x+gib.w and pob.x+pob.w > gib.x and
                                            pob.y < gib.y+gib.h and pob.y+pob.h > gib.y

                            if overlap then
                                if g.flipped then
                                    local enemyBotZone = gob.y + gob.h * 0.65
                                    if pa.vy < 0 and pob.y > enemyBotZone - 10 then
                                        _currentSoundPlayerId = nil; g:stomp()
                                        local bvy = math.abs(ADV_JUMP_VEL) * 0.40
                                        pa.vy = bvy; pa.jumpsLeft = 2
                                        local pts = 15
                                        ps.score = ps.score + pts
                                        table.insert(sim.events, { type='score', playerId=pid, delta=pts, x=g.x, y=g.y, bounceVy=bvy })
                                    else
                                        _currentSoundPlayerId = pid; pa:die(); _currentSoundPlayerId = nil
                                        killed = true
                                    end
                                else
                                    local gummyTopZone = gob.y + gob.h * 0.35
                                    if pa.vy > 0 and pob.y+pob.h < gummyTopZone + 10 then
                                        _currentSoundPlayerId = nil; g:stomp()
                                        local bvy = -math.abs(ADV_JUMP_VEL) * 0.40
                                        pa.vy = bvy; pa.jumpsLeft = 2
                                        local pts = (g.isBodyDisabled and 15) or 10
                                        ps.score = ps.score + pts
                                        table.insert(sim.events, { type='score', playerId=pid, delta=pts, x=g.x, y=g.y, bounceVy=bvy })
                                    else
                                        _currentSoundPlayerId = pid; pa:die(); _currentSoundPlayerId = nil
                                        killed = true
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Avanzar la simulación de una sala un paso de dt segundos
local function advanceRoomSim(room, dt)
    local sim = room.sim
    if not sim then return end

    _soundEvents = {}

    -- ── Reloj de nivel (autoritativo) ────────────────────────────────────────
    sim.levelTime = math.min(sim.levelTime + dt, 600)

    -- Límite de 10 minutos: matar a todos los jugadores activos (igual que modo solo)
    if sim.levelTime >= 600 and not sim.timeLimitKilled then
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

    -- ── Actualizar física de cada jugador ─────────────────────────────────────
    for pid, ps in pairs(sim.playerSims) do
        if not ps.isSpectator then
            local pa  = ps.pa
            local inp = ps.input

            -- Cargar el input de este jugador en el stub global
            _inp.left           = inp.left
            _inp.right          = inp.right
            _inp.jump           = inp.jump
            _inp.crouch         = inp.crouch
            _inp.jump_pressed   = inp.jump_pressed
            _inp.crouch_pressed = inp.crouch_pressed
            _currentSoundPlayerId = pid

            pa:update(dt, sim.level)

            -- Consumir flags "presionado" tras el update
            inp.jump_pressed   = false
            inp.crouch_pressed = false
            _currentSoundPlayerId = nil

            -- Fin de animación de muerte → restar vida y respawn/espectador
            if pa.dying and not pa.alive then
                pa.lives = pa.lives - 1
                if pa.lives <= 0 then
                    ps.isSpectator = true
                    table.insert(sim.events, { type='spectate', playerId=pid })
                else
                    _currentSoundPlayerId = pid
                    pa:respawn()
                    _currentSoundPlayerId = nil
                end
            end

            -- Colisión con ventilador de oxígeno (reinicia ahogamiento)
            if not pa.dying then
                local ob  = pa:getOuterBounds()
                local hit = sim.level:checkVentOxyCollision(ob.x, ob.y, ob.w, ob.h)
                if hit and (pa.drownPhase == 'warning' or pa.drownPhase == 'drowning') then
                    pa.drownTimer=0; pa.drownChime=0
                    pa.drownAudT=0;  pa.drownDead=false
                    pa.drownPhase='none'
                    pa.airBarAlpha=0; pa.airBarBobOn=false
                    table.insert(_soundEvents, { sound='airGasp', playerId=pid })
                    -- Evento autoritativo: el cliente debe resetear su estado local inmediatamente
                    table.insert(sim.events, { type='air_collected', playerId=pid })
                end
            end
        end
    end

    -- Restaurar input neutral
    _inp.left=false; _inp.right=false; _inp.jump=false; _inp.crouch=false
    _inp.jump_pressed=false; _inp.crouch_pressed=false
    _currentSoundPlayerId = nil

    -- ── Actualizar nivel (genera burbujas de oxígeno en vents) ───────────────
    sim.level:update(dt)

    -- ── Actualizar enemigos ───────────────────────────────────────────────────
    for _, e in ipairs(sim.enemies) do
        e:update(dt, sim.level)
    end

    -- ── Colisiones jugador-enemigo ────────────────────────────────────────────
    checkSimEnemyCollisions(sim)

    -- ── Fusionar eventos de sonido en sim.events ──────────────────────────────
    for _, se in ipairs(_soundEvents) do
        table.insert(sim.events, { type='sound', sound=se.sound, playerId=se.playerId })
    end
    _soundEvents = {}

    -- ── Detectar game over (todos los jugadores son espectadores) ─────────────
    if not sim.gameOverSent then
        local allSpec, anyPlayer = true, false
        for _, ps in pairs(sim.playerSims) do
            anyPlayer = true
            if not ps.isSpectator then allSpec = false; break end
        end
        if anyPlayer and allSpec then
            sim.gameOverSent = true
            table.insert(sim.events, { type='game_over' })
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
    local payload = {
        id=room.id, name=room.name, isPublic=room.isPublic,
        hasPassword=(room.password~=""), maxPlayers=room.maxPlayers,
        state=room.state, adminId=room.adminId, players=playerList,
    }
    for _, pid in ipairs(room.playerIds) do
        local c = findClientById(pid)
        if c then c:send("room_update", payload) end
    end
end

local function announceToRoom(room, msg)
    for _, pid in ipairs(room.playerIds) do
        local c = findClientById(pid)
        if c then c:send("room_announce", { msg=msg }) end
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

-- Construye y envía el estado autorizado de la partida a todos los jugadores.
local function broadcastAuthGameState(room)
    local sim = room.sim
    if not sim then return end

    -- Lista de jugadores
    local plist = {}
    for _, pid in ipairs(room.playerIds) do
        local c = findClientById(pid)
        if c and sim.playerSims[pid] then
            local ps = sim.playerSims[pid]
            local pa = ps.pa
            table.insert(plist, {
                id          = pid,
                name        = players[c].name,
                color       = players[c].color or {1,1,1},
                x           = pa.x,
                y           = pa.y,
                facing      = pa.facing,
                frame       = pa.frame,
                lives       = pa.lives,
                hp          = pa.hp,
                hpMax       = pa.hpMax,
                score       = ps.score,
                drownPhase  = pa.drownPhase,
                airFraction = math.max(0, 1 - pa.drownTimer / DROWN_TOTAL),
                drownAudT   = pa.drownAudT,
                dying       = pa.dying,
                deathPhase  = pa.deathPhase,
                isSpectator = ps.isSpectator,
            })
        end
    end

    -- Lista de enemigos
    local elist = {}
    for i, e in ipairs(sim.enemies) do
        local entry = {
            idx      = i,
            eType    = e._type,
            x        = e.x,
            y        = e.y,
            facing   = e.facing,
            state    = e.state,
            frame    = e.frame,
            alive    = e.alive,
            deadTimer = e.deadTimer,
            breatheT = e.breatheT,
            sprW     = e.sprW,
            sprH     = e.sprH,
        }
        if e._type == 'crabby' then
            entry.spikeProgress  = e.spikeProgress
            entry.flipped        = e.flipped
            entry.outerH         = e.outerH
            entry.currentImgName = e:getImgName()
        end
        table.insert(elist, entry)
    end

    -- Burbujas de oxígeno de los vents (sincronizadas entre clientes)
    local ventBubbles = {}
    for vi, vent in ipairs(sim.level.vents) do
        local bubs = {}
        for _, b in ipairs(vent.oxyBubbles) do
            if b.alive then
                table.insert(bubs, {x=b.x, y=b.y})
            end
        end
        ventBubbles[vi] = bubs
    end

    local payload = { players=plist, enemies=elist, events=sim.events, ventBubbles=ventBubbles,
                      levelTime=sim.levelTime }

    for _, pid in ipairs(room.playerIds) do
        local c = findClientById(pid)
        if c then c:send("game_state", payload) end
    end

    -- Limpiar eventos ya enviados
    sim.events = {}

    -- Si el juego terminó, transicionar la sala a WAITING
    if sim.gameOverSent then
        room.state = "WAITING"
        room.sim   = nil
        for _, pid in ipairs(room.playerIds) do
            local c = findClientById(pid)
            if c then players[c].isReady = false end
        end
        broadcastRoomUpdate(room)
        log("Partida terminada en sala '" .. room.name .. "' — todos muertos.")
    end
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
        announceToRoom(room, player.name .. " ha salido de la sala.")
    end

    if #room.playerIds == 0 then
        rooms[room.id] = nil
        log("Sala '" .. room.name .. "' eliminada (vacia).")
        return true
    end

    if room.adminId == player.id then
        room.adminId = room.playerIds[1]
        local newName = findPlayerNameById(room.adminId)
        announceToRoom(room, newName .. " es el nuevo admin.")
        log("Nuevo admin de '" .. room.name .. "': " .. newName)
    end

    broadcastRoomUpdate(room)
    return false
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Eventos de red
-- ─────────────────────────────────────────────────────────────────────────────

log("FlappyMonster Online Server (autoritativo) — Puerto " .. PORT)

server:on("connect", function(data, client)
    log("Cliente conectando...")
end)

server:on("set_nickname", function(nickname, client)
    local id = tostring(os.time()) .. tostring(math.random(1000, 9999))
    players[client] = { id=id, name=tostring(nickname), roomId=nil, isReady=false, color=nil }
    log("Registrado: '" .. tostring(nickname) .. "'")
    client:send("login_success", { name=tostring(nickname), id=id })
end)

server:on("get_rooms", function(data, client)
    client:send("room_list", buildPublicRoomList())
end)

server:on("create_room", function(data, client)
    local player = players[client]
    if not player then client:send("room_error",{msg="No registrado."}); return end
    if player.roomId then client:send("room_error",{msg="Ya estas en una sala."}); return end
    local name       = tostring(data.name or ("Sala de "..player.name))
    local isPublic   = (data.isPublic ~= false)
    local password   = tostring(data.password or "")
    local maxPlayers = tonumber(data.maxPlayers) or 4
    if #name<1 or #name>30 then client:send("room_error",{msg="Nombre: 1-30 chars."}); return end
    if maxPlayers<1 or maxPlayers>8 then client:send("room_error",{msg="Max jugadores: 1-8."}); return end
    local roomId = newRoomId()
    rooms[roomId] = { id=roomId, name=name, isPublic=isPublic, password=password,
                      maxPlayers=maxPlayers, playerIds={player.id},
                      adminId=player.id, state="WAITING", bannedNames={}, sim=nil }
    player.roomId  = roomId
    player.isReady = false
    player.color   = PLAYER_COLORS[1]
    log("Sala '" .. name .. "' creada por " .. player.name)
    broadcastRoomUpdate(rooms[roomId])
end)

server:on("join_room", function(data, client)
    local player = players[client]
    if not player then client:send("room_error",{msg="No registrado."}); return end
    if player.roomId then client:send("room_error",{msg="Ya estas en una sala."}); return end
    local room = rooms[tostring(data.id or "")]
    if not room then client:send("room_error",{msg="Sala no encontrada."}); return end
    if room.state ~= "WAITING" then client:send("room_error",{msg="Partida en curso."}); return end
    if #room.playerIds >= room.maxPlayers then client:send("room_error",{msg="Sala llena."}); return end
    if room.bannedNames[player.name] then client:send("room_error",{msg="Estas baneado."}); return end
    if room.password ~= "" and room.password ~= tostring(data.password or "") then
        client:send("room_error",{msg="Contrasena incorrecta."}); return
    end
    table.insert(room.playerIds, player.id)
    player.roomId  = room.id
    player.isReady = false
    player.color   = PLAYER_COLORS[#room.playerIds] or {1,1,1}
    log(player.name .. " se unio a '" .. room.name .. "'")
    broadcastRoomUpdate(room)
    announceToRoom(room, player.name .. " se ha unido.")
end)

server:on("leave_room", function(data, client)
    local player = players[client]
    if not player or not player.roomId then return end
    local room = rooms[player.roomId]
    if not room then player.roomId=nil; return end
    removePlayerFromRoom(player, room, false)
    client:send("room_left", {})
end)

server:on("set_ready", function(data, client)
    local player = players[client]
    if not player or not player.roomId then return end
    local room = rooms[player.roomId]
    if not room or room.state ~= "WAITING" then return end
    player.isReady = (data.ready == true)
    log(player.name .. (player.isReady and " → LISTO" or " → no listo"))
    broadcastRoomUpdate(room)
end)

server:on("start_game", function(data, client)
    local player = players[client]
    if not player or not player.roomId then return end
    local room = rooms[player.roomId]
    if not room then return end
    if room.adminId ~= player.id then client:send("room_error",{msg="Solo el admin puede iniciar."}); return end
    if room.state == "IN_GAME"   then client:send("room_error",{msg="Partida ya en curso."}); return end
    if #room.playerIds < 2       then client:send("room_error",{msg="Se necesitan al menos 2 jugadores."}); return end

    for _, pid in ipairs(room.playerIds) do
        local c = findClientById(pid)
        if c and not players[c].isReady then
            client:send("room_error",{msg="No todos estan listos."}); return
        end
    end

    -- Asignar colores
    for i, pid in ipairs(room.playerIds) do
        local c = findClientById(pid)
        if c then players[c].color = PLAYER_COLORS[i] or {1,1,1} end
    end

    room.state = "IN_GAME"
    room.sim   = initRoomSim(room)

    log("Partida iniciada en '" .. room.name .. "'!")
    announceToRoom(room, "La partida ha comenzado!")
    broadcastRoomUpdate(room)
    broadcastAuthGameState(room)
end)

server:on("stop_game", function(data, client)
    local player = players[client]
    if not player or not player.roomId then return end
    local room = rooms[player.roomId]
    if not room then return end
    if room.adminId ~= player.id then client:send("room_error",{msg="Solo el admin puede detener."}); return end
    if room.state ~= "IN_GAME" then return end

    room.state = "WAITING"
    room.sim   = nil
    for _, pid in ipairs(room.playerIds) do
        local c = findClientById(pid)
        if c then players[c].isReady=false end
    end
    log("Partida detenida en '" .. room.name .. "'.")
    announceToRoom(room, "La partida fue detenida.")
    broadcastRoomUpdate(room)
end)

server:on("kick_player", function(data, client)
    local admin = players[client]
    if not admin or not admin.roomId then return end
    local room = rooms[admin.roomId]
    if not room or room.adminId ~= admin.id then client:send("room_error",{msg="No eres admin."}); return end
    local targetId = tostring(data.playerId or "")
    if targetId == admin.id then client:send("room_error",{msg="No puedes kickearte."}); return end
    local tc = findClientById(targetId)
    if not tc or players[tc].roomId ~= room.id then client:send("room_error",{msg="Jugador no encontrado."}); return end
    local tname = players[tc].name
    tc:send("kicked", {msg="Fuiste expulsado."})
    removePlayerFromRoom(players[tc], room, true)
    announceToRoom(room, tname .. " fue expulsado.")
    log(admin.name .. " kickeo a " .. tname)
end)

server:on("ban_player", function(data, client)
    local admin = players[client]
    if not admin or not admin.roomId then return end
    local room = rooms[admin.roomId]
    if not room or room.adminId ~= admin.id then client:send("room_error",{msg="No eres admin."}); return end
    local targetId = tostring(data.playerId or "")
    if targetId == admin.id then client:send("room_error",{msg="No puedes banearte."}); return end
    local tc = findClientById(targetId)
    if not tc or players[tc].roomId ~= room.id then client:send("room_error",{msg="Jugador no encontrado."}); return end
    local tname = players[tc].name
    room.bannedNames[tname] = true
    tc:send("banned", {msg="Fuiste baneado."})
    removePlayerFromRoom(players[tc], room, true)
    announceToRoom(room, tname .. " fue baneado.")
    log(admin.name .. " baneo a " .. tname)
end)

-- Input del jugador durante la partida
server:on("player_input", function(data, client)
    local player = players[client]
    if not player or not player.roomId then return end
    local room = rooms[player.roomId]
    if not room or room.state ~= "IN_GAME" or not room.sim then return end
    local ps = room.sim.playerSims[player.id]
    if not ps then return end
    local inp = ps.input
    inp.left   = (data.left   == true)
    inp.right  = (data.right  == true)
    inp.jump   = (data.jump   == true)
    inp.crouch = (data.crouch == true)
    -- Flags de "recién presionado": se acumulan (OR), se consumen en el update
    if data.jump_pressed   then inp.jump_pressed   = true end
    if data.crouch_pressed then inp.crouch_pressed = true end
end)

server:on("close_room", function(data, client)
    local admin = players[client]
    if not admin or not admin.roomId then return end
    local room = rooms[admin.roomId]
    if not room or room.adminId ~= admin.id then
        client:send("room_error",{msg="No eres admin."}); return
    end
    log("Sala '" .. room.name .. "' cerrada por " .. admin.name)
    for _, pid in ipairs(room.playerIds) do
        local c = findClientById(pid)
        if c then
            c:send("room_closed", {msg="El admin cerro la sala."})
            players[c].roomId=nil; players[c].isReady=false; players[c].color=nil
        end
    end
    rooms[room.id] = nil
end)

server:on("disconnect", function(data, client)
    local player = players[client]
    if not player then log("Cliente desconocido desconectado."); return end
    log("Desconectado: '" .. player.name .. "'")
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
    local parentDir = love.filesystem.getSourceBaseDirectory():gsub("\\", "/")
    log("Directorio del juego: " .. parentDir)

    -- 1. Extender package.path para que require encuentre los .lua del juego
    package.path = parentDir .. "/?.lua;" .. package.path

    -- 2. Override love.filesystem.read para leer assets (JSON de niveles, etc.)
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
    Gummy           = require 'src/entities/Gummy'
    Crabby          = require 'src/entities/Crabby'

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

function love.update(dt)
    server:update()

    -- Avanzar simulaciones de salas en partida
    for _, room in pairs(rooms) do
        if room.state == "IN_GAME" and room.sim then
            advanceRoomSim(room, dt)
        end
    end

    pingTimer = pingTimer + dt
    if pingTimer >= PING_TICK then
        pingTimer = 0
        for _, room in pairs(rooms) do
            if #room.playerIds > 0 then broadcastRoomUpdate(room) end
        end
    end

    gameTimer = gameTimer + dt
    if gameTimer >= GAME_TICK then
        gameTimer = 0
        for _, room in pairs(rooms) do
            if room.state == "IN_GAME" and room.sim then
                broadcastAuthGameState(room)
            end
        end
    end
end