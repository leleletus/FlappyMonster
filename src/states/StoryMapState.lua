-- src/states/StoryMapState.lua
-- MODO HISTORIA: el MAPA DEL MUNDO (estilo Super Mario World). Un solo mapa grande que se desplaza:
-- islas por mundo (Pradera, Costa, Fortaleza, Cumbres, Cuevas y el volcán del Final) con acantilados,
-- mar animado, caminos de puntos (puentes sobre el agua), un CASTILLO con su jefe en pequeño al final de
-- cada mundo, decoraciones y enemigos del juego en pequeño paseando. El monstruo ANDA por el camino.
--   superado = punto dorado (+ su nota) · abierto = rojo · cerrado = gris (camino apagado)
--   ← → anda al nivel anterior / siguiente (cruza de mundo por el puente) · ↑ ↓ salta de mundo
--   ENTER juega · tocar un nivel: anda hasta él (tocar el suyo: juega) · flechas abajo: anterior / siguiente
-- El mapa son DATOS: assets/story/overworld.json (tools/ui/make_overworld.py) = el terreno por casillas,
-- el camino de cada mundo como polilínea (sus niveles, sean cuantos sean, se reparten por ella, el jefe
-- al final), los puentes entre mundos, las decoraciones, los bichos y el jefe de cada castillo. El orden
-- de mundos y niveles sigue siendo src/story/Worlds.lua; el progreso, src/story/Run.lua.
-- La geometría de pantalla se calcula al dibujar (WINDOW_W cambia: PC, móvil, Switch).
local BaseState     = require 'src/BaseState'
local CornerButtons = require 'src/ui/CornerButtons'
local PixelFont     = require 'src/ui/PixelFont'
local Run           = require 'src/story/Run'
local Worlds        = require 'src/story/Worlds'
local Difficulty    = require 'src/Difficulty'
local json          = require 'libs/json'
local L = require 'src/Lang'

local StoryMapState = BaseState:new()

-- Color de cada mundo (lo usa la pantalla de resultados)
local THEME = {
    pradera = { 0.36, 0.62, 0.36 }, costa = { 0.25, 0.6, 0.72 }, fortaleza = { 0.42, 0.36, 0.44 },
    nieve = { 0.6, 0.75, 0.88 }, cuevas = { 0.2, 0.2, 0.32 }, final = { 0.5, 0.22, 0.2 },
}
StoryMapState.THEME = THEME

local GRADE_COLOR = { S = { 1, 0.85, 0.2 }, A = { 0.5, 1, 0.5 }, B = { 0.5, 0.85, 1 }, C = { 1, 1, 1 }, D = { 0.8, 0.6, 0.6 } }
StoryMapState.GRADE_COLOR = GRADE_COLOR

local TOP_H, BOT_H = 112, 104            -- franjas de la cabecera y de la ficha del nivel
local WALK_SPD = 300                     -- px/s andando por el camino (más deprisa en viajes largos)

-- Terreno: baldosa de arriba (ground-Sheet) y la textura de su bloque para el ACANTILADO (vista de lado)
local GROUND = { g = 1, s = 2, w = 3, c = 4, f = 5, l = 6 }
local CLIFF = { g = 'grass', s = 'sand', w = 'snow', c = 'border', f = 'stone', l = 'deep_stone' }
-- Decoraciones: imagen + ancho de cuadro (animadas) + brillo
local DECO = {
    tulip = { 'assets/images/foliage/tulip.png' },
    bush = { 'assets/images/decorations/tropical/bush.png' },
    fern = { 'assets/images/decorations/tropical/fern.png' },
    hibiscus = { 'assets/images/decorations/tropical/hibiscus.png' },
    pineapple = { 'assets/images/decorations/tropical/pineapple.png' },
    palm = { 'assets/images/foliage/palmtree/palmtree.png', over = { 'assets/images/foliage/palmtree/coques.png', 'assets/images/foliage/palmtree/palmleaves.png' } },
    torch = { 'assets/images/decorations/cave/torch-Sheet.png', fw = 10, fps = 8, glow = { 1, 0.6, 0.2 } },
    bones = { 'assets/images/decorations/cave/bones.png' },
    stalagmite = { 'assets/images/decorations/cave/stalagmite.png' },
    stalagmite_small = { 'assets/images/decorations/cave/stalagmite_small.png' },
    snowy_pine = { 'assets/images/decorations/ice/snowy_pine.png' },
    snowman = { 'assets/images/decorations/ice/snowman-Sheet.png', fw = 18, fps = 1.5 },
    frozen_bush = { 'assets/images/decorations/ice/frozen_bush.png' },
    snow_pile = { 'assets/images/decorations/ice/snow_pile.png' },
    crystals = { 'assets/images/decorations/cave/crystals.png', glow = { 0.5, 0.7, 1 } },
    glow_mushroom = { 'assets/images/decorations/cave/glow_mushroom.png', glow = { 0.4, 1, 0.7 } },
}
-- Bichos: cuadros para andar (archivos o cuadros de una tira) y si se voltean al girar
local CRITTER = {
    gummy = { files = { 'assets/images/gummy/gummy1.png', 'assets/images/gummy/gummy2.png' }, spd = 1.2 },
    gummy_ice = { files = { 'assets/images/gummy_ice/gummy1.png', 'assets/images/gummy_ice/gummy2.png' }, spd = 1.2 },
    crabby = { files = { 'assets/images/crabby/crab1.png', 'assets/images/crabby/crab2.png', 'assets/images/crabby/crab3.png' }, spd = 1.6 },
    -- (el Crabby helado lleva sus PINZAS pequeñas, como en el juego: la misma tira y la misma colocación que su
    -- aspecto — `Crabby.SKINS.ice.claw` en types/crabby.lua —; en el mapa iba sin ellas)
    crabby_ice = { files = { 'assets/images/crabby_ice/crab1.png', 'assets/images/crabby_ice/crab2.png', 'assets/images/crabby_ice/crab3.png' }, spd = 1.4,
                   claw = { file = 'assets/images/crabby_ice/claw_left-Sheet.png', w = 7, x = 5.6, y = -0.6, inset = 1.0 } },
    bomb = { sheet = 'assets/images/bomb/bomb-Sheet.png', fw = 15, frames = { 2, 3 }, spd = 1.1 },
    puffer = { sheet = 'assets/images/puffer_fish/puffer_fish-Sheet.png', fw = 16, frames = { 1, 2 }, spd = 0.9, swim = true },
    gloomy = { sheet = 'assets/images/gloomy/gloomy-Sheet.png', fw = 26, frames = { 1, 2, 3 }, spd = 1.0,
               glow = 'assets/images/gloomy/glow-Sheet.png' },
}

-- Formaciones del relieve del mapa (colinas, picos, rocas, bocas de cueva…): una nueva = un PNG en
-- assets/images/story/features/ + su nombre en el overworld.json
local features = {}
local function featureDef(t)
    if features[t] == nil then
        local path = 'assets/images/story/features/' .. t .. '.png'
        features[t] = love.filesystem.getInfo(path) and { path, scale = 3 } or false
    end
    return features[t] or nil
end

local imgs = {}
local function img(path)
    if not imgs[path] then imgs[path] = love.graphics.newImage(path) end
    return imgs[path]
end
local quads = {}
local function quad(im, x, y, w, h)
    local key = tostring(im) .. x .. ',' .. y .. ',' .. w .. ',' .. h
    if not quads[key] then quads[key] = love.graphics.newQuad(x, y, w, h, im:getDimensions()) end
    return quads[key]
end
-- cuadro i (1..) de una tira de ancho fw
local function frameQ(im, fw, i) return quad(im, (i - 1) * fw, 0, fw, im:getHeight()) end

local invertShader
local function getInvert()
    if invertShader == nil then
        local ok, sh = pcall(love.graphics.newShader, [[
            vec4 effect(vec4 c, Image t, vec2 uv, vec2 sc) { vec4 p = Texel(t, uv); return vec4(1.0 - p.rgb, p.a) * c; }
        ]])
        invertShader = ok and sh or false
    end
    return invertShader or nil
end

-- Los nodos de un mundo EN EL MAPA: sus niveles, el jefe y, detrás, su BONUS (arena contra el bot; un ramal
-- desde el castillo). El bonus no es un nodo de Worlds.nodes (no cuenta para el progreso): su estado es aparte.
local mapCache = {}
local function mapNodes(w)
    if not mapCache[w] then
        local list = {}
        for _, n in ipairs(Worlds.nodes(w)) do list[#list + 1] = n end
        local b = Worlds.bonus(w)
        if b then list[#list + 1] = b end
        mapCache[w] = list
    end
    return mapCache[w]
end
local function stateOf(w, k)
    local n = mapNodes(w)[k]
    if n and n.bonus then return Run.bonusState(w) end
    return Run.state(w, k)
end

-- ── El mapa (datos) y su geometría en píxeles ───────────────────────────────
local MAP
local function polyLen(p)
    local acc = { 0 }
    for i = 2, #p do acc[i] = acc[i - 1] + math.sqrt((p[i][1] - p[i - 1][1]) ^ 2 + (p[i][2] - p[i - 1][2]) ^ 2) end
    return acc
end
local function pointAt(p, acc, s)
    for i = 2, #p do
        if s <= acc[i] or i == #p then
            local seg = acc[i] - acc[i - 1]
            local q = seg > 0 and math.max(0, math.min(1, (s - acc[i - 1]) / seg)) or 0
            return p[i - 1][1] + (p[i][1] - p[i - 1][1]) * q, p[i - 1][2] + (p[i][2] - p[i - 1][2]) * q
        end
    end
    return p[1][1], p[1][2]
end
-- tramo de la polilínea entre las distancias s0 < s1 (puntos, incluidos los extremos)
local function subPath(p, acc, s0, s1)
    local out = { { pointAt(p, acc, s0) } }
    for i = 1, #p do if acc[i] > s0 and acc[i] < s1 then out[#out + 1] = { p[i][1], p[i][2] } end end
    out[#out + 1] = { pointAt(p, acc, s1) }
    return out
end
local function reversed(p)
    local r = {}
    for i = #p, 1, -1 do r[#r + 1] = p[i] end
    return r
end

local function loadMap()
    if MAP then return MAP end
    local d = json.decode(love.filesystem.read('assets/story/overworld.json'))
    local C = d.cell
    MAP = { d = d, C = C, w = d.w, h = d.h, pw = d.w * C, ph = d.h * C, worlds = {}, dots = {} }
    local function px(p)
        local out = {}
        for i, q in ipairs(p) do out[i] = { (q[1] + 0.5) * C, (q[2] + 0.5) * C } end
        return out
    end
    for w = 1, Worlds.count() do
        local def = d.worlds[w] or d.worlds[#d.worlds]
        local p = px(def.path)
        local acc = polyLen(p)
        local n = #Worlds.nodes(w)
        local M = { def = def, p = p, acc = acc, node = {}, seg = {} }
        local s = {}
        for k = 1, n do
            s[k] = (n == 1) and acc[#acc] or acc[#acc] * (k - 1) / (n - 1)
            M.node[k] = { pointAt(p, acc, s[k]) }
        end
        for k = 1, n - 1 do M.seg[k] = subPath(p, acc, s[k], s[k + 1]) end
        local c = d.connect[w]
        if c and w < Worlds.count() then M.bridge = px(c) end
        if def.bonus and Worlds.bonus(w) then
            M.branch = px(def.bonus)
            M.node[n + 1] = M.branch[#M.branch]
        end
        -- el jefe, al lado del castillo que tenga TIERRA (derecha, izquierda o debajo); nunca en el agua
        local bx, by = M.node[n][1], M.node[n][2]
        local function land(x, y)
            local row = d.rows[math.floor(y / C) + 1]
            local ch = row and row:sub(math.floor(x / C) + 1, math.floor(x / C) + 1)
            return ch and ch ~= '' and ch ~= '~' and ch ~= 'L'
        end
        M.bossDx, M.bossDy = 58, 0
        for _, o in ipairs({ { 58, 0 }, { -58, 0 }, { 40, 40 }, { -40, 40 }, { 0, 52 } }) do
            if land(bx + o[1], by + o[2]) and land(bx + o[1] - 14, by + o[2]) and land(bx + o[1] + 14, by + o[2]) then
                M.bossDx, M.bossDy = o[1], o[2]; break
            end
        end
        MAP.worlds[w] = M
    end
    -- los PUNTOS del camino (cada 16 px), con la llave que dice si ese tramo está abierto
    local function dots(pts, key)
        local acc = polyLen(pts)
        local total = acc[#acc]
        local n = math.max(1, math.floor(total / 16))
        local list = {}
        for i = 1, n - 1 do
            local x, y = pointAt(pts, acc, total * i / n)
            local x2, y2 = pointAt(pts, acc, math.min(total, total * i / n + 2))
            local cx, cy = math.floor(x / C), math.floor(y / C)
            local row = d.rows[cy + 1]
            local water = row and row:sub(cx + 1, cx + 1) == '~'
            list[i] = { x = x, y = y, ang = math.atan2(y2 - y, x2 - x), wet = water, key = key }
        end
        -- el puente sigue dos tablones más sobre la orilla de cada lado (si no, acababa cortado en el borde)
        for i, dt in ipairs(list) do
            for j = math.max(1, i - 2), math.min(#list, i + 2) do if list[j].wet then dt.water = true end end
            MAP.dots[#MAP.dots + 1] = dt
        end
    end
    for w, M in ipairs(MAP.worlds) do
        for k, seg in ipairs(M.seg) do dots(seg, { w, k + 1 }) end
        if M.bridge then dots(M.bridge, { w + 1, 1 }) end
        if M.branch then dots(M.branch, { w, #Worlds.nodes(w) + 1 }) end
    end
    return MAP
end
StoryMapState.loadMap = loadMap

-- Todas las paradas en orden (mundo, nodo) y el camino de una a la siguiente
local function stopIndex(w, k)
    local i = 0
    for ww = 1, w - 1 do i = i + #mapNodes(ww) end
    return i + k
end
local function stopAt(i)
    for w = 1, Worlds.count() do
        local n = #mapNodes(w)
        if i <= n then return w, i end
        i = i - n
    end
end
local function totalStops() return stopIndex(Worlds.count(), #mapNodes(Worlds.count())) end
-- puntos del camino de la parada i a la i+1
local function legForward(i)
    local w, k = stopAt(i)
    local M = loadMap().worlds[w]
    local n = #Worlds.nodes(w)
    if k < n then return M.seg[k] end
    if k == n and M.branch then return M.branch end                       -- del castillo a su bonus
    local out = {}
    if k == n + 1 then for _, p in ipairs(reversed(M.branch)) do out[#out + 1] = p end end   -- del bonus, de vuelta al castillo…
    for _, p in ipairs(M.bridge or { M.node[n], (loadMap().worlds[w + 1] or M).node[1] }) do out[#out + 1] = p end   -- … y el puente
    return out
end

local function nodeXY(w, k)
    local p = loadMap().worlds[w].node[k]
    return p[1], p[2]
end

-- ── Estado ──────────────────────────────────────────────────────────────────
function StoryMapState:enter(args)
    loadMap()
    if not Run.active() then gStateMachine:change('story_slots'); return end
    args = args or {}
    local w, k = Run.frontier()
    self.world = args.world or Run.data.world or w
    if not Run.worldOpen(self.world) then self.world = w end
    self.node = args.node or ((self.world == w) and k or Run.data.node or 1)
    self.node = math.max(1, math.min(#mapNodes(self.world), self.node))
    self.t, self.shake = 0, 0
    self.heroX, self.heroY = nodeXY(self.world, self.node)
    self.queue = {}                               -- puntos que le quedan por andar
    self.facing = 1
    self.camX, self.camY = nil, nil
    self.justCleared = args.cleared               -- (acaba de superar ese nivel: destello)
    self.notice, self.noticeT = args.notice, 0    -- (aviso un momento: tras un Game Over, tras un bonus)
    self.noticeGood = args.good
    self.musicIsland = nil
    self:_music()
end

-- MÚSICA: la canción del mapa en el arreglo de la isla donde está el monstruo (la más cercana a él, así cambia
-- al cruzar el puente, no al pulsar); el mismo compás en todas (Sound.switchMusic)
function StoryMapState:_music()
    local best, bd
    for w = 1, Worlds.count() do
        for k = 1, #mapNodes(w) do
            local x, y = nodeXY(w, k)
            local d = (x - self.heroX) ^ 2 + (y - self.heroY) ^ 2
            if not bd or d < bd then best, bd = w, d end
        end
    end
    local id = best and Worlds.get(best).id
    if id == self.musicIsland then return end
    self.musicIsland = id
    local track = require('src/Music').get('map_' .. tostring(id)) and ('map_' .. id) or 'menus'
    if self.musicStarted then Sound.switchMusic(track) else Sound.playMusic(track); self.musicStarted = true end
end

function StoryMapState:_remember()
    Run.data.world, Run.data.node = self.world, self.node
    Run.save()
end

local function stopOpen(i)
    local w, k = stopAt(i)
    return stateOf(w, k) ~= 'locked'
end

-- Anda de parada en parada hasta la `target` (si alguna está cerrada, se para delante y "choca")
function StoryMapState:_walkTo(target)
    local cur = stopIndex(self.world, self.node)
    target = math.max(1, math.min(totalStops(), target))
    if target == cur then return false end
    local d = (target > cur) and 1 or -1
    local moved = false
    while cur ~= target do
        local nxt = cur + d
        if not stopOpen(nxt) then break end
        local leg = (d > 0) and legForward(cur) or reversed(legForward(nxt))
        for _, p in ipairs(leg) do self.queue[#self.queue + 1] = p end
        cur, moved = nxt, true
    end
    if moved then
        self.world, self.node = stopAt(cur)
        Sound.play('select')
    end
    if cur ~= target then self.shake = 0.3; Sound.play('headBump') end
    return moved
end

function StoryMapState:_move(d)
    self:_walkTo(stopIndex(self.world, self.node) + d)
end

-- ↑ ↓: al mundo anterior (a su jefe) o al siguiente (a su primer nivel), andando por el camino
function StoryMapState:_world(d)
    local w = self.world + d
    if w < 1 or w > Worlds.count() then return end
    if not Run.worldOpen(w) then self.shake = 0.3; Sound.play('headBump'); return end
    self:_walkTo(stopIndex(w, (d > 0) and 1 or #Worlds.nodes(w)))
end

function StoryMapState:_play()
    local st = stateOf(self.world, self.node)
    if st == 'locked' then self.shake = 0.3; Sound.play('headBump'); return end
    local nodes = Worlds.nodes(self.world)
    local n = mapNodes(self.world)[self.node]
    local world, node = self.world, self.node
    self.queue = {}
    self.heroX, self.heroY = nodeXY(world, node)
    self:_remember()
    Sound.play('select')
    if n.bonus then
        -- BONUS: Rey de la Colina contra el bot (src/story/BonusMatch.lua); las vidas de la aventura no se tocan
        gStateMachine:change('adventure', {
            level = Worlds.path(n.id), returnTo = 'story_map', difficulty = Run.data.difficulty,
            bonus = { onEnd = function(result)
                local reward = Run.bonusResult(n.id, result)
                gStateMachine:change('story_map', { world = world, node = node,
                    notice = reward and 'story.bonus.won_notice' or (result.won and 'story.bonus.again_notice' or 'story.bonus.lost_notice'),
                    good = result.won })
            end },
        })
        return
    end
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
            local summary = Run.complete(n.id, result)
            -- a los RESULTADOS y, de ahí, al mapa, ya en el siguiente (tras el jefe: al mundo que se abre)
            local nw, nk = world, math.min(#nodes, node + 1)
            if node == #nodes and Run.worldOpen(world + 1) then nw, nk = world + 1, 1 end
            Run.data.world, Run.data.node = nw, nk
            Run.save()
            gStateMachine:change('story_results', { level = n.id, result = result, summary = summary, color = THEME[Worlds.get(world).id],
                                                    map = { world = nw, node = nk, cleared = n.id } })
        end,
    })
end

function StoryMapState:_back()
    self:_remember()
    Sound.play('select')
    gStateMachine:change('story_slots')
end

-- Cámara: el monstruo en el centro del hueco entre la cabecera y la ficha, sin salirse del mapa
function StoryMapState:_camTarget()
    local M = loadMap()
    local viewH = WINDOW_H - TOP_H - BOT_H
    local cx = self.heroX - WINDOW_W / 2
    local cy = self.heroY - TOP_H - viewH / 2
    cx = (M.pw <= WINDOW_W) and (M.pw - WINDOW_W) / 2 or math.max(0, math.min(M.pw - WINDOW_W, cx))
    cy = math.max(-TOP_H, math.min(M.ph - WINDOW_H + BOT_H, cy))
    return cx, cy
end

function StoryMapState:update(dt)
    self.t = self.t + dt
    self.noticeT = (self.noticeT or 0) + dt
    self.shake = math.max(0, self.shake - dt)
    -- andar por el camino (en viajes largos, más deprisa: llega en ~1 s)
    if #self.queue > 0 then
        local left, px, py = 0, self.heroX, self.heroY
        for _, p in ipairs(self.queue) do left = left + math.sqrt((p[1] - px) ^ 2 + (p[2] - py) ^ 2); px, py = p[1], p[2] end
        local step = math.max(WALK_SPD, left / 1.1) * dt
        while step > 0 and #self.queue > 0 do
            local p = self.queue[1]
            local dx, dy = p[1] - self.heroX, p[2] - self.heroY
            local dist = math.sqrt(dx * dx + dy * dy)
            if math.abs(dx) > 0.5 then self.facing = (dx > 0) and 1 or -1 end
            if dist <= step then
                self.heroX, self.heroY = p[1], p[2]
                step = step - dist
                table.remove(self.queue, 1)
            else
                self.heroX, self.heroY = self.heroX + dx / dist * step, self.heroY + dy / dist * step
                step = 0
            end
        end
    end
    self:_music()
    local tx, ty = self:_camTarget()
    if not self.camX then self.camX, self.camY = tx, ty end
    local k = math.min(1, dt * 8)
    self.camX, self.camY = self.camX + (tx - self.camX) * k, self.camY + (ty - self.camY) * k

    if Input.pressed('nav_left') then self:_move(-1) end
    if Input.pressed('nav_right') then self:_move(1) end
    if Input.pressed('nav_up') then self:_world(-1) end
    if Input.pressed('nav_down') then self:_world(1) end
    if Input.pressed('confirm') or Input.pressed('flap') then self:_play(); return end
    if Input.pressed('back') then self:_back() end
end

-- Flechas de abajo (ratón / táctil): nivel anterior / siguiente
local function arrowRect(side)
    local w, h = 64, 64
    return (side < 0) and 16 or (WINDOW_W - w - 16), WINDOW_H - BOT_H + math.floor((BOT_H - h) / 2), w, h
end
local function inside(px, py, x, y, w, h) return px >= x and px <= x + w and py >= y and py <= y + h end

function StoryMapState:_nodeAt(x, y)
    local cx, cy = math.floor(self.camX or 0), math.floor(self.camY or 0)
    for w = 1, Worlds.count() do
        for k, node in ipairs(mapNodes(w)) do
            local nx, ny = nodeXY(w, k)
            local r = node.boss and 40 or 26
            if math.abs(x + cx - nx) <= r and math.abs(y + cy - (ny - (node.boss and 16 or 0))) <= r then return w, k end
        end
    end
end

function StoryMapState:mousemoved(x, y)
    self.backHover = CornerButtons.hitBack(x, y)
end

function StoryMapState:touchpressed(id, x, y)
    if CornerButtons.hitBack(x, y) then self:_back(); return end
    if inside(x, y, arrowRect(-1)) then self:_move(-1); return end
    if inside(x, y, arrowRect(1)) then self:_move(1); return end
    if y < TOP_H or y > WINDOW_H - BOT_H then return end
    local w, k = self:_nodeAt(x, y)
    if w then
        if w == self.world and k == self.node then self:_play() else self:_walkTo(stopIndex(w, k)) end
    end
end

-- ── Dibujo ──────────────────────────────────────────────────────────────────
local function drawBottom(im, q, x, y, s, fw, fh, flip)
    -- dibuja con el pie en (x, y), centrado
    local sx = flip and -s or s
    love.graphics.draw(im, q, math.floor(x - (flip and -1 or 1) * fw * s / 2), math.floor(y - fh * s), 0, sx, s)
end

-- Luz del suelo por altura (los hoyos, oscuros; lo alto, más claro) y textura del CUERPO del acantilado
-- (bajo el labio, que es la textura de su bloque: el césped enseña tierra debajo, la nieve roca…)
local LIT = { [0] = 0.4, 0.78, 0.9, 1 }
local CLIFF_BODY = { g = 'dirt', s = 'sand', w = 'stone', c = 'border', f = 'stone', l = 'deep_stone' }

function StoryMapState:_drawTerrain(cx, cy)
    local M = loadMap()
    local C, rows, hrows = M.C, M.d.rows, M.d.heights
    local c0, c1 = math.max(0, math.floor(cx / C) - 1), math.floor((cx + WINDOW_W) / C) + 1
    local r0, r1 = math.max(0, math.floor(cy / C) - 2), math.floor((cy + WINDOW_H) / C) + 1
    local water = img('assets/images/story/water-Sheet.png')
    local wq = frameQ(water, 16, (math.floor(self.t * 1.6) % 2) + 1)
    local ground = img('assets/images/story/ground-Sheet.png')
    local lava = img('assets/images/tiles/lava.png')
    local foam = img('assets/images/story/foam.png')
    local function at(c, r)
        local row = rows[r + 1]
        if not row or c < 0 or c >= M.w then return '~' end
        return row:sub(c + 1, c + 1)
    end
    -- altura para el relieve: el mar y los hoyos cuentan como 0
    local function ht(c, r)
        if at(c, r) == '~' then return 0 end
        local row = hrows and hrows[r + 1]
        return row and tonumber(row:sub(c + 1, c + 1)) or 1
    end
    love.graphics.setColor(1, 1, 1, 1)
    -- 1) el mar (también fuera del mapa) y el suelo, con su luz por altura
    for r = math.floor(cy / C) - 1, math.floor((cy + WINDOW_H) / C) + 1 do
        for c = math.floor(cx / C) - 1, math.floor((cx + WINDOW_W) / C) + 1 do
            local ch = at(c, r)
            local x, y = c * C - cx, r * C - cy
            if ch == '~' then love.graphics.setColor(1, 1, 1, 1); love.graphics.draw(water, wq, x, y, 0, C / 16, C / 16)
            elseif ch == 'L' then love.graphics.setColor(1, 1, 1, 1); love.graphics.draw(lava, frameQ(lava, 64, (math.floor(self.t * 6) % 4) + 1), x, y, 0, C / 64, C / 64)
            else
                local l = LIT[ht(c, r)] or 1
                love.graphics.setColor(l, l, l, 1)
                -- variante por casilla (fija): casi siempre lisa, a veces con motas o una mancha
                local h = (c * 73 + r * 151) % 17
                local v = (h < 11) and 1 or (h < 15) and 2 or 3
                love.graphics.draw(ground, frameQ(ground, 16, ((GROUND[ch] or 1) - 1) * 3 + v), x, y, 0, C / 16, C / 16)
                -- hierba alta (las briznas del bloque de césped del juego) sobre algo de la pradera
                if ch == 'g' and (c * 31 + r * 17) % 7 == 0 and ht(c, r) > 0 then
                    local bl = img('assets/images/tiles/grass_blades.png')
                    love.graphics.draw(bl, frameQ(bl, 64, (c + r) % 3 + 1), x, y + math.floor(C * 0.4), 0, C / 64, C / 64)
                end
            end
        end
    end
    -- bordes de lo alto (contorno oscuro + brillo) arriba y a los lados, donde el vecino está más bajo
    love.graphics.setColor(1, 1, 1, 1)
    local edge = img('assets/images/story/edge-Sheet.png')
    for r = r0, r1 do
        for c = c0, c1 do
            local ch = at(c, r)
            if ch ~= '~' and ch ~= 'L' then
                local h = ht(c, r)
                local q = frameQ(edge, 16, GROUND[ch] or 1)
                local x, y = c * C - cx, r * C - cy
                local function lower(cc, rr) return at(cc, rr) == '~' or (at(cc, rr) ~= 'L' and ht(cc, rr) < h) end
                if lower(c, r - 1) then love.graphics.draw(edge, q, x, y, 0, C / 16, 2) end
                if lower(c - 1, r) then love.graphics.draw(edge, q, x, y + C, -math.pi / 2, C / 16, 2) end
                if lower(c + 1, r) then love.graphics.draw(edge, q, x + C, y, math.pi / 2, C / 16, 2) end
            end
        end
    end
    -- 2) acantilados: bajo toda casilla más alta que la de abajo, la cara del bloque (vista de lado): el labio con
    --    la textura de su bloque y, si el salto es de más de un nivel, el cuerpo de roca / tierra debajo
    local FACE = math.floor(C * 0.75)
    for r = r0, r1 do
        for c = c0, c1 do
            local ch = at(c, r)
            local below = at(c, r + 1)
            local diff = (ch ~= '~') and (ht(c, r) - ht(c, r + 1)) or 0
            if ch == 'L' and below ~= '~' then diff = 0 end
            if diff > 0 then
                local key = (ch == 'L') and 'l' or ch
                local x, y = c * C - cx, (r + 1) * C - cy
                -- labio (la parte de arriba de su bloque: césped, nieve…) y debajo el cuerpo de roca / tierra
                local LIP = math.floor(C * 0.34)
                local tex = img('assets/images/tiles/' .. (CLIFF[key] or 'dirt') .. '.png')
                local span = tex:getWidth() / 64
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(tex, quad(tex, (c % span) * 64, 0, 64, LIP * 64 / C), x, y, 0, C / 64, C / 64)
                local body = img('assets/images/tiles/' .. (CLIFF_BODY[key] or 'dirt') .. '.png')
                body:setWrap('repeat', 'repeat')
                local bspan = body:getWidth() / 64
                local bh = FACE * diff - LIP
                love.graphics.setColor(0.66, 0.66, 0.72, 1)
                love.graphics.draw(body, quad(body, (c % bspan) * 64, 20, 64, bh * 64 / C), x, y + LIP, 0, C / 64, C / 64)
                local fh = FACE * diff
                love.graphics.setColor(0, 0, 0, 0.35)
                love.graphics.rectangle('fill', x, y + fh, C, 4)
                love.graphics.setColor(1, 1, 1, 1)
                if below == '~' then
                    love.graphics.draw(foam, x, y + fh + 4 + math.floor(math.sin(self.t * 2 + c) * 1.5), 0, C / 16, 2)
                end
            end
        end
    end
    -- 3) espuma en las orillas de los lados y de arriba
    love.graphics.setColor(1, 1, 1, 1)
    for r = r0, r1 do
        for c = c0, c1 do
            if at(c, r) == '~' then
                local x, y = c * C - cx, r * C - cy
                local wob = math.floor(math.sin(self.t * 2 + c + r) * 1.5)
                if at(c - 1, r) ~= '~' then love.graphics.draw(foam, x + 2 + wob, y, math.pi / 2, C / 16, 2) end
                if at(c + 1, r) ~= '~' then love.graphics.draw(foam, x + C - 2 - wob, y + C, -math.pi / 2, C / 16, 2) end
                if at(c, r + 1) ~= '~' then love.graphics.draw(foam, x + C, y + C - 2 - wob, math.pi, C / 16, 2) end
            end
        end
    end
end

function StoryMapState:_drawPaths(cx, cy)
    local M = loadMap()
    local dot = img('assets/images/story/path.png')
    local bridge = img('assets/images/story/bridge.png')
    for _, d in ipairs(M.dots) do
        local x, y = d.x - cx, d.y - cy
        if x > -20 and x < WINDOW_W + 20 and y > -20 and y < WINDOW_H + 20 then
            local open = stateOf(d.key[1], d.key[2]) ~= 'locked'
            if d.water then
                -- (siempre opaco: cerrado = más oscuro, nunca transparente)
                love.graphics.setColor(open and 1 or 0.5, open and 1 or 0.5, open and 1 or 0.56, 1)
                love.graphics.draw(bridge, math.floor(x), math.floor(y), d.ang, 2.25, 4, 4, 2)
            else
                love.graphics.setColor(open and 1 or 0.35, open and 1 or 0.35, open and 1 or 0.4, open and 1 or 0.6)
                love.graphics.draw(dot, math.floor(x) - 4, math.floor(y) - 4, 0, 2, 2)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function StoryMapState:_drawDecos(cx, cy)
    local M = loadMap()
    local C = M.C
    for _, d in ipairs(M.d.decos) do
        local def = DECO[d.t] or featureDef(d.t)
        local x, y = (d.x + 0.5) * C - cx, (d.oy and (d.y + d.oy) * C or (d.y + 1) * C - 4) - cy
        if def and x > -80 and x < WINDOW_W + 80 and y > -40 and y < WINDOW_H + 120 then
            local im = img(def[1])
            local fw = def.fw or im:getWidth()
            local nf = math.floor(im:getWidth() / fw)
            local fi = def.fps and (math.floor(self.t * def.fps + d.x) % nf) + 1 or 1
            local s = def.scale or 2
            if def.glow then
                love.graphics.setBlendMode('add')
                local g = def.glow
                love.graphics.setColor(g[1], g[2], g[3], 0.25 + 0.08 * math.sin(self.t * 3 + d.x))
                local gi = img('assets/images/decorations/fx/glow.png')
                love.graphics.draw(gi, math.floor(x - 32), math.floor(y - im:getHeight() - 24), 0, 2, 2)
                love.graphics.setBlendMode('alpha')
            end
            love.graphics.setColor(1, 1, 1, 1)
            drawBottom(im, frameQ(im, fw, fi), x, y, s, fw, im:getHeight())
            for _, o in ipairs(def.over or {}) do
                local oi = img(o)
                drawBottom(oi, frameQ(oi, oi:getWidth(), 1), x, y, s, oi:getWidth(), oi:getHeight())
            end
        end
    end
end

function StoryMapState:_drawCritters(cx, cy)
    local M = loadMap()
    local C = M.C
    for i, c in ipairs(M.d.critters) do
        local def = CRITTER[c.t]
        if def then
            -- va y viene (con una pausa suave en cada punta)
            local len = (c.x1 - c.x0)
            local u = (self.t * def.spd / len + i * 0.37) % 2
            local dir = (u < 1) and 1 or -1
            local q = (u < 1) and u or (2 - u)
            q = q * q * (3 - 2 * q)
            local x = (c.x0 + 0.5 + len * q) * C - cx
            local y = (c.y + 1) * C - cy - 6 + (def.swim and math.floor(math.sin(self.t * 2 + i) * 3) or 0)
            if x > -60 and x < WINDOW_W + 60 and y > -20 and y < WINDOW_H + 60 then
                local fi = (math.floor(self.t * 6 + i) % #(def.files or def.frames)) + 1
                love.graphics.setColor(1, 1, 1, 1)
                if def.files then
                    local im = img(def.files[fi])
                    drawBottom(im, frameQ(im, im:getWidth(), 1), x, y, 2, im:getWidth(), im:getHeight(), dir < 0)
                    if def.claw then
                        local cl = def.claw
                        local ci = img(cl.file)
                        local fh = ci:getHeight()
                        for k, side in ipairs({ -1, 1 }) do
                            local ph = (k == 1) and 0 or 1.9
                            local snap = (math.floor(self.t * 1.3 + i * 0.7 + k * 0.5) % 4 == 0) and (self.t * 1.3 + i * 0.7 + k * 0.5) % 1 < 0.2
                            local dy = math.sin(self.t * 9 + ph + i) * 0.55
                            local dx = side * (0.15 + 0.15 * math.sin(self.t * 4.5 + ph + i))
                            local px = side * (cl.x * 2 + cl.w - cl.inset * 2) + math.floor(dx * 2 + 0.5)
                            local py = math.floor(cl.y * 2 - fh * 2 + dy * 2 + 0.5)
                            love.graphics.draw(ci, frameQ(ci, cl.w, snap and 2 or 1), math.floor(x) + px, math.floor(y) + py, 0, -side * 2, 2, cl.w / 2, 0)
                        end
                    end
                else
                    local im = img(def.sheet)
                    drawBottom(im, frameQ(im, def.fw, def.frames[fi]), x, y, 2, def.fw, im:getHeight(), dir < 0)
                    if def.glow then
                        local gi = img(def.glow)
                        love.graphics.setBlendMode('add')
                        drawBottom(gi, frameQ(gi, def.fw, def.frames[fi]), x, y, 2, def.fw, gi:getHeight(), dir < 0)
                        love.graphics.setBlendMode('alpha')
                    end
                end
            end
        end
    end
end

-- El castillo del jefe (bandera roja; dorada al vencerlo) y el jefe en pequeño a su lado
function StoryMapState:_drawCastle(w, x, y, beaten)
    local castle = img('assets/images/story/castle-Sheet.png')
    love.graphics.setColor(1, 1, 1, 1)
    drawBottom(castle, frameQ(castle, 16, beaten and 2 or 1), x, y + 12, 4, 16, 16)
    local art = loadMap().worlds[w].def.boss
    if beaten or not art then return end
    local im = img(art.img)
    local fw = art.fw or im:getWidth()
    local M = loadMap().worlds[w]
    local bx = x + M.bossDx
    local by = y + 12 + M.bossDy - (art.fly and (22 + math.floor(math.sin(self.t * 2) * 4)) or 0)
    local s = (fw > 20) and 2 or 3
    local squash = art.fly and 1 or (1 + 0.06 * math.sin(self.t * 4))
    local shader = art.invert and getInvert()
    if shader then love.graphics.setShader(shader) end
    local fi = 1
    love.graphics.draw(im, frameQ(im, fw, fi), math.floor(bx - fw * s / 2), math.floor(by - im:getHeight() * s * squash),
                       0, s, s * squash)
    if art.over then
        local oi = img(art.over)
        love.graphics.draw(oi, math.floor(bx - oi:getWidth() * s / 2), math.floor(by - oi:getHeight() * s * squash), 0, s, s * squash)
    end
    if shader then love.graphics.setShader() end
    if art.glow then
        local gi = img(art.glow)
        love.graphics.setBlendMode('add')
        love.graphics.draw(gi, frameQ(gi, fw, fi), math.floor(bx - fw * s / 2), math.floor(by - gi:getHeight() * s * squash), 0, s, s * squash)
        love.graphics.setBlendMode('alpha')
    end
end

function StoryMapState:_drawNodes(cx, cy)
    local nodeImg = img('assets/images/story/node-Sheet.png')
    for w = 1, Worlds.count() do
        for k, node in ipairs(mapNodes(w)) do
            local nx, ny = nodeXY(w, k)
            local x, y = math.floor(nx - cx), math.floor(ny - cy)
            if x > -120 and x < WINDOW_W + 120 and y > -120 and y < WINDOW_H + 80 then
                local st = stateOf(w, k)
                if node.boss then
                    self:_drawCastle(w, x, y, st == 'done')
                else
                    love.graphics.setColor(1, 1, 1, 1)
                    local fi = (st == 'done') and 3 or (st == 'open') and (node.bonus and 4 or 2) or 1
                    love.graphics.draw(nodeImg, frameQ(nodeImg, 8, fi), x - 16, y - 16, 0, 4, 4)
                end
                if w == self.world and k == self.node then
                    local p = 4 + math.floor(math.abs(math.sin(self.t * 5)) * 3)
                    local r = node.boss and 36 or 18
                    local oy = node.boss and -20 or 0
                    love.graphics.setColor(1, 1, 1, 0.95)
                    love.graphics.setLineWidth(3)
                    love.graphics.rectangle('line', x - r - p, y + oy - r - p, 2 * (r + p), 2 * (r + p))
                    love.graphics.setLineWidth(1)
                end
                if node.bonus and st ~= 'locked' then
                    PixelFont.shadow('B', x - math.floor(PixelFont.width('B', 3) / 2), y - 40, 3, 1, { 0.6, 0.85, 1 })
                end
                local b = st == 'done' and not node.bonus and Run.data.best[node.id]
                if b and b.grade then
                    PixelFont.shadow(b.grade, x - math.floor(PixelFont.width(b.grade, 3) / 2) + (node.boss and -40 or 0), y + 20, 3, 1, GRADE_COLOR[b.grade])
                end
            end
        end
    end
end

function StoryMapState:_drawHero(cx, cy)
    local walking = #self.queue > 0
    local fi = walking and (math.floor(self.t * 10) % 3) + 1 or 1
    local im = img('assets/images/player/monstrito' .. fi .. '.png')
    local bob = walking and 0 or math.floor(math.abs(math.sin(self.t * 3)) * 4)
    local sh = (self.shake > 0) and math.floor(math.sin(self.t * 70) * 4) or 0
    local x, y = math.floor(self.heroX - cx + sh), math.floor(self.heroY - cy)
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle('fill', x - 12, y + 6, 24, 6)
    love.graphics.setColor(1, 1, 1, 1)
    drawBottom(im, frameQ(im, 9, 1), x, y + 8 - bob, 3, 9, 16, self.facing < 0)
end

function StoryMapState:render()
    local cx, cy = math.floor(self.camX or 0), math.floor(self.camY or 0)
    self:_drawTerrain(cx, cy)
    self:_drawPaths(cx, cy)
    self:_drawDecos(cx, cy)
    self:_drawCritters(cx, cy)
    self:_drawNodes(cx, cy)
    self:_drawHero(cx, cy)
    self:_drawHud()
end

-- El mapa ENTERO en una imagen (sin cabecera ni ficha), para revisarlo: lo usa el harness story_flow
-- (story_map_full.png). Devuelve el ImageData.
function StoryMapState:renderFull()
    local M = loadMap()
    local canvas = love.graphics.newCanvas(M.pw, M.ph)
    local ww, wh = WINDOW_W, WINDOW_H
    love.graphics.push('all')
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 1)
    WINDOW_W, WINDOW_H = M.pw, M.ph                  -- (los recortes de dibujo usan el tamaño de pantalla)
    self:_drawTerrain(0, 0)
    self:_drawPaths(0, 0)
    self:_drawDecos(0, 0)
    self:_drawCritters(0, 0)
    self:_drawNodes(0, 0)
    self:_drawHero(0, 0)
    WINDOW_W, WINDOW_H = ww, wh
    love.graphics.setCanvas()
    love.graphics.pop()
    return canvas:newImageData()
end

function StoryMapState:_drawHud()
    local W = Worlds.get(self.world)
    -- Cabecera: mundo y progreso
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle('fill', 0, 0, WINDOW_W, TOP_H)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle('fill', 0, TOP_H, WINDOW_W, 4)
    local title = L('story.world_n', { n = self.world }) .. '  ' .. L('story.world.' .. W.id)
    local ts = (PixelFont.width(title, 6) > WINDOW_W - 320) and 4 or 6
    PixelFont.shadow(title, math.floor((WINDOW_W - PixelFont.width(title, ts)) / 2), 18, ts, 1, { 1, 0.95, 0.15 })
    local done, total = Run.progress(self.world)
    local allDone, allTotal = Run.progress()
    love.graphics.setFont(FONT_MED)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.printf(L('story.progress', { done = done, total = total, all = allDone, allTotal = allTotal })
        .. '     ' .. L('difficulty.' .. Run.data.difficulty)
        .. ((done > 0) and ('     ' .. L('story.world_grade', { grade = select(2, Run.worldRating(self.world)) })) or ''), 0, 72, WINDOW_W, 'center')
    -- Vidas de la aventura (arriba a la derecha, como en el nivel)
    love.graphics.setColor(1, 1, 1, 1)
    local icon = img('assets/images/player/icon.png')
    love.graphics.draw(icon, WINDOW_W - 150, 22, 0, 4, 4)
    PixelFont.shadow('x' .. Run.data.lives, WINDOW_W - 96, 30, 5, 1)
    if self.notice and self.noticeT < 4 then
        local a = math.min(1, (4 - self.noticeT) / 0.6)
        local msg = L(self.notice)
        local mw = PixelFont.width(msg, 4)
        love.graphics.setColor(0, 0, 0, 0.6 * a)
        love.graphics.rectangle('fill', math.floor((WINDOW_W - mw) / 2) - 12, TOP_H + 16, mw + 24, PixelFont.height(4) + 20)
        PixelFont.shadow(msg, math.floor((WINDOW_W - mw) / 2), TOP_H + 26, 4, a, self.noticeGood and { 1, 0.9, 0.25 } or { 1, 0.35, 0.3 })
    end

    -- Ficha del nivel elegido (abajo)
    local by = WINDOW_H - BOT_H
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle('fill', 0, by - 4, WINDOW_W, 4)
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle('fill', 0, by, WINDOW_W, BOT_H)
    local node = mapNodes(self.world)[self.node]
    local st = stateOf(self.world, self.node)
    local name = (st == 'locked') and L('story.locked') or Worlds.levelName(node.id)
    if node.bonus and st ~= 'locked' then name = L('story.bonus.name', { name = name }) end
    love.graphics.setFont(FONT_BIG)
    local nameW = WINDOW_W - 2 * 100
    love.graphics.setColor(0, 0, 0, 0.7); love.graphics.printf(name, 103, by + 15, nameW, 'center')
    love.graphics.setColor(1, 1, 1, 1); love.graphics.printf(name, 100, by + 12, nameW, 'center')
    love.graphics.setFont(FONT_MED)
    local line
    if node.bonus then
        local b = Run.data.bonus[node.id]
        line = (st == 'locked') and L('story.bonus.locked_hint')
               or (st == 'done') and L('story.bonus.done_line', { score = b and b.best or 0 }) or L('story.bonus.line')
    elseif st == 'locked' then line = L('story.locked_hint')
    elseif st == 'done' then
        local b = Run.data.best[node.id] or {}
        line = L('story.done_line', { grade = b.grade or '-', score = b.score or 0, time = string.format('%d:%02d', math.floor((b.time or 0) / 60), math.floor((b.time or 0) % 60)) })
    else line = L(node.boss and 'story.boss_line' or 'story.play_line') end
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.printf(line, 100, by + 52, nameW, 'center')
    love.graphics.setFont(FONT_SMALL)
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.printf(L('story.map_hint'), 100, by + 80, nameW, 'center')
    -- flechas: nivel anterior / siguiente
    local cur = stopIndex(self.world, self.node)
    for _, side in ipairs({ -1, 1 }) do
        local i = cur + side
        if i >= 1 and i <= totalStops() then
            local x, y, aw, ah = arrowRect(side)
            local open = stopOpen(i)
            love.graphics.setColor(0, 0, 0, 0.5); love.graphics.rectangle('fill', x + 4, y + 4, aw, ah)
            love.graphics.setColor(open and 0.12 or 0.22, open and 0.12 or 0.22, open and 0.16 or 0.26, 0.95)
            love.graphics.rectangle('fill', x, y, aw, ah)
            love.graphics.setColor(open and 1 or 0.5, open and 1 or 0.5, open and 1 or 0.55, 1)
            love.graphics.setLineWidth(3); love.graphics.rectangle('line', x, y, aw, ah); love.graphics.setLineWidth(1)
            local g = side < 0 and '<' or '>'
            PixelFont.shadow(g, x + math.floor((aw - PixelFont.width(g, 5)) / 2), y + math.floor((ah - PixelFont.height(5)) / 2), 5, open and 1 or 0.4)
        end
    end
    love.graphics.setFont(FONT_MED)
    love.graphics.setColor(1, 1, 1, 1)
    CornerButtons.drawBack(self.backHover)
end

return StoryMapState
