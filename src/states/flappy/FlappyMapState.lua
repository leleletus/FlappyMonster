-- src/states/flappy/FlappyMapState.lua
-- CAMPAÑA FLAPPY: el MAPA DE ZONAS (Plan 3 de docs/design/flappy-plan-3-campaign-frame.md). PROVISIONAL de aspecto: el
-- fondo de los menús, el nombre de la zona arriba, sus etapas como nodos en un camino (superada = dorada con su nota,
-- abierta = roja, cerrada = gris, como el mapa de la historia), la ficha de la elegida abajo y las vidas arriba a la
-- derecha. El arte de verdad (el Valle, sus nidos) llega en el Plan 5.
--   ← → elegir etapa · ENTER jugar · ATRÁS a las partidas · tocar un nodo: elegirlo (el elegido: jugar)
-- Jugar = el mismo contrato que el mapa de la historia (StoryMapState:_start): AdventureState con las vidas de la
-- partida, `onLeave` (las PERDIDAS se guardan salga como salga), `onGameOver` (al principio de la zona) y `onFinish`
-- (FlappyRun.complete y los resultados, que vuelven aquí). Lo ganado en una etapa solo se guarda al terminarla.
--   args = { world = zona, node = etapa elegida, notice = clave de idioma (aviso arriba) }
local BaseState     = require 'src/core/BaseState'
local CornerButtons = require 'src/ui/CornerButtons'
local MenuScene     = require 'src/ui/menu/MenuScene'
local MenuKit       = require 'src/ui/menu/MenuKit'
local MenuList      = require 'src/ui/menu/MenuList'
local MenuAnim      = require 'src/ui/menu/MenuAnim'
local Transition    = require 'src/ui/menu/Transition'
local PixelFont     = require 'src/ui/PixelFont'
local FlappyRun     = require 'src/flappy/FlappyRun'
local Zones         = require 'src/flappy/Zones'
local Worlds        = require 'src/story/Worlds'
local L = require 'src/core/Lang'

local FlappyMapState = BaseState:new()

local COLOR = { 0.85, 0.55, 0.25 }                         -- (el de la zona en los resultados)
local NODE_R = 26
local STATE_COLOR = { done = { 1, 0.82, 0.25 }, open = { 0.86, 0.25, 0.22 }, locked = { 0.45, 0.45, 0.5 } }

function FlappyMapState:enter(args)
    args = args or {}
    local d = FlappyRun.data
    self.world = args.world or (d and d.world) or 1
    self.nodes = Zones.nodes(self.world)
    self.sel = math.max(1, math.min(#self.nodes, args.node or (d and d.node) or 1))
    self.notice, self.noticeT = args.notice, args.notice and 3 or 0
    self.anim = MenuAnim.new({ n = 4 })
    self.t = 0
    Sound.playMusic('menus')
end

-- Geometría (al dibujar: WINDOW_W cambia): un nodo por etapa, repartidos en una fila
function FlappyMapState:_layout()
    local n = #self.nodes
    local y = math.floor(WINDOW_H * 0.46)
    local span = math.min(WINDOW_W - 240, 220 * math.max(1, n - 1))
    local x0 = math.floor((WINDOW_W - span) / 2)
    local pts = {}
    for k = 1, n do
        local x = n > 1 and math.floor(x0 + span * (k - 1) / (n - 1)) or math.floor(WINDOW_W / 2)
        pts[k] = { x = x, y = y }
    end
    local cw = math.min(WINDOW_W - 80, 640)
    return { nodes = pts, card = { x = math.floor((WINDOW_W - cw) / 2), y = WINDOW_H - 200, w = cw, h = 112 } }
end

function FlappyMapState:_state(k) return FlappyRun.state(self.world, k) end

function FlappyMapState:_move(d)
    local k = math.max(1, math.min(#self.nodes, self.sel + d))
    if k ~= self.sel then self.sel = k; Sound.play('select', d > 0 and 1.08 or 0.94) end
end

function FlappyMapState:_play()
    if self:_state(self.sel) == 'locked' then Sound.play('headBump'); return end
    Sound.play('select')
    local world, node = self.world, self.sel
    local id = self.nodes[node].id
    FlappyRun.data.world, FlappyRun.data.node = world, node
    FlappyRun.save()
    self.anim:leave(function() end, 4)
    local p = self:_layout().nodes[node]
    Transition.go('adventure', {
        level = Zones.path(id), returnTo = 'flappy_map', difficulty = FlappyRun.data.difficulty,
        lives = FlappyRun.data.lives,
        onLeave = function(lives) FlappyRun.setLives(lives) end,
        gameOverNote = L('flappy.go_zone'),
        onGameOver = function()
            local z = FlappyRun.gameOver()
            gStateMachine:change('flappy_map', { world = z, node = 1, notice = 'flappy.go_notice' })
        end,
        onFinish = function(result)
            local summary = FlappyRun.complete(id, result)
            -- (de vuelta al mapa: en la siguiente si se abrió, si no en la misma)
            local nk = (node < #Zones.nodes(world) and FlappyRun.state(world, node + 1) ~= 'locked') and node + 1 or node
            FlappyRun.data.world, FlappyRun.data.node = world, nk
            FlappyRun.save()
            gStateMachine:change('story_results', { level = id, result = result, summary = summary, color = COLOR,
                                                    returnTo = 'flappy_map', map = { world = world, node = nk } })
        end,
    }, p.x, p.y, { style = 'level' })
end

function FlappyMapState:_back()
    Sound.play('select', 0.85)
    self.anim:leave(function() gStateMachine:change('story_slots', { campaign = 'flappy' }) end, 4)
end

function FlappyMapState:update(dt)
    self.t = self.t + dt
    MenuScene.update(dt)
    self.anim:update(dt)
    if self.noticeT > 0 then self.noticeT = math.max(0, self.noticeT - dt) end
    if self.anim:busy() then return end
    if Input.pressed('nav_left') then self:_move(-1) end
    if Input.pressed('nav_right') then self:_move(1) end
    if Input.pressed('confirm') or Input.pressed('flap') then return self:_play() end
    if Input.pressed('back') then return self:_back() end
end

function FlappyMapState:render()
    MenuScene.draw()
    local Z = Zones.get(self.world)
    MenuList.header(L('flappy.zone.' .. (Z and Z.id or '?')), 'orange', self.anim, 1)
    local Ly = self:_layout()
    local ox, _, a = self.anim:slide(2, 0, 60)
    -- el camino
    love.graphics.setColor(0.2, 0.16, 0.12, 0.85 * a)
    love.graphics.setLineWidth(10)
    for k = 2, #Ly.nodes do
        local p, q = Ly.nodes[k - 1], Ly.nodes[k]
        love.graphics.line(p.x + ox, p.y, q.x + ox, q.y)
    end
    love.graphics.setLineWidth(1)
    -- los nodos
    for k, p in ipairs(Ly.nodes) do
        local st = self:_state(k)
        local c = STATE_COLOR[st]
        local r = NODE_R + ((k == self.sel) and 6 or 0)
        love.graphics.setColor(0.08, 0.06, 0.1, a)
        love.graphics.rectangle('fill', p.x + ox - r - 4, p.y - r - 4, 2 * r + 8, 2 * r + 8)
        love.graphics.setColor(c[1], c[2], c[3], a)
        love.graphics.rectangle('fill', p.x + ox - r, p.y - r, 2 * r, 2 * r)
        PixelFont.shadow(tostring(k), p.x + ox - PixelFont.width(tostring(k), 4) / 2, p.y - 12, 4, a)
        local b = FlappyRun.data and FlappyRun.data.best[self.nodes[k].id]
        if st == 'done' and b and b.grade then
            PixelFont.shadow(b.grade, p.x + ox - PixelFont.width(b.grade, 4) / 2, p.y - r - 44, 4, a)
        end
        if k == self.sel then MenuKit.marker(p.x + ox - r - 4, p.y - r - 4, 2 * r + 8, 2 * r + 8) end
    end
    -- la ficha de la etapa elegida
    local C = Ly.card
    local n = self.nodes[self.sel]
    MenuKit.box('card', C.x, C.y, C.w, C.h, a)
    if n then
        MenuKit.text(FONT_MED, Worlds.levelName(n.id), C.x + 20, C.y + 18, C.w - 40, 'left', { 1, 1, 1 }, a)
        local b = FlappyRun.data and FlappyRun.data.best[n.id]
        local line = self:_state(self.sel) == 'locked' and L('flappy.map_locked')
                     or (b and b.grade) and L('flappy.map_best', { grade = b.grade, t = string.format('%.1f', b.time or 0) })
                     or L('flappy.map_new')
        MenuKit.text(FONT_SMALL, line, C.x + 20, C.y + 60, C.w - 40, 'left', { 0.85, 0.88, 1 }, a)
    end
    -- vidas y aviso
    -- (debajo del rótulo, a la derecha: en pantallas estrechas el rótulo llega al borde)
    if FlappyRun.data then PixelFont.shadow('x' .. FlappyRun.data.lives, WINDOW_W - 130, 150, 5, 1) end
    if self.noticeT > 0 and self.notice then
        MenuKit.text(FONT_MED, L(self.notice), 0, 200, WINDOW_W, 'center', { 1, 0.4, 0.35 }, math.min(1, self.noticeT))
    end
    MenuKit.hint(L('flappy.map_hint'), self.anim, 4)
    CornerButtons.drawBack(self.backHover)
end

-- ── Ratón y táctil ──────────────────────────────────────────────────────────
function FlappyMapState:_nodeAt(x, y)
    for k, p in ipairs(self:_layout().nodes) do
        if math.abs(x - p.x) <= NODE_R + 10 and math.abs(y - p.y) <= NODE_R + 10 then return k end
    end
end

function FlappyMapState:mousemoved(x, y) self.backHover = CornerButtons.hitBack(x, y) end

function FlappyMapState:touchpressed(id, x, y)
    if self.anim:busy() then return end
    if CornerButtons.hitBack(x, y) then return self:_back() end
    local k = self:_nodeAt(x, y)
    if not k then return end
    if k == self.sel then return self:_play() end
    self.sel = k
    Sound.play('select')
end

return FlappyMapState
