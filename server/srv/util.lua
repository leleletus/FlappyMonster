-- server/srv/util.lua
-- PARTE de server/main.lua: utilidades (registro, ids, buscar clientes, validar texto, mandar estado).
-- La carga server/main.lua con require(...)(S): S = el estado y las funciones que comparten las partes (los
-- módulos del juego, que se cargan en love.load, también: S.Level, S.Entities...).

return function(S)
local nextRoomId, nextPlayerSerial = 1, 1
local Protocol, LOG_MAX, players, rooms, serverLog = S.Protocol, S.LOG_MAX, S.players, S.rooms, S.serverLog
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


-- (lo que usan las demás partes)
S.log = log
S.newRoomId = newRoomId
S.newPlayerId = newPlayerId
S.findClientById = findClientById
S.findPlayerNameById = findPlayerNameById
S.countPlayers = countPlayers
S.countRooms = countRooms
S.peerIP = peerIP
S.isInt = isInt
S.cleanText = cleanText
S.sendState = sendState
end
