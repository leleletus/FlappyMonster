-- src/states/menu/AdventureModeSelectState.lua
-- Menú intermedio: TUTORIAL (0.5.190), HISTORIA (un jugador) u ONLINE (multijugador). (JUEGO LIBRE salió de aquí el 2026-11-07: está en
-- el menú de depuración — DebugMenuState —.)
-- Se muestra al elegir Aventura en el menú principal. Como todas las pantallas de menú (docs/architecture/menus.md): sobre
-- el fondo vivo (MenuScene), rótulo arriba, botones de colores que entran y salen escalonados (MenuList, MenuAnim)
-- y la descripción del elegido abajo. A otra pantalla de menú se pasa con la salida de los botones; a las que no
-- comparten el fondo, con la transición de bloques (Transition).

local CornerButtons = require 'src/ui/CornerButtons'
local BaseState     = require 'src/core/BaseState'
local MenuScene     = require 'src/ui/menu/MenuScene'
local MenuAnim      = require 'src/ui/menu/MenuAnim'
local MenuList      = require 'src/ui/menu/MenuList'
local Transition    = require 'src/ui/menu/Transition'
local L = require 'src/core/Lang'
local TutorialOffer = require 'src/states/story/TutorialOfferState'
local AdventureModeSelectState = BaseState:new()

function AdventureModeSelectState:enter(args)
    self.anim = MenuAnim.new({ n = 5 })
    local go = function(state) return function() self:_leave(state) end end
    self.list = MenuList.new({ anim = self.anim, first = 2, top = 0.34, selected = (args and args.selected) or 2, items = {   -- (por defecto, HISTORIA: el tutorial va primero en la lista)
        -- (el nivel TUTORIAL — docs/design/tutorial-level.md —: se vuelve a este menú)
        { text = 'adv.tutorial', color = 'green', desc = 'adv.desc_tutorial',
          go = function() TutorialOffer.markOffered(); self:_leave('adventure', { level = TutorialOffer.LEVEL, returnTo = 'adv_mode_select' }) end },
        { text = 'adv.story',  color = 'yellow', desc = 'adv.desc_story',  go = go('story_slots') },
        { text = 'adv.online', color = 'purple', desc = 'adv.desc_online', go = go('online_login') },
    } })
    Sound.playMusic('menus')
end

function AdventureModeSelectState:_leave(state, args)
    self.anim:leave(function() end, 5)
    Transition.go(state, args)
end

function AdventureModeSelectState:_back()
    if self.anim:busy() then return end
    Sound.play('select', 0.85)
    self.anim:leave(function() gStateMachine:change('main_menu', { select = 'adventure' }) end, 5)
end

function AdventureModeSelectState:update(dt)
    MenuScene.update(dt)
    self.anim:update(dt)
    if self.anim:busy() then return end
    if Input.pressed('back') then return self:_back() end
    self.list:update(dt)
end

function AdventureModeSelectState:render()
    MenuScene.draw()
    MenuList.header(L('adv.title'), 'green', self.anim, 1)
    self.list:draw()
    MenuList.footer(self.list:desc(), self.anim, 5)
    CornerButtons.drawBack(self.backHover)
end

function AdventureModeSelectState:mousemoved(x, y)
    self.backHover = CornerButtons.hitBack(x, y)
    if not self.backHover then self.list:mousemoved(x, y) end
end

function AdventureModeSelectState:touchpressed(id, x, y)
    if self.anim:busy() then return end
    if CornerButtons.hitBack(x, y) then return self:_back() end
    self.list:touchpressed(x, y)
end

return AdventureModeSelectState
