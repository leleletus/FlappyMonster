-- src/states/menu/SettingsState.lua
-- Configuración (desde el menú principal). Por ahora solo el idioma
-- (src/core/Lang.lua + assets/lang/); se guarda con src/core/Settings.lua.
-- Mandos/teclado: izquierda/derecha (o confirmar) cambian, atrás vuelve.
-- Ratón/táctil: flechas o el nombre del idioma.
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

-- Geometría compartida por dibujo, ratón y táctil: el botón del idioma con una flecha a cada lado
local function layout()
    local w = math.min(MenuList.W, WINDOW_W - 2 * ARROW_W - 120)
    local h = MenuList.H
    local y = math.floor(WINDOW_H * 0.46)
    local x = math.floor((WINDOW_W - w) / 2)
    return {
        value = { x = x, y = y, w = w, h = h },
        left  = { x = x - ARROW_W - 16, y = y, w = ARROW_W, h = h },
        right = { x = x + w + 16, y = y, w = ARROW_W, h = h },
    }
end

local function inside(r, x, y, pad)
    pad = pad or 8
    return x >= r.x - pad and x <= r.x + r.w + pad and y >= r.y - pad and y <= r.y + r.h + pad
end

function SettingsState:enter()
    self.anim = MenuAnim.new({ n = 5 })
    self.t, self.flash = 0, nil
    Sound.playMusic('menus')
end

function SettingsState:_step(d)
    local n = #L.LANGUAGES
    local i = (langIndex() - 1 + d) % n + 1
    Settings.setLanguage(L.LANGUAGES[i].id)
    self.flash = { d = d, t = 0 }
    Sound.play('select', d > 0 and 1.08 or 0.94)
end

function SettingsState:_back()
    if self.anim:busy() then return end
    Sound.play('select', 0.85)
    self.anim:leave(function() gStateMachine:change('main_menu', { selected = 3 }) end, 5)
end

function SettingsState:update(dt)
    self.t = self.t + dt
    if self.flash then self.flash.t = self.flash.t + dt end
    MenuScene.update(dt)
    self.anim:update(dt)
    if self.anim:busy() then return end
    if Input.pressed('nav_left') then self:_step(-1) end
    if Input.pressed('nav_right') or Input.pressed('confirm') then self:_step(1) end
    if Input.pressed('back') then self:_back() end
end

function SettingsState:render()
    MenuScene.draw()
    MenuList.header(L('menu.settings'), 'blue', self.anim, 1)

    local Lt = layout()
    local A = self.anim
    -- Etiqueta "IDIOMA"
    local ox, oy, a = A:slide(2, 0, 220)
    local label = L('settings.language')
    local ls = 5
    PixelFont.shadow(label, math.floor((WINDOW_W - PixelFont.width(label, ls)) / 2) + ox, Lt.value.y - 56 + oy, ls, a, { 1, 0.92, 0.3 })
    -- El idioma (al cambiar, el botón da un saltito hacia el lado de la flecha)
    local ox2, oy2, a2 = A:slide(3, 0, 220)
    local kick = 0
    if self.flash and self.flash.t < 0.14 then kick = self.flash.d * 8 end
    local bob = (math.floor(self.t * 3) % 2 == 0) and -4 or 0
    MenuButton.draw(L.LANGUAGES[langIndex()].name, Lt.value.x + ox2 + kick, Lt.value.y + oy2 + bob, Lt.value.w, Lt.value.h, 'teal', true, { alpha = a2 })
    -- Flechas
    local ox3, oy3, a3 = A:slide(4, 0, 220)
    local pl = self.flash and self.flash.d < 0 and self.flash.t < 0.12
    local pr = self.flash and self.flash.d > 0 and self.flash.t < 0.12
    MenuButton.draw('<', Lt.left.x + ox3, Lt.left.y + oy3 + (pl and 4 or 0), Lt.left.w, Lt.left.h, 'yellow', self.hover == 'left', { alpha = a3 })
    MenuButton.draw('>', Lt.right.x + ox3, Lt.right.y + oy3 + (pr and 4 or 0), Lt.right.w, Lt.right.h, 'yellow', self.hover == 'right', { alpha = a3 })

    MenuList.footer(L('menu.desc_settings'), A, 5,
        L('settings.hint', { change = Input.label('nav_left') .. Input.label('nav_right'), back = Input.label('back') }))
    love.graphics.setColor(COLOR_WHITE)
    CornerButtons.drawBack(self.backHover)
end

function SettingsState:mousemoved(tx, ty)
    self.backHover = CornerButtons.hitBack(tx, ty)
    local Lt = layout()
    self.hover = (inside(Lt.left, tx, ty) and 'left') or (inside(Lt.right, tx, ty) and 'right') or nil
end

function SettingsState:touchpressed(id, tx, ty)
    if self.anim:busy() then return end
    if CornerButtons.hitBack(tx, ty) then return self:_back() end
    local Lt = layout()
    if inside(Lt.left, tx, ty) then self:_step(-1)
    elseif inside(Lt.right, tx, ty) or inside(Lt.value, tx, ty) then self:_step(1) end
end

return SettingsState
