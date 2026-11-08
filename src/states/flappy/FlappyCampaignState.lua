-- src/states/flappy/FlappyCampaignState.lua
-- CLÁSICO en el menú principal: la CAMPAÑA FLAPPY (la precuela de Aventura: docs/design/flappy-prequel.md).
-- CAMPAÑA lleva a sus partidas (la pantalla de cartuchos, compartida con la historia: story_slots con campaign =
-- 'flappy'). Mientras Campaign.READY sea false (la campaña aún no tiene final), además el modo INFINITO de siempre; luego
-- queda solo en el menú de depuración. args.select = id del botón elegido al volver ('campaign' | 'endless').
local CornerButtons = require 'src/ui/CornerButtons'
local BaseState     = require 'src/core/BaseState'
local MenuScene     = require 'src/ui/menu/MenuScene'
local MenuAnim      = require 'src/ui/menu/MenuAnim'
local MenuList      = require 'src/ui/menu/MenuList'
local Transition    = require 'src/ui/menu/Transition'
local Campaign      = require 'src/flappy/Campaign'
local L = require 'src/core/Lang'
local FlappyCampaignState = BaseState:new()

local N = 5      -- rótulo + hasta 2 botones + pie (+1 de margen)

function FlappyCampaignState:enter(args)
    self.anim = MenuAnim.new({ n = N })
    local items = {
        { id = 'campaign', text = 'fc.campaign', color = 'orange', desc = 'fc.desc_campaign',
          go = function()
              self.anim:leave(function() end, N)
              Transition.go('story_slots', { campaign = 'flappy' })
          end },
    }
    if not Campaign.READY then
        items[#items + 1] = { id = 'endless', text = 'fc.endless', color = 'yellow', desc = 'fc.desc_endless',
                              go = function() self:_leave('difficulty', { from = 'flappy_campaign' }) end }
    end
    local sel = (args and args.selected) or 1
    for i, it in ipairs(items) do if args and it.id == args.select then sel = i end end
    self.list = MenuList.new({ anim = self.anim, first = 2, top = 0.36, selected = sel, items = items })
    Sound.playMusic('menus')
end

function FlappyCampaignState:_leave(state, args)
    self.anim:leave(function() gStateMachine:change(state, args) end, N)
end

function FlappyCampaignState:_back()
    if self.anim:busy() then return end
    Sound.play('select', 0.85)
    self:_leave('main_menu', { select = 'classic' })
end

function FlappyCampaignState:update(dt)
    MenuScene.update(dt)
    self.anim:update(dt)
    if self.anim:busy() then return end
    if Input.pressed('back') then return self:_back() end
    self.list:update(dt)
end

function FlappyCampaignState:render()
    MenuScene.draw()
    MenuList.header(L('menu.classic'), 'orange', self.anim, 1)
    self.list:draw()
    MenuList.footer(self.list:desc(), self.anim, N)
    CornerButtons.drawBack(self.backHover)
end

function FlappyCampaignState:mousemoved(x, y)
    self.backHover = CornerButtons.hitBack(x, y)
    if not self.backHover then self.list:mousemoved(x, y) end
end

function FlappyCampaignState:touchpressed(id, x, y)
    if self.anim:busy() then return end
    if CornerButtons.hitBack(x, y) then return self:_back() end
    self.list:touchpressed(x, y)
end

return FlappyCampaignState
