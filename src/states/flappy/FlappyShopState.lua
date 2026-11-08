-- src/states/flappy/FlappyShopState.lua
-- La TIENDA de una zona de la campaña Flappy (docs/design/powerups.md § Shops on the world maps; Plan 5b): lo que vende
-- (src/flappy/Shops.lua), una ficha por power-up con su icono, nombre, precio y cuántos se llevan; arriba, el MONEDERO
-- y el inventario. Las que no se pueden pagar, apagadas. Comprar pide confirmación (COMPRAR / CANCELAR) y gasta el
-- monedero con FlappyRun.buy (se guarda ya); inventario lleno o 3 de ese tipo: se rechaza con un aviso y no se gasta.
--   ↑ ↓ elegir · ENTER comprar · ATRÁS al mapa · tocar una ficha: elegirla (la elegida: comprar) · el botón VOLVER
--   args = { zone = índice de la zona (src/flappy/Zones.lua), selected = ficha elegida al entrar }
-- Se abre desde el mapa de la zona (FlappyMapState: el nido del mercader) y vuelve a él, con la tienda elegida.
local BaseState     = require 'src/core/BaseState'
local CornerButtons = require 'src/ui/CornerButtons'
local MenuScene     = require 'src/ui/menu/MenuScene'
local MenuKit       = require 'src/ui/menu/MenuKit'
local MenuList      = require 'src/ui/menu/MenuList'
local MenuAnim      = require 'src/ui/menu/MenuAnim'
local FlappyRun     = require 'src/flappy/FlappyRun'
local Shops         = require 'src/flappy/Shops'
local Powerups      = require 'src/world/powerups/Powerups'
local L = require 'src/core/Lang'

local FlappyShopState = BaseState:new()

local ICON_S = 4                         -- iconos de 12x12 ×4 (la densidad de los objetos, como en la rueda)
local NOTICE_T = 2.5                     -- s que se ve el aviso de una compra
local img, quads

local function loadArt()
    if img then return end
    img = love.graphics.newImage('assets/images/ui/powerups/icons-Sheet.png')
    img:setFilter('nearest', 'nearest')
    quads = {}
    for i = 1, img:getWidth() / 12 do quads[i] = love.graphics.newQuad((i - 1) * 12, 0, 12, 12, img:getDimensions()) end
end

function FlappyShopState:enter(args)
    args = args or {}
    self.zone = args.zone or (FlappyRun.data and FlappyRun.data.world) or 1
    self.items = Shops.forZone(self.zone)
    self.sel = math.max(1, math.min(#self.items, args.selected or 1))
    self.confirm = nil                   -- (la ventana de COMPRAR / CANCELAR abierta: { sel })
    self.notice, self.noticeT, self.noticeOk = nil, 0, false
    self.N = #self.items + 3             -- rótulo, monedero, una por ficha, pie
    self.anim = MenuAnim.new({ n = self.N })
    Sound.playMusic('menus')
end

function FlappyShopState:_wallet() return (FlappyRun.data and FlappyRun.data.wallet) or 0 end
function FlappyShopState:_owned(id) return (FlappyRun.data and FlappyRun.data.inventory and FlappyRun.data.inventory[id]) or 0 end
function FlappyShopState:_affordable(i) local it = self.items[i]; return it ~= nil and self:_wallet() >= it.price end

-- Geometría (al dibujar: WINDOW_W cambia): una ficha por artículo, en columna
function FlappyShopState:_layout()
    local n = math.max(1, #self.items)
    local cw = math.min(WINDOW_W - 80, 680)
    local x = math.floor((WINDOW_W - cw) / 2)
    local top, bottom, gap = 196, WINDOW_H - 132, 14
    local ch = math.min(100, math.floor((bottom - top - gap * (n - 1)) / n))
    local cards = {}
    for i = 1, #self.items do cards[i] = { x = x, y = top + (i - 1) * (ch + gap), w = cw, h = ch } end
    return { x = x, w = cw, infoY = 146, cards = cards }
end

function FlappyShopState:_say(key, ok, args)
    self.notice, self.noticeT, self.noticeOk = L(key, args), NOTICE_T, ok
end

function FlappyShopState:_move(d)
    if #self.items == 0 then return end
    local k = (self.sel - 1 + d) % #self.items + 1
    if k ~= self.sel then self.sel = k; Sound.play('select', d > 0 and 1.08 or 0.94) end
end

-- ENTER / tocar la elegida: sin puntos o sin sitio se avisa ya (no hay nada que confirmar); si no, la confirmación
function FlappyShopState:_try()
    local it = self.items[self.sel]
    if not it then return end
    local name = L('powerup.' .. it.id)
    if not self:_affordable(self.sel) then Sound.play('headBump'); return self:_say('shop.poor', false) end
    if FlappyRun.inventoryCount() >= FlappyRun.MAX_TOTAL then Sound.play('headBump'); return self:_say('shop.full', false) end
    if self:_owned(it.id) >= FlappyRun.MAX_TYPE then Sound.play('headBump'); return self:_say('shop.type_full', false, { name = name }) end
    Sound.play('select')
    self.confirm = { sel = 1 }
end

function FlappyShopState:_buy()
    local it = self.items[self.sel]
    self.confirm = nil
    if not it then return end
    local r = FlappyRun.buy(it.id, it.price)
    local name = L('powerup.' .. it.id)
    if r == 'ok' then
        Sound.play('collect')
        self:_say('shop.bought', true, { name = name })
    else
        Sound.play('headBump')
        self:_say('shop.' .. r, false, { name = name })
    end
end

function FlappyShopState:_choose(i)
    if i == 1 then return self:_buy() end
    Sound.play('select', 0.85)
    self.confirm = nil
end

function FlappyShopState:_back()
    Sound.play('select', 0.85)
    self.anim:leave(function() gStateMachine:change('flappy_map', { world = self.zone, shop = true }) end, self.N)   -- (con la tienda elegida)
end

function FlappyShopState:update(dt)
    MenuScene.update(dt)
    self.anim:update(dt)
    if self.noticeT > 0 then self.noticeT = math.max(0, self.noticeT - dt) end
    if self.anim:busy() then return end
    if self.confirm then
        if Input.pressed('back') then return self:_choose(2) end
        if Input.pressed('nav_up') or Input.pressed('nav_down') then
            self.confirm.sel = 3 - self.confirm.sel
            Sound.play('select')
        end
        if Input.pressed('confirm') then return self:_choose(self.confirm.sel) end
        return
    end
    if Input.pressed('nav_up') then self:_move(-1) end
    if Input.pressed('nav_down') then self:_move(1) end
    if Input.pressed('confirm') then return self:_try() end
    if Input.pressed('back') then return self:_back() end
end

function FlappyShopState:render()
    loadArt()
    MenuScene.draw()
    MenuList.header(L('shop.title'), 'yellow', self.anim, 1)
    local Ly = self:_layout()
    -- el monedero y el inventario
    local _, oy, ia = self.anim:slide(2, 0, -60)
    MenuKit.text(FONT_MED, L('shop.wallet', { n = self:_wallet() }), Ly.x, Ly.infoY + oy, Ly.w, 'left', { 1, 0.86, 0.36 }, ia)
    MenuKit.text(FONT_MED, L('shop.bag', { n = FlappyRun.inventoryCount(), m = FlappyRun.MAX_TOTAL }), Ly.x, Ly.infoY + oy, Ly.w,
                 'right', { 0.85, 0.88, 1 }, ia)
    -- las fichas
    for i, c in ipairs(Ly.cards) do
        local it = self.items[i]
        local ox, _, a = self.anim:slide(2 + i, 80, 0)
        local on, can = i == self.sel, self:_affordable(i)
        local x, y = c.x + ox, c.y
        MenuKit.box(on and 'card_sel' or 'card', x, y, c.w, c.h, a)
        local def = Powerups.get(it.id)
        local k = can and 1 or 0.4
        love.graphics.setColor(1, 1, 1, k * a)
        local is = 12 * ICON_S
        love.graphics.draw(img, quads[def and def.icon or 1], x + 22, y + math.floor((c.h - is) / 2), 0, ICON_S, ICON_S)
        local tx = x + 22 + is + 22
        local grey = { 0.6, 0.6, 0.66 }
        MenuKit.text(FONT_MED, L('powerup.' .. it.id), tx, y + 14, c.w - (tx - x) - 200, 'left', can and { 1, 1, 1 } or grey, a)
        local owned = self:_owned(it.id)
        MenuKit.text(FONT_SMALL, L('shop.owned', { n = owned, m = FlappyRun.MAX_TYPE }), tx, y + c.h - 34, c.w - (tx - x) - 20,
                     'left', owned >= FlappyRun.MAX_TYPE and { 1, 0.6, 0.45 } or { 0.85, 0.88, 1 }, a)
        MenuKit.text(FONT_MED, L('shop.price', { n = it.price }), x, y + 14, c.w - 22, 'right',
                     can and { 1, 0.86, 0.36 } or { 0.85, 0.4, 0.35 }, a)
        if on and not self.confirm then MenuKit.marker(x, y, c.w, c.h, love.timer.getTime(), a) end
    end
    -- la descripción del elegido y la ayuda
    local it = self.items[self.sel]
    MenuList.footer(it and L('powerup.' .. it.id .. '.desc') or nil, self.anim, self.N)
    if self.noticeT > 0 and self.notice then
        MenuKit.text(FONT_MED, self.notice, 0, WINDOW_H - 160, WINDOW_W, 'center',
                     self.noticeOk and { 0.55, 1, 0.55 } or { 1, 0.4, 0.35 }, math.min(1, self.noticeT))
    end
    CornerButtons.drawBack(self.backHover)
    if self.confirm and it then
        MenuKit.optionsWindow(L('powerup.' .. it.id), { L('shop.buy'), L('shop.cancel') }, { 'green', 'grey' }, self.confirm.sel, 1,
                              { note = L('shop.confirm', { n = it.price, w = self:_wallet() }) })
    end
end

-- ── Ratón y táctil ──────────────────────────────────────────────────────────
local CONFIRM_O = { note = true }        -- (la ventana lleva nota: la misma geometría que al dibujarla)

function FlappyShopState:_cardAt(x, y)
    for i, c in ipairs(self:_layout().cards) do
        if x >= c.x and x <= c.x + c.w and y >= c.y and y <= c.y + c.h then return i end
    end
end

function FlappyShopState:mousemoved(x, y)
    if self.confirm then
        local i = MenuKit.optionAt(2, x, y, CONFIRM_O)
        if i and i ~= self.confirm.sel then self.confirm.sel = i; Sound.play('select') end
        return
    end
    self.backHover = CornerButtons.hitBack(x, y)
end

function FlappyShopState:touchpressed(id, x, y)
    if self.anim:busy() then return end
    if self.confirm then
        local i = MenuKit.optionAt(2, x, y, CONFIRM_O)
        if i then return self:_choose(i) end
        local P = MenuKit.optionsLayout(2, CONFIRM_O)
        if x < P.x or x > P.x + P.w or y < P.y or y > P.y + P.h then self:_choose(2) end     -- (fuera de la ventana: cancelar)
        return
    end
    if CornerButtons.hitBack(x, y) then return self:_back() end
    local k = self:_cardAt(x, y)
    if not k then return end
    if k == self.sel then return self:_try() end
    self.sel = k
    Sound.play('select')
end

return FlappyShopState
