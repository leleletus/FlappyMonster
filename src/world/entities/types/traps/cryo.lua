-- Congelador (lanzador de nitrógeno líquido): bloque fijo y sólido que, tras una
-- CARGA (tiembla, el indicador se llena y brilla, escarcha en la boquilla), suelta
-- un chorro corto de líquido helado en línea recta (derecha / izquierda / arriba /
-- abajo). Lo que toca el chorro queda CONGELADO dentro de un bloque de hielo:
--  * jugadores: pa:freeze(t) (Interactions: caja de peligro effect='freeze');
--    pulsando saltar / moverse se rompe antes
--  * enemigos: e:freeze(t) (estado común 'frozen': caen, no hacen daño; caerles
--    encima rompe el hielo y los mata)
--  * jefes: solo los que lo permiten (Boss: canFreeze)
-- El chorro avanza a STREAM_SPEED y se corta en el primer bloque sólido.
--
-- Modos (editor):
--  'interval'  dispara cada `interval` s (el primero a los `firstDelay` s)
--  'switch'    dispara cuando cambia su Activador ON/OFF conectado (capa Bloques →
--              Conectar; `trigger`: cualquier cambio, al encender o al apagar). Así,
--              en la pelea de un jefe, salta a la vez que se abren las compuertas.
--
-- Online: lo simula el servidor; el cliente dibuja todo a partir de state +
-- deadTimer (+ el alcance `reach` en netPack). En reposo no se envía.
--
-- FASE DEL JEFE (prop `phase`, 0 = siempre): no está (ni choca, ni dispara) hasta que el
-- jefe de su zona llega a esa fase (z.phase, que viaja en el snapshot: BossZones); entonces
-- BAJA del techo colgado de sus cadenas (DESCEND_T s, sonido cryoDrop) y ya funciona.

local Entity      = require 'src/world/entities/base/Entity'
local SpriteStrip = require 'src/fx/SpriteStrip'

local Cryo = Entity.extend(Entity, {
    debugColor = { 0.5, 0.85, 1 },
    hitbox = { outerW = 1, outerH = 1, innerW = 1, innerH = 1 },
})

local SCALE        = GUMMY_SCALE       -- 16x16 → 64 px, una casilla
local STREAM_SPEED = 1800              -- px/s a los que avanza (y se va) el chorro
local STREAM_HALF  = 16                -- media anchura de la caja que congela (px)
local DIRS = { right = { 1, 0 }, left = { -1, 0 }, up = { 0, -1 }, down = { 0, 1 } }
local DESCEND_T    = 1.1               -- s bajando del techo al llegar su fase
local PhaseBlocks, Clip

Cryo.wantsLevel = true        -- (solo dibujo: mira los bloques de alrededor para apoyarse; BossZones.link / editor)

-- ANIMACIONES (assets/anim/traps/cryo.json), por nombre: el depósito `idle` / `charge` / `fire` y el cañón
-- `cannon_<la misma>`; las patas `cryo_feet`; el soporte `chain` / `anchor` / `clamp`; el chorro `stream` (se repite
-- a lo largo) y su punta `stream_head`. Por piezas: el depósito siempre derecho, el cañón girado hacia donde dispara
-- y las patas hacia lo que lo sostiene (centradas en la casilla).
Cryo.animId = 'traps/cryo'
local Anim
local function C(name)
    Anim = Anim or require 'src/fx/Anim'
    return Anim.clip(Cryo.animId, name)
end
local streamQuad
function Cryo.loadAssets() C('idle') end
function Cryo.sizePx() return 16 * SCALE, 16 * SCALE end

function Cryo:init()
    local p = self.props
    self.moving, self.vx, self.vy = false, 0, 0
    self.dir = DIRS[p.dir or 'right'] and (p.dir or 'right') or 'right'
    self.state, self.deadTimer = 'idle', 0
    self.waitFor = p.firstDelay or 2
    self.reach   = (p.range or 8) * TILE_PX
    self.lastSig = nil
end

-- ── Fase del jefe ──────────────────────────────────────────────────────────────
function Cryo:phaseZone()
    if self._pz == nil then
        local lv = self.levelRef
        if not lv then return nil end
        PhaseBlocks = PhaseBlocks or require 'src/world/systems/PhaseBlocks'
        local c, r = math.floor(self.x / TILE_PX) + 1, math.floor(self.y / TILE_PX) + 1
        self._pz = PhaseBlocks.zoneOf(lv, { zone = self.props.zone or 0, c0 = c, r0 = r }) or false
    end
    return self._pz or nil
end
function Cryo:phaseReached()
    local ph = self.props.phase or 0
    if ph <= 0 then return true end
    local z = self:phaseZone()
    return z ~= nil and (z.phase or 1) >= ph
end
-- ¿Ya está colocado y funcionando? (un jugador / servidor: tras bajar; cliente: con la fase)
function Cryo:isReady()
    if not self:phaseReached() then return false end
    return self.shownT == nil or self.shownT >= DESCEND_T
end

function Cryo:dirVec() local d = DIRS[self.dir]; return d[1], d[2] end

-- Boca de la boquilla: el borde de su casilla hacia donde mira
function Cryo:nozzle()
    local dx, dy = self:dirVec()
    return self.x + dx * TILE_PX / 2, self.y + dy * TILE_PX / 2
end

-- Hasta dónde llega el chorro: el alcance, o el primer bloque sólido delante
function Cryo:computeReach(level)
    local max = (self.props.range or 8) * TILE_PX
    local nx, ny = self:nozzle()
    local dx, dy = self:dirVec()
    for d = 4, max, 8 do
        if level:collisionAt(nx + dx * d, ny + dy * d) then return math.max(0, d - 4) end
    end
    return max
end

-- Tramo del chorro [cola, punta] (distancias desde la boquilla) en el paso actual
function Cryo:streamSpan()
    if self.state ~= 'fire' then return nil end
    local t = self.deadTimer or 0
    local burst = self.props.burst or 0.8
    local head = math.min(self.reach, t * STREAM_SPEED)
    local tail = math.min(self.reach, math.max(0, (t - burst) * STREAM_SPEED))
    if head - tail < 1 then return nil end
    return tail, head
end

-- Caja (mundo) del tramo [a, b] del chorro
function Cryo:streamBox(a, b)
    local nx, ny = self:nozzle()
    local dx, dy = self:dirVec()
    local x0, y0 = nx + dx * a, ny + dy * a
    local x1, y1 = nx + dx * b, ny + dy * b
    local lx, hx = math.min(x0, x1), math.max(x0, x1)
    local ly, hy = math.min(y0, y1), math.max(y0, y1)
    if dx ~= 0 then ly, hy = ly - STREAM_HALF, hy + STREAM_HALF else lx, hx = lx - STREAM_HALF, hx + STREAM_HALF end
    return { x = lx, y = ly, w = hx - lx, h = hy - ly }
end

local function overlap(a, b)
    return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y
end

function Cryo:startWindup()
    self.state, self.deadTimer = 'windup', 0
    Sound.play('cryoWindup')
end

function Cryo:updateCustom(dt, level)
    local p = self.props
    -- Con fase: escondido hasta que llega (solo sigue el Activador), luego baja
    if (p.phase or 0) > 0 then
        if not self:phaseReached() then
            self.shownT = nil
            if (p.mode or 'interval') == 'switch' then self.lastSig = level:signal(p.id or 1) end
            return true
        end
        if not self.shownT then
            self.shownT = 0
            Sound.play('cryoDrop')
        end
        if self.shownT < DESCEND_T then
            self.shownT = self.shownT + dt
            if (p.mode or 'interval') == 'switch' then self.lastSig = level:signal(p.id or 1) end
            return true
        end
    end
    self.deadTimer = self.deadTimer + dt
    local st = self.state
    if (p.mode or 'interval') == 'switch' then
        -- Conectado a un Activador: dispara cuando cambia (según `trigger`)
        local sig = level:signal(p.id or 1)
        if self.lastSig ~= nil and sig ~= self.lastSig and st == 'idle' then
            local tr = p.trigger or 'any'
            if tr == 'any' or (tr == 'on' and sig) or (tr == 'off' and not sig) then self:startWindup() end
        end
        self.lastSig = sig
    elseif st == 'idle' and self.deadTimer >= self.waitFor then
        self.waitFor = math.max(0.2, p.interval or 4)
        self:startWindup()
    end
    st = self.state
    if st == 'windup' then
        self.reach = self:computeReach(level)
        if self.deadTimer >= (p.windup or 0.8) then
            self.state, self.deadTimer = 'fire', 0
            Sound.play('cryoBlast')
        end
    elseif st == 'fire' then
        self.reach = math.min(self.reach, self:computeReach(level))      -- (un bloque que aparece lo corta)
        local tail, head = self:streamSpan()
        if tail and p.affectEnemies ~= false then
            local box = self:streamBox(tail, head)
            for _, e in ipairs(level.liveEntities or {}) do
                if e ~= self and e.alive and e.freeze and e:canFreeze() and overlap(box, e:getOuterBounds()) then
                    e:freeze(p.freezeTime or 3)
                end
            end
            -- El chorro que TOCA AGUA la enfría: se avisa a quien le importe (`e:onChilledWater(level, x, y, t)`;
            -- la Gran Bola de Nieve en su fase 3 se congela con estar en esa agua, sin que el chorro le dé)
            local nx, ny = self:nozzle()
            local dx, dy = self:dirVec()
            for d = tail, head, 24 do
                local wx, wy = nx + dx * d, ny + dy * d
                if level:liquidAt(wx, wy) then
                    for _, e in ipairs(level.liveEntities or {}) do
                        if e ~= self and e.alive and e.onChilledWater then e:onChilledWater(level, wx, wy, p.freezeTime or 3) end
                    end
                    break
                end
            end
        end
        if self.deadTimer >= (p.burst or 0.8) + self.reach / STREAM_SPEED + 0.05 then
            self.state, self.deadTimer = 'idle', 0
        end
    end
    return true
end

function Cryo:canBeKnocked() return false end
function Cryo:canFreeze() return false end
function Cryo:canBeStomped() return false end

-- Sólido como un bloque (lados, encima y debajo)
Cryo.solidFull = true
function Cryo:isSolidBody() return self.alive and self:isReady() end

-- El chorro congela a los jugadores (Interactions: effect='freeze', time)
function Cryo:getHazardBoxes()
    if self.props.affectPlayers == false then return nil end
    local tail, head = self:streamSpan()
    if not tail then return nil end
    local b = self:streamBox(tail, head)
    b.effect, b.time = 'freeze', self.props.freezeTime or 3
    return { b }
end

-- ── Red ───────────────────────────────────────────────────────────────────────
function Cryo:netAtRest() return self.state == 'idle' end
function Cryo:netRest() self.state, self.deadTimer = 'idle', 0 end
function Cryo:netPack() return { math.floor(self.reach + 0.5) } end
function Cryo:netApply(a, b, f) self.reach = (b and b[1]) or self.reach end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
local Particles
local function emit(kind, x, y, opts)
    Particles = Particles or require 'src/fx/Particles'
    Particles.emit(kind, x, y, opts)
end

-- Ángulo y espejo del sprite (dibujado mirando a la derecha)
local function pose(dir)
    if dir == 'left' then return 0, -1 end
    if dir == 'up'   then return -math.pi / 2, 1 end
    if dir == 'down' then return math.pi / 2, 1 end
    return 0, 1
end

-- Lados de la casilla y giros de las piezas (cañón dibujado hacia la derecha; patas hacia abajo)
local SIDE = { down = { 0, 1 }, up = { 0, -1 }, left = { -1, 0 }, right = { 1, 0 } }
local OPP  = { down = 'up', up = 'down', left = 'right', right = 'left' }
local CANNON_ANG = { right = 0, down = math.pi / 2, left = math.pi, up = -math.pi / 2 }
local FEET_ANG   = { down = 0, left = math.pi / 2, up = math.pi, right = -math.pi / 2 }

-- ¿En qué se apoya? (solo dibujo). Devuelve el lado de la superficie que lo sostiene
-- ('down' suelo, 'up' techo, 'left' / 'right' pared): ahí van las patas. Nunca el lado
-- hacia el que dispara. Preferencia: el suelo, la pared/techo de detrás del cañón, los
-- lados y por último el techo. nil = no toca nada: cuelga de cadenas (sin patas).
function Cryo:support()
    local level = self.levelRef
    if not level then return (self.dir == 'down') and 'up' or 'down' end
    local T = TILE_PX
    local c, r = math.floor(self.x / T) + 1, math.floor(self.y / T) + 1
    local function solid(cc, rr)
        if cc < 1 or rr < 1 or cc > level.tileW or rr > level.tileH then return false end
        return level:getDef(cc, rr).collision == 'solid'
    end
    for _, side in ipairs({ 'down', OPP[self.dir], 'left', 'right', 'up' }) do
        local d = SIDE[side]
        if side ~= self.dir and solid(c + d[1], r + d[2]) then return side end
    end
    return nil
end

-- Cadena(s) desde el techo hasta lo alto del depósito (dibujadas DETRÁS de él; disparando
-- hacia arriba, dos: a los lados del cañón)
function Cryo:drawHanger(camX, camY, sx, sy)
    local level, T, S = self.levelRef, TILE_PX, SCALE
    local xs = (self.dir == 'up') and { -4 * S, 4 * S } or { 0 }
    love.graphics.setColor(1, 1, 1, 1)
    for _, ox in ipairs(xs) do
        local wx = self.x + ox
        local c = math.floor(wx / T) + 1
        local ceil = 0
        for rr = math.floor(self.y / T), 1, -1 do
            if level:getDef(c, rr).collision == 'solid' then ceil = rr * T; break end
        end
        local x = math.floor(sx + ox)
        local top = math.floor(ceil - camY)
        local bottom = sy - 5 * S                                   -- (lo alto del depósito)
        local y = top + 2 * S
        local chain, anchor, clamp, now = C('chain'), C('anchor'), C('clamp'), love.timer.getTime()
        while y < bottom do
            chain:playPx(now, x - math.floor(chain.w * S / 2), y, 0, S, S)
            y = y + chain.h * S
        end
        anchor:playPx(now, x - math.floor(anchor.w * S / 2), top, 0, S, S)
        clamp:playPx(now, x - math.floor(clamp.w * S / 2), bottom - 2 * S, 0, S, S)
    end
end

-- Monta las piezas en (sx, sy) = centro de la casilla en pantalla
-- name = la animación del depósito (el cañón, la suya `cannon_<name>`); prog = avance 0..1 si es una carga
function Cryo:drawParts(name, prog, sx, sy, side)
    local now = love.timer.getTime()
    if side then C('cryo_feet'):play(now, sx, sy, FEET_ANG[side], SCALE, SCALE) end
    local body, cannon = C(name), C('cannon_' .. name) or C('cannon_idle')
    body:draw(prog and body:atProgress(prog) or body:at(now), sx, sy, 0, SCALE, SCALE)
    cannon:draw(prog and cannon:atProgress(prog) or cannon:at(now), sx, sy, CANNON_ANG[self.dir] or 0, SCALE, SCALE)
end

function Cryo:drawStream(camX, camY, tail, head, now)
    local nx, ny = self:nozzle()
    local ang = pose(self.dir)
    if self.dir == 'left' then ang = math.pi end
    love.graphics.push()
    love.graphics.translate(math.floor(nx - camX), math.floor(ny - camY))
    love.graphics.rotate(ang)
    love.graphics.setColor(1, 1, 1, 1)
    local stream = C('stream')
    local r = stream:rec(stream:at(now))                  -- (el cuadro del chorro que toca: fluye a su ritmo)
    local seg = r.w * SCALE
    streamQuad = streamQuad or love.graphics.newQuad(0, 0, 1, 1, 1, 1)
    -- (el dibujo se repite desde la boquilla: así "fluye" sin saltos al cortarse la cola)
    local x = math.floor(tail / seg) * seg
    while x < head do
        local a, b = math.max(x, tail), math.min(x + seg, head)
        if b > a then
            streamQuad:setViewport(r.x + (a - x) / SCALE, r.y, (b - a) / SCALE, r.h, r.iw, r.ih)
            love.graphics.draw(r.image, streamQuad, math.floor(a), -r.h / 2 * SCALE, 0, SCALE, SCALE)
        end
        x = x + seg
    end
    -- La punta: nube helada (mientras el chorro avanza y al chocar)
    C('stream_head'):play(now, math.floor(head - 3 * SCALE), 0, 0, SCALE, SCALE)
    love.graphics.pop()
    -- Bruma que cae del chorro (solo dibujo)
    if (self.lastMist or 0) + 0.03 < now then
        self.lastMist = now
        local dx, dy = self:dirVec()
        local d = tail + math.random() * (head - tail)
        emit('cryo_mist', nx + dx * d, ny + dy * d)
    end
end

-- Bajando del techo (solo dibujo, con su reloj): 0 = arriba (escondido) .. 1 = en su sitio
function Cryo:descendK(now)
    if EDITOR_VIEW or (self.props.phase or 0) <= 0 then return 1 end
    if not self:phaseReached() then self.appearAt = nil; return 0 end
    self.appearAt = self.appearAt or now
    return math.min(1, (now - self.appearAt) / DESCEND_T)
end

-- Altura del techo sobre él (px de mundo; solo dibujo)
function Cryo:ceilingY()
    local level, T = self.levelRef, TILE_PX
    if not level then return self.y - 3 * T end
    local c = math.floor(self.x / T) + 1
    for rr = math.floor(self.y / T), 1, -1 do
        if level:getDef(c, rr).collision == 'solid' then return rr * T end
    end
    return 0
end

function Cryo:render(camX, camY)
    local p   = self.props
    local now = love.timer.getTime()
    local dk  = self:descendK(now)
    if dk <= 0 then return end
    local dropY = 0
    if dk < 1 then
        -- cae frenando, con un rebote corto al final (la cadena se tensa)
        local e = 1 - (1 - dk) ^ 3
        local dist = self.y + TILE_PX / 2 - self:ceilingY()
        dropY = -math.floor((1 - e) * dist + 0.5)
        if dk > 0.85 then dropY = dropY - math.floor(math.sin((dk - 0.85) / 0.15 * math.pi) * 6) end
        self.dropFx = nil
    elseif not self.dropFx and self.appearAt then
        self.dropFx = true
        emit('cryo_puff', self.x, self.y - TILE_PX / 2, { nx = 0, ny = -1 })
        emit('snow_puff', self.x, self.y - TILE_PX / 2)
    end
    local st  = self.state
    local t   = self.deadTimer or 0
    local name, prog, shake = 'idle', nil, 0
    local wind = p.windup or 0.8
    if st == 'windup' then
        local k = math.min(1, t / math.max(0.05, wind))
        name, prog = 'charge', k
        shake = math.floor(k * 2.99)
        -- Escarcha por la boquilla, cada vez más seguida
        if (self.lastPuff or 0) + (0.12 - 0.08 * k) < now then
            self.lastPuff = now
            local dx, dy = self:dirVec()
            local nx, ny = self:nozzle()
            emit('cryo_puff', nx, ny, { nx = dx, ny = dy })
        end
    elseif st == 'fire' then
        local tail = self:streamSpan()
        name = (tail == 0 or t < 0.15) and 'fire' or 'idle'
        if t < 0.05 and not self.blasted then
            self.blasted = true
            local dx, dy = self:dirVec()
            local nx, ny = self:nozzle()
            emit('cryo_blast', nx, ny, { nx = dx, ny = dy })
        end
    end
    if st ~= 'fire' then self.blasted = nil end
    local side = self:support()
    if dk < 1 then
        -- bajando: cuelga, y lo que aún está dentro del techo no se ve
        side = nil
        Clip = Clip or require 'src/ui/Clip'
        Clip.push(math.floor(self.x - camX) - 2 * TILE_PX, math.floor(self:ceilingY() - camY), 4 * TILE_PX, 6 * TILE_PX)
    end
    if not side then self:drawHanger(camX, camY, math.floor(self.x - camX), math.floor(self.y - camY) + dropY) end
    local sx = math.floor(self.x - camX) + ((shake > 0) and math.floor((math.random() * 2 - 1) * shake + 0.5) or 0)
    local sy = math.floor(self.y - camY) + dropY + ((shake > 0) and math.floor((math.random() * 2 - 1) * shake + 0.5) or 0)
    love.graphics.setColor(1, 1, 1, 1)
    self:drawParts(name, prog, sx, sy, side)
    if st == 'windup' then
        -- Brillo azul que crece (aditivo) sobre todo el aparato
        local k = math.min(1, t / math.max(0.05, wind))
        local pulse = 0.5 + 0.5 * math.sin(now * (10 + 20 * k))
        love.graphics.setBlendMode('add')
        love.graphics.setColor(0.25 * k, 0.6 * k, 0.9 * k, 0.35 + 0.35 * pulse)
        self:drawParts(name, prog, sx, sy, side)
        love.graphics.setBlendMode('alpha')
    end
    if dk < 1 then Clip.pop() end
    local tail, head = self:streamSpan()
    if tail then self:drawStream(camX, camY, tail, head, now) end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Editor: el recorrido del chorro (alcance máximo; en juego se corta en el primer bloque)
function Cryo.drawEditorOverlay(props, cx, cy, zoom)
    local d = DIRS[props.dir or 'right'] or DIRS.right
    local r = (props.range or 8) * TILE_PX
    local nx, ny = cx + d[1] * TILE_PX / 2, cy + d[2] * TILE_PX / 2
    local x0, y0, x1, y1 = nx, ny, nx + d[1] * r, ny + d[2] * r
    local lx, hx, ly, hy = math.min(x0, x1), math.max(x0, x1), math.min(y0, y1), math.max(y0, y1)
    if d[1] ~= 0 then ly, hy = ly - STREAM_HALF, hy + STREAM_HALF else lx, hx = lx - STREAM_HALF, hx + STREAM_HALF end
    love.graphics.setColor(0.55, 0.9, 1, 0.15)
    love.graphics.rectangle('fill', lx, ly, hx - lx, hy - ly)
    love.graphics.setColor(0.55, 0.9, 1, 0.8)
    love.graphics.setLineWidth(2 / zoom)
    love.graphics.rectangle('line', lx, ly, hx - lx, hy - ly)
    love.graphics.setColor(1, 1, 1, 1)
end

local function opts(...)
    local o = {}
    for _, pair in ipairs({ ... }) do o[#o+1] = { value = pair[1], label = pair[2] } end
    return o
end

return {
    name = 'cryo', label = 'Congelador', category = 'Trampas',
    description = 'Lanza un chorro corto de nitrógeno líquido que congela en un bloque de hielo '
               .. 'a jugadores y enemigos. Cada X segundos o al cambiar su Activador ON/OFF conectado.',
    class = Cryo,
    hide = 'all',
    defaults = { movement = 'static', onTouch = 'none' },
    activatable = true,
    -- Al conectarle un Activador en el editor pasa a dispararse con él
    onLink = function(p) p.mode = 'switch' end,
    props = {
        { key='dir', kind='enum', label='Dispara hacia', group='Congelador', default='right',
          options=opts({'right','Derecha'}, {'left','Izquierda'}, {'up','Arriba'}, {'down','Abajo'}) },
        { key='mode', kind='enum', label='Se activa', group='Congelador', default='interval',
          options=opts({'interval','Cada X s'}, {'switch','Con su Activador'}),
          help='Con su Activador: dispara cuando cambia el Activador ON/OFF conectado (capa Bloques → Conectar)' },
        { key='interval', kind='number', label='Cada (s)', group='Congelador', default=4,
          min=0.5, max=60, step=0.5, help='Tiempo entre disparos (modo "Cada X s"; la carga cuenta dentro)' },
        { key='firstDelay', kind='number', label='Primer disparo (s)', group='Congelador', default=2,
          min=0, max=60, step=0.5, help='Para desfasar varios congeladores' },
        { key='trigger', kind='enum', label='Con el Activador', group='Congelador', default='any',
          options=opts({'any','Al cambiar'}, {'on','Al encender'}, {'off','Al apagar'}) },
        { key='windup', kind='number', label='Carga (s)', group='Chorro', default=0.8,
          min=0.1, max=5, step=0.1, help='Aviso antes de disparar: tiembla, brilla y suelta escarcha' },
        { key='burst', kind='number', label='Duración del chorro (s)', group='Chorro', default=0.8,
          min=0.1, max=5, step=0.1 },
        { key='range', kind='int', label='Alcance (casillas)', group='Chorro', default=8,
          min=1, max=40, step=1, help='Se corta antes en el primer bloque sólido' },
        { key='freezeTime', kind='number', label='Congelado (s)', group='Chorro', default=3,
          min=0.5, max=15, step=0.5, help='Lo que dura el bloque de hielo (el jugador sale antes pulsando)' },
        { key='affectPlayers', kind='bool', label='Congela jugadores', group='Chorro', default=true },
        { key='affectEnemies', kind='bool', label='Congela enemigos', group='Chorro', default=true },
        { key='phase', kind='int', label='Aparece en la fase del jefe', group='Aparición', default=0,
          min=0, max=5, step=1, help='0 = siempre. Si no, no está hasta que el jefe de su zona llega a esa fase: '
                                   .. 'entonces baja del techo colgado de cadenas' },
        { key='zone', kind='int', label='Zona de jefe', group='Aparición', default=0, min=0, max=20, step=1,
          help='Id de la zona cuya fase mira (0 = la que lo contiene o la más cercana)' },
    },
    editor = { sprite = 'assets/images/traps/cryo/cryo-Sheet.png', frameW = 16 },
}
