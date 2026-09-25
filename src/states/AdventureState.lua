-- src/states/AdventureState.lua
local BaseState       = require 'src/BaseState'
local Level           = require 'src/world/Level'
local PlayerAdventure = require 'src/entities/PlayerAdventure'
local Entities        = require 'src/world/Entities'

local AdventureState = BaseState:new()

local GAMEOVER_OPTIONS = { 'Reintentar', 'Menu' }
local RESPAWN_DELAY    = 0

-- ── Assets del HUD ────────────────────────────────────────────────────────────
local imgIcon = nil
local function loadHudAssets()
    if imgIcon then return end
    imgIcon = love.graphics.newImage('assets/images/player/icon.png')
end

local ICON_SCALE = 4
local HP_BAR_W   = 80
local HP_BAR_H   = 14
local HP_BAR_GAP = 8

-- ── Helper: botón cuadrado pixel art ─────────────────────────────────────────
local function drawPixelButton(label, cx, y, w, h, selected, alpha)
    if selected then
        love.graphics.setColor(0.18, 0.18, 0.18, alpha)
        love.graphics.rectangle('fill', cx - w/2 + 4, y + 4, w, h)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.rectangle('fill', cx - w/2, y, w, h)
        love.graphics.setColor(0, 0, 0, alpha)
        love.graphics.printf(label, cx - w/2, y + h/2 - FONT_MED:getHeight()/2, w, 'center')
    else
        love.graphics.setColor(1, 1, 1, alpha * 0.45)
        love.graphics.rectangle('line', cx - w/2, y, w, h)
        love.graphics.setColor(1, 1, 1, alpha * 0.5)
        love.graphics.printf(label, cx - w/2, y + h/2 - FONT_MED:getHeight()/2, w, 'center')
    end
end

local imgBg = nil
local BG_SCALE    = 15
local BG_PARALLAX = 0.3

local function loadBgAsset()
    if imgBg then return end
    imgBg = love.graphics.newImage('assets/images/level/Background.png')
end

-- ── Enter ─────────────────────────────────────────────────────────────────────
function AdventureState:enter(args)
    loadHudAssets()
    loadBgAsset()
    args = args or {}
    self.levelPath = args.level or 'assets/levels/nivel01.json'

    self.level  = Level.new(self.levelPath)
    local sx, sy = self.level:getSpawnPx()
    self.player = PlayerAdventure:new(sx, sy)

    -- Instanciar entidades (enemigos, NPCs) desde el catálogo
    self.enemies = {}
    for _, placement in ipairs(self.level.entities) do
        local e = Entities.create(placement)
        if e then table.insert(self.enemies, e) end
    end

    self.camX = 0
    self.camY = 0
    self.camFrozen = false
    self.bgScrollX = 0
    self.bgScrollY = 0

    self.sceneCanvas = love.graphics.newCanvas(WINDOW_W, WINDOW_H)

    self.dead         = false
    self.deadTimer    = 0
    self.timeScale    = 1.0
    self.selectedOpt  = 1
    self.respawning   = false
    self.respawnTimer = 0

    Sound.playMusic('level')

    self.score      = 0
    self.levelTime  = 0   -- segundos transcurridos
    self.popups     = {}  -- lista de textos flotantes de puntos
end

function AdventureState:pause()  end
function AdventureState:resume() Sound.playMusic('level') end

function AdventureState:pauseGame()
    if not self.dead then gStateMachine:push('pause') end
end

-- ── Cámara ────────────────────────────────────────────────────────────────────
-- ── Colisión jugador ↔ burbujas de oxígeno de vents ─────────────────────────
function AdventureState:checkVentOxyCollisions()
    local player = self.player
    if player.dying or not player.alive then return end
    local ob  = player:getOuterBounds()
    local hit = self.level:checkVentOxyCollision(ob.x, ob.y, ob.w, ob.h)
    if hit then
        if player.drownPhase == 'warning' or player.drownPhase == 'drowning' then
            if player.drownPhase == 'drowning' then
                Sound.stopTracked('drowning')
                Sound.playMusic('level')
            end
            player.drownTimer  = 0
            player.drownChime  = 0
            player.drownAudT   = 0
            player.drownDead   = false
            player.drownPhase  = 'none'
            player.airBarBobT  = 0
            player.airBarBobOn = true
        end
        Sound.play('airGasp')
    end
end

-- ── Popups de puntos ─────────────────────────────────────────────────────────
-- Animación: aparece desde abajo invisible → sube con rebote → desvanece
local POPUP_LIFE     = 1.4    -- duración total en segundos
local POPUP_RISE     = 28     -- px que sube en total
local POPUP_BOUNCE_T = 0.22   -- fracción del tiempo dedicada al bounce inicial

function AdventureState:spawnPopup(text, wx, wy)
    table.insert(self.popups, {
        text  = text,
        wx    = wx,    -- posición mundo X
        wy    = wy,    -- posición mundo Y (tope del gummy)
        timer = 0,
    })
end

function AdventureState:updatePopups(dt)
    for i = #self.popups, 1, -1 do
        local pop = self.popups[i]
        pop.timer = pop.timer + dt
        if pop.timer >= POPUP_LIFE then
            table.remove(self.popups, i)
        end
    end
end

function AdventureState:renderPopups()
    if #self.popups == 0 then return end
    love.graphics.setFont(FONT_MED)
    for _, pop in ipairs(self.popups) do
        local t        = pop.timer / POPUP_LIFE   -- 0→1
        local alpha, offsetY

        -- Curva continua: offsetY sube suavemente de 0 → POPUP_RISE con ease-out
        offsetY = POPUP_RISE * (1 - (1 - t) * (1 - t))

        if t < POPUP_BOUNCE_T then
            -- Fade in rápido
            alpha = t / POPUP_BOUNCE_T
        else
            -- Fade out
            local ft = (t - POPUP_BOUNCE_T) / (1 - POPUP_BOUNCE_T)
            alpha    = 1 - ft
        end

        local sx = math.floor(pop.wx - self.camX)
        local sy = math.floor(pop.wy - self.camY - offsetY)

        -- Sombra pixel-art
        love.graphics.setColor(0, 0, 0, alpha * 0.6)
        love.graphics.printf(pop.text, sx - 39, sy + 1, 80, 'center')
        -- Texto amarillo brillante
        love.graphics.setColor(1, 0.95, 0.15, alpha)
        love.graphics.printf(pop.text, sx - 40, sy, 80, 'center')
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function AdventureState:updateCamera(dt)
    if self.camFrozen then return end

    local targetX = self.player.x - WINDOW_W / 2
    local targetY = self.player.y - WINDOW_H / 2

    targetX = math.max(0, math.min(self.level.widthPx  - WINDOW_W, targetX))
    targetY = math.max(0, math.min(self.level.heightPx - WINDOW_H, targetY))

    local prevCamX = self.camX
    local prevCamY = self.camY
    self.camX = self.camX + (targetX - self.camX) * CAM_LERP * dt
    self.camY = self.camY + (targetY - self.camY) * CAM_LERP * dt

    local bgW = imgBg:getWidth()  * BG_SCALE
    local bgH = imgBg:getHeight() * BG_SCALE
    self.bgScrollX = self.bgScrollX + (self.camX - prevCamX) * BG_PARALLAX
    self.bgScrollY = self.bgScrollY + (self.camY - prevCamY) * BG_PARALLAX
    if self.bgScrollX >= bgW then self.bgScrollX = self.bgScrollX - bgW end
    if self.bgScrollY >= bgH then self.bgScrollY = self.bgScrollY - bgH end
end

-- ── Colisión jugador ↔ entidades ──────────────────────────────────────────────
-- Las reglas (pinchos, pisotón, hostilidad) viven en entities/Interactions.lua
function AdventureState:checkEnemyCollisions()
    local player = self.player
    if player.dying or not player.alive then return end

    for _, g in ipairs(self.enemies) do
        local result, bounceVy, pts = Entities.interactions.check(player, g)
        if result == 'kill' then
            player:die()
            return
        elseif result == 'hurt' then
            if player:hurt() then return end
        elseif result == 'stomp' then
            g:stomp()
            player.vy = bounceVy
            player.jumpsLeft = 2
            self.score = self.score + pts
            local popY = g.flipped and (g.y + g.outerH / 2) or (g.y - g.outerH / 2)
            self:spawnPopup('+' .. pts .. '!', g.x, popY)
        end
    end
end

-- ── Update ────────────────────────────────────────────────────────────────────
function AdventureState:update(dt)
    -- ── Game over ─────────────────────────────────────────────────────────────
    if self.dead then
        self.timeScale = self.timeScale + (0.7 - self.timeScale) * 2 * dt
        Sound.setMusicPitch(self.timeScale)
        self.deadTimer = self.deadTimer + dt

        local sdt = dt * self.timeScale
        self.player:update(sdt, self.level)

        if self.deadTimer > 0.8 then
            if Input.pressed('nav_up') then
                self.selectedOpt = self.selectedOpt - 1
                if self.selectedOpt < 1 then self.selectedOpt = #GAMEOVER_OPTIONS end
                Sound.play('select')
            end
            if Input.pressed('nav_down') then
                self.selectedOpt = self.selectedOpt + 1
                if self.selectedOpt > #GAMEOVER_OPTIONS then self.selectedOpt = 1 end
                Sound.play('select')
            end
            if Input.pressed('confirm') then
                Sound.play('select')
                if self.selectedOpt == 1 then
                    gStateMachine:change('adventure', { level = self.levelPath })
                else
                    gStateMachine:change('main_menu')
                end
                return
            end
        end
        return
    end

    -- ── Respawn ───────────────────────────────────────────────────────────────
    if self.respawning then
        self.player:update(dt, self.level)
        self.respawnTimer = self.respawnTimer + dt
        if self.respawnTimer >= RESPAWN_DELAY then
            self.player:respawn()
            self.camFrozen    = false
            self.respawning   = false
            self.respawnTimer = 0
        end
        return
    end

    -- ── Forzar recálculo del Canvas si la pantalla rota / cambia proporción ──
    if self.sceneCanvas:getWidth() ~= WINDOW_W or self.sceneCanvas:getHeight() ~= WINDOW_H then
        self.sceneCanvas = love.graphics.newCanvas(WINDOW_W, WINDOW_H)
    end

    -- ── Actualizar Controles Virtuales (Mantener presionado) ──
    if Input.isMobile and not self.dead then
        Input.VirtualPad.down['move_left']  = false
        Input.VirtualPad.down['move_right'] = false
        Input.VirtualPad.down['jump']       = false
        
        local touches = love.touch.getTouches()
        for _, id in ipairs(touches) do
            local tx, ty = love.touch.getPosition(id)
            local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
            local scale  = math.min(sw / WINDOW_W, sh / WINDOW_H)
            local offX   = (sw - WINDOW_W * scale) / 2
            local offY   = (sh - WINDOW_H * scale) / 2
            local lx     = (tx - offX) / scale
            local ly     = (ty - offY) / scale
            
            if ly > WINDOW_H - 250 then
                if lx > 20 and lx < 150 then
                    Input.VirtualPad.down['move_left'] = true
                elseif lx > 170 and lx < 300 then
                    Input.VirtualPad.down['move_right'] = true
                elseif lx > WINDOW_W - 200 and lx < WINDOW_W - 20 then
                    Input.VirtualPad.down['jump'] = true
                end
            end
        end
    end

    if Input.pressed('pause') then
        gStateMachine:push('pause')
        return
    end

    -- ── Lógica normal ─────────────────────────────────────────────────────────
    -- Cap del tiempo: congelar en 600 al morir por tiempo
    if not self.player.dying then
        self.levelTime = math.min(self.levelTime + dt, 600)
    end

    -- Límite de 10 minutos: muerte instantánea con todas las vidas
    if self.levelTime >= 600 and not self.player.dying then
        self.player.lives = 1   -- die() restará 1, quedando en 0 → game over
        self.player:die()
    end

    self.level:update(dt)
    self.level:updateFoliage(dt)
    self.player:update(dt, self.level)

    -- Actualizar enemigos y limpiar los que ya murieron
    for i = #self.enemies, 1, -1 do
        local g = self.enemies[i]
        g:update(dt, self.level)
        if not g.alive then
            table.remove(self.enemies, i)
        end
    end

    -- Colisiones jugador ↔ enemigos
    self:checkEnemyCollisions()
    self:checkVentOxyCollisions()
    self:updatePopups(dt)

    self:updateCamera(dt)

    -- ── Detectar muerte del jugador ───────────────────────────────────────────
    if self.player.dying and not self.player.alive then
        self.player.lives = self.player.lives - 1

        if self.player.lives <= 0 then
            self.dead        = true
            self.deadTimer   = 0
            self.selectedOpt = 1
            self.timeScale   = 1.0
        else
            self.respawning   = true
            self.respawnTimer = 0
            self.camFrozen    = true
        end
    elseif self.player.dying then
        self.camFrozen = true
    end
end

-- ── HUD: vidas ────────────────────────────────────────────────────────────────
local function renderLivesHud(player)
    local iconW = imgIcon:getWidth()  * ICON_SCALE
    local iconH = imgIcon:getHeight() * ICON_SCALE

    love.graphics.setFont(FONT_BIG)
    local label  = 'x' .. player.lives
    local labelW = FONT_BIG:getWidth(label)
    local gap    = 10

    local totalW = iconW + gap + labelW
    local sx     = WINDOW_W - totalW - 20
    local sy     = 14

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(imgIcon, sx, sy, 0, ICON_SCALE, ICON_SCALE)

    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.print(label, sx + iconW + gap, sy + iconH/2 - FONT_BIG:getHeight()/2)
end

-- ── HUD: barritas HP ──────────────────────────────────────────────────────────
local function renderHpBar(player)
    if not player.showHpBar then return end

    local totalW = player.hpMax * HP_BAR_W + (player.hpMax - 1) * HP_BAR_GAP
    local startX = math.floor((WINDOW_W - totalW) / 2)
    local barY   = WINDOW_H - HP_BAR_H - 20

    for i = 1, player.hpMax do
        local bx     = startX + (i - 1) * (HP_BAR_W + HP_BAR_GAP)
        local filled = i <= player.hp

        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.rectangle('fill', bx + 3, barY + 3, HP_BAR_W, HP_BAR_H)

        if filled then
            love.graphics.setColor(1, 1, 1, 1)
        else
            love.graphics.setColor(0.15, 0.15, 0.15, 0.85)
        end
        love.graphics.rectangle('fill', bx, barY, HP_BAR_W, HP_BAR_H)

        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle('line', bx, barY, HP_BAR_W, HP_BAR_H)
    end
end

-- ── Render ────────────────────────────────────────────────────────────────────
function AdventureState:render()
    local bgW = imgBg:getWidth()  * BG_SCALE
    local bgH = imgBg:getHeight() * BG_SCALE

    -- ── Aislar transformaciones para el Canvas (Evita zoom doble y cortes) ──
    love.graphics.push()
    love.graphics.origin()

    -- ── Paso 1: renderizar toda la escena al canvas ───────────────────────────
    love.graphics.setCanvas(self.sceneCanvas)
    love.graphics.clear(0, 0, 0, 1)

    love.graphics.setColor(1, 1, 1, 1)
    local startX = -(math.floor(self.bgScrollX) % bgW)
    local startY = -(math.floor(self.bgScrollY) % bgH)
    if startX > 0 then startX = startX - bgW end
    if startY > 0 then startY = startY - bgH end
    local x = startX
    while x < WINDOW_W do
        local y = startY
        while y < WINDOW_H do
            love.graphics.draw(imgBg, x, y, 0, BG_SCALE, BG_SCALE)
            y = y + bgH
        end
        x = x + bgW
    end

    self.level:render(self.camX, self.camY)
    self.level:renderVents(self.camX, self.camY)

    -- Renderizar enemigos (entre tiles y jugador)
    for _, g in ipairs(self.enemies) do
        g:render(self.camX, self.camY)
    end

    self.player:render(self.camX, self.camY)

    -- Decoraciones (por encima de enemigos y player)
    self.level:renderFoliage(self.camX, self.camY)

    -- Burbujas de agua y vent (por encima de todo menos agua)
    self.level:renderBubbles(self.camX, self.camY)

    love.graphics.setCanvas()
    love.graphics.pop()

    -- ── Paso 2: volver a pantalla y aplicar efecto agua ───────────────────────
    love.graphics.setColor(1, 1, 1, 1)

    self.level:renderWaterEffect(self.camX, self.camY, self.sceneCanvas)

    -- ── Debug hitboxes (F1) ───────────────────────────────────────────────────
    if DEBUG_HITBOX then
        self.player:renderDebug(self.camX, self.camY)

        -- Hitboxes de enemigos
        for _, g in ipairs(self.enemies) do
            g:renderDebug(self.camX, self.camY)
        end

        -- Hitboxes reales del nivel (pinchos, contacto, formas de colisión)
        self.level:renderDebug(self.camX, self.camY)

        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.print("DEBUG HITBOX [F1]", 20, WINDOW_H - 30)
    end

    -- HUD: SCORE y TIME  (sin fondo, valores alineados a la derecha)
    love.graphics.setFont(FONT_BIG)
    local fh = FONT_BIG:getHeight()

    local labelX  = 20
    local gap     = 20
    local row1Y   = 16
    local row2Y   = row1Y + fh + 10

    -- Calcular strings
    local totalSecs = math.floor(self.levelTime)
    local mins      = math.floor(totalSecs / 60)
    local secs      = totalSecs % 60
    local centis    = math.floor((self.levelTime - math.floor(self.levelTime)) * 100)
    local timeStr   = mins .. string.format("'%02d''%02d", secs, centis)
    local scoreStr  = string.format('%06d', self.score)

    -- Columna de etiquetas y columna de valores alineados a la derecha
    local scoreLabelW = FONT_BIG:getWidth('SCORE')
    local timeLabelW  = FONT_BIG:getWidth('TIME')
    local maxLabelW   = math.max(scoreLabelW, timeLabelW)
    local valueStartX = labelX + maxLabelW + gap
    -- El ancho del área de valor se fija al más ancho de los dos valores
    local maxValueW   = math.max(FONT_BIG:getWidth(scoreStr), FONT_BIG:getWidth(timeStr))
    local valueEndX   = valueStartX + maxValueW  -- borde derecho común

    -- Helper: imprime texto con borde negro de 1px
    local function printOutlined(text, x, y, r, g, b, a)
        love.graphics.setColor(0, 0, 0, (a or 1) * 0.75)
        love.graphics.print(text, x + 2, y + 2)
        love.graphics.setColor(r, g, b, a or 1)
        love.graphics.print(text, x, y)
    end

    local sw = FONT_BIG:getWidth(scoreStr)
    local tw = FONT_BIG:getWidth(timeStr)

    -- SCORE
    printOutlined('SCORE',  labelX,          row1Y, 1, 0.95, 0.15)
    printOutlined(scoreStr, valueEndX - sw,  row1Y, 1, 1,    1   )

    -- TIME (parpadea rojo cuando quedan menos de 60 s)
    local timeLeft = 600 - self.levelTime
    local tr, tg, tb, ta = 1, 0.95, 0.15, 1
    local vr, vg, vb, va = 1, 1,    1,    1
    if timeLeft < 60 then
        -- Parpadeo binario: 1s amarillo, 1s rojo
        local red = math.floor(love.timer.getTime()) % 2 == 0
        if red then
            tr, tg, tb = 1, 0.10, 0.10
            vr, vg, vb = 1, 0.20, 0.20
        end
    end
    printOutlined('TIME',   labelX,          row2Y, tr, tg, tb, ta)
    printOutlined(timeStr,  valueEndX - tw,  row2Y, vr, vg, vb, va)

    renderLivesHud(self.player)
    renderHpBar(self.player)
    self.player:renderAirBar()
    self:renderPopups()

    -- ── Game over overlay ─────────────────────────────────────────────────────
    if self.dead and self.deadTimer > 0.4 then
        local oa = math.min(1, (self.deadTimer - 0.4) / 0.4)

        love.graphics.setColor(0, 0, 0, 0.60 * oa)
        love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)

        love.graphics.setFont(FONT_BIG)
        love.graphics.setColor(COLOR_RED[1], COLOR_RED[2], COLOR_RED[3], oa)
        love.graphics.printf('GAME OVER', 0, WINDOW_H/2 - 110, WINDOW_W, 'center')

        if self.deadTimer > 0.8 then
            local ba = math.min(1, (self.deadTimer - 0.8) / 0.3)
            love.graphics.setFont(FONT_MED)
            local btnW   = 260
            local btnH   = 48
            local gap    = 18
            local totalH = #GAMEOVER_OPTIONS * btnH + (#GAMEOVER_OPTIONS - 1) * gap
            local startY = WINDOW_H/2 - totalH/2 + 30
            local cx     = WINDOW_W / 2
            for i, opt in ipairs(GAMEOVER_OPTIONS) do
                local by = startY + (i - 1) * (btnH + gap)
                drawPixelButton(opt, cx, by, btnW, btnH, i == self.selectedOpt, ba)
            end
        end
    end

    -- ── Dibujar controles virtuales en móviles si se usa la pantalla táctil ──
    if Input.isMobile and Input.lastDevice == 'touch' and not self.dead then
        love.graphics.setColor(1, 1, 1, 0.25)
        -- D-Pad
        love.graphics.circle('fill', 85, WINDOW_H - 125, 65)
        love.graphics.circle('fill', 235, WINDOW_H - 125, 65)
        -- Action (Jump)
        love.graphics.circle('fill', WINDOW_W - 110, WINDOW_H - 125, 65)
        -- Pause (Arriba derecha)
        love.graphics.circle('fill', WINDOW_W - 50, 50, 30)
        
        love.graphics.setFont(FONT_BIG)
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.printf('<', 20, WINDOW_H - 140, 130, 'center')
        love.graphics.printf('>', 170, WINDOW_H - 140, 130, 'center')
        love.graphics.printf('A', WINDOW_W - 175, WINDOW_H - 140, 130, 'center')
        love.graphics.printf('||', WINDOW_W - 80, 40, 60, 'center')
    end

    love.graphics.setFont(FONT_MED)
    love.graphics.setColor(COLOR_WHITE)
end

-- Hover del mouse: mueve la selección real (solo en game over)
function AdventureState:mousemoved(tx, ty)
    if not self.dead or self.deadTimer <= 0.8 then return end
    local btnW   = 260
    local btnH   = 48
    local gap    = 18
    local totalH = #GAMEOVER_OPTIONS * btnH + (#GAMEOVER_OPTIONS - 1) * gap
    local startY = WINDOW_H/2 - totalH/2 + 30
    local cx     = WINDOW_W / 2
    for i = 1, #GAMEOVER_OPTIONS do
        local by = startY + (i-1) * (btnH + gap)
        local bx = cx - btnW/2
        if tx >= bx-10 and tx <= bx+btnW+10 and ty >= by-5 and ty <= by+btnH+5 then
            if self.selectedOpt ~= i then self.selectedOpt = i; Sound.play('select') end
            return
        end
    end
end

-- Táctil Switch: tap en botón de game over
function AdventureState:touchpressed(id, tx, ty, dx, dy, pressure)
    if self.dead then
        if self.deadTimer <= 0.8 then return end
        local btnW   = 260
        local btnH   = 48
        local gap    = 18
        local totalH = #GAMEOVER_OPTIONS * btnH + (#GAMEOVER_OPTIONS-1) * gap
        local startY = WINDOW_H/2 - totalH/2 + 30
        local cx     = WINDOW_W / 2
        for i, _ in ipairs(GAMEOVER_OPTIONS) do
            local by = startY + (i-1) * (btnH + gap)
            local bx = cx - btnW/2
            if tx >= bx-10 and tx <= bx+btnW+10 and ty >= by-5 and ty <= by+btnH+5 then
                Sound.play('select')
                if i == 1 then
                    gStateMachine:change('adventure', { level = self.levelPath })
                else
                    gStateMachine:change('main_menu')
                end
                return
            end
        end
        return
    end

    -- Interceptar toques de un solo cuadro (Jump y Pause)
    if Input.isMobile then
        if ty > WINDOW_H - 250 then
            if tx > WINDOW_W - 200 and tx < WINDOW_W - 20 then
                Input.VirtualPad._pressedThisFrame['jump'] = true
            end
        elseif ty < 100 and tx > WINDOW_W - 100 then
            Input.VirtualPad._pressedThisFrame['pause'] = true
        end
    end
end

return AdventureState