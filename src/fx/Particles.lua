-- src/fx/Particles.lua
-- Partículas visuales pixel art (solo cliente; el servidor no dibuja).
--   Particles.emit(kind, x, y, opts)   en coordenadas de mundo
--   Particles.update(dt)  /  Particles.render(camX, camY)  /  Particles.clear()
-- Tipos: 'gp_land', 'gp_start', 'block_break', 'spawn', 'oneup', 'spike_land',
--        'spike_pop', 'boss_hit', 'boss_blast', 'boss_big_blast', 'mortar_blast', 'fire_puff', 'ember',
--        'exhaust', 'smoke', 'sparks', 'mega_step', 'mega_trail', 'mega_debris', 'mega_dirt',
--        'mega_slam', 'mega_land', 'mega_poof', 'mega_roar' (Mega Crabby), 'switch_hit' (bloque ON/OFF),
--        'helmet_break' (casco de Gummy), 'puffer_pop' (pez globo), 'cryo_puff' / 'cryo_mist' /
--        'cryo_blast' (congelador), 'ice_freeze' / 'ice_shatter' (bloque de hielo de lo congelado),
--        'shake_small', 'shake_big', 'shake_roar' (suave y largo) (temblor de pantalla:
--        Particles.shakeOffset() se suma a la cámara al dibujar)
-- (otros nombres no hacen nada)
--
-- Partículas FÍSICAS (`phys`: trozos, tierra, piedrecitas): chocan con el
-- nivel (Particles.setLevel), rebotan, se quedan en el suelo y en el agua
-- caen despacio. Las de impacto toman los colores del bloque golpeado
-- (TileTypes.debris: piedra gris, madera, tierra, césped...): se mira el
-- tile que hay junto al punto, o opts.def si quien las emite lo sabe.

local TileTypes = require 'src/world/tiles/TileTypes'

local Particles = {}
local level                                       -- nivel actual (choques)
function Particles.setLevel(l) level = l end
local list = {}
local shakeT, shakeDur, shakePow = 0, 0.35, 0     -- temblor de pantalla
local MAX  = 600

local function add(p)
    if #list >= MAX then table.remove(list, 1) end
    p.t = 0
    list[#list + 1] = p
end

local function rnd(a, b) return a + math.random() * (b - a) end

-- Señal de un Activador ON/OFF (x, y = esquina de su casilla): un reguero de chispas
-- corre hasta todo lo que controla (sus Bloques ON/OFF y los objetos conectados:
-- congeladores, inundaciones...), para que se vea qué hace cada Activador. Solo dibujo.
local SIGNAL_SPEED = 900
function Particles.signal(x, y)
    if not level then return end
    local T = TILE_PX
    local c, r = math.floor(x / T + 0.5) + 1, math.floor(y / T + 0.5) + 1
    local sx, sy = (c - 0.5) * T, (r - 0.5) * T
    local targets = {}
    for _, b in ipairs(level.switchBlocks or {}) do
        if b.src and b.src[1] == c and b.src[2] == r then targets[#targets + 1] = { (b.c - 0.5) * T, (b.r - 0.5) * T } end
    end
    for _, l in ipairs(level.links or {}) do
        if l.col == c and l.row == r then
            for _, e in ipairs(level.entities or {}) do
                local pr = e.props
                -- (solo lo que escucha a su Activador: congelador en modo Activador, inundación 'switch'...)
                if pr and pr.id == l.to and (pr.mode == nil or pr.mode == 'switch')
                   and (pr.control == nil or pr.control == 'switch') then
                    targets[#targets + 1] = { (e.col - 0.5) * T, (e.row - 0.5) * T }
                end
            end
        end
    end
    for _, tg in ipairs(targets) do
        local d = math.sqrt((tg[1] - sx) ^ 2 + (tg[2] - sy) ^ 2)
        if d > 1 then
            for i = 1, 9 do
                local v = SIGNAL_SPEED * (0.55 + i * 0.05)
                add({ implode = true, sx = sx, sy = sy, tx = tg[1], ty = tg[2], x = sx, y = sy,
                      life = d / v, size = (i % 3 == 0) and 6 or 4,
                      col = (i % 2 == 0) and { 1, 0.95, 0.45 } or { 1, 1, 0.9 } })
            end
        end
    end
end

-- ── Colores del material golpeado ────────────────────────────────────────────
local FALLBACK = { { 0.45, 0.33, 0.22 }, { 0.6, 0.45, 0.3 }, { 0.35, 0.25, 0.17 } }   -- tierra
-- Dónde buscar el bloque: debajo (suelo), encima (techo) y a los lados (paredes)
local PROBES = { { 0, 6 }, { 0, 16 }, { 0, -6 }, { -10, 0 }, { 10, 0 }, { 0, -16 }, { -20, 6 }, { 20, 6 } }
local function surfaceDef(x, y)
    if not level then return nil end
    for _, d in ipairs(PROBES) do
        local t = level:getDefAt(x + d[1], y + d[2])
        if t.collision ~= 'none' then return t end
    end
    return nil
end
-- Sólido (tile) en el punto, o nil
local function solidDef(x, y)
    local t = level:getDefAt(x, y)
    return t.collision ~= 'none' and t or nil
end
-- Superficie conocida su normal (nx, ny: hacia fuera): se busca el bloque
-- hacia dentro; si no hay (el borde invisible de una zona de jefe), el suelo
-- que haya debajo (lo más parecido a "de qué está hecho esto")
local function surfaceDefN(x, y, nx, ny)
    if not level then return nil end
    for d = 4, 48, 8 do
        local t = solidDef(x - nx * d, y - ny * d)
        if t then return t end
    end
    local t = surfaceDef(x, y)
    if t then return t end
    for d = 16, 20 * TILE_PX, 16 do
        t = solidDef(x, y + d)
        if t then return t end
    end
    return nil
end
local function paletteAt(x, y, opts)
    local t = opts.def or (opts.nx and surfaceDefN(x, y, opts.nx, opts.ny)) or surfaceDef(x, y)
    return t and TileTypes.debris(t) or FALLBACK
end
Particles.paletteAt = function(x, y, def) return paletteAt(x, y, { def = def }) end
local function pick(pal, k)
    local c = pal[math.random(#pal)]
    k = k or 1
    return { math.min(1, c[1] * k), math.min(1, c[2] * k), math.min(1, c[3] * k) }
end
-- Polvo: el color del material, muy aclarado
local function dustOf(pal)
    local c = pal[1]
    return { 0.5 + c[1] * 0.42, 0.48 + c[2] * 0.42, 0.44 + c[3] * 0.42 }
end

function Particles.emit(kind, x, y, opts)
    opts = opts or {}
    if kind == 'gp_land' then
        local pal = paletteAt(x, y, opts)
        local dust = dustOf(pal)
        for i = 1, 16 do                 -- polvo hacia los lados (del color del suelo)
            local dir = (i % 2 == 0) and 1 or -1
            add({ x = x + dir * rnd(4, 20), y = y - rnd(0, 6), vx = dir * rnd(120, 380), vy = -rnd(40, 220),
                  g = 700, life = rnd(0.35, 0.6), size = math.random(2, 3) * 3, col = dust, drag = 3 })
        end
        for i = 1, 5 do                  -- migas del suelo
            add({ x = x + rnd(-14, 14), y = y - 3, vx = rnd(-200, 200), vy = -rnd(160, 340), g = 1400,
                  life = rnd(0.6, 1.0), size = 3, col = pick(pal), phys = true, fadeLast = 0.3 })
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
        -- (x, y = esquina de la casilla; el material es el del bloque que había)
        local T = TILE_PX
        local def = opts.def or (level and level.previousDef and level:previousDef(math.floor(x / T) + 1, math.floor(y / T) + 1))
        local pal = TileTypes.debris(def or TileTypes.byName.breakable)
        for i = 1, math.random(9, 13) do
            local px, py = rnd(4, T - 4), rnd(4, T - 4)
            local dir = (px < T / 2) and -1 or 1
            add({ x = x + px, y = y + py, vx = dir * rnd(40, 260) + rnd(-60, 60), vy = -rnd(180, 620),
                  g = rnd(1200, 1700), life = rnd(1.6, 2.6), size = math.random(3, 7) * 2,
                  col = pick(pal, rnd(0.8, 1.1)), spin = rnd(-12, 12), chunk = true, fadeLast = 0.35,
                  phys = true, bounce = 0.3 })
        end
        for i = 1, math.random(14, 20) do  -- migas
            add({ x = x + rnd(0, T), y = y + rnd(0, T), vx = rnd(-220, 220), vy = -rnd(80, 420),
                  g = rnd(1000, 1500), life = rnd(0.9, 1.7), size = math.random(1, 2) * 3,
                  col = pick(pal, rnd(0.7, 1.15)), phys = true, fadeLast = 0.3 })
        end
        for i = 1, math.random(10, 16) do  -- polvo que se queda flotando
            add({ x = x + rnd(0, T), y = y + rnd(0, T), vx = rnd(-70, 70), vy = -rnd(10, 90), g = -rnd(0, 30),
                  life = rnd(0.8, 1.6), size = math.random(2, 4) * 3, col = dustOf(pal), drag = 1.5,
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
        -- Se clava: trozos del suelo saltando a los lados, chispas y un poco de polvo
        local pal = paletteAt(x, y, opts)
        for i = 1, math.random(10, 14) do
            local dir = (i % 2 == 0) and 1 or -1
            add({ x = x + dir * rnd(2, 12), y = y - rnd(0, 4), vx = dir * rnd(60, 260), vy = -rnd(120, 380),
                  g = rnd(1100, 1500), life = rnd(0.6, 1.1), size = math.random(1, 2) * 3,
                  col = pick(pal), phys = true, fadeLast = 0.3 })
        end
        for i = 1, 5 do
            local a = rnd(-math.pi * 0.9, -math.pi * 0.1)
            add({ x = x, y = y - 4, vx = math.cos(a) * rnd(160, 320), vy = math.sin(a) * rnd(160, 320),
                  g = 600, life = rnd(0.2, 0.35), size = 5, col = {1, 1, 0.85}, star = true })
        end
        for i = 1, 6 do
            add({ x = x + rnd(-18, 18), y = y - rnd(0, 6), vx = rnd(-50, 50), vy = -rnd(10, 60), g = -20,
                  life = rnd(0.5, 0.9), size = math.random(2, 3) * 3, col = dustOf(pal), drag = 2, dust = true })
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
    elseif kind == 'switch_hit' then
        -- Bloque ON/OFF golpeado (x, y = esquina de la casilla): chispitas
        -- desde arriba y abajo del bloque y un aro blanco
        local T = TILE_PX
        for i = 1, 12 do
            local top = i % 2 == 0
            add({ x = x + rnd(6, T - 6), y = y + (top and 0 or T), vx = rnd(-160, 160),
                  vy = top and -rnd(120, 320) or rnd(60, 200), g = 900, life = rnd(0.25, 0.45),
                  size = math.random(1, 2) * 3, col = ({ {1, 1, 0.85}, {1, 0.9, 0.4} })[math.random(2)] })
        end
        for i = 1, 12 do
            local a = (i / 12) * math.pi * 2
            add({ x = x + T / 2 + math.cos(a) * 20, y = y + T / 2 + math.sin(a) * 20,
                  vx = math.cos(a) * 180, vy = math.sin(a) * 180, life = 0.2, size = 4, col = {1, 1, 1}, drag = 6 })
        end
        Particles.signal(x, y)
    elseif kind == 'puffer_pop' then
        -- Pez globo que se hincha del todo: aro de burbujas que sale
        for i = 1, 14 do
            local a = (i / 14) * math.pi * 2
            add({ x = x + math.cos(a) * 26, y = y + math.sin(a) * 26, vx = math.cos(a) * rnd(90, 170),
                  vy = math.sin(a) * rnd(90, 170) - 30, life = rnd(0.35, 0.6), size = math.random(1, 2) * 3,
                  col = { 0.8, 0.95, 1 }, drag = 4 })
        end
    elseif kind == 'helmet_break' then
        -- Casco de Gummy que se rompe: trozos negros y grises que saltan
        for i = 1, 9 do
            local dir = (i % 2 == 0) and 1 or -1
            add({ x = x + rnd(-20, 20), y = y + rnd(-6, 6), vx = dir * rnd(80, 280), vy = -rnd(200, 460),
                  g = 1500, life = rnd(0.6, 1.0), size = math.random(2, 4) * 3,
                  col = ({ {0.08, 0.08, 0.08}, {0.17, 0.17, 0.17}, {1, 1, 1} })[math.random(3)],
                  spin = rnd(-12, 12), chunk = true, fadeLast = 0.3, phys = true, bounce = 0.4 })
        end
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
                  spin = rnd(-12, 12), chunk = true, fadeLast = 0.3, phys = true, bounce = 0.35 })
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
    -- ── Mega Crabby (un cangrejo colosal: polvo y tierra a lo grande) ─────────
    elseif kind == 'mega_step' then
        -- Pisada: polvo bajo y alguna piedrecita (del suelo que pisa)
        local pal = paletteAt(x, y, opts)
        for i = 1, 5 do
            add({ x = x + rnd(-14, 14), y = y - rnd(0, 4), vx = rnd(-130, 130), vy = -rnd(20, 70), g = -10,
                  life = rnd(0.35, 0.6), size = math.random(3, 5) * 3, col = dustOf(pal), drag = 4, dust = true })
        end
        for i = 1, 3 do
            add({ x = x + rnd(-10, 10), y = y - 2, vx = rnd(-120, 120), vy = -rnd(120, 260), g = 1300,
                  life = rnd(0.5, 0.8), size = 3, col = pick(pal), phys = true, fadeLast = 0.25 })
        end
    elseif kind == 'mega_trail' then
        -- Estela de la embestida (opts.dir = hacia dónde va): polvo del suelo
        local dir = opts.dir or 1
        local dust = dustOf(paletteAt(x, y, opts))
        for i = 1, 2 do
            add({ x = x + rnd(-8, 8), y = y - rnd(0, 8), vx = -dir * rnd(40, 140), vy = -rnd(20, 70), g = -10,
                  life = rnd(0.3, 0.55), size = math.random(2, 4) * 3, col = dust, drag = 3, dust = true })
        end
    elseif kind == 'mega_debris' then
        -- Piedrecitas que suelta al trepar por paredes y techo (de lo que pisa).
        -- opts.nx, ny = normal de la superficie: nacen fuera del bloque,
        -- repartidas a lo largo de ella, y se despegan hacia fuera
        local pal = paletteAt(x, y, opts)
        local nx, ny = opts.nx or 0, opts.ny or -1
        for i = 1, 3 do
            local k, out = rnd(-16, 16), rnd(8, 14)
            add({ x = x + nx * out - ny * k, y = y + ny * out + nx * k,
                  vx = nx * rnd(40, 120) + rnd(-40, 40), vy = ny * rnd(20, 80) + rnd(0, 60), g = 1200,
                  life = rnd(0.9, 1.4), size = math.random(1, 2) * 3,
                  col = pick(pal), phys = true, fadeLast = 0.3 })
        end
    elseif kind == 'mega_dirt' then
        -- Forcejeando clavado: trozos del suelo que saltan del agujero
        local pal = paletteAt(x, y, opts)
        for i = 1, 4 do
            add({ x = x + rnd(-12, 12), y = y - 2, vx = rnd(-170, 170), vy = -rnd(160, 380), g = 1400,
                  life = rnd(0.6, 1.0), size = math.random(1, 2) * 3,
                  col = pick(pal), phys = true, fadeLast = 0.3 })
        end
    elseif kind == 'mega_slam' then
        -- Se clava cayendo del techo: trozos del suelo, un muro de polvo y estrellas
        local pal = paletteAt(x, y, opts)
        for i = 1, math.random(16, 22) do
            local dir = (i % 2 == 0) and 1 or -1
            add({ x = x + dir * rnd(4, 30), y = y - rnd(2, 10), vx = dir * rnd(90, 480), vy = -rnd(260, 720),
                  g = rnd(1300, 1700), life = rnd(1.4, 2.2), size = math.random(2, 5) * 3,
                  col = pick(pal, rnd(0.85, 1.1)), spin = rnd(-12, 12), chunk = true, fadeLast = 0.3,
                  phys = true, bounce = 0.3 })
        end
        for i = 1, 18 do
            local dir = (i % 2 == 0) and 1 or -1
            add({ x = x + dir * rnd(0, 40), y = y - rnd(0, 14), vx = dir * rnd(150, 520), vy = -rnd(20, 140), g = -15,
                  life = rnd(0.6, 1.1), size = math.random(4, 7) * 3, col = dustOf(pal), drag = 3, dust = true })
        end
        for i = 1, 8 do
            local a = rnd(-math.pi * 0.95, -math.pi * 0.05)
            add({ x = x, y = y - 10, vx = math.cos(a) * rnd(200, 420), vy = math.sin(a) * rnd(200, 420),
                  g = 600, life = rnd(0.35, 0.6), size = 7, col = {1, 0.95, 0.5}, star = true })
        end
    elseif kind == 'mega_land' then
        -- Aterriza tras el salto: onda de polvo que barre el suelo a los lados
        local pal = paletteAt(x, y, opts)
        local dust = dustOf(pal)
        for i = 1, 28 do
            local dir = (i % 2 == 0) and 1 or -1
            add({ x = x + dir * rnd(0, 40), y = y - rnd(0, 8), vx = dir * rnd(260, 720), vy = -rnd(10, 90), g = -10,
                  life = rnd(0.4, 0.8), size = math.random(3, 6) * 3, col = dust, drag = 4, dust = true })
        end
        for i = 1, 10 do
            add({ x = x + rnd(-40, 40), y = y - 3, vx = rnd(-260, 260), vy = -rnd(160, 380), g = 1300,
                  life = rnd(0.7, 1.1), size = math.random(1, 2) * 3, col = pick(pal), phys = true, fadeLast = 0.3 })
        end
    elseif kind == 'mega_poof' then
        -- Se desinfla: nube grande de humo claro y destellos
        for i = 1, 26 do
            local a = rnd(0, math.pi * 2)
            add({ x = x + math.cos(a) * rnd(0, 40), y = y + math.sin(a) * rnd(0, 30),
                  vx = math.cos(a) * rnd(80, 300), vy = math.sin(a) * rnd(80, 300) - 40, g = -20,
                  life = rnd(0.7, 1.2), size = math.random(4, 8) * 3,
                  col = ({ {0.95, 0.95, 0.97}, {0.8, 0.8, 0.84}, {0.65, 0.65, 0.7} })[math.random(3)], drag = 3, dust = true })
        end
        for i = 1, 10 do
            local a = rnd(0, math.pi * 2)
            add({ x = x, y = y, vx = math.cos(a) * rnd(150, 340), vy = math.sin(a) * rnd(150, 340),
                  g = 300, life = rnd(0.4, 0.7), size = 6, col = {1, 1, 0.8}, star = true })
        end
    elseif kind == 'mega_roar' then
        -- Rugido: ondas de choque de píxeles que se abren (achatadas) y rayos
        -- en zigzag que saltan alrededor, parpadeando; unas gotas de espuma
        for ring = 1, 2 do
            add({ x = x, y = y, vx = 0, vy = 0, shock = true, r0 = 60 + ring * 10, r1 = 230 + ring * 90,
                  ph1 = rnd(0, 6.3), ph2 = rnd(0, 6.3), wob = rnd(0.05, 0.09),
                  life = 0.32 + ring * 0.1 + (ring - 1) * 0.08, delay = (ring - 1) * 0.08, size = (ring == 1) and 10 or 8,
                  col = (ring == 1) and {1, 0.97, 0.8} or {1, 0.78, 0.35} })
        end
        local nb = math.random(5, 7)
        for i = 1, nb do
            local a = (i + rnd(-0.3, 0.3)) / nb * math.pi * 2
            -- Onda de choque en zigzag IRREGULAR: pocos tramos largos con
            -- quiebros bruscos y desiguales (a veces dos hacia el mismo lado),
            -- gruesa en la raíz y afilada en la punta; a veces una grieta
            -- lateral. (Antes: muchos zigzags pequeños iguales = parecían curvas)
            local ca, sa = math.cos(a), math.sin(a)
            local qx, qy = -sa, ca                               -- (perpendicular)
            local function P(r, lat) return x + ca * r + qx * lat, y + (sa * r + qy * lat) * 0.75 end
            local pts, r, lat = {}, rnd(78, 96), rnd(-4, 4)
            local ax, ay = P(r, lat)
            pts[1], pts[2] = ax, ay
            local side = (math.random() < 0.5) and 1 or -1
            for s = 1, math.random(3, 5) do
                r = r + rnd(22, 46)
                if math.random() < 0.75 then side = -side end
                lat = side * rnd(6, 30)
                local bx, by = P(r, lat)
                pts[#pts + 1], pts[#pts + 2] = bx, by
            end
            local forks
            if math.random() < 0.6 and #pts >= 6 then
                -- (grieta: sale de un quiebro intermedio, en ángulo, 1-2 tramos)
                local k = math.random(2, #pts / 2 - 1) * 2 - 1
                local fa = a + ((math.random() < 0.5) and -1 or 1) * rnd(0.5, 0.9)
                local fx, fy = pts[k], pts[k + 1]
                local f = { fx, fy }
                for _ = 1, math.random(1, 2) do
                    local l = rnd(16, 30)
                    fx, fy = fx + math.cos(fa) * l, fy + math.sin(fa) * l * 0.75
                    fa = fa + rnd(-0.6, 0.6)
                    f[#f + 1], f[#f + 2] = fx, fy
                end
                forks = { f }
            end
            local delay = rnd(0, 0.12)
            add({ x = x, y = y, vx = 0, vy = 0, bolt = pts, forks = forks, life = delay + rnd(0.16, 0.3), delay = delay,
                  size = 6, col = ({ {0.96, 0.91, 0.8}, {0.85, 0.74, 0.57}, {0.9, 0.82, 0.68} })[math.random(3)],
                  edge = {0.24, 0.16, 0.1, 0.85} })          -- (hueso / arena: nada de "eléctrico")
        end
        for i = 1, 6 do
            add({ x = x + rnd(-20, 20), y = y + rnd(-10, 10), vx = rnd(-200, 200), vy = -rnd(60, 240), g = 900,
                  life = rnd(0.4, 0.7), size = 3, col = {0.85, 0.95, 1} })
        end
    elseif kind == 'ice_crack' then
        -- Hielo fino que se agrieta: esquirlas pequeñas y un destello
        for i = 1, 8 do
            add({ x = x + rnd(-24, 24), y = y + rnd(-6, 6), vx = rnd(-120, 120), vy = -rnd(60, 220), g = 1100,
                  life = rnd(0.35, 0.6), size = math.random(1, 2) * 2, chunk = true, spin = rnd(-12, 12), fadeLast = 0.3,
                  col = ({ {0.9, 0.96, 1}, {0.7, 0.82, 1}, {1, 1, 1} })[math.random(3)] })
        end
        for i = 1, 3 do
            add({ x = x + rnd(-20, 20), y = y + rnd(-8, 8), vx = 0, vy = 0, life = rnd(0.15, 0.3), size = 8,
                  star = true, col = {1, 1, 1} })
        end
    elseif kind == 'ice_break' then
        -- Hielo fino que se rompe: trozos de hielo que caen y rebotan (físicos),
        -- polvo de escarcha y destellos
        for i = 1, 22 do
            add({ x = x + rnd(-30, 30), y = y + rnd(-10, 10), vx = rnd(-200, 200), vy = rnd(-320, 40), g = 1300,
                  life = rnd(0.7, 1.2), size = math.random(2, 4) * 2, chunk = true, spin = rnd(-16, 16), fadeLast = 0.35,
                  phys = true, col = ({ {0.9, 0.96, 1}, {0.68, 0.8, 1}, {0.55, 0.7, 0.98}, {1, 1, 1} })[math.random(4)] })
        end
        for i = 1, 10 do
            add({ x = x + rnd(-30, 30), y = y + rnd(-8, 8), vx = rnd(-40, 40), vy = rnd(-60, 10), g = -20,
                  life = rnd(0.5, 0.9), size = math.random(2, 4) * 2, col = {0.92, 0.96, 1}, drag = 2, dust = true })
        end
        for i = 1, 5 do
            add({ x = x + rnd(-28, 28), y = y + rnd(-10, 10), vx = 0, vy = 0, life = rnd(0.2, 0.4), size = 10,
                  star = true, col = {1, 1, 1} })
        end
    elseif kind == 'snow_puff' then
        -- Nieve que salta (aterrizajes, bolas que se estampan): polvo blanco y grumos
        for i = 1, 10 do
            add({ x = x + rnd(-20, 20), y = y - rnd(0, 10), vx = rnd(-220, 220), vy = -rnd(60, 260), g = 700, drag = 3,
                  life = rnd(0.35, 0.7), size = math.random(2, 4) * 2, dust = true,
                  col = ({ {1, 1, 1}, {0.88, 0.92, 1}, {0.78, 0.84, 0.96} })[math.random(3)] })
        end
        for i = 1, 5 do
            add({ x = x + rnd(-14, 14), y = y - 4, vx = rnd(-240, 240), vy = -rnd(160, 380), g = 1400,
                  life = rnd(0.5, 0.9), size = math.random(1, 2) * 3, chunk = true, phys = true, fadeLast = 0.3,
                  col = ({ {0.96, 0.98, 1}, {0.82, 0.88, 0.98} })[math.random(2)] })
        end
    elseif kind == 'snow_trail' then
        -- Rodando: polvo de nieve que levanta
        for i = 1, 2 do
            add({ x = x + rnd(-10, 10), y = y - rnd(0, 6), vx = rnd(-60, 60), vy = -rnd(30, 140), g = 500, drag = 2.5,
                  life = rnd(0.3, 0.6), size = math.random(2, 3) * 2, dust = true,
                  col = ({ {1, 1, 1}, {0.86, 0.9, 1} })[math.random(2)] })
        end
    elseif kind == 'snow_slam' then
        -- El gran golpe de la Bola de Nieve: anillo, nube ancha y grumos
        add({ x = x, y = y - 10, vx = 0, vy = 0, shock = true, r0 = 30, r1 = 230, life = 0.4, size = 10,
              col = {0.95, 0.98, 1} })
        for i = 1, 26 do
            local dir = (i % 2 == 0) and 1 or -1
            add({ x = x + dir * rnd(10, 60), y = y - rnd(0, 14), vx = dir * rnd(160, 520), vy = -rnd(60, 300), g = 600,
                  drag = 2.5, life = rnd(0.5, 1.0), size = math.random(2, 5) * 2, dust = true,
                  col = ({ {1, 1, 1}, {0.88, 0.92, 1}, {0.76, 0.82, 0.96} })[math.random(3)] })
        end
        for i = 1, 12 do
            add({ x = x + rnd(-40, 40), y = y - 6, vx = rnd(-320, 320), vy = -rnd(200, 520), g = 1400,
                  life = rnd(0.6, 1.1), size = math.random(2, 3) * 3, chunk = true, phys = true, fadeLast = 0.3,
                  spin = rnd(-10, 10), col = ({ {0.96, 0.98, 1}, {0.8, 0.86, 0.98} })[math.random(2)] })
        end
    elseif kind == 'snow_crash' then
        -- Choca rodando contra algo: nieve y esquirlas de hielo hacia atrás
        for i = 1, 14 do
            add({ x = x + rnd(-8, 8), y = y + rnd(-40, 40), vx = rnd(-300, 300), vy = -rnd(80, 360), g = 1100, drag = 1.5,
                  life = rnd(0.4, 0.8), size = math.random(2, 4) * 2, chunk = (i % 3 == 0), phys = (i % 3 == 0), fadeLast = 0.3,
                  dust = (i % 3 ~= 0), col = ({ {1, 1, 1}, {0.7, 0.85, 1}, {0.88, 0.92, 1} })[math.random(3)] })
        end
        for i = 1, 3 do
            add({ x = x + rnd(-10, 10), y = y + rnd(-30, 30), vx = 0, vy = 0, life = rnd(0.15, 0.3), size = 10,
                  star = true, col = {1, 1, 1} })
        end
    elseif kind == 'snow_burst' then
        -- La Bola de Nieve revienta: gran nube, grumos que se quedan en el suelo
        add({ x = x, y = y, vx = 0, vy = 0, shock = true, r0 = 40, r1 = 260, life = 0.45, size = 12,
              col = {1, 1, 1} })
        for i = 1, 40 do
            local a = rnd(0, math.pi * 2)
            local s = rnd(80, 520)
            add({ x = x + math.cos(a) * 30, y = y + math.sin(a) * 30, vx = math.cos(a) * s, vy = math.sin(a) * s - 120,
                  g = 500, drag = 2, life = rnd(0.6, 1.3), size = math.random(3, 6) * 2, dust = true,
                  col = ({ {1, 1, 1}, {0.9, 0.93, 1}, {0.78, 0.84, 0.96} })[math.random(3)] })
        end
        for i = 1, 24 do
            add({ x = x + rnd(-50, 50), y = y + rnd(-50, 40), vx = rnd(-420, 420), vy = -rnd(200, 640), g = 1400,
                  life = rnd(1.2, 2.2), size = math.random(2, 4) * 3, chunk = true, phys = true, fadeLast = 0.4,
                  spin = rnd(-10, 10), col = ({ {0.97, 0.98, 1}, {0.84, 0.89, 0.98}, {0.7, 0.78, 0.94} })[math.random(3)] })
        end
    elseif kind == 'snow_drip' then
        -- Bola de Nieve empapada: gotas de agua que caen de ella
        add({ x = x + rnd(-4, 4), y = y, vx = rnd(-20, 20), vy = rnd(20, 80), g = 1200,
              life = rnd(0.35, 0.6), size = math.random(1, 2) * 2,
              col = ({ {0.55, 0.78, 1}, {0.75, 0.9, 1} })[math.random(2)] })
    elseif kind == 'snow_shed' then
        -- Bola de Nieve encogiendo (cambio de fase): se le caen trozos de nieve
        for i = 1, 16 do
            local a = rnd(0, math.pi * 2)
            add({ x = x + math.cos(a) * rnd(30, 70), y = y + math.sin(a) * rnd(30, 70), vx = math.cos(a) * rnd(80, 300),
                  vy = -rnd(120, 420), g = 1400, life = rnd(0.7, 1.3), size = math.random(2, 4) * 3, chunk = true,
                  phys = true, fadeLast = 0.4, spin = rnd(-10, 10),
                  col = ({ {0.97, 0.98, 1}, {0.84, 0.89, 0.98}, {0.72, 0.8, 0.95} })[math.random(3)] })
        end
        for i = 1, 10 do
            add({ x = x + rnd(-50, 50), y = y + rnd(-40, 40), vx = rnd(-80, 80), vy = -rnd(20, 120), g = 200, drag = 2,
                  life = rnd(0.4, 0.8), size = math.random(2, 4) * 2, dust = true, col = {1, 1, 1} })
        end
    elseif kind == 'frost_breath' then
        -- Aliento helado (cambio de fase): nube fría alrededor
        for i = 1, 24 do
            local a = rnd(0, math.pi * 2)
            local s = rnd(60, 260)
            add({ x = x, y = y, vx = math.cos(a) * s, vy = math.sin(a) * s * 0.5, g = -20, drag = 2,
                  life = rnd(0.6, 1.1), size = math.random(2, 4) * 2, dust = true,
                  col = ({ {0.9, 0.97, 1}, {0.7, 0.88, 1} })[math.random(2)] })
        end
    elseif kind == 'cryo_puff' then
        -- Congelador cargando: bocanadas de escarcha por la boquilla (opts.nx, ny = hacia dónde mira)
        local nx, ny = (opts and opts.nx) or 1, (opts and opts.ny) or 0
        for i = 1, 2 do
            add({ x = x + rnd(-4, 4), y = y + rnd(-4, 4), vx = nx * rnd(20, 70) + rnd(-25, 25), vy = ny * rnd(20, 70) - rnd(10, 40),
                  g = -30, drag = 2.5, life = rnd(0.35, 0.6), size = math.random(2, 3) * 2, dust = true,
                  col = ({ {0.9, 0.97, 1}, {0.75, 0.9, 1} })[math.random(2)] })
        end
    elseif kind == 'cryo_mist' then
        -- Bruma helada que suelta el chorro al pasar (cae y se deshace)
        add({ x = x + rnd(-6, 6), y = y + rnd(-6, 6), vx = rnd(-30, 30), vy = rnd(10, 60), g = 40, drag = 1.5,
              life = rnd(0.4, 0.8), size = math.random(2, 4) * 2, dust = true,
              col = ({ {0.92, 0.98, 1}, {0.7, 0.88, 1}, {1, 1, 1} })[math.random(3)] })
        if math.random() < 0.3 then
            add({ x = x + rnd(-8, 8), y = y + rnd(-8, 8), vx = 0, vy = 0, life = rnd(0.12, 0.25), size = 6,
                  star = true, col = {1, 1, 1} })
        end
    elseif kind == 'cryo_blast' then
        -- Disparo del congelador: nube de vapor helado en la boquilla
        local nx, ny = (opts and opts.nx) or 1, (opts and opts.ny) or 0
        for i = 1, 12 do
            local s = rnd(60, 260)
            add({ x = x, y = y, vx = nx * s + rnd(-80, 80), vy = ny * s + rnd(-80, 80), drag = 4, g = -20,
                  life = rnd(0.35, 0.7), size = math.random(2, 4) * 2, dust = true,
                  col = ({ {0.95, 0.99, 1}, {0.75, 0.9, 1} })[math.random(2)] })
        end
    elseif kind == 'ice_freeze' then
        -- Algo queda congelado: esquirlas que se cierran hacia el centro, destellos
        for i = 1, 14 do
            local a = rnd(0, math.pi * 2)
            local r = rnd(40, 70)
            add({ x = x + math.cos(a) * r, y = y + math.sin(a) * r, vx = -math.cos(a) * r * 4, vy = -math.sin(a) * r * 4,
                  life = 0.25, size = math.random(1, 2) * 2, fadeLast = 0.1,
                  col = ({ {0.9, 0.97, 1}, {0.65, 0.85, 1}, {1, 1, 1} })[math.random(3)] })
        end
        for i = 1, 4 do
            add({ x = x + rnd(-30, 30), y = y + rnd(-30, 30), vx = 0, vy = 0, life = rnd(0.2, 0.45), size = 10,
                  star = true, col = {1, 1, 1} })
        end
        for i = 1, 6 do
            add({ x = x + rnd(-30, 30), y = y + rnd(-20, 20), vx = rnd(-30, 30), vy = rnd(-40, 0), g = -10, drag = 2,
                  life = rnd(0.4, 0.7), size = math.random(2, 3) * 2, dust = true, col = {0.9, 0.97, 1} })
        end
    elseif kind == 'ice_shatter' then
        -- Se rompe el bloque de hielo de algo congelado: trozos que rebotan (físicos),
        -- escarcha y destellos
        for i = 1, 20 do
            add({ x = x + rnd(-30, 30), y = y + rnd(-34, 30), vx = rnd(-260, 260), vy = rnd(-420, -60), g = 1300,
                  life = rnd(0.6, 1.1), size = math.random(2, 4) * 2, chunk = true, spin = rnd(-16, 16), fadeLast = 0.35,
                  phys = true, col = ({ {0.9, 0.96, 1}, {0.68, 0.84, 1}, {0.55, 0.75, 1}, {1, 1, 1} })[math.random(4)] })
        end
        for i = 1, 10 do
            add({ x = x + rnd(-30, 30), y = y + rnd(-30, 30), vx = rnd(-60, 60), vy = rnd(-80, 0), g = -20, drag = 2,
                  life = rnd(0.5, 0.9), size = math.random(2, 4) * 2, col = {0.92, 0.97, 1}, dust = true })
        end
        for i = 1, 5 do
            add({ x = x + rnd(-30, 30), y = y + rnd(-30, 30), vx = 0, vy = 0, life = rnd(0.2, 0.4), size = 10,
                  star = true, col = {1, 1, 1} })
        end
    elseif kind == 'fuse_spark' then
        -- Chispas de la mecha encendida (saltan hacia arriba y se apagan)
        for i = 1, 2 do
            add({ x = x, y = y, vx = rnd(-80, 80), vy = -rnd(60, 200), g = 500, life = rnd(0.15, 0.35),
                  size = math.random(1, 2) * 2, col = ({ {1, 0.95, 0.6}, {1, 0.7, 0.2}, {1, 0.4, 0.1} })[math.random(3)] })
        end
    elseif kind == 'bomb_blast' then
        -- Explosión de una bomba (el sprite lo dibuja la bomba): onda, cascotes
        -- ardientes, chispas y humo
        add({ x = x, y = y, vx = 0, vy = 0, shock = true, r0 = 20, r1 = 190, life = 0.35, size = 10,
              col = {1, 0.92, 0.7} })
        for i = 1, 26 do
            local a = rnd(0, math.pi * 2)
            local sp = rnd(200, 650)
            add({ x = x, y = y, vx = math.cos(a) * sp, vy = math.sin(a) * sp - 200, g = 1300,
                  life = rnd(0.5, 1.0), size = math.random(1, 3) * 3, chunk = true, fadeLast = 0.3, spin = rnd(-16, 16),
                  col = ({ {1, 0.85, 0.3}, {1, 0.5, 0.15}, {0.25, 0.2, 0.2}, {0.95, 0.95, 0.95} })[math.random(4)] })
        end
        for i = 1, 14 do
            local a = rnd(0, math.pi * 2)
            add({ x = x, y = y, vx = math.cos(a) * rnd(250, 600), vy = math.sin(a) * rnd(250, 600),
                  g = 500, life = rnd(0.2, 0.45), size = 8, star = true, col = {1, 0.9, 0.5} })
        end
        for i = 1, 12 do
            add({ x = x + rnd(-30, 30), y = y + rnd(-30, 30), vx = rnd(-50, 50), vy = -rnd(30, 110), g = -40,
                  life = rnd(0.8, 1.4), size = math.random(4, 6) * 3, col = {0.3, 0.28, 0.3}, drag = 2, dust = true })
        end
    elseif kind == 'enemy_burst' then
        -- ¡Revienta! (enemigo lanzado que cae en pinchos): destello, muchos
        -- pedazos de caparazón que giran y lo atraviesan todo, humo y chispas
        add({ x = x, y = y, vx = 0, vy = 0, shock = true, r0 = 10, r1 = 120, life = 0.3, size = 10,
              col = {1, 0.95, 0.85} })
        for i = 1, 34 do
            local a = rnd(0, math.pi * 2)
            local sp = rnd(220, 720)
            add({ x = x + rnd(-10, 10), y = y + rnd(-10, 10), vx = math.cos(a) * sp, vy = math.sin(a) * sp - 260,
                  g = 1500, life = rnd(0.7, 1.2), size = math.random(2, 4) * 3, chunk = true, fadeLast = 0.3,
                  spin = rnd(-20, 20),
                  col = ({ {0.9, 0.25, 0.2}, {1, 0.45, 0.3}, {0.95, 0.9, 0.85}, {0.25, 0.12, 0.1}, {0.8, 0.8, 0.82} })[math.random(5)] })
        end
        for i = 1, 10 do
            add({ x = x + rnd(-16, 16), y = y + rnd(-16, 16), vx = rnd(-60, 60), vy = -rnd(40, 120), g = -30,
                  life = rnd(0.5, 0.9), size = math.random(3, 5) * 3, col = {0.25, 0.23, 0.26}, drag = 2, dust = true })
        end
        for i = 1, 12 do
            local a = rnd(0, math.pi * 2)
            add({ x = x, y = y, vx = math.cos(a) * rnd(200, 500), vy = math.sin(a) * rnd(200, 500),
                  g = 600, life = rnd(0.25, 0.5), size = 8, star = true, col = {1, 0.85, 0.4} })
        end
    elseif kind == 'mirror_shards' then
        -- El Espejo se rompe: trozos de cristal (blanco / celeste) en todas
        -- direcciones que giran y caen, y un destello
        for i = 1, 22 do
            local a = rnd(0, math.pi * 2)
            local sp = rnd(140, 420)
            add({ x = x + rnd(-14, 14), y = y + rnd(-30, 30), vx = math.cos(a) * sp, vy = math.sin(a) * sp - 120,
                  g = 1100, life = rnd(0.45, 0.8), size = math.random(1, 3) * 3, chunk = true, fadeLast = 0.4,
                  spin = rnd(-14, 14), col = ({ {0.95, 0.98, 1}, {0.7, 0.9, 1}, {0.55, 0.75, 0.95} })[math.random(3)] })
        end
        for i = 1, 6 do
            local a = rnd(0, math.pi * 2)
            add({ x = x, y = y, vx = math.cos(a) * rnd(60, 200), vy = math.sin(a) * rnd(60, 200),
                  life = rnd(0.25, 0.45), size = 10, col = {1, 1, 1}, star = true, drag = 3 })
        end
    elseif kind == 'mirror_glint' then
        -- Reaparece: brillos que se juntan hacia él
        for i = 1, 12 do
            local a = (i / 12) * math.pi * 2
            local r = rnd(60, 90)
            add({ x = x + math.cos(a) * r, y = y + math.sin(a) * r, vx = -math.cos(a) * r / 0.3,
                  vy = -math.sin(a) * r / 0.3, life = 0.3, size = 8, star = true,
                  col = ({ {1, 1, 1}, {0.7, 0.9, 1} })[math.random(2)] })
        end
    elseif kind == 'shake_roar' then
        -- Temblor suave y largo (rugidos): se nota sin marear
        local k = (Sound and Sound.falloff) and Sound.falloff(x, y) or 1
        local pow = 4 * k
        if pow > shakePow * (shakeT / shakeDur) then
            shakePow, shakeDur = pow, 0.9
            shakeT = shakeDur
        end
    elseif kind == 'spike_pop' then
        -- El Crabby arranca su pincho del suelo: trozos del suelo hacia arriba
        local pal = paletteAt(x, y, opts)
        for i = 1, 12 do
            add({ x = x + rnd(-10, 10), y = y, vx = rnd(-160, 160), vy = -rnd(200, 460), g = 1300,
                  life = rnd(0.7, 1.1), size = math.random(1, 2) * 3,
                  col = pick(pal), phys = true, fadeLast = 0.3 })
        end
    end
end

-- Desplazamiento de cámara del temblor actual (sumar a camX/camY al dibujar)
function Particles.shakeOffset()
    if shakeT <= 0 then return 0, 0 end
    local k = shakePow * (shakeT / shakeDur)
    return math.floor((math.random() * 2 - 1) * k + 0.5), math.floor((math.random() * 2 - 1) * k + 0.5)
end

-- Un paso de una partícula física: gravedad (poca en el agua, donde además
-- frena y se hunde despacio), choque con paredes y techos (rebota), aterriza
-- en suelos y plataformas (rebota si viene rápida; si no, se queda y resbala
-- hasta pararse) y vuelve a caer si pierde el apoyo
local WATER_G, WATER_DRAG, WATER_SINK = 0.2, 5, 70
function Particles.physStep(p, dt)
    local r = (p.size or 3) / 2
    if p.inside == nil then
        -- (nacida dentro de un bloque: sin choques, como antes)
        p.inside = level:collisionAt(p.x, p.y) ~= nil
        if p.inside then p.phys = false; return end
    end
    local water = level:liquidAt(p.x, p.y) ~= nil
    local drag = (p.drag or 0) + (water and WATER_DRAG or 0)
    if drag > 0 then
        local k = math.max(0, 1 - drag * dt)
        p.vx, p.vy = p.vx * k, p.vy * k
    end
    if p.ground then
        -- En el suelo: resbala frenando; si ya no hay nada debajo, cae
        p.vx = p.vx * math.max(0, 1 - 9 * dt)
        if not level:landingCross(p.x, p.y + r - 1, p.y + r + 2) then p.ground = false end
    end
    if not p.ground then
        p.vy = p.vy + (p.g or 0) * (water and WATER_G or 1) * dt
        if water and p.vy > WATER_SINK then p.vy = WATER_SINK end
    end
    local spin = p.spin or 0
    -- X: una pared la hace rebotar
    local nx = p.x + p.vx * dt
    if level:collisionAt(nx + (p.vx > 0 and r or -r), p.y) then
        nx, p.vx, spin = p.x, -p.vx * 0.35, -spin * 0.5
    end
    p.x = nx
    -- Y
    if not p.ground then
        local ny = p.y + p.vy * dt
        if p.vy > 0 then
            local t, top = level:landingCross(p.x, p.y + r, ny + r)
            if t then
                ny = top - r
                if p.vy > 150 then
                    p.vy, p.vx, spin = -p.vy * (p.bounce or 0.35), p.vx * 0.7, spin * 0.6
                else
                    p.vy, p.ground, spin = 0, true, 0
                end
            end
        elseif p.vy < 0 and level:collisionAt(p.x, ny - r) then
            ny, p.vy = p.y, -p.vy * 0.25
        end
        p.y = ny
    end
    p.spin = spin
    p.ang = (p.ang or 0) + spin * dt
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
        elseif p.phys and level then
            Particles.physStep(p, dt)
        else
            if p.drag then p.vx = p.vx * (1 - p.drag * dt); p.vy = p.vy * (1 - p.drag * dt) end
            p.vy = p.vy + (p.g or 0) * dt
            p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
            if p.spin then p.ang = (p.ang or 0) + p.spin * dt end
        end
    end
end

-- Onda de choque (elipse de trazos duros que se abre y adelgaza) y rayo
-- (zigzag que parpadea: borde oscuro + núcleo claro). Líneas 'rough' = sin
-- suavizado, bordes de píxel.
local function renderSpecial(p, camX, camY)
    local lt = p.t - (p.delay or 0)
    if lt < 0 then return end
    local k = lt / (p.life - (p.delay or 0))
    local c = p.col
    love.graphics.setLineStyle('rough')
    love.graphics.setLineJoin('none')
    if p.shock then
        local r = p.r0 + (p.r1 - p.r0) * (1 - (1 - k) ^ 2)
        local w = math.max(2, math.floor(p.size * (1 - k * 0.7)))
        local n = 40
        love.graphics.setLineWidth(w)
        love.graphics.setColor(c[1], c[2], c[3], 0.55 * (1 - k))
        local cx, cy = math.floor(p.x - camX), math.floor(p.y - camY)
        -- (deformada: ondulaciones suaves que se mueven mientras se abre)
        local function pt(a)
            local w = p.wob or 0
            local rr = r * (1 + w * math.sin(3 * a + (p.ph1 or 0) + lt * 9) + w * 0.6 * math.sin(5 * a + (p.ph2 or 0) - lt * 7))
            return math.floor(cx + math.cos(a) * rr), math.floor(cy + math.sin(a) * rr * 0.62)
        end
        for i = 0, n - 1 do
            if i % 5 ~= 4 then                                   -- (a trazos)
                local x0, y0 = pt(i / n * math.pi * 2)
                local x1, y1 = pt((i + 1) / n * math.pi * 2)
                love.graphics.line(x0, y0, x1, y1)
            end
        end
    elseif math.floor(lt * 30) % 3 ~= 2 then                     -- (parpadeo)
        -- Tramo a tramo, cada vez más fino (afilado en la punta): borde oscuro
        -- y núcleo claro
        local function jag(pts, w0)
            local n = #pts / 2 - 1
            for pass = 1, 2 do
                if pass == 1 then love.graphics.setColor(p.edge or {0.3, 0.15, 0.05, 0.85})
                else love.graphics.setColor(c[1], c[2], c[3], 1) end
                for i = 1, n do
                    local w = math.max(1, math.floor(w0 * (1 - 0.65 * (i - 1) / n) + 0.5))
                    love.graphics.setLineWidth(pass == 1 and w + 3 or w)
                    love.graphics.line(math.floor(pts[2 * i - 1] - camX), math.floor(pts[2 * i] - camY),
                                       math.floor(pts[2 * i + 1] - camX), math.floor(pts[2 * i + 2] - camY))
                end
            end
        end
        if #p.bolt >= 4 then jag(p.bolt, p.size) end
        for _, f in ipairs(p.forks or {}) do jag(f, math.max(2, p.size - 3)) end
    end
    love.graphics.setLineWidth(1)
    love.graphics.setLineStyle('smooth')
    love.graphics.setLineJoin('miter')
end

local function renderOne(p, camX, camY)
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
    elseif p.fadeLast then
        a = math.min(1, (1 - p.t / p.life) / p.fadeLast)
    end
    love.graphics.setColor(c[1], c[2], c[3], a)
    if p.star then
        love.graphics.rectangle('fill', x - s / 2, y - 1, s, 2)
        love.graphics.rectangle('fill', x - 1, y - s / 2, 2, s)
    elseif p.chunk then
        love.graphics.push()
        love.graphics.translate(x, y)
        love.graphics.rotate(p.ang or 0)
        love.graphics.rectangle('fill', -s / 2, -s / 2, s, s)
        love.graphics.setColor(0, 0, 0, 0.35)
        love.graphics.rectangle('line', -s / 2, -s / 2, s, s)
        love.graphics.pop()
    else
        love.graphics.rectangle('fill', x - s / 2, y - s / 2, s, s)
    end
end

function Particles.render(camX, camY)
    for _, p in ipairs(list) do
        if p.shock or p.bolt then renderSpecial(p, camX, camY) else renderOne(p, camX, camY) end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Particles.clear() list = {}; shakeT = 0 end
function Particles.debugList() return list end      -- (pruebas: tools/tests/subtiles)

return Particles
