-- src/states/online/OnlineLoginState.lua
-- Pantalla de login: ingresa nickname, host y puerto antes de conectar.

local BaseState        = require 'src/core/BaseState'
local MenuScene = require 'src/ui/menu/MenuScene'
local NameFilter = require 'src/network/NameFilter'
local NC               = require 'src/network/NetworkClient'
local Protocol         = require 'src/network/Protocol'
local Lang = require 'src/core/Lang'
local MenuAnim   = require 'src/ui/menu/MenuAnim'
local MenuButton = require 'src/ui/menu/MenuButton'
local MenuKit    = require 'src/ui/menu/MenuKit'
local OnlineLoginState = BaseState:new()

-- Campos del formulario (HOST y PORT fijos, solo se muestra NOMBRE)
local FIELD_NICK   = 1
local FIELD_LABELS = { 'login.name' }   -- claves de idioma

local FIXED_HOST = SERVER_HOST     -- (settings.lua)
local FIXED_PORT = SERVER_PORT

-- ── Enter ─────────────────────────────────────────────────────────────────────

function OnlineLoginState:enter(args)

    self.fields = {
        -- (el último nombre con el que se entró, guardado en las opciones: ya no hay que escribirlo cada vez)
        [FIELD_NICK] = (NC.myName and NC.myName ~= '' and NC.myName) or require('src/core/Settings').onlineName or "",
    }
    self.activeField = FIELD_NICK
    self.connecting  = false
    self.anim, self.t = MenuAnim.new(), 0
    self.btnIndex = 1

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
        require('src/core/Settings').setOnlineName((self.fields[FIELD_NICK] or ''):match('^%s*(.-)%s*$'))
        gStateMachine:change('online_hub')
    end)
    NC:on("connection_lost", function(data)
        self.connecting = false
        gStateMachine:change('online_error', {
            code = "ERR_SERVER_UNREACHABLE",
            msg  = data.msg or Lang('err.unreachable'),
        })
    end)
    NC:on("room_error", function(data)
        self.connecting = false
        self:_showError(Lang.fromServer(data, 'err.unknown'))
    end)
    -- Rechazo del handshake (versión incompatible, nombre en uso o inválido)
    NC:on("login_error", function(data)
        self.connecting = false
        -- Versión incompatible: intentar actualizar el juego (y volver aquí)
        if type(data) == 'table' and data.key == 'srv.version' and UPDATE_ENABLED and not UPDATE_TRIED then
            UPDATE_TRIED = true                  -- (una vez por sesión: sin bucles)
            gStateMachine:change('update', { after = 'online_login' })
            return
        end
        self:_showError(Lang.fromServer(data, 'login.failed'))
    end)
end

function OnlineLoginState:_showError(msg)
    Notify.toast(msg, 'error')
end

-- ── textinput (forwarded desde main.lua) ─────────────────────────────────────

function OnlineLoginState:textinput(t)
    if self.connecting then return end
    -- (solo los caracteres que puede llevar un nombre, y hasta su largo máximo: src/network/NameFilter.lua)
    local cur = self.fields[FIELD_NICK] or ""
    self.fields[FIELD_NICK] = (cur .. NameFilter.typed(t)):sub(1, NameFilter.MAX)
end

-- ── keypressed (forwarded desde main.lua) ────────────────────────────────────

function OnlineLoginState:keypressed(k)
    if k == "backspace" then
        local cur = self.fields[self.activeField] or ""
        if #cur > 0 then
            self.fields[self.activeField] = cur:sub(1, -2)
        end
    elseif k == "kpenter" then                -- (Enter y Esc normales ya son `confirm` / `back`, en update)
        self:_tryConnect()
    end
end

-- ── Update ────────────────────────────────────────────────────────────────────

function OnlineLoginState:update(dt)
    MenuScene.update(dt)
    self.anim:update(dt)
    self.t = self.t + dt
    if self.anim:busy() then return end

    if Input.pressed('nav_left') or Input.pressed('nav_right') then
        self.btnIndex = self.btnIndex == 1 and 2 or 1
        self.t = 0
        Sound.play('select', 1.04)
    end

    -- (solo con MANDO: X / Y borra una letra — no había forma sin teclado)
    if Input.usingPad() and Input.pressed('light') then self:keypressed('backspace') end
    if Input.pressed('confirm') then
        if self.btnIndex == 1 then self:_tryConnect() else self:_back() end
    end
    if Input.pressed('back') then self:_back() end
end

function OnlineLoginState:_tryConnect()
    if self.connecting then return end
    if NC:isConnected() then gStateMachine:change('online_hub'); return end

    local nick = (self.fields[FIELD_NICK] or ""):match("^%s*(.-)%s*$")

    if #nick == 0 then
        self:_showError(Lang('login.enter_name'))
        love.keyboard.setTextInput(true)          -- (vuelve a abrir el teclado: en la Switch, si se cerró, no había otra)
        return
    end
    -- antes de enviarlo: largo, caracteres y palabras no permitidas (el servidor lo vuelve a comprobar)
    local okName, why = NameFilter.check(nick)
    if not okName then
        self:_showError(Lang('login.name_' .. why))
        return
    end

    self.connecting = true
    NC:connect(FIXED_HOST, FIXED_PORT, nick)
end

-- ── Geometría (compartida por render, ratón y táctil) ────────────────────────

local function layout()
    local w = math.min(640, WINDOW_W - 160)
    local x = math.floor((WINDOW_W - w) / 2)
    local y = math.floor(WINDOW_H * 0.30)
    local L = { card = { x = x, y = y, w = w, h = 196 } }
    L.field = { x = x + 32, y = y + 72, w = w - 64, h = 64 }
    local bw, bh, gap = math.floor((w - 72) / 2), 60, 72
    local by = y + L.card.h + 28
    L.buttons = {
        { id = 'connect', label = 'login.connect', color = 'green', x = x,            y = by, w = bw, h = bh },
        { id = 'back',    label = 'common.back',   color = 'grey',  x = x + bw + gap, y = by, w = bw, h = bh },
    }
    return L
end

local function inRect(r, x, y, pad)
    pad = pad or 0
    return x >= r.x - pad and x <= r.x + r.w + pad and y >= r.y - pad and y <= r.y + r.h + pad
end

function OnlineLoginState:_back()
    NC:disconnect()
    if self.anim:busy() then return end
    self.anim:leave(function() gStateMachine:change('adv_mode_select') end)
end

-- ── Render ────────────────────────────────────────────────────────────────────

function OnlineLoginState:render()
    MenuScene.backdrop()                 -- (el fondo vivo de los menús: src/ui/menu/MenuScene)
    local A = self.anim
    MenuKit.title(Lang('login.title'), 'purple', A, 1)

    local L = layout()
    local c = L.card
    local ox, oy, a = A:slide(2, 0, 220)
    MenuKit.box('card', c.x + ox, c.y + oy, c.w, c.h, a)
    MenuKit.section(Lang(FIELD_LABELS[FIELD_NICK]), c.x + 32 + ox, c.y + 26 + oy, c.w - 64, true, a)
    local f = L.field
    MenuKit.field(f.x + ox, f.y + oy, f.w, f.h, self.fields[FIELD_NICK] or "", not self.connecting, { alpha = a })
    -- estado de la conexión (o las reglas del nombre)
    local dots = string.rep('.', math.floor(love.timer.getTime() * 3) % 4)
    local msg = self.connecting and (Lang('login.connecting'):gsub('%.+$', '') .. dots) or Lang('login.name_chars')
    MenuKit.text(FONT_SMALL, msg, c.x + ox, f.y + f.h + 22 + oy, c.w, 'center',
                 self.connecting and { 1, 0.86, 0.36 } or { 0.7, 0.76, 0.92 }, a)

    -- Botones (mando, ratón y táctil)
    for i, b in ipairs(L.buttons) do
        local bx, by, ba = A:slide(2 + i, 0, 220)
        local sel = self.btnIndex == i
        local bob = sel and ((math.floor(self.t * 3) % 2 == 0) and -4 or 0) or 0
        local dis = self.connecting and b.id == 'connect'
        -- (la acción principal, un punto más grande que VOLVER)
        local txt = Lang(b.label)
        MenuButton.draw(txt, b.x + bx, b.y + by + bob, b.w, b.h, dis and 'grey' or b.color, sel and not dis,
                        { alpha = ba * (dis and 0.7 or 1), scale = MenuButton.textScale(txt, b.w - 48, b.id == 'connect' and 5 or 4) })
        if sel then MenuKit.marker(b.x + bx, b.y + by + bob, b.w, b.h, self.t, ba) end
    end
    MenuKit.hint(Lang('login.hint'), A, 5)
    love.graphics.setColor(COLOR_WHITE)
end

-- ── Exit ──────────────────────────────────────────────────────────────────────

function OnlineLoginState:exit()
    love.keyboard.setTextInput(false)
end

-- ── Touch ─────────────────────────────────────────────────────────────────────

function OnlineLoginState:mousemoved(tx, ty)
    for i, b in ipairs(layout().buttons) do
        if inRect(b, tx, ty, 4) and self.btnIndex ~= i then self.btnIndex, self.t = i, 0; Sound.play('select') end
    end
end

function OnlineLoginState:touchpressed(id, tx, ty)
    local L = layout()
    for _, b in ipairs(L.buttons) do
        if inRect(b, tx, ty, 6) then
            Sound.play('select')
            if b.id == 'back' then self:_back() else self:_tryConnect() end
            return
        end
    end
    if self.connecting then return end
    -- Toque sobre el campo de texto → mostrar teclado (móvil)
    if inRect(L.field, tx, ty) then love.keyboard.setTextInput(true) end
end

return OnlineLoginState
