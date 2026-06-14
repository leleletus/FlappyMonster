-- src/states/OnlineHubState.lua
-- Hub de salas: lista de salas, crear sala y unirse.
-- Toda la navegación con flechas/gamepad — sin atajos de teclado directos.

local BaseState      = require 'src/BaseState'
local NC             = require 'src/network/NetworkClient'
local OnlineHubState = BaseState:new()

local imgBg = nil
local function loadAssets()
    if imgBg then return end
    imgBg = love.graphics.newImage('assets/images/menus/MenuDif.png')
end

-- Sub-estados
local SUB_LIST     = "LIST"
local SUB_CREATE   = "CREATE"
local SUB_PASSWORD = "PASSWORD"
local SUB_WAITING  = "WAITING"   -- esperando room_update tras create/join

local ROOM_WAIT_TIMEOUT = 6   -- segundos antes de considerar que el server no responde

-- Pasos del wizard de creación
local STEP_NAME    = 1
local STEP_PRIVACY = 2
local STEP_PASS    = 3
local STEP_MAX     = 4

-- Botones inferiores de la lista
local BTN_CREATE  = 1
local BTN_REFRESH = 2
local BTN_BACK    = 3
local LIST_BTNS   = { 'CREAR SALA', 'REFRESCAR', 'VOLVER' }

-- ── Enter ─────────────────────────────────────────────────────────────────────

function OnlineHubState:enter(args)
    loadAssets()
    self.sub          = SUB_LIST
    self.roomList     = {}
    self.selectedIdx  = 1
    self.errorMsg     = ""
    self.errorTimer   = 0
    self.refreshTimer = 0
    self._keyboardOn     = false
    self.hoveredCreateBtn = nil   -- solo para botones sin variable de selección (STEP_MAX ±)
    self.hoveredPassBtn  = nil    -- solo para CANCELAR (UNIRSE ya es siempre selected)

    -- Lista: foco en salas o en botones inferiores
    self.listFocus    = 'rooms'   -- 'rooms' | 'btns'
    self.btnSel       = BTN_CREATE

    -- Wizard de creación
    self.createStep   = STEP_NAME
    self.createData   = { name="", isPublic=true, password="", maxPlayers=4 }
    self.inputBuffer  = ""
    self.privacySel   = 1    -- 1=PUBLICA, 2=PRIVADA
    self.maxValue     = 4    -- seleccionado en paso 4

    -- Contraseña de entrada
    self.joinRoom     = nil

    -- Timeout al esperar respuesta del servidor tras create/join
    self.waitTimer    = 0

    self:_setupHandlers()
    NC:send("get_rooms", {})
end

function OnlineHubState:_setupHandlers()
    NC:on("room_list", function(data)
        self.roomList    = data or {}
        self.selectedIdx = math.min(self.selectedIdx, math.max(1, #self.roomList))
    end)
    NC:on("room_update", function(data)
        gStateMachine:change('online_room', { room = data })
    end)
    NC:on("room_error", function(data)
        self.errorMsg   = data.msg or "Error"
        self.errorTimer = 4
        if self.sub == SUB_PASSWORD or self.sub == SUB_WAITING then
            self.sub = SUB_LIST; self.inputBuffer = ""
        end
    end)
    NC:on("kicked",       function(data) self.errorMsg=data.msg or "Expulsado"; self.errorTimer=4 end)
    NC:on("room_closed",  function(data) self.errorMsg=data.msg or "Sala cerrada"; self.errorTimer=4 end)
    NC:on("connection_lost", function(data)
        gStateMachine:change('online_error', {
            code = "ERR_CONNECTION_LOST",
            msg  = data.msg or "Se perdio la conexion con el servidor.",
        })
    end)
end

function OnlineHubState:_showError(msg)
    self.errorMsg = msg; self.errorTimer = 4
end

-- Abre/cierra el teclado Android según si el sub-estado actual necesita texto.
-- Solo llama a setTextInput cuando el estado cambia (evita flicker).
function OnlineHubState:_syncKeyboard()
    local needs = (self.sub == SUB_CREATE and
                   (self.createStep == STEP_NAME or self.createStep == STEP_PASS)) or
                  (self.sub == SUB_PASSWORD)
    if needs ~= self._keyboardOn then
        self._keyboardOn = needs
        love.keyboard.setTextInput(needs)
    end
end

function OnlineHubState:_resetCreate()
    self.createStep = STEP_NAME
    self.createData = { name="", isPublic=true, password="", maxPlayers=4 }
    self.inputBuffer = ""
    self.privacySel  = 1
    self.maxValue    = 4
end

function OnlineHubState:_joinRoom(room)
    if room.hasPassword then
        self.joinRoom    = room
        self.inputBuffer = ""
        self.sub         = SUB_PASSWORD
    else
        NC:send("join_room", { id=room.id, password="" })
        self.sub = SUB_WAITING; self.waitTimer = 0
    end
end

-- ── textinput ─────────────────────────────────────────────────────────────────

function OnlineHubState:textinput(t)
    if self.sub == SUB_CREATE then
        if self.createStep == STEP_NAME and #self.inputBuffer < 28 then
            self.inputBuffer = self.inputBuffer .. t
        elseif self.createStep == STEP_PASS and #self.inputBuffer < 24 then
            self.inputBuffer = self.inputBuffer .. t
        end
        -- STEP_MAX y STEP_PRIVACY no usan textinput
    elseif self.sub == SUB_PASSWORD and #self.inputBuffer < 24 then
        self.inputBuffer = self.inputBuffer .. t
    end
end

-- ── keypressed ────────────────────────────────────────────────────────────────

function OnlineHubState:keypressed(k)
    -- Backspace: borrar último carácter del buffer de texto
    if k == "backspace" then
        if (self.sub == SUB_CREATE and (self.createStep == STEP_NAME or self.createStep == STEP_PASS)) or
           self.sub == SUB_PASSWORD then
            if #self.inputBuffer > 0 then
                self.inputBuffer = self.inputBuffer:sub(1, -2)
            end
        end
        return
    end
    -- Escape: se maneja en update() vía Input.pressed('back')
    -- Enter: se maneja en update() vía Input.pressed('confirm')
end

-- ── Update ────────────────────────────────────────────────────────────────────

function OnlineHubState:update(dt)
    if self.errorTimer > 0 then
        self.errorTimer = self.errorTimer - dt
        if self.errorTimer <= 0 then self.errorMsg = "" end
    end

    -- Auto-refresh cada 5s en lista
    if self.sub == SUB_LIST then
        self.refreshTimer = self.refreshTimer + dt
        if self.refreshTimer >= 5 then
            self.refreshTimer = 0; NC:send("get_rooms", {})
        end
    else
        self.refreshTimer = 0
    end

    -- ── SUB_WAITING: esperando room_update tras create/join ───────────────────
    if self.sub == SUB_WAITING then
        self.waitTimer = self.waitTimer + dt
        if self.waitTimer >= ROOM_WAIT_TIMEOUT then
            gStateMachine:change('online_error', {
                code = "ERR_SERVER_TIMEOUT",
                msg  = "El servidor no respondio a tiempo.",
            })
            return
        end
        if Input.pressed('back') then
            self.sub = SUB_LIST
        end
        return
    end

    -- ── SUB_LIST ──────────────────────────────────────────────────────────────
    if self.sub == SUB_LIST then
        local nr = #self.roomList

        if self.listFocus == 'rooms' then
            if Input.pressed('nav_up') then
                self.selectedIdx = self.selectedIdx - 1
                if self.selectedIdx < 1 then
                    -- subir por encima del primer item → ir a botones (última opción)
                    self.listFocus = 'btns'
                    self.btnSel    = #LIST_BTNS
                end
                Sound.play('select')
            end
            if Input.pressed('nav_down') then
                self.selectedIdx = self.selectedIdx + 1
                if self.selectedIdx > math.max(1, nr) or nr == 0 then
                    -- bajar del último item → ir a botones
                    self.selectedIdx = math.max(1, nr)
                    self.listFocus   = 'btns'
                    self.btnSel      = BTN_CREATE
                end
                Sound.play('select')
            end
            if Input.pressed('confirm') then
                if nr > 0 then
                    Sound.play('select')
                    self:_joinRoom(self.roomList[self.selectedIdx])
                end
            end
            if Input.pressed('back') then
                NC:disconnect(); gStateMachine:change('online_login')
            end

        elseif self.listFocus == 'btns' then
            if Input.pressed('nav_left') then
                self.btnSel = self.btnSel - 1
                if self.btnSel < 1 then self.btnSel = #LIST_BTNS end
                Sound.play('select')
            end
            if Input.pressed('nav_right') then
                self.btnSel = self.btnSel + 1
                if self.btnSel > #LIST_BTNS then self.btnSel = 1 end
                Sound.play('select')
            end
            if Input.pressed('nav_up') then
                -- volver a lista de salas
                self.listFocus   = 'rooms'
                self.selectedIdx = math.max(1, nr)
                Sound.play('select')
            end
            if Input.pressed('confirm') then
                Sound.play('select')
                if self.btnSel == BTN_CREATE then
                    self:_resetCreate(); self.sub = SUB_CREATE
                elseif self.btnSel == BTN_REFRESH then
                    NC:send("get_rooms", {})
                elseif self.btnSel == BTN_BACK then
                    NC:disconnect(); gStateMachine:change('online_login')
                end
            end
            if Input.pressed('back') then
                NC:disconnect(); gStateMachine:change('online_login')
            end
        end

    -- ── SUB_CREATE ────────────────────────────────────────────────────────────
    elseif self.sub == SUB_CREATE then

        if Input.pressed('back') then
            self.sub = SUB_LIST; self:_resetCreate()
            self:_syncKeyboard(); return
        end

        -- Paso 1: Nombre (text input + Enter para confirmar)
        if self.createStep == STEP_NAME then
            if Input.pressed('confirm') then
                if #self.inputBuffer > 0 then
                    self.createData.name = self.inputBuffer
                    self.inputBuffer     = ""
                    self.createStep      = STEP_PRIVACY
                    Sound.play('select')
                else
                    self:_showError("El nombre no puede estar vacío.")
                end
            end

        -- Paso 2: Privacidad (dos botones navegables)
        elseif self.createStep == STEP_PRIVACY then
            if Input.pressed('nav_up') or Input.pressed('nav_left') then
                self.privacySel = 1; Sound.play('select')
            end
            if Input.pressed('nav_down') or Input.pressed('nav_right') then
                self.privacySel = 2; Sound.play('select')
            end
            if Input.pressed('confirm') then
                self.createData.isPublic = (self.privacySel == 1)
                Sound.play('select')
                if self.privacySel == 2 then
                    self.inputBuffer = ""
                    self.createStep  = STEP_PASS
                else
                    self.createData.password = ""
                    self.createStep          = STEP_MAX
                end
            end

        -- Paso 3: Contraseña (solo para privadas; text input + Enter)
        elseif self.createStep == STEP_PASS then
            if Input.pressed('confirm') then
                self.createData.password = self.inputBuffer
                self.inputBuffer         = ""
                self.createStep          = STEP_MAX
                Sound.play('select')
            end

        -- Paso 4: Máximo de jugadores (selector ± con flechas + CREAR SALA)
        elseif self.createStep == STEP_MAX then
            if Input.pressed('nav_left') or Input.pressed('nav_up') then
                self.maxValue = math.max(2, self.maxValue - 1); Sound.play('select')
            end
            if Input.pressed('nav_right') or Input.pressed('nav_down') then
                self.maxValue = math.min(8, self.maxValue + 1); Sound.play('select')
            end
            if Input.pressed('confirm') then
                self.createData.maxPlayers = self.maxValue
                NC:send("create_room", self.createData)
                self:_resetCreate()
                self.sub = SUB_WAITING; self.waitTimer = 0
                Sound.play('select')
            end
        end

    -- ── SUB_PASSWORD ──────────────────────────────────────────────────────────
    elseif self.sub == SUB_PASSWORD then
        if Input.pressed('confirm') then
            if self.joinRoom then
                NC:send("join_room", { id=self.joinRoom.id, password=self.inputBuffer })
                self.inputBuffer = ""; self.joinRoom = nil
                self.sub = SUB_WAITING; self.waitTimer = 0
                Sound.play('select')
            end
        end
        if Input.pressed('back') then
            self.sub = SUB_LIST; self.inputBuffer = ""; self.joinRoom = nil
        end
    end

    -- Sincronizar teclado Android tras cualquier cambio de sub-estado o paso
    self:_syncKeyboard()
end

-- ── Helpers de dibujo ─────────────────────────────────────────────────────────

local function drawPanel(x, y, w, h)
    love.graphics.setColor(0, 0, 0, 0.65)
    love.graphics.rectangle('fill', x, y, w, h)
    love.graphics.setColor(1, 1, 1, 0.55)
    love.graphics.rectangle('line', x,   y,   w,   h)
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle('line', x+2, y+2, w-4, h-4)
end

local function drawBtn(label, x, y, w, h, selected)
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

local function drawTextBox(x, y, w, h, text, active)
    love.graphics.setColor(1, 1, 1, active and 0.15 or 0.08)
    love.graphics.rectangle('fill', x, y, w, h)
    love.graphics.setColor(1, 1, 1, active and 0.9 or 0.4)
    love.graphics.rectangle('line', x,   y,   w,   h)
    love.graphics.setColor(0, 0, 0, active and 0.6 or 0.3)
    love.graphics.rectangle('line', x+2, y+2, w-4, h-4)
    love.graphics.setFont(FONT_MED)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(text .. (active and "_" or ""), x + 12, y + h/2 - FONT_MED:getHeight()/2, w - 24, 'left')
end

-- ── Render ────────────────────────────────────────────────────────────────────

function OnlineHubState:render()
    local bx = WINDOW_W / imgBg:getWidth()
    local by = WINDOW_H / imgBg:getHeight()
    love.graphics.setColor(COLOR_WHITE)
    love.graphics.draw(imgBg, 0, 0, 0, bx, by)

    if self.sub == SUB_WAITING then
        self:_renderList()   -- fondo de lista debajo
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)
        local dots = string.rep(".", math.floor(love.timer.getTime() * 2) % 4)
        love.graphics.setFont(FONT_MED)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("Conectando" .. dots, 0, WINDOW_H / 2 - FONT_MED:getHeight(), WINDOW_W, 'center')
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(1, 1, 1, 0.4)
        love.graphics.printf("[ESC] Cancelar", 0, WINDOW_H / 2 + 20, WINDOW_W, 'center')
    elseif self.sub == SUB_LIST then
        self:_renderList()
    elseif self.sub == SUB_CREATE then
        self:_renderCreate()
    elseif self.sub == SUB_PASSWORD then
        self:_renderPassword()
    end

    if self.errorMsg ~= "" then
        local ew = math.min(700, WINDOW_W - 80)
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle('fill', (WINDOW_W-ew)/2 - 8, WINDOW_H - 40, ew + 16, 28)
        love.graphics.setColor(1, 0.3, 0.3, 1)
        love.graphics.rectangle('line', (WINDOW_W-ew)/2 - 8, WINDOW_H - 40, ew + 16, 28)
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(1, 0.3, 0.3, 1)
        love.graphics.printf(self.errorMsg, (WINDOW_W-ew)/2, WINDOW_H - 36, ew, 'center')
    end

    love.graphics.setColor(COLOR_WHITE)
end

function OnlineHubState:_renderList()
    local panelX = math.floor(WINDOW_W * 0.06)
    local panelY = 44
    local panelW = WINDOW_W - 2 * panelX
    local panelH = WINDOW_H - 88

    drawPanel(panelX, panelY, panelW, panelH)

    -- Título
    love.graphics.setFont(FONT_BIG)
    love.graphics.setColor(1, 0.95, 0.15, 1)
    love.graphics.printf('HUB DE SALAS', 0, panelY + 12, WINDOW_W, 'center')

    -- Usuario
    love.graphics.setFont(FONT_SMALL)
    love.graphics.setColor(1, 1, 1, 0.45)
    love.graphics.printf('Jugando como: ' .. (NC.myName or "?"), panelX + 20, panelY + 56, panelW - 40, 'left')

    love.graphics.setColor(1, 0.85, 0, 0.25)
    love.graphics.line(panelX + 20, panelY + 74, panelX + panelW - 20, panelY + 74)

    -- Botones de acción inferiores (altura fija)
    local btnH    = 48
    local btnGap  = 14
    local nBtns   = #LIST_BTNS
    local btnZoneH = btnH + 20   -- zona reservada abajo
    local btnsY   = panelY + panelH - btnZoneH

    love.graphics.setColor(1, 0.85, 0, 0.18)
    love.graphics.line(panelX + 20, btnsY, panelX + panelW - 20, btnsY)

    local btnTotalW = nBtns * math.floor((panelW - 80) / nBtns)
    local btnW      = math.floor((panelW - 80 - (nBtns-1) * btnGap) / nBtns)
    local bx0       = panelX + 40
    local by0       = btnsY + 10
    local btnColors = { {0.3,1,0.3}, {0.3,0.7,1}, {0.8,0.3,0.3} }

    for i, lbl in ipairs(LIST_BTNS) do
        local bx  = bx0 + (i-1) * (btnW + btnGap)
        local sel = (self.listFocus == 'btns' and i == self.btnSel)
        drawBtn(lbl, bx, by0, btnW, btnH, sel)
    end

    -- Lista de salas
    local listStartY = panelY + 84
    local listEndY   = btnsY - 6
    local listH      = listEndY - listStartY
    local nr         = #self.roomList
    local rowH       = 46

    if nr == 0 then
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(1, 1, 1, 0.35)
        love.graphics.printf('No hay salas disponibles. Crea una!',
            panelX + 20, listStartY + listH/2 - 8, panelW - 40, 'center')
    else
        local maxVisible = math.floor(listH / rowH)
        -- Scroll si hay muchas salas
        local scrollOff  = math.max(0, self.selectedIdx - maxVisible)
        for i = scrollOff + 1, math.min(nr, scrollOff + maxVisible) do
            local ry       = listStartY + (i - 1 - scrollOff) * rowH
            local room     = self.roomList[i]
            local selected = (i == self.selectedIdx) and self.listFocus == 'rooms'
            local inGame   = (room.state == "IN_GAME")

            if selected then
                love.graphics.setColor(1, 0.85, 0, 0.16)
                love.graphics.rectangle('fill', panelX + 14, ry, panelW - 28, rowH - 3)
                love.graphics.setColor(1, 0.85, 0, 0.65)
                love.graphics.rectangle('line', panelX + 14, ry, panelW - 28, rowH - 3)
                love.graphics.setFont(FONT_SMALL)
                love.graphics.setColor(1, 0.85, 0, 1)
                love.graphics.print(">", panelX + 20, ry + rowH/2 - FONT_SMALL:getHeight()/2)
            elseif (i == self.selectedIdx) then
                love.graphics.setColor(1, 1, 1, 0.05)
                love.graphics.rectangle('fill', panelX + 14, ry, panelW - 28, rowH - 3)
            end

            love.graphics.setFont(FONT_SMALL)
            local nameColor = inGame and {1,0.65,0.1} or {1,1,1}
            love.graphics.setColor(nameColor[1], nameColor[2], nameColor[3], 1)
            local lockStr = room.hasPassword and "[P] " or (room.isPublic == false and "[V] " or "    ")
            love.graphics.print(lockStr .. room.name, panelX + 36, ry + rowH/2 - FONT_SMALL:getHeight()/2)

            love.graphics.setColor(0.7, 0.7, 0.7, 0.85)
            local statusStr = inGame and "EN PARTIDA" or "ESPERANDO"
            love.graphics.printf(
                string.format("%d/%d  %s", room.currentPlayers, room.maxPlayers, statusStr),
                panelX, ry + rowH/2 - FONT_SMALL:getHeight()/2, panelW - 26, 'right')
        end
    end
end

function OnlineHubState:_renderCreate()
    local panelW = math.min(700, WINDOW_W - 120)
    local panelX = math.floor((WINDOW_W - panelW) / 2)
    local panelH = 350
    local panelY = math.floor((WINDOW_H - panelH) / 2)

    drawPanel(panelX, panelY, panelW, panelH)

    -- Título y paso
    love.graphics.setFont(FONT_BIG)
    love.graphics.setColor(1, 0.95, 0.15, 1)
    love.graphics.printf('CREAR SALA', 0, panelY + 14, WINDOW_W, 'center')

    local stepLabels = {
        "Nombre de la sala",
        "Visibilidad",
        "Contrasena de la sala",
        "Maximo de jugadores",
    }
    love.graphics.setFont(FONT_SMALL)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.printf("Paso " .. self.createStep .. "/4  —  " .. stepLabels[self.createStep],
        panelX + 20, panelY + 62, panelW - 40, 'center')

    love.graphics.setColor(1, 0.85, 0, 0.25)
    love.graphics.line(panelX + 30, panelY + 82, panelX + panelW - 30, panelY + 82)

    -- Barra de progreso de pasos
    local maxStep = self.createData.isPublic and 3 or 4
    local barW    = panelW - 80
    local barX    = panelX + 40
    local barY    = panelY + 92
    love.graphics.setColor(1, 0.85, 0, 0.15)
    love.graphics.rectangle('fill', barX, barY, barW, 6)
    love.graphics.setColor(1, 0.85, 0, 0.8)
    love.graphics.rectangle('fill', barX, barY, math.floor(barW * (self.createStep-1) / 3), 6)

    local contentY = panelY + 116

    -- Paso 1: Nombre
    if self.createStep == STEP_NAME then
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.printf("Escribe el nombre de la sala y presiona CONFIRMAR",
            panelX + 20, contentY, panelW - 40, 'center')
        drawTextBox(panelX + 40, contentY + 32, panelW - 80, 56, self.inputBuffer, true)
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(1, 1, 1, 0.3)
        love.graphics.printf("max. 28 caracteres", panelX + 40, contentY + 96, panelW - 80, 'right')
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(1,1,1,0.3)
        love.graphics.printf("[ENTER] Confirmar   [ESC] Cancelar", panelX, panelY + panelH - 24, panelW, 'center')

    -- Paso 2: Privacidad (botones navegables)
    elseif self.createStep == STEP_PRIVACY then
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.printf("Elige la visibilidad de la sala",
            panelX + 20, contentY, panelW - 40, 'center')

        local bW  = math.floor((panelW - 100) / 2)
        local bH  = 80
        local bY  = contentY + 36
        local bX1 = panelX + 40
        local bX2 = panelX + 60 + bW

        -- Botón PUBLICA
        local pubSel = (self.privacySel == 1)
        drawBtn('PUBLICA', bX1, bY, bW, bH, pubSel)
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(pubSel and {1,1,1,0.75} or {0,0,0,0.65})
        love.graphics.printf("Aparece en la lista", bX1 + 4, bY + bH - 20, bW - 8, 'center')

        -- Botón PRIVADA
        local privSel = (self.privacySel == 2)
        drawBtn('PRIVADA', bX2, bY, bW, bH, privSel)
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(privSel and {1,1,1,0.75} or {0,0,0,0.65})
        love.graphics.printf("Solo por contrasena", bX2 + 4, bY + bH - 20, bW - 8, 'center')

        -- Instrucción
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(1,1,1,0.4)
        love.graphics.printf("[<][>] Seleccionar   [ENTER] Confirmar   [ESC] Cancelar",
            panelX, panelY + panelH - 24, panelW, 'center')

    -- Paso 3: Contraseña (solo si privada)
    elseif self.createStep == STEP_PASS then
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.printf("Escribe una contrasena (opcional — deja vacio para ninguna)",
            panelX + 20, contentY, panelW - 40, 'center')
        drawTextBox(panelX + 40, contentY + 32, panelW - 80, 56, self.inputBuffer, true)
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(1,1,1,0.3)
        love.graphics.printf("Dejar vacio = sin contrasena", panelX + 40, contentY + 96, panelW - 80, 'left')
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(1,1,1,0.3)
        love.graphics.printf("[ENTER] Confirmar   [ESC] Cancelar", panelX, panelY + panelH - 24, panelW, 'center')

    -- Paso 4: Máximo de jugadores (selector)
    elseif self.createStep == STEP_MAX then
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.printf("Numero maximo de jugadores (1 - 8)",
            panelX + 20, contentY, panelW - 40, 'center')

        -- Selector de número
        local selW  = 80
        local selH  = 80
        local selX  = math.floor((WINDOW_W - selW) / 2)
        local selY  = contentY + 36

        local arrowW = 60
        local arrowH = selH
        local arrowY = selY

        -- Flecha izquierda  [−]
        local lx    = selX - arrowW - 20
        local lhov  = self.hoveredCreateBtn == 1 and Input.lastDevice == 'mouse'
        drawBtn('-', lx, arrowY, arrowW, arrowH, lhov)

        -- Número central
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle('fill', selX + 3, selY + 3, selW, selH)
        love.graphics.setColor(1, 0.95, 0.15, 1)
        love.graphics.rectangle('fill', selX, selY, selW, selH)
        love.graphics.setFont(FONT_BIG)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.printf(tostring(self.maxValue), selX, selY + selH/2 - FONT_BIG:getHeight()/2, selW, 'center')

        -- Flecha derecha  [+]
        local rx   = selX + selW + 20
        local rhov = self.hoveredCreateBtn == 2 and Input.lastDevice == 'mouse'
        drawBtn('+', rx, arrowY, arrowW, arrowH, rhov)

        -- Instrucción
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(1,1,1,0.4)
        love.graphics.printf("[<][>] Cambiar", panelX, selY + selH + 12, panelW, 'center')

        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(1,1,1,0.3)
        love.graphics.printf("[ENTER] Crear sala   [ESC] Cancelar", panelX, panelY + panelH - 24, panelW, 'center')
    end
end

function OnlineHubState:_renderPassword()
    local panelW = math.min(560, WINDOW_W - 120)
    local panelH = 320
    local panelX = math.floor((WINDOW_W - panelW) / 2)
    local panelY = math.floor((WINDOW_H - panelH) / 2)

    drawPanel(panelX, panelY, panelW, panelH)

    love.graphics.setFont(FONT_BIG)
    love.graphics.setColor(1, 0.95, 0.15, 1)
    love.graphics.printf('CONTRASENA', 0, panelY + 14, WINDOW_W, 'center')

    if self.joinRoom then
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(1, 1, 1, 0.55)
        love.graphics.printf('Sala: ' .. self.joinRoom.name, panelX + 20, panelY + 66, panelW - 40, 'center')
    end

    love.graphics.setColor(1, 0.85, 0, 0.2)
    love.graphics.line(panelX + 20, panelY + 88, panelX + panelW - 20, panelY + 88)

    local boxY = panelY + 104
    drawTextBox(panelX + 40, boxY, panelW - 80, 56, self.inputBuffer, true)

    -- Botones UNIRSE y CANCELAR
    local bW  = math.floor((panelW - 100) / 2)
    local bY2 = boxY + 74
    local mouse = Input.lastDevice == 'mouse'
    drawBtn('UNIRSE',   panelX + 40,      bY2, bW, 48, true)
    drawBtn('CANCELAR', panelX + 60 + bW, bY2, bW, 48, self.hoveredPassBtn == 2 and mouse)

    love.graphics.setFont(FONT_SMALL)
    love.graphics.setColor(1,1,1,0.3)
    love.graphics.printf("[ENTER] Unirse   [ESC] Cancelar", panelX, panelY + panelH - 24, panelW, 'center')
end

-- ── Hover del mouse: actualiza las variables de selección reales ──────────────

function OnlineHubState:mousemoved(tx, ty)
    self.hoveredCreateBtn = nil
    self.hoveredPassBtn   = nil

    if self.sub == SUB_LIST then
        local panelX     = math.floor(WINDOW_W * 0.06)
        local panelY     = 44
        local panelW     = WINDOW_W - 2 * panelX
        local panelH     = WINDOW_H - 88
        local rowH       = 46
        local listStartY = panelY + 84
        local btnH       = 48
        local btnGap     = 14
        local nBtns      = #LIST_BTNS
        local btnZoneH   = btnH + 20
        local btnsY      = panelY + panelH - btnZoneH
        local listEndY   = btnsY - 6
        local listH      = listEndY - listStartY
        local btnW       = math.floor((panelW - 80 - (nBtns-1) * btnGap) / nBtns)
        local bx0        = panelX + 40
        local by0        = btnsY + 10

        -- Botones inferiores (CREAR SALA / REFRESCAR / VOLVER)
        for i = 1, nBtns do
            local bx = bx0 + (i-1) * (btnW + btnGap)
            if tx >= bx-8 and tx <= bx+btnW+8 and ty >= by0-8 and ty <= by0+btnH+8 then
                if self.listFocus ~= 'btns' or self.btnSel ~= i then
                    self.listFocus = 'btns'; self.btnSel = i; Sound.play('select')
                end
                return
            end
        end

        -- Filas de salas
        local nr = #self.roomList
        if nr > 0 then
            local maxVisible = math.floor(listH / rowH)
            local scrollOff  = math.max(0, self.selectedIdx - maxVisible)
            for i = scrollOff + 1, math.min(nr, scrollOff + maxVisible) do
                local ry = listStartY + (i - 1 - scrollOff) * rowH
                if tx >= panelX+14 and tx <= panelX+panelW-14 and ty >= ry and ty <= ry+rowH-3 then
                    if self.listFocus ~= 'rooms' or self.selectedIdx ~= i then
                        self.listFocus = 'rooms'; self.selectedIdx = i; Sound.play('select')
                    end
                    return
                end
            end
        end

    elseif self.sub == SUB_CREATE then
        local panelW   = math.min(700, WINDOW_W - 120)
        local panelX   = math.floor((WINDOW_W - panelW) / 2)
        local panelH   = 350
        local panelY   = math.floor((WINDOW_H - panelH) / 2)
        local contentY = panelY + 116

        if self.createStep == STEP_PRIVACY then
            -- Actualiza privacySel (variable de selección real)
            local bW  = math.floor((panelW - 100) / 2)
            local bH  = 80
            local bY  = contentY + 36
            local bX1 = panelX + 40
            local bX2 = panelX + 60 + bW
            if tx >= bX1-8 and tx <= bX1+bW+8 and ty >= bY-8 and ty <= bY+bH+8 then
                if self.privacySel ~= 1 then self.privacySel = 1; Sound.play('select') end
            elseif tx >= bX2-8 and tx <= bX2+bW+8 and ty >= bY-8 and ty <= bY+bH+8 then
                if self.privacySel ~= 2 then self.privacySel = 2; Sound.play('select') end
            end
        elseif self.createStep == STEP_MAX then
            -- Botones +/- sin variable de selección: solo hover visual
            local selW   = 80; local selH = 80
            local selX   = math.floor((WINDOW_W - selW) / 2)
            local selY   = contentY + 36
            local arrowW = 60
            local lArX   = selX - arrowW - 20
            local rArX   = selX + selW + 20
            local prev   = self.hoveredCreateBtn
            if tx >= lArX-8 and tx <= lArX+arrowW+8 and ty >= selY-8 and ty <= selY+selH+8 then
                self.hoveredCreateBtn = 1
            elseif tx >= rArX-8 and tx <= rArX+arrowW+8 and ty >= selY-8 and ty <= selY+selH+8 then
                self.hoveredCreateBtn = 2
            end
            if self.hoveredCreateBtn and self.hoveredCreateBtn ~= prev then Sound.play('select') end
        end

    elseif self.sub == SUB_PASSWORD then
        -- CANCELAR no tiene variable de selección (UNIRSE siempre está "selected")
        local panelW = math.min(560, WINDOW_W - 120)
        local panelH = 320
        local panelX = math.floor((WINDOW_W - panelW) / 2)
        local panelY = math.floor((WINDOW_H - panelH) / 2)
        local boxY   = panelY + 104
        local bW     = math.floor((panelW - 100) / 2)
        local bY2    = boxY + 74
        local prev   = self.hoveredPassBtn
        if tx >= panelX+60+bW-8 and tx <= panelX+60+2*bW+8 and ty >= bY2-8 and ty <= bY2+48+8 then
            self.hoveredPassBtn = 2
        end
        if self.hoveredPassBtn and self.hoveredPassBtn ~= prev then Sound.play('select') end
    end
end

-- ── Exit ──────────────────────────────────────────────────────────────────────

function OnlineHubState:exit()
    love.keyboard.setTextInput(false)
    self._keyboardOn = false
end

-- ── Touch ─────────────────────────────────────────────────────────────────────

function OnlineHubState:touchpressed(id, tx, ty)
    if self.sub == SUB_WAITING then return end

    -- ── SUB_LIST ─────────────────────────────────────────────────────────────
    if self.sub == SUB_LIST then
        local panelX   = math.floor(WINDOW_W * 0.06)
        local panelY   = 44
        local panelW   = WINDOW_W - 2 * panelX
        local panelH   = WINDOW_H - 88
        local rowH     = 46
        local listStartY = panelY + 84
        local btnH     = 48
        local btnGap   = 14
        local nBtns    = #LIST_BTNS
        local btnZoneH = btnH + 20
        local btnsY    = panelY + panelH - btnZoneH
        local listEndY = btnsY - 6
        local listH    = listEndY - listStartY
        local btnW     = math.floor((panelW - 80 - (nBtns-1) * btnGap) / nBtns)
        local bx0      = panelX + 40
        local by0      = btnsY + 10

        -- Botones de acción inferiores (CREAR SALA / REFRESCAR / VOLVER)
        for i = 1, nBtns do
            local bx = bx0 + (i-1) * (btnW + btnGap)
            if tx >= bx - 8 and tx <= bx + btnW + 8 and
               ty >= by0 - 8 and ty <= by0 + btnH + 8 then
                Sound.play('select')
                if i == BTN_CREATE then
                    self:_resetCreate(); self.sub = SUB_CREATE
                    self:_syncKeyboard()
                elseif i == BTN_REFRESH then
                    NC:send("get_rooms", {})
                elseif i == BTN_BACK then
                    NC:disconnect(); gStateMachine:change('online_login')
                end
                return
            end
        end

        -- Lista de salas (con scroll igual que en render)
        local nr = #self.roomList
        if nr > 0 then
            local maxVisible = math.floor(listH / rowH)
            local scrollOff  = math.max(0, self.selectedIdx - maxVisible)
            for i = scrollOff + 1, math.min(nr, scrollOff + maxVisible) do
                local ry = listStartY + (i - 1 - scrollOff) * rowH
                if tx >= panelX + 14 and tx <= panelX + panelW - 14 and
                   ty >= ry          and ty <= ry + rowH - 3 then
                    Sound.play('select')
                    self:_joinRoom(self.roomList[i])
                    self:_syncKeyboard()
                    return
                end
            end
        end
        return
    end

    -- ── SUB_CREATE ────────────────────────────────────────────────────────────
    if self.sub == SUB_CREATE then
        local panelW   = math.min(700, WINDOW_W - 120)
        local panelX   = math.floor((WINDOW_W - panelW) / 2)
        local panelH   = 350
        local panelY   = math.floor((WINDOW_H - panelH) / 2)
        local contentY = panelY + 116

        -- Paso 1: Nombre
        if self.createStep == STEP_NAME then
            local tbX = panelX + 40;  local tbY = contentY + 32
            local tbW = panelW - 80;  local tbH = 56
            -- Toque en el cuadro de texto → abrir teclado
            if tx >= tbX and tx <= tbX + tbW and ty >= tbY and ty <= tbY + tbH then
                love.keyboard.setTextInput(true); self._keyboardOn = true
                return
            end
            -- Toque en el resto del panel → confirmar nombre
            if tx >= panelX and tx <= panelX + panelW and
               ty >= panelY and ty <= panelY + panelH then
                if #self.inputBuffer > 0 then
                    self.createData.name = self.inputBuffer
                    self.inputBuffer     = ""
                    self.createStep      = STEP_PRIVACY
                    Sound.play('select')
                    self:_syncKeyboard()
                else
                    self:_showError("El nombre no puede estar vacío.")
                end
            end

        -- Paso 2: Privacidad (seleccionar + confirmar con un solo toque)
        elseif self.createStep == STEP_PRIVACY then
            local bW  = math.floor((panelW - 100) / 2)
            local bH  = 80
            local bY  = contentY + 36
            local bX1 = panelX + 40
            local bX2 = panelX + 60 + bW

            if tx >= bX1 - 8 and tx <= bX1 + bW + 8 and
               ty >= bY  - 8 and ty <= bY  + bH + 8 then
                -- PUBLICA seleccionada y confirmada
                self.privacySel          = 1
                self.createData.isPublic = true
                self.createData.password = ""
                self.createStep          = STEP_MAX
                Sound.play('select')
                self:_syncKeyboard()
                return
            end
            if tx >= bX2 - 8 and tx <= bX2 + bW + 8 and
               ty >= bY  - 8 and ty <= bY  + bH + 8 then
                -- PRIVADA seleccionada y confirmada
                self.privacySel          = 2
                self.createData.isPublic = false
                self.inputBuffer         = ""
                self.createStep          = STEP_PASS
                Sound.play('select')
                self:_syncKeyboard()
                return
            end

        -- Paso 3: Contraseña
        elseif self.createStep == STEP_PASS then
            local tbX = panelX + 40;  local tbY = contentY + 32
            local tbW = panelW - 80;  local tbH = 56
            if tx >= tbX and tx <= tbX + tbW and ty >= tbY and ty <= tbY + tbH then
                love.keyboard.setTextInput(true); self._keyboardOn = true
                return
            end
            if tx >= panelX and tx <= panelX + panelW and
               ty >= panelY and ty <= panelY + panelH then
                self.createData.password = self.inputBuffer
                self.inputBuffer         = ""
                self.createStep          = STEP_MAX
                Sound.play('select')
                self:_syncKeyboard()
            end

        -- Paso 4: Máximo de jugadores
        elseif self.createStep == STEP_MAX then
            local selW   = 80
            local selH   = 80
            local selX   = math.floor((WINDOW_W - selW) / 2)
            local selY   = contentY + 36
            local arrowW = 60
            local lArX   = selX - arrowW - 20   -- botón [−]
            local rArX   = selX + selW + 20     -- botón [+]

            -- Botón [−]
            if tx >= lArX - 8 and tx <= lArX + arrowW + 8 and
               ty >= selY - 8 and ty <= selY + selH   + 8 then
                self.maxValue = math.max(2, self.maxValue - 1)
                Sound.play('select')
                return
            end
            -- Botón [+]
            if tx >= rArX - 8 and tx <= rArX + arrowW + 8 and
               ty >= selY - 8 and ty <= selY + selH   + 8 then
                self.maxValue = math.min(8, self.maxValue + 1)
                Sound.play('select')
                return
            end
            -- Toque en el número central o resto del panel → confirmar y crear sala
            if tx >= panelX and tx <= panelX + panelW and
               ty >= panelY and ty <= panelY + panelH then
                self.createData.maxPlayers = self.maxValue
                NC:send("create_room", self.createData)
                self:_resetCreate()
                self.sub       = SUB_WAITING
                self.waitTimer = 0
                Sound.play('select')
                self:_syncKeyboard()
            end
        end
        return
    end

    -- ── SUB_PASSWORD ──────────────────────────────────────────────────────────
    if self.sub == SUB_PASSWORD then
        local panelW = math.min(560, WINDOW_W - 120)
        local panelH = 320
        local panelX = math.floor((WINDOW_W - panelW) / 2)
        local panelY = math.floor((WINDOW_H - panelH) / 2)
        local boxY   = panelY + 104
        local bW     = math.floor((panelW - 100) / 2)
        local bY2    = boxY + 74

        -- Campo de texto → abrir teclado
        if tx >= panelX + 40 and tx <= panelX + panelW - 40 and
           ty >= boxY         and ty <= boxY + 56 then
            love.keyboard.setTextInput(true); self._keyboardOn = true
            return
        end

        -- Botón UNIRSE
        if tx >= panelX + 40 - 8          and tx <= panelX + 40 + bW + 8 and
           ty >= bY2  - 8                 and ty <= bY2 + 48 + 8 then
            if self.joinRoom then
                NC:send("join_room", { id=self.joinRoom.id, password=self.inputBuffer })
                self.inputBuffer = ""; self.joinRoom = nil
                self.sub = SUB_WAITING; self.waitTimer = 0
                Sound.play('select')
                self:_syncKeyboard()
            end
            return
        end

        -- Botón CANCELAR
        if tx >= panelX + 60 + bW - 8     and tx <= panelX + 60 + 2*bW + 8 and
           ty >= bY2  - 8                 and ty <= bY2 + 48 + 8 then
            self.sub = SUB_LIST; self.inputBuffer = ""; self.joinRoom = nil
            self:_syncKeyboard()
            return
        end
    end
end

return OnlineHubState
