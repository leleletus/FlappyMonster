-- El ICEBERG (témpano): un bloque de hielo que FLOTA en la superficie del agua de su columna — agua de casillas o de una
-- inundación: sube y baja con ella (marea, inundación); sin agua se queda en el fondo —, se mece un poco y se HUNDE algo
-- con lo que lleva encima (systems/Weight: jugadores, cajas, escarabajos cargados, enemigos). Con más peso del que
-- aguanta (`capacity`) avisa (tiembla y cruje WARN_T s) y se HUNDE bajo el agua (lo de encima se moja: agua helada…);
-- al quitarle el peso vuelve a flotar. Es un cuerpo sólido que se mueve (Entities.solidBodies: quien está encima va con
-- él; lo que no es un jugador lo lleva él).
--   * NO se mueve solo (el usuario, 2026-10-29: ni deriva ni se agrieta): de lado solo se mueve si lo EMPUJAN (andando o
--     nadando contra él, o empujando una caja contra él: la regla de la Caja, `pushBy`) o lo SOPLA el aire (systems/Push:
--     Soplón, Ventisca…), y luego se desliza con el ROCE del agua hasta pararse; choca con paredes y otros icebergs.
--   * Hereda de la Caja (types/items/box.lua) lo de empujar en fila según el peso, la predicción del cliente que empuja y
--     el no meterse NUNCA dentro de un jugador (Box:moveAndCollide).
--   * Se coloca en su casilla de ARRIBA a la IZQUIERDA. Props: `width` / `height` (casillas), `capacity` (peso que
--     aguanta sin hundirse: un jugador pesa 1, la caja grande 2), `float` (casillas que asoma vacío), `sinkDepth` (casillas
--     bajo la superficie cuando se hunde).
-- Arte (tools/art/world/make_iceberg.py): assets/images/mechanisms/iceberg/h<alto>-w<ancho>-<1|2>.png (16 px de arte por
-- casilla). Sonidos icebergCreak (aviso) e icebergSink (se hunde), de tools/sounds/iceberg.py.
-- Red: x, y y el estado van en la instantánea; el netPack es el de la Caja (quién la empuja y su factor de empuje).
local Entity = require 'src/world/entities/base/Entity'
local Box    = require('src/world/entities/types/items/box')[1].class
local Weight = require 'src/world/systems/Weight'
local Push   = require 'src/world/systems/Push'

local Iceberg = Entity.extend(Box, { debugColor = { 0.6, 0.9, 1 },
    hitbox = { outerW = 1, outerH = 1, innerW = 1, innerH = 1 } })

local T, S       = TILE_PX, GUMMY_SCALE
local K_SPRING   = 36          -- 1/s²: lo que tira el agua hacia su línea de flotación
local C_DAMP     = 7           -- 1/s: amortiguación (cabecea un poco al caer y se asienta)
local LOAD_SINK  = 0.75        -- con su `capacity` encima asoma solo el 25 % de lo que asoma vacío
local DIP        = 70          -- px/s por unidad de peso que se le sube encima (el "chof" al posarse)
local POUND_DIP  = 260         -- px/s: un ground pound encima lo hunde de golpe un momento
local BOB_A, BOB_W = 2, 2.4    -- px, rad/s: el cabeceo en reposo
local WARN_T     = 0.7         -- s de aviso antes de hundirse
local RISE_DELAY = 0.35        -- s sin sobrepeso antes de volver a flotar
local SINK_VMAX  = 150         -- px/s: lo más rápido que se hunde (quien va encima baja con él)
local VMAX       = 520
local DRAG       = 0.9         -- 1/s: el roce del agua de lado (se desliza y se para)
local WIND_K     = 0.45        -- × la velocidad del aire: a lo que lo lleva el viento (sin peso encima)
local WIND_RATE  = 1.5         -- 1/s: lo que tarda en coger esa velocidad (inercia)
local GROUND_FRIC = 14         -- 1/s: varado en el fondo, frena en seco

Iceberg.denseProbe = true      -- (ancho: choca mirando cada media casilla — Entity:moveAndCollide —)
Iceberg.pushInWater = true     -- (se empuja también nadando contra él — PlayerCollision, Box:pushBy —)
Iceberg.weight = 2             -- (empujarlo cuesta como la caja grande; con gente encima, más: Weight)
Iceberg.ridesMoving = false    -- (de la Caja: él no sigue solo al cuerpo de debajo; si va encima de algo, lo lleva ese algo)
Iceberg.wantsLevel = true

local function clampi(v, lo, hi) return math.max(lo, math.min(hi, math.floor((tonumber(v) or lo) + 0.5))) end
Iceberg.MAX_W, Iceberg.MAX_H = 8, 3

function Iceberg.sizePx() return T, T end

local imgs = {}
local function art(h, w, v)
    local key = h * 100 + w * 10 + v
    if imgs[key] == nil then
        local ok, img = pcall(love.graphics.newImage, ('assets/images/mechanisms/iceberg/h%d-w%d-%d.png'):format(h, w, v))
        if ok then img:setFilter('nearest', 'nearest') end
        imgs[key] = ok and img or false
    end
    return imgs[key]
end

function Iceberg:init()
    Box.init(self)
    local p = self.props
    self.wT, self.hT = clampi(p.width, 1, Iceberg.MAX_W), clampi(p.height, 1, Iceberg.MAX_H)
    self.outerW, self.outerH = self.wT * T, self.hT * T
    self.innerW, self.innerH = self.outerW, self.outerH
    -- (la casilla colocada es la de arriba a la izquierda)
    self.x = (self.col - 1) * T + self.outerW / 2
    self.y = (self.row - 1) * T + self.outerH / 2
    self.state = 'float'
    self.sinkT, self.riseT, self.loadW = 0, 0, 0
    self.bobT = ((self.col or 0) * 0.83 + (self.row or 0) * 0.37) % (2 * math.pi)
    self.variant = ((self.col or 0) + (self.row or 0)) % 2 + 1
    self.lastX = self.x
end

function Iceberg:isSolidBody() return self.alive end
function Iceberg:isObstacle() return true end
function Iceberg:pushable() return self.alive and self.state ~= 'sunk' end
function Iceberg:canBePushed() return false end          -- (el aire lo mueve él mismo, con su inercia: abajo)
function Iceberg:breakApart() end                        -- (no se rompe: ni ground pound, ni bombas, ni caídas)
function Iceberg:onBlastHit() end
function Iceberg:onLava() end
function Iceberg:canBeEaten() return false end

-- Un ground pound encima: lo hunde de golpe un momento (y el golpe sigue siendo un ground pound normal)
function Iceberg:onPound(pa, z)
    if pa.standBody == self then self.vy = (self.vy or 0) + POUND_DIP end
    return false
end

-- La superficie del agua en la que flota: la más alta de las de sus columnas mojadas (mirando desde su cara de abajo),
-- o nil si no toca el agua (cae: sin agua se queda en el fondo)
local SX = { 0.12, 0.5, 0.88 }
function Iceberg:surface(level)
    if not level.waterSurfaceAt then return nil end
    local b = self:getOuterBounds()
    local best
    for _, k in ipairs(SX) do
        local s = level:waterSurfaceAt(b.x + b.w * k, b.y + b.h - 2, b.h + 24 * T)
        if s and (not best or s < best) then best = s end
    end
    return best
end

-- El aire de lado sobre su cara de arriba (systems/Push; la media de tres puntos)
function Iceberg:wind(level)
    if not (level.pushers and level.pushers[1]) then return 0 end
    local b = self:getOuterBounds()
    local sum = 0
    for _, k in ipairs(SX) do sum = sum + (Push.at(level, b.x + b.w * k, b.y - 6, self)) end
    return sum / #SX
end

-- Lo que va encima (no los jugadores: van solos con standBody) se mueve con él: de lado lo que no se lleva a sí mismo
-- (`ridesMoving`: la Caja mira el cuerpo de debajo ella sola), de arriba abajo todo (como los platillos de la Balanza)
local function carry(level, ents, dx, dy)
    for _, e in ipairs(ents) do
        if dx ~= 0 and not e.ridesMoving then
            local vx, f = e.vx, e.facing
            e:moveAndCollide(level, dx, 0)
            e.vx, e.facing = vx, f
        end
        if dy ~= 0 then
            -- (sigue apoyado: subiéndolo con sus choques no deja de estar en el suelo — una caja mira `onGround` para
            -- ir con el cuerpo de debajo —)
            local g = e.onGround
            if e.solidFull and dy < 0 then e:moveAndCollide(level, 0, dy) else e.y = e.y + dy end
            e.onGround = g
        end
    end
end

function Iceberg:updateCustom(dt, level)
    self.levelRef = level
    if self.state == 'gone' or self.state == 'spawning' then return false end
    local p = self.props
    local cap = math.max(0.1, tonumber(p.capacity) or 1.5)
    local _, ents, w = Weight.stack(self, level, self)
    if w > self.loadW + 0.01 then self.vy = (self.vy or 0) + (w - self.loadW) * DIP end   -- (alguien se posa: se hunde un poco)
    self.loadW = w

    -- ── Vertical: flotar ──────────────────────────────────────────────────────
    local surf = self:surface(level)
    local hh = self.outerH / 2
    if surf then
        if self.state == 'ground' then self.state = 'float' end
        if w > cap then
            self.riseT = 0
            if self.state == 'float' then self.state, self.sinkT = 'warn', 0; Sound.play('icebergCreak') end
            if self.state == 'warn' then
                self.sinkT = self.sinkT + dt
                if self.sinkT >= WARN_T then self.state = 'sunk'; Sound.play('icebergSink') end
            end
        elseif self.state == 'warn' then
            self.state = 'float'                                   -- (le quitaron el peso a tiempo)
        elseif self.state == 'sunk' then
            self.riseT = self.riseT + dt
            if self.riseT >= RISE_DELAY then self.state = 'float'; Sound.play('waterSplashOut') end
        end
        local top
        if self.state == 'sunk' then
            top = surf + (tonumber(p.sinkDepth) or 1) * T
        else
            local free = (tonumber(p.float) or 0.3) * T
            top = surf - free * (1 - LOAD_SINK * math.min(1, w / cap))
            if self.state == 'float' then
                self.bobT = self.bobT + dt
                top = top + math.sin(self.bobT * BOB_W) * BOB_A
            end
        end
        local ty = top + hh
        -- (el amortiguador frena la diferencia con lo que se mueve el AGUA: sigue la marea sin quedarse atrás)
        local vSurf = (self.lastSurf and math.abs(surf - self.lastSurf) < T) and (surf - self.lastSurf) / math.max(dt, 1e-3) or 0
        self.lastSurf = surf
        self.vy = self.vy + (K_SPRING * (ty - self.y) - C_DAMP * (self.vy - vSurf)) * dt
        self.vy = math.max(-VMAX, math.min(self.state == 'sunk' and SINK_VMAX or VMAX, self.vy))
    else
        if self.state ~= 'sunk' then self.state = 'ground' end
        self.sinkT, self.riseT, self.lastSurf = 0, 0, nil
        self.vy = math.min((self.vy or 0) + ADV_GRAVITY * dt, 1400)
    end

    -- ── De lado: solo empujado o soplado, con el roce del agua ────────────────
    local pushed = self:tickPush(dt)
    if pushed then
        -- (el empujón ya lo movió — Box:pushBy —: sigue deslizándose a esa velocidad cuando lo suelten)
        self.vx = (self.x - (self.lastX or self.x)) / math.max(dt, 1e-3)
    elseif surf then
        self.vx = self.vx * math.exp(-DRAG * dt)
        local wx = self:wind(level)
        if wx ~= 0 then
            local want = wx * WIND_K / (1 + 0.3 * w)
            self.vx = self.vx + (want - self.vx) * math.min(1, WIND_RATE * dt)
        end
    else
        self.vx = self.vx * math.max(0, 1 - GROUND_FRIC * dt)
    end
    if math.abs(self.vx) < 1 then self.vx = 0 end

    local x0, y0 = self.lastX or self.x, self.y
    local xBefore = self.x
    local dx = pushed and 0 or self.vx * dt
    local vx, f0 = self.vx, self.facing
    local dy = self.vy * dt
    -- (subiendo, lo de encima sube ANTES: una caja encima es un cuerpo sólido y lo pararía)
    if dy < 0 then carry(level, ents, 0, dy) end
    self:moveAndCollide(level, dx, dy)
    self.facing = f0
    if dx ~= 0 and math.abs(self.x - (xBefore + dx)) > 0.5 then self.vx = 0 else self.vx = vx end   -- (pared, otro iceberg)
    if self.onGround and self.vy > 0 then self.vy = 0 end
    carry(level, ents, self.x - x0, dy < 0 and 0 or (self.y - y0))
    self.lastX = self.x

    if self:fellOut(level) then self:resetToHome() end
    return true
end

-- ── Red ───────────────────────────────────────────────────────────────────────
-- (siempre se manda: se mece; varado en su sitio de salida, no)
function Iceberg:netAtRest()
    return self.state == 'ground' and self.x == self.home.x and self.y == self.home.y
end
function Iceberg:netRest() self:resetToHome(); self.state = 'ground' end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
function Iceberg:render(camX, camY)
    local b = self:getOuterBounds()
    local dx = 0
    if self.state == 'warn' then dx = (math.floor(love.timer.getTime() * 22) % 2 == 0) and -S or S end   -- (tiembla)
    local img = art(self.hT or 1, self.wT or 1, self.variant or 1)
    love.graphics.setColor(1, 1, 1, 1)
    if img then
        love.graphics.draw(img, math.floor(b.x - camX + 0.5) + dx, math.floor(b.y - camY + 0.5), 0, S, S)
    end
end

-- Editor (seleccionado): su tamaño y lo que aguanta
function Iceberg.drawEditorOverlay(props, cx, cy, zoom)
    local k = zoom or 1
    local w, h = clampi(props.width, 1, Iceberg.MAX_W), clampi(props.height, 1, Iceberg.MAX_H)
    local x0, y0 = cx - T / 2 * k, cy - T / 2 * k
    love.graphics.setColor(0.6, 0.9, 1, 0.9)
    love.graphics.rectangle('line', x0, y0, w * T * k, h * T * k)
    love.graphics.setColor(0.6, 0.9, 1, 0.5)
    local fy = y0 + (tonumber(props.float) or 0.3) * T * k
    love.graphics.line(x0 - 6, fy, x0 + w * T * k + 6, fy)        -- (la línea del agua, vacío)
    love.graphics.setColor(1, 1, 1, 1)
end

return {
    name = 'iceberg', label = 'Iceberg', category = 'Mecanismos', class = Iceberg,
    description = 'Bloque de hielo que FLOTA en el agua (de casillas o de una inundación: sube y baja con ella) y se '
               .. 'puede pisar. Con más peso del que aguanta se hunde (avisa antes) y vuelve a flotar sin él. Solo se '
               .. 'mueve si lo empujan o lo sopla el aire. Se coloca en su casilla de arriba a la izquierda.',
    defaults = { movement = 'static' }, hide = 'all',
    props = {
        { key = 'width', kind = 'int', label = 'Ancho (casillas)', group = 'Iceberg', default = 3, min = 1, max = Iceberg.MAX_W, step = 1 },
        { key = 'height', kind = 'int', label = 'Alto (casillas)', group = 'Iceberg', default = 1, min = 1, max = Iceberg.MAX_H, step = 1 },
        { key = 'capacity', kind = 'number', label = 'Peso que aguanta', group = 'Iceberg', default = 1.5, min = 0.5, max = 10, step = 0.5,
          help = 'Más peso encima y se hunde (avisa antes). Un jugador pesa 1 (+ lo que lleve), la caja grande 2, la pequeña y un escarabajo 1' },
        { key = 'float', kind = 'number', label = 'Asoma (casillas)', group = 'Iceberg', default = 0.3, min = 0.1, max = 2, step = 0.05,
          help = 'Lo que asoma sobre el agua sin nada encima (con peso se hunde un poco)' },
        { key = 'sinkDepth', kind = 'number', label = 'Se hunde hasta (casillas)', group = 'Iceberg', default = 1, min = 0.25, max = 6, step = 0.25,
          help = 'Casillas bajo la superficie a las que baja su cara de arriba cuando se hunde por el peso' },
    },
    editor = { sprite = 'assets/images/mechanisms/iceberg/h1-w1-1.png' },
}
