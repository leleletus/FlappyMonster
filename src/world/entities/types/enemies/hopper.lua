-- SALTARÍN: una bola con cara sobre un muelle. No anda: SALTA. Se queda quieto, se agacha un instante (el aviso) y
-- salta en arco hacia el jugador más cercano; al caer descansa y vuelve a empezar. Sin nadie cerca se PASEA a saltos
-- al azar por su ruta (prop común `patrol`; sin ruta, por todo el nivel). Es la amenaza "desde arriba" que no tenía ningún enemigo: se le esquiva pasando por debajo de su salto
-- o se le pisa (en el suelo o en el aire). Reglas con el jugador: las normales (Interactions.defaultCheck).
--
-- Estados: 'idle' (quieto; deadTimer = lo que lleva) → 'crouch' (WINDUP s) → 'hop' (balístico) → 'idle'.
-- ('walk', el estado con el que nace o reaparece cualquier entidad, pasa a 'idle' al momento.)
-- Todo lo que se dibuja sale de estado + deadTimer (viajan en el snapshot): igual en un jugador y online.
--
-- ASPECTOS por isla (prop `skin`; 'auto' = según el fondo del nivel): pradera, costa, fortaleza, nieve, cueva,
-- volcán — la misma forma con otra paleta, otras motas y otra cosa en la cabeza. Hojas de 4 cuadros 16x21 (quieto,
-- agachado, en el aire, aplastado): assets/images/enemies/hopper/<isla>-Sheet.png, de tools/ui/make_hopper_sprites.py.
-- Sonidos hopWind / hopJump / hopLand (tools/sounds/hopper.py).
local Entity      = require 'src/world/entities/base/Entity'
local SpriteStrip = require 'src/fx/SpriteStrip'

local Hopper = Entity.extend(Entity, {
    debugColor = { 0.5, 0.9, 0.3 },
    -- (la bola mide 9 de los 16 px de ancho; de alto, bola + muelle = 13 px: la caja es lo que se ve)
    hitbox = { outerW = 0.56, outerH = 1.0, innerW = 0.4, innerH = 0.62 },
})

local S       = GUMMY_SCALE
local FW, FH  = 16, 21
local BODY_H  = 13               -- filas del cuadro "quieto" (el alto de su caja)
local WINDUP  = 0.35             -- s agachado antes de saltar (el aviso)
local LAND_T  = 0.14             -- s de "aplastón" al caer (solo dibujo)
local IDLE_HOP = 0.9             -- casillas: el saltito en el sitio cuando no hay nadie
local MAX_H   = 5.5              -- casillas: tope de altura aunque el jugador esté muy arriba
Hopper.SKINS  = { 'pradera', 'costa', 'fortaleza', 'nieve', 'cueva', 'volcan' }
-- fondo del nivel (src/fx/Sky.lua) → aspecto
local BY_BG = { meadow = 'pradera', forest = 'pradera', coast = 'costa', fortress = 'fortaleza', snow = 'nieve',
                mountain = 'nieve', cave = 'cueva', underwater = 'cueva', volcano = 'volcan' }

local sheets = {}
function Hopper.loadAssets()
    if sheets.pradera then return end
    for _, id in ipairs(Hopper.SKINS) do sheets[id] = SpriteStrip.load('assets/images/enemies/hopper/' .. id .. '-Sheet.png', FW) end
end
function Hopper.sizePx() return FW * S, BODY_H * S end

Hopper.BY_BG = BY_BG                 -- (qué isla es cada fondo: lo usa también la comida, types/apple.lua)
function Hopper.skinFor(props, level)
    local id = props and props.skin or 'auto'
    if id == 'auto' then
        id = level and (((level.spikeSkin == 'ice' or level.snow) and 'nieve') or BY_BG[level.background or 'meadow']) or 'pradera'
    end
    return sheets[id] and id or 'pradera'
end

function Hopper:init()
    self.moving, self.vx, self.flipped = false, 0, false
    self.state, self.deadTimer = 'idle', 0
    self.wait = (self.props.jumpEvery or 1.4) * (0.5 + 0.5 * math.random())    -- (no todos a la vez)
end

function Hopper:isObstacle() return false end          -- (los que andan no se dan la vuelta ante él: salta por encima)

-- El jugador vivo más cercano dentro de su alcance
function Hopper:target(level)
    local best, bd = nil, (self.props.range or 7) * TILE_PX * require('src/core/Difficulty').k('sense')
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false then
            local d = math.abs(pa.x - self.x) + math.abs(pa.y - self.y) * 0.5
            if d < bd then best, bd = pa, d end
        end
    end
    return best
end

-- ¿Hay suelo donde caería? (desde la altura del salto hasta unas casillas por debajo de sus pies)
-- (bajo sus DOS bordes: con solo el centro apoyado en el canto de una plataforma, se caía)
function Hopper:groundAt(level, x, top)
    local y1 = self.y + self.outerH / 2 + TILE_PX * 3
    local function col(px)
        local y = math.max(top, 8)                 -- (por encima del nivel todo cuenta como sólido)
        while y <= y1 do
            if level:isEnemySolidAt(px, y) then return true end
            y = y + 16
        end
        return false
    end
    local hw = self.outerW / 2
    return col(x - hw) and col(x + hw)
end

-- No se tira al vacío: acorta el salto hasta donde haya suelo (o salta en el sitio)
function Hopper:safeDx(level, dx, top)
    if self.props.careful == false then return dx end
    local step = (dx >= 0) and -TILE_PX / 2 or TILE_PX / 2
    while math.abs(dx) > 1 and not self:groundAt(level, self.x + dx, top) do
        dx = dx + step
        if (step < 0 and dx < 0) or (step > 0 and dx > 0) then dx = 0 end
    end
    return dx
end

function Hopper:startHop(level)
    local T, g = TILE_PX, ADV_GRAVITY
    local pa = self:target(level)
    local maxD = (self.props.jumpDist or 4.5) * T
    local h, dx = self.props.jumpH or 3, 0
    -- su RUTA (la del editor; sin ruta: todo el nivel)
    local lo, hi = self.leftBoundPx - self.x + self.outerW / 2, self.rightBoundPx - self.x - self.outerW / 2
    if pa then
        local up = (self.y - pa.y) / T                              -- el jugador está más arriba: salta más
        if up > h - 1 then h = math.min(MAX_H, up + 1) end
        dx = math.max(-maxD, math.min(maxD, pa.x - self.x))
        dx = self:safeDx(level, math.max(lo, math.min(hi, dx)), self.y - h * T)
    else
        -- SIN NADIE CERCA: se pasea a saltos al azar por su ruta (sin ruta, por donde quiera), más bajos y cortos.
        -- Prueba unos cuantos destinos y se queda con el primero al que de verdad pueda ir
        h = h * (0.45 + 0.3 * math.random())
        for _ = 1, 6 do
            local d = (0.25 + 0.75 * math.random()) * maxD * 0.8 * ((math.random() < 0.5) and -1 or 1)
            d = self:safeDx(level, math.max(lo, math.min(hi, d)), self.y - h * T)
            if math.abs(d) >= T * 0.5 then dx = d; break end
        end
        if dx == 0 then h = IDLE_HOP end                            -- (no tiene adónde: un saltito en el sitio)
    end
    if math.abs(dx) > 4 then self.facing = (dx > 0) and 1 or -1 end
    self.vy = -math.sqrt(2 * g * h * T)
    self.vx = dx / (2 * -self.vy / g)                               -- (cae a su misma altura al cabo de 2·vy/g)
    self.onGround = false
    self.state, self.deadTimer = 'hop', 0
    self.roaming = not pa                                           -- (paseando suena más flojo)
    Sound.play('hopJump', pa and 1 or 1.25, pa and 1 or 0.4)
end

function Hopper:updateCustom(dt, level)
    local st = self.state
    if st == 'walk' then st = 'idle'; self.state, self.deadTimer = 'idle', 0 end
    if st == 'idle' then
        self.deadTimer = self.deadTimer + dt
        self.vx = 0
        self:fall(level, dt)
        if self.y > level.heightPx + TILE_PX * 4 then self.alive = false; return true end
        local pa = self:target(level)
        if pa and math.abs(pa.x - self.x) > 8 then self.facing = (pa.x > self.x) and 1 or -1 end
        if self.onGround and self.deadTimer >= self.wait then
            self.state, self.deadTimer = 'crouch', 0
            if pa then Sound.play('hopWind') end
        end
        return true
    elseif st == 'crouch' then
        self.deadTimer = self.deadTimer + dt
        self:fall(level, dt)
        if self.deadTimer >= WINDUP then self:startHop(level) end
        return true
    elseif st == 'hop' then
        self.deadTimer = self.deadTimer + dt
        local vx = self.vx
        self.vy = self.vy + ADV_GRAVITY * dt
        local x0 = self.x
        self:moveAndCollide(level, vx * dt, self.vy * dt)
        if self.state ~= 'hop' then return true end                  -- (un trampolín lo lanzó)
        if vx ~= 0 and math.abs(self.x - x0) < math.abs(vx * dt) * 0.5 then self.vx = 0 end    -- chocó con una pared: cae recto
        if self.deadTimer > 0.05 and self:onDeadlyGround(level) then
            self:dieBurst()                                          -- (cayó en pinchos o en lava)
            return true
        end
        if self.onGround and self.vy >= 0 and self.deadTimer > 0.05 then
            self.vx, self.vy = 0, 0
            self.state, self.deadTimer = 'idle', 0
            local every = self.props.jumpEvery or 1.4
            self.wait = every * (0.85 + 0.3 * math.random())
            Sound.play('hopLand', 1, self.roaming and 0.35 or 0.8)
        elseif self.y > level.heightPx + TILE_PX * 4 then
            self.alive = false
        end
        return true
    end
    return false
end

-- ── Dibujo (de estado + deadTimer) ────────────────────────────────────────────
function Hopper:render(camX, camY)
    if self.state == 'reserve' then return end
    local sh = sheets[Hopper.skinFor(self.props, self.levelRef)]
    local st, t = self.state, self.deadTimer or 0
    local fr, sx, sy = 1, 1, 1
    if st == 'dead' then fr = 4
    elseif st == 'crouch' then
        fr = 2
        local k = math.min(1, t / WINDUP)
        sx, sy = 1 + 0.10 * k, 1 - 0.10 * k                          -- se aprieta cada vez más
    elseif st == 'hop' or st == 'launched' then fr = 3
    elseif st == 'idle' and t < LAND_T then
        fr = 2
        local k = 1 - t / LAND_T
        sx, sy = 1 + 0.16 * k, 1 - 0.16 * k                          -- el aplastón al caer
    else
        local b = math.sin(t * 5) * 0.03                             -- quieto: el muelle le mece un poco
        sx, sy = 1 - b, 1 + b
    end
    local x = math.floor(self.x - camX)
    local feet = math.floor(self.y - camY + self.sprH / 2)
    love.graphics.setColor(1, 1, 1, 1)
    -- (el dibujo mira a la IZQUIERDA — la cara está un píxel hacia ese lado —: mirando a la derecha va espejado. Antes
    -- iba al revés y al ver a un jugador le daba la espalda)
    love.graphics.draw(sh.image, sh.quads[fr], x, feet, 0, -S * self.facing * sx, S * sy, FW / 2, FH)
end

local G = 'Saltarín'
local skinOpts = { { value = 'auto', label = 'Auto' }, { value = 'pradera', label = 'Pradera' }, { value = 'costa', label = 'Costa' },
                   { value = 'fortaleza', label = 'Fortaleza' }, { value = 'nieve', label = 'Nieve' },
                   { value = 'cueva', label = 'Cueva' }, { value = 'volcan', label = 'Volcán' } }

return {
    name = 'hopper', label = 'Saltarín', category = 'Enemigos', class = Hopper,
    description = 'Una bola sobre un muelle: se agacha un instante y salta en arco hacia el jugador más cercano. '
               .. 'Se le esquiva pasando por debajo o se le pisa. Sin nadie cerca se pasea a saltos por su ruta (sin ruta, por donde quiera).',
    traits = { wantsLevel = true },
    -- (movement = 'walk' solo para que el editor enseñe la RUTA; no anda: lo mueve updateCustom)
    defaults = { movement = 'walk', points = 15, onTouch = 'hurt' },
    hide = { 'movement', 'attach', 'speed', 'startDir', 'turnAtEdges', 'flyMode', 'flyRange', 'bobAmp', 'pauses', 'dropOnSight', 'detectRange' },
    props = {
        { key='skin', kind='enum', label='Aspecto', group=G, default='auto', options=skinOpts,
          help='Auto: el de la isla, según el fondo del nivel (nevado: el de nieve)' },
        { key='jumpEvery', kind='number', label='Descanso entre saltos (s)', group=G, default=1.4, min=0.3, max=8, step=0.1 },
        { key='range', kind='int', label='Ve al jugador a (casillas)', group=G, default=7, min=1, max=30 },
        { key='jumpH', kind='number', label='Altura del salto (casillas)', group=G, default=3, min=1, max=5, step=0.25 },
        { key='jumpDist', kind='number', label='Largo máximo del salto (casillas)', group=G, default=4.5, min=0, max=10, step=0.25,
          help='0 = salta en el sitio' },
        { key='careful', kind='bool', label='No se tira al vacío', group=G, default=true,
          help='Acorta el salto hasta donde haya suelo. Sin esto persigue aunque se caiga' },
    },
    noises = { hopLand = 4 },
    editor = { sprite = 'assets/images/enemies/hopper/pradera-Sheet.png', frameW = FW },
}
