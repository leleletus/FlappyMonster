-- src/states/menu/SettingsState.lua
-- Configuración (desde el menú principal): idioma (src/core/Lang.lua + assets/lang/), volúmenes, silencio, A / B del
-- mando...; se guarda con src/core/Settings.lua.
-- Mandos/teclado: izquierda/derecha (o confirmar) cambian, atrás vuelve; abajo: el botón de los CRÉDITOS (la película
-- de los créditos, docs/story/credits.md; siempre se pueden ver desde aquí).
-- Ratón/táctil: flechas o el nombre del idioma; el botón de los créditos.
-- Como todas las pantallas de menú (docs/architecture/menus.md): fondo vivo, rótulo, botones de colores que entran y salen.

local CornerButtons = require 'src/ui/CornerButtons'
local BaseState     = require 'src/core/BaseState'
local PixelFont     = require 'src/ui/PixelFont'
local Settings      = require 'src/core/Settings'
local MenuScene     = require 'src/ui/menu/MenuScene'
local MenuAnim      = require 'src/ui/menu/MenuAnim'
local MenuList      = require 'src/ui/menu/MenuList'
local MenuButton    = require 'src/ui/menu/MenuButton'
local L             = require 'src/core/Lang'
local SettingsState = BaseState:new()

local ARROW_W = 76

local function langIndex()
    for i, l in ipairs(L.LANGUAGES) do if l.id == L.current() then return i end end
    return 1
end

-- Las FILAS, de arriba abajo: el texto, su color, `step(d)` (izquierda / derecha) y `go()` (confirmar). Una opción nueva es
-- una fila más; las que no caben se ven desplazándose con la seleccionada.
local function vol(key, label)
    return { color = 'green', text = function() return L(label, { n = tostring(Settings[key]) }) end,
             step = function(_, d) Settings.set(key, math.max(0, math.min(10, Settings[key] + d))); Sound.play('select', d > 0 and 1.08 or 0.94) end }
end
local function flag(key, on, off, color)
    local toggle = function() Settings.set(key, not Settings[key]); Sound.play('select', Settings[key] and 1.08 or 0.94) end
    return { color = color, text = function() return L(Settings[key] and on or off) end, step = toggle, go = toggle }
end
local ROWS = {
    { color = 'teal', text = function() return L.LANGUAGES[langIndex()].name end,
      step = function(self, d) self:_step(d) end, go = function(self) self:_step(1) end },
    vol('musicVol', 'settings.music'),
    vol('sfxVol', 'settings.sfx'),
    flag('muted', 'settings.mute_on', 'settings.mute_off', 'green'),
    flag('swapAB', 'settings.swap_on', 'settings.swap_off', 'blue'),
    -- (el retardo del audio en el duelo de ritmo del Cangrejo Groove: depende del aparato)
    { color = 'pink', text = function() return L('settings.rhythm_offset', { ms = tostring(Settings.rhythmOffset or 0) }) end,
      step = function(self, d) self:_offset(d * 10) end },
    -- (el medidor de rendimiento: src/ui/PerfOverlay.lua)
    { color = 'orange', text = function() return L(Settings.showPerf and 'settings.perf_on' or 'settings.perf_off') end,
      step = function(self) self:_perf() end, go = function(self) self:_perf() end },
    { color = 'purple', text = function() return L('credits.button') end, go = function(self) return self:_credits() end },
}
SettingsState.ROWS = ROWS

-- Geometría compartida por dibujo, ratón y táctil: las filas que caben, desde `first`, con una flecha a cada lado
local function layout(first)
    local w = math.min(MenuList.W, WINDOW_W - 2 * ARROW_W - 120)
    local h, gap = 56, 10
    local y = math.floor(WINDOW_H * 0.2)
    local x = math.floor((WINDOW_W - w) / 2)
    local fit = math.max(1, math.floor((WINDOW_H - 130 - y + gap) / (h + gap)))
    local out = { fit = math.min(fit, #ROWS), rows = {} }
    for i = 0, out.fit - 1 do
        out.rows[first + i] = { x = x, y = y + i * (h + gap), w = w, h = h }
    end
    out.arrow = function(r)
        return { x = r.x - ARROW_W - 16, y = r.y, w = ARROW_W, h = r.h }, { x = r.x + r.w + 16, y = r.y, w = ARROW_W, h = r.h }
    end
    return out
end

local function inside(r, x, y, pad)
    pad = pad or 8
    return x >= r.x - pad and x <= r.x + r.w + pad and y >= r.y - pad and y <= r.y + r.h + pad
end

function SettingsState:enter()
    self.anim = MenuAnim.new({ n = 6 })
    self.t, self.flash, self.row, self.first = 0, nil, 1, 1
    Sound.playMusic('menus')
end

function SettingsState:_step(d)
    local n = #L.LANGUAGES
    local i = (langIndex() - 1 + d) % n + 1
    Settings.setLanguage(L.LANGUAGES[i].id)
    self.flash = { d = d, t = 0 }
    Sound.play('select', d > 0 and 1.08 or 0.94)
end

function SettingsState:_offset(d)
    Settings.setRhythmOffset((Settings.rhythmOffset or 0) + d)
    Sound.play('select', d > 0 and 1.08 or 0.94)
end

function SettingsState:_perf()
    Settings.setShowPerf(not Settings.showPerf)
    Sound.play('select', Settings.showPerf and 1.08 or 0.94)
end

-- Los créditos (y de vuelta aquí)
function SettingsState:_credits()
    Sound.play('select', 1.25)
    self.anim:leave(function() end, 5)
    require('src/ui/menu/Transition').go('story_film', { film = 'credits', onDone = function() gStateMachine:change('settings') end })
end

function SettingsState:_back()
    if self.anim:busy() then return end
    Sound.play('select', 0.85)
    self.anim:leave(function() gStateMachine:change('main_menu', { selected = 3 }) end, 5)
end

-- Elegir una fila: la lista se desplaza para que se vea
function SettingsState:_select(i)
    self.row = i
    local fit = layout(1).fit
    if i < self.first then self.first = i elseif i >= self.first + fit then self.first = i - fit + 1 end
end

function SettingsState:update(dt)
    self.t = self.t + dt
    if self.flash then self.flash.t = self.flash.t + dt end
    MenuScene.update(dt)
    self.anim:update(dt)
    if self.anim:busy() then return end
    local n, row = #ROWS, self.row
    if Input.pressed('nav_down') then self:_select(row % n + 1); Sound.play('select') end
    if Input.pressed('nav_up') then self:_select((row + n - 2) % n + 1); Sound.play('select') end
    local r = ROWS[self.row]
    if r.step then
        if Input.pressed('nav_left') then r.step(self, -1) end
        if Input.pressed('nav_right') then r.step(self, 1) end
    end
    if r.go and (Input.pressed('confirm') or (not r.step and Input.pressed('flap'))) then return r.go(self) end
    if Input.pressed('back') then self:_back() end
end

function SettingsState:render()
    MenuScene.draw()
    MenuList.header(L('menu.settings'), 'blue', self.anim, 1)

    local Lt = layout(self.first)
    local A = self.anim
    local ox, oy, a = A:slide(3, 0, 220)
    local bob = (math.floor(self.t * 3) % 2 == 0) and -4 or 0
    for i, box in pairs(Lt.rows) do
        local on = i == self.row
        local kick = (on and self.flash and self.flash.t < 0.14) and self.flash.d * 8 or 0
        MenuButton.draw(ROWS[i].text(), box.x + ox + kick, box.y + oy + (on and bob or 0), box.w, box.h, ROWS[i].color, on, { alpha = a })
        if on and ROWS[i].step then
            local l, r = Lt.arrow(box)
            local ox3, oy3, a3 = A:slide(4, 0, 220)
            MenuButton.draw('<', l.x + ox3, l.y + oy3, l.w, l.h, 'yellow', self.hover == 'left', { alpha = a3 })
            MenuButton.draw('>', r.x + ox3, r.y + oy3, r.w, r.h, 'yellow', self.hover == 'right', { alpha = a3 })
        end
    end

    MenuList.footer(L('menu.desc_settings'), A, 6,
        L('settings.hint', { change = Input.label('nav_left') .. Input.label('nav_right'), back = Input.label('back') }))
    love.graphics.setColor(COLOR_WHITE)
    CornerButtons.drawBack(self.backHover)
end

function SettingsState:mousemoved(tx, ty)
    self.backHover = CornerButtons.hitBack(tx, ty)
    local Lt = layout(self.first)
    local sel = Lt.rows[self.row]
    self.hover = nil
    if sel then
        local l, r = Lt.arrow(sel)
        self.hover = (inside(l, tx, ty) and 'left') or (inside(r, tx, ty) and 'right') or nil
    end
    for i, box in pairs(Lt.rows) do if inside(box, tx, ty, 3) then self:_select(i) end end
end

function SettingsState:touchpressed(id, tx, ty)
    if self.anim:busy() then return end
    if CornerButtons.hitBack(tx, ty) then return self:_back() end
    local Lt = layout(self.first)
    local sel = Lt.rows[self.row]
    if sel and ROWS[self.row].step then
        local l, r = Lt.arrow(sel)
        if inside(l, tx, ty) then return ROWS[self.row].step(self, -1) end
        if inside(r, tx, ty) then return ROWS[self.row].step(self, 1) end
    end
    for i, box in pairs(Lt.rows) do
        if inside(box, tx, ty, 3) then
            local was = self.row == i
            self:_select(i)
            local row = ROWS[i]
            -- (la fila ya elegida: confirmar, o la mitad izquierda / derecha baja o sube)
            if was or not row.step then
                if row.go then return row.go(self) end
                return row.step(self, tx < box.x + box.w / 2 and -1 or 1)
            end
            return
        end
    end
end

return SettingsState
