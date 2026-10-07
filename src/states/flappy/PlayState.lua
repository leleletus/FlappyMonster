local CornerButtons = require 'src/ui/CornerButtons'
-- src/states/flappy/PlayState.lua
local BaseState = require 'src/core/BaseState'
local Player    = require 'src/flappy/Player'
local Pipe      = require 'src/flappy/Pipe'
local L = require 'src/core/Lang'
local PixelFont  = require 'src/ui/PixelFont'
local PixelIcons = require 'src/ui/PixelIcons'

-- HUD: puntuación grande en el centro (fuente pixel de los menús), récord debajo
-- con la corona, dificultad en una placa de su color arriba a la izquierda
local SCORE_PX   = 12                       -- escala de la fuente pixel de la puntuación
local POP_T      = 0.18                     -- s del "salto" al sumar un punto
local FLASH_T    = 0.6                      -- s del destello amarillo cada 10 puntos
local YELLOW     = { 1, 0.9, 0.2 }
local DIFF_COLOR = { easy = { 0.30, 0.72, 0.36 }, normal = { 0.95, 0.72, 0.15 }, hard = { 0.86, 0.24, 0.24 } }

local PlayState = BaseState:new()

local PALETTES = {
    easy   = {{0.55,1.00,0.55},{0.40,0.95,0.60},{0.70,1.00,0.40},{0.45,1.00,0.75},{0.60,0.90,0.45}},
    normal = {{0.50,0.80,1.00},{0.40,0.65,1.00},{0.60,0.90,1.00},{0.35,0.75,0.95},{0.55,0.85,0.98}},
    hard   = {{1.00,0.45,0.45},{1.00,0.60,0.40},{1.00,0.35,0.55},{0.95,0.50,0.35},{1.00,0.55,0.55}},
}

local BG_SCALE        = 15
local BG_PARALLAX     = 0.4
local COLOR_LERP_SPD  = 0.5
local SLOWDOWN_TARGET = 0.7
local SLOWDOWN_SPEED  = 1.8

local GAMEOVER_OPTIONS = { 'common.retry', 'common.menu' }   -- claves de idioma

local imgBg = nil
local function loadBg()
    if imgBg then return end
    imgBg = love.graphics.newImage('assets/images/flappy/Background.png')
end

-- ── Helper: botón cuadrado pixel art ─────────────────────────────────────────
local function drawPixelButton(label, cx, y, w, h, selected, alpha)
    if selected then
        love.graphics.setColor(0.18, 0.18, 0.18, alpha)
        love.graphics.rectangle('fill', cx - w/2 + 4, y + 4, w, h)   -- sombra
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

function PlayState:enter(args)
    loadBg()
    args = args or {}
    local diffKey = args.difficulty or 'normal'
    local diff    = DIFFICULTIES[diffKey]

    self.diffKey       = diffKey
    self.diff          = diff
    self.baseSpeed     = PIPE_SPEED     * diff.speedMult
    self.pipeSpeed     = self.baseSpeed
    self.pipeGap       = PIPE_GAP       * diff.gapMult
    self.pipeSpacing   = diff.spacing
    self.pointsPerPipe = diff.points
    self.passed        = 0                  -- tuberías pasadas (aceleración)
    self.pipeMinY      = 80
    self.pipeMaxY      = WINDOW_H - 80 - self.pipeGap

    self.player    = Player:new()
    self.pipes     = {}
    self.score     = 0
    self.popT, self.flashT = 0, 0
    self.highScore = self:loadHighScore(diffKey)
    self.bgScroll  = 0
    self.pipeDist  = self.pipeSpacing * 0.45          -- (la primera tubería llega pronto)

    self.dead        = false
    self.deadTimer   = 0
    self.timeScale   = 1.0
    self.selectedOpt = 1

    local palette     = PALETTES[diffKey]
    self.palette      = palette
    self.colorIdx     = 1
    self.nextColorIdx = 2
    self.colorT       = 0

    Sound.setLevelMusic(nil); Sound.setBaseLevelMusic(nil)   -- Flappy: la de siempre
    Sound.playMusic('level')
end

function PlayState:pause()  end
-- Al volver de la pausa la música sigue donde estaba (no se reinicia)
function PlayState:resume()
    if not Sound.resumeAll() then Sound.playMusic('level') end
end

function PlayState:pauseGame()
    if not self.dead then gStateMachine:push('pause') end
end

function PlayState:update(dt)
    if self.dead then
        self.timeScale = self.timeScale + (SLOWDOWN_TARGET - self.timeScale)
                         * SLOWDOWN_SPEED * dt
        Sound.setMusicPitch(self.timeScale)
    end

    local sdt = dt * self.timeScale

    if self.dead then
        self.deadTimer = self.deadTimer + dt
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
                    gStateMachine:change('play', { difficulty = self.diffKey })
                else
                    gStateMachine:change('main_menu')
                end
                return
            end
        end
        self.player:update(sdt)
        self:spawnPipes(sdt)
        for i = #self.pipes, 1, -1 do
            local p = self.pipes[i]
            p:update(sdt)
            p.x = p.x - self.pipeSpeed * sdt
            if p:isOffScreen() then table.remove(self.pipes, i) end
        end
        self:updateScroll(sdt)
        self:updateColor(dt)
        return
    end

    if Input.pressed('flap') then self.player:flap() end
    if Input.pressed('pause') then
        gStateMachine:push('pause')
        return
    end

    self:updateScroll(sdt)
    self:updateColor(dt)

    self:spawnPipes(sdt)

    for i = #self.pipes, 1, -1 do
        local p = self.pipes[i]
        p:update(sdt)
        p.x = p.x - self.pipeSpeed * sdt
        if not p.passed and p.x + p.w < self.player.x then
            p.passed = true
            -- (la velocidad sube un poco con cada tubería, hasta su tope)
            self.passed = self.passed + 1
            self.pipeSpeed = self.baseSpeed * (1 + math.min(self.diff.rampMax or 0, self.passed * (self.diff.ramp or 0)))
            local before = self.score
            self.score = self.score + self.pointsPerPipe
            self.popT = POP_T
            if math.floor(self.score / 10) > math.floor(before / 10) then self.flashT = FLASH_T end
            if self.score % 10 == 0 then
                Sound.play('decimal', Sound.decimalPitch(self.score))
            else
                Sound.play('point')
            end
        end
        if p:isOffScreen() then table.remove(self.pipes, i) end
    end

    self.player:update(sdt)

    local bounds = self.player:getBounds()
    for _, p in ipairs(self.pipes) do
        if p:collides(bounds) then self:die(); return end
    end
    if not self.player.alive then self:die() end
end

-- Saca tuberías por DISTANCIA recorrida (la separación no cambia al acelerar). El
-- hueco nuevo no se aleja más de maxJump del anterior: rápido pero siempre alcanzable
function PlayState:spawnPipes(sdt)
    self.pipeDist = self.pipeDist + self.pipeSpeed * sdt
    if self.pipeDist < self.pipeSpacing then return end
    self.pipeDist = self.pipeDist - self.pipeSpacing
    local lo = math.floor(self.pipeMinY + self.pipeGap / 2)
    local hi = math.floor(self.pipeMaxY + self.pipeGap / 2)
    local mj = self.diff.maxJump
    if mj and self.lastGapY then
        lo = math.max(lo, math.floor(self.lastGapY - mj))
        hi = math.min(hi, math.floor(self.lastGapY + mj))
    end
    local gapY = math.random(lo, math.max(lo, hi))
    self.lastGapY = gapY
    local p = Pipe:new(WINDOW_W + PIPE_W, gapY)
    p.gap = self.pipeGap
    table.insert(self.pipes, p)
end

function PlayState:updateScroll(sdt)
    self.bgScroll = self.bgScroll + self.pipeSpeed * BG_PARALLAX * sdt
    local bgW = imgBg:getWidth() * BG_SCALE
    if self.bgScroll >= bgW then self.bgScroll = self.bgScroll - bgW end
end

function PlayState:updateColor(dt)
    self.colorT = self.colorT + dt * COLOR_LERP_SPD
    if self.colorT >= 1 then
        self.colorT       = self.colorT - 1
        self.colorIdx     = self.nextColorIdx
        self.nextColorIdx = (self.nextColorIdx % #self.palette) + 1
    end
end

function PlayState:die()
    self.dead        = true
    self.selectedOpt = 1
    self.player:die()
    Sound.play('dies')
    self.newBest = self.score > self.highScore
    if self.score > self.highScore then
        self.highScore = self.score
        self:saveHighScore(self.diffKey, self.score)
    end
end

function PlayState:render()
    local ca = self.palette[self.colorIdx]
    local cb = self.palette[self.nextColorIdx]
    local t  = self.colorT
    local r  = ca[1] + (cb[1]-ca[1]) * t
    local g  = ca[2] + (cb[2]-ca[2]) * t
    local b  = ca[3] + (cb[3]-ca[3]) * t

    love.graphics.setColor(r, g, b, 1)
    love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)

    local bgW = imgBg:getWidth()  * BG_SCALE
    local bgH = imgBg:getHeight() * BG_SCALE
    love.graphics.setColor(r, g, b, 1)
    local startX = -(math.floor(self.bgScroll) % bgW)
    if startX > 0 then startX = startX - bgW end
    local x = startX
    while x < WINDOW_W do
        local y = 0
        while y < WINDOW_H do
            love.graphics.draw(imgBg, x, y, 0, BG_SCALE, BG_SCALE)
            y = y + bgH
        end
        x = x + bgW
    end

    for _, p in ipairs(self.pipes) do p:render() end
    self.player:render()

    -- HUD
    if not self.dead then self:renderHud() end

    -- ── Game over overlay ─────────────────────────────────────────────────────
    if self.dead and self.deadTimer > 0.4 then
        local oa = math.min(1, (self.deadTimer - 0.4) / 0.4)

        love.graphics.setColor(0, 0, 0, 0.60 * oa)
        love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)

        self:renderGameOverCard(oa)

        if self.deadTimer > 0.8 then
            local ba = math.min(1, (self.deadTimer - 0.8) / 0.3)

            local btnW   = 260
            local btnH   = 48
            local gap    = 18
            local totalH = #GAMEOVER_OPTIONS * btnH + (#GAMEOVER_OPTIONS - 1) * gap
            local startY = WINDOW_H/2 - totalH/2 + 40
            local cx     = WINDOW_W / 2

            for i, opt in ipairs(GAMEOVER_OPTIONS) do
                local by = startY + (i - 1) * (btnH + gap)
                drawPixelButton(L(opt), cx, by, btnW, btnH, i == self.selectedOpt, ba)
            end
        end
    end

    if not self.dead then CornerButtons.drawPause(self.pauseHover) end

    love.graphics.setFont(FONT_MED)
    love.graphics.setColor(COLOR_WHITE)
end

-- Texto en la fuente pixel con margen negro de un píxel (de la fuente) y sombra
local function boxed(text, x, y, s, a, color)
    local w, h = PixelFont.width(text, s), PixelFont.height(s)
    local top = text:find('[\195]') and 2 * s or 0             -- (tildes encima)
    love.graphics.setColor(0, 0, 0, 0.45 * (a or 1))
    love.graphics.rectangle('fill', x - s + s, y - s - top + s, w + 2 * s, h + 2 * s + top)
    love.graphics.setColor(0, 0, 0, a or 1)
    love.graphics.rectangle('fill', x - s, y - s - top, w + 2 * s, h + 2 * s + top)
    PixelFont.draw(text, x, y, s, a, color)
end

-- Texto con sombra negra (como el HUD de la Aventura)
local function shadowed(font, text, x, y, c, a)
    love.graphics.setFont(font)
    love.graphics.setColor(0, 0, 0, 0.8 * (a or 1))
    love.graphics.print(text, x + 3, y + 3)
    love.graphics.setColor(c[1], c[2], c[3], a or 1)
    love.graphics.print(text, x, y)
end

function PlayState:renderHud()
    local dt = love.timer.getDelta()
    self.popT = math.max(0, (self.popT or 0) - dt)
    self.flashT = math.max(0, (self.flashT or 0) - dt)
    -- Puntuación: grande y centrada; da un saltito al sumar y destella cada 10
    local txt = tostring(self.score)
    local px = SCORE_PX + ((self.popT > POP_T / 2) and 2 or (self.popT > 0 and 1 or 0))
    local w = PixelFont.width(txt, px)
    local col = (self.flashT > 0 and math.floor(self.flashT * 12) % 2 == 0) and YELLOW or nil
    boxed(txt, math.floor(WINDOW_W / 2 - w / 2), 30 - (px - SCORE_PX) * 2, px, 1, col)
    -- Récord (o ¡nuevo récord!, parpadeando, si ya lo has superado en esta partida)
    local by = 30 + PixelFont.height(SCORE_PX) + 26
    local beaten = self.highScore > 0 and self.score > self.highScore
    -- (con la fuente pixel: la del HUD no tiene tildes en mayúscula)
    local label = beaten and L('flappy.new_best') or (L('flappy.best_label') .. ' ' .. self.highScore)
    local LS = 4
    local lw = PixelFont.width(label, LS)
    local iconW = 11 * 3 + 10
    local lx = math.floor(WINDOW_W / 2 - (lw + iconW) / 2)
    local blink = beaten and math.floor(love.timer.getTime() * 4) % 2 == 0
    PixelIcons.draw('crown', lx, by - 4, 3, 1)
    boxed(label, lx + iconW, by, LS, 1, blink and { 1, 1, 1 } or YELLOW)
    -- Dificultad: placa negra con marco de su color, arriba a la izquierda
    local dl = L('diff.' .. self.diffKey)
    local dc = DIFF_COLOR[self.diffKey] or DIFF_COLOR.normal
    local DS = 4
    local dw, dh = PixelFont.width(dl, DS), PixelFont.height(DS)
    local px, py = 30, 32
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle('fill', px - 10 + 4, py - 12 + 4, dw + 20, dh + 22)   -- sombra
    love.graphics.setColor(dc[1], dc[2], dc[3], 1)
    love.graphics.rectangle('fill', px - 10, py - 12, dw + 20, dh + 22)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle('fill', px - 4, py - 6, dw + 8, dh + 10)
    PixelFont.draw(dl, px, py, DS, 1, dc)
end

-- Tarjeta de fin de partida: GAME OVER, la puntuación grande y el récord
function PlayState:renderGameOverCard(oa)
    local cw, ch = 520, 230
    local x, y = math.floor(WINDOW_W / 2 - cw / 2), math.floor(WINDOW_H / 2 - 270)
    love.graphics.setColor(0, 0, 0, 0.8 * oa)
    love.graphics.rectangle('fill', x + 6, y + 6, cw, ch)
    love.graphics.setColor(0.10, 0.10, 0.16, 0.95 * oa)
    love.graphics.rectangle('fill', x, y, cw, ch)
    love.graphics.setColor(1, 1, 1, oa)
    for _, r in ipairs({ { x, y, cw, 4 }, { x, y + ch - 4, cw, 4 }, { x, y, 4, ch }, { x + cw - 4, y, 4, ch } }) do
        love.graphics.rectangle('fill', r[1], r[2], r[3], r[4])
    end
    local go = L('hud.game_over')
    shadowed(FONT_BIG, go, math.floor(WINDOW_W / 2 - FONT_BIG:getWidth(go) / 2), y + 22, COLOR_RED, oa)
    local txt = tostring(self.score)
    local w = PixelFont.width(txt, 8)
    boxed(txt, math.floor(WINDOW_W / 2 - w / 2), y + 84, 8, oa)
    local newBest = self.score > 0 and self.score >= self.highScore and self.newBest
    local label = newBest and L('flappy.new_best') or (L('flappy.best_label') .. ' ' .. self.highScore)
    local lw = PixelFont.width(label, 4) + 43
    local lx = math.floor(WINDOW_W / 2 - lw / 2)
    PixelIcons.draw('crown', lx, y + ch - 56, 3, oa)
    boxed(label, lx + 43, y + ch - 50, 4, oa, YELLOW)
end

function PlayState:exit() end

function PlayState:loadHighScore(key)
    local file = key .. "_" .. SCORE_FILE
    if love.filesystem.getInfo(file) then
        return tonumber((love.filesystem.read(file))) or 0
    end
    return 0
end

function PlayState:saveHighScore(key, score)
    love.filesystem.write(key .. "_" .. SCORE_FILE, tostring(score))
end

-- Hover del mouse: mueve la selección real (solo en game over)
function PlayState:mousemoved(tx, ty)
    self.pauseHover = not self.dead and CornerButtons.hitPause(tx, ty)
    if not self.dead or self.deadTimer <= 0.8 then return end
    local btnW   = 260
    local btnH   = 48
    local gap    = 18
    local totalH = #GAMEOVER_OPTIONS * btnH + (#GAMEOVER_OPTIONS - 1) * gap
    local startY = WINDOW_H/2 - totalH/2 + 40
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

-- Táctil Switch: vivo = flap, muerto = tap en botón
function PlayState:touchpressed(id, tx, ty, dx, dy, pressure)
    if not self.dead then
        if CornerButtons.hitPause(tx, ty) then
            gStateMachine:push('pause')
        else
            self.player:flap()
        end
        return
    end
    if self.deadTimer <= 0.8 then return end
    local btnW   = 260
    local btnH   = 48
    local gap    = 18
    local totalH = #GAMEOVER_OPTIONS * btnH + (#GAMEOVER_OPTIONS-1) * gap
    local startY = WINDOW_H/2 - totalH/2 + 40
    local cx     = WINDOW_W / 2
    for i, _ in ipairs(GAMEOVER_OPTIONS) do
        local by = startY + (i-1) * (btnH + gap)
        local bx = cx - btnW/2
        if tx >= bx-10 and tx <= bx+btnW+10 and ty >= by-5 and ty <= by+btnH+5 then
            Sound.play('select')
            if i == 1 then
                gStateMachine:change('play', { difficulty = self.diffKey })
            else
                gStateMachine:change('main_menu')
            end
            return
        end
    end
end

return PlayState