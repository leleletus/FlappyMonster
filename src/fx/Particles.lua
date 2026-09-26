-- src/fx/Particles.lua
-- Partículas visuales pixel art (solo cliente; el servidor no dibuja).
--   Particles.emit(kind, x, y, opts)   en coordenadas de mundo
--   Particles.update(dt)  /  Particles.render(camX, camY)  /  Particles.clear()
-- Tipos: 'gp_land', 'gp_start', 'block_break', 'collect', 'spawn', 'oneup',
--        'checkpoint', 'spike_land', 'stun'

local Particles = {}
local list = {}
local MAX  = 600

local function add(p)
    if #list >= MAX then table.remove(list, 1) end
    p.t = 0
    list[#list + 1] = p
end

local function rnd(a, b) return a + math.random() * (b - a) end

function Particles.emit(kind, x, y, opts)
    opts = opts or {}
    if kind == 'gp_land' then
        for i = 1, 16 do                 -- polvo hacia los lados
            local dir = (i % 2 == 0) and 1 or -1
            add({ x = x + dir * rnd(4, 20), y = y - rnd(0, 6), vx = dir * rnd(120, 380), vy = -rnd(40, 220),
                  g = 700, life = rnd(0.35, 0.6), size = math.random(2, 3) * 3, col = {0.92, 0.9, 0.85}, drag = 3 })
        end
        for i = 1, 6 do                  -- estrellitas
            local a = rnd(-math.pi, 0)
            add({ x = x, y = y - 10, vx = math.cos(a) * rnd(150, 300), vy = math.sin(a) * rnd(150, 300),
                  g = 500, life = rnd(0.4, 0.7), size = 6, col = {1, 0.9, 0.3}, star = true })
        end
    elseif kind == 'gp_start' then
        for i = 1, 10 do
            local a = (i / 10) * math.pi * 2
            add({ x = x + math.cos(a) * 14, y = y + math.sin(a) * 14, vx = math.cos(a) * 140, vy = math.sin(a) * 140,
                  life = 0.25, size = 4, col = {1, 1, 1}, drag = 6 })
        end
    elseif kind == 'block_break' then
        local T = TILE_PX
        for i = 0, 3 do                  -- 4 trozos del bloque
            local ox, oy = (i % 2) * T / 2, math.floor(i / 2) * T / 2
            add({ x = x + ox + T / 4, y = y + oy + T / 4, vx = (ox > 0 and 1 or -1) * rnd(80, 200),
                  vy = -rnd(250, 480), g = 1400, life = 1.0, size = T / 2 - 4, col = opts.col or {0.55, 0.45, 0.35},
                  spin = rnd(-8, 8), chunk = true })
        end
        for i = 1, 10 do
            add({ x = x + rnd(0, T), y = y + rnd(0, T), vx = rnd(-150, 150), vy = -rnd(50, 250), g = 900,
                  life = rnd(0.3, 0.6), size = 4, col = {0.8, 0.75, 0.7} })
        end
    elseif kind == 'collect' or kind == 'oneup' or kind == 'checkpoint' then
        local col = (kind == 'oneup') and {0.4, 1, 0.5} or (kind == 'checkpoint' and {0.4, 0.9, 1} or {1, 0.95, 0.4})
        for i = 1, 14 do
            local a = (i / 14) * math.pi * 2
            add({ x = x, y = y, vx = math.cos(a) * rnd(100, 220), vy = math.sin(a) * rnd(100, 220),
                  life = rnd(0.4, 0.7), size = 5, col = col, drag = 4, star = (i % 2 == 0) })
        end
    elseif kind == 'spawn' then
        for i = 1, 18 do
            local a = rnd(0, math.pi * 2)
            local r = rnd(30, 60)
            add({ x = x + math.cos(a) * r, y = y + math.sin(a) * r, tx = x, ty = y, life = 0.5,
                  size = 4, col = {1, 1, 1}, implode = true, sx = x + math.cos(a) * r, sy = y + math.sin(a) * r })
        end
    elseif kind == 'spike_land' then
        for i = 1, 8 do
            add({ x = x + rnd(-20, 20), y = y, vx = rnd(-120, 120), vy = -rnd(60, 200), g = 900,
                  life = 0.4, size = 4, col = {0.85, 0.85, 0.85} })
        end
    end
end

function Particles.update(dt)
    for i = #list, 1, -1 do
        local p = list[i]
        p.t = p.t + dt
        if p.t >= p.life then
            table.remove(list, i)
        elseif p.implode then
            local k = p.t / p.life
            p.x = p.sx + (p.tx - p.sx) * k
            p.y = p.sy + (p.ty - p.sy) * k
        else
            if p.drag then p.vx = p.vx * (1 - p.drag * dt); p.vy = p.vy * (1 - p.drag * dt) end
            p.vy = p.vy + (p.g or 0) * dt
            p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
        end
    end
end

function Particles.render(camX, camY)
    for _, p in ipairs(list) do
        local a = 1 - p.t / p.life
        local c = p.col
        local x, y = math.floor(p.x - camX), math.floor(p.y - camY)
        local s = p.size
        love.graphics.setColor(c[1], c[2], c[3], p.chunk and 1 or a)
        if p.star then
            love.graphics.rectangle('fill', x - s / 2, y - 1, s, 2)
            love.graphics.rectangle('fill', x - 1, y - s / 2, 2, s)
        elseif p.chunk then
            love.graphics.push()
            love.graphics.translate(x, y)
            love.graphics.rotate(p.t * p.spin)
            love.graphics.rectangle('fill', -s / 2, -s / 2, s, s)
            love.graphics.setColor(0, 0, 0, 0.35)
            love.graphics.rectangle('line', -s / 2, -s / 2, s, s)
            love.graphics.pop()
        else
            love.graphics.rectangle('fill', x - s / 2, y - s / 2, s, s)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Particles.clear() list = {} end

return Particles
