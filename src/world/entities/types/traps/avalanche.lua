-- EL ALUD (Montañas Heladas; aprobado por el usuario el 2026-10-29, FlappyMonster_pruebas/islas_heladas/diseno.md §A4):
-- un CANAL de nieve, una franja de columnas del nivel por la que, cada `period` s, tras un AVISO (`warn` s: retumbo
-- `avalancheRumble`, copos que caen y la CORNISA de arriba temblando) se suelta un TORRENTE de nieve durante `pour` s.
--   * Se coloca en la casilla de ARRIBA a la izquierda del canal (justo debajo del saliente del que cuelga la
--     cornisa); `width` columnas a la derecha y hasta `length` casillas hacia abajo.
--   * La nieve NO atraviesa bloques: en cada columna se para en el primer bloque o plataforma (se mira el nivel, así
--     que los jugadores se ponen a cubierto bajo un saliente). Abajo salpica (`snow_burst`).
--   * Empuja hacia ABAJO todo lo que tiene física (systems/Push: jugadores, enemigos, cajas, bombas…) y, con `damage`,
--     hace daño a los jugadores con las reglas de la base (caja de peligro `effect = 'hurt'`: 1 de vida e
--     invulnerabilidad; además los aparta de lado: `PlayerAdventure:recoil`).
--   * `delay` = cuándo es el primer aviso: varios canales con `delay` distintos hacen una línea ESCALONADA.
-- Es un reloj: el estado (idle → warn → pour → drain → idle) sale de `clock` (un jugador / el servidor) y viaja con
-- el estado y deadTimer de siempre; el cliente dibuja y predice el empujón con ellos. En reposo no se envía.
-- Arte (tools/art/world/make_avalanche_cablecar.py): assets/images/traps/avalanche/*.png. Sonidos avalancheRumble y
-- avalanchePour (tools/sounds/avalanche_cablecar.py). Partículas `snow_burst` (src/fx/Particles.lua).
local Entity = require 'src/world/entities/base/Entity'
local TileTypes = require 'src/world/tiles/TileTypes'

local Aval = Entity.extend(Entity, { debugColor = { 0.85, 0.95, 1 },
    hitbox = { outerW = 1, outerH = 1, innerW = 1, innerH = 1 } })

local S       = GUMMY_SCALE
local T       = TILE_PX
local SPEED   = 900          -- px/s: lo rápido que cae el frente (y que se va la cola al acabar)
local PUSH    = 650          -- px/s hacia abajo del empujón (× power): cuesta mucho subir contra él
local POUR_SND = 1.2         -- s: cada cuánto se repite el sonido del torrente
local INSET   = 4            -- px: el daño, un poco por dentro de cada columna (rozar el borde no duele)
Aval.SPEED, Aval.PUSH = SPEED, PUSH

Aval.wantsLevel = true
function Aval.sizePx() return T, T end

-- La franja del canal (mundo, px): x0, top, x1 y el largo máximo
function Aval.band(col, row, p)
    local x0 = (col - 1) * T
    return x0, (row - 1) * T, x0 + (p.width or 2) * T, (p.length or 10) * T
end

function Aval:init()
    self.moving, self.flying, self.vx, self.vy = false, true, 0, 0
    self.x0, self.top, self.x1, self.len = Aval.band(self.col, self.row, self.props)
    -- (x, y: el centro de la franja — de ahí salen los sonidos si no hay nadie y lo usa el servidor para saber a quién
    -- mandarlo: con 30 casillas como mucho, el centro queda a menos de Protocol.NEAR_Y de cualquier punto)
    self.x, self.y = (self.x0 + self.x1) / 2, self.top + self.len / 2
    self.clock = 0
    self.state, self.deadTimer = 'idle', 0
end
function Aval:canBeStomped() return false end
function Aval:canBeKnocked() return false end
function Aval:canFreeze() return false end
function Aval:isObstacle() return false end
function Aval:isBodyDisabled() return true end            -- (no tiene cuerpo: solo el torrente)

-- ── El reloj ──────────────────────────────────────────────────────────────────
function Aval:drainT() return self.len / SPEED end
-- Estado y tiempo en él a la hora `clock` (pura: igual en todos)
function Aval:phaseAt(clock)
    local p = self.props
    local c = clock - (p.delay or 0)
    if c < 0 then return 'idle', clock end
    local period = math.max(p.period or 6, (p.warn or 1.2) + (p.pour or 2.5) + self:drainT() + 0.2)
    c = c % period
    local w, d = p.warn or 1.2, p.pour or 2.5
    if c < w then return 'warn', c end
    if c < w + d then return 'pour', c - w end
    if c < w + d + self:drainT() then return 'drain', c - w - d end
    return 'idle', c - w - d - self:drainT()
end

-- ── La nieve contra el nivel ──────────────────────────────────────────────────
-- Hasta dónde puede caer en cada columna (px desde `top`): el primer bloque o plataforma, o `length`
function Aval:measure(level)
    level = level or self.levelRef
    local w = self.props.width or 2
    local out = self.bots or {}
    for i = 1, w do
        local x = self.x0 + (i - 0.5) * T
        local b = self.len
        if level then
            for y = self.top + 4, self.top + self.len, 8 do
                local t = level:collisionAt(x, y, true)
                if t then
                    local c, r = math.floor(x / T) + 1, math.floor(y / T) + 1
                    local _, hy = TileTypes.worldHitbox(t, c, r)
                    b = math.max(0, math.min(self.len, (hy or y) - self.top))
                    break
                end
            end
        end
        out[i] = b
    end
    for i = w + 1, #out do out[i] = nil end
    self.bots = out
    return out
end
function Aval:bottoms() return self.bots or self:measure() end

-- La nieve que hay AHORA (distancias desde `top`): el frente y la cola; nil = nada
function Aval:span()
    local st, t = self.state, self.deadTimer or 0
    if st == 'pour' then return 0, math.min(self.len, t * SPEED) end
    if st == 'drain' then
        local tail = t * SPEED
        if tail >= self.len then return nil end
        return tail, self.len
    end
    return nil
end

-- Los tramos de nieve de cada columna: { x0, y0, x1, y1, landed } (mundo, px)
local SEGS = {}
function Aval:segments(into)
    local out = into or SEGS
    for i = #out, 1, -1 do out[i] = nil end
    local tail, front = self:span()
    if not tail then return out end
    for i, bot in ipairs(self:bottoms()) do
        local a, b = tail, math.min(front, bot)
        if b > a then
            local x = self.x0 + (i - 1) * T
            out[#out + 1] = { x, self.top + a, x + T, self.top + b, front >= bot }
        end
    end
    return out
end

-- ── Lo que hace ───────────────────────────────────────────────────────────────
-- Empuja hacia abajo lo que está dentro del torrente (systems/Push; también la predicción del cliente)
function Aval:pushAt(x, y)
    if self.state ~= 'pour' and self.state ~= 'drain' then return nil end
    if x < self.x0 or x >= self.x1 then return nil end
    for _, s in ipairs(self:segments()) do
        if x >= s[1] and x < s[3] and y >= s[2] - 24 and y < s[4] then return 0, PUSH * (self.props.power or 1), 2 end
    end
    return nil
end

-- Daño (Interactions: caja de peligro 'hurt' = 1 de vida, la regla de siempre)
function Aval:getHazardBoxes()
    if self.props.damage == false then return nil end
    local list = self:segments()
    if not list[1] then return nil end
    local out = {}
    for _, s in ipairs(list) do
        out[#out + 1] = { x = s[1] + INSET, y = s[2], w = (s[3] - s[1]) - 2 * INSET, h = s[4] - s[2], effect = 'hurt' }
    end
    return out
end
-- … y lo aparta de lado (hacia el borde más cercano del canal)
function Aval:onHurtPlayer(pa)
    local mid = (self.x0 + self.x1) / 2
    pa:recoil((pa.x < mid) and -1 or 1)
end

-- El punto del canal más cerca de un jugador: de ahí salen sus sonidos (la franja puede ser alta)
function Aval:soundPoint(level)
    local best, bx, by
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying then
            local x = math.max(self.x0, math.min(self.x1, pa.x))
            local y = math.max(self.top, math.min(self.top + self.len, pa.y))
            local d = (x - pa.x) ^ 2 + (y - pa.y) ^ 2
            if not best or d < best then best, bx, by = d, x, y end
        end
    end
    return bx or self.x, by or self.y
end

function Aval:updateCustom(dt, level)
    self.levelRef, self.simulated = level, true
    self.clock = self.clock + dt
    local was = self.state
    self.state, self.deadTimer = self:phaseAt(self.clock)
    self:measure(level)
    local st = self.state
    if st ~= was then
        local sx, sy = self:soundPoint(level)
        if st == 'warn' then Sound.playAt('avalancheRumble', sx, sy)
        elseif st == 'pour' then
            Sound.playAt('avalanchePour', sx, sy)
            self.sndT, self.landed = POUR_SND, false
            Entity.emitFx('snow_burst', (self.x0 + self.x1) / 2, self.top + 8)
        end
    end
    if st == 'pour' then
        self.sndT = (self.sndT or 0) - dt
        if self.sndT <= 0 and self.deadTimer < (self.props.pour or 2.5) - 0.5 then
            Sound.playAt('avalanchePour', self:soundPoint(level)); self.sndT = POUR_SND
        end
        -- (el frente llega abajo: polvo donde choca, una vez por columna más alta)
        if not self.landed then
            local _, front = self:span()
            local bots = self:bottoms()
            local lo
            for _, b in ipairs(bots) do if not lo or b < lo then lo = b end end
            if lo and front >= lo then
                self.landed = true
                for i, b in ipairs(bots) do
                    if b < self.len then Entity.emitFx('snow_burst', self.x0 + (i - 0.5) * T, self.top + b) end
                end
            end
        end
    end
    return true
end

-- ── Red ───────────────────────────────────────────────────────────────────────
function Aval:netAtRest() return self.state == 'idle' end
function Aval:netRest() self.state, self.deadTimer = 'idle', 0 end

-- F1: el torrente
function Aval:debugBoxes()
    local out = {}
    for _, s in ipairs(self:segments({})) do
        out[#out + 1] = { x = s[1], y = s[2], w = s[3] - s[1], h = s[4] - s[2], kind = (self.props.damage == false) and 'area' or 'hurt' }
    end
    out[#out + 1] = { x = self.x0, y = self.top, w = self.x1 - self.x0, h = self.len, kind = 'area' }
    return out
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
local strips = {}
local function strip(name, w)
    local path = 'assets/images/traps/avalanche/' .. name
    if not strips[path] then strips[path] = require('src/fx/SpriteStrip').load(path, w) end
    return strips[path]
end
-- Azar fijo por número (las partículas dibujadas: igual en todos los clientes, sin math.random)
local function hash(a, b)
    local v = math.sin(a * 12.9898 + b * 78.233) * 43758.5453
    return v - math.floor(v)
end

function Aval:render(camX, camY)
    if not self.simulated and self.levelRef then self:measure() end      -- (cliente / editor: el nivel puede cambiar)
    local st, t = self.state, self.deadTimer or 0
    local w = self.props.width or 2
    local top = math.floor(self.top - camY)
    love.graphics.setColor(1, 1, 1, 1)
    -- el TORRENTE
    local segs = self:segments({})
    if EDITOR_VIEW and not segs[1] then
        -- (editor: hasta dónde llega, tenue)
        love.graphics.setColor(1, 1, 1, 0.3)
        local saveSt, saveT = self.state, self.deadTimer
        self.state, self.deadTimer = 'pour', 99
        segs = self:segments({})
        self.state, self.deadTimer = saveSt, saveT
    end
    if segs[1] then
        local col, side, headS = strip('stream-Sheet.png', 16), strip('side-Sheet.png', 4), strip('head-Sheet.png', 16)
        local f = 1 + math.floor((love.timer and love.timer.getTime() or 0) * 14) % 3
        local Clip = require 'src/ui/Clip'
        for k, s in ipairs(segs) do
            local x, y0, y1 = math.floor(s[1] - camX), math.floor(s[2] - camY), math.floor(s[4] - camY)
            Clip.push(x, y0, T, y1 - y0)
            for yy = y0 - ((y0 + math.floor(camY)) % T), y1, T do col:draw(f, x + T / 2, yy + T / 2, 0, S, S) end
            Clip.pop()
            -- (los bordes de fuera, deshilachados)
            if k == 1 or segs[k - 1][3] ~= s[1] then
                Clip.push(x - 4 * S, y0, 4 * S, y1 - y0)
                for yy = y0, y1, T do side:draw(f, x - 2 * S, yy + T / 2, 0, -S, S) end
                Clip.pop()
            end
            if k == #segs or segs[k + 1][1] ~= s[3] then
                Clip.push(x + T, y0, 4 * S, y1 - y0)
                for yy = y0, y1, T do side:draw(f, x + T + 2 * S, yy + T / 2, 0, S, S) end
                Clip.pop()
            end
            -- el FRENTE que cae (aún no ha llegado abajo) o lo que SALPICA abajo
            if st == 'pour' and not s[5] then headS:draw(f, x + T / 2, y1, 0, S, S)
            elseif s[5] then
                strip('splash-Sheet.png', 16):draw(f, x + T / 2, y1 - 4 * S + 2, 0, S, S)
            end
        end
        love.graphics.setColor(1, 1, 1, 1)
    end
    -- AVISO: copos que caen de la cornisa (más cuanto más cerca de soltarse)
    if st == 'warn' then
        local fl = strip('flake-Sheet.png', 4)
        local warn = self.props.warn or 1.2
        local k = math.min(1, t / warn)
        local n = math.floor(4 + 10 * k) * w
        for i = 0, n - 1 do
            local life = 0.6 + 0.5 * hash(i, 3)
            local u = ((t + hash(i, 1) * life) / life) % 1
            local px = self.x0 + hash(i, 2) * (self.x1 - self.x0) + math.sin(t * 4 + i) * 6
            local py = self.top + 20 + u * u * T * (1.5 + 2 * hash(i, 4))
            love.graphics.setColor(1, 1, 1, 1 - u)
            fl:draw(1 + i % 3, math.floor(px - camX), math.floor(py - camY), 0, S, S)
        end
        love.graphics.setColor(1, 1, 1, 1)
    end
    -- la CORNISA (temblando en el aviso; durante el torrente, sin ella: ya cayó; vuelve a formarse al acabar)
    local shaking = st == 'warn'
    local gone = st == 'pour' or st == 'drain'
    if not gone or EDITOR_VIEW then
        local cor = strip('cornice-Sheet.png', 16)
        local jx = shaking and ((math.floor(t * 30) % 2 == 0) and -S or S) * math.min(1, t / 0.4) or 0
        for i = 1, w do
            local x = math.floor(self.x0 + (i - 0.5) * T - camX + jx)
            cor:draw(shaking and 2 or 1, x, top + 4 * S, 0, S, S)
        end
    elseif st == 'drain' then
        -- (vuelve a crecer la cornisa mientras se vacía)
        local cor = strip('cornice-Sheet.png', 16)
        love.graphics.setColor(1, 1, 1, math.min(1, t / self:drainT()))
        for i = 1, w do cor:draw(1, math.floor(self.x0 + (i - 0.5) * T - camX), top + 4 * S, 0, S, S) end
        love.graphics.setColor(1, 1, 1, 1)
    end
end

-- Editor: la franja del canal (ancho × largo)
function Aval.drawEditorOverlay(props, cx, cy, zoom)
    -- (el lienzo del editor ya está escalado por el zoom)
    local w, len = (props.width or 2) * T, (props.length or 10) * T
    local x, y = cx - T / 2, cy - T / 2
    love.graphics.setColor(0.85, 0.95, 1, 0.9)
    love.graphics.rectangle('line', x, y, w, len)
    love.graphics.setColor(0.85, 0.95, 1, 0.12)
    love.graphics.rectangle('fill', x, y, w, len)
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawIcon(x, y, s)
    love.graphics.setColor(1, 1, 1, 1)
    strip('cornice-Sheet.png', 16):draw(1, x + s / 2, y + s * 0.15, 0, s / 16, s / 16)
    strip('stream-Sheet.png', 16):draw(1, x + s / 2, y + s * 0.6, 0, s / 24, s / 24)
end

return {
    name = 'avalanche', label = 'Alud', category = 'Trampas', class = Aval,
    description = 'Canal de nieve: tras un aviso (retumbo, copos, la cornisa tiembla) cae un torrente que empuja hacia '
               .. 'abajo y hace daño. Se para en el primer bloque: bajo un saliente se está a cubierto. Se coloca '
               .. 'arriba a la izquierda del canal, bajo el saliente.',
    hide = 'all', defaults = { movement = 'static' },
    props = {
        { key = 'width', kind = 'int', label = 'Ancho (casillas)', group = 'Alud', default = 2, min = 1, max = 8, step = 1,
          help = 'Columnas del canal, hacia la derecha desde la casilla de la entidad' },
        { key = 'length', kind = 'int', label = 'Largo (casillas)', group = 'Alud', default = 10, min = 2, max = 30, step = 1,
          help = 'Hasta dónde puede caer (en cada columna se para antes en el primer bloque o plataforma)' },
        { key = 'period', kind = 'number', label = 'Cada (s)', group = 'Alud', default = 6, min = 2, max = 60, step = 0.5,
          help = 'Lo que tarda un ciclo entero (aviso + torrente + calma)' },
        { key = 'warn', kind = 'number', label = 'Aviso (s)', group = 'Alud', default = 1.2, min = 0.3, max = 5, step = 0.1 },
        { key = 'pour', kind = 'number', label = 'Torrente (s)', group = 'Alud', default = 2.5, min = 0.5, max = 20, step = 0.1 },
        { key = 'delay', kind = 'number', label = 'Primer aviso tras (s)', group = 'Alud', default = 1, min = 0, max = 60, step = 0.1,
          help = 'Varios canales con retrasos distintos hacen una línea escalonada' },
        { key = 'damage', kind = 'bool', label = 'Hace daño', group = 'Alud', default = true,
          help = 'Sin daño solo empuja hacia abajo' },
        { key = 'power', kind = 'number', label = 'Fuerza', group = 'Alud', default = 1, min = 0.3, max = 3, step = 0.05 },
    },
    editor = { draw = drawIcon },
}
