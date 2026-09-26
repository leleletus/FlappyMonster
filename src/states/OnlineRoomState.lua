-- src/states/OnlineRoomState.lua
-- Sala de espera online.  Interfaz completamente navegable con flechas/gamepad.
-- Dos columnas: lista de jugadores (izquierda) y botones de acción (derecha).
-- TODOS los controles son botones seleccionables — sin atajos de teclado directos.

local BaseState       = require 'src/BaseState'
local NC              = require 'src/network/NetworkClient'
local Modes           = require 'src/world/Modes'
local PixelIcons      = require 'src/ui/PixelIcons'
local ModeSelectMenu  = require 'src/ui/ModeSelectMenu'
local OnlineRoomState = BaseState:new()

local imgBg = nil
local function loadAssets()
    if imgBg then return end
    imgBg = love.graphics.newImage('assets/images/menus/MenuDif.png')
end

-- Sub-estados
local SUB_MAIN   = 'main'
local SUB_PMENU  = 'pmenu'   -- menú de acción sobre un jugador (admin)
local SUB_MODES  = 'modes'   -- menú "MODO DE JUEGO" (admin)

-- Columnas de foco
local FOCUS_PLAYERS = 'players'
local FOCUS_ACTIONS = 'actions'

-- Opciones del menú de jugador
local PMENU_KICK   = 1
local PMENU_BAN    = 2
local PMENU_CANCEL = 3
local PMENU_LABELS = { 'KICKEAR', 'BANEAR', 'CANCELAR' }
local PMENU_COLORS = { {1,0.65,0.1}, {1,0.25,0.25}, {0.55,0.55,0.55} }

-- ── Enter ─────────────────────────────────────────────────────────────────────

function OnlineRoomState:enter(args)
    loadAssets()
    args = args or {}

    self.currentRoom   = args.room or {}
    self.isReady       = false
    self.announcements = {}
    self.errorMsg      = ""
    self.errorTimer    = 0

    -- Navegación
    self.sub           = SUB_MAIN
    self.focus         = FOCUS_ACTIONS
    self.playerSel     = 1
    self.actionSel     = 1
    self.pmenuSel      = PMENU_CANCEL

    self.t             = 0
    self.catalog       = nil     -- niveles con miniatura (para la tarjeta de partida)

    self:_setupHandlers()
    NC:send("get_levels", {})
    Sound.playMusic('menus')
end

function OnlineRoomState:_setupHandlers()
    NC:on("room_update", function(data)
        self.currentRoom = data
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
        table.insert(self.announcements, { msg = data.msg or "", timer = 5 })
        if #self.announcements > 5 then table.remove(self.announcements, 1) end
    end)
    NC:on("room_left",   function(data) gStateMachine:change('online_hub') end)
    NC:on("kicked",      function(data) gStateMachine:change('online_hub') end)
    NC:on("banned",      function(data) gStateMachine:change('online_hub') end)
    NC:on("room_closed", function(data) gStateMachine:change('online_hub') end)
    NC:on("room_error",  function(data)
        self.errorMsg   = data.msg or "Error"
        self.errorTimer = 4
        self.sub        = SUB_MAIN
    end)
    NC:on("connection_lost", function(data)
        gStateMachine:change('online_error', {
            code = "ERR_CONNECTION_LOST",
            msg  = data.msg or "Se perdio la conexion con el servidor.",
        })
    end)
end

local fitText = require('src/ui/TextUtil').fit

-- Construye la lista dinámica de botones de acción según el estado actual.
function OnlineRoomState:_buildActions()
    local room    = self.currentRoom
    local isAdmin = room and (room.adminId == NC.myId)
    local list    = {}
    table.insert(list, { id='ready',   label = self.isReady and 'NO LISTO' or 'LISTO',
                         color = self.isReady and {0.3,1,0.3} or {1,0.95,0.15} })
    if isAdmin then
        if room.state == "WAITING" then
            -- El host elige el objetivo de la ronda y el nivel en su menú
            table.insert(list, { id='gamemode', label='MODO DE JUEGO' })
            table.insert(list, { id='start', label='INICIAR PARTIDA', color={0.3,1,0.3} })
        else
            table.insert(list, { id='stop',  label='DETENER PARTIDA', color={1,0.55,0.2} })
        end
    end
    table.insert(list, { id='leave', label='SALIR DE LA SALA', color={0.8,0.25,0.25} })
    return list
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
    elseif id == 'start' then
        NC:send("start_game", {})
    elseif id == 'stop' then
        NC:send("stop_game", {})
    elseif id == 'leave' then
        NC:send("leave_room", {})
    end
end

-- ── Update ────────────────────────────────────────────────────────────────────

function OnlineRoomState:update(dt)
    self.t = self.t + dt
    -- Timers
    if self.errorTimer > 0 then
        self.errorTimer = self.errorTimer - dt
        if self.errorTimer <= 0 then self.errorMsg = "" end
    end
    for i = #self.announcements, 1, -1 do
        self.announcements[i].timer = self.announcements[i].timer - dt
        if self.announcements[i].timer <= 0 then table.remove(self.announcements, i) end
    end

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
    if self.pmenuSel == PMENU_KICK and target then
        NC:send("kick_player", { playerId = target.id })
    elseif self.pmenuSel == PMENU_BAN and target then
        NC:send("ban_player",  { playerId = target.id })
    end
    self.sub = SUB_MAIN
end

-- ── Layout (ÚNICA fuente de geometría: render, ratón y táctil) ───────────────

local PANEL_X, PANEL_Y = 76, 40
local PANEL_W, PANEL_H = WINDOW_W - 152, WINDOW_H - 80
local HDR_H   = 84
local ROW_H   = 54
local CARD_H  = 196
local BTN_H, BTN_GAP = 50, 12
local PM_W, PM_BW, PM_BH, PM_GAP = 340, 240, 48, 10

function OnlineRoomState:_layout()
    local L = {}
    L.panel = { x = PANEL_X, y = PANEL_Y, w = PANEL_W, h = PANEL_H }
    local bodyY  = PANEL_Y + HDR_H + 14
    local leftX  = PANEL_X + 24
    local leftW  = math.floor(PANEL_W * 0.50) - 36
    local rightX = leftX + leftW + 40
    local rightW = PANEL_X + PANEL_W - 24 - rightX
    L.bodyY, L.bottom = bodyY, PANEL_Y + PANEL_H - 34
    L.left  = { x = leftX,  y = bodyY, w = leftW }
    L.right = { x = rightX, y = bodyY, w = rightW }

    -- Jugadores
    L.rows = {}
    local players = (self.currentRoom and self.currentRoom.players) or {}
    for i = 1, #players do
        local y = bodyY + 26 + (i - 1) * (ROW_H + 6)
        if y + ROW_H > L.bottom then break end
        L.rows[i] = { x = leftX, y = y, w = leftW, h = ROW_H }
    end

    -- Tarjeta de la partida (modo + mapa) arriba a la derecha
    L.card = { x = rightX, y = bodyY + 26, w = rightW, h = CARD_H }

    -- Botones debajo
    L.buttons = {}
    local by = L.card.y + CARD_H + 18
    for i = 1, #self:_buildActions() do
        L.buttons[i] = { x = rightX, y = by + (i - 1) * (BTN_H + BTN_GAP), w = rightW, h = BTN_H }
    end

    -- Menú de acción sobre un jugador
    local mh = #PMENU_LABELS * (PM_BH + PM_GAP) + 72
    L.pmenu = { x = math.floor((WINDOW_W - PM_W) / 2), y = math.floor((WINDOW_H - mh) / 2), w = PM_W, h = mh }
    L.pmenuBtns = {}
    for i = 1, #PMENU_LABELS do
        L.pmenuBtns[i] = { x = L.pmenu.x + (PM_W - PM_BW) / 2, y = L.pmenu.y + 52 + (i - 1) * (PM_BH + PM_GAP),
                           w = PM_BW, h = PM_BH }
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
                if self.pmenuSel ~= i then self.pmenuSel = i; Sound.play('select') end
                return
            end
        end
        return
    end
    for i, r in ipairs(L.buttons) do
        if hit(r, tx, ty, 4) then
            if self.focus ~= FOCUS_ACTIONS or self.actionSel ~= i then
                self.focus = FOCUS_ACTIONS; self.actionSel = i; Sound.play('select')
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
                self.sub, self.pmenuSel = SUB_PMENU, PMENU_CANCEL
            end
            return
        end
    end
    local actions = self:_buildActions()
    for i, r in ipairs(L.buttons) do
        if hit(r, tx, ty, 4) and actions[i] then
            self.focus, self.actionSel = FOCUS_ACTIONS, i
            Sound.play('select')
            self:_executeAction(actions[i].id)
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

-- ── Helpers de dibujo ─────────────────────────────────────────────────────────

local function drawSharpPanel(x, y, w, h, fillR, fillG, fillB, fillA)
    love.graphics.setColor(fillR, fillG, fillB, fillA)
    love.graphics.rectangle('fill', x, y, w, h)
    love.graphics.setColor(1, 1, 1, 0.55)
    love.graphics.rectangle('line', x,   y,   w,   h)
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle('line', x+2, y+2, w-4, h-4)
end

local function drawActionBtn(label, r, selected, accent)
    local x, y, w, h = r.x, r.y, r.w, r.h
    accent = accent or {1, 1, 1}
    love.graphics.setFont(FONT_MED)
    if selected then
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle('fill', x + 4, y + 4, w, h)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle('fill', x, y, w, h)
        love.graphics.setColor(accent[1] * 0.8, accent[2] * 0.8, accent[3] * 0.8, 1)
        love.graphics.rectangle('fill', x, y, 6, h)
        love.graphics.setColor(0, 0, 0, 1)
    else
        love.graphics.setColor(0, 0, 0, 0.75)
        love.graphics.rectangle('fill', x, y, w, h)
        love.graphics.setColor(1, 1, 1, 0.35)
        love.graphics.rectangle('line', x, y, w, h)
        love.graphics.setColor(accent[1], accent[2], accent[3], 0.9)
        love.graphics.rectangle('fill', x, y, 3, h)
        love.graphics.setColor(1, 1, 1, 0.9)
    end
    love.graphics.printf(label, x, y + h/2 - FONT_MED:getHeight()/2, w, 'center')
end

local function sectionLabel(text, x, y, w, active)
    love.graphics.setFont(FONT_SMALL)
    love.graphics.setColor(1, 0.85, 0, active and 0.95 or 0.5)
    love.graphics.print(text, x, y)
    love.graphics.setColor(1, 0.85, 0, active and 0.45 or 0.15)
    love.graphics.rectangle('fill', x, y + 15, w, 1)
end

-- Tarjeta "PARTIDA": modo elegido, su objetivo y el mapa con miniatura.
function OnlineRoomState:_renderGameCard(r, isAdmin)
    local room = self.currentRoom or {}
    local mode = Modes.get(room.mode)
    if not mode then return end
    local col  = mode.color
    local x, y, w, h = r.x, r.y, r.w, r.h
    local pad  = 14

    love.graphics.setColor(col[1] * 0.14, col[2] * 0.14, col[3] * 0.14, 0.92)
    love.graphics.rectangle('fill', x, y, w, h)
    love.graphics.setColor(col[1], col[2], col[3], 0.85)
    love.graphics.rectangle('line', x, y, w, h)
    love.graphics.rectangle('fill', x, y, w, 4)

    -- Modo: icono + nombre
    local iw, ih = PixelIcons.size(mode.icon or '')
    local tx = x + pad
    if iw > 0 then
        PixelIcons.draw(mode.icon, tx, y + 16, 3)
        tx = tx + iw * 3 + 14
    end
    love.graphics.setFont(FONT_SMALL)
    love.graphics.setColor(1, 1, 1, 0.45)
    love.graphics.print('MODO', tx, y + 14)
    love.graphics.setFont(FONT_MED)
    love.graphics.setColor(col[1], col[2], col[3], 1)
    love.graphics.print(fitText(FONT_MED, mode.label, x + w - pad - tx), tx, y + 30)

    -- Objetivo
    love.graphics.setFont(FONT_SMALL)
    love.graphics.setColor(1, 1, 1, 0.75)
    local _, lines = FONT_SMALL:getWrap(mode.tagline, w - 2 * pad)
    local ty = y + 62
    for i = 1, math.min(2, #lines) do
        love.graphics.print(lines[i], x + pad, ty)
        ty = ty + FONT_SMALL:getHeight() + 6
    end

    -- Mapa: miniatura + nombre
    local my = y + h - 84
    love.graphics.setColor(col[1], col[2], col[3], 0.3)
    love.graphics.rectangle('fill', x + pad, my - 8, w - 2 * pad, 1)
    local pw, ph = 150, 64
    local lvl
    for _, l in ipairs(self.catalog or {}) do if l.path == room.level then lvl = l end end
    if lvl then
        ModeSelectMenu.drawPreview(lvl, x + pad, my + 2, pw, ph, self.t or 0, 1)
    else
        love.graphics.setColor(0.2, 0.3, 0.5, 1)
        love.graphics.rectangle('fill', x + pad, my + 2, pw, ph)
    end
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.rectangle('line', x + pad, my + 2, pw, ph)
    local nx = x + pad + pw + 16
    love.graphics.setFont(FONT_SMALL)
    love.graphics.setColor(1, 1, 1, 0.45)
    love.graphics.print('MAPA', nx, my + 8)
    if room.levelName then
        love.graphics.setFont(FONT_MED)
        love.graphics.setColor(1, 0.85, 0.2, 1)
        love.graphics.print(fitText(FONT_MED, room.levelName, x + w - pad - nx), nx, my + 24)
    else
        love.graphics.setColor(1, 0.35, 0.35, 0.95)
        love.graphics.print('Ningún mapa sirve para este modo', nx, my + 26)
    end
    love.graphics.setFont(FONT_SMALL)
    love.graphics.setColor(1, 1, 1, 0.35)
    love.graphics.print(isAdmin and 'Cambia en MODO DE JUEGO' or 'Lo elige el host', nx, my + 50)
end

-- ── Render ────────────────────────────────────────────────────────────────────

function OnlineRoomState:render()
    -- Fondo
    love.graphics.setColor(COLOR_WHITE)
    love.graphics.draw(imgBg, 0, 0, 0, WINDOW_W / imgBg:getWidth(), WINDOW_H / imgBg:getHeight())

    local room    = self.currentRoom or {}
    local players = room.players or {}
    local np      = #players
    local isAdmin = room.adminId == NC.myId
    local actions = self:_buildActions()
    local L       = self:_layout()
    local P       = L.panel

    drawSharpPanel(P.x, P.y, P.w, P.h, 0.02, 0.02, 0.04, 0.93)

    -- ── Cabecera ──────────────────────────────────────────────────────────────
    love.graphics.setFont(FONT_BIG)
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.printf(room.name or "Sala", P.x + 3, P.y + 17, P.w, 'center')
    love.graphics.setColor(1, 0.95, 0.15, 1)
    love.graphics.printf(room.name or "Sala", P.x, P.y + 14, P.w, 'center')
    love.graphics.setFont(FONT_SMALL)
    local stateStr = (room.state == "IN_GAME") and "EN PARTIDA" or "ESPERANDO"
    local privStr  = (room.isPublic == false) and "PRIVADA" or "PUBLICA"
    local countStr = np .. "/" .. (room.maxPlayers or "?") .. " JUGADORES"
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.printf(stateStr .. "   ·   " .. privStr .. "   ·   " .. countStr, P.x, P.y + 56, P.w, 'center')
    love.graphics.setColor(1, 0.85, 0, 0.25)
    love.graphics.rectangle('fill', P.x + 20, P.y + HDR_H, P.w - 40, 1)

    -- Separador vertical
    love.graphics.setColor(1, 0.85, 0, 0.12)
    love.graphics.rectangle('fill', L.right.x - 20, L.bodyY, 1, L.bottom - L.bodyY)

    -- ── Jugadores ─────────────────────────────────────────────────────────────
    local focusP = self.focus == FOCUS_PLAYERS and self.sub == SUB_MAIN
    sectionLabel("JUGADORES", L.left.x, L.bodyY, L.left.w, focusP)
    for i, p in ipairs(players) do
        local r = L.rows[i]
        if not r then break end
        local col    = p.color or {0.7, 0.7, 0.7}
        local isSelf = (p.id == NC.myId)
        local isSel  = (i == self.playerSel) and focusP

        love.graphics.setColor(1, 1, 1, isSel and 0.10 or 0.04)
        love.graphics.rectangle('fill', r.x, r.y, r.w, r.h)
        if isSel then
            love.graphics.setColor(1, 0.85, 0, 0.7)
            love.graphics.rectangle('line', r.x, r.y, r.w, r.h)
        end
        love.graphics.setColor(col[1], col[2], col[3], 1)
        love.graphics.rectangle('fill', r.x, r.y, 6, r.h)

        -- Nombre (+ corona del host centrada con el texto, como en el HUD)
        love.graphics.setFont(FONT_MED)
        local nameY = r.y + r.h / 2 - FONT_MED:getHeight() / 2
        local nx = r.x + 20
        if p.id == room.adminId then
            local px = 2
            PixelIcons.crown(nx, nameY + FONT_MED:getHeight() / 2 - 6.5 * px, px)
            nx = nx + PixelIcons.CROWN_W * px + 10
        end
        local nameMax = r.w - (nx - r.x) - 110
        local name = fitText(FONT_MED, p.name or '?', nameMax - (isSelf and 60 or 0))
        love.graphics.setColor(col[1] * 0.7 + 0.3, col[2] * 0.7 + 0.3, col[3] * 0.7 + 0.3, 1)
        love.graphics.print(name, nx, nameY)
        if isSelf then
            love.graphics.setFont(FONT_SMALL)
            love.graphics.setColor(0.6, 0.85, 1, 0.8)
            love.graphics.print("(tú)", nx + FONT_MED:getWidth(name) + 10, nameY + 4)
        end

        -- Listo (pastilla) y ping
        love.graphics.setFont(FONT_SMALL)
        local bw, bh = 76, 20
        local bx, byy = r.x + r.w - bw - 12, r.y + 8
        if p.isReady then
            love.graphics.setColor(0.3, 1, 0.45, 0.9)
            love.graphics.rectangle('fill', bx, byy, bw, bh)
            love.graphics.setColor(0, 0, 0, 1)
        else
            love.graphics.setColor(1, 1, 1, 0.25)
            love.graphics.rectangle('line', bx, byy, bw, bh)
            love.graphics.setColor(1, 1, 1, 0.45)
        end
        love.graphics.printf(p.isReady and "LISTO" or "ESPERA", bx, byy + 5, bw, 'center')
        love.graphics.setColor(1, 1, 1, 0.35)
        love.graphics.printf(string.format("%d ms", p.ping or 0), bx - 20, r.y + r.h - 16, bw + 20, 'right')
    end
    if focusP and isAdmin then
        local sel = players[self.playerSel]
        if sel and sel.id ~= NC.myId then
            love.graphics.setFont(FONT_SMALL)
            love.graphics.setColor(1, 0.85, 0, 0.6)
            love.graphics.print("[ENTER] acciones sobre " .. (sel.name or '?'), L.left.x, L.bottom + 6)
        end
    end

    -- ── Partida + acciones ────────────────────────────────────────────────────
    sectionLabel("PARTIDA", L.right.x, L.bodyY, L.right.w, false)
    self:_renderGameCard(L.card, isAdmin)

    local focusA = self.focus == FOCUS_ACTIONS and self.sub == SUB_MAIN
    for i, act in ipairs(actions) do
        local r = L.buttons[i]
        if r and r.y + r.h <= L.bottom + 10 then
            drawActionBtn(act.label, r, focusA and i == self.actionSel, act.color)
        end
    end

    -- Ayuda de navegación
    love.graphics.setFont(FONT_SMALL)
    love.graphics.setColor(1, 1, 1, 0.3)
    local hint = self.focus == FOCUS_ACTIONS and "[<] ver jugadores" or "[>] ir a acciones"
    love.graphics.printf(hint, L.right.x, L.bottom + 6, L.right.w, 'right')

    -- ── Menú de acción sobre un jugador ──────────────────────────────────────
    if self.sub == SUB_PMENU then
        local target = players[self.playerSel]
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)
        local M = L.pmenu
        drawSharpPanel(M.x, M.y, M.w, M.h, 0.04, 0.04, 0.06, 0.96)
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(1, 1, 1, 0.65)
        love.graphics.printf("Acción sobre:  " .. (target and target.name or "?"), M.x, M.y + 16, M.w, 'center')
        love.graphics.setColor(1, 0.85, 0, 0.3)
        love.graphics.rectangle('fill', M.x + 20, M.y + 38, M.w - 40, 1)
        for i, lbl in ipairs(PMENU_LABELS) do
            drawActionBtn(lbl, L.pmenuBtns[i], i == self.pmenuSel, PMENU_COLORS[i])
        end
    end

    -- ── Menú "MODO DE JUEGO" ──────────────────────────────────────────────────
    if self.sub == SUB_MODES and self.modeMenu then self.modeMenu:render() end

    -- ── Anuncios ──────────────────────────────────────────────────────────────
    if #self.announcements > 0 then
        -- Al pie de la columna de jugadores
        love.graphics.setFont(FONT_SMALL)
        local ay = L.bottom - 24 - (#self.announcements - 1) * 30
        for _, ann in ipairs(self.announcements) do
            local alpha = math.min(ann.timer / 1.5, 1)
            local text  = fitText(FONT_SMALL, "» " .. ann.msg, L.left.w - 24)
            local tw    = FONT_SMALL:getWidth(text) + 24
            local ax    = math.floor(L.left.x + (L.left.w - tw) / 2)
            love.graphics.setColor(0, 0, 0, 0.75 * alpha)
            love.graphics.rectangle('fill', ax, ay - 8, tw, 26)
            love.graphics.setColor(1, 0.95, 0.2, alpha)
            love.graphics.print(text, ax + 12, ay)
            ay = ay + 30
        end
    end

    -- ── Error ─────────────────────────────────────────────────────────────────
    if self.errorMsg ~= "" then
        local eW = math.min(600, P.w - 40)
        local eX = math.floor((WINDOW_W - eW) / 2)
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle('fill', eX - 8, WINDOW_H - 36, eW + 16, 28)
        love.graphics.setColor(1, 0.3, 0.3, 1)
        love.graphics.rectangle('line', eX - 8, WINDOW_H - 36, eW + 16, 28)
        love.graphics.setFont(FONT_SMALL)
        love.graphics.printf(self.errorMsg, eX, WINDOW_H - 27, eW, 'center')
    end

    love.graphics.setColor(COLOR_WHITE)
end

return OnlineRoomState
