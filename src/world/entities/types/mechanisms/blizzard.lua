-- La VENTISCA: un ÁREA (se coloca en su esquina de arriba a la izquierda y se arrastra la de abajo a la derecha) donde,
-- cada poco y al azar, sopla el viento: primero un AVISO de ~1 s (una flecha parpadea en el borde de la pantalla por
-- donde va a entrar, y `windWarn`) y luego 2-3 s de viento (`windGust`, rachas cruzando) que EMPUJA a los jugadores, a
-- los enemigos y a todo lo que tiene física (systems/Push: `pushAt`) hacia la izquierda, la derecha, arriba (ayuda a
-- volar) o abajo (cuesta subir). Las direcciones posibles, cada cuánto y la fuerza son props. Aprobado por el usuario:
-- 1 s de aviso, 2-3 s de viento, pausa al azar; en torre_viento, las cuatro direcciones. Reutilizable en cualquier nivel.
-- Arte (tools/art/world/make_wind_geyser.py): assets/images/mechanisms/wind/<isla>-gust-Sheet.png (rachas 32x8, 3
-- cuadros, hacia la derecha: se giran) y warn-Sheet.png (flecha 16x16 hacia la derecha, 2 cuadros: encendida/apagada).
-- Red: estado y tiempo (los de siempre) + la dirección y lo que dura la racha en su netPack. El azar lo tira el que
-- simula (un jugador / el servidor).
local Entity = require 'src/world/entities/base/Entity'
local Isles  = require 'src/world/level/Isles'

local Bliz = Entity.extend(Entity, { debugColor = { 0.8, 0.9, 1 },
    hitbox = { outerW = 1, outerH = 1, innerW = 1, innerH = 1 } })

local S = GUMMY_SCALE
local FADE = 0.25
local DIRS = { { 'right', 1, 0 }, { 'left', -1, 0 }, { 'up', 0, -1 }, { 'down', 0, 1 } }
local SPEED = { right = 330, left = 330, up = 520, down = 330 }      -- px/s del aire (× power)
local GUST_SND = 1.15

Bliz.wantsLevel = true
function Bliz.sizePx() return TILE_PX, TILE_PX end

local function num(v, d) v = tonumber(v); return v and math.floor(v) or d end
function Bliz.rectOf(col, row, props)
    local cr = (props or {}).corner or {}
    local c0, c1 = math.min(col, num(cr.col, col)), math.max(col, num(cr.col, col))
    local r0, r1 = math.min(row, num(cr.row, row)), math.max(row, num(cr.row, row))
    local T = TILE_PX
    return (c0 - 1) * T, (r0 - 1) * T, c1 * T, r1 * T
end

function Bliz:init()
    self.moving, self.flying, self.vx, self.vy = false, true, 0, 0
    self.x0, self.y0, self.x1, self.y1 = Bliz.rectOf(self.col, self.row, self.props)
    self.state, self.deadTimer = 'calm', 0
    self.dir, self.blowT = 1, 2.5
    self.gap = self.props.firstDelay or 2
end
function Bliz:canBeStomped() return false end
function Bliz:canBeKnocked() return false end
function Bliz:canFreeze() return false end
function Bliz:isObstacle() return false end
function Bliz:isGhost() return true end            -- (no se toca: solo sopla)
function Bliz:interact() return nil end

local function allowed(p)
    local out = {}
    for i, d in ipairs(DIRS) do if p['dir_' .. d[1]] ~= false then out[#out + 1] = i end end
    if #out == 0 then out[1] = 1 end
    return out
end
local function rnd(a, b) return a + math.random() * (b - a) end

function Bliz:inside(x, y) return x >= self.x0 and x < self.x1 and y >= self.y0 and y < self.y1 end

function Bliz:pushAt(x, y)
    if self.state ~= 'blow' or not self:inside(x, y) then return nil end
    local t = self.deadTimer or 0
    local k = math.min(1, t / FADE, ((self.blowT or 2.5) - t) / FADE)
    if k <= 0 then return nil end
    local d = DIRS[self.dir] or DIRS[1]
    local v = SPEED[d[1]] * (self.props.power or 1) * k
    return d[2] * v, d[3] * v
end

function Bliz:updateCustom(dt, level)
    self.levelRef = level
    -- (sus sonidos salen de lo más cerca del jugador que esté dentro: el área puede ser una torre entera)
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying then
            self.x = math.max(self.x0, math.min(self.x1, pa.x))
            self.y = math.max(self.y0, math.min(self.y1, pa.y))
            break
        end
    end
    self.deadTimer = self.deadTimer + dt
    local st, p = self.state, self.props
    if st == 'calm' and self.deadTimer >= self.gap then
        local list = allowed(p)
        self.dir = list[math.random(#list)]
        self.state, self.deadTimer = 'warn', 0
        Sound.play('windWarn')
    elseif st == 'warn' and self.deadTimer >= (p.warn or 1) then
        self.state, self.deadTimer = 'blow', 0
        self.blowT = rnd(p.blowMin or 2, p.blowMax or 3)
        self.sndT = 0
    elseif st == 'blow' then
        self.sndT = (self.sndT or 0) - dt
        if self.sndT <= 0 and self.deadTimer < self.blowT - 0.4 then Sound.play('windGust'); self.sndT = GUST_SND end
        if self.deadTimer >= self.blowT then
            self.state, self.deadTimer = 'calm', 0
            self.gap = rnd(p.gapMin or 3, p.gapMax or 7)
        end
    end
    return true
end

-- ── Red ───────────────────────────────────────────────────────────────────────
function Bliz:netAtRest() return self.state == 'calm' end
function Bliz:netRest() self.state = 'calm' end
function Bliz:netPack() return { self.dir or 1, math.floor((self.blowT or 2.5) * 100) } end
function Bliz:netApply(a, b, f) self.dir, self.blowT = b[1] or 1, (b[2] or 250) / 100 end

function Bliz:debugBoxes()
    return { { x = self.x0, y = self.y0, w = self.x1 - self.x0, h = self.y1 - self.y0, kind = 'area' } }
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
local imgs = {}
local function strip(path, w)
    if not imgs[path] then imgs[path] = require('src/fx/SpriteStrip').load(path, w) end
    return imgs[path]
end
local ROT = { right = 0, left = math.pi, up = -math.pi / 2, down = math.pi / 2 }

function Bliz:render(camX, camY)
    -- lo que se ve del área
    local vx0, vy0 = math.max(self.x0, camX), math.max(self.y0, camY)
    local vx1, vy1 = math.min(self.x1, camX + WINDOW_W), math.min(self.y1, camY + WINDOW_H)
    if vx1 <= vx0 or vy1 <= vy0 then return end
    local d = DIRS[self.dir] or DIRS[1]
    local t = self.deadTimer or 0
    if self.state == 'warn' then
        -- la FLECHA en el borde de la pantalla por donde entra el viento (apuntando hacia donde va), parpadeando
        local ar = strip('assets/images/mechanisms/wind/warn-Sheet.png', 16)
        local fr = (math.floor(t * 8) % 2 == 0) and 1 or 2
        local cx, cy = (vx0 + vx1) / 2 - camX, (vy0 + vy1) / 2 - camY
        local m = 40
        local x = (d[2] > 0 and m) or (d[2] < 0 and WINDOW_W - m) or cx
        local y = (d[3] > 0 and m + 30) or (d[3] < 0 and WINDOW_H - m) or cy
        love.graphics.setColor(1, 1, 1, 1)
        for k = -1, 1 do                                   -- (tres flechas a lo largo del borde)
            local ox, oy = (d[2] ~= 0) and 0 or k * 160, (d[2] ~= 0) and k * 160 or 0
            ar:draw(fr, math.floor(x + ox), math.floor(y + oy), ROT[d[1]], S, S)
        end
        return
    end
    if self.state ~= 'blow' then return end
    -- las RACHAS: cruzan lo que se ve del área (solo dependen de deadTimer: igual online)
    local g = strip('assets/images/mechanisms/wind/' .. Isles.of(self.levelRef, self.props.isle) .. '-gust-Sheet.png', 32)
    local a = math.min(1, t / FADE, ((self.blowT or 2.5) - t) / FADE)
    local W, H = vx1 - vx0, vy1 - vy0
    local along = (d[2] ~= 0) and W or H
    local across = (d[2] ~= 0) and H or W
    local v = SPEED[d[1]] * 1.6
    love.graphics.setColor(1, 1, 1, a * 0.9)
    for n = 0, 17 do
        local u = (t * v + n * 211) % (along + 128) - 64
        local w = (n * 97 + 31) % 1000 / 1000 * across
        local px, py
        if d[2] ~= 0 then px, py = (d[2] > 0) and (vx0 + u) or (vx1 - u), vy0 + w
        else px, py = vx0 + w, (d[3] > 0) and (vy0 + u) or (vy1 - u) end
        g:draw(1 + (n + math.floor(t * 12)) % 3, math.floor(px - camX), math.floor(py - camY), ROT[d[1]], S, S)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawIcon(x, y, s)
    local ar = strip('assets/images/mechanisms/wind/warn-Sheet.png', 16)
    love.graphics.setColor(1, 1, 1, 1)
    ar:draw(1, x + s / 2, y + s / 2, 0, s / 16, s / 16)
end

return {
    name = 'blizzard', label = 'Ventisca', category = 'Mecanismos', class = Bliz,
    description = 'Área donde, cada poco y al azar, sopla el viento (con aviso de 1 s): empuja a todos hacia un lado, '
               .. 'arriba o abajo, sin daño. Arrastra la esquina para el tamaño.',
    hide = 'all', defaults = { movement = 'static' },
    inBlockOk = true,
    props = {
        { key = 'corner', kind = 'point', label = 'Esquina inferior derecha', group = 'Área',
          default = function(d) return { col = (d.col or 1) + 10, row = (d.row or 1) + 8 } end,
          help = 'Arrastra la cajita en el mapa. La casilla de la entidad es la esquina superior izquierda' },
        { key = 'dir_right', kind = 'bool', label = 'Hacia la derecha', group = 'Ventisca', default = true },
        { key = 'dir_left', kind = 'bool', label = 'Hacia la izquierda', group = 'Ventisca', default = true },
        { key = 'dir_up', kind = 'bool', label = 'Hacia arriba', group = 'Ventisca', default = true },
        { key = 'dir_down', kind = 'bool', label = 'Hacia abajo', group = 'Ventisca', default = true },
        { key = 'warn', kind = 'number', label = 'Aviso (s)', group = 'Ventisca', default = 1, min = 0.3, max = 4, step = 0.1 },
        { key = 'blowMin', kind = 'number', label = 'Racha mínima (s)', group = 'Ventisca', default = 2, min = 0.5, max = 10, step = 0.1 },
        { key = 'blowMax', kind = 'number', label = 'Racha máxima (s)', group = 'Ventisca', default = 3, min = 0.5, max = 10, step = 0.1 },
        { key = 'gapMin', kind = 'number', label = 'Calma mínima (s)', group = 'Ventisca', default = 3, min = 0.5, max = 30, step = 0.5 },
        { key = 'gapMax', kind = 'number', label = 'Calma máxima (s)', group = 'Ventisca', default = 7, min = 0.5, max = 30, step = 0.5 },
        { key = 'firstDelay', kind = 'number', label = 'Primera racha tras (s)', group = 'Ventisca', default = 2, min = 0, max = 30, step = 0.5 },
        { key = 'power', kind = 'number', label = 'Fuerza', group = 'Ventisca', default = 1, min = 0.3, max = 3, step = 0.05 },
    },
    isleArt = true,
    editor = { draw = drawIcon },
}
