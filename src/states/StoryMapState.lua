-- src/states/StoryMapState.lua
-- MODO HISTORIA: el MAPA. Un mundo por pantalla: un camino de NODOS (sus niveles en orden) que
-- acaba en el nodo del JEFE. El monstruo se mueve de nodo en nodo; ENTER entra en el nivel.
--   superado = dorado con su marca · abierto = blanco · cerrado = gris con candado
--   ← → mueve por el camino · ↑ ↓ (o las flechas de los lados) cambia de mundo, si está abierto
-- Los niveles se abren en orden y el mundo siguiente al vencer al jefe (src/story/Run.lua); el
-- orden de mundos y niveles son datos (src/story/Worlds.lua). Al superar un nivel
-- (AdventureState `onFinish`) se apunta, se guarda y se vuelve aquí, ya en el nodo siguiente.
-- La geometría se calcula al dibujar (WINDOW_W cambia: PC, móvil, Switch).
local BaseState     = require 'src/BaseState'
local CornerButtons = require 'src/ui/CornerButtons'
local PixelFont     = require 'src/ui/PixelFont'
local PixelIcons    = require 'src/ui/PixelIcons'
local Run           = require 'src/story/Run'
local Worlds        = require 'src/story/Worlds'
local Difficulty    = require 'src/Difficulty'
local L = require 'src/Lang'

local StoryMapState = BaseState:new()

local NODE, BOSS = 54, 74                 -- lado del nodo (y del jefe)
local PATH_Y = 0.52                       -- altura del camino (fracción de la pantalla)
-- Color de cada mundo (cielo de su mapa)
local THEME = {
    pradera = { 0.36, 0.62, 0.36 }, costa = { 0.25, 0.6, 0.72 }, fortaleza = { 0.42, 0.36, 0.44 },
    nieve = { 0.6, 0.75, 0.88 }, cuevas = { 0.2, 0.2, 0.32 }, final = { 0.5, 0.22, 0.2 },
}

local imgBg, imgHero
local function loadAssets()
    if imgBg then return end
    imgBg = love.graphics.newImage('assets/images/menus/MenuDif.png')
    imgHero = love.graphics.newImage('assets/images/player/icon.png')
    imgHero:setFilter('nearest', 'nearest')
end

-- Centro del nodo k de un mundo de n nodos: repartidos a lo ancho, en zigzag suave
local function nodePos(k, n)
    local margin = math.max(90, WINDOW_W * 0.12)
    local x = (n == 1) and WINDOW_W / 2 or (margin + (WINDOW_W - 2 * margin) * (k - 1) / (n - 1))
    local y = WINDOW_H * PATH_Y + ((k % 2 == 0) and -46 or 46)
    return math.floor(x), math.floor(y)
end

function StoryMapState:enter(args)
    loadAssets()
    if not Run.active() then gStateMachine:change('story_slots'); return end
    args = args or {}
    local w, k = Run.frontier()
    self.world = args.world or Run.data.world or w
    if not Run.worldOpen(self.world) then self.world = w end
    self.node = args.node or ((self.world == w) and k or Run.data.node or 1)
    self.node = math.max(1, math.min(#Worlds.nodes(self.world), self.node))
    self.t, self.hop, self.shake = 0, 1, 0
    self.heroX, self.heroY = nodePos(self.node, #Worlds.nodes(self.world))
    self.justCleared = args.cleared               -- (acaba de superar ese nivel: destello)
    self.notice, self.noticeT = args.notice, 0    -- (aviso un momento: tras un Game Over)
    Sound.playMusic('menus')
end

function StoryMapState:_remember()
    Run.data.world, Run.data.node = self.world, self.node
    Run.save()
end

function StoryMapState:_move(d)
    local n = #Worlds.nodes(self.world)
    local k = self.node + d
    if k < 1 or k > n then return end
    self.node, self.hop = k, 0
    Sound.play('select')
end

function StoryMapState:_world(d)
    local w = self.world + d
    if w < 1 or w > Worlds.count() then return end
    if not Run.worldOpen(w) then self.shake = 0.3; Sound.play('headBump'); return end
    self.world = w
    self.node = (d > 0) and 1 or #Worlds.nodes(w)
    self.heroX, self.heroY = nodePos(self.node, #Worlds.nodes(w))
    Sound.play('select')
end

function StoryMapState:_play()
    local st = Run.state(self.world, self.node)
    if st == 'locked' then self.shake = 0.3; Sound.play('headBump'); return end
    local nodes = Worlds.nodes(self.world)
    local n = nodes[self.node]
    local world, node = self.world, self.node
    self:_remember()
    Sound.play('select')
    gStateMachine:change('adventure', {
        level = Worlds.path(n.id), returnTo = 'story_map', difficulty = Run.data.difficulty,
        -- las VIDAS son de la aventura: entran con las que lleva y, salga como salga, se guardan
        lives = Run.data.lives,
        onLeave = function(lives) Run.setLives(lives) end,
        gameOverNote = L(Difficulty.of(Run.data.difficulty, 'restartGame', false) and 'story.go_game' or 'story.go_world'),
        onGameOver = function()
            local w = Run.gameOver(world)                 -- al principio del mundo (o del juego)
            gStateMachine:change('story_map', { world = w, node = 1, notice = 'story.go_notice' })
        end,
        onFinish = function(result)
            Run.complete(n.id, result)
            -- de vuelta al mapa, ya en el siguiente (tras el jefe: al mundo que se abre)
            local nw, nk = world, math.min(#nodes, node + 1)
            if node == #nodes and Run.worldOpen(world + 1) then nw, nk = world + 1, 1 end
            Run.data.world, Run.data.node = nw, nk
            Run.save()
            gStateMachine:change('story_map', { world = nw, node = nk, cleared = n.id })
        end,
    })
end

function StoryMapState:_back()
    self:_remember()
    Sound.play('select')
    gStateMachine:change('story_slots')
end

function StoryMapState:update(dt)
    self.t = self.t + dt
    self.noticeT = (self.noticeT or 0) + dt
    self.hop = math.min(1, self.hop + dt * 5)
    self.shake = math.max(0, self.shake - dt)
    local tx, ty = nodePos(self.node, #Worlds.nodes(self.world))
    self.heroX = self.heroX + (tx - self.heroX) * math.min(1, dt * 12)
    self.heroY = self.heroY + (ty - self.heroY) * math.min(1, dt * 12)
    if Input.pressed('nav_left') then self:_move(-1) end
    if Input.pressed('nav_right') then self:_move(1) end
    if Input.pressed('nav_up') then self:_world(-1) end
    if Input.pressed('nav_down') then self:_world(1) end
    if Input.pressed('confirm') or Input.pressed('flap') then self:_play(); return end
    if Input.pressed('back') then self:_back() end
end

-- Flechas de los lados para cambiar de mundo (ratón / táctil)
local function arrowRect(side)
    local w, h = 54, 90
    return (side < 0) and 14 or (WINDOW_W - w - 14), math.floor(WINDOW_H * PATH_Y - h / 2), w, h
end
local function inside(px, py, x, y, w, h) return px >= x and px <= x + w and py >= y and py <= y + h end

function StoryMapState:_nodeAt(x, y)
    local n = #Worlds.nodes(self.world)
    for k = 1, n do
        local nx, ny = nodePos(k, n)
        if math.abs(x - nx) <= BOSS / 2 + 8 and math.abs(y - ny) <= BOSS / 2 + 8 then return k end
    end
end

function StoryMapState:mousemoved(x, y)
    self.backHover = CornerButtons.hitBack(x, y)
    local k = self:_nodeAt(x, y)
    if k and k ~= self.node then self.node, self.hop = k, 0 end
end

function StoryMapState:touchpressed(id, x, y)
    if CornerButtons.hitBack(x, y) then self:_back(); return end
    if inside(x, y, arrowRect(-1)) then self:_world(-1); return end
    if inside(x, y, arrowRect(1)) then self:_world(1); return end
    local k = self:_nodeAt(x, y)
    if k then
        if k == self.node then self:_play() else self.node, self.hop = k, 0; Sound.play('select') end
    end
end

local function box(x, y, w, h, fill, edge)
    love.graphics.setColor(0, 0, 0, 0.5); love.graphics.rectangle('fill', x + 4, y + 4, w, h)
    love.graphics.setColor(fill); love.graphics.rectangle('fill', x, y, w, h)
    love.graphics.setColor(edge); love.graphics.setLineWidth(4); love.graphics.rectangle('line', x, y, w, h)
    love.graphics.setLineWidth(1)
end

function StoryMapState:render()
    local W = Worlds.get(self.world)
    local nodes = Worlds.nodes(self.world)
    local n = #nodes
    local th = THEME[W.id] or { 0.3, 0.3, 0.4 }
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(imgBg, 0, 0, 0, WINDOW_W / imgBg:getWidth(), WINDOW_H / imgBg:getHeight())
    love.graphics.setColor(th[1], th[2], th[3], 0.82)
    love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)
    love.graphics.setColor(0, 0, 0, 0.28)
    love.graphics.rectangle('fill', 0, WINDOW_H * PATH_Y + 96, WINDOW_W, WINDOW_H)

    -- Cabecera: mundo y progreso
    local title = L('story.world_n', { n = self.world }) .. '  ' .. L('story.world.' .. W.id)
    local ts = (PixelFont.width(title, 6) > WINDOW_W - 80) and 4 or 6
    PixelFont.draw(title, math.floor((WINDOW_W - PixelFont.width(title, ts)) / 2), 40, ts, 1, { 1, 0.95, 0.15 })
    local done, total = Run.progress(self.world)
    local allDone, allTotal = Run.progress()
    love.graphics.setFont(FONT_MED)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.printf(L('story.progress', { done = done, total = total, all = allDone, allTotal = allTotal })
        .. '     ' .. L('diff.' .. Run.data.difficulty), 0, 98, WINDOW_W, 'center')
    -- Vidas de la aventura (arriba a la derecha, como en el nivel)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(imgHero, WINDOW_W - 150, 22, 0, 4, 4)
    PixelFont.draw('x' .. Run.data.lives, WINDOW_W - 96, 30, 5, 1)
    if self.notice and self.noticeT < 4 then
        local a = math.min(1, (4 - self.noticeT) / 0.6)
        local msg = L(self.notice)
        PixelFont.draw(msg, math.floor((WINDOW_W - PixelFont.width(msg, 4)) / 2), 140, 4, a, { 1, 0.35, 0.3 })
    end

    -- El camino (punteado) entre nodos
    for k = 1, n - 1 do
        local x0, y0 = nodePos(k, n)
        local x1, y1 = nodePos(k + 1, n)
        local open = Run.state(self.world, k + 1) ~= 'locked'
        love.graphics.setColor(open and 1 or 0.25, open and 0.95 or 0.25, open and 0.6 or 0.3, open and 0.95 or 0.7)
        local steps = math.floor(math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2) / 22)
        for i = 1, steps - 1 do
            local q = i / steps
            love.graphics.rectangle('fill', math.floor(x0 + (x1 - x0) * q) - 4, math.floor(y0 + (y1 - y0) * q) - 4, 8, 8)
        end
    end

    -- Los nodos
    for k, node in ipairs(nodes) do
        local x, y = nodePos(k, n)
        local st = Run.state(self.world, k)
        local s = node.boss and BOSS or NODE
        if k == self.node then
            local p = 6 + math.floor(math.sin(self.t * 6) * 2 + 0.5)
            love.graphics.setColor(1, 1, 1, 0.95)
            love.graphics.setLineWidth(4)
            love.graphics.rectangle('line', x - s / 2 - p, y - s / 2 - p, s + 2 * p, s + 2 * p)
            love.graphics.setLineWidth(1)
        end
        local fill = (st == 'done') and { 1, 0.82, 0.2, 1 } or (st == 'open') and { 0.96, 0.96, 0.98, 1 } or { 0.3, 0.3, 0.36, 1 }
        if node.boss and st ~= 'locked' and st ~= 'done' then fill = { 0.9, 0.3, 0.3, 1 } end
        box(x - s / 2, y - s / 2, s, s, fill, { 0.08, 0.08, 0.12, 1 })
        local icon = (st == 'locked') and 'lock' or (node.boss and 'skull') or (st == 'done' and 'check') or nil
        if icon then
            local iw, ih = PixelIcons.size(icon)
            local px = node.boss and 5 or 4
            PixelIcons.draw(icon, x - iw * px / 2, y - ih * px / 2, px)
        else
            local num = tostring(k)
            PixelFont.draw(num, math.floor(x - PixelFont.width(num, 5) / 2), math.floor(y - PixelFont.height(5) / 2), 5, 1)
        end
        if st == 'done' and node.boss then PixelIcons.draw('check', x + s / 2 - 16, y - s / 2 - 12, 3) end
    end

    -- El monstruo, sobre su nodo (un saltito al moverse)
    local s = nodes[self.node].boss and BOSS or NODE
    local jump = math.sin(self.hop * math.pi) * 26 + math.abs(math.sin(self.t * 3)) * 5
    local sh = (self.shake > 0) and math.floor(math.sin(self.t * 70) * 5) or 0
    local hs = 5
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(imgHero, math.floor(self.heroX + sh - imgHero:getWidth() * hs / 2),
                       math.floor(self.heroY - s / 2 - imgHero:getHeight() * hs - 8 - jump), 0, hs, hs)

    -- Ficha del nivel elegido
    local node = nodes[self.node]
    local st = Run.state(self.world, self.node)
    local name = (st == 'locked') and L('story.locked') or Worlds.levelName(node.id)
    local py = math.floor(WINDOW_H * PATH_Y + 122)
    love.graphics.setFont(FONT_BIG)
    love.graphics.setColor(0, 0, 0, 0.7); love.graphics.printf(name, 3, py + 3, WINDOW_W, 'center')
    love.graphics.setColor(1, 1, 1, 1); love.graphics.printf(name, 0, py, WINDOW_W, 'center')
    love.graphics.setFont(FONT_MED)
    local line
    if st == 'locked' then line = L('story.locked_hint')
    elseif st == 'done' then
        local b = Run.data.best[node.id] or {}
        line = L('story.done_line', { score = b.score or 0, time = string.format('%d:%02d', math.floor((b.time or 0) / 60), math.floor((b.time or 0) % 60)) })
    else line = L(node.boss and 'story.boss_line' or 'story.play_line') end
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.printf(line, 0, py + 44, WINDOW_W, 'center')

    -- Flechas de mundo
    for _, side in ipairs({ -1, 1 }) do
        local w = self.world + side
        if w >= 1 and w <= Worlds.count() then
            local x, y, aw, ah = arrowRect(side)
            local open = Run.worldOpen(w)
            box(x, y, aw, ah, open and { 0.1, 0.1, 0.14, 0.9 } or { 0.2, 0.2, 0.24, 0.7 }, open and { 1, 1, 1, 1 } or { 0.5, 0.5, 0.55, 1 })
            if open then
                PixelFont.draw(side < 0 and '<' or '>', x + aw / 2 - PixelFont.width('<', 5) / 2, y + ah / 2 - PixelFont.height(5) / 2, 5, 1)
            else
                local iw, ih = PixelIcons.size('lock')
                PixelIcons.draw('lock', x + aw / 2 - iw * 1.5, y + ah / 2 - ih * 1.5, 3)
            end
        end
    end

    love.graphics.setFont(FONT_SMALL)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.printf(L('story.map_hint'), 0, WINDOW_H - 30, WINDOW_W, 'center')
    love.graphics.setFont(FONT_MED)
    love.graphics.setColor(1, 1, 1, 1)
    CornerButtons.drawBack(self.backHover)
end

return StoryMapState
