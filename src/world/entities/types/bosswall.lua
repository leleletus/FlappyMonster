-- Bloque de jefe: un rectángulo de bloques normales que empieza INVISIBLE y
-- traspasable. Cuando empieza la pelea de su zona de jefe aparece (animación)
-- y funciona como un bloque normal (p. ej. cierra la puerta de la arena);
-- cuando la zona queda superada (o vuelve a esperar) desaparece.
--
-- Como la inundación: la casilla de la entidad es la esquina superior
-- izquierda y la cajita "Esquina" la inferior derecha. `zone` = id de su zona
-- de jefe (0 = la más cercana). Es un cuerpo sólido (solidFull) mientras está
-- activo: bloquea a jugadores y entidades, y se puede trepar.
--
-- Estados (autoritativos: un jugador y servidor; el cliente los recibe):
--   hidden → appearing → solid → vanishing → hidden
-- Si al terminar de aparecer hay un jugador dentro, espera a que salga (nadie
-- se queda encerrado dentro del bloque).

local Entity    = require 'src/world/entities/Entity'
local TileTypes = require 'src/world/tiles/TileTypes'

local BW = Entity.extend(Entity, { debugColor = { 0.6, 0.6, 0.7 },
    hitbox = { outerW = 1, outerH = 1, innerW = 1, innerH = 1 } })
BW.solidFull = true
BW.wantsLevel = true         -- (BossZones.link le da el nivel: bordes como los bloques)

function BW.loadAssets() end
function BW.sizePx() return TILE_PX, TILE_PX end

local function num(v, d) v = tonumber(v); return v and math.floor(v) or d end

-- Rectángulo (casillas y px) a partir de la colocación
function BW.rectOf(col, row, props)
    local cr = (props or {}).corner or {}
    local c0, c1 = math.min(col, num(cr.col, col)), math.max(col, num(cr.col, col))
    local r0, r1 = math.min(row, num(cr.row, row)), math.max(row, num(cr.row, row))
    local T = TILE_PX
    return c0, r0, c1, r1, (c0 - 1) * T, (r0 - 1) * T, c1 * T, r1 * T
end

function BW:init()
    self.moving, self.flying, self.vx, self.vy = false, true, 0, 0
    self.c0, self.r0, self.c1, self.r1, self.x0, self.y0, self.x1, self.y1 = BW.rectOf(self.col, self.row, self.props)
    self.x, self.y = (self.x0 + self.x1) / 2, (self.y0 + self.y1) / 2
    self.outerW, self.outerH = self.x1 - self.x0, self.y1 - self.y0
    self.innerW, self.innerH = self.outerW, self.outerH
    self.state = 'hidden'
end

function BW:getOuterBounds() return { x = self.x0, y = self.y0, w = self.x1 - self.x0, h = self.y1 - self.y0 } end
function BW:getInnerBounds() return self:getOuterBounds() end

function BW:isSolidBody() return self.alive and self.state == 'solid' end

-- Se dibuja como bloques de su material (prop `material`: piedra, tierra, césped,
-- arena o nieve; con el dibujo real de ese tile): sólido, los bloques 'ground' de al lado
-- (grandes, mini bloques y otros bloques de jefe) se unen con él sin borde
-- (TileTypes.joinsCell; BossZones.link lo apunta en level.joinOverlay)
function BW:joinsCell(c, r, group)
    return group == 'ground' and self.alive and self.state == 'solid'
       and c >= self.c0 and c <= self.c1 and r >= self.r0 and r <= self.r1
end
function BW:canBeStomped() return false end
function BW:canBeKnocked() return false end
function BW:canBeLaunched() return false end
function BW:isBodyDisabled() return true end
function BW:isObstacle() return false end
function BW:isGhost() return self.state ~= 'solid' end
function BW:interact() return nil end
function BW:collect() return false end

-- Invisible y en su sitio de siempre: no se envía por red
function BW:netAtRest() return self.state == 'hidden' end
function BW:netRest() self.state, self.deadTimer = 'hidden', 0 end

-- Su zona de jefe (por id, o la más cercana)
function BW:findZone(level)
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

local function overlap(a, b) return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y end

-- Polvo en sus casillas al aparecer / desaparecer (lo manda el servidor)
function BW:cellFx(kind)
    local T, n = TILE_PX, 0
    for c = self.c0, self.c1 do
        for r = self.r0, self.r1 do
            n = n + 1
            if n <= 12 then Entity.emitFx(kind, (c - 0.5) * T, (r - 0.5) * T) end
        end
    end
end

function BW:updateCustom(dt, level)
    self.levelRef = level
    self.zoneRef = self.zoneRef or self:findZone(level)
    local z = self.zoneRef
    local active = z ~= nil and z.state == 'fight'
    local st = self.state
    self.deadTimer = self.deadTimer + dt
    if st == 'hidden' then
        if active then
            self.state, self.deadTimer = 'appearing', 0
            Sound.play('blockBreak', 0.6)
            self:cellFx('gp_start')
        end
    elseif st == 'appearing' then
        if not active then
            self.state, self.deadTimer = 'vanishing', 0
        elseif self.deadTimer >= (self.props.appearTime or 0.5) then
            -- Solo se cierra si no hay nadie dentro
            local me, clear = self:getOuterBounds(), true
            for _, pa in ipairs(level.players or {}) do
                if not pa.dying and overlap(pa:getOuterBounds(), me) then clear = false end
            end
            if clear then
                self.state, self.deadTimer = 'solid', 0
                Sound.play('gpImpact', 0.8)
                Entity.emitFx('shake_small', self.x, self.y)
            end
        end
    elseif st == 'solid' then
        if not active then
            self.state, self.deadTimer = 'vanishing', 0
            Sound.play('respawnFx', 0.7)
            self:cellFx('smoke')
        end
    elseif st == 'vanishing' then
        if active then
            self.state, self.deadTimer = 'appearing', 0
        elseif self.deadTimer >= (self.props.vanishTime or 0.6) then
            self.state, self.deadTimer = 'hidden', 0
        end
    end
    return true
end

-- ── Dibujo: como un bloque normal (mismos colores y bordes) ──────────────────

-- Cada casilla aparece / desaparece con un poco de retraso según su posición
local function cellK(self, c, r, t, dur, appearing)
    local n = math.max(1, (self.c1 - self.c0) + (self.r1 - self.r0))
    local delay = ((c - self.c0) + (r - self.r0)) / n * dur * 0.5
    local k = math.max(0, math.min(1, (t - delay) / (dur * 0.5)))
    return appearing and k or 1 - k
end

function BW:render(camX, camY)
    local st, t = self.state, self.deadTimer or 0
    local T = TILE_PX
    local def = TileTypes.byName[self.props.material or 'solid'] or TileTypes.byName.solid
    if st == 'hidden' and not EDITOR_VIEW then return end
    local level = self.levelRef
    local appearing = st == 'appearing'
    local dur = appearing and (self.props.appearTime or 0.5) or (self.props.vanishTime or 0.6)
    for c = self.c0, self.c1 do
        for r = self.r0, self.r1 do
            local k = 1
            if st == 'appearing' or st == 'vanishing' then k = cellK(self, c, r, t, dur, appearing) end
            if EDITOR_VIEW and st == 'hidden' then k = 1 end
            if k > 0 then
                local x, y = (c - 1) * T - camX, (r - 1) * T - camY
                -- Crece desde el centro de la casilla (con un pequeño rebote)
                local s = (k < 1) and (k + math.sin(k * math.pi) * 0.15) or 1
                local sz = math.floor(T * s + 0.5)
                local ox, oy = math.floor(x + (T - sz) / 2), math.floor(y + (T - sz) / 2)
                -- Aristas: solo las de fuera del rectángulo, con la regla de todos
                -- los bloques (bloques grandes, mini bloques y otros bloques de jefe)
                local function side(inside, name)
                    if inside then return false end
                    if not level then return true end
                    return TileTypes.sideExposure(level, c, r, name, 'ground')
                end
                local e = {
                    top    = side(r > self.r0, 'top'),
                    bottom = side(r < self.r1, 'bottom'),
                    left   = side(c > self.c0, 'left'),
                    right  = side(c < self.c1, 'right'),
                }
                if k < 1 then e = { top = true, bottom = true, left = true, right = true } end
                -- (el dibujo real del tile de su material: césped, transiciones de la arena...)
                TileTypes.drawTile(def, { x = ox, y = oy, size = sz, level = level, col = c, row = r, edges = e })
                if EDITOR_VIEW and st == 'hidden' then
                    love.graphics.setColor(1, 0.35, 0.35, 0.3)       -- (en el editor: aún no está)
                    love.graphics.rectangle('fill', ox, oy, sz, sz)
                end
            end
        end
    end
    if EDITOR_VIEW then                                   -- (en el editor: borde a trazos)
        love.graphics.setColor(1, 0.35, 0.35, 0.9)
        local x0, y0 = self.x0 - camX, self.y0 - camY
        local w, h = self.x1 - self.x0, self.y1 - self.y0
        for i = 0, w - 1, 12 do
            love.graphics.rectangle('fill', x0 + i, y0, 6, 2); love.graphics.rectangle('fill', x0 + i, y0 + h - 2, 6, 2)
        end
        for i = 0, h - 1, 12 do
            love.graphics.rectangle('fill', x0, y0 + i, 2, 6); love.graphics.rectangle('fill', x0 + w - 2, y0 + i, 2, 6)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function BW.drawEditorOverlay(props, cx, cy, zoom, ctx)
    if not ctx then return end
    love.graphics.push()
    love.graphics.translate(cx, cy - TILE_PX / 2 - 18 / zoom); love.graphics.scale(1 / zoom)
    local txt = ((props.zone or 0) > 0) and ('Zona de jefe ' .. props.zone) or 'Zona de jefe: la más cercana'
    love.graphics.setColor(0, 0, 0, 0.6); love.graphics.print(txt, 1, 1)
    love.graphics.setColor(1, 0.5, 0.5, 1); love.graphics.print(txt, 0, 0)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

-- Icono: bloque con un candado
local function drawIcon(x, y, s)
    local k = s / 16
    love.graphics.setColor(0.28, 0.28, 0.32, 1)
    love.graphics.rectangle('fill', x + 1 * k, y + 1 * k, 14 * k, 14 * k)
    love.graphics.setColor(0.46, 0.46, 0.52, 1)
    love.graphics.rectangle('line', x + 1 * k, y + 1 * k, 14 * k, 14 * k)
    love.graphics.setColor(1, 0.4, 0.4, 1)
    love.graphics.rectangle('fill', x + 5 * k, y + 7 * k, 6 * k, 5 * k)
    love.graphics.rectangle('line', x + 6 * k, y + 4 * k, 4 * k, 4 * k)
    love.graphics.setColor(1, 1, 1, 1)
end

return {
    name = 'bosswall', label = 'Bloque de jefe', category = 'Mecanismos',
    description = 'Bloques invisibles y traspasables que aparecen al empezar la pelea de su zona de jefe '
               .. '(p. ej. para cerrar la arena) y desaparecen al vencer al jefe.',
    class = BW,
    inBlockOk = true,          -- (son bloques: su celda puede estar dentro de otros)
    hide = 'all',
    defaults = { movement = 'static' },
    props = {
        { key='corner', kind='point', label='Esquina inferior derecha', group='Área',
          default=function(d) return { col = d.col or 1, row = (d.row or 1) + 2 } end,
          help='Arrastra la cajita en el mapa. La casilla de la entidad es la esquina superior izquierda' },
        { key='zone', kind='int', label='Zona de jefe (id)', group='Bloque', default=0, min=0, max=99,
          help='Id de la zona de jefe que lo activa. 0 = la zona más cercana' },
        { key='appearTime', kind='number', label='Aparece en (s)', group='Bloque', default=0.5,
          min=0.1, max=3, step=0.05 },
        { key='vanishTime', kind='number', label='Desaparece en (s)', group='Bloque', default=0.6,
          min=0.1, max=3, step=0.05 },
        { key='material', kind='enum', label='Material', group='Bloque', default='solid',
          options = { { value='solid', label='Piedra' }, { value='dirt', label='Tierra' }, { value='grass', label='Césped' },
                      { value='sand', label='Arena' }, { value='snow', label='Nieve' } },
          help='Aspecto de los bloques: el mismo que el suelo o las paredes de la arena' },
    },
    editor = { draw = drawIcon },
}
