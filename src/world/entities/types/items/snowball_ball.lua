-- La BOLA DE NIEVE QUE SE CARGA (`snowball_ball`, 0.5.186, el usuario: «al matar una bolita de nieve debería
-- convertirse en una bola de nieve cargable y lanzable; no todas, solo algunas»). No se coloca a mano: la deja al morir
-- (pisada o con un ground pound) una Bola de Nieve que la tiene (`leaves` en assets/enemies/snowball.json y la prop
-- `leaves` de cada una: 1 de cada 3 al azar, siempre o nunca). Es su SÚBDITO DE RESERVA (Entity:makeReserve: la crea el
-- nivel al cargar, mismos índices en el servidor y los clientes) y sale con Entity:appearAt donde murió.
-- Se CARGA (systems/Carry: ARRIBA) y se LANZA como la caja pequeña (misma física: hereda de ella). Lanzada, lo primero
-- que toca la deshace en nieve: un ENEMIGO (lo derriba como un pisotón — no a los jefes —), el suelo o una pared.
-- Dejada con cuidado (AGACHADO + ARRIBA) no se deshace. Pinchos, lava o fuera del nivel también la deshacen. Deshecha,
-- vuelve a la reserva de su Bola de Nieve (la siguiente vez que muera, puede dejar otra).
-- Arte: assets/images/items/snowball/ball.png (10x10, de tools/art/items/make_snowball_ball.py).
local Entity   = require 'src/world/entities/base/Entity'
local SmallBox = require('src/world/entities/types/items/box')[2].class

local Ball = Entity.extend(SmallBox, { debugColor = { 0.85, 0.92, 1 },
    hitbox = { outerW = 1, outerH = 1, innerW = 1, innerH = 1 } })

local S      = GUMMY_SCALE
local POOF_T = 0.35                      -- s: la nube al deshacerse (luego, a la reserva)
local POP_T  = 0.25                      -- s: aparece creciendo (solo dibujo)

Ball.BREAK_LAND, Ball.BREAK_WALL = math.huge, math.huge     -- (lanzada se deshace al tocar; quieta no se rompe)
Ball.weight, Ball.PUSH_K = 0.5, 0
function Ball.sizePx() return 10 * S, 10 * S end
function Ball:isSolidBody() return false end
function Ball:pushable() return false end
function Ball:isObstacle() return false end
function Ball:canBeCarried() return self.state == 'rest' and not self.thrown end   -- (volando: ni se coge ni la arrolla nadie)
function Ball:onPound() return false end
function Ball:onBlastHit() self:poof() end

function Ball:onPickUp() self.thrown = nil; Sound.play('snowballBonk', 1.3, 0.6) end
function Ball:onPutDown() self.thrown = nil end
function Ball:onThrow(pa, vx, vy)
    self.vx, self.vy, self.onGround = vx, vy, false
    self.thrown, self.throwPa = true, pa
end

-- Se deshace en nieve y vuelve a la reserva
function Ball:poof()
    if self.state ~= 'rest' then return end
    self.state, self.deadTimer, self.vx, self.vy, self.thrown = 'broken', 0, 0, 0, nil
    Sound.play('snowballBonk', 1.1)
    Entity.emitFx('snow_puff', self.x, self.y)
end
Ball.breakApart = Ball.poof              -- (lo que rompe la caja pequeña — pinchos, lava, fuera del nivel — la deshace)

-- Lanzada: ¿pilla a un enemigo? (los que se pisan caen como pisados; los jefes no)
local HIT_B, E_B = {}, {}
local function hitEnemy(self, level)
    local b = self:getOuterBounds(HIT_B)
    for _, e in ipairs(level.liveEntities or {}) do
        if e ~= self and e.alive and e.def and e.def.category == 'Enemigos' and not e.def.boss and e.state ~= 'dead'
           and e.state ~= 'carried' and not (e.isGhost and e:isGhost()) and e.props.stompable then
            local o = e:getOuterBounds(E_B)
            if b.x < o.x + o.w and b.x + b.w > o.x and b.y < o.y + o.h and b.y + b.h > o.y then return e end
        end
    end
    return nil
end

function Ball:updateCustom(dt, level)
    self.levelRef = level
    if self.state == 'broken' then
        self.deadTimer = self.deadTimer + dt
        if self.deadTimer >= POOF_T then self:makeReserve(self.summonOf) end
        return true
    end
    if self.state ~= 'rest' then return false end
    self.popT = (self.popT or POP_T) + dt
    local vx0, wasGround = self.vx, self.onGround
    local r = SmallBox.updateCustom(self, dt, level)          -- (la física de la caja pequeña: cae, rebota, frena)
    if self.state ~= 'rest' then return r end
    if self.thrown then
        local e = hitEnemy(self, level)
        if e then
            e:stomp()
            self:poof()
        elseif (self.onGround and not wasGround) or (vx0 ~= 0 and self.vx ~= vx0 and math.abs(self.vx) < math.abs(vx0) * 0.5) then
            self:poof()                                        -- (contra el suelo o una pared: nieve)
        end
    end
    return true
end

-- Sale donde murió su Bola de Nieve (Entity:appearAt) creciendo un momento
function Ball:appearAt(x, y)
    Entity.appearAt(self, x, y)
    self.state, self.popT, self.thrown = 'rest', 0, nil
end

-- ── Red ───────────────────────────────────────────────────────────────────────
-- En la reserva no se envía (la regla de los súbditos); en juego, como cualquier entidad
function Ball:netAtRest() return self.state == 'reserve' or not self.alive end
function Ball:netRest() self.alive, self.state = false, 'reserve' end
function Ball:netPack() return nil end
function Ball:netApply() end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
local img
function Ball:render(camX, camY)
    if self.state ~= 'rest' and self.state ~= 'carried' then return end
    img = img or require('src/fx/SpriteStrip').load('assets/images/items/snowball/ball.png')
    local k = math.min(1, (self.popT or POP_T) / POP_T)
    local s = S * (0.4 + 0.6 * k + math.sin(k * math.pi) * 0.15)
    love.graphics.setColor(1, 1, 1, 1)
    img:draw(1, math.floor(self.x - camX + 0.5), math.floor(self.y - camY + 0.5), 0, s, s)
end

return {
    name = 'snowball_ball', label = 'Bola de nieve (cargable)', category = 'Objetos', class = Ball,
    description = 'La deja al morir una Bola de Nieve (su prop «Deja una bola»). Se carga y se lanza: deshace en nieve '
               .. 'lo primero que toca y derriba a los enemigos que se pisan. No se coloca a mano.',
    defaults = { movement = 'static' },
    editorHide = true,                    -- (no se coloca: la crea el nivel como reserva de cada Bola de Nieve)
    editor = { sprite = 'assets/images/items/snowball/ball.png' },
}
