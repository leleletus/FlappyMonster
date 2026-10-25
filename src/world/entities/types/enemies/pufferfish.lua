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
-- SIN AGUA (0.5.31, como el Pez Globo Gigante): sigue el nivel del agua — si la superficie baja de su lomo, nada hacia
-- abajo, y no elige destinos secos —; si se queda en seco (una inundación que baja más rápido que él, o un área que
-- sale del agua) CAE ('dry_fall', con choques) y en el suelo da botes y coletazos salvajes ('dry_flop'). Si vuelve a
-- caer al agua, sigue nadando; si pasa `dryTime` s fuera, se MUERE ('dry_die': panza arriba y se desvanece).
-- Dentro de un bloque cuenta como mojado (su área puede atravesarlos).
--
-- Sprites: assets/images/enemies/pufferfish/puffer_fish-Sheet.png, cuadros de 16x16
-- mirando a la DERECHA (a la izquierda se espeja): nadar (1 o 2 cuadros, se
-- alternan), medio hinchado, hinchado. Con 3 cuadros nada con el primero.
-- Sonidos: pufferWarn / pufferInflate / pufferDeflate / pufferPrick.
local Entity      = require 'src/world/entities/base/Entity'
local SpriteStrip = require 'src/fx/SpriteStrip'

local S = 5                    -- escala del pixel art
local SHEET = 'assets/images/enemies/pufferfish/puffer_fish-Sheet.png'
-- Cuerpo hinchado dentro del cuadro (px del sprite, mirando a la derecha):
-- columnas 4..14, filas 4..13 (sin la cola). La caja que pincha es un poco
-- menor (HURT_K) para que no pinche "por el aire" en las esquinas.
local BODY_X0, BODY_X1, BODY_Y0, BODY_Y1 = 4, 15, 4, 14
local HURT_K = 0.85
local DEFLATE_T = 0.4          -- s de la animación de deshincharse
local ARRIVE    = 14           -- px: ha llegado a su destino
local POP_T     = 0.12         -- s del "pop" al hincharse del todo (solo dibujo)
local SWIM_FPS  = 2.5          -- cambios de cuadro por segundo al nadar (no cambia su velocidad)
local DRY_G     = 1500         -- gravedad en seco (px/s²)
local SINK_SPD  = 140          -- px/s hacia abajo cuando el agua le baja del lomo
local DIE_T     = 1.0          -- s de la muerte en seco (panza arriba, se desvanece)
local DRY = { dry_fall = true, dry_flop = true, dry_die = true }

local Puffer = Entity.extend(Entity, {
    debugColor = { 1, 0.8, 0.2 },
    hitbox = { outerW = 0.6, outerH = 0.5, innerW = 0.5, innerH = 0.4 },
})
Puffer.renderFront = true
Puffer.freezeFloats = true      -- (congelado: el bloque de hielo flota donde estaba)

Puffer.animId = 'enemies/pufferfish'
function Puffer.loadAssets() Puffer.anims(Puffer) end

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

-- ¿Agua (o un bloque: lo atraviesa) en el punto?
local function wetAt(level, x, y) return level:liquidAt(x, y) ~= nil or level:collisionAt(x, y) ~= nil end

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
        if inside(poly, x, y) and (not here or segInside(poly, self.px, self.py, x, y))
           and (not self.levelRef or wetAt(self.levelRef, x, y - self.outerH * 0.5)) then      -- (nunca a un sitio seco)
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

function Puffer:topY() return self.py - self.outerH * 0.5 end          -- (el lomo)

function Puffer:init()
    self.flying = true              -- (sin gravedad; su movimiento es propio)
    self.dryT   = 0                 -- s seguidos fuera del agua
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
    if self.state ~= 'inflated' or not self.alive then return nil end
    local w = (BODY_X1 - BODY_X0) * S * HURT_K
    local h = (BODY_Y1 - BODY_Y0) * S * HURT_K
    local cx = ((BODY_X0 + BODY_X1) / 2 - 8) * S * self.facing
    local cy = ((BODY_Y0 + BODY_Y1) / 2 - 8) * S
    return { { x = self.x + cx - w / 2, y = self.y + cy - h / 2, w = w, h = h, effect = 'hurt' } }
end

-- El jugador más cercano que esté en el agua y a su alcance
function Puffer:targetIn(level)
    local r = (self.props.range or 2.5) * TILE_PX * require('src/core/Difficulty').k('sense')
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

-- En seco: cae con choques, bota y coletea en el suelo; si vuelve al agua, nada; si tarda, se muere
function Puffer:updateDry(dt, level)
    local p, st = self.props, self.state
    if st == 'dry_die' then
        if self.deadTimer >= DIE_T then self.alive, self.state = false, 'dead' end
        return
    end
    self.dryT = self.dryT + dt
    if self.dryT >= (p.dryTime or 5) then
        self.state, self.deadTimer, self.vx = 'dry_die', 0, 0
        Sound.play('pufferDeflate', 1.3)
        return
    end
    self.vy = math.min(self.vy + DRY_G * dt, 900)
    self.x, self.y = self.px, self.py
    self.leftBoundPx, self.rightBoundPx = -1e9, 1e9            -- (sin ruta: choca solo con lo sólido)
    local was = self.onGround
    self:moveAndCollide(level, self.vx * dt, self.vy * dt)
    self.px, self.py = self.x, self.y
    if wetAt(level, self.px, self.py) and not level:collisionAt(self.px, self.py) then    -- ¡de vuelta al agua!
        self.state, self.deadTimer, self.dryT = 'walk', 0, 0
        self.vy = math.min(self.vy, 120)
        Sound.play('waterSplash', 1.5, 0.5)
        self:pickTarget()
        return
    end
    if self.onGround then
        if not was then self.vx = self.vx * 0.3 end
        if st ~= 'dry_flop' then self.state, self.deadTimer = 'dry_flop', 0 end
        -- coletazos salvajes: botes cortos al azar, cada vez más cansados
        self.hopT = (self.hopT or 0) - dt
        if self.hopT <= 0 then
            local tired = 1 - 0.5 * math.min(1, self.dryT / (p.dryTime or 5))
            self.vy = -(260 + math.random() * 320) * tired
            self.vx = (math.random() * 2 - 1) * 170 * tired
            self.facing = (math.random() < 0.5) and -1 or 1
            self.onGround = false
            self.hopT = 0.18 + math.random() * 0.3
            Sound.play('kingHop', 2.4, 0.35)
        end
    end
end

function Puffer:updateCustom(dt, level)
    local p = self.props
    local st = self.state
    self.deadTimer = self.deadTimer + dt
    self.cool = math.max(0, self.cool - dt)
    self.levelRef = level
    if not self.poly then self:buildArea(); self:pickTarget() end
    -- ¿En seco? (el centro fuera del agua y fuera de un bloque): deja lo que hacía y cae
    if not DRY[st] and not wetAt(level, self.px, self.py) then
        self.state, self.deadTimer, self.onGround, self.hopT = 'dry_fall', 0, false, 0
        self.vx = self.vx * 0.5
        st = self.state
    end
    if DRY[st] then self:updateDry(dt, level); self.x, self.y = self.px, self.py; return true end
    local swimming = st == 'walk' or st == 'idle'
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
    -- Sigue el nivel del agua: si la superficie le baja del lomo, nada hacia abajo (sea cual sea su destino)
    -- (solo hacia más agua: nunca se hunde en un bloque; si debajo no hay agua, se queda y al bajar más el agua, cae)
    local sinking = not wetAt(level, self.px, self:topY())
    if sinking and level:liquidAt(self.px, self.py + self.outerH * 0.5) then wy = math.max(wy, SINK_SPD)
    elseif sinking then wy = math.min(wy, 0) end
    local k = math.min(1, dt * ((swimming and not sinking) and 3 or 6))
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
-- Cada estado pide su animación por nombre (assets/anim/enemies/pufferfish.json): `swim` nadando, `warn` (tiembla
-- y se queda a medio hinchar), `puffed` hinchado, `deflate` deshinchándose. Cuadros y ritmo: los del conjunto.
function Puffer:render(camX, camY)
    local st, t = self.state, self.deadTimer or 0
    if DRY[st] then return self:renderDry(camX, camY) end
    local name, k = 'swim', 1
    if st == 'warn' then name = 'warn'
    elseif st == 'inflated' then
        name = 'puffed'
        if t < POP_T then k = 1 + 0.18 * math.sin(t / POP_T * math.pi) end
    elseif st == 'deflate' then name = 'deflate'
    else t = love.timer.getTime() + (self.home and self.home.x or 0) * 0.01 end
    local x, y = math.floor(self.x - camX), math.floor(self.y - camY)
    -- Temblor del aviso
    if st == 'warn' then x = x + math.floor(math.sin(t * 60) * 2 + 0.5) end
    love.graphics.setColor(1, 1, 1, 1)
    self:anims():draw(name, t, x, y, 0, S * k * self.facing, S * k, 0.5, 0.5)
end

-- En seco: coletea (los dos cuadros de nadar, rápido) dando vueltas; muriendo, panza arriba y se desvanece
function Puffer:renderDry(camX, camY)
    local st, t = self.state, self.deadTimer or 0
    local x, y = math.floor(self.x - camX), math.floor(self.y - camY)
    local f, rot, sy, a = self.facing or 1, 0, 1, 1
    local at = t * 4
    if st == 'dry_flop' then rot = math.sin(t * 23) * 0.5
    elseif st == 'dry_fall' then rot = math.sin(t * 11) * 0.3
    else at, sy, a = 0, -1, 1 - math.max(0, (t - DIE_T * 0.4) / (DIE_T * 0.6)) end
    love.graphics.setColor(1, 1, 1, a)
    self:anims():draw('swim', at, x, y, rot, S * f, S * sy, 0.5, 0.5)
    love.graphics.setColor(1, 1, 1, 1)
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
local function drawIcon(x, y, s)
    local c = Puffer.anims(Puffer) and require('src/fx/Anim').clip(Puffer.animId, 'swim')
    c:drawPx(1, x, y, 0, s / c.w, s / c.w)
end

return {
    name = 'pufferfish', label = 'Pez globo', category = 'Enemigos',
    description = 'Solo para el agua: explora su área de nado por delante de todo (atraviesa bloques). Si un jugador que está '
               .. 'en el agua se acerca, avisa, se hincha y pincha (1 de vida y empujón). No se le puede matar. '
               .. 'Sigue el nivel del agua; en seco bota y coletea y, si tarda en volver al agua, se muere.',
    class = Puffer,
    inBlockOk = true,          -- (atraviesa los bloques: dentro de uno no es un aviso)
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
        { key='dryTime', kind='number', label='Aguanta en seco (s)', group='Pez globo', default=5,
          min=1, max=30, step=0.5, help='Fuera del agua bota y coletea; pasado este tiempo, se muere' },
    },
    editor = { draw = drawIcon },
}
