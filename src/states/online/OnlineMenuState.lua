-- src/states/online/OnlineMenuState.lua
-- El MENÚ ONLINE (el usuario, 2026-11-03): tras entrar con el nombre, tres opciones — SALAS (la lista de salas, el hub),
-- DESAFÍO DEL DÍA (su menú: en solitario o el club del día, OnlineDailyState) y RÉCORDS (OnlineRecordsState).
-- ATRÁS cierra la conexión y vuelve al nombre. Como las demás pantallas de menú (docs/architecture/menus.md): rótulo,
-- botones de colores que entran escalonados (MenuList, MenuAnim) y la descripción del elegido abajo.
local BaseState     = require 'src/core/BaseState'
local MenuScene     = require 'src/ui/menu/MenuScene'
local MenuAnim      = require 'src/ui/menu/MenuAnim'
local MenuList      = require 'src/ui/menu/MenuList'
local CornerButtons = require 'src/ui/CornerButtons'
local NC            = require 'src/network/NetworkClient'
local L             = require 'src/core/Lang'

local OnlineMenuState = BaseState:new()

function OnlineMenuState:enter(args)
    self.anim = MenuAnim.new({ n = 5 })
    local go = function(state) return function() self:_leave(state) end end
    self.list = MenuList.new({ anim = self.anim, first = 2, top = 0.34, selected = (args and args.selected) or 1, items = {
        { text = 'onlinemenu.rooms',   color = 'purple', desc = 'onlinemenu.desc_rooms',   go = go('online_hub') },
        { text = 'onlinemenu.daily',   color = 'orange', desc = 'onlinemenu.desc_daily',   go = go('online_daily') },
        { text = 'onlinemenu.records', color = 'yellow', desc = 'onlinemenu.desc_records', go = go('online_records') },
    } })
    -- (volver a la partida tras un corte: el login trae aquí y el servidor manda la sala en marcha → la sala → la partida)
    NC:on("room_update", function(data) gStateMachine:change('online_room', { room = data }) end)
    NC:on("room_error", function(data) Notify.toast(L.fromServer(type(data) == 'table' and data or {}, 'hub.error'), 'error') end)
    NC:on("connection_lost", function(data)
        gStateMachine:change('online_error', { code = "ERR_CONNECTION_LOST", msg = data.msg or L('err.lost') })
    end)
    Sound.playMusic('menus')
end

function OnlineMenuState:_leave(state)
    self.anim:leave(function() gStateMachine:change(state) end, 5)
end

function OnlineMenuState:_back()
    if self.anim:busy() then return end
    Sound.play('select', 0.85)
    NC:disconnect()
    self.anim:leave(function() gStateMachine:change('online_login') end, 5)
end

function OnlineMenuState:update(dt)
    MenuScene.update(dt)
    self.anim:update(dt)
    if self.anim:busy() then return end
    if Input.pressed('back') then return self:_back() end
    self.list:update(dt)
end

function OnlineMenuState:render()
    MenuScene.backdrop('online')
    MenuList.header(L('onlinemenu.title'), 'purple', self.anim, 1)
    self.list:draw()
    MenuList.footer(self.list:desc(), self.anim, 5)
    CornerButtons.drawBack(self.backHover)
end

function OnlineMenuState:mousemoved(x, y)
    self.backHover = CornerButtons.hitBack(x, y)
    if not self.backHover then self.list:mousemoved(x, y) end
end

function OnlineMenuState:touchpressed(id, x, y)
    if self.anim:busy() then return end
    if CornerButtons.hitBack(x, y) then return self:_back() end
    self.list:touchpressed(x, y)
end

return OnlineMenuState
