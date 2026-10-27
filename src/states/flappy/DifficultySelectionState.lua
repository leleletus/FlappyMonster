-- src/states/flappy/DifficultySelectionState.lua
-- Elegir la dificultad del modo clásico (Flappy). Los nombres son TEXTO en
-- la fuente pixel de los menús (src/ui/PixelFont), traducidos (diff.*).
-- Como todas las pantallas de menú (docs/architecture/menus.md): fondo vivo, rótulo, un botón de color por dificultad
-- (verde, amarillo, rojo) que entran y salen escalonados; a la partida se pasa con la transición de bloques.
local CornerButtons = require 'src/ui/CornerButtons'
local BaseState  = require 'src/core/BaseState'
local MenuScene  = require 'src/ui/menu/MenuScene'
local MenuAnim   = require 'src/ui/menu/MenuAnim'
local MenuList   = require 'src/ui/menu/MenuList'
local Transition = require 'src/ui/menu/Transition'
local L          = require 'src/core/Lang'
local DifficultySelectionState = BaseState:new()

-- Color del botón de cada dificultad (las que no estén aquí, naranja)
local COLORS = { easy = 'green', normal = 'yellow', hard = 'red' }

function DifficultySelectionState:enter(args)
    self.anim = MenuAnim.new({ n = 2 + #DIFFICULTY_ORDER })
    local items = {}
    for i, key in ipairs(DIFFICULTY_ORDER) do
        items[i] = { text = 'diff.' .. key, color = COLORS[key] or 'mono', go = function() self:_start(key) end }
    end
    self.list = MenuList.new({ anim = self.anim, first = 2, top = 0.36, selected = 2, items = items })
    Sound.playMusic('menus')
end

function DifficultySelectionState:_start(key)
    self.anim:leave(function() end)
    Transition.go('play', { difficulty = key })
end

function DifficultySelectionState:_back()
    if self.anim:busy() then return end
    Sound.play('select', 0.85)
    self.anim:leave(function() gStateMachine:change('main_menu', { selected = 2 }) end)
end

function DifficultySelectionState:update(dt)
    MenuScene.update(dt)
    self.anim:update(dt)
    if self.anim:busy() then return end
    if Input.pressed('back') then return self:_back() end
    self.list:update(dt)
end

function DifficultySelectionState:render()
    MenuScene.draw()
    MenuList.header(L('difficulty.title'), 'mono', self.anim, 1)
    self.list:draw()
    MenuList.footer(L('menu.desc_classic'), self.anim, 2 + #DIFFICULTY_ORDER)
    CornerButtons.drawBack(self.backHover)
end

function DifficultySelectionState:mousemoved(x, y)
    self.backHover = CornerButtons.hitBack(x, y)
    if not self.backHover then self.list:mousemoved(x, y) end
end

function DifficultySelectionState:touchpressed(id, x, y)
    if self.anim:busy() then return end
    if CornerButtons.hitBack(x, y) then return self:_back() end
    self.list:touchpressed(x, y)
end

return DifficultySelectionState
