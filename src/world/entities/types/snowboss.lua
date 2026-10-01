-- Jefe GRAN BOLA DE NIEVE (types/snowboss.lua). Una bola de nieve juguetona que cree
-- que esto es una pelea de bolas. Nunca se le hace daño así como así: hay que dejarla
-- VULNERABLE con el escenario y entonces pisotón 1 / ground pound 2:
--   * MAREADA ('dizzy'): rodando se estampa contra una pared o un escalón (fase 1 a la
--     primera; fase 2 tras 1 rebote; fase 3 tras 2), o le cae un CARÁMBANO encima
--   * EMPAPADA ('soaked'): cae al agua del lago (hielo fino roto) → atascada un rato
--   * CONGELADA ('frozen', fase 3): empapada y la alcanza un Congelador → ground pound 3
--     (seca, el Congelador solo la aturde un momento)
-- Tres fases que la ENCOGEN (escala 10 → 8 → 6: cada vez más ágil):
--   1 grande: escupe, rueda, salta bajito (no llega a las plataformas)
--   2 mediana: SALTO A PLATAFORMA (ballístico hasta cerca del jugador; marca donde cae).
--     Cada aterrizaje sacude los carámbanos del techo a menos de 2.5 casillas: tiemblan
--     y caen (en el jugador 2 de vida; en ella, mareada). Vuelven a crecer.
--   3 pequeña: GRAN GOLPE (rompe el hielo fino y levanta olas por el suelo), rueda con 2
--     rebotes, salta, ráfagas de 5 bolas. Bajan del techo los Congeladores y sale el
--     Activador del suelo (bloques/props `phase` de la arena: BossZones / PhaseBlocks).
-- Como mucho 2 ataques seguidos y descansa. El lago (hielo fino) se vuelve a helar solo
-- unos segundos después de romperse. Entrada (genérica de Boss): una bolita entra
-- botando y creciendo, se estampa, se ríe y escupe una bola a la cámara. Muerte: se
-- agrieta → revienta en nieve → una bolita con cara huye (libera la zona antes).
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
Snow.wantsLevel  = true                 -- (BossZones.link: carámbanos, sombras sobre la superficie real)

local SC = { 10, 8, 6 }                 -- escala del arte por fase (16x16 → 160 / 128 / 96 px)
Snow.SC = SC
local T = TILE_PX
local GRAV = 2200

-- Duraciones / fuerzas
-- RITMO (por fase: normal / media / agresiva). La fase media tiene el ritmo que antes era
-- el de la fase 3; la normal va más rápida que antes y la agresiva, mucho más
local IDLE_T     = { 0.5, 0.4, 0.22 }   -- pausa entre los ataques de una tanda
local REST_T     = { 1.15, 0.9, 0.5 }   -- descanso tras cada tanda
local STREAK     = { 2, 2, 3 }          -- ataques seguidos por tanda
local SHOTS      = { 4, 6, 8 }          -- bolas por ráfaga
local HOP_VY     = 900                  -- (bajito: no se sube a las plataformas de la arena)
local HOP_AIR    = 0.82                 -- s en el aire (2·HOP_VY/GRAV) para apuntar el salto
local LAND_T     = { 0.3, 0.24, 0.16 }
local LEAP_WIND  = { 0.55, 0.45, 0.32 } -- aviso del salto a plataforma (marca donde cae)
local LEAP_LAND  = { 0.8, 0.6, 0.42 }   -- se queda quieta tras caer (los carámbanos caen)
local ESCAPE_WIND = 0.5                 -- empapada: coge impulso antes del gran salto fuera del agua
local ESCAPE_UP  = 2.6                  -- casillas sobre lo más alto del gran salto para salir
local LEAP_UP    = 1.4                  -- casillas por encima del punto más alto del salto
local SHOOT_WIND = { 0.4, 0.32, 0.24 }
local SHOOT_GAP  = { 0.18, 0.15, 0.11 }
local WINDUP_T   = { 0.6, 0.5, 0.34 }
local ROLL_SPD   = { 620, 760, 900 }
local ROLL_ACC   = 2600
local ROLL_MAX_T = { 3.2, 5.0, 7.0 }    -- s empujando antes de dejarse deslizar (le dan para sus rebotes)
local BOUNCES    = { 0, 1, 2 }          -- rebotes por ataque rodando (el último choque la marea)
local DIZZY_T    = 2.6
local DAZE_T     = 1.4                  -- Congelador seca: solo aturdida
local FROZEN_T   = 4.5                  -- Congelador empapada: congelada
local RECOVER_T  = { 0.6, 0.5, 0.32 }
local SLAM_H     = 480                  -- px que sube el gran golpe (menos si no cabe bajo el techo)
local SLAM_HOLD  = { 0.3, 0.28, 0.2 }
local SLAM_FALL  = 1700
local SLAM_LAND  = { 0.6, 0.5, 0.38 }
local SHOCK_SPD  = 560
local SHOCK_LIFE = 1.35
local PHASE_T    = 1.8
local CRASH_SPD  = 240                  -- px/s mínimos para marearse al chocar
local CRASH_RUN  = 2.5                  -- casillas rodadas (desde el último choque) para marearse
local LAND_CRACK, SLAM_CRACK = 4, 4     -- estados de hielo fino que rompe al caer: pesa, lo rompe SIEMPRE
local ROLL_WEAR  = 0.15                 -- s rodando / deslizando sobre hielo fino por cada estado que lo gasta
local MAX_CRASHES = 8                   -- choques como mucho por ataque rodando (seguro: siempre acaba)
local ICE_DECEL  = 260                  -- frenada deslizando sobre hielo (px/s²)
local SNOW_DECEL = 2600                 -- y sobre lo demás
local BALL_HIT   = 26                   -- lado de la caja de daño de una bola
-- Carámbanos del techo
local ICE_R      = 2.5                  -- casillas: un aterrizaje sacude los que tiene a esta distancia
local ICE_GROW   = 0.9
local ICE_SHAKE  = 0.6
local ICE_LEN    = 60                   -- px del colgadero a la punta (dibujo 8x16 a escala 4)
-- Golpes a los jugadores: { vida, vx, vy, s sin control (el impulso no se pierde), s aturdido }
local HIT_BALL   = { 1, 620, -360, 0.22, 0 }       -- bola de nieve: empujón fuerte
local HIT_ICICLE = { 2, 320, -280, 0.12, 0 }       -- carámbano en la cabeza
local HIT_WAVE   = { 1, 1000, -560, 0.30, 0.35 }   -- ola de nieve del gran golpe
local HIT_SLAM   = { 1, 1350, -700, 0.38, 0.55 }   -- onda del aterrizaje del gran golpe: MUY fuerte
local SLAM_R     = 3.5                  -- casillas (además del medio cuerpo) que alcanza la onda
local DEATH = { dying_crack = true, dying_burst = true, dying_flee = true }
local CRACK_T, BURST_T, FLEE_T = 2.0, 0.6, 3.2

-- Ciclo de ataques por fase (de 2 en 2, con descanso entre tandas)
local CYCLE = {
    { 'shoot', 'roll', 'hop', 'roll' },
    { 'leap', 'shoot', 'leap', 'roll' },
    { 'slam', 'roll', 'leap', 'slam', 'shoot', 'leap' },
}
Snow.CYCLE = CYCLE

-- Carámbanos: estados (códigos de red)
local IC_HIDDEN, IC_GROW, IC_READY, IC_SHAKE, IC_FALL, IC_WAIT = 0, 1, 2, 3, 4, 5
Snow.IC = { hidden = IC_HIDDEN, grow = IC_GROW, ready = IC_READY, shake = IC_SHAKE, fall = IC_FALL, wait = IC_WAIT }

-- ── Arte ──────────────────────────────────────────────────────────────────────
local body, rollH, rollA, cracksB, cracksR, sweat, ballImg, flee, icicleImg, shock, splat
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
    flee     = SpriteStrip.load(D .. 'flee-Sheet.png', 12)
    icicleImg = SpriteStrip.load(D .. 'icicle.png', 8)
    shock    = SpriteStrip.load(D .. 'shock-Sheet.png', 16)
    splat    = SpriteStrip.load(D .. 'splat-Sheet.png', 64)
end
function Snow.sizePx() return 16 * SC[1], 16 * SC[1] end

local function rand(a, b) return a + math.random() * (b - a) end
local overlap = Boss.overlap

-- ── Tamaño (encoge en cada fase) ─────────────────────────────────────────────
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
    self.sc = SC[1]
    self.outerW, self.outerH = 13 * SC[1], 13 * SC[1]
    self.innerW, self.innerH = 12 * SC[1], 12 * SC[1]
    -- apoyada en el suelo de su celda
    self.y = self.row * T - self.outerH / 2
    self.phase, self.cycleI, self.streak = 1, 0, 0
    self.vx, self.vy, self.onGround = 0, 0, true
    self.proj, self.nextId = {}, 0
    self.shockT, self.shockX, self.shockY = 99, 0, 0
    self.landX, self.landY = 0, 0
    self.facing, self.dir = -1, -1
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

-- ── Movimiento propio ────────────────────────────────────────────────────────
-- Como un jugador: choca con los bloques sólidos y los cuerpos sólidos (bloques de
-- jefe, Congeladores), pero las PLATAFORMAS (one-way) las atraviesa subiendo y de lado
-- y solo se posa en ellas cayendo desde arriba (Level:landingCross). Así puede saltar
-- a una plataforma desde debajo.
local function solidTile(level, x, y)
    local d = level:getDefAt(x, y)
    if d.collision == 'solid' and d.enemySolid ~= false and TileTypes.hitboxContains(d, x, y) then return d end
    return nil
end

local MAX_STEP = 16
-- `self.passY` (saltos a una marca): atraviesa plataformas y bloques por el camino (de lado y
-- hacia arriba) y solo se posa en una cara superior a la altura de la marca o más abajo;
-- así llega a donde marcó (antes se quedaba enganchada en las plataformas de en medio)
function Snow:move(level, dx, dy)
    local hw, hh = self.outerW / 2, self.outerH / 2
    local x, y = self.x + dx, self.y
    local hitX, hitDef
    local pass = self.passY
    if dx ~= 0 and not pass then
        local edge = (dx > 0) and (x + hw) or (x - hw)
        local face
        for _, py in ipairs(level:samples(y - hh + 4, y + hh - 4)) do
            local f, d
            local td = solidTile(level, edge, py)
            if td then
                local c0 = math.floor(edge / T) * T
                if dx > 0 then f = c0 + td.hitbox.x * T else f = c0 + (td.hitbox.x + td.hitbox.w) * T end
                d = td
            else
                local o, b = level:bodyAt(edge, py, self)
                if o then f = (dx > 0) and b.x or (b.x + b.w) end
            end
            if f and (not face or (dx > 0 and f < face) or (dx < 0 and f > face)) then face, hitDef = f, d end
        end
        if face then
            x = (dx > 0) and (face - hw) or (face + hw)
            hitX = true
        end
    end
    self.onGround = false
    local cols = level:samples(x - hw + 4, x + hw - 4)
    local left = dy
    while left ~= 0 do
        local step = (left > 0) and math.min(left, MAX_STEP) or math.max(left, -MAX_STEP)
        left = left - step
        local ny = y + step
        local stop
        if step > 0 then
            local f0, f1 = y + hh, ny + hh
            for _, px in ipairs(cols) do
                local _, top = level:landingCross(px, f0, f1)
                if not top then
                    local o, b = level:bodyAt(px, f1, self)
                    if o and f0 <= b.y + 0.5 then top = b.y end
                end
                if top and pass and top < pass - 8 then top = nil end      -- (más arriba que la marca: la atraviesa)
                if top and (not stop or top < stop) then stop = top end
            end
            if stop then y = stop - hh; self.vy = 0; self.onGround = true; break end
        elseif not pass then
            local e = ny - hh
            for _, px in ipairs(cols) do
                local f
                local td = solidTile(level, px, e)
                if td then f = math.floor(e / T) * T + (td.hitbox.y + td.hitbox.h) * T
                else
                    local o, b = level:bodyAt(px, e, self)
                    if o then f = b.y + b.h end
                end
                if f and (not stop or f > stop) then stop = f end
            end
            if stop then y = stop + hh; self.vy = 0; break end
        end
        y = ny
    end
    self.x, self.y = x, y
    return hitX, hitDef
end

-- Mueve con gravedad y choques. Devuelve 'wall' (+ def del tile) si chocó de lado.
function Snow:physics(level, dt, gravity)
    local vx0 = self.vx
    if gravity ~= false then self.vy = self.vy + GRAV * dt end
    local x0 = self.x
    local hitX, def = self:move(level, self.vx * dt, self.vy * dt)
    local hit
    self.hitToggles = nil
    if hitX and vx0 ~= 0 then
        hit = 'wall'
        local fx = self.x + (vx0 > 0 and 1 or -1) * (self.outerW / 2 + 4)
        for _, yy in ipairs({ self.y - self.outerH * 0.3, self.y, self.y + self.outerH * 0.35 }) do
            local d = solidTile(level, fx, yy)
            -- Activadores ON/OFF tocados (crash los cambia; nada de romper bloques)
            if d and d.toggle then
                local c, r = math.floor(fx / T) + 1, math.floor(yy / T) + 1
                self.hitToggles = self.hitToggles or {}
                local dup = false
                for _, h in ipairs(self.hitToggles) do if h[1] == c and h[2] == r then dup = true end end
                if not dup then self.hitToggles[#self.hitToggles + 1] = { c, r } end
            end
        end
    end
    -- Paredes y techo de la zona
    local zx0, zx1, zy0 = self:zoneBounds()
    local hw = self.outerW / 2
    if self.x - hw < zx0 then self.x = zx0 + hw; hit = hit or 'wall' end
    if self.x + hw > zx1 then self.x = zx1 - hw; hit = hit or 'wall' end
    if self.y - self.outerH / 2 < zy0 and self.vy < 0 then self.y = zy0 + self.outerH / 2; self.vy = 0 end
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

-- Agrieta el hielo fino bajo ella `n` estados. Es PESADA: si una celda se rompe, se rompe
-- todo lo que pisa (si no, una celda vecina la sostenía y casi nunca caía al agua)
function Snow:crackUnder(level, n)
    local cells, broke = self:cellsUnder(level), false
    for _, cr in ipairs(cells) do
        if level:getDef(cr[1], cr[2]).thinIce then
            level:crackIce(cr[1], cr[2], n, 'pound')
            if not level:getDef(cr[1], cr[2]).thinIce then broke = true end
        end
    end
    if broke then
        for _, cr in ipairs(cells) do
            if level:getDef(cr[1], cr[2]).thinIce then level:crackIce(cr[1], cr[2], 4, 'pound') end
        end
    end
end

-- Rodando / deslizando sobre hielo fino lo va gastando (un estado cada ROLL_WEAR s)
function Snow:wearIce(level, dt)
    if not self.onGround then return end
    local on = false
    for _, cr in ipairs(self:cellsUnder(level)) do
        if level:getDef(cr[1], cr[2]).thinIce then on = true end
    end
    if not on then self.wearT = 0; return end
    self.wearT = (self.wearT or 0) + dt
    if self.wearT >= ROLL_WEAR then
        self.wearT = 0
        self:crackUnder(level, 1)
    end
end

-- Daño por contacto (rodando, aterrizando encima): 1 de vida y empujón / aplastado
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

-- ── Carámbanos del techo ─────────────────────────────────────────────────────
-- Fijos (prop `icicles`: celdas; cuelgan del borde de arriba de su celda). Salen en la
-- fase 2. Un aterrizaje de la bola a menos de ICE_R casillas los sacude: tiemblan
-- ICE_SHAKE s y caen. Al jugador: 2 de vida. A la bola: MAREADA. Al romperse vuelven
-- a crecer a los `icicleRegrow` s. Misma lista (mismos índices) en servidor y clientes.
function Snow:icicleList()
    if self.icicles then return self.icicles end
    local list = {}
    local pts = self.props.icicles
    if type(pts) == 'table' and #pts > 0 then
        for _, p in ipairs(pts) do
            local top = (p.row - 1) * T
            list[#list + 1] = { x = (p.col - 0.5) * T, top = top, y = top, vy = 0, st = IC_HIDDEN, t = 0 }
        end
    elseif self.zone then
        local z = self.zone
        for c = z.col + 2, z.col + z.w - 3, 3 do
            list[#list + 1] = { x = (c - 0.5) * T, top = z.y0, y = z.y0, vy = 0, st = IC_HIDDEN, t = 0 }
        end
    end
    self.icicles = list
    return list
end

function Snow:icicleBox(c)
    return { x = c.x - 12, y = c.y + 8, w = 24, h = ICE_LEN - 8 }
end

function Snow:growIcicles()
    for _, c in ipairs(self:icicleList()) do
        if c.st == IC_HIDDEN then c.st, c.t, c.y = IC_GROW, 0, c.top end
    end
end

-- Un aterrizaje sacude los carámbanos cercanos (en horizontal)
function Snow:shakeIcicles(x)
    local any = false
    for _, c in ipairs(self:icicleList()) do
        if c.st == IC_READY and math.abs(c.x - x) <= ICE_R * T then
            c.st, c.t = IC_SHAKE, 0
            any = true
        end
    end
    if any then Sound.play('iceCrack', 1.2, 0.7) end
end

-- ¿Le puede marear un carámbano ahora?
local BONK_NO = { dizzy = true, frozen = true, soaked = true, phase_up = true, slam_hold = true }
function Snow:canBonk()
    return self:isActive() and not BONK_NO[self.state] and self.inv <= 0
end

function Snow:updateIcicles(level, dt)
    local players = level.players or {}
    for _, c in ipairs(self:icicleList()) do
        c.t = c.t + dt
        if c.st == IC_GROW then
            if c.t >= ICE_GROW then c.st, c.t = IC_READY, 0 end
        elseif c.st == IC_SHAKE then
            if c.t >= ICE_SHAKE then c.st, c.t, c.vy = IC_FALL, 0, 0 end
        elseif c.st == IC_FALL then
            c.vy = c.vy + GRAV * 1.2 * dt
            local ny = c.y + c.vy * dt
            local landT, landY = level:landingCross(c.x, c.y + ICE_LEN, ny + ICE_LEN)
            local broke = false
            c.y = ny
            local box = self:icicleBox(c)
            -- en la bola: mareada
            if self:isActive() and overlap(box, self:getOuterBounds()) then
                broke = true
                if self:canBonk() then self:bonk() end
            end
            -- en un jugador: 2 de vida
            if not broke then
                for _, pa in ipairs(players) do
                    if overlap(pa:getOuterBounds(), box) and strike(pa, HIT_ICICLE, (pa.x >= c.x) and 1 or -1) then
                        broke = true
                        break
                    end
                end
            end
            if broke or landT or ny > level.heightPx then
                Sound.play('iceBreak', 1.1, 0.8)
                Entity.emitFx('ice_break', c.x, broke and (c.y + ICE_LEN * 0.6) or ((landY or ny) - 6))
                c.st, c.t, c.y, c.vy = IC_WAIT, 0, c.top, 0
            end
        elseif c.st == IC_WAIT then
            if c.t >= (self.props.icicleRegrow or 6) then c.st, c.t = IC_GROW, 0 end
        end
    end
end

-- Le cae un carámbano: mareada (sin daño)
function Snow:bonk()
    self:stopRoll()
    self.vx = 0
    if self.vy < 0 then self.vy = 0 end
    self.dizzyFor = DIZZY_T
    self:enter('dizzy')
    Sound.play('snowDizzy')
    Entity.emitFx('shake_small', self.x, self.y)
end

-- ── Lo que lanza (bolas) y las olas de nieve contra los jugadores ───────────
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
                    Sound.play('snowSplat')
                    Entity.emitFx('snow_puff', b.x, b.y)
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

-- ── El lago (hielo fino sobre agua) ──────────────────────────────────────────
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

-- ¿Hay alguien (ella o un jugador) en la casilla?
function Snow:cellTaken(level, c, r)
    local box = { x = (c - 1) * T, y = (r - 1) * T, w = T, h = T }
    if overlap(self:getOuterBounds(), box) then return true end
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and overlap(pa:getOuterBounds(), box) then return true end
    end
    return false
end

-- Las celdas de hielo fino de la zona al empezar (se vuelven a helar solas)
function Snow:findLake(level)
    self.lake = {}
    if not self.zone then return end
    local zx0, zx1, zy0, zy1 = self:zoneBounds()
    for r = math.floor(zy0 / T) + 1, math.floor((zy1 - 1) / T) + 2 do
        for c = math.floor(zx0 / T) + 1, math.floor((zx1 - 1) / T) + 1 do
            if level:getDef(c, r).thinIce then self.lake[#self.lake + 1] = { c, r, 0 } end
        end
    end
end

-- Celda rota del lago: a los `lakeRegrow` s se vuelve a helar (si no hay nadie dentro;
-- `now` = todas ya, al morir)
function Snow:regrowLake(level, dt, now)
    local thin = TileTypes.byName.thin_ice
    local any = false
    -- Mientras ella esté en el agua (empapada, cogiendo impulso o saltando fuera) el hielo
    -- NO se rehace; vuelve cuando ya ha salido (dryT: s fuera del agua)
    local wet = self:inWater(level) or self.state == 'soaked' or self.escaping
    if wet then self.dryT = 0 else self.dryT = (self.dryT or 99) + dt end
    if not now and (self.dryT or 99) < 0.6 then return end
    for _, cr in ipairs(self.lake or {}) do
        local d = level:getDef(cr[1], cr[2])
        if d.thinIce or d.collision == 'solid' then
            cr[3] = 0
        else
            cr[3] = cr[3] + dt
            if (now or cr[3] >= (self.props.lakeRegrow or 4)) and not self:cellTaken(level, cr[1], cr[2]) then
                cr[3] = 0
                placeTile(level, cr[1], cr[2], thin.id)
                Entity.emitFx('ice_freeze', (cr[1] - 0.5) * T, (cr[2] - 0.5) * T)
                any = true
            end
        end
    end
    if any then Sound.play('snowBreath', 1.3, 0.5) end
end

-- Cae al agua (hielo roto): EMPAPADA, atascada `soakTime` s (vulnerable); luego sale
-- (solo al ENTRAR en el agua: si sigue dentro tras el remojo / el hielo / el cambio de
-- fase, no vuelve a empaparse; su siguiente ataque es salir de un salto)
local NO_SOAK = { soaked = true, frozen = true, phase_up = true }
function Snow:checkSoak(level)
    local wet = self:inWater(level)
    local was = self.wasWet
    self.wasWet = wet
    if not wet or was or NO_SOAK[self.state] or not self:isActive() then return end
    self:stopRoll()
    self.vx = 0
    self:enter('soaked')
    -- el agujero, a su medida: rompe el hielo fino que tiene encima o a los lados (si no,
    -- quedaba encajada bajo el hielo y no podía salir)
    local hw = self.outerW / 2 + T / 4
    for _, cr in ipairs(self.lake or {}) do
        local cx0, cx1 = (cr[1] - 1) * T, cr[1] * T
        if cx1 > self.x - hw and cx0 < self.x + hw and level:getDef(cr[1], cr[2]).thinIce then
            level:crackIce(cr[1], cr[2], 4, 'pound')
        end
    end
    Sound.play('waterSplash', 0.7)
    Sound.play('snowDizzy', 0.9)
    Entity.emitFx('snow_puff', self.x, self:feetY() - 20)
    Entity.emitFx('shake_small', self.x, self.y)
end
function Snow:inWater(level) return level:liquidAt(self.x, self:feetY() - 8) ~= nil end

-- ── Pelea ─────────────────────────────────────────────────────────────────────
function Snow:onFightStart(n)
    self.state, self.deadTimer = 'idle', 0
    self.cycleI, self.streak = 0, 0
    self.lake = nil                      -- (se apunta en el primer paso: ver findLake)
end

function Snow:bossPhase() return self.phase or 1 end

function Snow:phaseFor()
    local p = self.props
    local k = self.hp / math.max(1, self.hpMax)
    if k <= (p.phase3 or 0.33) then return 3 end
    if k <= (p.phase2 or 0.66) then return 2 end
    return 1
end

function Snow:enter(st)
    self.state, self.deadTimer = st, 0
    -- (un salto cortado — congelada en el aire, cambio de fase... — no deja atrás el
    -- atravesar plataformas ni el "saliendo del agua", que impedía rehacer el hielo)
    if st ~= 'leap' then self.passY = nil end
    if st ~= 'leap' and st ~= 'leap_wind' and st ~= 'leap_land' then self.escaping = nil end
end

-- Sitios donde puede posarse (saltos a plataforma y para salir del agua): bordes de
-- arriba de bloques / plataformas dentro de la zona con sitio para su cuerpo.
-- `dry` = ni hielo fino ni agua debajo.
function Snow:spots(level, dry)
    local zx0, zx1, zy0, zy1 = self:zoneBounds()
    local hw, h = self.outerW / 2, self.outerH
    local out = {}
    local c0, c1 = math.max(1, math.floor(zx0 / T) + 1), math.min(level.tileW, math.floor((zx1 - 1) / T) + 1)
    local r0, r1 = math.max(1, math.floor(zy0 / T) + 1), math.min(level.tileH, math.floor((zy1 - 1) / T) + 2)
    for r = r0, r1 do
        for c = c0, c1 do
            local d = level:getDef(c, r)
            if d.collision == 'solid' or d.collision == 'oneway' then
                local top = (r - 1) * T + ((d.hitbox and d.hitbox.y) or 0) * T
                -- x = mitad de la celda o su borde derecho
                for _, x in ipairs({ (c - 0.5) * T, c * T }) do
                    if x - hw >= zx0 and x + hw <= zx1 and top - h >= zy0 + 4 then
                        local ok = true
                        for _, px in ipairs({ x - hw + 6, x, x + hw - 6 }) do
                            if not level:collisionAt(px, top + 2, true) or level:collisionAt(px, top - 2, true) then ok = false; break end
                            -- (seco: ni hielo fino / agua debajo NI agua encima — el fondo de la poza
                            -- contaba como seco y "salía" otra vez al fondo: se quedaba atascada)
                            if dry and (level:getDefAt(px, top + 2).thinIce or level:liquidAt(px, top + 2)
                                        or level:liquidAt(px, top - 8)) then ok = false; break end
                        end
                        if ok then
                            for _, py in ipairs({ top - h + 6, top - h / 2, top - 8 }) do
                                for _, px in ipairs({ x - hw + 4, x, x + hw - 4 }) do
                                    if solidTile(level, px, py) or level:bodyAt(px, py, self) then ok = false end
                                end
                            end
                        end
                        if ok then out[#out + 1] = { x = x, y = top } end
                    end
                end
            end
        end
    end
    return out
end

-- Salto ballístico a (tx, ty = pies), subiendo `up` casillas sobre lo más alto
function Snow:jumpTo(tx, ty, up)
    local _, _, zy0 = self:zoneBounds()
    local y0 = self:feetY()
    local apex = math.min(y0, ty) - (up or LEAP_UP) * T
    apex = math.max(apex, zy0 + self.outerH + 8)                  -- (sin tocar el techo de la zona)
    apex = math.min(apex, math.min(y0, ty) - 16)
    local vy = -math.sqrt(2 * GRAV * (y0 - apex))
    local tu = -vy / GRAV
    local td = math.sqrt(2 * math.max(1, ty - apex) / GRAV)
    self.vy = vy
    self.vx = (tx - self.x) / (tu + td)
    self.onGround = false
    self.facing = (tx >= self.x) and 1 or -1
end

-- Elige dónde caer: el sitio más cerca del jugador (a su altura si está en una
-- plataforma). `dry` (saliendo del agua): el sitio seco más cercano a ella
function Snow:pickLeap(level, pa, dry)
    local list = self:spots(level, dry)
    if #list == 0 then return nil end
    local tx, ty = self.x, self:feetY()
    if pa then local ob = pa:getOuterBounds(); tx, ty = pa.x, ob.y + ob.h end
    local best, bd
    for _, s in ipairs(list) do
        local d
        if dry then d = math.abs(s.x - self.x) + math.abs(s.y - self:feetY()) * 0.5
        else d = math.abs(s.x - tx) + math.abs(s.y - ty) * 0.8 end
        if not bd or d < bd then best, bd = s, d end
    end
    return best
end

function Snow:leapWind()
    if self.escaping then return ESCAPE_WIND end
    return LEAP_WIND[self.phase or 1]
end

function Snow:startLeap(level, pa, dry)
    local s = self:pickLeap(level, pa, dry)
    if not s then return false end
    self.landX, self.landY = math.floor(s.x), math.floor(s.y)
    self.vx = 0
    self:enter('leap_wind')
    return true
end

function Snow:nextAttack(level)
    if self:phaseNow() then return end
    local pa = self:target(level)
    -- En el agua (se le pasó el remojo): sale de un salto a lo seco
    if self:inWater(level) then
        self.escaping = true
        if not self:startLeap(level, pa, true) then
            self.vy, self.onGround = -HOP_VY, false
            self:enter('hop')
        end
        return
    end
    -- Tanda de 2 ataques y descanso
    if self.streak >= STREAK[self.phase] then
        self.streak = 0
        self:enter('rest')
        return
    end
    self.streak = self.streak + 1
    local cyc = CYCLE[self.phase]
    self.cycleI = self.cycleI % #cyc + 1
    local a = cyc[self.cycleI]
    self.dir = (pa and pa.x < self.x) and -1 or 1
    self.facing = self.dir
    if a == 'hop' then
        local zx0, zx1 = self:zoneBounds()
        local tx = pa and (pa.x + rand(-1, 1) * T) or self.x
        tx = math.max(zx0 + self.outerW / 2, math.min(zx1 - self.outerW / 2, tx))
        self.vx = (tx - self.x) / HOP_AIR
        self.vy = -HOP_VY
        self.onGround = false
        Sound.play('snowLand', 1.3, 0.5)
        self:enter('hop')
    elseif a == 'leap' then
        if not self:startLeap(level, pa) then self:enter('idle') end
    elseif a == 'shoot' then
        self.shots = SHOTS[self.phase]
        self.shotN = 0
        self:enter('shoot')
    elseif a == 'roll' then
        self.bounces = BOUNCES[self.phase]
        self:enter('windup')
    elseif a == 'slam' then
        local zx0, zx1, zy0 = self:zoneBounds()
        local tx = pa and pa.x or self.x
        tx = math.max(zx0 + self.outerW / 2, math.min(zx1 - self.outerW / 2, tx))
        -- sube hasta SLAM_H (sin tocar el techo de la zona) y llega a la vertical del
        -- jugador justo en lo más alto: de ahí cae en vertical
        local feet = self:feetY()
        local apex = math.max(feet - SLAM_H, zy0 + self.outerH + 8)
        local h = math.max(T, feet - apex)
        self.vy = -math.sqrt(2 * GRAV * h)
        self.vx = (tx - self.x) / (-self.vy / GRAV)
        self.onGround = false
        Sound.play('snowSpit', 0.6)
        self:enter('slam_up')
    end
end

-- Escupe una bola de nieve hacia un jugador, en arco
function Snow:spit(level)
    local pa = self:target(level)
    local mx, my = self.x + self.facing * self.outerW * 0.2, self.y - self.outerH * 0.05
    local tx = pa and (pa.x + rand(-1.5, 1.5) * T) or (self.x + self.facing * 4 * T)
    local ty = pa and (pa.y + 30) or self:feetY()
    local tf = math.max(0.55, math.min(1.1, math.abs(tx - mx) / 700 + 0.45))
    local vx = (tx - mx) / tf
    local vy = (ty - my - 0.5 * GRAV * tf * tf) / tf
    self.nextId = self.nextId % 999 + 1
    table.insert(self.proj, { id = self.nextId, x = mx, y = my, vx = vx, vy = vy, t = 0 })
    self.facing = (vx >= 0) and 1 or -1
    Sound.play('snowSpit')
    Entity.emitFx('snow_puff', mx, my)
end

function Snow:updateProjectiles(level, dt)
    for i = #self.proj, 1, -1 do
        local b = self.proj[i]
        b.t = b.t + dt
        b.vy = b.vy + GRAV * dt
        local nx, ny = b.x + b.vx * dt, b.y + b.vy * dt
        local gone = b.t > 4 or ny > level.heightPx
        if not gone then
            -- Atraviesan las PLATAFORMAS (tiles traspasables: ni las frenan ni las rompen);
            -- las para lo sólido de verdad (suelo, repisas, paredes) o salir de la zona
            local floorY
            if level:collisionAt(nx, ny + 10) then                       -- (solo sólidos: sin 'oneway')
                floorY = math.floor((ny + 10) / T) * T
                local d = level:getDefAt(nx, ny + 10)
                if d.hitbox then floorY = floorY + d.hitbox.y * T end
            end
            if self.zone then
                local zx0, zx1 = self:zoneBounds()
                if nx < zx0 or nx > zx1 then gone = true end
            end
            if floorY then
                gone = true
                Sound.play('snowSplat')
                Entity.emitFx('snow_puff', nx, floorY - 10)
            end
        end
        if gone then table.remove(self.proj, i) else b.x, b.y = nx, ny end
    end
end

-- Cajas de peligro (solo para F1 / depuración: los golpes los da hitWithShots)
function Snow:getHazardBoxes()
    local out = {}
    for _, b in ipairs(self.proj or {}) do
        out[#out + 1] = { x = b.x - BALL_HIT / 2, y = b.y - BALL_HIT / 2, w = BALL_HIT, h = BALL_HIT, effect = 'hurt' }
    end
    for _, c in ipairs(self.icicles or {}) do
        if c.st == IC_FALL then local b = self:icicleBox(c); b.effect = 'hurt'; out[#out + 1] = b end
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
local VULN = { dizzy = true, frozen = true, soaked = true }
function Snow:isActive() return Boss.isActive(self) and not DEATH[self.state] end
function Snow:isDying() return DEATH[self.state] == true or Boss.isDying(self) end
function Snow:isVulnerable() return self:isActive() and VULN[self.state] == true end
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

-- Tras un golpe: UN golpe por ocasión. Mareada → se recupera; empapada → sale ya del agua
function Snow:onDamaged(n, kind)
    if self:isDying() then return end
    if self:phaseNow() then return end
    if self.state == 'soaked' then
        self.deadTimer = math.max(self.deadTimer, (self.props.soakTime or 2.8) - 0.4)
    elseif self.state ~= 'frozen' then
        self:enter('recover')
        self.vx = 0
    end
end

-- Si el golpe la dejó por debajo del umbral de fase, cambia YA. true si cambió.
function Snow:phaseNow()
    if self:isDying() or self.state == 'phase_up' or self:phaseFor() <= self.phase then return false end
    self:stopRoll()
    self:enter('phase_up')
    self.vx = 0
    return true
end

-- Derrotada: muerte propia (se agrieta → revienta → la bolita huye)
function Snow:defeat()
    self.hp, self.inv, self.ghost = 0, 0, false
    self.proj = {}
    for _, c in ipairs(self.icicles or {}) do
        if c.st == IC_FALL or c.st == IC_SHAKE then c.st, c.t, c.y = IC_READY, 0, c.top end
    end
    self.crackN = nil
    self.vx = 0
    self:enter('dying_crack')
    self:onDefeat()
end

-- ── Congelador ────────────────────────────────────────────────────────────────
-- Empapada → CONGELADA (FROZEN_T s; ground pound 3). Seca → solo aturdida (DAZE_T s).
-- Después queda escarchada `frostProof` s: ningún Congelador le hace nada.
local NO_FREEZE = { frozen = true, phase_up = true, dizzy = true }
function Snow:canFreeze()
    return self:isActive() and not NO_FREEZE[self.state] and self.inv <= 0 and (self.frostT or 0) <= 0
end
function Snow:freeze(t)
    if not self:canFreeze() then return false end
    self:stopRoll()
    Sound.play('cryoFreeze')
    Entity.emitFx('ice_freeze', self.x, self.y)
    if self.state == 'soaked' then
        self.frozenFor = FROZEN_T
        self:enter('frozen')
    else
        self.frostT = self.props.frostProof or 7
        self.dizzyFor = DAZE_T
        self.vx = 0
        self:enter('dizzy')
    end
    return true
end
function Snow:thaw()
    Sound.play('cryoFree')
    Entity.emitFx('ice_shatter', self.x, self.y)
    self.frostT = self.props.frostProof or 7       -- (sale escarchada: un rato sin volver a congelarse)
    if self:phaseNow() then return end
    self:enter('recover')
    self.vx = 0
end

-- (solo se ríe en su entrada: reírse de las muertes es cosa del Espejo)
function Snow:onPlayerDeath(pa) end

-- Aterriza (salto bajito, salto a plataforma, gran golpe): polvo, grietas, aplasta y
-- sacude los carámbanos de encima
function Snow:landed(level, crack)
    Entity.emitFx('snow_puff', self.x, self:feetY())
    self:crackUnder(level, crack)
    self:hitPlayers(level, true)
    self:shakeIcicles(self.x)
end

-- ── Update ────────────────────────────────────────────────────────────────────
function Snow:updateBoss(dt, level)
    if self.state == 'dormant' then return end           -- (antes de la pelea no hace nada)
    if not self.lake then self:findLake(level) end
    self.deadTimer = self.deadTimer + dt
    if self.shockT < 10 then self.shockT = self.shockT + dt end
    if (self.frostT or 0) > 0 and self.state ~= 'frozen' then self.frostT = math.max(0, self.frostT - dt) end
    self:updateProjectiles(level, dt)
    self:updateIcicles(level, dt)
    self:hitWithShots(level)
    if self:isActive() then
        self:checkSoak(level)
        self:regrowLake(level, dt)
    end
    local st, t = self.state, self.deadTimer

    if st == 'fight' then self:enter('idle'); return end

    if st == 'idle' or st == 'rest' then
        self:physics(level, dt); self:friction(level, dt)
        local wait = (st == 'rest') and REST_T[self.phase] or IDLE_T[self.phase]
        if t >= wait and self.onGround then self:nextAttack(level) end

    elseif st == 'hop' then
        self:physics(level, dt)
        if self.onGround and self.vy >= 0 and t > 0.1 then
            self:enter('land')
            Sound.play('snowLand')
            Entity.emitFx('shake_small', self.x, self.y)
            self:landed(level, LAND_CRACK)
            self.vx = self.vx * 0.3
            self.escaping = nil
        end

    elseif st == 'land' then
        self:physics(level, dt); self:friction(level, dt)
        if t >= LAND_T[self.phase] then self:enter('idle') end

    elseif st == 'leap_wind' then
        -- Se agacha (la marca de donde caerá ya se ve) y salta
        self:physics(level, dt); self:friction(level, dt)
        self.facing = (self.landX >= self.x) and 1 or -1
        if self.escaping and (self.lastSplash or -1) < math.floor(t / 0.15) then
            self.lastSplash = math.floor(t / 0.15)                -- (chapotea cogiendo impulso)
            Entity.emitFx('snow_puff', self.x + rand(-1, 1) * self.outerW * 0.4, self:feetY() - 10)
        end
        if t >= self:leapWind() then
            self.passY = self.landY
            if self.escaping then
                -- GRAN SALTO pesado fuera del agua (atraviesa el hielo y las plataformas)
                self:jumpTo(self.landX, self.landY, ESCAPE_UP)
                Sound.play('waterSplash', 0.6)
                Sound.play('snowLand', 0.7, 0.9)
                Entity.emitFx('shake_small', self.x, self.y)
                Entity.emitFx('snow_crash', self.x, self:feetY() - 20)
            else
                self:jumpTo(self.landX, self.landY)
                Sound.play('snowLand', 1.4, 0.6)
            end
            Sound.play('snowSpit', 0.5, 0.5)
            self.lastSplash = nil
            self:enter('leap')
        end

    elseif st == 'leap' then
        self:physics(level, dt)
        if self.onGround and self.vy >= 0 and t > 0.1 then
            self.vx = 0
            self.passY = nil
            self:enter('leap_land')
            Sound.play('snowLand', self.escaping and 0.7 or 0.9)
            Entity.emitFx(self.escaping and 'shake_big' or 'shake_small', self.x, self.y)
            self:landed(level, LAND_CRACK)
            self.escaping = nil
        end

    elseif st == 'leap_land' then
        self:physics(level, dt); self:friction(level, dt)
        if t >= LEAP_LAND[self.phase] then self:enter('idle') end

    elseif st == 'shoot' then
        self:physics(level, dt); self:friction(level, dt)
        local sw, sg = SHOOT_WIND[self.phase], SHOOT_GAP[self.phase]
        local due = math.floor((t - sw) / sg) + 1
        while t >= sw and self.shotN < math.min(self.shots, due) do
            self.shotN = self.shotN + 1
            self:spit(level)
        end
        if t >= sw + self.shots * sg + 0.2 then self:enter('idle') end

    elseif st == 'windup' then
        self:physics(level, dt); self:friction(level, dt)
        local pa = self:target(level)
        if pa then self.dir = (pa.x < self.x) and -1 or 1 end
        self.facing = self.dir
        if t >= WINDUP_T[self.phase] then
            self:enter('roll')
            -- Fin DETERMINISTA: un presupuesto de tiempo empujando; al gastarse se deja
            -- deslizar (sin rebotes) y se para al frenar o al chocar
            self.rollLeft = ROLL_MAX_T[self.phase]
            self.crashes, self.rollRun = 0, 0
            self.vx = self.dir * 120
            Sound.play('snowSpit', 0.5)
        end

    elseif st == 'roll' then
        local spd = ROLL_SPD[self.phase]
        self.vx = self.vx + self.dir * ROLL_ACC * dt
        if math.abs(self.vx) > spd then self.vx = self.dir * spd end
        local x0 = self.x
        local hit, def = self:physics(level, dt)
        self.rollRun = (self.rollRun or 0) + math.abs(self.x - x0)
        self:hitPlayers(level)
        self:wearIce(level, dt)
        if hit then self:crash(level, def) end
        if self.state == 'roll' then
            self.rollLeft = (self.rollLeft or 0) - dt
            if self.rollLeft <= 0 then self:endRoll() end
        end

    elseif st == 'slide' then
        local x0 = self.x
        local hit, def = self:physics(level, dt)
        self.rollRun = (self.rollRun or 0) + math.abs(self.x - x0)
        self:friction(level, dt)
        self:wearIce(level, dt)
        if math.abs(self.vx) > 200 then self:hitPlayers(level) end
        if hit then self:crash(level, def) end
        if self.state == 'slide' and self.vx == 0 then self:enter('recover') end

    elseif st == 'dizzy' then
        self:physics(level, dt); self:friction(level, dt)
        if t >= (self.dizzyFor or DIZZY_T) then self:enter('recover') end

    elseif st == 'soaked' then
        self:physics(level, dt); self:friction(level, dt)
        if t >= (self.props.soakTime or 2.8) then
            self:enter('idle')
            self.deadTimer = 99                                   -- (sale ya: nextAttack la saca del agua)
        end

    elseif st == 'frozen' then
        local hit = self:physics(level, dt)          -- (resbala dentro del bloque de hielo)
        self:friction(level, dt)
        if hit then self.vx = 0 end
        if t >= (self.frozenFor or FROZEN_T) then self:thaw() end

    elseif st == 'recover' then
        self:physics(level, dt); self:friction(level, dt)
        if t >= RECOVER_T[self.phase] then self.streak = 0; self:enter('idle') end

    elseif st == 'slam_up' then
        self:physics(level, dt)
        if self.vy >= 0 then
            self.vx, self.vy = 0, 0
            self:enter('slam_hold')
        end

    elseif st == 'slam_hold' then
        if t >= SLAM_HOLD[self.phase] then
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
            -- olas solo si cae en el suelo de la arena (encima de una plataforma, no)
            local zy1 = select(4, self:zoneBounds())
            if self:feetY() >= zy1 - 8 then
                self.shockT, self.shockX, self.shockY = 0, math.floor(self.x), math.floor(self:feetY())
            end
            self:landed(level, SLAM_CRACK)
            self:slamWave(level)
        end

    elseif st == 'slam_land' then
        self:physics(level, dt)
        if t >= SLAM_LAND[self.phase] then self:enter('idle') end

    elseif st == 'phase_up' then
        -- Ruge, suelta nieve y ENCOGE (la escala va en el snapshot)
        self:physics(level, dt); self:friction(level, dt)
        if t >= 0.3 and not self.roared then
            self.roared = true
            Sound.play('snowRoar')
            Entity.emitFx('shake_roar', self.x, self.y)
            Entity.emitFx('frost_breath', self.x, self.y)
        end
        local from, to = SC[self.phase] or SC[3], SC[math.min(3, self.phase + 1)]
        if t >= 0.5 then
            local k = math.min(1, (t - 0.5) / 0.8)
            local sc = math.floor(from + (to - from) * k + 0.5)
            if sc ~= self.sc then
                self:setScale(sc)
                Sound.play('snowCrack', 1.1)
                Entity.emitFx('snow_shed', self.x, self.y)
            end
        end
        if t >= PHASE_T then
            self.roared = nil
            self.phase = math.min(3, self.phase + 1)
            self:setScale(SC[self.phase])
            self.cycleI, self.streak = 0, 0
            if self.phase >= 2 then self:growIcicles() end
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
            self:regrowLake(level, 0, true)               -- (el lago se hiela: se puede cruzar)
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

-- El choque al rodar contra una pared o un escalón: rebota mientras le queden rebotes
-- (empujando, con presupuesto); el último choque fuerte (rápida y tras rodar CRASH_RUN
-- casillas: arrancar pegada a la pared no cuenta) la MAREA; flojo, se para
function Snow:crash(level, def)
    local speed = math.abs(self.vx)
    Sound.play('snowCrash')
    Entity.emitFx('snow_crash', self.x + self.dir * self.outerW / 2, self.y)
    Entity.emitFx('shake_small', self.x, self.y)
    self:toggleHit(level)
    self.crashes = (self.crashes or 0) + 1
    if self.state == 'roll' and self.bounces > 0 and (self.rollLeft or 0) > 0 and self.crashes < MAX_CRASHES then
        self.bounces = self.bounces - 1
        self.dir = -self.dir
        self.vx = self.dir * math.max(260, speed * 0.85)
        self.rollRun = 0
        return
    end
    self:stopRoll()
    if speed >= CRASH_SPD and (self.rollRun or 0) >= CRASH_RUN * T then
        self.vx = -self.dir * 140
        self.vy = -380
        self.dizzyFor = DIZZY_T
        Sound.play('snowDizzy')
        self:enter('dizzy')
        return
    end
    self.vx = -self.dir * 160
    self.vy = -300
    self:enter('recover')
end

-- Se acaba el empuje: desliza (sin más rebotes)
function Snow:endRoll()
    self.bounces, self.rollLeft = 0, 0
    self:enter('slide')
end
function Snow:stopRoll()
    self.bounces, self.rollLeft = 0, 0
end

-- Rodando contra un Activador ON/OFF: lo cambia, como un cabezazo. Una vez por choque.
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
    local sc = self.sc or SC[1]
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
    local sc = SC[1] * self:introScale(t)
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
-- { fase, escala, ola(t·100, x, y), dir, congelada(s·10), escarcha(s·10), mareada(s·10),
--   marca del salto (x, y), nBolas, {id, x, y}…, nCarámbanos, {estado, y, t·100}… }
local NB = 11
function Snow:netPackExtra()
    local out = { self.phase, self.sc, math.floor(math.min(self.shockT, 99) * 100), self.shockX, self.shockY,
                  self.dir or 1, math.floor((self.frozenFor or FROZEN_T) * 10), math.floor((self.frostT or 0) * 10),
                  math.floor((self.dizzyFor or DIZZY_T) * 10), self.landX or 0, self.landY or 0, #self.proj }
    for _, b in ipairs(self.proj) do
        out[#out + 1] = b.id; out[#out + 1] = math.floor(b.x); out[#out + 1] = math.floor(b.y)
    end
    local ics = self:icicleList()
    out[#out + 1] = #ics
    for _, c in ipairs(ics) do
        out[#out + 1] = c.st; out[#out + 1] = math.floor(c.y); out[#out + 1] = math.floor(c.t * 100)
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
    self.dir, self.frozenFor, self.frostT, self.dizzyFor = b[6], b[7] / 10, b[8] / 10, b[9] / 10
    self.landX, self.landY = b[10], b[11]
    local pb, k = readList(b, NB + 1, 3)
    local pa = (type(a[NB + 1]) == 'number') and readList(a, NB + 1, 3) or {}
    local prev = {}
    for _, e in ipairs(pa) do if e[1] then prev[e[1]] = e end end
    self.proj = {}
    for _, e in ipairs(pb) do
        local x, y = e[2], e[3]
        local o = prev[e[1]]
        if o and type(o[2]) == 'number' and type(o[3]) == 'number' then x, y = o[2] + (x - o[2]) * f, o[3] + (y - o[3]) * f end
        self.proj[#self.proj + 1] = { id = e[1], x = x, y = y }
    end
    local ib = readList(b, k, 3)
    local ka = (type(a[NB + 1]) == 'number') and (NB + 2 + (a[NB + 1] or 0) * 3) or nil
    local ia = ka and readList(a, ka, 3) or {}
    local ics = self:icicleList()
    for i, e in ipairs(ib) do
        local c = ics[i]
        if c then
            local y = e[2]
            local o = ia[i]
            if o and o[1] == e[1] and type(o[2]) == 'number' then y = o[2] + (y - o[2]) * f end
            c.st, c.y, c.t = e[1], y, e[3] / 100
        end
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
    if st == 'dizzy' or st == 'soaked' then return 'body', 11 + math.floor(t * 6) % 2 end
    if st == 'dying_crack' then return 'body', 10 end
    if self.inv > 0 and not self.ghost and self.state == 'recover' then return 'body', angry and 10 or 9 end
    if st == 'land' or st == 'slam_land' or st == 'leap_land' then return 'body', b + ((t < 0.12) and 3 or 2) end
    if st == 'windup' or st == 'leap_wind' then return 'body', b + 3 end
    if st == 'leap' then return 'body', b + 4 end
    if st == 'shoot' then
        local ph = self.phase or 1
        local u = t - SHOOT_WIND[ph]
        if u < 0 then return 'body', b + 2 end
        return 'body', b + ((u % SHOOT_GAP[ph]) < SHOOT_GAP[ph] * 0.6 and 4 or 1)
    end
    if st == 'phase_up' then return 'body', 8 end
    if st == 'slam_hold' then return 'body', b + 4 end
    if st == 'rest' then return 'body', b + ((math.floor(t * 3) % 2 == 0) and 1 or 2) end
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
    local now = love.timer.getTime()
    if st == 'intro' and t < ROLL_IN then sc = math.max(2, math.floor(self.sc * self:introScale(t) + 0.5)) end
    local fx = math.floor(self.x - camX)
    local fy = math.floor(self.y - camY + (self.outerH / 2))         -- pies
    if st == 'intro' and t < ROLL_IN then fy = math.floor(self.y - camY + 6.5 * SC[1] * self:introScale(t)) end
    -- temblor (carga, fase, grietas) y saltitos de risa
    local sh = 0
    if st == 'windup' then sh = 2 + math.floor(t / WINDUP_T[self.phase or 1] * 3) end
    if st == 'leap_wind' then sh = 1 + math.floor(math.min(1, t / self:leapWind()) * 2) end
    if st == 'phase_up' or st == 'dying_crack' then sh = 3 end
    if (self.phase or 1) == 3 and st == 'idle' then sh = 1 end
    if st == 'intro' and t >= SPIT_WIND and t < SPIT_AT then                    -- coge aire: tiembla cada vez más
        sh = 1 + math.floor((t - SPIT_WIND) / (SPIT_AT - SPIT_WIND) * 2.99)
    end
    if st == 'intro' and t >= SPIT_AT and t < SPIT_AT + 0.1 then fy = fy - sc end  -- (retroceso al escupir)
    if st == 'soaked' then fy = fy + math.floor(math.sin(now * 5) * sc * 0.5) end  -- (flota en el agua)
    if sh > 0 then fx = fx + math.floor((math.random() * 2 - 1) * sh + 0.5); fy = fy + math.floor((math.random() * 2 - 1) * sh * 0.5 + 0.5) end
    local r, g, bl = 1, 1, 1
    if st == 'soaked' then                                   -- empapada: más oscura y azulada, gotea
        r, g, bl = 0.72, 0.8, 0.95
        if (self.lastDrip or 0) + 0.07 < now then
            self.lastDrip = now
            emit('snow_drip', self.x + (math.random() - 0.5) * self.outerW * 0.8, self.y - self.outerH * 0.2)
        end
    elseif (self.frostT or 0) > 0 and st ~= 'frozen' then    -- escarchada: azulada, latiendo
        local k = 0.5 + 0.5 * math.sin(now * 9)
        r, g = 0.62 + 0.15 * k, 0.82 + 0.1 * k
        if (self.lastFrost or 0) + 0.12 < now then
            self.lastFrost = now
            emit('cryo_mist', self.x + (math.random() - 0.5) * self.outerW, self.y + (math.random() - 0.5) * self.outerH)
        end
    end
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
    if ((self.phase or 1) >= 3 or st == 'dizzy') and kind ~= 'roll' and st ~= 'frozen' and st ~= 'soaked' then
        local k = (now * 1.4) % 1
        love.graphics.setColor(1, 1, 1, alpha * (1 - k))
        sweat:draw(math.floor(now * 4) % 2 + 1, fx + 6 * sc, fy - (15 - topRow(fr)) * sc + k * 3 * sc, 0, sc * 0.5, sc * 0.5)
    end
    -- Mareada / empapada: estrellas (gotas azules empapada) girando
    if st == 'dizzy' or st == 'soaked' then
        for i = 0, 2 do
            local a = now * 5 + i * (math.pi * 2 / 3)
            local x = math.floor(fx + math.cos(a) * 7 * sc)
            local y = math.floor(fy - 15 * sc + math.sin(a) * 2 * sc)
            if st == 'soaked' then love.graphics.setColor(0.55, 0.8, 1, alpha) else love.graphics.setColor(1, 0.9, 0.3, alpha) end
            love.graphics.rectangle('fill', x - 6, y - 2, 12, 4)
            love.graphics.rectangle('fill', x - 2, y - 6, 4, 12)
        end
    end
    return fx, fy, sc
end

-- Sombra en (x, gy) de ancho w: más oscura cuanto más cerca (k 0..1)
local function shadow(x, gy, w, k, camX, camY)
    love.graphics.setColor(0, 0, 0, 0.18 + 0.22 * k)
    love.graphics.rectangle('fill', math.floor(x - camX - w / 2), math.floor(gy - camY - 6), math.floor(w), 6)
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

    -- Sombra donde va a caer (saltando / gran golpe): sobre la superficie real de debajo
    if st == 'hop' or st == 'slam_up' or st == 'slam_hold' or st == 'slam_fall' then
        local gy = self:groundBelow(self.x, self:feetY())
        local k = math.max(0.2, 1 - (gy - self:feetY()) / (6 * T))
        shadow(self.x, gy, self.outerW * (0.5 + 0.35 * k), k, camX, camY)
    end
    -- Salto a plataforma: MARCA donde va a caer (parpadea, se cierra al acercarse)
    if st == 'leap_wind' or st == 'leap' then
        local k = (st == 'leap') and 1 or math.min(1, t / self:leapWind())
        local w = math.floor(self.outerW * (1.3 - 0.4 * k))
        local x0 = math.floor(self.landX - camX - w / 2)
        local y0 = math.floor(self.landY - camY - 8)
        local blink = (math.floor(now * 10) % 2 == 0) and 1 or 0.6
        love.graphics.setColor(0, 0, 0, 0.45)
        love.graphics.rectangle('fill', x0 + 2, y0 + 2, w, 6)
        love.graphics.setColor(0.55, 0.85, 1, 0.8 * blink)
        love.graphics.rectangle('fill', x0, y0, w, 6)
        love.graphics.rectangle('fill', x0, y0 - 14, 6, 14)
        love.graphics.rectangle('fill', x0 + w - 6, y0 - 14, 6, 14)
    end

    if st == 'dying_burst' then
        -- (solo quedan los trozos de nieve)
    elseif st == 'dying_flee' then
        local k = math.max(0, 1 - math.max(0, t - FLEE_T + 1))
        love.graphics.setColor(1, 1, 1, k)
        flee:draw(math.floor(t * 10) % 2 + 1, math.floor(self.x - camX), math.floor((self.fleeY or self:feetY()) - camY - 6 * 5),
                  0, 5 * (self.fleeDir or 1), 5)
    else
        local _, _, sc = self:drawBody(camX, camY, alpha)
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
        ballImg:draw(1, math.floor(b.x - camX), math.floor(b.y - camY), 0, 4, 4)
    end
    -- Carámbanos del techo: crecen, tiemblan (sombra donde caerán) y caen
    for _, c in ipairs(self.icicles or {}) do
        local cx = math.floor(c.x - camX)
        if c.st == IC_GROW or c.st == IC_READY or c.st == IC_SHAKE then
            local k = (c.st == IC_GROW) and math.min(1, c.t / ICE_GROW) or 1
            if c.st == IC_SHAKE then
                cx = cx + math.floor(math.sin(now * 70) * 3)
                c.gy = c.gy or self:groundBelow(c.x, c.top + ICE_LEN + 8)
                local u = math.min(1, c.t / ICE_SHAKE)
                shadow(c.x, c.gy, 14 + 30 * u, u, camX, camY)
            else
                c.gy = nil
            end
            love.graphics.setColor(1, 1, 1, 1)
            -- (crece hacia abajo desde el techo)
            love.graphics.draw(icicleImg.image, icicleImg.quads[1], cx, math.floor(c.top - camY), 0, 4, 4 * k, 4, 0)
        elseif c.st == IC_FALL then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(icicleImg.image, icicleImg.quads[1], cx, math.floor(c.y - camY), 0, 4, 4, 4, 0)
        end
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

-- Primera superficie (bloque o plataforma) bajo (x, y) dentro de la zona (solo dibujo)
function Snow:groundBelow(x, y)
    local zy1 = select(4, self:zoneBounds())
    local level = self.levelRef
    if not level then return zy1 end
    for yy = math.floor(y), math.min(zy1 + 2 * T, level.tileH * T), 8 do
        if level:collisionAt(x, yy, true) then return math.floor(yy / 8) * 8 end
    end
    return zy1
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

-- Editor: cada carámbano (línea) y lo que alcanza la sacudida de un aterrizaje
function Snow.drawEditorOverlay(props, cx, cy, zoom, ctx)
    if not ctx or type(props.icicles) ~= 'table' then return end
    love.graphics.setColor(0.6, 0.9, 1, 0.5)
    for _, p in ipairs(props.icicles) do
        local x = (p.col - 0.5) * ctx.t - ctx.camX
        local y = (p.row - 1) * ctx.t - ctx.camY
        love.graphics.rectangle('fill', math.floor(x - 2), math.floor(y), 4, ctx.t)
        love.graphics.rectangle('line', math.floor(x - ICE_R * ctx.t), math.floor(y), math.floor(2 * ICE_R * ctx.t), ctx.t)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local G = 'Bola de nieve'
return {
    name = 'snowboss', label = 'Gran Bola de Nieve', category = 'Jefes',
    description = 'Jefe de hielo en 3 fases que la encogen: rueda, escupe bolas, salta a las plataformas y da '
               .. 'un gran golpe. Solo se le daña MAREADA (choca rodando contra una pared o le cae un carámbano), '
               .. 'EMPAPADA (cae al agua del lago) o CONGELADA (empapada + chorro de un Congelador).',
    class = Snow,
    boss = { title = 'GRAN BOLA DE NIEVE' },
    hide = Boss.HIDE,
    defaults = { points = 30 },
    props = Boss.props({ hp = 14, hpPerPlayer = 4 }, {
        { key='phase2', kind='number', label='Fase 2 con vida ≤', group=G, default=0.66,
          min=0.1, max=0.95, step=0.01, help='Fracción de vida: encoge, salta a las plataformas y salen los carámbanos' },
        { key='phase3', kind='number', label='Fase 3 con vida ≤', group=G, default=0.33,
          min=0.05, max=0.9, step=0.01, help='Encoge más: gran golpe que rompe el hielo; aparece lo que tenga "fase 3"' },
        { key='icicles', kind='points', label='Carámbanos del techo', group=G, min=1, max=16,
          default=function(d)
              local c, r = d.col or 1, math.max(1, (d.row or 10) - 9)
              return { { col = c - 6, row = r }, { col = c - 2, row = r }, { col = c + 2, row = r }, { col = c + 6, row = r } }
          end,
          help='Celdas de las que cuelgan (del borde de arriba). Salen en la fase 2; un aterrizaje cerca los hace caer' },
        { key='icicleRegrow', kind='number', label='Carámbanos vuelven a crecer (s)', group=G, default=6,
          min=1, max=30, step=0.5 },
        { key='soakTime', kind='number', label='Empapada (s)', group=G, default=2.8,
          min=0.5, max=10, step=0.1, help='Lo que se queda atascada (y vulnerable) al caer al agua' },
        { key='lakeRegrow', kind='number', label='El hielo fino se rehace (s)', group=G, default=4,
          min=1, max=30, step=0.5, help='Segundos que tarda una casilla rota del lago en volver a helarse' },
        { key='frostProof', kind='number', label='Escarchada tras el hielo (s)', group=G, default=7,
          min=0, max=20, step=0.5, help='Tras un Congelador no le vuelve a afectar ninguno durante este tiempo' },
    }),
    editor = { sprite = 'assets/images/bosses/snowboss/body-Sheet.png', frameW = 16 },
}
