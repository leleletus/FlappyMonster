-- src/world/entities/types/bosses/MegacrabbyRender.lua
-- El DIBUJO del Mega Crabby (megacrabby.lua; también el helado y el lúgubre, que heredan de él): cuerpo, pinzas, pinchos, ira y aturdido.
-- La carga megacrabby.lua con require(...)(Mega, P): añade sus funciones a la misma tabla. P = lo que antes eran locales del
-- archivo compartidos (docs/architecture/project-structure.md, «Split files»).
return function(Mega, P)
local AIM_LOCK_CEIL, AIM_LOCK_WALL, BossFx, CRAWL, Crawler, FALL_WAIT = P.AIM_LOCK_CEIL, P.AIM_LOCK_WALL, P.BossFx, P.CRAWL, P.Crawler, P.FALL_WAIT
local GETUP_T, INTRO, MS, SIDES, SPIKE_HW, SUMMON_WARN = P.GETUP_T, P.INTRO, P.MS, P.SIDES, P.SPIKE_HW, P.SUMMON_WARN

-- ── Dibujo ────────────────────────────────────────────────────────────────────
-- Todo lo "secundario" (squash & stretch, balanceo de pinzas, forcejeo,
-- partículas continuas) sale del estado y su tiempo (deadTimer), que llegan
-- por red: se ve igual en un jugador y online. Nada de esto toca la física.
local Particles
local TAU = math.pi * 2

local function spring(t, amp, freq, damp) return amp * math.exp(-t * damp) * math.cos(t * freq) end

-- Chasquidos del sonido megaWindup (= WINDUP_SNAPS de tools/sounds/megacrabby.py;
-- el último, las dos a la vez). ¿Está una pinza cerrada en `t`? → true, cuál (0 = las dos)
local WINDUP_SNAPS = { 0.02, 0.16, 0.27, 0.35, 0.41, 0.46, 0.50, 0.53 }
local function windupSnap(t)
    for i, s in ipairs(WINDUP_SNAPS) do
        if t >= s + 0.02 and t < s + 0.075 then
            return true, (i == #WINDUP_SNAPS) and 0 or ((i % 2 == 1) and 1 or 2)
        end
    end
    return false
end

-- Pinzas: cada una se cierra y abre sola cada cierto tiempo (más a menudo
-- cuando está nervioso). Solo es dibujo (cada cliente a su aire).
local function clawFrame(self, i, now, nervous)
    if self._clawForce then return self._clawForce[i] end   -- (al compás del sonido)
    self._claws = self._claws or { { next = now + math.random() }, { next = now + math.random() } }
    local c = self._claws[i]
    if now >= c.next then
        c.closedUntil = now + 0.12
        c.next = now + (nervous and (0.12 + math.random() * 0.3) or (0.7 + math.random() * 1.8))
    end
    return (c.closedUntil and now < c.closedUntil) and 2 or 1
end
local CLAW_ANIM = { 'claw_open', 'claw_closed' }

-- Deformación del cuerpo (sx, sy desde los pies), temblor y balanceo de las
-- pinzas (en píxeles de pinza) según lo que esté haciendo
function Mega:pose2d(now, moving, walkPhase)
    local st, t = self.state, self.deadTimer or 0
    local sx, sy, shx = 1, 1, 0
    local claws = { { 0, 0 }, { 0, 0 } }                 -- izquierda, derecha: dx, dy
    local function swing(amp, speed, spread)
        for i, side in ipairs(SIDES) do
            local ph = (i == 1) and 0 or 1.9
            claws[i][2] = math.sin(now * speed + ph) * amp
            claws[i][1] = side * (spread or 0)
        end
    end
    local breath = math.sin(now * 3)
    local spikeK = 1
    -- Rugido: se echa atrás, se estira hacia arriba temblando con las pinzas
    -- en alto y abiertas, y vuelve a su sitio
    local function roarPose(rt)
        if rt < 0.25 then
            local k = rt / 0.25
            sx, sy = 1 + 0.08 * k, 1 - 0.1 * k
            for i = 1, 2 do claws[i][2] = 1.0 * k end
        elseif rt < 1.15 then
            local k = math.min(1, (rt - 0.25) / 0.12)
            local tr = math.sin(now * 48) * 0.025
            sx, sy = 1 - 0.07 * k - tr, 1 + 0.16 * k + tr
            shx = math.floor(math.sin(now * 61) * 2 * self.MS / 4)
            spikeK = 1 + 0.1 * k + math.sin(now * 40) * 0.04
            for i, side in ipairs(SIDES) do
                claws[i][1] = side * 1.4 * k
                claws[i][2] = -3.4 * k + math.sin(now * 34 + i * 2) * 0.6
            end
        else
            local q = spring(rt - 1.15, 0.12, 16, 6)
            sx, sy = 1 + q, 1 - q
        end
    end
    if st == 'dormant' or st == 'recover' or st == 'ready' or ((st == 'chase' or st == 'intro') and not moving) then
        sy, sx = 1 + 0.025 * breath, 1 - 0.015 * breath
        swing(0.8, 2.1)
    elseif st == 'rest' then
        -- Descansando: respira hondo y despacio, pinzas caídas meciéndose...
        local deep = math.sin(now * 1.9)
        sy, sx = 1 + 0.04 * deep, 1 - 0.025 * deep
        swing(1.1, 1.3, 0.3)
        -- ...tras su emote
        local kind = self.restKind or 0
        if kind == 1 and t < 1.4 then
            roarPose(t)
        elseif kind == 2 and t < 1.15 then
            -- Amenaza: puñetazos al aire alternando las pinzas, botando
            local k = math.min(1, t / 0.12) * math.min(1, (1.15 - t) / 0.15)
            sy, sx = 1 + 0.05 * math.abs(math.sin(t * 16)) * k, 1 - 0.03 * math.abs(math.sin(t * 16)) * k
            for i, side in ipairs(SIDES) do
                local ph = math.max(0, math.sin(t * 16 + (i == 1 and 0 or math.pi)))
                claws[i][1] = side * (0.4 + 1.2 * ph) * k
                claws[i][2] = (-1.0 - 2.6 * ph) * k
            end
        elseif kind == 3 and t < 1.2 then
            -- Saca pecho: se encoge, el pincho crece de golpe y vibra
            if t < 0.5 then
                local k = t / 0.5
                sx, sy = 1 + 0.1 * k, 1 - 0.12 * k
                spikeK = 1 - 0.1 * k
                for i = 1, 2 do claws[i][2] = 1.2 * k end
            else
                local q = spring(t - 0.5, 0.18, 18, 5)
                sx, sy = 1 - 0.05 - q * 0.5, 1 + 0.1 + q
                spikeK = 1.35 + spring(t - 0.5, 0.25, 30, 5)
                for i, side in ipairs(SIDES) do claws[i][1] = side * 1.0; claws[i][2] = -1.6 end
            end
        end
    elseif st == 'roar_in' then
        roarPose(t)
    elseif st == 'land_in' then
        -- Aterriza del cielo: aplastado y rebotando
        local q = spring(t, 0.32, 17, 5)
        sx, sy = 1 + q, 1 - q
        for i, side in ipairs(SIDES) do claws[i][1] = side * 1.2 * math.max(0, q * 3); claws[i][2] = 1.2 end
    elseif st == 'fall_in' then
        -- Cayendo: estirado, patas y pinzas arriba agitándose
        sx, sy = 0.9, 1.14
        for i, side in ipairs(SIDES) do
            claws[i][1] = side * 0.8
            claws[i][2] = -2.4 + math.sin(now * 26 + i * 2) * 0.8
        end
    end
    if (st == 'chase' or st == 'climb' or st == 'ceiling' or st == 'wallclimb' or st == 'charge' or st == 'dying_flee') and moving then
        -- Andando: rebota con cada paso y las pinzas se mecen a contrapaso
        local b = math.sin(walkPhase * TAU)
        sy, sx = 1 + 0.045 * b, 1 - 0.03 * b
        for i, side in ipairs(SIDES) do
            local w = walkPhase * TAU + (i == 1 and 0 or math.pi)
            claws[i][1], claws[i][2] = math.cos(w) * 0.6, math.sin(w) * 1.3
        end
    end
    if (st == 'chase' or st == 'recover') and t < 0.6 and (self._prevState == 'getup' or self._prevState == 'pounce') then
        -- Aterriza del salto: se aplasta y rebota
        local q = spring(t, 0.24, 20, 7)
        sx, sy = sx * (1 + q), sy * (1 - q)
    elseif st == 'summon' then
        -- Invoca: se alza con las pinzas arriba, castañeteando
        local up = math.sin(math.min(1, t / 0.45) * math.pi * 0.5)
        sx, sy = 1 - 0.08 * up, 1 + 0.14 * up
        for i, side in ipairs(SIDES) do
            claws[i][1] = side * 0.8 * up
            claws[i][2] = -3.0 * up + math.sin(now * 30 + i) * 0.5
        end
    elseif st == 'wallaim' then
        -- En la pared, a punto de saltar: encogido, pinzas arriba temblando
        local k = math.min(1, t / 0.5)
        sx, sy = 1 + 0.08 * k, 1 - 0.12 * k
        for i, side in ipairs(SIDES) do
            claws[i][1] = side * 0.5
            claws[i][2] = -2 * k + math.sin(now * 38 + i * 2) * 0.5
        end
    elseif st == 'pounce' then
        -- Saltando: estirado, pinzas por delante
        sx, sy = 0.9, 1.14
        for i = 1, 2 do claws[i][1] = self.facing * 1.0; claws[i][2] = -1.4 end
    elseif st == 'intro' then
        local q = 0.09 * math.abs(math.sin(t * 9)) * math.max(0, 1 - t)
        sx, sy = 1 - q * 0.5, 1 + q
        for i = 1, 2 do claws[i][2] = -1.6 - math.abs(math.sin(t * 9 + i)) * 1.2 end
    elseif st == 'windup' then
        -- Anticipación de cangrejo: agachado, escarbando en el sitio (se mece
        -- de lado a lado) con las pinzas en alto; cada chasquido del sonido
        -- (WINDUP_SNAPS) la pinza que toca da un tirón hacia delante
        local k = math.min(1, t / 0.2)
        sx, sy = 1 + 0.10 * k, 1 - 0.14 * k
        shx = math.floor(math.sin(t * 38) * 2 * self.MS / 4)
        local snap, which = windupSnap(t)
        for i, side in ipairs(SIDES) do
            local jab = (snap and (which == 0 or which == i)) and 1 or 0
            claws[i][1] = side * 0.6 * k + self.facing * 0.9 * jab
            claws[i][2] = -2.2 * k + 0.8 * jab + math.sin(now * 42 + i) * 0.3
        end
    elseif st == 'charge' then
        -- Lanzado: estirado hacia delante, pinzas por delante
        local q = spring(t, 0.10, 16, 6)
        sx, sy = sx * (1.10 - q), sy * (0.93 + q)
        for i = 1, 2 do claws[i][1] = claws[i][1] + self.facing * 1.2; claws[i][2] = claws[i][2] - 0.6 end
    elseif st == 'recover' then
        local q = spring(t, -0.10, 18, 6)
        sx, sy = sx * (1 + q), sy * (1 - q)
    elseif st == 'aim' then
        -- Colgado, a punto de caer: vibra y abre las pinzas
        sx, sy = 1 + 0.03 * math.sin(now * 30), 1 - 0.03 * math.sin(now * 30)
        for i, side in ipairs(SIDES) do
            claws[i][1] = side * 0.8
            claws[i][2] = math.sin(now * 20 + i * 2) * 1.2
        end
    elseif st == 'drop' then
        -- Cayendo de cabeza: estirado, pinzas echadas hacia atrás (los pies)
        sx, sy = 0.88, 1.18
        for i = 1, 2 do claws[i][2] = 1.6 end
    elseif st == 'stuck' or st == 'dying_kick' then
        -- Clavado: aplastado por el golpe y luego forcejeando (como el Crabby)
        local q = spring(t, 0.28, 22, 7)
        local fury = (st == 'dying_kick') and 1.8 or 1
        sx, sy = 1 + q + 0.04 * math.sin(now * 13) * fury, 1 - q - 0.04 * math.sin(now * 13) * fury
        if t > 0.3 then shx = math.floor(math.sin(now * 45) * 2 * fury * self.MS / 4) end
        for i = 1, 2 do
            claws[i][1] = math.cos(now * 17 * fury + i * 2.3) * 1.0
            claws[i][2] = math.sin(now * 22 * fury + i * 3.1) * 2.0
        end
    elseif st == 'dying_stand' or st == 'dying_iced' then
        -- Vencido de pie: forcejea, las pinzas dando tirones (el helado, con ellas congeladas: las mueve su capa)
        for i = 1, 2 do
            claws[i][1] = math.cos(now * 15 + i * 2.3) * 0.8
            claws[i][2] = math.sin(now * 19 + i * 3.1) * 1.6
        end
    elseif st == 'dying_daze' then
        -- Aturdido: se bambolea y las pinzas cuelgan sueltas, meciéndose a destiempo con el vaivén
        local w = math.sin(now * 7)
        sy, sx = 1 + 0.05 * math.abs(w), 1 - 0.03 * math.abs(w)
        for i, side in ipairs(SIDES) do
            claws[i][1] = side * 0.3 + w * 0.9 + math.sin(now * 23 + i * 2) * 0.2
            claws[i][2] = 0.6 + math.sin(now * 7 + (i == 1 and 0.9 or -0.9)) * 1.6 + math.sin(now * 31 + i) * 0.3
        end
    elseif st == 'dying_flee' and math.abs(self._rdy or 0) > 0.3 then
        -- Huyendo, en un salto: estirado subiendo, aplastado al bajar; pinzas arriba agitándose
        local up = (self._rdy or 0) < 0
        sx, sy = up and 0.92 or 1.05, up and 1.1 or 0.96
        for i, side in ipairs(SIDES) do
            claws[i][1] = side * 0.7
            claws[i][2] = (up and -2.2 or -1.2) + math.sin(now * 26 + i * 2) * 0.8
        end
    elseif st == 'getup' then
        local k = math.min(1, t / GETUP_T)
        sy, sx = 1 + 0.12 * math.sin(k * math.pi), 1 - 0.08 * math.sin(k * math.pi)
        for i = 1, 2 do claws[i][2] = -1.5 * math.sin(k * math.pi) end
    end
    return sx, sy, shx, claws, spikeK
end

-- Dibuja el cangrejo "como en el suelo" con los pies en (px, py) de pantalla,
-- girado `ang`, a escala de píxel `s`, deformado (sx, sy) desde los pies
function Mega:drawLocal(px, py, ang, s, img, withSpike, alpha, nervous, sx, sy, claws, noClaws, spikeK)
    local now = love.timer.getTime()
    local red = self:flashRed()
    if red then love.graphics.setColor(1, 0.3, 0.3, alpha)
    elseif self._angry then
        -- Enfadado: se le sube el color (rojizo que late)
        local k = 0.07 + 0.05 * math.sin(now * 9)
        love.graphics.setColor(1, 1 - k, 1 - k * 1.2, alpha)
    else love.graphics.setColor(1, 1, 1, alpha) end
    love.graphics.push()
    love.graphics.translate(px, py)
    love.graphics.rotate(ang)
    love.graphics.scale(sx or 1, sy or 1)
    local A = self.art
    local ih = img.h                                   -- (img = el cuadro del cuerpo que toca: Clip:rec)
    local spike = A.clip('spike'):rec(A.clip('spike'):at(now))
    local cs = s * A.clawK
    if withSpike then                             -- detrás del cuerpo, sobre la cabeza
        local k = spikeK or 1                     -- (los emotes lo hinchan)
        love.graphics.draw(spike.image, spike.quad, 0, -(ih - A.spikeDy) * s, 0, s / 4 * (0.85 + 0.15 * k), s / 4 * k,
                           spike.w / 2, spike.h - 1)
    end
    love.graphics.draw(img.image, img.quad, 0, 0, 0, s * self.facing, s, img.w / 2, ih)
    self:drawWear('head', 0, -(ih - A.spikeDy) * s, s, nil, self.facing < 0)    -- (su corona: Boss:drawWear)
    if self.drawBodyOverlay then self:drawBodyOverlay(s, now) end      -- (capas de otras variantes)
    -- Pinzas delante del cuerpo, saliendo del costado junto a las patas
    for i, side in ipairs(noClaws and {} or { -1, 1 }) do
        local off = claws and claws[i] or { 0, 0 }
        local cx = side * (A.clawX * s + A.clawW * cs / 2 - A.clawIn * cs) + math.floor(off[1] * cs + 0.5)
        local cy = A.clawY * s - A.clawH * cs / 2 + math.floor(off[2] * cs + 0.5)
        A.clip(CLAW_ANIM[clawFrame(self, i, now, nervous)]):play(now, cx, cy, 0, -side * cs, cs)
        if self.drawClawOverlay then self:drawClawOverlay(i, side, cx, cy, cs, now) end
    end
    love.graphics.pop()
end

-- Marca en el suelo de donde va a caer (parpadea)
local function drawTarget(x, y, w, t, col)
    local on = math.floor(t * 8) % 2 == 0
    col = col or { 1, 0.2, 0.2 }
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle('fill', x - w / 2, y - 6, w, 6)
    love.graphics.setColor(col[1], col[2], col[3], on and 0.9 or 0.45)
    local seg = math.floor(w / 6)
    for i = 0, 5, 2 do love.graphics.rectangle('fill', x - w / 2 + i * seg, y - 4, seg, 4) end
end

-- Partículas continuas (solo dibujo): pisadas, estela, piedrecitas, tierra
local STEP_DIST = 7 * MS
function Mega:renderFx(now, fx, fy, moved)
    if EDITOR_VIEW then return end
    Particles = Particles or require 'src/fx/Particles'
    local st = self.state
    local f = self._fx or { acc = 0, t = 0, foot = 1 }
    self._fx = f
    local walking = st == 'chase' or st == 'charge'
    local crawling = st == 'climb' or st == 'ceiling' or st == 'wallclimb'
    -- Pegado a pared/techo: la normal de la superficie (las piedrecitas salen
    -- de ella, del material que sea, y no nacen metidas en el bloque)
    local nx, ny = 0, -1
    if self.crawl and self.cattached then nx, ny = self.cnx or 0, self.cny or -1 end
    local srf = { nx = nx, ny = ny }
    if (walking or crawling) and moved > 0 then
        f.acc = f.acc + moved
        if f.acc >= STEP_DIST then
            f.acc, f.foot = 0, -f.foot
            if walking then Particles.emit('mega_step', fx + f.foot * self.sprW * 0.3, fy)
            else Particles.emit('mega_debris', fx, fy, srf) end
        end
    end
    local every = (st == 'charge') and 0.04 or (st == 'stuck' or st == 'dying_kick') and 0.16
                  or (st == 'aim' or st == 'wallaim') and 0.12 or (st == 'windup') and 0.09 or nil
    if every and now - f.t >= every then
        f.t = now
        if st == 'charge' then Particles.emit('mega_trail', fx - self.facing * self.sprW * 0.3, fy, { dir = self.facing })
        elseif st == 'windup' then Particles.emit('mega_trail', fx - self.facing * self.sprW * 0.35, fy, { dir = -self.facing })
        elseif st == 'aim' or st == 'wallaim' then
            -- (repartidas a lo largo de la superficie: horizontal en el techo, vertical en la pared)
            local k = (math.random() - 0.5) * self.sprW * 0.6
            Particles.emit('mega_debris', fx - ny * k, fy + nx * k, srf)
        else Particles.emit('mega_dirt', self.x + (math.random() - 0.5) * SPIKE_HW, self.floorY) end
    end
end

-- Enfadado (rage): símbolos de enfado que salen al azar alrededor de la cabeza
-- (vena 💢 que late, nube de vapor que sube, garabato). Solo dibujo: cada
-- cliente los saca a su aire; la vida (y por tanto el enfado) llega por red.
local ANGER_S = 3                                  -- escala de píxel de los símbolos
local ANGER_KINDS = { 'vein', 'vein', 'steam', 'scribble', 'vein', 'steam' }
local ANGER_LIFE = { vein = 0.8, steam = 0.6, scribble = 0.7 }
function Mega:renderAnger(now, fx, fy, ang, camX, camY)
    local list = self._anger or {}
    self._anger = list
    local st = self.state
    local on = self:rage() and not self:isDying() and not INTRO[st] and st ~= 'dormant' and not EDITOR_VIEW
    if on and now >= (self._angerNext or 0) and #list < 3 then
        self._angerNext = now + 0.3 + math.random() * 0.55
        local kinds = self.angerKinds or ANGER_KINDS
        local kind = kinds[math.random(#kinds)]
        -- (arriba, a un lado u otro de la cabeza; nunca dos seguidos en el mismo lado)
        self._angerSide = -(self._angerSide or 1)
        local a = self._angerSide * (0.35 + math.random() * 0.8)
        local r = self.sprW * (0.32 + math.random() * 0.14)
        list[#list + 1] = { kind = kind, born = now, ox = math.sin(a) * r, oy = -math.cos(a) * r * 0.4 + self.sprH * 0.1 }
    end
    if #list == 0 then return end
    -- Cabeza = pies + (0, -alto) girado con el cuerpo
    local ca, sa = math.cos(ang), math.sin(ang)
    local hx, hy = fx + sa * self.sprH, fy - ca * self.sprH
    for i = #list, 1, -1 do
        local p = list[i]
        local age, life = now - p.born, ANGER_LIFE[p.kind]
        if age >= life then
            table.remove(list, i)
        else
            local ox, oy = p.ox * ca - p.oy * sa, p.ox * sa + p.oy * ca
            local x, y = hx + ox - camX, hy + oy - camY
            local k, frame = ANGER_S, BossFx.angerStep(p.kind, age, life)
            local alpha = math.min(1, (life - age) / 0.15)
            if p.kind == 'vein' then
                -- Aparece de golpe (con rebote) y late
                k = ANGER_S * ((age < 0.1) and (0.5 + age / 0.1 * 0.75) or 1)
            elseif p.kind == 'steam' then
                y = y - age * 60
                x = x + math.sin(age * 12) * 3
            else
                x = x + math.floor(math.sin(age * 40) * 2)
            end
            k = math.floor(k + 0.5)
            x, y = math.floor(x + 0.5), math.floor(y + 0.5)
            love.graphics.setColor(0, 0, 0, 0.5 * alpha)
            BossFx.angerClip(p.kind):draw(frame, x + 3, y + 3, 0, k, k)
            love.graphics.setColor(1, 1, 1, alpha)
            BossFx.angerClip(p.kind):draw(frame, x, y, 0, k, k)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Mega:render(camX, camY)
    local st, t = self.state, self.deadTimer or 0
    local now = love.timer.getTime()
    -- Antes de su entrada no está; cayendo, su sombra crece en el suelo
    if not EDITOR_VIEW and (st == 'dormant' or (st == 'fall_in' and t < FALL_WAIT)) then
        self._lx = nil
        return
    end
    if st == 'fall_in' and not EDITOR_VIEW and (self.floorY or 0) > 0 then
        local k = math.max(0, math.min(1, 1 - (self.floorY - (self.y + self.outerH / 2)) / 900))
        local w = math.floor(self.sprW * (0.25 + 0.6 * k))
        love.graphics.setColor(0, 0, 0, 0.2 + 0.35 * k)
        love.graphics.rectangle('fill', math.floor(self.x - camX - w / 2), math.floor(self.floorY - camY - 6), w, 6)
        love.graphics.setColor(1, 1, 1, 1)
    end
    local s, alpha = self.MS, 1
    local emote = st == 'rest' and t < 1.2 and (self.restKind or 0) or 0
    local nervous = st == 'windup' or st == 'aim' or st == 'stuck' or st == 'dying_kick' or st == 'dying_stand' or st == 'dying_iced' or st == 'intro'
                    or st == 'charge' or st == 'summon' or st == 'wallaim' or st == 'pounce'
                    or st == 'roar_in' or st == 'fall_in' or emote == 1 or emote == 2
    if self._rstate ~= st then self._prevState, self._rstate = self._rstate, st end

    -- ¿Se mueve? (para el paso y el balanceo): lo que avanzó desde el dibujo anterior
    local moved = self._lx and math.sqrt((self.x - self._lx) ^ 2 + (self.y - self._ly) ^ 2) or 0
    if self._ly and moved > 0.05 then self._rdy = self.y - self._ly end      -- (subiendo / bajando: los saltos al huir)
    self._lx, self._ly = self.x, self.y
    self._dist = (self._dist or 0) + moved
    local walkPhase = self._dist / (STEP_DIST * 2)
    -- (sigue "andando" un momento tras el último avance: si se dibuja más a menudo de lo que se mueve —la física
    --  a pasos fijos de los créditos en una pantalla de 120 Hz, un snapshot que se repite—, entre paso y paso no
    --  avanza y alternaba andar / quieto en cada cuadro: el cangrejo parecía temblar)
    if moved > 0.05 then self._movedAt = now end
    local moving = self._movedAt ~= nil and now - self._movedAt < 0.1

    -- Sprite: andar, o patalear clavado
    local body, step = self.art.clip('walk'), self.frame or 1
    if st == 'stuck' or st == 'dying_kick' then
        body = self.art.clip(st == 'dying_kick' and 'kick' or 'wiggle'); step = body:at(t)
    elseif st == 'fall_in' or (emote == 2 and t < 1.15) or st == 'windup' then
        body = self.art.clip(st == 'windup' and 'windup' or 'dig'); step = body:at(now)   -- (patalea / escarba)
    elseif not moving and (st == 'dormant' or st == 'windup' or st == 'aim' or st == 'recover' or st == 'chase' or st == 'rest'
                           or st == 'intro' or st == 'summon' or st == 'wallaim' or st == 'land_in' or st == 'roar_in'
                           or st == 'ready') then
        body = self.art.clip('idle'); step = body:at(now)
    end
    local img = body:rec(step)
    local withSpike = true

    -- Temblor (aviso de embestida, a punto de caer, pataleo final)
    local jx, jy = 0, 0
    -- (apuntando: solo al final, cuando ya se ha fijado y va a lanzarse)
    local k = self:speedMult()
    local locked = (st == 'aim' and t >= (self.props.aimTime or 1.8) / k - AIM_LOCK_CEIL)
                or (st == 'wallaim' and t >= (self.props.pounceAim or 1.4) / k - AIM_LOCK_WALL)
    if st == 'windup' or locked or st == 'dying_kick' or st == 'dying_stand' or st == 'dying_iced' then
        jx = math.floor(math.sin(now * 70) * 3)
        jy = math.floor(math.cos(now * 55) * 2)
    end

    if st == 'summon' and t < SUMMON_WARN and not EDITOR_VIEW then
        -- Dónde van a salir los súbditos (marca amarilla y tierra que burbujea)
        for i = 1, (self.summonN or 0) do
            local x, _, fy0 = self:summonSpot(i)
            drawTarget(math.floor(x - camX), math.floor(fy0 - camY), TILE_PX, now, { 1, 0.85, 0.2 })
            self._sfx = self._sfx or {}
            if now - (self._sfx[i] or 0) > 0.15 then
                self._sfx[i] = now
                Particles = Particles or require 'src/fx/Particles'
                Particles.emit('mega_dirt', x, fy0)
            end
        end
    end
    if (st == 'aim' or st == 'wallaim') and not EDITOR_VIEW then
        local mx = (st == 'aim') and self.x or self.markerX
        drawTarget(math.floor(mx - camX), math.floor(self.landY - camY), self.sprW * 0.9, now)
    end

    local sx, sy, shx, claws, spikeK = self:pose2d(now, moving, walkPhase)
    -- ENFADADO (rage): solo rojizo y un temblor LEVE (1 px de vez en cuando),
    -- además de los símbolos de enfado. Pinzas y rebote, los de siempre (el
    -- usuario quitó el resto: demasiado)
    local angry = self:rage() and not self:isDying() and not INTRO[st] and st ~= 'dormant' and not EDITOR_VIEW
    self._angry = angry
    if angry then shx = shx + math.floor(math.sin(now * 41) * 0.9 + 0.5) end
    local fx, fy, ang
    if self.crawl and self.cattached and CRAWL[st] then
        fx, fy, ang = Crawler.pose(self)
    else
        local H = self.sprH
        ang = 0
        if st == 'drop' or st == 'stuck' or st == 'dying_kick' then ang = math.pi
        elseif st == 'getup' then ang = math.pi * (1 - math.min(1, t / GETUP_T))
        elseif st == 'pounce' then ang = self.facing * math.pi / 2 * (1 - math.min(1, t / 0.3))
        elseif st == 'dying_getup' then ang = math.pi * (1 - math.min(1, t / GETUP_T))
        end
        if not fx then fx, fy = self.x - math.sin(ang) * H / 2, self.y + math.cos(ang) * H / 2 end
    end
    if st == 'dying_daze' and not EDITOR_VIEW then
        -- aturdido: se bambolea y tiembla (las estrellitas: las de detrás antes del cuerpo, las de delante después)
        jx = math.floor(math.sin(now * 7) * 6 + math.sin(now * 61) * 2 + 0.5)
        jy = math.floor(math.abs(math.cos(now * 7)) * -3 + 0.5)
    end
    if st == 'dying_flee' then alpha = self:fleeAlpha(t) end
    if EDITOR_VIEW then nervous = false end
    self._clawForce = nil
    if st == 'windup' and not EDITOR_VIEW then
        local snap, which = windupSnap(t)
        self._clawForce = { (snap and which ~= 2) and 2 or 1, (snap and which ~= 1) and 2 or 1 }
    end
    self:renderFx(now, fx, fy, moved)
    local daze = st == 'dying_daze' and not EDITOR_VIEW
    local starsAt = function(part)          -- corro de estrellitas sobre la cabeza, a los lados del pincho
        BossFx.stars(math.floor(fx - camX + jx), math.floor(fy - self.sprH * self.STARS_Y - camY + jy),
                     self.sprW * 0.46, self.sprW * 0.09, 6, nil, part)
    end
    if daze then starsAt('back') end                                   -- (las de detrás, antes del cuerpo)
    self:drawLocal(math.floor(fx - camX + 0.5) + jx + shx, math.floor(fy - camY + 0.5) + jy, ang, s, img,
                   withSpike, alpha * self:ghostAlpha(), nervous, sx, sy, claws, false, spikeK)
    self:renderAnger(now, fx + jx + shx, fy + jy, ang, camX, camY)
    if daze then starsAt('front') end                                  -- (y las de delante, después)
    love.graphics.setColor(1, 1, 1, 1)
end
end
