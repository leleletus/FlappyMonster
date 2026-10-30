-- src/states/menu/FilmTestState.lua
-- FILM TEST secreto (para desarrolladores; el usuario, 2026-10-30: "un test de cinemática, de esta forma podré ver las
-- que quiera cuando quiera"): TODAS las cinemáticas de la historia, para verlas sueltas:
--   · las PELÍCULAS (assets/story/films.json: intro, persecución, guarida, final — con y sin todas las astillas —, créditos);
--   · las ESCENAS DEL MAPA de los secretos (StoryMapScenes.SCENES: el robo, los cangrejos que vuelven a crecer, la
--     bola que se rompe);
--   · las MICROCINEMÁTICAS DENTRO DEL JUEGO: la escena final de "La Huida del Espejo" (RunOut), la ENTRADA de cada
--     jefe en su arena (la del Espejo entre ellos: el nivel empieza con el jugador ya en la zona) y la intro del Mega
--     Mashup.
-- La lista sale de los CATÁLOGOS (films.json, SCENES, Worlds.LIST): una película o un jefe nuevos salen solos.
-- Se entra desde el SOUND TEST (◀ en la lista, o su botón); ◀ / ▶ pasan de uno a otro. Para ver las escenas que leen
-- la partida se monta una PARTIDA DE MENTIRA en memoria (Run.data sin hueco: Run.save no escribe nada) con lo que la
-- escena necesita, y al volver se deja la de antes como estaba.
local BaseState     = require 'src/core/BaseState'
local MenuScene     = require 'src/ui/menu/MenuScene'
local MenuKit       = require 'src/ui/menu/MenuKit'
local MenuButton    = require 'src/ui/menu/MenuButton'
local MenuAnim      = require 'src/ui/menu/MenuAnim'
local CornerButtons = require 'src/ui/CornerButtons'
local Clip          = require 'src/ui/Clip'
local fitText       = require('src/ui/TextUtil').fit
local L             = require 'src/core/Lang'
-- (los módulos de la HISTORIA, solo al usarlo: cargarlos al arrancar el juego — game.lua registra este estado — los
-- cargaba antes de que el juego montara su partida, y el arnés story_flow perdía la suya; el usuario, 2026-10-30)
local Worlds, Run, Save
local function story()
    Worlds, Run, Save = require 'src/story/Worlds', require 'src/story/Run', require 'src/story/Save'
end

local FilmTestState = BaseState:new()

local ROW_H, TOP, BOTTOM = 26, 132, 64
FilmTestState.last = 1                      -- (la fila elegida sigue ahí al volver de ver una)

-- ── La partida de mentira ─────────────────────────────────────────────────────────────────────────────────────────
-- `collect`: 'none' (sin astillas), 'all' (todas), 'stolen' (robadas por el Groove); `done`: todo superado
local savedRun
local function fakeRun(collect, extra)
    story()
    if not savedRun then savedRun = { slot = Run.slot, data = Run.data, had = true } end
    local d = Save.new('normal')
    for w = 1, Worlds.count() do
        local W = Worlds.get(w)
        for _, id in ipairs(W.levels) do d.done[id] = true end
        if W.boss then d.done[W.boss] = true end
    end
    local Shards = require 'src/story/Shards'
    for _, n in ipairs(Shards.ORDER) do d.shards[tostring(n)] = true end
    d.collect, d.found = {}, {}
    local Collect = require 'src/story/Collect'
    for _, c in ipairs(Collect.ofKind('splinter')) do
        if collect == 'all' then d.collect[c.id] = true elseif collect == 'stolen' then d.collect[c.id] = 'stolen' end
        if collect ~= 'none' and c.source and c.source.level then d.found[c.source.level] = true; d.done[c.source.level] = true end
    end
    if extra then extra(d) end
    Run.slot, Run.data = nil, d                                     -- (sin hueco: nada se escribe en disco)
    Run.filmTest = true
end
local function restoreRun()
    if not Run then return end
    if savedRun then Run.slot, Run.data = savedRun.slot, savedRun.data; savedRun = nil end
    Run.filmTest = nil
end

-- ── La lista (de los catálogos) ───────────────────────────────────────────────────────────────────────────────────
local function back() gStateMachine:change('film_test') end

local function items()
    story()
    local out = {}
    local function add(it) out[#out + 1] = it end
    -- Películas (films.json), en su orden de la historia; el final con y sin astillas (el Groove solo sale con todas)
    local Film = require 'src/story/Film'
    local order = { 'intro', 'chase', 'lair', 'ending', 'credits' }
    local seen = {}
    for _, id in ipairs(order) do if Film.data()[id] then seen[id] = true else seen[id] = false end end
    for id in pairs(Film.data()) do if id ~= '_' and seen[id] == nil then order[#order + 1] = id end end
    for _, id in ipairs(order) do
        if Film.data()[id] then
            local name = L.has('ft.film_' .. id) and L('ft.film_' .. id) or id
            local function go(collect)
                return function()
                    fakeRun(collect)
                    gStateMachine:change('story_film', { film = id, xtra = false, onDone = back })
                end
            end
            add({ group = 'film', id = id, name = name, desc = L.has('ft.desc_' .. id) and L('ft.desc_' .. id) or '', go = go('none') })
            if id == 'ending' then
                add({ group = 'film', id = id .. '_all', name = L('ft.film_ending_all'), desc = L('ft.desc_ending_all'), go = go('all') })
            end
        end
    end
    -- Escenas del mapa (StoryMapScenes.SCENES): cada una con la partida que la hace posible
    local SM = require('src/states/story/StoryMapState').SCENES or {}
    local sceneRun = { groove = 'all', regrow = 'stolen', disco = 'stolen' }
    local sceneOrder = { 'groove', 'regrow', 'disco' }
    for id in pairs(SM) do
        local known = false
        for _, s in ipairs(sceneOrder) do if s == id then known = true end end
        if not known then sceneOrder[#sceneOrder + 1] = id end
    end
    for _, id in ipairs(sceneOrder) do
        if SM[id] then
            add({ group = 'map', id = id, name = L.has('ft.scene_' .. id) and L('ft.scene_' .. id) or id,
                  desc = L.has('ft.desc_scene_' .. id) and L('ft.desc_scene_' .. id) or '',
                  go = function()
                      fakeRun(sceneRun[id] or 'all', function(d) d.films = {} end)
                      gStateMachine:change('story_map', { scene = id, sceneDone = back })
                  end })
        end
    end
    -- Dentro del juego: las escenas finales que enlazan (Worlds `outros`), la entrada de cada jefe, el Mashup
    for w = 1, Worlds.count() do
        local W = Worlds.get(w)
        for id, col in pairs(W.outros or {}) do
            add({ group = 'game', id = 'outro_' .. id, name = L('ft.outro'):gsub('{name}', Worlds.levelName(id)), desc = L('ft.desc_outro'),
                  go = function()
                      fakeRun('none')
                      gStateMachine:change('adventure', { level = Worlds.path(id), returnTo = 'film_test', outro = Worlds.outro(id),
                          onFinish = back,
                          onReady = function(st)                        -- (adelanta la carrera hasta justo antes de la escena)
                              local a = st.level.autoScroll
                              if a then
                                  a.state, a.x = 'run', (col - 1) * TILE_PX - 40
                                  st.player.x, st.player.vx, st.player.vy = a.x + 500, 0, 0
                                  st.player.spawnX = st.player.x
                              end
                              st.startCd = nil
                          end })
                  end })
        end
    end
    local function bossEntry(id)
        add({ group = 'game', id = 'boss_' .. id, name = L('ft.boss_entry'):gsub('{name}', Worlds.levelName(id)), desc = L('ft.desc_boss_entry'),
              go = function()
                  fakeRun('none')
                  gStateMachine:change('adventure', { level = Worlds.path(id), returnTo = 'film_test',
                      onReady = function(st)                            -- (el jugador, ya dentro de la arena: empieza la entrada)
                          local z = st.level.bossZones and st.level.bossZones[1]
                          if z then
                              local x, y = require('src/world/systems/BossZones').safeSpawn(st.level, z)
                              if x then st.player.x, st.player.y, st.player.vx, st.player.vy = x, y, 0, 0; st.player.spawnX, st.player.spawnY = x, y end
                          end
                          st.startCd = nil
                      end })
              end })
    end
    for w = 1, Worlds.count() do
        local W = Worlds.get(w)
        if W.boss then bossEntry(W.boss) end
        for _, s in ipairs(W.secrets or {}) do if s.level then bossEntry(s.level) end end
    end
    add({ group = 'game', id = 'mashup_intro', name = L('ft.mashup_intro'), desc = L('ft.desc_mashup_intro'),
          go = function()
              fakeRun('stolen')
              gStateMachine:change('adventure', { level = Worlds.path('mashup_cangrejos'), returnTo = 'film_test',
                                                  onReady = function(st) st.startCd = nil end })
          end })
    return out
end
FilmTestState.items = items

-- ── Ciclo de vida ─────────────────────────────────────────────────────────────────────────────────────────────────
function FilmTestState:enter()
    Sound.stopMusic()
    Sound.stopAllTracked()
    restoreRun()
    self.list = items()
    self.sel = math.max(1, math.min(#self.list, FilmTestState.last))
    self.scroll, self.scrollTarget = 0, 0
    self.anim, self.t = MenuAnim.new(), 0
    self:_keepVisible()
    self.scroll = self.scrollTarget
end

function FilmTestState:_item() return self.list[self.sel] end

function FilmTestState:_layout()
    local m = 24
    local listW = math.floor((WINDOW_W - 3 * m) * 0.55)
    local list = { x = m, y = TOP, w = listW, h = WINDOW_H - TOP - BOTTOM }
    local ox = m * 2 + listW
    local optW = WINDOW_W - ox - m
    local info = { x = ox, y = TOP, w = optW, h = 150 }
    return { list = list, info = info,
             play = { x = info.x + info.w - 64, y = info.y + 10, w = 52, h = 44 },
             sound = { x = ox, y = TOP + 170, w = optW, h = 48 } }
end

function FilmTestState:_keepVisible()
    local Ly = self:_layout()
    local view = Ly.list.h - 16
    local y = (self.sel - 1) * ROW_H
    local s = self.scrollTarget
    if y < s then s = y end
    if y + ROW_H > s + view then s = y + ROW_H - view end
    self.scrollTarget = math.max(0, s)
end

function FilmTestState:_move(d)
    local n = #self.list
    if n == 0 then return end
    local s = math.max(1, math.min(n, self.sel + d))
    if s ~= self.sel then self.sel = s; Sound.play('select'); self:_keepVisible() end
end

-- Ver la elegida (la fila se recuerda para la vuelta)
function FilmTestState:_watch()
    local it = self:_item()
    if not it then return end
    FilmTestState.last = self.sel
    Sound.play('select')
    it.go()
end

function FilmTestState:_toSound() Sound.play('select'); gStateMachine:change('sound_test') end
function FilmTestState:_exit() Sound.play('select'); gStateMachine:change('title', { menu = true }) end

function FilmTestState:update(dt)
    MenuScene.update(dt)
    self.anim:update(dt)
    self.t = self.t + dt
    if Input.pressed('nav_up') then self:_move(-1) end
    if Input.pressed('nav_down') then self:_move(1) end
    if Input.pressed('nav_left') or Input.pressed('nav_right') or Input.pressed('light') then self:_toSound() end
    if Input.pressed('confirm') or Input.pressed('flap') then self:_watch() end
    if Input.pressed('back') then self:_exit() end
    self.scroll = self.scroll + (self.scrollTarget - self.scroll) * math.min(1, dt * 14)
end

-- ── Ratón / táctil ────────────────────────────────────────────────────────────────────────────────────────────────
local function inside(r, x, y) return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end
function FilmTestState:_rowAt(x, y)
    local Ly = self:_layout()
    if not inside(Ly.list, x, y) then return nil end
    local i = math.floor((y - Ly.list.y - 8 + self.scroll) / ROW_H) + 1
    return (i >= 1 and i <= #self.list) and i or nil
end
function FilmTestState:wheelmoved(dx, dy)
    local Ly = self:_layout()
    self.scrollTarget = math.max(0, math.min(math.max(0, #self.list * ROW_H - Ly.list.h + 16), self.scrollTarget - dy * 80))
end
function FilmTestState:mousemoved(x, y)
    self.backHover = CornerButtons.hitBack(x, y)
    local Ly = self:_layout()
    self.hoverPlay, self.hoverSound = inside(Ly.play, x, y), inside(Ly.sound, x, y)
    local row = self:_rowAt(x, y)
    if row and self.sel ~= row then self.sel = row; Sound.play('select') end
end
function FilmTestState:touchpressed(id, x, y)
    if CornerButtons.hitBack(x, y) then self:_exit(); return end
    local Ly = self:_layout()
    if inside(Ly.play, x, y) or inside(Ly.info, x, y) then self:_watch(); return end
    if inside(Ly.sound, x, y) then self:_toSound(); return end
    local row = self:_rowAt(x, y)
    if row then self.touch = { id = id, y = y, lastY = y, row = row, moved = false } end
end
function FilmTestState:touchmoved(id, x, y)
    local tc = self.touch
    if not tc or tc.id ~= id then return end
    if math.abs(y - tc.y) > 10 then tc.moved = true end
    if tc.moved then
        local Ly = self:_layout()
        self.scrollTarget = math.max(0, math.min(math.max(0, #self.list * ROW_H - Ly.list.h + 16), self.scrollTarget - (y - tc.lastY)))
        self.scroll = self.scrollTarget
    end
    tc.lastY = y
end
function FilmTestState:touchreleased(id, x, y)
    local tc = self.touch
    if not tc or tc.id ~= id then return end
    self.touch = nil
    if tc.moved then return end
    -- (tocar una fila la elige; tocar la elegida la ve)
    if self.sel == tc.row then self:_watch() else self.sel = tc.row; Sound.play('select') end
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────────────────────────────────────────
local GROUP_COLOR = { film = { 1, 0.86, 0.36 }, map = { 0.6, 0.9, 1 }, game = { 0.75, 1, 0.65 } }
function FilmTestState:render()
    MenuScene.backdrop('sound')
    MenuKit.dim(0.45)
    local A = self.anim
    MenuKit.title('FILM TEST', 'teal', A, 1, 5)
    local Ly = self:_layout()
    local Lr = Ly.list
    MenuKit.text(FONT_SMALL, L('ft.tab') .. '  (' .. #self.list .. ')', Lr.x, Lr.y - 22, Lr.w, 'left', { 1, 0.86, 0.36 })
    MenuKit.box('well', Lr.x, Lr.y, Lr.w, Lr.h)
    Clip.push(Lr.x + 4, Lr.y + 4, Lr.w - 8, Lr.h - 8)
    local i0 = math.max(1, math.floor(self.scroll / ROW_H))
    local i1 = math.min(#self.list, i0 + math.ceil(Lr.h / ROW_H) + 1)
    for i = i0, i1 do
        local it = self.list[i]
        local y = math.floor(Lr.y + 8 + (i - 1) * ROW_H - self.scroll)
        local isSel = i == self.sel
        if isSel then
            love.graphics.setColor(1, 0.86, 0.36, 0.28)
            love.graphics.rectangle('fill', Lr.x + 8, y - 2, Lr.w - 16, ROW_H - 2)
        end
        local tag = L('ft.group_' .. it.group)
        MenuKit.text(FONT_SMALL, tag, Lr.x + 14, y + 4, 110, 'left', GROUP_COLOR[it.group] or { 1, 1, 1 })
        MenuKit.text(FONT_SMALL, fitText(FONT_SMALL, it.name, Lr.w - 140), Lr.x + 124, y + 4, Lr.w - 140, 'left',
                     isSel and { 1, 1, 1 } or { 0.72, 0.78, 0.95 })
    end
    Clip.pop()
    -- La elegida: nombre, qué es y cómo se ve en el juego; el botón ▶
    local I = Ly.info
    MenuKit.box('card', I.x, I.y, I.w, I.h)
    local it = self:_item()
    if it then
        local tw = I.w - 96
        MenuKit.text(FONT_MED, fitText(FONT_MED, it.name, tw), I.x + 16, I.y + 14, tw, 'left', { 1, 1, 1 })
        MenuKit.text(FONT_SMALL, L('ft.group_' .. it.group) .. '  ·  ' .. it.id, I.x + 16, I.y + 40, tw, 'left', { 0.7, 0.76, 0.92 })
        MenuKit.text(FONT_SMALL, it.desc, I.x + 16, I.y + 66, I.w - 32, 'left', { 0.85, 0.88, 1 })
        local P = Ly.play
        MenuButton.draw(nil, P.x, P.y, P.w, P.h, 'green', self.hoverPlay, {})
        love.graphics.setColor(1, 1, 1, 1)
        local cx, cy = P.x + P.w / 2, P.y + (P.h - 4) / 2
        love.graphics.polygon('fill', cx - 7, cy - 10, cx - 7, cy + 10, cx + 10, cy)
    end
    local S = Ly.sound
    MenuButton.draw(L('ft.to_sound'), S.x, S.y, S.w, S.h, self.hoverSound and 'teal' or 'blue', self.hoverSound, { scale = 3 })
    MenuKit.hint(L('ft.hint'), A, 3)
    CornerButtons.drawBack(self.backHover)
end

return FilmTestState
