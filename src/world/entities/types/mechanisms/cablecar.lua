-- EL TELEFÉRICO (Montañas Heladas, reutilizable en cualquier isla; aprobado por el usuario el 2026-10-29,
-- FlappyMonster_pruebas/islas_heladas/diseno.md §A5): una PLATAFORMA que cuelga de un CABLE tendido entre dos o más
-- puntos y lo recorre a `speed` casillas/s, de ida y vuelta (`mode` = 'pingpong') o en circuito cerrado ('loop': del
-- último punto vuelve al primero).
--   * Se coloca en el PRIMER punto del cable; `path` = los demás (el editor los dibuja como cajitas numeradas que se
--     arrastran, como la ruta de la Nave). Cada punto es el centro de su casilla.
--   * `cabins` cabinas en el mismo cable, repartidas a lo largo de él (en ida y vuelta, dos cabinas se cruzan en medio).
--   * `stops` = s que espera cada cabina al llegar a un extremo (en circuito: al pasar por el primer punto).
--   * `onWeight` = solo se mueve mientras hay algo encima de alguna cabina; sin peso, tras un momento, VUELVE al
--     principio (`back`, por defecto sí: un teleférico que se queda a medio camino no deja el nivel sin salida).
--   * Cada cabina es una PIEZA sólida de un solo sentido que se MUEVE (Entities.solidBodies: jugadores — standBody —
--     y lo que está encima — Weight — van con ella; cajas, enemigos, bombas…).
--   * Cable, poleas y apoyos: cada punto tiene su polea, sujeta por una TORRE hasta el suelo de debajo o, sin suelo,
--     colgada del techo (el usuario: nada flotando sin cuerda). Se mira una vez el nivel (solo dibujo).
-- Simulación: el avance del cable `u` (px). Red: `u` en su netPack; las cabinas se calculan de él. `netBounds()` = la
-- caja de todo el cable: el servidor lo manda a quien la tenga cerca (no solo cerca de su primer punto).
-- Arte por isla (`isleArt`; tools/art/world/make_avalanche_cablecar.py): assets/images/mechanisms/cablecar/<isla>-*.png.
-- Sonidos cablecarMove (se mueve) y cablecarStop (llega / arranca).
local Entity = require 'src/world/entities/base/Entity'
local Isles  = require 'src/world/level/Isles'
local Weight = require 'src/world/systems/Weight'
local TileTypes = require 'src/world/tiles/TileTypes'
local Clip   = require 'src/ui/Clip'

local CC = Entity.extend(Entity, { debugColor = { 0.9, 0.7, 0.4 },
    hitbox = { outerW = 1, outerH = 1, innerW = 1, innerH = 1 } })

local S       = GUMMY_SCALE
local T       = TILE_PX
local CAB_W   = 48 * S                -- el dibujo de la cabina: 48x28
local HOOK_Y  = 3 * S                 -- del cable al gancho de la cabina (el carro: el cable pasa por su fila 4)
local DECK_Y  = HOOK_Y + 22 * S       -- del cable a la cara de arriba de la plataforma (filas 22-27 del dibujo)
local DECK_H  = 6 * S
local BACK_DELAY = 1.0                -- s sin peso antes de volver al principio (`onWeight` + `back`)
local MOVE_SND = 0.6                  -- s: cada cuánto se repite el sonido de moverse
local MAX_POSES = 12                  -- poses del grafo del bot (BotNav): como mucho
CC.DECK_Y, CC.CAB_W = DECK_Y, CAB_W

CC.wantsLevel = true
function CC.sizePx() return T, T end

-- ── La geometría del cable ────────────────────────────────────────────────────
-- Puntos (mundo, px: centros de casilla), longitudes acumuladas y largo. En circuito, el tramo de vuelta cuenta.
function CC.pathOf(col, row, p)
    local pts = { { (col - 0.5) * T, (row - 0.5) * T } }
    for _, q in ipairs(p.path or {}) do pts[#pts + 1] = { (q.col - 0.5) * T, (q.row - 0.5) * T } end
    local loop = p.mode == 'loop' and #pts > 2
    local acc, L = { 0 }, 0
    local n = loop and #pts or #pts - 1
    for i = 1, n do
        local a, b = pts[i], pts[i % #pts + 1]
        L = L + math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
        acc[i + 1] = L
    end
    return { pts = pts, acc = acc, len = math.max(L, 1), loop = loop, segs = n }
end

-- Punto del cable a la distancia `d` (0..len) → x, y, ángulo del tramo
local function pointAt(g, d)
    local pts, acc = g.pts, g.acc
    if g.segs < 1 then return pts[1][1], pts[1][2], 0 end
    d = math.max(0, math.min(g.len, d))
    for i = 1, g.segs do
        if d <= acc[i + 1] or i == g.segs then
            local a, b = pts[i], pts[i % #pts + 1]
            local sl = acc[i + 1] - acc[i]
            local k = sl > 0 and (d - acc[i]) / sl or 0
            return a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k, math.atan2(b[2] - a[2], b[1] - a[1])
        end
    end
end
CC.pointAt = pointAt

-- El ciclo del avance: ida y vuelta = 2 × largo; circuito = el largo
function CC:cycle() return self.geo.loop and self.geo.len or 2 * self.geo.len end
-- Dónde está la cabina `i` (distancia por el cable) con el avance `u`
function CC:cabinDist(i, u)
    local n, L = self.props.cabins or 1, self.geo.len
    local c = self:cycle()
    local v = ((u or self.u) + (i - 1) * c / n) % c
    if self.geo.loop then return v end
    return (v <= L) and v or (2 * L - v)
end
function CC:cabinPos(i, u)
    local x, y = pointAt(self.geo, self:cabinDist(i, u))
    return x, y
end

local function deckPart(owner, i)
    local part = { owner = owner, idx = i, solidFull = true, oneway = true, moves = true, alive = true }
    function part:getOuterBounds(into)
        local x, y = owner:cabinPos(i)
        local b = into or {}
        b.x, b.y, b.w, b.h = x - CAB_W / 2, y + DECK_Y, CAB_W, DECK_H
        return b
    end
    return part
end

function CC:init()
    self.moving, self.flying, self.vx, self.vy = false, true, 0, 0
    self.geo = CC.pathOf(self.col, self.row, self.props)
    self.u, self.waitT, self.lightT = 0, 0, 0
    self.state, self.deadTimer = 'idle', 0
    local n = math.max(1, self.props.cabins or 1)
    self.parts = self.parts or {}
    for i = 1, n do self.parts[i] = self.parts[i] or deckPart(self, i) end
    for i = n + 1, #self.parts do self.parts[i] = nil end
end
function CC:bodyParts() return self.parts end
function CC:canBeStomped() return false end
function CC:canBeKnocked() return false end
function CC:canFreeze() return false end
function CC:isObstacle() return false end
function CC:isGhost() return true end
function CC:interact() return nil end

function CC:isle() return Isles.of(self.levelRef, self.props.isle) end

-- ¿Hay algo encima de alguna cabina? (jugadores de pie, entidades apoyadas: systems/Weight)
function CC:weighted(level)
    for _, part in ipairs(self.parts) do
        local pl, ents = Weight.stack(part, level, self)
        if pl[1] or ents[1] then return true end
    end
    return false
end

-- Avanza el cable `du` px (> 0), parándose si una cabina llega a un extremo (`stops`): devuelve lo que avanzó
function CC:advance(du)
    local stops = self.props.stops or 0
    local u0, L, c, n = self.u, self.geo.len, self:cycle(), #self.parts
    local u1 = u0 + du
    if stops > 0 then
        local best
        for i = 1, n do
            local off = (i - 1) * c / n
            -- (la última vez que la cabina i cruza un extremo en este paso; con margen: un paso que se queda a 1e-7 de
            -- él cuenta como llegar, si no el siguiente lo saltaba)
            local q1 = math.floor((u1 + off) / L + 1e-6)
            local uc = q1 * L - off
            if uc > u0 + 1e-6 and uc <= u1 + 1e-4 and (not best or uc < best) then best = uc end
        end
        if best then u1 = best; self.waitT = stops end
    end
    self.u = u1 % c
    return u1 - u0
end

-- Lo que va encima de cada plataforma (entidades: los jugadores van solos, standBody) se mueve con ella
local B0, B1 = {}, {}
local function carryRiders(self, level, before)
    for i, part in ipairs(self.parts) do
        local ents = before[i]
        if ents and ents[1] then
            local b1 = part:getOuterBounds(B1)
            local dx, dy = b1.x - before.bx[i], b1.y - before.by[i]
            for _, e in ipairs(ents) do
                -- (de lado: si hay un bloque delante no pasa — la plataforma sale de debajo y se cae —; lo que ya va solo
                -- con el cuerpo que pisa — `ridesMoving`: la Caja — no)
                if dx ~= 0 and not e.ridesMoving then
                    local hw, hh = (e.outerW or T) / 2, (e.outerH or T) / 2
                    local edge = e.x + (dx > 0 and hw or -hw) + dx
                    if not (level:collisionAt(edge, e.y - hh + 4) or level:collisionAt(edge, e.y + hh - 4)) then e.x = e.x + dx end
                end
                if dy ~= 0 then
                    local hh = (e.outerH or T) / 2
                    if dy > 0 or not level:collisionAt(e.x, e.y - hh + dy) then e.y = e.y + dy end
                end
            end
        end
    end
end

function CC:updateCustom(dt, level)
    self.levelRef, self.simulated = level, true
    local p = self.props
    local speed = (p.speed or 2) * T
    local heavy = self:weighted(level)
    if heavy then self.lightT = 0 else self.lightT = (self.lightT or 0) + dt end
    local was = self.state
    -- lo que hay encima ANTES de moverse
    local before = { bx = {}, by = {} }
    for i, part in ipairs(self.parts) do
        local _, ents = Weight.stack(part, level, self)
        before[i] = ents
        local b = part:getOuterBounds(B0)
        before.bx[i], before.by[i] = b.x, b.y
    end
    local moved = 0
    if self.waitT > 0 then
        self.waitT = self.waitT - dt
        self.state = 'waiting'
    elseif p.onWeight and not heavy then
        -- sin peso: quieto, o de vuelta al principio (`back`) tras un momento
        if p.back ~= false and self.u ~= 0 and self.lightT >= BACK_DELAY then
            local c, L = self:cycle(), self.geo.len
            local step = speed * dt
            if not self.geo.loop and self.u <= L then
                local nu = math.max(0, self.u - step); moved = self.u - nu; self.u = nu
            else
                local nu = math.min(c, self.u + step); moved = nu - self.u; self.u = nu % c
            end
            self.state = 'moving'
        else
            self.state = 'idle'
        end
    else
        moved = self:advance(speed * dt)
        self.state = (self.waitT > 0) and 'waiting' or 'moving'
    end
    if self.state ~= was then self.deadTimer = 0 else self.deadTimer = self.deadTimer + dt end
    carryRiders(self, level, before)
    -- sonidos: desde la cabina más cerca de un jugador
    local function near()
        local best, bx, by
        for i = 1, #self.parts do
            local x, y = self:cabinPos(i)
            for _, pa in ipairs(level.players or {}) do
                local d = (x - pa.x) ^ 2 + (y - pa.y) ^ 2
                if not best or d < best then best, bx, by = d, x, y + DECK_Y / 2 end
            end
        end
        return bx or self.x, by or self.y
    end
    if self.state == 'moving' and moved ~= 0 then
        self.sndT = (self.sndT or 0) - dt
        if self.sndT <= 0 then Sound.playAt('cablecarMove', near()); self.sndT = MOVE_SND end
    else
        self.sndT = 0
    end
    if (self.state == 'waiting' and was == 'moving') or (was == 'waiting' and self.state == 'moving')
       or (was == 'idle' and self.state == 'moving') then
        Sound.playAt('cablecarStop', near())
    end
    self.spin = (self.spin or 0) + moved
    return true
end

-- ── Bot (src/ai/BotNav.lua) ───────────────────────────────────────────────────
-- Poses del grafo: el avance en reposo (0) y repartido por el recorrido (como mucho MAX_POSES)
function CC:navPoses()
    local c = self:cycle()
    local n = math.max(1, math.min(MAX_POSES, math.floor(c / T)))
    local list = {}
    for k = 0, n - 1 do list[#list + 1] = k * c / n end
    return list
end
function CC:navPose(u) self.u = u end

-- ── Red ───────────────────────────────────────────────────────────────────────
function CC:netAtRest() return self.state == 'idle' and self.u == 0 end
function CC:netRest() self.u, self.state = 0, 'idle' end
function CC:netPack() return { math.floor(self.u * 4 + 0.5) } end
function CC:netApply(a, b, f)
    local ua, ub = (a[1] or 0) / 4, (b[1] or 0) / 4
    local c = self:cycle()
    -- (el avance da la vuelta: se interpola por el camino corto)
    if ub - ua > c / 2 then ua = ua + c elseif ua - ub > c / 2 then ub = ub + c end
    local u = (ua + (ub - ua) * f) % c
    self.spin = (self.spin or 0) + math.abs(u - (self.u or 0)) % c
    self.u = u
end
-- La caja de todo el cable con sus cabinas (server/main.lua: se manda a quien la tenga cerca)
function CC:netBounds()
    local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
    for _, q in ipairs(self.geo.pts) do
        x0, x1 = math.min(x0, q[1]), math.max(x1, q[1])
        y0, y1 = math.min(y0, q[2]), math.max(y1, q[2])
    end
    return x0 - CAB_W / 2, y0, x1 + CAB_W / 2, y1 + DECK_Y + DECK_H
end

-- F1: las plataformas y el cable
function CC:debugBoxes()
    local out = {}
    for _, part in ipairs(self.parts) do
        local b = part:getOuterBounds({})
        out[#out + 1] = { x = b.x, y = b.y, w = b.w, h = b.h, kind = 'area' }
    end
    return out
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
local imgs = {}
local function art(isle)
    if not imgs[isle] then
        local SpriteStrip = require 'src/fx/SpriteStrip'
        local b = 'assets/images/mechanisms/cablecar/' .. isle
        imgs[isle] = { cabin = SpriteStrip.load(b .. '-cabin.png', 48), trolley = SpriteStrip.load(b .. '-trolley-Sheet.png', 16),
                       cable = SpriteStrip.load(b .. '-cable.png', 8), pulley = SpriteStrip.load(b .. '-pulley-Sheet.png', 12),
                       tower = SpriteStrip.load(b .. '-tower.png', 16), top = SpriteStrip.load(b .. '-towertop.png', 16),
                       foot = SpriteStrip.load(b .. '-towerfoot.png', 16), hanger = SpriteStrip.load(b .. '-hanger.png', 4),
                       clamp = SpriteStrip.load(b .. '-clamp.png', 8) }
    end
    return imgs[isle]
end

-- De qué se sujeta cada polea (se mira una vez: el nivel no se mueve): { 'tower', ySuelo } o { 'hang', yTecho }
local GROUND_MAX = 14 * T
local function firstHit(level, x, y0, y1, step)
    for yy = y0, y1, step do
        local t = level:collisionAt(x, yy, true)
        if t then
            local c, r = math.floor(x / T) + 1, math.floor(yy / T) + 1
            local _, hy, _, hh = TileTypes.worldHitbox(t, c, r)
            return hy or yy, (hy or yy) + (hh or 0)
        end
    end
end
function CC:supports(level)
    if self.sup and self.supLevel == level then return self.sup end
    local out, bottom = {}, level.heightPx or level.tileH * T
    for i, q in ipairs(self.geo.pts) do
        local x, y = q[1], q[2]
        local gy = firstHit(level, x, y + 8, bottom, 8)
        local _, cy = firstHit(level, x, y - 8, 0, -8)
        if gy and gy - y <= GROUND_MAX then out[i] = { 'tower', gy }     -- (suelo cerca: torre)
        elseif cy then out[i] = { 'hang', cy }                           -- (techo: colgada)
        else out[i] = { 'tower', gy or bottom } end                       -- (suelo lejos o el fondo del nivel)
    end
    self.sup, self.supLevel = out, level
    return out
end

local function drawCable(a, x0, y0, x1, y1, camX, camY)
    local dx, dy = x1 - x0, y1 - y0
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1 then return end
    local ang = math.atan2(dy, dx)
    local step = 8 * S
    local ux, uy = dx / len, dy / len
    for d = step / 2, len - step / 2 + step - 1, step do
        local k = math.min(d, len - step / 2)
        a.cable:draw(1, math.floor(x0 + ux * k - camX), math.floor(y0 + uy * k - camY), ang, S, S)
    end
end

function CC:render(camX, camY)
    local a = art(self:isle())
    local level = self.levelRef
    local g = self.geo
    local sup = level and self:supports(level) or {}
    love.graphics.setColor(1, 1, 1, 1)
    -- los APOYOS (detrás de todo): torre hasta el suelo o varilla hasta el techo
    for i, q in ipairs(g.pts) do
        local s = sup[i]
        local x = math.floor(q[1] - camX)
        local py = math.floor(q[2] - camY)
        if s and s[1] == 'tower' then
            -- (torre de celosía de la polea al suelo: remate arriba, zapata abajo)
            local gy = math.floor(s[2] - camY)
            local top = py + 2 * S
            Clip.push(x - T / 2, top, T, math.max(0, gy - 4 * S - top))
            for yy = top, gy, T do a.tower:draw(1, x, yy + T / 2, 0, S, S) end
            Clip.pop()
            a.foot:draw(1, x, gy - 2 * S, 0, S, S)
            a.top:draw(1, x, py + 3 * S, 0, S, S)
        elseif s then
            -- (varilla de la polea al techo y su anclaje)
            local cy = math.floor(s[2] - camY)
            local bot = py - 5 * S
            Clip.push(x - 2 * S, cy, 4 * S, math.max(0, bot - cy))
            for yy = bot, cy - 8 * S, -8 * S do a.hanger:draw(1, x, yy - 4 * S, 0, S, S) end
            Clip.pop()
            a.clamp:draw(1, x, cy + 2 * S, 0, S, S)
        end
    end
    -- el CABLE
    for i = 1, g.segs do
        local p0, p1 = g.pts[i], g.pts[i % #g.pts + 1]
        drawCable(a, p0[1], p0[2], p1[1], p1[2], camX, camY)
    end
    -- las POLEAS
    local fr = 1 + math.floor(math.abs(self.spin or 0) / 24) % 2
    for _, q in ipairs(g.pts) do a.pulley:draw(fr, math.floor(q[1] - camX), math.floor(q[2] - camY), 0, S, S) end
    -- las CABINAS (colgando en vertical) con su carro (girado como el tramo)
    for i = 1, #self.parts do
        local x, y, ang = pointAt(g, self:cabinDist(i))
        local sx, sy = math.floor(x - camX), math.floor(y - camY)
        a.cabin:draw(1, sx, sy + HOOK_Y + 14 * S, 0, S, S)
        a.trolley:draw(fr, sx, sy, ang, S, S)
    end
end

-- Editor: el cable desde la casilla de la entidad al primer punto de `path` (el resto lo dibuja el editor)
function CC.drawEditorOverlay(props, cx, cy, zoom, ctx)
    local k = zoom or 1
    local q = (props.path or {})[1]
    if not q or not ctx then return end
    local col = math.floor((cx + ctx.camX) / ctx.t) + 1
    local row = math.floor((cy + ctx.camY) / ctx.t) + 1
    love.graphics.setColor(1, 0.55, 0.2, 0.9)
    love.graphics.line(cx, cy, cx + (q.col - col) * ctx.t, cy + (q.row - row) * ctx.t)
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawIcon(x, y, s)
    local a = art('pradera')
    love.graphics.setColor(1, 1, 1, 1)
    a.cabin:draw(1, x + s / 2, y + s * 0.62, 0, s / 52, s / 52)
    a.trolley:draw(1, x + s / 2, y + s * 0.12, 0, s / 52, s / 52)
end

return {
    name = 'cablecar', label = 'Teleférico', category = 'Mecanismos', class = CC,
    description = 'Plataforma colgada de un cable tendido entre varios puntos: va y vuelve o da la vuelta en circuito. '
               .. 'Se coloca en el primer punto; los demás se arrastran en el mapa. Lleva a jugadores, cajas y enemigos.',
    defaults = { movement = 'static' }, hide = 'all',
    inBlockOk = true,
    props = {
        { key = 'path', kind = 'points', label = 'Cable (puntos)', group = 'Teleférico', min = 1, max = 16,
          default = function(d) return { { col = (d.col or 1) + 8, row = d.row or 1 } } end,
          help = 'Los puntos por los que pasa el cable, en orden (el primero es la casilla de la entidad)' },
        { key = 'mode', kind = 'enum', label = 'Recorrido', group = 'Teleférico', default = 'pingpong',
          options = { { value = 'pingpong', label = 'Ida y vuelta' }, { value = 'loop', label = 'Circuito (vuelve al primero)' } } },
        { key = 'speed', kind = 'number', label = 'Velocidad (casillas/s)', group = 'Teleférico', default = 2, min = 0.25, max = 8, step = 0.25 },
        { key = 'cabins', kind = 'int', label = 'Cabinas', group = 'Teleférico', default = 1, min = 1, max = 6, step = 1,
          help = 'Repartidas por el cable (en ida y vuelta, dos se cruzan a mitad de camino)' },
        { key = 'stops', kind = 'number', label = 'Espera en los extremos (s)', group = 'Teleférico', default = 0, min = 0, max = 10, step = 0.25,
          help = 'Lo que espera cada cabina al llegar a un extremo (en circuito: al pasar por el primer punto)' },
        { key = 'onWeight', kind = 'bool', label = 'Solo con peso', group = 'Teleférico', default = false,
          help = 'Solo se mueve mientras hay algo encima de alguna cabina' },
        { key = 'back', kind = 'bool', label = 'Vuelve sin peso', group = 'Teleférico', default = true,
          showIf = function(p) return p.onWeight end,
          help = 'Con «Solo con peso»: sin nadie encima, vuelve al principio (si no, se queda donde está)' },
    },
    isleArt = true,
    editor = { draw = drawIcon },
}
