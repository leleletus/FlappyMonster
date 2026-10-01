-- Pez globo: enemigo exclusivo del agua. Nada en un plano POR DELANTE del
-- juego (atraviesa bloques, plataformas y objetos; se dibuja delante de los
-- jugadores: renderFront) explorando libremente su ÁREA DE NADO: un polígono
-- (prop `area`, de 3 a 24 puntos = centros de casilla; puede ser irregular y
-- cóncavo). Elige puntos al azar dentro del área a los que se llega en línea
-- recta SIN salir de ella, nada hasta allí, a veces se para un momento y
-- vuelve a elegir. (Solo simula quien manda: un jugador / servidor.)
-- Cuando un jugador que está EN EL AGUA se le acerca (`range` casillas):
--   warn (medio hinchado, aviso) → inflated (hinchado: pincha, 1 de vida y
--   empujón) → deflate → sigue nadando (`cooldown` s sin volver a hincharse).
-- Deshinchado no hace nada. No se le puede matar (no cuenta para Cacería).
--
-- Sprites: assets/images/puffer_fish/puffer_fish-Sheet.png, cuadros de 16x16
-- mirando a la DERECHA (a la izquierda se espeja): nadar (1 o 2 cuadros, se
-- alternan), medio hinchado, hinchado. Con 3 cuadros nada con el primero.
-- Sonidos: pufferWarn / pufferInflate / pufferDeflate / pufferPrick.
local Entity      = require 'src/world/entities/Entity'
local SpriteStrip = require 'src/fx/SpriteStrip'

local S = 5                    -- escala del pixel art
local SHEET = 'assets/images/puffer_fish/puffer_fish-Sheet.png'
-- Cuerpo hinchado dentro del cuadro (px del sprite, mirando a la derecha):
-- columnas 4..14, filas 4..13 (sin la cola). La caja que pincha es un poco
-- menor (HURT_K) para que no pinche "por el aire" en las esquinas.
local BODY_X0, BODY_X1, BODY_Y0, BODY_Y1 = 4, 15, 4, 14
local HURT_K = 0.85
local DEFLATE_T = 0.4          -- s de la animación de deshincharse
local ARRIVE    = 14           -- px: ha llegado a su destino
local POP_T     = 0.12         -- s del "pop" al hincharse del todo (solo dibujo)
local SWIM_FPS  = 2.5          -- cambios de cuadro por segundo al nadar (no cambia su velocidad)

local Puffer = Entity.extend(Entity, {
    debugColor = { 1, 0.8, 0.2 },
    hitbox = { outerW = 0.6, outerH = 0.5, innerW = 0.5, innerH = 0.4 },
})
Puffer.renderFront = true
Puffer.freezeFloats = true      -- (congelado: el bloque de hielo flota donde estaba)

local strip

function Puffer.loadAssets()
    if strip then return end
    strip = SpriteStrip.load(SHEET, 16)
end

function Puffer.sizePx() return 16 * S, 16 * S end

-- ── Área de nado (polígono en px de mundo: centros de las casillas) ──────────
local function inside(poly, x, y)
    local c, n = false, #poly
    local j = n
    for i = 1, n do
        local a, b = poly[i], poly[j]
        if (a[2] > y) ~= (b[2] > y) and x < (b[1] - a[1]) * (y - a[2]) / (b[2] - a[2]) + a[1] then c = not c end
        j = i
    end
    return c
end

-- ¿El tramo recto de (x0,y0) a (x1,y1) queda dentro del área? (cada 12 px)
local function segInside(poly, x0, y0, x1, y1)
    local d = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
    local n = math.max(1, math.ceil(d / 12))
    for i = 1, n do
        local k = i / n
        if not inside(poly, x0 + (x1 - x0) * k, y0 + (y1 - y0) * k) then return false end
    end
    return true
end

function Puffer:buildArea()
    local T, pts = TILE_PX, self.props.area
    local poly = {}
    for _, q in ipairs(type(pts) == 'table' and pts or {}) do poly[#poly + 1] = { (q.col - 0.5) * T, (q.row - 0.5) * T } end
    if #poly < 3 then                -- (sin área: un rectángulo alrededor de donde se colocó)
        local x, y = self.home.x, self.home.y
        poly = { { x - 3 * T, y - T }, { x + 3 * T, y - T }, { x + 3 * T, y + T }, { x - 3 * T, y + T } }
    end
    local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
    for _, v in ipairs(poly) do
        x0, y0 = math.min(x0, v[1]), math.min(y0, v[2]); x1, y1 = math.max(x1, v[1]), math.max(y1, v[2])
    end
    self.poly, self.bx0, self.by0, self.bx1, self.by1 = poly, x0, y0, x1, y1
end

-- Nuevo destino: un punto del área al que se llega en línea recta sin salir
-- de ella. Se juntan varios candidatos y casi siempre gana el MÁS LEJANO: así
-- llega a los extremos de cada brazo del área (y desde ahí ve los demás) en
-- vez de quedarse dando vueltas por la parte más grande. Si no encuentra
-- ninguno, vuelve a donde se colocó (o se queda donde está).
function Puffer:pickTarget()
    local poly, best = self.poly, nil
    local here = inside(poly, self.px, self.py)
    local cands = {}
    for try = 1, 60 do
        local x = self.bx0 + math.random() * (self.bx1 - self.bx0)
        local y = self.by0 + math.random() * (self.by1 - self.by0)
        if inside(poly, x, y) and (not here or segInside(poly, self.px, self.py, x, y)) then
            cands[#cands + 1] = { x, y }
            if #cands >= 8 then break end
        end
    end
    if #cands > 0 then
        if math.random() < 0.65 then
            local bd = -1
            for _, c in ipairs(cands) do
                local d = (c[1] - self.px) ^ 2 + (c[2] - self.py) ^ 2
                if d > bd then best, bd = c, d end
            end
        else
            best = cands[math.random(#cands)]
        end
    end
    if not best then
        best = inside(poly, self.home.x, self.home.y) and { self.home.x, self.home.y } or { self.px, self.py }
    end
    self.tx, self.ty = best[1], best[2]
    local d = math.sqrt((self.tx - self.px) ^ 2 + (self.ty - self.py) ^ 2)
    self.goT = d / math.max(10, self.speed) * 2 + 2          -- (tiempo máximo para llegar)
end

function Puffer:init()
    self.flying = true              -- (sin gravedad; su movimiento es propio)
    self.state  = 'walk'
    self.cool   = 0
    self.swimT  = 0
    self.px, self.py, self.vy = self.x, self.y, 0     -- posición sin la oscilación
    self.restT  = 0
    self.poly   = nil               -- (el área se prepara en el primer paso)
end

-- Nada nunca le afecta: ni empujones, ni trampolines, ni es un obstáculo
function Puffer:canBeStomped() return false end
function Puffer:canBeKnocked() return false end
function Puffer:canBeLaunched() return false end
function Puffer:isObstacle() return false end
function Puffer:isBodyDisabled() return true end      -- (solo pincha con la caja de peligro)
function Puffer:canDropNow() return false end

-- Caja que pincha (solo hinchado)
function Puffer:getHazardBoxes()
    if self.state ~= 'inflated' then return nil end
    local w = (BODY_X1 - BODY_X0) * S * HURT_K
    local h = (BODY_Y1 - BODY_Y0) * S * HURT_K
    local cx = ((BODY_X0 + BODY_X1) / 2 - 8) * S * self.facing
    local cy = ((BODY_Y0 + BODY_Y1) / 2 - 8) * S
    return { { x = self.x + cx - w / 2, y = self.y + cy - h / 2, w = w, h = h, effect = 'hurt' } }
end

-- El jugador más cercano que esté en el agua y a su alcance
function Puffer:targetIn(level)
    local r = (self.props.range or 2.5) * TILE_PX
    local best, bd
    for _, pa in ipairs(level.players or {}) do
        if pa.inWater and not pa.dying and pa.alive ~= false then
            local dx, dy = pa.x - self.x, pa.y - self.y
            local d = dx * dx + dy * dy
            if d <= r * r and (not bd or d < bd) then best, bd = pa, d end
        end
    end
    return best
end

-- Pinchazo (Interactions.run, cuando de verdad le quitó vida): suena y lo aparta
function Puffer:onHurtPlayer(pa)
    Sound.play('pufferPrick')
    pa:recoil(pa.x >= self.x and 1 or -1)
end

function Puffer:updateCustom(dt, level)
    local p = self.props
    local st = self.state
    self.deadTimer = self.deadTimer + dt
    self.cool = math.max(0, self.cool - dt)
    local swimming = st == 'walk' or st == 'idle'
    if not self.poly then self:buildArea(); self:pickTarget() end
    -- Movimiento: hacia su destino dentro del área, atravesándolo todo; frena
    -- al hincharse y, al llegar, a veces descansa un momento
    local wx, wy = 0, 0
    if swimming then
        local dx, dy = self.tx - self.px, self.ty - self.py
        local d = math.sqrt(dx * dx + dy * dy)
        self.goT = self.goT - dt
        if self.restT > 0 then
            self.restT = self.restT - dt
            if self.restT <= 0 then self:pickTarget() end
        elseif d < ARRIVE or self.goT <= 0 then
            if math.random() < 0.4 then self.restT = 0.3 + math.random() * 0.9 else self:pickTarget() end
        else
            -- (frena al acercarse al destino)
            local sp = self.speed * math.min(1, d / (TILE_PX * 0.75) + 0.25)
            wx, wy = dx / d * sp, dy / d * sp
        end
    end
    local k = math.min(1, dt * (swimming and 3 or 6))
    self.vx = self.vx + (wx - self.vx) * k
    self.vy = self.vy + (wy - self.vy) * k
    self.px, self.py = self.px + self.vx * dt, self.py + self.vy * dt
    if swimming and math.abs(self.vx) > 6 then self.facing = self.vx > 0 and 1 or -1 end
    self.swimT = self.swimT + dt * (swimming and 1 or 0.4)
    self.x = self.px
    self.y = self.py + math.sin(self.swimT * 1.7) * (p.swimBob or 6)

    if swimming then
        self.state = 'walk'
        local pa = self.cool <= 0 and self:targetIn(level)
        if pa then
            self.state, self.deadTimer = 'warn', 0
            self.facing = (pa.x >= self.x) and 1 or -1
            Sound.play('pufferWarn')
        end
    elseif st == 'warn' then
        if self.deadTimer >= (p.warnTime or 0.6) then
            self.state, self.deadTimer = 'inflated', 0
            Sound.play('pufferInflate')
            Entity.emitFx('puffer_pop', self.x, self.y)
        end
    elseif st == 'inflated' then
        if self.deadTimer >= (p.inflateTime or 2.5) then
            self.state, self.deadTimer = 'deflate', 0
            Sound.play('pufferDeflate')
        end
    elseif st == 'deflate' then
        if self.deadTimer >= DEFLATE_T then
            self.state, self.deadTimer = 'walk', 0
            self.cool = p.cooldown or 1.5
        end
    end
    return true
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
function Puffer:render(camX, camY)
    local n = strip.count
    local half, full = math.max(1, n - 1), n
    local st, t = self.state, self.deadTimer or 0
    local f, k = 1, 1
    if st == 'warn' then
        -- Aviso: primero tiembla entre deshinchado y medio, luego medio hinchado
        f = (t < 0.3 and math.floor(t / 0.06) % 2 == 0) and 1 or half
    elseif st == 'inflated' then
        f = full
        if t < POP_T then k = 1 + 0.18 * math.sin(t / POP_T * math.pi) end
    elseif st == 'deflate' then
        f = (t < DEFLATE_T * 0.6) and half or 1
    elseif n >= 4 then
        f = math.floor((love.timer.getTime() + (self.home and self.home.x or 0) * 0.01) * SWIM_FPS) % 2 + 1
    end
    local x, y = math.floor(self.x - camX), math.floor(self.y - camY)
    -- Temblor del aviso
    if st == 'warn' then x = x + math.floor(math.sin(t * 60) * 2 + 0.5) end
    love.graphics.setColor(1, 1, 1, 1)
    strip:draw(f, x, y, 0, S * k * self.facing, S * k)
end

-- Editor: área de nado (relleno) y alcance de detección (círculo) al seleccionarlo
function Puffer.drawEditorOverlay(props, cx, cy, zoom, ctx)
    if ctx and type(props.area) == 'table' and #props.area >= 3 then
        local vs = {}
        for _, q in ipairs(props.area) do
            vs[#vs + 1] = (q.col - 0.5) * ctx.t - ctx.camX
            vs[#vs + 1] = (q.row - 0.5) * ctx.t - ctx.camY
        end
        local ok, tris = pcall(love.math.triangulate, vs)        -- (cóncavo: en triángulos)
        love.graphics.setColor(0.2, 0.9, 0.6, 0.16)
        if ok then for _, tri in ipairs(tris) do love.graphics.polygon('fill', tri) end end
        love.graphics.setColor(0.2, 0.9, 0.6, 0.9)
        love.graphics.setLineWidth(3 / zoom)
        love.graphics.polygon('line', vs)
    end
    local r = (props.range or 2.5) * TILE_PX
    love.graphics.setColor(0.3, 0.8, 1, 0.12)
    love.graphics.circle('fill', cx, cy, r)
    love.graphics.setColor(0.3, 0.8, 1, 0.8)
    love.graphics.setLineWidth(2 / zoom)
    love.graphics.circle('line', cx, cy, r)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Icono de la paleta: el primer cuadro
local iconImg, iconQuad
local function drawIcon(x, y, s)
    if not iconImg then
        iconImg = love.graphics.newImage(SHEET)
        iconImg:setFilter('nearest', 'nearest')
        iconQuad = love.graphics.newQuad(0, 0, 16, 16, iconImg:getWidth(), iconImg:getHeight())
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(iconImg, iconQuad, x, y, 0, s / 16, s / 16)
end

return {
    name = 'pufferfish', label = 'Pez globo', category = 'Enemigos',
    description = 'Solo para el agua: explora su área de nado por delante de todo (atraviesa bloques). Si un jugador que está '
               .. 'en el agua se acerca, avisa, se hincha y pincha (1 de vida y empujón). No se le puede matar.',
    class = Puffer,
    hide = { 'movement', 'attach', 'patrol', 'turnAtEdges', 'bobAmp', 'pauses', 'onTouch', 'stompable', 'points',
             'dropOnSight', 'detectRange', 'respawn' },
    defaults = { movement = 'walk', speed = 45, stompable = false, points = 0, onTouch = 'none', pauses = false },
    props = {
        { key='area', kind='points', label='Área de nado', group='Pez globo', min=3, max=24,
          default=function(d)
              local c, r = d.col or 1, d.row or 1
              return { { col = c - 3, row = r - 1 }, { col = c + 3, row = r - 1 },
                       { col = c + 3, row = r + 1 }, { col = c - 3, row = r + 1 } }
          end,
          help='Contorno de la zona por la que nada (puede ser irregular). Explora libremente todo su interior' },
        { key='range', kind='number', label='Alcance (casillas)', group='Pez globo', default=2.5,
          min=1, max=10, step=0.5, help='Se hincha si un jugador que está en el agua se acerca a esta distancia' },
        { key='warnTime', kind='number', label='Aviso (s)', group='Pez globo', default=0.6,
          min=0.2, max=3, step=0.1, help='Medio hinchado antes de pinchar' },
        { key='inflateTime', kind='number', label='Hinchado (s)', group='Pez globo', default=2.5,
          min=0.5, max=10, step=0.5 },
        { key='cooldown', kind='number', label='Descanso (s)', group='Pez globo', default=1.5,
          min=0, max=10, step=0.5, help='Tras deshincharse, cuánto nada antes de poder hincharse otra vez' },
        { key='swimBob', kind='number', label='Oscilación al nadar (px)', group='Pez globo', default=6,
          min=0, max=80, step=2 },
    },
    editor = { draw = drawIcon },
}
