local CornerButtons = require 'src/ui/CornerButtons'
-- src/states/PlayState.lua
local BaseState = require 'src/BaseState'
local Player    = require 'src/entities/Player'
local Pipe      = require 'src/entities/Pipe'

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

local GAMEOVER_OPTIONS = { 'Reintentar', 'Menu' }

local imgBg = nil
local function loadBg()
    if imgBg then return end
    imgBg = love.graphics.newImage('assets/images/level/Background.png')
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
    self.pipeSpeed     = PIPE_SPEED     * diff.speedMult
    self.pipeGap       = PIPE_GAP       * diff.gapMult
    self.pipeSpawnTime = PIPE_SPAWN_TIME / diff.spawnMult
    self.pointsPerPipe = diff.points
    self.pipeMinY      = 80
    self.pipeMaxY      = WINDOW_H - 80 - self.pipeGap

    self.player    = Player:new()
    self.pipes     = {}
    self.score     = 0
    self.highScore = self:loadHighScore(diffKey)
    self.bgScroll  = 0
    self.pipeTimer = self.pipeSpawnTime * 0.55

    self.dead        = false
    self.deadTimer   = 0
    self.timeScale   = 1.0
    self.selectedOpt = 1

    local palette     = PALETTES[diffKey]
    self.palette      = palette
    self.colorIdx     = 1
    self.nextColorIdx = 2
    self.colorT       = 0

    Sound.playMusic('level')
end

function PlayState:pause()  end
function PlayState:resume() Sound.playMusic('level') end

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
        self.pipeTimer = self.pipeTimer + sdt
        if self.pipeTimer >= self.pipeSpawnTime then
            self.pipeTimer = 0
            local gapY = math.random(
                math.floor(self.pipeMinY + self.pipeGap / 2),
                math.floor(self.pipeMaxY + self.pipeGap / 2))
            local p = Pipe:new(WINDOW_W + PIPE_W, gapY)
            p.gap = self.pipeGap
            table.insert(self.pipes, p)
        end
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

    self.pipeTimer = self.pipeTimer + sdt
    if self.pipeTimer >= self.pipeSpawnTime then
        self.pipeTimer = 0
        local gapY = math.random(
            math.floor(self.pipeMinY + self.pipeGap / 2),
            math.floor(self.pipeMaxY + self.pipeGap / 2))
        local p = Pipe:new(WINDOW_W + PIPE_W, gapY)
        p.gap = self.pipeGap
        table.insert(self.pipes, p)
    end

    for i = #self.pipes, 1, -1 do
        local p = self.pipes[i]
        p:update(sdt)
        p.x = p.x - self.pipeSpeed * sdt
        if not p.passed and p.x + p.w < self.player.x then
            p.passed = true
            self.score = self.score + self.pointsPerPipe
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
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.setFont(FONT_MED)
    love.graphics.print("Score: " .. self.score,     20, 20)
    love.graphics.print("Best:  " .. self.highScore, 20, 55)
    love.graphics.setFont(FONT_BIG)
    local diffLabel = string.upper(self.diffKey)
    local diffW = FONT_BIG:getWidth(diffLabel)
    love.graphics.print(diffLabel, WINDOW_W - diffW - 24, 20)

    -- ── Game over overlay ─────────────────────────────────────────────────────
    if self.dead and self.deadTimer > 0.4 then
        local oa = math.min(1, (self.deadTimer - 0.4) / 0.4)

        love.graphics.setColor(0, 0, 0, 0.60 * oa)
        love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)

        love.graphics.setFont(FONT_BIG)
        love.graphics.setColor(COLOR_RED[1], COLOR_RED[2], COLOR_RED[3], oa)
        love.graphics.printf('GAME OVER', 0, WINDOW_H/2 - 110, WINDOW_W, 'center')

        love.graphics.setFont(FONT_MED)
        love.graphics.setColor(1, 1, 1, oa)
        love.graphics.printf('Puntuacion: ' .. self.score, 0, WINDOW_H/2 - 40, WINDOW_W, 'center')

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
                drawPixelButton(opt, cx, by, btnW, btnH, i == self.selectedOpt, ba)
            end
        end
    end

    if not self.dead then CornerButtons.drawPause(self.pauseHover) end

    love.graphics.setFont(FONT_MED)
    love.graphics.setColor(COLOR_WHITE)
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