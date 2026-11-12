-- server/srv/lobby.lua
-- PARTE de server/main.lua: las conexiones y los mensajes de los clientes (salas, admin, inputs).
-- La carga server/main.lua con require(...)(S): S = el estado y las funciones que comparten las partes (los
-- módulos del juego, que se cargan en love.load, también: S.Level, S.Entities...).

return function(S)
local Protocol, NameFilter, Modes, Lang, Updates, PORT = S.Protocol, S.NameFilter, S.Modes, S.Lang, S.Updates, S.PORT
local MSG_RATE, MSG_BURST, FLOOD_LIMIT, INVALID_LIMIT, MAX_CONN_PER_IP, JOIN_FAIL_MAX = S.MSG_RATE, S.MSG_BURST, S.FLOOD_LIMIT, S.INVALID_LIMIT, S.MAX_CONN_PER_IP, S.JOIN_FAIL_MAX
local JOIN_FAIL_LOCK, PASSWORD_MAX, ROOM_NAME_MAX, MAX_SEQ_AHEAD, PLAYER_COLORS, server = S.JOIN_FAIL_LOCK, S.PASSWORD_MAX, S.ROOM_NAME_MAX, S.MAX_SEQ_AHEAD, S.PLAYER_COLORS, S.server
local players, rooms = S.players, S.rooms
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
        S.announceToRoom(room, 'srv.left', { name = player.name }, 'leave')
    end

    if #room.playerIds == 0 then
        rooms[room.id] = nil
        S.log("Sala '" .. room.name .. "' eliminada (vacia).")
        return true
    end

    if room.adminId == player.id then
        -- (el primero que SIGA conectado: uno que se fue en plena partida no puede ser admin)
        room.adminId = room.playerIds[1]
        for _, pid in ipairs(room.playerIds) do if S.findClientById(pid) then room.adminId = pid; break end end
        local newName = S.findPlayerNameById(room.adminId)
        S.announceToRoom(room, 'srv.new_host', { name = newName }, 'admin')
        S.log("Nuevo admin de '" .. room.name .. "': " .. newName)
    end

    S.broadcastRoomUpdate(room)
    return false
end

-- Expulsa una conexión (abuso, versión, timeout). La desconexión es "graceful":
-- ENet dispara luego el evento disconnect y ahí se limpia `players`.
local function dropClient(client, reason)
    local p = players[client]
    if not p or p.kicked then return end
    p.kicked = true
    S.log("Expulsando " .. (p.name or S.peerIP(client)) .. ": " .. reason)
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

-- Actualizaciones automáticas de los clientes (sin login; ver updates.lua)
Updates.register(function(event, handler)
    on(event, function(data, client, p)
        p.updT = love.timer.getTime()
        handler(data, client, p)
    end, true)
end)

-- El cliente terminó de CARGAR el nivel de la partida (0.5.202): el servidor espera a todos antes de la tarjeta y la
-- cuenta atrás (server/srv/sim.lua S.startWaitOver)
on("level_loaded", function(data, client, player)
    if not player.roomId then return end
    local room = rooms[player.roomId]
    local sim = room and room.sim
    if not sim or sim.startTicks then return end
    sim.loaded[player.id] = true
    sim.firstLoadedTick = sim.firstLoadedTick or sim.tick
end)

-- El resultado del duelo de ritmo de un jugador: cada cliente lo juega contra su música (src/ui/RhythmDuel.lua)
on("rhythm_result", function(data, client, player)
    if type(data) ~= "table" or not player.roomId then return end
    local room = rooms[player.roomId]
    if not room or room.state ~= "IN_GAME" or not room.sim then return end
    local ps = room.sim.playerSims[player.id]
    if not ps or ps.isSpectator or type(data.acc) ~= "number" or type(data.bar) ~= "number" then return end
    for _, e in ipairs(room.sim.enemies or {}) do
        if e.duelReport then e:duelReport(ps.pa, data.bar, data.acc, data.failed == true) end
    end
end)

-- La POSE de un jugador en el duelo de ritmo (acierto / fallo de una flecha): solo dibujo; se reenvía a los demás de
-- su sala, que lo ven bailar en el minijuego (src/ui/RhythmDuel.lua: R.remotePose)
on("rhythm_pose", function(data, client, player)
    if type(data) ~= "table" or not player.roomId or type(data.lane) ~= "number" then return end
    local room = rooms[player.roomId]
    if not room or room.state ~= "IN_GAME" then return end
    local msg = { id = player.id, lane = math.max(1, math.min(4, math.floor(data.lane))), ok = data.ok == true }
    for _, pid in ipairs(room.playerIds) do
        if pid ~= player.id then
            local c = S.findClientById(pid)
            if c then c:send("rhythm_pose", msg) end
        end
    end
end)

server.onInvalidPacket = function(client, size)
    local p = client and players[client]
    if not p or p.kicked then return end
    p.invalid = p.invalid + 1
    if p.invalid >= INVALID_LIMIT then dropClient(client, "paquetes malformados") end
end

server.onHandlerError = function(client, eventName, err)
    S.log("ERROR en handler '" .. tostring(eventName) .. "': " .. tostring(err))
end

S.log("FlappyMonster Online Server (autoritativo) — Puerto " .. PORT
    .. " — protocolo v" .. Protocol.VERSION)

server:on("connect", function(data, client)
    local ip  = S.peerIP(client)
    local now = love.timer.getTime()
    players[client] = {
        id=nil, name=nil, verified=false, roomId=nil, isReady=false, color=nil,
        ip=ip, tokens=MSG_BURST, lastT=now, dropped=0, dropWindow=now, invalid=0,
        kicked=false, connectedAt=now,
    }
    -- Detectar desconexiones en 3-10 s en vez de ~30 s
    pcall(function() client.connection:timeout(32, 3000, 10000) end)

    local n = 0
    for _, p in pairs(players) do if p.ip == ip and not p.kicked then n = n + 1 end end
    if n > MAX_CONN_PER_IP then
        dropClient(client, "demasiadas conexiones desde " .. ip)
        return
    end
    S.log("Cliente conectando desde " .. ip)
end)

-- Handshake: versión de protocolo + nickname.
on("hello", function(data, client, p)
    if p.verified then return end
    if type(data) ~= "table" or data.v ~= Protocol.VERSION then
        client:send("login_error", Lang.message('srv.version'))
        return
    end
    -- El nombre se valida AQUÍ también (longitud, caracteres, palabras vetadas: src/network/NameFilter.lua): el
    -- cliente ya lo comprueba antes de enviar, pero uno modificado podría saltárselo
    local name = type(data.name) == 'string' and data.name:match('^%s*(.-)%s*$') or nil
    local okName, why = NameFilter.check(name)
    if not okName then
        client:send("login_error", Lang.message(why == 'blocked' and 'srv.name_blocked' or 'srv.bad_name')); return
    end
    local lname = name:lower()
    for _, other in pairs(players) do
        if other.verified and not other.kicked and other.name:lower() == lname then
            client:send("login_error", Lang.message('srv.name_taken')); return
        end
    end
    p.id, p.name, p.verified = S.newPlayerId(), name, true
    -- VOLVER A ENTRAR: con el `rejoin` que dio game_init y el mismo nombre, a la partida en marcha que se le cortó
    local room, ps = S.findAway(data.rejoin, name)
    if room then p.id = ps.id end
    S.log("Registrado: '" .. name .. "' (" .. p.ip .. ")" .. (room and (" — vuelve a '" .. room.name .. "'") or ""))
    client:send("login_success", { name=name, id=p.id })
    if room then
        p.roomId, p.color, p.isReady = room.id, ps.color, false
        S.resumePlayerSim(ps)
        S.broadcastRoomUpdate(room)
        S.sendGameInit(room, ps.id)
        S.announceToRoom(room, 'srv.rejoined', { name = name }, 'join')
    end
end, true)

-- ── Volver a entrar ──────────────────────────────────────────────────────────
-- A quien se le corta la conexión en plena partida no se le saca: su jugador se queda quieto en la partida (`away`)
-- REJOIN_T s, por si vuelve (hello con su `rejoin`). Pasado ese tiempo, o si ya no queda nadie conectado, sale.
local REJOIN_T = 60
function S.findAway(token, name)
    if type(token) ~= 'string' or #token ~= 16 then return nil end
    for _, room in pairs(rooms) do
        for _, ps in pairs(room.sim and room.sim.playerSims or {}) do
            if ps.away and ps.token == token and ps.name:lower() == name:lower() then return room, ps end
        end
    end
end
local function anyoneHere(room)
    for _, pid in ipairs(room.playerIds) do if S.findClientById(pid) then return true end end
    return false
end
function S.dropAway(room, ps)
    for i, pid in ipairs(room.playerIds) do
        if pid == ps.id then table.remove(room.playerIds, i); break end
    end
    room.sim.playerSims[ps.id] = nil
    S.announceToRoom(room, 'srv.left', { name = ps.name }, 'leave')
    if room.adminId == ps.id then
        for _, pid in ipairs(room.playerIds) do if S.findClientById(pid) then room.adminId = pid; break end end
    end
end
function S.checkAway()
    local now = love.timer.getTime()
    for id, room in pairs(rooms) do
        for _, ps in pairs(room.sim and room.sim.playerSims or {}) do
            if ps.away and now - ps.away > REJOIN_T then S.dropAway(room, ps) end
        end
        if #room.playerIds == 0 or not anyoneHere(room) then
            rooms[id] = nil
            S.log("Sala '" .. room.name .. "' eliminada (nadie conectado).")
        end
    end
end

-- Clientes antiguos (protocolo v1): avisar en su pantalla de login.
on("set_nickname", function(data, client, p)
    client:send("room_error", Lang.message('srv.outdated'))
end, true)

on("get_rooms", function(data, client, p)
    client:send("room_list", S.buildPublicRoomList(type(data) == "table" and data.daily == true))   -- (daily: la del club del día)
end)

on("create_room", function(data, client, player)
    if type(data) ~= "table" then return end
    if player.roomId then client:send("room_error",Lang.message('srv.already_in_room')); return end
    local name = Protocol.sanitizeName(data.name, ROOM_NAME_MAX)
    if name and NameFilter.isBlocked(name) then name = nil end        -- (nombres de sala: el mismo filtro de palabras)
    name = name or ("Sala de " .. player.name)
    local isPublic   = (data.isPublic ~= false)
    local password   = S.cleanText(data.password, PASSWORD_MAX)
    -- PRIVADA = con contraseña (sin ella estaba en la lista y abierta a cualquiera)
    if not isPublic and password == "" then client:send("room_error", Lang.message('srv.password_required')); return end
    local maxPlayers = tonumber(data.maxPlayers) or 4
    if not S.isInt(maxPlayers, 1, 8) then client:send("room_error",Lang.message('srv.max_players')); return end
    local roomId = S.newRoomId()
    rooms[roomId] = { id=roomId, name=name, isPublic=isPublic, password=password,
                      maxPlayers=maxPlayers, playerIds={player.id},
                      adminId=player.id, state="WAITING", bannedNames={}, bannedIPs={}, sim=nil,
                      mode=Modes.DEFAULT, level=nil }
    -- (una sala del CLUB DEL DÍA: Carrera en el nivel de hoy, con su propia lista — server/srv/records.lua —)
    if data.daily == true and not S.makeDaily(rooms[roomId]) then
        rooms[roomId] = nil; client:send("room_error", Lang.message('srv.no_map')); return
    end
    player.roomId  = roomId
    player.isReady = false
    player.color   = PLAYER_COLORS[1]
    S.log("Sala '" .. name .. "' creada por " .. player.name)
    S.broadcastRoomUpdate(rooms[roomId])
end)

-- Contraseñas falladas, por IP (por conexión, volver a conectar las ponía a cero): [ip] = { fails, lockUntil, t }
local joinLocks = {}
-- Entrar en una sala (join_room y el desafío del día: server/srv/records.lua)
function S.joinRoom(client, player, room, password)
    local now = love.timer.getTime()
    for ip, j in pairs(joinLocks) do if now - j.t > 600 and now >= j.lockUntil then joinLocks[ip] = nil end end
    local jl = joinLocks[player.ip]
    if jl and now < jl.lockUntil then
        client:send("room_error",Lang.message('srv.too_many_tries')); return
    end
    -- (con la partida en marcha se entra a MIRAR: sin vidas hasta la próxima ronda — addPlayerSim `late` —)
    local late = room.state == "IN_GAME" and room.sim and not room.sim.ended
    if room.state ~= "WAITING" and not late then client:send("room_error",Lang.message('srv.room_in_game')); return end
    if #room.playerIds >= room.maxPlayers then client:send("room_error",Lang.message('srv.room_full')); return end
    if room.bannedNames[player.name:lower()] or room.bannedIPs[player.ip] then
        client:send("room_error",Lang.message('srv.banned_here', nil,
                                   { kind = "banned", room = room.name })); return
    end
    if room.password ~= "" and room.password ~= S.cleanText(password, PASSWORD_MAX) then
        jl = jl or { fails = 0, lockUntil = 0 }
        joinLocks[player.ip] = jl
        jl.fails, jl.t = jl.fails + 1, now
        if jl.fails >= JOIN_FAIL_MAX then
            jl.fails = 0
            jl.lockUntil = now + JOIN_FAIL_LOCK
            S.log(player.name .. " bloqueado " .. JOIN_FAIL_LOCK .. "s por contrasenas erroneas")
        end
        client:send("room_error",Lang.message('srv.wrong_password')); return
    end
    if jl then jl.fails = 0 end
    table.insert(room.playerIds, player.id)
    player.roomId  = room.id
    player.isReady = false
    player.color   = PLAYER_COLORS[#room.playerIds] or {1,1,1}
    S.log(player.name .. " se unio a '" .. room.name .. "'" .. (late and " (mirando)" or ""))
    if late then
        local idx = 0
        for _, ps in pairs(room.sim.playerSims) do idx = math.max(idx, ps.idx) end
        local sx, sy = room.sim.level:getSpawnPx()
        S.addPlayerSim(room.sim, player.id, idx + 1, sx, sy, player, true)
    end
    S.broadcastRoomUpdate(room)
    if late then S.sendGameInit(room, player.id) end
    S.announceToRoom(room, late and 'srv.joined_watch' or 'srv.joined', { name = player.name }, 'join')
end

on("join_room", function(data, client, player)
    if type(data) ~= "table" then return end
    if player.roomId then client:send("room_error",Lang.message('srv.already_in_room')); return end
    local room = rooms[tostring(data.id or ""):sub(1, 12)]
    if not room then client:send("room_error",Lang.message('srv.room_not_found')); return end
    S.joinRoom(client, player, room, data.password)
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
    S.log(player.name .. (player.isReady and " → LISTO" or " → no listo"))
    S.broadcastRoomUpdate(room)
end)

on("start_game", function(data, client, player)
    if not player.roomId then return end
    local room = rooms[player.roomId]
    if not room then return end
    if room.adminId ~= player.id then client:send("room_error",Lang.message('srv.only_host_start')); return end
    if room.state == "IN_GAME"   then client:send("room_error",Lang.message('srv.already_playing')); return end
    if #room.playerIds < 2 and not room.daily then client:send("room_error",Lang.message('srv.need_two')); return end   -- (el desafío del día, solo)

    for _, pid in ipairs(room.playerIds) do
        local c = S.findClientById(pid)
        if c and not players[c].isReady then
            client:send("room_error",Lang.message('srv.not_all_ready')); return
        end
    end

    -- Asignar colores
    for i, pid in ipairs(room.playerIds) do
        local c = S.findClientById(pid)
        if c then players[c].color = PLAYER_COLORS[i] or {1,1,1} end
    end

    S.scanLevels(true)
    S.ensureRoomLevel(room)
    if not room.level then
        client:send("room_error",Lang.message('srv.no_map')); return
    end

    room.state = "IN_GAME"
    room.sim   = S.initRoomSim(room)

    S.log("Partida iniciada en '" .. room.name .. "'!")
    S.announceToRoom(room, 'srv.started', nil, 'game')
    S.broadcastRoomUpdate(room)   -- el cliente cambia a OnlineAdventureState...
    S.sendGameInit(room)          -- ...y recibe los datos iniciales (mismo canal, en orden)
end)

on("stop_game", function(data, client, player)
    if not player.roomId then return end
    local room = rooms[player.roomId]
    if not room then return end
    if room.adminId ~= player.id then client:send("room_error",Lang.message('srv.only_host_stop')); return end
    if room.state ~= "IN_GAME" then return end
    S.announceToRoom(room, 'srv.stopped', nil, 'game')
    S.endGame(room, "detenida por el admin")
end)

-- El host elige modo de juego y nivel (solo en la sala de espera)
local function adminRoom(client, player)
    local room = player.roomId and rooms[player.roomId]
    if not room then return nil end
    if room.adminId ~= player.id then client:send("room_error",Lang.message('srv.only_host')); return nil end
    if room.state ~= "WAITING" then return nil end
    if room.daily then client:send("room_error",Lang.message('srv.daily_fixed')); return nil end   -- (el desafío del día no se cambia)
    return room
end

on("set_mode", function(data, client, player)
    if type(data) ~= "table" or type(data.mode) ~= "string" then return end
    local room = adminRoom(client, player)
    if not room or not Modes.get(data.mode) then return end
    room.mode = data.mode
    -- Nivel elegido junto al modo (menú del lobby); si no sirve, uno compatible
    local info = type(data.level) == "string" and S.levelInfo(data.level)
    if info and info.modes[room.mode] then room.level = info.path end
    -- Dificultad de la sala (opcional): un id de src/core/Difficulty.lua o 'none'
    if data.difficulty == 'none' then room.difficulty = nil
    elseif S.Difficulty.valid(data.difficulty) then room.difficulty = data.difficulty end
    S.ensureRoomLevel(room)
    S.log(player.name .. " cambio el modo a " .. Modes.get(room.mode).label)
    S.broadcastRoomUpdate(room)
end)

-- DIFICULTAD de la sala (la elige el host en la sala de espera; todos la ven en el room_update y llega a la
-- partida en game_init): un id de src/core/Difficulty.lua o 'none' (el juego de siempre)
on("set_difficulty", function(data, client, player)
    if type(data) ~= "table" then return end
    local room = adminRoom(client, player)
    if not room then return end
    if data.difficulty == 'none' then room.difficulty = nil
    elseif S.Difficulty.valid(data.difficulty) then room.difficulty = data.difficulty
    else return end
    S.log(player.name .. " cambio la dificultad a " .. tostring(room.difficulty or 'ninguna'))
    S.broadcastRoomUpdate(room)
end)

-- Catálogo de niveles con miniaturas (lo pide el menú de modos del lobby)
-- (la lista con miniaturas pesa ~100 KB: como mucho una cada 2 s por cliente — repetida a 120/s eran ~13 MB/s)
local GET_LEVELS_EVERY = 2
on("get_levels", function(data, client, player)
    local room = player.roomId and rooms[player.roomId]
    if not room then return end
    local now = love.timer.getTime()
    if player.getLevelsT and now - player.getLevelsT < GET_LEVELS_EVERY then return end
    player.getLevelsT = now
    local levels = S.scanLevels()
    if not S.levelCatalogMsg then
        local list = {}
        for _, info in ipairs(levels) do
            local modes = {}
            for id in pairs(info.modes) do modes[#modes+1] = id end
            list[#list+1] = { path = info.path, name = info.name, name_en = info.name_en, w = info.w, h = info.h,
                              enemies = info.enemies, finish = info.finish, modes = modes,
                              preview = info.preview }
        end
        S.levelCatalogMsg = { levels = list }
    end
    client:send("level_catalog", S.levelCatalogMsg)
end)

on("set_level", function(data, client, player)
    if type(data) ~= "table" or type(data.level) ~= "string" then return end
    local room = adminRoom(client, player)
    if not room then return end
    local info = S.levelInfo(data.level)
    if not info or not info.modes[room.mode] then
        client:send("room_error",Lang.message('srv.map_not_valid')); return
    end
    room.level = info.path
    S.broadcastRoomUpdate(room)
end)

local function adminTarget(data, client, admin, selfKey)
    if type(data) ~= "table" or not admin.roomId then return end
    local room = rooms[admin.roomId]
    if not room or room.adminId ~= admin.id then client:send("room_error",Lang.message('srv.not_host')); return end
    local targetId = tostring(data.playerId or ""):sub(1, 32)
    if targetId == admin.id then client:send("room_error",Lang.message(selfKey)); return end
    local tc = S.findClientById(targetId)
    if not tc or players[tc].roomId ~= room.id then client:send("room_error",Lang.message('srv.player_gone')); return end
    return room, tc
end

on("kick_player", function(data, client, admin)
    local room, tc = adminTarget(data, client, admin, 'srv.cant_kick_self')
    if not room then return end
    local tname = players[tc].name
    tc:send("kicked", Lang.message('srv.kicked', { by = admin.name }, { room = room.name, by = admin.name }))
    removePlayerFromRoom(players[tc], room, true)
    S.announceToRoom(room, 'srv.was_kicked', { name = tname }, 'kick')
    S.log(admin.name .. " kickeo a " .. tname)
end)

-- DENUNCIAR a otro jugador de la misma sala (cualquiera, no solo el admin): se apunta en `reports.log` (la carpeta de
-- guardado del servidor) con la hora, la sala, quién y a quién (su nombre, su id y un trozo de su IP), para revisarlo a
-- mano. Una denuncia por pareja cada REPORT_EVERY s (si no, `again`).
local REPORT_EVERY = 600
local reported = {}
on("report_player", function(data, client, player)
    if type(data) ~= "table" or not player.roomId then return end
    local targetId = tostring(data.playerId or ""):sub(1, 32)
    local tc = S.findClientById(targetId)
    if targetId == player.id or not tc or players[tc].roomId ~= player.roomId then return end
    local key, now = player.id .. '>' .. targetId, love.timer.getTime()
    if reported[key] and now - reported[key] < REPORT_EVERY then client:send("reported", { again = true }); return end
    reported[key] = now
    local t, room = players[tc], rooms[player.roomId]
    local ipPart = (t.ip or '?'):match('^(%d+%.%d+)') or '?'
    local line = ('%s\tsala=%s\tdenuncia=%s\ta=%s (%s, ip %s.*)\n'):format(os.date('!%Y-%m-%d %H:%M:%S'),
        room and room.name or '?', player.name or '?', t.name or '?', targetId, ipPart)
    love.filesystem.append('reports.log', line)
    S.log('DENUNCIA: ' .. (player.name or '?') .. ' a ' .. (t.name or '?'))
    client:send("reported", {})
end)

-- CEDER EL ADMIN a otro jugador de la sala: él pasa a ser el admin y quien lo cede deja de serlo en el acto (solo hay
-- un admin, `room.adminId`); todos lo ven en el siguiente room_update. Vale en la sala de espera y con la partida en marcha.
on("give_admin", function(data, client, admin)
    local room, tc = adminTarget(data, client, admin, 'srv.cant_admin_self')
    if not room then return end
    local target = players[tc]
    room.adminId = target.id
    S.announceToRoom(room, 'srv.new_host', { name = target.name }, 'admin')
    S.broadcastRoomUpdate(room)
    S.log(admin.name .. " cedio el admin de '" .. room.name .. "' a " .. target.name)
end)

on("ban_player", function(data, client, admin)
    local room, tc = adminTarget(data, client, admin, 'srv.cant_ban_self')
    if not room then return end
    local target = players[tc]
    local tname  = target.name
    -- Por nombre Y por IP: cambiarse el nick ya no evita el baneo.
    room.bannedNames[tname:lower()] = true
    room.bannedIPs[target.ip] = true
    tc:send("banned", Lang.message('srv.banned', { by = admin.name },
                        { room = room.name, by = admin.name }))
    removePlayerFromRoom(target, room, true)
    S.announceToRoom(room, 'srv.was_banned', { name = tname }, 'ban')
    S.log(admin.name .. " baneo a " .. tname)
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
    if not S.isInt(first, 1, 2^31) or type(list) ~= "table" then return end
    -- Tick del mundo que el cliente tenía en pantalla al generar el último input
    local view = data.v
    if view ~= nil and not S.isInt(view, 0, 2^31) then return end
    local n = #list
    if n < 1 or n > Protocol.INPUT_REDUNDANCY * 2 then return end

    for i = 1, n do
        local bits = list[i]
        if not S.isInt(bits, 0, Protocol.IN_MAX) then return end
    end
    -- Muy por delante de lo procesado: el cliente siguió contando durante un corte de red (sus paquetes se
    -- perdieron) → se salta hasta él, lo perdido ya no vuelve. (Antes se tiraba el paquete y, tras un corte de 3-6 s,
    -- TODOS los siguientes: el jugador no volvía a moverse. Un seq inventado solo se perjudica a sí mismo.)
    if first + n - 1 > ps.lastProcSeq + MAX_SEQ_AHEAD then
        for i = #ps.queue, 1, -1 do ps.queue[i] = nil end
        ps.lastProcSeq, ps.lastRecvSeq, ps.highQueue = first - 1, first - 1, 0
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
        client:send("room_error",Lang.message('srv.not_host')); return
    end
    S.log("Sala '" .. room.name .. "' cerrada por " .. admin.name)
    for _, pid in ipairs(room.playerIds) do
        local c = S.findClientById(pid)
        if c then
            c:send("room_closed", Lang.message('srv.room_closed', { by = admin.name }, { room = room.name, by = admin.name }))
            players[c].roomId=nil; players[c].isReady=false; players[c].color=nil
        end
    end
    rooms[room.id] = nil
end)

server:on("disconnect", function(data, client)
    local player = players[client]
    if not player then return end
    S.log("Desconectado: '" .. (player.name or player.ip) .. "'")
    if player.roomId then
        local room = rooms[player.roomId]
        local ps = room and room.sim and not room.sim.ended and room.sim.playerSims[player.id]
        if ps and not ps.isSpectator then
            -- (en plena partida: se queda quieto esperando a que vuelva — S.checkAway —)
            ps.away, ps.queue, ps.lastBits = love.timer.getTime(), {}, 0
            players[client] = nil
            S.announceToRoom(room, 'srv.dropped', { name = player.name }, 'leave')
            if not anyoneHere(room) then S.checkAway() end
            return
        end
        if room then removePlayerFromRoom(player, room, false) end
    end
    players[client] = nil
end)



-- (lo que usan las demás partes)
S.removePlayerFromRoom = removePlayerFromRoom
S.dropClient = dropClient
S.rateOk = rateOk
S.on = on
S.adminRoom = adminRoom
S.adminTarget = adminTarget
end
