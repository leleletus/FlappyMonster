-- EL ESPEJO, PERSIGUIENDO (el nivel de antes del jefe final). No es una pelea: no se le puede hacer nada — solo
-- CORRER. Va SUELTO por el nivel (2ª versión; el usuario: pegado al borde y con una carguita de vez en cuando era
-- "muy fácil" — lo quería libre, teletransportándose, atacando y EMPUJANDO, intenso y frenético): no choca con nada
-- ni le afecta nada del nivel, y encadena ataques con muy poco descanso. Cada golpe quita 1 de vida y, sobre todo,
-- EMPUJA: casi siempre hacia atrás, hacia el borde de la cámara automática (src/world/AutoScroll.lua), que es lo
-- que mata. Sus ataques (los del jefe, a la carrera):
--   · ESPEJO (dive): se rompe, aparece en un espejo flotante SOBRE el jugador (lo sigue y al final se fija; marca
--     en el suelo) y cae en picado: golpe + onda que empuja a los de alrededor.
--   · EMBESTIDA (dash): aparece en el lado DERECHO de la pantalla a la altura del jugador, avisa con una línea y
--     cruza la pantalla entera hacia la izquierda. Se salta.
--   · EMPUJÓN (shove): aparece justo delante del jugador y carga corto contra él.
-- Entre ataques ('stalk') vuelve al borde izquierdo un instante. Si alguien muere, se ríe.
--
-- Solo simula en un jugador / el servidor; el cliente dibuja lo que llega (x, y, estado, deadTimer + netPack: la
-- marca, hacia dónde va y qué ataque es). Sin cámara automática en el nivel se queda quieto.
-- Estados: 'lurk' (antes de empezar) → 'stalk' → 'warp_out' → ('portal' → 'dive' → 'recover') | ('aim' → 'rush')
-- → 'stalk' … → 'left' (la carrera acabó: se rompe y desaparece).
local Entity = require 'src/world/entities/Entity'
local Boss   = require 'src/world/entities/Boss'

local Chase = Entity.extend(Entity, {
    debugColor = { 0.9, 0.2, 0.9 },
    hitbox = { outerW = 0.7, outerH = 0.85, innerW = 0.55, innerH = 0.75 },
})

local S, T    = PLAYER_SCALE, TILE_PX
local FW, FH  = 9, 16
local LEAD    = 1.1 * T              -- en 'stalk': cuánto asoma por dentro del borde izquierdo de la cámara
local WARP_T  = 0.28                 -- s rompiéndose antes de reaparecer
local PORTAL_T, PORTAL_LOCK = 0.85, 0.3      -- s en el espejo flotante; los últimos, fijo (ya no sigue)
local PORTAL_FOLLOW = 460            -- px/s siguiendo al jugador desde el espejo
local PORTAL_UP = 4.2 * T
local DIVE_V  = 1500
local RECOVER_T = 0.3
local AIM_DASH, AIM_SHOVE = 0.55, 0.4        -- s de aviso
local RUSH_V  = 1350
local SHOVE_FROM, SHOVE_LEN = 4 * T, 7.5 * T
local WAVE_R  = 1.7 * T              -- la onda del picado
local GRACE   = 0.7                  -- s sin volver a golpear tras un golpe
-- {vida, vx, vy, s sin control, s aturdido} (Boss.strike)
local HIT_DIVE  = { 1, 620, -420, 0.3, 0.35 }
local HIT_RUSH  = { 1, 980, -340, 0.4, 0.3 }
local HIT_TOUCH = { 1, 560, -320, 0.25, 0 }
local KINDS   = { 'dive', 'dash', 'shove', 'dash', 'dive', 'shove' }
local DANGER  = { stalk = true, dive = true, rush = true, recover = true, aim = true }
local HIDDEN  = { warp_out = true, left = true }

local frames, Mirror
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
    self.restT = 1.6
    self.kindI, self.kind = 0, 'dive'
    self.markX, self.markY, self.dir = self.x, self.y, 1
    self.graceT = 0
end

function Chase:canBeStomped() return false end
function Chase:canBeKnocked() return false end
function Chase:canFreeze() return false end
function Chase:canBeLaunched() return false end
function Chase:isObstacle() return false end
function Chase:isGhost() return true end                 -- (las reglas normales jugador ↔ entidad no van con él)
function Chase:interact() return nil end                 -- (pega él, en su update: Boss.strike)

local function alive(pa) return not pa.dying and pa.alive ~= false end
local function nearest(level, x, y)
    local best, bd
    for _, pa in ipairs(level.players or {}) do
        if alive(pa) then
            local d = math.abs(pa.x - x) + math.abs(pa.y - y)
            if not bd or d < bd then best, bd = pa, d end
        end
    end
    return best
end

function Chase:enter(st) self.state, self.deadTimer = st, 0 end

-- El suelo bajo (x, y): la primera cara sólida hacia abajo (o el fondo del nivel)
function Chase:floorBelow(level, x, y)
    local yy = math.max(8, y)
    while yy < level.heightPx do
        if level:isEnemySolidAt(x, yy) then return math.floor(yy / 16) * 16 end
        yy = yy + 16
    end
    return level.heightPx
end

-- Golpea a quien toque su cuerpo (con `hit` y hacia `dir`; 0 = lejos de él)
function Chase:hitPlayers(level, hit, dir)
    if self.graceT > 0 then return false end
    local b, any = self:getInnerBounds(), false
    for _, pa in ipairs(level.players or {}) do
        if alive(pa) then
            local o = pa:getOuterBounds()
            if o.x < b.x + b.w and o.x + o.w > b.x and o.y < b.y + b.h and o.y + o.h > b.y then
                local d = (dir ~= 0) and dir or ((pa.x >= self.x) and 1 or -1)
                if Boss.strike(pa, hit, d) then any = true end
            end
        end
    end
    if any then self.graceT = GRACE end
    return any
end

function Chase:pickAttack(level, a, pa)
    self.kindI = self.kindI % #KINDS + 1
    self.kind = KINDS[self.kindI]
    -- (el empujón de frente necesita sitio por delante dentro de la pantalla)
    if self.kind == 'shove' and pa.x + SHOVE_FROM > a.x + a.W - T then self.kind = 'dash' end
    self:enter('warp_out')
    Entity.emitFx('mirror_shards', self.x, self.y)
    Sound.play('mirrorWarp')
end

function Chase:updateCustom(dt, level)
    local a = level.autoScroll
    local st = self.state
    if st == 'walk' then st = 'lurk'; self.state = 'lurk' end
    self.deadTimer = self.deadTimer + dt
    self.graceT = math.max(0, self.graceT - dt)
    if st == 'left' then
        if self.deadTimer > 0.5 then self.alive = false end
        return true
    end
    if not a then return true end
    if a.state == 'stop' then                                       -- la carrera acabó: se rompe y se va
        self:enter('left')
        Entity.emitFx('mirror_shards', self.x, self.y)
        Sound.play('mirrorWarp')
        return true
    end
    if a.state ~= 'run' then
        if a.state == 'countdown' and not self.laughed then self.laughed = true; Sound.play('mirrorLaugh') end
        self.x = a.x + LEAD
        return true
    end
    -- alguien acaba de morir: se ríe (una vez por muerte)
    self.deadSeen = self.deadSeen or setmetatable({}, { __mode = 'k' })
    for _, pa in ipairs(level.players or {}) do
        if pa.dying and not self.deadSeen[pa] then self.deadSeen[pa] = true; Sound.play('mirrorLaugh', 1.1)
        elseif not pa.dying then self.deadSeen[pa] = nil end
    end
    local pa = nearest(level, self.x, self.y)
    local t = self.deadTimer
    local every = (self.props.rest or 1.1)
    if st == 'lurk' then
        self:enter('stalk'); self.restT = every
        Sound.play('mirrorAppear')
    elseif st == 'stalk' then
        -- vuelve al borde izquierdo y busca la altura del jugador
        local tx = a.x + LEAD
        self.x = self.x + (tx - self.x) * math.min(1, dt * 8)
        if pa then self.y = self.y + math.max(-340 * dt, math.min(340 * dt, pa.y - self.y)) end
        self.facing = 1
        self:hitPlayers(level, HIT_TOUCH, 1)
        self.restT = self.restT - dt
        if self.restT <= 0 and pa then self:pickAttack(level, a, pa) end
    elseif st == 'warp_out' then
        if t >= WARP_T then
            if not pa then self:enter('stalk'); self.restT = 0.3; self.x = a.x + LEAD; return true end
            if self.kind == 'dive' then
                self.x = pa.x
                self.y = math.max(1.5 * T, pa.y - PORTAL_UP)
                self.markX, self.markY = self.x, self:floorBelow(level, self.x, pa.y)
                self:enter('portal'); Sound.play('mirrorPortal')
            else
                local shove = self.kind == 'shove'
                self.dir = -1                                            -- viene de delante: empuja hacia ATRÁS
                self.x = shove and (pa.x + SHOVE_FROM) or (a.x + a.W - 0.8 * T)
                self.y = pa.y
                self.facing = -1
                self.markX = shove and (self.x - SHOVE_LEN) or (a.x - 2 * T)   -- hasta dónde llega
                self.markY = self.y
                self:enter('aim'); Sound.play('mirrorAppear')
            end
        end
    elseif st == 'portal' then
        if pa and t < PORTAL_T - PORTAL_LOCK then                       -- sigue al jugador; al final se fija
            self.x = self.x + math.max(-PORTAL_FOLLOW * dt, math.min(PORTAL_FOLLOW * dt, pa.x - self.x))
            self.markX, self.markY = self.x, self:floorBelow(level, self.x, pa.y)
        end
        self.x = self.x + a.speed * dt * 0                               -- (el espejo NO viaja con la cámara: se queda atrás)
        if t >= PORTAL_T then self:enter('dive'); Sound.play('gpStart') end
    elseif st == 'dive' then
        local y1 = self.markY - self.outerH / 2
        self.y = math.min(y1, self.y + DIVE_V * dt)
        self:hitPlayers(level, HIT_DIVE, -1)
        if self.y >= y1 then
            -- la onda: empuja a los que estén cerca en el suelo (sin daño)
            for _, p in ipairs(level.players or {}) do
                if alive(p) and math.abs(p.x - self.x) < WAVE_R and math.abs(p.y - self.y) < T * 1.2 and self.graceT <= 0 then
                    p:knockback((p.x >= self.x) and 1 or -1)
                end
            end
            Entity.emitFx('gp_land', self.x, self.markY); Entity.emitFx('shake_small', self.x, self.y)
            Sound.play('gpImpact')
            self:enter('recover')
        end
    elseif st == 'recover' then
        self:hitPlayers(level, HIT_TOUCH, 0)
        if t >= RECOVER_T then self:enter('stalk'); self.restT = every * (0.7 + 0.6 * math.random()) end
    elseif st == 'aim' then
        local shove = self.kind == 'shove'
        -- (mientras avisa viaja con la cámara: si no, la pantalla se lo comería)
        self.x = self.x + a.speed * dt
        self.markX = self.markX + a.speed * dt
        if pa and t < (shove and AIM_SHOVE or AIM_DASH) * 0.6 then self.y = self.y + (pa.y - self.y) * math.min(1, dt * 10); self.markY = self.y end
        if t >= (shove and AIM_SHOVE or AIM_DASH) then self:enter('rush'); Sound.play('mirrorWarp', 1.3) end
    elseif st == 'rush' then
        self.x = self.x + self.dir * RUSH_V * dt
        self:hitPlayers(level, HIT_RUSH, self.dir)
        if self.kind ~= 'shove' then self.markX = a.x - 1.5 * T end       -- (la embestida acaba al salir por el borde de AHORA)
        if (self.dir < 0 and self.x <= self.markX) or (self.dir > 0 and self.x >= self.markX) or t > 1.6 then
            self:enter('stalk'); self.restT = every * (0.7 + 0.6 * math.random())
        end
    end
    return true
end

function Chase:netPack()
    return { math.floor(self.markX or 0), math.floor(self.markY or 0), self.dir or 1, (self.kind == 'dive' and 1) or (self.kind == 'shove' and 3) or 2 }
end
function Chase:netApply(a, b)
    if type(b[1]) ~= 'number' then return end
    self.markX, self.markY, self.dir = b[1], b[2], b[3] or 1
    self.kind = (b[4] == 1 and 'dive') or (b[4] == 3 and 'shove') or 'dash'
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
    Mirror = Mirror or require('src/world/entities/types/mirror').class
    local now = love.timer.getTime()
    local x, y = math.floor(self.x - camX), math.floor(self.y - camY)
    if st == 'warp_out' then return end                                  -- (roto en pedazos: las partículas)
    -- avisos
    if st == 'portal' then
        Mirror.drawMark(math.floor((self.markX or self.x) - camX), math.floor((self.markY or self.y) - camY), now)
        Mirror.drawPortal(x, y, math.min(1, t / 0.2), now)
    elseif st == 'dive' then
        Mirror.drawMark(math.floor(self.markX - camX), math.floor(self.markY - camY), now)
    elseif st == 'aim' or st == 'rush' then
        -- la línea por donde va a pasar (a trazos, parpadea al avisar)
        local x1 = math.floor((self.markX or self.x) - camX)
        local a0, a1 = math.min(x, x1), math.max(x, x1)
        local on = st == 'rush' or math.floor(now * 14) % 2 == 0
        love.graphics.setColor(1, 0.25, 0.35, on and 0.85 or 0.35)
        local off = math.floor(now * 240) % 32
        for xx = a0 - off, a1, 32 do
            local w0, w1 = math.max(a0, xx), math.min(a1, xx + 18)
            if w1 > w0 then love.graphics.rectangle('fill', w0, y - 3, w1 - w0, 6) end
        end
    end
    local fr, sx, sy, dx, dy = 3, 1, 1, 0, 0
    if st == 'stalk' then fr, dy = (math.floor(now * 12) % 3) + 1, math.floor(math.sin(now * 5) * 4)
    elseif st == 'portal' then fr, sx, sy = 5, 0.9, 0.9
    elseif st == 'dive' then fr, sx, sy = 2, 0.85, 1.3
    elseif st == 'recover' then fr, sx, sy = 5, 1.15, 0.85
    elseif st == 'aim' then fr, dx, sx, sy = 5, math.floor(math.sin(now * 70) * 3), 1.1, 0.9
    elseif st == 'rush' then fr, sx, sy = 2, 1.4, 0.8
    elseif st == 'lurk' then dy = math.floor(math.abs(math.sin(now * 9)) * -6) end
    invert()
    local img = frames[fr]
    local f = self.facing or 1
    if st == 'rush' or st == 'dive' or st == 'stalk' then                -- estela
        for i = 3, 1, -1 do
            love.graphics.setColor(1, 1, 1, 0.14 * (4 - i))
            local ox = (st == 'rush') and -(self.dir or -1) * i * 38 or (st == 'stalk' and -i * 12 or 0)
            local oy = (st == 'dive') and -i * 40 or 0
            love.graphics.draw(img, x + ox + dx, y + oy + dy, 0, S * sx * f, S * sy, FW / 2, FH / 2)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, x + dx, y + dy, 0, S * sx * f, S * sy, FW / 2, FH / 2)
    love.graphics.setShader()
end

local G = 'Persecución'
return {
    name = 'mirrorchase', label = 'Espejo perseguidor', category = 'Jefes', class = Chase,
    description = 'El Espejo persiguiendo en un nivel de CÁMARA AUTOMÁTICA: va suelto, se teletransporta y ataca sin parar '
               .. '(cae en picado desde un espejo, cruza la pantalla embistiendo, empuja de frente). No se le puede hacer nada; '
               .. 'cada golpe quita 1 de vida y empuja hacia el borde. El HUD dice ¡CORRE!',
    traits = { diesWithBlock = false, renderFront = true },
    pace = false,                              -- (su ritmo no lo acelera la dificultad aparte)
    hide = 'all', defaults = { movement = 'static' },
    props = {
        { key='rest', kind='number', label='Descanso entre ataques (s)', group=G, default=1.1, min=0.2, max=10, step=0.1,
          help='Cuanto menos, más frenético' },
    },
    editor = { sprite = 'assets/images/player/monstrito3.png', invert = true },
}
