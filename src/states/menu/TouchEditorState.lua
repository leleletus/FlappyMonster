-- src/states/menu/TouchEditorState.lua
-- EL EDITOR DE LOS CONTROLES TÁCTILES (0.5.207, docs/design/touch-editor.md; el usuario: «que se puedan mover a su gusto»,
-- tamaño por botón, opacidad para todos). Opciones → CONTROLES → EDITAR CONTROLES TÁCTILES. Los botones de verdad
-- (src/ui/TouchControls.lua: cruceta, salto, correr y el extra — se ve la linterna —) sobre el fondo de los menús; con
-- el dedo (o el ratón) se ARRASTRA uno a donde se quiera; tocarlo lo ELIGE. Arriba — en la franja donde los botones no
-- pueden ir — el panel: TAMAÑO del elegido, OPACIDAD de todos, RESTABLECER y LISTO. Cada botón queda dentro, bajo la
-- franja del HUD y sin pisar a otro (TouchControls.clampLayout). Se guarda en las opciones (Settings.touchLayout).
-- Teclado / mando (para probar en PC): Tab / L / R cambia de botón, las flechas lo mueven, confirmar o atrás = listo.
local BaseState  = require 'src/core/BaseState'
local TC         = require 'src/ui/TouchControls'
local MenuButton = require 'src/ui/menu/MenuButton'
local L          = require 'src/core/Lang'

local TE = BaseState:new()

local KEYS = TC.KEYS
local GRAB_K = 1.15            -- (para cogerlo con el dedo: un poco más que el dibujo)

-- La disposición de ahora como fracciones (la guardada o la de siempre) en esta pantalla
local function current(sw, sh)
    local S = require 'src/core/Settings'
    local t = S.touchLayout
    if t and t.moved then
        local c = {}
        for _, k in ipairs(KEYS) do c[k] = { t[k][1], t[k][2], t[k][3] } end
        c.alpha, c.moved = t.alpha or 1, true
        return c
    end
    local D = TC.layout(sw, sh, false)
    return { pad = { D.padX / sw, D.padY / sh, 1 }, jump = { D.jumpX / sw, D.jumpY / sh, 1 },
             run = { D.runX / sw, D.runY / sh, 1 }, extra = { D.lightX / sw, D.lightY / sh, 1 },
             alpha = (t and t.alpha) or 1, moved = false }
end

function TE:enter(args)
    self.args = args or {}
    self.sw, self.sh = love.graphics.getDimensions()
    self.work = current(self.sw, self.sh)
    self.sel = 'pad'
    self.drag = nil
    self.t = 0
end

-- El dibujo de lo que se está editando (siempre en su sitio de ahora)
function TE:layout()
    local w = self.work
    return TC.layout(self.sw, self.sh, { pad = w.pad, jump = w.jump, run = w.run, extra = w.extra, alpha = w.alpha, moved = true })
end

-- Los rectángulos del panel en coordenadas LÓGICAS (lovesize): una sola fuente para dibujar y tocar
function TE:panel()
    local W = WINDOW_W
    local pw = math.min(W - 40, 760)
    local px = math.floor((W - pw) / 2)
    local P = { x = px, y = 12, w = pw, h = 190 }
    local barX, barW = px + 250, pw - 280
    P.size  = { x = barX, y = P.y + 54,  w = barW, h = 28 }
    P.alpha = { x = barX, y = P.y + 96,  w = barW, h = 28 }
    local bw = math.floor((pw - 60) / 2)
    P.reset = { x = px + 20, y = P.y + 136, w = bw, h = 40 }
    P.done  = { x = px + 40 + bw, y = P.y + 136, w = bw, h = 40 }
    return P
end

local function inside(r, x, y) return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end

-- De la pantalla real al juego (lovesize)
function TE:toLogical(sx, sy)
    local gx, gy, _, _, s = TC.gameRect(self.sw, self.sh)
    return (sx - gx) / s, (sy - gy) / s
end

function TE:_place(key, fx, fy, size)
    local w = self.work
    local v = w[key]
    w[key] = { fx or v[1], fy or v[2], size or v[3] }
    -- (colocado: el que se mueve manda — va primero — y los demás se apartan solo si hace falta)
    local order = { key }
    for _, k in ipairs(KEYS) do if k ~= key then order[#order + 1] = k end end
    local c = TC.clampLayout(w, self.sw, self.sh, order)
    for _, k in ipairs(KEYS) do w[k] = c[k] end
    w.moved = true
end

function TE:_value(rect, x)
    return math.max(0, math.min(1, (x - rect.x) / rect.w))
end

-- Un dedo / el ratón en (sx, sy) de la pantalla real: `down` = recién pulsado
function TE:pointer(sx, sy, down)
    local lx, ly = self:toLogical(sx, sy)
    local P = self:panel()
    if down then
        if inside(P.reset, lx, ly) then self:reset(); return end
        if inside(P.done, lx, ly) then self:done(); return end
        if inside(P.size, lx, ly) then self.drag = { slider = 'size' }
        elseif inside(P.alpha, lx, ly) then self.drag = { slider = 'alpha' }
        else
            local Lt = self:layout()
            for _, b in ipairs(TC.buttons(Lt, 'light', true)) do
                if (sx - b.x) ^ 2 + (sy - b.y) ^ 2 <= (b.r * GRAB_K) ^ 2 then
                    self.sel = b.key
                    self.drag = { key = b.key, dx = b.x - sx, dy = b.y - sy }
                    Sound.play('select')
                    break
                end
            end
        end
    end
    local d = self.drag
    if not d then return end
    if d.slider == 'size' then
        self:_place(self.sel, nil, nil, TC.SIZE_MIN + self:_value(P.size, lx) * (TC.SIZE_MAX - TC.SIZE_MIN))
    elseif d.slider == 'alpha' then
        self.work.alpha = TC.ALPHA_MIN + self:_value(P.alpha, lx) * (1 - TC.ALPHA_MIN)
    elseif d.key then
        self:_place(d.key, (sx + d.dx) / self.sw, (sy + d.dy) / self.sh)
    end
end

function TE:release() self.drag = nil end

function TE:reset()
    Sound.play('select', 0.9)
    local D = TC.layout(self.sw, self.sh, false)
    self.work = { pad = { D.padX / self.sw, D.padY / self.sh, 1 }, jump = { D.jumpX / self.sw, D.jumpY / self.sh, 1 },
                  run = { D.runX / self.sw, D.runY / self.sh, 1 }, extra = { D.lightX / self.sw, D.lightY / self.sh, 1 },
                  alpha = 1, moved = false }
end

-- Guardar y volver a las opciones (a esta fila)
function TE:done()
    Sound.play('select', 1.1)
    local S = require 'src/core/Settings'
    local w = self.work
    if w.moved or math.abs((w.alpha or 1) - 1) > 0.001 then S.touchLayout = S.cleanTouch(w) else S.touchLayout = nil end
    S.save()
    gStateMachine:change('settings', { tab = 'controls', row = 'touchEdit' })
end

function TE:update(dt)
    self.t = self.t + dt
    require('src/ui/menu/MenuScene').update(dt)
    local sw, sh = love.graphics.getDimensions()
    if sw ~= self.sw or sh ~= self.sh then self.sw, self.sh = sw, sh end
    -- dedos (el primero) o ratón, en píxeles de pantalla
    local touches = love.touch.getTouches()
    local x, y, held
    if #touches > 0 then x, y = love.touch.getPosition(touches[1]); held = true
    elseif love.mouse.isDown(1) then x, y = love.mouse.getPosition(); held = true end
    if held then self:pointer(x, y, not self.wasHeld) elseif self.wasHeld then self:release() end
    self.wasHeld = held
    -- teclado / mando
    if Input.pressed('tab_next') or Input.pressed('tab_prev') then
        local d = Input.pressed('tab_prev') and -1 or 1
        local i = 1
        for k, v in ipairs(KEYS) do if v == self.sel then i = k end end
        self.sel = KEYS[(i - 1 + d) % #KEYS + 1]; Sound.play('select')
    end
    local step = 0.02
    local v = self.work[self.sel]
    if Input.pressed('nav_left') then self:_place(self.sel, v[1] - step, nil) end
    if Input.pressed('nav_right') then self:_place(self.sel, v[1] + step, nil) end
    if Input.pressed('nav_up') then self:_place(self.sel, nil, v[2] - step) end
    if Input.pressed('nav_down') then self:_place(self.sel, nil, v[2] + step) end
    if Input.pressed('confirm') or Input.pressed('back') then self:done() end
end

local function bar(r, k, label)
    love.graphics.setColor(0.12, 0.13, 0.2, 1)
    love.graphics.rectangle('fill', r.x, r.y, r.w, r.h)
    love.graphics.setColor(1, 0.85, 0.3, 1)
    love.graphics.rectangle('fill', r.x + 3, r.y + 3, math.floor((r.w - 6) * k), r.h - 6)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(FONT_MED)
    love.graphics.print(label, r.x - 230, r.y + math.floor((r.h - FONT_MED:getHeight()) / 2))
end

function TE:render()
    require('src/ui/menu/MenuScene').draw()
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)
    local P = self:panel()
    MenuButton.panel(P.x, P.y, P.w, P.h, 0.95)
    love.graphics.setFont(FONT_MED)
    love.graphics.setColor(1, 0.9, 0.45, 1)
    love.graphics.printf(L('touched.title') .. ' · ' .. L('touched.btn_' .. self.sel), P.x, P.y + 16, P.w, 'center')
    local v = self.work[self.sel]
    bar(P.size, (v[3] - TC.SIZE_MIN) / (TC.SIZE_MAX - TC.SIZE_MIN), L('touched.size') .. ' ' .. math.floor(v[3] * 100 + 0.5) .. '%')
    bar(P.alpha, ((self.work.alpha or 1) - TC.ALPHA_MIN) / (1 - TC.ALPHA_MIN), L('touched.alpha') .. ' ' .. math.floor((self.work.alpha or 1) * 100 + 0.5) .. '%')
    for _, b in ipairs({ { P.reset, 'touched.reset' }, { P.done, 'touched.done' } }) do
        local r = b[1]
        MenuButton.panel(r.x, r.y, r.w, r.h, 1)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(L(b[2]), r.x, r.y + math.floor((r.h - FONT_MED:getHeight()) / 2), r.w, 'center')
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Los botones, en píxeles de pantalla (como en el juego), y el elegido con su marco dorado
function TE:drawScreen()
    local Lt = self:layout()
    TC.draw(Lt, { l = false, r = false, d = false, j = false, rn = false }, 1, 'light', true)
    for _, b in ipairs(TC.buttons(Lt, 'light', true)) do
        if b.key == self.sel then
            local pulse = 0.6 + 0.4 * math.abs(math.sin(self.t * 4))
            love.graphics.setColor(1, 0.85, 0.3, pulse)
            love.graphics.setLineWidth(4)
            love.graphics.circle('line', b.x, b.y, b.r + 6)
            love.graphics.setLineWidth(1)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return TE
