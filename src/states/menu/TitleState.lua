-- src/states/menu/TitleState.lua
-- EL TÍTULO Y EL MENÚ PRINCIPAL, en una sola pantalla (docs/architecture/menus.md), sobre el fondo vivo de los menús
-- (src/ui/menu/MenuScene: un nivel de verdad de cada isla con el monstruo corriendo).
--   · TÍTULO: el recuadro del logo (title_logo.png, el de siempre remasterizado) cae botando, sus letras salen
--     una a una y luego se mecen en ola;
--     "Presiona ENTER" parpadea debajo.
--   · Al pulsar, el logo SUBE y entran los botones desde abajo, uno detrás de otro: CONTINUAR (solo si hay una
--     partida de la historia: la última que se jugó), FLAPPY, AVENTURA y CONFIGURACIÓN. Atrás = vuelta al título.
--   · Al elegir, los botones y el logo SALEN y se pasa a la pantalla siguiente (que entra sobre el mismo fondo);
--     CONTINUAR va directamente al mapa de la historia con la transición de bloques (src/ui/menu/Transition).
-- Dos nombres de estado: `title` (empieza en el título) y `main_menu` (empieza con los botones; a él vuelven las
-- demás pantallas: args.select = el id del botón que queda elegido: 'classic' (FLAPPY), 'adventure', 'settings').
local BaseState  = require 'src/core/BaseState'
local L          = require 'src/core/Lang'
local CornerButtons = require 'src/ui/CornerButtons'
local MenuScene  = require 'src/ui/menu/MenuScene'
local MenuAnim   = require 'src/ui/menu/MenuAnim'
local MenuList   = require 'src/ui/menu/MenuList'
local Transition = require 'src/ui/menu/Transition'
local TitleLogo  = require 'src/ui/menu/TitleLogo'
local Campaign   = require 'src/flappy/Campaign'
local TitleState = BaseState:new()

local LOGO_S = math.floor(LOGO_SCALE / 2)      -- el logo remasterizado está a 2x: a media escala ocupa lo de siempre
local RISE_T = 0.38                             -- s que tarda el logo en subir al abrir el menú

-- La última partida que se jugó, de CUALQUIER campaña (src/story/Campaigns.lua: Flappy o la historia de Aventura): el
-- archivo escrito más tarde → id de la campaña, hueco (nil si no hay ninguna). Con Aventura bloqueada, la suya no cuenta
-- (sus partidas siguen en el disco y vuelven al desbloquearla). En un empate de segundo, gana la primera de
-- Campaigns.IDS.
local function lastSave()
    local Campaigns = require 'src/story/Campaigns'
    local bestC, bestI, when = nil, nil, -1
    for _, id in ipairs(Campaigns.IDS) do
        if not (id == 'story' and Campaign.adventureLocked()) then
            local c = Campaigns.get(id)
            for i = 1, c.saves.SLOTS do
                local t = c.saves.modtime(i)
                if t and t > when and c.saves.load(i) then bestC, bestI, when = id, i, t end
            end
        end
    end
    return bestC, bestI
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
    self:_buildList(args.select)
    Sound.playMusic('menus')
end

function TitleState:_buildList(select)
    -- Aventura bloqueada (hasta terminar la campaña Flappy: src/flappy/Campaign.lua): botón gris con su aviso
    local locked = Campaign.adventureLocked()
    -- CONTINUAR: la última partida jugada, sea del modo que sea (el usuario, 2026-11-07)
    local camp, slot = lastSave()
    self.slot, self.contCampaign = slot, camp
    local items = {}
    if slot then
        items[#items + 1] = { text = 'menu.continue', color = 'pink', desc = 'menu.desc_continue', descArgs = { n = slot, mode = L(camp == 'flappy' and 'menu.classic' or 'menu.adventure') },
                              id = 'continue', go = function() self:_continue() end }
    end
    -- FLAPPY primero (el usuario, 2026-11-07), luego AVENTURA (id 'classic': el de siempre, no cambia)
    items[#items + 1] = { text = 'menu.classic', color = 'orange', desc = 'menu.desc_classic', id = 'classic',
                          go = function() self:_leave('flappy_campaign') end }
    if locked then
        items[#items + 1] = { text = 'menu.adventure', color = 'grey', desc = 'menu.desc_adventure_locked', id = 'adventure',
                              locked = true, go = function() Sound.play('headBump') end }
    else
        items[#items + 1] = { text = 'menu.adventure', color = 'green', desc = 'menu.desc_adventure', id = 'adventure',
                              go = function() self:_leave('adv_mode_select') end }
    end
    -- (CONFIGURACIÓN ya no es un botón de la lista: es el ENGRANAJE de la esquina — docs/design/settings-menu-rework.md —)
    -- `select` = id del botón elegido al volver de otra pantalla (sin él, el primero: CONTINUAR si está); 'settings' =
    -- el engranaje
    local sel = 1
    for i, it in ipairs(items) do if it.id == select then sel = i end end
    self.gearSel = select == 'settings'
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
    local c = require('src/story/Campaigns').get(self.contCampaign)
    self.leavingTo = c.map
    self.anim:leave(function() end, #self.list.items + 1)
    c.run.open(self.slot)
    Transition.go(c.map)
end

-- MENÚ DE DEPURACIÓN secreto (src/states/menu/DebugMenuState.lua: clásico infinito, Aventura sin candado, juego libre,
-- sound test, film test): ↑ ↑ ↓ ↓ ← → ← → (flechas o cruceta), o 7 toques seguidos
-- en la versión (abajo a la IZQUIERDA desde 0.5.197: a la derecha está el engranaje)
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
                if ok then self:_openDebug(); return true end
            end
        end
    end
end
function TitleState:_openDebug()
    self.secretSeq, self.versionTaps = nil, nil
    Sound.play('oneUp')
    gStateMachine:change('debug_menu')
end
-- La versión (y sus 7 toques secretos) abajo a la IZQUIERDA; a la derecha, el engranaje (el usuario, 2026-11-11)
function TitleState:_versionRect() return 0, WINDOW_H - 50, 180, 50 end

-- EL ENGRANAJE (la configuración): abajo a la derecha, solo con el menú abierto, en cualquier aparato. Teclado / mando:
-- abajo desde el último botón lo elige (gearSel); arriba vuelve a la lista; abajo otra vez, al primero
local GEAR_S = 3                                  -- (el arte es de 20x20: 60 px en pantalla)
function TitleState:_gearRect() local s = 20 * GEAR_S + 16; return WINDOW_W - s - 16, WINDOW_H - s - 16, s, s end
local gearImg, gearQ
local function gearArt()
    if not gearImg then
        gearImg = love.graphics.newImage('assets/images/ui/settings/gear-Sheet.png')
        gearImg:setFilter('nearest', 'nearest')
        gearQ = { love.graphics.newQuad(0, 0, 20, 20, 40, 20), love.graphics.newQuad(20, 0, 20, 20, 40, 20) }
    end
    return gearImg, gearQ
end
function TitleState:_drawGear()
    local x, y, w, h = self:_gearRect()
    local _, oy, a = self.anim:slide(#self.list.items + 2, 0, 200)
    local MenuButton = require 'src/ui/menu/MenuButton'
    local sel = self.gearSel or self.gearHover
    local bob = (sel and math.floor(self.t * 3) % 2 == 0) and -4 or 0
    MenuButton.draw('', x, y + oy + bob, w, h, sel and 'yellow' or 'blue', sel, { alpha = a })
    local img, q = gearArt()
    love.graphics.setColor(1, 1, 1, a)
    love.graphics.draw(img, q[sel and 2 or 1], x + 8, y + oy + bob + 4, 0, GEAR_S, GEAR_S)
    love.graphics.setColor(1, 1, 1, 1)
end

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
    local n = #self.list.items
    if self.gearSel then
        if Input.pressed('nav_up') then self.gearSel = false; self.list.selected = n; Sound.play('select', 0.94); return end
        if Input.pressed('nav_down') then self.gearSel = false; self.list.selected = 1; Sound.play('select', 1.08); return end
        if Input.pressed('confirm') or Input.pressed('flap') then Sound.play('select', 1.2); return self:_leave('settings') end
        return
    end
    if (Input.pressed('nav_down') and self.list.selected == n) or (Input.pressed('nav_up') and self.list.selected == 1) then
        self.gearSel = true
        Sound.play('select', 1.08)
        return
    end
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
        local keep = self.list.selected
        if self.gearSel then self.list.selected = 0 end            -- (con el engranaje elegido, ningún botón lo está)
        self.list:draw()
        self.list.selected = keep
        self:_drawGear()
        MenuList.footer(self.gearSel and L('menu.desc_settings') or self.list:desc(), self.anim, #self.list.items + 2)
    end

    -- Versión instalada (version.txt; la cambian las actualizaciones)
    if not self.version then
        local ok, v = pcall(love.filesystem.read, 'version.txt')
        self.version = 'v' .. ((ok and v or '?'):match('^%s*(.-)%s*$'))
    end
    love.graphics.setFont(FONT_SMALL)
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.print(self.version, 16, WINDOW_H - 22)
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.print(self.version, 14, WINDOW_H - 24)
    love.graphics.setColor(1, 1, 1, 1)
    if self.menu then CornerButtons.drawBack(self.backHover) end
end

-- ── Ratón y táctil ──────────────────────────────────────────────────────────
function TitleState:mousemoved(x, y)
    if not self.menu then return end
    self.backHover = CornerButtons.hitBack(x, y)
    local gx, gy, gw, gh = self:_gearRect()
    self.gearHover = x >= gx and x <= gx + gw and y >= gy and y <= gy + gh
    if self.gearHover then return end
    if not self.backHover and self.list:mousemoved(x, y) then self.gearSel = false end
end

function TitleState:touchpressed(id, x, y)
    local vx, vy, vw, vh = self:_versionRect()
    if x >= vx and x <= vx + vw and y >= vy and y <= vy + vh then
        local now = love.timer.getTime()
        local vt = self.versionTaps
        if not vt or now - vt.t > 0.8 then vt = { n = 0 } end
        vt.n, vt.t = vt.n + 1, now
        self.versionTaps = vt
        if vt.n >= 7 then self:_openDebug() end
        return
    end
    if self.anim:busy() then return end
    if not self.menu then return self:_open() end
    if CornerButtons.hitBack(x, y) then return self:_close() end
    local gx, gy, gw, gh = self:_gearRect()
    if x >= gx and x <= gx + gw and y >= gy and y <= gy + gh then
        self.gearSel = true; Sound.play('select', 1.2)
        return self:_leave('settings')
    end
    self.list:touchpressed(x, y)
end

return TitleState
