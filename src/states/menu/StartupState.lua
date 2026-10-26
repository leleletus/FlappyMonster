-- src/states/menu/StartupState.lua
-- PANTALLA DE INICIO: el logo de mtvemo antes del título. Negro → funde al cielo de noche → la MONEDA M·T·V entra
-- girando y aterriza → a su lado caen las seis letras, cada una con su nota de la melodía (assets/sounds/jingles/
-- startup.wav, tools/sounds/startup.py) → con el acorde final todo da un saltito, un brillo lo cruza y salen
-- destellos → funde a negro → título. Todo en PIXEL ART (escala entera).
-- La animación son cuadros ya dibujados (assets/startup/logo_anim.png + .json, el cielo y las estrellas): los
-- escribe tools/art/ui/make_mtvemo_logo.py --apply (el diseño D, "moneda arcade", que eligió el usuario).
-- Se salta con cualquier botón o tocando la pantalla (funde a negro enseguida). Solo sale al arrancar el juego.

local BaseState = require 'src/core/BaseState'
local json      = require 'libs/json'
local StartupState = BaseState:new()

local DIR = 'assets/startup/'
-- (noteAt / chordAt: la primera nota y el acorde, en s de la animación; chordAt - noteAt = CHORD_AT de
-- tools/sounds/startup.py, y las letras caen cada STEP)
local DATA = json.decode(love.filesystem.read(DIR .. 'logo_anim.json'))
StartupState.T_IN    = 0.6        -- s de negro al cielo (luego empieza la animación)
StartupState.T_FIRST = StartupState.T_IN + DATA.noteAt   -- s a los que aterriza la primera letra (y empieza la melodía)
StartupState.T_HOLD  = 0.5        -- s con el logo quieto al acabar la animación
StartupState.T_OUT   = 0.6        -- s de fundido a negro
StartupState.T_SKIP  = 0.25       -- … si se salta
local ANIM_DUR = #DATA.frames / DATA.fps

local art
local function loadArt()
    if art then return art end
    art = {}
    for _, k in ipairs({ 'logo_anim', 'sky', 'stars' }) do
        art[k] = love.graphics.newImage(DIR .. k .. '.png')
        art[k]:setFilter('nearest', 'nearest')                -- (pixel art: píxeles duros, escala entera)
    end
    art.stars:setWrap('repeat', 'repeat')
    local sw, sh = art.stars:getDimensions()
    art.starQuad = love.graphics.newQuad(0, 0, sw, sh, sw, sh)
    art.quads = {}
    local iw, ih = art.logo_anim:getDimensions()
    local n = 0
    for _, f in ipairs(DATA.frames) do n = math.max(n, f + 1) end
    for i = 0, n - 1 do
        art.quads[i] = love.graphics.newQuad((i % DATA.cols) * DATA.w, math.floor(i / DATA.cols) * DATA.h,
                                             DATA.w, DATA.h, iw, ih)
    end
    return art
end

function StartupState:enter(args)
    self.after = (args and args.after) or 'title'
    self.t, self.outAt, self.outDur, self.played = 0, nil, StartupState.T_OUT, false
    loadArt()
end

-- (la hoja de cuadros solo hace falta aquí: se suelta al salir)
function StartupState:exit()
    if art then for _, k in ipairs({ 'logo_anim', 'sky', 'stars' }) do art[k]:release() end end
    art = nil
end

function StartupState:total() return StartupState.T_IN + ANIM_DUR + StartupState.T_HOLD end

function StartupState:skip()
    if self.outAt then return end
    self.outAt, self.outDur = self.t, StartupState.T_SKIP
    if self.played then Sound.stopTracked('startup') end
    self.played = true                                    -- (si aún no había sonado, ya no suena)
end

function StartupState:update(dt)
    self.t = self.t + dt
    if not self.played and self.t >= StartupState.T_FIRST then
        self.played = true
        Sound.playTracked('startup')
    end
    if not self.outAt then
        if Input.pressed('confirm') or Input.pressed('flap') or Input.pressed('back') then self:skip()
        elseif self.t >= self:total() then self.outAt = self.t end
    elseif self.t >= self.outAt + self.outDur then
        gStateMachine:change(self.after)
    end
end

function StartupState:touchpressed() self:skip() end

function StartupState:render()
    local a, t = loadArt(), self.t
    local SW, SH = DATA.screen[1], DATA.screen[2]
    -- el cielo (franjas estiradas a toda la pantalla) y las estrellas, a escala ENTERA y repetidas a lo ancho
    local sc = math.max(1, math.floor(math.min(WINDOW_W / SW, WINDOW_H / SH)))
    local ox, oy = math.floor((WINDOW_W - SW * sc) / 2), math.floor((WINDOW_H - SH * sc) / 2)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(a.sky, 0, 0, 0, WINDOW_W, WINDOW_H / SH)
    local tx = ox - math.ceil(ox / (SW * sc)) * SW * sc
    local ty = oy - math.ceil(oy / (SH * sc)) * SH * sc
    a.starQuad:setViewport(0, 0, math.ceil((WINDOW_W - tx) / sc), math.ceil((WINDOW_H - ty) / sc))
    love.graphics.draw(a.stars, a.starQuad, tx, ty, 0, sc, sc)
    -- el cuadro de la animación de ahora (antes de empezar, nada; al acabar, el último)
    local u = t - StartupState.T_IN
    if u >= 0 then
        local f = DATA.frames[math.min(#DATA.frames, math.floor(u * DATA.fps) + 1)]
        love.graphics.draw(a.logo_anim, a.quads[f], ox + DATA.x * sc, oy + DATA.y * sc, 0, sc, sc)
    end
    -- fundidos: desde negro al empezar, a negro al acabar
    local black = math.max(0, 1 - t / StartupState.T_IN)
    if self.outAt then black = math.max(black, math.min(1, (t - self.outAt) / self.outDur)) end
    if black > 0 then
        love.graphics.setColor(0, 0, 0, black)
        love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return StartupState
