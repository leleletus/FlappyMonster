-- src/ui/menu/MenuList.lua
-- Una LISTA DE BOTONES de menú (docs/architecture/menus.md): botones de colores en columna (src/ui/menu/MenuButton), el
-- seleccionado más claro, botando y con el monstruito al lado; entran y salen con la animación de la pantalla
-- (src/ui/menu/MenuAnim). Una sola geometría para dibujo, ratón y táctil. Y lo común de las pantallas de menú:
-- el RÓTULO de arriba, la DESCRIPCIÓN del botón elegido y la línea de AYUDA de abajo.
--   local list = MenuList.new{ items = { { text = 'menu.adventure', color = 'green', desc = 'menu.desc_adventure',
--                                          go = function(i) ... end }, ... }, anim = A, first = 2, top = 0.36 }
--   list:update(dt)  list:draw()  list:mousemoved(x, y)  list:touchpressed(x, y)
--   MenuList.header(texto, color, A, i)   MenuList.footer(desc, A, i)
local PixelFont  = require 'src/ui/PixelFont'
local MenuButton = require 'src/ui/menu/MenuButton'
local L          = require 'src/core/Lang'

local MenuList = {}
MenuList.__index = MenuList

MenuList.W, MenuList.H, MenuList.GAP = 520, 68, 14      -- px de cada botón y entre botones
local ICON_S = 4                                         -- escala del monstruito que marca el elegido

local icon
local function iconImg()
    if not icon then icon = love.graphics.newImage('assets/images/player/icon.png') end
    return icon
end

-- o.items: { text (clave de idioma o texto con raw = true), color, desc (clave), descArgs, go(i), disabled }
-- o.anim: la MenuAnim de la pantalla; o.first: número de orden del primer botón en ella (los anteriores son el
-- rótulo...); o.top: dónde empieza la lista (0..1 del alto; centrada si no); o.selected
function MenuList.new(o)
    local l = setmetatable({ items = o.items, anim = o.anim, first = o.first or 1, top = o.top,
                             selected = o.selected or 1, t = 0, w = o.w, h = o.h, gap = o.gap }, MenuList)
    l.selected = math.max(1, math.min(#l.items, l.selected))
    return l
end

function MenuList:text(i)
    local it = self.items[i]
    return it.raw and it.text or L(it.text)
end

-- Rectángulos de los botones (la única fuente de geometría)
function MenuList:layout()
    local n = #self.items
    local h, gap = self.h or MenuList.H, self.gap or MenuList.GAP
    -- (en pantallas bajas o con muchos botones, más juntos)
    local avail = WINDOW_H * (1 - (self.top or 0.3)) - 120
    while n * h + (n - 1) * gap > avail and h > 56 do h, gap = h - 4, math.max(8, gap - 2) end
    local w = math.min(self.w or MenuList.W, WINDOW_W - 160)
    local total = n * h + (n - 1) * gap
    local y = self.top and math.floor(WINDOW_H * self.top) or math.floor((WINDOW_H - total) / 2)
    local x = math.floor((WINDOW_W - w) / 2)
    local out = {}
    for i = 1, n do out[i] = { x = x, y = y + (i - 1) * (h + gap), w = w, h = h } end
    return out
end

function MenuList:move(d)
    local n = #self.items
    for _ = 1, n do
        self.selected = (self.selected - 1 + d) % n + 1
        if not self.items[self.selected].disabled then break end
    end
    self.t = 0
    Sound.play('select', d > 0 and 1.08 or 0.94)
end

function MenuList:choose(i)
    local it = self.items[i]
    if not it or it.disabled or (self.anim and self.anim:busy()) then return end
    self.selected = i
    self.chosen, self.t = i, 0
    Sound.play('select', 1.25)
    if it.go then it.go(i) end
end

function MenuList:update(dt)
    self.t = self.t + dt
    if self.anim and self.anim:busy() then return end
    if Input.pressed('nav_up') then self:move(-1) end
    if Input.pressed('nav_down') then self:move(1) end
    if Input.pressed('confirm') or Input.pressed('flap') then self:choose(self.selected) end
end

function MenuList:draw()
    local A = self.anim
    for i, r in ipairs(self:layout()) do
        local it = self.items[i]
        local sel = i == self.selected and not it.disabled
        -- entran desde abajo, uno detrás de otro
        local ox, oy, a = 0, 0, 1
        if A then ox, oy, a = A:slide(self.first + i - 1, 0, 220) end
        -- el elegido bota (2 px arriba y abajo, a saltos); el que se acaba de pulsar, se hunde un momento
        local bob = 0
        if sel then bob = (math.floor(self.t * 3) % 2 == 0) and -4 or 0 end
        if self.chosen == i and self.t < 0.12 then bob = 4 end
        local color = it.disabled and 'grey' or it.color
        MenuButton.draw(self:text(i), r.x + ox, r.y + oy + bob, r.w, r.h, color, sel, { alpha = a * (it.disabled and 0.7 or 1) })
        if sel then
            -- el monstruito, a la izquierda, saltando
            local im = iconImg()
            local hop = math.floor(math.abs(math.sin(self.t * 6)) * 3) * 4
            local ix = r.x + ox - im:getWidth() * ICON_S - 20
            local iy = r.y + oy + math.floor((r.h - im:getHeight() * ICON_S) / 2) - hop - 4
            love.graphics.setColor(0, 0, 0, 0.4 * a)
            love.graphics.draw(im, ix + 4, iy + 4 + hop, 0, ICON_S, ICON_S)
            love.graphics.setColor(1, 1, 1, a)
            love.graphics.draw(im, ix, iy, 0, ICON_S, ICON_S)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- La descripción del botón elegido (o nil)
function MenuList:desc()
    local it = self.items[self.selected]
    return it and it.desc and L(it.desc, it.descArgs) or nil
end

local function hit(r, x, y) return x >= r.x - 8 and x <= r.x + r.w + 8 and y >= r.y - 6 and y <= r.y + r.h + 6 end

function MenuList:mousemoved(x, y)
    if self.anim and self.anim:busy() then return end
    for i, r in ipairs(self:layout()) do
        if hit(r, x, y) and not self.items[i].disabled then
            if self.selected ~= i then self.selected, self.t = i, 0; Sound.play('select') end
            return true
        end
    end
end

function MenuList:touchpressed(x, y)
    for i, r in ipairs(self:layout()) do
        if hit(r, x, y) then self:choose(i); return true end
    end
end

-- ── Lo común de las pantallas de menú ──────────────────────────────────────

-- El RÓTULO de arriba: un botón grande (sin seleccionar) con el título; entra desde arriba
function MenuList.header(text, color, A, i)
    local s = 7
    while s > 3 and PixelFont.width(text, s) > WINDOW_W - 260 do s = s - 1 end
    local w = PixelFont.width(text, s) + 26 * MenuButton.S
    local h = PixelFont.height(s) + 14 * MenuButton.S
    local x, y = math.floor((WINDOW_W - w) / 2), 36
    local ox, oy, a = 0, 0, 1
    if A then ox, oy, a = A:slide(i or 1, 0, -200) end
    MenuButton.draw(text, x + ox, y + oy, w, h, color, false, { alpha = a, scale = s })
    return y + h
end

-- La DESCRIPCIÓN del elegido (en un panel abajo) y la AYUDA de los botones
function MenuList.footer(desc, A, i, hint)
    local ox, oy, a = 0, 0, 1
    if A then ox, oy, a = A:slide(i or 1, 0, 160) end
    if desc then
        love.graphics.setFont(FONT_MED)
        local w = math.min(WINDOW_W - 80, FONT_MED:getWidth(desc) + 64)
        local h = 52
        local x, y = math.floor((WINDOW_W - w) / 2) + ox, WINDOW_H - 112 + oy
        MenuButton.panel(x, y, w, h, 0.95 * a)
        love.graphics.setColor(1, 1, 1, a)
        love.graphics.printf(desc, x, y + math.floor((h - FONT_MED:getHeight()) / 2) + 2, w, 'center')
    end
    hint = hint or L('menu.hint', { move = Input.label('nav_up') .. Input.label('nav_down'),
                                    ok = Input.label('confirm'), back = Input.label('back') })
    if hint ~= '' then
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(0, 0, 0, 0.6 * a)
        love.graphics.printf(hint, 2, WINDOW_H - 40 + oy + 2, WINDOW_W, 'center')
        love.graphics.setColor(1, 1, 1, 0.9 * a)
        love.graphics.printf(hint, 0, WINDOW_H - 40 + oy, WINDOW_W, 'center')
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return MenuList
