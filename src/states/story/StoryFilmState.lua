-- src/states/story/StoryFilmState.lua
-- Pone una CINEMÁTICA de la historia (src/story/Film.lua): la intro al crear una partida, el final al
-- recuperar el último fragmento. Se puede SALTAR manteniendo pulsado un botón (o el dedo en la pantalla).
--   gStateMachine:change('story_film', { film = 'intro' | 'ending', xtra = bool, onDone = function() end })
local BaseState = require 'src/core/BaseState'
local Film = require 'src/story/Film'
local PixelFont = require 'src/ui/PixelFont'
local L = require 'src/core/Lang'

local StoryFilmState = BaseState:new()

local HOLD = 1.0                                   -- s manteniendo pulsado para saltarla
local HINT = 2.5                                   -- s que se ve el aviso tras tocar algo
local KEYS = { 'confirm', 'flap', 'jump', 'resume', 'back', 'pause' }

function StoryFilmState:enter(args)
    require('src/ui/View').lockGameplay()          -- (encuadres fijos: 1280x720 en todas las pantallas)
    args = args or {}
    self.onDone = args.onDone
    self.film = Film.new(args.film or 'intro', { xtra = args.xtra })
    self.hold, self.hintT, self.left = 0, 0, false
    Sound.stopMusic()
    Sound.setEcho(0)
    if self.film.tl.music then Sound.playMusic(self.film.tl.music) end
end

function StoryFilmState:exit()
    require('src/ui/View').unlock()
    require('src/story/Stage').reset()
end

function StoryFilmState:_finish()
    if self.left then return end
    self.left = true
    Sound.stopMusic()
    if self.onDone then self.onDone() else gStateMachine:change('story_map') end
end

function StoryFilmState:update(dt)
    if self.left then return end
    self.film:update(dt)
    -- (el dedo o el ratón, MIRANDO si siguen puestos: un clic suelto no la salta)
    -- (en la Switch no existe el módulo del ratón; en algunos PC, tampoco el táctil)
    local down = (love.touch ~= nil and #love.touch.getTouches() > 0) or (love.mouse ~= nil and love.mouse.isDown(1))
    for _, k in ipairs(KEYS) do if Input.down(k) then down = true end end
    if down then
        self.hold, self.hintT = self.hold + dt, HINT
        if self.hold >= HOLD then Sound.play('select'); self:_finish(); return end
    else
        self.hold = 0
        self.hintT = math.max(0, self.hintT - dt)
    end
    if self.film:done() then self:_finish() end
end

function StoryFilmState:touchpressed() end          -- (que un toque no caiga en los menús de debajo)

function StoryFilmState:render()
    self.film:draw()
    -- "mantén para saltar" + su barra, en la franja de abajo
    if self.hintT > 0 then
        local a = math.min(1, self.hintT / 0.4)
        local msg = L('story.skip_hint')
        local w = PixelFont.width(msg, 3)
        local x, y = WINDOW_W - w - 150, WINDOW_H - 38
        PixelFont.draw(msg, x, y, 3, a * 0.9)
        love.graphics.setColor(1, 1, 1, 0.35 * a)
        love.graphics.rectangle('fill', WINDOW_W - 134, y + 2, 104, 12)
        love.graphics.setColor(1, 0.9, 0.25, a)
        love.graphics.rectangle('fill', WINDOW_W - 132, y + 4, math.floor(100 * math.min(1, self.hold / HOLD)), 8)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

return StoryFilmState
