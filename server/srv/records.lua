-- server/srv/records.lua
-- PARTE de server/main.lua: los RÉCORDS (las mejores marcas de Carrera de cada nivel) y el DESAFÍO DEL DÍA.
-- La carga server/main.lua con require(...)(S): S = el estado y las funciones que comparten las partes.
--
-- · records.json (carpeta de guardado del servidor): { levels = { [nivel] = { {name, time, date}, … } },
--   daily = { [fecha] = { level, list = { … } } } }. Por nivel, los TOP mejores tiempos (uno por nombre: su mejor).
--   Se apunta al acabar cada ronda de Carrera (S.recordRound, desde server/srv/sim.lua) con quien llegó a la meta.
-- · Desafío del día: un nivel de Carrera SIN jefes por día (UTC), elegido con la fecha. Se juega EN SOLITARIO
--   (`join_daily`: una sala privada de 1, fuera de las listas) o en el CLUB DEL DÍA (`create_room { daily = true }`:
--   salas con su propia lista, `get_rooms { daily = true }`; las normales no salen ahí ni ellas en la normal).
--   Pueden empezar con UN jugador y no se cambian (lobby: room.daily). Sus llegadas van también a la tabla del día.
-- Mensajes: `get_records { level? }` → `records` (sin nivel: el índice — cada nivel con su mejor marca — y el día;
-- con nivel: su lista) · `join_daily` → el desafío en solitario.

return function(S)
local Lang, PLAYER_COLORS, players, rooms = S.Lang, S.PLAYER_COLORS, S.players, S.rooms
local FILE, TOP, KEEP_DAYS = 'records.json', 10, 7

local data
local function load()
    if data then return data end
    local ok, d = pcall(function() return S.json.decode(love.filesystem.read(FILE)) end)
    data = (ok and type(d) == 'table') and d or {}
    data.levels, data.daily = data.levels or {}, data.daily or {}
    return data
end
local function save() pcall(love.filesystem.write, FILE, S.json.encode(data)) end

local function today() return os.date('!%Y-%m-%d') end

-- Una marca en una lista (la mejor por nombre, ordenada, las TOP primeras). ¿Entró?
local function add(list, name, time, date)
    for i, e in ipairs(list) do
        if e.name:lower() == name:lower() then
            if time >= e.time then return false end
            table.remove(list, i); break
        end
    end
    list[#list + 1] = { name = name, time = time, date = date }
    table.sort(list, function(a, b) return a.time < b.time end)
    while #list > TOP do table.remove(list) end
    for _, e in ipairs(list) do if e.name == name and e.time == time then return true end end
    return false
end

-- El nivel del desafío de `date`: uno de Carrera sin jefes, siempre el mismo para esa fecha
function S.dailyLevel(date)
    local list = {}
    for _, info in ipairs(S.levelsForMode('race')) do
        if (info.bosses or 0) == 0 then list[#list + 1] = info end
    end
    if #list == 0 then return nil end
    table.sort(list, function(a, b) return a.path < b.path end)
    local h = 0
    for i = 1, #date do h = (h * 31 + date:byte(i)) % 1000003 end
    return list[h % #list + 1]
end

-- Fin de una ronda (sim.lua, con el evento round_end): las llegadas de Carrera, a sus tablas
function S.recordRound(room, ev)
    if ev.mode ~= 'race' or not room.level then return end
    local d, date = load(), today()
    d.levels[room.level] = d.levels[room.level] or {}
    local any = false
    for _, e in ipairs(ev.entries or {}) do
        if e.finished and type(e.time) == 'number' and e.time > 0 then
            if add(d.levels[room.level], e.name, e.time, date) then any = true end
            if room.daily == date then
                d.daily[date] = d.daily[date] or { level = room.level, list = {} }
                if add(d.daily[date].list, e.name, e.time, date) then any = true end
            end
        end
    end
    -- (los días viejos se van: solo los últimos KEEP_DAYS)
    local days = {}
    for k in pairs(d.daily) do days[#days + 1] = k end
    table.sort(days)
    for i = 1, #days - KEEP_DAYS do d.daily[days[i]] = nil end
    if any then save() end
end

S.on("get_records", function(msg, client)
    local d = load()
    local date = today()
    local dl = S.dailyLevel(date)
    local daily = { date = date, level = dl and dl.path, name = dl and dl.name, name_en = dl and dl.name_en,
                    list = (d.daily[date] and d.daily[date].list) or {} }
    if type(msg) == 'table' and type(msg.level) == 'string' then
        local info = S.levelInfo(msg.level)
        client:send("records", { level = msg.level, name = info and info.name, name_en = info and info.name_en,
                                 list = d.levels[msg.level] or {}, daily = daily })
        return
    end
    local index = {}
    for path, list in pairs(d.levels) do
        local info = S.levelInfo(path)
        if info and list[1] then
            index[#index + 1] = { level = path, name = info.name, name_en = info.name_en, best = list[1] }
        end
    end
    table.sort(index, function(a, b) return a.name:lower() < b.name:lower() end)
    client:send("records", { index = index, daily = daily })
end)

-- DESAFÍO EN SOLITARIO: una sala solo tuya (privada, de 1, fuera de todas las listas) con el nivel del día
S.on("join_daily", function(msg, client, player)
    if player.roomId then client:send("room_error", Lang.message('srv.already_in_room')); return end
    local date = today()
    local dl = S.dailyLevel(date)
    if not dl then client:send("room_error", Lang.message('srv.no_map')); return end
    local roomId = S.newRoomId()
    local room = { id = roomId, name = Lang('srv.daily_room', { date = date }), isPublic = false, password = '',
                   maxPlayers = 1, playerIds = { player.id }, adminId = player.id, state = "WAITING",
                   bannedNames = {}, bannedIPs = {}, sim = nil, mode = 'race', level = dl.path, daily = date, solo = true }
    rooms[roomId] = room
    player.roomId, player.isReady, player.color = roomId, false, PLAYER_COLORS[1]
    S.log("Desafío del día en solitario (" .. date .. ", " .. dl.path .. ") de " .. player.name)
    S.broadcastRoomUpdate(room)
end)

-- Una sala del CLUB DEL DÍA (create_room con daily = true, server/srv/lobby.lua): Carrera en el nivel de hoy.
-- false si hoy no hay nivel.
function S.makeDaily(room)
    local date = today()
    local dl = S.dailyLevel(date)
    if not dl then return false end
    room.mode, room.level, room.daily, room.difficulty = 'race', dl.path, date, nil
    return true
end

-- ¿Sale esta sala en la lista pedida? (las del club, solo las de hoy; las normales, sin desafío; las de un jugador, nunca)
function S.roomListed(room, daily)
    if room.solo then return false end
    if daily then return room.daily == today() end
    return room.daily == nil
end


end
