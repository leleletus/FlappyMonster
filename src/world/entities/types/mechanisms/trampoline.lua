-- Trampolín: bloque sólido de una casilla con una cara que lanza (la del
-- "cojín" amarillo). Cuatro versiones según hacia dónde mira: arriba, abajo,
-- izquierda y derecha (se registran como cuatro entidades de la paleta).
--
--  * Por los otros lados se choca con él como con una pared.
--  * Al llegar a su cara con velocidad (caer encima, saltar contra él...) lanza
--    al jugador en esa dirección, bastante lejos.
--  * Tras lanzar: un instante (BOUNCE_WINDOW) en el que sigue lanzando a todo
--    el que llegue a la vez; luego se queda EXTENDIDO `cooldown` s (solo es una
--    pared) y se recoge; ya recogido vuelve a lanzar. Así varios jugadores
--    pueden usarlo a la vez, pero no uno detrás de otro sin parar.
-- Online: el choque lo detecta la física del jugador (bodyHit, predicha en el
-- cliente) y el estado del trampolín lo decide el servidor.

local Entity = require 'src/world/entities/base/Entity'

local Tramp = Entity.extend(Entity, { debugColor = { 1, 0.85, 0.2 },
    hitbox = { outerW = 1, outerH = 1, innerW = 1, innerH = 1 } })

local S             = GUMMY_SCALE     -- 16x16 → una casilla
local BOUNCE_WINDOW = 0.1             -- s en los que lanza a todos los que lleguen a la vez
local RETRACT_T     = 0.15            -- s recogiéndose
local MIN_SPEED     = 120             -- px/s: apoyarse quieto no lanza
local MIN_SPEED_WATER = 25           -- (en el agua la caída es lenta)
local PAD_TOP       = { normal = 7, extended = 4 }   -- fila del cojín en el sprite (mirando arriba)

-- Cara del CUERPO que lanza, según hacia dónde mira el trampolín
local FACE = { up = 'top', down = 'bottom', left = 'left', right = 'right' }
local ROT  = { up = 0, right = math.pi / 2, down = math.pi, left = -math.pi / 2 }

-- ASPECTOS (solo dibujo; prop `skin`): 'normal' y 'ice' = el trampolín HELADO (la misma textura que el de los Crabbies
-- helados). 'auto' (por defecto) = helado en los niveles nevados — los de pinchos de hielo o nieve cayendo
-- (level.spikeSkin == 'ice' / level.snow) —, así ninguno se queda sin cambiar; un aspecto nuevo = dos PNG + una línea
local SKINS = { normal = { 'normal.png', 'extended.png' }, ice = { 'ice_normal.png', 'ice_extended.png' } }
local imgNormal, imgExtended
local skinImg = {}
function Tramp.loadAssets()
    if imgNormal then return end
    for id, f in pairs(SKINS) do
        local a = love.graphics.newImage('assets/images/mechanisms/trampoline/' .. f[1])
        local b = love.graphics.newImage('assets/images/mechanisms/trampoline/' .. f[2])
        if a.setFilter then a:setFilter('nearest', 'nearest'); b:setFilter('nearest', 'nearest') end
        skinImg[id] = { a, b }
    end
    imgNormal, imgExtended = skinImg.normal[1], skinImg.normal[2]
end
Tramp.wantsLevel = true                      -- (BossZones.link / el editor le dan el nivel: levelRef)
function Tramp.skinFor(props, level)
    local id = props and props.skin or 'auto'
    if id == 'auto' then id = (level and (level.spikeSkin == 'ice' or level.snow)) and 'ice' or 'normal' end
    return SKINS[id] and id or 'normal'
end
function Tramp.sizePx() return TILE_PX, TILE_PX end

function Tramp:init()
    self.moving, self.flying, self.vx, self.vy = false, true, 0, 0
    self.dir   = self.def.dir or 'up'
    self.face  = FACE[self.dir]
    self.state, self.deadTimer = 'ready', 0
end

-- Sólido como un bloque, con cara que lanza (ver PlayerAdventure.moveAndCollide)
Tramp.solidFull  = true
Tramp.bouncyFace = true
function Tramp:isSolidBody() return self.alive end
function Tramp:canBeStomped() return false end
function Tramp:canBeKnocked() return false end

function Tramp:isExtended() return self.state == 'bounce' or self.state == 'extended' end
function Tramp:canLaunchEntity() return self.state == 'ready' or self.state == 'bounce' end

-- Caja sólida = lo que se ve del sprite (sube un poco al extenderse)
function Tramp:getOuterBounds()
    local T  = TILE_PX
    local top = (self:isExtended() and PAD_TOP.extended or PAD_TOP.normal) * S
    local ox, oy = self.x - T / 2, self.y - T / 2
    local side = S                            -- columnas 1..14 del sprite
    local d = self.dir
    if d == 'down'  then return { x = ox + side, y = oy,       w = T - 2 * side, h = T - top } end
    if d == 'left'  then return { x = ox + top,  y = oy + side, w = T - top,     h = T - 2 * side } end
    if d == 'right' then return { x = ox,        y = oy + side, w = T - top,     h = T - 2 * side } end
    return { x = ox + side, y = oy + top, w = T - 2 * side, h = T - top }
end
Tramp.getInnerBounds = Tramp.getOuterBounds

-- Velocidad con la que lanza
function Tramp:launchVelocity()
    local P = math.abs(ADV_JUMP_VEL) * (self.props.power or 1.75)
    local d = self.dir
    if d == 'down'  then return 0, P * 0.6 end
    if d == 'left'  then return -P * 0.85, -380 end
    if d == 'right' then return  P * 0.85, -380 end
    return 0, -P
end

-- ¿Lanza a este jugador? (sin efectos: el cliente lo usa para predecir)
function Tramp:interact(pa)
    local h = pa.bodyHit
    if not h or h.o ~= self or h.face ~= self.face then return nil end
    -- Cayendo encima / saltando contra él: con velocidad (apoyarse quieto no
    -- lanza). De lado basta con empujarlo, aunque sea despacio.
    local sideways = (self.face == 'left' or self.face == 'right')
    -- (bajo el agua se cae muy despacio — nunca se llegaba a MIN_SPEED y solo lanzaba con un ground pound —:
    -- ahí basta con caerle encima)
    local min = sideways and 1 or ((pa.inWater and MIN_SPEED_WATER) or MIN_SPEED)
    if (h.speed or 0) < min then return nil end
    if self.state ~= 'ready' and self.state ~= 'bounce' then return nil end      -- extendido: pared
    return 'launch', self:launchVelocity()
end

function Tramp:onLaunch(pa)
    if self.state ~= 'ready' then return end            -- ya estaba lanzando (varios a la vez)
    self.state, self.deadTimer = 'bounce', 0
    Sound.play('trampoline')
    local b = self:getOuterBounds()
    Entity.emitFx('gp_start', b.x + b.w / 2, b.y + b.h / 2)
end

function Tramp:updateCustom(dt, level)
    self.deadTimer = self.deadTimer + dt
    local st = self.state
    if st == 'bounce' then
        if self.deadTimer >= BOUNCE_WINDOW then self.state, self.deadTimer = 'extended', 0 end
    elseif st == 'extended' then
        if self.deadTimer >= (self.props.cooldown or 0.6) then self.state, self.deadTimer = 'retract', 0 end
    elseif st == 'retract' then
        if self.deadTimer >= RETRACT_T then self.state, self.deadTimer = 'ready', 0 end
    end
    return true
end

-- Red: recogido y listo = en reposo (no se envía)
function Tramp:netAtRest() return self.state == 'ready' end
function Tramp:netRest() self.state, self.deadTimer = 'ready', 0 end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
local function drawTramp(img, cx, cy, rot, sc, squash)
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(rot)
    love.graphics.scale(1, squash or 1)
    love.graphics.draw(img, 0, 0, 0, sc, sc, 8, 8)
    love.graphics.pop()
end

function Tramp:render(camX, camY)
    local sk = skinImg[Tramp.skinFor(self.props, self.levelRef)]
    local img = self:isExtended() and sk[2] or sk[1]
    -- "Boing": al lanzar se estira un poco y vuelve
    local sq = 1
    if self.state == 'bounce' then sq = 1.12 end
    if self.state == 'extended' and self.deadTimer < 0.12 then sq = 1 + 0.12 * (1 - self.deadTimer / 0.12) end
    love.graphics.setColor(1, 1, 1, 1)
    drawTramp(img, math.floor(self.x - camX), math.floor(self.y - camY), ROT[self.dir] or 0, S, sq)
end

local function editorIcon(dir)
    return function(x, y, s)
        Tramp.loadAssets()
        love.graphics.setColor(1, 1, 1, 1)
        drawTramp(imgNormal, x + s / 2, y + s / 2, ROT[dir], s / 16)
    end
end

local PROPS = {
    { key='power', kind='number', label='Fuerza', group='Trampolín', default=1.75, min=0.5, max=4, step=0.05,
      help='Multiplicador del salto normal (1.75 = unas 5 casillas)' },
    { key='cooldown', kind='number', label='Extendido tras lanzar (s)', group='Trampolín', default=0.6,
      min=0, max=10, step=0.05, help='Mientras está extendido no lanza: solo es una pared' },
    { key='skin', kind='enum', label='Aspecto', group='Trampolín', default='auto',
      options = { { value = 'auto', label = 'Auto' }, { value = 'normal', label = 'Normal' }, { value = 'ice', label = 'Helado' } },
      help='Auto: helado en los niveles nevados (pinchos de hielo o nieve), normal en los demás' },
}

local defs = {}
for _, d in ipairs({ { 'up', 'trampoline', 'Arriba' }, { 'down', 'trampoline_down', 'Abajo' },
                     { 'left', 'trampoline_left', 'Izquierda' }, { 'right', 'trampoline_right', 'Derecha' } }) do
    -- Cada dirección es su propia clase (la definición guarda la dirección).
    -- En el editor son una sola ficha "Trampolín" con selector de dirección.
    local cls = Entity.extend(Tramp)
    defs[#defs+1] = {
        name = d[2], label = 'Trampolín (' .. d[3]:lower() .. ')', category = 'Mecanismos', class = cls, dir = d[1],
        description = 'Bloque sólido con una cara que lanza a jugadores y enemigos por los aires.',
        variant = { group = 'trampoline', label = d[3], groupLabel = 'Trampolín', prop = 'Dirección' },
        hide = 'all', defaults = { movement = 'static' }, props = PROPS,
        editor = { sprite = 'assets/images/mechanisms/trampoline/normal.png', draw = editorIcon(d[1]) },
    }
end
return defs
