-- Jefe GRAN BOLA DE NIEVE (types/snowboss.lua). Una bola de nieve juguetona que cree
-- que esto es una pelea de bolas: salta, escupe bolas de nieve y RUEDA por la arena
-- helada. Nunca se le hace daño así como así; se le gana con el ESCENARIO:
--   * MAREADA ('dizzy'): rodando choca contra una compuerta (Bloque ON/OFF sólido)
--     o le explota una bomba cerca → pisotón 1 / ground pound 2
--   * CONGELADA ('frozen'): la alcanza el chorro de un Congelador (los de la arena
--     disparan al cambiar su Activador) → pisotón 1 / ground pound 3 (rompe el hielo)
--   * si no, rebota sin hacerle nada (jefe inmune)
-- Fases (por vida): 1 contenta (salta, escupe 3 bolas, rueda) · 2 enfadada (≤ phase2,
-- se hincha x1.25: rueda más rápido y rebota en las paredes, bolas-bomba que al caer
-- son bombas encendidas que se le pueden devolver de una patada, GRAN GOLPE con ola de
-- nieve y carámbanos que caen) · 3 agrietada (≤ phase3: AVALANCHA rodando sin parar,
-- tapa los Activadores con nieve prensada rompible, ráfagas de 5 bolas).
-- Hielo fino: sus aterrizajes lo agrietan (1, el gran golpe 2); al cambiar de fase
-- sopla y lo vuelve a congelar. Entrada (genérica de Boss): una bolita entra rodando,
-- botando y creciendo, se estampa, se ríe y escupe una bola a la cámara.
-- Muerte: se agrieta → revienta en nieve → una bolita con cara huye avergonzada
-- (libera la zona antes: releasesZone).
-- Todo lo que se dibuja sale de state + deadTimer + x, y (+ netPackExtra): igual online.
-- Sprites: assets/images/bosses/snowboss/ (tools/ui/make_snowboss_sprites.py);
-- sonidos: assets/sounds/bosses/snowboss/ (tools/sounds/snowboss.py).

local Entity      = require 'src/world/entities/Entity'
local Boss        = require 'src/world/entities/Boss'
local SpriteStrip = require 'src/fx/SpriteStrip'
local TileTypes   = require 'src/world/tiles/TileTypes'
local TileCodec   = require 'src/world/tiles/TileCodec'
local IceEncase                         -- (solo dibujo)

local Snow = Entity.extend(Boss, {
    debugColor = { 0.7, 0.85, 1 },
    hitbox = { outerW = 13 / 16, outerH = 13 / 16, innerW = 12 / 16, innerH = 12 / 16 },
})
Snow.hurtSound   = 'bossHurt'
Snow.renderFront = true                 -- (por delante de los jugadores: rueda por encima)
Snow.introLength = 4.4

local SC1, SC2 = 8, 10                  -- escala del arte (fase 1 / hinchada)
local T = TILE_PX
local GRAV = 2200

-- Duraciones / fuerzas
local IDLE_T     = { 1.0, 0.75, 0.55 }  -- pausa entre ataques por fase
local HOP_VY     = 900                  -- (bajito: no se sube a las plataformas de la arena)
local HOP_AIR    = 0.82                 -- s en el aire (2·HOP_VY/GRAV) para apuntar el salto
local LAND_T     = 0.35
local SHOOT_WIND = 0.45
local SHOOT_GAP  = 0.2
local WINDUP_T   = { 0.75, 0.6, 0.45 }
local ROLL_SPD   = { 560, 700, 820 }
local ROLL_ACC   = 2600
local ROLL_MAX_T = 2.6                  -- s rodando (empujando) antes de dejarse deslizar
local DIZZY_T    = 2.6
local FROZEN_T   = 4.0
local RECOVER_T  = 0.8
local SLAM_VY    = 1450
local SLAM_HOLD  = 0.3
local SLAM_FALL  = 1700
local SLAM_LAND  = 0.7
local SHOCK_SPD  = 560
local SHOCK_LIFE = 1.35
local AVAL_T     = 6.0
local PHASE_T    = 1.6
local CRASH_SPD  = 240                  -- px/s mínimos para marearse al chocar
local ICE_DECEL  = 260                  -- frenada deslizando sobre hielo (px/s²)
local SNOW_DECEL = 2600                 -- y sobre lo demás
local ICICLE_WARN = 0.85
local BALL_HIT   = 26                   -- lado de la caja de daño de una bola
-- Golpes a los jugadores: { vida, vx, vy, s sin control (el impulso no se pierde), s aturdido }
local HIT_BALL   = { 1, 620, -360, 0.22, 0 }       -- bola de nieve: empujón fuerte
local HIT_ICICLE = { 2, 320, -280, 0.12, 0 }       -- carámbano en la cabeza
local HIT_WAVE   = { 1, 1000, -560, 0.30, 0.35 }   -- ola de nieve del gran golpe
local HIT_SLAM   = { 1, 1350, -700, 0.38, 0.55 }   -- onda del aterrizaje del gran golpe: MUY fuerte
local SLAM_R     = 3.5                  -- casillas (además del medio cuerpo) que alcanza la onda
local DEATH = { dying_crack = true, dying_burst = true, dying_flee = true }
local CRACK_T, BURST_T, FLEE_T = 2.0, 0.6, 3.2

-- Ciclo de ataques por fase
local CYCLE = {
    { 'hop', 'shoot', 'hop', 'roll' },
    { 'shoot', 'roll', 'slam', 'hop', 'shoot', 'roll' },
    { 'avalanche', 'shoot', 'slam', 'roll', 'shoot' },
}

-- ── Arte ──────────────────────────────────────────────────────────────────────
local body, rollH, rollA, cracksB, cracksR, sweat, ballImg, bombBall, flee, icicleImg, shock, splat
function Snow.loadAssets()
    if body then return end
    local D = 'assets/images/bosses/snowboss/'
    body     = SpriteStrip.load(D .. 'body-Sheet.png', 16)
    rollH    = SpriteStrip.load(D .. 'roll_happy-Sheet.png', 16)
    rollA    = SpriteStrip.load(D .. 'roll_angry-Sheet.png', 16)
    -- grietas adaptadas a cada cuadro del cuerpo y de rodar (tools/ui/make_snowboss_cracks.py)
    cracksB  = SpriteStrip.load(D .. 'cracks_body-Sheet.png', 16)
    cracksR  = SpriteStrip.load(D .. 'cracks_roll-Sheet.png', 16)
    sweat    = SpriteStrip.load(D .. 'sweat-Sheet.png', 5)
    ballImg  = SpriteStrip.load(D .. 'ball.png', 8)
    bombBall = SpriteStrip.load(D .. 'bomb_ball-Sheet.png', 10)
    flee     = SpriteStrip.load(D .. 'flee-Sheet.png', 12)
    icicleImg = SpriteStrip.load(D .. 'icicle.png', 8)
    shock    = SpriteStrip.load(D .. 'shock-Sheet.png', 16)
    splat    = SpriteStrip.load(D .. 'splat-Sheet.png', 64)
end
function Snow.sizePx() return 16 * SC1, 16 * SC1 end

local function rand(a, b) return a + math.random() * (b - a) end
local overlap = Boss.overlap

-- ── Tamaño (cambia al hincharse) ─────────────────────────────────────────────
function Snow:setScale(sc)
    local feet = self.y + (self.outerH or 0) / 2
    self.sc = sc
    self.outerW, self.outerH = 13 * sc, 13 * sc
    self.innerW, self.innerH = 12 * sc, 12 * sc
    self.sprW, self.sprH = 16 * sc, 16 * sc
    self.y = feet - self.outerH / 2
end
function Snow:feetY() return self.y + self.outerH / 2 end

function Snow:initBoss()
    self.sc = SC1
    self.outerW, self.outerH = 13 * SC1, 13 * SC1
    self.innerW, self.innerH = 12 * SC1, 12 * SC1
    -- apoyada en el suelo de su celda
    self.y = self.row * T - self.outerH / 2
    self.phase, self.cycleI = 1, 0
    self.summonKey = 'sb' .. self.col .. ',' .. self.row        -- (sus bombas de reserva: def.summons)
    self.vx, self.vy, self.onGround = 0, 0, true
    self.proj, self.icicles, self.nextId = {}, {}, 0
    self.shockT, self.shockX, self.shockY = 99, 0, 0
    self.facing = -1
    self.dir = -1
    self.bounces = 0
end

-- ── Utilidades ────────────────────────────────────────────────────────────────
function Snow:zoneBounds()
    local z = self.zone
    if z then return z.x0, z.x1, z.y0, z.y1 end
    return 0, 1e9, 0, 1e9
end

function Snow:target(level)
    local best, bd
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false then
            local d = math.abs(pa.x - self.x) + math.abs(pa.y - self.y) * 0.3
            if not bd or d < bd then best, bd = pa, d end
        end
    end
    return best
end

-- Fricción del suelo que pisa (el hielo resbala: ICE_DECEL)
function Snow:groundDecel(level)
    local d = level:getDefAt(self.x, self:feetY() + 4)
    local m = d and d.mat
    if m and m.friction and m.friction < 0.5 then return ICE_DECEL end
    return SNOW_DECEL
end

local SOLID_VS = function(level, x, y)
    local d = level:getDefAt(x, y)
    return d.collision == 'solid' and TileTypes.hitboxContains(d, x, y) and d or nil
end

-- Mueve con gravedad y choques. Devuelve 'wall' (+ def del tile) si chocó de lado.
function Snow:physics(level, dt, gravity)
    local vx0 = self.vx
    if gravity ~= false then self.vy = self.vy + GRAV * dt end
    local x0 = self.x
    self.speed = 0
    self:moveAndCollide(level, self.vx * dt, self.vy * dt)
    local hit, def
    self.hitToggles = nil
    if vx0 ~= 0 and self.vx == 0 then
        hit = 'wall'
        local fx = self.x + (vx0 > 0 and 1 or -1) * (self.outerW / 2 + 4)
        for _, yy in ipairs({ self.y - self.outerH * 0.3, self.y, self.y + self.outerH * 0.35 }) do
            local d = SOLID_VS(level, fx, yy)
            local c, r = math.floor(fx / T) + 1, math.floor(yy / T) + 1
            if d and (d.switchBlock or d.breakable) then def = d; self.hitCol = c; self.hitRow = r end
            -- Activadores ON/OFF tocados (crash los cambia; nada de romper bloques)
            if d and d.toggle then
                self.hitToggles = self.hitToggles or {}
                local dup = false
                for _, h in ipairs(self.hitToggles) do if h[1] == c and h[2] == r then dup = true end end
                if not dup then self.hitToggles[#self.hitToggles + 1] = { c, r } end
            end
        end
        self.vx = vx0                                -- (quien llama decide qué pasa)
    end
    -- Paredes de la zona
    local zx0, zx1 = self:zoneBounds()
    local hw = self.outerW / 2
    if self.x - hw < zx0 then self.x = zx0 + hw; hit = hit or 'wall' end
    if self.x + hw > zx1 then self.x = zx1 - hw; hit = hit or 'wall' end
    if hit and vx0 == 0 then hit = nil end
    if self.x ~= x0 and self.onGround and math.abs(vx0) > 50 then self.facing = vx0 > 0 and 1 or -1 end
    return hit, def
end

function Snow:friction(level, dt)
    if not self.onGround then return end
    local dec = self:groundDecel(level) * dt
    if math.abs(self.vx) <= dec then self.vx = 0 else self.vx = self.vx - dec * (self.vx > 0 and 1 or -1) end
end

-- Celdas bajo sus pies (para el hielo fino)
function Snow:cellsUnder(level)
    local out = {}
    local r = math.floor((self:feetY() + 6) / T) + 1
    local c0 = math.floor((self.x - self.outerW / 2 + 4) / T) + 1
    local c1 = math.floor((self.x + self.outerW / 2 - 4) / T) + 1
    for c = c0, c1 do out[#out + 1] = { c, r } end
    return out
end

function Snow:crackUnder(level, n)
    for _, cr in ipairs(self:cellsUnder(level)) do
        if level:getDef(cr[1], cr[2]).thinIce then level:crackIce(cr[1], cr[2], n, 'pound') end
    end
end

-- Daño por contacto (rodando, aterrizando encima): 1 de vida y empujón
function Snow:hitPlayers(level, crush)
    local ob = self:getOuterBounds()
    local box = { x = ob.x - 4, y = ob.y - 4, w = ob.w + 8, h = ob.h + 8 }
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false and not pa:isInvulnerable() and overlap(pa:getOuterBounds(), box) then
            local dir = (pa.x >= self.x) and 1 or -1
            Boss.withPlayer(pa, function()
                pa:hurt(1)
                if not pa.dying then
                    if crush then pa:squash(dir) else pa:knockback(dir) end
                end
            end)
        end
    end
end

-- Golpe a un jugador (un jugador / servidor): `hit` = { vida, vx, vy, bloqueo, aturdido },
-- empujado hacia `dir`. Invulnerable o congelado: nada (ni empujón). true si le dio.
local function strike(pa, hit, dir)
    if pa.dying or pa.alive == false or pa:isInvulnerable() then return false end
    Boss.withPlayer(pa, function()
        if pa:hurt(hit[1]) or pa.dying then return end
        pa.vx, pa.vy = dir * hit[2], hit[3]
        pa.onGround, pa.crouching = false, false
        pa.gpPhase, pa.gpT = nil, 0
        pa.ctrlLockT = math.max(pa.ctrlLockT or 0, hit[4])
        if hit[5] > 0 then
            pa.stunT = math.max(pa.stunT or 0, hit[5])
            Sound.play('stunned')
        end
    end)
    return true
end
Snow.strike = strike

-- Onda del aterrizaje del gran golpe: a quien esté cerca y a ras de suelo, 1 de vida
-- y un empujón MUY fuerte hacia fuera (la caída encima ya lo aplasta: hitPlayers)
function Snow:slamWave(level)
    local reach = self.outerW / 2 + SLAM_R * T
    local floorY = self:feetY()
    for _, pa in ipairs(level.players or {}) do
        local ob = pa:getOuterBounds()
        local dx = pa.x - self.x
        if math.abs(dx) <= reach and ob.y + ob.h >= floorY - 1.6 * T and ob.y <= floorY + 8 then
            strike(pa, HIT_SLAM, (dx >= 0) and 1 or -1)
        end
    end
end

-- Lo que lanza (bolas, carámbanos) y las olas de nieve contra los jugadores
function Snow:hitWithShots(level)
    local players = level.players or {}
    if #players == 0 then return end
    for i = #self.proj, 1, -1 do
        local b = self.proj[i]
        local box = { x = b.x - BALL_HIT / 2, y = b.y - BALL_HIT / 2, w = BALL_HIT, h = BALL_HIT }
        for _, pa in ipairs(players) do
            if overlap(pa:getOuterBounds(), box) then
                local dir = (b.vx > 30 and 1) or (b.vx < -30 and -1) or ((pa.x >= b.x) and 1 or -1)
                if strike(pa, HIT_BALL, dir) then
                    table.remove(self.proj, i)
                    if b.kind == 2 then
                        self:dropBomb(level, b.x, b.y + 20)
                    else
                        Sound.play('snowSplat')
                        Entity.emitFx('snow_puff', b.x, b.y)
                    end
                    break
                end
            end
        end
    end
    for i = #self.icicles, 1, -1 do
        local c = self.icicles[i]
        if c.stage == 2 then
            local box = { x = c.x - 12, y = c.y + 4, w = 24, h = 44 }
            for _, pa in ipairs(players) do
                if overlap(pa:getOuterBounds(), box) and strike(pa, HIT_ICICLE, (pa.x >= c.x) and 1 or -1) then
                    table.remove(self.icicles, i)
                    Sound.play('iceBreak', 1.1, 0.8)
                    Entity.emitFx('ice_break', c.x, c.y + 40)
                    break
                end
            end
        end
    end
    if (self.shockT or 99) < SHOCK_LIFE then
        local d = self.shockT * SHOCK_SPD
        for _, sd in ipairs({ -1, 1 }) do
            local x = self.shockX + sd * d
            local box = { x = x - 22, y = self.shockY - 30, w = 44, h = 30 }
            for _, pa in ipairs(players) do
                if overlap(pa:getOuterBounds(), box) then strike(pa, HIT_WAVE, sd) end
            end
        end
    end
end

-- Cambia una celda (un jugador / servidor) y la manda a los clientes ('set')
local function placeTile(level, c, r, id)
    if level.canBreak == false then return end
    local raw = level:getRaw(c, r)
    local _, water = TileCodec.decode(raw)
    local new = TileCodec.encode(id, water)
    level:setTileRaw(c, r, new)
    level.brokenQueue = level.brokenQueue or {}
    table.insert(level.brokenQueue, { c, r, new, 'set' })
end

-- Vuelve a congelar el lago (las celdas que eran hielo fino al empezar)
function Snow:refreeze(level)
    if not self.lake then return end
    local thin = TileTypes.byName.thin_ice
    local any = false
    for _, cr in ipairs(self.lake) do
        local d = level:getDef(cr[1], cr[2])
        if d.name ~= 'thin_ice' and (d.collision ~= 'solid') then
            placeTile(level, cr[1], cr[2], thin.id)
            Entity.emitFx('ice_freeze', (cr[1] - 0.5) * T, (cr[2] - 0.5) * T)
            any = true
        elseif d.thinIce and d.name ~= 'thin_ice' then
            placeTile(level, cr[1], cr[2], thin.id)
            any = true
        end
    end
    if any then Sound.play('snowBreath') end
end

-- Fase 3: rodea cada Activador de la zona con nieve prensada (rompible) en las 8
-- casillas de alrededor, SOLO donde hay hueco: casillas vacías de verdad (sin bloque,
-- agua, pinchos, mini bloques, cuerpos sólidos como los Congeladores, ni jugadores
-- dentro). Nunca sustituye nada del nivel.
local AROUND = { { 0, 1 }, { 0, -1 }, { -1, 0 }, { 1, 0 }, { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }
local SubTiles
function Snow:freeCell(level, c, r)
    if c < 1 or r < 1 or c > level.tileW or r > level.tileH then return false end
    local raw = level:getRaw(c, r)
    local id, water = TileCodec.decode(raw)
    if water or TileCodec.hasSpikes(raw) or level:getDef(c, r).name ~= 'empty' or id ~= 0 then return false end
    SubTiles = SubTiles or require 'src/world/SubTiles'
    if SubTiles.solidInCell(level, c, r) then return false end
    local box = { x = (c - 1) * T, y = (r - 1) * T, w = T, h = T }
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and overlap(pa:getOuterBounds(), box) then return false end
    end
    for _, e in ipairs(level.liveEntities or {}) do
        if e ~= self and e.alive and e.solidFull and e.getOuterBounds and overlap(e:getOuterBounds(), box) then return false end
    end
    return true
end

function Snow:bury(level)
    local zx0, zx1, zy0, zy1 = self:zoneBounds()
    local c0, c1 = math.floor(zx0 / T) + 1, math.floor((zx1 - 1) / T) + 1
    local r0, r1 = math.floor(zy0 / T) + 1, math.floor((zy1 - 1) / T) + 1
    local packed = TileTypes.byName.packed_snow
    if not packed then return end
    -- (los activadores pueden estar en la pared, justo fuera de la zona)
    for r = math.max(1, r0 - 1), math.min(level.tileH, r1 + 1) do
        for c = math.max(1, c0 - 1), math.min(level.tileW, c1 + 1) do
            local d = level:getDef(c, r)
            if d.name == 'switch_on' or d.name == 'switch_off' then
                for _, o in ipairs(AROUND) do
                    local cc, rr = c + o[1], r + o[2]
                    if self:freeCell(level, cc, rr) then
                        placeTile(level, cc, rr, packed.id)
                        Entity.emitFx('snow_puff', (cc - 0.5) * T, (rr - 0.5) * T)
                    end
                end
            end
        end
    end
end

-- ── Pelea ─────────────────────────────────────────────────────────────────────
function Snow:onFightStart(n)
    self.state, self.deadTimer = 'idle', 0
    self.cycleI = 0
    self.lake = nil                      -- (se apunta en el primer paso: ver findLake)
end

-- El lago: las celdas de hielo fino de la zona al empezar (para volver a congelarlas)
function Snow:findLake(level)
    self.lake = {}
    if not self.zone then return end                       -- (sin zona: nada que buscar)
    local zx0, zx1, zy0, zy1 = self:zoneBounds()
    for r = math.floor(zy0 / T) + 1, math.floor((zy1 - 1) / T) + 2 do
        for c = math.floor(zx0 / T) + 1, math.floor((zx1 - 1) / T) + 1 do
            if level:getDef(c, r).thinIce then self.lake[#self.lake + 1] = { c, r } end
        end
    end
end

function Snow:phaseFor()
    local p = self.props
    local k = self.hp / math.max(1, self.hpMax)
    if k <= (p.phase3 or 0.25) then return 3 end
    if k <= (p.phase2 or 0.6) then return 2 end
    return 1
end

function Snow:enter(st)
    self.state, self.deadTimer = st, 0
end

function Snow:nextAttack(level)
    if self:phaseFor() > self.phase then
        self:enter('phase_up')
        self.vx = 0
        return
    end
    local cyc = CYCLE[self.phase]
    self.cycleI = self.cycleI % #cyc + 1
    local a = cyc[self.cycleI]
    local pa = self:target(level)
    self.dir = (pa and pa.x < self.x) and -1 or 1
    if a == 'hop' then
        local zx0, zx1 = self:zoneBounds()
        local tx = pa and (pa.x + rand(-1, 1) * T) or self.x
        tx = math.max(zx0 + self.outerW / 2, math.min(zx1 - self.outerW / 2, tx))
        self.vx = (tx - self.x) / HOP_AIR
        self.vy = -HOP_VY
        self.onGround = false
        Sound.play('snowLand', 1.3, 0.5)
        self:enter('hop')
    elseif a == 'shoot' then
        self.shots = (self.phase == 3) and 5 or 3
        self.shotN = 0
        self:enter('shoot')
    elseif a == 'roll' then
        self.bounces = (self.phase >= 2) and 1 or 0
        self:enter('windup')
    elseif a == 'slam' then
        local zx0, zx1 = self:zoneBounds()
        local tx = pa and pa.x or self.x
        tx = math.max(zx0 + self.outerW / 2, math.min(zx1 - self.outerW / 2, tx))
        self.vx = (tx - self.x) / 0.62
        self.vy = -SLAM_VY
        self.onGround = false
        Sound.play('snowSpit', 0.6)
        self:enter('slam_up')
    elseif a == 'avalanche' then
        self.bounces = 99
        self:enter('windup')
        self.avalanche, self.avalT = true, 0
    end
end

-- Escupe una bola (kind 1 = nieve, 2 = bola-bomba) hacia un jugador, en arco
function Snow:spit(level, kind)
    local pa = self:target(level)
    local mx, my = self.x + self.facing * self.outerW * 0.2, self.y - self.outerH * 0.05
    local tx = pa and (pa.x + rand(-1.5, 1.5) * T) or (self.x + self.facing * 4 * T)
    local ty = pa and (pa.y + 30) or self:feetY()
    local tf = math.max(0.55, math.min(1.1, math.abs(tx - mx) / 700 + 0.45))
    local vx = (tx - mx) / tf
    local vy = (ty - my - 0.5 * GRAV * tf * tf) / tf
    self.nextId = self.nextId % 999 + 1
    table.insert(self.proj, { id = self.nextId, x = mx, y = my, vx = vx, vy = vy, kind = kind, t = 0 })
    self.facing = (vx >= 0) and 1 or -1
    Sound.play('snowSpit', kind == 2 and 0.85 or 1)
    Entity.emitFx('snow_puff', mx, my)
end

-- Bombas de reserva (def.summons): la bola-bomba al caer se convierte en una
function Snow:freeBomb(level)
    for _, e in ipairs(level.liveEntities or {}) do
        if e.summonOf == self.summonKey and not e.alive then return e end
    end
end

function Snow:dropBomb(level, x, y)
    local e = self:freeBomb(level)
    if not e then Entity.emitFx('snow_puff', x, y); return end
    local h = e.home
    h.x, h.y, h.vx = x, y - e.outerH / 2 - 2, 0
    e:resetToHome()
    e.alive = true
    e:throw(0, -120, true, self.props.bombFuse or 2.4)
    Entity.emitFx('snow_puff', x, y)
end

-- Una bomba pateada que le toca explota ya (si no, la atravesaría: su cuerpo no
-- es sólido para las bombas)
function Snow:bombContact(level)
    local ob = self:getOuterBounds()
    for _, e in ipairs(level.liveEntities or {}) do
        if e.summonOf == self.summonKey and e.alive and e.state == 'lit' and not e.thrown
           and math.abs(e.vx or 0) > 120 and overlap(ob, e:getOuterBounds()) and e.dieBurst then
            e:dieBurst()
        end
    end
end

function Snow:updateProjectiles(level, dt)
    for i = #self.proj, 1, -1 do
        local b = self.proj[i]
        b.t = b.t + dt
        b.vy = b.vy + GRAV * dt
        local nx, ny = b.x + b.vx * dt, b.y + b.vy * dt
        local gone = b.t > 4 or ny > level.heightPx
        if not gone then
            local landT, landY
            if b.vy > 0 then landT, landY = level:landingCross(nx, b.y + 10, ny + 10) end
            if landT or level:collisionAt(nx, ny) then
                gone = true
                local yy = landY and (landY - 10) or b.y
                if b.kind == 2 then
                    self:dropBomb(level, nx, landY or b.y)
                else
                    Sound.play('snowSplat')
                    Entity.emitFx('snow_puff', nx, yy)
                end
            end
        end
        if gone then table.remove(self.proj, i) else b.x, b.y = nx, ny end
    end
end

function Snow:spawnIcicles(level, n)
    local zx0, zx1, zy0 = self:zoneBounds()
    local xs = {}
    for _ = 1, n * 4 do
        if #xs >= n then break end
        local x = rand(zx0 + T * 0.5, zx1 - T * 0.5)
        local ok = math.abs(x - self.x) > self.outerW
        for _, o in ipairs(xs) do if math.abs(o - x) < T * 1.5 then ok = false end end
        if ok then xs[#xs + 1] = x end
    end
    -- un carámbano encima del jugador más cercano, para que haya que moverse
    local pa = self:target(level)
    if pa and #xs > 0 then xs[1] = pa.x end
    for i, x in ipairs(xs) do
        self.nextId = self.nextId % 999 + 1
        table.insert(self.icicles, { id = self.nextId, x = math.floor(x), y = zy0 + 32, vy = 0, t = -(i - 1) * 0.12, stage = 1 })
    end
end

function Snow:updateIcicles(level, dt)
    for i = #self.icicles, 1, -1 do
        local c = self.icicles[i]
        c.t = c.t + dt
        local gone = false
        if c.stage == 1 then
            if c.t >= ICICLE_WARN then c.stage, c.t = 2, 0 end
        else
            c.vy = c.vy + GRAV * 1.2 * dt
            local ny = c.y + c.vy * dt
            local landT, landY = level:landingCross(c.x, c.y + 30, ny + 30)
            if landT or ny > level.heightPx then
                gone = true
                Sound.play('iceBreak', 1.1, 0.8)
                Entity.emitFx('ice_break', c.x, (landY or ny) - 6)
            else
                c.y = ny
            end
        end
        if gone then table.remove(self.icicles, i) end
    end
end

-- Cajas de peligro: bolas, carámbanos cayendo, olas de nieve (1 de vida)
function Snow:getHazardBoxes()
    local out = {}
    for _, b in ipairs(self.proj or {}) do
        out[#out + 1] = { x = b.x - BALL_HIT / 2, y = b.y - BALL_HIT / 2, w = BALL_HIT, h = BALL_HIT, effect = 'hurt' }
    end
    for _, c in ipairs(self.icicles or {}) do
        if c.stage == 2 then out[#out + 1] = { x = c.x - 12, y = c.y + 4, w = 24, h = 44, effect = 'hurt' } end
    end
    if (self.shockT or 99) < SHOCK_LIFE then
        local d = self.shockT * SHOCK_SPD
        for _, s in ipairs({ -1, 1 }) do
            local x = self.shockX + s * d
            out[#out + 1] = { x = x - 22, y = self.shockY - 30, w = 44, h = 30, effect = 'hurt' }
        end
    end
    return out
end

-- ── Interacción ───────────────────────────────────────────────────────────────
local VULN = { dizzy = true, frozen = true }
function Snow:isActive() return Boss.isActive(self) and not DEATH[self.state] end
function Snow:isDying() return DEATH[self.state] == true or Boss.isDying(self) end
function Snow:isVulnerable() return self:isActive() and (VULN[self.state] == true or self.blastHit == true) end
function Snow:releasesZone() return self.state == 'dying_flee' or self.state == 'dead' end

function Snow:stomp()
    local frozen = self.state == 'frozen'
    if self:damage(1, 'stomp') and frozen and not self:isDying() then self:thaw() end
end
function Snow:pound(pa)
    if self.state == 'frozen' then
        if self:damage(3, 'pound') and not self:isDying() then self:thaw() end
        return
    end
    self:damage(2, 'pound')
end

function Snow:onDamaged(n, kind)
    if self:isDying() then return end
    if self.blastHit then
        self.blastHit = nil
        self:enter('dizzy')
        return
    end
    if self.state ~= 'frozen' and not self:phaseNow() then self:enter('recover'); self.vx = 0 end
end

-- Si el golpe la dejó por debajo del umbral de fase, cambia YA (no espera a su
-- siguiente ataque: un Congelador que la vuelve a congelar en cada pausa la dejaría
-- en la fase 1 hasta morir). true si cambió.
function Snow:phaseNow()
    if self:isDying() or self:phaseFor() <= self.phase then return false end
    self:enter('phase_up')
    self.vx = 0
    return true
end

-- Derrotada: muerte propia (se agrieta → revienta → la bolita huye)
function Snow:defeat()
    self.hp, self.inv, self.ghost = 0, 0, false
    self.proj, self.icicles, self.avalanche, self.blastHit = {}, {}, nil, nil
    self.crackN = nil
    self.vx = 0
    self:enter('dying_crack')
    self:onDefeat()
end

-- Una bomba explotó cerca (Explosions.blast): 1 de daño y mareada
function Snow:onBlastHit(x, y, d)
    if not self:isActive() or self.inv > 0 or self.state == 'phase_up' then return end
    self.blastHit = true
    if not self:damage(1, 'blast') then self.blastHit = nil end
end

-- ── Congelador ────────────────────────────────────────────────────────────────
local NO_FREEZE = { frozen = true, phase_up = true }
function Snow:canFreeze()
    return self:isActive() and not NO_FREEZE[self.state] and self.inv <= 0
end
function Snow:freeze(t)
    if not self:canFreeze() then return false end
    self.frozenFor = math.max(FROZEN_T, (t or 0) + 1)
    self.avalanche = nil
    self:enter('frozen')
    Sound.play('cryoFreeze')
    Entity.emitFx('ice_freeze', self.x, self.y)
    return true
end
function Snow:thaw()
    Sound.play('cryoFree')
    Entity.emitFx('ice_shatter', self.x, self.y)
    if self:phaseNow() then return end
    self:enter('recover')
    self.vx = 0
end

function Snow:onPlayerDeath(pa)
    if self:isActive() then Sound.play('snowLaugh') end
end

-- ── Update ────────────────────────────────────────────────────────────────────
local ROLLING = { roll = true, slide = true }

function Snow:updateBoss(dt, level)
    if self.state == 'dormant' then return end           -- (antes de la pelea no hace nada)
    if not self.lake then self:findLake(level) end
    self.deadTimer = self.deadTimer + dt
    local st, t = self.state, self.deadTimer
    if self.shockT < 10 then self.shockT = self.shockT + dt end
    self:updateProjectiles(level, dt)
    self:updateIcicles(level, dt)
    if level.canBreak ~= false then self:hitWithShots(level) end   -- (el cliente online no decide golpes)
    if self:isActive() then self:bombContact(level) end

    if st == 'fight' then self:enter('idle'); return end

    if st == 'idle' then
        self:physics(level, dt); self:friction(level, dt)
        if t >= IDLE_T[self.phase] and self.onGround then self:nextAttack(level) end

    elseif st == 'hop' then
        local was = self.onGround
        self:physics(level, dt)
        if self.onGround and self.vy >= 0 and t > 0.1 then
            self:enter('land')
            Sound.play('snowLand')
            Entity.emitFx('snow_puff', self.x, self:feetY())
            Entity.emitFx('shake_small', self.x, self.y)
            self:crackUnder(level, self.phase >= 2 and 2 or 1)
            self:hitPlayers(level, true)
            self.vx = self.vx * 0.3
        end

    elseif st == 'land' then
        self:physics(level, dt); self:friction(level, dt)
        if t >= LAND_T then self:enter('idle') end

    elseif st == 'shoot' then
        self:physics(level, dt); self:friction(level, dt)
        local due = math.floor((t - SHOOT_WIND) / SHOOT_GAP) + 1
        while t >= SHOOT_WIND and self.shotN < math.min(self.shots, due) do
            self.shotN = self.shotN + 1
            local bombs = (self.phase == 2 and self.shotN == 2) or (self.phase == 3 and (self.shotN == 2 or self.shotN == 4))
            self:spit(level, bombs and 2 or 1)
        end
        if t >= SHOOT_WIND + self.shots * SHOOT_GAP + 0.3 then self:enter('idle') end

    elseif st == 'windup' then
        self:physics(level, dt); self:friction(level, dt)
        local pa = self:target(level)
        if pa then self.dir = (pa.x < self.x) and -1 or 1 end
        self.facing = self.dir
        if t >= WINDUP_T[self.phase] then
            self:enter('roll')
            self.vx = self.dir * 120
            Sound.play('snowSpit', 0.5)
        end

    elseif st == 'roll' then
        local spd = ROLL_SPD[self.phase] * (self.avalanche and 1.08 or 1)
        self.vx = self.vx + self.dir * ROLL_ACC * dt
        if math.abs(self.vx) > spd then self.vx = self.dir * spd end
        local hit, def = self:physics(level, dt)
        self:hitPlayers(level)
        if hit then self:crash(level, def) end
        if self.state == 'roll' then
            self.avalT = (self.avalT or 0) + dt
            if self.avalanche and self.avalT >= AVAL_T then
                self.avalanche = nil; self:enter('slide')
            elseif not self.avalanche and t >= ROLL_MAX_T then
                self:enter('slide')
            end
        end

    elseif st == 'slide' then
        local hit, def = self:physics(level, dt)
        self:friction(level, dt)
        if math.abs(self.vx) > 200 then self:hitPlayers(level) end
        if hit then self:crash(level, def) end
        if self.state == 'slide' and self.vx == 0 then self:enter('recover') end

    elseif st == 'dizzy' then
        self:physics(level, dt); self:friction(level, dt)
        if t >= DIZZY_T then self:enter('recover') end

    elseif st == 'frozen' then
        local hit = self:physics(level, dt)          -- (resbala dentro del bloque de hielo)
        self:friction(level, dt)
        if hit then self.vx = 0 end
        if t >= (self.frozenFor or FROZEN_T) then self:thaw() end

    elseif st == 'recover' then
        self:physics(level, dt); self:friction(level, dt)
        if t >= RECOVER_T then self:enter('idle') end

    elseif st == 'slam_up' then
        self:physics(level, dt)
        if self.vy >= 0 then
            self.vx, self.vy = 0, 0
            self:enter('slam_hold')
        end

    elseif st == 'slam_hold' then
        if t >= SLAM_HOLD then
            self.vy = SLAM_FALL
            self:enter('slam_fall')
        end

    elseif st == 'slam_fall' then
        self:physics(level, dt, false)
        if self.onGround then
            self:enter('slam_land')
            self.vx, self.vy = 0, 0
            Sound.play('snowSlam')
            Entity.emitFx('snow_slam', self.x, self:feetY())
            Entity.emitFx('shake_big', self.x, self.y)
            self.shockT, self.shockX, self.shockY = 0, math.floor(self.x), math.floor(self:feetY())
            self:crackUnder(level, 2)
            self:hitPlayers(level, true)
            self:slamWave(level)
            self:spawnIcicles(level, (self.phase == 3) and 5 or 3)
        end

    elseif st == 'slam_land' then
        self:physics(level, dt)
        if t >= SLAM_LAND then self:enter('idle') end

    elseif st == 'phase_up' then
        self:physics(level, dt); self:friction(level, dt)
        if t >= 0.3 and not self.roared then
            self.roared = true
            Sound.play('snowRoar')
            Entity.emitFx('shake_roar', self.x, self.y)
            Entity.emitFx('frost_breath', self.x, self.y)
            self:refreeze(level)
        end
        if self.phase == 1 and t >= 0.3 then
            -- se hincha (la escala va en el snapshot)
            local k = math.min(1, (t - 0.3) / 0.6)
            local sc = SC1 + (SC2 - SC1) * k
            if math.floor(sc) ~= self.sc then self:setScale(math.floor(sc)) end
        end
        if t >= PHASE_T then
            self.roared = nil
            self.phase = math.min(3, self.phase + 1)
            self.cycleI = 0
            if self.phase == 3 then self:bury(level) end
            self:enter('idle')
        end

    elseif st == 'dying_crack' then
        local n = math.floor(t / 0.6)
        if n > (self.crackN or -1) and n < 3 then
            self.crackN = n
            Sound.play('snowCrack', 1 - n * 0.08)
            Entity.emitFx('shake_small', self.x, self.y)
        end
        self:physics(level, dt); self:friction(level, dt)
        if t >= CRACK_T then
            self:enter('dying_burst')
            Sound.play('snowBurst')
            Entity.emitFx('snow_burst', self.x, self.y)
            Entity.emitFx('shake_big', self.x, self.y)
            self:refreeze(level)
        end

    elseif st == 'dying_burst' then
        if t >= BURST_T then
            local zx0, zx1 = self:zoneBounds()
            self.fleeDir = (self.x - zx0 < zx1 - self.x) and -1 or 1
            self.fleeY = self:feetY()
            self:enter('dying_flee')
            Sound.play('snowFlee')
        end

    elseif st == 'dying_flee' then
        self.x = self.x + (self.fleeDir or 1) * 300 * dt
        if t >= FLEE_T then self.state, self.alive = 'dead', false end
    end
end

-- El choque al rodar: compuerta → mareada; pared (o la nieve prensada) → rebota (fases 2+, una vez; la avalancha siempre) o se para
function Snow:crash(level, def)
    local speed = math.abs(self.vx)
    Sound.play('snowCrash')
    Entity.emitFx('snow_crash', self.x + self.dir * self.outerW / 2, self.y)
    Entity.emitFx('shake_small', self.x, self.y)
    self:toggleHit(level)
    if def and def.switchBlock and speed >= CRASH_SPD then
        self.avalanche = nil
        self.vx = -self.dir * 140
        self.vy = -380
        Sound.play('snowDizzy')
        self:enter('dizzy')
        return
    end
    if self.bounces > 0 then
        self.bounces = self.bounces - 1
        self.dir = -self.dir
        self.vx = self.dir * math.max(260, speed * 0.85)
        self.deadTimer = math.min(self.deadTimer, ROLL_MAX_T - 1.2)
        if self.state ~= 'roll' then self:enter('roll') end
        return
    end
    self.avalanche = nil
    self.vx = -self.dir * 160
    self.vy = -300
    self:enter('recover')
end

-- Rodando contra un Activador ON/OFF: lo cambia, como un cabezazo (y sus Bloques
-- ON/OFF y Congeladores conectados reaccionan). Solo activadores: nunca rompe bloques
-- rompibles, nieve prensada ni hielo. Una vez por choque (physics apunta las celdas).
function Snow:toggleHit(level)
    for _, cr in ipairs(self.hitToggles or {}) do
        if level:getDef(cr[1], cr[2]).toggle and level:hitTile(cr[1], cr[2], 'head') == 'toggle' then
            Entity.emitFx('switch_hit', (cr[1] - 1) * T, (cr[2] - 1) * T)
            Sound.play(level:getDef(cr[1], cr[2]).name == 'switch_on' and 'switchOn' or 'switchOff')
        end
    end
    self.hitToggles = nil
end

-- ── Entrada ──────────────────────────────────────────────────────────────────
-- Recorrido: entra arriba a la izquierda de la zona, bota en lo primero que encuentra
-- debajo (una plataforma), luego en el suelo a medio camino y llega a su sitio,
-- creciendo (escala 0.3 → 1). Los puntos de bote se calculan al empezar (un jugador /
-- servidor, con el nivel); el cliente solo dibuja x, y y la escala sale del tiempo.
local ROLL_IN = 2.2
-- Escupitajo a la cámara: coge aire (SPIT_WIND), escupe (SPIT_AT: boca abierta, nube),
-- la bola vuela hacia la pantalla creciendo y se estampa (SPLAT_AT)
local SPIT_WIND, SPIT_AT, SPLAT_AT = 3.2, 3.45, 3.78
Snow.SPIT_AT, Snow.SPLAT_AT = SPIT_AT, SPLAT_AT

-- Boca en el cuadro de escupir (arte 16x16, origen en los pies 8,15)
function Snow:mouthPos()
    local sc = self.sc or SC1
    return self.x - 0.5 * sc, self:feetY() - 6 * sc
end
local function surfaceBelow(level, x, y0, y1)
    for y = y0, y1, 8 do
        if level:collisionAt(x, y, true) then return math.floor(y / 8) * 8 end
    end
    return y1
end

function Snow:introScale(t) return 0.3 + 0.7 * math.min(1, t / ROLL_IN) end

function Snow:planIntro(level)
    local zx0, _, zy0, zy1 = self:zoneBounds()
    local hx, feet = self.home.x, self.home.y + self.outerH / 2
    local x1 = zx0 + 3.5 * T
    local x2 = (x1 + hx) / 2
    self.introPts = {
        { zx0 + 0.6 * T, zy0 + 0.4 * T },
        { x1, surfaceBelow(level, x1, zy0 + T, zy1) },
        { x2, surfaceBelow(level, x2, zy0 + T, zy1) },
        { hx, feet },
    }
end

-- Posición (centro) a los t s: arcos entre los puntos de bote (el centro de la bola
-- queda a 6.5 px de arte * escala por encima del suelo)
function Snow:introPath(t)
    local pts = self.introPts
    if not pts then return self.home.x, self.home.y end
    local k = math.min(1, t / ROLL_IN)
    local seg = math.min(2.999, k * 3)
    local i = math.floor(seg)
    local u = seg - i
    local a, b = pts[i + 1], pts[i + 2]
    local x = a[1] + (b[1] - a[1]) * u
    local h = ({ 0.4, 2.4, 1.2 })[i + 1] * T
    local base = a[2] + (b[2] - a[2]) * u
    local y = base - h * 4 * u * (1 - u)
    if i == 0 then y = a[2] + (b[2] - a[2]) * u * u end          -- (cae desde arriba)
    local sc = SC1 * self:introScale(t)
    return x, y - 6.5 * sc
end

function Snow:introFocus()
    local zx0, zx1, zy0, zy1 = self:zoneBounds()
    return (zx0 + zx1) / 2, (zy0 + zy1) / 2
end

function Snow:onIntroStart(level, players)
    self.introStep = 0
    self:planIntro(level)
    self.x, self.y = self:introPath(0)
    Sound.play('snowIntroRoll')
end

function Snow:updateIntro(dt, level, t)
    if t < ROLL_IN then
        self.x, self.y = self:introPath(t)
        local seg = math.floor(math.min(2.999, t / ROLL_IN * 3))
        if seg > (self.introStep or 0) then
            self.introStep = seg
            Sound.play('snowLand', 1.3 - seg * 0.1, 0.5 + seg * 0.2)
            Entity.emitFx('snow_puff', self.x, self.y + self.outerH / 2)
        end
    else
        self.x, self.y = self.home.x, self.home.y
        if (self.introStep or 0) < 3 then
            self.introStep = 3
            Sound.play('snowSlam', 1.1)
            Entity.emitFx('snow_slam', self.x, self:feetY())
            Entity.emitFx('shake_big', self.x, self.y)
            self:crackUnder(level, 1)
        end
        if t >= 2.6 and self.introStep < 4 then self.introStep = 4; Sound.play('snowLaugh') end
        if t >= SPIT_WIND and self.introStep < 5 then self.introStep = 5; Sound.play('snowBreath', 1.2, 0.6) end   -- (coge aire)
        if t >= SPIT_AT and self.introStep < 6 then
            self.introStep = 6
            Sound.play('snowSpit', 0.9)
            local mx, my = self:mouthPos()
            Entity.emitFx('snow_puff', mx, my)
            Entity.emitFx('cryo_puff', mx, my)
        end
        if t >= SPLAT_AT and self.introStep < 7 then
            self.introStep = 7
            Sound.play('snowSplat', 0.8)
            Entity.emitFx('shake_small', self.x, self.y)
        end
    end
end

-- ── Red ───────────────────────────────────────────────────────────────────────
function Snow:netPackExtra()
    local out = { self.phase, self.sc, math.floor(math.min(self.shockT, 99) * 100), self.shockX, self.shockY,
                  self.dir or 1, math.floor((self.frozenFor or FROZEN_T) * 10), #self.proj }
    for _, b in ipairs(self.proj) do
        out[#out + 1] = b.id; out[#out + 1] = math.floor(b.x); out[#out + 1] = math.floor(b.y); out[#out + 1] = b.kind
    end
    out[#out + 1] = #self.icicles
    for _, c in ipairs(self.icicles) do
        out[#out + 1] = c.id; out[#out + 1] = c.x; out[#out + 1] = math.floor(c.y); out[#out + 1] = c.stage
        out[#out + 1] = math.floor(c.t * 100)
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

function Snow:netApplyExtra(a, b, f)
    if type(b[1]) ~= 'number' then return end
    self.phase = b[1]
    if b[2] ~= self.sc then self:setScale(b[2]) end
    self.shockT, self.shockX, self.shockY = b[3] / 100, b[4], b[5]
    self.dir, self.frozenFor = b[6], b[7] / 10
    local pb, k = readList(b, 8, 4)
    local pa = (type(a[8]) == 'number') and readList(a, 8, 4) or {}
    local prev = {}
    for _, e in ipairs(pa) do if e[1] then prev[e[1]] = e end end
    self.proj = {}
    for _, e in ipairs(pb) do
        local x, y = e[2], e[3]
        local o = prev[e[1]]
        if o and type(o[2]) == 'number' and type(o[3]) == 'number' then x, y = o[2] + (x - o[2]) * f, o[3] + (y - o[3]) * f end
        self.proj[#self.proj + 1] = { id = e[1], x = x, y = y, kind = e[4] }
    end
    local ib = readList(b, k, 5)
    local ka = (type(a[8]) == 'number') and (8 + 1 + (a[8] or 0) * 4) or nil
    local ia = ka and readList(a, ka, 5) or {}
    local iprev = {}
    for _, e in ipairs(ia) do if e[1] then iprev[e[1]] = e end end
    self.icicles = {}
    for _, e in ipairs(ib) do
        local y = e[3]
        local o = iprev[e[1]]
        if o and o[4] == e[4] and type(o[3]) == 'number' then y = o[3] + (y - o[3]) * f end
        self.icicles[#self.icicles + 1] = { id = e[1], x = e[2], y = y, stage = e[4], t = e[5] / 100 }
    end
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
local Particles
local function emit(kind, x, y, o)
    Particles = Particles or require 'src/fx/Particles'
    Particles.emit(kind, x, y, o)
end

-- Fila de arriba (arte) de cada cuadro del cuerpo: el sudor y las estrellas de mareo se
-- apoyan en la cabeza también cuando está aplastada (se mide del PNG: solo dibujo)
local bodyTop
local function topRow(fr)
    if not bodyTop then
        bodyTop = {}
        local ok, data = pcall(love.image.newImageData, 'assets/images/bosses/snowboss/body-Sheet.png')
        if ok and data then
            for i = 1, math.floor(data:getWidth() / 16) do
                for y = 0, 15 do
                    local found = false
                    for x = (i - 1) * 16, i * 16 - 1 do
                        local _, _, _, a = data:getPixel(x, y)
                        if a > 0 then found = true; break end
                    end
                    if found then bodyTop[i] = y; break end
                end
            end
        end
    end
    return bodyTop[fr] or 1
end

-- Cuadro del cuerpo (1-12) o, rodando, de la tira de rodar
function Snow:pose()
    local st, t = self.state, self.deadTimer or 0
    local angry = (self.phase or 1) >= 2
    local b = angry and 4 or 0
    if st == 'roll' or st == 'slide' or (st == 'intro' and t < ROLL_IN) then
        local r = 7 * self.sc
        local ang = -(self.x / r)
        return 'roll', math.floor(ang / (math.pi / 4)) % 8 + 1
    end
    if st == 'dizzy' then return 'body', 11 + math.floor(t * 6) % 2 end
    if st == 'dying_crack' then return 'body', 10 end
    if self.inv > 0 and not self.ghost and self.state == 'recover' then return 'body', angry and 10 or 9 end
    if st == 'land' or st == 'slam_land' then return 'body', b + ((t < 0.12) and 3 or 2) end
    if st == 'windup' then return 'body', b + 3 end
    if st == 'shoot' then
        local u = t - SHOOT_WIND
        if u < 0 then return 'body', b + 2 end
        return 'body', b + ((u % SHOOT_GAP) < SHOOT_GAP * 0.6 and 4 or 1)
    end
    if st == 'phase_up' then return 'body', 8 end
    if st == 'slam_hold' then return 'body', b + 4 end
    if st == 'intro' or st == 'ready' then
        if t >= 2.2 and t < 2.45 then return 'body', 3 end
        if t >= 2.6 and t < SPIT_WIND then return 'body', (math.floor((t - 2.6) * 8) % 2 == 0) and 4 or 2 end
        if t >= SPIT_WIND and t < SPIT_AT then return 'body', (t < SPIT_WIND + 0.1) and 2 or 3 end   -- coge aire
        if t >= SPIT_AT and t < SPLAT_AT + 0.15 then return 'body', 4 end                          -- boca abierta
        return 'body', 1
    end
    return 'body', b + 1
end

function Snow:drawBody(camX, camY, alpha)
    local kind, fr = self:pose()
    local sc = self.sc
    local st, t = self.state, self.deadTimer or 0
    if st == 'intro' and t < ROLL_IN then sc = math.max(2, math.floor(self.sc * self:introScale(t) + 0.5)) end
    local fx = math.floor(self.x - camX)
    local fy = math.floor(self.y - camY + (self.outerH / 2))         -- pies
    if st == 'intro' and t < ROLL_IN then fy = math.floor(self.y - camY + 6.5 * SC1 * self:introScale(t)) end
    -- temblor (carga, fase, grietas) y saltitos de risa
    local sh = 0
    if st == 'windup' then sh = 2 + math.floor(t / WINDUP_T[self.phase or 1] * 3) end
    if st == 'phase_up' or st == 'dying_crack' then sh = 3 end
    if (self.phase or 1) == 3 and st == 'idle' then sh = 1 end
    if st == 'intro' and t >= SPIT_WIND and t < SPIT_AT then                    -- coge aire: tiembla cada vez más
        sh = 1 + math.floor((t - SPIT_WIND) / (SPIT_AT - SPIT_WIND) * 2.99)
    end
    if st == 'intro' and t >= SPIT_AT and t < SPIT_AT + 0.1 then fy = fy - sc end  -- (retroceso al escupir)
    if sh > 0 then fx = fx + math.floor((math.random() * 2 - 1) * sh + 0.5); fy = fy + math.floor((math.random() * 2 - 1) * sh * 0.5 + 0.5) end
    local r, g, bl = 1, 1, 1
    if self:flashRed() then r, g, bl = 1, 0.35, 0.35 end
    love.graphics.setColor(r, g, bl, alpha)
    local strip = (kind == 'roll') and (((self.phase or 1) >= 2) and rollA or rollH) or body
    love.graphics.draw(strip.image, strip.quads[fr], fx, fy, 0, sc, sc, 8, 15)
    -- Grietas (fase 3; muriendo cada vez más)
    local ck = nil
    if st == 'dying_crack' then ck = math.min(3, 1 + math.floor(t / (CRACK_T / 3)))
    elseif (self.phase or 1) >= 3 then ck = 2 end
    if ck then
        -- (una tira por cuadro: siguen el aplastamiento y giran al rodar)
        local cs, n = cracksB, 12
        if kind == 'roll' then cs, n = cracksR, 8 end
        love.graphics.setColor(r, g, bl, alpha)
        love.graphics.draw(cs.image, cs.quads[(ck - 1) * n + fr], fx, fy, 0, sc, sc, 8, 15)
    end
    -- Sudor (fase 3 / mareada)
    if ((self.phase or 1) >= 3 or st == 'dizzy') and kind ~= 'roll' and st ~= 'frozen' then
        local now = love.timer.getTime()
        local k = (now * 1.4) % 1
        love.graphics.setColor(1, 1, 1, alpha * (1 - k))
        local top = (kind == 'roll') and 1 or topRow(fr)
        sweat:draw(math.floor(now * 4) % 2 + 1, fx + 6 * sc, fy - (15 - top) * sc + k * 3 * sc, 0, sc * 0.5, sc * 0.5)
    end
    -- Mareada: pajaritos/estrellas girando
    if st == 'dizzy' then
        local now = love.timer.getTime()
        for i = 0, 2 do
            local a = now * 5 + i * (math.pi * 2 / 3)
            local x = math.floor(fx + math.cos(a) * 7 * sc)
            local y = math.floor(fy - 15 * sc + math.sin(a) * 2 * sc)
            love.graphics.setColor(1, 0.9, 0.3, alpha)
            love.graphics.rectangle('fill', x - 6, y - 2, 12, 4)
            love.graphics.rectangle('fill', x - 2, y - 6, 4, 12)
        end
    end
    return fx, fy, sc
end

function Snow:render(camX, camY)
    local st, t = self.state, self.deadTimer or 0
    local now = love.timer.getTime()
    -- Retumbo rodando (bucle solo de dibujo; cada cliente lo oye a su distancia)
    if not EDITOR_VIEW and Sound.loop then
        Sound.loop('snowRoll', st == 'roll' or st == 'slide', self.x, self.y)
    end
    local alpha = self:ghostAlpha()
    if st == 'dormant' then self:renderSplat(camX, camY, now); return end

    -- Sombra en el suelo (saltando / gran golpe)
    if st == 'hop' or st == 'slam_up' or st == 'slam_hold' or st == 'slam_fall' then
        love.graphics.setColor(0, 0, 0, 0.25)
        local zy1 = select(4, self:zoneBounds())
        local w = self.outerW * 0.8
        love.graphics.rectangle('fill', math.floor(self.x - camX - w / 2), math.floor(zy1 - camY - 6), math.floor(w), 6)
    end

    if st == 'dying_burst' then
        -- (solo quedan los trozos de nieve)
    elseif st == 'dying_flee' then
        local k = math.max(0, 1 - math.max(0, t - FLEE_T + 1))
        love.graphics.setColor(1, 1, 1, k)
        flee:draw(math.floor(t * 10) % 2 + 1, math.floor(self.x - camX), math.floor((self.fleeY or self:feetY()) - camY - 6 * 5),
                  0, 5 * (self.fleeDir or 1), 5)
    else
        local fx, fy, sc = self:drawBody(camX, camY, alpha)
        if st == 'frozen' then
            IceEncase = IceEncase or require 'src/fx/IceEncase'
            local b = self:getOuterBounds()
            IceEncase.draw(b.x - camX, b.y - camY - sc, b.w, b.h + sc, now, (self.frozenFor or FROZEN_T) - t)
        end
        -- Polvo de nieve rodando / deslizando
        if (st == 'roll' or st == 'slide') and (self.lastTrail or 0) + 0.04 < now then
            self.lastTrail = now
            emit('snow_trail', self.x - (self.dir or 1) * self.outerW * 0.3, self:feetY() - 4)
        end
        -- Aliento helado al cambiar de fase
        if st == 'phase_up' and (self.lastBreath or 0) + 0.05 < now then
            self.lastBreath = now
            emit('cryo_puff', self.x, self.y + self.outerH * 0.1, { nx = (self.facing or 1), ny = 0 })
        end
    end

    -- Bolas
    for _, b in ipairs(self.proj or {}) do
        love.graphics.setColor(1, 1, 1, 1)
        if b.kind == 2 then
            bombBall:draw(math.floor(now * 12) % 2 + 1, math.floor(b.x - camX), math.floor(b.y - camY) - 4, 0, 4, 4)
            if (b.lastSpark or 0) + 0.05 < now then b.lastSpark = now; emit('fuse_spark', b.x + 14, b.y - 22) end
        else
            ballImg:draw(1, math.floor(b.x - camX), math.floor(b.y - camY), 0, 4, 4)
        end
    end
    -- Carámbanos: aviso (sombra que crece + tiembla arriba) y caída
    local zy1 = select(4, self:zoneBounds())
    for _, c in ipairs(self.icicles or {}) do
        love.graphics.setColor(1, 1, 1, 1)
        local cx = math.floor(c.x - camX)
        if c.stage == 1 then
            local k = math.max(0, math.min(1, c.t / ICICLE_WARN))
            cx = cx + ((k > 0.4) and math.floor(math.sin(now * 60) * 2) or 0)
            love.graphics.setColor(0, 0, 0, 0.15 + 0.25 * k)
            local w = 12 + 30 * k
            love.graphics.rectangle('fill', math.floor(c.x - camX - w / 2), math.floor(zy1 - camY - 6), math.floor(w), 6)
            love.graphics.setColor(1, 1, 1, 1)
        end
        icicleImg:draw(1, cx, math.floor(c.y - camY + 32), 0, 4, 4)
    end
    -- Olas de nieve del gran golpe
    if (self.shockT or 99) < SHOCK_LIFE then
        local d = self.shockT * SHOCK_SPD
        local a = math.min(1, (SHOCK_LIFE - self.shockT) / 0.3)
        love.graphics.setColor(1, 1, 1, a)
        local fr = math.floor(now * 10) % 2 + 1
        for _, s in ipairs({ -1, 1 }) do
            shock:draw(fr, math.floor(self.shockX + s * d - camX), math.floor(self.shockY - camY - 16), 0, 4 * s, 4)
        end
    end
    self:renderSplat(camX, camY, now)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Escupitajo de la entrada (solo dibujo, del reloj de la entrada: igual online):
-- la bola sale de la boca, vuela hacia la cámara creciendo y girando (con estela) y al
-- llegar se estampa en la pantalla (destello + mancha que chorrea y cae, 1.6 s)
function Snow:renderSplat(camX, camY, now)
    local t = self.deadTimer or 0
    if self.state == 'dormant' then self.splatAt = nil end
    if self.state == 'intro' and t >= SPIT_AT and t < SPLAT_AT then
        local mx, my = self:mouthPos()
        local x0, y0 = mx - camX, my - camY
        local x1, y1 = WINDOW_W / 2, WINDOW_H * 0.46
        for i = 3, 0, -1 do                                        -- (estela: copias de antes)
            local u = math.max(0, (t - i * 0.025 - SPIT_AT) / (SPLAT_AT - SPIT_AT))
            local e = u * u                                        -- (acelera hacia la cámara)
            local x = x0 + (x1 - x0) * e
            local y = y0 + (y1 - y0) * e - math.sin(u * math.pi) * 70
            local k = math.floor(4 + 26 * e * e + 0.5)            -- 8 px → ~240 px
            love.graphics.setColor(1, 1, 1, (i == 0) and 1 or (0.35 - i * 0.08))
            ballImg:draw(1, math.floor(x), math.floor(y), u * 7, k, k)
        end
    end
    if self.state == 'intro' and t >= SPLAT_AT and not self.splatAt then self.splatAt = now end
    local s = self.splatAt
    if not s then return end
    local u = now - s
    if u > 1.6 then return end
    if u < 0.09 then                                               -- destello del golpe
        love.graphics.setColor(1, 1, 1, 0.45 * (1 - u / 0.09))
        love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)
    end
    local fr = (u < 0.55) and 1 or ((u < 1.1) and 2 or 3)
    local slide = math.max(0, u - 0.55) * 180
    local sc = (u < 0.06) and 14 or 12                             -- (aplasta un instante al chocar)
    love.graphics.setColor(1, 1, 1, math.min(1, (1.6 - u) / 0.4))
    splat:draw(fr, math.floor(WINDOW_W / 2), math.floor(WINDOW_H * 0.46 + slide), 0, sc, sc)
end

function Snow.drawEditorOverlay(props, cx, cy, zoom) end

return {
    name = 'snowboss', label = 'Gran Bola de Nieve', category = 'Jefes',
    description = 'Jefe de hielo: salta, escupe bolas (y bolas-bomba), rueda y da un gran golpe con '
               .. 'carámbanos. Solo se le daña MAREADA (chocando rodando contra un Bloque ON sólido o con una '
               .. 'bomba) o CONGELADA (chorro de un Congelador).',
    class = Snow,
    boss = { title = 'GRAN BOLA DE NIEVE' },
    hide = Boss.HIDE,
    defaults = { points = 30 },
    props = Boss.props({ hp = 14, hpPerPlayer = 4 }, {
        { key='phase2', kind='number', label='Fase 2 con vida ≤', group='Bola de nieve', default=0.6,
          min=0.1, max=0.95, step=0.05, help='Fracción de vida: se enfada, se hincha, bolas-bomba y gran golpe' },
        { key='phase3', kind='number', label='Fase 3 con vida ≤', group='Bola de nieve', default=0.25,
          min=0.05, max=0.9, step=0.05, help='Avalancha y tapa los Activadores con nieve prensada' },
        { key='bombFuse', kind='number', label='Mecha de las bolas-bomba (s)', group='Bola de nieve', default=2.4,
          min=0.5, max=8, step=0.1 },
    }),
    editor = { sprite = 'assets/images/bosses/snowboss/body-Sheet.png', frameW = 16 },
    -- Bombas de reserva: las bolas-bomba, al caer, se convierten en una (ver dropBomb)
    summons = function(pl)
        local out = {}
        for i = 1, 4 do
            out[#out + 1] = { type = 'bombobject', col = pl.col, row = pl.row,
                              summonKey = 'sb' .. pl.col .. ',' .. pl.row, props = {} }
        end
        return out
    end,
}
