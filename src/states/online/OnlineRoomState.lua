-- src/states/online/OnlineRoomState.lua
-- Sala de espera online.  Interfaz completamente navegable con flechas/gamepad.
-- Dos columnas: lista de jugadores (izquierda) y botones de acción (derecha).
-- TODOS los controles son botones seleccionables — sin atajos de teclado directos.

local BaseState       = require 'src/core/BaseState'
local MenuScene = require 'src/ui/menu/MenuScene'
local NC              = require 'src/network/NetworkClient'
local Modes           = require 'src/world/modes/Modes'
local PixelIcons      = require 'src/ui/PixelIcons'
local ModeSelectMenu  = require 'src/ui/ModeSelectMenu'
local Lang            = require 'src/core/Lang'
local Difficulty      = require 'src/core/Difficulty'
local MenuAnim        = require 'src/ui/menu/MenuAnim'
local MenuButton      = require 'src/ui/menu/MenuButton'
local MenuKit         = require 'src/ui/menu/MenuKit'
local PixelFont       = require 'src/ui/PixelFont'
local OnlineRoomState = BaseState:new()

-- Sub-estados
local SUB_MAIN   = 'main'
local SUB_PMENU  = 'pmenu'   -- menú de acción sobre un jugador (admin)
local SUB_MODES  = 'modes'   -- menú "MODO DE JUEGO" (admin)

-- Columnas de foco
local FOCUS_PLAYERS = 'players'
local FOCUS_ACTIONS = 'actions'

-- Opciones del menú de jugador
local PMENU_ADMIN  = 1     -- ceder el admin a ese jugador (quien lo cede deja de serlo)
local PMENU_KICK   = 2
local PMENU_BAN    = 3
local PMENU_CANCEL = 4
local PMENU_LABELS = { 'room.give_admin', 'room.kick', 'room.ban', 'hub.cancel' }   -- claves de idioma
local PMENU_COLORS = { 'yellow', 'red', 'red', 'mono' }                             -- (colores de botón)

-- ── Enter ─────────────────────────────────────────────────────────────────────

function OnlineRoomState:enter(args)
    args = args or {}

    self.currentRoom   = args.room or {}
    self.isReady       = false

    -- Navegación
    self.sub           = SUB_MAIN
    self.focus         = FOCUS_ACTIONS
    self.playerSel     = 1
    self.actionSel     = 1
    self.pmenuSel      = PMENU_CANCEL

    self.t             = 0
    self.anim, self.winAnim = MenuAnim.new(), MenuAnim.new()
    self.catalog       = nil     -- niveles con miniatura (para la tarjeta de partida)

    self:_setupHandlers()
    NC:send("get_levels", {})
    Sound.playMusic('menus')
end

function OnlineRoomState:_setupHandlers()
    NC:on("room_update", function(data)
        self.currentRoom = data
        self.pendingDiff = nil            -- (la dificultad que pidió el host ya la dice el servidor)
        if data.level and self.catalog then
            local known = false
            for _, l in ipairs(self.catalog) do if l.path == data.level then known = true end end
            if not known then NC:send("get_levels", {}) end
        end
        if self.modeMenu then
            self.modeMenu:setRoom(data)
            -- Ya no somos host o empezó la partida: cerrar el menú
            if data.adminId ~= NC.myId or data.state ~= "WAITING" then self:_closeModeMenu() end
        end
        for _, p in ipairs(data.players or {}) do
            if p.id == NC.myId then self.isReady = p.isReady; break end
        end
        local np = #(data.players or {})
        if self.playerSel > math.max(1, np) then self.playerSel = math.max(1, np) end
        if data.state == "IN_GAME" then
            gStateMachine:change('online_adventure', { room = data })
        end
    end)
    NC:on("level_catalog", function(data)
        if type(data) ~= 'table' or type(data.levels) ~= 'table' then return end
        self.catalog = data.levels
        ModeSelectMenu.clearPreviews()
        if self.modeMenu then self.modeMenu:setCatalog(data) end
    end)
    NC:on("room_announce", function(data)
        if type(data) == 'table' then Notify.toast(Lang.fromServer(data), data.kind) end
    end)
    NC:on("room_left",   function(data) gStateMachine:change('online_hub') end)
    NC:on("kicked",       function(data) Notify.roomExit('kicked', data) end)
    NC:on("banned",       function(data) Notify.roomExit('banned', data) end)
    NC:on("room_closed",  function(data) Notify.roomExit('room_closed', data) end)
    NC:on("room_error",  function(data)
        Notify.toast(Lang.fromServer(data, 'hub.error'), 'error')
        if self.sub == SUB_PMENU then self.sub = SUB_MAIN end
    end)
    NC:on("connection_lost", function(data)
        gStateMachine:change('online_error', {
            code = "ERR_CONNECTION_LOST",
            msg  = data.msg or Lang('err.lost'),
        })
    end)
end

local fitText = require('src/ui/TextUtil').fit

-- La dificultad que se ve en la sala ('none' = sin dificultad): la del servidor o la que acaba de pedir el host
function OnlineRoomState:_difficulty()
    return self.pendingDiff or (self.currentRoom and self.currentRoom.difficulty) or 'none'
end

-- Las opciones del selector del host: sin dificultad y TODAS las de src/core/Difficulty.lua, en su orden
local function diffOrder()
    local o = { 'none' }
    for _, d in ipairs(Difficulty.ORDER) do o[#o + 1] = d end
    return o
end

-- El host mueve el selector de dificultad (d = -1 / 1; da la vuelta en los extremos)
function OnlineRoomState:_stepDifficulty(d)
    local order, cur = diffOrder(), self:_difficulty()
    local i = 1
    for k, id in ipairs(order) do if id == cur then i = k end end
    local nxt = order[(i - 1 + d) % #order + 1]
    self.pendingDiff, self.t = nxt, 0
    Sound.play('select', d > 0 and 1.08 or 0.94)
    NC:send("set_difficulty", { difficulty = nxt })
end

-- (para los arneses) elige el selector de dificultad; false si no está (no eres host o hay partida)
function OnlineRoomState:focusDifficulty()
    for i, a in ipairs(self:_buildActions()) do
        if a.stepper then self.focus, self.actionSel, self.sub = FOCUS_ACTIONS, i, SUB_MAIN; return true end
    end
    return false
end

-- Construye la lista dinámica de botones de acción según el estado actual (color = de src/ui/menu/MenuButton).
function OnlineRoomState:_buildActions()
    local room    = self.currentRoom
    local isAdmin = room and (room.adminId == NC.myId)
    local list    = {}
    table.insert(list, { id='ready',   label = self.isReady and Lang('room.not_ready') or Lang('room.ready'),
                         color = self.isReady and 'green' or 'yellow' })
    if isAdmin then
        if room.state == "WAITING" then
            -- El host elige el objetivo de la ronda y el nivel en su menú
            table.insert(list, { id='gamemode', label=Lang('room.game_mode'), color = 'mono' })
            -- … y la DIFICULTAD: un selector ◀ ▶ con todas (todos la ven en la tarjeta de la partida)
            local d = self:_difficulty()
            table.insert(list, { id='difficulty', stepper = true, diff = d, value = Lang('difficulty.' .. d),
                                 color = Difficulty.COLORS[d] or 'mono' })
            local why = self:_startBlocker()
            table.insert(list, { id='start', label=Lang('room.start'), color='green',
                                 disabled = why ~= nil, why = why })
        else
            table.insert(list, { id='stop',  label=Lang('room.stop'), color='red' })
        end
    end
    table.insert(list, { id='leave', label=Lang('room.leave'), color='red' })
    return list
end

-- Motivo por el que aún no se puede iniciar (nil = se puede). Las mismas
-- reglas que comprueba el servidor, para desactivar el botón de antemano.
function OnlineRoomState:_startBlocker()
    local room    = self.currentRoom or {}
    local players = room.players or {}
    if #players < 2 then
        return Lang('room.need_players')
    end
    local waiting, meWaiting = {}, false
    for _, p in ipairs(players) do
        if not p.isReady then
            if p.id == NC.myId then meWaiting = true else waiting[#waiting + 1] = p.name end
        end
    end
    if meWaiting and #waiting == 0 then
        return Lang('room.me_not_ready')
    elseif #waiting > 0 then
        local who = table.concat(waiting, ", ")
        return Lang(#waiting == 1 and 'room.waiting_one' or 'room.waiting_many', { names = who })
               .. (meWaiting and Lang('room.and_you') or "") .. "."
    end
    if not room.level then
        return Lang('room.no_map')
    end
    return nil
end

function OnlineRoomState:_closeModeMenu()
    self.modeMenu = nil
    if self.sub == SUB_MODES then self.sub = SUB_MAIN end
end

function OnlineRoomState:exit()
    NC:off("level_catalog")
end

function OnlineRoomState:_executeAction(id)
    if id == 'ready' then
        self.isReady = not self.isReady
        NC:send("set_ready", { ready = self.isReady })
    elseif id == 'gamemode' then
        self.sub      = SUB_MODES
        self.modeMenu = ModeSelectMenu.new(self.currentRoom, self.catalog)
    elseif id == 'difficulty' then
        self:_stepDifficulty(1)
    elseif id == 'start' then
        local why = self:_startBlocker()
        if why then Notify.toast(why, 'warn') else NC:send("start_game", {}) end
    elseif id == 'stop' then
        NC:send("stop_game", {})
    elseif id == 'leave' then
        NC:send("leave_room", {})
    end
end

-- ── Update ────────────────────────────────────────────────────────────────────

function OnlineRoomState:update(dt)
    MenuScene.update(dt)
    self.anim:update(dt); self.winAnim:update(dt)
    self.t = self.t + dt

    local room    = self.currentRoom
    local players = room and room.players or {}
    local np      = #players
    local actions = self:_buildActions()
    local na      = #actions
    local isAdmin = room and (room.adminId == NC.myId)

    -- Clamp índices
    if self.playerSel > math.max(1, np) then self.playerSel = math.max(1, np) end
    if self.actionSel > na then self.actionSel = na end
    if self.actionSel < 1  then self.actionSel = 1  end

    -- ── Menú "MODO DE JUEGO" ──────────────────────────────────────────────────
    if self.sub == SUB_MODES and self.modeMenu then
        if self.modeMenu:update(dt) == 'close' then self:_closeModeMenu() end
        return
    end

    -- ── Menú de jugador (sub-overlay) ─────────────────────────────────────────
    if self.sub == SUB_PMENU then
        if Input.pressed('nav_up') then
            self.pmenuSel = self.pmenuSel - 1
            if self.pmenuSel < 1 then self.pmenuSel = #PMENU_LABELS end
            Sound.play('select')
        end
        if Input.pressed('nav_down') then
            self.pmenuSel = self.pmenuSel + 1
            if self.pmenuSel > #PMENU_LABELS then self.pmenuSel = 1 end
            Sound.play('select')
        end
        if Input.pressed('confirm') then
            Sound.play('select')
            self:_executePmenu(players)
        end
        if Input.pressed('back') then
            self.sub = SUB_MAIN
        end
        return
    end

    -- ── Navegación normal ─────────────────────────────────────────────────────
    if Input.pressed('back') then
        local leave
        for i, a in ipairs(actions) do if a.id == 'leave' then leave = i end end
        if leave and self.focus == FOCUS_ACTIONS and self.actionSel == leave then
            Sound.play('select'); self:_executeAction('leave')
        elseif leave then
            self.focus, self.actionSel, self.t = FOCUS_ACTIONS, leave, 0
            Sound.play('select', 0.9)
        end
        return
    end

    -- El selector de dificultad (elegido) usa izquierda / derecha para cambiarla
    local cur = self.focus == FOCUS_ACTIONS and actions[self.actionSel]
    if cur and cur.stepper and (Input.pressed('nav_left') or Input.pressed('nav_right')) then
        self:_stepDifficulty(Input.pressed('nav_left') and -1 or 1)
        return
    end

    -- Cambiar columna de foco
    if Input.pressed('nav_left') then
        if self.focus == FOCUS_ACTIONS then
            self.focus = FOCUS_PLAYERS
            Sound.play('select')
        end
    end
    if Input.pressed('nav_right') then
        if self.focus == FOCUS_PLAYERS then
            self.focus = FOCUS_ACTIONS
            Sound.play('select')
        end
    end

    if self.focus == FOCUS_PLAYERS then
        if Input.pressed('nav_up') then
            self.playerSel = self.playerSel - 1
            if self.playerSel < 1 then self.playerSel = math.max(1, np) end
            Sound.play('select')
        end
        if Input.pressed('nav_down') then
            self.playerSel = self.playerSel + 1
            if self.playerSel > np then self.playerSel = 1 end
            Sound.play('select')
        end
        if Input.pressed('confirm') then
            local sel = players[self.playerSel]
            if isAdmin and sel and sel.id ~= NC.myId then
                self.sub      = SUB_PMENU
                self.winAnim  = MenuAnim.new()
                self.pmenuSel = PMENU_CANCEL
                Sound.play('select')
            end
        end

    elseif self.focus == FOCUS_ACTIONS then
        if Input.pressed('nav_up') then
            self.actionSel = self.actionSel - 1
            if self.actionSel < 1 then self.actionSel = na end
            Sound.play('select')
        end
        if Input.pressed('nav_down') then
            self.actionSel = self.actionSel + 1
            if self.actionSel > na then self.actionSel = 1 end
            Sound.play('select')
        end
        if Input.pressed('confirm') then
            local act = actions[self.actionSel]
            if act then
                Sound.play('select')
                self:_executeAction(act.id)
            end
        end
    end
end

function OnlineRoomState:_executePmenu(players)
    local target = players[self.playerSel]
    if self.pmenuSel == PMENU_ADMIN and target then
        NC:send("give_admin", { playerId = target.id })
    elseif self.pmenuSel == PMENU_KICK and target then
        NC:send("kick_player", { playerId = target.id })
    elseif self.pmenuSel == PMENU_BAN and target then
        NC:send("ban_player",  { playerId = target.id })
    end
    self.sub = SUB_MAIN
end

-- ── Layout (ÚNICA fuente de geometría: render, ratón y táctil) ───────────────

local TOP     = 168         -- debajo del rótulo y la línea de estado
local ROW_H, ROW_GAP = 52, 6
local CARD_H  = 172
local BTN_H, BTN_GAP = 52, 8
local PM_W, PM_BH, PM_GAP = 440, 56, 10

function OnlineRoomState:_layout()
    -- (con el ancho lógico ACTUAL: en móviles más alargados que 16:9, main.lua
    -- lo cambia al arrancar o al girar; calcularlo al cargar el archivo dejaba
    -- el panel con el tamaño de 1280 y pegado a la izquierda)
    local L = {}
    local mx = math.max(40, math.floor(WINDOW_W * 0.06))
    local gap = 40
    local leftW  = math.floor((WINDOW_W - 2 * mx - gap) * 0.48)
    local rightX = mx + leftW + gap
    local rightW = WINDOW_W - mx - rightX
    L.bottom = WINDOW_H - 56
    L.left  = { x = mx, y = TOP, w = leftW }
    L.right = { x = rightX, y = TOP, w = rightW }
    -- Jugadores: un hueco con una fila por jugador
    L.well = { x = mx, y = TOP + 30, w = leftW, h = L.bottom - TOP - 30 }
    L.rows = {}
    local players = (self.currentRoom and self.currentRoom.players) or {}
    for i = 1, #players do
        local y = L.well.y + 12 + (i - 1) * (ROW_H + ROW_GAP)
        if y + ROW_H > L.well.y + L.well.h - 8 then break end
        L.rows[i] = { x = mx + 12, y = y, w = leftW - 24, h = ROW_H }
    end
    -- La tarjeta de la partida (modo, mapa, dificultad) y los botones debajo
    L.card = { x = rightX, y = TOP + 30, w = rightW, h = CARD_H }
    L.buttons = {}
    local acts = self:_buildActions()
    local by = L.card.y + CARD_H + 14
    local bh = BTN_H
    while #acts * (bh + BTN_GAP) - BTN_GAP > L.bottom - by and bh > 40 do bh = bh - 4 end
    for i = 1, #acts do
        L.buttons[i] = { x = rightX + 52, y = by + (i - 1) * (bh + BTN_GAP), w = rightW - 52, h = bh }
    end
    -- Menú de acción sobre un jugador (ventana)
    local mh = #PMENU_LABELS * (PM_BH + PM_GAP) + 120
    local pw = math.min(PM_W, WINDOW_W - 120)
    L.pmenu = { x = math.floor((WINDOW_W - pw) / 2), y = math.floor((WINDOW_H - mh) / 2), w = pw, h = mh }
    L.pmenuBtns = {}
    for i = 1, #PMENU_LABELS do
        L.pmenuBtns[i] = { x = L.pmenu.x + 72, y = L.pmenu.y + 96 + (i - 1) * (PM_BH + PM_GAP), w = pw - 112, h = PM_BH }
    end
    return L
end

local function hit(r, x, y, pad)
    pad = pad or 0
    return r and x >= r.x - pad and x <= r.x + r.w + pad and y >= r.y - pad and y <= r.y + r.h + pad
end

-- ── Hover del mouse: mueve la selección real al elemento bajo el cursor ──────

function OnlineRoomState:mousemoved(tx, ty)
    if self.sub == SUB_MODES then
        if self.modeMenu then self.modeMenu:hover(tx, ty) end
        return
    end
    local L = self:_layout()
    if self.sub == SUB_PMENU then
        for i, r in ipairs(L.pmenuBtns) do
            if hit(r, tx, ty, 4) then
                if self.pmenuSel ~= i then self.pmenuSel, self.t = i, 0; Sound.play('select') end
                return
            end
        end
        return
    end
    for i, r in ipairs(L.buttons) do
        if hit(r, tx, ty, 4) then
            if self.focus ~= FOCUS_ACTIONS or self.actionSel ~= i then
                self.focus = FOCUS_ACTIONS; self.actionSel = i; self.t = 0; Sound.play('select')
            end
            return
        end
    end
    for i, r in ipairs(L.rows) do
        if hit(r, tx, ty) then
            if self.focus ~= FOCUS_PLAYERS or self.playerSel ~= i then
                self.focus = FOCUS_PLAYERS; self.playerSel = i; Sound.play('select')
            end
            return
        end
    end
end

-- ── Táctil / clic ─────────────────────────────────────────────────────────────

function OnlineRoomState:touchpressed(id, tx, ty)
    local room    = self.currentRoom
    local players = room and room.players or {}
    local isAdmin = room and (room.adminId == NC.myId)

    if self.sub == SUB_MODES and self.modeMenu then
        if self.modeMenu:touch(tx, ty) == 'close' then self:_closeModeMenu() end
        return
    end

    local L = self:_layout()
    if self.sub == SUB_PMENU then
        for i, r in ipairs(L.pmenuBtns) do
            if hit(r, tx, ty, 4) then
                self.pmenuSel = i
                Sound.play('select')
                self:_executePmenu(players)
                return
            end
        end
        self.sub = SUB_MAIN          -- toque fuera del menú = cancelar
        return
    end

    for i, r in ipairs(L.rows) do
        if hit(r, tx, ty) then
            self.focus, self.playerSel = FOCUS_PLAYERS, i
            Sound.play('select')
            local sel = players[i]
            if isAdmin and sel and sel.id ~= NC.myId then
                self.sub, self.pmenuSel, self.winAnim = SUB_PMENU, PMENU_CANCEL, MenuAnim.new()
            end
            return
        end
    end
    local actions = self:_buildActions()
    for i, r in ipairs(L.buttons) do
        if hit(r, tx, ty, 4) and actions[i] then
            self.focus, self.actionSel, self.t = FOCUS_ACTIONS, i, 0
            Sound.play('select')
            -- (el selector de dificultad: cada mitad, una flecha)
            if actions[i].stepper then self:_stepDifficulty(MenuKit.stepperSide(r, tx))
            else self:_executeAction(actions[i].id) end
            return
        end
    end
    -- La tarjeta de la partida abre el menú de modos (host)
    if isAdmin and room.state == "WAITING" and hit(L.card, tx, ty) then
        Sound.play('select')
        self:_executeAction('gamemode')
    end
end

-- ── keypressed (solo texto / teclas que Input.pressed no cubre) ───────────────

function OnlineRoomState:keypressed(k)
    -- Sin lógica adicional: todo se maneja vía Input.pressed en update().
    -- Solo se intercepta escape aquí como fallback por compatibilidad.
    if k == "escape" then
        if self.sub == SUB_PMENU then
            self.sub = SUB_MAIN
        end
    end
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────

local function bobOf(t, sel) return sel and ((math.floor(t * 3) % 2 == 0) and -4 or 0) or 0 end

-- Una "pastilla" de texto pixel con fondo de color (LISTO / ESPERA, la dificultad...)
local function pill(text, x, y, s, fg, bg, a, alignRight)
    local w = PixelFont.width(text, s) + 6 * s
    local h = PixelFont.height(s) + 4 * s
    if alignRight then x = x - w end
    x, y = math.floor(x), math.floor(y)
    love.graphics.setColor(0, 0, 0, 0.45 * a)
    love.graphics.rectangle('fill', x + s, y + s, w, h)
    love.graphics.setColor(bg[1], bg[2], bg[3], a)
    love.graphics.rectangle('fill', x, y, w, h)
    PixelFont.draw(text, x + 3 * s, y + 2 * s, s, a, fg)
    love.graphics.setColor(1, 1, 1, 1)
    return w, h
end

-- Colores de fondo de las pastillas de dificultad (los mismos tonos que sus botones)
local DIFF_BG = { mono = { 0.2, 0.2, 0.23 }, green = { 0.25, 0.52, 0.3 }, yellow = { 0.62, 0.5, 0.18 },
                  blue = { 0.22, 0.34, 0.62 }, red = { 0.62, 0.24, 0.22 }, purple = { 0.4, 0.27, 0.62 } }

-- Tarjeta "PARTIDA": modo elegido, su objetivo, el mapa con miniatura y la dificultad.
function OnlineRoomState:_renderGameCard(r, isAdmin, a, oy)
    local room = self.currentRoom or {}
    local mode = Modes.get(room.mode)
    if not mode then return end
    local col  = mode.color
    local x, y, w, h = r.x, r.y + oy, r.w, r.h
    local pad  = 18
    MenuKit.box('card', x, y, w, h, a)
    love.graphics.setColor(col[1], col[2], col[3], 0.9 * a)
    love.graphics.rectangle('fill', x + 8, y + 8, w - 16, 4)

    -- Modo: icono + nombre
    local iw = PixelIcons.size(mode.icon or '')
    local tx = x + pad
    if iw > 0 then
        PixelIcons.draw(mode.icon, tx, y + 24, 3, a)
        tx = tx + iw * 3 + 14
    end
    PixelFont.draw(Lang('room.mode'), tx, y + 22, 2, 0.6 * a)
    -- la DIFICULTAD de la sala (la elige el host), arriba a la derecha
    local d = self:_difficulty()
    local dc = DIFF_BG[Difficulty.COLORS[d] or 'mono'] or DIFF_BG.mono
    local dw = pill(Lang('difficulty.' .. d), x + w - pad, y + 20, 2, { 1, 1, 1 }, dc, a, true)
    MenuKit.text(FONT_MED, fitText(FONT_MED, mode.label, x + w - pad - dw - 12 - tx), tx, y + 38, w, 'left', { col[1] * 0.6 + 0.4, col[2] * 0.6 + 0.4, col[3] * 0.6 + 0.4 }, a)

    -- Objetivo
    love.graphics.setFont(FONT_SMALL)
    local _, lines = FONT_SMALL:getWrap(mode.tagline, w - 2 * pad)
    local ty = y + 70
    for i = 1, math.min(2, #lines) do
        MenuKit.text(FONT_SMALL, lines[i], x + pad, ty, w, 'left', { 0.82, 0.86, 1 }, a)
        ty = ty + FONT_SMALL:getHeight() + 6
    end

    -- Mapa: miniatura + nombre
    local pw, ph = 132, 56
    local my = y + h - ph - 14
    local lvl
    for _, l in ipairs(self.catalog or {}) do if l.path == room.level then lvl = l end end
    if lvl then
        ModeSelectMenu.drawPreview(lvl, x + pad, my, pw, ph, self.t or 0, a, Modes.get(room.mode))
    else
        love.graphics.setColor(0.12, 0.16, 0.32, a)
        love.graphics.rectangle('fill', x + pad, my, pw, ph)
    end
    love.graphics.setColor(0.05, 0.07, 0.16, a)
    love.graphics.rectangle('line', x + pad - 0.5, my - 0.5, pw + 1, ph + 1)
    local nx = x + pad + pw + 16
    PixelFont.draw(Lang('room.map'), nx, my + 2, 2, 0.6 * a)
    if room.levelName then
        local levelName = Lang.localName({ name = room.levelName, name_en = room.levelName_en })
        MenuKit.text(FONT_MED, fitText(FONT_MED, levelName, x + w - pad - nx), nx, my + 18, w, 'left', { 1, 0.86, 0.36 }, a)
    else
        MenuKit.text(FONT_MED, fitText(FONT_MED, Lang('room.no_map_short'), x + w - pad - nx), nx, my + 18, w, 'left', { 1, 0.45, 0.4 }, a)
    end
    MenuKit.text(FONT_SMALL, fitText(FONT_SMALL, isAdmin and Lang('room.change_in_mode') or Lang('room.host_picks'), x + w - pad - nx),
                 nx, my + 42, w, 'left', { 0.6, 0.66, 0.85 }, a)
end

-- ── Render ────────────────────────────────────────────────────────────────────

function OnlineRoomState:render()
    MenuScene.backdrop('online')                 -- (ladrillos del Flappy: src/ui/menu/MenuScene)

    local A       = self.anim
    local room    = self.currentRoom or {}
    local players = room.players or {}
    local np      = #players
    local isAdmin = room.adminId == NC.myId
    local actions = self:_buildActions()
    local L       = self:_layout()

    -- ── Cabecera: el nombre de la sala y su estado ───────────────────────────
    local hy = MenuKit.title(room.name or Lang('room.default_name'), 'mono', A, 1)
    local stateStr = (room.state == "IN_GAME") and Lang('hub.in_game') or Lang('hub.waiting')
    local privStr  = (room.isPublic == false) and Lang('hub.private') or Lang('hub.public')
    local countStr = Lang('room.players_count', { n = np, max = room.maxPlayers or '?' })
    local _, ioy, ia = A:slide(1, 0, -200, 0, -200)
    local info = stateStr .. "  -  " .. privStr .. "  -  " .. countStr
    PixelFont.shadow(info, math.floor((WINDOW_W - PixelFont.width(info, 2)) / 2), hy + 14 + ioy, 2, ia, { 0.8, 0.85, 1 })

    -- ── Jugadores ─────────────────────────────────────────────────────────────
    local focusP = self.focus == FOCUS_PLAYERS and self.sub == SUB_MAIN
    local ox, oy, a = A:slide(2, -260, 0)
    MenuKit.section(Lang('room.players'), L.left.x + 4 + ox, L.left.y + oy, L.left.w - 8, focusP, a)
    MenuKit.box('well', L.well.x + ox, L.well.y + oy, L.well.w, L.well.h, a)
    for i, p in ipairs(players) do
        local r = L.rows[i]
        if not r then break end
        local col    = p.color or {0.7, 0.7, 0.7}
        local isSelf = (p.id == NC.myId)
        local isSel  = (i == self.playerSel) and focusP
        local x, y = r.x + ox, r.y + oy
        MenuKit.box(isSel and 'card_sel' or 'card', x, y, r.w, r.h, a)
        love.graphics.setColor(col[1], col[2], col[3], a)
        love.graphics.rectangle('fill', x + 8, y + 8, 8, r.h - 16)

        -- Nombre (+ corona del host centrada con el texto, como en el HUD)
        local nameY = y + math.floor((r.h - FONT_MED:getHeight()) / 2)
        local nx = x + 28
        if p.id == room.adminId then
            local px = 2
            PixelIcons.crown(nx, nameY + FONT_MED:getHeight() / 2 - 6.5 * px, px, a)
            nx = nx + PixelIcons.CROWN_W * px + 10
        end
        -- a la derecha: listo / espera y el ping
        local ping = string.format("%dMS", p.ping or 0)
        local pgw = PixelFont.width(ping, 2)
        PixelFont.draw(ping, x + r.w - 16 - pgw, y + r.h - 16, 2, 0.55 * a)
        local rdy = p.isReady and Lang('room.ready') or Lang('room.wait')
        local pw = pill(rdy, x + r.w - 16, y + 8, 2, p.isReady and { 0.08, 0.2, 0.1 } or { 0.8, 0.84, 0.95 },
                        p.isReady and { 0.45, 0.9, 0.5 } or { 0.2, 0.25, 0.42 }, a, true)
        local nameMax = (x + r.w - 28 - math.max(pw, pgw)) - nx
        local you = isSelf and (' ' .. Lang('room.you')) or ''
        local name = fitText(FONT_MED, p.name or '?', nameMax - (isSelf and FONT_SMALL:getWidth(you) + 6 or 0))
        MenuKit.text(FONT_MED, name, nx, nameY, nameMax, 'left', { col[1] * 0.6 + 0.4, col[2] * 0.6 + 0.4, col[3] * 0.6 + 0.4 }, a)
        if isSelf then
            MenuKit.text(FONT_SMALL, you, nx + FONT_MED:getWidth(name) + 4, nameY + 4, 200, 'left', { 0.6, 0.85, 1 }, a)
        end
    end

    -- ── Partida + acciones ────────────────────────────────────────────────────
    local cx, cy, ca = A:slide(3, 260, 0)
    MenuKit.section(Lang('room.match'), L.right.x + 4 + cx, L.right.y + cy, L.right.w - 8, not focusP, ca)
    self:_renderGameCard({ x = L.card.x + cx, y = L.card.y, w = L.card.w, h = L.card.h }, isAdmin, ca, cy)

    local focusA = self.focus == FOCUS_ACTIONS and self.sub == SUB_MAIN
    for i, act in ipairs(actions) do
        local r = L.buttons[i]
        if r then
            local bx, by, ba = A:slide(3 + i, 0, 220)
            local sel = focusA and i == self.actionSel
            local rr = { x = r.x + bx, y = r.y + by, w = r.w, h = r.h }
            local color = act.disabled and 'mono' or act.color
            if act.stepper then
                MenuKit.stepper(Lang('room.difficulty_label'), act.value, rr, color, sel, { alpha = ba, bob = bobOf(self.t, sel), scale = 4 })
            else
                MenuButton.draw(act.label, rr.x, rr.y + bobOf(self.t, sel), rr.w, rr.h, color, sel and not act.disabled,
                                { alpha = ba * (act.disabled and 0.75 or 1), scale = MenuButton.textScale(act.label, rr.w - 48, 4) })
            end
            if sel then MenuKit.marker(rr.x, rr.y + bobOf(self.t, sel), rr.w, rr.h, self.t, ba) end
        end
    end

    -- Ayuda de abajo: la descripción de la dificultad elegida, las acciones sobre un jugador o la navegación
    local hint = self.focus == FOCUS_ACTIONS and Lang('room.see_players') or Lang('room.go_actions')
    local act = focusA and actions[self.actionSel]
    if act and act.stepper then
        hint = Lang('room.difficulty_hint', { desc = Lang('difficulty.desc.' .. act.diff) })
    elseif act and act.disabled and act.why then
        hint = act.why
    elseif focusP and isAdmin then
        local sel = players[self.playerSel]
        if sel and sel.id ~= NC.myId then hint = Lang('room.actions_on', { name = sel.name or '?' }) end
    end
    if self.sub == SUB_MAIN then MenuKit.hint(hint, A, 9) end

    -- ── Menú de acción sobre un jugador ──────────────────────────────────────
    if self.sub == SUB_PMENU then
        local target = players[self.playerSel]
        MenuKit.dim(0.6)
        local M = L.pmenu
        local _, poy, pa = self.winAnim:slide(1, 0, 160)
        MenuKit.box('window', M.x, M.y + poy, M.w, M.h, pa)
        local title = Lang('room.action_on', { name = target and target.name or '?' })
        MenuKit.text(FONT_MED, fitText(FONT_MED, title, M.w - 40), M.x, M.y + 36 + poy, M.w, 'center', { 1, 0.86, 0.36 }, pa)
        for i, lbl in ipairs(PMENU_LABELS) do
            local r = L.pmenuBtns[i]
            local sel = i == self.pmenuSel
            MenuButton.draw(Lang(lbl), r.x, r.y + poy + bobOf(self.t, sel), r.w, r.h, PMENU_COLORS[i], sel, { alpha = pa, scale = MenuButton.textScale(Lang(lbl), r.w - 48, 4) })
            if sel then MenuKit.marker(r.x, r.y + poy + bobOf(self.t, sel), r.w, r.h, self.t, pa) end
        end
        MenuKit.hint(Lang('menu.hint', { move = Input.label('nav_up') .. Input.label('nav_down'),
                                        ok = Input.label('confirm'), back = Input.label('back') }))
    end

    -- ── Menú "MODO DE JUEGO" ──────────────────────────────────────────────────
    if self.sub == SUB_MODES and self.modeMenu then self.modeMenu:render() end

    love.graphics.setColor(COLOR_WHITE)
end

return OnlineRoomState
