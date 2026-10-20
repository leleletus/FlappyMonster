-- src/states/online/OnlineHubState.lua
-- Hub de salas: lista de salas, crear sala y unirse.
-- Toda la navegación con flechas/gamepad — sin atajos de teclado directos.

local BaseState      = require 'src/core/BaseState'
local MenuScene = require 'src/ui/menu/MenuScene'
local NC             = require 'src/network/NetworkClient'
local L = require 'src/core/Lang'
local MenuAnim       = require 'src/ui/menu/MenuAnim'
local MenuButton     = require 'src/ui/menu/MenuButton'
local MenuKit        = require 'src/ui/menu/MenuKit'
local PixelFont      = require 'src/ui/PixelFont'
local PixelIcons     = require 'src/ui/PixelIcons'
local fitText        = require('src/ui/TextUtil').fit
local OnlineHubState = BaseState:new()

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
local LIST_BTNS   = { 'hub.create', 'hub.refresh', 'common.back' }   -- claves de idioma

-- ── Enter ─────────────────────────────────────────────────────────────────────

function OnlineHubState:enter(args)
    Sound.playMusic('menus')      -- (si ya sonaba, sigue sin cortarse)
    self.sub          = SUB_LIST
    self.anim, self.winAnim, self.t = MenuAnim.new(), MenuAnim.new(), 0
    self.roomList     = {}
    self.selectedIdx  = 1
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
        data = type(data) == 'table' and data or {}
        if data.kind == 'banned' then
            Notify.modal(L('hub.banned_title'), L.fromServer(data, 'hub.banned'), {
                kind = 'ban', subtitle = data.room and L('hub.room_label', { name = data.room }) or nil })
        else
            Notify.toast(L.fromServer(data, 'hub.error'), 'error')
        end
        if self.sub == SUB_PASSWORD or self.sub == SUB_WAITING then
            self:_setSub(SUB_LIST); self.inputBuffer = ""
        end
    end)
    NC:on("connection_lost", function(data)
        gStateMachine:change('online_error', {
            code = "ERR_CONNECTION_LOST",
            msg  = data.msg or L('err.lost'),
        })
    end)
end

-- Cambia de sub-pantalla (las ventanas entran con su animación)
function OnlineHubState:_setSub(sub)
    if sub ~= self.sub and sub ~= SUB_LIST then self.winAnim = MenuAnim.new() end
    self.sub, self.t = sub, 0
end

-- Vuelve al login (desconecta)
function OnlineHubState:_leave()
    if self.anim:busy() then return end
    NC:disconnect()
    self.anim:leave(function() gStateMachine:change('online_login') end)
end

function OnlineHubState:_sendPassword()
    if not self.joinRoom then return end
    NC:send("join_room", { id = self.joinRoom.id, password = self.inputBuffer })
    self.inputBuffer = ""; self.joinRoom = nil
    self:_setSub(SUB_WAITING); self.waitTimer = 0
    Sound.play('select')
    self:_syncKeyboard()
end

function OnlineHubState:_showError(msg)
    Notify.toast(msg, 'error')
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
    self.hoveredCreateNav = nil   -- botón de abajo con el foco (1 CANCELAR, 2 SIGUIENTE/CREAR) o nil: lo del paso
end

function OnlineHubState:_joinRoom(room)
    if room.hasPassword then
        self.joinRoom    = room
        self.inputBuffer = ""
        self:_setSub(SUB_PASSWORD)
    else
        NC:send("join_room", { id=room.id, password="" })
        self:_setSub(SUB_WAITING); self.waitTimer = 0
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
    MenuScene.update(dt)
    self.anim:update(dt); self.winAnim:update(dt)
    self.t = self.t + dt
    if self.anim:busy() then return end

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
                msg  = L('err.timeout'),
            })
            return
        end
        if Input.pressed('back') then
            self:_setSub(SUB_LIST)
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
                self:_leave()
            end

        elseif self.listFocus == 'btns' then
            if Input.pressed('nav_left') then
                self.btnSel = self.btnSel - 1
                if self.btnSel < 1 then self.btnSel = #LIST_BTNS end
                self.t = 0; Sound.play('select')
            end
            if Input.pressed('nav_right') then
                self.btnSel = self.btnSel + 1
                if self.btnSel > #LIST_BTNS then self.btnSel = 1 end
                self.t = 0; Sound.play('select')
            end
            if Input.pressed('nav_up') then
                -- volver a lista de salas
                self.listFocus   = 'rooms'
                self.selectedIdx = math.max(1, nr)
                Sound.play('select')
            end
            if Input.pressed('confirm') then
                Sound.play('select')
                self:_listButton(self.btnSel)
            end
            if Input.pressed('back') then
                self:_leave()
            end
        end

    -- ── SUB_CREATE ────────────────────────────────────────────────────────────
    elseif self.sub == SUB_CREATE then
        if Input.pressed('back') then
            self:_createCancel(); return
        end
        if Input.usingPad() and Input.pressed('light') then self:keypressed('backspace') end   -- (X / Y: borrar)
        -- Teclado / mando: arriba, lo del paso (◀ ▶ eligen o cambian; confirmar avanza); ABAJO baja a los botones
        -- CANCELAR / SIGUIENTE (◀ ▶ entre ellos, confirmar pulsa el elegido, ARRIBA vuelve). Antes el mando no llegaba
        -- a CANCELAR y en el número de jugadores arriba restaba y abajo sumaba.
        local nNav = (self.createStep == STEP_PRIVACY) and 1 or 2
        local nav = self.hoveredCreateNav
        if nav then
            local to = nav
            if Input.pressed('nav_left') then to = math.max(1, nav - 1) end
            if Input.pressed('nav_right') then to = math.min(nNav, nav + 1) end
            if Input.pressed('nav_up') then to = nil end
            if to ~= nav then self.hoveredCreateNav, self.t = to, 0; Sound.play('select')
            elseif Input.pressed('confirm') then
                if nav == 1 then Sound.play('select'); self:_createCancel() else self:_createNext() end
            end
        else
            if self.createStep == STEP_PRIVACY then
                if Input.pressed('nav_left') and self.privacySel ~= 1 then self.privacySel, self.t = 1, 0; Sound.play('select') end
                if Input.pressed('nav_right') and self.privacySel ~= 2 then self.privacySel, self.t = 2, 0; Sound.play('select') end
            elseif self.createStep == STEP_MAX then
                if Input.pressed('nav_left') then self:_stepMax(-1) end
                if Input.pressed('nav_right') then self:_stepMax(1) end
            end
            if Input.pressed('nav_down') then self.hoveredCreateNav, self.t = nNav, 0; Sound.play('select')
            elseif Input.pressed('confirm') then self:_createNext() end
        end

    -- ── SUB_PASSWORD ──────────────────────────────────────────────────────────
    elseif self.sub == SUB_PASSWORD then
        if Input.usingPad() and Input.pressed('light') then self:keypressed('backspace') end
        if Input.pressed('confirm') then self:_sendPassword() end
        if Input.pressed('back') then
            self:_setSub(SUB_LIST); self.inputBuffer = ""; self.joinRoom = nil
        end
    end

    -- Sincronizar teclado Android tras cualquier cambio de sub-estado o paso
    self:_syncKeyboard()
end

-- ── Crear sala: avanzar / cancelar (teclado, ratón y táctil) ────────────────

-- Máximo de jugadores: -1 / +1 (de 2 a 8); el botón pulsado se hunde un momento
function OnlineHubState:_stepMax(d)
    local v = math.max(2, math.min(8, self.maxValue + d))
    if v ~= self.maxValue then self.maxValue = v; Sound.play('select', d > 0 and 1.08 or 0.94) end
    self.stepPush, self.t = d, 0
end

function OnlineHubState:_createCancel()
    self:_setSub(SUB_LIST); self:_resetCreate()
    self:_syncKeyboard()
end

function OnlineHubState:_createNext()
    local step = self.createStep
    self.hoveredCreateNav = nil                   -- (cada paso empieza con el foco en lo suyo)
    if step == STEP_NAME then
        if #self.inputBuffer == 0 then
            love.keyboard.setTextInput(true); self._keyboardOn = true     -- (vuelve a abrir el teclado)
            self:_showError(L('hub.name_empty')); return
        end
        self.createData.name = self.inputBuffer
        self.inputBuffer     = ""
        self.createStep      = STEP_PRIVACY
    elseif step == STEP_PRIVACY then
        self.createData.isPublic = (self.privacySel == 1)
        if self.privacySel == 2 then
            self.inputBuffer = ""
            self.createStep  = STEP_PASS
        else
            self.createData.password = ""
            self.createStep          = STEP_MAX
        end
    elseif step == STEP_PASS then
        self.createData.password = self.inputBuffer
        self.inputBuffer         = ""
        self.createStep          = STEP_MAX
    elseif step == STEP_MAX then
        self.createData.maxPlayers = self.maxValue
        NC:send("create_room", self.createData)
        self:_resetCreate()
        self:_setSub(SUB_WAITING); self.waitTimer = 0
    end
    Sound.play('select')
    self:_syncKeyboard()
end

-- ── Layout (ÚNICA fuente de geometría: render, ratón y táctil) ───────────────

local ROW_H, ROW_GAP = 60, 8
local BTN_H = 56

function OnlineHubState:_layout()
    local L = {}
    local mx = math.max(40, math.floor(WINDOW_W * 0.07))
    L.list = { x = mx, y = 168, w = WINDOW_W - 2 * mx, h = WINDOW_H - 168 - BTN_H - 92 }
    L.rows = {}
    local y0 = L.list.y + 16
    L.maxVisible = math.max(1, math.floor((L.list.h - 32 + ROW_GAP) / (ROW_H + ROW_GAP)))
    L.scroll = math.max(0, math.min(self.selectedIdx - L.maxVisible, #self.roomList - L.maxVisible))
    for i = L.scroll + 1, math.min(#self.roomList, L.scroll + L.maxVisible) do
        L.rows[i] = { x = L.list.x + 16, y = y0 + (i - 1 - L.scroll) * (ROW_H + ROW_GAP), w = L.list.w - 32, h = ROW_H }
    end
    -- botones de abajo (crear / refrescar / volver); el primero deja sitio al cursor
    local n, gap = #LIST_BTNS, 24
    local bx0 = L.list.x + 56
    local bw = math.floor((L.list.x + L.list.w - bx0 - (n - 1) * gap) / n)
    L.btns = {}
    for i = 1, n do L.btns[i] = { x = bx0 + (i - 1) * (bw + gap), y = L.list.y + L.list.h + 20, w = bw, h = BTN_H } end

    -- ventana del asistente / de la contraseña / de espera
    local ww = math.min(760, WINDOW_W - 120)
    local wh = self.sub == SUB_PASSWORD and 360 or (self.sub == SUB_WAITING and 200 or 420)
    L.win = { x = math.floor((WINDOW_W - ww) / 2), y = math.floor((WINDOW_H - wh) / 2) + 16, w = ww, h = wh }
    local W = L.win
    L.field = { x = W.x + 40, y = W.y + 170, w = W.w - 80, h = 64 }
    local cw = math.floor((W.w - 80 - 24) / 2)
    L.choices = { { x = W.x + 40, y = W.y + 158, w = cw, h = 96 }, { x = W.x + 40 + cw + 24, y = W.y + 158, w = cw, h = 96 } }
    local nw = math.floor((W.w - 80 - 72) / 2)           -- (entre los dos, sitio para el cursor)
    -- máximo de jugadores: [<] número [>]
    local nbw, abw = 200, 72
    local nx = W.x + math.floor((W.w - nbw) / 2)
    L.num   = { x = nx, y = W.y + 150, w = nbw, h = 108 }
    L.minus = { x = nx - 24 - abw, y = W.y + 168, w = abw, h = abw }
    L.plus  = { x = nx + nbw + 24, y = W.y + 168, w = abw, h = abw }
    L.nav = { { x = W.x + 40, y = W.y + W.h - 96, w = nw, h = BTN_H },               -- CANCELAR
              { x = W.x + 40 + nw + 72, y = W.y + W.h - 96, w = nw, h = BTN_H } }    -- SIGUIENTE / CREAR / UNIRSE
    if self.sub == SUB_CREATE and self.createStep == STEP_PRIVACY then
        -- (elegir una opción ya avanza: solo CANCELAR, en el centro)
        L.nav = { { x = W.x + math.floor((W.w - nw) / 2), y = W.y + W.h - 96, w = nw, h = BTN_H } }
    end
    if self.sub == SUB_PASSWORD then
        L.field.y = W.y + 140
        L.nav[1], L.nav[2] = L.nav[2], L.nav[1]            -- (UNIRSE a la izquierda, CANCELAR a la derecha)
        L.nav.join, L.nav.cancel = L.nav[2], L.nav[1]
    end
    return L
end

local function inRect(r, x, y, pad)
    pad = pad or 0
    return r and x >= r.x - pad and x <= r.x + r.w + pad and y >= r.y - pad and y <= r.y + r.h + pad
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────

local function bobOf(t, sel) return sel and ((math.floor(t * 3) % 2 == 0) and -4 or 0) or 0 end

-- Botón de menú con su rebote y el cursor si está elegido
function OnlineHubState:_button(text, r, color, sel, a, ox, oy)
    ox, oy = ox or 0, oy or 0
    MenuButton.draw(text, r.x + ox, r.y + oy + bobOf(self.t, sel), r.w, r.h, color, sel,
                    { alpha = a, scale = MenuButton.textScale(text, r.w - 48, 4) })
    if sel then MenuKit.marker(r.x + ox, r.y + oy + bobOf(self.t, sel), r.w, r.h, self.t, a) end
end

-- Una ventana con su título en la fuente pixel (entra desde abajo)
function OnlineHubState:_window(title, sub)
    local Ly = self:_layout()
    local W = Ly.win
    MenuKit.dim(0.55)
    local _, oy, a = self.winAnim:slide(1, 0, 160)
    MenuKit.box('window', W.x, W.y + oy, W.w, W.h, a)
    local s = 5
    while s > 3 and PixelFont.width(title, s) > W.w - 80 do s = s - 1 end
    PixelFont.shadow(title, math.floor(W.x + (W.w - PixelFont.width(title, s)) / 2), W.y + 30 + oy, s, a, { 1, 0.86, 0.36 })
    if sub then MenuKit.text(FONT_SMALL, sub, W.x + 20, W.y + 30 + PixelFont.height(s) + 18 + oy, W.w - 40, 'center', { 0.75, 0.8, 0.95 }, a) end
    return Ly, oy, a
end

function OnlineHubState:render()
    MenuScene.backdrop()                 -- (el fondo vivo de los menús: src/ui/menu/MenuScene)
    self:_renderList()
    if self.sub == SUB_WAITING then
        local dots = string.rep(".", math.floor(love.timer.getTime() * 2) % 4)
        local Ly, oy, a = self:_window(L('hub.connecting') .. dots)
        MenuKit.text(FONT_SMALL, L(Input.lastDevice == 'touch' and 'hub.tap_cancel' or 'hub.cancel_hint'), Ly.win.x, Ly.win.y + Ly.win.h - 52 + oy, Ly.win.w, 'center', { 0.7, 0.76, 0.92 }, a)
    elseif self.sub == SUB_CREATE then
        self:_renderCreate()
    elseif self.sub == SUB_PASSWORD then
        self:_renderPassword()
    end
    love.graphics.setColor(COLOR_WHITE)
end

function OnlineHubState:_renderList()
    local A = self.anim
    local Ly = self:_layout()
    MenuKit.title(L('hub.title'), 'purple', A, 1)
    local focusRooms = self.sub == SUB_LIST and self.listFocus == 'rooms'

    -- La lista de salas
    local ox, oy, a = A:slide(2, 0, 220)
    local R = Ly.list
    MenuKit.section(L('hub.rooms', { n = #self.roomList }), R.x + 4 + ox, R.y - 36 + oy, R.w / 2, focusRooms, a)
    MenuKit.text(FONT_SMALL, L('hub.playing_as', { name = NC.myName or '?' }), R.x + ox, R.y - 30 + oy, R.w - 4, 'right', { 0.75, 0.8, 0.95 }, a)
    MenuKit.box('well', R.x + ox, R.y + oy, R.w, R.h, a)
    if #self.roomList == 0 then
        MenuKit.text(FONT_MED, L('hub.no_rooms'), R.x + ox, R.y + R.h / 2 - 8 + oy, R.w, 'center', { 0.6, 0.66, 0.85 }, a)
    end
    for i, r in pairs(Ly.rows) do
        local room = self.roomList[i]
        local sel = i == self.selectedIdx and focusRooms
        local x, y = r.x + ox, r.y + oy
        MenuKit.box(sel and 'card_sel' or 'card', x, y, r.w, r.h, a)
        local cy = y + math.floor((r.h - FONT_MED:getHeight()) / 2)
        -- candado (contraseña) o hueco
        local nx = x + 20
        if room.hasPassword then
            local iw, ih = PixelIcons.size('lock')
            PixelIcons.draw('lock', nx, y + math.floor((r.h - ih * 3) / 2), 3, a)
            nx = nx + iw * 3 + 14
        end
        local inGame = room.state == "IN_GAME"
        -- a la derecha: jugadores y estado
        local status = inGame and L('hub.in_game') or L('hub.waiting')
        local sw = PixelFont.width(status, 2)
        local sx = x + r.w - 20 - sw
        PixelFont.shadow(status, sx, y + math.floor((r.h - PixelFont.height(2)) / 2), 2, a, inGame and { 1, 0.62, 0.3 } or { 0.5, 0.95, 0.55 })
        local count = string.format("%d/%d", room.currentPlayers or 0, room.maxPlayers or 0)
        local cw = PixelFont.width(count, 3)
        PixelFont.shadow(count, sx - 28 - cw, y + math.floor((r.h - PixelFont.height(3)) / 2), 3, a)
        local name = fitText(FONT_MED, room.name or '?', sx - 56 - cw - nx)
        MenuKit.text(FONT_MED, name, nx, cy, sx - nx, 'left', sel and { 1, 1, 1 } or { 0.88, 0.9, 1 }, a)
    end
    -- flechas de que hay más salas arriba / abajo
    if Ly.scroll > 0 then MenuKit.text(FONT_SMALL, '^', R.x + ox, R.y + 2 + oy, R.w, 'center', { 1, 0.86, 0.36 }, a) end
    if Ly.scroll + Ly.maxVisible < #self.roomList then MenuKit.text(FONT_SMALL, 'v', R.x + ox, R.y + R.h - 14 + oy, R.w, 'center', { 1, 0.86, 0.36 }, a) end

    -- Botones de abajo
    local colors = { 'green', 'blue', 'grey' }
    for i, lbl in ipairs(LIST_BTNS) do
        local bx, by, ba = A:slide(2 + i, 0, 220)
        local sel = self.sub == SUB_LIST and self.listFocus == 'btns' and i == self.btnSel
        self:_button(L(lbl), Ly.btns[i], colors[i], sel, ba, bx, by)
    end
    if self.sub == SUB_LIST then MenuKit.hint(L('hub.list_hint'), A, 6) end
end

function OnlineHubState:_renderCreate()
    local stepLabels = { L('hub.step_name'), L('hub.step_visibility'), L('hub.step_password'), L('hub.step_max') }
    local Ly, oy, a = self:_window(L('hub.create'), stepLabels[self.createStep])
    local W = Ly.win
    -- los pasos: un cuadradito por paso (el de contraseña solo si es privada)
    local steps = self.privacySel == 2 and { 1, 2, 3, 4 } or { 1, 2, 4 }
    local n = #steps
    local sz, gap = 16, 12
    local sx = math.floor(W.x + (W.w - (n * sz + (n - 1) * gap)) / 2)
    for i, st in ipairs(steps) do
        local done, cur = st < self.createStep, st == self.createStep
        love.graphics.setColor(0, 0, 0, 0.5 * a)
        love.graphics.rectangle('fill', sx + (i - 1) * (sz + gap) + 4, W.y + 126 + oy + 4, sz, sz)
        if cur then love.graphics.setColor(1, 0.86, 0.36, a)
        elseif done then love.graphics.setColor(0.5, 0.95, 0.55, a)
        else love.graphics.setColor(0.3, 0.36, 0.55, a) end
        love.graphics.rectangle('fill', sx + (i - 1) * (sz + gap), W.y + 126 + oy, sz, sz)
    end
    love.graphics.setColor(1, 1, 1, 1)

    local F = Ly.field
    if self.createStep == STEP_NAME then
        MenuKit.field(F.x, F.y + oy, F.w, F.h, self.inputBuffer, true, { alpha = a, placeholder = L('hub.name_prompt') })
        MenuKit.text(FONT_SMALL, L('hub.name_max'), F.x, F.y + F.h + 12 + oy, F.w, 'right', { 0.6, 0.66, 0.85 }, a)
    elseif self.createStep == STEP_PRIVACY then
        local opts = { { 'hub.public', 'hub.public_desc', 'blue' }, { 'hub.private', 'hub.private_desc', 'pink' } }
        for i, o in ipairs(opts) do
            local r = Ly.choices[i]
            local sel = self.privacySel == i
            MenuButton.draw(L(o[1]), r.x, r.y + oy + bobOf(self.t, sel), r.w, r.h, sel and o[3] or 'grey', sel,
                            { alpha = a, scale = MenuButton.textScale(L(o[1]), r.w - 48, 5) })
            if sel and not self.hoveredCreateNav then MenuKit.marker(r.x, r.y + oy + bobOf(self.t, sel), r.w, r.h, self.t, a) end
            MenuKit.text(FONT_SMALL, L(o[2]), r.x, r.y + r.h + 16 + oy, r.w, 'center', sel and { 1, 1, 1 } or { 0.6, 0.66, 0.85 }, a)
        end
    elseif self.createStep == STEP_PASS then
        MenuKit.field(F.x, F.y + oy, F.w, F.h, self.inputBuffer, true, { alpha = a, placeholder = L('hub.password_empty') })
    elseif self.createStep == STEP_MAX then
        -- el número en su hueco y un botón a cada lado (se hunde un momento al pulsarlo)
        local N = Ly.num
        MenuKit.box('well', N.x, N.y + oy, N.w, N.h, a)
        if not self.hoveredCreateNav then MenuKit.marker(Ly.minus.x, N.y + oy, Ly.plus.x + Ly.plus.w - Ly.minus.x, N.h, self.t, a) end
        local num = tostring(self.maxValue)
        PixelFont.shadow(num, math.floor(N.x + (N.w - PixelFont.width(num, 8)) / 2), N.y + 16 + oy, 8, a, { 1, 0.86, 0.36 })
        local lbl = L('hub.players_word')
        PixelFont.draw(lbl, math.floor(N.x + (N.w - PixelFont.width(lbl, 2)) / 2), N.y + N.h - 24 + oy, 2, 0.8 * a)
        for i, r in ipairs({ Ly.minus, Ly.plus }) do
            local d = i == 1 and -1 or 1
            local can = (d < 0 and self.maxValue > 2) or (d > 0 and self.maxValue < 8)
            local hov = self.hoveredCreateBtn == i
            local push = (self.stepPush == d and self.t < 0.12) and 4 or 0
            MenuButton.draw(nil, r.x, r.y + oy + push, r.w, r.h, can and 'blue' or 'grey', hov and can, { alpha = a * (can and 1 or 0.6) })
            MenuKit.arrow(math.floor(r.x + r.w / 2) + (d < 0 and 8 or -8), math.floor(r.y + (r.h - 4) / 2) + oy + push, 28, d,
                          a * (can and 1 or 0.6), { 1, 1, 1 })
        end
    end
    -- CANCELAR / SIGUIENTE (o CREAR); en la privacidad, solo CANCELAR (elegir ya avanza)
    local nav = self.hoveredCreateNav
    self:_button(L('hub.cancel'), Ly.nav[1], 'grey', nav == 1, a, 0, oy)
    if #Ly.nav > 1 then
        self:_button(self.createStep == STEP_MAX and L('hub.create') or L('hub.next'), Ly.nav[2], 'green', nav == 2, a, 0, oy)
    end
    local hints = { L('hub.confirm_hint'), L('hub.select_hint'), L('hub.confirm_hint'), L('hub.change_hint') .. '   ' .. L('hub.create_hint') }
    MenuKit.hint(hints[self.createStep])
end

function OnlineHubState:_renderPassword()
    local Ly, oy, a = self:_window(L('hub.password_title'), self.joinRoom and L('hub.room_label', { name = self.joinRoom.name }) or nil)
    local F = Ly.field
    MenuKit.field(F.x, F.y + oy, F.w, F.h, self.inputBuffer, true, { alpha = a, mask = true })
    local cancelSel = self.hoveredPassBtn == 2
    self:_button(L('hub.join'), Ly.nav.join, 'green', not cancelSel, a, 0, oy)
    self:_button(L('hub.cancel'), Ly.nav.cancel, 'grey', cancelSel, a, 0, oy)
    MenuKit.hint(L('hub.join_hint'))
end

-- ── Ratón: mueve la selección real al elemento bajo el cursor ────────────────

function OnlineHubState:mousemoved(tx, ty)
    local Ly = self:_layout()
    if self.sub == SUB_LIST then
        for i, r in ipairs(Ly.btns) do
            if inRect(r, tx, ty, 8) then
                if self.listFocus ~= 'btns' or self.btnSel ~= i then
                    self.listFocus, self.btnSel, self.t = 'btns', i, 0; Sound.play('select')
                end
                return
            end
        end
        for i, r in pairs(Ly.rows) do
            if inRect(r, tx, ty) then
                if self.listFocus ~= 'rooms' or self.selectedIdx ~= i then
                    self.listFocus, self.selectedIdx = 'rooms', i; Sound.play('select')
                end
                return
            end
        end
    elseif self.sub == SUB_CREATE then
        local prev = self.hoveredCreateNav
        self.hoveredCreateNav = nil
        for i, r in ipairs(Ly.nav) do if inRect(r, tx, ty, 4) then self.hoveredCreateNav = i end end
        if self.hoveredCreateNav and self.hoveredCreateNav ~= prev then self.t = 0; Sound.play('select') end
        if self.createStep == STEP_PRIVACY then
            for i, r in ipairs(Ly.choices) do
                if inRect(r, tx, ty, 8) and self.privacySel ~= i then self.privacySel, self.t = i, 0; Sound.play('select') end
            end
        elseif self.createStep == STEP_MAX then
            local prevB = self.hoveredCreateBtn
            self.hoveredCreateBtn = inRect(Ly.minus, tx, ty, 6) and 1 or (inRect(Ly.plus, tx, ty, 6) and 2 or nil)
            if self.hoveredCreateBtn and self.hoveredCreateBtn ~= prevB then Sound.play('select') end
        end
    elseif self.sub == SUB_PASSWORD then
        local prev = self.hoveredPassBtn
        self.hoveredPassBtn = inRect(Ly.nav.cancel, tx, ty, 4) and 2 or nil
        if self.hoveredPassBtn and self.hoveredPassBtn ~= prev then self.t = 0; Sound.play('select') end
    end
end

function OnlineHubState:touchmoved(id, tx, ty)
    local lt = self.listTouch
    if not lt or lt.id ~= id or self.sub ~= SUB_LIST then return end
    local dy = ty - lt.y
    if math.abs(dy) > 12 then lt.moved = true end
    if lt.moved then
        local n = math.max(1, #self.roomList)
        local idx = math.max(1, math.min(n, lt.idx - math.floor(dy / (ROW_H + ROW_GAP) + 0.5)))
        if idx ~= self.selectedIdx then self.selectedIdx, self.listFocus = idx, 'rooms'; Sound.play('select') end
    end
end

function OnlineHubState:touchreleased(id, tx, ty)
    local lt = self.listTouch
    if not lt or lt.id ~= id then return end
    self.listTouch = nil
    if lt.moved or self.sub ~= SUB_LIST or not self.roomList[lt.row] then return end
    Sound.play('select')
    if self.selectedIdx == lt.row and self.listFocus == 'rooms' then
        self:_joinRoom(self.roomList[lt.row]); self:_syncKeyboard()
    else
        self.selectedIdx, self.listFocus = lt.row, 'rooms'
    end
end

-- Rueda del ratón: desplaza la lista de salas
function OnlineHubState:wheelmoved(dx, dy)
    if self.sub ~= SUB_LIST or #self.roomList == 0 then return end
    self.listFocus   = 'rooms'
    self.selectedIdx = math.max(1, math.min(#self.roomList, self.selectedIdx - dy))
end

-- ── Exit ──────────────────────────────────────────────────────────────────────

function OnlineHubState:exit()
    love.keyboard.setTextInput(false)
    self._keyboardOn = false
end

-- ── Touch ─────────────────────────────────────────────────────────────────────

function OnlineHubState:_listButton(i)
    if i == BTN_CREATE then
        self:_resetCreate(); self:_setSub(SUB_CREATE)
    elseif i == BTN_REFRESH then
        NC:send("get_rooms", {})
    elseif i == BTN_BACK then
        self:_leave()
    end
end

function OnlineHubState:touchpressed(id, tx, ty)
    if self.sub == SUB_WAITING then self:_setSub(SUB_LIST); return end      -- (tocar = cancelar, como VOLVER)
    local Ly = self:_layout()

    if self.sub == SUB_LIST then
        for i, r in ipairs(Ly.btns) do
            if inRect(r, tx, ty, 8) then Sound.play('select'); self:_listButton(i); self:_syncKeyboard(); return end
        end
        for i, r in pairs(Ly.rows) do
            if inRect(r, tx, ty) then
                if id ~= 'mouse' then
                    -- (dedo: se decide al soltar — tocar = elegir / entrar; arrastrar = desplazar: antes solo cabían
                    -- 5 y las demás salas no se podían alcanzar en Android)
                    self.listTouch = { id = id, y = ty, idx = self.selectedIdx, row = i, moved = false }
                    return
                end
                Sound.play('select')
                self.selectedIdx, self.listFocus = i, 'rooms'
                self:_joinRoom(self.roomList[i])
                self:_syncKeyboard()
                return
            end
        end
        return
    end

    if self.sub == SUB_CREATE then
        if inRect(Ly.nav[1], tx, ty, 6) then Sound.play('select'); self:_createCancel(); return end
        if inRect(Ly.nav[2], tx, ty, 6) then self:_createNext(); return end
        if (self.createStep == STEP_NAME or self.createStep == STEP_PASS) and inRect(Ly.field, tx, ty) then
            love.keyboard.setTextInput(true); self._keyboardOn = true
        elseif self.createStep == STEP_PRIVACY then
            -- (un toque elige y avanza)
            for i, r in ipairs(Ly.choices) do
                if inRect(r, tx, ty, 8) then self.privacySel = i; self:_createNext(); return end
            end
        elseif self.createStep == STEP_MAX then
            if inRect(Ly.minus, tx, ty, 8) then self:_stepMax(-1) elseif inRect(Ly.plus, tx, ty, 8) then self:_stepMax(1) end
        end
        return
    end

    if self.sub == SUB_PASSWORD then
        if inRect(Ly.field, tx, ty) then love.keyboard.setTextInput(true); self._keyboardOn = true; return end
        if inRect(Ly.nav.join, tx, ty, 6) then self:_sendPassword(); return end
        if inRect(Ly.nav.cancel, tx, ty, 6) then
            self:_setSub(SUB_LIST); self.inputBuffer = ""; self.joinRoom = nil
            self:_syncKeyboard()
        end
    end
end

return OnlineHubState
