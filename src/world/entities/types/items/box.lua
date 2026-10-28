-- La CAJA: un bloque suelto de una casilla que se EMPUJA andando contra él (más despacio que andar), cae por los
-- bordes, se para en las paredes y se puede pisar (es sólida como un bloque). Pesa: cuenta en un platillo de la
-- Balanza. El aire (Soplón, Ventisca, Géiser) la mueve. Se ROMPE (salta en 4 trozos) con un GROUND POUND encima, en
-- pinchos o lava y al caer desde MUY alto (una catapulta de la Balanza, un precipicio: BREAK_LAND); para que ningún
-- nivel se quede sin solución, REAPARECE en su sitio de salida tras `respawn` s (el usuario). Fuera del nivel, igual.
-- La CAJA PEQUEÑA (`smallbox`, misma clase base): más LIGERA (se empuja casi andando, el aire la lleva más) y SE
-- CARGA (systems/Carry: ARRIBA); lanzada, según la fuerza del golpe se rompe o no (contra el suelo > BREAK_LAND,
-- contra una pared > BREAK_WALL) y reaparece igual. La grande no se carga y cuesta empujarla (el usuario).
-- Aspecto por isla (Isles): assets/images/mechanisms/box/<isla>.png (16x16) + <isla>-bits-Sheet.png (4 trozos 8x8);
-- la pequeña <isla>-small.png (10x10) + -small-bits-Sheet.png (5x5); de tools/art/world/make_scale_box.py.
-- Sonidos boxPush / boxLand / boxBreak.
--
-- Empujarla: PlayerAdventure.moveAndCollide llama a `pushBy(pa, dx)` al chocar de lado con ella andando por el
-- suelo; la caja se mueve (con sus choques) y el jugador se queda pegado a su cara. ONLINE: la mueve el servidor;
-- el cliente que la empuja (su índice viaja en el netPack) la adelanta en su dibujo y en su choque mientras empuja,
-- así no se frena contra la posición vieja de la instantánea.
local Entity       = require 'src/world/entities/base/Entity'
local Isles        = require 'src/world/level/Isles'

local Box = Entity.extend(Entity, { debugColor = { 0.8, 0.6, 0.3 },
    hitbox = { outerW = 1, outerH = 1, innerW = 1, innerH = 1 } })

local S          = GUMMY_SCALE           -- 16x16 → una casilla
local BREAK_T    = 0.8                   -- s volando los trozos
local LAND_VY    = 260                   -- px/s: caer más rápido que esto suena al tocar el suelo
local PUSH_SND_T = 0.32                  -- s entre roces al arrastrarla
local PRED_T     = 0.25                  -- s que el cliente adelanta la caja tras su último empujón

Box.solidFull = true
Box.moves     = true                     -- (cuerpo que se mueve: lleva encima a quien la pisa — Entities.solidBodies)
Box.weight    = 2                        -- (cuenta en la Balanza: la grande pesa el doble que la pequeña o un jugador)
Box.PUSH_K    = 0.4                      -- empujarla: esta fracción de lo que anda el jugador (la grande cuesta: el usuario)
Box.windK     = 0.4                      -- el aire la mueve así de poco (systems/Push)
Box.wantsLevel = true
-- Lo que cambia la pequeña (SmallBox, abajo): su arte, su tamaño y cuándo se rompe
Box.ART, Box.ART_W, Box.BITS_W = '', 16, 8
Box.FRICTION   = 14                      -- 1/s: frena en el suelo (lanzada por la Balanza)
Box.BREAK_LAND = 1000                    -- px/s: cayendo más rápido que esto se rompe al tocar el suelo (≈ 5 casillas)
Box.BREAK_WALL = math.huge               -- px/s: contra una pared (la grande no)
Box.BOUNCE     = 0                       -- rebote en las paredes (× la velocidad)

function Box.sizePx() return TILE_PX, TILE_PX end

local imgs = {}
local function art(cls, isle)
    local key = isle .. cls.ART
    if not imgs[key] then
        local SpriteStrip = require 'src/fx/SpriteStrip'
        local base = 'assets/images/mechanisms/box/' .. isle .. cls.ART
        imgs[key] = { body = SpriteStrip.load(base .. '.png'), bits = SpriteStrip.load(base .. '-bits-Sheet.png', cls.BITS_W) }
    end
    return imgs[key]
end

function Box:init()
    self.moving, self.flying = false, false
    self.vx, self.vy = 0, 0
    self.state, self.deadTimer = 'rest', 0
    self.leftBoundPx, self.rightBoundPx = -math.huge, math.huge
    self.pushSndT, self.pusherIdx = 0, 0
end

function Box:isSolidBody() return self.alive and self.state == 'rest' end
function Box:canBeStomped() return false end
function Box:canBeKnocked() return false end
function Box:canBeLaunched() return false end
function Box:canFreeze() return false end
function Box:isObstacle() return self.state == 'rest' end
function Box:interact(pa) return nil end          -- (el choque es de la física del jugador)
function Box:onLava() self:breakApart(true) end

-- ¿Se puede empujar ahora? (quieta en el suelo)
function Box:pushable() return self.alive and self.state == 'rest' and self.onGround ~= false end

-- El jugador la empuja `dx` px (andando contra ella). Devuelve lo que se movió de verdad.
function Box:pushBy(pa, dx)
    if not self:pushable() or not pa.onGround then return 0 end
    local want = dx * self.PUSH_K
    if self.clientView then
        -- (cliente: solo el que la está empujando según el servidor la adelanta; los demás chocan con ella)
        if self.pusherIdx == 0 or self.pusherIdx ~= pa.ownerIdx then return 0 end
        self.predX, self.predT = self.x + want, PRED_T
        self.x = self.predX
        return want
    end
    local level = self.levelRef
    if not level then return 0 end
    local x0, vx0, f0 = self.x, self.vx, self.facing
    self:moveAndCollide(level, want, 0)
    self.vx, self.facing = vx0, f0
    local moved = self.x - x0
    if moved ~= 0 then
        self.pushedNow, self.pusherIdx = true, pa.ownerIdx or 0
    end
    return moved
end

-- Romperse (ground pound, lava, fuera del nivel): los trozos vuelan y reaparece en su sitio
function Box:breakApart(quiet)
    if self.state ~= 'rest' then return end
    self.state, self.deadTimer = 'broken', 0
    self.vx, self.vy = 0, 0
    if not quiet then Sound.play('boxBreak') end
    Entity.emitFx('block_break', self.x - TILE_PX / 2, self.y - TILE_PX / 2)
end

-- Ground pound (Interactions.run): encima de ella, se rompe
function Box:onPound(pa, z)
    if self.state ~= 'rest' then return false end
    local b = self:getOuterBounds()
    if pa.standBody == self or (z.x < b.x + b.w and z.x + z.w > b.x and z.y < b.y + b.h + 4 and z.y + z.h > b.y - 4) then
        self:breakApart()
        return true
    end
    return false
end

function Box:updateCustom(dt, level)
    self.levelRef = level
    local st = self.state
    if st == 'broken' then
        self.deadTimer = self.deadTimer + dt
        if self.deadTimer >= BREAK_T then
            -- (Entity: 'gone' cuenta hasta props.respawn, vuelve a casa y aparece con su animación)
            self.state, self.deadTimer = 'gone', BREAK_T
        end
        return true
    end
    if st ~= 'rest' then return false end
    -- Encima de otro cuerpo que se mueve (otra caja empujada): va con él
    local carry = 0
    local under = level:bodyAt(self.x, self.y + self.outerH / 2 + 2, self)
    if under and under.moves and self.onGround then carry = under.stepDx or 0 end
    local vx0, vy0, wasGround = self.vx, self.vy, self.onGround
    self.vy = math.min(self.vy + ADV_GRAVITY * dt, 1400)
    if self.onGround then self.vx = self.vx * math.max(0, 1 - self.FRICTION * dt) end
    local vx, f0 = self.vx, self.facing
    self:moveAndCollide(level, vx * dt + carry, self.vy * dt)
    -- (Entity.moveAndCollide da la vuelta a los que andan al chocar: aquí es un objeto)
    local wall = vx ~= 0 and self.vx ~= vx
    self.vx, self.facing = wall and -vx * self.BOUNCE or vx, f0
    if math.abs(self.vx) < 2 then self.vx = 0 end
    -- Golpes: muy fuerte contra el suelo o una pared, se rompe; en pinchos o lava, también
    if self.onGround and not wasGround and vy0 > self.BREAK_LAND then self:breakApart(); return true end
    if wall and math.abs(vx0) > self.BREAK_WALL then self:breakApart(); return true end
    if self:onDeadlyGround(level) then self:breakApart(); return true end
    if self.onGround and not wasGround and vy0 > LAND_VY then Sound.play('boxLand') end
    if self:fellOut(level) then self:breakApart(true) end
    -- (arrastrándola: el roce, cada poco)
    if self.pushedNow then
        self.pushSndT = self.pushSndT - dt
        if self.pushSndT <= 0 then Sound.play('boxPush'); self.pushSndT = PUSH_SND_T end
        self.pushedNow, self.pushT = false, 0.15
    else
        self.pushT = (self.pushT or 0) - dt
        if self.pushT <= 0 then self.pusherIdx, self.pushSndT = 0, 0 end
    end
    return true
end

-- ── Red ───────────────────────────────────────────────────────────────────────
-- En reposo en su sitio de salida: no se envía
function Box:netAtRest()
    return self.state == 'rest' and self.x == self.home.x and self.y == self.home.y
end
function Box:netRest() self:resetToHome(); self.state = 'rest' end
function Box:netPack() return { self.pusherIdx or 0 } end
function Box:netApply(a, b, f)
    self.clientView = true
    self.pusherIdx = b[1] or 0
    -- Empujándola yo: la instantánea va por detrás; se queda donde la llevo (sin volver atrás) un momento
    if self.predT and self.predT > 0 and self.predX then
        local dt = love.timer.getDelta()
        self.predT = self.predT - dt
        if (self.predX - self.x) * (self.predX - (self.lastSnapX or self.x)) >= 0 then
            if math.abs(self.predX - self.x) < 48 then self.x = self.predX end
        end
    end
    self.lastSnapX = self.x
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
function Box:render(camX, camY)
    local a = art(getmetatable(self), Isles.of(self.levelRef, self.props.isle))
    love.graphics.setColor(1, 1, 1, 1)
    if self.state == 'broken' then
        -- Los 4 trozos: salen de las esquinas, giran y caen (solo depende de deadTimer: igual online)
        local t = self.deadTimer or 0
        local k = 1 - math.max(0, (t - BREAK_T * 0.6) / (BREAK_T * 0.4))
        love.graphics.setColor(1, 1, 1, k)
        for i = 1, 4 do
            local sx, sy = (i % 2 == 1) and -1 or 1, (i <= 2) and -1 or 1
            local vx, vy = sx * 170, -380 + (sy + 1) * 90
            local px = self.x + sx * self.outerW / 4 + vx * t
            local py = self.y + sy * self.outerH / 4 + vy * t + 0.5 * ADV_GRAVITY * t * t
            a.bits:draw(i, math.floor(px - camX), math.floor(py - camY), sx * t * 9, S, S)
        end
        love.graphics.setColor(1, 1, 1, 1)
        return
    end
    a.body:draw(1, math.floor(self.x - camX + 0.5), math.floor(self.y - camY + 0.5), 0, S, S)
end

-- ── La CAJA PEQUEÑA: la misma, sin cuerpo sólido, que se carga y se rompe según el golpe ─────────────────────────
local SmallBox = Entity.extend(Box, { debugColor = { 0.9, 0.7, 0.4 } })
SmallBox.ART, SmallBox.ART_W, SmallBox.BITS_W = '-small', 10, 5
SmallBox.carryable = true                  -- (systems/Carry: ARRIBA la coge; también se empuja y se pisa, más ligera)
SmallBox.weight, SmallBox.PUSH_K, SmallBox.windK = 1, 0.8, 1
SmallBox.FRICTION   = 7
SmallBox.BREAK_LAND = 650                  -- (lanzada al suelo plano aguanta; desde una casilla más alta, se rompe)
SmallBox.BREAK_WALL = 500                  -- (contra una pared, lanzada corriendo)
SmallBox.BOUNCE     = 0.3
function SmallBox.sizePx() return 10 * S, 10 * S end
function SmallBox:canBeCarried() return self.state == 'rest' end
function SmallBox:onThrow(pa, vx, vy) self.vx, self.vy, self.onGround = vx, vy, false end

return { {
    name = 'box', label = 'Caja', category = 'Objetos', class = Box,
    description = 'Bloque suelto que se empuja andando contra él; se pisa, cae por los bordes y pesa en la Balanza. '
               .. 'Un ground pound la rompe y reaparece en su sitio.',
    defaults = { movement = 'static', respawn = 5 },
    props = {
        { key = 'respawn', kind = 'number', label = 'Reaparece tras (s)', group = 'Caja', default = 5, min = 1, max = 60, step = 0.5,
          help = 'Rota (ground pound), fuera del nivel o en lava: vuelve a su sitio de salida tras este tiempo' },
    },
    isleArt = true,                        -- (prop `isle`: src/world/level/Isles.lua)
    editor = { sprite = 'assets/images/mechanisms/box/pradera.png' },
}, {
    name = 'smallbox', label = 'Caja pequeña', category = 'Objetos', class = SmallBox,
    description = 'Caja que se carga (ARRIBA): lanzada, si el golpe es fuerte se rompe. Reaparece en su sitio.',
    defaults = { movement = 'static', respawn = 5 },
    props = {
        { key = 'respawn', kind = 'number', label = 'Reaparece tras (s)', group = 'Caja', default = 5, min = 1, max = 60, step = 0.5,
          help = 'Rota (golpe fuerte, ground pound, pinchos, lava) o fuera del nivel: vuelve a su sitio tras este tiempo' },
    },
    isleArt = true,
    editor = { sprite = 'assets/images/mechanisms/box/pradera-small.png' },
} }
