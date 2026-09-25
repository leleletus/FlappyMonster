-- src/states/OnlineLoginState.lua
-- Pantalla de login: ingresa nickname, host y puerto antes de conectar.

local BaseState        = require 'src/BaseState'
local NC               = require 'src/network/NetworkClient'
local Protocol         = require 'src/network/Protocol'
local OnlineLoginState = BaseState:new()

local imgBg = nil
local function loadAssets()
    if imgBg then return end
    imgBg = love.graphics.newImage('assets/images/menus/MenuDif.png')
end

-- Campos del formulario (HOST y PORT fijos, solo se muestra NOMBRE)
local FIELD_NICK   = 1
local FIELD_LABELS = { "NOMBRE" }

local FIXED_HOST = "djvemo.net.pe"
local FIXED_PORT = 22122

-- ── Enter ─────────────────────────────────────────────────────────────────────

function OnlineLoginState:enter(args)
    loadAssets()

    self.fields = {
        [FIELD_NICK] = NC.myName or "",
    }
    self.activeField = FIELD_NICK
    self.errorMsg    = ""
    self.errorTimer  = 0
    self.connecting  = false

    -- Si ya estamos conectados, ir directo al hub
    if NC:isConnected() then
        gStateMachine:change('online_hub')
        return
    end

    -- En móvil / Android: abrir teclado virtual al entrar (hay un único campo de texto)
    love.keyboard.setTextInput(true)

    -- Handlers de red
    NC:on("login_success", function(data)
        self.connecting = false
        gStateMachine:change('online_hub')
    end)
    NC:on("connection_lost", function(data)
        self.connecting = false
        gStateMachine:change('online_error', {
            code = "ERR_SERVER_UNREACHABLE",
            msg  = data.msg or "No se pudo establecer conexion con el servidor.",
        })
    end)
    NC:on("room_error", function(data)
        self.connecting = false
        self:_showError(data.msg or "Error desconocido")
    end)
    -- Rechazo del handshake (versión incompatible, nombre en uso o inválido)
    NC:on("login_error", function(data)
        self.connecting = false
        self:_showError(data and data.msg or "No se pudo iniciar sesion.")
    end)
end

function OnlineLoginState:_showError(msg)
    self.errorMsg   = msg
    self.errorTimer = 4
end

-- ── textinput (forwarded desde main.lua) ─────────────────────────────────────

function OnlineLoginState:textinput(t)
    if self.connecting then return end
    local cur = self.fields[FIELD_NICK] or ""
    if #cur >= Protocol.NAME_MAX then return end
    self.fields[FIELD_NICK] = cur .. t
end

-- ── keypressed (forwarded desde main.lua) ────────────────────────────────────

function OnlineLoginState:keypressed(k)
    if k == "backspace" then
        local cur = self.fields[self.activeField] or ""
        if #cur > 0 then
            self.fields[self.activeField] = cur:sub(1, -2)
        end
    elseif k == "return" or k == "kpenter" then
        self:_tryConnect()
    elseif k == "escape" then
        NC:disconnect()
        gStateMachine:change('adv_mode_select')
    end
end

-- ── Update ────────────────────────────────────────────────────────────────────

function OnlineLoginState:update(dt)
    if self.errorTimer > 0 then
        self.errorTimer = self.errorTimer - dt
        if self.errorTimer <= 0 then self.errorMsg = "" end
    end

    -- Solo hay un campo, no hay navegación entre campos

    if Input.pressed('confirm') then
        self:_tryConnect()
    end
    if Input.pressed('back') then
        NC:disconnect()
        gStateMachine:change('adv_mode_select')
    end
end

function OnlineLoginState:_tryConnect()
    if self.connecting then return end
    if NC:isConnected() then gStateMachine:change('online_hub'); return end

    local nick = (self.fields[FIELD_NICK] or ""):match("^%s*(.-)%s*$")

    if #nick == 0 then
        self:_showError("Ingresa un nombre de jugador.")
        return
    end

    self.connecting = true
    self.errorMsg   = ""
    NC:connect(FIXED_HOST, FIXED_PORT, nick)
end

-- ── Render ────────────────────────────────────────────────────────────────────

function OnlineLoginState:render()
    local bx = WINDOW_W / imgBg:getWidth()
    local by = WINDOW_H / imgBg:getHeight()
    love.graphics.setColor(COLOR_WHITE)
    love.graphics.draw(imgBg, 0, 0, 0, bx, by)

    -- Título
    love.graphics.setFont(FONT_BIG)
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.printf('ONLINE', 2, 162, WINDOW_W, 'center')
    love.graphics.setColor(1, 0.95, 0.15, 1)
    love.graphics.printf('ONLINE', 0, 160, WINDOW_W, 'center')

    -- Panel central
    local panelW = 600
    local panelH = 160
    local panelX = math.floor((WINDOW_W - panelW) / 2)
    local panelY = math.floor(WINDOW_H / 2 - panelH / 2 + 20)

    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle('fill', panelX, panelY, panelW, panelH)
    love.graphics.setColor(1, 0.85, 0, 0.55)
    love.graphics.rectangle('line', panelX, panelY, panelW, panelH)
    love.graphics.rectangle('line', panelX+2, panelY+2, panelW-4, panelH-4)

    -- Campo NOMBRE (único)
    local fieldH  = 52
    local labelW  = 120
    local inputX  = panelX + labelW + 30
    local inputW  = panelW - labelW - 60
    local fy      = panelY + 30
    local val     = self.fields[FIELD_NICK] or ""
    local display = val .. "_"

    love.graphics.setFont(FONT_SMALL)
    love.graphics.setColor(1, 0.85, 0, 0.9)
    love.graphics.print(FIELD_LABELS[FIELD_NICK], panelX + 20, fy + fieldH/2 - FONT_SMALL:getHeight()/2)

    love.graphics.setColor(1, 1, 1, 0.15)
    love.graphics.rectangle('fill', inputX, fy, inputW, fieldH)
    love.graphics.setColor(1, 0.85, 0, 0.9)
    love.graphics.rectangle('line', inputX, fy, inputW, fieldH)

    love.graphics.setFont(FONT_MED)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(display, inputX + 10, fy + fieldH/2 - FONT_MED:getHeight()/2, inputW - 20, 'left')

    -- Hint / estado de conexión
    local hintY = panelY + panelH - 44
    love.graphics.setFont(FONT_SMALL)
    if self.connecting then
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.printf('CONECTANDO...', 0, hintY, WINDOW_W, 'center')
    else
        love.graphics.setColor(1, 1, 1, 0.35)
        love.graphics.printf('[ENTER] conectar   [ESC] volver',
            0, hintY, WINDOW_W, 'center')
    end

    -- Error
    if self.errorMsg ~= "" then
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(1, 0.25, 0.25, 1)
        love.graphics.printf(self.errorMsg, 0, panelY + panelH + 16, WINDOW_W, 'center')
    end

    love.graphics.setColor(COLOR_WHITE)
end

-- ── Exit ──────────────────────────────────────────────────────────────────────

function OnlineLoginState:exit()
    love.keyboard.setTextInput(false)
end

-- ── Touch ─────────────────────────────────────────────────────────────────────

function OnlineLoginState:touchpressed(id, tx, ty)
    if self.connecting then return end

    -- Calcular área del campo de texto (igual que en render)
    local panelW  = 600
    local panelH  = 160
    local panelX  = math.floor((WINDOW_W - panelW) / 2)
    local panelY  = math.floor(WINDOW_H / 2 - panelH / 2 + 20)
    local fieldH  = 52
    local labelW  = 120
    local inputX  = panelX + labelW + 30
    local inputW  = panelW - labelW - 60
    local fy      = panelY + 30

    -- Toque sobre el campo de texto → mostrar teclado Android (no conectar)
    if tx >= inputX and tx <= inputX + inputW and
       ty >= fy     and ty <= fy + fieldH then
        love.keyboard.setTextInput(true)
        return
    end

    -- Toque en cualquier otra parte → intentar conectar
    self:_tryConnect()
end

return OnlineLoginState
