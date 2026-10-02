-- src/ui/Celebration.lua
-- CONFETI y FUEGOS ARTIFICIALES de las pantallas de resultados (la de la ronda online y la de un
-- nivel del modo historia): una instancia por pantalla.
--   local fx = Celebration.new()
--   fx:burst(x, y, n, spread)   ráfaga de confeti hacia arriba
--   fx:rain(dt)                 confeti suave cayendo de arriba (llamar cada fotograma)
--   fx:rocket()                 un cohete que sube y estalla (con su sonido)
--   fx:update(dt)  ·  fx:drawBack() (cohetes y chispas, detrás)  ·  fx:drawFront() (confeti, delante)
local Celebration = {}
Celebration.__index = Celebration

Celebration.COLORS = { { 1, 0.85, 0.2 }, { 1, 0.35, 0.45 }, { 0.35, 0.85, 1 }, { 0.5, 1, 0.45 }, { 0.85, 0.5, 1 }, { 1, 1, 1 } }
local COLS = Celebration.COLORS

function Celebration.new() return setmetatable({ confetti = {}, sparks = {}, rockets = {} }, Celebration) end

function Celebration:burst(x, y, n, spread)
    for _ = 1, n do
        local ang = -math.pi / 2 + (math.random() * 2 - 1) * (spread or 1.1)
        local sp = 250 + math.random() * 420
        self.confetti[#self.confetti + 1] = {
            x = x, y = y, vx = math.cos(ang) * sp, vy = math.sin(ang) * sp,
            rot = math.random() * 6.28, vr = (math.random() * 2 - 1) * 12,
            w = 5 + math.random() * 6, h = 3 + math.random() * 4,
            col = COLS[math.random(#COLS)], life = 3.5 + math.random() * 2, sway = math.random() * 6.28,
        }
    end
end

function Celebration:rain(dt)
    if math.random() < dt * 14 then
        self.confetti[#self.confetti + 1] = {
            x = math.random() * WINDOW_W, y = -10, vx = (math.random() * 2 - 1) * 30, vy = 60 + math.random() * 60,
            rot = math.random() * 6.28, vr = (math.random() * 2 - 1) * 8,
            w = 5 + math.random() * 5, h = 3 + math.random() * 3,
            col = COLS[math.random(#COLS)], life = 12, sway = math.random() * 6.28,
        }
    end
end

-- Cohete: sube desde abajo dejando estela y estalla arriba
function Celebration:rocket()
    local x = 80 + math.random() * (WINDOW_W - 160)
    local ty = 90 + math.random() * 200
    self.rockets[#self.rockets + 1] = { x = x, y = WINDOW_H + 10, tx = x + (math.random() * 2 - 1) * 60, ty = ty,
                                        sx = x, sy = WINDOW_H + 10, t = 0, dur = 0.9 + math.random() * 0.3,
                                        large = math.random() < 0.3, trail = {} }
    Sound.play('fwLaunch', 0.9 + math.random() * 0.2, 0.55)
end

function Celebration:firework(x, y, large)
    local col, col2 = COLS[math.random(#COLS)], COLS[math.random(#COLS)]
    local n = large and 60 or 34
    for i = 1, n do
        local ang = (i / n) * math.pi * 2 + math.random() * 0.2
        local sp = (large and 200 or 140) + math.random() * 90
        self.sparks[#self.sparks + 1] = { x = x, y = y, vx = math.cos(ang) * sp, vy = math.sin(ang) * sp,
                                          col = (i % 3 == 0) and col2 or col, life = 1.1 + math.random() * 0.5, t = 0 }
    end
    if large then Sound.play('fwBlastLarge', 0.95 + math.random() * 0.1, 0.8)
    else Sound.play(math.random() < 0.5 and 'fwBlast1' or 'fwBlast2', 0.9 + math.random() * 0.2, 0.7) end
end

function Celebration:update(dt)
    for i = #self.rockets, 1, -1 do
        local r = self.rockets[i]
        r.t = r.t + dt
        local k = 1 - (1 - math.min(1, r.t / r.dur)) ^ 2          -- frena al subir
        r.x, r.y = r.sx + (r.tx - r.sx) * k, r.sy + (r.ty - r.sy) * k
        table.insert(r.trail, 1, { x = r.x, y = r.y })
        if #r.trail > 10 then table.remove(r.trail) end
        if r.t >= r.dur then table.remove(self.rockets, i); self:firework(r.x, r.y, r.large) end
    end
    for i = #self.confetti, 1, -1 do
        local c = self.confetti[i]
        c.vy = math.min(150, c.vy + 520 * dt)                       -- resistencia del aire
        c.vx = c.vx * (1 - 1.8 * dt)
        c.sway = c.sway + dt * 3
        c.x, c.y = c.x + (c.vx + math.sin(c.sway) * 40) * dt, c.y + c.vy * dt
        c.rot, c.life = c.rot + c.vr * dt, c.life - dt
        if c.life <= 0 or c.y > WINDOW_H + 20 then table.remove(self.confetti, i) end
    end
    for i = #self.sparks, 1, -1 do
        local p = self.sparks[i]
        p.t, p.vy = p.t + dt, p.vy + 120 * dt
        p.vx, p.vy = p.vx * (1 - 1.5 * dt), p.vy * (1 - 1.5 * dt)
        p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
        if p.t >= p.life then table.remove(self.sparks, i) end
    end
end

function Celebration:drawBack()
    for _, r in ipairs(self.rockets) do
        for k, tp in ipairs(r.trail) do
            love.graphics.setColor(1, 0.8, 0.4, (1 - k / (#r.trail + 1)) * 0.8)
            love.graphics.rectangle('fill', tp.x - 2, tp.y - 2, 4, 4)
        end
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle('fill', r.x - 3, r.y - 3, 6, 6)
    end
    for _, p in ipairs(self.sparks) do
        local a = 1 - p.t / p.life
        love.graphics.setColor(p.col[1], p.col[2], p.col[3], a)
        love.graphics.rectangle('fill', p.x - 2, p.y - 2, 4, 4)
        love.graphics.setColor(1, 1, 1, a * 0.6)
        love.graphics.rectangle('fill', p.x - 1, p.y - 1, 2, 2)
    end
end

function Celebration:drawFront()
    for _, c in ipairs(self.confetti) do
        love.graphics.push()
        love.graphics.translate(c.x, c.y)
        love.graphics.rotate(c.rot)
        love.graphics.setColor(c.col[1], c.col[2], c.col[3], math.min(1, c.life))
        local k = math.abs(math.cos(c.rot * 1.7))
        love.graphics.rectangle('fill', -c.w / 2, -c.h / 2 * k, c.w, c.h * k + 1)
        love.graphics.pop()
    end
end

return Celebration
