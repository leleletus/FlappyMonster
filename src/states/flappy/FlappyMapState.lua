-- src/states/flappy/FlappyMapState.lua
-- CAMPAÑA FLAPPY: el MAPA DE ZONA (Plan 3 de docs/design/flappy-plan-3-campaign-frame.md; el arte, Plan 5b). La zona
-- DIBUJADA (el Valle: el cuadro de fondo repetido a lo ancho, pilares de basalto delante): cada etapa es un NIDO en lo
-- alto de su pilar (abierta = banderín rojo, superada = dorado con su nota encima, cerrada = gris con candado), el jefe
-- es el icono de su máquina flotando sobre el suyo y la TIENDA es el nido del MERCADER (siempre abierta; no es una
-- etapa: no cuenta para el progreso, CONTINUAR ni el final). Caminos de puntos (los del mapa de la historia) en arco
-- de un nido al siguiente; la ficha de lo elegido abajo y las vidas arriba a la derecha. Arte:
-- assets/images/flappy/map/<art>_*.png (tools/art/ui/make_flappy_map.py); sitios: src/flappy/Zones.lua `map`.
--   ← → ir de un sitio al de al lado (en orden de izquierda a derecha, la tienda incluida) · ENTER jugar / entrar en
--   la tienda · ATRÁS a las partidas · tocar un sitio: elegirlo (el elegido: jugar / la tienda)
-- Jugar = el mismo contrato que el mapa de la historia (StoryMapState:_start): AdventureState con las vidas de la
-- partida, `onLeave` (las PERDIDAS se guardan salga como salga), `onGameOver` (al principio de la zona) y `onFinish`
-- (FlappyRun.complete y los resultados, que vuelven aquí). Lo ganado en una etapa solo se guarda al terminarla.
--   args = { world = zona, node = etapa elegida, shop = true (la tienda elegida: al volver de ella),
--            notice = clave de idioma (aviso arriba),
--            replay = true + cleared = etapa: REINTENTAR desde los resultados — esa etapa otra vez en cuanto el mapa está listo — }
local BaseState     = require 'src/core/BaseState'
local CornerButtons = require 'src/ui/CornerButtons'
local MenuKit       = require 'src/ui/menu/MenuKit'
local MenuList      = require 'src/ui/menu/MenuList'
local MenuAnim      = require 'src/ui/menu/MenuAnim'
local Transition    = require 'src/ui/menu/Transition'
local PixelFont     = require 'src/ui/PixelFont'
local PixelIcons    = require 'src/ui/PixelIcons'
local FlappyRun     = require 'src/flappy/FlappyRun'
local Shops         = require 'src/flappy/Shops'
local Zones         = require 'src/flappy/Zones'
local Worlds        = require 'src/story/Worlds'
local L = require 'src/core/Lang'

local FlappyMapState = BaseState:new()

local COLOR = { 0.85, 0.55, 0.25 }                         -- (el de la zona en los resultados)
local S = 4                                                -- escala del arte (la del cielo y el mapa de la historia)
local MAP_W = 1280                                         -- ancho máximo del mapa (más ancho: centrado; el fondo se repite)
local GROUND = 30                                          -- filas de arte de la hierba del fondo hasta abajo
local PILLAR_W, PILLAR_H, BASE_H = 18, 160, 10             -- el pilar (make_flappy_map.py): las BASE_H de abajo, su base
-- cada clase de sitio: cuadro del sprite (ancho, alto) y dónde va respecto a la boca del pilar (filas por encima)
local SPRITE = { nest = { 24, 22, 19 }, boss = { 24, 26, 27 }, shop = { 30, 24, 21 } }
local NEST_FRAME = { open = 1, done = 2, locked = 3 }
local BOSS_FRAME = { open = 1, done = 2, locked = 3 }
local DIR = 'assets/images/flappy/map/'
local DOT = 'assets/images/story/path.png'                 -- (el punto de los caminos del mapa de la historia)

local imgs, quads = {}, {}
local function img(path)
    if not imgs[path] then
        imgs[path] = love.graphics.newImage(path)
        imgs[path]:setFilter('nearest', 'nearest')
    end
    return imgs[path]
end
local function quad(im, x, y, w, h)
    local k = tostring(im) .. ':' .. x .. ',' .. y .. ',' .. w .. ',' .. h
    if not quads[k] then quads[k] = love.graphics.newQuad(x, y, w, h, im:getDimensions()) end
    return quads[k]
end

function FlappyMapState:enter(args)
    args = args or {}
    local d = FlappyRun.data
    self.world = args.world or (d and d.world) or 1
    self.nodes = Zones.nodes(self.world)
    self.spots = self:_spots()
    self.sel = math.max(1, math.min(#self.nodes, args.node or (d and d.node) or 1))
    self.onShop = args.shop == true and self:_shopSpot() ~= nil
    self.notice, self.noticeT = args.notice, args.notice and 3 or 0
    if args.replay then self.sel, self.onShop, self.playOnArrive = args.cleared or self.sel, false, true end
    self.anim = MenuAnim.new({ n = 4 })
    self.t = 0
    Sound.playMusic('menus')
end

-- Los SITIOS del mapa (normalizados, de Zones `map`): uno por nodo { k } y la tienda { shop = true } si la zona tiene;
-- en orden de izquierda a derecha (el de ← →). Un nodo sin sitio en los datos se reparte a lo ancho
function FlappyMapState:_spots()
    local Z = Zones.get(self.world)
    local M = (Z and Z.map) or {}
    local at, n, out = M.at or {}, #self.nodes, {}
    for k, node in ipairs(self.nodes) do
        local p = at[node.id] or { (k - 0.5) / math.max(1, n), 0.5 }
        out[#out + 1] = { k = k, nx = p[1], ny = p[2], kind = node.boss and 'boss' or 'nest' }
    end
    if M.shop and #Shops.forZone(self.world) > 0 then
        out[#out + 1] = { shop = true, nx = M.shop[1], ny = M.shop[2], kind = 'shop' }
    end
    table.sort(out, function(a, b) return a.nx < b.nx end)
    return out
end

function FlappyMapState:_shopSpot()
    for i, s in ipairs(self.spots) do if s.shop then return i end end
end

-- El sitio elegido (índice en self.spots)
function FlappyMapState:_cur()
    for i, s in ipairs(self.spots) do
        if (self.onShop and s.shop) or (not self.onShop and s.k == self.sel) then return i end
    end
    return 1
end

function FlappyMapState:_art()
    local Z = Zones.get(self.world)
    return DIR .. ((Z and Z.map and Z.map.art) or 'valle')
end

-- Geometría (al dibujar: WINDOW_W cambia): cada sitio en el ancho del mapa (centrado, MAP_W como mucho), su caja
-- (el sprite: para tocarlo y para el cursor); `nodes[k]` = el de cada etapa, `shop` = el de la tienda
function FlappyMapState:_layout()
    local mw = math.min(WINDOW_W, MAP_W)
    local x0 = math.floor((WINDOW_W - mw) / 2)
    local pts, nodes, shop = {}, {}, nil
    for i, s in ipairs(self.spots) do
        local x, y = x0 + math.floor(s.nx * mw), math.floor(s.ny * WINDOW_H)
        local sp = SPRITE[s.kind]
        local p = { x = x, y = y, spot = s,
                    box = { x = x - 12 * S, y = y - sp[3] * S, w = 24 * S, h = (sp[3] + 3) * S } }
        pts[i] = p
        if s.shop then shop = p else nodes[s.k] = p end
    end
    local cw = math.min(WINDOW_W - 80, 640)
    return { spots = pts, nodes = nodes, shop = shop, ground = WINDOW_H - GROUND * S,
             card = { x = math.floor((WINDOW_W - cw) / 2), y = WINDOW_H - 200, w = cw, h = 112 } }
end

function FlappyMapState:_state(k) return FlappyRun.state(self.world, k) end

function FlappyMapState:_move(d)
    local i = math.max(1, math.min(#self.spots, self:_cur() + d))
    if i == self:_cur() then return end
    self:_select(i)
    Sound.play('select', d > 0 and 1.08 or 0.94)
end

function FlappyMapState:_select(i)
    local s = self.spots[i]
    if not s then return end
    self.onShop = s.shop == true
    if s.k then self.sel = s.k end
end

-- ENTER / tocar el elegido: la etapa o la tienda
function FlappyMapState:_activate()
    if self.onShop then return self:_openShop() end
    return self:_play()
end

function FlappyMapState:_openShop()
    Sound.play('select')
    local zone = self.world
    self.anim:leave(function() gStateMachine:change('flappy_shop', { zone = zone }) end, 4)
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
        taken = FlappyRun.data.taken and FlappyRun.data.taken[id] or nil,   -- (vidas extra ya cogidas aquí: solo dan puntos)
        rescued = FlappyRun.data.rescued and FlappyRun.data.rescued[id] or nil,   -- (flappies ya liberados: jaulas vacías)
        powerups = FlappyRun.powerupInventory(),                            -- (la rueda rápida: docs/design/powerups.md)
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
                                                    returnTo = 'flappy_map', map = { world = world, node = nk, cleared = node } })
        end,
    }, p.x, p.y - 8 * S, { style = 'level' })
end

function FlappyMapState:_back()
    Sound.play('select', 0.85)
    self.anim:leave(function() gStateMachine:change('story_slots', { campaign = 'flappy' }) end, 4)
end

function FlappyMapState:update(dt)
    self.t = self.t + dt
    self.anim:update(dt)
    if self.noticeT > 0 then self.noticeT = math.max(0, self.noticeT - dt) end
    if self.anim:busy() then return end
    if self.playOnArrive then self.playOnArrive = false; return self:_play() end
    if Input.pressed('nav_left') then self:_move(-1) end
    if Input.pressed('nav_right') then self:_move(1) end
    if Input.pressed('confirm') or Input.pressed('flap') then return self:_activate() end
    if Input.pressed('back') then return self:_back() end
end

-- ── Dibujo ──────────────────────────────────────────────────────────────────
-- El cuadro de fondo, repetido a lo ancho y centrado (sus capas dan la vuelta a los 320 px de arte)
function FlappyMapState:_drawBackground(art)
    local bg = img(art .. '_bg.png')
    local bw = bg:getWidth() * S
    local x = math.floor((WINDOW_W - bw) / 2)
    while x > 0 do x = x - bw end
    love.graphics.setColor(1, 1, 1, 1)
    while x < WINDOW_W do love.graphics.draw(bg, x, 0, 0, S, S); x = x + bw end
end

-- Un camino de puntos en ARCO de p a q (los flappies van volando de nido en nido)
local function drawArc(p, q, lit, a)
    local dot = img(DOT)
    local x0, y0, x1, y1 = p.x, p.y - 7 * S, q.x, q.y - 7 * S
    local dist = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
    local cx, cy = (x0 + x1) / 2, math.min(y0, y1) - dist * 0.22
    local n = math.max(2, math.floor(dist / 22))
    if lit then love.graphics.setColor(1, 1, 1, a) else love.graphics.setColor(0.4, 0.4, 0.46, 0.75 * a) end
    for i = 1, n - 1 do
        local u = i / n
        local x = (1 - u) ^ 2 * x0 + 2 * (1 - u) * u * cx + u ^ 2 * x1
        local y = (1 - u) ^ 2 * y0 + 2 * (1 - u) * u * cy + u ^ 2 * y1
        love.graphics.draw(dot, math.floor(x) - 4, math.floor(y) - 4, 0, 2, 2)
    end
end

-- El pilar de un sitio: de su boca (p.y) hasta un poco bajo la hierba, con su base
local function drawPillar(art, p, ground, a)
    local im = img(art .. '_pillar.png')
    local rows = math.max(BASE_H + 1, math.floor((ground - p.y) / S) + 4)
    local top = math.min(rows - BASE_H, PILLAR_H - BASE_H)
    local x = p.x - PILLAR_W / 2 * S
    love.graphics.setColor(1, 1, 1, a)
    love.graphics.draw(im, quad(im, 0, 0, PILLAR_W, top), x, p.y, 0, S, S)
    love.graphics.draw(im, quad(im, 0, PILLAR_H - BASE_H, PILLAR_W, BASE_H), x, p.y + top * S, 0, S, S)
end

function FlappyMapState:_drawSpot(art, p, a)
    local s = p.spot
    local sp = SPRITE[s.kind]
    local x, y = p.x - 12 * S, p.y - sp[3] * S
    love.graphics.setColor(1, 1, 1, a)
    if s.shop then
        -- el mercader saluda de vez en cuando
        local im = img(art .. '_shop-Sheet.png')
        local fr = (self.t % 3 > 2.4) and 2 or 1
        love.graphics.draw(im, quad(im, (fr - 1) * sp[1], 0, sp[1], sp[2]), x, y, 0, S, S)
        return
    end
    local st = self:_state(s.k)
    if s.kind == 'boss' then
        local im = img(art .. '_boss-Sheet.png')
        local bob = (st == 'done') and 0 or math.floor(math.sin(self.t * 2.2) * 1.5 + 0.5) * S   -- (vencido: posado)
        love.graphics.draw(im, quad(im, (BOSS_FRAME[st] - 1) * sp[1], 0, sp[1], sp[2]), x, y + bob, 0, S, S)
    else
        local im = img(art .. '_nest-Sheet.png')
        love.graphics.draw(im, quad(im, (NEST_FRAME[st] - 1) * sp[1], 0, sp[1], sp[2]), x, y, 0, S, S)
        -- el número de la etapa en la cara del pilar
        local num = tostring(s.k)
        PixelFont.shadow(num, p.x - math.floor(PixelFont.width(num, 3) / 2), p.y + 8 * S, 3, a)
    end
    if st == 'locked' then
        local iw, ih = PixelIcons.size('lock')
        PixelIcons.draw('lock', p.x - math.floor(iw * 3 / 2), p.y - 2 * S - ih * 3, 3, a)
    end
    local b = FlappyRun.data and FlappyRun.data.best[self.nodes[s.k].id]
    if st == 'done' and b and b.grade then
        PixelFont.shadow(b.grade, p.x - math.floor(PixelFont.width(b.grade, 4) / 2), y - 36, 4, a, { 1, 0.9, 0.3 })
    end
end

function FlappyMapState:render()
    local art = self:_art()
    local Ly = self:_layout()
    local _, _, a = self.anim:slide(2, 0, 60)
    self:_drawBackground(art)
    -- los caminos: de cada etapa a la siguiente (encendido si la de destino está abierta) y de la tienda a la etapa más cercana
    for k = 2, #self.nodes do
        if Ly.nodes[k - 1] and Ly.nodes[k] then drawArc(Ly.nodes[k - 1], Ly.nodes[k], self:_state(k) ~= 'locked', a) end
    end
    if Ly.shop then
        local best
        for _, p in pairs(Ly.nodes) do
            if not best or math.abs(p.x - Ly.shop.x) < math.abs(best.x - Ly.shop.x) then best = p end
        end
        if best then drawArc(Ly.shop, best, true, a) end
    end
    -- los pilares y lo que llevan encima
    for _, p in ipairs(Ly.spots) do drawPillar(art, p, Ly.ground, a) end
    for _, p in ipairs(Ly.spots) do
        self:_drawSpot(art, p, a)
        MenuKit.occupy(p.box.x, p.box.y, p.box.w, p.box.h)
    end
    local cur = Ly.spots[self:_cur()]
    if cur then MenuKit.marker(cur.box.x, cur.box.y, cur.box.w, cur.box.h, self.t, a) end
    local Z = Zones.get(self.world)
    MenuList.header(L('flappy.zone.' .. (Z and Z.id or '?')), 'orange', self.anim, 1)
    -- la ficha de lo elegido
    local C = Ly.card
    MenuKit.box('card', C.x, C.y, C.w, C.h, a)
    if self.onShop then
        MenuKit.text(FONT_MED, L('flappy.map_shop'), C.x + 20, C.y + 18, C.w - 40, 'left', { 1, 1, 1 }, a)
        MenuKit.text(FONT_SMALL, L('flappy.map_shop_line'), C.x + 20, C.y + 60, C.w - 40, 'left', { 0.85, 0.88, 1 }, a)
        MenuKit.text(FONT_SMALL, L('shop.wallet', { n = (FlappyRun.data and FlappyRun.data.wallet) or 0 }),
                     C.x + 20, C.y + 82, C.w - 40, 'left', { 1, 0.86, 0.36 }, a)
    else
        local n = self.nodes[self.sel]
        if n then
            MenuKit.text(FONT_MED, Worlds.levelName(n.id), C.x + 20, C.y + 18, C.w - 40, 'left', { 1, 1, 1 }, a)
            local b = FlappyRun.data and FlappyRun.data.best[n.id]
            local line = self:_state(self.sel) == 'locked' and L('flappy.map_locked')
                         or (b and b.grade) and L('flappy.map_best', { grade = b.grade, t = string.format('%.1f', b.time or 0) })
                         or L('flappy.map_new')
            MenuKit.text(FONT_SMALL, line, C.x + 20, C.y + 60, C.w - 40, 'left', { 0.85, 0.88, 1 }, a)
            local freed, cages = FlappyRun.rescuedCount(n.id)
            if cages > 0 then
                MenuKit.text(FONT_SMALL, L('flappy.map_cages', { n = freed, m = cages }), C.x + 20, C.y + 82, C.w - 40, 'left', { 1, 0.75, 0.85 }, a)
            end
        end
    end
    -- vidas y aviso
    -- (debajo del rótulo, a la derecha: en pantallas estrechas el rótulo llega al borde)
    if FlappyRun.data then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img('assets/images/player/icon.png'), WINDOW_W - 186, 144, 0, 4, 4)
        PixelFont.shadow('x' .. FlappyRun.data.lives, WINDOW_W - 130, 150, 5, 1)
    end
    if self.noticeT > 0 and self.notice then
        MenuKit.text(FONT_MED, L(self.notice), 0, 200, WINDOW_W, 'center', { 1, 0.4, 0.35 }, math.min(1, self.noticeT))
    end
    MenuKit.hint(L(self.onShop and 'flappy.map_hint_shop' or 'flappy.map_hint'), self.anim, 4)
    CornerButtons.drawBack(self.backHover)
end

-- ── Ratón y táctil ──────────────────────────────────────────────────────────
function FlappyMapState:_spotAt(x, y)
    for i, p in ipairs(self:_layout().spots) do
        local b = p.box
        if x >= b.x - 8 and x <= b.x + b.w + 8 and y >= b.y - 8 and y <= b.y + b.h + 8 then return i end
    end
end

function FlappyMapState:mousemoved(x, y) self.backHover = CornerButtons.hitBack(x, y) end

function FlappyMapState:touchpressed(id, x, y)
    if self.anim:busy() then return end
    if CornerButtons.hitBack(x, y) then return self:_back() end
    local i = self:_spotAt(x, y)
    if not i then return end
    if i == self:_cur() then return self:_activate() end
    self:_select(i)
    Sound.play('select')
end

return FlappyMapState
