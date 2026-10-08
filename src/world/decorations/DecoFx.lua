-- src/world/decorations/DecoFx.lua
-- Ayudas de dibujo y animación para las decoraciones (solo se usan desde
-- draw/update: nada de esto existe en el servidor). Cada decoración guarda sus
-- propias partículas en d.fx (no toca el sistema global de Particles): viven
-- pegadas a su punto de anclaje, así que se mueven con la cámara.
--
--   DecoFx.anim(conjunto, nombre)   una animación (clip de src/fx/Anim.lua), por su nombre
--                                   imagen entera es un cuadro (los sprites llevan 1 px de
--                                   margen transparente: nunca se ven cortados)
--   DecoFx.sheet(d, sx, sy, strip, frame, opts)   dibuja un cuadro anclado
--        opts.hang = cuelga desde arriba de su celda/subcelda; opts.alpha, opts.rot
--   DecoFx.wave(d, sx, sy, strip, frame, amp, speed, opts)
--        dibuja por filas de arte desplazadas en seno: mecerse de algas, pinos,
--        helechos... (la raíz quieta, la punta se mueve `amp` px de arte)
--   DecoFx.glow(sx, sy, radius, color, alpha)     halo aditivo (fx/glow.png)
--   DecoFx.seen(d) / DecoFx.visible(d)    solo se crean partículas si se ve
--   DecoFx.emit(d, p) / update(d, dt) / draw(d, sx, sy)   partículas propias
--   DecoFx.every(d, key, dt, a, b)  true cada [a,b] s (temporizador propio)
local SpriteStrip = require 'src/fx/SpriteStrip'

local DecoFx = {}
DecoFx.SCALE = 4                 -- escala del arte de las decoraciones
DecoFx.FX = 'assets/images/world/decorations/fx/'
local MAX_FX = 24                -- partículas por decoración

-- ANIMACIÓN de una decoración, por su nombre (clip de src/fx/Anim.lua; false si no existe): lo que usan los tipos.
--   local A = function(n) return DecoFx.anim('world/decorations/cave', n) end
-- DecoFx.fx(nombre) = una de las partículas compartidas (conjunto world/decorations/fx).
local Anim
local clips = {}
function DecoFx.anim(set, name)
    name = name:gsub('%.png$', ''):gsub('%-Sheet$', '')
    local k = set .. '#' .. name
    if clips[k] == nil then
        Anim = Anim or require 'src/fx/Anim'
        local ok, c = pcall(Anim.clip, set, name)
        clips[k] = ok and c or false
    end
    return clips[k]
end
function DecoFx.fx(name) return DecoFx.anim('world/decorations/fx', name) end
-- Paso de la animación que toca: nil = el que diga SU reloj (su ritmo, sus cuadros); un número = ese paso
local function stepOf(d, s, frame)
    if frame == nil then return s:at((d.animT or love.timer.getTime()) + (d.phase or 0)) end
    return math.max(1, math.min(s.count, frame))
end
DecoFx.stepOf = stepOf

-- Esquina de arriba del dibujo: anclado abajo-centro, o colgando del techo de
-- su celda (sy - TILE_PX) o subcelda (sy - TILE_PX/2)
local function topLeft(d, sx, sy, s, hang)
    local S = DecoFx.SCALE
    local w, h = s.w * S, s.h * S
    local y = hang and (sy - (d.def.placement == 'sub' and TILE_PX / 2 or TILE_PX)) or (sy - h)
    return sx - w / 2, y, w, h
end

function DecoFx.sheet(d, sx, sy, s, frame, opts)
    if not s then return end
    opts = opts or {}
    local S = DecoFx.SCALE
    local x, y, w, h = topLeft(d, sx, sy, s, opts.hang)
    love.graphics.setColor(1, 1, 1, opts.alpha or 1)
    local f = stepOf(d, s, frame)
    local q, img = s.quads[f], s.images and s.images[f] or s.image
    if opts.rot then
        -- (gira alrededor de la base)
        love.graphics.draw(img, q, math.floor(sx), math.floor(y + h), opts.rot, S * d.flip, S, s.w / 2, s.h)
    else
        love.graphics.draw(img, q, math.floor(x + (d.flip < 0 and w or 0)), math.floor(y), 0, S * d.flip, S)
    end
end

-- Quads de una fila de arte de un cuadro (cacheados en la tira)
local function rowQuad(s, frame, row)
    s.rows = s.rows or {}
    local k = frame * 1024 + row
    local q = s.rows[k]
    if not q then
        local r = s.recs and s.recs[frame]
        if r then q = love.graphics.newQuad(r.x, r.y + row, r.w, 1, r.iw, r.ih)
        else
            local iw, ih = s.image:getDimensions()
            q = love.graphics.newQuad((frame - 1) * s.w, row, s.w, 1, iw, ih)
        end
        s.rows[k] = q
    end
    return q
end

function DecoFx.wave(d, sx, sy, s, frame, amp, speed, opts)
    if not s then return end
    opts = opts or {}
    local S = DecoFx.SCALE
    local x, y, w = topLeft(d, sx, sy, s, opts.hang)
    local t = d.animT * (speed or 1) + d.phase * 6.28
    local f = stepOf(d, s, frame)
    local img = s.images and s.images[f] or s.image
    love.graphics.setColor(1, 1, 1, opts.alpha or 1)
    for row = 0, s.h - 1 do
        -- k = 0 en la raíz (abajo, o arriba si cuelga) → 1 en la punta
        local k = opts.hang and (row / (s.h - 1)) or (1 - row / (s.h - 1))
        local off = math.floor(amp * S * k ^ 1.4 * math.sin(t - k * 1.3) + 0.5)
        love.graphics.draw(img, rowQuad(s, f, row),
            math.floor(x + off + (d.flip < 0 and w or 0)), math.floor(y + row * S), 0, S * d.flip, S)
    end
end

function DecoFx.glow(sx, sy, radius, c, alpha)
    local g = DecoFx.fx('glow')
    if not g then return end
    local mode, am = love.graphics.getBlendMode()
    love.graphics.setBlendMode('add')
    love.graphics.setColor(c[1], c[2], c[3], alpha or 0.5)
    g:draw(1, math.floor(sx), math.floor(sy), 0, radius / 16, radius / 16)
    love.graphics.setBlendMode(mode, am)
end

-- ── Partículas propias ──────────────────────────────────────────────────────
function DecoFx.seen(d) d._seenT = d.animT end
function DecoFx.visible(d) return d._seenT and d.animT - d._seenT < 0.3 end

-- Temporizador: true una vez cada [a, b] s (aleatorio), solo si se ve
function DecoFx.every(d, key, dt, a, b)
    d._tm = d._tm or {}
    local left = (d._tm[key] or (a + (b - a) * d.phase)) - dt
    if left <= 0 then
        d._tm[key] = a + (b - a) * math.random()
        return DecoFx.visible(d)
    end
    d._tm[key] = left
    return false
end

-- p: x, y (px respecto al ancla), vx, vy, g (gravedad), drag, life,
--    sheet (tira), frame | frames+fps, scale, alpha, fade (se desvanece al final),
--    wob (vaivén lateral px), add (aditivo), onUpdate(p, dt, d) → false = muere
function DecoFx.emit(d, p)
    d.fx = d.fx or {}
    if #d.fx >= MAX_FX then return end
    p.t, p.vx, p.vy = 0, p.vx or 0, p.vy or 0
    p.wph = math.random() * 6.28
    if p.variant and p.sheet then p.frame = math.random(p.sheet.count) end   -- (una variante al azar de las que haya)
    d.fx[#d.fx + 1] = p
    return p
end

function DecoFx.update(d, dt)
    local list = d.fx
    if not list then return end
    for i = #list, 1, -1 do
        local p = list[i]
        p.t = p.t + dt
        p.vy = p.vy + (p.g or 0) * dt
        if p.drag then local k = math.max(0, 1 - p.drag * dt); p.vx, p.vy = p.vx * k, p.vy * k end
        p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
        local alive = p.t < p.life
        if alive and p.onUpdate then alive = p.onUpdate(p, dt, d) ~= false end
        if not alive then table.remove(list, i) end
    end
end

function DecoFx.draw(d, sx, sy)
    local list = d.fx
    if not list then return end
    local mode, am = love.graphics.getBlendMode()
    for _, p in ipairs(list) do
        local s = p.sheet
        if s then
            local a = p.alpha or 1
            if p.fade then a = a * math.min(1, (p.life - p.t) / p.fade) end
            if p.fadeIn then a = a * math.min(1, p.t / p.fadeIn) end
            local f = p.frame or s:at(p.t)                 -- (un paso fijo — variante al azar —, o el que diga su reloj)
            local x = p.x + (p.wob and math.sin(p.t * 3 + p.wph) * p.wob or 0)
            if p.add then love.graphics.setBlendMode('add') end
            local c = p.color or { 1, 1, 1 }
            love.graphics.setColor(c[1], c[2], c[3], a)
            s:draw(f, math.floor(sx + x), math.floor(sy + p.y), 0, p.scale or 3)
            if p.add then love.graphics.setBlendMode(mode, am) end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Sonido de ambiente de una decoración, donde está (se atenúa con la distancia; en las cuevas
-- lleva eco). Solo en el cliente (el servidor no tiene playAt); tono algo distinto cada vez
DecoFx.AMBIENT_VOL = 0.35                  -- (de fondo: una gota no debe sonar como un efecto del juego)
function DecoFx.sound(name, x, y, vol)
    if Sound and Sound.playAt then Sound.playAt(name, x, y, 0.85 + math.random() * 0.4, vol or DecoFx.AMBIENT_VOL) end
end

-- Gota que cae (estalactitas, carámbanos): se forma colgando, cae y salpica al
-- tocar el suelo del nivel (d.level), o se va a la casilla y media sin nivel
function DecoFx.drip(d, x, y, color)
    local s, splash = DecoFx.anim('fx', 'ice_drop'), DecoFx.anim('fx', 'ice_splash')
    if not s then return end
    DecoFx.emit(d, { x = x, y = y, life = 6, sheet = s, scale = 3, color = color, phase = 'form',
        onUpdate = function(p, dt, dd)
            if p.phase == 'form' then
                p.vy = 0
                if p.t > 0.5 then
                    p.phase, p.g = 'fall', 1200
                    DecoFx.sound('dripFall', dd.x + p.x, dd.y + p.y)
                end
            elseif p.phase == 'fall' then
                local wx, wy = dd.x + p.x, dd.y + p.y
                local lv = dd.level
                if lv and lv.landingCross then
                    local hit, top = lv:landingCross(wx, wy - p.vy * dt + 6, wy + 6)
                    if hit then
                        p.y, p.vy, p.g, p.phase, p.sheet, p.life = top - dd.y - 4, 0, 0, 'splash', splash or s, p.t + 0.16
                        DecoFx.sound('dripSplash', wx, top)
                    end
                    if lv:liquidAt(wx, wy) or wy > (lv.heightPx or 1e9) then return false end
                elseif p.y > TILE_PX * 1.5 then
                    return false
                end
            end
        end })
end

return DecoFx
