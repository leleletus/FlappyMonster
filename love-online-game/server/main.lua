local sock   = require "libs.sock"
local bitser = require "libs.bitser"

io.stdout:setvbuf("no")
math.randomseed(os.time())

-- ─────────────────────────────────────────────────────────────────────────────
--  Constantes
-- ─────────────────────────────────────────────────────────────────────────────

local PORT        = 22122
local PING_TICK   = 3      -- segundos entre room_update (para pings)
local GAME_TICK   = 0.05   -- segundos entre game_state broadcast (20 fps)
local LOG_MAX     = 22     -- líneas en el log visual
local BALL_R      = 15     -- radio de las bolitas (para validar posición)
local HUD_H       = 30     -- altura del HUD del cliente (área protegida arriba)

-- Paleta de 16 colores, uno por jugador
local PLAYER_COLORS = {
    {1.00,0.30,0.30}, {0.30,0.60,1.00}, {0.30,1.00,0.30}, {1.00,1.00,0.20},
    {1.00,0.55,0.05}, {0.80,0.30,1.00}, {0.05,0.90,0.85}, {1.00,0.40,0.80},
    {0.50,1.00,0.50}, {0.90,0.65,0.15}, {0.60,0.80,1.00}, {1.00,0.70,0.70},
    {0.35,1.00,1.00}, {1.00,0.90,0.50}, {0.70,0.40,0.95}, {0.50,0.95,0.55},
}

-- Posiciones de inicio para hasta 16 jugadores (ventana cliente 800×600)
local START_POS = {
    {120,155},{680,155},{120,480},{680,480},
    {400,155},{400,480},{120,315},{680,315},
    {270,225},{530,225},{270,430},{530,430},
    {155,265},{645,265},{155,395},{645,395},
}

-- ─────────────────────────────────────────────────────────────────────────────
--  Servidor
-- ─────────────────────────────────────────────────────────────────────────────

local server = sock.newServer("*", PORT)
server:setSerialization(bitser.dumps, bitser.loads)

-- ─────────────────────────────────────────────────────────────────────────────
--  Estructuras de datos
-- ─────────────────────────────────────────────────────────────────────────────

-- players[clientObj] = { id, name, roomId, isReady, x, y, color }
local players    = {}

-- rooms[roomId] = {
--   id, name, isPublic, password, maxPlayers,
--   playerIds, adminId, state ("WAITING"|"IN_GAME"), bannedNames
-- }
local rooms      = {}
local nextRoomId = 1

-- ─────────────────────────────────────────────────────────────────────────────
--  Log visual (buffer circular que también imprime al stdout)
-- ─────────────────────────────────────────────────────────────────────────────

local serverLog = {}

local function log(msg)
    print(msg)
    table.insert(serverLog, msg)
    if #serverLog > LOG_MAX then table.remove(serverLog, 1) end
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Timers
-- ─────────────────────────────────────────────────────────────────────────────

local pingTimer = 0
local gameTimer = 0

-- ─────────────────────────────────────────────────────────────────────────────
--  Utilidades
-- ─────────────────────────────────────────────────────────────────────────────

local function newRoomId()
    local id = tostring(nextRoomId)
    nextRoomId = nextRoomId + 1
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
    local n = 0; for _ in pairs(players) do n = n + 1 end; return n
end

local function countRooms()
    local n = 0; for _ in pairs(rooms) do n = n + 1 end; return n
end

-- Broadcast estado completo de sala (ping, ready, etc.)
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
            })
        end
    end
    local payload = {
        id          = room.id,   name        = room.name,
        isPublic    = room.isPublic,
        hasPassword = (room.password ~= ""),
        maxPlayers  = room.maxPlayers,
        state       = room.state,
        adminId     = room.adminId,
        players     = playerList,
    }
    for _, pid in ipairs(room.playerIds) do
        local c = findClientById(pid)
        if c then c:send("room_update", payload) end
    end
end

-- Broadcast posiciones en tiempo real (solo cuando IN_GAME)
local function broadcastGameState(room)
    local plist = {}
    for _, pid in ipairs(room.playerIds) do
        local c = findClientById(pid)
        if c then
            table.insert(plist, {
                id    = pid,
                name  = players[c].name,
                x     = players[c].x or 400,
                y     = players[c].y or 300,
                color = players[c].color or {1, 1, 1},
            })
        end
    end
    local payload = { players = plist }
    for _, pid in ipairs(room.playerIds) do
        local c = findClientById(pid)
        if c then c:send("game_state", payload) end
    end
end

local function announceToRoom(room, msg)
    for _, pid in ipairs(room.playerIds) do
        local c = findClientById(pid)
        if c then c:send("room_announce", { msg = msg }) end
    end
end

local function buildPublicRoomList()
    local list = {}
    for _, room in pairs(rooms) do
        if room.isPublic then
            table.insert(list, {
                id             = room.id,
                name           = room.name,
                hasPassword    = (room.password ~= ""),
                currentPlayers = #room.playerIds,
                maxPlayers     = room.maxPlayers,
                state          = room.state,
            })
        end
    end
    return list
end

-- Elimina al jugador de la sala y limpia su estado de juego.
-- silent=true → suprime el anuncio genérico "X salió".
-- Devuelve true si la sala quedó vacía y fue borrada.
local function removePlayerFromRoom(player, room, silent)
    for i, pid in ipairs(room.playerIds) do
        if pid == player.id then
            table.remove(room.playerIds, i); break
        end
    end
    player.isReady = false
    player.roomId  = nil
    player.x       = nil
    player.y       = nil
    player.color   = nil

    if not silent then
        announceToRoom(room, player.name .. " ha salido de la sala.")
    end

    if #room.playerIds == 0 then
        rooms[room.id] = nil
        log("Sala '" .. room.name .. "' eliminada (vacía).")
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
--  Eventos del servidor
-- ─────────────────────────────────────────────────────────────────────────────

log("¡Servidor iniciado en el puerto " .. PORT .. "!")

server:on("connect", function(data, client)
    log("Nuevo cliente conectando...")
end)

server:on("set_nickname", function(nickname, client)
    local id = tostring(os.time()) .. tostring(math.random(1000, 9999))
    players[client] = {
        id = id, name = nickname, roomId = nil,
        isReady = false, x = nil, y = nil, color = nil,
    }
    log("Registrado: '" .. nickname .. "'")
    client:send("login_success", { name = nickname, id = id })
end)

server:on("get_rooms", function(data, client)
    client:send("room_list", buildPublicRoomList())
end)

server:on("create_room", function(data, client)
    local player = players[client]
    if not player then client:send("room_error",{msg="No registrado."}); return end
    if player.roomId then client:send("room_error",{msg="Ya estás en una sala."}); return end

    local name       = tostring(data.name or ("Sala de " .. player.name))
    local isPublic   = (data.isPublic ~= false)
    local password   = tostring(data.password or "")
    local maxPlayers = tonumber(data.maxPlayers) or 4

    if #name < 1 or #name > 30 then client:send("room_error",{msg="Nombre: 1-30 chars."}); return end
    if maxPlayers < 2 or maxPlayers > 16 then client:send("room_error",{msg="Máx: 2-16."}); return end

    local roomId = newRoomId()
    rooms[roomId] = {
        id=roomId, name=name, isPublic=isPublic, password=password,
        maxPlayers=maxPlayers, playerIds={player.id},
        adminId=player.id, state="WAITING", bannedNames={},
    }
    player.roomId  = roomId
    player.isReady = false
    log("Sala '" .. name .. "' creada por " .. player.name)
    broadcastRoomUpdate(rooms[roomId])
end)

server:on("join_room", function(data, client)
    local player = players[client]
    if not player then client:send("room_error",{msg="No registrado."}); return end
    if player.roomId then client:send("room_error",{msg="Ya estás en una sala."}); return end

    local room = rooms[tostring(data.id or "")]
    if not room then client:send("room_error",{msg="Sala no encontrada."}); return end
    if room.state ~= "WAITING" then client:send("room_error",{msg="Partida en curso."}); return end
    if #room.playerIds >= room.maxPlayers then client:send("room_error",{msg="Sala llena."}); return end
    if room.bannedNames[player.name] then client:send("room_error",{msg="Estás baneado."}); return end
    if room.password ~= "" and room.password ~= tostring(data.password or "") then
        client:send("room_error",{msg="Contraseña incorrecta."}); return
    end

    table.insert(room.playerIds, player.id)
    player.roomId  = room.id
    player.isReady = false
    log(player.name .. " se unió a '" .. room.name .. "'")
    broadcastRoomUpdate(room)
    announceToRoom(room, player.name .. " se ha unido.")
end)

server:on("leave_room", function(data, client)
    local player = players[client]
    if not player or not player.roomId then return end
    local room = rooms[player.roomId]
    if not room then player.roomId = nil; return end
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
    if room.state == "IN_GAME" then client:send("room_error",{msg="Ya en curso."}); return end
    if #room.playerIds < 2 then client:send("room_error",{msg="Mínimo 2 jugadores."}); return end
    for _, pid in ipairs(room.playerIds) do
        local c = findClientById(pid)
        if c and not players[c].isReady then
            client:send("room_error",{msg="No todos están listos."}); return
        end
    end

    -- Asignar colores y posiciones de inicio a cada jugador
    for i, pid in ipairs(room.playerIds) do
        local c = findClientById(pid)
        if c then
            players[c].color = PLAYER_COLORS[i] or {1,1,1}
            local sp = START_POS[i] or {400, 300}
            players[c].x = sp[1]
            players[c].y = sp[2]
        end
    end

    room.state = "IN_GAME"
    log("¡Partida iniciada en '" .. room.name .. "'!")
    announceToRoom(room, "¡La partida ha comenzado!")
    broadcastRoomUpdate(room)
    broadcastGameState(room)  -- posiciones iniciales de inmediato
end)

server:on("stop_game", function(data, client)
    local player = players[client]
    if not player or not player.roomId then return end
    local room = rooms[player.roomId]
    if not room then return end
    if room.adminId ~= player.id then client:send("room_error",{msg="Solo el admin puede detener."}); return end
    if room.state ~= "IN_GAME" then return end

    room.state = "WAITING"
    for _, pid in ipairs(room.playerIds) do
        local c = findClientById(pid)
        if c then
            players[c].isReady = false
            players[c].x = nil; players[c].y = nil; players[c].color = nil
        end
    end
    log("Partida detenida en '" .. room.name .. "'.")
    announceToRoom(room, "La partida fue detenida. ¡Prepárense de nuevo!")
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
    log(admin.name .. " kickeó a " .. tname)
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
    log(admin.name .. " baneó a " .. tname)
end)

-- Recibe la posición del jugador y la valida con los límites del campo
server:on("player_move", function(data, client)
    local player = players[client]
    if not player or not player.roomId then return end
    local room = rooms[player.roomId]
    if not room or room.state ~= "IN_GAME" then return end
    local x, y = tonumber(data.x), tonumber(data.y)
    if x and y then
        player.x = math.max(BALL_R, math.min(800 - BALL_R, x))
        player.y = math.max(HUD_H + BALL_R, math.min(600 - BALL_R, y))
    end
end)

-- Admin cierra la sala completamente: todos vuelven al menú principal
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
            c:send("room_closed", {msg="El admin cerró la sala."})
            players[c].roomId  = nil
            players[c].isReady = false
            players[c].x = nil; players[c].y = nil; players[c].color = nil
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
    love.window.setTitle("Servidor — Puerto " .. PORT)
    love.window.setMode(820, 640)
end

function love.draw()
    local W, H = love.graphics.getDimensions()
    love.graphics.setBackgroundColor(0.07, 0.09, 0.11)

    -- ── Cabecera ──────────────────────────────────────────────────────────────
    love.graphics.setColor(0.12, 0.15, 0.18)
    love.graphics.rectangle("fill", 0, 0, W, 28)
    love.graphics.setColor(0.95, 0.80, 0.15)
    love.graphics.print(
        "  SERVIDOR   Puerto " .. PORT ..
        "        Jugadores: " .. countPlayers() ..
        "   Salas: " .. countRooms(),
        8, 6
    )
    love.graphics.setColor(0.25, 0.30, 0.35)
    love.graphics.line(0, 28, W, 28)

    -- ── Salas ─────────────────────────────────────────────────────────────────
    local y = 36
    if countRooms() == 0 then
        love.graphics.setColor(0.40, 0.42, 0.45)
        love.graphics.print("  (sin salas activas)", 10, y)
        y = y + 20
    else
        for _, room in pairs(rooms) do
            if y > 370 then break end   -- no pisar el log

            -- Nombre de sala
            if room.state == "IN_GAME" then
                love.graphics.setColor(1.00, 0.75, 0.15)
            else
                love.graphics.setColor(0.25, 1.00, 0.50)
            end
            local priv = room.isPublic and "Pública" or "Privada"
            love.graphics.print(
                string.format("  [%s] %-22s %s  %d/%d  [%s]",
                    room.id, room.name, priv,
                    #room.playerIds, room.maxPlayers, room.state),
                10, y
            )
            y = y + 18

            -- Jugadores de la sala
            for _, pid in ipairs(room.playerIds) do
                local c = findClientById(pid)
                if c then
                    local p    = players[c]
                    local ping = 0
                    if c.connection then
                        local ok, rtt = pcall(function() return c.connection:round_trip_time() end)
                        if ok and type(rtt) == "number" then ping = rtt end
                    end
                    local atag = (pid == room.adminId) and "[A]" or "   "
                    local rtag = p.isReady and "[LISTO]" or "[     ]"
                    local col  = p.color or {0.65, 0.70, 0.80}
                    love.graphics.setColor(col[1], col[2], col[3])
                    love.graphics.print(
                        string.format("       %s  %-16s  %s  %4dms",
                            atag, p.name, rtag, ping),
                        10, y
                    )
                    y = y + 17
                end
            end
            y = y + 6
        end
    end

    -- ── Separador ─────────────────────────────────────────────────────────────
    local logTop = H - (LOG_MAX * 16) - 26
    if logTop < y + 6 then logTop = y + 6 end
    love.graphics.setColor(0.25, 0.30, 0.35)
    love.graphics.line(0, logTop, W, logTop)
    love.graphics.setColor(0.95, 0.80, 0.15)
    love.graphics.print("  LOG", 8, logTop + 4)
    love.graphics.setColor(0.25, 0.30, 0.35)
    love.graphics.line(0, logTop + 20, W, logTop + 20)

    -- ── Log ───────────────────────────────────────────────────────────────────
    love.graphics.setColor(0.55, 0.75, 0.55)
    local ly = logTop + 24
    for _, entry in ipairs(serverLog) do
        love.graphics.print("  > " .. entry, 10, ly)
        ly = ly + 16
        if ly > H - 4 then break end
    end

    love.graphics.setColor(1, 1, 1)
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Loop principal
-- ─────────────────────────────────────────────────────────────────────────────

function love.update(dt)
    server:update()

    -- Ping periódico para todos los jugadores en salas
    pingTimer = pingTimer + dt
    if pingTimer >= PING_TICK then
        pingTimer = 0
        for _, room in pairs(rooms) do
            if #room.playerIds > 0 then broadcastRoomUpdate(room) end
        end
    end

    -- Game state broadcast (20 fps) solo para salas IN_GAME
    gameTimer = gameTimer + dt
    if gameTimer >= GAME_TICK then
        gameTimer = 0
        for _, room in pairs(rooms) do
            if room.state == "IN_GAME" then broadcastGameState(room) end
        end
    end
end
