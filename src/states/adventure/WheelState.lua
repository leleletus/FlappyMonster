-- src/states/adventure/WheelState.lua
-- La RUEDA RÁPIDA de los POWER-UPS (docs/design/powerups.md; Plan 4b). Se apila ENCIMA del nivel (como la pausa): el
-- nivel queda CONGELADO mientras está abierta (un jugador). Una casilla por tipo que se tiene, en el orden del catálogo
-- (src/world/powerups/Powerups.lua), con su icono y ×N; las que no se pueden usar ahora (pa:canUse), apagadas.
--   · Mantener (Q / Tab / L): se apunta con el ratón, las flechas / WASD o la palanca y se SUELTA para usar; soltar sin
--     elegir, Esc o la pausa: cancelar (no se gasta nada). Con la opción "rueda: pulsar" (Settings.wheelToggle), se
--     abre pulsando y se elige pulsando otra vez (o ENTER).
--   · Táctil (la bolsa del HUD de Flappy): tocar una casilla la usa (o mantener la bolsa, deslizar y levantar); tocar el
--     centro o fuera cancela.
-- Usar = `inv.spend(id)` (se GUARDA ya: el usuario) y `pa:usePowerup(id)`.
--   args = { pa = jugador, inv = { items() → { {id, count}, ... }, spend(id) → bool }, mode = 'hold' | 'toggle' | 'tap'
--            (nil = el de la opción: mantener o pulsar), touchId = el dedo que la abrió (su levantar no cuenta) }
-- Revisión final del Plan 4b: tocar la bolsa y levantar el MISMO dedo ya no la cierra; el ratón (game.lua lo manda como
-- touchpressed 'mouse', sin soltar) usa la casilla al hacer clic; soltar con la dirección (palanca / flechas) en el
-- centro CANCELA (el diseño: "soltar L con la palanca centrada")
-- 0.5.196 (el usuario: «una vez entras y te mueves para ver lo que tienes, no sé cómo salir y casi siempre termino
-- gastando uno sin querer»): abajo, SIEMPRE, cómo se usa y cómo se sale sin gastar; volver al CENTRO (ratón también)
-- deja de elegir; y al soltar solo se usa lo que lleva elegido al menos PICK_HOLD s (pasar por encima no gasta nada)
local BaseState = require 'src/core/BaseState'
local MenuKit   = require 'src/ui/menu/MenuKit'
local PixelFont = require 'src/ui/PixelFont'
local L = require 'src/core/Lang'

local WheelState = BaseState:new()

local CELL, R = 104, 222                 -- casilla (px) y radio del anillo (el centro cabe dentro sin tapar casillas)
local ICON_S = 4                         -- iconos de 12x12 ×4 (la densidad de los objetos)
local PICK_HOLD = 0.3                    -- s apuntando a la misma casilla para que soltar la use
local img, quads

local function loadArt()
    if img then return end
    img = love.graphics.newImage('assets/images/ui/powerups/icons-Sheet.png')
    img:setFilter('nearest', 'nearest')
    quads = {}
    for i = 1, img:getWidth() / 12 do quads[i] = love.graphics.newQuad((i - 1) * 12, 0, 12, 12, img:getDimensions()) end
end

function WheelState:enter(args)
    args = args or {}
    self.pa, self.inv = args.pa, args.inv
    self.mode = args.mode or (require('src/core/Settings').wheelToggle and 'toggle' or 'hold')
    self.openTouch = args.touchId                   -- (el dedo que abrió la rueda: su levantar se ignora)
    self.items = self.inv and self.inv.items() or {}
    self.sel = nil
    self.t = 0
    Sound.play('select', 1.2)
end

-- Geometría (dibujo, ratón y táctil): el centro y una casilla por tipo en el anillo, empezando arriba
function WheelState:_layout()
    local cx, cy = math.floor(WINDOW_W / 2), math.floor(WINDOW_H / 2)
    local n = math.max(1, #self.items)
    local cells = {}
    for i = 1, #self.items do
        local a = -math.pi / 2 + (i - 1) * 2 * math.pi / n
        local x, y = math.floor(cx + math.cos(a) * R - CELL / 2), math.floor(cy + math.sin(a) * R - CELL / 2)
        cells[i] = { x = x, y = y, w = CELL, h = CELL, a = a }
    end
    return { cx = cx, cy = cy, cells = cells }
end

-- La casilla en esa dirección (vector), o nil si es casi nula
function WheelState:_pick(dx, dy)
    if dx * dx + dy * dy < 0.25 or #self.items == 0 then return nil end
    local a = math.atan2(dy, dx)
    local best, bd
    for i, c in ipairs(self:_layout().cells) do
        local d = math.abs(math.atan2(math.sin(a - c.a), math.cos(a - c.a)))
        if not bd or d < bd then best, bd = i, d end
    end
    return best
end

function WheelState:_usable(i)
    local it = self.items[i]
    return it ~= nil and self.pa ~= nil and self.pa:canUse(it.id)
end

function WheelState:_close() gStateMachine:pop() end

function WheelState:_setSel(i, src)
    if i ~= self.sel then
        if i then Sound.play('select') end
        self.selT = 0
    end
    self.sel, self.lastSrc = i, src or self.lastSrc
end

function WheelState:_choose(fromRelease)
    local i = self.sel
    if fromRelease and i and (self.selT or 0) < PICK_HOLD then i = nil end      -- (pasaba por encima: no se gasta)
    if i and self:_usable(i) and self.inv.spend(self.items[i].id) then
        self.pa:usePowerup(self.items[i].id)
    elseif i then
        Sound.play('headBump')
    end
    self:_close()
end

function WheelState:update(dt)
    self.t = self.t + dt
    self.selT = (self.selT or 0) + dt
    if Input.pressed('pause') or Input.pressed('back') then Sound.play('select', 0.85); return self:_close() end
    -- apuntar: palanca o flechas / WASD
    local sx, sy = Input.stick()
    local kx = (Input.down('move_right') and 1 or 0) - (Input.down('move_left') and 1 or 0)
    local ky = (Input.down('crouch') and 1 or 0) - (Input.down('grab') and 1 or 0)
    local p = self:_pick(sx, sy) or self:_pick(kx, ky)
    if p then
        self:_setSel(p, 'dir')
    elseif self.lastSrc == 'dir' then
        self:_setSel(nil)                           -- (la palanca / las flechas vuelven al centro: nada elegido)
    end
    if self.mode == 'hold' then
        if not Input.down('wheel') then return self:_choose(true) end
    elseif self.mode == 'toggle' then
        if self.t > 0.05 and (Input.pressed('wheel') or Input.pressed('confirm')) then return self:_choose() end
    end
end

function WheelState:render()
    loadArt()
    MenuKit.dim(0.55)
    local Ly = self:_layout()
    local a = math.min(1, self.t / 0.12)
    for i, c in ipairs(Ly.cells) do
        local it, on = self.items[i], self:_usable(i)
        MenuKit.box(i == self.sel and 'card_sel' or 'card', c.x, c.y, c.w, c.h, a)
        local def = require('src/world/powerups/Powerups').get(it.id)
        love.graphics.setColor(1, 1, 1, (on and 1 or 0.35) * a)
        love.graphics.draw(img, quads[def and def.icon or 1], c.x + (c.w - 12 * ICON_S) / 2, c.y + 14, 0, ICON_S, ICON_S)
        PixelFont.shadow('x' .. it.count, c.x + c.w - 12 - PixelFont.width('x' .. it.count, 3), c.y + c.h - 30, 3, (on and 1 or 0.5) * a)
    end
    -- el centro: lo elegido (nombre y qué hace) o cómo se usa
    local it = self.sel and self.items[self.sel]
    local W, H = 300, 104
    MenuKit.box('window', Ly.cx - W / 2, Ly.cy - H / 2, W, H, a)
    if it then
        MenuKit.text(FONT_MED, L('powerup.' .. it.id), Ly.cx - W / 2 + 10, Ly.cy - 38, W - 20, 'center', { 1, 0.92, 0.4 }, a)
        MenuKit.text(FONT_SMALL, self:_usable(self.sel) and L('powerup.' .. it.id .. '.desc') or L('wheel.cant'),
                     Ly.cx - W / 2 + 10, Ly.cy + 2, W - 20, 'center', { 1, 1, 1 }, a)
    else
        local hint = (self.mode == 'tap' and 'wheel.hint_tap') or (self.mode == 'toggle' and 'wheel.hint_toggle') or 'wheel.hint'
        MenuKit.text(FONT_SMALL, #self.items == 0 and L('wheel.empty') or L(hint), Ly.cx - W / 2 + 10, Ly.cy - 6,
                     W - 20, 'center', { 1, 1, 1 }, a)
    end
    -- abajo, siempre: cómo se usa y cómo se sale sin gastar nada
    local foot = (self.mode == 'tap' and 'wheel.foot_tap') or (self.mode == 'toggle' and 'wheel.foot_toggle') or 'wheel.foot'
    local ft = L(foot, { wheel = Input.label('wheel') })
    local fw = math.min(WINDOW_W - 32, FONT_SMALL:getWidth(ft) + 40)
    MenuKit.box('window', math.floor((WINDOW_W - fw) / 2), WINDOW_H - 84, fw, 52, a)
    MenuKit.text(FONT_SMALL, ft, math.floor((WINDOW_W - fw) / 2) + 20, WINDOW_H - 66, fw - 40, 'center', { 1, 1, 1 }, a)
    love.graphics.setColor(1, 1, 1, 1)
end

-- ── Ratón y táctil ──────────────────────────────────────────────────────────
local function inside(r, x, y) return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end
function WheelState:_cellAt(x, y)
    for i, c in ipairs(self:_layout().cells) do if inside(c, x, y) then return i end end
end
function WheelState:mousemoved(x, y)
    local Ly = self:_layout()
    -- (en el centro: nada elegido, también con el ratón — antes se quedaba lo último que tocó y se gastaba al soltar —)
    self:_setSel(self:_pick((x - Ly.cx) / 60, (y - Ly.cy) / 60), 'mouse')
end
function WheelState:touchpressed(id, x, y)
    self.openTouch = nil                            -- (un toque nuevo: el dedo que la abrió ya se levantó — en Android el id se reusa —)
    local i = self:_cellAt(x, y)
    -- el RATÓN (game.lua: un clic llega como touchpressed 'mouse', sin soltar): el clic es la elección entera
    if id == 'mouse' then
        if i then self.sel = i; return self:_choose() end
        self.sel = nil
        return self:_close()
    end
    if i then self.sel = i end
end
function WheelState:touchmoved(id, x, y)
    local i = self:_cellAt(x, y)
    if i then self.sel = i end
end
function WheelState:touchreleased(id, x, y)
    if id == self.openTouch then self.openTouch = nil; return end      -- (el dedo que la abrió: tocar la bolsa no la cierra)
    local i = self:_cellAt(x, y)
    if i then self.sel = i; return self:_choose() end
    self.sel = nil
    return self:_close()
end

return WheelState
