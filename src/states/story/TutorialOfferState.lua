-- src/states/story/TutorialOfferState.lua
-- La OFERTA del tutorial (0.5.191; el usuario: «sí, de forma opcional»): la primera vez que se empieza una historia
-- nueva en este aparato, antes de la intro, se pregunta si se quiere jugar el nivel tutorial (docs/design/tutorial-level.md).
-- Solo se ofrece una vez (Settings.tutorialOffered, que también marca entrar al tutorial desde el menú de Aventura).
-- Lo lleva quien tenga `offerTutorial` en su campaña (src/story/Campaigns.lua).
--   gStateMachine:change / Transition.go('tutorial_offer', { state = a dónde se sigue, args = sus argumentos })
-- El nivel sale siempre a este estado (`returnTo`: al acabar, al salir desde la pausa…), que al volver sin argumentos
-- sigue con lo pendiente: la partida empieza igual se termine el tutorial o no.
local BaseState  = require 'src/core/BaseState'
local Settings   = require 'src/core/Settings'
local MenuScene  = require 'src/ui/menu/MenuScene'
local MenuAnim   = require 'src/ui/menu/MenuAnim'
local MenuList   = require 'src/ui/menu/MenuList'
local Transition = require 'src/ui/menu/Transition'
local CornerButtons = require 'src/ui/CornerButtons'
local L = require 'src/core/Lang'

local Offer = BaseState:new()
Offer.LEVEL = 'assets/levels/tutorial.json'

local pending                                      -- { state, args }: sobrevive a la ida y vuelta por el nivel

function Offer.shouldOffer() return not Settings.tutorialOffered end
function Offer.markOffered()
    if not Settings.tutorialOffered then Settings.set('tutorialOffered', true) end
end

function Offer:enter(args)
    if not (args and args.state) then self.resume = true; return end    -- (de vuelta del nivel)
    pending = { state = args.state, args = args.args }
    Offer.markOffered()
    self.anim = MenuAnim.new({ n = 4 })
    self.list = MenuList.new({ anim = self.anim, first = 2, top = 0.38, selected = 1, items = {
        { text = 'story.tut_yes', color = 'green', desc = 'story.tut_desc_yes', go = function() self:_play() end },
        { text = 'story.tut_no',  color = 'yellow', desc = 'story.tut_desc_no', go = function() self:_skip() end },
    } })
    Sound.playMusic('menus')
end

function Offer:_play()
    self.anim:leave(function() end, 4)
    Transition.go('adventure', { level = Offer.LEVEL, returnTo = 'tutorial_offer' })
end

function Offer:_skip()
    self.anim:leave(function() end, 4)
    Transition.go(pending.state, pending.args)
end

function Offer:update(dt)
    if self.resume then
        local p = pending or { state = 'main_menu' }
        pending = nil
        return gStateMachine:change(p.state, p.args)
    end
    MenuScene.update(dt)
    self.anim:update(dt)
    if self.anim:busy() then return end
    if Input.pressed('back') then Sound.play('select', 0.85); return self:_skip() end
    self.list:update(dt)
end

function Offer:render()
    if self.resume then return end
    MenuScene.draw()
    MenuList.header(L('story.tut_offer'), 'green', self.anim, 1)
    self.list:draw()
    MenuList.footer(self.list:desc(), self.anim, 4)
    CornerButtons.drawBack(self.backHover)
end

function Offer:mousemoved(x, y)
    if self.resume then return end
    self.backHover = CornerButtons.hitBack(x, y)
    if not self.backHover then self.list:mousemoved(x, y) end
end

function Offer:touchpressed(id, x, y)
    if self.resume or self.anim:busy() then return end
    if CornerButtons.hitBack(x, y) then return self:_skip() end
    self.list:touchpressed(x, y)
end

return Offer
