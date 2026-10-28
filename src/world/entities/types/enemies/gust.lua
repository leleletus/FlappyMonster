-- El SOPLÓN: una nubecilla con cara que flota. Cuando ve a un jugador delante (a su altura) INSPIRA (~1 s: se hincha,
-- el aviso) y SOPLA una racha horizontal que EMPUJA (sin daño) a los jugadores y a todo lo que tiene física
-- (systems/Push: `pushAt`). Reglas (aprobadas por el usuario en el diseño):
--   * Pisarlo mientras inspira (o flotando) lo REVIENTA; pisarlo mientras sopla, REBOTA (no muere). Un ground pound
--     siempre lo revienta. Su cuerpo no hace daño (ni de lado).
--   * Todos solo empujan, en todas las islas (como el Géiser del volcán: el usuario, "por continuidad, para no
--     confundir"); en la cueva, su soplido es además un RUIDO que oyen los lúgubres (`noises`).
-- Arte (tools/art/enemies/make_gust_sprites.py): assets/images/enemies/gust/<isla>-Sheet.png (8 cuadros 16x16, mira a la
-- IZQUIERDA: 1-2 flota, 3-4 inspira, 5-6 sopla, 7-8 revienta) y wind-Sheet.png (las partículas de la racha: una fila de
-- 3 cuadros 8x8 por isla, en el orden de Isles.IDS). Sonidos gustInhale / gustBlow / gustPop.
local Entity       = require 'src/world/entities/base/Entity'
local Interactions = require 'src/world/entities/base/Interactions'
local Isles        = require 'src/world/level/Isles'

local Gust = Entity.extend(Entity, { debugColor = { 0.8, 0.9, 1 },
    hitbox = { outerW = 0.8, outerH = 0.7, innerW = 0.6, innerH = 0.5 } })

local S         = GUMMY_SCALE
local INHALE_T  = 1.0
local BLOW_T    = 1.6
local REST_T    = 1.2
local POWER     = 420          -- px/s: la velocidad del aire de la racha
local SEE_H     = 1.5          -- casillas arriba / abajo en las que ve a un jugador
local FADE      = 0.2          -- s en los que la racha crece / se apaga

Gust.noWings = true
Gust.wantsLevel = true
function Gust.sizePx() return 16 * S, 16 * S end

local sheets, windImg, windQuads = {}, nil, {}
local function art(isle)
    if not sheets[isle] then
        sheets[isle] = require('src/fx/SpriteStrip').load('assets/images/enemies/gust/' .. isle .. '-Sheet.png', 16)
    end
    if not windImg then
        windImg = love.graphics.newImage('assets/images/enemies/gust/wind-Sheet.png')
        windImg:setFilter('nearest', 'nearest')
        for row, id in ipairs(Isles.IDS) do
            windQuads[id] = {}
            for k = 1, 3 do windQuads[id][k] = love.graphics.newQuad((k - 1) * 8, (row - 1) * 8, 8, 8, windImg:getDimensions()) end
        end
    end
    return sheets[isle]
end

function Gust:init()
    self.restT = 0.5
end

local function reach(self) return (self.props.reach or 5.5) * TILE_PX end

-- La racha: delante de él, a su altura
function Gust:pushAt(x, y)
    if self.state ~= 'blow' or not self.alive then return nil end
    local dir = self.facing or -1
    local front = self.x + dir * self.outerW / 2
    local dx = (x - front) * dir
    if dx < -8 or dx > reach(self) or math.abs(y - self.y) > (self.props.width or 1.6) * TILE_PX / 2 then return nil end
    local t = self.deadTimer or 0
    local k = math.min(1, t / FADE, (BLOW_T - t) / FADE)
    if k <= 0 then return nil end
    return dir * POWER * (self.props.power or 1) * k, 0
end

-- ¿Ve a un jugador delante, a su altura? (devuelve hacia dónde)
local function sees(self, level)
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying then
            local dx, dy = pa.x - self.x, pa.y - self.y
            if math.abs(dy) < SEE_H * TILE_PX and math.abs(dx) < reach(self) + TILE_PX * 0.5 and math.abs(dx) > 8 then
                return dx > 0 and 1 or -1
            end
        end
    end
    return nil
end

function Gust:updateCustom(dt, level)
    local st = self.state
    if st == 'inhale' or st == 'blow' then
        self.deadTimer = self.deadTimer + dt
        self.flyT = (self.flyT or 0) + dt
        local ty = (self.baseY or self.y) + math.sin(self.flyT * 3) * 4
        if ty ~= self.y then self:moveAndCollide(level, 0, ty - self.y) end
        if st == 'inhale' and self.deadTimer >= INHALE_T then
            self.state, self.deadTimer = 'blow', 0
            Sound.play('gustBlow')
        elseif st == 'blow' and self.deadTimer >= BLOW_T then
            self.state, self.deadTimer, self.restT = 'walk', 0, REST_T
            self.vx = (self.speed or 0) * (self.facing or 1)
        end
        return true
    end
    if st == 'walk' or st == 'idle' then
        self.restT = math.max(0, (self.restT or 0) - dt)
        local dir = self.restT <= 0 and sees(self, level)
        if dir then
            self.facing = dir
            self.state, self.deadTimer = 'inhale', 0
            self.baseY = self.y
            Sound.play('gustInhale')
            return true
        end
    end
    return false
end

-- Pisarlo: revienta, salvo mientras sopla (rebota). Un ground pound siempre lo revienta. De lado no hace nada.
function Gust:interact(pa)
    local r, a, b, c = Interactions.defaultCheck(pa, self)
    if r == 'stomp' and self.state == 'blow' and pa.gpPhase ~= 'fall' then return 'bounce', a end
    return r, a, b, c
end
function Gust:onStomp() Sound.play('gustPop') end

-- F1: la racha
function Gust:debugBoxes()
    if self.state ~= 'blow' and self.state ~= 'inhale' then return nil end
    local dir, w = self.facing or -1, reach(self)
    local x0 = self.x + dir * self.outerW / 2
    local h = (self.props.width or 1.6) * TILE_PX
    return { { x = dir > 0 and x0 or x0 - w, y = self.y - h / 2, w = w, h = h, kind = 'area' } }
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
local function frameOf(self)
    local st, t = self.state, self.deadTimer or 0
    if st == 'inhale' then return 3 + math.floor(t * 6) % 2 end
    if st == 'blow' then return 5 + math.floor(t * 8) % 2 end
    if st == 'dead' then return t < 0.12 and 7 or 8 end
    return 1 + math.floor(love.timer.getTime() * 3 + (self.home and self.home.x or 0)) % 2
end

function Gust:render(camX, camY)
    local isle = Isles.of(self.levelRef, self.props.isle)
    local sh = art(isle)
    local dir = self.facing or -1
    local x, y = math.floor(self.x - camX + 0.5), math.floor(self.y - camY + 0.5)
    if self.state == 'dead' then
        local t = self.deadTimer or 0
        love.graphics.setColor(1, 1, 1, math.max(0, 1 - t / 0.4))
    else
        love.graphics.setColor(1, 1, 1, 1)
    end
    -- (inspirando se hincha un poco)
    local k = 1
    if self.state == 'inhale' then k = 1 + 0.12 * math.min(1, (self.deadTimer or 0) / INHALE_T) end
    sh:draw(frameOf(self), x, y, 0, -dir * S * k, S * k)
    -- La racha: partículas que corren por delante (solo dependen de deadTimer: igual online)
    if self.state == 'blow' and windImg then
        local t, w = self.deadTimer or 0, reach(self)
        local a = math.min(1, t / FADE, (BLOW_T - t) / FADE)
        local q = windQuads[isle] or windQuads.pradera
        for n = 0, 7 do
            local u = ((t * 420 + n * w / 8) % w)
            local py = y + ((n * 37) % 5 - 2) * 9 + math.sin(t * 9 + n) * 4
            love.graphics.setColor(1, 1, 1, a * (1 - u / w * 0.6))
            love.graphics.draw(windImg, q[1 + (n + math.floor(t * 10)) % 3], math.floor(x + dir * (self.outerW / 2 + u)), math.floor(py),
                               0, -dir * S, S, 4, 4)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return {
    name = 'gust', label = 'Soplón', category = 'Enemigos', class = Gust,
    description = 'Nubecilla que flota; al ver a un jugador delante inspira (aviso) y sopla una racha que empuja, sin daño. '
               .. 'Pisarlo lo revienta (soplando, rebota); un ground pound siempre.',
    defaults = { movement = 'fly', speed = 25, bobAmp = 10, onTouch = 'none', points = 15, pauses = false },
    hide = { 'onTouch', 'attach', 'dropOnSight', 'detectRange', 'turnAtEdges', 'pauses' },
    noises = { gustBlow = 8 },
    props = {
        { key = 'reach', kind = 'number', label = 'Alcance (casillas)', group = 'Soplón', default = 5.5, min = 2, max = 12, step = 0.5,
          help = 'Lo largo de la racha (y desde dónde ve a un jugador)' },
        { key = 'width', kind = 'number', label = 'Alto de la racha (casillas)', group = 'Soplón', default = 1.6, min = 0.5, max = 4, step = 0.1 },
        { key = 'power', kind = 'number', label = 'Fuerza', group = 'Soplón', default = 1, min = 0.3, max = 3, step = 0.05,
          help = '1 = arrastra al monstruo más deprisa de lo que anda' },
    },
    isleArt = true,
    editor = { sprite = 'assets/images/enemies/gust/pradera-Sheet.png', frameW = 16 },
}
