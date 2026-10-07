-- Cristal roto de jefe: EVENTO de la pelea. Cada cierto tiempo (y al cambiar
-- de fase el jefe) el suelo de la arena se llena de cristales rotos y hay que
-- pelear sobre las plataformas.
--
-- Como el bloque de jefe: la casilla de la entidad es la esquina superior
-- izquierda y "Esquina" la inferior derecha; se pinta la fila (o filas) de AIRE
-- justo encima del suelo: los cristales salen apoyados en el borde de abajo.
-- `zone` = id de su zona de jefe (0 = la más cercana).
--
-- Estados (autoritativos: un jugador y servidor; el cliente los recibe):
--   idle → warn (grietas que parpadean: ¡arriba!) → active (cristales) →
--   retract → idle.   Solo durante la pelea de su zona.
-- Disparo: cada `every` s (la primera vez a los `first` s de pelea) y cuando la
-- vida del jefe baja de `phase1` / `phase2` (una vez cada una).
--
-- Tocarlos (activos): 1 de vida (si no es invulnerable) y sale disparado hacia
-- arriba con TODOS los saltos recargados, para poder volver a una plataforma
-- ('launch' en Interactions: el cliente lo predice). Los jefes que lo miran
-- (b:glassDanger) evitan el suelo mientras dura; el Espejo, si cae, también
-- recibe 1 y vuelve de un salto a una plataforma.

local Entity = require 'src/world/entities/base/Entity'

local G = Entity.extend(Entity, { debugColor = { 0.6, 0.9, 1 },
    hitbox = { outerW = 1, outerH = 1, innerW = 1, innerH = 1 } })
G.wantsLevel = true
G.launchSound = 'glassHit'                     -- (el cliente lo toca al predecir el salto)

local SHARD_H   = 0.42                          -- alto de los cristales (casillas)
local RISE_T    = 0.15                          -- s saliendo del suelo
local RETRACT_T = 0.5

function G.loadAssets() end
function G.sizePx() return TILE_PX, TILE_PX end

local function num(v, d) v = tonumber(v); return v and math.floor(v) or d end

function G.rectOf(col, row, props)
    local cr = (props or {}).corner or {}
    local c0, c1 = math.min(col, num(cr.col, col)), math.max(col, num(cr.col, col))
    local r0, r1 = math.min(row, num(cr.row, row)), math.max(row, num(cr.row, row))
    local T = TILE_PX
    return c0, r0, c1, r1, (c0 - 1) * T, (r0 - 1) * T, c1 * T, r1 * T
end

function G:init()
    self.moving, self.flying, self.vx, self.vy = false, true, 0, 0
    self.c0, self.r0, self.c1, self.r1, self.x0, self.y0, self.x1, self.y1 = G.rectOf(self.col, self.row, self.props)
    self.x, self.y = (self.x0 + self.x1) / 2, (self.y0 + self.y1) / 2
    self.outerW, self.outerH = self.x1 - self.x0, self.y1 - self.y0
    self.innerW, self.innerH = self.outerW, self.outerH
    self.state = 'idle'
    self.fightT, self.nextAt, self.phasesDone = 0, nil, {}
end

function G:getOuterBounds() return { x = self.x0, y = self.y0, w = self.x1 - self.x0, h = self.y1 - self.y0 } end
function G:getInnerBounds() return self:getOuterBounds() end
function G:canBeStomped() return false end
function G:canBeKnocked() return false end
function G:canBeLaunched() return false end
function G:isBodyDisabled() return true end
function G:isObstacle() return false end
function G:collect() return false end
function G:netAtRest() return self.state == 'idle' end
function G:netRest() self.state, self.deadTimer = 'idle', 0 end

-- ¿Peligro (aviso o cristales)? Lo miran los jefes para evitar el suelo
function G:isDanger() return self.state == 'warn' or self.state == 'active' end
function G:isActiveGlass()
    return self.state == 'active' or (self.state == 'retract' and (self.deadTimer or 0) < 0.15)
end

function G:isGhost() return not self:isActiveGlass() end

-- Caja que hace daño: los cristales, apoyados en el borde de abajo
function G:debugBoxes()                                   -- (F1: los cristales, cuando lanzan y dañan)
    if not self:isDanger() then return nil end
    local b = self:glassBox()
    return { b }
end
function G:glassBox()
    local h = SHARD_H * TILE_PX
    return { x = self.x0, y = self.y1 - h, w = self.x1 - self.x0, h = h }
end
-- ¿Está (x, y) sobre los cristales? (reapariciones: nunca ahí mientras hay peligro)
function G:unsafeAt(x, y)
    return self:isDanger() and x >= self.x0 and x <= self.x1 and y >= self.y0 - TILE_PX and y <= self.y1
end

local function overlap(a, b) return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y end

-- Sin efectos (el cliente lo usa para predecir): lanzado hacia arriba con los
-- saltos recargados si toca los cristales y no va ya subiendo
function G:interact(pa)
    if not self:isActiveGlass() or pa.dying then return nil end
    if pa.vy < -120 then return nil end
    if not overlap(pa:getOuterBounds(), self:glassBox()) then return nil end
    return 'launch', 0, -(self.props.launchSpeed or 900), 2
end

-- Autoritativo (un jugador / servidor): el daño
function G:onLaunch(pa)
    Sound.play('glassHit')
    Entity.emitFx('mirror_shards', pa.x, self.y1 - 8)
    if not pa:isInvulnerable() then
        local hp0 = pa.hp
        require('src/player/PlayerAdventure').asOwner(pa, function() pa:hurt(self.props.damage or 1) end)
        if pa.hp < hp0 and pa.dying then return end
    end
end

-- Su zona de jefe (por id, o la más cercana)
function G:findZone(level)
    local want, best, bd = self.props.zone or 0, nil, nil
    for _, z in ipairs(level.bossZones or {}) do
        if want > 0 then
            if z.id == want then return z end
        else
            local dx = math.max(z.x0 - self.x1, 0, self.x0 - z.x1)
            local dy = math.max(z.y0 - self.y1, 0, self.y0 - z.y1)
            local d = dx * dx + dy * dy
            if not bd or d < bd then best, bd = z, d end
        end
    end
    return best
end

-- Vida del jefe de la zona (fracción), para las fases
local function bossRatio(z)
    local r
    for _, b in ipairs(z.bosses or {}) do
        if b.alive and (b.hpMax or 0) > 0 then r = math.min(r or 1, (b.hp or 0) / b.hpMax) end
    end
    return r
end

function G:updateCustom(dt, level)
    self.levelRef = level
    self.zoneRef = self.zoneRef or self:findZone(level)
    local z, p = self.zoneRef, self.props
    local fighting = z ~= nil and z.state == 'fight'
    local st = self.state
    self.deadTimer = self.deadTimer + dt
    if not fighting then
        if st == 'warn' or st == 'active' then self.state, self.deadTimer = 'retract', 0 end
        if self.state == 'retract' and self.deadTimer >= RETRACT_T then self.state = 'idle' end
        self.fightT, self.nextAt, self.phasesDone = 0, nil, {}
        return true
    end
    self.fightT = self.fightT + dt
    self.nextAt = self.nextAt or (p.first or 15)
    if st == 'idle' then
        local go = self.fightT >= self.nextAt
        -- Cambio de fase del jefe: una vez cada umbral
        local r = bossRatio(z)
        for i, key in ipairs({ 'phase1', 'phase2' }) do
            local at = p[key] or (i == 1 and 0.66 or 0.33)
            if at > 0 and r and r <= at and not self.phasesDone[i] then self.phasesDone[i], go = true, true end
        end
        if go then
            self.state, self.deadTimer = 'warn', 0
            Sound.play('glassWarn')
        end
    elseif st == 'warn' then
        if self.deadTimer >= (p.warnTime or 2.2) then
            self.state, self.deadTimer = 'active', 0
            Sound.play('glassRise')
            Entity.emitFx('shake_small', self.x, self.y1)
            local T, n = TILE_PX, 0
            for c = self.c0, self.c1, 2 do
                n = n + 1
                if n <= 10 then Entity.emitFx('mirror_shards', (c - 0.5) * T, self.y1 - 10) end
            end
        end
    elseif st == 'active' then
        if self.deadTimer >= (p.activeTime or 7) then
            self.state, self.deadTimer = 'retract', 0
            Sound.play('mirrorAppear', 0.8)
        end
    elseif st == 'retract' then
        if self.deadTimer >= RETRACT_T then
            self.state, self.deadTimer = 'idle', 0
            self.nextAt = self.fightT + (p.every or 25)
        end
    end
    return true
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
-- Cristales: púas finas y torcidas de alturas distintas (siempre las mismas
-- para cada columna), celestes y blancas con borde oscuro y destellos
local function hash(i) local v = math.sin(i * 12.9898) * 43758.5453; return v - math.floor(v) end

local function drawShards(x0, x1, baseY, k, now, alpha)
    local T = TILE_PX
    local step = 12
    local i = 0
    for x = x0, x1 - step, step do
        i = i + 1
        local h = math.floor((0.45 + 0.55 * hash(i + x * 0.01)) * SHARD_H * T * k)
        if h > 2 then
            local w = 10 + math.floor(hash(i * 3.1) * 6)
            local lean = math.floor((hash(i * 7.7) - 0.5) * 10)
            local cx = x + step / 2
            local bx0, bx1 = cx - w / 2, cx + w / 2
            local tx, ty = cx + lean, baseY - h
            love.graphics.setColor(0.05, 0.1, 0.2, 0.85 * alpha)
            love.graphics.polygon('fill', bx0 - 2, baseY, bx1 + 2, baseY, tx, ty - 3)
            local cyan = hash(i * 5.3) < 0.5
            love.graphics.setColor(cyan and 0.62 or 0.85, cyan and 0.88 or 0.95, 1, 0.9 * alpha)
            love.graphics.polygon('fill', bx0, baseY, bx1, baseY, tx, ty)
            love.graphics.setColor(1, 1, 1, 0.8 * alpha)                     -- filo claro
            love.graphics.polygon('fill', bx0 + 2, baseY, bx0 + 4, baseY, tx, ty + 2)
            -- Destello que recorre los cristales
            if math.floor(now * 6 + i * 0.7) % 9 == 0 then
                love.graphics.setColor(1, 1, 1, alpha)
                love.graphics.rectangle('fill', math.floor(tx) - 1, math.floor(ty) - 5, 2, 10)
                love.graphics.rectangle('fill', math.floor(tx) - 5, math.floor(ty) - 1, 10, 2)
            end
        end
    end
end

-- Aviso: grietas blancas en zigzag sobre el suelo y un brillo rojo que late
local function drawCracks(self, baseY, t, camX)
    local T = TILE_PX
    local k = math.min(1, t / 0.8)                              -- (las grietas van creciendo)
    local on = math.floor(t * (t > 1.4 and 12 or 6)) % 2 == 0
    love.graphics.setColor(1, 0.15, 0.15, on and 0.35 or 0.15)
    love.graphics.rectangle('fill', self.x0 - camX, baseY - 10, self.x1 - self.x0, 10)
    love.graphics.setColor(0.9, 0.97, 1, 0.9)
    local i = 0
    for x = self.x0 - camX, self.x1 - camX - T, T / 2 do
        i = i + 1
        if hash(i * 2.3) < k then
            local px, py = x + hash(i) * T * 0.3, baseY - 2
            for s = 1, 4 do
                local nx = px + 6 + hash(i * s) * 6
                local ny = baseY - 2 - ((s % 2 == 0) and 0 or 5)
                love.graphics.line(math.floor(px), math.floor(py), math.floor(nx), math.floor(ny))
                px, py = nx, ny
            end
        end
    end
end

function G:render(camX, camY)
    local st, t = self.state, self.deadTimer or 0
    local baseY = math.floor(self.y1 - camY)
    local now = love.timer.getTime()
    if EDITOR_VIEW then
        drawShards(self.x0 - camX, self.x1 - camX, baseY, 1, 0, 0.5)
        love.graphics.setColor(0.6, 0.9, 1, 0.9)
        local x0, y0 = self.x0 - camX, self.y0 - camY
        local w, h = self.x1 - self.x0, self.y1 - self.y0
        for i = 0, w - 1, 12 do
            love.graphics.rectangle('fill', x0 + i, y0, 6, 2); love.graphics.rectangle('fill', x0 + i, y0 + h - 2, 6, 2)
        end
        for i = 0, h - 1, 12 do
            love.graphics.rectangle('fill', x0, y0 + i, 2, 6); love.graphics.rectangle('fill', x0 + w - 2, y0 + i, 2, 6)
        end
        love.graphics.setColor(1, 1, 1, 1)
        return
    end
    love.graphics.setLineStyle('rough')
    love.graphics.setLineWidth(2)
    if st == 'warn' then
        drawCracks(self, baseY, t, camX)
    elseif st == 'active' then
        drawShards(self.x0 - camX, self.x1 - camX, baseY, math.min(1, t / RISE_T), now, 1)
    elseif st == 'retract' then
        local k = 1 - math.min(1, t / RETRACT_T)
        drawShards(self.x0 - camX, self.x1 - camX, baseY, k, now, k)
    end
    love.graphics.setLineWidth(1)
    love.graphics.setLineStyle('smooth')
    love.graphics.setColor(1, 1, 1, 1)
end

function G.drawEditorOverlay(props, cx, cy, zoom, ctx)
    if not ctx then return end
    love.graphics.push()
    love.graphics.translate(cx, cy - TILE_PX / 2 - 18 / zoom); love.graphics.scale(1 / zoom)
    local txt = ((props.zone or 0) > 0) and ('Zona de jefe ' .. props.zone) or 'Zona de jefe: la más cercana'
    love.graphics.setColor(0, 0, 0, 0.6); love.graphics.print(txt, 1, 1)
    love.graphics.setColor(0.6, 0.9, 1, 1); love.graphics.print(txt, 0, 0)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

-- Icono: tres cristales
local function drawIcon(x, y, s)
    local k = s / 16
    love.graphics.setColor(0.62, 0.88, 1, 1)
    love.graphics.polygon('fill', x + 1 * k, y + 15 * k, x + 6 * k, y + 15 * k, x + 3 * k, y + 5 * k)
    love.graphics.polygon('fill', x + 5 * k, y + 15 * k, x + 11 * k, y + 15 * k, x + 8 * k, y + 1 * k)
    love.graphics.polygon('fill', x + 10 * k, y + 15 * k, x + 15 * k, y + 15 * k, x + 13 * k, y + 7 * k)
    love.graphics.setColor(1, 1, 1, 1)
end

return {
    name = 'bossglass', label = 'Cristal roto de jefe', category = 'Mecanismos',
    description = 'Evento de la pelea: el suelo de la arena se llena de cristales rotos cada cierto tiempo y al '
               .. 'cambiar de fase el jefe. Quita 1 de vida y lanza hacia arriba con los saltos recargados. '
               .. 'Pinta la fila de aire justo encima del suelo.',
    class = G,
    inBlockOk = true,          -- (zona: puede tocar bloques)
    hide = 'all',
    defaults = { movement = 'static' },
    props = {
        { key='corner', kind='point', label='Esquina inferior derecha', group='Área',
          default=function(d) return { col = (d.col or 1) + 8, row = d.row or 1 } end,
          help='Arrastra la cajita en el mapa. Los cristales salen en el borde de abajo del área' },
        { key='zone', kind='int', label='Zona de jefe (id)', group='Evento', default=0, min=0, max=99,
          help='Id de la zona de jefe. 0 = la zona más cercana' },
        { key='first', kind='number', label='Primera vez (s de pelea)', group='Evento', default=15,
          min=1, max=120, step=1 },
        { key='every', kind='number', label='Luego cada (s)', group='Evento', default=25,
          min=5, max=120, step=1, help='Tiempo entre el final de un evento y el siguiente' },
        { key='phase1', kind='number', label='También con vida del jefe ≤', group='Evento', default=0.66,
          min=0, max=1, step=0.01, help='Fracción de vida del jefe que lo dispara una vez (0 = no)' },
        { key='phase2', kind='number', label='Y otra vez con vida ≤', group='Evento', default=0.33,
          min=0, max=1, step=0.01 },
        { key='warnTime', kind='number', label='Aviso (s)', group='Evento', default=2.2,
          min=0.5, max=6, step=0.1, help='Grietas en el suelo antes de que salgan los cristales' },
        { key='activeTime', kind='number', label='Duración (s)', group='Evento', default=7,
          min=1, max=30, step=0.5 },
        { key='damage', kind='int', label='Daño', group='Cristales', default=1, min=1, max=3, step=1 },
        { key='launchSpeed', kind='number', label='Impulso hacia arriba', group='Cristales', default=900,
          min=400, max=1600, step=20, help='px/s (un salto normal: 568). Recarga todos los saltos' },
    },
    editor = { draw = drawIcon },
}
