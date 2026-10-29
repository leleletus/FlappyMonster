-- La PIRAÑA (types/enemies/piranha.lua; 0.5.96, diseño B «Aguja» elegido por el usuario el 2026-10-29): de la
-- JUNGLA (cualquier nivel con agua puede usarla). Larga y fina como una lanza, con un pico de dientes.
--   · NADA COMO EL PEZ GLOBO (0.5.97, el usuario): explora libremente su ÁREA DE NADO (prop `area`, un polígono; sin
--     ella, 4 casillas a cada lado y 2 arriba y abajo de donde se colocó) eligiendo destinos a los que se llega en línea
--     recta por agua libre (base/Swimmer.lua; ella NO atraviesa bloques). Se mantiene bajo la superficie (si el agua
--     baja, baja con ella); nunca sale del agua salvo saltando.
--   · Un jugador FUERA del agua, por encima de la superficie y cerca (a `range` casillas de lado, hasta LEAP_MAX
--     casillas por encima): se acerca a la superficie temblando (el aviso, AIM_T) y SALTA en arco hacia él con la
--     boca abierta; morder (tocarla) quita 1. Cae de nuevo al agua y nada; no vuelve a saltar en `cooldown` s.
--   · Un jugador NADANDO cerca: tras el mismo aviso, se le LANZA en línea recta bajo el agua (LUNGE_T s).
--   · Se la puede PISAR en el aire Y en el agua (0.5.97, el usuario: si no, era injusto): muere panza arriba (sube
--     flotando a la superficie si está en el agua). De lado o por debajo, morder hace daño.
--   · REBOTA AL MORDER (0.5.97, el usuario: "por la inercia del salto acaba debajo del jugador y muere aplastada sin que
--     el jugador haga nada"): tras morder saltando sale despedida HACIA ATRÁS (al revés de su salto: REB_VX de lado,
--     REB_VY hacia arriba, acortado para que caiga en su agua) en el estado 'rebound'; los primeros REB_INV s no se la
--     puede pisar (pisarla = rebotas, como el Escarabajo recién volcado) ni muerde. Luego cae al agua y nada.
--   · Si cae en seco (se pasa de un salto, o el agua se va: una inundación que baja) hace LO MISMO QUE EL PEZ GLOBO
--     (base/Swimmer.lua): cae ('dry_fall'), da coletazos ('dry_flop': inofensiva, se la puede pisar); si vuelve a caer
--     al agua, nada; si pasa `dryTime` s (5) en seco, se muere ('dry_die', panza arriba). Lava / pinchos: revienta.
-- Todo lo que se dibuja sale de estado + deadTimer + x, y + facing (y del netPack: cuándo llega a lo más alto del
-- salto): igual online. Arte: assets/images/enemies/piranha/piranha-Sheet.png (9 cuadros 22x20 mirando a la DERECHA,
-- el pez centrado en el cuadro) de tools/art/enemies/make_jungle_enemies.py; conjunto assets/anim/enemies/piranha.json.
-- Sonidos: waterSplashOut / waterSplash (los de siempre) y piranhaBite (tools/sounds/jungle_enemies.py).
local Entity       = require 'src/world/entities/base/Entity'
local Interactions = require 'src/world/entities/base/Interactions'
local Swimmer      = require 'src/world/entities/base/Swimmer'

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
local BOB        = 4             -- px de oscilación nadando
local FLOAT_V    = 45            -- px/s: muerta en el agua, sube flotando
local DRY = Swimmer.DRY          -- (en seco: base/Swimmer.lua)
local SWIM = { swim = true, aim = true, lunge = true }
local REB_VX     = 200           -- px/s de lado al rebotar tras morder (al revés de su salto)
local REB_VY     = 300           -- px/s hacia arriba al rebotar
local REB_INV    = 0.4           -- s del rebote en los que no se la puede pisar (ni muerde)
local AIR = { leap = true, rebound = true }

Piranha.animId = 'enemies/piranha'
Piranha.freezeFloats = true      -- (congelada: el bloque de hielo flota donde estaba)
function Piranha.sizePx() return FW * S, FH * S end

function Piranha:init()
    self.state, self.deadTimer = 'swim', 0
    self.cd, self.apexT = 0, 0
    self.vx, self.vy = 0, 0
    self.swimBob, self.swimFallback = BOB, { 4, 2 }        -- (base/Swimmer.lua: oscilación, área sin `area`)
    self.dryDeadly = true                                  -- (en seco: pinchos / lava / vacío la revientan)
    self.dryDieSound = { 'enemyExplode', 1.4, 0.4 }
    Swimmer.init(self)
    self.props.stompable, self.props.onTouch = true, 'hurt'
end

local wet                        -- (abajo: ¿agua libre en ese punto?)

-- ── Reglas ────────────────────────────────────────────────────────────────────
function Piranha:canBeStomped() return self.state ~= 'dry_die' end
function Piranha:canBeKnocked() return false end
function Piranha:canBeLaunched() return false end
function Piranha:canBePushed() return false end
function Piranha:isObstacle() return false end
function Piranha:canDropNow() return false end
function Piranha:freeOfRoute() return true end
-- La Planta carnívora solo se la come FUERA del agua (saltando, en seco)
function Piranha:canBeEaten() return (AIR[self.state] or (DRY[self.state] and self.state ~= 'dry_die')) and Entity.canBeEaten(self) end

-- Sin efectos (el cliente predice con esto, con el estado y el deadTimer de la instantánea): se la pisa en el aire y
-- en el agua; dando coletazos en seco, inofensiva; rebotando tras morder, ni muerde ni se la pisa (los REB_INV s)
function Piranha:interact(pa)
    local r, a, b, c = Interactions.defaultCheck(pa, self)
    if DRY[self.state] and (r == 'hurt' or r == 'kill') then return nil end
    if self.state == 'rebound' then
        if r == 'hurt' or r == 'kill' then return nil end
        if r == 'stomp' and (self.deadTimer or 0) < REB_INV then
            return 'bounce', a, (pa.x >= self.x) and 1 or -1
        end
    end
    return r, a, b, c
end

function Piranha:onHurtPlayer(pa)
    if pa.recoil then pa:recoil(pa.x >= self.x and 1 or -1) end
    if self.state == 'leap' then self:rebound(pa) end
end

-- Tras morder saltando: sale despedida HACIA ATRÁS (al revés de su salto; si saltó recto, lejos del jugador), un poco
-- hacia arriba, acortado para caer en su agua (la de donde saltó: leapY)
function Piranha:rebound(pa)
    local dir
    if math.abs(self.vx or 0) > 4 then dir = (self.vx > 0) and -1 or 1
    else dir = (self.x >= pa.x) and 1 or -1 end
    local level = self.levelRef
    local g, vy = ADV_GRAVITY, -REB_VY
    local y0 = self.leapY or (self.y + TILE_PX)
    -- (cuándo vuelve a la altura de la que saltó: y + vy·t + g·t²/2 = y0)
    local dy = math.max(0, y0 - self.y)
    local tl = (-vy + math.sqrt(vy * vy + 2 * g * dy)) / g
    local vx = dir * REB_VX
    if level then
        local hw = self.outerW / 2 + 4
        for _, k in ipairs({ 1, 0.7, 0.4, 0.15, 0 }) do
            local lx = self.x + vx * k * tl
            if wet(level, lx - hw, y0) and wet(level, lx + hw, y0) then vx = vx * k; break end
            if k == 0 then vx = 0 end
        end
    end
    self.vx, self.vy, self.onGround = vx, vy, false
    self.state, self.deadTimer, self.bit = 'rebound', 0, true
end

-- ── El agua ───────────────────────────────────────────────────────────────────
function wet(level, x, y) return level:liquidAt(x, y) ~= nil and not level:isEnemySolidAt(x, y) end

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
    self.leapY = self.y                                       -- (su agua: el rebote tras morder vuelve a ella)
    Sound.play('waterSplashOut', 1.2, 0.8)
    Entity.emitFx('water_splash', self.x, self.y - self.outerH / 2)
end

-- De vuelta al agua (tras un salto, o en seco: Swimmer.updateDry) — nada otra vez
function Piranha:onBackToWater(level)
    self.state, self.deadTimer, self.cd, self.dryT = 'swim', 0, self.props.cooldown or 1.4, 0
    self.vy = math.min(self.vy or 0, 260)
    Swimmer.sync(self)
    local s = surfaceY(level, self.x, self.y)
    -- (el centro SIN la oscilación, bajo la superficie: con la oscilación hacia arriba quedaba fuera — en seco — y al
    -- caer volvía aquí, sin fin: se quedaba temblando en la superficie)
    if s then self.py = math.max(self.py, s + self.outerH / 2 + 2) end
    Sound.play('waterSplash', 1.3, 0.8)
    Entity.emitFx('water_splash', self.x, s or self.y)
end
function Piranha:backToWater(level) self:onBackToWater(level); Swimmer.pickTarget(self) end

-- Se queda en seco (cae y coletea, como el pez globo)
function Piranha:goDry()
    Swimmer.sync(self)
    Swimmer.goDry(self)
end

function Piranha:updateSwim(dt, level)
    local st = self.state
    local surf = surfaceY(level, self.x, self.y)
    if not surf or Swimmer.isDry(self, level) then self:goDry(); return end
    local minY = surf + self.outerH / 2 + SURF_GAP           -- (saltando: el lomo justo bajo la superficie)
    if st == 'swim' then
        Swimmer.move(self, dt, level, true)                    -- (explora su área: base/Swimmer.lua)
        if self.cd <= 0 then
            local pa = self:target(level, surf)
            if pa then
                self.state, self.deadTimer, self.aimAt = 'aim', 0, pa
                self.facing = (pa.x >= self.x) and 1 or -1
            end
        end
        return
    end
    self.swimT = self.swimT + dt
    if st == 'aim' then
        local pa, how = self:target(level, surf)
        if pa then self.facing = (pa.x >= self.x) and 1 or -1 end
        if how ~= 'lunge' then                                  -- (para saltar, sube a la superficie)
            self.y = math.max(minY - 2, self.y - AIM_V * dt)
        end
        Swimmer.sync(self)
        if self.deadTimer >= AIM_T then
            if not pa then self.state, self.deadTimer = 'swim', 0; self.vx, self.vy = 0, 0
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
        Swimmer.sync(self)
        if self.deadTimer >= LUNGE_T then
            self.state, self.deadTimer, self.cd = 'swim', 0, self.props.cooldown or 1.4
            self.vx, self.vy = self.lx * 0.3, self.ly * 0.3
            Swimmer.pickTarget(self)
        end
    end
end

function Piranha:updateCustom(dt, level)
    Swimmer.ready(self, level)
    if self.state == 'walk' or self.state == 'idle' then self.state, self.deadTimer = 'swim', 0 end   -- (al reaparecer)
    local st = self.state
    if self.cd > 0 then self.cd = math.max(0, self.cd - dt) end
    self.deadTimer = self.deadTimer + dt
    local t = self.deadTimer

    if SWIM[st] then
        self:updateSwim(dt, level)
        return true

    elseif AIR[st] then                                         -- (saltando, o rebotando tras morder)
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

    elseif DRY[st] then
        Swimmer.updateDry(self, dt, level)
        if DRY[self.state] or self.state == 'dead' then self.x, self.y = self.px, self.py end
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
    if st == 'rebound' then                                     -- (despedida hacia atrás tras morder: el morro arriba)
        fr = set:frameAt('bite', t)
        r = -f * math.min(0.5, t * 3)
    elseif st == 'leap' then
        local ap = self.apexT or 0.4
        if t < ap * 0.75 then fr = set:frameAt('leap', t)
        elseif t < ap * 1.2 then fr = set:frameAt('bite', t - ap * 0.75)
        else fr = set:frameAt('fall', 0) end
    elseif st == 'lunge' then fr = set:frameAt('bite', t)
    elseif st == 'aim' then
        fr = set:frameAt('swim', t * 3)
        x = x + ((math.floor(t * 30) % 2 == 0) and S or 0)                     -- (tiembla: el aviso)
    elseif st == 'dry_die' then                                 -- (en seco, muerta: panza arriba y se desvanece)
        local _, _, _, al = Swimmer.dryPose(self)
        fr, a = set:frameAt('dead', 0), al
    elseif DRY[st] then                                         -- (coletazos: como el pez globo, base/Swimmer.lua)
        local at, rot = Swimmer.dryPose(self)
        fr, r = set:frameAt('swim', at), rot
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
function Piranha.drawEditorOverlay(props, cx, cy, zoom, ctx)
    Swimmer.drawArea(props, ctx, zoom)
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
    description = 'De la jungla (vale en cualquier agua). Explora su área de nado como el pez globo (sin atravesar '
               .. 'bloques). Si estás FUERA del agua por encima y cerca, sube temblando y SALTA en arco hacia ti (morder: '
               .. '1 de vida); si nadas cerca, se te lanza bajo el agua. Se la puede pisar (en el aire y en el agua); de '
               .. 'lado muerde. En seco coletea y, si no vuelve al agua, se muere (como el pez globo).',
    traits = { wantsLevel = true },
    -- (nada con su propio movimiento, por su área: la ruta no cuenta)
    defaults = { movement = 'walk', speed = 70, points = 20, onTouch = 'hurt', pauses = false },
    hide = { 'movement', 'attach', 'patrol', 'turnAtEdges', 'flyMode', 'flyRange', 'bobAmp', 'pauses', 'dropOnSight',
             'detectRange', 'onTouch', 'stompable' },
    props = {
        Swimmer.areaProp(G, 'Contorno de su agua (puede ser irregular): la explora entera sin atravesar bloques ni salir del agua'),
        { key = 'range', kind = 'number', label = 'Salta a (casillas de lado)', group = G, default = 4.5, min = 1, max = 15,
          step = 0.5, help = 'Salta hacia un jugador fuera del agua a esta distancia de lado (y hasta 5 casillas por encima de la superficie)' },
        { key = 'cooldown', kind = 'number', label = 'Descanso (s)', group = G, default = 1.4, min = 0.3, max = 10, step = 0.1,
          help = 'Tras un salto, lo que nada antes de poder saltar otra vez' },
        Swimmer.dryTimeProp(G),
    },
    editor = { draw = drawIcon },
}
