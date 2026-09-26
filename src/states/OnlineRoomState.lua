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

    self:_setupHandlers()
    Sound.playMusic('menus')
end

function OnlineRoomState:_setupHandlers()
    NC:on("room_update", function(data)
        self.currentRoom = data
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
        self.modeMenu = ModeSelectMenu.new(self.currentRoom)
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

-- ── Hover del mouse: actualiza las variables de selección reales ──────────────

function OnlineRoomState:mousemoved(tx, ty)
    if self.sub == SUB_MODES then return end
    if self.sub == SUB_PMENU then
        local mW  = 340
        local mH  = #PMENU_LABELS * 60 + 72
        local mX  = math.floor((WINDOW_W - mW) / 2)
        local mY  = math.floor((WINDOW_H - mH) / 2)
        local bW  = 240; local bH = 48; local bGap = 10
        local bX  = mX + (mW - bW) / 2; local bY0 = mY + 50
        for i = 1, #PMENU_LABELS do
            local by = bY0 + (i-1) * (bH + bGap)
            if tx >= bX-10 and tx <= bX+bW+10 and ty >= by-5 and ty <= by+bH+5 then
                if self.pmenuSel ~= i then self.pmenuSel = i; Sound.play('select') end
                return
            end
        end
    else
        local actions   = self:_buildActions()
        local panelX    = math.floor(WINDOW_W * 0.06)
        local panelY    = 44
        local panelW    = WINDOW_W - 2 * panelX
        local panelH    = WINDOW_H - 88
        local hdrH      = 78
        local bodyY     = panelY + hdrH + 8
        local leftW     = math.floor(panelW * 0.53) - 20
        local rightX    = panelX + 20 + leftW + 20
        local rightW    = panelW - leftW - 20 - 40
        local btnH      = 56; local btnGap = 14
        local btnStartY = bodyY + 2 + 28
        for i = 1, #actions do
            local by = btnStartY + (i-1) * (btnH + btnGap)
            if by + btnH > panelY + panelH - 14 then break end
            if tx >= rightX-10 and tx <= rightX+rightW+10 and ty >= by-5 and ty <= by+btnH+5 then
                if self.focus ~= FOCUS_ACTIONS or self.actionSel ~= i then
                    self.focus = FOCUS_ACTIONS; self.actionSel = i; Sound.play('select')
                end
                return
            end
        end
    end
end

-- ── Touch ─────────────────────────────────────────────────────────────────────

function OnlineRoomState:touchpressed(id, tx, ty)
    local room    = self.currentRoom
    local players = room and room.players or {}
    local np      = #players
    local isAdmin = room and (room.adminId == NC.myId)
    local actions = self:_buildActions()

    if self.sub == SUB_MODES and self.modeMenu then
        if self.modeMenu:touch(tx, ty) == 'close' then self:_closeModeMenu() end
        return
    end

    -- ── Overlay del menú de jugador ──────────────────────────────────────────
    if self.sub == SUB_PMENU then
        local mW  = 340
        local mH  = #PMENU_LABELS * 60 + 72
        local mX  = math.floor((WINDOW_W - mW) / 2)
        local mY  = math.floor((WINDOW_H - mH) / 2)
        local bW  = 240
        local bH  = 48
        local bGap = 10
        local bX  = mX + (mW - bW) / 2
        local bY0 = mY + 50

        for i = 1, #PMENU_LABELS do
            local by = bY0 + (i - 1) * (bH + bGap)
            if tx >= bX - 10 and tx <= bX + bW + 10 and
               ty >= by  - 5 and ty <= by + bH  + 5 then
                self.pmenuSel = i
                Sound.play('select')
                self:_executePmenu(players)
                return
            end
        end
        -- Toque fuera del menú = cancelar
        self.sub = SUB_MAIN
        return
    end

    -- ── Geometría de columnas (igual que render) ─────────────────────────────
    local panelX     = math.floor(WINDOW_W * 0.06)
    local panelY     = 44
    local panelW     = WINDOW_W - 2 * panelX
    local panelH     = WINDOW_H - 88
    local hdrH       = 78
    local bodyY      = panelY + hdrH + 8
    local bodyH      = panelH - hdrH - 8
    local gapBetween = 20
    local leftW      = math.floor(panelW * 0.53) - 20
    local rightW     = panelW - leftW - gapBetween - 40
    local leftX      = panelX + 20
    local rightX     = leftX + leftW + gapBetween

    -- ── Columna izquierda: lista de jugadores ────────────────────────────────
    local lblY       = bodyY + 2
    local listStartY = lblY + 24
    local rowH       = math.min(58, math.floor((bodyH - 28) / math.max(1, np)))
    rowH = math.max(42, rowH)

    for i = 1, np do
        local ry = listStartY + (i - 1) * rowH
        if ry + rowH > panelY + panelH - 14 then break end
        if tx >= leftX     and tx <= leftX + leftW and
           ty >= ry        and ty <= ry + rowH - 3 then
            self.focus     = FOCUS_PLAYERS
            self.playerSel = i
            Sound.play('select')
            -- Admin: abrir menú de acción si selecciona a otro jugador
            local sel = players[i]
            if isAdmin and sel and sel.id ~= NC.myId then
                self.sub      = SUB_PMENU
                self.pmenuSel = PMENU_CANCEL
            end
            return
        end
    end

    -- ── Columna derecha: botones de acción ───────────────────────────────────
    local btnH      = 56
    local btnGap    = 14
    local actLblY   = bodyY + 2
    local btnStartY = actLblY + 28

    for i, act in ipairs(actions) do
        local by = btnStartY + (i - 1) * (btnH + btnGap)
        if by + btnH > panelY + panelH - 14 then break end
        if tx >= rightX - 10      and tx <= rightX + rightW + 10 and
           ty >= by    - 5        and ty <= by    + btnH   + 5 then
            self.focus     = FOCUS_ACTIONS
            self.actionSel = i
            Sound.play('select')
            self:_executeAction(act.id)
            return
        end
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

local function drawActionBtn(label, x, y, w, h, selected)
    if selected then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle('fill', x, y, w, h)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle('line', x, y, w, h)
        love.graphics.setFont(FONT_MED)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.printf(label, x, y + h/2 - FONT_MED:getHeight()/2, w, 'center')
    else
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle('fill', x, y, w, h)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle('line', x, y, w, h)
        love.graphics.setFont(FONT_MED)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(label, x, y + h/2 - FONT_MED:getHeight()/2, w, 'center')
    end
end

-- Tarjeta con el modo elegido, su objetivo y el nivel. `bottom` = borde inferior.
function OnlineRoomState:_renderModeCard(x, bottom, w, isAdmin)
    local room = self.currentRoom or {}
    local mode = Modes.get(room.mode)
    if not mode then return end
    local col  = mode.color
    local pad  = 12
    local _, tagLines = FONT_SMALL:getWrap(mode.tagline, w - 2 * pad)
    local h    = pad + 28 + #tagLines * (FONT_SMALL:getHeight() + 6) + 8 + 18 + pad
    local y    = bottom - h

    love.graphics.setColor(col[1] * 0.15, col[2] * 0.15, col[3] * 0.15, 0.85)
    love.graphics.rectangle('fill', x, y, w, h)
    love.graphics.setColor(col[1], col[2], col[3], 0.8)
    love.graphics.rectangle('line', x, y, w, h)
    love.graphics.rectangle('fill', x, y, 4, h)

    -- Icono + nombre del modo
    local iw, ih = PixelIcons.size(mode.icon or '')
    local tx = x + pad + 6
    if iw > 0 then
        PixelIcons.draw(mode.icon, tx, y + pad + 2, 2)
        tx = tx + iw * 2 + 12
    end
    love.graphics.setFont(FONT_MED)
    love.graphics.setColor(col[1], col[2], col[3], 1)
    love.graphics.print(fitText(FONT_MED, mode.label, x + w - pad - tx), tx, y + pad + 3)

    -- Objetivo
    love.graphics.setFont(FONT_SMALL)
    love.graphics.setColor(1, 1, 1, 0.75)
    local ty = y + pad + 28
    for _, line in ipairs(tagLines) do
        love.graphics.print(line, x + pad + 6, ty)
        ty = ty + FONT_SMALL:getHeight() + 6
    end

    -- Nivel
    ty = ty + 8
    if room.levelName then
        love.graphics.setColor(1, 0.85, 0, 0.9)
        love.graphics.print(fitText(FONT_SMALL, 'NIVEL: ' .. room.levelName, w - 2 * pad - 6), x + pad + 6, ty)
    else
        love.graphics.setColor(1, 0.35, 0.35, 0.95)
        love.graphics.print('NINGUN NIVEL SIRVE PARA ESTE MODO', x + pad + 6, ty)
    end
    if not isAdmin then
        love.graphics.setColor(1, 1, 1, 0.35)
        love.graphics.printf('elige el host', x, ty, w - pad, 'right')
    end
end

-- ── Render ────────────────────────────────────────────────────────────────────

function OnlineRoomState:render()
    -- Fondo
    local bx = WINDOW_W / imgBg:getWidth()
    local by = WINDOW_H / imgBg:getHeight()
    love.graphics.setColor(COLOR_WHITE)
    love.graphics.draw(imgBg, 0, 0, 0, bx, by)

    local room    = self.currentRoom
    local players = room and room.players or {}
    local np      = #players
    local isAdmin = room and (room.adminId == NC.myId)
    local actions = self:_buildActions()

    -- Geometría del panel principal
    local panelX = math.floor(WINDOW_W * 0.06)
    local panelY = 44
    local panelW = WINDOW_W - 2 * panelX
    local panelH = WINDOW_H - 88

    -- Panel de fondo
    drawSharpPanel(panelX, panelY, panelW, panelH, 0,0,0,0.65)

    -- ── Cabecera ──────────────────────────────────────────────────────────────
    local hdrH   = 78
    local roomName = room and room.name or "Sala"
    love.graphics.setFont(FONT_BIG)
    love.graphics.setColor(1, 0.95, 0.15, 1)
    love.graphics.printf(roomName, panelX, panelY + 14, panelW, 'center')

    -- Info: estado | tipo | jugadores
    love.graphics.setFont(FONT_SMALL)
    local stateStr = (room and room.state == "IN_GAME") and "EN PARTIDA" or "ESPERANDO"
    local privStr  = (room and room.isPublic == false) and "PRIVADA" or "PUBLICA"
    local countStr = np .. "/" .. (room and room.maxPlayers or "?")
    love.graphics.setColor(1, 1, 1, 0.45)
    love.graphics.printf(stateStr .. "  |  " .. privStr .. "  |  " .. countStr,
        panelX, panelY + hdrH - 22, panelW, 'center')

    -- Línea divisora horizontal
    love.graphics.setColor(1, 0.85, 0, 0.25)
    love.graphics.line(panelX + 20, panelY + hdrH, panelX + panelW - 20, panelY + hdrH)

    -- ── Cuerpo: dos columnas ──────────────────────────────────────────────────
    local bodyY  = panelY + hdrH + 8
    local bodyH  = panelH - hdrH - 8

    local gapBetween = 20
    local leftW      = math.floor(panelW * 0.53) - 20
    local rightW     = panelW - leftW - gapBetween - 40
    local leftX      = panelX + 20
    local rightX     = leftX + leftW + gapBetween

    -- Línea divisora vertical
    love.graphics.setColor(1, 0.85, 0, 0.18)
    love.graphics.line(rightX - gapBetween/2, bodyY + 4, rightX - gapBetween/2, panelY + panelH - 12)

    -- ── Columna izquierda: jugadores ──────────────────────────────────────────
    local lblY = bodyY + 2
    love.graphics.setFont(FONT_SMALL)
    love.graphics.setColor(1, 0.85, 0, self.focus == FOCUS_PLAYERS and 0.9 or 0.45)
    love.graphics.print("JUGADORES", leftX, lblY)
    love.graphics.setColor(1, 0.85, 0, self.focus == FOCUS_PLAYERS and 0.5 or 0.15)
    love.graphics.line(leftX, lblY + 16, leftX + leftW, lblY + 16)

    local listStartY = lblY + 24
    local rowH       = math.min(58, math.floor((bodyH - 28) / math.max(1, np)))
    rowH = math.max(42, rowH)

    for i, p in ipairs(players) do
        local ry      = listStartY + (i - 1) * rowH
        if ry + rowH > panelY + panelH - 14 then break end  -- no salir del panel

        local col     = p.color or {0.7, 0.7, 0.7}
        local isSelf  = (p.id == NC.myId)
        local isSel   = (i == self.playerSel)
        local focused = (self.focus == FOCUS_PLAYERS)

        -- Fondo de fila seleccionada
        if isSel and focused then
            love.graphics.setColor(1, 1, 1, 0.08)
            love.graphics.rectangle('fill', leftX, ry, leftW, rowH - 3)
            love.graphics.setColor(1, 0.85, 0, 0.6)
            love.graphics.rectangle('line', leftX, ry, leftW, rowH - 3)
        elseif isSel then
            love.graphics.setColor(1, 1, 1, 0.04)
            love.graphics.rectangle('fill', leftX, ry, leftW, rowH - 3)
        end

        -- Cursor ">"
        if isSel and focused then
            love.graphics.setFont(FONT_SMALL)
            love.graphics.setColor(1, 0.85, 0, 1)
            love.graphics.print(">", leftX + 4, ry + rowH/2 - FONT_SMALL:getHeight()/2)
        end

        -- Barra de color
        love.graphics.setColor(col[1], col[2], col[3], isSel and 1 or 0.7)
        love.graphics.rectangle('fill', leftX + 22, ry + 8, 5, rowH - 18)

        -- Nombre
        local nameY = ry + rowH/2 - FONT_SMALL:getHeight()/2
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(col[1] * 0.8 + 0.2, col[2] * 0.8 + 0.2, col[3] * 0.8 + 0.2, 1)
        love.graphics.print(p.name, leftX + 34, nameY)

        -- Tags
        local tagX = leftX + 34 + FONT_SMALL:getWidth(p.name) + 8
        if isSelf then
            love.graphics.setColor(0.5, 0.8, 1, 0.8)
            love.graphics.print("(tú)", tagX, nameY)
            tagX = tagX + FONT_SMALL:getWidth("(tú)") + 8
        end
        if p.id == room.adminId then
            love.graphics.setColor(1, 0.85, 0, 0.8)
            love.graphics.print("ADM", tagX, nameY)
        end

        -- Admin: indicador de acción disponible si otro jugador está seleccionado
        if isSel and focused and isAdmin and not isSelf then
            love.graphics.setFont(FONT_SMALL)
            love.graphics.setColor(1, 0.85, 0, 0.65)
            love.graphics.printf("[ENTER] acción", leftX, ry + rowH - FONT_SMALL:getHeight() - 3, leftW, 'right')
        end

        -- Ping (derecha) y listo
        local rightEdge = leftX + leftW - 6
        love.graphics.setFont(FONT_SMALL)
        local pingStr = string.format("%dms", p.ping or 0)
        local readyStr = p.isReady and "LISTO" or "—"
        love.graphics.setColor(p.isReady and {0.3,1,0.3,0.9} or {0.5,0.5,0.5,0.5})
        love.graphics.printf(readyStr, leftX, ry + rowH/2 - FONT_SMALL:getHeight() - 2, leftW - 6, 'right')
        love.graphics.setColor(0.5, 0.5, 0.5, 0.45)
        love.graphics.printf(pingStr, leftX, ry + rowH/2 + 2, leftW - 6, 'right')
    end

    -- Aviso para admin de cómo navegar a acciones
    local navHintY = panelY + panelH - 24
    if self.focus == FOCUS_PLAYERS then
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(1, 1, 1, 0.3)
        love.graphics.print("[>] ir a acciones", leftX, navHintY)
    end

    -- ── Columna derecha: botones de acción ────────────────────────────────────
    local actLblY = bodyY + 2
    love.graphics.setFont(FONT_SMALL)
    love.graphics.setColor(1, 0.85, 0, self.focus == FOCUS_ACTIONS and 0.9 or 0.45)
    love.graphics.print("ACCIONES", rightX, actLblY)
    love.graphics.setColor(1, 0.85, 0, self.focus == FOCUS_ACTIONS and 0.5 or 0.15)
    love.graphics.line(rightX, actLblY + 16, rightX + rightW, actLblY + 16)

    local btnH   = 56
    local btnGap = 14
    local btnStartY = actLblY + 28
    local focused   = (self.focus == FOCUS_ACTIONS)

    for i, act in ipairs(actions) do
        local by  = btnStartY + (i - 1) * (btnH + btnGap)
        if by + btnH > panelY + panelH - 14 then break end
        local sel = (i == self.actionSel) and focused
        drawActionBtn(act.label, rightX, by, rightW, btnH, sel)
    end

    -- Tarjeta del modo de juego (la ven todos)
    self:_renderModeCard(rightX, navHintY - 12, rightW, isAdmin)

    -- Aviso de cómo navegar de vuelta a jugadores
    if self.focus == FOCUS_ACTIONS then
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(1, 1, 1, 0.3)
        love.graphics.printf("[<] ver jugadores", rightX, navHintY, rightW, 'right')
    end

    -- ── Overlay menú de jugador ───────────────────────────────────────────────
    if self.sub == SUB_PMENU then
        local target = players[self.playerSel]
        local tname  = target and target.name or "?"

        -- Fondo semitransparente
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)

        local mW = 340
        local mH = #PMENU_LABELS * 60 + 72
        local mX = math.floor((WINDOW_W - mW) / 2)
        local mY = math.floor((WINDOW_H - mH) / 2)

        drawSharpPanel(mX, mY, mW, mH, 0.04,0.04,0.06,0.96)

        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(1, 1, 1, 0.65)
        love.graphics.printf("Acción sobre:  " .. tname, mX, mY + 16, mW, 'center')
        love.graphics.setColor(1, 0.85, 0, 0.3)
        love.graphics.line(mX + 20, mY + 38, mX + mW - 20, mY + 38)

        love.graphics.setFont(FONT_MED)
        local bW = 240
        local bH = 48
        local bGap = 10
        local bX = mX + (mW - bW) / 2
        local bY0 = mY + 50

        for i, lbl in ipairs(PMENU_LABELS) do
            local by  = bY0 + (i - 1) * (bH + bGap)
            local sel = (i == self.pmenuSel)
            drawActionBtn(lbl, bX, by, bW, bH, sel)
        end
    end

    -- ── Anuncios ──────────────────────────────────────────────────────────────
    if #self.announcements > 0 then
        love.graphics.setFont(FONT_MED)
        local annH   = FONT_MED:getHeight() + 20
        local annGap = 8
        local totalH = #self.announcements * annH + (#self.announcements - 1) * annGap
        local ay     = WINDOW_H * 0.62 - totalH / 2
        for _, ann in ipairs(self.announcements) do
            local alpha = math.min(ann.timer / 1.5, 1)
            local text  = "» " .. ann.msg
            local tw    = FONT_MED:getWidth(text)
            local ax    = math.floor((WINDOW_W - tw) / 2)
            love.graphics.setColor(1, 0.95, 0.2, alpha)
            love.graphics.print(text, ax, ay)
            ay = ay + annH + annGap
        end
    end

    -- ── Menú "MODO DE JUEGO" ──────────────────────────────────────────────────
    if self.sub == SUB_MODES and self.modeMenu then self.modeMenu:render() end

    -- ── Error ─────────────────────────────────────────────────────────────────
    if self.errorMsg ~= "" then
        local eW = math.min(600, panelW - 40)
        local eX = math.floor((WINDOW_W - eW) / 2)
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle('fill', eX - 8, WINDOW_H - 38, eW + 16, 28)
        love.graphics.setColor(1, 0.3, 0.3, 1)
        love.graphics.rectangle('line', eX - 8, WINDOW_H - 38, eW + 16, 28)
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(1, 0.3, 0.3, 1)
        love.graphics.printf(self.errorMsg, eX, WINDOW_H - 34, eW, 'center')
    end

    love.graphics.setColor(COLOR_WHITE)
end

return OnlineRoomState
