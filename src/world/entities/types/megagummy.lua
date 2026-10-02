-- Jefe REY GUMMY (types/megagummy.lua): el Gummy en grande (su MISMO sprite 16x16 a escala 10,
-- con cejas y una coronita de oro; tools/ui/make_gummy_variants.py --apply-mega). Persigue a
-- saltitos (contacto = 1 de vida y empujón; de lado es sólido; encima solo rebota) y:
--   1. PANZAZO ('flop_wind' → 'flop_air' → 'flop_land'): se agacha (la MARCA de dónde caerá sigue
--      al jugador y se fija al final), salta muy alto y cae de barriga: aplasta (2 de vida) y salen
--      dos OLAS de gelatina por el suelo (bajitas: se saltan; 1 de vida + empujón). Después queda
--      MAREADO ('dazed', estrellitas): es lo ÚNICO vulnerable del cuerpo → pisotón 1 / ground pound 2,
--      un golpe por ocasión. En la fase 2 encadena 2 panzazos antes de marearse.
--   2. GUARDIA REAL (fase 2, `phase2`): toca la fanfarria y entran Gummies (normal, con casco y
--      volador) por cualquier sitio de la arena (suelo, lados, techo en paracaídas, aire), marcado antes. Son entidades de reserva del nivel (def.summons, como los
--      súbditos del Mega Crabby): mismos índices en servidor y clientes; mueren con él.
--   3. SE DIVIDE (fase 3): cuando le quedan `splitCount` × `partHp` de vida, la corona sale volando
--      y revienta en `splitCount` Gummies medianos (escala 6) que persiguen a saltos. Cada trozo:
--      contacto 1 de vida; pisotón 1 / ground pound 2 (`partHp` de vida). La barra de vida sigue
--      bajando con ellos (hp = suma de los trozos). Muerto el último: revienta en confeti y la
--      corona da un último bote (muerte propia 'dying_pop'; libera la zona).
-- Entrada (genérica de Boss): cae del cielo de panza, se levanta, fanfarria y risa.
-- Todo lo que se dibuja sale de state + deadTimer + x, y (+ netPackExtra): igual online.
-- Sprites: assets/images/bosses/megagummy/; sonidos: assets/sounds/bosses/megagummy/
-- (tools/sounds/megagummy.py). Física (choques, saltos a una marca, zona): la de la Gran Bola
-- de Nieve (types/snowboss.lua), reutilizada.

local Entity      = require 'src/world/entities/Entity'
local Boss        = require 'src/world/entities/Boss'
local SpriteStrip = require 'src/fx/SpriteStrip'
local Snow        = require('src/world/entities/types/snowboss').class

local MG = Entity.extend(Boss, {
    debugColor = { 1, 0.95, 0.6 },
    hitbox = { outerW = 12 / 16, outerH = 13 / 16, innerW = 11 / 16, innerH = 12 / 16 },
})
MG.hurtSound   = 'kingHurt'
MG.introLength = 3.6
MG.wantsLevel  = true                  -- (BossZones.link: sombra y marca sobre la superficie real)

-- Física compartida con la Gran Bola de Nieve (misma gravedad: Snow.jumpTo cuadra con Snow.physics)
MG.move, MG.physics, MG.friction, MG.groundDecel = Snow.move, Snow.physics, Snow.friction, Snow.groundDecel
MG.zoneBounds, MG.target, MG.jumpTo, MG.groundBelow = Snow.zoneBounds, Snow.target, Snow.jumpTo, Snow.groundBelow
local strike = Snow.strike

local T  = TILE_PX
local MS = 10                         -- escala del cuerpo (16x16 → 160 px)
local PS = 6                          -- escala de los trozos (Gummies medianos)
MG.MS, MG.PS = MS, PS

-- Ritmo por fase (1 = normal, 2 = con la guardia: más rápido)
local HOP_GAP    = { 0.5, 0.36 }      -- s en el suelo entre saltitos persiguiendo
local HOP_VX     = { 190, 260 }
local HOP_VY     = 560
local FLOP_EVERY = { 3.4, 2.4 }       -- s persiguiendo antes de un panzazo
local FLOP_WIND  = { 0.75, 0.55 }     -- se agacha (la marca sigue al jugador)
local FLOP_LOCK  = 0.22               -- últimos s de la carga: la marca ya no se mueve
local FLOP_UP    = { 4.2, 3.6 }       -- casillas que sube por encima de lo más alto
local FLOP_CHAIN = { 1, 2 }           -- panzazos seguidos antes de marearse
local FLOP_LAND  = 0.45               -- tumbado tras un panzazo de la cadena (no el último)
local DAZE_T     = { 2.8, 2.2 }
local RECOVER_T  = 0.7
local SUMMON_T   = 1.6                -- fanfarria: entran a los SUMMON_AT s
local SUMMON_AT  = 0.9
local FANFARE_AT = 0.3
local PHASE_T    = 1.6
local SPLIT_T    = 1.0                -- tiembla; a los SPLIT_T s revienta en trozos
local CROWN_AT, CROWN_T = 0.25, 0.9   -- la corona sale volando (y tarda en caer)
local POP_T      = 2.4                -- muerte: confeti y la corona bota
local GRACE      = 0.8                -- s sin daño por contacto tras un golpe de contacto
local WAVE_SPD   = 470
local WAVE_LIFE  = 1.7
local WAVE_W, WAVE_H = 40, 30         -- caja de la ola (bajita: se salta)
local PART_WAIT  = { 0.55, 0.42 }     -- trozos: s en el suelo entre saltos (2 trozos / 3 trozos)
local PART_INV   = 0.8
-- Golpes a un jugador: { vida, vx, vy, bloqueo, aturdido } (Snow.strike)
local HIT_TOUCH  = { 1, 520, -420, 0.2, 0 }
local HIT_WAVE   = { 1, 620, -520, 0.25, 0.3 }
local DEATH = { dying_pop = true }
MG.HOP_GAP, MG.FLOP_EVERY, MG.DAZE_T, MG.WAVE_LIFE = HOP_GAP, FLOP_EVERY, DAZE_T, WAVE_LIFE

-- Cuadros de body-Sheet.png
local F_IDLE, F_WALK1, F_WALK2, F_JUMP, F_DAZED, F_HURT, F_LAUGH, F_SHOUT = 1, 2, 3, 4, 5, 6, 7, 8

-- ── Arte ──────────────────────────────────────────────────────────────────────
local body, crownImg, waveS, starsS, targetS, shadowImg
function MG.loadAssets()
    if body then return end
    local D = 'assets/images/bosses/megagummy/'
    body      = SpriteStrip.load(D .. 'body-Sheet.png', 16)
    crownImg  = SpriteStrip.load(D .. 'crown.png', 16)
    waveS     = SpriteStrip.load(D .. 'wave-Sheet.png', 12)
    starsS    = SpriteStrip.load(D .. 'stars-Sheet.png', 5)
    targetS   = SpriteStrip.load(D .. 'target-Sheet.png', 16)
    shadowImg = SpriteStrip.load(D .. 'shadow.png', 16)
end
function MG.sizePx() return 16 * MS, 16 * MS end

local function rand(a, b) return a + math.random() * (b - a) end
local overlap = Boss.overlap

function MG:feetY() return self.y + self.outerH / 2 end

function MG:initBoss()
    self.y = self.row * T - self.outerH / 2          -- (de pie en el suelo de su celda)
    self.phase = 1
    self.vx, self.vy, self.onGround = 0, 0, true
    self.facing = -1
    self.landX, self.landY = math.floor(self.x), math.floor(self:feetY())
    self.waves, self.nextId = {}, 0
    self.parts = {}
    self.splitX, self.splitY, self.crownX, self.crownY = 0, 0, 0, 0
    self.flopT, self.summonT, self.hopT, self.graceT = 0, 0, 0, 0
    self.flopsLeft = 0
    self.marks = {}
    self.summonKey = 'mg' .. self.col .. ',' .. self.row
end

-- Vida: el cuerpo + lo de los trozos (hp ≤ splitHp → se divide)
function MG:splitHp() return math.max(1, math.floor(self.props.splitCount or 3)) * math.max(1, math.floor(self.props.partHp or 2)) end
function MG:phase2Hp()
    local s = self:splitHp()
    return s + (self.hpMax - s) * (self.props.phase2 or 0.5)
end

function MG:onFightStart(n)
    local s = self:splitHp()
    if self.hpMax < s + 2 then self.hpMax = s + 2; self.hp = self.hpMax end
    self:enter('chase')
end

function MG:bossPhase() return self.phase or 1 end
function MG:enter(st)
    self.state, self.deadTimer = st, 0
    if st ~= 'flop_air' then self.passY = nil end
end

-- ── Golpes a los jugadores ────────────────────────────────────────────────────
-- ¿Le cae encima? (los pies en la parte de arriba: entonces decide interact, no el contacto)
local function onTop(pa, box)
    local pob = pa:getOuterBounds()
    return pob.y + pob.h < box.y + box.h * 0.35 + 10
end

-- Contacto con una caja (cuerpo o trozo): 1 de vida y empujón. true si dio a alguien.
function MG:touch(level, box, cx)
    local hitAny = false
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false and not pa:isInvulnerable() and overlap(pa:getOuterBounds(), box)
           and not onTop(pa, box) then
            if strike(pa, HIT_TOUCH, (pa.x >= cx) and 1 or -1) then hitAny = true end
        end
    end
    return hitAny
end

-- Aterriza de un panzazo encima de alguien: 2 de vida y aplastado
function MG:crush(level)
    local ob = self:getOuterBounds()
    local box = { x = ob.x - 4, y = ob.y - 4, w = ob.w + 8, h = ob.h + 8 }
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false and not pa:isInvulnerable() and overlap(pa:getOuterBounds(), box) then
            local dir = (pa.x >= self.x) and 1 or -1
            Boss.withPlayer(pa, function()
                pa:hurt(2)
                if not pa.dying then pa:squash(dir) end
            end)
        end
    end
end

-- ── Olas de gelatina ─────────────────────────────────────────────────────────
function MG:spawnWaves(level)
    local fy = math.floor(self:feetY())
    for _, d in ipairs({ -1, 1 }) do
        self.nextId = self.nextId % 999 + 1
        self.waves[#self.waves + 1] = { id = self.nextId, x = math.floor(self.x + d * (self.outerW / 2 - 10)),
                                        y = fy, dir = d, t = 0, hit = {} }
    end
    Sound.play('kingWave')
end

function MG:waveBox(w) return { x = w.x - WAVE_W / 2, y = w.y - WAVE_H, w = WAVE_W, h = WAVE_H } end

function MG:updateWaves(level, dt)
    local zx0, zx1 = self:zoneBounds()
    for i = #self.waves, 1, -1 do
        local w = self.waves[i]
        w.t = w.t + dt
        w.x = w.x + w.dir * WAVE_SPD * dt
        local ahead = w.x + w.dir * WAVE_W / 2
        local gone = w.t >= WAVE_LIFE or ahead < zx0 or ahead > zx1
            or level:entitySolidAt(ahead, w.y - 12)                       -- (pared o escalón)
            or not level:collisionAt(w.x, w.y + 6, true)                  -- (se acaba el suelo)
        if gone then
            table.remove(self.waves, i)
        else
            local box = self:waveBox(w)
            for _, pa in ipairs(level.players or {}) do
                if not w.hit[pa] and overlap(pa:getOuterBounds(), box) and strike(pa, HIT_WAVE, w.dir) then
                    w.hit[pa] = true
                end
            end
        end
    end
end

-- ── Panzazo ───────────────────────────────────────────────────────────────────
-- Dónde caería sobre `pa`: su x (dentro de la zona) y la primera superficie bajo sus pies
function MG:aimAt(level, pa)
    local zx0, zx1, _, zy1 = self:zoneBounds()
    local hw = self.outerW / 2
    local tx = pa and pa.x or self.x
    tx = math.max(zx0 + hw, math.min(zx1 - hw, tx))
    local y0 = pa and (pa:getOuterBounds().y + pa:getOuterBounds().h - 6) or self:feetY() - 6
    local top
    for _, px in ipairs({ tx - hw + 6, tx, tx + hw - 6 }) do
        local _, t = level:landingCross(px, y0, zy1 + T)
        if t and (not top or t < top) then top = t end
    end
    return math.floor(tx), math.floor(top or zy1)
end

function MG:startFlop(level)
    self.flopsLeft = (self.flopsLeft > 0) and self.flopsLeft or FLOP_CHAIN[self.phase]
    self.landX, self.landY = self:aimAt(level, self:target(level))
    self.vx = 0
    self:enter('flop_wind')
    Sound.play('kingCharge')
end

function MG:landFlop(level)
    self.vx, self.vy = 0, 0
    Sound.play('kingFlop')
    Entity.emitFx('king_splat', self.x, self:feetY())
    Entity.emitFx('shake_big', self.x, self.y)
    self:crush(level)
    self:spawnWaves(level)
    self.flopsLeft = self.flopsLeft - 1
    if self.flopsLeft > 0 then self:enter('flop_land')
    else
        self:enter('dazed')
        Sound.play('stunned')
    end
end

-- ── Guardia real (súbditos de reserva) ───────────────────────────────────────
function MG:minions(level)
    local out = {}
    for _, e in ipairs(level.liveEntities or {}) do
        if e.summonOf == self.summonKey then out[#out + 1] = e end
    end
    return out
end

function MG:summonable(level)
    local p = self.props
    local free, active = {}, 0
    for _, e in ipairs(self:minions(level)) do
        if e.alive then active = active + 1 else free[#free + 1] = e end
    end
    return math.min(#free, p.guardCount or 2, math.max(0, (p.guardMax or 3) - active)), free
end

-- POR DÓNDE ENTRA cada guardia (antes siempre por los dos lados: demasiado previsible). Según
-- la clase de Gummy, por cualquier sitio válido de la arena:
--   1 SUELO   brota del suelo o de una plataforma (cualquier celda donde quepa de pie)
--   2 LADO    aparece junto a una pared de la zona, en el suelo o en una plataforma
--   3 CIELO   baja del techo en PARACAÍDAS hasta lo primero que haya debajo
--   4 AIRE    los voladores: aparecen en el aire, en la mitad de arriba (y luego vuelo libre)
-- Cada sitio se elige al EMPEZAR la llamada y se MARCA (self.marks, en netPackExtra) hasta que
-- el guardia sale — el del paracaídas, hasta que se posa —: nadie muere sin haberlo visto venir.
-- Un sitio vale si no pisa a un jugador (≥ GUARD_FAR casillas), al jefe, a otra marca ni a otro
-- guardia vivo; si no hay ninguno de una clase, prueba las otras y, al final, el lado de siempre.
local GUARD_FAR, GUARD_GAP = 2.5, 1.5            -- casillas: de un jugador / entre guardias
local K_FLOOR, K_SIDE, K_SKY, K_AIR = 1, 2, 3, 4
local WALK_ENTRIES = { K_FLOOR, K_SKY, K_SIDE }

function MG:spotFree(level, x, y, far)
    for _, pa in ipairs(level.players or {}) do
        if pa.alive ~= false and (pa.x - x) ^ 2 + (pa.y - y) ^ 2 < (far * T) ^ 2 then return false end
    end
    if math.abs(x - self.x) < self.outerW / 2 + T and y > self.y - self.outerH / 2 - T then return false end
    for _, m in ipairs(self.marks) do
        if (m.x - x) ^ 2 + (m.y - y) ^ 2 < (GUARD_GAP * T) ^ 2 then return false end
    end
    for _, e in ipairs(self:minions(level)) do
        if e.alive and (e.x - x) ^ 2 + (e.y - y) ^ 2 < (GUARD_GAP * T) ^ 2 then return false end
    end
    return true
end

-- Sitio para un guardia de la clase `kind`: x, y (la superficie; en el aire, el centro) o nil
function MG:guardSpot(level, e, kind)
    local zx0, zx1, zy0, zy1 = self:zoneBounds()
    local c0, c1 = math.floor(zx0 / T) + 1, math.floor((zx1 - 1) / T) + 1
    local r0, r1 = math.floor(zy0 / T) + 2, math.floor((zy1 - 1) / T) + 1
    for _ = 1, 30 do
        if kind == K_AIR then
            local FF = require 'src/world/entities/FreeFlight'
            local a = { x0 = zx0, y0 = zy0, x1 = zx1, y1 = zy1 }
            local x = zx0 + T + math.random() * (zx1 - zx0 - 2 * T)
            local y = zy0 + T + math.random() * (zy1 - zy0) * 0.45
            if FF.fits(e, level, x, y, a) and self:spotFree(level, x, y, GUARD_FAR + 0.5) then return math.floor(x), math.floor(y) end
        elseif kind == K_SKY then
            local x = zx0 + T + math.random() * (zx1 - zx0 - 2 * T)
            local top = zy0 + T * 0.5
            local okCol = true
            for _, px in ipairs({ x - e.outerW / 2, x, x + e.outerW / 2 }) do
                if level:entitySolidAt(px, top, e) or level:entitySolidAt(px, top + e.outerH, e) then okCol = false end
            end
            -- (lo primero que toque CUALQUIER parte de su caja: el borde de una plataforma también)
            local land
            for _, px in ipairs({ x - e.outerW / 2 + 4, x, x + e.outerW / 2 - 4 }) do
                local _, t2 = level:landingCross(px, top + e.outerH, zy1 + T)
                if t2 and (not land or t2 < land) then land = t2 end
            end
            land = land or zy1
            if okCol and land - top > 3 * T and level:isStandable(math.floor(x / T) + 1, math.floor((land - 2) / T) + 1)
               and self:spotFree(level, x, land - e.outerH / 2, GUARD_FAR - 0.5) then
                return math.floor(x), math.floor(land)
            end
        else
            local c = math.random(c0, c1)
            if kind == K_SIDE then c = (math.random() < 0.5) and c0 or c1 end
            local r = math.random(r0, r1)
            if level:isStandable(c, r) then
                local x, y = (c - 0.5) * T, r * T
                if kind == K_SIDE then x = (c == c0) and (zx0 + T * 0.8) or (zx1 - T * 0.8) end
                if self:spotFree(level, x, y - e.outerH / 2, GUARD_FAR) then return math.floor(x), math.floor(y) end
            end
        end
    end
    return nil
end

-- Elige y marca por dónde entrará cada guardia de esta llamada
function MG:planGuards(level)
    local n, free = self:summonable(level)
    self.marks = self.marks or {}
    self.guardTurn = self.guardTurn or 0
    local zx0, zx1, _, zy1 = self:zoneBounds()
    for i = 1, n do
        local e = free[i]
        local tries = { K_AIR }
        if not e.flying then
            self.guardTurn = self.guardTurn + 1
            tries = {}
            for k = 0, 2 do tries[#tries + 1] = WALK_ENTRIES[(self.guardTurn + k - 1) % 3 + 1] end
        end
        local x, y, kind
        for _, k in ipairs(tries) do
            x, y = self:guardSpot(level, e, k)
            if x then kind = k; break end
        end
        if not x then                                    -- (sin sitio: por un lado, como antes)
            local side = (self.guardTurn % 2 == 0) and -1 or 1
            x = (side < 0) and (zx0 + T * 0.8) or (zx1 - T * 0.8)
            local _, top = level:landingCross(x, zy1 - 2 * T, zy1 + T)
            y, kind = math.floor(top or zy1), K_SIDE
            if e.flying then y, kind = y - 3 * T, K_AIR end
        end
        self.marks[#self.marks + 1] = { x = x, y = y, kind = kind, e = e }
    end
end

-- Salen por sus marcas, mirando hacia el centro de la zona
function MG:summonGuards(level)
    local pending = false
    for _, m in ipairs(self.marks or {}) do if m.e and not m.out then pending = true end end
    if not pending then self:planGuards(level) end
    local zx0, zx1, zy0, zy1 = self:zoneBounds()
    local any = false
    for i = #self.marks, 1, -1 do
        local m = self.marks[i]
        local e = m.e
        if e and not m.out then
            m.out, any = true, true
            local dir = (m.x < (zx0 + zx1) / 2) and 1 or -1
            local h = e.home
            local y = (m.kind == K_AIR) and m.y or (m.y - e.outerH / 2)
            if m.kind == K_SKY then y = zy0 + T * 0.5 + e.outerH / 2 end
            h.x, h.y, h.facing, h.flipped, h.state = m.x, y, dir, false, 'walk'
            h.vx = e.speed * dir
            e:resetToHome()
            e.leftBoundPx, e.rightBoundPx = zx0, zx1
            if e.flying then
                e.freeFly, e.flyArea = true, { x0 = zx0, y0 = zy0, x1 = zx1, y1 = zy1 }
            end
            if m.kind == K_SKY then
                e:startParachute()                        -- (la marca sigue hasta que se pose)
            else
                e.state, e.deadTimer = 'spawning', 0
                table.remove(self.marks, i)
                if m.kind == K_FLOOR then Entity.emitFx('gp_land', m.x, m.y) end
            end
            Entity.emitFx('spawn', m.x, y)
            Entity.emitFx('king_sparkle', m.x, y)
        end
    end
    if any then Sound.play('respawnFx', 0.9) end
end

-- Las marcas de los paracaidistas se quitan al posarse (o si mueren en el aire)
function MG:updateMarks()
    if self.state == 'dead' or self.state:sub(1, 6) == 'dying_' then self.marks = {}; return end
    for i = #(self.marks or {}), 1, -1 do
        local m = self.marks[i]
        if m.out and (not m.e or not m.e.alive or m.e.state ~= 'para') then table.remove(self.marks, i) end
    end
end

-- ── Se divide ─────────────────────────────────────────────────────────────────
-- Trozo = caja propia con la física de la bola (Snow.move/physics) dentro de la zona
local Part = {}
Part.__index = Part
Part.move, Part.physics, Part.friction, Part.groundDecel = Snow.move, Snow.physics, Snow.friction, Snow.groundDecel
function Part:zoneBounds() return self.boss:zoneBounds() end
function Part:feetY() return self.y + self.outerH / 2 end
function Part:box() return { x = self.x - self.outerW / 2, y = self.y - self.outerH / 2, w = self.outerW, h = self.outerH } end
function Part:innerBox()
    local w, h = 11 * PS, 12 * PS
    return { x = self.x - w / 2, y = self.y + self.outerH / 2 - h, w = w, h = h }
end
local function newPart(boss, x, y)
    return setmetatable({ boss = boss, x = x, y = y, vx = 0, vy = 0, outerW = 12 * PS, outerH = 13 * PS,
                          hp = 0, inv = 0, st = 2, facing = 1, wait = 0, onGround = false }, Part)
end
MG.newPart = newPart

-- Dónde cae la corona (en el suelo, al lado contrario del jugador más cercano)
function MG:startSplit(level)
    local zx0, zx1, _, zy1 = self:zoneBounds()
    self.vx, self.vy = 0, 0
    self.waves = {}
    self.splitX, self.splitY = math.floor(self.x), math.floor(self:feetY())
    local pa = self:target(level)
    local dir = (pa and pa.x > self.x) and -1 or 1
    local cx = math.max(zx0 + T, math.min(zx1 - T, self.x + dir * 3 * T))
    local _, top = level:landingCross(cx, self.y, zy1 + T)
    self.crownX, self.crownY = math.floor(cx), math.floor(top or zy1)
    self.phase = 3
    self:enter('split')
    Sound.play('kingHurt', 0.8)
end

function MG:burst(level)
    local n = math.max(1, math.floor(self.props.splitCount or 3))
    local hp = math.max(1, math.floor(self.props.partHp or 2))
    self.parts = {}
    for i = 1, n do
        local k = (n == 1) and 0 or ((i - 1) / (n - 1) * 2 - 1)        -- -1 .. 1
        local p = newPart(self, self.x + k * 30, self.y)
        p.vx, p.vy = k * 380, (k == 0) and -1100 or -880
        p.hp, p.facing = hp, (k < 0) and -1 or 1
        p.wait = PART_WAIT[(n <= 2) and 1 or 2] + i * 0.15
        self.parts[i] = p
    end
    self.hp = n * hp
    self:enter('parts')
    Sound.play('kingSplit')
    Entity.emitFx('king_splat', self.x, self:feetY())
    Entity.emitFx('king_confetti', self.x, self.y)
    Entity.emitFx('shake_big', self.x, self.y)
end

function MG:aliveParts()
    local n = 0
    for _, p in ipairs(self.parts or {}) do if p.st ~= 0 then n = n + 1 end end
    return n
end

function MG:updateParts(level, dt)
    local wait = PART_WAIT[(#self.parts <= 2) and 1 or 2]
    local sx, sy, n = 0, 0, 0
    for _, p in ipairs(self.parts) do
        if p.st ~= 0 then
            if p.inv > 0 then p.inv = math.max(0, p.inv - dt) end
            local was = p.onGround
            p:physics(level, dt)
            if p.onGround then
                if not was then
                    p.vx = 0
                    Entity.emitFx('gp_land', p.x, p:feetY())
                end
                p.st = 1
                p:friction(level, dt)
                p.wait = p.wait - dt
                if p.wait <= 0 then
                    local pa = self.target(p, level)
                    local dir = (pa and pa.x < p.x) and -1 or 1
                    p.facing = dir
                    p.vx, p.vy = dir * rand(180, 300), -rand(700, 900)
                    p.onGround, p.st = false, 2
                    p.wait = wait * rand(0.8, 1.25)
                    Sound.play('kingHop', 1.35)
                end
            else
                p.st = 2
            end
            self:touch(level, p:box(), p.x)
            sx, sy, n = sx + p.x, sy + p.y, n + 1
        end
    end
    -- (el jefe "está" donde están sus trozos: cámara, sonido)
    if n > 0 then self.x, self.y = sx / n, sy / n end
end

function MG:hitPart(i, n)
    local p = self.parts and self.parts[i]
    if not p or p.st == 0 or p.inv > 0 then return false end
    n = math.min(n, p.hp)
    p.hp = p.hp - n
    self.hp = math.max(0, self.hp - n)
    Sound.play('kingHurt', 1.4)
    Entity.emitFx('boss_hit', p.x, p.y)
    if p.hp <= 0 then
        p.st = 0
        Sound.play('kingPop')
        Entity.emitFx('king_confetti', p.x, p.y)
        if self:aliveParts() == 0 then
            self.x, self.y = p.x, p.y
            self:defeat()
        end
    else
        p.inv = PART_INV
    end
    return true
end

-- ── Interacción ───────────────────────────────────────────────────────────────
local SPLIT = { split = true, parts = true }
function MG:isActive() return Boss.isActive(self) and not DEATH[self.state] end
function MG:isDying() return DEATH[self.state] == true or Boss.isDying(self) end
function MG:isVulnerable() return self:isActive() and self.state == 'dazed' end
function MG:releasesZone() return self.state == 'dying_pop' or self.state == 'dead' end
function MG:isSolidBody() return Boss.isSolidBody(self) and not SPLIT[self.state] and not DEATH[self.state] end
function MG:canBeKnocked() return false end

-- Sin efectos (el cliente lo usa para predecir): con trozos, el trozo que toca (apunta cuál en
-- _hitPart para el stomp/pound que viene justo después)
function MG:interact(pa)
    if self.state == 'split' then return nil end
    if self.state ~= 'parts' then return Boss.interact(self, pa) end
    local pob = pa:getOuterBounds()
    local bvy = -math.abs(ADV_JUMP_VEL) * self.BOUNCE
    for i, p in ipairs(self.parts) do
        if p.st ~= 0 then
            local ob = p:box()
            if overlap(pob, p:innerBox()) then
                local side = (pa.x >= p.x) and 1 or -1
                local top = pob.y + pob.h * 0.5 < ob.y + ob.h * 0.5
                if pa.gpPhase == 'fall' and top then
                    self._hitPart = i
                    if p.inv > 0 then return 'bounce', bvy, side end
                    return 'pound', bvy, 0
                end
                if (pa.vy or 0) > 0 and pob.y + pob.h < ob.y + ob.h * 0.35 + 10 then
                    self._hitPart = i
                    if p.inv > 0 then return 'bounce', bvy, side end
                    return 'stomp', bvy, 0
                end
            end
        end
    end
    return nil
end

function MG:stomp()
    if self.state == 'parts' then self:hitPart(self._hitPart, 1); return end
    Boss.stomp(self)
end
function MG:pound(pa)
    if self.state == 'parts' then self:hitPart(self._hitPart, 2); return end
    self:damage(2, 'pound')
end

-- El cuerpo nunca baja de la vida de los trozos (el sobrante no se pierde)
function MG:damage(n, kind)
    if not SPLIT[self.state] then n = math.min(n or 1, math.max(1, self.hp - self:splitHp())) end
    return Boss.damage(self, n, kind)
end

function MG:onDamaged(n, kind)
    if self:isDying() then return end
    self.vx = 0
    if self.hp <= self:splitHp() then
        self.inv, self.ghost = 0, false
        self:startSplit(self.levelRef or {})
    elseif self.phase == 1 and self.hp <= self:phase2Hp() then
        self:enter('phase_up')
    else
        self:enter('recover')
    end
end

-- Derrotado: revienta en confeti y la corona da un último bote (los guardias se van con él)
function MG:defeat()
    self.hp, self.inv, self.ghost = 0, 0, false
    self.waves = {}
    self.vx, self.vy = 0, 0
    self:enter('dying_pop')
    Sound.play('kingPop', 0.8)
    Sound.play('kingCrown', 0.9)
    Entity.emitFx('king_confetti_big', self.x, self.y)
    Entity.emitFx('shake_big', self.x, self.y)
    local level = self.levelRef
    for _, e in ipairs(level and self:minions(level) or {}) do
        if e.alive and e.state ~= 'dead' then
            e.state, e.deadTimer, e.vx, e.vy = 'dead', 0, 0, 0
            Entity.emitFx('king_confetti', e.x, e.y)
        end
    end
    self:onDefeat()
end

-- (NO se ríe cuando muere un jugador: eso es cosa del Espejo. Solo su risa de la entrada)

-- ── Update ────────────────────────────────────────────────────────────────────
function MG:updateBoss(dt, level)
    if self.state == 'dormant' then return end
    self.levelRef = self.levelRef or level
    self.deadTimer = self.deadTimer + dt
    if self.graceT > 0 then self.graceT = math.max(0, self.graceT - dt) end
    self:updateWaves(level, dt)
    self:updateMarks()
    local st, t = self.state, self.deadTimer
    local ph = math.min(2, self.phase)

    if st == 'fight' then self:enter('chase'); return end

    if st == 'chase' then
        local was = self.onGround
        self:physics(level, dt)
        if self.onGround then
            if not was then
                self.vx = 0
                Entity.emitFx('gp_land', self.x, self:feetY())
            end
            self:friction(level, dt)
            self.hopT = self.hopT + dt
        end
        self.flopT = self.flopT + dt
        if self.phase >= 2 then self.summonT = self.summonT + dt end
        if self.onGround then
            if self.phase >= 2 and self.summonT >= (self.props.guardEvery or 9) and self:summonable(level) > 0 then
                self.summonT = 0
                self:enter('summon')
            elseif self.flopT >= FLOP_EVERY[ph] then
                self.flopT = 0
                self:startFlop(level)
            elseif self.hopT >= HOP_GAP[ph] then
                self.hopT = 0
                local pa = self:target(level)
                local dir = (pa and pa.x < self.x) and -1 or 1
                self.facing = dir
                self.vx, self.vy, self.onGround = dir * HOP_VX[ph], -HOP_VY, false
                Sound.play('kingHop')
            end
        end
        if self.graceT <= 0 and self:touch(level, self:getOuterBounds(), self.x) then self.graceT = GRACE end

    elseif st == 'flop_wind' then
        self:physics(level, dt); self:friction(level, dt)
        if t < FLOP_WIND[ph] - FLOP_LOCK then self.landX, self.landY = self:aimAt(level, self:target(level)) end
        self.facing = (self.landX >= self.x) and 1 or -1
        if t >= FLOP_WIND[ph] then
            self.passY = self.landY
            self:jumpTo(self.landX, self.landY, FLOP_UP[ph])
            self:enter('flop_air')
            self.passY = self.landY
            Sound.play('kingJump')
        end

    elseif st == 'flop_air' then
        self:physics(level, dt)
        if self.onGround and self.vy >= 0 and t > 0.1 then self:landFlop(level) end

    elseif st == 'flop_land' then
        self:physics(level, dt)
        if t >= FLOP_LAND then self:startFlop(level) end

    elseif st == 'dazed' then
        self:physics(level, dt); self:friction(level, dt)
        if t >= DAZE_T[ph] then self:enter('recover') end

    elseif st == 'recover' then
        self:physics(level, dt); self:friction(level, dt)
        if t >= RECOVER_T then
            self.flopT, self.hopT = 0, 0
            self:enter('chase')
        end

    elseif st == 'summon' or st == 'phase_up' then
        self:physics(level, dt); self:friction(level, dt)
        local len = (st == 'summon') and SUMMON_T or PHASE_T
        if not self.planned then self.planned = true; self:planGuards(level) end     -- (marcas: desde ya)
        if t >= FANFARE_AT and not self.tooted then
            self.tooted = true
            Sound.play('kingFanfare')
            Entity.emitFx('king_sparkle', self.x, self:feetY() - 15 * MS)
            if st == 'phase_up' then Entity.emitFx('shake_roar', self.x, self.y) end
        end
        if t >= SUMMON_AT and not self.called then
            self.called = true
            self:summonGuards(level)
        end
        if t >= len then
            self.tooted, self.called, self.planned = nil, nil, nil
            if st == 'phase_up' then self.phase, self.summonT = 2, 0 end
            self.flopT, self.hopT = 0, 0
            self:enter('chase')
        end

    elseif st == 'split' then
        if t >= CROWN_AT and not self.crownOff then
            self.crownOff = true
            Sound.play('kingCrown')
        end
        if t >= SPLIT_T then self:burst(level) end

    elseif st == 'parts' then
        self:updateParts(level, dt)

    elseif st == 'dying_pop' then
        if t >= 0.3 and not self.crownHop then
            self.crownHop = true
            Sound.play('kingCrown', 1.2)
        end
        if t >= POP_T then self.state, self.alive = 'dead', false end
    end
end

-- ── Entrada (genérica de Boss): cae de panza del cielo, se levanta, fanfarria y risa ─────
local FALL_AT, LAND_AT, TOOT_AT, LAUGH_AT = 0.5, 1.1, 1.8, 2.6
MG.LAND_AT = LAND_AT
function MG:introFocus()
    local zx0, zx1, zy0, zy1 = self:zoneBounds()
    return (zx0 + zx1) / 2, (zy0 + zy1) / 2
end
function MG:onIntroStart(level, players)
    self.introStep = 0
    self.levelRef = self.levelRef or level
end
function MG:updateIntro(dt, level, t)
    local hx, hy = self.home.x, self.home.y
    local _, _, zy0 = self:zoneBounds()
    self.x = hx
    if t < LAND_AT then
        local y0 = zy0 - self.outerH
        local u = math.max(0, (t - FALL_AT) / (LAND_AT - FALL_AT))
        self.y = (t < FALL_AT) and y0 or (y0 + (hy - y0) * u * u)
        if t >= FALL_AT and self.introStep < 1 then self.introStep = 1; Sound.play('kingJump', 0.7) end
        return
    end
    self.y = hy
    if self.introStep < 2 then
        self.introStep = 2
        Sound.play('kingLand')
        Entity.emitFx('king_splat', self.x, self:feetY())
        Entity.emitFx('shake_big', self.x, self.y)
    end
    if t >= TOOT_AT and self.introStep < 3 then
        self.introStep = 3
        Sound.play('kingFanfare')
        Entity.emitFx('king_sparkle', self.x, self:feetY() - 15 * MS)
    end
    if t >= LAUGH_AT and self.introStep < 4 then self.introStep = 4; Sound.play('kingLaugh') end
end

-- ── Red ───────────────────────────────────────────────────────────────────────
-- { fase, marca x, y, división x, y, corona x, y, nOlas, {id, x, y, dir, t·100}…,
--   nTrozos, {x, y, vida, inv·100, estado, mira}…, nMarcas, {x, y, clase}… }
local NB = 7
function MG:netPackExtra()
    local out = { self.phase, self.landX or 0, self.landY or 0, self.splitX, self.splitY, self.crownX, self.crownY,
                  #self.waves }
    for _, w in ipairs(self.waves) do
        out[#out + 1] = w.id; out[#out + 1] = math.floor(w.x); out[#out + 1] = w.y
        out[#out + 1] = w.dir; out[#out + 1] = math.floor(w.t * 100)
    end
    out[#out + 1] = #self.parts
    for _, p in ipairs(self.parts) do
        out[#out + 1] = math.floor(p.x); out[#out + 1] = math.floor(p.y); out[#out + 1] = p.hp
        out[#out + 1] = math.floor(p.inv * 100); out[#out + 1] = p.st; out[#out + 1] = p.facing
    end
    out[#out + 1] = #self.marks                            -- marcas de la guardia: x, y, clase
    for _, m in ipairs(self.marks) do
        out[#out + 1] = m.x; out[#out + 1] = m.y; out[#out + 1] = m.kind
    end
    return out
end

local function readList(b, k, stride)
    local n = b[k] or 0
    local list = {}
    for i = 0, n - 1 do
        local e = {}
        for j = 1, stride do e[j] = b[k + 1 + i * stride + j - 1] end
        list[#list + 1] = e
    end
    return list, k + 1 + n * stride
end

function MG:netApplyExtra(a, b, f)
    if type(b[1]) ~= 'number' then return end
    self.phase, self.landX, self.landY = b[1], b[2], b[3]
    self.splitX, self.splitY, self.crownX, self.crownY = b[4], b[5], b[6], b[7]
    local wb, k = readList(b, NB + 1, 5)
    local hasA = type(a[NB + 1]) == 'number'
    local wa, ka = {}, nil
    if hasA then wa, ka = readList(a, NB + 1, 5) end
    local prev = {}
    for _, e in ipairs(wa) do if e[1] then prev[e[1]] = e end end
    self.waves = {}
    for _, e in ipairs(wb) do
        local x = e[2]
        local o = prev[e[1]]
        if o and type(o[2]) == 'number' then x = o[2] + (x - o[2]) * f end
        self.waves[#self.waves + 1] = { id = e[1], x = x, y = e[3], dir = e[4], t = e[5] / 100, hit = {} }
    end
    local pb, km = readList(b, k, 6)
    self.marks = {}
    for _, e in ipairs(readList(b, km, 3)) do self.marks[#self.marks + 1] = { x = e[1], y = e[2], kind = e[3] } end
    local pa = ka and readList(a, ka, 6) or {}
    local parts = {}
    for i, e in ipairs(pb) do
        local p = self.parts[i] or newPart(self, e[1], e[2])
        local x, y = e[1], e[2]
        local o = pa[i]
        if o and type(o[1]) == 'number' and type(o[2]) == 'number' then x, y = o[1] + (x - o[1]) * f, o[2] + (y - o[2]) * f end
        p.x, p.y, p.hp, p.inv, p.st, p.facing = x, y, e[3], e[4] / 100, e[5], e[6]
        parts[i] = p
    end
    self.parts = parts
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
local Particles
local function emit(kind, x, y, o)
    Particles = Particles or require 'src/fx/Particles'
    Particles.emit(kind, x, y, o)
end

-- Pose del cuerpo: cuadro, estirar x/y, tumbado (girado 90°), temblor, ¿se ve?
function MG:pose()
    local st, t = self.state, self.deadTimer or 0
    local now = love.timer.getTime()
    local ph = math.min(2, self.phase or 1)
    if st == 'dormant' then return F_IDLE, 1, 1, false, 0, EDITOR_VIEW == true end
    if st == 'intro' or st == 'ready' then
        local it = (st == 'ready') and (MG.introLength + t) or t
        if it < FALL_AT then return F_JUMP, 1, 1, false, 0, false end
        if it < LAND_AT then return F_JUMP, 0.92, 1.12, false, 0, true end
        local u = it - LAND_AT
        if u < 0.5 then return F_HURT, 1 + 0.25 * (1 - u / 0.5), 1 - 0.3 * (1 - u / 0.5), false, 0, true end
        if it < TOOT_AT then return F_IDLE, 1, 1, false, 0, true end
        if it < LAUGH_AT then return F_SHOUT, 1, 1.06, false, 0, true end
        local b = math.abs(math.sin(it * 14)) * 0.05
        return F_LAUGH, 1 + b, 1 - b, false, 0, true
    end
    if st == 'chase' then
        if not self.onGround then return F_JUMP, 0.94, 1.08, false, 0, true end
        local u = math.min(1, (self.hopT or 0) / HOP_GAP[ph])
        local sq = (u > 0.7) and (u - 0.7) / 0.3 * 0.12 or 0           -- (se agacha antes del salto)
        return (math.floor(now * 6) % 2 == 0) and F_WALK1 or F_WALK2, 1 + sq, 1 - sq, false, 0, true
    end
    if st == 'flop_wind' then
        local k = math.min(1, t / FLOP_WIND[ph])
        return F_IDLE, 1 + 0.22 * k, 1 - 0.28 * k, false, 1 + math.floor(k * 2), true
    end
    if st == 'flop_air' then
        if (self.vy or 0) < 0 then return F_JUMP, 0.9, 1.14, false, 0, true end
        return F_JUMP, 1, 1, true, 0, true                                   -- (cae de barriga)
    end
    if st == 'flop_land' then return F_DAZED, 1.06, 0.9, true, 0, true end
    if st == 'dazed' then
        local w = math.sin(now * 6) * 0.04
        return F_DAZED, 1 + w, 1 - w, false, 0, true
    end
    if st == 'recover' then
        if self.inv > 0 and not self.ghost then return F_HURT, 1, 1, false, 0, true end
        return F_IDLE, 1, 1, false, 0, true
    end
    if st == 'summon' or st == 'phase_up' then
        if t >= FANFARE_AT and t < SUMMON_AT + 0.4 then return F_SHOUT, 0.97, 1.07, false, (st == 'phase_up') and 2 or 0, true end
        return F_IDLE, 1, 1, false, 0, true
    end
    if st == 'split' then
        local k = math.min(1, t / SPLIT_T)
        local w = math.sin(now * 40) * 0.16 * k
        return F_HURT, 1 + w, 1 - w, false, 1 + math.floor(k * 3), true
    end
    return F_IDLE, 1, 1, false, 0, not (st == 'parts' or DEATH[st] or st == 'dead')
end

-- Cuerpo (y corona encima, en la misma rejilla) con los pies en (fx, fy)
local function drawGummy(fr, fx, fy, sc, facing, sx, sy, crown)
    love.graphics.draw(body.image, body.quads[fr], fx, fy, 0, sc * facing * sx, sc * sy, 7.5, 16)
    if crown then love.graphics.draw(crownImg.image, crownImg.quads[1], fx, fy, 0, sc * facing * sx, sc * sy, 7.5, 16) end
end

-- Corona suelta: volando (división), en el suelo (trozos) y su último bote (muerte)
function MG:crownPos()
    local st, t = self.state, self.deadTimer or 0
    if st == 'split' then
        if t < CROWN_AT then return nil end
        local u = math.min(1, (t - CROWN_AT) / CROWN_T)
        local x0, y0 = self.splitX, self.splitY - 15 * MS
        local x = x0 + (self.crownX - x0) * u
        local y = y0 + (self.crownY - y0) * u - math.sin(u * math.pi) * 3 * T
        return x, y, u * 9, 1
    elseif st == 'parts' then
        return self.crownX, self.crownY, 0.5, 1
    elseif st == 'dying_pop' then
        local u = math.max(0, t - 0.3)
        local hop = math.max(0, u * 900 - 0.5 * 2200 * u * u)
        return self.crownX, self.crownY - hop, 0.5 + u * 6, math.max(0, 1 - math.max(0, t - 1.6) / (POP_T - 1.6))
    end
    return nil
end

function MG:render(camX, camY)
    local st, t = self.state, self.deadTimer or 0
    local now = love.timer.getTime()
    local alpha = self:ghostAlpha()

    -- Marca de dónde caerá el panzazo + sombra del cuerpo en el aire
    if st == 'flop_wind' or st == 'flop_air' then
        local fr = (math.floor(now * 10) % 2) + 1
        local k = (st == 'flop_air') and 1 or math.min(1, t / FLOP_WIND[math.min(2, self.phase or 1)])
        local sc = 8
        love.graphics.setColor(1, 1, 1, 0.55 + 0.45 * k)
        targetS:draw(fr, math.floor(self.landX - camX), math.floor(self.landY - camY - 2 * sc), 0, sc, sc)
        if st == 'flop_air' then
            local gy = self:groundBelow(self.x, self:feetY())
            local d = math.max(0, gy - self:feetY())
            local w = math.max(4, math.floor(self.outerW / 16 * (1 - math.min(0.6, d / (8 * T)))))
            love.graphics.setColor(1, 1, 1, 0.25 + 0.3 * (1 - math.min(1, d / (8 * T))))
            love.graphics.draw(shadowImg.image, shadowImg.quads[1], math.floor(self.x - camX), math.floor(gy - camY - 3 * 2),
                               0, w, 2, 8, 0)
        end
    end

    -- Marcas de por dónde entra la guardia (parpadean; la del paracaídas, hasta que se posa)
    for i, m in ipairs(self.marks or {}) do
        local fr2 = (math.floor(now * 10 + i) % 2) + 1
        local sc = 4
        love.graphics.setColor(1, 0.95, 0.35, 0.65 + 0.35 * math.sin(now * 14 + i))
        targetS:draw(fr2, math.floor(m.x - camX), math.floor(m.y - camY - 2 * sc), 0, sc, sc)
        if m.kind == 4 then                               -- (en el aire: otra encima, como un aro)
            targetS:draw(fr2, math.floor(m.x - camX), math.floor(m.y - camY - 28), 0, sc, -sc)
        end
        if not EDITOR_VIEW and math.random() < 0.06 then emit('king_sparkle', m.x, m.y - 10) end
    end

    local fr, sx, sy, lying, shake, visible = self:pose()
    if visible then
        local fx = math.floor(self.x - camX)
        local fy = math.floor(self:feetY() - camY)
        if shake > 0 then
            fx = fx + math.floor((math.random() * 2 - 1) * shake + 0.5)
            fy = fy + math.floor((math.random() * 2 - 1) * shake * 0.5 + 0.5)
        end
        local r, g, b = 1, 1, 1
        if self:flashRed() then r, g, b = 1, 0.35, 0.35 end
        love.graphics.setColor(r, g, b, alpha)
        local crown = not (st == 'split' and t >= CROWN_AT)
        if lying then
            -- De barriga: girado 90° alrededor del centro del cuerpo (filas 2-15 → centro 9)
            local cy = math.floor(self.y - camY)
            local f = self.facing or 1
            love.graphics.draw(body.image, body.quads[fr], fx, cy, f * math.pi / 2, MS * sx, MS * sy, 7.5, 9)
            if crown then love.graphics.draw(crownImg.image, crownImg.quads[1], fx, cy, f * math.pi / 2, MS * sx, MS * sy, 7.5, 9) end
        else
            drawGummy(fr, fx, fy, MS, self.facing or 1, sx, sy, crown)
        end
        -- Mareado: estrellitas girando sobre la cabeza
        if st == 'dazed' then
            love.graphics.setColor(1, 1, 1, alpha)
            for i = 0, 2 do
                local a = now * 5 + i * (math.pi * 2 / 3)
                local x = math.floor(fx + math.cos(a) * 6 * MS)
                local y = math.floor(fy - 15 * MS + math.sin(a) * 1.5 * MS)
                starsS:draw((math.floor(now * 8) + i) % 2 + 1, x, y, 0, 4, 4)
            end
        end
        -- Goterones de gelatina al aterrizar / al temblar antes de dividirse
        if st == 'split' and (self.lastDrip or 0) + 0.06 < now then
            self.lastDrip = now
            emit('king_wave', self.x + rand(-1, 1) * self.outerW * 0.4, self.y + rand(-0.4, 0.4) * self.outerH,
                 { nx = (math.random() < 0.5) and -1 or 1 })
        end
    end

    -- Trozos (Gummies medianos)
    if st == 'parts' then
        for _, p in ipairs(self.parts or {}) do
            if p.st ~= 0 then
                local pfr = (p.st == 2) and F_JUMP or ((math.floor(now * 6) % 2 == 0) and F_WALK1 or F_WALK2)
                local blink = p.inv > 0 and math.floor(now * 12) % 2 == 0
                if blink then love.graphics.setColor(1, 0.35, 0.35, 1) else love.graphics.setColor(1, 1, 1, 1) end
                drawGummy(pfr, math.floor(p.x - camX), math.floor(p.y + p.outerH / 2 - camY), PS, p.facing or 1, 1, 1, false)
            end
        end
    end

    -- Corona suelta
    local cx, cy, rot, ca = self:crownPos()
    if cx then
        love.graphics.setColor(1, 1, 1, ca)
        love.graphics.draw(crownImg.image, crownImg.quads[1], math.floor(cx - camX), math.floor(cy - camY), rot, MS, MS, 7.5, 1.5)
        if (self.lastShine or 0) + 0.5 < now and ca > 0.3 then
            self.lastShine = now
            emit('king_sparkle', cx, cy)
        end
    end

    -- Olas de gelatina
    for _, w in ipairs(self.waves or {}) do
        local a = math.min(1, (WAVE_LIFE - w.t) / 0.3)
        love.graphics.setColor(1, 1, 1, a)
        waveS:draw(math.floor(now * 10) % 2 + 1, math.floor(w.x - camX), math.floor(w.y - camY - 16), 0, 4 * w.dir, 4)
        if (w.lastFx or 0) + 0.05 < now then
            w.lastFx = now
            emit('king_wave', w.x, w.y, { nx = w.dir })
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Cajas de peligro (solo para F1: los golpes los dan touch / crush / updateWaves)
function MG:getHazardBoxes()
    local out = {}
    for _, w in ipairs(self.waves or {}) do
        local b = self:waveBox(w); b.effect = 'hurt'; out[#out + 1] = b
    end
    return out
end

local G = 'Rey Gummy'
local GG = 'Guardia real'
return {
    name = 'megagummy', label = 'Rey Gummy', category = 'Jefes',
    description = 'Un Gummy gigante con corona. Persigue a saltitos; su PANZAZO (marca dónde cae) suelta olas de '
               .. 'gelatina que se saltan y lo deja MAREADO: solo entonces se le daña. En la fase 2 llama a su '
               .. 'guardia (Gummies que brotan del suelo, entran por los lados, bajan en paracaídas o vuelan libres; cada entrada se marca antes). Al final se DIVIDE en Gummies medianos: hay que acabar con todos.',
    class = MG,
    boss = { title = 'REY GUMMY' },
    hide = Boss.HIDE,
    defaults = { points = 30 },
    props = Boss.props({ hp = 12, hpPerPlayer = 4 }, {
        { key='phase2', kind='number', label='Fase 2 con vida del cuerpo ≤', group=G, default=0.5,
          min=0.1, max=0.95, step=0.05, help='Fracción de la vida del cuerpo (sin la de los trozos): más rápido, '
          .. 'dos panzazos seguidos y llama a su guardia' },
        { key='splitCount', kind='int', label='Se divide en (trozos)', group=G, default=3, min=1, max=4, step=1,
          help='Gummies medianos al final. Su vida sale de la del jefe' },
        { key='partHp', kind='int', label='Vida de cada trozo', group=G, default=2, min=1, max=6, step=1,
          help='Pisotón 1, ground pound 2' },
        { key='guardEvery', kind='number', label='Llama a la guardia cada (s)', group=GG, default=9,
          min=2, max=60, step=0.5, help='Solo en la fase 2, persiguiendo' },
        { key='guardCount', kind='int', label='Guardias por llamada', group=GG, default=2, min=0, max=4, step=1 },
        { key='guardMax', kind='int', label='Guardias a la vez (máximo)', group=GG, default=3, min=1, max=6, step=1 },
        { key='guardPool', kind='int', label='Reserva de guardias', group=GG, default=6, min=0, max=9, step=1,
          help='Gummies que el nivel prepara para él (normal, con casco y volador; reutiliza los que mueren)' },
        { key='guardSpeed', kind='number', label='Velocidad de los guardias', group=GG, default=90,
          min=20, max=300, step=10 },
    }),
    editor = { sprite = 'assets/images/bosses/megagummy/body-Sheet.png', frameW = 16 },
    -- Guardia: Gummies de reserva que el nivel crea al cargar (Level.fromData), después de las
    -- entidades del JSON (mismos índices en servidor y clientes). El jefe los activa.
    summons = function(pl)
        local p, out = pl.props or {}, {}
        for i = 1, math.max(0, math.floor(p.guardPool or 6)) do
            local kind = i % 3                        -- 1 normal, 2 casco, 0 volador
            out[#out + 1] = {
                type = 'gummy', col = pl.col, row = pl.row,
                summonKey = 'mg' .. pl.col .. ',' .. pl.row,
                props = { movement = (kind == 0) and 'fly' or 'walk', flyMode = (kind == 0) and 'free' or nil, speed = p.guardSpeed or 90,
                          helmet = (kind == 2) or nil, respawn = 0, points = 5 },
            }
        end
        return out
    end,
}
