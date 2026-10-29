-- La PLANTA CARNÍVORA (types/enemies/carnivoreplant.lua; 0.5.96, diseño B «Cepo» elegido por el usuario el
-- 2026-10-29): de la JUNGLA. FIJA, como una trampa: dos hojas dentadas abiertas con una flor de cebo.
--   · DÓNDE (prop `mount`, 0.5.97): en el SUELO (por defecto: cae hasta él), colgada del TECHO o en una PARED (a su
--     izquierda o a su derecha). Colgada se PEGA al bloque que tiene detrás (no cae); si ese bloque desaparece, sale
--     despedida (dieFling). Sus cajas (disparo, mordisco, cuerpo) y el dibujo giran con ella.
--   · Un jugador que pasa POR DELANTE de sus hojas (su caja de disparo: TRIGGER_HW de lado, TRIGGER_H de fondo) la
--     dispara: tiembla un instante (el aviso, TELL_T) y se CIERRA de golpe (SNAP_T). Al jugador que pilla dentro de lo
--     que barren las hojas (SNAP_HW) se lo TRAGA (0.5.97, el usuario: "como los escarabajos"): queda DENTRO, sin
--     control y sin verse (PlayerAdventure:swallow, src/player/PlayerGulp.lua), con la ayuda de MACHACAR BOTONES encima;
--     cada pulsación cuenta y con las suficientes lo ESCUPE (un instante invulnerable); dentro pierde 1 de vida cada
--     GULP_BITE s (si llega a 0, muere como siempre). Se traga a UNO a la vez ('hold'). Corriendo por encima, te pilla;
--     hay que saltarla.
--   · Luego se queda CERRADA masticando (`chewTime` s). Tocarla cerrada no hace nada. Después se vuelve a abrir
--     (OPEN_T) y no se dispara en REARM s.
--   · NO SE LA MATA PISÁNDOLA (0.5.97, el usuario: "así el jugador prioriza distraerla o dormirla en vez de matarla"):
--     pisarla ABIERTA = te traga (caes dentro de lo que muerde); un pisotón o un ground pound con ella CERRADA
--     (masticando, con algo dentro) o DORMIDA solo te hace REBOTAR, sin hacerle nada (rasgo `stompProof`,
--     Interactions.check). Todo lo demás que mata a un enemigo la mata: una bomba que explota DENTRO o una explosión
--     cerca (Explosions.blast → dieFling), que se rompa el bloque en el que está (de pie: Level:forStanders; colgada:
--     supported), lava, pinchos, el vacío.
--   · SE COME DE TODO (0.5.97, el usuario): cualquier entidad que no sea un jefe y se pueda comer (Entity:canBeEaten:
--     los enemigos — Gummies, Crabbies, Topos asomados, Saltarines, Pirañas saltando... — y lo `edible`, el Escarabajo)
--     que entra en su caja de disparo → se cierra sobre ella, se la COME (desaparece con un crujido: Entity:dieEaten)
--     y DUERME `sleepTime` s ("z"): inofensiva (pisarla, rebotas). Por instinto los enemigos NO se acercan (su caja de
--     disparo es una ZONA DE PELIGRO: dangerBox, Entity:dangerAt), pero empujados (ground pound, lanzados, el aire...)
--     sí acaban dentro.
--   · BOMBAS (0.5.97, el usuario): una bomba suelta no le interesa; una bomba LANZADA por un jugador sí (su canBeEaten):
--     se cierra sobre ella y se la traga ('bomb'); la bomba explota DENTRO al cabo de BombCore.EATEN_FUSE s y la
--     planta REVIENTA (dieBurst), con la explosión de siempre (Explosions.blast) desde su vaina.
-- No se mueve (static): ni empujones, ni trampolines, ni el aire. EL MORDISCO SE VE (0.5.97, el usuario: "le falta
-- squash & stretch: que se la vea abalanzarse a un lado, al otro, arriba o abajo, estirándose para atrapar a su
-- presa"): al avisar se encoge (anticipación), al cerrarse se ESTIRA hacia la presa (a lo largo de su normal: arriba
-- en el suelo, abajo en el techo, de lado en una pared) y se INCLINA hacia el lado en el que está (shear desde la base:
-- las hojas de abajo no se mueven); al morder, rebota (se aplasta y vuelve, un muelle amortiguado). Dónde está la
-- presa (aimT / aimN: de lado y de fondo, desde su base) va en su netPack. Todo lo que se dibuja sale de estado +
-- deadTimer + eso (y de la prop `mount`): igual online; abierta y esperando no se envía (netAtRest). Arte:
-- assets/images/enemies/carnivoreplant/plant-Sheet.png (11 cuadros 26x24, la base en la fila de abajo) de
-- tools/art/enemies/make_jungle_enemies.py; conjunto assets/anim/enemies/carnivoreplant.json; la "z" de dormida,
-- BossFx.sleepZ. Sonidos plantRustle / plantSnap / plantCrunch (tools/sounds/jungle_enemies.py).
local Entity       = require 'src/world/entities/base/Entity'
local Interactions = require 'src/world/entities/base/Interactions'
local BossFx

local Plant = Entity.extend(Entity, {
    debugColor = { 0.85, 0.3, 0.5 },
    deadDuration = 2.5,              -- (marchita, se queda un rato)
    -- (la caja es la de la vaina CERRADA: ~8 de los 26 px de ancho, 16 de los 24 de alto)
    -- (0.5.97: la vaina cerrada va de pie sobre un tallo — ~17 px de alto —)
    hitbox = { outerW = 0.3, outerH = 0.68, innerW = 0.26, innerH = 0.58 },
})

local S         = GUMMY_SCALE
local FW, FH    = 26, 24
local TRIGGER_HW = 52            -- px a cada lado del centro: la caja que la dispara (las hojas abiertas miden ±44)
local TRIGGER_H  = 1.2           -- casillas por delante de su base (en el suelo: por encima)
local SNAP_HW    = 44            -- px a cada lado: lo que barren las hojas al cerrarse (ahí muerde)
local SNAP_H     = 0.9           -- casillas de fondo de lo que muerde
local DANGER_M   = 6             -- px de más alrededor de la caja de disparo: lo que evitan los enemigos
local TELL_T     = 0.3           -- s temblando (el aviso)
local SNAP_T     = 0.15          -- s cerrándose (lo que dura el mordisco)
local CHEW_T     = 2.4           -- s cerrada masticando (prop `chewTime`): la ventana para pisarla
local SLEEP_T    = 6             -- s dormida tras comer (prop `sleepTime`)
local OPEN_T     = 0.35          -- s abriéndose
local REARM      = 0.4           -- s abierta antes de poder dispararse otra vez
local BOMB_WARN  = 1.2           -- s: con una bomba dentro, lo que tarda en hincharse del todo (solo dibujo)
-- (cerrada: pisarla solo te hace rebotar — stompProof —; abierta, pisarla te traga)
local SHUT = { chew = true, sleep = true, hold = true, bomb = true, eat = true }
-- El mordisco (dibujo): cuánto se estira hacia la presa y cuánto dura el rebote
local STRETCH_MIN, STRETCH_MAX = 0.2, 0.5    -- estirón (fracción de su alto) con la presa cerca / lejos
local LEAN_MAX   = 48            -- px que se inclina la punta hacia el lado de la presa, como mucho
local RECOIL_T   = 0.7           -- s del rebote tras cerrarse (muelle amortiguado)

-- Dónde está: la normal (hacia fuera del bloque que tiene detrás) y el giro del dibujo
local MOUNT = {
    floor      = { 0, -1, 0 },
    ceiling    = { 0, 1, math.pi },
    wall_left  = { 1, 0, math.pi / 2 },     -- (la pared a su IZQUIERDA: mira a la derecha)
    wall_right = { -1, 0, -math.pi / 2 },   -- (la pared a su DERECHA: mira a la izquierda)
}
Plant.MOUNT = MOUNT

Plant.animId = 'enemies/carnivoreplant'
Plant.freezeFloats = true
Plant.inedible = true            -- (otra planta no se la come)
Plant.stompProof = true          -- (pisotones y ground pounds: solo rebotas — Interactions.check —)
function Plant.sizePx() return FW * S, FH * S end

function Plant:init()
    self.state, self.deadTimer, self.cd = 'idle', 0, 0
    self.aimT, self.aimN = 0, 0
    self.vx, self.moving = 0, false
    self.props.stompable, self.props.onTouch = true, 'none'
    local m = MOUNT[self.props.mount or 'floor'] or MOUNT.floor
    self.nx, self.ny, self.rot = m[1], m[2], m[3]
    self.mounted = self.ny ~= -1                          -- (colgada: techo o pared, pegada a su bloque)
    if self.mounted then self.flying = true end           -- (sin gravedad: Entity no la hace caer)
end

-- ── Dónde está ───────────────────────────────────────────────────────────────
-- La BASE: el punto de la cara del bloque en el que está (en el suelo, sus pies): a media vaina del centro de su caja,
-- hacia el bloque (sale de x, y: igual en el cliente online)
function Plant:base()
    return self.x - self.nx * self.outerH / 2, self.y - self.ny * self.outerH / 2
end

-- Una caja por delante de la base: `hw` px a cada lado, `h` px de fondo (girada con ella)
function Plant:frontBox(hw, h, into)
    local bx, by = self:base()
    if self.nx == 0 then
        return Entity.box(into, bx - hw, (self.ny < 0) and (by - h) or by, hw * 2, h)
    end
    return Entity.box(into, (self.nx > 0) and bx or (bx - h), by - hw, h, hw * 2)
end

-- Colgada: se pega al bloque que tiene detrás (desde el centro de su casilla hacia él). Sin bloque, se queda en el
-- suelo (cae, como la de siempre)
function Plant:tryAttach(level)
    if not self.mounted then return false end
    if self.ax then self.x, self.y, self.onGround = self.ax, self.ay, true; return true end   -- (ya pegada: reaparecer…)
    if not level then return false end
    local hx, hy = self.home and self.home.x or self.x, self.home and self.home.y or self.y
    for d = 0, TILE_PX * 1.5, 1 do
        local px, py = hx - self.nx * d, hy - self.ny * d
        if level:isEnemySolidAt(px, py) then
            -- (la base en la cara del bloque; el centro de su caja, a media vaina de ella)
            local bx, by = px + self.nx * 0.5, py + self.ny * 0.5
            self.ax, self.ay = bx + self.nx * self.outerH / 2, by + self.ny * self.outerH / 2
            self.x, self.y, self.onGround = self.ax, self.ay, true
            return true
        end
    end
    self.mounted, self.flying, self.nx, self.ny, self.rot = false, false, 0, -1, 0
    return false
end

-- ¿Sigue ahí el bloque al que está pegada?
function Plant:supported(level)
    local bx, by = self:base()
    return level:isEnemySolidAt(bx - self.nx * 4, by - self.ny * 4)
end

function Plant:fall(level, dt, vx)
    if self.mounted then return end
    return Entity.fall(self, level, dt, vx)
end

-- (de pared: la caja es la misma, tumbada)
function Plant:getOuterBounds(into)
    if self.nx == 0 then return Entity.getOuterBounds(self, into) end
    return Entity.box(into, self.x - self.outerH / 2, self.y - self.outerW / 2, self.outerH, self.outerW)
end
function Plant:getInnerBounds(into)
    if self.nx == 0 then return Entity.getInnerBounds(self, into) end
    return Entity.box(into, self.x - self.innerH / 2, self.y - self.innerW / 2, self.innerH, self.innerW)
end
function Plant:surfaceNormal() return self.nx, self.ny end

-- ── Reglas ────────────────────────────────────────────────────────────────────
function Plant:canBeStomped() return false end         -- (stompProof)
function Plant:canBeKnocked() return false end
function Plant:canBeLaunched() return false end
function Plant:canBePushed() return false end
function Plant:canDropNow() return false end
function Plant:canFreeze() return not self.mounted and Entity.canFreeze(self) end

local function overlap(a, b) return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y end

function Plant:triggerBox() return self:frontBox(TRIGGER_HW, TRIGGER_H * TILE_PX) end
function Plant:snapBox() return self:frontBox(SNAP_HW, SNAP_H * TILE_PX) end
-- La ZONA DE PELIGRO (Entity:dangerAt): su caja de disparo y un poco más. Mientras vive
function Plant:dangerBox()
    if not self.alive or self.state == 'dead' or Entity.SPECIAL_DEATH[self.state] or self:isGhost() then return nil end
    local b = self:frontBox(TRIGGER_HW + DANGER_M, TRIGGER_H * TILE_PX + DANGER_M, self._dz)
    self._dz = b
    return b
end

-- Sin efectos: abierta, caerle encima no hace nada aquí (caes en su caja de disparo y te traga: update); cerrada o
-- dormida, el pisotón / ground pound se queda en un REBOTE (stompProof: Interactions.check lo convierte)
function Plant:interact(pa)
    local r, a, b, c = Interactions.defaultCheck(pa, self)
    if r == 'stomp' and not SHUT[self.state] then return nil end
    return r, a, b, c
end

function Plant:netAtRest() return Entity.netAtRest(self) or (self.alive and self.state == 'idle' and self.cd <= 0) end
function Plant:netRest()
    if self.summonOf then return Entity.netRest(self) end
    self.alive, self.state, self.deadTimer = true, 'idle', 0
    self.aimT, self.aimN = 0, 0
end
-- Online: dónde está la presa (para el dibujo del mordisco)
function Plant:netPack() return { math.floor((self.aimT or 0) + 0.5), math.floor((self.aimN or 0) + 0.5) } end
function Plant:netApply(a, b) self.aimT, self.aimN = tonumber(b[1]) or 0, tonumber(b[2]) or 0 end

-- Apunta a la presa (de lado — a lo largo de su base — y de fondo — por delante —, desde su base)
function Plant:aimAt(px, py)
    local bx, by = self:base()
    local dx, dy = px - bx, py - by
    self.aimT = math.max(-80, math.min(80, dx * -self.ny + dy * self.nx))
    self.aimN = math.max(0, math.min(160, dx * self.nx + dy * self.ny))
end

-- ¿Algún jugador en la caja? (`free` = solo uno al que se puede tragar: no invulnerable ni ya tragado)
function Plant:playerIn(level, box, free)
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false and not pa.gulped and overlap(box, pa:getOuterBounds())
           and (not free or (pa.canBeSwallowed and pa:canBeSwallowed())) then
            return pa
        end
    end
    return nil
end
-- ¿Algo que se come? (Entity:canBeEaten: enemigos, el Escarabajo, una bomba lanzada... nunca los jefes)
function Plant:foodIn(level, box)
    for _, e in ipairs(level.liveEntities or {}) do
        if e ~= self and e.canBeEaten and e:canBeEaten() and overlap(box, e:getOuterBounds()) then return e end
    end
    return nil
end

function Plant:shut(st)
    self.state, self.deadTimer = st, 0
end

-- Dónde tiene la vaina (lo que se traga va ahí)
function Plant:podCenter() return self.x, self.y end

-- ── Update ────────────────────────────────────────────────────────────────────
function Plant:updateCustom(dt, level)
    local st = self.state
    if st == 'walk' then st = 'idle'; self.state, self.deadTimer = 'idle', 0 end    -- (al reaparecer)
    if self.cd > 0 then self.cd = math.max(0, self.cd - dt) end
    self.deadTimer = self.deadTimer + dt
    local t = self.deadTimer
    self.vx = 0
    if self.mounted then
        self:tryAttach(level)
        if self.mounted and not self:supported(level) then self:dieFling(self.nx ~= 0 and self.nx or self.facing); return true end
    end
    self:fall(level, dt)
    if self:onDeadlyGround(level) or self:fellOut(level) or self:inVoid(level) then self:dieBurst(); return true end
    local p = self.props

    if st == 'idle' then
        if self.cd <= 0 then
            local box = self:triggerBox()
            local food = self:foodIn(level, box)
            if food then self:snapOn(food); return true end
            local pa = self:playerIn(level, box)
            if pa then
                self.state, self.deadTimer = 'tell', 0
                self:aimAt(pa.x, pa.y)
                Sound.play('plantRustle')
            end
        end
    elseif st == 'tell' then
        local box = self:triggerBox()
        local food = self:foodIn(level, box)
        if food then self:snapOn(food); return true end
        local pa = self:playerIn(level, box)
        if pa then self:aimAt(pa.x, pa.y) end
        if t >= TELL_T then
            self.state, self.deadTimer = 'snap', 0
            Sound.play('plantSnap')
            local bx, by = self:base()
            Entity.emitFx('crab_dig', bx, by + 4 * -self.ny, { n = 3 })
        end
    elseif st == 'snap' then
        local box = self:snapBox()
        local food = self:foodIn(level, box)
        if food then self:snapOn(food); return true end
        local pa = self:playerIn(level, box, true)
        if pa then self:swallowPlayer(pa); return true end
        local near = self:playerIn(level, self:triggerBox())
        if near then self:aimAt(near.x, near.y) end
        if t >= SNAP_T then self:shut('chew') end
    elseif st == 'hold' then
        -- (con un jugador dentro: hasta que se escapa machacando botones o se muere — PlayerGulp —)
        local pa = self.held
        local here = false                                      -- (sigue en la partida: online se puede ir)
        for _, q in ipairs(level.players or {}) do if q == pa then here = true end end
        if not pa or not here or pa.gulpBy ~= self or not pa.gulped or pa.dying or pa.alive == false then
            self.held = nil
            if pa and pa.gulpBy == self then pa.gulpBy = nil end
            self:shut('chew')                                   -- (lo escupió: cerrada, se la puede pisar)
        end
    elseif st == 'eat' then
        if t >= SNAP_T then self:shut('sleep') end
    elseif st == 'bomb' then
        -- (con una bomba dentro: cuando explota — BombCore, estado 'eaten' → 'exploding' —, revienta)
        local b = self.inside
        if not b or not b.alive or b.state ~= 'eaten' then self.inside = nil; self:dieBurst(); return true end
    elseif st == 'chew' then
        if t >= (p.chewTime or CHEW_T) then self.state, self.deadTimer = 'open', 0 end
    elseif st == 'sleep' then
        if t >= (p.sleepTime or SLEEP_T) then
            self.state, self.deadTimer = 'open', 0
            Sound.play('plantRustle', 1.3, 0.5)
        end
    elseif st == 'open' then
        if t >= OPEN_T then self.state, self.deadTimer, self.cd = 'idle', 0, REARM end
    else
        return false
    end
    return true
end

-- Se cierra sobre algo que se come: desaparece y ella se duerme. Si eso SIGUE VIVO dentro (`onEaten(planta)` → true:
-- la bomba lanzada), lo guarda ('bomb') hasta que revienta
function Plant:snapOn(food)
    Sound.play('plantSnap')
    self:aimAt(food.x, food.y)
    local bx, by = self:base()
    if food.onEaten and food:onEaten(self) then
        self.inside = food
        self.state, self.deadTimer = 'bomb', 0
        Entity.emitFx('crab_dig', bx, by - self.ny * 4, { n = 4 })
        return
    end
    food:dieEaten()
    self.state, self.deadTimer = 'eat', 0
    Sound.play('plantCrunch')
    Entity.emitFx('crab_dig', bx, by - self.ny * 4, { n = 4 })
end

-- Se cierra sobre un jugador: se lo traga (PlayerAdventure:swallow) y lo tiene dentro ('hold')
function Plant:swallowPlayer(pa)
    local bx, by = self:base()
    self:aimAt(pa.x, pa.y)
    if not pa:swallow(bx, by, self.nx, self.ny) then return end
    pa.gulpBy = self
    self.held = pa
    self.state, self.deadTimer = 'hold', 0
    Sound.play('plantCrunch', 0.8, 0.8)
    Entity.emitFx('crab_dig', bx, by - self.ny * 4, { n = 4 })
    Entity.emitFx('shake_small', self.x, self.y)
end

-- Con una bomba dentro, cualquier cosa que la mate (otra explosión, la suya): revienta en pedazos
function Plant:dieFling(dirX)
    if self.state == 'bomb' then return self:dieBurst() end
    return Entity.dieFling(self, dirX)
end

-- ── Dibujo (de estado + deadTimer + aimT/aimN + la prop `mount`) ─────────────
-- El MORDISCO (squash & stretch): → sx, sy (de lado / a lo largo de su normal, desde la base) y cuánto se inclina la
-- punta hacia el lado de la presa (px). Avisando se encoge un poco y se echa atrás (anticipación); cerrándose se
-- estira hacia ella; al morder rebota como un muelle (estirada → aplastada → en reposo)
local function spring(rt)
    if rt < 0.04 then return 0.6 + 0.4 * rt / 0.04 end            -- (comida sin aviso: el estirón de golpe)
    rt = rt - 0.04
    return math.exp(-rt * 6) * math.cos(rt * 18)
end
local RECOIL = { eat = 0, hold = 0, bomb = 0, chew = 0, sleep = SNAP_T }   -- (dormida: viene de 'eat', que dura SNAP_T)
function Plant:pose(st, t)
    local str = math.max(STRETCH_MIN, math.min(STRETCH_MAX, STRETCH_MIN + (self.aimN or 0) / 300))
    local lean = math.max(-LEAN_MAX, math.min(LEAN_MAX, (self.aimT or 0) * 0.9))
    if st == 'tell' then
        local q = math.min(1, t / TELL_T)
        return 1 + 0.08 * q, 1 - 0.14 * q, -lean * 0.2 * q
    elseif st == 'snap' then
        local p = math.sin(math.pi / 2 * math.min(1, t / (SNAP_T * 0.6)))
        return 1 - 0.35 * str * p, 1 + str * p, lean * p
    elseif RECOIL[st] then
        local rt = t + RECOIL[st]
        if rt < RECOIL_T then
            local v = spring(rt) * (1 - rt / RECOIL_T)
            return 1 - 0.35 * str * v, 1 + str * v, lean * v
        end
    end
    return 1, 1, 0
end

function Plant:render(camX, camY)
    local st, t = self.state, self.deadTimer or 0
    if st == 'reserve' or st == 'dead_burst' then return end
    if self.mounted and not self.ax and self.levelRef then self:tryAttach(self.levelRef) end   -- (cliente: aún sin instantánea)
    local set = self:anims()
    local f = self.facing or 1
    local bx, by = self:base()
    local x, y = math.floor(bx - camX), math.floor(by - camY)
    local tx, ty = -self.ny, self.nx                          -- (de lado, a lo largo de su base)
    local fr, o, a, k = nil, 0, 1, 1
    if st == 'tell' then
        fr = set:frameAt('tell', t)
        o = (math.floor(t * 30) % 2 == 0) and 1 or -1
    elseif st == 'snap' or st == 'eat' then fr = set:frameAt('snap', t)
    elseif st == 'chew' then fr = set:frameAt('chew', t)
    elseif st == 'hold' then                                 -- (con alguien dentro: mastica y se agita)
        fr = set:frameAt('chew', t * 1.6)
        o = (math.floor(t * 16) % 2 == 0) and 1 or -1
    elseif st == 'bomb' then                                 -- (con una bomba dentro: tiembla cada vez más y se hincha)
        local q = math.min(1, t / BOMB_WARN)
        fr = set:frameAt('chew', t * (1 + 3 * q))
        o = ((math.floor(t * (12 + 30 * q)) % 2 == 0) and 1 or -1) * (1 + math.floor(q * 1.5))
        k = 1 + 0.12 * q
    elseif st == 'sleep' then fr = set:frameAt('sleep', t)
    elseif st == 'open' then fr = set:frameAt('snap', math.max(0, set:length('snap') * (1 - t / OPEN_T)))   -- (al revés)
    elseif st == 'dead' or st == 'dead_fling' then
        fr = set:frameAt('dead', 0)
        a = math.max(0, 1 - math.max(0, t - self.tuning.deadDuration * 0.4) / (self.tuning.deadDuration * 0.6))
    else
        fr = set:frameAt('idle', love.timer.getTime() + (self.home and self.home.x or 0) * 0.013)
    end
    if st == 'bomb' and math.floor(t * (4 + 14 * math.min(1, t / BOMB_WARN))) % 2 == 0 then
        love.graphics.setColor(1, 0.55, 0.5, a)                 -- (destellos rojos: va a reventar)
    else
        love.graphics.setColor(1, 1, 1, a)
    end
    local r = self.rot + ((st == 'dead_fling') and t * 10 * f or 0)
    local px, py, lean = self:pose(st, t)
    local sx, sy = S * f * k * px, S * k * py
    -- (inclinación: la punta — FH px por encima de la base — se corre `lean` px a lo largo de su base; la base, quieta)
    local kx = (lean ~= 0) and (-lean / (FH * sx)) or 0
    set:drawFrame(fr, x + tx * o * S, y + ty * o * S, r, sx, sy, 0.5, 1, kx, 0)
    love.graphics.setColor(1, 1, 1, 1)
    if st == 'sleep' then
        BossFx = BossFx or require 'src/fx/BossFx'
        BossFx.sleepZ(t, x + tx * 4 * S + self.nx * 13 * S, y + ty * 4 * S + self.ny * 13 * S, 3)
    end
end

-- F1: la caja que la dispara (blanca) y lo que muerde al cerrarse (roja, solo cerrándose)
function Plant:debugBoxes()
    local b = self:triggerBox()
    b.kind = 'area'
    if self.state == 'snap' then return { b, self:snapBox() } end
    return { b }
end

-- Editor: la caja que la dispara, girada según dónde está (prop `mount`)
function Plant.drawEditorOverlay(props, cx, cy, zoom)
    local m = MOUNT[props.mount or 'floor'] or MOUNT.floor
    local nx, ny, T = m[1], m[2], TILE_PX
    local bx, by = cx - nx * T / 2, cy - ny * T / 2
    local hw, h = TRIGGER_HW, TRIGGER_H * T
    local x, y, w, hh
    if nx == 0 then x, y, w, hh = bx - hw, (ny < 0) and (by - h) or by, hw * 2, h
    else x, y, w, hh = (nx > 0) and bx or (bx - h), by - hw, h, hw * 2 end
    love.graphics.setColor(0.9, 0.3, 0.5, 0.8)
    love.graphics.setLineWidth(2 / zoom)
    love.graphics.rectangle('line', x, y, w, hh)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawIcon(x, y, s)
    local c = require('src/fx/Anim').clip('enemies/carnivoreplant', 'idle')
    c:drawPx(1, x, y + (s - s * c.h / c.w), 0, s / c.w, s / c.w)
end

local G = 'Planta carnívora'
return {
    name = 'carnivoreplant', label = 'Planta carnívora', category = 'Enemigos', class = Plant,
    description = 'De la jungla. Fija en el suelo, el techo o una pared, abierta. Si pasas por DELANTE de sus hojas, '
               .. 'tiembla y se CIERRA de golpe: si te pilla, te TRAGA (machaca botones para salir; dentro pierdes 1 de '
               .. 'vida cada poco). Luego mastica un rato: SOLO cerrada se la puede pisar. Se come de todo lo que no es un '
               .. 'jefe (los enemigos se apartan de ella, pero empujados caen dentro) y se DUERME: inofensiva, se la pisa. '
               .. 'Si le lanzas una bomba, se la traga y revienta.',
    traits = { wantsLevel = true },
    defaults = { movement = 'static', speed = 0, points = 20, onTouch = 'none', pauses = false },
    hide = { 'movement', 'attach', 'speed', 'startDir', 'patrol', 'turnAtEdges', 'flyMode', 'flyRange', 'bobAmp', 'pauses',
             'dropOnSight', 'detectRange', 'onTouch', 'stompable' },
    props = {
        { key = 'mount', kind = 'enum', label = 'Dónde está', group = G, default = 'floor',
          options = { { value = 'floor', label = 'Suelo' }, { value = 'ceiling', label = 'Colgada del techo' },
                      { value = 'wall_left', label = 'Pared a su izquierda' }, { value = 'wall_right', label = 'Pared a su derecha' } },
          help = 'En el suelo cae hasta él; en el techo o en una pared se pega al bloque que tiene detrás (y gira)' },
        { key = 'chewTime', kind = 'number', label = 'Cerrada masticando (s)', group = G, default = CHEW_T, min = 0.5, max = 10,
          step = 0.1, help = 'Tras cerrarse (o escupir a un jugador): el rato en que se la puede pisar' },
        { key = 'sleepTime', kind = 'number', label = 'Dormida tras comer (s)', group = G, default = SLEEP_T, min = 1, max = 30,
          step = 0.5, help = 'Tras comerse algo: inofensiva y se la puede pisar' },
    },
    editor = { draw = drawIcon },
}
