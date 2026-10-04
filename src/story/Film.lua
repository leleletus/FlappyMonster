-- src/story/Film.lua
-- Las CINEMÁTICAS de la historia ("El Espejo Roto": docs/historia/HISTORIA.md). Las dibuja el propio juego, con
-- sus sprites, fondos, decorados (niveles de verdad) y efectos: nada pregrabado.
--   · TIEMPOS: assets/story/films.json — cada escena dura `beats` pulsos a `bpm` y tiene sus `cues` (momentos,
--     en pulsos). Es la ÚNICA fuente: la música (tools/music/story_music.py) se compone sobre esos mismos tiempos.
--   · ESCENAS: src/story/films/<película>.lua → { [id de escena] = { enter(c), update(c, t, dt), draw(c, t),
--     events = { { cue = 'nombre' | beat = n, fn = function(c) end }, ... } } }. Las piezas con que se montan
--     (el monstruo, el espejo, el mapa, los decorados...) están en src/story/Stage.lua.
--   · Film.new(nombre, opts) → :update(dt), :draw(), :done(). Si suena su música, el reloj es el de la música
--     (imagen y sonido no se separan aunque el juego vaya a tirones).
-- `c` (el contexto que reciben las escenas): c.t (s dentro de la escena), c.dur, c.beat (s por pulso),
-- c.at(cue) (s), c.b(pulsos) (s), c.k(t0, t1) (0..1 entre dos tiempos), c.shared (lo que pasa de una escena a
-- la siguiente), c.v (lo de esta escena), c.xtra (Xtra extremo: 14 mitades), c.sfx(nombre, tono, volumen).
local json = require 'libs/json'

local Film = {}
Film.__index = Film

local DATA
function Film.data()
    if not DATA then DATA = json.decode(love.filesystem.read('assets/story/films.json')) end
    return DATA
end

-- La línea de tiempo de una película: { music, total, scenes = { { id, t0, dur, beat, beats, cues = { nombre = s }, enter = 'cut'... } } }
function Film.timeline(name)
    local def = Film.data()[name]
    if not def then return nil end
    local tl = { name = name, music = def.music, scenes = {}, total = 0 }
    for i, s in ipairs(def.scenes) do
        local beat = 60 / s.bpm
        local sc = { id = s.id, index = i, t0 = tl.total, dur = s.beats * beat, beat = beat, beats = s.beats, cues = {}, enter = s['in'] or 'cut' }
        for k, v in pairs(s.cues or {}) do sc.cues[k] = v * beat end
        tl.scenes[i] = sc
        tl.total = tl.total + sc.dur
    end
    return tl
end

local FADE = 0.4          -- lo que tarda en entrar una escena con fundido

function Film.new(name, opts)
    opts = opts or {}
    local tl = Film.timeline(name)
    local f = setmetatable({ name = name, tl = tl, impl = require('src/story/films/' .. name), t = 0, index = 0,
                             shared = {}, xtra = opts.xtra, mute = opts.mute }, Film)
    f.ctx = { film = f, shared = f.shared, xtra = opts.xtra, stage = require 'src/story/Stage' }
    f.ctx.sfx = function(sound, pitch, vol) if not f.mute then Sound.play(sound, pitch, vol) end end
    f.ctx.stage.reset()
    return f
end

function Film:scene() return self.tl.scenes[self.index] end
function Film:done() return self.t >= self.tl.total end

-- Entrar en la escena i (las anteriores sin entrar se entran también, en orden: cada una deja preparado lo
-- que la siguiente hereda)
function Film:_enter(i)
    local sc = self.tl.scenes[i]
    local c = self.ctx
    self.index = i
    c.scene, c.v, c.dur, c.beat, c.t = sc, {}, sc.dur, sc.beat, 0
    c.at = function(cue) return sc.cues[cue] or 0 end
    c.b = function(n) return n * sc.beat end
    c.k = function(t0, t1) return math.max(0, math.min(1, (c.t - t0) / math.max(1e-6, t1 - t0))) end
    self.fired = {}
    local S = self.impl[sc.id]
    if S and S.enter then S.enter(c) end
end

function Film:update(dt)
    if self:done() then return end
    -- el reloj: el de la música si suena la de esta película
    local t = self.t + dt
    if self.tl.music and not self.mute then
        local name, pos = Sound.musicPosition()
        if name == self.tl.music and pos and math.abs(pos - t) > 0.06 and pos > self.t - 0.5 then t = pos end
    end
    self.t = math.max(self.t, t)
    -- escena que toca
    local i = math.max(1, self.index)
    while self.tl.scenes[i + 1] and self.t >= self.tl.scenes[i + 1].t0 do i = i + 1 end
    while self.index < i do self:_enter(self.index + 1) end
    local sc, c = self.tl.scenes[self.index], self.ctx
    local prev = c.t
    c.t = math.min(sc.dur, self.t - sc.t0)
    local S = self.impl[sc.id]
    if S then
        for n, ev in ipairs(S.events or {}) do
            local at = ev.cue and (sc.cues[ev.cue] or 0) or (ev.beat or 0) * sc.beat
            if not self.fired[n] and c.t >= at then self.fired[n] = true; ev.fn(c) end
        end
        if S.update then S.update(c, c.t, c.t - prev) end
    end
    c.stage.update(dt)
end

function Film:draw()
    local sc, c = self.tl.scenes[self.index], self.ctx
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)
    if not sc then return end
    local S = self.impl[sc.id]
    love.graphics.setColor(1, 1, 1, 1)
    if S and S.draw then S.draw(c, c.t) end
    love.graphics.setShader()
    love.graphics.setBlendMode('alpha')
    -- cómo entra la escena: fundido desde negro o desde blanco
    if sc.enter ~= 'cut' and c.t < FADE then
        local v = (sc.enter == 'white') and 1 or 0
        love.graphics.setColor(v, v, v, 1 - c.t / FADE)
        love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)
    end
    -- el final de la película se funde a negro
    local left = self.tl.total - self.t
    if left < 0.6 then
        love.graphics.setColor(0, 0, 0, 1 - math.max(0, left) / 0.6)
        love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)
    end
    c.stage.bars()
    love.graphics.setColor(1, 1, 1, 1)
end

return Film
