-- src/states/story/StoryCollectionState.lua
-- LA COLECCIÓN del modo historia (docs/story/story-mode.md § The collection): una ficha por cada coleccionable del
-- catálogo assets/story/collectibles.json (src/story/Collect.lua), sean cuantos sean. Se abre ENCIMA del mapa del mundo
-- (push desde StoryMapState: {alt} o tocar la ficha de los fragmentos; lo tapa con los ladrillos de la historia) y
-- ATRÁS la quita (pop): el mapa sigue donde estaba, con su música.
--   Ficha de lo que SE TIENE (Run.data.collect[id]): su icono, nombre, qué es (desc) y cómo se consiguió (how).
--   En otro ESTADO de la partida (p. ej. 'stolen': el Groove le robó la astilla): el icono de ese estado
--   (collectibles.json `states`), la etiqueta story.collect.state.<estado> y el texto <keys>.<estado> en vez del "cómo".
--   Ficha de lo que FALTA: la silueta "???" (assets/images/story/collectibles/locked.png) y la pista (hint).
-- Textos: `<keys>.name|desc|how|hint` de cada entrada (assets/lang/es.lua y en.lua) y story.collect.*.
-- Teclado / mando: flechas por la rejilla, ATRÁS vuelve. Ratón / táctil: tocar una ficha la elige, arrastrar desplaza,
-- VOLVER arriba a la izquierda. La geometría se calcula al dibujar (WINDOW_W cambia: 960 / 1280 / 1600…): una sola
-- función (layout) para dibujo, ratón y táctil.
local BaseState     = require 'src/core/BaseState'
local Collect       = require 'src/story/Collect'
local Run           = require 'src/story/Run'
local L             = require 'src/core/Lang'
local MenuKit       = require 'src/ui/menu/MenuKit'
local MenuList      = require 'src/ui/menu/MenuList'
local MenuAnim      = require 'src/ui/menu/MenuAnim'
local MenuScene     = require 'src/ui/menu/MenuScene'
local PixelFont     = require 'src/ui/PixelFont'
local CornerButtons = require 'src/ui/CornerButtons'
local Clip          = require 'src/ui/Clip'
local TextUtil      = require 'src/ui/TextUtil'
local MenuButton    = require 'src/ui/menu/MenuButton'
local Shards        = require 'src/story/Shards'
local Worlds        = require 'src/story/Worlds'

-- PESTAÑAS (el usuario, 2026-11-02): COLECCIÓN (los coleccionables), FRAGMENTOS (la galería: los fragmentos del espejo
-- mundo a mundo, los que tiene con el dibujo de su jefe y los que faltan como "???") y CINE (las películas de la
-- historia: las ya vistas se vuelven a ver con confirmar; las demás, cerradas con cuándo se ven). ARRIBA desde la
-- primera fila da el foco a las pestañas (◀ ▶ cambian, ABAJO vuelve); tocar una pestaña la abre.
local TABS = { 'items', 'shards', 'films' }
local FILMS = { 'intro', 'chase', 'lair', 'ending', 'credits' }

local StoryCollectionState = BaseState:new()

local TOP = 196              -- y donde empiezan las fichas (bajo el rótulo y las pestañas)
local BOTTOM = 60            -- hueco de abajo (la ayuda)
local GAP = 20               -- entre fichas
local CARD_MIN_W = 520       -- ancho mínimo de una ficha (cuántas columnas caben)
local CARD_H = 188
local ICON_BOX = 128         -- el hueco del icono
local LOCKED = 'assets/images/story/collectibles/locked.png'

local lockedImg
local function lockedImage()
    if lockedImg == nil then
        local ok, im = pcall(love.graphics.newImage, LOCKED)
        lockedImg = ok and im or false
        if lockedImg then lockedImg:setFilter('nearest', 'nearest') end
    end
    return lockedImg or nil
end

-- Geometría (sin desplazar): columnas, vista y la caja de cada ficha
local function layout(n)
    local view = { x = 40, y = TOP, w = WINDOW_W - 80, h = WINDOW_H - TOP - BOTTOM }
    local cols = math.max(1, math.min(n, math.floor((view.w + GAP) / (CARD_MIN_W + GAP))))
    local cw = math.floor((view.w - GAP * (cols - 1)) / cols)
    if cols == 1 then cw = math.min(cw, 820) end
    local x0 = math.floor((WINDOW_W - (cw * cols + GAP * (cols - 1))) / 2)
    local cards = {}
    for i = 1, n do
        local c, r = (i - 1) % cols, math.floor((i - 1) / cols)
        cards[i] = { x = x0 + c * (cw + GAP), y = TOP + r * (CARD_H + GAP), w = cw, h = CARD_H }
    end
    local rows = math.ceil(n / cols)
    local contentH = rows * (CARD_H + GAP) - GAP
    return { view = view, cols = cols, cards = cards, maxScroll = math.max(0, contentH - view.h) }
end

-- ¿Película ya vista en esta partida? (la intro, al crearla; la emboscada y la guarida, al entrar en sus niveles; el
-- final y los créditos, al vencer al Espejo)
local function filmSeen(id)
    if not Run.active() then return false end
    local d = Run.data
    if id == 'intro' then return true end
    if id == 'ending' or id == 'credits' then return Run.isDone('ruta_del_espejo') end
    return d.films ~= nil and d.films[id] == true
end
StoryCollectionState.filmSeen = filmSeen

-- La lista de cada pestaña: coleccionables, fragmentos ({ shard = n, def }), películas ({ film = id })
function StoryCollectionState:_buildList()
    if self.tab == 'shards' then
        local list, byId = {}, {}
        for _, d in ipairs(Shards.LIST) do byId[d.id] = d end
        for _, n in ipairs(Shards.ORDER) do list[#list + 1] = { shard = n, def = byId[n] } end
        return list
    elseif self.tab == 'films' then
        local list = {}
        for _, id in ipairs(FILMS) do list[#list + 1] = { film = id } end
        return list
    end
    return Collect.LIST
end

function StoryCollectionState:_setTab(tab)
    if tab == self.tab then return end
    self.tab = tab
    self.list = self:_buildList()
    self.sel, self.scroll, self.scrollTarget = 1, 0, 0
    Sound.play('select')
end

function StoryCollectionState:enter(args)
    args = args or {}
    self.tab = args.tab or 'items'
    self.tabFocus = false
    self.list = self:_buildList()
    self.sel = math.max(1, math.min(#self.list, args.sel or 1))
    self.scroll, self.scrollTarget = 0, 0
    self.anim = MenuAnim.new({ n = 4 })
    self.t = 0
end

-- Su ESTADO en la partida (Collect.state: true = lo tiene; otro, p. ej. 'stolen' = el Groove le robó la astilla) y lo
-- que la ficha enseña en un estado distinto de true: su icono (collectibles.json `states`), la etiqueta
-- story.collect.state.<estado> y el texto <keys>.<estado> (si existen)
function StoryCollectionState:state(i)
    local c = self.list[i]
    if c and (c.shard or c.film) then return nil end
    return c and Run.active() and Collect.state(Run.data, c.id) or nil
end
function StoryCollectionState:iconPath(i)
    local c = self.list[i]
    return c and Collect.iconPath(c.id, self:state(i)) or nil
end
function StoryCollectionState:stateTexts(i)
    local c, st = self.list[i], self:state(i)
    if not c or st == nil or st == true then return nil, nil end
    local keys = c.keys or ('story.collect.' .. c.id)
    local tag, line = 'story.collect.state.' .. tostring(st), keys .. '.' .. tostring(st)
    return L.has(tag) and L(tag) or nil, L.has(line) and L(line) or nil
end

function StoryCollectionState:owned(i)
    local c = self.list[i]
    if not c or not Run.active() then return false end
    if c.film then return filmSeen(c.film) end
    if c.shard then
        for _, id in ipairs(Shards.ids(c.shard, Shards.isXtra(Run.data.difficulty))) do
            if Run.data.shards and Run.data.shards[id] then return true end
        end
        return false
    end
    return Collect.has(Run.data, c.id)
end

-- Volver a ver una película (CINE): de vuelta, al mapa con esta pestaña abierta
function StoryCollectionState:_playFilm(i)
    local c = self.list[i]
    if not (c and c.film) then return end
    if not self:owned(i) then Sound.play('headBump'); return end
    Sound.play('select', 1.2)
    local xtra = Shards.isXtra(Run.data.difficulty)
    local sel = i
    gStateMachine:change('story_film', { film = c.film, xtra = xtra, onDone = function()
        gStateMachine:change('story_map')
        gStateMachine:push('story_collection', { tab = 'films', sel = sel })
    end })
end

-- Las pestañas: arriba, centradas
function StoryCollectionState:_tabRects()
    local w, h, gap = 240, 44, 16
    local x0 = math.floor((WINDOW_W - 3 * w - 2 * gap) / 2)
    local out = {}
    for k, id in ipairs(TABS) do out[id] = { x = x0 + (k - 1) * (w + gap), y = 136, w = w, h = h } end
    return out
end

-- (el desplazamiento que deja ver la elegida)
function StoryCollectionState:_follow()
    local Ly = layout(#self.list)
    local r = Ly.cards[self.sel]
    if not r then return end
    local top, bot = r.y - TOP, r.y - TOP + r.h
    if top < self.scrollTarget then self.scrollTarget = top end
    if bot > self.scrollTarget + Ly.view.h then self.scrollTarget = bot - Ly.view.h end
    self.scrollTarget = math.max(0, math.min(Ly.maxScroll, self.scrollTarget))
end

function StoryCollectionState:_move(d)
    local n = #self.list
    if n == 0 then return end
    local s = self.sel + d
    if s < 1 or s > n then return end
    self.sel = s
    Sound.play('select')
    self:_follow()
end

function StoryCollectionState:_back()
    if self.anim:busy() then return end
    Sound.play('select')
    self.anim:leave(function() gStateMachine:pop() end)
end

function StoryCollectionState:update(dt)
    self.t = self.t + dt
    self.anim:update(dt)
    -- (la ventana puede cambiar de tamaño con la pantalla abierta: el desplazamiento se ajusta al de ahora)
    self.scrollTarget = math.max(0, math.min(layout(#self.list).maxScroll, self.scrollTarget))
    local k = math.min(1, dt * 12)
    self.scroll = self.scroll + (self.scrollTarget - self.scroll) * k
    if math.abs(self.scroll - self.scrollTarget) < 0.5 then self.scroll = self.scrollTarget end
    if self.anim:busy() then return end
    local cols = layout(#self.list).cols
    if self.tabFocus then
        local k = 1
        for j, id in ipairs(TABS) do if id == self.tab then k = j end end
        if Input.pressed('nav_left') then self:_setTab(TABS[(k - 2) % #TABS + 1]) end
        if Input.pressed('nav_right') then self:_setTab(TABS[k % #TABS + 1]) end
        if Input.pressed('nav_down') or Input.pressed('confirm') then self.tabFocus = false; Sound.play('select') end
    else
        if Input.pressed('nav_left') then self:_move(-1) end
        if Input.pressed('nav_right') then self:_move(1) end
        if Input.pressed('nav_up') then
            if self.sel <= cols then self.tabFocus = true; Sound.play('select') else self:_move(-cols) end
        end
        if Input.pressed('nav_down') then self:_move(cols) end
        if (Input.pressed('confirm') or Input.pressed('flap')) and self.tab == 'films' then self:_playFilm(self.sel) end
    end
    if Input.pressed('back') or Input.pressed('light') then self:_back() end
end

-- ── Ratón y táctil ──────────────────────────────────────────────────────────
function StoryCollectionState:_cardAt(x, y)
    local Ly = layout(#self.list)
    local v = Ly.view
    if x < v.x or x > v.x + v.w or y < v.y or y > v.y + v.h then return nil end
    for i, r in ipairs(Ly.cards) do
        local ry = r.y - math.floor(self.scroll)
        if x >= r.x and x <= r.x + r.w and y >= ry and y <= ry + r.h then return i end
    end
end

function StoryCollectionState:mousemoved(x, y)
    self.backHover = CornerButtons.hitBack(x, y)
end

function StoryCollectionState:touchpressed(id, x, y)
    if CornerButtons.hitBack(x, y) then self:_back(); return end
    for tab, r in pairs(self:_tabRects()) do
        if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then self:_setTab(tab); return end
    end
    self.drag = { id = id, y = y, y0 = y, moved = false }
end

function StoryCollectionState:touchmoved(id, x, y)
    local d = self.drag
    if not d or d.id ~= id then return end
    if math.abs(y - d.y0) > 12 then d.moved = true end
    if d.moved then
        local Ly = layout(#self.list)
        self.scrollTarget = math.max(0, math.min(Ly.maxScroll, self.scrollTarget - (y - d.y)))
        self.scroll = self.scrollTarget
    end
    d.y = y
end

function StoryCollectionState:touchreleased(id, x, y)
    local d = self.drag
    self.drag = nil
    if not d or d.moved then return end
    local i = self:_cardAt(x, y)
    if i and i ~= self.sel then self.sel = i; Sound.play('select')
    elseif i and self.tab == 'films' then self:_playFilm(i) end           -- (la ya elegida, en el CINE: se ve)
end

function StoryCollectionState:wheelmoved(dx, dy)
    local Ly = layout(#self.list)
    self.scrollTarget = math.max(0, math.min(Ly.maxScroll, self.scrollTarget - dy * 80))
end

-- ── Dibujo ──────────────────────────────────────────────────────────────────
-- El icono centrado en el hueco, a la escala entera mayor que cabe
local function drawIcon(im, x, y, w, h, a, color)
    if not im then return end
    local iw, ih = im:getDimensions()
    local s = math.max(1, math.floor(math.min((w - 16) / iw, (h - 16) / ih)))
    local c = color or { 1, 1, 1 }
    love.graphics.setColor(c[1], c[2], c[3], a)
    love.graphics.draw(im, math.floor(x + (w - iw * s) / 2), math.floor(y + (h - ih * s) / 2), 0, s, s)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Texto que cabe en `lines` líneas de ancho w (si no, recortado con "…")
local function wrapped(font, text, x, y, w, lines, color, a)
    local _, ls = font:getWrap(text, w)
    if #ls > lines then
        ls = { unpack(ls, 1, lines) }
        ls[lines] = TextUtil.fit(font, ls[lines] .. '...', w)
    end
    local lh = math.floor(font:getHeight() * 1.5)
    for k, l in ipairs(ls) do MenuKit.text(font, l, x, y + (k - 1) * lh, w, 'left', color, a) end
    return y + #ls * lh
end

-- Ficha de un FRAGMENTO o de una PELÍCULA
local shardImgs = {}
function StoryCollectionState:_drawExtra(i, r, oy, a)
    local c = self.list[i]
    local owned = self:owned(i)
    local sel = i == self.sel and not self.tabFocus
    local x, y = r.x, r.y + oy + ((sel and math.floor(self.t * 3) % 2 == 0) and -4 or 0)
    MenuKit.box(sel and 'card_sel' or 'card', x, y, r.w, r.h, a * (owned and 1 or 0.85))
    local ix, iy = x + 20, y + math.floor((r.h - ICON_BOX) / 2)
    MenuKit.box('well', ix, iy, ICON_BOX, ICON_BOX, a)
    local tx, tw = ix + ICON_BOX + 20, r.w - ICON_BOX - 60
    local ty = y + 20
    if c.shard then
        local def = c.def or {}
        local w = Worlds.worldOf(def.level or '')
        if owned then
            local path = def.normal and def.normal.img
            if path and shardImgs[path] == nil then
                local ok, im = pcall(love.graphics.newImage, path)
                shardImgs[path] = ok and im or false
                if ok then im:setFilter('nearest', 'nearest') end
            end
            local hex = def.tint or '#ffffff'
            local col = { tonumber(hex:sub(2, 3), 16) / 255, tonumber(hex:sub(4, 5), 16) / 255, tonumber(hex:sub(6, 7), 16) / 255 }
            love.graphics.setColor(col[1], col[2], col[3], (0.12 + 0.06 * math.sin(self.t * 3 + i)) * a)
            love.graphics.rectangle('fill', ix + 8, iy + 8, ICON_BOX - 16, ICON_BOX - 16)
            local im = shardImgs[path] or nil
            local iw, ih = 0, 0
            if im then iw, ih = im:getDimensions() end
            local fw = def.normal and def.normal.fw or ((im and iw > ih * 1.5) and ih or nil)
            if im and fw then
                -- (una hoja de cuadros — `fw` de shards.json —: solo el primero)
                local q = love.graphics.newQuad(0, 0, fw, ih, iw, ih)
                local sc = math.max(1, math.floor(math.min((ICON_BOX - 16) / fw, (ICON_BOX - 16) / ih)))
                love.graphics.setColor(1, 1, 1, a)
                love.graphics.draw(im, q, math.floor(ix + (ICON_BOX - fw * sc) / 2), math.floor(iy + (ICON_BOX - ih * sc) / 2), 0, sc, sc)
                love.graphics.setColor(1, 1, 1, 1)
            elseif im then
                drawIcon(im, ix, iy, ICON_BOX, ICON_BOX, a)
            else
                drawIcon(lockedImage(), ix, iy, ICON_BOX, ICON_BOX, a, col)        -- (sin dibujo de jefe: el fragmento, de su color)
            end
        else
            drawIcon(lockedImage(), ix, iy, ICON_BOX, ICON_BOX, a * 0.9)
        end
        MenuKit.text(FONT_MED, L('story.collect.shard', { n = c.shard }), tx, ty, tw, 'left', owned and { 1, 0.9, 0.45 } or { 0.7, 0.72, 0.85 }, a)
        ty = ty + FONT_MED:getHeight() + 10
        if w then MenuKit.text(FONT_SMALL, L('story.world.' .. w), tx, ty, tw, 'left', { 0.6, 0.8, 1 }, a) end
        ty = ty + FONT_SMALL:getHeight() + 12
        wrapped(FONT_SMALL, L(owned and 'story.collect.shard_have' or 'story.collect.shard_missing'), tx, ty, tw, 3,
                owned and { 0.65, 1, 0.65 } or { 0.78, 0.8, 0.95 }, a)
    else
        -- una película: un trozo de cinta (los agujeros arriba y abajo) con ▶ si ya se vio
        love.graphics.setColor(0.12, 0.1, 0.14, a)
        love.graphics.rectangle('fill', ix + 12, iy + 28, ICON_BOX - 24, ICON_BOX - 56)
        love.graphics.setColor(0.85, 0.85, 0.8, a)
        for k = 0, 4 do
            love.graphics.rectangle('fill', ix + 18 + k * 20, iy + 32, 8, 8)
            love.graphics.rectangle('fill', ix + 18 + k * 20, iy + ICON_BOX - 40, 8, 8)
        end
        if owned then
            love.graphics.setColor(1, 0.86, 0.36, a)
            local cx, cy = ix + ICON_BOX / 2, iy + ICON_BOX / 2
            love.graphics.polygon('fill', cx - 12, cy - 16, cx - 12, cy + 16, cx + 16, cy)
        else
            local q = L('story.collect.unknown')
            PixelFont.shadow(q, math.floor(ix + (ICON_BOX - PixelFont.width(q, 3)) / 2), math.floor(iy + (ICON_BOX - PixelFont.height(3)) / 2), 3, a, { 0.75, 0.8, 1 })
        end
        love.graphics.setColor(1, 1, 1, 1)
        MenuKit.text(FONT_MED, TextUtil.fit(FONT_MED, owned and L('ft.film_' .. c.film) or L('story.collect.unknown'), tw), tx, ty, tw, 'left',
                     owned and { 1, 0.9, 0.45 } or { 0.7, 0.72, 0.85 }, a)
        ty = ty + FONT_MED:getHeight() + 14
        wrapped(FONT_SMALL, owned and L('story.collect.film_watch', { ok = Input.label('confirm') }) or L('ft.desc_' .. c.film), tx, ty, tw, 3,
                owned and { 0.65, 1, 0.65 } or { 0.78, 0.8, 0.95 }, a)
    end
    if sel then MenuKit.marker(x, y, r.w, r.h, self.t, a) end
end

function StoryCollectionState:_drawCard(i, r, oy, a)
    local c = self.list[i]
    if c and (c.shard or c.film) then return self:_drawExtra(i, r, oy, a) end
    local owned = self:owned(i)
    local sel = i == self.sel
    local x, y = r.x, r.y + oy
    local bob = (sel and math.floor(self.t * 3) % 2 == 0) and -4 or 0
    y = y + bob
    MenuKit.box(sel and 'card_sel' or 'card', x, y, r.w, r.h, a * (owned and 1 or 0.85))
    -- el hueco del icono
    local ix, iy = x + 20, y + math.floor((r.h - ICON_BOX) / 2)
    MenuKit.box('well', ix, iy, ICON_BOX, ICON_BOX, a)
    if owned and self:state(i) ~= true then
        drawIcon(Collect.image(c.id, self:state(i)), ix, iy, ICON_BOX, ICON_BOX, a)     -- (sin brillo: le falta algo)
    elseif owned then
        local gl = 0.08 + 0.06 * math.sin(self.t * 3 + i)          -- (un brillo suave detrás: es suyo)
        love.graphics.setColor(1, 0.95, 0.7, gl * a)
        love.graphics.rectangle('fill', ix + 8, iy + 8, ICON_BOX - 16, ICON_BOX - 16)
        drawIcon(Collect.image(c.id, self:state(i)), ix, iy, ICON_BOX, ICON_BOX, a)
    else
        drawIcon(lockedImage(), ix, iy, ICON_BOX, ICON_BOX, a * 0.9)
        local q = L('story.collect.unknown')
        PixelFont.shadow(q, math.floor(ix + (ICON_BOX - PixelFont.width(q, 4)) / 2),
                         math.floor(iy + (ICON_BOX - PixelFont.height(4)) / 2), 4, a, { 0.75, 0.8, 1 })
    end
    -- los textos
    local tx, tw = ix + ICON_BOX + 20, r.w - ICON_BOX - 60
    local ty = y + 20
    local keys = c.keys or ('story.collect.' .. c.id)
    if owned then
        MenuKit.text(FONT_MED, TextUtil.fit(FONT_MED, L(keys .. '.name'), tw), tx, ty, tw, 'left', { 1, 0.9, 0.45 }, a)
        ty = ty + FONT_MED:getHeight() + 10
        local kind = L('story.collect.kind.' .. tostring(c.kind))
        MenuKit.text(FONT_SMALL, kind, tx, ty, tw, 'left', { 0.6, 0.8, 1 }, a)
        local tag, line = self:stateTexts(i)
        if tag then                                                    -- (la etiqueta del estado: "ROBADA")
            local gx = tx + FONT_SMALL:getWidth(kind) + 16
            local gw = FONT_SMALL:getWidth(tag) + 12
            love.graphics.setColor(0.55, 0.12, 0.14, 0.95 * a)
            love.graphics.rectangle('fill', gx, ty - 4, gw, FONT_SMALL:getHeight() + 8)
            MenuKit.text(FONT_SMALL, tag, gx + 6, ty, gw, 'left', { 1, 0.85, 0.8 }, a)
        end
        ty = ty + FONT_SMALL:getHeight() + 12
        ty = wrapped(FONT_SMALL, L(keys .. '.desc'), tx, ty, tw, 3, nil, a) + 6
        -- (cómo se consiguió; en otro estado, lo que le pasó: "te la robó el Groove…")
        if line then wrapped(FONT_SMALL, line, tx, ty, tw, 3, { 1, 0.6, 0.5 }, a)
        else wrapped(FONT_SMALL, L(keys .. '.how'), tx, ty, tw, 3, { 0.65, 1, 0.65 }, a) end
    else
        MenuKit.text(FONT_MED, L('story.collect.unknown'), tx, ty, tw, 'left', { 0.7, 0.72, 0.85 }, a)
        ty = ty + FONT_MED:getHeight() + 10
        MenuKit.text(FONT_SMALL, L('story.collect.kind.' .. tostring(c.kind)), tx, ty, tw, 'left', { 0.5, 0.6, 0.8 }, a)
        ty = ty + FONT_SMALL:getHeight() + 12
        wrapped(FONT_SMALL, L(keys .. '.hint'), tx, ty, tw, 4, { 0.78, 0.8, 0.95 }, a)
    end
    if sel then MenuKit.marker(x, y, r.w, r.h, self.t, a) end
end

function StoryCollectionState:render()
    local A = self.anim
    -- (tapa el mapa entero —ocupa casi toda la pantalla: los ladrillos de las pantallas de la historia,
    -- docs/architecture/menus.md 0.5.20—; dim limpia además lo que el mapa apuntó para el cursor)
    MenuKit.dim(1)
    MenuScene.bricks('story')
    MenuList.header(L('story.collect.title'), 'purple', A, 1)
    -- las pestañas, cada una con su cuenta (lo que tiene / el total)
    local _, cy, ca = A:slide(2, 0, -120, 0, -120)
    local function count(tab)
        if tab == 'items' then return Collect.count(Run.active() and Run.data or nil) end
        local saved = { self.tab, self.list }
        self.tab = tab; self.list = self:_buildList()
        local n = 0
        for k = 1, #self.list do if self:owned(k) then n = n + 1 end end
        local total = #self.list
        self.tab, self.list = saved[1], saved[2]
        return n, total
    end
    local colors = { items = 'purple', shards = 'teal', films = 'orange' }
    for _, tab in ipairs(TABS) do
        local r = self:_tabRects()[tab]
        local on = self.tab == tab
        local n, total = count(tab)
        local lbl = L('story.collect.tab_' .. tab) .. ' ' .. n .. '/' .. total
        MenuButton.draw(lbl, r.x, r.y + cy, r.w, r.h, on and colors[tab] or 'grey', on and self.tabFocus, { alpha = ca, scale = 2 })
        if on and self.tabFocus then MenuKit.marker(r.x, r.y + cy, r.w, r.h, self.t, ca) end
    end
    -- las fichas (recortadas a la vista: Clip, nunca stencil)
    local Ly = layout(#self.list)
    local v = Ly.view
    local ox, oy, a = A:slide(3, 0, 120, 0, 120)
    Clip.push(v.x - 12, v.y - 12, v.w + 24, v.h + 24)
    for i, r in ipairs(Ly.cards) do
        local ry = r.y - math.floor(self.scroll) + oy
        if ry + r.h >= v.y - 12 and ry <= v.y + v.h + 12 then
            self:_drawCard(i, { x = r.x + ox, y = r.y, w = r.w, h = r.h }, -math.floor(self.scroll) + oy, a)
        end
    end
    Clip.pop()
    -- (hay más por debajo / por encima: una flecha)
    if self.scroll < Ly.maxScroll - 1 then MenuKit.text(FONT_MED, 'v', WINDOW_W - 32, v.y + v.h - 16, 24, 'left', nil, a) end
    if self.scroll > 1 then MenuKit.text(FONT_MED, '^', WINDOW_W - 32, v.y, 24, 'left', nil, a) end
    MenuKit.hint(L('story.collect.hint'), A, 4)
    CornerButtons.drawBack(self.backHover)
end

StoryCollectionState.layout = layout          -- (el arnés `collection` mira la geometría)

return StoryCollectionState
