-- CRABBY LÚGUBRE ("Gloomy Crabby", Cancrocaeca xenomorpha: cangrejo de cueva, ciego y sin
-- pigmento, de patas larguísimas). Un enemigo de OTRA clase, para los niveles a oscuras
-- (level.dark): no tiene ruta, no se esconde, no mata al tocarlo. Caza DE OÍDO y huye de la LUZ.
--
--   A oscuras solo se le ven dos puntos luminosos (renderGlow: encima de la oscuridad).
--   explorar ('walk')   recorre suelo, paredes y techo (Crawler) a su aire: cambia de sentido cada
--                       cierto tiempo y a veces se para ('idle').
--   OYE (src/world/Noise.lua): cada ruido tiene un radio y deja una MARCA "!" roja donde sonó
--                       — salto 3,5 casillas, un golpe a un jugador o un enemigo muerto 9, ground
--                       pound 15; ANDAR no hace ruido —; el suyo de
--                       oído lo multiplica (`hearing`). Si lo oye → 'hunt': va hacia donde SONÓ
--                       (no hacia el jugador: no sabe dónde está), por la superficie.
--   'search'            llega al sitio y no hay nadie: ronda por allí `searchTime` s y, si no
--                       vuelve a oír nada, lo deja y sigue explorando.
--   CASI NO SUENA (el silencio es la tensión del nivel; el usuario lo encontró ruidoso): lo que
--   le pasa se cuenta con un ICONO que flota sobre él y se ve a oscuras — "!" ha oído algo, "?"
--   busca, "…" pierde el rastro —; solo suenan el siseo antes de saltar y el salto.
--   SIENTE de cerca     a un jugador que se MUEVE a menos de `senseRange` casillas (a uno quieto,
--                       solo a la mitad): entonces se agacha ('crouch', `leapWind` s: los puntos
--                       parpadean y sisea = el aviso) y SALTA hacia él ('leap', balístico). En el
--                       aire, tocarlo = 1 de vida + empujón. Cae donde caiga y se agarra a lo que
--                       toque (nunca se queda clavado como los otros Crabbies); luego 'rest'.
--   LUZ ('flee')        si le da la linterna de un jugador (Lights.lit: cono, alcance y sin pared
--                       en medio) se ASUSTA: huye de la luz al doble de velocidad y olvida lo que
--                       perseguía; a oscuras otra vez, tarda `calmTime` s en calmarse.
--   BURLA ('taunt'): cuando le da a un jugador (de un salto o al tocarlo) se queda un momento
--   haciendo flexiones con los ojos parpadeando: da tiempo a apartarse.
--   NAVEGAR: planea el camino por las superficies (Gloomy:plan) y lo anda entero; no titubea.
--   Tocarlo = 1 de vida (nunca mata). Se le pisotea como a cualquier Crabby (también en paredes
--   y techo, con las reglas del trepador).
-- Todo lo que se dibuja sale de state + frame + deadTimer + la superficie (red: Crawler.netPack).
-- Arte: assets/images/gloomy/ (tools/ui/make_gloomy_sprites.py); sonidos: tools/sounds/gloomy.py.

local Entity      = require 'src/world/entities/Entity'
local Crawler     = require 'src/world/entities/Crawler'
local Lights      = require 'src/world/Lights'
local Noise       = require 'src/world/Noise'
local SpriteStrip = require 'src/fx/SpriteStrip'

local T = TILE_PX
local S = GUMMY_SCALE
local FW, FH = 26, 15                     -- cuadro (px de arte)
local F_IDLE, F_CROUCH, F_LEAP, F_SCARED, F_DEAD = 5, 6, 7, 8, 9

local Gloomy = Entity.extend(Entity, {
    walkFps = 11, walkFrames = 4,
    idleEvery = { 3.0, 7.0 }, idleFor = { 0.8, 1.8 },
    debugColor = { 0.6, 0.8, 1 },
    -- (la caja de fuera, todo el alto: el trepador se apoya a outerH/2 de la superficie; de ancho,
    -- el cuerpo y el arranque de las patas — las patas largas no cuentan)
    hitbox = { outerW = 12 / FW, outerH = 1, innerW = 9 / FW, innerH = 8 / FH },
})

local REST_T     = 0.7                    -- s quieto tras un salto
local LEAP_T     = 0.5                    -- s de vuelo del salto (lo que tarda en llegar al objetivo)
local LEAP_MAX   = 5.0                    -- casillas: no salta más lejos
local FLEE_PLAN  = 0.6                    -- s entre decisiones de por dónde huir
local TAUNT_T    = 1.1                    -- s de burla tras darle a un jugador
local FLEE_K     = 2.0                    -- velocidad huyendo (× la suya)
local HUNT_K     = 1.5                    -- velocidad yendo a un ruido
local ARRIVE     = 0.9 * T                -- "ha llegado" al sitio del ruido
local STILL_SPD  = 30                     -- px/s: por debajo, el jugador está "quieto"
local GLOW       = { 1, 0.77, 0.35 }      -- ámbar

local body, glow, icons
-- DURO: un pisotón normal solo rebota en él; hace falta un GROUND POUND para matarlo (regla
-- genérica de Interactions.check: `needsPound`)
Gloomy.needsPound = true
Crawler.mixin(Gloomy)                     -- trepador: cajas giradas, normal de su superficie, soltarse, caer
-- (encima de él no hace daño: solo de lado… o cuando es ÉL quien salta sobre ti)
function Gloomy:hurtsFromAbove() return self.state == 'leap' end

function Gloomy.loadAssets()
    if body then return end
    icons = SpriteStrip.load('assets/images/gloomy/icons-Sheet.png', 7)
    body = SpriteStrip.load('assets/images/gloomy/gloomy-Sheet.png', FW)
    glow = SpriteStrip.load('assets/images/gloomy/glow-Sheet.png', FW)
end
function Gloomy.sizePx() return FW * S, FH * S end

function Gloomy:init()
    self.crawl = true
    self.cnx, self.cny = 0, self.flipped and 1 or -1
    self.cdir = self.flipped and -self.facing or self.facing
    self.cattached = nil
    self.leftBoundPx, self.rightBoundPx = -math.huge, math.huge      -- (sin ruta)
    self.heardSeq = nil               -- (el primer paso: desde los ruidos de ahora)
    self.goalX, self.goalY = nil, nil
    self.wanderT = 1 + math.random() * 3
    self.modeT, self.stallT, self.bestD = 0, 0, nil
    self.calmT = 0
    self.leapCd = 0
    self.icon, self.iconT = 0, 0
end

-- (Súbdito de reserva: Entity:makeReserve. Cajas giradas, normal y soltarse: Crawler.mixin, abajo)
function Gloomy:knockback(dir)
    self:releaseCrawl()
    self.goalX = nil
    Entity.knockback(self, dir)
end
-- (los trampolines no lo lanzan estando agarrado; suelto, sí)
function Gloomy:canBeLaunched() return not self.cattached and Entity.canBeLaunched(self) end

-- El empujón del salto (Interactions.run lo llama solo si el golpe quitó vida)
function Gloomy:onHurtPlayer(pa)
    if self.state == 'leap' then
        pa:recoil((pa.x >= self.x) and 1 or -1)
        self.gloat = true                                   -- (al posarse: burla)
    elseif self.cattached and self.state ~= 'flee' and self.state ~= 'crouch' then
        self:setMode('taunt')                               -- (le ha dado andando: se para a burlarse)
    end
end

-- ── Sentidos ─────────────────────────────────────────────────────────────────
function Gloomy:setMode(st)
    self.state, self.modeT = st, 0
    self.deadTimer = 0
    self.stallT, self.bestD = 0, nil
end

local function alive(pa) return pa.alive ~= false and not pa.dying end

-- Jugador que nota cerca (por lo que se mueve): el más próximo dentro de su alcance
function Gloomy:sensed(level)
    local r = (self.props.senseRange or 2.6) * T * require('src/Difficulty').k('sense')
    local best, bd
    for _, pa in ipairs(level.players or {}) do
        if alive(pa) then
            local d = math.sqrt((pa.x - self.x) ^ 2 + (pa.y - self.y) ^ 2)
            local moving = math.abs(pa.vx or 0) > STILL_SPD or math.abs(pa.vy or 0) > STILL_SPD
            if d <= (moving and r or r * 0.5) and (not bd or d < bd) then best, bd = pa, d end
        end
    end
    return best, bd
end

-- ¿Camino libre para saltar hasta (x, y)? (sin bloque sólido en la recta)
local function clearTo(level, x0, y0, x1, y1)
    local d = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
    local n = math.max(1, math.floor(d / 16))
    for i = 1, n - 1 do
        if level:collisionAt(x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n) then return false end
    end
    return true
end

function Gloomy:hear(level)
    if not self.heardSeq then self.heardSeq = (level.noises and level.noises.seq) or 0; return nil end
    local z, seq = Noise.heard(level, self.x, self.y, self.heardSeq, self.props.hearing or 1)
    self.heardSeq = seq
    return z
end

-- ── Orientarse: por dónde ir ─────────────────────────────────────────────────
-- No decide "hacia dónde tira" en cada momento (eso lo dejaba yendo y viniendo, temblando en
-- esquinas y plataformas: girar una esquina cambia qué sentido "acerca"). PLANEA: simula su propio
-- trepar (Crawler.move con una copia) en los DOS sentidos de la superficie, hasta PLAN_MAX px o
-- hasta dar la vuelta entera, y se queda con el que pasa más cerca del sitio. Luego anda ESE
-- camino entero, sin cambiar de idea, hasta el punto más cercano (`planLeft` px). Si desde ahí
-- el sitio sigue lejos (está en otra superficie: el suelo bajo su plataforma, la otra pared) y
-- tiene el paso libre, SALTA hasta él; si no, ronda.
local PLAN_MAX, PLAN_STEP = 44 * T, 16

local function probe(self, level, dir, gx, gy, away)
    local g = { x = self.x, y = self.y, cnx = self.cnx, cny = self.cny, cdir = dir, outerH = self.outerH,
                sprW = self.sprW, sprH = self.sprH, speed = self.speed, crawl = true, cattached = true }
    local function score() local d = math.sqrt((gx - g.x) ^ 2 + (gy - g.y) ^ 2); return away and -d or d end
    local best, bestAt, walked = score(), 0, 0
    while walked < PLAN_MAX do
        if not Crawler.move(g, level, PLAN_STEP) then break end
        walked = walked + PLAN_STEP
        local d = score()
        if d < best - 1 then best, bestAt = d, walked end
        if walked > 4 * PLAN_STEP and math.abs(g.x - self.x) < PLAN_STEP and math.abs(g.y - self.y) < PLAN_STEP
           and g.cnx == self.cnx and g.cny == self.cny then break end            -- (vuelta entera)
        if away and walked >= 7 * T then break end                              -- (huyendo: mira solo cerca)
    end
    return best, bestAt
end

-- Elige sentido y cuánto andar para acercarse lo más posible a (gx, gy) (o alejarse: `away`)
function Gloomy:plan(level, gx, gy, away)
    if not self.cattached then return end
    local b1, a1 = probe(self, level, 1, gx, gy, away)
    local b2, a2 = probe(self, level, -1, gx, gy, away)
    local pick = 1
    if b2 < b1 - 8 or (math.abs(b2 - b1) <= 8 and a2 < a1) then pick = -1 end
    if math.abs(b2 - b1) <= 8 and a1 == a2 then pick = self.cdir end             -- (da igual: sigue como iba)
    self.cdir = pick
    self.planLeft = (pick == 1) and a1 or a2
    self.planBest = (pick == 1) and b1 or b2
end

function Gloomy:crawl_(level, dt, speed)
    -- Otro enemigo delante: no lo atraviesa. Media vuelta y, si iba a algún sitio, deja ese camino
    -- (cazando: llega hasta ahí y busca o salta; huyendo: vuelve a planear en un momento)
    if Crawler.entityAhead(self, level) then
        self.cdir = -self.cdir
        self.planLeft = 0
        return false
    end
    if not Crawler.move(self, level, speed * dt) then return false end
    self.flipped = (self.cny == 1)
    if self.cnx ~= 0 then self.facing = self.cdir
    else self.facing = ((-self.cny * self.cdir) >= 0) and 1 or -1 end
    self:animateWalk(dt)
    return true
end

function Gloomy:animateWalk(dt)
    local tn = self.tuning
    self.animT = self.animT + dt
    if self.animT >= 1 / tn.walkFps then
        self.animT = self.animT - 1 / tn.walkFps
        self.frame = (self.frame % tn.walkFrames) + 1
    end
end

function Gloomy:startLeap(level, tx, ty)
    local dx, dy = tx - self.x, ty - self.y
    self:releaseCrawl()
    self.vx = dx / LEAP_T
    self.vy = dy / LEAP_T - ADV_GRAVITY * LEAP_T / 2
    self.facing = (dx >= 0) and 1 or -1
    self.onGround = false
    self:setMode('leap')
    self.leapCd = (self.props.leapEvery or 2.5)
    Sound.play('gloomyLeap')
end

-- ── Update ───────────────────────────────────────────────────────────────────
function Gloomy:updateCustom(dt, level)
    if self.state == 'reserve' then return true end
    Crawler.advanceTurn(self, dt)
    if self.cattached == nil then Crawler.attach(self, level, T) end        -- (al colocarlo)
    local st = self.state
    self.modeT = (self.modeT or 0) + dt
    self.deadTimer = self.modeT
    if self.leapCd > 0 then self.leapCd = self.leapCd - dt end
    -- Icono sobre él (en vez de sonidos: el silencio es parte del nivel): ! oye · ? busca · … lo deja
    if (self.iconT or 0) > 0 then
        self.iconT = self.iconT - dt
        if self.iconT <= 0 then self.icon = 0 end
    end
    if st == 'search' then self.icon, self.iconT = 2, 0.2 end
    local p = self.props

    -- En el aire (salto / soltado): balístico hasta tocar algo y agarrarse
    if st == 'leap' or not self.cattached then
        self.turnT = nil
        self.flipped = false
        self.vy = math.min(self.vy + ADV_GRAVITY * dt, 1400)
        local vx = self.vx
        self:moveAndCollide(level, vx * dt, self.vy * dt)
        local hitWall = st == 'leap' and self.vx ~= vx
        if self.onGround or hitWall or (st == 'leap' and self.modeT > 0.08 and self.vy == 0) then
            -- (se agarra a lo primero que toque: suelo, pared o techo)
            self.cnx, self.cny = 0, -1
            if hitWall and not self.onGround then self.cnx, self.cny = (vx > 0) and -1 or 1, 0 end
            if not Crawler.attach(self, level, T * 0.75) and self.onGround then Crawler.edgeRescue(self, level, dt) end
            self.vx, self.vy = 0, 0
            if self.cattached then
                self.cdir = (self.facing >= 0) and 1 or -1
                self:setMode(self.gloat and 'taunt' or 'rest')
                self.gloat = nil
            end
        elseif self.y > (level.heightPx or 1e9) + T * 4 then
            self.alive = false
        end
        if st ~= 'leap' and self.cattached then self:setMode('rest') end
        return true
    end

    -- LUZ: huye (manda sobre todo lo demás, salvo que ya esté en el aire)
    local lit, lx, ly = Lights.lit(level, self.x, self.y)
    if lit then
        if st ~= 'flee' then
            self:setMode('flee')
            self.icon, self.iconT, self.fleeT, self.planFor = 0, 0, 0, nil
        end
        self.calmT = p.calmTime or 1.2
        self.goalX, self.lightX, self.lightY = nil, lx, ly
    end
    if st == 'flee' or self.state == 'flee' then
        if not lit then
            self.calmT = self.calmT - dt
            if self.calmT <= 0 then self:setMode('walk'); self.wanderT = 2 + math.random() * 2; return true end
        end
        if self.modeT < 0.12 then self.frame = self.frame; return true end      -- (el respingo)
        -- por dónde huir: se decide (planeando) cada FLEE_PLAN s, no en cada paso
        self.fleeT = (self.fleeT or 0) - dt
        if self.fleeT <= 0 then
            self.fleeT = FLEE_PLAN
            self:plan(level, self.lightX or self.x, self.lightY or self.y, true)
        end
        self:crawl_(level, dt, self.speed * FLEE_K)
        return true
    end

    -- OÍDO: un ruido nuevo lo pone a cazar (o le cambia de sitio si ya cazaba)
    local z = self:hear(level)
    if z and st ~= 'crouch' then
        if st ~= 'hunt' then self.icon, self.iconT = 1, 0.9 end          -- ("!": lo ha oído)
        self.goalX, self.goalY = z.x, z.y
        self:setMode('hunt')
        st = 'hunt'
    end

    -- De cerca: a por él de un salto
    if (st == 'hunt' or st == 'search' or st == 'walk' or st == 'idle') and self.leapCd <= 0 and st ~= 'taunt' then
        local pa, d = self:sensed(level)
        if pa and d <= LEAP_MAX * T and clearTo(level, self.x, self.y, pa.x, pa.y) then
            self.leapX, self.leapY = pa.x, pa.y
            self.facing = (pa.x >= self.x) and 1 or -1
            self:setMode('crouch')
            Sound.play('gloomyWind')
            return true
        end
    end

    if st == 'crouch' then
        if self.modeT >= (p.leapWind or 0.45) then self:startLeap(level, self.leapX, self.leapY) end
        return true
    elseif st == 'rest' then
        if self.modeT >= REST_T then
            if self.goalX then self:setMode('search') else self:setMode('walk') end
        end
        return true
    elseif st == 'taunt' then
        -- Burla tras darle a un jugador: se queda en el sitio haciendo flexiones (solo dibujo)
        if self.modeT >= TAUNT_T then
            if self.goalX then self:setMode('search') else self:setMode('walk') end
        end
        return true
    elseif st == 'hunt' then
        local d = math.sqrt((self.goalX - self.x) ^ 2 + (self.goalY - self.y) ^ 2)
        if d <= ARRIVE then self:setMode('search'); return true end
        if self.planFor ~= self.goalX * 100000 + self.goalY then            -- sitio nuevo: planea el camino
            self.planFor = self.goalX * 100000 + self.goalY
            self:plan(level, self.goalX, self.goalY)
        end
        -- ATAJO: si andando queda mucho rodeo (≥ 3 casillas y bastante más que en línea recta) y el sitio está a tiro y a la vista,
        -- salta ya (del techo al suelo, de una pared a la otra); se mira cada poco, no cada paso
        self.cutT = (self.cutT or 0) - dt
        local cut = false
        if self.cutT <= 0 then
            self.cutT = 0.35
            cut = (self.planLeft or 0) >= 3 * T and (self.planLeft or 0) > d * 1.6 + T      -- (un rodeo de verdad)
                  and d <= LEAP_MAX * T and self.leapCd <= 0
                  and clearTo(level, self.x, self.y, self.goalX, self.goalY)
        end
        if (self.planLeft or 0) <= 0 or cut then
            -- Ya está lo más cerca que se puede llegar andando (o hay atajo): salta hasta el sitio o ronda
            if d <= LEAP_MAX * T and self.leapCd <= 0 and clearTo(level, self.x, self.y, self.goalX, self.goalY) then
                self.leapX, self.leapY = self.goalX, self.goalY
                self.facing = (self.goalX >= self.x) and 1 or -1
                self:setMode('crouch')
                Sound.play('gloomyWind')
            else
                self:setMode('search')
            end
            return true
        end
        local sp = self.speed * HUNT_K
        self.planLeft = self.planLeft - sp * dt
        self:crawl_(level, dt, sp)
        return true
    elseif st == 'search' then
        -- Ronda el último sitio: va y viene sin alejarse de él
        if self.modeT >= (p.searchTime or 4) then
            self.goalX, self.planFor = nil, nil
            self.icon, self.iconT = 3, 1.3                                 -- ("…": pierde el rastro)
            self:setMode('walk')
            return true
        end
        self.roamT = (self.roamT or 0) - dt
        if self.roamT <= 0 then
            self.roamT = 1.0 + math.random() * 0.8
            local d = self.goalX and math.sqrt((self.goalX - self.x) ^ 2 + (self.goalY - self.y) ^ 2) or 0
            if d > 2.5 * T then self:plan(level, self.goalX, self.goalY)     -- se alejó: vuelve (plan entero, sin titubeos)
            elseif math.random() < 0.5 then self.cdir = -self.cdir end
        end
        self:crawl_(level, dt, self.speed)
        return true
    elseif st == 'idle' then
        self.idleTimer = self.idleTimer + dt
        self.breatheT = self.breatheT + dt
        if self.idleTimer >= self.idleDuration then self:setMode('walk') end
        return true
    end

    -- Explorar a su aire
    self.state = 'walk'
    self.wanderT = self.wanderT - dt
    if self.wanderT <= 0 then
        self.wanderT = 2 + math.random() * 4
        local r = math.random()
        if r < 0.45 then self.cdir = -self.cdir
        elseif r < 0.65 and p.pauses ~= false then self:startIdle(); self.modeT = 0; return true end
    end
    self:crawl_(level, dt, self.speed)
    return true
end

-- ── Red ──────────────────────────────────────────────────────────────────────
function Gloomy:netPack()
    local surf, turn = Crawler.netPack(self)
    return { surf, turn, math.floor((self.modeT or 0) * 100), self.icon or 0 }
end
function Gloomy:netApply(a, b, f)
    a = a or b
    Crawler.netApply(self, b[1], a[2], b[2], f, self.state == 'leap')
    self.modeT = (tonumber(b[3]) or 0) / 100
    self.icon = tonumber(b[4]) or 0
    self.flipped = self.cattached and self.cny == 1 or false
end

-- ── Dibujo ───────────────────────────────────────────────────────────────────
function Gloomy:frameNow()
    local st = self.state
    if st == 'dead' then return F_DEAD end
    if st == 'leap' then return F_LEAP end
    if st == 'crouch' then return F_CROUCH end
    if st == 'idle' or st == 'rest' then return F_IDLE end
    -- burla: flexiones (agachado ↔ de pie) a toda prisa
    if st == 'taunt' then return (math.floor((self.modeT or 0) * 9) % 2 == 0) and F_CROUCH or F_IDLE end
    if st == 'flee' and (self.modeT or 0) < 0.12 then return F_SCARED end
    if st == 'stunned' or st == 'frozen' then return F_SCARED end
    return math.max(1, math.min(4, self.frame or 1))
end

-- Pies (px de pantalla) y ángulo de dibujo
function Gloomy:pose(camX, camY)
    if self.crawl and self.cattached and self.state ~= 'leap' then
        local fx, fy, ang = Crawler.pose(self)
        return math.floor(fx - camX + 0.5), math.floor(fy - camY + 0.5), ang
    end
    local ang = 0
    if self.state == 'leap' then ang = math.atan2(self.vy or 0, math.abs(self.vx or 0) + 1) * 0.5 * (self.facing or 1) end
    return math.floor(self.x - camX), math.floor(self.y - camY + self.sprH / 2), ang
end

function Gloomy:drawSheet(sheet, camX, camY)
    local px, py, ang = self:pose(camX, camY)
    local bx, by = self:breatheScale()
    local fr = self:frameNow()
    local face = self.facing or 1
    if self.crawl and self.cattached and self.cny == 1 then face = -face end
    love.graphics.draw(sheet.image, sheet.quads[fr], px, py, ang, S * face * bx, S * by, FW / 2, FH)
end

function Gloomy:render(camX, camY)
    if self.state == 'reserve' then return end
    love.graphics.setColor(1, 1, 1, 1)
    self:drawSheet(body, camX, camY)
end

-- Los dos puntos: SIEMPRE visibles (los estados lo llaman encima de la oscuridad; a la luz, ya
-- van en el propio cuerpo). Parpadean deprisa antes del salto (el aviso) y se apagan al morir
function Gloomy:renderGlow(camX, camY)
    local st = self.state
    if st == 'dead' or st == 'gone' or st == 'spawning' or st == 'reserve' then return end
    local a = 0.9
    if st == 'crouch' then a = (math.floor(love.timer.getTime() * 22) % 2 == 0) and 1 or 0.25
    elseif st == 'taunt' then a = (math.floor(love.timer.getTime() * 9) % 2 == 0) and 1 or 0.5
    elseif st == 'flee' then a = 0.55
    elseif st == 'idle' or st == 'rest' then a = 0.6 + 0.3 * math.sin(love.timer.getTime() * 3 + self.x) end
    love.graphics.setColor(GLOW[1], GLOW[2], GLOW[3], a)
    self:drawSheet(glow, camX, camY)
    -- un halo pequeño: los mismos puntos, tenues, un píxel de arte hacia cada lado
    love.graphics.setBlendMode('add')
    love.graphics.setColor(GLOW[1], GLOW[2], GLOW[3], 0.22 * a)
    for _, o in ipairs({ { S, 0 }, { -S, 0 }, { 0, S }, { 0, -S } }) do
        self:drawSheet(glow, camX - o[1], camY - o[2])
    end
    love.graphics.setBlendMode('alpha')
    -- icono flotando sobre él (siempre derecho, esté en el suelo, la pared o el techo)
    local ic = self.icon or 0
    if ic > 0 and st ~= 'flee' and st ~= 'leap' and st ~= 'crouch' then
        local bob = math.floor(math.sin(love.timer.getTime() * 6) * 2)
        local col = (ic == 1) and { 1, 0.85, 0.3 } or ((ic == 2) and { 0.75, 0.9, 1 } or { 0.7, 0.72, 0.8 })
        love.graphics.setColor(col[1], col[2], col[3], 0.95)
        love.graphics.draw(icons.image, icons.quads[ic], math.floor(self.x - camX), math.floor(self.y - camY - 46 + bob), 0, 3, 3, 3.5, 9)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Gloomy.drawEditorOverlay(props, cx, cy, zoom)
    love.graphics.setColor(1, 0.77, 0.35, 0.35)
    love.graphics.circle('line', cx, cy, (props.senseRange or 2.6) * T * zoom)
    love.graphics.setColor(1, 1, 1, 1)
end

local GG = 'Crabby lúgubre'
return {
    name = 'gloomy', label = 'Crabby lúgubre', category = 'Enemigos',
    description = 'Cangrejo de cueva ciego, para niveles A OSCURAS: explora suelo, paredes y techo sin ruta, va hacia '
               .. 'los RUIDOS (pasos, saltos, ground pound...), de cerca salta sobre el jugador (1 de vida + empujón) '
               .. 'y HUYE de la linterna. Tocarlo quita 1 de vida. Se le pisotea.',
    class = Gloomy,
    defaults = { speed = 70, points = 15, onTouch = 'hurt', pauses = true },
    hide = { 'movement', 'attach', 'patrol', 'turnAtEdges', 'bobAmp', 'flyMode', 'flyRange', 'dropOnSight', 'detectRange' },
    props = {
        { key='hearing', kind='number', label='Oído (× el radio de cada ruido)', group=GG, default=1, min=0, max=3, step=0.1,
          help='Salto 3,5 casillas · golpe a un jugador o enemigo muerto 9 · ground pound 15 (andar no suena). 0 = sordo' },
        { key='senseRange', kind='number', label='Nota a un jugador a (casillas)', group=GG, default=2.6, min=0.5, max=8, step=0.1,
          help='Si se mueve; a uno quieto, a la mitad. Entonces se agacha y salta sobre él' },
        { key='leapWind', kind='number', label='Aviso antes de saltar (s)', group=GG, default=0.45, min=0.15, max=2, step=0.05 },
        { key='leapEvery', kind='number', label='Entre saltos (s)', group=GG, default=2.5, min=0.5, max=10, step=0.1 },
        { key='searchTime', kind='number', label='Busca donde oyó algo (s)', group=GG, default=4, min=0, max=20, step=0.5 },
        { key='calmTime', kind='number', label='Tras la luz, se calma en (s)', group=GG, default=1.2, min=0, max=10, step=0.1 },
    },
    editor = { sprite = 'assets/images/gloomy/gloomy-Sheet.png', frameW = FW },
}
