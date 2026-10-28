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
-- Red: el desnivel (`d`) en su netPack; los platillos se calculan de él.
local Entity = require 'src/world/entities/base/Entity'
local Isles  = require 'src/world/level/Isles'

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
local ON_TOP   = 4                         -- px: "encima" de un platillo

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
    local part = { owner = owner, side = side, solidFull = true, oneway = true, moves = true, alive = true }
    function part:getOuterBounds(into)
        local lx, ly, rx, ry = geom(owner.x, owner.y, owner.props, owner.d or 0)
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
local PB = {}
-- ¿Está `e` (sus pies) apoyado en la cara de arriba de la caja `b`?
local function restsOn(e, b)
    local eb = e:getOuterBounds()
    local foot = eb.y + eb.h
    return foot >= b.y - ON_TOP and foot <= b.y + ON_TOP and eb.x + eb.w > b.x and eb.x < b.x + b.w
end
local function counts(self, e)
    -- (lo que VUELA no pesa: un Soplón que pasa rozando el platillo no lo baja)
    return e ~= self and e.alive and not e.flying and e.state ~= 'carried' and not (e.isGhost and e:isGhost()) and not (e.def and e.def.boss)
end

-- Lo que hay encima de un platillo, APILADO incluido (el usuario: una caja con algo encima pesa las dos cosas):
-- jugadores de pie en el platillo o en algo de la pila (`standBody`) y entidades apoyadas en el platillo o en algo de
-- la pila; lo que lleva un jugador en las manos pesa con él
local function onPan(self, pan, level)
    local players, ents, w = {}, {}, 0
    local seen = {}
    local frontier = { pan }
    while #frontier > 0 do
        local base = table.remove(frontier)
        local b = base:getOuterBounds(PB)
        b = { x = b.x, y = b.y, w = b.w, h = b.h }
        for _, pa in ipairs(level.players or {}) do
            if not seen[pa] and not pa.dying and pa.standBody == base then
                seen[pa] = true
                players[#players + 1] = pa
                w = w + 1 + ((pa.carrying and pa.carrying.weight) or (pa.carrying and 1) or 0)
            end
        end
        for _, e in ipairs(level.liveEntities or {}) do
            if not seen[e] and counts(self, e) and restsOn(e, b) then
                seen[e] = true
                ents[#ents + 1] = e
                w = w + (e.weight or 1)
                frontier[#frontier + 1] = e                -- (y lo que esté encima de ella)
            end
        end
    end
    return players, ents, w
end

-- Ground pound (Interactions.run): el que cae sobre un platillo lo hunde y lanza lo del otro
function Scale:onPound(pa, z)
    local hit
    for _, pan in ipairs(self.pans) do if pa.standBody == pan then hit = pan end end
    if not hit then return false end
    local level = self.levelRef
    local other = (hit == self.pans[1]) and self.pans[2] or self.pans[1]
    local players, ents = onPan(self, other, level or {})
    local v = -math.abs(ADV_JUMP_VEL) * LAUNCH_V * (self.props.power or 1)
    for _, p in ipairs(players) do if p ~= pa then p:launch(0, v) end end
    for _, e in ipairs(ents) do
        if e.launch and e.canBeLaunched and e:canBeLaunched() then e:launch(e.vx or 0, v)
        else e.vy, e.onGround = v, false end
    end
    self.slamT, self.slamSide = 0.35, hit.side
    Sound.play('scaleLaunch')
    local b = other:getOuterBounds()
    Entity.emitFx('gp_start', b.x + b.w / 2, b.y)
    return true
end

function Scale:updateCustom(dt, level)
    self.levelRef = level
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
    if self.d < target then self.d = math.min(target, self.d + speed * dt)
    elseif self.d > target then self.d = math.max(target, self.d - speed * dt) end
    local dd = self.d - d0
    if dd ~= 0 then
        self.state = 'moving'
        -- lo que no es un jugador y está encima va con su platillo (los jugadores: standBody)
        for i, pan in ipairs(self.pans) do
            local _, ents = onPan(self, pan, level)
            local dy = (i == 1) and dd or -dd
            for _, e in ipairs(ents) do e.y = e.y + dy end
        end
        self.creakT = self.creakT - dt
        if self.creakT <= 0 then Sound.play('scaleCreak'); self.creakT = CREAK_T end
        self.spin = (self.spin or 0) + dd
    else
        self.state, self.creakT = 'idle', 0
    end
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
