-- La BALANZA: dos platillos colgados de una polea. Lo que pesa más baja su platillo y sube el otro (jugadores 1, la
-- Caja grande 2, la pequeña 1, enemigos 1, `weight` de cada tipo); iguales, vuelven a nivelarse. Un GROUND POUND
-- sobre un platillo lo hunde de golpe y CATAPULTA todo lo que está en el otro (jugadores, cajas, enemigos, bombas…).
-- Funciona en cooperativo (cada jugador pesa).
--   * Se coloca en la casilla de la POLEA (arriba). Props: `span` (casillas entre los centros de los platillos),
--     `drop` (casillas de cuerda con la balanza nivelada), `travel` (cuánto puede bajar / subir cada platillo),
--     `power` (fuerza de la catapulta), `isle` (aspecto: Isles).
--   * Los platillos son PIEZAS sólidas de un solo sentido (se pisan desde arriba) que se MUEVEN (Entities.solidBodies:
--     quien está encima va con ellos). Lo que no es un jugador y está encima lo mueve la balanza.
-- Arte (tools/art/world/make_scale_box.py): assets/images/mechanisms/scale/<isla>-pan.png (48x8), -rope.png (4x8),
-- -pulley-Sheet.png (2 cuadros 16x16). Sonidos scaleCreak (se mueve) y scaleLaunch (catapulta).
-- JEFES en la balanza (0.5.76, el Escarabajo Rinoceronte Gigante; regla de la base, cualquier jefe la usa): un jefe no
-- pesa (Weight), pero si su clase tiene `ridesScale` y está de pie en un platillo VA CON ÉL (sube y baja); un ground pound
-- en el OTRO platillo lo dispara: `onScaleLaunch(vy, scale)`; y un jefe que cae de golpe en un platillo
-- (`Scale.slamUnder(level, boss, power)`) hace lo mismo que un ground pound: dispara lo del otro (jugadores incluidos) y
-- le avisa a quién (`onScaleCatapult(players, ents)`): un arma de doble filo (el usuario).
-- IMPACTOS (0.5.76, el usuario: "para cualquier cosa móvil de balanzas"): lo que CAE DE GOLPE en un platillo (una caja
-- desde lo alto, algo lanzado, una pila…) lo hunde de golpe y el otro sube tan rápido que DISPARA lo que lleve, con más
-- fuerza cuanto más pesa y más rápido cae lo que llega, y con menos cuanto más pesa lo que hay que lanzar
-- (`impactPower`). Un golpe flojo solo inclina la balanza como siempre. El ground pound del jugador va aparte (onPound).
-- SALTAR JUSTO ANTES (0.5.79, el usuario): quien saltó un instante antes de que su platillo saliera disparado ya no
-- estaba "de pie" en él y el platillo, que se atraviesa desde abajo, lo atravesaba (se libraba del arma de doble filo
-- del Escarabajo y de otras mecánicas): la catapulta lanza también a quien está en el aire justo encima (`JUMP_GRACE`)
-- y un platillo que SUBE no atraviesa a un jugador que estaba encima: lo recoge y se lo lleva (`sweepPlayers`).
-- Red: el desnivel (`d`) en su netPack; los platillos se calculan de él.
local Entity = require 'src/world/entities/base/Entity'
local Isles  = require 'src/world/level/Isles'
local Weight = require 'src/world/systems/Weight'

local Scale = Entity.extend(Entity, { debugColor = { 0.9, 0.8, 0.4 },
    hitbox = { outerW = 1, outerH = 1, innerW = 1, innerH = 1 } })

local S        = GUMMY_SCALE
local PAN_W, PAN_H = 48 * S, 8 * S         -- el dibujo del platillo: 3 casillas x media
-- (la TABLA del platillo está en las filas 2-7 del dibujo; las de arriba son la argolla de la cuerda: la caja que se
-- pisa empieza ahí — si no, lo de encima flotaba 8 px: el usuario)
local PLANK_Y, PLANK_H = 2 * S, 6 * S
local SPEED    = 150                       -- px/s: lo que sube / baja un platillo
local SLAM_SPEED = 900                     -- px/s: hundido por un ground pound
local LAUNCH_V = 1.9                       -- × el salto: la catapulta
local CREAK_T  = 0.45
local JUMP_GRACE = 1.5 * TILE_PX           -- px por encima de la tabla: quien está ahí en el aire también sale disparado
local IMPACT_REF = 2 * 1100                -- peso × px/s de caída que dispara con fuerza 1 (la caja grande a 1100 px/s)
local IMPACT_MIN = 0.6                     -- por debajo, el golpe solo inclina
local IMPACT_MAX = 1.6
local IMPACT_VY  = 750                     -- px/s (≈ caer 3 casillas): más despacio no es un golpe

Scale.wantsLevel = true
function Scale.sizePx() return TILE_PX, TILE_PX end

local imgs = {}
local function art(isle)
    if not imgs[isle] then
        local SpriteStrip = require 'src/fx/SpriteStrip'
        local b = 'assets/images/mechanisms/scale/' .. isle
        imgs[isle] = { pan = SpriteStrip.load(b .. '-pan.png', 48), rope = SpriteStrip.load(b .. '-rope.png', 4),
                       pulley = SpriteStrip.load(b .. '-pulley-Sheet.png', 16) }
    end
    return imgs[isle]
end

-- Geometría (también para el editor): centro de cada platillo con desnivel d (px; d > 0 = el izquierdo más abajo)
local function geom(x, y, p, d)
    local half = (p.span or 5) * TILE_PX / 2
    local base = y + (p.drop or 4) * TILE_PX
    return x - half, base + d, x + half, base - d
end

local function panPart(owner, side)
    -- (NO se baja por ellos agachándose — `dropThrough` —: hay que poder dejar cajas encima con cuidado, agachado +
    -- ARRIBA; el usuario, 0.5.69)
    local part = { owner = owner, side = side, solidFull = true, oneway = true, moves = true, alive = true }
    function part:getOuterBounds(into, d)
        local lx, ly, rx, ry = geom(owner.x, owner.y, owner.props, d or owner.d or 0)
        local cx, cy = (side < 0) and lx or rx, (side < 0) and ly or ry
        local b = into or {}
        b.x, b.y, b.w, b.h = cx - PAN_W / 2, cy + PLANK_Y, PAN_W, PLANK_H
        return b
    end
    return part
end

function Scale:init()
    self.moving, self.flying, self.vx, self.vy = false, true, 0, 0
    self.state, self.deadTimer = 'idle', 0
    self.d, self.slamT, self.creakT = 0, 0, 0
    self.pans = self.pans or { panPart(self, -1), panPart(self, 1) }
end
function Scale:bodyParts() return self.pans end
function Scale:canBeStomped() return false end
function Scale:canBeKnocked() return false end
function Scale:canFreeze() return false end
function Scale:isObstacle() return false end
function Scale:interact(pa) return nil end

-- Lo que hay encima de un platillo: jugadores (de pie en él) y entidades apoyadas en su cara
-- ¿Está `e` (sus pies) apoyado en la cara de arriba de la caja `b`?
-- Lo que hay encima de un platillo, APILADO incluido (el usuario: una caja con algo encima pesa las dos cosas): la regla
-- de todos, systems/Weight (jugadores de pie en él o en la pila + lo que llevan; entidades apoyadas; lo que vuela no)
local function onPan(self, pan, level) return Weight.stack(pan, level, self) end

-- Los jefes que van montados en un platillo (`ridesScale` y sus pies en la tabla; uno disparado o en el aire, no)
local RB = {}
local function bossRiders(pan, level)
    local out = {}
    local b = pan:getOuterBounds(RB)
    for _, e in ipairs(level.liveEntities or {}) do
        if e.ridesScale and e.alive and e.def and e.def.boss and (not e.ridesPan or e:ridesPan()) then
            local eb = e:getOuterBounds()
            local foot = eb.y + eb.h
            if math.abs(foot - b.y) <= 6 and eb.x + eb.w > b.x + 8 and eb.x < b.x + b.w - 8 then out[#out + 1] = e end
        end
    end
    return out
end

-- ¿Choca algún platillo al pasar de `d0` a `d`? El que BAJA mira su cara de abajo contra bloques, plataformas y cuerpos
-- sólidos (cajas) que no van en su pila; el que SUBE, su cara de arriba contra bloques y plataformas.
local QB = {}
function Scale:panBlocked(level, d, d0)
    for i, pan in ipairs(self.pans) do
        local down = ((i == 1) and (d - d0) or (d0 - d)) > 0
        local b = pan:getOuterBounds(QB, d)
        local y = down and (b.y + b.h + 1) or (b.y - 1)
        local stack
        -- (el que SUBE no mete lo que lleva encima — una caja — en un jugador que no va montado en ello: lo aplastaba)
        if not down and level.players then
            local rise = math.abs(d - d0)
            local _, ents = onPan(self, pan, level)
            for _, e in ipairs(ents) do
                if e.solidFull then
                    local eb = e:getOuterBounds()
                    for _, pa in ipairs(level.players) do
                        local pb = pa:getOuterBounds()
                        if not pa.dying and pa.standBody ~= e and pb.x < eb.x + eb.w - 1 and pb.x + pb.w > eb.x + 1
                           and pb.y < eb.y - rise + eb.h - 1 and pb.y + pb.h > eb.y - rise + 1
                           and not (pb.y < eb.y + eb.h - 1 and pb.y + pb.h > eb.y + 1) then return true end
                    end
                end
            end
        end
        for x = b.x + 4, b.x + b.w - 4, 16 do
            local t = level:collisionAt(x, y, true) or (level.onewayCellAt and level:onewayCellAt(x, y))
            if t then return true end
            if down then
                local o = level:bodyAt(x, y, pan)
                if o and o.owner ~= self then
                    if not stack then
                        stack = {}
                        local _, ents = onPan(self, pan, level)
                        for _, e in ipairs(ents) do stack[e] = true end
                    end
                    if not stack[o] then return true end
                end
            end
        end
    end
    return false
end

-- Lo de encima del platillo `hit` se hunde de golpe y lo del OTRO sale disparado (× `power`): jugadores (menos
-- `except`), entidades y los jefes montados (`onScaleLaunch`). `by` (un jefe que cayó encima) se entera de a quién
-- disparó (`onScaleCatapult`)
function Scale:catapult(hit, except, power, by)
    local level = self.levelRef
    local other = (hit == self.pans[1]) and self.pans[2] or self.pans[1]
    local players, ents = onPan(self, other, level or {})
    local v = -math.abs(ADV_JUMP_VEL) * LAUNCH_V * (self.props.power or 1) * (power or 1)
    local shot = {}
    for _, p in ipairs(players) do if p ~= except then p:launch(0, v); shot[#shot + 1] = p end end
    -- (quien saltó justo antes: en el aire, encima de la tabla y a menos de JUMP_GRACE, también)
    local ob = other:getOuterBounds()
    for _, p in ipairs((level or {}).players or {}) do
        if p ~= except and not p.dying and p.standBody ~= other then
            local pb = p:getOuterBounds()
            local foot = pb.y + pb.h
            local seen = false
            for _, q in ipairs(shot) do if q == p then seen = true end end
            if not seen and foot <= ob.y + 4 and foot >= ob.y - JUMP_GRACE and pb.x + pb.w > ob.x + 4 and pb.x < ob.x + ob.w - 4 then
                p:launch(0, v); shot[#shot + 1] = p
            end
        end
    end
    for _, e in ipairs(ents) do
        if e.launch and e.canBeLaunched and e:canBeLaunched() then e:launch(e.vx or 0, v)
        else e.vy, e.onGround = v, false end
    end
    for _, e in ipairs(level and bossRiders(other, level) or {}) do
        if e ~= by and e.onScaleLaunch then e:onScaleLaunch(v, self) end
    end
    if by and by.onScaleCatapult then by:onScaleCatapult(shot, ents) end
    self.slamT, self.slamSide = 0.35, hit.side
    self.slamBy, self.slamPower = by, power or 1                          -- (para los que recoge el platillo al subir)
    Sound.play('scaleLaunch')
    local b = other:getOuterBounds()
    Entity.emitFx('gp_start', b.x + b.w / 2, b.y)
    return true
end

-- Un platillo que SUBE no atraviesa a un jugador que estaba ENCIMA de su tabla (en el aire, sin ir montado): lo recoge
-- — los pies en la tabla, subiendo con ella — y, si el platillo va disparado (catapulta), sale disparado
local SB0 = {}
function Scale:sweepPlayers(level, dd, dt)
    for i, pan in ipairs(self.pans) do
        local dy = (i == 1) and dd or -dd
        if dy < 0 then
            local b1 = pan:getOuterBounds()
            local top0 = b1.y - dy                                   -- (la tabla antes de subir)
            local firing = self.slamT > 0 and self.slamSide ~= pan.side       -- (este platillo va disparado: la catapulta)
            local vLaunch = -math.abs(ADV_JUMP_VEL) * LAUNCH_V * (self.props.power or 1) * (self.slamPower or 1)
            local function fire(p)
                p:launch(0, vLaunch)
                local by = self.slamBy
                if by and by.alive and by.onScaleCatapult then by:onScaleCatapult({ p }, {}) end   -- (el golpe contra el techo)
            end
            for _, p in ipairs(level.players or {}) do
                if firing and not p.dying and p.standBody == pan and (p.vy or 0) > vLaunch * 0.8 then   -- (ya disparado: no)
                    -- (se posó en él mientras sube disparado: también sale disparado)
                    fire(p)
                elseif not p.dying and p.standBody ~= pan then
                    local pb = p:getOuterBounds(SB0)
                    local foot = pb.y + pb.h
                    if foot <= top0 + 2 and foot > b1.y and pb.x + pb.w > b1.x + 4 and pb.x < b1.x + b1.w - 4 then
                        p.y = p.y - (foot - b1.y)
                        local vPan = dy / math.max(dt, 1e-3)
                        if firing then
                            if (p.vy or 0) > vLaunch * 0.8 then fire(p) end
                        elseif (p.vy or 0) > vPan then p.vy = vPan end
                    end
                end
            end
        end
    end
end

-- Ground pound (Interactions.run): el que cae sobre un platillo lo hunde y lanza lo del otro
function Scale:onPound(pa, z)
    for _, pan in ipairs(self.pans) do if pa.standBody == pan then return self:catapult(pan, pa, 1, nil) end end
    return false
end

-- El platillo en el que está de pie `e` (sus pies en la tabla): scale, platillo — o nil
function Scale.panUnder(level, e)
    local eb = e:getOuterBounds()
    local foot = eb.y + eb.h
    for _, s in ipairs(level.liveEntities or {}) do
        if s.pans and s.catapult then
            for _, pan in ipairs(s.pans) do
                local b = pan:getOuterBounds()
                if math.abs(foot - b.y) <= 8 and eb.x + eb.w > b.x + 8 and eb.x < b.x + b.w - 8 then return s, pan end
            end
        end
    end
    return nil
end

-- La fuerza del disparo por un golpe: peso que llega × velocidad a la que cae, contra lo que pesa lo del otro platillo
function Scale.impactPower(wIn, vy, wOther)
    if vy < IMPACT_VY then return 0 end
    local k = wIn * vy / IMPACT_REF / math.sqrt(math.max(1, wOther))
    if k < IMPACT_MIN then return 0 end
    return math.min(IMPACT_MAX, k)
end

-- Lo que acaba de posarse en cada platillo y a qué velocidad venía (lastVy: la del paso anterior, antes de posarse)
local function noteVy(self, level)
    self.lastVy = self.lastVy or setmetatable({}, { __mode = 'k' })
    for _, pa in ipairs(level.players or {}) do self.lastVy[pa] = pa.vy or 0 end
    for _, e in ipairs(level.liveEntities or {}) do
        if e ~= self and e.vy then self.lastVy[e] = e.vy end
    end
end
function Scale:impacts(level)
    self.prevOn = self.prevOn or { {}, {} }
    local now = { {}, {} }
    local fired = false
    for i, pan in ipairs(self.pans) do
        local players, ents, w = onPan(self, pan, level)
        local wIn, vIn = 0, 0
        for _, pa in ipairs(players) do
            now[i][pa] = true
            -- (un ground pound ya hace lo suyo: onPound)
            if not self.prevOn[i][pa] and pa.gpPhase ~= 'fall' and not pa.gpLanded then
                local vy = (self.lastVy or {})[pa] or 0
                if vy > IMPACT_VY then wIn, vIn = wIn + require('src/world/systems/Weight').ofPlayer(pa), math.max(vIn, vy) end
            end
        end
        for _, e in ipairs(ents) do
            now[i][e] = true
            if not self.prevOn[i][e] then
                local vy = (self.lastVy or {})[e] or 0
                if vy > IMPACT_VY then wIn, vIn = wIn + Weight.ofEntity(e), math.max(vIn, vy) end
            end
        end
        if wIn > 0 and not fired and self.slamT <= 0 then
            local _, _, wOther = onPan(self, self.pans[3 - i], level)
            local k = Scale.impactPower(wIn, vIn, wOther)
            if k > 0 then self:catapult(pan, nil, k, nil); fired = true end
        end
    end
    self.prevOn = now
end

-- Un jefe cae de golpe en un platillo: como un ground pound (con su fuerza)
function Scale.slamUnder(level, boss, power)
    local s, pan = Scale.panUnder(level, boss)
    if not s then return false end
    s.levelRef = s.levelRef or level
    return s:catapult(pan, nil, power, boss)
end

function Scale:updateCustom(dt, level)
    self.levelRef = level
    self:impacts(level)
    local travel = (self.props.travel or 2.5) * TILE_PX
    local target, speed
    if self.slamT > 0 then
        self.slamT = self.slamT - dt
        target, speed = self.slamSide * -travel, SLAM_SPEED       -- (el golpeado, abajo del todo: izquierdo → d > 0)
    else
        local _, _, wl = onPan(self, self.pans[1], level)
        local _, _, wr = onPan(self, self.pans[2], level)
        target = (wl > wr and travel) or (wr > wl and -travel) or 0
        speed = SPEED * (1 + math.min(2, math.abs(wl - wr)) * 0.25)
    end
    local d0 = self.d
    local riders = { bossRiders(self.pans[1], level), bossRiders(self.pans[2], level) }    -- (antes de moverse)
    local nd = d0
    if d0 < target then nd = math.min(target, d0 + speed * dt)
    elseif d0 > target then nd = math.max(target, d0 - speed * dt) end
    -- los platillos se PARAN si chocan con un bloque, una plataforma o una caja (el usuario: atravesaban el suelo); lo
    -- que va encima de ese platillo no cuenta, y los enemigos sí se atraviesan
    if nd ~= d0 and self:panBlocked(level, nd, d0) then nd = d0 end
    self.d = nd
    local dd = self.d - d0
    if dd ~= 0 then
        self.state = 'moving'
        -- lo que no es un jugador y está encima va con su platillo (los jugadores: standBody)
        for i, pan in ipairs(self.pans) do
            local _, ents = onPan(self, pan, level)
            local dy = (i == 1) and dd or -dd
            for _, e in ipairs(ents) do
                if e.solidFull and dy < 0 then e:moveAndCollide(level, 0, dy) else e.y = e.y + dy end   -- (una caja: con sus choques)
            end
        end
        for i, list in ipairs(riders) do
            for _, e in ipairs(list) do e.y = e.y + ((i == 1) and dd or -dd) end
        end
        self:sweepPlayers(level, dd, dt)
        self.creakT = self.creakT - dt
        if self.creakT <= 0 then Sound.play('scaleCreak'); self.creakT = CREAK_T end
        self.spin = (self.spin or 0) + dd
    else
        self.state, self.creakT = 'idle', 0
    end
    noteVy(self, level)
    return true
end

-- ── Red ───────────────────────────────────────────────────────────────────────
function Scale:netAtRest() return self.d == 0 and self.state == 'idle' end
function Scale:netRest() self.d, self.state = 0, 'idle' end
function Scale:netPack() return { math.floor(self.d + 0.5) } end
function Scale:netApply(a, b, f)
    local da, db = a[1] or 0, b[1] or 0
    self.spin = (self.spin or 0) + ((da + (db - da) * f) - (self.d or 0))
    self.d = da + (db - da) * f
end

-- F1: los platillos
function Scale:debugBoxes()
    local out = {}
    for _, pan in ipairs(self.pans) do
        local b = pan:getOuterBounds()
        out[#out + 1] = { x = b.x, y = b.y, w = b.w, h = b.h, kind = 'area' }
    end
    return out
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
local function drawScale(a, x, y, p, d, spin, camX, camY)
    local lx, ly, rx, ry = geom(x, y, p, d)
    local px, py = math.floor(x - camX), math.floor(y - camY)
    local ropeY = py + 6 * S                            -- (de donde salen las cuerdas: el eje de la polea)
    love.graphics.setColor(1, 1, 1, 1)
    -- la cuerda de arriba, de un lado al otro por encima de la polea (la cuerda tumbada)
    for xx = math.floor(lx - camX), math.floor(rx - camX) - 1, a.rope.h * S do
        a.rope:draw(1, xx + a.rope.h * S / 2, ropeY, math.pi / 2, S, S)
    end
    -- las dos cuerdas, hasta su platillo
    for _, c in ipairs({ { lx, ly }, { rx, ry } }) do
        local cx = math.floor(c[1] - camX)
        local top, bot = ropeY, math.floor(c[2] - camY)
        local step = a.rope.h * S
        for yy = top, bot - 1, step do
            local h = math.min(step, bot - yy)
            if h > 0 then a.rope:draw(1, cx, yy + step / 2, 0, S, S) end
        end
        a.pan:draw(1, cx, math.floor(c[2] - camY) + PAN_H / 2, 0, S, S)
    end
    a.pulley:draw(1 + math.floor(math.abs(spin or 0) / 24) % 2, px, py, 0, S, S)
end

function Scale:render(camX, camY)
    drawScale(art(Isles.of(self.levelRef, self.props.isle)), self.x, self.y, self.props, self.d or 0, self.spin, camX, camY)
end

-- Editor: dónde quedan los platillos (nivelada) y hasta dónde suben / bajan
function Scale.drawEditorOverlay(props, cx, cy, zoom)
    local k = zoom or 1
    local half = (props.span or 5) * TILE_PX / 2 * k
    local base = (props.drop or 4) * TILE_PX * k
    local tr = (props.travel or 2.5) * TILE_PX * k
    local w = PAN_W * k
    love.graphics.setColor(1, 0.85, 0.3, 0.9)
    for _, sx in ipairs({ -1, 1 }) do
        love.graphics.rectangle('line', cx + sx * half - w / 2, cy + base, w, PAN_H * k)
        love.graphics.setColor(1, 0.85, 0.3, 0.35)
        love.graphics.rectangle('line', cx + sx * half - w / 2, cy + base - tr, w, 2 * tr + PAN_H * k)
        love.graphics.setColor(1, 0.85, 0.3, 0.9)
        love.graphics.line(cx, cy, cx + sx * half, cy + base)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return {
    name = 'scale', label = 'Balanza', category = 'Mecanismos', class = Scale,
    description = 'Dos platillos colgados de una polea: lo que pesa más baja. Un ground pound en uno catapulta lo que hay '
               .. 'en el otro. Se coloca en la casilla de la polea.',
    defaults = { movement = 'static' }, hide = 'all',
    props = {
        { key = 'span', kind = 'number', label = 'Separación (casillas)', group = 'Balanza', default = 5, min = 4, max = 16, step = 1,
          help = 'Entre los centros de los dos platillos (cada platillo mide 3)' },
        { key = 'drop', kind = 'number', label = 'Cuerda (casillas)', group = 'Balanza', default = 4, min = 2, max = 12, step = 0.5,
          help = 'De la polea a los platillos con la balanza nivelada' },
        { key = 'travel', kind = 'number', label = 'Recorrido (casillas)', group = 'Balanza', default = 2.5, min = 0.5, max = 8, step = 0.5,
          help = 'Lo que baja un platillo (y sube el otro) cuando un lado pesa más' },
        { key = 'power', kind = 'number', label = 'Catapulta', group = 'Balanza', default = 1, min = 0.3, max = 3, step = 0.05,
          help = 'Fuerza con la que lanza lo del otro platillo un ground pound (1 ≈ 6 casillas de alto)' },
    },
    isleArt = true,
    editor = { sprite = 'assets/images/mechanisms/scale/pradera-pulley-Sheet.png', frameW = 16 },
}
