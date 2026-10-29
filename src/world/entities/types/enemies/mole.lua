-- El TOPO (types/enemies/mole.lua; 0.5.96, diseño A «Periscopio» elegido por el usuario el 2026-10-29): enemigo
-- GENERAL, de todas las islas (su aspecto, el de la isla del nivel: prop `isle`, Isles). Vive BAJO TIERRA:
--   · Escondido solo se ve un MONTÍCULO (de la tierra de su isla) que avanza por la superficie del suelo hacia el
--     jugador más cercano (a `range` casillas de lado y a su altura). Inofensivo y no se le puede pisar. Sin nadie
--     cerca, se pasea despacio.
--   · Al llegar (casi) debajo del jugador, el montículo TIEMBLA (el aviso, TELL_T) y el topo ASOMA y MUERDE: tocarlo
--     mientras muerde quita 1. Luego se queda mirando un momento fuera (LOOK_T: pisarlo lo aplasta; de lado, hace
--     daño) y se HUNDE; vuelve a moverse bajo tierra y no asoma otra vez en COOLDOWN s.
--   · Un GROUND POUND cerca de su montículo (POUND_RX de lado, a su altura) lo SACA del suelo: MAREADO (DIZZY_T s,
--     estrellitas), inofensivo y se le puede pisar; luego se vuelve a hundir. Fuera del suelo, el empujón de un ground
--     pound también lo marea.
--   · Nunca deja SU suelo: solo avanza por tierra BLANDA (materiales con `diggable`: tierra, césped, arena, nieve,
--     ceniza, barro; el de la fortaleza y el de la cueva también la PIEDRA de su isla: EXTRA_DIG), con aire encima,
--     sin pinchos y dentro de su ruta; en un borde, una pared o un suelo que no se puede cavar, se para (persiguiendo:
--     espera ahí) o se da la vuelta (paseando). Lava, pinchos, vacío: revienta como los demás.
--   · SIN PARPADEOS (0.5.97, el usuario: en el borde de su alcance el sprite se volvía de un lado a otro sin parar,
--     "muy creepy"): una vez te ve, te sigue viendo hasta que te alejas de verdad (alcance + LOSE_M casillas, y un
--     margen de altura); no se gira por menos de FACE_DZ px de lado y entre dos giros pasa al menos TURN_MIN s
--     (persiguiendo, si aún no puede girarse, espera quieto); encajonado sin salida, se queda quieto sin girarse.
--   · Evita las zonas de peligro (la Planta carnívora: Entity:dangerAt) — no avanza hacia ellas —.
-- Todo lo que se dibuja sale de estado + deadTimer + x + facing (las instantáneas): igual online. Sin netPack.
-- Arte: hojas assets/images/enemies/mole/<isla>-Sheet.png (14 cuadros 22x20, mira a la DERECHA, los pies en la fila
-- de abajo) de tools/art/enemies/make_jungle_enemies.py; conjunto assets/anim/enemies/mole.json (una VARIANTE por isla).
-- Sonidos moleDig / molePop / moleBite (tools/sounds/jungle_enemies.py) y 'stunned'.
local Entity       = require 'src/world/entities/base/Entity'
local Interactions = require 'src/world/entities/base/Interactions'
local Isles        = require 'src/world/level/Isles'
local Anim, BossFx

local Mole = Entity.extend(Entity, {
    debugColor = { 0.75, 0.5, 0.3 },
    -- (el cuerpo de pie: ~9 de los 22 px de ancho, 16 de los 20 de alto)
    hitbox = { outerW = 0.42, outerH = 0.8, innerW = 0.32, innerH = 0.62 },
})

local S         = GUMMY_SCALE
local FW, FH    = 22, 20
local BODY_DX   = 2             -- px del cuadro: el cuerpo está 2 px a la izquierda del centro (el hocico, delante)
local WANDER_V  = 35            -- px/s paseando bajo tierra sin nadie cerca (persiguiendo: la prop `speed`)
local UP_SEE    = 3             -- casillas: ve a un jugador cuyos pies estén hasta aquí por encima de su suelo
local REACH     = 0.3           -- casillas de lado: "debajo del jugador"
local REACH_UP  = 1.5           -- casillas: los pies del jugador, como mucho así de altos para asomar a morder
local TELL_T    = 0.45          -- s: el montículo tiembla (el aviso)
local EMERGE_T  = 0.14          -- s asomando
local BITE_T    = 0.45          -- s mordiendo
local LOOK_T    = 0.9           -- s fuera mirando tras morder (la ventana para pisarlo; prop `lookTime`)
local DIVE_T    = 0.25          -- s hundiéndose
local COOLDOWN  = 1.0           -- s sin volver a asomar
local DIZZY_T   = 3.0           -- s mareado tras sacarlo con un ground pound
local DIZZY_HOP = 420           -- px/s: el salto al salir despedido del suelo
local POUND_RX  = 2.5           -- casillas de lado de un ground pound que lo saca
local POUND_RY  = 1             -- casillas de alto (el jugador, a la altura de su suelo)
local DIG_EVERY = 0.3           -- s entre dos ruidos de escarbar
local LOSE_M    = 1.5           -- casillas de más: a quien ya ve no lo pierde hasta que se aleja de verdad
local LOSE_UP   = 0.5           -- casillas de más (arriba / abajo) para no perderlo
local FACE_DZ   = 10            -- px de lado: por menos no se gira hacia el jugador
local TURN_MIN  = 0.35          -- s entre dos giros
-- La piedra de SU isla también se cava (la fortaleza y las cuevas son casi todo piedra)
local EXTRA_DIG = { fortaleza = { stone = true }, cueva = { stone = true, deep_stone = true } }

local UNDER = { under = true, tell = true, dive = true }       -- (bajo tierra: ni se le toca ni hace daño)
local UP    = { emerge = true, bite = true, look = true, dizzy = true }

Mole.animId      = 'enemies/mole'
Mole.ownStunLook = true
function Mole.sizePx() return FW * S, FH * S end

function Mole:init()
    self.state, self.deadTimer = 'under', 0
    self.cd, self.digT = 0, 0
    self.vx = 0
    self.turnT, self.prey = TURN_MIN, nil
    self.props.stompable, self.props.onTouch = true, 'hurt'      -- (fijas: ocultas en el editor)
end

-- La isla (su aspecto y la piedra que cava) — sin el nivel, la pradera
function Mole:isle(level) return Isles.of(level or self.levelRef, self.props.isle) end
function Mole:anims()
    Anim = Anim or require 'src/fx/Anim'
    local isle = self:isle()
    return Anim.load(self.animId, isle ~= 'pradera' and isle or nil)
end

-- ── Reglas ────────────────────────────────────────────────────────────────────
function Mole:isUnder() return UNDER[self.state] == true or self.state == 'walk' or self.state == 'spawning' end
function Mole:isBodyDisabled() return self:isUnder() end
function Mole:canBeStomped() return UP[self.state] == true end
function Mole:isObstacle() return UP[self.state] == true and Entity.isObstacle(self) end
function Mole:canBeKnocked() return UP[self.state] == true and self.state ~= 'dizzy' end
function Mole:canBeLaunched() return UP[self.state] == true and Entity.canBeLaunched(self) end
function Mole:canFreeze() return UP[self.state] == true and Entity.canFreeze(self) end
function Mole:canBePushed() return false end                     -- (está en su agujero: el aire no lo mueve)
function Mole:canDropNow() return false end
function Mole:canBeEaten() return UP[self.state] == true and Entity.canBeEaten(self) end   -- (bajo tierra, la planta no lo alcanza)

-- Sin efectos (el cliente predice con esto). Bajo tierra, nada; mareado no hace daño (se le pisa)
function Mole:interact(pa)
    if self:isUnder() then return nil end
    local r, a, b, c = Interactions.defaultCheck(pa, self)
    if self.state == 'dizzy' and (r == 'hurt' or r == 'kill') then return nil end
    return r, a, b, c
end

-- Mordisco (Interactions.run, cuando de verdad quitó vida): aparta al jugador
function Mole:onHurtPlayer(pa)
    if pa.recoil then pa:recoil(pa.x >= self.x and 1 or -1) end
end

-- Ground pound: bajo tierra, si cae cerca de su montículo y a su altura, lo saca mareado (el resto, nada: está bajo
-- tierra). Fuera, lo de siempre (aplastado justo debajo; el empujón lo marea: knockback)
function Mole:onPound(pa, z)
    if not self:isUnder() then return false end
    local pb = pa:getOuterBounds()
    local feet = self.y + self.outerH / 2
    if math.abs(pa.x - self.x) <= POUND_RX * TILE_PX and math.abs(pb.y + pb.h - feet) <= POUND_RY * TILE_PX then
        self:knockOut()
    end
    return true
end
function Mole:knockback(dirX) self:knockOut() end

function Mole:knockOut()
    self.state, self.deadTimer = 'dizzy', 0
    self.vx, self.vy, self.onGround = 0, -DIZZY_HOP, false
    Sound.play('molePop', 0.85)
    Sound.play('stunned')
    Entity.emitFx('crab_dig', self.x, self.y + self.outerH / 2 + 4, { n = 8 })
end

-- ¿Se cava en el punto? (un bloque sólido de tierra blanda, o la piedra de su isla)
function Mole:digsAt(level, x, y)
    local t = level:getDefAt(x, y)
    if not t or t.collision ~= 'solid' or not t.mat or t.mat.contact then return false end
    if t.mat.diggable then return true end
    local extra = EXTRA_DIG[self:isle(level)]
    return extra ~= nil and extra[t.mat.name] == true
end

-- ¿Puede avanzar bajo tierra hacia `dir`? Suelo que se cava, aire encima (sin paredes ni pinchos) y dentro de su ruta
function Mole:canTravel(level, dir)
    local ax = self.x + dir * (self.outerW / 2 + 2)
    if ax >= self.rightBoundPx - 1 or ax <= self.leftBoundPx + 1 then return false end
    local feet = self.y + self.outerH / 2
    if not self:digsAt(level, ax, feet + 6) then return false end
    if level:isEnemySolidAt(ax, feet - 6) or level:isEnemySolidAt(ax, feet - TILE_PX * 0.6) then return false end
    if level.hasSpikeCellInBox and level:hasSpikeCellInBox(ax - 2, feet - TILE_PX * 0.5, 4, TILE_PX * 0.5 - 2) then return false end
    if self:dangerAt(level, ax - 2, feet - self.outerH, 4, self.outerH) then return false end    -- (una planta: ni se acerca)
    return true
end

-- El jugador vivo más cercano a su alcance: de lado `range` casillas, los pies sobre su suelo (no por debajo) y no
-- más de UP_SEE casillas por encima. Al que ya seguía no lo pierde hasta que se aleja de verdad (LOSE_M / LOSE_UP:
-- en el borde del alcance lo veía y dejaba de verlo cada fotograma y se giraba sin parar)
function Mole:target(level)
    local T = TILE_PX
    local feet = self.y + self.outerH / 2
    local R = (self.props.range or 6) * T * require('src/core/Difficulty').k('sense')
    local best, bd = nil, nil
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false and not pa.gulped then
            local pb = pa:getOuterBounds()
            local pf = pb.y + pb.h
            local d = math.abs(pa.x - self.x)
            local kept = pa == self.prey
            local r, lo, hi = R, feet + 8, feet - UP_SEE * T
            if kept then r, lo, hi = R + LOSE_M * T, lo + LOSE_UP * T, hi - LOSE_UP * T end
            if d <= r and pf <= lo and pf >= hi and (not bd or d < bd) then best, bd = pa, d end
        end
    end
    self.prey = best
    return best
end

-- Se gira hacia `f` (si no, false): como mucho un giro cada TURN_MIN s
function Mole:turnTo(f)
    if f == self.facing then return true end
    if (self.turnT or TURN_MIN) < TURN_MIN then return false end
    self.facing, self.turnT = f, 0
    return true
end

-- ¿Está justo encima, a tiro de mordisco?
function Mole:inReach(pa)
    local pb = pa:getOuterBounds()
    return math.abs(pa.x - self.x) <= REACH * TILE_PX and pb.y + pb.h >= self.y + self.outerH / 2 - REACH_UP * TILE_PX
end

function Mole:face(pa) if pa and math.abs(pa.x - self.x) > FACE_DZ then self:turnTo((pa.x > self.x) and 1 or -1) end end

-- ── Update ────────────────────────────────────────────────────────────────────
local function deadly(self, level)
    if self:onDeadlyGround(level) or self:inVoid(level) or self:fellOut(level) then self:dieBurst(); return true end
    return false
end

function Mole:updateCustom(dt, level)
    self.levelRef = level
    local st = self.state
    if st == 'walk' then st = 'under'; self.state, self.deadTimer = 'under', 0 end     -- (al reaparecer / caer de un trampolín)
    if self.cd > 0 then self.cd = math.max(0, self.cd - dt) end
    self.turnT = (self.turnT or TURN_MIN) + dt
    self.deadTimer = self.deadTimer + dt
    local t = self.deadTimer

    if st == 'under' then
        local pa = self:target(level)
        local dir, v = 0, 0
        if pa then
            if self.cd <= 0 and self:inReach(pa) then
                self.state, self.deadTimer, self.vx = 'tell', 0, 0
                self:face(pa)
                Sound.play('moleDig', 0.8, 0.9)
                self:fall(level, dt)
                return true
            end
            local dx = pa.x - self.x
            -- (de cara al jugador; por menos de FACE_DZ no se gira: si ya mira hacia él, se arrima hasta debajo)
            if math.abs(dx) > FACE_DZ or (math.abs(dx) > 2 and ((dx > 0) and 1 or -1) == self.facing) then
                dir = (dx > 0) and 1 or -1
            end
            v = math.min(self.speed > 0 and self.speed or 110, math.abs(dx) / dt)    -- (en el último tramo no se pasa)
            if dir ~= 0 and not self:canTravel(level, dir) then dir = 0 end          -- (persiguiendo: espera en el borde)
            if dir ~= 0 and not self:turnTo(dir) then dir = 0 end                    -- (aún no puede girarse: espera)
        else
            dir, v = self.facing or 1, WANDER_V
            if not self:canTravel(level, dir) then
                -- (paseando: media vuelta si por detrás puede ir; encajonado, quieto — no se gira cada fotograma —)
                if self:canTravel(level, -dir) and self:turnTo(-dir) then dir = -dir else dir = 0 end
            end
        end
        local x0, f = self.x, self.facing
        self:fall(level, dt, dir * v)
        self.facing, self.vx = f, dir * v
        if math.abs(self.x - x0) > 0.2 then
            self.digT = self.digT - dt
            if self.digT <= 0 then
                self.digT = DIG_EVERY
                Sound.play('moleDig', 0.9 + 0.2 * math.random(), pa and 0.6 or 0.25)
                if pa then Entity.emitFx('crab_dig', self.x - dir * 20, self.y + self.outerH / 2 + 4, { n = 2 }) end
            end
        end
        return true

    elseif st == 'tell' then
        self.vx = 0
        self:fall(level, dt)
        self:face(self:target(level))
        if t >= TELL_T then
            self.state, self.deadTimer = 'emerge', 0
            Sound.play('molePop')
            Entity.emitFx('crab_dig', self.x, self.y + self.outerH / 2 + 4, { n = 6 })
        end
        return true

    elseif st == 'emerge' or st == 'bite' or st == 'look' or st == 'dive' then
        self.vx = 0
        self:fall(level, dt)
        if deadly(self, level) then return true end
        if st == 'emerge' and t >= EMERGE_T then
            self.state, self.deadTimer = 'bite', 0
            self:face(self:target(level))
            Sound.play('moleBite')
        elseif st == 'bite' and t >= BITE_T then
            self.state, self.deadTimer = 'look', 0
        elseif st == 'look' then
            self:face(self:target(level))
            if t >= (self.props.lookTime or LOOK_T) then
                self.state, self.deadTimer = 'dive', 0
                Sound.play('moleDig', 0.8, 0.7)
                Entity.emitFx('crab_dig', self.x, self.y + self.outerH / 2 + 4, { n = 4 })
            end
        elseif st == 'dive' and t >= DIVE_T then
            self.state, self.deadTimer, self.cd = 'under', 0, COOLDOWN
        end
        return true

    elseif st == 'dizzy' then
        self.vx = 0
        self:fall(level, dt)
        if deadly(self, level) then return true end
        if t >= DIZZY_T and self.onGround then
            self.state, self.deadTimer = 'dive', 0
            Sound.play('moleDig', 0.8, 0.7)
        end
        return true
    end
    return false
end

-- ── Dibujo (de estado + deadTimer + x + facing) ───────────────────────────────
function Mole:pose()
    local st, t = self.state, self.deadTimer or 0
    local set = self:anims()
    if st == 'under' or st == 'walk' or st == 'spawning' then
        -- (moviéndose el montículo rueda; quieto, el primer cuadro. Lo sabe por cómo cambia x: viaja en la instantánea)
        local moving = self._drawX ~= nil and math.abs(self.x - self._drawX) > 0.05
        self._drawX = self.x
        if moving then self._moundT = (self._moundT or 0) + love.timer.getDelta() end
        return set:frameAt('mound', self._moundT or 0), 0
    end
    if st == 'tell' then
        return set:frameN('mound', 2), (math.floor(t * 30) % 2 == 0) and 1 or -1          -- (tiembla)
    end
    if st == 'emerge' then return set:frameAt('emerge', t), 0 end
    if st == 'bite' then return set:frameAt('bite', t), 0 end
    if st == 'dive' then return set:frameAt('dive', t), 0 end
    if st == 'dizzy' or st == 'dead_fling' then return set:frameAt('dizzy', t), 0 end
    if st == 'dead' then return set:frameAt('dead', t), 0 end
    return set:frameAt('idle', t), 0                                                       -- (look, lanzado, congelado…)
end

function Mole:render(camX, camY)
    local st = self.state
    if st == 'reserve' or st == 'dead_burst' then return end
    local fr, ox = self:pose()
    local f = self.facing or 1
    local x = math.floor(self.x - camX) + (BODY_DX + ox) * S * f
    local feet = math.floor(self.y + self.outerH / 2 - camY)
    local a = 1
    if st == 'dead' then a = math.max(0, 1 - (self.deadTimer or 0) / self.tuning.deadDuration) end
    local dizzy = st == 'dizzy'
    BossFx = BossFx or require 'src/fx/BossFx'
    local hx, hy = math.floor(self.x - camX), feet - 18 * S
    if dizzy then BossFx.stars(hx, hy, 6 * S, 2 * S, 2, 1, 'back') end
    love.graphics.setColor(1, 1, 1, a)
    local r = (st == 'dead_fling') and (self.deadTimer or 0) * 10 * f or 0
    self:anims():drawFrame(fr, x, feet, r, S * f, S, 0.5, 1)
    love.graphics.setColor(1, 1, 1, 1)
    if dizzy then BossFx.stars(hx, hy, 6 * S, 2 * S, 2, 1, 'front') end
end

-- Editor: alcance (de lado) al seleccionarlo
function Mole.drawEditorOverlay(props, cx, cy, zoom)
    local r = (props.range or 6) * TILE_PX
    love.graphics.setColor(0.8, 0.55, 0.3, 0.8)
    love.graphics.setLineWidth(2 / zoom)
    love.graphics.rectangle('line', cx - r, cy - UP_SEE * TILE_PX, 2 * r, (UP_SEE + 0.5) * TILE_PX)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Icono de la paleta: de pie (el cuadro "quieto")
local function drawIcon(x, y, s)
    local c = require('src/fx/Anim').clip('enemies/mole', 'idle')
    c:drawPx(1, x, y + (s - s * c.h / c.w), 0, s / c.w, s / c.w)
end

local G = 'Topo'
return {
    name = 'mole', label = 'Topo', category = 'Enemigos', class = Mole,
    description = 'De todas las islas (su aspecto, el de la isla). Va BAJO TIERRA: solo se ve un montículo que avanza por '
               .. 'el suelo hacia ti. Debajo de ti tiembla, ASOMA y MUERDE (1 de vida); se queda un momento fuera (pisarlo '
               .. 'lo aplasta) y se hunde. Un ground pound cerca de su montículo lo saca MAREADO: inofensivo, se le pisa. '
               .. 'Solo cava tierra blanda (tierra, césped, arena, nieve, ceniza, barro; el de la fortaleza y el de la '
               .. 'cueva, también piedra): en bordes, paredes o piedra se para o se da la vuelta.',
    isleArt = true,
    traits = { wantsLevel = true },
    -- (movement = 'walk' solo para que el editor enseñe la RUTA: lo mueve updateCustom)
    defaults = { movement = 'walk', speed = 110, points = 20, onTouch = 'hurt', pauses = false },
    hide = { 'movement', 'attach', 'turnAtEdges', 'flyMode', 'flyRange', 'bobAmp', 'pauses', 'dropOnSight', 'detectRange',
             'onTouch', 'stompable' },
    props = {
        { key = 'range', kind = 'int', label = 'Te ve a (casillas)', group = G, default = 6, min = 1, max = 30,
          help = 'De lado; y a su altura (hasta 3 casillas por encima de su suelo)' },
        { key = 'lookTime', kind = 'number', label = 'Fuera tras morder (s)', group = G, default = LOOK_T, min = 0.2, max = 5,
          step = 0.1, help = 'Lo que se queda asomado después de morder: el momento de pisarlo' },
    },
    editor = { draw = drawIcon },
}
