-- src/states/menu/SoundTestState.lua
-- SOUND TEST secreto (para desarrolladores): todas las pistas de música (assets/music/index.json) y todos los efectos
-- que carga Sound, para escucharlos con opciones: repetir, tono, volumen, eco y sala (reverberación), y avanzar /
-- retroceder en la pista. Se entra desde el TÍTULO (TitleState): ↑ ↑ ↓ ↓ ← → ← → con las flechas o la cruceta, o
-- tocando 7 veces seguidas la versión (abajo a la derecha) en el móvil.
--
-- Suena con sus PROPIAS fuentes (no toca la música ni las voces del juego): la música, desde sus archivos (con su
-- intro y su bucle, como en el juego); los efectos, copias de los de Sound (con su ganancia ya aplicada).
local BaseState    = require 'src/core/BaseState'
local MenuScene    = require 'src/ui/menu/MenuScene'
local MenuKit      = require 'src/ui/menu/MenuKit'
local MenuAnim     = require 'src/ui/menu/MenuAnim'
local CornerButtons = require 'src/ui/CornerButtons'
local Clip         = require 'src/ui/Clip'
local Music        = require 'src/audio/Music'
local fitText      = require('src/ui/TextUtil').fit
local L            = require 'src/core/Lang'

local SoundTestState = BaseState:new()

local ROW_H, TOP, BOTTOM = 26, 132, 64
local OPTS = { 'list', 'loop', 'pitch', 'volume', 'echo', 'room', 'pos' }
local ECHO = {                                  -- (love.audio: efectos de OpenAL; sin ellos, "no disponible")
    false,
    { type = 'echo', delay = 0.12, tapdelay = 0.18, damping = 0.4, feedback = 0.35, spread = -0.5, volume = 0.8 },
    { type = 'echo', delay = 0.2, tapdelay = 0.32, damping = 0.2, feedback = 0.6, spread = -0.8, volume = 1 },
}
local ROOM = {
    false,
    { type = 'reverb', decaytime = 2.2, density = 0.7, diffusion = 0.8, gain = 0.4, highgain = 0.6, volume = 1 },
    { type = 'reverb', decaytime = 6.5, density = 1, diffusion = 1, gain = 0.5, highgain = 0.4, volume = 1 },
}
local FX_OK = love.audio.isEffectsSupported and love.audio.isEffectsSupported() or false

local function fmtTime(s, dur)
    s = math.max(0, s or 0)
    if (dur or s) < 10 then return string.format('%.1f s', s) end          -- (efectos cortos: décimas)
    return string.format('%d:%02d', math.floor(s / 60), math.floor(s % 60))
end

-- ── Listas ───────────────────────────────────────────────────────────────────
local function musicItems()
    local out = {}
    for _, tr in ipairs(Music.list) do
        if not tr.pending then
            out[#out + 1] = { id = tr.id, name = tr.name, music = tr, volume = tr.volume or 0.7,
                              path = tr.file or tr.intro or tr.loopFile }
        end
    end
    return out
end
local function sfxItems()
    local out = {}
    for name, path in pairs(Sound._origin) do
        if not Music.byId[name] then out[#out + 1] = { id = name, name = name, path = path, volume = 1 } end
    end
    table.sort(out, function(a, b) return a.id:lower() < b.id:lower() end)
    return out
end

-- ── Ciclo de vida ────────────────────────────────────────────────────────────
function SoundTestState:enter()
    Sound.stopMusic()
    Sound.stopAllTracked()
    self.lists = { musicItems(), sfxItems() }
    self.tab, self.sel, self.scroll, self.scrollTarget = 1, { 1, 1 }, { 0, 0 }, { 0, 0 }
    self.focus, self.opt = 'list', 1
    self.loop, self.pitch, self.vol, self.echo, self.room = true, 1.0, nil, 1, 1
    self.anim, self.t = MenuAnim.new(), 0
    if FX_OK then
        for i, e in ipairs(ECHO) do if e then love.audio.setEffect('st_echo' .. i, e) end end
        for i, r in ipairs(ROOM) do if r then love.audio.setEffect('st_room' .. i, r) end end
    end
end

function SoundTestState:exit()
    self:_stop()
    if FX_OK then
        for i in ipairs(ECHO) do pcall(love.audio.setEffect, 'st_echo' .. i, false) end
        for i in ipairs(ROOM) do pcall(love.audio.setEffect, 'st_room' .. i, false) end
    end
end

function SoundTestState:_items() return self.lists[self.tab] end
function SoundTestState:_item() return self:_items()[self.sel[self.tab]] end

-- ── Sonar ────────────────────────────────────────────────────────────────────
function SoundTestState:_stop()
    for _, s in ipairs({ self.src, self.loopSrc }) do pcall(function() s:stop() end) end
    self.src, self.loopSrc, self.playing = nil, nil, nil
end

-- Volumen, tono, repetir y efectos a la fuente que suena (también al cambiarlos mientras suena)
function SoundTestState:_apply(src)
    if not src then return end
    local it = self.playing
    src:setPitch(self.pitch)
    src:setVolume(self.vol or (it and it.volume) or 1)
    if src ~= self.src or not self.loopSrc then src:setLooping(self.loop) end
    if FX_OK then
        for i in ipairs(ECHO) do if ECHO[i] then pcall(src.setEffect, src, 'st_echo' .. i, self.echo == i) end end
        for i in ipairs(ROOM) do if ROOM[i] then pcall(src.setEffect, src, 'st_room' .. i, self.room == i) end end
    end
end

function SoundTestState:_play(it)
    self:_stop()
    if not it then return end
    local ok
    if it.music then
        local tr = it.music
        ok = pcall(function()
            if tr.intro then
                self.src = love.audio.newSource(tr.intro, 'stream')
                self.loopSrc = tr.loopFile and love.audio.newSource(tr.loopFile, 'stream') or nil
            else
                self.src = love.audio.newSource(tr.file or tr.loopFile, 'stream')
            end
        end)
    else
        local base = Sound.source(it.id)
        ok = base ~= nil
        if ok then self.src = base:clone() end
    end
    if not ok or not self.src then self.src = nil; return end
    self.playing = it
    self:_apply(self.src)
    if self.loopSrc then self.loopSrc:setLooping(true); self:_apply(self.loopSrc); self.src:setLooping(false) end
    self.src:play()
end

function SoundTestState:_toggle()
    local it = self:_item()
    if self.playing == it and self:_current() then self:_stop() else self:_play(it) end
end

-- La fuente que suena ahora (la intro o, pasada, el bucle)
function SoundTestState:_current()
    if self.loopSrc and self.loopSrc:isPlaying() then return self.loopSrc end
    if self.src and self.src:isPlaying() then return self.src end
    return nil
end

-- ── Opciones ─────────────────────────────────────────────────────────────────
function SoundTestState:_change(o, d)
    local k = OPTS[o]
    if k == 'list' then
        self.tab = (self.tab == 1) and 2 or 1
    elseif k == 'loop' then
        self.loop = not self.loop
    elseif k == 'pitch' then
        self.pitch = math.max(0.25, math.min(3, math.floor((self.pitch + d * 0.05) * 100 + 0.5) / 100))
    elseif k == 'volume' then
        local it = self.playing or self:_item()
        local v = self.vol or (it and it.volume) or 1
        self.vol = math.max(0, math.min(1, math.floor((v + d * 0.05) * 100 + 0.5) / 100))
    elseif k == 'echo' then
        if not FX_OK then return end
        self.echo = (self.echo - 1 + d) % #ECHO + 1
    elseif k == 'room' then
        if not FX_OK then return end
        self.room = (self.room - 1 + d) % #ROOM + 1
    elseif k == 'pos' then
        local s = self:_current()
        if s then
            local dur = s:getDuration() or 0
            pcall(s.seek, s, math.max(0, math.min(math.max(0, dur - 0.05), s:tell() + d * 5)))
        end
    end
    Sound.play('select', d > 0 and 1.06 or 0.94)
    self:_apply(self.src); self:_apply(self.loopSrc)
    if self.loopSrc and self.src then self.src:setLooping(false) end
end

function SoundTestState:_value(o)
    local k = OPTS[o]
    if k == 'list' then return L(self.tab == 1 and 'st.tab_music' or 'st.tab_sfx')
    elseif k == 'loop' then return L(self.loop and 'st.yes' or 'st.no')
    elseif k == 'pitch' then return string.format('%.2f', self.pitch)
    elseif k == 'volume' then
        local it = self.playing or self:_item()
        return string.format('%d %%', math.floor((self.vol or (it and it.volume) or 1) * 100 + 0.5))
    elseif k == 'echo' then return FX_OK and L('st.echo_' .. self.echo) or L('st.no_fx')
    elseif k == 'room' then return FX_OK and L('st.room_' .. self.room) or L('st.no_fx')
    elseif k == 'pos' then
        local s = self:_current()
        local dur = s and s:getDuration()
        return s and (fmtTime(s:tell(), dur) .. ' / ' .. fmtTime(dur)) or '-'
    end
end

-- ── Geometría (calculada al dibujar: el ancho lógico cambia) ────────────────
function SoundTestState:_layout()
    local m = 40
    local listW = math.floor((WINDOW_W - 3 * m) * 0.5)
    local list = { x = m, y = TOP, w = listW, h = WINDOW_H - TOP - BOTTOM }
    local ox = m * 2 + listW
    local optW = WINDOW_W - ox - m
    local opts = {}
    for i = 1, #OPTS do opts[i] = { x = ox, y = TOP + 96 + (i - 1) * 58, w = optW, h = 48 } end
    return { list = list, opts = opts, info = { x = ox, y = TOP, w = optW, h = 84 } }
end

function SoundTestState:_keepVisible()
    local Ly = self:_layout()
    local view = Ly.list.h - 16
    local y = (self.sel[self.tab] - 1) * ROW_H
    local s = self.scrollTarget[self.tab]
    if y < s then s = y end
    if y + ROW_H > s + view then s = y + ROW_H - view end
    self.scrollTarget[self.tab] = math.max(0, s)
end

function SoundTestState:_move(d)
    local n = #self:_items()
    if n == 0 then return end
    local s = math.max(1, math.min(n, self.sel[self.tab] + d))
    if s ~= self.sel[self.tab] then self.sel[self.tab] = s; Sound.play('select'); self:_keepVisible() end
end

-- ── Update ───────────────────────────────────────────────────────────────────
function SoundTestState:update(dt)
    MenuScene.update(dt)
    self.anim:update(dt)
    self.t = self.t + dt
    -- intro → bucle (como Sound.update con la música del juego)
    if self.loopSrc and self.src and not self.src:isPlaying() and not self.loopSrc:isPlaying() and self.playing then
        if self.loop then self.loopSrc:play() else self.playing = nil end
    elseif self.playing and not self:_current() and not self.loopSrc then
        self.playing = nil
    end
    if self.focus == 'list' then
        if Input.pressed('nav_up') then self:_move(-1) end
        if Input.pressed('nav_down') then self:_move(1) end
        if Input.pressed('nav_right') then self.focus = 'opts'; Sound.play('select') end
        if Input.pressed('light') then self:_change(1, 1) end                       -- (atajo: música / efectos)
        if Input.pressed('confirm') or Input.pressed('flap') then self:_toggle() end
        if Input.pressed('back') then Sound.play('select'); gStateMachine:change('title', { menu = true }) end
    else
        if Input.pressed('nav_up') then self.opt = (self.opt - 2) % #OPTS + 1; Sound.play('select') end
        if Input.pressed('nav_down') then self.opt = self.opt % #OPTS + 1; Sound.play('select') end
        if Input.pressed('nav_left') then self:_change(self.opt, -1) end
        if Input.pressed('nav_right') then self:_change(self.opt, 1) end
        if Input.pressed('confirm') or Input.pressed('flap') then self:_toggle() end
        if Input.pressed('back') then self.focus = 'list'; Sound.play('select') end
    end
    local sc, st = self.scroll, self.scrollTarget
    sc[self.tab] = sc[self.tab] + (st[self.tab] - sc[self.tab]) * math.min(1, dt * 14)
end

-- ── Ratón / táctil ───────────────────────────────────────────────────────────
local function inside(r, x, y) return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end

function SoundTestState:_rowAt(x, y)
    local Ly = self:_layout()
    if not inside(Ly.list, x, y) then return nil end
    local i = math.floor((y - Ly.list.y - 8 + self.scroll[self.tab]) / ROW_H) + 1
    return (i >= 1 and i <= #self:_items()) and i or nil
end

function SoundTestState:wheelmoved(dx, dy)
    local n = #self:_items()
    local Ly = self:_layout()
    self.scrollTarget[self.tab] = math.max(0, math.min(math.max(0, n * ROW_H - Ly.list.h + 16), self.scrollTarget[self.tab] - dy * 80))
end

function SoundTestState:mousemoved(x, y) self.backHover = CornerButtons.hitBack(x, y) end

function SoundTestState:touchpressed(id, x, y)
    if CornerButtons.hitBack(x, y) then gStateMachine:change('title', { menu = true }); return end
    local Ly = self:_layout()
    for i, r in ipairs(Ly.opts) do
        if inside(r, x, y) then
            self.focus, self.opt = 'opts', i
            self:_change(i, MenuKit.stepperSide(r, x))
            return
        end
    end
    if inside(Ly.info, x, y) then self:_toggle(); return end
    if self:_rowAt(x, y) then self.touch = { id = id, y = y, lastY = y, row = self:_rowAt(x, y), moved = false } end
end

function SoundTestState:touchmoved(id, x, y)
    local tc = self.touch
    if not tc or tc.id ~= id then return end
    if math.abs(y - tc.y) > 10 then tc.moved = true end
    if tc.moved then
        local n = #self:_items()
        local Ly = self:_layout()
        local s = self.scrollTarget[self.tab] - (y - tc.lastY)
        self.scrollTarget[self.tab] = math.max(0, math.min(math.max(0, n * ROW_H - Ly.list.h + 16), s))
        self.scroll[self.tab] = self.scrollTarget[self.tab]
    end
    tc.lastY = y
end

function SoundTestState:touchreleased(id, x, y)
    local tc = self.touch
    if not tc or tc.id ~= id then return end
    self.touch = nil
    if tc.moved then return end
    -- (tocar una fila: la elige y suena; tocar la que suena: la para)
    self.sel[self.tab], self.focus = tc.row, 'list'
    self:_toggle()
end

-- ── Dibujo ───────────────────────────────────────────────────────────────────
function SoundTestState:render()
    MenuScene.backdrop()
    MenuKit.dim(0.45)
    local A = self.anim
    MenuKit.title('SOUND TEST', 'teal', A, 1, 5)
    local Ly = self:_layout()

    -- Lista (con su pestaña arriba)
    local Lr = Ly.list
    MenuKit.text(FONT_SMALL, L(self.tab == 1 and 'st.tab_music' or 'st.tab_sfx') .. '  (' .. #self:_items() .. ')',
                 Lr.x, Lr.y - 22, Lr.w, 'left', { 1, 0.86, 0.36 })
    MenuKit.box('well', Lr.x, Lr.y, Lr.w, Lr.h)
    Clip.push(Lr.x + 4, Lr.y + 4, Lr.w - 8, Lr.h - 8)
    local items, sel, scroll = self:_items(), self.sel[self.tab], self.scroll[self.tab]
    local i0 = math.max(1, math.floor(scroll / ROW_H))
    local i1 = math.min(#items, i0 + math.ceil(Lr.h / ROW_H) + 1)
    for i = i0, i1 do
        local it = items[i]
        local y = math.floor(Lr.y + 8 + (i - 1) * ROW_H - scroll)
        local isSel, isPlay = i == sel, self.playing == it
        if isSel then
            love.graphics.setColor(1, 0.86, 0.36, self.focus == 'list' and 0.28 or 0.14)
            love.graphics.rectangle('fill', Lr.x + 8, y - 2, Lr.w - 16, ROW_H - 2)
        end
        local label = (isPlay and '> ' or '  ') .. it.name .. ((it.name ~= it.id) and ('  ·  ' .. it.id) or '')
        MenuKit.text(FONT_SMALL, fitText(FONT_SMALL, label, Lr.w - 28), Lr.x + 14, y + 4, Lr.w - 28, 'left',
                     isPlay and { 0.5, 1, 0.6 } or (isSel and { 1, 1, 1 } or { 0.72, 0.78, 0.95 }))
    end
    Clip.pop()

    -- Lo que suena / lo elegido
    local I = Ly.info
    MenuKit.box('card', I.x, I.y, I.w, I.h)
    local it = self.playing or self:_item()
    if it then
        local s = self:_current()
        MenuKit.text(FONT_MED, fitText(FONT_MED, it.name, I.w - 32), I.x + 16, I.y + 14, I.w - 32, 'left',
                     s and { 0.5, 1, 0.6 } or { 1, 1, 1 })
        MenuKit.text(FONT_SMALL, fitText(FONT_SMALL, (s and L('st.playing') or L('st.stopped')) .. '  ·  ' .. (it.path or ''), I.w - 32),
                     I.x + 16, I.y + 42, I.w - 32, 'left', { 0.7, 0.76, 0.92 })
        if s then
            local dur = s:getDuration() or 0
            local k = dur > 0 and math.min(1, s:tell() / dur) or 0
            love.graphics.setColor(0, 0, 0, 0.5)
            love.graphics.rectangle('fill', I.x + 16, I.y + 64, I.w - 32, 8)
            love.graphics.setColor(1, 0.86, 0.36, 1)
            love.graphics.rectangle('fill', I.x + 16, I.y + 64, math.floor((I.w - 32) * k), 8)
            love.graphics.setColor(1, 1, 1, 1)
        end
    end

    -- Opciones (◀ valor ▶)
    for o, r in ipairs(Ly.opts) do
        local selO = self.focus == 'opts' and self.opt == o
        MenuKit.stepper(L('st.opt_' .. OPTS[o]) .. ':', self:_value(o), r, selO and 'teal' or 'blue', selO, { scale = 3 })
        if selO then MenuKit.marker(r.x, r.y, r.w, r.h, self.t) end
    end

    MenuKit.hint(L(self.focus == 'list' and 'st.hint_list' or 'st.hint_opts'), A, 3)
    CornerButtons.drawBack(self.backHover)
end

return SoundTestState
