-- src/fx/Particles.lua
-- Partículas visuales pixel art (solo cliente; el servidor no dibuja).
--   Particles.emit(kind, x, y, opts)   en coordenadas de mundo
--   Particles.update(dt)  /  Particles.render(camX, camY)  /  Particles.clear()
-- Tipos: 'gp_land', 'gp_start', 'block_break', 'spawn', 'oneup', 'spike_land',
--        'spike_pop', 'boss_hit', 'boss_blast', 'boss_big_blast', 'mortar_blast', 'fire_puff', 'ember',
--        'exhaust', 'smoke', 'sparks', 'shake_small', 'shake_big' (temblor de pantalla:
--        Particles.shakeOffset() se suma a la cámara al dibujar)
-- (otros nombres no hacen nada)

local Particles = {}
local list = {}
local shakeT, shakeDur, shakePow = 0, 0.35, 0     -- temblor de pantalla
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
        -- Trozos de ladrillo de tamaños y trayectorias al azar, migas y polvo
        local T = TILE_PX
        local base = opts.col or {0.55, 0.40, 0.28}   -- ladrillo (breakable.lua)
        local function shade(k)
            return { base[1] * k, base[2] * k, base[3] * k }
        end
        for i = 1, math.random(9, 13) do
            local px, py = rnd(4, T - 4), rnd(4, T - 4)
            local dir = (px < T / 2) and -1 or 1
            add({ x = x + px, y = y + py, vx = dir * rnd(40, 260) + rnd(-60, 60), vy = -rnd(180, 620),
                  g = rnd(1200, 1700), life = rnd(1.2, 2.2), size = math.random(3, 7) * 2,
                  col = shade(rnd(0.7, 1.15)), spin = rnd(-12, 12), chunk = true, fadeLast = 0.35 })
        end
        for i = 1, math.random(14, 20) do  -- migas
            add({ x = x + rnd(0, T), y = y + rnd(0, T), vx = rnd(-220, 220), vy = -rnd(80, 420),
                  g = rnd(1000, 1500), life = rnd(0.7, 1.5), size = math.random(1, 2) * 3,
                  col = shade(rnd(0.6, 1.2)) })
        end
        for i = 1, math.random(10, 16) do  -- polvo que se queda flotando
            add({ x = x + rnd(0, T), y = y + rnd(0, T), vx = rnd(-70, 70), vy = -rnd(10, 90), g = -rnd(0, 30),
                  life = rnd(0.8, 1.6), size = math.random(2, 4) * 3, col = {0.85, 0.8, 0.72}, drag = 1.5,
                  dust = true })
        end
    elseif kind == 'points' then
        -- Puntos de una zona: monedas doradas que saltan y chispas que suben
        for i = 1, 7 do
            local a = rnd(-math.pi * 0.85, -math.pi * 0.15)
            add({ x = x + rnd(-10, 10), y = y - 20, vx = math.cos(a) * rnd(60, 180), vy = math.sin(a) * rnd(160, 320),
                  g = 900, life = rnd(0.45, 0.7), size = 6, col = {1, 0.82, 0.22}, fadeLast = 0.3 })
        end
        for i = 1, 6 do
            add({ x = x + rnd(-22, 22), y = y + rnd(-10, 30), vx = rnd(-20, 20), vy = -rnd(90, 170),
                  life = rnd(0.4, 0.7), size = 4, col = {1, 0.95, 0.6}, star = (i % 2 == 0), drag = 1 })
        end
    elseif kind == 'oneup' then
        local col = {0.4, 1, 0.5}
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
        -- Se clava: tierra saltando a los lados, chispas y un poco de polvo
        for i = 1, math.random(10, 14) do
            local dir = (i % 2 == 0) and 1 or -1
            add({ x = x + dir * rnd(2, 12), y = y - rnd(0, 4), vx = dir * rnd(60, 260), vy = -rnd(120, 380),
                  g = rnd(1100, 1500), life = rnd(0.35, 0.7), size = math.random(1, 2) * 3,
                  col = ({ {0.45, 0.33, 0.22}, {0.6, 0.45, 0.3}, {0.35, 0.25, 0.17} })[math.random(3)] })
        end
        for i = 1, 5 do
            local a = rnd(-math.pi * 0.9, -math.pi * 0.1)
            add({ x = x, y = y - 4, vx = math.cos(a) * rnd(160, 320), vy = math.sin(a) * rnd(160, 320),
                  g = 600, life = rnd(0.2, 0.35), size = 5, col = {1, 1, 0.85}, star = true })
        end
        for i = 1, 6 do
            add({ x = x + rnd(-18, 18), y = y - rnd(0, 6), vx = rnd(-50, 50), vy = -rnd(10, 60), g = -20,
                  life = rnd(0.5, 0.9), size = math.random(2, 3) * 3, col = {0.85, 0.8, 0.72}, drag = 2, dust = true })
        end
    elseif kind == 'boss_hit' then
        -- Golpe al jefe: estallido de chispas blancas y rojas
        for i = 1, 14 do
            local ang = (i / 14) * math.pi * 2
            add({ x = x, y = y, vx = math.cos(ang) * rnd(160, 320), vy = math.sin(ang) * rnd(160, 320),
                  life = rnd(0.25, 0.45), size = 6, drag = 5, star = (i % 2 == 0),
                  col = (i % 3 == 0) and {1, 0.25, 0.25} or {1, 1, 1} })
        end
    elseif kind == 'boss_blast' then
        -- Explosión (secuencia de muerte de un jefe): bloques naranjas y humo
        for i = 1, 20 do
            local ang = rnd(0, math.pi * 2)
            add({ x = x, y = y, vx = math.cos(ang) * rnd(80, 340), vy = math.sin(ang) * rnd(80, 340) - 60,
                  life = rnd(0.4, 0.8), size = math.random(2, 5) * 3, drag = 3,
                  col = ({ {1, 0.9, 0.3}, {1, 0.55, 0.1}, {1, 0.25, 0.15} })[math.random(3)] })
        end
        for i = 1, 5 do
            add({ x = x + rnd(-12, 12), y = y + rnd(-12, 12), vx = rnd(-40, 40), vy = -rnd(20, 80), g = -30,
                  life = rnd(0.5, 0.9), size = math.random(3, 5) * 3, col = {0.35, 0.35, 0.4}, drag = 2, dust = true })
        end
    elseif kind == 'shake_small' or kind == 'shake_big' then
        -- Temblor de pantalla (se nota menos cuanto más lejos, como el sonido)
        local k = (Sound and Sound.falloff) and Sound.falloff(x, y) or 1
        local pow = (kind == 'shake_big' and 16 or 7) * k
        if pow > shakePow * (shakeT / shakeDur) then
            shakePow, shakeDur = pow, (kind == 'shake_big') and 0.7 or 0.3
            shakeT = shakeDur
        end
    elseif kind == 'exhaust' then
        -- Humo del motor de una nave: bocanada pálida que cae y se deshace
        add({ x = x + rnd(-6, 6), y = y, vx = rnd(-20, 20), vy = rnd(60, 140), life = rnd(0.25, 0.45),
              size = math.random(2, 3) * 3, col = {0.9, 0.9, 0.93}, drag = 3, dust = true })
    elseif kind == 'smoke' then
        -- Humo negro de algo dañado
        add({ x = x + rnd(-10, 10), y = y, vx = rnd(-25, 25), vy = -rnd(40, 90), g = -20, life = rnd(0.6, 1.1),
              size = math.random(3, 5) * 3, col = {0.2, 0.2, 0.22}, drag = 1.5, dust = true })
    elseif kind == 'sparks' then
        -- Chispas metálicas (salen los pinchos de la nave, choques...)
        for i = 1, 10 do
            local ang = rnd(0, math.pi)
            add({ x = x + rnd(-40, 40), y = y, vx = math.cos(ang) * rnd(80, 260), vy = math.sin(ang) * rnd(40, 200),
                  g = 900, life = rnd(0.2, 0.4), size = 3, col = ({ {1, 1, 0.8}, {1, 0.85, 0.3} })[math.random(2)] })
        end
    elseif kind == 'boss_big_blast' then
        -- Explosión final de una nave: gran estallido, trozos y humo
        for i = 1, 40 do
            local ang = rnd(0, math.pi * 2)
            add({ x = x, y = y, vx = math.cos(ang) * rnd(120, 620), vy = math.sin(ang) * rnd(120, 620) - 120,
                  g = 500, life = rnd(0.5, 1.1), size = math.random(2, 6) * 3, drag = 2,
                  col = ({ {1, 1, 0.6}, {1, 0.8, 0.2}, {1, 0.45, 0.1}, {1, 0.2, 0.1} })[math.random(4)] })
        end
        for i = 1, 14 do
            local ang = rnd(0, math.pi * 2)
            add({ x = x, y = y, vx = math.cos(ang) * rnd(150, 450), vy = math.sin(ang) * rnd(150, 450) - 250,
                  g = rnd(1200, 1600), life = rnd(1.0, 1.8), size = math.random(3, 6) * 2,
                  col = ({ {0.25, 0.25, 0.28}, {0.5, 0.5, 0.52}, {0.9, 0.9, 0.92} })[math.random(3)],
                  spin = rnd(-12, 12), chunk = true, fadeLast = 0.3 })
        end
        for i = 1, 16 do
            add({ x = x + rnd(-40, 40), y = y + rnd(-30, 30), vx = rnd(-60, 60), vy = -rnd(30, 120), g = -30,
                  life = rnd(1.0, 1.8), size = math.random(4, 7) * 3, col = {0.3, 0.3, 0.34}, drag = 1.5, dust = true })
        end
    elseif kind == 'mortar_blast' then
        -- Disparo del mortero: fogonazo hacia arriba y humo
        for i = 1, 10 do
            local ang = rnd(-math.pi * 0.85, -math.pi * 0.15)
            add({ x = x, y = y, vx = math.cos(ang) * rnd(80, 260), vy = math.sin(ang) * rnd(80, 260),
                  g = 300, life = rnd(0.2, 0.4), size = math.random(1, 2) * 3, drag = 3,
                  col = ({ {1, 0.9, 0.3}, {1, 0.5, 0.1} })[math.random(2)] })
        end
        for i = 1, 8 do
            add({ x = x + rnd(-10, 10), y = y - rnd(0, 8), vx = rnd(-40, 40), vy = -rnd(40, 120), g = -40,
                  life = rnd(0.5, 1.0), size = math.random(3, 5) * 3, col = {0.3, 0.3, 0.32}, drag = 2, dust = true })
        end
    elseif kind == 'fire_puff' then
        -- Fuego que se apaga: humo gris y alguna chispa
        for i = 1, 7 do
            add({ x = x + rnd(-8, 8), y = y + rnd(-6, 4), vx = rnd(-30, 30), vy = -rnd(30, 90), g = -30,
                  life = rnd(0.4, 0.8), size = math.random(2, 4) * 3, col = {0.55, 0.55, 0.58}, drag = 2, dust = true })
        end
        for i = 1, 4 do
            add({ x = x, y = y, vx = rnd(-120, 120), vy = -rnd(60, 200), g = 700, life = rnd(0.2, 0.4),
                  size = 3, col = {1, 0.6, 0.1} })
        end
    elseif kind == 'ember' then
        -- Chispa que suelta la bola de fuego al volar
        add({ x = x + rnd(-6, 6), y = y + rnd(-6, 6), vx = rnd(-20, 20), vy = -rnd(10, 50), g = -60,
              life = rnd(0.25, 0.5), size = 3, col = ({ {1, 0.85, 0.2}, {1, 0.45, 0.05} })[math.random(2)] })
    elseif kind == 'spike_pop' then
        -- El Crabby arranca su pincho del suelo: tierra hacia arriba
        for i = 1, 12 do
            add({ x = x + rnd(-10, 10), y = y, vx = rnd(-160, 160), vy = -rnd(200, 460), g = 1300,
                  life = rnd(0.4, 0.8), size = math.random(1, 2) * 3,
                  col = ({ {0.45, 0.33, 0.22}, {0.6, 0.45, 0.3} })[math.random(2)] })
        end
    end
end

-- Desplazamiento de cámara del temblor actual (sumar a camX/camY al dibujar)
function Particles.shakeOffset()
    if shakeT <= 0 then return 0, 0 end
    local k = shakePow * (shakeT / shakeDur)
    return math.floor((math.random() * 2 - 1) * k + 0.5), math.floor((math.random() * 2 - 1) * k + 0.5)
end

function Particles.update(dt)
    if shakeT > 0 then shakeT = math.max(0, shakeT - dt) end
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
        if p.chunk then
            -- Los trozos se ven enteros y se desvanecen solo al final
            local f = p.fadeLast or 0
            a = (f > 0) and math.min(1, (1 - p.t / p.life) / f) or 1
        elseif p.dust then
            a = a * 0.55
        end
        love.graphics.setColor(c[1], c[2], c[3], a)
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

function Particles.clear() list = {}; shakeT = 0 end

return Particles
