local sock   = require "libs.sock"
local bitser = require "libs.bitser"

io.stdout:setvbuf("no")

-- ─────────────────────────────────────────────────────────────────────────────
--  Constantes del juego
-- ─────────────────────────────────────────────────────────────────────────────

local BALL_R       = 15     -- radio de la bolita
local PLAYER_SPEED = 160    -- píxeles/segundo
local HUD_H        = 30     -- altura del HUD superior (área libre de juego)
local MOVE_RATE    = 1/20   -- enviar posición al servidor 20 veces/segundo

-- ─────────────────────────────────────────────────────────────────────────────
--  Estado global
-- ─────────────────────────────────────────────────────────────────────────────

local client = nil
-- LOGIN | LOBBY | CREATE_ROOM | JOIN_PASSWORD | ROOM | GAME
local state  = "LOGIN"
local myName = ""
local myId   = ""

-- ── Lobby ─────────────────────────────────────────────────────────────────────
local roomList           = {}
local selectedRoom       = nil
local lobbyRefreshTimer  = 0
local LOBBY_REFRESH_SECS = 5

-- ── Sala actual (pre-partida) ─────────────────────────────────────────────────
local currentRoom  = nil
local isReady      = false
local pendingAction = nil   -- "kick" | "ban"

-- Anuncios flotantes en la sala
local announcements = {}
local ANNOUNCE_SECS = 5

-- ── Juego ─────────────────────────────────────────────────────────────────────
local gameState    = {}       -- tabla de jugadores recibida del servidor
local myX          = 400      -- posición X local (predicción cliente)
local myY          = 300      -- posición Y local
local myColor      = {1,1,1}  -- color asignado por el servidor
local myPosInit    = false     -- ¿ya inicializamos posición desde server?
local showNames    = true      -- mostrar nombres sobre las bolitas
local moveSendTimer= 0

-- ── Error temporal en pantalla ────────────────────────────────────────────────
local errorMsg   = ""
local errorTimer = 0
local ERROR_SECS = 4

-- ── Formulario creación de sala (wizard 4 pasos) ──────────────────────────────
local createStep  = 1
local createData  = {}
local inputBuffer = ""

-- ─────────────────────────────────────────────────────────────────────────────
--  Utilidades
-- ─────────────────────────────────────────────────────────────────────────────

local function resetCreateForm()
    createStep  = 1
    createData  = { name="", isPublic=true, password="", maxPlayers=4 }
    inputBuffer = ""
end

local function showError(msg)
    errorMsg   = msg
    errorTimer = ERROR_SECS
    print("ERROR: " .. msg)
end

local function addAnnouncement(msg)
    table.insert(announcements, { msg=msg, timer=ANNOUNCE_SECS })
    if #announcements > 4 then table.remove(announcements, 1) end
end

-- Limpia todo el estado de juego/sala
local function cleanGameState()
    gameState   = {}
    myPosInit   = false
    myColor     = {1,1,1}
end

local function cleanRoomState()
    currentRoom   = nil
    isReady       = false
    announcements = {}
    pendingAction = nil
    cleanGameState()
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Handlers de red
-- ─────────────────────────────────────────────────────────────────────────────

local function registerNetworkHandlers()

    client:on("connect", function()
        print("Conectado. Enviando nickname: " .. myName)
        client:send("set_nickname", myName)
    end)

    client:on("login_success", function(data)
        myId  = data.id
        state = "LOBBY"
        client:send("get_rooms", {})
        print("Login OK — id: " .. myId)
    end)

    client:on("room_list", function(data)
        roomList = data
    end)

    -- ── Máquina de estados para room_update ──────────────────────────────────
    --
    --   LOBBY/etc. ──────────────────────────────► ROOM
    --   ROOM  + data.state == "IN_GAME" ─────────► GAME  (partida iniciada)
    --   ROOM  + data.state == "WAITING" ─────────  ROOM  (sin cambio)
    --   GAME  + data.state == "WAITING" ─────────► ROOM  (partida cancelada)
    --   GAME  + data.state == "IN_GAME" ─────────  GAME  (ping update, no transición)
    --
    client:on("room_update", function(data)
        currentRoom = data

        -- Sincronizar nuestro "listo" con el servidor
        for _, p in ipairs(data.players) do
            if p.id == myId then isReady = p.isReady; break end
        end

        if state == "GAME" then
            if data.state == "WAITING" then
                -- Admin canceló/detuvo la partida → volver a sala de espera
                cleanGameState()
                announcements = {}
                pendingAction = nil
                state = "ROOM"
            end
            -- si sigue IN_GAME: mantenemos estado GAME, solo actualizamos currentRoom

        elseif state == "ROOM" then
            if data.state == "IN_GAME" then
                -- ¡La partida comenzó!
                cleanGameState()
                showNames = true
                state = "GAME"
            end

        else
            -- Viniendo de LOGIN, LOBBY, CREATE_ROOM, etc.
            cleanGameState()
            announcements = {}
            pendingAction = nil
            state = "ROOM"
        end
    end)

    client:on("room_announce", function(data)
        addAnnouncement(data.msg)
    end)

    client:on("room_left", function(data)
        cleanRoomState()
        state = "LOBBY"
        client:send("get_rooms", {})
    end)

    client:on("kicked", function(data)
        cleanRoomState()
        showError(data.msg or "Fuiste expulsado.")
        state = "LOBBY"
        client:send("get_rooms", {})
    end)

    client:on("banned", function(data)
        cleanRoomState()
        showError(data.msg or "Fuiste baneado.")
        state = "LOBBY"
        client:send("get_rooms", {})
    end)

    -- El admin cerró la sala completamente: todos vuelven al menú principal
    client:on("room_closed", function(data)
        cleanRoomState()
        showError(data.msg or "La sala fue cerrada.")
        state = "LOBBY"
        client:send("get_rooms", {})
    end)

    -- Posiciones de todos los jugadores en tiempo real
    client:on("game_state", function(data)
        gameState = data

        -- Primera recepción: inicializar posición y color propios
        if not myPosInit then
            for _, p in ipairs(data.players or {}) do
                if p.id == myId then
                    myX       = p.x
                    myY       = p.y
                    myColor   = p.color or {1,1,1}
                    myPosInit = true
                    break
                end
            end
        else
            -- Mantener el color sincronizado (por si el server lo cambia)
            for _, p in ipairs(data.players or {}) do
                if p.id == myId then
                    myColor = p.color or myColor; break
                end
            end
        end
    end)

    client:on("room_error", function(data)
        showError(data.msg)
    end)
end

-- ─────────────────────────────────────────────────────────────────────────────
--  LÖVE callbacks
-- ─────────────────────────────────────────────────────────────────────────────

function love.load()
    love.window.setTitle("Love Online Game")
    love.window.setMode(800, 600)
    resetCreateForm()
end

function love.update(dt)
    -- ── Red ───────────────────────────────────────────────────────────────────
    if client then
        local ok, err = pcall(function() client:update() end)
        if not ok then
            print("Error de red: " .. tostring(err))
            client = nil; state = "LOGIN"; myName = ""; myId = ""
            cleanRoomState(); roomList = {}
            showError("Conexión perdida.")
        end
    end

    -- ── Movimiento del jugador (solo en GAME) ─────────────────────────────────
    if state == "GAME" then
        local W, H = love.graphics.getDimensions()

        if love.keyboard.isDown("left")  then myX = myX - PLAYER_SPEED * dt end
        if love.keyboard.isDown("right") then myX = myX + PLAYER_SPEED * dt end
        if love.keyboard.isDown("up")    then myY = myY - PLAYER_SPEED * dt end
        if love.keyboard.isDown("down")  then myY = myY + PLAYER_SPEED * dt end

        -- Clamp al área de juego (debajo del HUD)
        myX = math.max(BALL_R,        math.min(W - BALL_R,        myX))
        myY = math.max(HUD_H + BALL_R, math.min(H - BALL_R,       myY))

        -- Enviar posición al servidor (rate-limited)
        moveSendTimer = moveSendTimer + dt
        if moveSendTimer >= MOVE_RATE and client then
            moveSendTimer = 0
            client:send("player_move", { x = myX, y = myY })
        end
    else
        moveSendTimer = 0
    end

    -- ── Auto-refresh del lobby ────────────────────────────────────────────────
    if state == "LOBBY" and client then
        lobbyRefreshTimer = lobbyRefreshTimer + dt
        if lobbyRefreshTimer >= LOBBY_REFRESH_SECS then
            lobbyRefreshTimer = 0
            client:send("get_rooms", {})
        end
    else
        lobbyRefreshTimer = 0
    end

    -- ── Timers de anuncios ────────────────────────────────────────────────────
    for i = #announcements, 1, -1 do
        announcements[i].timer = announcements[i].timer - dt
        if announcements[i].timer <= 0 then table.remove(announcements, i) end
    end

    -- ── Timer de error ────────────────────────────────────────────────────────
    if errorTimer > 0 then
        errorTimer = errorTimer - dt
        if errorTimer <= 0 then errorMsg = "" end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Render
-- ─────────────────────────────────────────────────────────────────────────────

function love.draw()
    local W, H = love.graphics.getDimensions()

    -- ─── JUEGO ───────────────────────────────────────────────────────────────
    if state == "GAME" then
        -- Fondo
        love.graphics.setColor(0.10, 0.10, 0.18)
        love.graphics.rectangle("fill", 0, 0, W, H)

        -- Borde del área de juego
        love.graphics.setColor(0.20, 0.20, 0.35)
        love.graphics.rectangle("line", BALL_R, HUD_H + BALL_R,
            W - BALL_R*2, H - HUD_H - BALL_R*2)

        -- HUD superior
        love.graphics.setColor(0.12, 0.12, 0.22)
        love.graphics.rectangle("fill", 0, 0, W, HUD_H)
        love.graphics.setColor(0.90, 0.90, 0.90)
        love.graphics.print(
            "Flechas: mover    [N] " .. (showNames and "Ocultar" or "Mostrar") .. " nombres",
            10, 7
        )

        -- Controles del admin (esquina superior derecha)
        if currentRoom and currentRoom.adminId == myId then
            love.graphics.setColor(1.00, 0.80, 0.15)
            love.graphics.print("[ESC] Volver a sala    [Q] Cerrar sala", W - 310, 7)
        end
        love.graphics.setColor(0.25, 0.27, 0.40)
        love.graphics.line(0, HUD_H, W, HUD_H)

        -- ── Bolitas ──────────────────────────────────────────────────────────
        local font = love.graphics.getFont()
        for _, p in ipairs(gameState.players or {}) do
            -- Usar posición local para el propio jugador (predicción)
            local px = (p.id == myId) and myX or p.x
            local py = (p.id == myId) and myY or p.y
            local c  = p.color or {1, 1, 1}

            -- Sombra
            love.graphics.setColor(0, 0, 0, 0.35)
            love.graphics.circle("fill", px + 2, py + 3, BALL_R)

            -- Relleno
            love.graphics.setColor(c[1], c[2], c[3])
            love.graphics.circle("fill", px, py, BALL_R)

            -- Borde más oscuro
            love.graphics.setColor(c[1] * 0.45, c[2] * 0.45, c[3] * 0.45)
            love.graphics.circle("line", px, py, BALL_R)

            -- Brillo interior (cuadrante superior-izquierdo)
            love.graphics.setColor(1, 1, 1, 0.22)
            love.graphics.circle("fill", px - 4, py - 4, BALL_R * 0.45)

            -- Nombre sobre la bolita
            if showNames then
                local nw = font:getWidth(p.name)
                -- Sombra del texto
                love.graphics.setColor(0, 0, 0, 0.70)
                love.graphics.print(p.name, px - nw/2 + 1, py - BALL_R - 17)
                -- Texto blanco
                love.graphics.setColor(1, 1, 1)
                love.graphics.print(p.name, px - nw/2,     py - BALL_R - 18)
            end
        end

        love.graphics.setColor(1, 1, 1)

    else
        -- ─── ESTADOS NO-JUEGO ─────────────────────────────────────────────────

        -- Error flotante (siempre visible en la parte inferior)
        if errorMsg ~= "" then
            love.graphics.setColor(0.95, 0.25, 0.25)
            love.graphics.print("⚠ " .. errorMsg, 50, H - 22)
            love.graphics.setColor(1, 1, 1)
        end

        -- ── LOGIN ─────────────────────────────────────────────────────────────
        if state == "LOGIN" then
            love.graphics.print("=== LOGIN ===", 50, 30)
            love.graphics.print("Nickname:", 50, 70)
            love.graphics.print("> " .. myName .. "_", 50, 95)
            love.graphics.print("[ENTER] conectar", 50, 125)

        -- ── LOBBY ─────────────────────────────────────────────────────────────
        elseif state == "LOBBY" then
            love.graphics.print("=== LOBBY — " .. myName .. " ===", 50, 30)
            love.graphics.print(
                "[C] Crear sala    [R] Refrescar    (auto cada " .. LOBBY_REFRESH_SECS .. "s)",
                50, 55
            )
            love.graphics.print(string.rep("─", 54), 50, 73)

            if #roomList == 0 then
                love.graphics.print("No hay salas públicas disponibles.", 50, 95)
            else
                for i, room in ipairs(roomList) do
                    local y      = 95 + (i - 1) * 26
                    local lock   = room.hasPassword and "[P]" or "   "
                    local status = room.state == "WAITING" and "Esperando" or "En partida"
                    love.graphics.print(
                        string.format("[%d] %s %-22s  %d/%d  %s",
                            i, lock, room.name,
                            room.currentPlayers, room.maxPlayers, status),
                        50, y
                    )
                end
            end

        -- ── CREAR SALA ────────────────────────────────────────────────────────
        elseif state == "CREATE_ROOM" then
            love.graphics.print("=== CREAR SALA ===  [ESC] Cancelar", 50, 30)
            love.graphics.print(string.rep("─", 54), 50, 50)
            if createStep == 1 then
                love.graphics.print("Paso 1/4 — Nombre de la sala:", 50, 78)
                love.graphics.print("> " .. inputBuffer .. "_", 50, 105)
                love.graphics.print("[ENTER] continuar", 50, 132)
            elseif createStep == 2 then
                love.graphics.print("Paso 2/4 — Visibilidad:", 50, 78)
                love.graphics.print("[P] Pública  (aparece en la lista)", 50, 108)
                love.graphics.print("[V] Privada  (solo por código)", 50, 133)
            elseif createStep == 3 then
                love.graphics.print("Paso 3/4 — Contraseña (vacío = sin contraseña):", 50, 78)
                love.graphics.print("> " .. inputBuffer .. "_", 50, 105)
                love.graphics.print("[ENTER] confirmar", 50, 132)
            elseif createStep == 4 then
                love.graphics.print("Paso 4/4 — Máximo de jugadores (2–16):", 50, 78)
                love.graphics.print("> " .. inputBuffer .. "_", 50, 105)
                love.graphics.print("[ENTER] crear sala", 50, 132)
            end

        -- ── CONTRASEÑA PARA UNIRSE ────────────────────────────────────────────
        elseif state == "JOIN_PASSWORD" then
            love.graphics.print("=== UNIRSE A SALA ===  [ESC] Cancelar", 50, 30)
            if selectedRoom then
                love.graphics.print("Sala: " .. selectedRoom.name, 50, 62)
            end
            love.graphics.print("Contraseña:", 50, 90)
            love.graphics.print("> " .. inputBuffer .. "_", 50, 115)
            love.graphics.print("[ENTER] unirse", 50, 145)

        -- ── SALA DE ESPERA ────────────────────────────────────────────────────
        elseif state == "ROOM" then
            if not currentRoom then
                love.graphics.print("Cargando sala...", 50, 50)
            else
                local isAdmin  = (currentRoom.adminId == myId)
                local stateTag = currentRoom.state == "IN_GAME" and "[EN PARTIDA]" or "[Esperando]"
                local privacy  = currentRoom.isPublic and "Pública" or "Privada"

                love.graphics.print(
                    "=== " .. currentRoom.name .. "  " .. stateTag .. "  " .. privacy .. " ===",
                    50, 30
                )
                love.graphics.print(
                    #currentRoom.players .. "/" .. currentRoom.maxPlayers .. " jugadores",
                    50, 52
                )
                love.graphics.print(string.rep("─", 54), 50, 68)

                for i, p in ipairs(currentRoom.players) do
                    local y       = 85 + (i - 1) * 22
                    local atag    = (p.id == currentRoom.adminId) and "[A]" or "   "
                    local rtag    = p.isReady and "[LISTO]  " or "[      ] "
                    local pingStr = string.format("%4dms", p.ping or 0)
                    love.graphics.print(
                        string.format("[%d] %s %-18s %s %s",
                            i, atag, p.name, rtag, pingStr),
                        50, y
                    )
                end

                local cy = 85 + #currentRoom.players * 22 + 12
                love.graphics.print(string.rep("─", 54), 50, cy); cy = cy + 18

                local readyLabel = isReady and "NO LISTO" or "LISTO"
                love.graphics.print("[ESPACIO]  Marcarme como " .. readyLabel, 50, cy)
                cy = cy + 22

                if isAdmin then
                    if currentRoom.state == "WAITING" then
                        local allReady = (#currentRoom.players >= 2)
                        for _, p in ipairs(currentRoom.players) do
                            if not p.isReady then allReady = false; break end
                        end
                        if allReady then
                            love.graphics.print("[S]  Iniciar partida  ✓ todos listos", 50, cy)
                        else
                            love.graphics.setColor(0.50, 0.50, 0.50)
                            love.graphics.print("[S]  Iniciar partida  (faltan listos)", 50, cy)
                            love.graphics.setColor(1, 1, 1)
                        end
                    else
                        love.graphics.print("[S]  Detener partida", 50, cy)
                    end
                    cy = cy + 22

                    if pendingAction == "kick" then
                        love.graphics.setColor(1, 0.65, 0.1)
                        love.graphics.print("Kickear → ¿quién? [número]  o  [ESC] cancelar", 50, cy)
                        love.graphics.setColor(1, 1, 1)
                    elseif pendingAction == "ban" then
                        love.graphics.setColor(1, 0.30, 0.30)
                        love.graphics.print("Banear  → ¿quién? [número]  o  [ESC] cancelar", 50, cy)
                        love.graphics.setColor(1, 1, 1)
                    else
                        love.graphics.print("[K]+[N] Kickear Nº   [B]+[N] Banear Nº", 50, cy)
                    end
                end

                -- Anuncios flotantes (inferior, con fade)
                if #announcements > 0 then
                    local ay = H - 50 - (#announcements - 1) * 20
                    for _, ann in ipairs(announcements) do
                        local alpha = math.min(ann.timer / 1.5, 1)
                        love.graphics.setColor(1, 1, 0.40, alpha)
                        love.graphics.print("» " .. ann.msg, 50, ay)
                        ay = ay + 20
                    end
                    love.graphics.setColor(1, 1, 1)
                end

                love.graphics.print("[ESC] Salir de la sala", 50, H - 22)
            end
        end
    end

    -- Error en GAME también (esquina inferior)
    if state == "GAME" and errorMsg ~= "" then
        love.graphics.setColor(0.95, 0.25, 0.25)
        love.graphics.print("⚠ " .. errorMsg, 10, H - 22)
        love.graphics.setColor(1, 1, 1)
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Entrada de texto
-- ─────────────────────────────────────────────────────────────────────────────

function love.textinput(t)
    if state == "LOGIN" then
        myName = myName .. t
    elseif state == "CREATE_ROOM" then
        if createStep == 1 or createStep == 3 then
            inputBuffer = inputBuffer .. t
        elseif createStep == 4 and t:match("%d") then
            inputBuffer = inputBuffer .. t
        end
    elseif state == "JOIN_PASSWORD" then
        inputBuffer = inputBuffer .. t
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Teclado
-- ─────────────────────────────────────────────────────────────────────────────

function love.keypressed(key)

    -- ── Backspace ─────────────────────────────────────────────────────────────
    if key == "backspace" then
        if state == "LOGIN" then
            if #myName > 0 then myName = myName:sub(1, -2) end
        elseif state == "CREATE_ROOM" and createStep ~= 2 then
            if #inputBuffer > 0 then inputBuffer = inputBuffer:sub(1, -2) end
        elseif state == "JOIN_PASSWORD" then
            if #inputBuffer > 0 then inputBuffer = inputBuffer:sub(1, -2) end
        end
        return
    end

    -- ── ESC ───────────────────────────────────────────────────────────────────
    if key == "escape" then
        if state == "CREATE_ROOM" then
            resetCreateForm(); state = "LOBBY"
        elseif state == "JOIN_PASSWORD" then
            inputBuffer = ""; selectedRoom = nil; state = "LOBBY"
        elseif state == "ROOM" then
            if pendingAction then
                pendingAction = nil
            else
                client:send("leave_room", {})
            end
        elseif state == "GAME" then
            if currentRoom and currentRoom.adminId == myId then
                -- Admin: detener partida (volver a sala de espera)
                client:send("stop_game", {})
            else
                -- Jugador normal: salir de la sala durante la partida
                client:send("leave_room", {})
            end
        end
        return
    end

    -- ─── LOGIN ────────────────────────────────────────────────────────────────
    if state == "LOGIN" then
        if (key == "return" or key == "kpenter") and #myName > 0 then
            print("Conectando a localhost:22122...")
            client = sock.newClient("localhost", 22122)
            client:setSerialization(bitser.dumps, bitser.loads)
            registerNetworkHandlers()
            client:connect()
        end

    -- ─── LOBBY ───────────────────────────────────────────────────────────────
    elseif state == "LOBBY" then
        if key == "r" then
            lobbyRefreshTimer = 0
            client:send("get_rooms", {})
        elseif key == "c" then
            resetCreateForm(); state = "CREATE_ROOM"
        else
            local num = tonumber(key)
            if num and num >= 1 and num <= #roomList then
                selectedRoom = roomList[num]
                if selectedRoom.hasPassword then
                    inputBuffer = ""; state = "JOIN_PASSWORD"
                else
                    client:send("join_room", { id=selectedRoom.id, password="" })
                end
            end
        end

    -- ─── CREAR SALA ──────────────────────────────────────────────────────────
    elseif state == "CREATE_ROOM" then
        if key == "return" or key == "kpenter" then
            if createStep == 1 then
                if #inputBuffer > 0 then
                    createData.name = inputBuffer; inputBuffer = ""; createStep = 2
                end
            elseif createStep == 3 then
                createData.password = inputBuffer; inputBuffer = ""; createStep = 4
            elseif createStep == 4 then
                local n = tonumber(inputBuffer)
                if n and n >= 2 and n <= 16 then
                    createData.maxPlayers = n
                    client:send("create_room", createData)
                    resetCreateForm()
                else
                    showError("Introduce un número entre 2 y 16.")
                end
            end
        elseif createStep == 2 then
            if key == "p" then
                createData.isPublic = true;  inputBuffer = ""; createStep = 4
            elseif key == "v" then
                createData.isPublic = false; inputBuffer = ""; createStep = 3
            end
        end

    -- ─── CONTRASEÑA PARA UNIRSE ──────────────────────────────────────────────
    elseif state == "JOIN_PASSWORD" then
        if (key == "return" or key == "kpenter") and selectedRoom then
            client:send("join_room", { id=selectedRoom.id, password=inputBuffer })
            inputBuffer = ""; selectedRoom = nil
        end

    -- ─── SALA DE ESPERA ───────────────────────────────────────────────────────
    elseif state == "ROOM" then
        if pendingAction then
            local num = tonumber(key)
            if num and currentRoom and num >= 1 and num <= #currentRoom.players then
                local target = currentRoom.players[num]
                if target.id == myId then
                    showError("No puedes hacer eso a ti mismo.")
                else
                    local evt = (pendingAction == "kick") and "kick_player" or "ban_player"
                    client:send(evt, { playerId = target.id })
                end
                pendingAction = nil
            end
        else
            if key == "space" then
                isReady = not isReady
                client:send("set_ready", { ready = isReady })
            elseif key == "s" and currentRoom and currentRoom.adminId == myId then
                if currentRoom.state == "WAITING" then
                    client:send("start_game", {})
                else
                    client:send("stop_game", {})
                end
            elseif key == "k" and currentRoom and currentRoom.adminId == myId then
                pendingAction = "kick"
            elseif key == "b" and currentRoom and currentRoom.adminId == myId then
                pendingAction = "ban"
            end
        end

    -- ─── JUEGO ────────────────────────────────────────────────────────────────
    elseif state == "GAME" then
        if key == "n" then
            showNames = not showNames
        elseif key == "q" and currentRoom and currentRoom.adminId == myId then
            -- Admin: cerrar sala completamente (todos vuelven al menú)
            client:send("close_room", {})
        end
        -- ESC ya fue manejado arriba (stop_game o leave_room)
    end
end
