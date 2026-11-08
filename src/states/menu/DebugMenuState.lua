-- src/states/menu/DebugMenuState.lua
-- MENÚ DE DEPURACIÓN secreto (para desarrolladores y probadores): se entra desde el TÍTULO con ↑ ↑ ↓ ↓ ← → ← → (flechas
-- o cruceta) o tocando 7 veces seguidas la versión (abajo a la derecha). Lleva a lo que el jugador normal no ve:
--   · CLÁSICO (infinito): el Flappy de siempre con sus 3 dificultades (sin acceso normal cuando exista la campaña)
--   · AVENTURA sin candado: abre Aventura durante esta sesión aunque no se haya terminado la campaña Flappy
--   · JUEGO LIBRE, SOUND TEST y FILM TEST (antes el film test se abría desde el sound test con ◀)
-- Como todas las pantallas de menú (docs/architecture/menus.md): fondo vivo, rótulo, botones escalonados.
local CornerButtons = require 'src/ui/CornerButtons'
local BaseState     = require 'src/core/BaseState'
local MenuScene     = require 'src/ui/menu/MenuScene'
local MenuAnim      = require 'src/ui/menu/MenuAnim'
local MenuList      = require 'src/ui/menu/MenuList'
local Transition    = require 'src/ui/menu/Transition'
local Campaign      = require 'src/flappy/Campaign'
local L = require 'src/core/Lang'
local DebugMenuState = BaseState:new()

local N = 7      -- elementos animados: rótulo + 5 botones + pie

function DebugMenuState:enter(args)
    self.anim = MenuAnim.new({ n = N })
    local menu = function(state, a) return function() self:_leave(state, a) end end
    local iris = function(state) return function() self:_iris(state) end end
    self.list = MenuList.new({ anim = self.anim, first = 2, top = 0.30, selected = (args and args.selected) or 1, items = {
        { id = 'classic',   text = 'dbg.classic',   color = 'orange', desc = 'dbg.desc_classic',
          go = menu('difficulty', { from = 'debug_menu' }) },
        { id = 'adventure', text = 'dbg.adventure', color = 'green',  desc = 'dbg.desc_adventure',
          go = function() Campaign.debugOpen = true; self:_leave('adv_mode_select') end },
        { id = 'free',      text = 'dbg.free',      color = 'teal',   desc = 'dbg.desc_free',
          go = function() Campaign.debugOpen = true; self:_iris('free_play') end },
        { id = 'sound',     text = 'dbg.sound',     color = 'blue',   desc = 'dbg.desc_sound',   go = iris('sound_test') },
        { id = 'film',      text = 'dbg.film',      color = 'purple', desc = 'dbg.desc_film',    go = iris('film_test') },
    } })
    Sound.playMusic('menus')
end

-- A otra pantalla de menú (mismo fondo): salen los botones; a las demás, el iris
function DebugMenuState:_leave(state, args)
    self.anim:leave(function() gStateMachine:change(state, args) end, N)
end
function DebugMenuState:_iris(state)
    self.anim:leave(function() end, N)
    Transition.go(state)
end

function DebugMenuState:_back()
    if self.anim:busy() then return end
    Sound.play('select', 0.85)
    self.anim:leave(function() gStateMachine:change('main_menu') end, N)
end

function DebugMenuState:update(dt)
    MenuScene.update(dt)
    self.anim:update(dt)
    if self.anim:busy() then return end
    if Input.pressed('back') then return self:_back() end
    self.list:update(dt)
end

function DebugMenuState:render()
    MenuScene.draw()
    MenuList.header(L('dbg.title'), 'red', self.anim, 1)
    self.list:draw()
    MenuList.footer(self.list:desc(), self.anim, N)
    CornerButtons.drawBack(self.backHover)
end

function DebugMenuState:mousemoved(x, y)
    self.backHover = CornerButtons.hitBack(x, y)
    if not self.backHover then self.list:mousemoved(x, y) end
end

function DebugMenuState:touchpressed(id, x, y)
    if self.anim:busy() then return end
    if CornerButtons.hitBack(x, y) then return self:_back() end
    self.list:touchpressed(x, y)
end

return DebugMenuState
