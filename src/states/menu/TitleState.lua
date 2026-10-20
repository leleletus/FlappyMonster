-- src/states/menu/TitleState.lua
-- EL TÍTULO Y EL MENÚ PRINCIPAL, en una sola pantalla (docs/architecture/menus.md), sobre el fondo vivo de los menús
-- (src/ui/menu/MenuScene: un nivel de verdad de cada isla con el monstruo corriendo).
--   · TÍTULO: el recuadro del logo (title_logo.png, el de siempre remasterizado) cae botando, sus letras salen
--     una a una y luego se mecen en ola;
--     "Presiona ENTER" parpadea debajo.
--   · Al pulsar, el logo SUBE y entran los botones desde abajo, uno detrás de otro: CONTINUAR (solo si hay una
--     partida de la historia: la última que se jugó), AVENTURA, CLÁSICO y CONFIGURACIÓN. Atrás = vuelta al título.
--   · Al elegir, los botones y el logo SALEN y se pasa a la pantalla siguiente (que entra sobre el mismo fondo);
--     CONTINUAR va directamente al mapa de la historia con la transición de bloques (src/ui/menu/Transition).
-- Dos nombres de estado: `title` (empieza en el título) y `main_menu` (empieza con los botones; a él vuelven las
-- demás pantallas: args.selected = qué botón queda elegido).
local BaseState  = require 'src/core/BaseState'
local json       = require 'libs/json'
local L          = require 'src/core/Lang'
local CornerButtons = require 'src/ui/CornerButtons'
local MenuScene  = require 'src/ui/menu/MenuScene'
local MenuAnim   = require 'src/ui/menu/MenuAnim'
local MenuList   = require 'src/ui/menu/MenuList'
local Transition = require 'src/ui/menu/Transition'
local Save       = require 'src/story/Save'
local TitleState = BaseState:new()

local LOGO_S = math.floor(LOGO_SCALE / 2)      -- el logo remasterizado está a 2x: a media escala ocupa lo de siempre
local BOX_T = 0.45                              -- s que tarda el recuadro en caer
local DROP = 0.06                               -- s entre letra y letra al salir
local POP_T = 0.16                              -- s que tarda cada letra en asentarse
local RISE_T = 0.38                             -- s que tarda el logo en subir al abrir el menú

local logo
local function loadLogo()
    if logo then return logo end
    local im = love.graphics.newImage('assets/images/ui/menus/title_logo.png')
    local data = json.decode(love.filesystem.read('assets/images/ui/menus/title_logo.json'))
    local b = data.box
    logo = { img = im, w = data.w, h = data.h, letters = {}, box = love.graphics.newQuad(b.sx, b.sy, b.w, b.h, im:getDimensions()) }
    for i, l in ipairs(data.letters) do
        logo.letters[i] = { q = love.graphics.newQuad(l.sx, l.sy, l.w, l.h, im:getDimensions()), x = l.x, y = l.y,
                            w = l.w, h = l.h, line = l.line }
    end
    return logo
end

-- La última partida de la historia que se jugó (el archivo más reciente), o nil
local function lastSlot()
    local best, when = nil, -1
    for i = 1, Save.SLOTS do
        local info = love.filesystem.getInfo('story' .. i .. '.sav')
        if info and (info.modtime or 0) > when and Save.load(i) then best, when = i, info.modtime or 0 end
    end
    return best
end

local function ease(k) k = math.max(0, math.min(1, k)); return 1 - (1 - k) * (1 - k) * (1 - k) end
local function back(k) k = math.max(0, math.min(1, k)) - 1; return 1 + k * k * (2.7 * k + 1.7) end

function TitleState:enter(args)
    args = args or {}
    loadLogo()
    self.t = 0
    self.menu = self.startInMenu or args.menu or false
    self.logoUp = self.menu and 1 or 0            -- 0 = logo en el centro (título), 1 = arriba (menú)
    self.dropped = self.menu                      -- (en el menú directo no vuelven a caer las letras)
    self.logoSlide = self.menu                    -- (… sino que el logo entra desde arriba)
    self.anim = MenuAnim.new({ n = 6 })
    self:_buildList(args.selected)
    Sound.playMusic('menus')
end

function TitleState:_buildList(selected)
    local slot = lastSlot()
    self.slot = slot
    local items = {}
    if slot then
        items[#items + 1] = { text = 'menu.continue', color = 'pink', desc = 'menu.desc_continue', descArgs = { n = slot },
                              id = 'continue', go = function() self:_continue() end }
    end
    items[#items + 1] = { text = 'menu.adventure', color = 'green', desc = 'menu.desc_adventure', id = 'adventure',
                          go = function() self:_leave('adv_mode_select') end }
    items[#items + 1] = { text = 'menu.classic', color = 'orange', desc = 'menu.desc_classic', id = 'classic',
                          go = function() self:_leave('difficulty') end }
    items[#items + 1] = { text = 'menu.settings', color = 'blue', desc = 'menu.desc_settings', id = 'settings',
                          go = function() self:_leave('settings') end }
    -- args.selected = 1 aventura, 2 clásico, 3 configuración (sin contar CONTINUAR, que no siempre está)
    local sel = selected and (selected + (slot and 1 or 0)) or 1
    self.list = MenuList.new({ items = items, anim = self.anim, first = 2, top = 0.33, selected = sel })
end

-- Abrir el menú (del título) y volver al título (del menú)
function TitleState:_open()
    self.menu, self.logoSlide, self.dropped = true, false, true
    self.anim = MenuAnim.new({ n = 6 })
    self.list.anim = self.anim
    self.anim.t = -0.12                           -- (los botones esperan a que el logo empiece a subir)
    Sound.play('select', 1.2)
end

function TitleState:_close()
    self.logoSlide = false
    self.anim:leave(function()
        self.menu = false
        self.anim = MenuAnim.new({ n = 6 })
        self.list.anim = self.anim
    end, #self.list.items + 1)
    Sound.play('select', 0.85)
end

-- Elegir: todo sale y luego se cambia de pantalla
function TitleState:_leave(state, args)
    self.leavingTo = state
    self.anim:leave(function() gStateMachine:change(state, args) end, #self.list.items + 1)
end

function TitleState:_continue()
    local Run = require 'src/story/Run'
    self.anim:leave(function() end, #self.list.items + 1)
    Run.open(self.slot)
    Transition.go('story_map')
end

function TitleState:update(dt)
    self.t = self.t + dt
    MenuScene.update(dt)
    self.anim:update(dt)
    local target = self.menu and 1 or 0
    if self.menu and self.anim:leaving() and not self.leavingTo then target = 0 end
    local spd = dt / RISE_T
    self.logoUp = (self.logoUp < target) and math.min(target, self.logoUp + spd) or math.max(target, self.logoUp - spd)
    if not self.menu then
        if self.anim:busy() then return end
        if Input.pressed('confirm') or Input.pressed('flap') then self:_open() end
        return
    end
    if self.anim:busy() then return end
    if Input.pressed('back') then return self:_close() end
    self.list:update(dt)
end

-- ── Dibujo ──────────────────────────────────────────────────────────────────
function TitleState:_drawLogo()
    local lg = logo
    local W = lg.w * LOGO_S
    local x0 = math.floor((WINDOW_W - W) / 2)
    -- del centro del título (28 % del alto) a arriba del todo
    local yTitle, yMenu = math.floor(WINDOW_H * 0.24), 34
    local k = ease(self.logoUp)
    local y0 = math.floor((yTitle + (yMenu - yTitle) * k) / 4 + 0.5) * 4
    -- al elegir una opción el logo también se va (hacia arriba); al llegar directamente al menú, baja desde arriba
    if self.leavingTo or self.logoSlide then y0 = y0 + select(2, self.anim:slide(1, 0, -260)) end
    -- el recuadro cae desde arriba con rebote; luego las letras salen una a una dentro (un saltito y se asientan)
    local by = 0
    if not self.dropped then by = math.floor((1 - back(self.t / BOX_T)) * -(y0 + lg.h * LOGO_S + 40) / LOGO_S) * LOGO_S end
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.draw(lg.img, lg.box, x0 + 4, y0 + by + 4, 0, LOGO_S, LOGO_S)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(lg.img, lg.box, x0, y0 + by, 0, LOGO_S, LOGO_S)
    for i, l in ipairs(lg.letters) do
        local dy, a = 0, 1
        if not self.dropped then
            local k = (self.t - BOX_T - (i - 1) * DROP) / POP_T
            if k <= 0 then a = 0
            else
                k = math.min(1, k)
                dy = -math.floor((1 - back(k)) * 2 + 0.5) * LOGO_S              -- (sube 2 px del logo y baja)
                a = k < 0.34 and 0.4 or (k < 0.67 and 0.75 or 1)
            end
        end
        -- la ola: cada letra sube un píxel del logo y baja, desfasada
        local wave = (math.sin(self.t * 3 - i * 0.55) > 0.6) and -LOGO_S or 0
        if a > 0 then
            love.graphics.setColor(1, 1, 1, a)
            love.graphics.draw(lg.img, l.q, x0 + l.x * LOGO_S, y0 + by + l.y * LOGO_S + dy + wave, 0, LOGO_S, LOGO_S)
        end
    end
    if not self.dropped and self.t > BOX_T + (#lg.letters - 1) * DROP + POP_T then self.dropped = true end
    love.graphics.setColor(1, 1, 1, 1)
    return y0 + lg.h * LOGO_S
end

function TitleState:render()
    MenuScene.draw()
    local bottom = self:_drawLogo()
    if not self.menu then
        -- "Presiona ENTER": aparece cuando han caído las letras; parpadea y bota
        local ready = BOX_T + (#logo.letters - 1) * DROP + POP_T
        local k = ease((self.t - ready) / 0.3)
        if self.anim:leaving() then k = 0 end
        if k > 0 then
            local blink = (math.floor(self.t * 2.2) % 3 ~= 2) and 1 or 0.35
            local hop = (math.floor(self.t * 2.2) % 3 == 0) and -4 or 0
            local text = L('title.press', { key = Input.label('confirm') })
            love.graphics.setFont(FONT_MED)
            local y = math.floor(WINDOW_H * 0.70) + hop + math.floor((1 - k) * 40 / 4) * 4
            local w = FONT_MED:getWidth(text) + 56
            local MenuButton = require 'src/ui/menu/MenuButton'
            MenuButton.panel(math.floor((WINDOW_W - w) / 2), y - 18, w, FONT_MED:getHeight() + 36, 0.9 * k)
            love.graphics.setColor(1, 0.92, 0.3, blink * k)
            love.graphics.printf(text, 0, y + 2, WINDOW_W, 'center')
        end
    else
        self.list:draw()
        MenuList.footer(self.list:desc(), self.anim, #self.list.items + 2)
    end

    -- Versión instalada (version.txt; la cambian las actualizaciones)
    if not self.version then
        local ok, v = pcall(love.filesystem.read, 'version.txt')
        self.version = 'v' .. ((ok and v or '?'):match('^%s*(.-)%s*$'))
    end
    love.graphics.setFont(FONT_SMALL)
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.printf(self.version, 0, WINDOW_H - 22, WINDOW_W - 14, 'right')
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.printf(self.version, 0, WINDOW_H - 24, WINDOW_W - 16, 'right')
    love.graphics.setColor(1, 1, 1, 1)
    if self.menu then CornerButtons.drawBack(self.backHover) end
end

-- ── Ratón y táctil ──────────────────────────────────────────────────────────
function TitleState:mousemoved(x, y)
    if not self.menu then return end
    self.backHover = CornerButtons.hitBack(x, y)
    if not self.backHover then self.list:mousemoved(x, y) end
end

function TitleState:touchpressed(id, x, y)
    if self.anim:busy() then return end
    if not self.menu then return self:_open() end
    if CornerButtons.hitBack(x, y) then return self:_close() end
    self.list:touchpressed(x, y)
end

return TitleState
