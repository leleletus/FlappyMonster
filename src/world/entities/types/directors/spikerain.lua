-- Lluvia de pinchos: director que hace caer los "Pinchos de lluvia" de su
-- grupo (rainspike.lua). Es la idea de EvilCaibles del original, pero jugable:
--
--  * Dificultad en OLAS (como EvilCaibles): mínimo → sube → máximo → baja →
--    mínimo... Cada ola llega un poco más arriba (firstPeak + peakGrowth por
--    ola, hasta diffMax). La dificultad (0..1) decide cuántos pinchos puede
--    haber cayendo a la vez, cada cuánto se lanza una tanda y cuánto avisan.
--  * Solo elige pinchos que de verdad pueden alcanzar a alguien: dentro del
--    alcance de un jugador, por encima de él y con el camino libre (un techo
--    en medio = zona segura). Con cierta probabilidad apunta justo encima del
--    jugador, anticipando hacia dónde se mueve.
--  * Reparto justo online: cada pincho de la tanda va a por un jugador
--    distinto (por turnos), y hay un extra de pinchos por jugador.
--  * Separación mínima entre los pinchos de una tanda (siempre hay hueco) y
--    enfriamiento de cada pincho tras volver a salir.
--  * Opcional: solo mientras corre la cámara automática y/o solo en una zona
--    de columnas.
-- En la partida no se ve (en el editor, sí). Lo simula el servidor online.

local Entity = require 'src/world/entities/base/Entity'

local Rain = Entity.extend(Entity, { debugColor = { 1, 0.4, 0.8 },
    hitbox = { outerW = 1, outerH = 1, innerW = 1, innerH = 1 } })

local function rand(a, b) return a + math.random() * (b - a) end
local function lerp(a, b, t) return a + (b - a) * t end

function Rain.loadAssets() end
function Rain.sizePx() return TILE_PX, TILE_PX end

function Rain:init()
    self.moving, self.flying, self.vx, self.vy = false, true, 0, 0
    self.state     = 'idle'
    self.phase     = 'min'       -- 'min' | 'up' | 'max' | 'down'
    self.phaseT    = 0
    self.cycle     = 0           -- olas completadas (cada una llega más arriba)
    self.diff      = 0
    self.runT      = 0
    self.gapT      = 0
    self.turn      = 0
    self.spikes    = nil
    self.readyAt   = setmetatable({}, { __mode = 'k' })   -- [pincho] = clock en que vuelve a estar disponible
    self.prevSt    = setmetatable({}, { __mode = 'k' })
    self.clock     = 0
end

function Rain:canBeStomped() return false end
function Rain:canBeKnocked() return false end
function Rain:isBodyDisabled() return true end
function Rain:isObstacle() return false end
function Rain:isGhost() return true end        -- nada interactúa con él

-- Pinchos de su grupo (se buscan una vez entre las entidades vivas del nivel)
function Rain:link(level)
    self.spikes = {}
    for _, e in ipairs(level.liveEntities or {}) do
        if e.trigger and e.autoDetect == false and (e.props.group or 1) == (self.props.group or 1) then
            table.insert(self.spikes, e)
        end
    end
end

-- Jugadores que cuentan (vivos y, si hay zona, dentro de ella)
function Rain:activePlayers(level)
    local out, zone = {}, self.props.zone
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false then
            local c = math.floor(pa.x / TILE_PX) + 1
            if not zone or (c >= zone.left and c <= zone.right) then out[#out+1] = pa end
        end
    end
    return out
end

-- ── Olas de dificultad (EvilCaibles: Subiendo / EnMaximo / Bajando / EnMinimo) ─
function Rain:updateWave(dt)
    local p = self.props
    self.phaseT = self.phaseT + dt
    local k
    if self.phase == 'min' then
        k = 0
        if self.phaseT >= (p.holdMin or 5) then self.phase, self.phaseT = 'up', 0 end
    elseif self.phase == 'up' then
        k = math.min(1, self.phaseT / math.max(0.1, p.rampUp or 10))
        if self.phaseT >= (p.rampUp or 10) then self.phase, self.phaseT = 'max', 0 end
    elseif self.phase == 'max' then
        k = 1
        if self.phaseT >= (p.holdMax or 5) then self.phase, self.phaseT = 'down', 0 end
    else
        k = math.max(0, 1 - self.phaseT / math.max(0.1, p.rampDown or 8))
        if self.phaseT >= (p.rampDown or 8) then
            self.phase, self.phaseT = 'min', 0
            self.cycle = self.cycle + 1
        end
    end
    local lo = p.diffMin or 0
    local peak = math.min(p.diffMax or 1, (p.firstPeak or 0.55) + (p.peakGrowth or 0.15) * self.cycle)
    self.diff = lerp(lo, math.max(lo, peak), k)
end

-- ¿Puede este pincho llegar a este jugador? (encima, a su alcance, sin techo en medio)
local function clearDrop(level, s, pa, reach)
    local top = pa.y - 16 * PLAYER_SCALE / 2          -- cabeza del jugador (aprox.)
    if s.y >= top or top - s.y > reach then return false end
    local y = s.y + TILE_PX / 2
    while y < top do
        local t = level:collisionAt(s.x, y)
        if t and t.collision == 'solid' then return false end
        y = y + TILE_PX / 2
    end
    return true
end

-- Elige y dispara hasta `n` pinchos
function Rain:volley(level, players, n, warn)
    local p = self.props
    local T = TILE_PX
    local range, reach = (p.range or 7) * T, (p.reach or 12) * T
    local spacing = (p.spacing or 2) * T
    local chosen = {}
    local function farFromChosen(s)
        for _, c in ipairs(chosen) do if math.abs(c.x - s.x) < spacing then return false end end
        return true
    end
    for _ = 1, n do
        -- Por turnos: cada pincho de la tanda va a por un jugador
        local done = false
        for tries = 1, #players do
            self.turn = self.turn % #players + 1
            local pa = players[self.turn]
            local predX = pa.x + (pa.vx or 0) * (p.lead or 0.35)
            local pool, aimed = {}, {}
            for _, s in ipairs(self.spikes) do
                if s.state == 'armed' and self.clock >= (self.readyAt[s] or 0) and farFromChosen(s)
                   and math.abs(s.x - predX) <= range and clearDrop(level, s, pa, reach) then
                    pool[#pool+1] = s
                    if math.abs(s.x - predX) <= (p.aimSpread or 1) * T then aimed[#aimed+1] = s end
                end
            end
            if #aimed > 0 and math.random() < (p.aimChance or 0.55) then pool = aimed end
            if #pool > 0 then
                local s = pool[math.random(#pool)]
                if Sound.withEmitter then Sound.withEmitter(s.x, s.y, function() s:trigger(warn) end)
                else s:trigger(warn) end
                chosen[#chosen+1] = s
                done = true
                break
            end
        end
        if not done then break end
    end
    return #chosen
end

function Rain:updateCustom(dt, level)
    local p = self.props
    self.clock = self.clock + dt
    if not self.spikes then self:link(level) end

    -- Enfriamiento: cuando un pincho vuelve a estar listo, espera un poco más
    local active = 0
    for _, s in ipairs(self.spikes) do
        local st = s.state
        if st == 'armed' and self.prevSt[s] and self.prevSt[s] ~= 'armed' then
            self.readyAt[s] = self.clock + (p.spikeCooldown or 1.5)
        end
        self.prevSt[s] = st
        if st == 'shake' or st == 'falling' then active = active + 1 end
    end

    -- ¿Toca llover?
    local a = level.autoScroll
    if p.onlyWhileScrolling and a and a.state ~= 'run' then self.state = 'idle'; return true end
    local players = self:activePlayers(level)
    if #players == 0 then self.state = 'idle'; return true end
    self.state = 'rain'
    self.runT = self.runT + dt
    if self.runT < (p.startDelay or 2) then return true end

    self:updateWave(dt)
    local d = self.diff
    local maxActive = math.floor(lerp(p.activeEasy or 1, p.activeHard or 4, d)
                                 * (1 + (p.perPlayer or 0.5) * (#players - 1)) + 0.5)
    self.gapT = self.gapT - dt
    if self.gapT <= 0 then
        self.gapT = rand(lerp(p.gapEasyMin or 1.2, p.gapHardMin or 0.3, d),
                         lerp(p.gapEasyMax or 2.6, p.gapHardMax or 0.8, d))
        if active < maxActive then
            -- CicloActivacion: tanda de 1..(huecos libres) pinchos
            local n = math.random(1, maxActive - active)
            self:volley(level, players, n, lerp(p.warnEasy or 0.7, p.warnHard or 0.4, d))
        end
    end
    return true
end

-- En la partida no se ve; en el editor, un icono
local function drawIcon(x, y, s)
    love.graphics.setColor(0.35, 0.15, 0.3, 0.9)
    love.graphics.rectangle('fill', x, y, s, s * 0.35)
    love.graphics.setColor(1, 0.4, 0.8, 1)
    love.graphics.rectangle('line', x, y, s, s * 0.35)
    for i = 0, 3 do
        local cx = x + s * (0.125 + i * 0.25)
        local ty = y + s * (0.55 + (i % 2) * 0.3)
        love.graphics.setColor(0.92, 0.92, 0.92, 1)
        love.graphics.polygon('fill', cx - s * 0.08, y + s * 0.4, cx + s * 0.08, y + s * 0.4, cx, ty)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Rain:render(camX, camY)
    if not EDITOR_VIEW then return end
    drawIcon(math.floor(self.x - camX - TILE_PX / 2), math.floor(self.y - camY - TILE_PX / 2), TILE_PX)
end

-- Editor (seleccionada): sus pinchos, y el alcance alrededor de un jugador
function Rain.drawEditorOverlay(props, cx, cy, zoom, ctx)
    if not ctx then return end
    local T = ctx.t
    love.graphics.setLineWidth(2 / zoom)
    local n = 0
    for _, e in ipairs(ctx.entities) do
        if e.type == 'rainspike' and (e.props.group or 1) == (props.group or 1) then
            n = n + 1
            local ex = (e.col - 1) * T + ((e.sub or 1) - 1) % 2 * T / 2 + T / 4 - ctx.camX
            local ey = (e.row - 1) * T + math.floor(((e.sub or 1) - 1) / 2) * T / 2 + T / 4 - ctx.camY
            love.graphics.setColor(1, 0.4, 0.8, 0.9)
            love.graphics.rectangle('line', ex - T / 4, ey - T / 4, T / 2, T / 2)
        end
    end
    -- Alcance horizontal alrededor de "un jugador" puesto en la lluvia
    local r = (props.range or 7) * T
    love.graphics.setColor(1, 0.4, 0.8, 0.25)
    love.graphics.rectangle('line', cx - r, cy - (props.reach or 12) * T, r * 2, (props.reach or 12) * T)
    love.graphics.setColor(1, 0.4, 0.8, 1)
    love.graphics.print(n .. ' pinchos en el grupo ' .. (props.group or 1), cx - 60, cy + T / 2 + 4)
    love.graphics.setColor(1, 1, 1, 1)
end

return {
    name = 'spikerain', label = 'Lluvia de pinchos', category = 'Directores',
    description = 'Invisible: hace caer los Pinchos de lluvia de su grupo en olas de dificultad.',
    class = Rain,
    hide = 'all',
    defaults = { movement = 'static' },
    props = {
        { key='group', kind='int', label='Grupo', group='Lluvia', default=1, min=1, max=99, step=1,
          help='Hace caer los Pinchos de lluvia con este mismo grupo' },
        { key='zone', kind='patrol', label='Solo en estas columnas', group='Lluvia', default=false,
          help='Si se activa, solo cuenta a los jugadores dentro de estas columnas' },
        { key='onlyWhileScrolling', kind='bool', label='Solo con la cámara en marcha', group='Lluvia', default=true,
          help='Si el nivel tiene camara automatica, solo llueve mientras avanza' },
        { key='startDelay', kind='number', label='Espera inicial (s)', group='Lluvia', default=2,
          min=0, max=60, step=0.5 },
        -- Objetivos
        { key='range', kind='int', label='Alcance (casillas)', group='Objetivo', default=7, min=1, max=40, step=1,
          help='A cuántas casillas de un jugador (a los lados) puede caer un pincho' },
        { key='reach', kind='int', label='Altura máxima (casillas)', group='Objetivo', default=12, min=1, max=60, step=1,
          help='Pinchos más altos que esto por encima del jugador no se eligen' },
        { key='aimChance', kind='number', label='Apunta al jugador', group='Objetivo', default=0.55,
          min=0, max=1, step=0.05, help='Probabilidad de elegir un pincho justo encima (0 = al azar en el alcance)' },
        { key='aimSpread', kind='number', label='Precisión (casillas)', group='Objetivo', default=1,
          min=0, max=10, step=0.5, help='Cuánto de "justo encima" cuenta al apuntar' },
        { key='lead', kind='number', label='Anticipación (s)', group='Objetivo', default=0.35,
          min=0, max=2, step=0.05, help='Apunta a donde estará el jugador dentro de este tiempo' },
        { key='spacing', kind='number', label='Separación (casillas)', group='Objetivo', default=2,
          min=0, max=20, step=0.5, help='Entre los pinchos de una misma tanda: siempre deja hueco' },
        { key='spikeCooldown', kind='number', label='Descanso por pincho (s)', group='Objetivo', default=1.5,
          min=0, max=30, step=0.5, help='Tras volver a salir del techo, tarda esto en poder caer otra vez' },
        { key='perPlayer', kind='number', label='Extra por jugador', group='Objetivo', default=0.5,
          min=0, max=3, step=0.1, help='Más pinchos a la vez por cada jugador además del primero (0.5 = +50%)' },
        -- Olas
        { key='diffMin', kind='number', label='Dificultad mínima', group='Olas', default=0, min=0, max=1, step=0.05 },
        { key='diffMax', kind='number', label='Dificultad máxima', group='Olas', default=1, min=0, max=1, step=0.05 },
        { key='firstPeak', kind='number', label='Pico de la 1a ola', group='Olas', default=0.55, min=0, max=1, step=0.05,
          help='Hasta dónde sube la primera ola' },
        { key='peakGrowth', kind='number', label='Sube cada ola', group='Olas', default=0.15, min=0, max=1, step=0.05,
          help='Cada ola llega esto más arriba (hasta la dificultad máxima)' },
        { key='holdMin', kind='number', label='Calma (s)', group='Olas', default=5, min=0, max=60, step=0.5 },
        { key='rampUp', kind='number', label='Subida (s)', group='Olas', default=10, min=0.5, max=120, step=0.5 },
        { key='holdMax', kind='number', label='En el pico (s)', group='Olas', default=5, min=0, max=60, step=0.5 },
        { key='rampDown', kind='number', label='Bajada (s)', group='Olas', default=8, min=0.5, max=120, step=0.5 },
        -- Fácil / difícil
        { key='activeEasy', kind='int', label='A la vez (fácil)', group='Fácil / difícil', default=1, min=0, max=30, step=1 },
        { key='activeHard', kind='int', label='A la vez (difícil)', group='Fácil / difícil', default=4, min=1, max=30, step=1 },
        { key='gapEasyMin', kind='number', label='Entre tandas, fácil mín. (s)', group='Fácil / difícil', default=1.2, min=0.05, max=20, step=0.05 },
        { key='gapEasyMax', kind='number', label='Entre tandas, fácil máx. (s)', group='Fácil / difícil', default=2.6, min=0.05, max=20, step=0.05 },
        { key='gapHardMin', kind='number', label='Entre tandas, difícil mín. (s)', group='Fácil / difícil', default=0.3, min=0.05, max=20, step=0.05 },
        { key='gapHardMax', kind='number', label='Entre tandas, difícil máx. (s)', group='Fácil / difícil', default=0.8, min=0.05, max=20, step=0.05 },
        { key='warnEasy', kind='number', label='Aviso fácil (s)', group='Fácil / difícil', default=0.7, min=0.05, max=3, step=0.05,
          help='Lo que tiemblan antes de caer con la dificultad al mínimo' },
        { key='warnHard', kind='number', label='Aviso difícil (s)', group='Fácil / difícil', default=0.4, min=0.05, max=3, step=0.05 },
    },
    editor = { draw = drawIcon },
}
