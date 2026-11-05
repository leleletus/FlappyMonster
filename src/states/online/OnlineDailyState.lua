-- src/states/online/OnlineDailyState.lua
-- El menú del DESAFÍO DEL DÍA (el usuario, 2026-11-04), desde el menú online: dos opciones —
--  · EN SOLITARIO: una sala solo tuya con el nivel de hoy (server/srv/records.lua `join_daily`; llega room_update →
--    la sala, OnlineRoomState, con solo LISTO / EMPEZAR / SALIR);
--  · CLUB DEL DÍA: la lista de salas del desafío con amigos (OnlineHubState con `daily`: su propia lista, crear y entrar).
-- ATRÁS vuelve al menú online. Como las demás pantallas de menú (docs/architecture/menus.md).
local BaseState     = require 'src/core/BaseState'
local MenuScene     = require 'src/ui/menu/MenuScene'
local MenuAnim      = require 'src/ui/menu/MenuAnim'
local MenuList      = require 'src/ui/menu/MenuList'
local CornerButtons = require 'src/ui/CornerButtons'
local NC            = require 'src/network/NetworkClient'
local L             = require 'src/core/Lang'

local OnlineDailyState = BaseState:new()

local WAIT_SOLO = 6        -- s esperando la sala en solitario antes de dar el error

function OnlineDailyState:enter(args)
    self.anim = MenuAnim.new({ n = 4 })
    self.list = MenuList.new({ anim = self.anim, first = 2, top = 0.38, selected = (args and args.selected) or 1, items = {
        { text = 'daily.solo', color = 'orange', desc = 'daily.desc_solo', go = function() self:_solo() end },
        { text = 'daily.club', color = 'teal',   desc = 'daily.desc_club',
          go = function() self.anim:leave(function() gStateMachine:change('online_hub', { daily = true }) end, 4) end },
    } })
    self.waiting = nil
    NC:on("room_update", function(data) gStateMachine:change('online_room', { room = data }) end)
    NC:on("room_error", function(data)
        self.waiting = nil
        Notify.toast(L.fromServer(type(data) == 'table' and data or {}, 'hub.error'), 'error')
    end)
    NC:on("connection_lost", function(data)
        gStateMachine:change('online_error', { code = "ERR_CONNECTION_LOST", msg = data.msg or L('err.lost') })
    end)
    Sound.playMusic('menus')
end

-- En solitario: el servidor nos hace una sala de uno (al salir de ella se vuelve aquí: NC:toLobby)
function OnlineDailyState:_solo()
    if self.waiting then return end
    self.waiting = 0
    NC.lobby = { 'online_daily', { selected = 1 } }
    NC:send("join_daily", {})
end

function OnlineDailyState:_back()
    if self.anim:busy() then return end
    Sound.play('select', 0.85)
    self.anim:leave(function() gStateMachine:change('online_menu', { selected = 2 }) end, 4)
end

function OnlineDailyState:update(dt)
    MenuScene.update(dt)
    self.anim:update(dt)
    if self.waiting then
        self.waiting = self.waiting + dt
        if self.waiting >= WAIT_SOLO then
            gStateMachine:change('online_error', { code = "ERR_SERVER_TIMEOUT", msg = L('err.timeout') })
        end
        return
    end
    if self.anim:busy() then return end
    if Input.pressed('back') then return self:_back() end
    self.list:update(dt)
end

function OnlineDailyState:render()
    MenuScene.backdrop('online')
    MenuList.header(L('daily.title'), 'orange', self.anim, 1)
    self.list:draw()
    MenuList.footer(self.waiting and L('hub.connecting') or self.list:desc(), self.anim, 4)
    CornerButtons.drawBack(self.backHover)
end

function OnlineDailyState:mousemoved(x, y)
    self.backHover = CornerButtons.hitBack(x, y)
    if not self.backHover then self.list:mousemoved(x, y) end
end

function OnlineDailyState:touchpressed(id, x, y)
    if self.anim:busy() or self.waiting then return end
    if CornerButtons.hitBack(x, y) then return self:_back() end
    self.list:touchpressed(x, y)
end

return OnlineDailyState
