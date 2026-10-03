-- Mortero (DoubleShooter en el original): cañón fijo que lanza bolas de fuego.
--
-- Como en Unity (DoubleShooter.cs + la bola FIRE 1):
--  * Espera un tiempo al azar (delayMin..delayMax). Al acabar, si hay algún
--    jugador dentro del alcance, ataca; si no, vuelve a esperar.
--  * Ataque: tiembla y se pone rojo poco a poco (warnTime), cambia al sprite
--    de disparo y lanza DOS bolas de fuego, una a cada lado, en un arco muy
--    empinado (upRatio = alto/lado). Suena el disparo. A los 0,5 s vuelve al
--    sprite normal.
--  * La bola cae con la gravedad; al tocar el suelo se queda ardiendo y se
--    va encogiendo (el ScaleLerp del prefab) hasta apagarse. En el agua se
--    apaga al momento.
-- A diferencia del original, el daño va con el sistema de vida del juego:
-- quita 1 de vida (o mata, si se elige en el editor) y respeta la
-- invulnerabilidad del jugador.
--
-- Online: lo simula el servidor; las bolas viajan en el snapshot (netPack) con
-- un id para interpolarlas en el cliente.

local Entity      = require 'src/world/entities/Entity'
local SpriteStrip = require 'src/fx/SpriteStrip'

local Mortar = Entity.extend(Entity, {
    debugColor = { 1, 0.45, 0.1 },
    hitbox = { outerW = 0.75, outerH = 0.85, innerW = 0.6, innerH = 0.6 },
})

local SCALE      = GUMMY_SCALE     -- 16x16 → 64 px, una casilla
local FIRE_SCALE = 3               -- bola de fuego (cuadros de 16x16)
local FIRE_FPS   = 12
local FIRE_HIT   = 9 * FIRE_SCALE  -- lado de la caja de daño de la bola (px)
local FIRE_HALF  = 8 * FIRE_SCALE  -- media altura del dibujo: al arder se apoya en el suelo
local SHOT_SPRITE_T = 0.5          -- ResetSpriteAfterDelay(0.5f)
local MAX_FIRE   = 12              -- bolas vivas por mortero
local FIRE_LIFE  = 8               -- s máximos de una bola (por si acaso)

local function rand(a, b) return a + math.random() * (b - a) end

local imgNormal, imgShoot, fireStrip
function Mortar.loadAssets()
    if imgNormal then return end
    imgNormal = love.graphics.newImage('assets/images/mortar/normal.png')
    imgShoot  = love.graphics.newImage('assets/images/mortar/shooting.png')
    fireStrip = SpriteStrip.load('assets/images/mortar/flame.png')
    if imgNormal.setFilter then imgNormal:setFilter('nearest', 'nearest'); imgShoot:setFilter('nearest', 'nearest') end
end
function Mortar.sizePx() return 16 * SCALE, 16 * SCALE end

function Mortar:init()
    local p = self.props
    self.moving, self.vx, self.vy = false, 0, 0
    self.y = self.row * TILE_PX - self.sprH / 2       -- apoyado en el suelo de su celda
    self.state, self.deadTimer = 'wait', 0
    self.waitFor = rand(p.delayMin or 2.5, math.max(p.delayMin or 2.5, p.delayMax or 6))
    self.shotT   = 0
    self.proj    = {}
    self.nextId  = 0
    self.goRight = false          -- currentDirection (se alterna en cada disparo)
end

-- Cualquier jugador dentro del alcance (IsPlayerInRange)
function Mortar:playerInRange(level)
    local r = (self.props.range or 12) * TILE_PX * require('src/Difficulty').k('sense')
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false then
            local dx, dy = pa.x - self.x, pa.y - self.y
            if dx * dx + dy * dy <= r * r then return true end
        end
    end
    return false
end

function Mortar:muzzle() return self.x, self.y - self.sprH * 0.28 end

-- FireProjectile: dirección (±1, upRatio) normalizada × velocidad
function Mortar:fire(dir)
    if #self.proj >= MAX_FIRE then table.remove(self.proj, 1) end
    local p = self.props
    local up = p.upRatio or 3
    local len = math.sqrt(1 + up * up)
    local v = p.launchSpeed or 950
    local mx, my = self:muzzle()
    self.nextId = (self.nextId % 999) + 1
    table.insert(self.proj, { id = self.nextId, x = mx, y = my, vx = dir * v / len, vy = -up * v / len,
                              t = 0, burn = nil, scale = 1 })
end

function Mortar:attack()
    local sides = self.props.sides or 'both'
    if sides == 'both' then
        self:fire(self.goRight and 1 or -1)
        self:fire(self.goRight and -1 or 1)
    else
        self:fire(sides == 'right' and 1 or -1)
    end
    self.goRight = not self.goRight
    self.shotT = SHOT_SPRITE_T
    Sound.play('mortarShoot')
    local mx, my = self:muzzle()
    Entity.emitFx('mortar_blast', mx, my)
end

-- Movimiento de las bolas: vuelan con gravedad, arden en el suelo y se apagan
function Mortar:updateFire(dt, level)
    local burnTime = self.props.burnTime or 1.2
    local r = FIRE_HIT / 2
    for i = #self.proj, 1, -1 do
        local f = self.proj[i]
        f.t = f.t + dt
        local gone = f.t > FIRE_LIFE or f.y > level.heightPx + TILE_PX * 2
        if not gone and level:liquidAt(f.x, f.y) then
            gone = true
            Sound.play('fireFizzle')
            Entity.emitFx('fire_puff', f.x, f.y)
        elseif not gone and f.burn then
            f.burn = f.burn + dt
            f.scale = math.max(0, 1 - f.burn / math.max(0.05, burnTime))
            if f.burn >= burnTime then gone = true; Entity.emitFx('fire_puff', f.x, f.y) end
        elseif not gone then
            f.vy = f.vy + ADV_GRAVITY * dt
            local nx = f.x + f.vx * dt
            if level:collisionAt(nx + (f.vx > 0 and r or -r), f.y) then f.vx = 0 else f.x = nx end
            local ny = f.y + f.vy * dt
            local landT, landY
            if f.vy > 0 then landT, landY = level:landingCross(f.x, f.y + r, ny + r) end
            if landT then
                -- Aterriza: se queda ardiendo sobre el suelo
                f.y = landY - FIRE_HALF
                f.vx, f.vy, f.burn = 0, 0, 0
                if burnTime <= 0 then gone = true; Entity.emitFx('fire_puff', f.x, f.y) end
            elseif f.vy < 0 and level:collisionAt(f.x, ny - r) then
                f.vy = 0
            else
                f.y = ny
            end
        end
        if gone then table.remove(self.proj, i) end
    end
end

-- AttackCycle
function Mortar:updateCustom(dt, level)
    local p = self.props
    self.deadTimer = self.deadTimer + dt
    if self.shotT > 0 then self.shotT = math.max(0, self.shotT - dt) end
    if self.state == 'wait' then
        if self.deadTimer >= self.waitFor then
            self.deadTimer = 0
            self.waitFor = rand(p.delayMin or 2.5, math.max(p.delayMin or 2.5, p.delayMax or 6))
            if self:playerInRange(level) then self.state = 'warn' end
        end
    elseif self.state == 'warn' then
        if self.deadTimer >= (p.warnTime or 0.5) then
            self:attack()
            self.state, self.deadTimer = 'wait', 0
        end
    end
    self:updateFire(dt, level)
    return true
end

function Mortar:onDead(dt) self.proj = {} end
function Mortar:canBeKnocked() return false end
function Mortar:canFreeze() return false end

-- Sólido como un bloque (lados, encima y debajo): ver PlayerAdventure.moveAndCollide
Mortar.solidFull = true
function Mortar:isSolidBody() return self.alive and self.state ~= 'dead' end
-- Caja del cañón (sprite 16x16: cuerpo desde la fila 2, patas hasta abajo)
function Mortar:getOuterBounds()
    local w = 12 * SCALE
    return { x = self.x - w / 2, y = self.y - self.sprH / 2 + 2 * SCALE, w = w, h = self.sprH - 2 * SCALE }
end
Mortar.getInnerBounds = Mortar.getOuterBounds

-- Las bolas son zonas de daño (Interactions)
function Mortar:getHazardBoxes()
    if #self.proj == 0 then return nil end
    local effect = (self.props.fireDamage == 'kill') and 'kill' or 'hurt'
    local out = {}
    for _, f in ipairs(self.proj) do
        local sc = f.scale or 1
        local s  = FIRE_HIT * sc
        local cy = f.y + (1 - sc) * FIRE_HALF          -- se consume hacia el suelo
        if s >= 6 then out[#out+1] = { x = f.x - s / 2, y = cy - s / 2, w = s, h = s, effect = effect } end
    end
    return out
end

-- ── Red: sprite de disparo + bolas {id, x, y, escala} ─────────────────────────
function Mortar:netPack()
    local out = { self.shotT > 0 and 1 or 0 }
    for _, f in ipairs(self.proj) do
        out[#out+1] = f.id; out[#out+1] = math.floor(f.x + 0.5); out[#out+1] = math.floor(f.y + 0.5)
        out[#out+1] = math.floor((f.scale or 1) * 100 + 0.5)
    end
    return out
end

function Mortar:netApply(a, b, f)
    a = a or b
    self.shotT = (b[1] == 1) and 1 or 0
    local prev = {}
    for k = 2, #a - 3, 4 do prev[a[k]] = k end
    local list = {}
    for k = 2, #b - 3, 4 do
        local id, x, y, sc = b[k], b[k + 1], b[k + 2], b[k + 3]
        local ka = prev[id]
        if ka and type(a[ka + 1]) == 'number' then
            x = a[ka + 1] + (x - a[ka + 1]) * f
            y = a[ka + 2] + (y - a[ka + 2]) * f
            sc = a[ka + 3] + (sc - a[ka + 3]) * f
        end
        list[#list+1] = { id = id, x = x, y = y, scale = sc / 100 }
    end
    self.proj = list
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
local Particles
function Mortar:render(camX, camY)
    local p   = self.props
    local img = (self.shotT > 0) and imgShoot or imgNormal
    local x   = math.floor(self.x - camX)
    local bot = math.floor(self.y - camY + self.sprH / 2)
    local k, alpha = 0, 1
    if self.state == 'dead' then alpha = math.max(0, 1 - (self.deadTimer or 0) / 1.0) end
    if self.state == 'warn' then
        -- VisualWarningBeforeShot: temblor + rojo que va subiendo
        k = math.min(1, (self.deadTimer or 0) / math.max(0.05, p.warnTime or 0.5)) * (p.redIntensity or 0.7)
        local sh = p.shake or 4
        x   = x + math.floor((math.random() * 2 - 1) * sh + 0.5)
        bot = bot + math.floor((math.random() * 2 - 1) * sh + 0.5)
    end
    love.graphics.setColor(1, 1 - k, 1 - k, alpha)
    love.graphics.draw(img, x, bot, 0, SCALE * (self.facing or 1), SCALE, img:getWidth() / 2, img:getHeight())
    if k > 0 then
        -- El sprite es casi negro: el rojo se suma para que se note de verdad
        love.graphics.setBlendMode('add')
        love.graphics.setColor(k, k * 0.12, k * 0.05, 1)
        love.graphics.draw(img, x, bot, 0, SCALE * (self.facing or 1), SCALE, img:getWidth() / 2, img:getHeight())
        love.graphics.setBlendMode('alpha')
    end

    -- Bolas de fuego (y sus chispas)
    local now = love.timer.getTime()
    Particles = Particles or require 'src/fx/Particles'
    for _, f in ipairs(self.proj) do
        local sc = FIRE_SCALE * (f.scale or 1)
        if sc > 0.05 then
            love.graphics.setColor(1, 1, 1, 1)
            local cy = f.y + (1 - (f.scale or 1)) * FIRE_HALF   -- se consume hacia el suelo
            fireStrip:draw(fireStrip:frameAt(now + f.id * 0.13, FIRE_FPS), math.floor(f.x - camX), math.floor(cy - camY), 0, sc, sc)
            if (f.lastEmber or 0) + 0.06 < now then
                f.lastEmber = now
                Particles.emit('ember', f.x, f.y)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Editor: círculo del alcance de detección
function Mortar.drawEditorOverlay(props, cx, cy, zoom)
    local r = (props.range or 12) * TILE_PX
    love.graphics.setColor(1, 0.35, 0.2, 0.7)
    love.graphics.setLineWidth(2 / zoom)
    love.graphics.circle('line', cx, cy, r, 64)
    love.graphics.setColor(1, 0.35, 0.2, 0.08)
    love.graphics.circle('fill', cx, cy, r, 64)
end

local function opts(...)
    local o = {}
    for _, pair in ipairs({ ... }) do o[#o+1] = { value = pair[1], label = pair[2] } end
    return o
end

return {
    name = 'mortar', label = 'Mortero', category = 'Enemigos',
    description = 'Cañón sólido que dispara bolas de fuego en arco cuando ve a un jugador.',
    class = Mortar,
    -- Objeto fijo, sólido e indestructible: no aplican las propiedades de enemigo
    hide = 'all',
    defaults = { movement = 'static' },
    props = {
        { key='range', kind='int', label='Alcance de detección (casillas)', group='Mortero', default=12,
          min=1, max=60, step=1, help='Casillas (radio) a las que tiene que haber un jugador para disparar' },
        { key='delayMin', kind='number', label='Espera mínima (s)', group='Mortero', default=2.5,
          min=0.2, max=30, step=0.5, help='Tiempo al azar entre ataques (minimo)' },
        { key='delayMax', kind='number', label='Espera máxima (s)', group='Mortero', default=6,
          min=0.2, max=30, step=0.5 },
        { key='warnTime', kind='number', label='Aviso antes de disparar (s)', group='Mortero', default=0.5,
          min=0, max=5, step=0.1, help='Tiempo que tiembla y se pone rojo' },
        { key='redIntensity', kind='number', label='Intensidad del rojo', group='Mortero', default=0.7,
          min=0, max=1, step=0.05 },
        { key='shake', kind='int', label='Temblor (px)', group='Mortero', default=4, min=0, max=20, step=1 },
        { key='sides', kind='enum', label='Dispara hacia', group='Disparo', default='both',
          options=opts({'both','Los dos lados'}, {'left','Izquierda'}, {'right','Derecha'}) },
        { key='launchSpeed', kind='number', label='Fuerza del disparo', group='Disparo', default=950,
          min=100, max=2500, step=25, help='px/s de salida de cada bola de fuego' },
        { key='upRatio', kind='number', label='Inclinación (alto/lado)', group='Disparo', default=3,
          min=0, max=10, step=0.25, help='3 = sube tres veces más de lo que avanza (arco empinado)' },
        { key='fireDamage', kind='enum', label='Daño del fuego', group='Disparo', default='hurt',
          options=opts({'hurt','Quita 1 de vida'}, {'kill','Mata'}) },
        { key='burnTime', kind='number', label='Arde en el suelo (s)', group='Disparo', default=1.2,
          min=0, max=10, step=0.1, help='Lo que tarda la bola en consumirse tras caer (0 = se apaga al tocar el suelo)' },
    },
    editor = { sprite = 'assets/images/mortar/normal.png' },
}
