-- La PIRAÑA (types/enemies/piranha.lua; 0.5.96, diseño B «Aguja» elegido por el usuario el 2026-10-29): de la
-- JUNGLA (cualquier nivel con agua puede usarla). Larga y fina como una lanza, con un pico de dientes.
--   · NADA de lado a lado por su agua (nunca sale de ella salvo saltando): se da la vuelta donde se acaba el agua, en
--     un bloque o en el límite de su ruta. Se mantiene bajo la superficie (si el agua baja, baja con ella).
--   · Un jugador FUERA del agua, por encima de la superficie y cerca (a `range` casillas de lado, hasta LEAP_MAX
--     casillas por encima): se acerca a la superficie temblando (el aviso, AIM_T) y SALTA en arco hacia él con la
--     boca abierta; morder (tocarla) quita 1. Cae de nuevo al agua y nada; no vuelve a saltar en `cooldown` s.
--   · Un jugador NADANDO cerca: tras el mismo aviso, se le LANZA en línea recta bajo el agua (LUNGE_T s).
--   · En el AIRE (saltando) se la puede PISAR: muere panza arriba (sube flotando a la superficie si cae al agua). En el
--     agua NO: tocarla, aunque sea desde arriba, hace daño.
--   · Si cae en seco (salta a la orilla, o el agua se va: una inundación que baja) da COLETAZOS ('flop': inofensiva, se
--     la puede pisar); si vuelve a caer al agua, nada; si pasa DRY_T s en seco, se muere. Lava / pinchos: revienta.
-- Todo lo que se dibuja sale de estado + deadTimer + x, y + facing (y del netPack: cuándo llega a lo más alto del
-- salto): igual online. Arte: assets/images/enemies/piranha/piranha-Sheet.png (9 cuadros 22x20 mirando a la DERECHA,
-- el pez centrado en el cuadro) de tools/art/enemies/make_jungle_enemies.py; conjunto assets/anim/enemies/piranha.json.
-- Sonidos: waterSplashOut / waterSplash (los de siempre) y piranhaBite (tools/sounds/jungle_enemies.py).
local Entity       = require 'src/world/entities/base/Entity'
local Interactions = require 'src/world/entities/base/Interactions'

local Piranha = Entity.extend(Entity, {
    debugColor = { 0.2, 0.75, 0.65 },
    deadDuration = 2.0,
    -- (el pez mide ~18 de los 22 px de largo y ~6 de alto)
    hitbox = { outerW = 0.8, outerH = 0.32, innerW = 0.64, innerH = 0.24 },
})

local S          = GUMMY_SCALE
local FW, FH     = 22, 20
local LEAP_MAX   = 5             -- casillas por encima de la superficie: hasta ahí salta
local LEAP_MIN_H = 1.5           -- casillas: el salto más bajo
local LEAP_VX    = 380           -- px/s de lado como mucho
local AIM_T      = 0.35          -- s del aviso (sube a la superficie temblando)
local AIM_V      = 260           -- px/s subiendo a la superficie en el aviso
local SURF_GAP   = 6             -- px del lomo a la superficie al saltar
local LUNGE_V    = 330           -- px/s lanzándose a un jugador que nada
local LUNGE_T    = 0.45
local SINK_K     = 5             -- amortiguación del impulso vertical al volver al agua (1/s)
local DEPTH_V    = 90            -- px/s volviendo a su profundidad
local BOB        = 4             -- px de oscilación nadando
local DRY_T      = 3.5           -- s en seco antes de morirse
local FLOAT_V    = 45            -- px/s: muerta en el agua, sube flotando
local AIR = { leap = true, flop = true }

Piranha.animId = 'enemies/piranha'
Piranha.freezeFloats = true      -- (congelada: el bloque de hielo flota donde estaba)
function Piranha.sizePx() return FW * S, FH * S end

function Piranha:init()
    self.state, self.deadTimer = 'swim', 0
    self.cd, self.apexT, self.dryT, self.hopT = 0, 0, 0, 0
    self.swimY, self.swimT = self.y, 0
    self.vx, self.vy = (self.speed or 70) * (self.facing or 1), 0
    self.props.stompable, self.props.onTouch = true, 'hurt'
end

-- ── Reglas ────────────────────────────────────────────────────────────────────
function Piranha:canBeStomped() return AIR[self.state] == true end
function Piranha:canBeKnocked() return false end
function Piranha:canBeLaunched() return false end
function Piranha:canBePushed() return false end
function Piranha:isObstacle() return false end
function Piranha:canDropNow() return false end
function Piranha:freeOfRoute() return self.state ~= 'swim' end

-- Sin efectos (el cliente predice con esto): en el agua no se la pisa (hace daño); dando coletazos en seco, inofensiva
function Piranha:interact(pa)
    local r, a, b, c = Interactions.defaultCheck(pa, self)
    if r == 'stomp' and not AIR[self.state] then return 'hurt' end
    if self.state == 'flop' and (r == 'hurt' or r == 'kill') then return nil end
    return r, a, b, c
end

function Piranha:onHurtPlayer(pa)
    if pa.recoil then pa:recoil(pa.x >= self.x and 1 or -1) end
end

-- ── El agua ───────────────────────────────────────────────────────────────────
local function wet(level, x, y) return level:liquidAt(x, y) ~= nil and not level:isEnemySolidAt(x, y) end

-- La superficie del agua sobre el punto (la y de su cara de arriba), o nil si el punto no está en el agua
local function surfaceY(level, x, y)
    if not wet(level, x, y) then return nil end
    local yy = y
    for _ = 1, 64 do
        if not wet(level, x, yy - 16) then break end
        yy = yy - 16
    end
    for _ = 1, 4 do if wet(level, x, yy - 4) then yy = yy - 4 end end
    return yy - 2
end
Piranha.surfaceY = surfaceY

-- El jugador al que va: fuera del agua y por encima de la superficie, o nadando cerca. → pa, 'leap' | 'lunge'
function Piranha:target(level, surf)
    local R = (self.props.range or 4.5) * TILE_PX * require('src/core/Difficulty').k('sense')
    local best, bd, how
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false then
            local dx, dy = pa.x - self.x, pa.y - self.y
            if pa.inWater then
                local d = math.sqrt(dx * dx + dy * dy)
                if d <= R and (not bd or d < bd) then best, bd, how = pa, d, 'lunge' end
            elseif surf and math.abs(dx) <= R then
                local pb = pa:getOuterBounds()
                local feet = pb.y + pb.h
                if feet <= surf + 8 and pa.y >= surf - LEAP_MAX * TILE_PX and (not bd or math.abs(dx) < bd) then
                    best, bd, how = pa, math.abs(dx), 'leap'
                end
            end
        end
    end
    return best, how
end

-- ── Update ────────────────────────────────────────────────────────────────────
function Piranha:startLeap(level, pa)
    local g, T = ADV_GRAVITY, TILE_PX
    local H = math.max(LEAP_MIN_H * T, math.min(self.y - pa.y + 24, (LEAP_MAX + 0.5) * T))
    self.vy = -math.sqrt(2 * g * H)
    self.apexT = -self.vy / g
    self.vx = math.max(-LEAP_VX, math.min(LEAP_VX, (pa.x - self.x) / self.apexT))
    -- (nunca se tira a la orilla: acorta el salto hasta que caiga en su agua — vuelve a su altura en 2·apexT —)
    local vx = self.vx
    for _, k in ipairs({ 1, 0.75, 0.5, 0.25, 0 }) do
        self.vx = vx * k
        local lx, hw = self.x + self.vx * 2 * self.apexT, self.outerW / 2 + 4
        if wet(level, lx - hw, self.y) and wet(level, lx + hw, self.y) then break end    -- (todo el cuerpo, no la orilla)
    end
    if math.abs(self.vx) > 4 then self.facing = (self.vx > 0) and 1 or -1 end
    self.state, self.deadTimer, self.bit, self.onGround = 'leap', 0, false, false
    Sound.play('waterSplashOut', 1.2, 0.8)
    Entity.emitFx('water_splash', self.x, self.y - self.outerH / 2)
end

function Piranha:backToWater(level)
    self.state, self.deadTimer, self.cd, self.dryT = 'swim', 0, self.props.cooldown or 1.4, 0
    self.vx = (self.speed or 70) * (self.facing or 1)
    self.vy = math.min(self.vy or 0, 260)
    local s = surfaceY(level, self.x, self.y)
    Sound.play('waterSplash', 1.3, 0.8)
    Entity.emitFx('water_splash', self.x, s or self.y)
end

-- Se queda en seco (cae y coletea)
function Piranha:goDry()
    self.state, self.deadTimer, self.onGround, self.hopT = 'flop', 0, false, 0.15
end

function Piranha:updateSwim(dt, level)
    local st = self.state
    local surf = surfaceY(level, self.x, self.y)
    if not surf then self:goDry(); return end
    -- su profundidad: la de siempre, pero siempre bajo la superficie (si el agua baja, baja con ella)
    local minY = surf + self.outerH / 2 + SURF_GAP
    local depth = math.max(self.swimY, minY)
    self.swimT = self.swimT + dt
    if st == 'swim' then
        local dir = self.facing or 1
        local ax = self.x + dir * (self.outerW / 2 + 4)
        if not wet(level, ax, self.y) or ax >= self.rightBoundPx or ax <= self.leftBoundPx then
            dir = -dir; self.facing = dir
        end
        self.vx = (self.speed or 70) * dir
        local nx = self.x + self.vx * dt
        if wet(level, nx + dir * self.outerW / 2, self.y) then self.x = nx end
        -- el impulso del salto se apaga; luego vuelve a su profundidad con una oscilación
        if math.abs(self.vy) > 1 then
            local ny = self.y + self.vy * dt
            if wet(level, self.x, ny + self.outerH / 2) and ny >= minY then self.y = ny else self.vy = 0 end
            self.vy = self.vy * math.max(0, 1 - SINK_K * dt)
        else
            local ty = depth + math.sin(self.swimT * 2.2) * BOB
            local dy = math.max(-DEPTH_V * dt, math.min(DEPTH_V * dt, ty - self.y))
            if wet(level, self.x, self.y + dy + (dy > 0 and self.outerH / 2 or -self.outerH / 2)) or dy < 0 then
                self.y = math.max(self.y + dy, minY - 2)
            end
        end
        if self.cd <= 0 then
            local pa = self:target(level, surf)
            if pa then
                self.state, self.deadTimer, self.aimAt = 'aim', 0, pa
                self.facing = (pa.x >= self.x) and 1 or -1
            end
        end
    elseif st == 'aim' then
        local pa, how = self:target(level, surf)
        if pa then self.facing = (pa.x >= self.x) and 1 or -1 end
        if how ~= 'lunge' then                                  -- (para saltar, sube a la superficie)
            self.y = math.max(minY - 2, self.y - AIM_V * dt)
        end
        if self.deadTimer >= AIM_T then
            if not pa then self.state, self.deadTimer = 'swim', 0
            elseif how == 'lunge' then
                local dx, dy = pa.x - self.x, pa.y - self.y
                local d = math.max(1, math.sqrt(dx * dx + dy * dy))
                self.lx, self.ly = dx / d * LUNGE_V, dy / d * LUNGE_V
                self.state, self.deadTimer = 'lunge', 0
                Sound.play('piranhaBite', 1, 0.8)
            else
                self:startLeap(level, pa)
            end
        end
    elseif st == 'lunge' then
        local nx, ny = self.x + self.lx * dt, self.y + self.ly * dt
        if wet(level, nx + (self.lx > 0 and 1 or -1) * self.outerW / 2, self.y) then self.x = nx end
        if wet(level, self.x, ny + (self.ly > 0 and 1 or -1) * self.outerH / 2) and ny >= minY - 2 then self.y = ny end
        if math.abs(self.lx) > 4 then self.facing = (self.lx > 0) and 1 or -1 end
        if self.deadTimer >= LUNGE_T then
            self.state, self.deadTimer, self.cd, self.vy = 'swim', 0, self.props.cooldown or 1.4, 0
            self.swimY = math.max(self.swimY, minY)
        end
    end
end

function Piranha:updateCustom(dt, level)
    self.levelRef = level
    if self.state == 'walk' or self.state == 'idle' then self.state, self.deadTimer = 'swim', 0 end   -- (al reaparecer)
    local st = self.state
    if self.cd > 0 then self.cd = math.max(0, self.cd - dt) end
    self.deadTimer = self.deadTimer + dt
    local t = self.deadTimer

    if st == 'swim' or st == 'aim' or st == 'lunge' then
        self:updateSwim(dt, level)
        return true

    elseif st == 'leap' then
        local vx = self.vx
        self.vy = self.vy + ADV_GRAVITY * dt
        local x0 = self.x
        self:moveAndCollide(level, vx * dt, self.vy * dt)
        self.vx = vx
        if vx ~= 0 and math.abs(self.x - x0) < math.abs(vx * dt) * 0.5 then self.vx = 0 end      -- (una pared: cae recto)
        if not self.bit and t >= self.apexT * 0.8 then
            self.bit = true
            Sound.play('piranhaBite')
        end
        if t > 0.1 and self:onDeadlyGround(level) then self:dieBurst(); return true end
        if t > 0.12 and self.vy > 0 and wet(level, self.x, self.y) then self:backToWater(level); return true end
        if self.onGround then self:goDry()
        elseif self:fellOut(level) then self.alive = false end
        return true

    elseif st == 'flop' then
        self.dryT = self.dryT + dt
        self.vy = math.min(self.vy + ADV_GRAVITY * dt, 900)
        local was = self.onGround
        self:moveAndCollide(level, self.vx * dt, self.vy * dt)
        if wet(level, self.x, self.y) then self:backToWater(level); return true end
        if self:onDeadlyGround(level) or self:inVoid(level) then self:dieBurst(); return true end
        if self:fellOut(level) then self.alive = false; return true end
        if self.dryT >= DRY_T then
            self.state, self.deadTimer, self.vx, self.vy = 'dead', 0, 0, 0
            Sound.play('enemyExplode', 1.4, 0.4)
            return true
        end
        if self.onGround then
            if not was then self.vx = self.vx * 0.3 end
            -- coletazos: botes cortos al azar, cada vez más cansados
            self.hopT = self.hopT - dt
            if self.hopT <= 0 then
                local tired = 1 - 0.5 * math.min(1, self.dryT / DRY_T)
                self.vy = -(240 + math.random() * 280) * tired
                self.vx = (math.random() * 2 - 1) * 150 * tired
                self.facing = (math.random() < 0.5) and -1 or 1
                self.onGround = false
                self.hopT = 0.2 + math.random() * 0.3
                Sound.play('kingHop', 2.6, 0.3)
            end
        end
        return true
    end
    return false
end

-- Muerta: panza arriba; en el agua sube flotando hasta la superficie, en el aire cae
function Piranha:onDead(dt)
    local level = self.levelRef
    if not level then return end
    local s = surfaceY(level, self.x, self.y)
    if s then
        self.vy = 0
        if self.y - self.outerH / 2 > s + 2 then self.y = self.y - FLOAT_V * dt end
    else
        self.vy = math.min((self.vy or 0) + ADV_GRAVITY * dt, 900)
        self:moveAndCollide(level, 0, self.vy * dt)
    end
end

-- ── Red: cuándo llega a lo más alto del salto (para el cuadro) ────────────────
function Piranha:netPack() return { math.floor((self.apexT or 0) * 100 + 0.5) } end
function Piranha:netApply(a, b) self.apexT = (tonumber(b[1]) or 0) / 100 end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
function Piranha:render(camX, camY)
    local st, t = self.state, self.deadTimer or 0
    if st == 'reserve' or st == 'dead_burst' then return end
    local set = self:anims()
    local f = self.facing or 1
    local x, y = math.floor(self.x - camX), math.floor(self.y - camY)
    local fr, r, sy, a = nil, 0, 1, 1
    if st == 'leap' then
        local ap = self.apexT or 0.4
        if t < ap * 0.75 then fr = set:frameAt('leap', t)
        elseif t < ap * 1.2 then fr = set:frameAt('bite', t - ap * 0.75)
        else fr = set:frameAt('fall', 0) end
    elseif st == 'lunge' then fr = set:frameAt('bite', t)
    elseif st == 'aim' then
        fr = set:frameAt('swim', t * 3)
        x = x + ((math.floor(t * 30) % 2 == 0) and S or 0)                     -- (tiembla: el aviso)
    elseif st == 'flop' then
        fr = set:frameAt('swim', t * 4)
        r = math.sin(t * 23) * 0.5
    elseif st == 'dead' or st == 'dead_fling' then
        fr = set:frameAt('dead', 0)
        a = math.max(0, 1 - math.max(0, t - self.tuning.deadDuration * 0.5) / (self.tuning.deadDuration * 0.5))
        if st == 'dead_fling' then r = t * 10 * f end
    else
        fr = set:frameAt('swim', love.timer.getTime() + (self.home and self.home.x or 0) * 0.01)
    end
    love.graphics.setColor(1, 1, 1, a)
    set:drawFrame(fr, x, y, r, S * f, S * sy, 0.5, 0.5)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Editor: alcance (de lado) y altura del salto al seleccionarla
function Piranha.drawEditorOverlay(props, cx, cy, zoom)
    local r = (props.range or 4.5) * TILE_PX
    love.graphics.setColor(0.2, 0.8, 0.7, 0.8)
    love.graphics.setLineWidth(2 / zoom)
    love.graphics.rectangle('line', cx - r, cy - LEAP_MAX * TILE_PX, 2 * r, LEAP_MAX * TILE_PX + TILE_PX / 2)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawIcon(x, y, s)
    local c = require('src/fx/Anim').clip('enemies/piranha', 'swim')
    c:drawPx(1, x, y + (s - s * c.h / c.w) / 2, 0, s / c.w, s / c.w)
end

local G = 'Piraña'
return {
    name = 'piranha', label = 'Piraña', category = 'Enemigos', class = Piranha,
    description = 'De la jungla (vale en cualquier agua). Nada de lado a lado por su agua. Si estás FUERA del agua por '
               .. 'encima y cerca, sube temblando y SALTA en arco hacia ti (morder: 1 de vida); si nadas cerca, se te '
               .. 'lanza bajo el agua. En el AIRE se la puede pisar; en el agua, no (hace daño). En seco coletea y, si '
               .. 'no vuelve al agua, se muere.',
    traits = { wantsLevel = true },
    -- (movement = 'walk' solo para que el editor enseñe la RUTA: nada con su propio movimiento)
    defaults = { movement = 'walk', speed = 70, points = 20, onTouch = 'hurt', pauses = false },
    hide = { 'movement', 'attach', 'turnAtEdges', 'flyMode', 'flyRange', 'bobAmp', 'pauses', 'dropOnSight', 'detectRange',
             'onTouch', 'stompable' },
    props = {
        { key = 'range', kind = 'number', label = 'Salta a (casillas de lado)', group = G, default = 4.5, min = 1, max = 15,
          step = 0.5, help = 'Salta hacia un jugador fuera del agua a esta distancia de lado (y hasta 5 casillas por encima de la superficie)' },
        { key = 'cooldown', kind = 'number', label = 'Descanso (s)', group = G, default = 1.4, min = 0.3, max = 10, step = 0.1,
          help = 'Tras un salto, lo que nada antes de poder saltar otra vez' },
    },
    editor = { draw = drawIcon },
}
