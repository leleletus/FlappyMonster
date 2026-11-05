-- server/srv/broadcast.lua
-- PARTE de server/main.lua: lo que se manda a los clientes: estado de la sala, datos iniciales, eventos, fotos, fin de partida.
-- La carga server/main.lua con require(...)(S): S = el estado y las funciones que comparten las partes (los
-- módulos del juego, que se cargan en love.load, también: S.Level, S.Entities...).

return function(S)
local bitser, Protocol, Lang, TICK_DT, SNAPSHOT_EVERY, round = S.bitser, S.Protocol, S.Lang, S.TICK_DT, S.SNAPSHOT_EVERY, S.round
local NEAR_X, NEAR_Y, DROWN_TOTAL, players, rooms = S.NEAR_X, S.NEAR_Y, S.DROWN_TOTAL, S.players, S.rooms
-- ─────────────────────────────────────────────────────────────────────────────
--  Broadcasts
-- ─────────────────────────────────────────────────────────────────────────────

local function broadcastRoomUpdate(room)
    local playerList = {}
    for _, pid in ipairs(room.playerIds) do
        local c = S.findClientById(pid)
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
    S.ensureRoomLevel(room)
    local levels = {}
    for _, info in ipairs(S.levelsForMode(room.mode)) do levels[#levels+1] = { path = info.path, name = info.name, name_en = info.name_en } end
    local cur = room.level and S.levelInfo(room.level)
    local payload = {
        id=room.id, name=room.name, isPublic=room.isPublic,
        hasPassword=(room.password~=""), maxPlayers=room.maxPlayers,
        state=room.state, adminId=room.adminId, players=playerList,
        mode=room.mode, level=room.level, levelName=cur and cur.name or nil, levelName_en=cur and cur.name_en or nil, levels=levels,
        difficulty=room.difficulty,                      -- (id de src/core/Difficulty.lua; nil = sin dificultad)
        daily=room.daily,                                -- (el desafío del día: fecha; su nivel y modo no se cambian)
        solo=room.solo,                                  -- (el desafío en solitario: sala de uno, fuera de las listas)
    }
    for _, pid in ipairs(room.playerIds) do
        local c = S.findClientById(pid)
        if c then c:send("room_update", payload) end
    end
end

-- kind: 'join' | 'leave' | 'kick' | 'ban' | 'admin' | 'game' (el cliente lo colorea)
-- key/args: mensaje en assets/lang (cada cliente lo muestra en su idioma)
local function announceToRoom(room, key, args, kind)
    for _, pid in ipairs(room.playerIds) do
        local c = S.findClientById(pid)
        if c then c:send("room_announce", Lang.message(key, args, { kind = kind or 'info' })) end
    end
end

-- daily: la lista del CLUB DEL DÍA (sus salas, solo de hoy) en vez de la normal (server/srv/records.lua S.roomListed)
local function buildPublicRoomList(daily)
    local list = {}
    for _, room in pairs(rooms) do
        if S.roomListed(room, daily) then table.insert(list, {
            id=room.id, name=room.name,
            isPublic=room.isPublic,
            hasPassword=(room.password~=""),
            currentPlayers=#room.playerIds,
            maxPlayers=room.maxPlayers,
            state=room.state,
            daily=room.daily,                               -- (una sala del club del día: su fecha)
        }) end
    end
    return list
end

-- Datos estáticos de la partida: se envían UNA vez (fiable) al empezar, así
-- los snapshots no repiten nombres, colores ni IDs largos.
-- `only`: solo a ese jugador (entra con la partida en marcha o vuelve a entrar)
local function sendGameInit(room, only)
    local sim = room.sim
    local roster = {}
    for _, pid in ipairs(room.playerIds) do
        local ps = sim.playerSims[pid]
        if ps then
            table.insert(roster, { idx=ps.idx, id=pid, name=ps.name, color=ps.color or {1,1,1} })
        end
    end
    for _, pid in ipairs(room.playerIds) do
        local c  = S.findClientById(pid)
        local ps = sim.playerSims[pid]
        if c and ps and (not only or only == pid) then
            c:send("game_init", {
                tick     = sim.tick,
                idx      = ps.idx,
                roster   = roster,
                own      = Protocol.packOwnState(ps.pa),
                tickRate = Protocol.TICK_RATE,
                snapEvery= SNAPSHOT_EVERY,
                mode     = room.mode,
                difficulty = room.difficulty,   -- (nil = sin dificultad)
                level    = sim.levelRaw,        -- el nivel viaja al cliente
                cd       = sim.startTicks,      -- cuenta atrás del principio (ticks), StartCountdown
                rejoin   = ps.token,            -- (para volver a entrar si se corta: hello con `rejoin`)
                late     = ps.late,             -- (entró con la partida en marcha: mira hasta la próxima ronda)
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
        local c = S.findClientById(pid)
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
            if (pa.stunT or 0) > 0 then flags = flags + Protocol.PF_STUNNED end
            if (pa.hurtT or 0) > 0 and not pa.dying then flags = flags + Protocol.PF_HURT end
            if (pa.invT or 0) > 0 and not pa.dying then flags = flags + Protocol.PF_INVULN end
            if (pa.squashT or 0) > 0 and not pa.dying then flags = flags + Protocol.PF_SQUASH end
            if (pa.iceT or 0) > 0 and not pa.dying then flags = flags + Protocol.PF_ICE end
            if pa.lightOn and not pa.dying then flags = flags + Protocol.PF_LIGHT end
            if pa.gulped and (pa.gulpKind or 0) == 0 and not pa.dying then flags = flags + Protocol.PF_GULP end   -- (atrapado por una pinza: se ve)
            table.insert(plist, {
                ps.idx, round(pa.x), round(pa.y), pa.facing, pa.frame, flags,
                pa.lives, pa.hp, ps.score, Protocol.drownCode(pa.drownPhase),
                round(math.max(0, 1 - pa.drownTimer / DROWN_TOTAL) * 100),
                ps.place or 0,
            })
        end
    end

    local elist, ebig, ebox = {}, {}, {}
    for i, e in ipairs(sim.enemies) do
      -- En reposo (p. ej. pinchos colgando): no se envía, el cliente lo sabe
      if not e:netAtRest() then
        local entry = {
            round(e.x), round(e.y), e.facing, e.state, e.frame, e.alive,
            round((e.deadTimer or 0) * 100), round((e.breatheT or 0) * 100),
            e.flipped and 1 or 0,
        }
        -- (lo que se puede cargar: quién lo lleva — índice del jugador, 0 = nadie —, en el 10: systems/Carry)
        local base = 9
        if e.carryable then base = 10; entry[10] = e.carrierIdx or 0 end
        -- Datos propios del tipo (p. ej. pincho y sprite del Crabby)
        local extra = e:netPack()
        if extra then for k, v in ipairs(extra) do entry[base + k] = v end end
        elist[i] = entry
        if (e.def and e.def.boss) or e.netAlways then ebig[i] = true end     -- (`netAlways`: un director, lejos de todos)
        if e.netBounds then ebox[i] = { e:netBounds() } end
      end
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
    local bz = S.BossZones.netPack(sim.level)
    local sc = S.AutoScroll.netPack(sim.level)
    local fc = S.Floods.netPack(sim.level, TICK_DT)     -- inundaciones controladas (jefe / ON-OFF)
    local zc = S.PointAreas.netPack(sim.level)          -- reloj de la zona de puntos que se mueve (nil con una sola)
    for _, pid in ipairs(room.playerIds) do
        local c  = S.findClientById(pid)
        local ps = sim.playerSims[pid]
        if c then
            -- Entidades: a cada jugador solo las que tiene CERCA (los jefes, siempre). Un nivel con más de 100 en
            -- movimiento (laberinto_submarino) daba fotos de 2,2 KB: pasada la MTU, ENet las manda en trozos FIABLES
            -- y una pérdida frena todo el canal. Las que no vienen, el cliente las deja quietas (netRest), fuera de
            -- la vista. Los espectadores ven a otros: todas.
            local el = elist
            if ps and not ps.isSpectator and ps.pa then
                el = ps.elist or {}
                ps.elist = el
                for k in pairs(el) do el[k] = nil end
                -- (desde donde MIRA: muriendo, el cuerpo salta y cae fuera de la pantalla —hasta 500 px por debajo del
                -- nivel— mientras su cámara se queda quieta; medido desde el cuerpo, lo de arriba —los bloques de jefe—
                -- dejaba de venir, el cliente lo daba por "en reposo" y los muros PARPADEABAN: el usuario, 0.5.62)
                if not ps.pa.dying then ps.viewX, ps.viewY = ps.pa.x, ps.pa.y end
                local px, py = ps.viewX or ps.pa.x, ps.viewY or ps.pa.y
                for i, entry in pairs(elist) do
                    -- (lo que ocupa mucho — el cable de un Teleférico —: `netBounds()` = su caja; cerca de ella, se manda)
                    local nb = ebox[i]
                    if ebig[i] or (nb and px > nb[1] - NEAR_X and px < nb[3] + NEAR_X and py > nb[2] - NEAR_Y and py < nb[4] + NEAR_Y)
                       or (not nb and math.abs(entry[1] - px) < NEAR_X and math.abs(entry[2] - py) < NEAR_Y) then el[i] = entry end
                end
            end
            local snap = { t=sim.tick, lt=lt, p=plist, e=el, vb=vb, md=md, bz=bz, sc=sc, fc=fc, zc=zc }
            if ps and not ps.isSpectator then
                snap.a  = ps.lastProcSeq
                snap.o  = Protocol.packOwnState(ps.pa)
                snap.bs = ps.bounceSeq
            end
            -- (FM_PERF: el tamaño de la foto; pasada la MTU (~1200 B) ENet la manda en trozos FIABLES)
            if PERF_SNAP then
                local n = #bitser.dumps({ "s", snap })
                if n > PERF_SNAP.max then PERF_SNAP.max = n end
                PERF_SNAP.sum, PERF_SNAP.n = PERF_SNAP.sum + n, PERF_SNAP.n + 1
                if n > 1200 then PERF_SNAP.big = PERF_SNAP.big + 1 end
            end
            S.sendState(c, "s", snap)
        end
    end
end

local function endGame(room, reason)
    -- (los que se fueron en plena partida y no volvieron salen ya: en la sala de espera no se puede esperar a nadie)
    for _, ps in pairs(room.sim and room.sim.playerSims or {}) do if ps.away then S.dropAway(room, ps) end end
    room.state = "WAITING"
    room.sim   = nil
    for _, pid in ipairs(room.playerIds) do
        local c = S.findClientById(pid)
        if c then players[c].isReady = false end
    end
    broadcastRoomUpdate(room)
    S.log("Partida terminada en sala '" .. room.name .. "' — " .. reason .. ".")
end


-- (lo que usan las demás partes)
S.broadcastRoomUpdate = broadcastRoomUpdate
S.announceToRoom = announceToRoom
S.buildPublicRoomList = buildPublicRoomList
S.sendGameInit = sendGameInit
S.flushEvents = flushEvents
S.broadcastSnapshot = broadcastSnapshot
S.endGame = endGame
end
