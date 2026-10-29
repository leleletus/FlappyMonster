-- Jefe ESCARABAJO RINOCERONTE GIGANTE (types/bosses/giantbeetle.lua): el jefe de la JUNGLA (isla futura; diseño
-- aprobado por el usuario el 2026-10-28: docs/bosses/giantbeetle.md). Es el Escarabajo Rinoceronte
-- (types/enemies/beetle.lua) en grande — su MISMA hoja a escala 12 (MS), con la runa dorada de la Furia del Espejo —,
-- en un templo con una gran BALANZA (mechanisms/scale) cuyos platillos están a ras del suelo, en dos fosos.
--   · ACORAZADO: pisarlo de pie solo rebota. Solo se le puede golpear PATAS ARRIBA (pisotón 1 / ground pound 2).
--   · Cómo se le vuelca (el usuario): con él en un platillo, un ground pound en el OTRO lo DISPARA hacia arriba; se
--     estrella contra el techo (o lo que haya encima), cae PATAS ARRIBA y se queda expuesto (FLIP_T s). Y al revés:
--     cuando cae de su salto en un platillo, dispara lo del otro — al jugador — contra el techo (daño): doble filo.
--   · Ataques: EMBESTIDA con el cuerno de lado a lado (contra la pared: temblor y caen CASCOTES del techo, con su sombra
--     de aviso); LANZAR un trozo del suelo que pisa (en arco, a por ti; se rompe al caer); SALTO CON LAS
--     ALAS (zumbando; la diana marca dónde cae) y aterrizaje que suelta dos ONDAS por el suelo. Si estás en un
--     platillo, a veces salta al OTRO para dispararte.
--   · ENFADADO (por debajo de `rageAt`): más rápido, dos embestidas seguidas, dos bloques, y salen escarabajos VOLADORES
--     pequeños que patrullan el cielo (súbditos de reserva, def.summons; más cuanto más difícil).
-- Entrada: baja zumbando del techo, aterriza de golpe y escarba. Derrota: patas arriba, la runa se apaga, se da la
-- vuelta y se va volando torpe hacia arriba atravesando el techo ('dying_flee'; pura función del tiempo), soltando el
-- fragmento. Todo lo que se dibuja sale de state + deadTimer + x, y (+ netPackExtra): igual online.
-- Física (choques, saltos a una marca, zona): la de la Gran Bola de Nieve (types/snowboss.lua), reutilizada.
-- 0.5.78 (el usuario): su caja era más grande que su cuerpo (costaba muchísimo saltarlo): ahora es la del CUERPO, sin
-- el cuerno, y el dibujo se corre 2 px para que caiga sobre ella; tocarlo = su caja, sin margen. LANZA un TROZO DEL
-- SUELO que pisa (su material: césped, tierra, piedra, arena…; se dibuja con la textura de ese tile y se rompe en
-- pedazos de ese material) en vez de un bloque fijo. Sonidos repetidos (pasos, zumbido) más espaciados.

local Entity = require 'src/world/entities/base/Entity'
local Boss   = require 'src/world/entities/base/Boss'
local Snow   = require('src/world/entities/types/bosses/snowboss').class
local BossFx = require 'src/fx/BossFx'
local BossWaves = require 'src/world/entities/base/BossWaves'

local GB = Entity.extend(Boss, {
    ATTACKS  = { charge_wind = true, charge = true, toss_wind = true, toss = true, leap_wind = true, leap = true },
    OPENINGS = { flipped = true },
    debugColor = { 0.6, 0.8, 0.3 },
    -- (el cuerpo mide ~16 de los 22 px del cuadro; de alto, del lomo a las uñas, ~12 de 20)
    -- (0.5.78: el cuerpo del dibujo: ~14 de 22 px de ancho y 11 de 20 de alto con las patas)
    hitbox = { outerW = 0.64, outerH = 0.55, innerW = 0.54, innerH = 0.44 },
})
GB.hurtSound   = 'megaHurt'
GB.introLength = 3.2
GB.wantsLevel  = true
GB.weight      = 3                              -- (en un platillo lo BAJA: más que un jugador con una caja pequeña; 0.5.84)
GB.ridesScale  = true                           -- (va en los platillos de la balanza: mechanisms/scale)
GB.animId      = 'bosses/giantbeetle'

GB.move, GB.physics, GB.friction, GB.groundDecel = Snow.move, Snow.physics, Snow.friction, Snow.groundDecel
GB.zoneBounds, GB.jumpTo = Snow.zoneBounds, Snow.jumpTo
local strike, overlap = Boss.strike, Boss.overlap
local Scale = require('src/world/entities/types/mechanisms/scale').class

local T  = TILE_PX
local MS = 12
local FW, FH = 22, 20
-- (los pies: cada cuadro se dibuja con su último píxel en el suelo — Anim footGap —, salvo en el aire: AIR)
local AIR = { leap = true, hop = true, launched = true, tumble = true, dying_flee = true }
GB.MS = MS

-- Ritmo: { normal, enfadado }
local REST_T      = { 1.2, 0.8 }
local CHARGE_WIND = { 0.8, 0.6 }
local CHARGE_V    = { 860, 1060 }               -- px/s embistiendo
local CHARGE_MAX  = 3.0
local BONK_T      = { 1.1, 0.8 }                -- s aturdido tras chocar (acorazado: no se le golpea)
local TOSS_WIND   = { 0.75, 0.55 }
local TOSS_GAP    = 0.4                         -- s entre los dos bloques (enfadado)
local LEAP_WIND   = { 0.7, 0.55 }
local LEAP_UP     = 3.5                         -- casillas por encima de lo más alto
local SLAM_T      = 0.5
local LAUNCH_V    = 1500                        -- px/s: disparado por la balanza (sube recto hasta chocar)
local LAUNCH_MAX  = 1.4                         -- s subiendo como mucho (sin techo: cae igual, patas arriba)
-- s patas arriba (vulnerable), según la dificultad: { normal, enfadado } (0.5.81, el usuario: con 4,2 / 3,4 era casi
-- imposible pasar de un platillo al otro a tiempo → bastante más en Fácil / Normal, unos segundos más en las difíciles)
-- (0.5.82: 1 s menos; y tras el primer golpe se levanta en Boss.GETUP_T, como todos los jefes)
local FLIP_T      = { easy = { 9, 7.5 }, normal = { 7.5, 6 }, hard = { 5.5, 4.5 }, extreme = { 5.2, 4.2 }, xtra = { 5, 4 } }
local RIGHT_T     = 0.7
local GRACE       = 0.8                         -- s sin volver a dar a nadie tras un golpe
local SLAM_POWER  = 1.5                         -- × la catapulta de la balanza cuando cae él en un platillo
local PAN_BAIT    = 0.65                        -- probabilidad de saltar al OTRO platillo si estás en uno
-- APRENDE (0.5.92; 0.5.94, el usuario: aún caía en la trampa — quieto en un platillo, noquearlo, volver al platillo y
-- repetir —): una cuenta de lo que el jugador "acampa" en los platillos: sube CAMP_UP por segundo encima de ellos y
-- CAMP_LAUNCH cada vez que la balanza lo dispara contra el techo; baja CAMP_DOWN por segundo fuera. Con CAMP_MAX o
-- más ya no salta al otro platillo: intenta BAJARLO del suyo — le salta encima (el aterrizaje lo aparta) o le lanza
-- trozos —. (Antes: 2 saltos y se le olvidaba a los 2 s fuera: lo que se tarda en ir a pegarle.)
local CAMP_UP, CAMP_LAUNCH, CAMP_DOWN, CAMP_MAX = 0.2, 10, 0.3, 6

-- Bloques lanzados y cascotes
local BLOCK_G, BLOCK_VY = 2400, -1050
local BLOCK_S     = 56                          -- lado del trozo de suelo (casi una casilla)
local BODY_DX     = 2                           -- px del cuadro: el cuerpo, 2 a la izquierda del centro (el cuerno, delante)
local STEP_EVERY, BUZZ_EVERY = 0.28, 0.3      -- s entre pasos embistiendo / entre zumbidos de las alas
local ROCKS       = { 4, 6 }                    -- cascotes por choque
local ROCK_WARN   = 0.75                        -- s de sombra antes de caer
local ROCK_G      = 2600
local ROCK_S      = 8 * 6                       -- lado de un cascote (8 px a escala 6)

-- Ondas al aterrizar del salto (base/BossWaves)
local WAVES = { spd = 470, life = 2.2, w = 24 * 4, h = 12 * 4 }

-- Golpes a los jugadores: { vida, vx, vy, s sin control, s aturdido }
local HIT_TOUCH  = { 1, 480, -420, 0.2, 0 }
local HIT_CHARGE = { 1, 760, -520, 0.35, 0 }
local HIT_BLOCK  = { 1, 360, -380, 0.2, 0 }
local HIT_ROCK   = { 1, 200, -300, 0.15, 0 }
local HIT_CEIL   = { 1, 0, 260, 0.3, 0.6 }      -- (disparado por la balanza contra el techo)
WAVES.hit = { 1, 300, -440, 0.15, 0 }

-- Muerte
local OUT_D     = 2.4
local THROW_T   = 0.8
local FLEE_MIN  = 1.8
local FLEE_WIND = 0.5
local FLEE_VX, FLEE_VY = 180, -520              -- vuelo torpe de la huida (sin choques: atraviesa el techo)

-- Escarabajos pequeños de la segunda fase: cuántos a la vez según la dificultad
local MINIONS     = { easy = 1, normal = 2, hard = 2, extreme = 3, xtra = 3 }
local MINION_POOL = 3
local SPAWN_EVERY = 7.0
local DEATH = { dying_out = true, dying_flee = true }
local BACK  = { launched = true, tumble = true, flipped = true, righting = true, dying_out = true }

function GB.sizePx() return FW * MS, FH * MS end

local function rand(a, b) return a + math.random() * (b - a) end

function GB:feetY() return self.y + self.outerH / 2 end
function GB:ph() return self.rage and 2 or 1 end
function GB:bossPhase() return self.rage and 2 or 1 end
function GB:angryPhase() return self.rage end
function GB:ridesPan() return self.onGround and not BACK[self.state] or self.state == 'flipped' end

function GB:initBoss()
    self.y = self.row * T - self.outerH / 2
    self.vx, self.vy, self.onGround = 0, 0, true
    self.facing = -1
    self.rage = false
    self.waves, self.blocks, self.rocks, self.nextId = {}, {}, {}, 0
    self.graceT, self.spawnT, self.charges, self.tossN = 0, 0, 0, 0
    self.markX, self.markY = math.floor(self.x), math.floor(self:feetY())
    self.shot = {}
    self.last = nil
    self.summonKey = 'gb' .. self.col .. ',' .. self.row
end

function GB:onFightStart(n) self:enter('fight') end
function GB:rollStart(r) self.spawnT = r(0, SPAWN_EVERY * 0.8) end

-- ── Estados que sabe hacer el cuerpo ─────────────────────────────────────────
function GB:isActive() return Boss.isActive(self) and not DEATH[self.state] end
function GB:isDying() return DEATH[self.state] == true or Boss.isDying(self) end
function GB:isVulnerable() return self:isActive() and self.state == 'flipped' end
function GB:releasesZone() return self.state == 'dying_flee' or self.state == 'dead' end
function GB:shardDrop() return not self.alive or (self.state == 'dying_flee' and self.deadTimer >= THROW_T) end
function GB:isSolidBody() return Boss.isSolidBody(self) and not DEATH[self.state] end
function GB:canBeKnocked() return false end

-- ── La balanza (mechanisms/scale) ─────────────────────────────────────────────
-- Un ground pound en el otro platillo: sale DISPARADO hacia arriba
function GB:onScaleLaunch(vy, scale)
    if not self:isActive() or BACK[self.state] then return end
    self.camp = (self.camp or 0) + CAMP_LAUNCH                            -- (lo ha pillado la balanza: aprende)
    self.vx, self.vy, self.onGround = 0, -LAUNCH_V, false
    self.waves = {}
    self:enter('launched')
    Sound.play('scaleLaunch')
    Sound.play('megaRoar', 1.3, 0.6)
end
-- Cayó él en un platillo: a quién disparó (para el golpe contra el techo)
function GB:onScaleCatapult(players, ents)
    for _, pa in ipairs(players) do self.shot[#self.shot + 1] = { pa = pa, t = 0, vy = pa.vy or 0 } end
end
-- Los disparados por su golpe que se estrellan contra el techo: 1 de vida
function GB:updateShot(level, dt)
    for i = #self.shot, 1, -1 do
        local s = self.shot[i]
        s.t = s.t + dt
        local pa = s.pa
        local vy = pa.vy or 0
        if s.t > 1.2 or pa.dying then table.remove(self.shot, i)
        elseif s.vy < -250 and vy >= -20 and s.t > 0.05 then                       -- (frenazo en seco subiendo: el techo)
            local pb = pa:getOuterBounds()
            if level:collisionAt(pa.x, pb.y - 6) or level:bodyAt(pa.x, pb.y - 6) then
                strike(pa, HIT_CEIL, 0)
                Sound.play('headBump')
                Entity.emitFx('shake_small', pa.x, pb.y)
            end
            table.remove(self.shot, i)
        else s.vy = vy end
    end
end

-- ── Golpes a los jugadores ────────────────────────────────────────────────────
function GB:touch(level, hit)
    if self.graceT > 0 or BACK[self.state] then return end
    local b = self:getOuterBounds()
    local box = b                                                  -- (su cuerpo, sin margen: 0.5.78)
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false and not pa:isInvulnerable() then
            local pb = pa:getOuterBounds()
            -- (encima del caparazón — los pies por encima de su mitad, bajando o subiendo tras el rebote — no es tocarlo: es
            -- rebotar (Boss:interact); antes solo valía una franja de 14 px y al caer rápido dolía: el usuario, 0.5.79)
            local onTop = pb.y + pb.h <= b.y + b.h * 0.5
            if not onTop and overlap(pb, box) and strike(pa, hit or HIT_TOUCH, (pa.x >= self.x) and 1 or -1) then
                self.graceT = GRACE
            end
        end
    end
end

-- ── Ondas ─────────────────────────────────────────────────────────────────────
function GB:spawnWaves() BossWaves.spawn(self, self:feetY(), self.outerW / 2) end
function GB:waveBox(w) return BossWaves.box(w, WAVES) end

-- ── Bloques lanzados ──────────────────────────────────────────────────────────
function GB:nid() self.nextId = self.nextId % 999 + 1; return self.nextId end
function GB:throwBlock(level, pa)
    local hx = self.x + (self.facing or 1) * self.outerW * 0.45
    local hy = self:feetY() - 15 * MS
    local tx = pa and pa.x or (self.x + (self.facing or 1) * 6 * T)
    local ty = pa and (pa:getOuterBounds().y + pa:getOuterBounds().h) or self:feetY()
    -- tiro en arco que cae en (tx, ty): sube con BLOCK_VY y baja hasta ty
    local vy = BLOCK_VY
    local tUp = -vy / BLOCK_G
    local apex = hy + vy * tUp / 2
    local tDown = math.sqrt(2 * math.max(1, ty - apex) / BLOCK_G)
    local vx = (tx - hx) / (tUp + tDown)
    local tile, pan = self:floorTile(level)
    self.blocks[#self.blocks + 1] = { id = self:nid(), x = hx, y = hy, vx = vx, vy = vy, t = 0, tile = tile, pan = pan, hit = {} }
    Sound.play('megaSlam', 1.4, 0.4)
    -- (lo arranca del suelo delante del cuerno: tierra que salta del material de ese suelo)
    Entity.emitFx('chunk_break', math.floor(hx - T / 2), math.floor(self:feetY() - T), { tile = tile })
end
-- El tile del suelo que pisa delante del cuerno (o bajo él): el material del trozo que arranca — también una
-- plataforma traspasable (madera; 0.5.79, salía piedra) —. Sobre un PLATILLO de la balanza: un trozo DEL PLATILLO
-- (0.5.92, el usuario: salía con la textura de la plataforma traspasable) — devuelve también su isla (índice en
-- Isles.IDS: se dibuja con el arte de ese platillo) y el material de su isla —; sin nada, piedra
local PAN_MAT = { pradera = 'platform_drop', costa = 'platform_drop', fortaleza = 'solid', nieve = 'ice', cueva = 'solid',
                  volcan = 'basalt', jungla = 'temple_brick' }
-- (el dibujo del platillo de la isla `idx` — Isles.IDS —, con el tramo del medio: el trozo que arranca de él)
local panImgs = {}
local function panImage(idx)
    if panImgs[idx] == nil then
        local isle = require('src/world/level/Isles').IDS[idx]
        local ok, img = pcall(require('src/fx/Anim').image, 'assets/images/mechanisms/scale/' .. tostring(isle) .. '-pan.png')
        if ok and img then
            img:setFilter('nearest', 'nearest')
            panImgs[idx] = { img = img, quad = love.graphics.newQuad(16, 0, 16, 8, img:getDimensions()) }
        else
            panImgs[idx] = false
        end
    end
    return panImgs[idx]
end

function GB:floorTile(level)
    local TileTypes = require 'src/world/tiles/TileTypes'
    local by = TileTypes.byName
    local y = self:feetY() + 4
    for _, x in ipairs({ self.x + (self.facing or 1) * self.outerW * 0.45, self.x }) do
        local id = level:getTileAt(x, y)
        local def = TileTypes.get(id)
        if id and id ~= 0 and (def.collision == 'solid' or def.collision == 'oneway') then return id end
    end
    -- (0.5.80: sobre un platillo seguía saliendo piedra — sus pies no siempre tocan la tabla al píxel —: se busca un
    -- cuerpo debajo en una franja, bajo el cuerpo y bajo el cuerno)
    for dy = -4, 20, 4 do
        for _, x in ipairs({ self.x, self.x + (self.facing or 1) * self.outerW * 0.3, self.x - (self.facing or 1) * self.outerW * 0.3 }) do
            local o = level:bodyAt(x, self:feetY() + dy, self)
            if o and o.owner and o.owner.pans then
                local Isles = require 'src/world/level/Isles'
                local isle = Isles.of(level, o.owner.props and o.owner.props.isle)
                local idx = 1
                for i, id in ipairs(Isles.IDS) do if id == isle then idx = i end end
                local m = by[PAN_MAT[isle] or 'platform_drop'] or by.platform_drop
                return m.id, idx
            end
            if o and by.platform_drop then return by.platform_drop.id end
        end
    end
    return by.stone and by.stone.id or 1
end

function GB:updateBlocks(level, dt)
    local _, _, _, zy1 = self:zoneBounds()
    for i = #self.blocks, 1, -1 do
        local b = self.blocks[i]
        b.t = b.t + dt
        b.vy = b.vy + BLOCK_G * dt
        b.x, b.y = b.x + b.vx * dt, b.y + b.vy * dt
        local box = { x = b.x - BLOCK_S / 2, y = b.y - BLOCK_S / 2, w = BLOCK_S, h = BLOCK_S }
        for _, pa in ipairs(level.players or {}) do
            if not b.hit[pa] and overlap(pa:getOuterBounds(), box) and strike(pa, HIT_BLOCK, (b.vx >= 0) and 1 or -1) then
                b.hit[pa] = true
            end
        end
        local bottom = b.y + BLOCK_S / 2
        if (b.vy > 0 and (level:collisionAt(b.x, bottom, true) or level:bodyAt(b.x, bottom, self))) or b.y > zy1 + T
           or level:collisionAt(b.x + ((b.vx >= 0) and 1 or -1) * BLOCK_S / 2, b.y) then
            local mat = require('src/world/tiles/TileTypes').get(b.tile).mat     -- (suena a lo que es: su material)
            Sound.playAt(mat and mat.breakSound or 'blockBreak', b.x, b.y, 0.95, 1.0)
            Entity.emitFx('chunk_break', math.floor(b.x - T / 2), math.floor(b.y - T / 2), { tile = b.tile })   -- (en pedazos de su material)
            table.remove(self.blocks, i)
        end
    end
end

-- ── Cascotes del techo (al chocar de una embestida) ──────────────────────────
function GB:dropRocks(level)
    local zx0, zx1, zy0 = self:zoneBounds()
    local n = ROCKS[self:ph()]
    local players = level.players or {}
    for k = 1, n do
        local x
        local pa = players[(k - 1) % math.max(1, #players) + 1]
        if pa and k <= #players then x = pa.x + rand(-T, T)                       -- (uno encima de cada jugador)
        else x = rand(zx0 + T, zx1 - T) end
        x = math.max(zx0 + ROCK_S, math.min(zx1 - ROCK_S, x))
        local top = self:floorBelow(level, x, zy0 + 4)
        self.rocks[#self.rocks + 1] = { id = self:nid(), x = math.floor(x), y = zy0 + ROCK_S / 2, vy = 0,
                                        t = -ROCK_WARN - k * 0.12, floor = math.floor(top or (zy0 + 12 * T)), hit = {} }
    end
end
-- Lo primero que hay debajo de (x, y): un tile (también plataforma) o un cuerpo (los platillos de la balanza); así la
-- sombra de aviso sale donde de verdad caerá (0.5.79: sobre un platillo, la sombra quedaba en el fondo del foso, tapada)
function GB:floorBelow(level, x, y)
    local _, _, _, zy1 = self:zoneBounds()
    for yy = y, zy1 + 4 * T, 8 do
        if level:collisionAt(x, yy, true) then return math.floor(yy / T) * T end
        local o, b = level:bodyAt(x, yy, self)
        if o then return math.floor(b.y) end
    end
    return zy1
end

function GB:updateRocks(level, dt)
    local _, _, zy0 = self:zoneBounds()
    for i = #self.rocks, 1, -1 do
        local r = self.rocks[i]
        r.t = r.t + dt
        if r.t < 0 then r.floor = math.floor(self:floorBelow(level, r.x, zy0 + 4)) end      -- (el aviso sigue al platillo)
        if r.t >= 0 then
            r.vy = r.vy + ROCK_G * dt
            r.y = r.y + r.vy * dt
            local box = { x = r.x - ROCK_S / 2, y = r.y - ROCK_S / 2, w = ROCK_S, h = ROCK_S }
            for _, pa in ipairs(level.players or {}) do
                if not r.hit[pa] and overlap(pa:getOuterBounds(), box) and strike(pa, HIT_ROCK, (pa.x >= r.x) and 1 or -1) then
                    r.hit[pa] = true
                end
            end
            local bottom = r.y + ROCK_S / 2
            -- (dónde caerá, cada paso: los platillos se mueven — 0.5.81, el usuario: quedaban sombras flotando —)
            r.floor = math.floor(self:floorBelow(level, r.x, r.y))
            local o = r.vy > 0 and level:bodyAt(r.x, bottom, self)
            if bottom >= r.floor or o then
                Sound.play('cavePebble', 1, 0.8)
                Entity.emitFx('block_break', r.x - T / 2, r.floor - T)
                table.remove(self.rocks, i)
            end
        end
    end
end

-- ── Escarabajos pequeños de la segunda fase ──────────────────────────────────
function GB:minionMax(level) return math.min(MINION_POOL, MINIONS[level.difficulty or ''] or MINIONS.normal) end
function GB:spawnMinions(level, dt)
    self.spawnT = self.spawnT + dt
    if self.spawnT < SPAWN_EVERY then return end
    local free, active = nil, 0
    for _, e in ipairs(self:minions(level)) do
        if e.alive and e.state ~= 'dead' then active = active + 1 elseif not free then free = e end
    end
    if not free or active >= self:minionMax(level) then return end
    self.spawnT = 0
    -- (0.5.79, el usuario: VOLADORES con sus alas, como la guardia del Rey Gummy: salen arriba y patrullan el cielo de
    -- la zona — su mitad de arriba —; pisados caen patas arriba y, si se levantan, vuelven a volar)
    local zx0, zx1, zy0, zy1 = self:zoneBounds()
    local x, y = rand(zx0 + 2 * T, zx1 - 2 * T), zy0 + T + free.outerH / 2
    local dir = (math.random() < 0.5) and 1 or -1
    local h = free.home
    h.x, h.y, h.facing, h.flipped, h.state, h.vx = x, y, dir, false, 'walk', free.speed * dir
    free:resetToHome()
    free.leftBoundPx, free.rightBoundPx = zx0, zx1
    free.freeFly, free.flyArea = true, { x0 = zx0, y0 = zy0, x1 = zx1, y1 = math.floor((zy0 + zy1) / 2 + T) }
    free.state, free.deadTimer = 'spawning', 0
    Entity.emitFx('spawn', x, y)
    Sound.play('gustBlow', 1.3, 0.6)
end

-- ── Elegir el siguiente ataque ────────────────────────────────────────────────
-- El platillo en el que está de pie un jugador (y el otro)
local function panOf(level, pa)
    for _, s in ipairs(level.liveEntities or {}) do
        if s.pans and s.catapult then
            for i, pan in ipairs(s.pans) do
                if pa.standBody == pan then return s, pan, s.pans[3 - i] end
            end
        end
    end
    return nil
end

function GB:aimAt(level, tx, ty)
    local zx0, zx1, zy0, zy1 = self:zoneBounds()
    local hw = self.outerW / 2
    tx = math.max(zx0 + hw, math.min(zx1 - hw, tx))
    local top
    for _, px in ipairs({ tx - hw + 8, tx, tx + hw - 8 }) do
        local _, t = level:landingCross(px, (ty or zy0) - 2 * T, zy1 + T)
        if not t then
            local o, b = level:bodyAt(px, (ty or zy1) + 2, self)
            if o then t = b.y end
        end
        if t and (not top or t < top) then top = t end
    end
    return math.floor(tx), math.floor(top or zy1)
end

function GB:choose(level)
    local pa = self:nearestPlayer(level)
    if pa and math.abs(pa.x - self.x) > 8 then self.facing = (pa.x > self.x) and 1 or -1 end
    -- en un platillo: salta al OTRO para dispararlo (doble filo) — hasta que aprende (CAMP_MAX): entonces lo baja
    if pa then
        local _, mine, other = panOf(level, pa)
        if other and (self.camp or 0) >= CAMP_MAX then
            if math.random() < 0.3 then
                self.last, self.tossN = 'toss', self.rage and 2 or 1
                Sound.play('megaWindup', 1.3, 0.5)
                return self:enter('toss_wind')
            end
            local b = mine:getOuterBounds()                                -- (le salta encima, a su platillo)
            self.markX, self.markY = math.floor(math.max(b.x + 8, math.min(b.x + b.w - 8, pa.x))), math.floor(b.y)
            self.last = 'leap'
            Sound.play('gustBlow', 0.7, 0.6)
            return self:enter('leap_wind')
        end
        if other and math.random() < PAN_BAIT then
            local b = other:getOuterBounds()
            self.markX, self.markY = math.floor(b.x + b.w / 2), math.floor(b.y)
            self.last = 'leap'
            Sound.play('gustBlow', 0.7, 0.6)
            return self:enter('leap_wind')
        end
    end
    local opts = {}
    for _, o in ipairs({ 'charge', 'toss', 'leap' }) do if o ~= self.last then opts[#opts + 1] = o end end    -- (no repite)
    local pick = opts[math.random(#opts)]
    self.last = pick
    if pick == 'charge' then
        self.charges = self.rage and 2 or 1
        Sound.play('megaWindup', 1, 0.7)
        return self:enter('charge_wind')
    elseif pick == 'toss' then
        self.tossN = self.rage and 2 or 1
        Sound.play('megaWindup', 1.3, 0.5)
        return self:enter('toss_wind')
    end
    local tx = pa and pa.x or self.x
    local ty = pa and (pa:getOuterBounds().y + pa:getOuterBounds().h) or nil
    self.markX, self.markY = self:aimAt(level, tx, ty)
    Sound.play('gustBlow', 0.7, 0.6)
    self:enter('leap_wind')
end

-- ¿Está de pie en un platillo de la balanza? (el cuerpo de un solo sentido de una Balanza bajo sus pies)
local function isPan(o) return o and o.owner and o.owner.pans ~= nil end
function GB:onAPan(level)
    for _, x in ipairs({ self.x - self.outerW * 0.3, self.x, self.x + self.outerW * 0.3 }) do
        if isPan((level:bodyAt(x, self:feetY() + 4, self))) then return true end
    end
    return false
end
-- Si está en un platillo, salta a un sitio (suelo o plataforma) que no sea un platillo, a 3-9 casillas: 'hop'
function GB:hopOff(level)
    if not self:onAPan(level) then return false end
    local zx0, zx1 = self:zoneBounds()
    local hw = self.outerW / 2
    local spots = {}
    for x = zx0 + hw + 8, zx1 - hw - 8, T / 2 do
        local d = math.abs(x - self.x)
        if d >= 3 * T and d <= 9 * T then
            local tx, ty = self:aimAt(level, x, nil)
            local clear = true
            for _, px in ipairs({ tx - hw + 8, tx, tx + hw - 8 }) do
                if isPan((level:bodyAt(px, ty + 2, self))) then clear = false end
            end
            if clear then spots[#spots + 1] = { tx, ty } end
        end
    end
    if #spots == 0 then return false end
    local s = spots[math.random(#spots)]
    self.markX, self.markY = s[1], s[2]
    self.passY = s[2]
    self:jumpTo(s[1], s[2], 2)
    self:enter('hop')
    Sound.play('gustBlow', 0.6, 0.8)
    return true
end

function GB:rest(len)
    self.restLen = len or REST_T[self:ph()]
    self:enter('rest')
end

-- ── Golpes y derrota ──────────────────────────────────────────────────────────
function GB:onDamaged(n, kind)
    if self:isDying() then return end
    if not self.rage and self.hp <= self.hpMax * (self.props.rageAt or 0.5) then
        self.rage = true
        Entity.emitFx('shake_roar', self.x, self.y)
        Sound.play('megaRoar', 1, 0.8)
    end
end

function GB:defeat()
    self.hp, self.inv, self.ghost = 0, 0, false
    self.waves, self.blocks, self.rocks, self.shot = {}, {}, {}, {}
    for _, e in ipairs(self.levelRef and self:minions(self.levelRef) or {}) do
        if e.alive and e.state ~= 'dead' then e:dieBurst() end
    end
    self.vx = 0
    self:enter('dying_out')
    Sound.play('megaHurt', 0.8, 0.8)
    Sound.play('stunned')
    self:onDefeat()
end

-- ── Update ────────────────────────────────────────────────────────────────────
function GB:updateBoss(dt, level)
    if self.state == 'dormant' then return end
    self.levelRef = self.levelRef or level
    self.deadTimer = self.deadTimer + dt
    if self.graceT > 0 then self.graceT = math.max(0, self.graceT - dt) end
    BossWaves.update(self, level, dt, WAVES)
    -- (lo que el jugador acampa en los platillos: sube encima, se le olvida despacio fuera)
    local near = self:nearestPlayer(level)
    if near and panOf(level, near) then self.camp = (self.camp or 0) + CAMP_UP * dt
    else self.camp = math.max(0, (self.camp or 0) - CAMP_DOWN * dt) end
    self:updateBlocks(level, dt)
    self:updateRocks(level, dt)
    self:updateShot(level, dt)
    local st, t, ph = self.state, self.deadTimer, self:ph()

    if st == 'fight' then self:rest(); return end

    if st == 'rest' then
        self:physics(level, dt); self:friction(level, dt)
        self:touch(level)
        if self.rage then self:spawnMinions(level, dt) end
        local pa = self:nearestPlayer(level)
        if pa and math.abs(pa.x - self.x) > 8 then self.facing = (pa.x > self.x) and 1 or -1 end
        if t >= (self.restLen or REST_T[ph]) and self.onGround and self:mayAttack(level) then self:choose(level) end

    elseif st == 'charge_wind' then
        self:physics(level, dt); self:friction(level, dt)
        self:touch(level)
        local pa = self:nearestPlayer(level)
        if pa and t < CHARGE_WIND[ph] * 0.6 and math.abs(pa.x - self.x) > 8 then self.facing = (pa.x > self.x) and 1 or -1 end
        if math.floor(t * 8) ~= math.floor((t - dt) * 8) then
            Entity.emitFx('gp_land', self.x - (self.facing or 1) * self.outerW / 2, self:feetY())
        end
        if t >= CHARGE_WIND[ph] then
            self.vx = (self.facing or 1) * CHARGE_V[ph]
            self:enter('charge')
            Sound.play('megaStep', 1.2, 0.8)
        end

    elseif st == 'charge' then
        self.vx = (self.facing or 1) * CHARGE_V[ph]
        local hit = self:physics(level, dt)
        self:touch(level, HIT_CHARGE)
        if math.floor(t / STEP_EVERY) ~= math.floor((t - dt) / STEP_EVERY) then Sound.play('megaStep', 1.3, 0.5) end
        if hit == 'wall' then
            self.vx = 0
            Sound.play('megaSlam', 1, 0.8)
            Sound.play('caveRumble', 1, 0.7)
            Entity.emitFx('shake_big', self.x, self.y)
            self:dropRocks(level)
            self:enter('bonk')
        elseif t >= CHARGE_MAX then self:rest() end

    elseif st == 'bonk' then
        self:physics(level, dt); self:friction(level, dt)
        if t >= BONK_T[ph] then
            self.charges = self.charges - 1
            if self.charges > 0 then
                self.facing = -(self.facing or 1)
                Sound.play('megaWindup', 1, 0.7)
                self:enter('charge_wind')
            else self:rest() end
        end

    elseif st == 'toss_wind' then
        self:physics(level, dt); self:friction(level, dt)
        self:touch(level)
        local pa = self:nearestPlayer(level)
        if pa and math.abs(pa.x - self.x) > 8 then self.facing = (pa.x > self.x) and 1 or -1 end
        if t >= TOSS_WIND[ph] then
            self:throwBlock(level, pa)
            self.tossN = self.tossN - 1
            self:enter('toss')
        end

    elseif st == 'toss' then
        self:physics(level, dt); self:friction(level, dt)
        self:touch(level)
        if self.tossN > 0 and t >= TOSS_GAP then
            local pa = self:nearestPlayer(level)
            self:throwBlock(level, pa)
            self.tossN = self.tossN - 1
            self.deadTimer = 0
        elseif self.tossN <= 0 and t >= 0.45 then self:rest() end

    elseif st == 'leap_wind' then
        self:physics(level, dt); self:friction(level, dt)
        self:touch(level)
        if math.abs(self.markX - self.x) > 4 then self.facing = (self.markX > self.x) and 1 or -1 end
        if t >= LEAP_WIND[ph] then
            self.passY = self.markY
            self:jumpTo(self.markX, self.markY, LEAP_UP)
            self:enter('leap')
            Sound.play('gustBlow', 0.6, 0.8)
        end

    elseif st == 'leap' then
        self:physics(level, dt)
        self:touch(level)
        if math.floor(t / BUZZ_EVERY) ~= math.floor((t - dt) / BUZZ_EVERY) then Sound.play('gustBlow', 1.6, 0.2) end    -- (el zumbido)
        if self.onGround and self.vy >= 0 and t > 0.1 then
            self.passY, self.vx = nil, 0
            Sound.play('megaSlam', 1, 0.9)
            Sound.play('gpImpact', 1, 0.7)
            Entity.emitFx('gp_land', self.x, self:feetY())
            Entity.emitFx('shake_big', self.x, self.y)
            self:spawnWaves()
            Scale.slamUnder(level, self, SLAM_POWER)               -- (en un platillo: dispara lo del otro)
            self:enter('slam')
        end

    elseif st == 'slam' then
        self:physics(level, dt); self:friction(level, dt)
        self:touch(level)
        if t >= SLAM_T then self:rest() end

    elseif st == 'launched' then
        -- disparado por la balanza: sube recto hasta chocar con algo
        self.vx, self.vy = 0, -LAUNCH_V
        local y0 = self.y
        self:physics(level, dt, false)
        if self.y > y0 - LAUNCH_V * dt * 0.5 or t >= LAUNCH_MAX then
            if t < LAUNCH_MAX then
                Sound.play('megaSlam', 0.8, 1)
                Sound.play('blockBreak', 1, 0.8)
                Entity.emitFx('shake_big', self.x, self.y)
                local _, _, zy0 = self:zoneBounds()
                Entity.emitFx('block_break', self.x - T / 2, math.max(zy0, self.y - self.outerH / 2 - T))
            end
            self.vy = 0
            self:enter('tumble')
        end

    elseif st == 'tumble' then
        self:physics(level, dt)
        if self.onGround and t > 0.1 then
            Sound.play('megaFall', 1, 0.8)
            Sound.play('stunned')
            Entity.emitFx('shake_big', self.x, self.y)
            self:enter('flipped')
        end

    elseif st == 'flipped' then
        self:physics(level, dt); self:friction(level, dt)
        if t >= self:downTime((FLIP_T[level.difficulty or ''] or FLIP_T.normal)[ph]) then self:enter('righting') end

    elseif st == 'righting' then
        self:physics(level, dt); self:friction(level, dt)
        if t >= RIGHT_T then
            Sound.play('megaStep', 1, 0.8)
            -- (0.5.85, el usuario: levantado en un platillo, el jugador corría al otro y lo volvía a disparar contra el
            -- techo en bucle → si está en un platillo, salta YA al suelo o a una plataforma lejos de los platillos)
            if not self:hopOff(level) then
                self.vy, self.onGround = -500, false
                self:rest(0.6)
            end
        end

    elseif st == 'hop' then
        -- (el salto para bajarse del platillo: sin ondas ni disparar la balanza)
        self:physics(level, dt)
        if math.floor(t / BUZZ_EVERY) ~= math.floor((t - dt) / BUZZ_EVERY) then Sound.play('gustBlow', 1.6, 0.2) end
        if self.onGround and self.vy >= 0 and t > 0.1 then
            self.passY, self.vx = nil, 0
            Sound.play('gpImpact', 1, 0.6)
            Entity.emitFx('gp_land', self.x, self:feetY())
            self:rest(0.6)
        end

    elseif st == 'dying_out' then
        self:physics(level, dt); self:friction(level, dt)
        if t >= OUT_D and self.onGround then
            self.fleeDir = self:fleeSide(level)
            self.facing, self.fleeing = self.fleeDir, true
            self.fleeX0, self.fleeY0, self.broke = self.x, self.y, false
            self:enter('dying_flee')
        end

    elseif st == 'dying_flee' then
        -- se da la vuelta y se va volando torpe hacia arriba (pura función del tiempo): atraviesa el techo
        local tj = t - FLEE_WIND
        if tj >= 0 then
            if tj - dt < 0 then Sound.play('gustBlow', 0.6, 0.8) end
            self.x = self.fleeX0 + self.fleeDir * FLEE_VX * tj + math.sin(tj * 9) * 14
            self.y = self.fleeY0 + FLEE_VY * tj
            self.vx, self.vy = self.fleeDir * FLEE_VX, FLEE_VY
            local _, _, zy0 = Boss.zoneBounds(self)
            if not self.broke and self.y - self.outerH / 2 < zy0 then
                self.broke = true
                Sound.play('gpImpact', 1, 0.6)
                Entity.emitFx('block_break', self.x - T / 2, zy0 - T)
                Entity.emitFx('shake_small', self.x, zy0)
            end
        end
        if self:fleeOver(level, dt, t, FLEE_MIN) then self.state, self.alive = 'dead', false end
    end
end

-- ── Entrada: baja zumbando del techo, aterriza de golpe y escarba ────────────
local LAND_AT, ROAR_AT = 1.2, 2.0
GB.LAND_AT = LAND_AT
function GB:introFocus()
    local zx0, zx1, zy0, zy1 = self:zoneBounds()
    return (zx0 + zx1) / 2, (zy0 + zy1) / 2
end
function GB:onIntroStart(level, players)
    self.introStep = 0
    self.levelRef = self.levelRef or level
end
function GB:updateIntro(dt, level, t)
    local hx, hy = self.home.x, self.home.y
    local _, _, zy0 = self:zoneBounds()
    self.x = hx
    if t < LAND_AT then
        local y0 = zy0 - self.outerH
        local u = math.max(0, t / LAND_AT)
        self.y = y0 + (hy - y0) * u * u
        if math.floor(t / BUZZ_EVERY) ~= math.floor((t - dt) / BUZZ_EVERY) then Sound.play('gustBlow', 1.5, 0.25) end
        return
    end
    self.y = hy
    if self.introStep < 1 then
        self.introStep = 1
        Sound.play('megaSlam', 1, 0.9)
        Sound.play('gpImpact', 1, 0.6)
        Entity.emitFx('gp_land', self.x, self:feetY())
        Entity.emitFx('shake_big', self.x, self.y)
    end
    if t >= ROAR_AT and self.introStep < 2 then self.introStep = 2; Sound.play('megaRoar', 1, 0.7) end
end

-- ── Red ───────────────────────────────────────────────────────────────────────
-- { enfadado, diana x, y, nTrozos, {id, x, y, tile}…, nCascotes, {id, x, y, t·100, suelo}…, ondas… }
function GB:netPackExtra()
    local out = { self.rage and 1 or 0, self.markX or 0, self.markY or 0, #self.blocks }
    for _, b in ipairs(self.blocks) do
        out[#out + 1] = b.id; out[#out + 1] = math.floor(b.x); out[#out + 1] = math.floor(b.y)
        out[#out + 1] = (b.tile or 0) + (b.pan or 0) * 256                -- (tile + isla del platillo × 256)
    end
    out[#out + 1] = #self.rocks
    for _, r in ipairs(self.rocks) do
        out[#out + 1] = r.id; out[#out + 1] = r.x; out[#out + 1] = math.floor(r.y)
        out[#out + 1] = math.floor(r.t * 100); out[#out + 1] = r.floor
    end
    return BossWaves.pack(self.waves, out)
end

local function readList(b, k, stride)
    local n = type(b[k]) == 'number' and b[k] or 0
    local list = {}
    for i = 0, n - 1 do
        local e = {}
        for j = 1, stride do e[j] = b[k + 1 + i * stride + j - 1] end
        list[#list + 1] = e
    end
    return list, k + 1 + n * stride
end

function GB:netApplyExtra(a, b, f)
    if type(b[1]) ~= 'number' then return end
    self.rage, self.markX, self.markY = b[1] == 1, b[2], b[3]
    local function lerpById(la, lb, keys)
        local prev = {}
        for _, e in ipairs(la) do if e[1] then prev[e[1]] = e end end
        for _, e in ipairs(lb) do
            local o = prev[e[1]]
            if o then for _, k in ipairs(keys) do
                if type(o[k]) == 'number' and type(e[k]) == 'number' then e[k] = o[k] + (e[k] - o[k]) * f end
            end end
        end
    end
    local ba, ka = readList(a, 4, 4)
    local bb, kb = readList(b, 4, 4)
    lerpById(ba, bb, { 2, 3 })
    self.blocks = {}
    for _, e in ipairs(bb) do
        local pan = math.floor(e[4] / 256)
        self.blocks[#self.blocks + 1] = { id = e[1], x = e[2], y = e[3], tile = e[4] % 256, pan = pan > 0 and pan or nil,
                                          vx = 0, vy = 0, t = 0, hit = {} }
    end
    local ra = (type(a[ka]) == 'number') and readList(a, ka, 5) or {}
    local rb, kr = readList(b, kb, 5)
    lerpById(ra, rb, { 3 })
    self.rocks = {}
    for _, e in ipairs(rb) do
        self.rocks[#self.rocks + 1] = { id = e[1], x = e[2], y = e[3], t = (e[4] or 0) / 100, floor = e[5], vy = 0, hit = {} }
    end
    self.waves = BossWaves.unpack(a, b, kr, f)
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
-- (cuadro, escala x/y, desvío x, giro en radianes o false) según el estado
function GB:pose()
    local st, t = self.state, self.deadTimer or 0
    local set = self:anims()
    local now = love.timer.getTime()
    local fr, sx, sy, ox, flip = set:frameAt('idle', 0), 1, 1, 0, false
    if st == 'intro' or st == 'ready' then
        local it = (st == 'ready') and (self:introTime() + t) or t
        if it < LAND_AT then fr = set:frameAt('fly', it)
        elseif it < LAND_AT + 0.25 then fr, sx, sy = set:frameAt('slam', 0), 1.1, 0.9
        else fr = set:frameAt('charge', (it >= ROAR_AT) and it or 0) end
    elseif st == 'rest' then
        if t < 0.15 and self.onGround then fr = set:frameAt('slam', 0) else fr = set:frameAt('walk', now) end
        if math.abs(self.vx) < 5 then fr = set:frameAt('idle', 0) end
    elseif st == 'charge_wind' then
        fr, ox = set:frameAt('charge', 0), (math.floor(now * 30) % 2 == 0) and 1 or -1
    elseif st == 'charge' then fr = set:frameAt('charge', t * 1.6)
    elseif st == 'bonk' then fr, ox = set:frameAt('slam', 0), (math.floor(t * 16) % 2 == 0) and 1 or 0
    elseif st == 'toss_wind' then fr = set:frameN('toss', 1)
    elseif st == 'toss' then fr = set:frameN('toss', 2)
    elseif st == 'leap_wind' then fr, sx, sy = set:frameAt('fly', now * 2), 1.05, 0.95
    elseif st == 'leap' or st == 'hop' then fr = set:frameAt('fly', now)
    elseif st == 'slam' then fr = set:frameAt('slam', 0)
    elseif st == 'launched' then fr = set:frameAt('walk', now * 2)                      -- (sale disparado de pie)
    elseif st == 'tumble' then fr, flip = set:frameAt('walk', now * 2), math.min(math.pi, t * 7)   -- (se da la vuelta cayendo)
    elseif st == 'flipped' or st == 'dying_out' then
        fr = set:frameAt('flip', (st == 'dying_out') and t * math.max(0.2, 1 - t / OUT_D) or now)
    elseif st == 'righting' then fr, sy = set:frameAt('flip', now * 3), 1 - 0.1 * math.sin(t / RIGHT_T * math.pi)
    elseif st == 'dying_flee' then fr = (t < FLEE_WIND) and set:frameAt('idle', 0) or set:frameAt('fly', now)
    end
    return fr, sx, sy, ox, flip
end

function GB:render(camX, camY)
    if self.state == 'dormant' and not EDITOR_VIEW then return end
    if self.state == 'dead' then return end
    local st = self.state
    local now = love.timer.getTime()
    local fr, sx, sy, ox, flip = self:pose()
    local x = math.floor(self.x - camX) + ox * MS / 3 + BODY_DX * MS * (self.facing or 1)   -- (el cuerpo, no el cuadro, sobre su x)
    local set = self:anims()
    local inAir = AIR[st] or ((st == 'intro' or st == 'ready') and (self.introStep or 0) == 0)
    -- (+1: las patas de DELANTE son 1 px más largas; así las de detrás tocan el suelo y las de delante lo atraviesan
    -- 1 px — el usuario, 2026-10-28)
    local gap = inAir and 1 or (set:footGap(fr) + 1)
    local feet = math.floor(self:feetY() - camY) + gap * MS
    local alpha = self:ghostAlpha()
    if st == 'dying_flee' then alpha = alpha * self:fleeAlpha(self.deadTimer) end
    local f = self.facing or 1
    local dizzy = (st == 'flipped' or st == 'dying_out') and not EDITOR_VIEW
    local hx, hy = math.floor(self.x - camX), feet - 9 * MS
    if dizzy then BossFx.stars(hx, hy, 7 * MS, 1.2 * MS, 5, alpha, 'back') end
    if self:flashRed() then love.graphics.setColor(1, 0.35, 0.35, alpha)
    elseif self.rage and self:isActive() then
        local q = 0.82 + 0.1 * math.sin(now * 6)
        love.graphics.setColor(1, q, q, alpha)
    else love.graphics.setColor(1, 1, 1, alpha) end
    -- (el dibujo mira a la DERECHA; tras chocar con el techo se da la vuelta en el aire, girando sobre su centro)
    if flip then set:drawFrame(fr, x, feet - FH * MS / 2, flip * f, MS * f * sx, MS * sy, 0.5, 0.5)
    else set:drawFrame(fr, x, feet, 0, MS * f * sx, MS * sy, 0.5, 1) end
    self:drawOver(camX, camY)
    love.graphics.setColor(1, 1, 1, 1)
end

-- La diana del salto, los bloques, los cascotes (con su sombra de aviso), las ondas, las estrellitas, el enfado
function GB:drawOver(camX, camY)
    local st = self.state
    local now = love.timer.getTime()
    local set = self:anims()
    if st == 'leap_wind' and not EDITOR_VIEW then
        local blink = (math.floor(now * 12) % 2 == 0) and 0.95 or 0.55
        love.graphics.setColor(1, 0.85, 0.3, blink)
        BossFx.target(now * 1.2, math.floor(self.markX - camX), math.floor(self.markY - camY - 16), 8, 8)
    end
    love.graphics.setColor(1, 1, 1, 1)
    local TileTypes = require 'src/world/tiles/TileTypes'
    for _, b in ipairs(self.blocks or {}) do                      -- (el trozo de suelo: la textura de su tile, girando)
        local def = TileTypes.get(b.tile or 0)
        love.graphics.push()
        love.graphics.translate(math.floor(b.x - camX), math.floor(b.y - camY))
        love.graphics.rotate(((now * 7 + (b.id or 0)) % (2 * math.pi)) * ((b.vx or 1) >= 0 and 1 or -1))
        -- (la sombra, del tamaño de lo que se ve del tile — su hitbox —: una pasarela es fina; 0.5.80, el usuario: el
        -- trozo de plataforma salía con un cuadrado oscuro detrás)
        local pimg = b.pan and panImage(b.pan)
        if pimg then
            -- (un trozo del platillo: el tramo del medio de su dibujo — 16x8 —, con su sombra)
            local k = BLOCK_S / 16
            love.graphics.setColor(0, 0, 0, 0.35)
            love.graphics.rectangle('fill', -BLOCK_S / 2 + 4, -4 * k + 4, BLOCK_S, 8 * k)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(pimg.img, pimg.quad, -BLOCK_S / 2, -4 * k, 0, k, k)
        else
            local hb = def.hitbox or { x = 0, y = 0, w = 1, h = 1 }
            love.graphics.setColor(0, 0, 0, 0.35)
            love.graphics.rectangle('fill', -BLOCK_S / 2 + 4 + hb.x * BLOCK_S, -BLOCK_S / 2 + 4 + hb.y * BLOCK_S, hb.w * BLOCK_S, hb.h * BLOCK_S)
            TileTypes.drawTile(def, { x = -BLOCK_S / 2, y = -BLOCK_S / 2, size = BLOCK_S, col = 1, row = 1, time = now })
        end
        love.graphics.pop()
        love.graphics.setColor(1, 1, 1, 1)
    end
    for _, r in ipairs(self.rocks or {}) do
        if r.t < 0 or r.y < r.floor - ROCK_S then                    -- (la sombra en el suelo: el aviso, hasta que llega)
            local fall = r.t < 0 and (1 - math.min(1, -r.t / (ROCK_WARN + 0.8))) or 1
            local blink = (math.floor(now * 10 + r.id) % 2 == 0) and 1 or 0.7
            love.graphics.setColor(0, 0, 0, (0.5 + 0.3 * fall) * blink)
            love.graphics.ellipse('fill', math.floor(r.x - camX), math.floor(r.floor - camY) - 4, ROCK_S * (0.55 + 0.35 * fall), 10)
            love.graphics.setColor(1, 1, 1, 1)
        end
        if r.t >= 0 then
            set:drawFrame(set:frameN('debris', (r.id % 3) + 1), math.floor(r.x - camX), math.floor(r.y - camY), 0, 6, 6, 0.5, 0.5)
        end
    end
    for _, w in ipairs(self.waves or {}) do
        local k = math.floor((w.t or 0) * 12) % 4 + 1
        set:drawFrame(set:frameN('wave', k), math.floor(w.x - camX), math.floor(w.y - camY), 0, 4 * w.dir, 4, 0.5, 1)
    end
    if (st == 'flipped' or st == 'dying_out') and not EDITOR_VIEW then
        local feet = math.floor(self:feetY() - camY) + MS
        BossFx.stars(math.floor(self.x - camX), feet - 9 * MS, 7 * MS, 1.2 * MS, 5, self:ghostAlpha(), 'front')
    end
    BossFx.anger(self, self.rage and self:isActive(), self.x - camX, self:feetY() - camY - 14 * MS)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Cajas de depuración (F1): ondas, bloques y cascotes
function GB:debugBoxes()
    local out = {}
    for _, w in ipairs(self.waves or {}) do local b = self:waveBox(w); b.kind = 'hazard'; out[#out + 1] = b end
    for _, b in ipairs(self.blocks or {}) do
        out[#out + 1] = { x = b.x - BLOCK_S / 2, y = b.y - BLOCK_S / 2, w = BLOCK_S, h = BLOCK_S, kind = 'hazard' }
    end
    for _, r in ipairs(self.rocks or {}) do
        out[#out + 1] = { x = r.x - ROCK_S / 2, y = r.y - ROCK_S / 2, w = ROCK_S, h = ROCK_S, kind = (r.t < 0) and 'area' or 'hazard' }
    end
    return out
end

local G = 'Escarabajo Rinoceronte Gigante'
return {
    name = 'giantbeetle', label = 'Escarabajo Rinoceronte Gigante', category = 'Jefes',
    description = 'El jefe del templo de la jungla. Acorazado: solo se le golpea PATAS ARRIBA. Con él en un platillo de la '
               .. 'balanza, un ground pound en el otro lo dispara contra el techo y cae volcado. Embiste (caen cascotes), '
               .. 'lanza bloques y salta con las alas (ondas; si cae en un platillo, te dispara a ti).',
    class = GB,
    boss = { title = 'ESCARABAJO RINOCERONTE GIGANTE' },
    hide = Boss.HIDE,
    defaults = { points = 30 },
    props = Boss.props({ hp = 10, hpPerPlayer = 4 }, {
        { key = 'rageAt', kind = 'number', label = 'Se enfada con (fracción de vida)', group = G, default = 0.5,
          min = 0.1, max = 0.9, step = 0.05 },
    }),
    editor = { sprite = 'assets/images/bosses/giantbeetle/body-Sheet.png', frameW = FW },
    -- Escarabajos de la segunda fase: de reserva (Level.fromData los crea detrás de las entidades del JSON); el jefe
    -- los suelta arriba, volando (GB:spawnMinions)
    summons = function(pl)
        local out = {}
        for _ = 1, MINION_POOL do
            out[#out + 1] = { type = 'beetle', col = pl.col, row = pl.row, summonKey = 'gb' .. pl.col .. ',' .. pl.row,
                              props = { pauses = false, patrol = false, points = 5, movement = 'fly', flyMode = 'free',
                                        wings = true, speed = 110, respawn = 0 } }
        end
        return out
    end,
}

