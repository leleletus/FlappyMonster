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
local L          = require 'src/core/Lang'
local CornerButtons = require 'src/ui/CornerButtons'
local MenuScene  = require 'src/ui/menu/MenuScene'
local MenuAnim   = require 'src/ui/menu/MenuAnim'
local MenuList   = require 'src/ui/menu/MenuList'
local Transition = require 'src/ui/menu/Transition'
local Save       = require 'src/story/Save'
local TitleLogo  = require 'src/ui/menu/TitleLogo'
local TitleState = BaseState:new()

local LOGO_S = math.floor(LOGO_SCALE / 2)      -- el logo remasterizado está a 2x: a media escala ocupa lo de siempre
local RISE_T = 0.38                             -- s que tarda el logo en subir al abrir el menú

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

function TitleState:enter(args)
    args = args or {}
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
        items[#items + 1] = { text = 'menu.continue', color = 'green', desc = 'menu.desc_continue', descArgs = { n = slot },
                              id = 'continue', go = function() self:_continue() end }
    end
    items[#items + 1] = { text = 'menu.adventure', color = 'mono', desc = 'menu.desc_adventure', id = 'adventure',
                          go = function() self:_leave('adv_mode_select') end }
    items[#items + 1] = { text = 'menu.classic', color = 'mono', desc = 'menu.desc_classic', id = 'classic',
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
    self.leavingTo = 'story_map'
    self.anim:leave(function() end, #self.list.items + 1)
    Run.open(self.slot)
    Transition.go('story_map')
end

-- SOUND TEST secreto (src/states/menu/SoundTestState.lua): ↑ ↑ ↓ ↓ ← → ← → (flechas o cruceta), o 7 toques seguidos
-- en la versión (abajo a la derecha)
local SECRET = { 'nav_up', 'nav_up', 'nav_down', 'nav_down', 'nav_left', 'nav_right', 'nav_left', 'nav_right' }
function TitleState:_secret()
    for _, a in ipairs({ 'nav_up', 'nav_down', 'nav_left', 'nav_right' }) do
        if Input.pressed(a) then
            local seq = self.secretSeq or {}
            self.secretSeq = seq
            seq[#seq + 1] = a
            if #seq > #SECRET then table.remove(seq, 1) end
            if #seq == #SECRET then
                local ok = true
                for i = 1, #SECRET do if seq[i] ~= SECRET[i] then ok = false; break end end
                if ok then self:_openSoundTest(); return true end
            end
        end
    end
end
function TitleState:_openSoundTest()
    self.secretSeq, self.versionTaps = nil, nil
    Sound.play('oneUp')
    gStateMachine:change('sound_test')
end
function TitleState:_versionRect() return WINDOW_W - 180, WINDOW_H - 50, 180, 50 end

function TitleState:update(dt)
    self.t = self.t + dt
    if self:_secret() then return end
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
    local W, H = TitleLogo.size(LOGO_S)
    local x0 = math.floor((WINDOW_W - W) / 2)
    -- del centro del título a arriba del todo
    local yTitle, yMenu = math.floor(WINDOW_H * 0.24), 34
    local k = ease(self.logoUp)
    local y0 = math.floor((yTitle + (yMenu - yTitle) * k) / 4 + 0.5) * 4
    -- al elegir una opción el logo se va POR ARRIBA (y se desvanece); al llegar directamente al menú, baja desde arriba
    local alpha = 1
    if self.leavingTo or self.logoSlide then
        local _, oy, a = self.anim:slide(1, 0, -260, 0, -(y0 + H + 40))
        y0, alpha = y0 + oy, a
    end
    TitleLogo.draw(x0, y0, LOGO_S, { t = self.t, intro = not self.dropped, wave = true, alpha = alpha })
    if not self.dropped and self.t > TitleLogo.introTime() then self.dropped = true end
    return y0 + H
end

function TitleState:render()
    MenuScene.draw()
    local bottom = self:_drawLogo()
    if not self.menu then
        -- "Presiona ENTER": aparece cuando han caído las letras; parpadea y bota
        local ready = TitleLogo.introTime()
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
    local vx, vy, vw, vh = self:_versionRect()
    if x >= vx and x <= vx + vw and y >= vy and y <= vy + vh then
        local now = love.timer.getTime()
        local vt = self.versionTaps
        if not vt or now - vt.t > 0.8 then vt = { n = 0 } end
        vt.n, vt.t = vt.n + 1, now
        self.versionTaps = vt
        if vt.n >= 7 then self:_openSoundTest() end
        return
    end
    if self.anim:busy() then return end
    if not self.menu then return self:_open() end
    if CornerButtons.hitBack(x, y) then return self:_close() end
    self.list:touchpressed(x, y)
end

return TitleState
