-- EL ESPEJO, PERSIGUIENDO (el nivel de antes del jefe final). No es una pelea: no se le puede hacer nada — solo
-- CORRER. Va pegado al borde izquierdo de la cámara automática del nivel (src/world/AutoScroll.lua), volando por
-- encima de todo (lo atraviesa todo) a la altura del jugador, y de vez en cuando se LANZA hacia delante: avisa
-- (se encoge y tiembla), sale disparado unas casillas y vuelve a su sitio. Tocarlo es morir.
--
-- Su x SALE de la cámara (a.x + lo que lleve de embestida): en un jugador y en el servidor se calcula aquí; el
-- cliente lo dibuja con lo que llega en el snapshot (x, y, estado, deadTimer). Sin cámara automática en el nivel
-- se queda donde lo pusieron (sigue matando al tocarlo).
-- Estados: 'lurk' (esperando a que empiece: se ríe) → 'chase' → 'wind' (aviso) → 'dash' (embestida) → 'chase' …
-- → 'left' (la carrera acabó: se rompe en pedazos y desaparece).
-- Se dibuja como el Espejo: el monstruo con los colores invertidos (los sprites del jugador) y una estela.
local Entity = require 'src/world/entities/Entity'

local Chase = Entity.extend(Entity, {
    debugColor = { 0.9, 0.2, 0.9 },
    hitbox = { outerW = 0.7, outerH = 0.85, innerW = 0.5, innerH = 0.7 },
})

local S       = PLAYER_SCALE
local FW, FH  = 9, 16
local LEAD    = 1.1 * TILE_PX        -- cuánto asoma por dentro del borde izquierdo de la cámara
local WIND_T  = 0.6                  -- s de aviso antes de embestir
local DASH_OUT, DASH_HOLD, DASH_BACK = 0.22, 0.12, 0.55
local FOLLOW  = 300                  -- px/s con que busca la altura del jugador
local ACTIVE  = { chase = true, wind = true, dash = true }

local frames
function Chase.loadAssets()
    if frames then return end
    frames = {}
    for i = 1, 5 do
        frames[i] = love.graphics.newImage('assets/images/player/monstrito' .. i .. '.png')
        if frames[i].setFilter then frames[i]:setFilter('nearest', 'nearest') end
    end
end
function Chase.sizePx() return FW * S, FH * S end

function Chase:init()
    self.moving, self.flying, self.vx, self.vy = false, true, 0, 0
    self.state, self.deadTimer = 'lurk', 0
    self.facing = 1
    self.lungeT = (self.props.lungeEvery or 6) * 0.6
    self.extra = 0
end

function Chase:canBeStomped() return false end
function Chase:canBeKnocked() return false end
function Chase:canFreeze() return false end
function Chase:canBeLaunched() return false end
function Chase:isObstacle() return false end

-- Tocarlo es morir (sin efectos: el cliente lo usa para predecir). Con la invulnerabilidad de reaparecer, no
function Chase:interact(pa)
    if not ACTIVE[self.state] then return nil end
    if pa:isInvulnerable() then return nil end
    local a, b = pa:getInnerBounds(), self:getInnerBounds()
    if a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y then return 'kill' end
    return nil
end

local function nearest(level, x, y)
    local best, bd
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false then
            local d = math.abs(pa.x - x) + math.abs(pa.y - y)
            if not bd or d < bd then best, bd = pa, d end
        end
    end
    return best
end

function Chase:updateCustom(dt, level)
    local a = level.autoScroll
    local st = self.state
    if st == 'walk' then st = 'lurk'; self.state = 'lurk' end
    self.deadTimer = self.deadTimer + dt
    if st == 'left' then
        if self.deadTimer > 0.5 then self.alive = false end
        return true
    end
    if not a then return true end                                   -- (sin cámara automática: un peligro quieto)
    if a.state == 'stop' then                                       -- la carrera acabó: se rompe y se va
        self.state, self.deadTimer = 'left', 0
        Entity.emitFx('mirror_shards', self.x, self.y)
        Sound.play('mirrorWarp')
        return true
    end
    if a.state ~= 'run' then
        if a.state == 'countdown' and not self.laughed then self.laughed = true; Sound.play('mirrorLaugh') end
        self.x = a.x + LEAD
        return true
    end
    if st == 'lurk' then st = 'chase'; self.state, self.deadTimer = 'chase', 0; Sound.play('mirrorAppear') end
    -- la altura: la del jugador más cercano (no mientras avisa o embiste: ahí ya ha apuntado)
    local pa = nearest(level, self.x, self.y)
    if pa and st == 'chase' then
        local dy = pa.y - self.y
        self.y = self.y + math.max(-FOLLOW * dt, math.min(FOLLOW * dt, dy))
    end
    -- la embestida
    local every = self.props.lungeEvery or 6
    if st == 'chase' and every > 0 then
        self.lungeT = self.lungeT - dt
        if self.lungeT <= 0 and pa then
            self.state, self.deadTimer = 'wind', 0
            Sound.play('mirrorPortal')
        end
    elseif st == 'wind' then
        if self.deadTimer >= WIND_T then self.state, self.deadTimer = 'dash', 0; Sound.play('mirrorWarp') end
    elseif st == 'dash' then
        local t, D = self.deadTimer, (self.props.lungeDist or 5) * TILE_PX
        if t < DASH_OUT then self.extra = D * (t / DASH_OUT)
        elseif t < DASH_OUT + DASH_HOLD then self.extra = D
        elseif t < DASH_OUT + DASH_HOLD + DASH_BACK then
            local u = (t - DASH_OUT - DASH_HOLD) / DASH_BACK
            self.extra = D * (1 - u * u * (3 - 2 * u))
        else
            self.extra = 0
            self.state, self.deadTimer = 'chase', 0
            self.lungeT = every * (0.75 + 0.5 * math.random())
        end
    end
    self.x = a.x + LEAD + (self.extra or 0)
    return true
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
local INVERT = [[
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec4 c = Texel(tex, tc);
    return vec4(1.0 - c.rgb, c.a) * color;
}]]
local shader
local function invert()
    if shader == nil then
        local ok, sh = pcall(love.graphics.newShader, INVERT)
        shader = ok and sh or false
    end
    if shader then love.graphics.setShader(shader) end
end

function Chase:render(camX, camY)
    local st, t = self.state, self.deadTimer or 0
    if st == 'left' then return end
    local now = love.timer.getTime()
    local x, y = math.floor(self.x - camX), math.floor(self.y - camY)
    -- la OSCURIDAD que trae detrás: bandas duras, más negras cuanto más atrás (no hay vuelta)
    if ACTIVE[st] then
        for i = 1, 5 do
            love.graphics.setColor(0.05, 0, 0.08, 0.16 * i)
            love.graphics.rectangle('fill', x - 30 - i * 26 - 400 * (i == 5 and 1 or 0), -8, 26 + 400 * (i == 5 and 1 or 0), WINDOW_H + 16)
        end
    end
    local fr, sx, sy, dx, dy = 3, 1, 1, 0, math.floor(math.sin(now * 5) * 4)
    if st == 'chase' then fr = (math.floor(now * 12) % 3) + 1
    elseif st == 'wind' then
        fr, dx = 5, math.floor(math.sin(now * 70) * 3)                       -- se encoge y tiembla
        sx, sy = 1.1, 0.9
    elseif st == 'dash' then fr, sx, sy = 2, 1.35, 0.8                       -- estirado
    elseif st == 'lurk' then dy = math.floor(math.abs(math.sin(now * 9)) * -6) end      -- se ríe a saltitos
    invert()
    local img = frames[fr]
    -- estela (copias más tenues detrás)
    if st == 'chase' or st == 'dash' then
        for i = 3, 1, -1 do
            love.graphics.setColor(1, 1, 1, 0.14 * (4 - i))
            love.graphics.draw(img, x - i * (st == 'dash' and 34 or 14) + dx, y + dy, 0, S * sx, S * sy, FW / 2, FH / 2)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, x + dx, y + dy, 0, S * sx, S * sy, FW / 2, FH / 2)
    love.graphics.setShader()
end

local G = 'Persecución'
return {
    name = 'mirrorchase', label = 'Espejo perseguidor', category = 'Jefes', class = Chase,
    description = 'El Espejo persiguiendo: va en el borde izquierdo de la CÁMARA AUTOMÁTICA del nivel, a la altura del '
               .. 'jugador, y de vez en cuando embiste. No se le puede hacer nada: tocarlo es morir. El HUD dice ¡CORRE!',
    traits = { diesWithBlock = false, renderFront = true },
    pace = false,                              -- (su ritmo es el de la cámara: la dificultad no lo acelera aparte)
    hide = 'all', defaults = { movement = 'static' },
    props = {
        { key='lungeEvery', kind='number', label='Embiste cada (s)', group=G, default=6, min=0, max=30, step=0.5, help='0 = nunca' },
        { key='lungeDist', kind='number', label='Embestida (casillas)', group=G, default=5, min=1, max=12, step=0.5 },
    },
    editor = { sprite = 'assets/images/player/monstrito3.png', invert = true },
}
