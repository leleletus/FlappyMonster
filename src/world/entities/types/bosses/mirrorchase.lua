-- EL ESPEJO, PERSIGUIENDO (el nivel de antes del jefe final). No es una pelea: no se le puede hacer nada — solo
-- CORRER. Va SUELTO por el nivel (2ª versión; el usuario: pegado al borde y con una carguita de vez en cuando era
-- "muy fácil" — lo quería libre, teletransportándose, atacando y EMPUJANDO, intenso y frenético): no choca con nada
-- ni le afecta nada del nivel, y encadena ataques con muy poco descanso. Cada golpe quita 1 de vida y, sobre todo,
-- EMPUJA: casi siempre hacia atrás, hacia el borde de la cámara automática (src/world/systems/AutoScroll.lua), que es lo
-- que mata. Sus ataques (los del jefe, a la carrera):
--   · ESPEJO (dive): se rompe, aparece en un espejo flotante SOBRE el jugador (lo sigue y al final se fija; marca
--     en el suelo) y cae en picado: golpe + onda que empuja a los de alrededor.
--   · EMBESTIDA (dash): aparece en el lado DERECHO de la pantalla a la altura del jugador, avisa con una línea y
--     cruza la pantalla entera hacia la izquierda. Se salta.
--   · EMPUJÓN (shove): aparece justo delante del jugador y carga corto contra él.
-- Entre ataques ('stalk') ANDA SUELTO por el nivel como un jugador más (3ª versión; el usuario: que no se quede fijo
-- en la pared izquierda — "que camine por ahí, pase de un lado a otro, suba a plataformas y ataque de forma más
-- orgánica"): corre (más que el jugador) hacia un punto a un lado u otro de él, alternando, salta paredes y huecos,
-- sube a donde esté el jugador (salto alto y doble), y al cruzarse con él lo arrolla y lo empuja. La lava y los
-- pinchos no le hacen nada (sale de un salto). Si se queda atrás, fuera de la pantalla o atascado, se rompe y
-- reaparece junto al jugador. Y también ataca desde donde esté: SALTO (pounce) — brinca por encima y cae en picado.
-- Si alguien muere, se ríe.
--
-- Solo simula en un jugador / el servidor; el cliente dibuja lo que llega (x, y, estado, deadTimer + netPack: la
-- marca, hacia dónde va y qué ataque es). Sin cámara automática en el nivel se queda quieto.
-- Estados: 'lurk' (antes de empezar) → 'stalk' → 'warp_out' → ('portal' → 'dive' → 'recover') | ('aim' → 'rush')
-- → 'stalk' … → 'left' (la carrera acabó: se rompe y desaparece).
local Entity = require 'src/world/entities/base/Entity'
local Boss   = require 'src/world/entities/base/Boss'
local Difficulty = require 'src/core/Difficulty'

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
local HIT_TOUCH = { 0, 560, -320, 0.25, 0 }      -- (tocarlo NO quita vida: solo empuja)
-- RITMO: todo él (andar, saltos, avisos, ataques, descansos) va a SLOW × el `bossPace` de la dificultad
local SLOW    = 0.9
local KINDS   = { 'pounce', 'dash', 'dive', 'shove', 'pounce', 'dash', 'dive' }
local RUN     = 430                  -- px/s andando suelto (el jugador: 240; la cámara: ~160)
local JUMP_H  = { 2.2, 4.3 }         -- casillas: salto normal / salto alto (para subir adonde esté el jugador)
local SIDE_D  = { 3, 6 }             -- a cuántas casillas del jugador va (a un lado y luego al otro)
local STUCK_T = 0.9                  -- s sin avanzar → se teletransporta
local POUNCE_UP = 3.6 * T
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
    self.moving, self.flying, self.vx, self.vy = false, false, 0, 0      -- (anda: la gravedad la lleva él en roam)
    self.state, self.deadTimer = 'lurk', 0
    self.facing = 1
    self.restT = 1.6
    self.kindI, self.kind = 0, 'dive'
    self.markX, self.markY, self.dir = self.x, self.y, 1
    self.graceT = 0
    self.leftBoundPx, self.rightBoundPx = -math.huge, math.huge       -- (sin ruta)
    self.speed = 0
    self.side, self.sideT, self.stuckT, self.jumps = 1, 0, 0, 0
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

-- ANDAR SUELTO: corre hacia un punto a un lado del jugador (y luego al otro), salta lo que haga falta
function Chase:roam(dt, level, a, pa)
    local g = ADV_GRAVITY
    self.sideT = self.sideT - dt
    if self.sideT <= 0 then                                             -- cambia de lado
        self.side = -self.side
        self.sideT = 1.1 + math.random() * 1.3
        self.sideD = (SIDE_D[1] + math.random() * (SIDE_D[2] - SIDE_D[1])) * T
    end
    local tx = (pa and pa.x or (a.x + a.W / 2)) + self.side * (self.sideD or 4 * T)
    tx = math.max(a.x + 1.2 * T, math.min(a.x + a.W - 1.2 * T, tx))     -- dentro de la pantalla
    local dx = tx - self.x
    local dir = (dx > 12) and 1 or (dx < -12) and -1 or 0
    -- (parado en su punto, corre con la cámara para no quedarse atrás)
    local vx = (dir ~= 0) and dir * RUN or a.speed * (self.camK or 1)
    if dir ~= 0 then self.facing = dir end
    self.vy = self.vy + g * dt
    local x0, wasGround = self.x, self.onGround
    self:moveAndCollide(level, vx * dt, self.vy * dt)
    self.vx = vx
    local moved = math.abs(self.x - x0)
    local jump
    if self.onGround then
        self.jumps = 0
        local hw, feet = self.outerW / 2, self.y + self.outerH / 2
        local ahead = self.x + (dir ~= 0 and dir or 1) * (hw + 20)
        local blocked = dir ~= 0 and moved < math.abs(vx * dt) * 0.4
        local gap = dir ~= 0 and not level:isEnemySolidAt(ahead, feet + 8) and not level:isEnemySolidAt(ahead, feet + 8 + T)
        local up = pa and (feet - (pa.y + 40)) > 1.2 * T and math.abs(pa.x - self.x) < 5 * T
        if blocked or up then jump = JUMP_H[2] elseif gap then jump = JUMP_H[1] end
    elseif self.jumps < 2 and self.vy > 0 and dir ~= 0 and moved < math.abs(vx * dt) * 0.4 then
        jump = JUMP_H[2]                                                -- (doble salto contra una pared)
    end
    -- la lava / los pinchos no le hacen nada: sale de un salto
    if self:onDeadlyGround(level) then jump = JUMP_H[2]; self.jumps = 0 end
    if jump then
        self.vy = -math.sqrt(2 * g * jump * T)
        self.onGround = false
        self.jumps = self.jumps + 1
        if not self._quiet then Sound.play('jump', 0.7, 0.6) end
    end
    self.frame = self.onGround and (dir ~= 0 and 6 or 3) or (self.vy < 0 and 2 or 1)
    self:hitPlayers(level, HIT_TOUCH, dir ~= 0 and dir or 0)
    -- atascado, atrás o fuera: se rompe y reaparece junto al jugador
    if dir ~= 0 and moved < 1 then self.stuckT = self.stuckT + dt else self.stuckT = 0 end
    if self.stuckT > STUCK_T or self.x < a.x - 1.5 * T or self.x > a.x + a.W + 2 * T or self.y > level.heightPx + T then
        self.stuckT = 0
        self.kind = 'blink'
        self:enter('warp_out')
        Entity.emitFx('mirror_shards', self.x, self.y)
        Sound.play('mirrorWarp')
    end
end

-- Dónde reaparecer de pie: cerca del jugador (al lado que toque), sobre el primer suelo
function Chase:blinkSpot(level, a, pa)
    local x = (pa and pa.x or (a.x + a.W / 2)) + self.side * 4 * T
    x = math.max(a.x + 2 * T, math.min(a.x + a.W - 2 * T, x))
    local fy = self:floorBelow(level, x, (pa and pa.y or self.y) - 2 * T)
    return x, fy - self.outerH / 2 - 2
end

function Chase:pickAttack(level, a, pa)
    self.kindI = self.kindI % #KINDS + 1
    self.kind = KINDS[self.kindI]
    if self.kind == 'pounce' then                                       -- SALTO: sin romperse, desde donde está
        self.markX, self.markY = pa.x, self:floorBelow(level, pa.x, pa.y)
        self.px0, self.py0 = self.x, self.y
        self.facing = (pa.x >= self.x) and 1 or -1
        self:enter('pounce'); Sound.play('jump', 0.6, 0.9)
        return
    end
    -- (el empujón de frente necesita sitio por delante dentro de la pantalla)
    if self.kind == 'shove' and pa.x + SHOVE_FROM > a.x + a.W - T then self.kind = 'dash' end
    self:enter('warp_out')
    Entity.emitFx('mirror_shards', self.x, self.y)
    Sound.play('mirrorWarp')
end

function Chase:updateCustom(dt, level)
    local a = level.autoScroll
    -- (la cámara NO se frena con él: lo que viaja con ella usa el tiempo real, `self.camK` × su dt)
    local k = SLOW * Difficulty.k('bossPace')
    self.camK = 1 / k
    dt = dt * k
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
        self.vy, self.onGround = 0, false
        Sound.play('mirrorAppear')
    elseif st == 'stalk' then
        self:roam(dt, level, a, pa)
        if self.state ~= 'stalk' then return true end                    -- (se teletransportó)
        self.restT = self.restT - dt
        if self.restT <= 0 and pa and (self.onGround or self.kindI % #KINDS + 1 ~= 1) then self:pickAttack(level, a, pa) end
    elseif st == 'warp_out' then
        if t >= WARP_T then
            if not pa or self.kind == 'blink' then                       -- (solo se recoloca: reaparece andando)
                self.x, self.y = self:blinkSpot(level, a, pa)
                self.vy, self.onGround = 0, false
                self:enter('stalk'); self.restT = math.max(self.restT, 0.5)
                Sound.play('mirrorAppear')
                return true
            end
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
    elseif st == 'pounce' then
        -- brinca en arco hasta encima del jugador (0,45 s) y de ahí cae en picado sobre la marca
        local u = math.min(1, t / 0.45)
        if pa and u < 0.7 then self.markX = self.markX + math.max(-300 * dt, math.min(300 * dt, pa.x - self.markX)) end
        self.markY = self:floorBelow(level, self.markX, (pa and pa.y or self.markY) - T)
        local topY = math.max(1.5 * T, self.markY - self.outerH / 2 - POUNCE_UP)
        self.x = self.px0 + (self.markX - self.px0) * u
        self.y = self.py0 + (topY - self.py0) * (1 - (1 - u) * (1 - u))
        self.frame = 2
        if u >= 1 then self:enter('dive'); Sound.play('gpStart') end
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
        if t >= RECOVER_T then self:enter('stalk'); self.restT = every * (0.7 + 0.6 * math.random()); self.vy, self.onGround = 0, false end
    elseif st == 'aim' then
        local shove = self.kind == 'shove'
        -- (mientras avisa viaja con la cámara: si no, la pantalla se lo comería)
        self.x = self.x + a.speed * dt * self.camK
        self.markX = self.markX + a.speed * dt * self.camK
        if pa and t < (shove and AIM_SHOVE or AIM_DASH) * 0.6 then self.y = self.y + (pa.y - self.y) * math.min(1, dt * 10); self.markY = self.y end
        if t >= (shove and AIM_SHOVE or AIM_DASH) then self:enter('rush'); Sound.play('mirrorWarp', 1.3) end
    elseif st == 'rush' then
        self.x = self.x + self.dir * RUSH_V * dt
        self:hitPlayers(level, HIT_RUSH, self.dir)
        if self.kind ~= 'shove' then self.markX = a.x - 1.5 * T end       -- (la embestida acaba al salir por el borde de AHORA)
        if (self.dir < 0 and self.x <= self.markX) or (self.dir > 0 and self.x >= self.markX) or t > 1.6 then
            self:enter('stalk'); self.restT = every * (0.7 + 0.6 * math.random()); self.vy, self.onGround = 0, false
        end
    end
    return true
end

function Chase:netPack()
    return { math.floor(self.markX or 0), math.floor(self.markY or 0), self.dir or 1, (self.kind == 'dive' and 1) or (self.kind == 'shove' and 3) or 2 }      -- (el cuadro de andar / saltar va en `frame`, que ya viaja)
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
    Mirror = Mirror or require('src/world/entities/types/bosses/mirror').class
    local now = love.timer.getTime()
    local x, y = math.floor(self.x - camX), math.floor(self.y - camY)
    if st == 'warp_out' then return end                                  -- (roto en pedazos: las partículas)
    -- avisos
    if st == 'pounce' then
        Mirror.drawMark(math.floor((self.markX or self.x) - camX), math.floor((self.markY or self.y) - camY), now)
    elseif st == 'portal' then
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
    if st == 'stalk' then fr = (self.frame == 6 and (math.floor(now * 14) % 3) + 1) or (self.frame == 2 and 2) or (self.frame == 1 and ((math.floor(now * 6) % 2 == 0) and 1 or 3)) or 3
    elseif st == 'pounce' then fr, sx, sy = 2, 0.9, 1.15
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
            local ox = (st == 'rush') and -(self.dir or -1) * i * 38 or (st == 'stalk' and -f * i * 12 or 0)
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
               .. 'sus ataques quitan 1 de vida y empujan hacia el borde; tocarlo mientras anda solo empuja. Su ritmo depende de la dificultad. El HUD dice ¡CORRE!',
    traits = { diesWithBlock = false, renderFront = true },
    pace = false,                              -- (la dificultad lo escala DENTRO: ver SLOW; la cámara sigue a su paso)
    hide = 'all', defaults = { movement = 'static' },
    props = {
        { key='rest', kind='number', label='Descanso entre ataques (s)', group=G, default=1.1, min=0.2, max=10, step=0.1,
          help='Cuanto menos, más frenético' },
    },
    editor = { sprite = 'assets/images/player/monstrito3.png', invert = true },
}
