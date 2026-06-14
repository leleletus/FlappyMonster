-- src/states/TitleState.lua
local BaseState  = require 'src/BaseState'
local TitleState = BaseState:new()

local imgBg    = nil
local imgLogo  = nil
local imgMons  = nil

local MONSTER_COUNT = 15
local SCALE         = PLAYER_SCALE + 1
local MW            = 9  * SCALE
local MH            = 16 * SCALE
local MIN_SPEED     = 100
local MAX_SPEED     = 250

local function loadAssets()
    if imgBg then return end
    imgBg   = love.graphics.newImage('assets/images/menus/Menu.png')
    imgLogo = love.graphics.newImage('assets/images/menus/logo.png')
    imgMons = {
        love.graphics.newImage('assets/images/player/monstrito1.png'),
        love.graphics.newImage('assets/images/player/monstrito2.png'),
        love.graphics.newImage('assets/images/player/monstrito3.png'),
    }
end

local function newMonster()
    local speed = MIN_SPEED + math.random() * (MAX_SPEED - MIN_SPEED)
    local angle = math.random() * math.pi * 2
    return {
        x      = math.random(MW, WINDOW_W - MW),
        y      = math.random(MH, WINDOW_H - MH),
        vx     = math.cos(angle) * speed,
        vy     = math.sin(angle) * speed,
        angle  = math.random() * math.pi * 2,
        va     = (math.random() - 0.5) * 6,
        frame  = math.random(1, 3),
        frameT = 0,
        puff   = 1,
    }
end

function TitleState:enter(args)
    loadAssets()
    self.pulse    = 0
    self.monsters = {}
    for i = 1, MONSTER_COUNT do
        table.insert(self.monsters, newMonster())
    end
    Sound.playMusic('menus')
end

function TitleState:update(dt)
    self.pulse = self.pulse + dt * 2.5

    if Input.pressed('confirm') or Input.pressed('flap') then
        Sound.play('select')
        gStateMachine:change('main_menu')   -- ← ahora va al menú principal
    end

    for _, m in ipairs(self.monsters) do
        m.x = m.x + m.vx * dt
        m.y = m.y + m.vy * dt
        m.angle = m.angle + m.va * dt

        if m.x - MW/2 < 0 then
            m.x   = MW/2
            m.vx  = math.abs(m.vx)
            m.va  = m.vy * 0.03
            m.puff = 1.2
            Sound.play('jump', 0.6 + math.random() * 0.4, 0.2)
        end
        if m.x + MW/2 > WINDOW_W then
            m.x   = WINDOW_W - MW/2
            m.vx  = -math.abs(m.vx)
            m.va  = -m.vy * 0.03
            m.puff = 1.2
            Sound.play('jump', 0.6 + math.random() * 0.4, 0.2)
        end
        if m.y - MH/2 < 0 then
            m.y   = MH/2
            m.vy  = math.abs(m.vy)
            m.va  = m.vx * 0.03
            m.puff = 1.2
            Sound.play('jump', 0.6 + math.random() * 0.4, 0.2)
        end
        if m.y + MH/2 > WINDOW_H then
            m.y   = WINDOW_H - MH/2
            m.vy  = -math.abs(m.vy)
            m.va  = -m.vx * 0.03
            m.puff = 1.2
            Sound.play('jump', 0.6 + math.random() * 0.4, 0.2)
        end

        m.frameT = m.frameT + dt
        local fps = 4 + math.abs(m.va) * 0.5
        if m.frameT >= 1 / fps then
            m.frameT = 0
            m.frame  = (m.frame == 1) and 3 or 1
        end

        m.puff = m.puff + (1 - m.puff) * 10 * dt
        m.va   = m.va * (1 - 3 * dt)
    end

    for i = 1, #self.monsters do
        for j = i + 1, #self.monsters do
            local a  = self.monsters[i]
            local b  = self.monsters[j]
            local dx = b.x - a.x
            local dy = b.y - a.y
            local dist = math.sqrt(dx*dx + dy*dy)
            local minD = MW * 0.85

            if dist < minD and dist > 0 then
                local nx   = dx / dist
                local ny   = dy / dist
                local over = (minD - dist) / 2
                a.x = a.x - nx * over
                a.y = a.y - ny * over
                b.x = b.x + nx * over
                b.y = b.y + ny * over

                local dvx = b.vx - a.vx
                local dvy = b.vy - a.vy
                local dot = dvx * nx + dvy * ny
                if dot < 0 then
                    a.vx = a.vx + dot * nx
                    a.vy = a.vy + dot * ny
                    b.vx = b.vx - dot * nx
                    b.vy = b.vy - dot * ny

                    local tx  = -ny
                    local ty  =  nx
                    local tan = dvx * tx + dvy * ty
                    a.va = a.va - tan * 0.06
                    b.va = b.va + tan * 0.06

                    a.puff = 1.25
                    b.puff = 1.25
                    a.frame = 2
                    b.frame = 2
                    Sound.play('jump', 0.7 + math.random() * 0.6, 0.35)
                end
            end
        end
    end
end

function TitleState:touchpressed(id, x, y, dx, dy, pressure)
    Sound.play('select')
    gStateMachine:change('main_menu')
end

function TitleState:render()
    local bx = WINDOW_W / imgBg:getWidth()
    local by = WINDOW_H / imgBg:getHeight()
    love.graphics.setColor(COLOR_WHITE)
    love.graphics.draw(imgBg, 0, 0, 0, bx, by)

    for _, m in ipairs(self.monsters) do
        local img = imgMons[m.frame] or imgMons[1]
        local iw  = img:getWidth()
        local ih  = img:getHeight()
        local s   = SCALE * m.puff
        local fx  = (m.vx >= 0) and s or -s
        love.graphics.setColor(COLOR_WHITE)
        love.graphics.draw(img,
            math.floor(m.x), math.floor(m.y),
            m.angle,
            fx, s,
            iw / 2, ih / 2)
    end

    local lw = imgLogo:getWidth() * LOGO_SCALE
    love.graphics.setColor(COLOR_WHITE)
    love.graphics.draw(imgLogo,
        math.floor((WINDOW_W - lw) / 2),
        math.floor(WINDOW_H * 0.28),
        0, LOGO_SCALE, LOGO_SCALE)

    local alpha = (math.sin(self.pulse) + 1) / 2 * 0.7 + 0.3
    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.printf(
        "Presiona " .. Input.label('confirm') .. " para continuar",
        0, math.floor(WINDOW_H * 0.72), WINDOW_W, 'center')

    love.graphics.setColor(COLOR_WHITE)
end

return TitleState