-- src/states/menu/SettingsState.lua
-- Configuración (desde el menú principal). Por ahora solo el idioma
-- (src/core/Lang.lua + assets/lang/); se guarda con src/core/Settings.lua.
-- Mandos/teclado: izquierda/derecha (o confirmar) cambian, atrás vuelve.
-- Ratón/táctil: flechas o el nombre del idioma.

local CornerButtons = require 'src/ui/CornerButtons'
local BaseState     = require 'src/core/BaseState'
local PixelFont     = require 'src/ui/PixelFont'
local Settings      = require 'src/core/Settings'
local L             = require 'src/core/Lang'
local SettingsState = BaseState:new()

local imgBg = nil
local TITLE_SCALE, VALUE_SCALE = 8, 8

local function loadAssets()
    if imgBg then return end
    imgBg = love.graphics.newImage('assets/images/menus/MenuDif.png')
end

local function langIndex()
    for i, l in ipairs(L.LANGUAGES) do if l.id == L.current() then return i end end
    return 1
end

-- Geometría compartida por dibujo, ratón y táctil
local function layout()
    local name = L.LANGUAGES[langIndex()].name
    local s = VALUE_SCALE
    local vw = PixelFont.width(name, s)
    local aw = PixelFont.width('<', s)
    local gap = 40
    local vy = math.floor(WINDOW_H * 0.54)
    local vx = math.floor((WINDOW_W - vw) / 2)
    return {
        name  = name,
        value = { x = vx, y = vy, w = vw, h = PixelFont.height(s) },
        left  = { x = vx - gap - aw, y = vy, w = aw, h = PixelFont.height(s) },
        right = { x = vx + vw + gap, y = vy, w = aw, h = PixelFont.height(s) },
    }
end

local function inside(r, x, y, pad)
    pad = pad or 16
    return x >= r.x - pad and x <= r.x + r.w + pad and y >= r.y - pad and y <= r.y + r.h + pad
end

function SettingsState:enter()
    loadAssets()
    Sound.playMusic('menus')
end

function SettingsState:_step(d)
    local n = #L.LANGUAGES
    local i = (langIndex() - 1 + d) % n + 1
    Settings.setLanguage(L.LANGUAGES[i].id)
    Sound.play('select')
end

function SettingsState:_back()
    Sound.play('select')
    gStateMachine:change('main_menu', { selected = 3 })
end

function SettingsState:update(dt)
    if Input.pressed('nav_left') then self:_step(-1) end
    if Input.pressed('nav_right') or Input.pressed('confirm') then self:_step(1) end
    if Input.pressed('back') then self:_back() end
end

function SettingsState:render()
    love.graphics.setColor(COLOR_WHITE)
    love.graphics.draw(imgBg, 0, 0, 0, WINDOW_W / imgBg:getWidth(), WINDOW_H / imgBg:getHeight())

    -- Título
    local title = L('menu.settings')
    local ts = TITLE_SCALE
    if PixelFont.width(title, ts) > WINDOW_W - 120 then ts = math.max(4, math.floor(ts * (WINDOW_W - 120) / PixelFont.width(title, ts))) end
    PixelFont.draw(title, math.floor((WINDOW_W - PixelFont.width(title, ts)) / 2), math.floor(WINDOW_H * 0.24), ts, 1)

    -- Idioma
    local Lt = layout()
    love.graphics.setFont(FONT_MED)
    local label = L('settings.language')
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.printf(label, 2, Lt.value.y - 50 + 2, WINDOW_W, 'center')
    love.graphics.setColor(1, 0.95, 0.15, 1)
    love.graphics.printf(label, 0, Lt.value.y - 50, WINDOW_W, 'center')
    PixelFont.draw(Lt.name, Lt.value.x, Lt.value.y, VALUE_SCALE, 1)
    PixelFont.draw('<', Lt.left.x, Lt.left.y, VALUE_SCALE, self.hover == 'left' and 1 or 0.6)
    PixelFont.draw('>', Lt.right.x, Lt.right.y, VALUE_SCALE, self.hover == 'right' and 1 or 0.6)

    -- Ayuda
    love.graphics.setFont(FONT_SMALL)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.printf(L('settings.hint', { change = Input.label('nav_left') .. Input.label('nav_right'), back = Input.label('back') }),
                         40, math.floor(WINDOW_H * 0.74), WINDOW_W - 80, 'center')
    love.graphics.setColor(COLOR_WHITE)
    CornerButtons.drawBack(self.backHover)
end

function SettingsState:mousemoved(tx, ty)
    self.backHover = CornerButtons.hitBack(tx, ty)
    local Lt = layout()
    self.hover = (inside(Lt.left, tx, ty) and 'left') or (inside(Lt.right, tx, ty) and 'right') or nil
end

function SettingsState:touchpressed(id, tx, ty)
    if CornerButtons.hitBack(tx, ty) then return self:_back() end
    local Lt = layout()
    if inside(Lt.left, tx, ty) then self:_step(-1)
    elseif inside(Lt.right, tx, ty) or inside(Lt.value, tx, ty) then self:_step(1) end
end

return SettingsState
