-- MEGA CRABBY HELADO: el Mega Crabby (megacrabby.lua: TODOS sus estados, ataques, entrada,
-- descansos, súbditos y muerte) con el aspecto del cangrejo antártico Paralomis birsteini
-- (assets/images/bosses/megacrabby_ice/, tools/ui/make_icecrab_sprites.py) y tres cosas de hielo:
--  1. PALMADA HELADA: al acabar cada embestida da un golpe con las pinzas en el suelo ('clap'):
--     dos ondas de escarcha corren por el suelo (una a cada lado) y CONGELAN `waveFreeze` s a
--     quien pillen (se esquivan saltando). Las pinzas se quedan pegadas al suelo por el hielo
--     ('clap_stuck', `clapStuck` s): es otro momento para golpearlo (un golpe: pisotón 1 /
--     ground pound 2), como cuando está clavado.
--  2. CAMPO DE CARÁMBANOS: donde cae su salto desde la pared el suelo se agrieta a los dos lados
--     (aviso, FIELD_WARN s) y brotan carámbanos, de dentro afuera, en `patchWidth` casillas en
--     total: tocarlos quita 1 de vida y empuja. Duran `patchTime` s y se rompen. (Antes dejaba
--     una placa que resbalaba: sobre un suelo que ya es de hielo no se notaba.)
--  3. ENFADADO (rageAt): le salen esquirlas de hielo afiladas en el caparazón y las pinzas (capas
--     rage_body-Sheet / rage_claw-Sheet encima del cuerpo y de cada pinza; en vez del rojizo), con
--     la vena y el vapor del Mega (sin el garabato), y sus carámbanos duran `ragePatchTime` s.
-- Sus súbditos son Crabbies helados (púa de hielo / trampolín de hielo).
-- Todo lo que se dibuja sale de state + deadTimer + lo que llega en netPackExtra (igual online).

local Entity      = require 'src/world/entities/Entity'
local Boss        = require 'src/world/entities/Boss'
local SpriteStrip = require 'src/fx/SpriteStrip'
local baseDef     = require 'src/world/entities/types/megacrabby'
local Mega        = baseDef.class
local IceEncase, Particles

local IM = Entity.extend(Mega, { debugColor = { 1, 0.55, 0.25 } })
IM.wantsLevel = true                -- (BossZones.link: el cliente necesita el nivel para ver qué carámbanos tienen suelo)

local MS = 9                         -- (el Mega mide 10: el helado, de cuerpo más alto, va algo más pequeño — el usuario)
local T = TILE_PX
local CLAP_AT, CLAP_END = 0.32, 0.6 -- s: golpe de pinzas y fin de la palmada
local WAVE_LIFE = 1.4               -- s que corre cada onda
local WAVE_H = 34                   -- alto de la onda (se esquiva saltando)
local FIELD_WARN = 0.45             -- s de grietas antes de que brote el primer carámbano
local FIELD_SPREAD = 700            -- px/s: brotan de dentro afuera
local FIELD_GROW = 0.14             -- s que tarda cada uno en salir
local FIELD_END = 0.35              -- s del final en que se rompen (ya no dañan)
local ICI_STEP = 32                 -- px entre carámbanos (8 px de arte × 4)
local ICI_SC = 4                    -- escala del arte (8x16 → 32x64)
local ICI_HW, ICI_HH = 20, 44       -- su zona de daño: más estrecha y baja que el dibujo
local RAGE_BW, RAGE_CW = 26, 18     -- ancho de cuadro de las capas de rabia (make_icecrab_sprites.py)
local RAGE_GROW = 0.3               -- s del destello al salirle las esquirlas

local rageBody, rageClaw, shock, fieldS, fieldQuad
function IM.loadAssets()
    Mega.loadAssets()
    if rawget(IM, 'art') then return end
    -- (pinzas a la escala del cuerpo y más bajas, junto a las patas: ver la vista previa)
    IM.art = Mega.loadArt('assets/images/bosses/megacrabby_ice/', 18, 13, 10, 7, 1.0, 5.4, -1.2, 1.5, 2)
    rageBody = SpriteStrip.load('assets/images/bosses/megacrabby_ice/rage_body-Sheet.png', RAGE_BW)
    rageClaw = SpriteStrip.load('assets/images/bosses/megacrabby_ice/rage_claw-Sheet.png', RAGE_CW)
    shock = SpriteStrip.load('assets/images/bosses/snowboss/shock-Sheet.png', 16)
    fieldS = SpriteStrip.load('assets/images/bosses/megacrabby_ice/ice_field-Sheet.png', 8)
end
function IM.sizePx() return 18 * MS, 13 * MS end
IM.MS = MS
IM.smallPx = 3.5                     -- (la escala del Crabby helado: Crabby.SKINS.ice / Ice.artScale)

function IM:initBoss()
    Mega.initBoss(self)
    self.waves, self.fields = {}, {}
    self.nextWave = 0
end

-- ── Pinzas pegadas al suelo: el punto débil ──────────────────────────────────
-- Con el pincho de la cabeza el lomo NO se puede pisar (rebotas, como siempre); lo que se
-- golpea es una PINZA congelada: en la palmada salen hacia fuera, planas sobre el suelo y más
-- allá del cuerpo. Un ground pound sobre una rompe el hielo (2 de daño, un golpe por palmada);
-- un pisotón normal rebota (el hielo aguanta).
local CLAW_OUT, CLAW_DOWN = 1.6, 1.2      -- desplazamiento de las pinzas en la palmada (px de arte)
function IM:clawBoxes()
    local A, s = self.art, self.MS
    local cs = s * A.clawK
    local fx, fy = self.x, self.y + self.sprH / 2
    local out = {}
    for i, side in ipairs({ -1, 1 }) do
        local cx = fx + side * (A.clawX * s + A.clawW * cs / 2 - A.clawIn * cs + CLAW_OUT * cs)
        local cy = fy + A.clawY * s - A.clawH * cs / 2 + CLAW_DOWN * cs
        local w, h = A.clawW * cs + 8, A.clawH * cs + 8
        out[i] = { x = cx - w / 2, y = cy - h / 2, w = w, h = h, side = side }
    end
    return out
end

function IM:isVulnerable()
    if self.state == 'clap_stuck' then return not self.hitDrop and not self._shell end
    return Mega.isVulnerable(self)
end

-- (sin efectos secundarios: el cliente lo usa para predecir)
function IM:interact(pa)
    if self.state ~= 'clap_stuck' then return Mega.interact(self, pa) end
    local pob = pa:getOuterBounds()
    if not self.hitDrop and self.inv <= 0 and (pa.vy or 0) > 0 then
        for _, cb in ipairs(self:clawBoxes()) do
            if Boss.overlap(pob, cb) and pob.y + pob.h * 0.5 < cb.y + cb.h * 0.5 then
                local bvy = -math.abs(ADV_JUMP_VEL) * self.BOUNCE
                if pa.gpPhase == 'fall' then return 'pound', bvy, self.props.points or 0 end
                return 'bounce', bvy, cb.side
            end
        end
    end
    -- El lomo, con su pincho: inmune (rebota hacia un lado)
    self._shell = true
    local a, b, c = Mega.interact(self, pa)
    self._shell = nil
    return a, b, c
end

function IM:onDamaged(n, kind)
    if self.state == 'clap_stuck' then
        self.hitDrop = true                                  -- (un golpe)
        self.state, self.deadTimer, self.recoverFor = 'recover', 0, 0.8
        self.graceT = 1.0
        Sound.play('cryoFree')
        Entity.emitFx('ice_shatter', self.x, self.y + self.outerH / 2 - 20)
        return
    end
    return Mega.onDamaged(self, n, kind)
end

-- ── Palmada helada ────────────────────────────────────────────────────────────
function IM:startClap()
    self.state, self.deadTimer, self.clapped = 'clap', 0, false
    self.vx = 0
    Sound.play('megaClack', 0.8)
end

function IM:spawnWaves()
    local fy = self.y + self.outerH / 2
    for _, d in ipairs({ -1, 1 }) do
        self.nextWave = self.nextWave % 999 + 1
        self.waves[#self.waves + 1] = { id = self.nextWave, x = self.x + d * self.sprW * 0.45, y = fy, dir = d, t = 0 }
    end
    Sound.play('megaSlam', 1.25)
    Sound.play('cryoBlast', 0.9)
    Entity.emitFx('mega_land', self.x, fy)
    Entity.emitFx('ice_freeze', self.x, fy - 30)
    Entity.emitFx('shake_small', self.x, fy)
end

-- Las ondas corren por el suelo y congelan a quien pillen (un jugador / servidor)
function IM:updateWaves(dt, level)
    local p = self.props
    local zx0, zx1 = -1e9, 1e9
    if self.zone then zx0, zx1 = self.zone.x0, self.zone.x1 end
    for i = #self.waves, 1, -1 do
        local w = self.waves[i]
        w.t = w.t + dt
        w.x = w.x + w.dir * (p.waveSpeed or 560) * dt
        local gone = w.t >= WAVE_LIFE or w.x < zx0 or w.x > zx1
                     or level:collisionAt(w.x + w.dir * 16, w.y - WAVE_H * 0.5)
        if not gone and level.canBreak ~= false then
            local box = { x = w.x - 22, y = w.y - WAVE_H, w = 44, h = WAVE_H }
            for _, pa in ipairs(level.players or {}) do
                if not pa.dying and pa.alive ~= false and not pa:isInvulnerable() and (pa.iceT or 0) <= 0
                   and Boss.overlap(pa:getOuterBounds(), box) then
                    Boss.withPlayer(pa, function() pa:freeze(p.waveFreeze or 1.0) end)
                end
            end
        end
        if gone then table.remove(self.waves, i) end
    end
end

-- ── Campo de carámbanos ───────────────────────────────────────────────────────
-- Un campo = { x0, x1, y (suelo), dir (hacia dónde brota), t (edad), life }. Los carámbanos
-- van cada ICI_STEP px desde el borde de dentro; solo donde hay suelo debajo y sitio encima
-- (función pura del campo y del nivel: igual en el servidor y en el cliente).
local function fieldSpikes(fp, level)
    if fp.xs then return fp.xs end
    local xs = {}
    local n = math.floor((fp.x1 - fp.x0) / ICI_STEP + 0.01)
    for i = 0, n - 1 do
        local d = ICI_STEP / 2 + i * ICI_STEP                       -- distancia al borde de dentro
        local x = (fp.dir > 0) and (fp.x0 + d) or (fp.x1 - d)
        if not level or (level:collisionAt(x, fp.y + 8) and not level:collisionAt(x, fp.y - 24)) then
            xs[#xs + 1] = { x = x, at = FIELD_WARN + d / FIELD_SPREAD }
        end
    end
    if level then fp.xs = xs end
    return xs
end

-- Cuánto ha salido el carámbano (0..1); 0 = aún no / ya roto
local function spikeUp(fp, sp)
    if fp.t >= fp.life - FIELD_END then return 0 end
    return math.max(0, math.min(1, (fp.t - sp.at) / FIELD_GROW))
end

function IM:addField(level)
    local p = self.props
    local fy = math.floor(self.y + self.outerH / 2)
    local w = math.max(ICI_STEP, math.floor((p.patchWidth or 4) * T / 2 / ICI_STEP + 0.5) * ICI_STEP)
    local life = (self:rage() and (p.ragePatchTime or 8) or (p.patchTime or 5)) + FIELD_WARN
    local zx0, zx1 = -1e9, 1e9
    if self.zone then zx0, zx1 = self.zone.x0, self.zone.x1 end
    for _, dir in ipairs({ -1, 1 }) do
        local inner = math.floor(self.x + dir * (self.sprW / 2 + 48))      -- (por fuera de las pinzas)
        local x0, x1 = inner, inner + dir * w
        if dir < 0 then x0, x1 = x1, x0 end
        x0, x1 = math.max(zx0, x0), math.min(zx1, x1)
        if x1 - x0 >= ICI_STEP then
            self.fields[#self.fields + 1] = { x0 = x0, x1 = x1, y = fy, dir = dir, t = 0, life = life }
        end
    end
    Sound.play('iceCrack', 0.8)
    Entity.emitFx('ice_freeze', self.x, fy - 10)
end

function IM:updateFields(dt, level)
    for i = #self.fields, 1, -1 do
        local fp = self.fields[i]
        local was = fp.t
        fp.t = fp.t + dt
        if was < FIELD_WARN and fp.t >= FIELD_WARN then
            Sound.play('cryoFreeze', 0.9)
            Entity.emitFx('shake_small', (fp.x0 + fp.x1) / 2, fp.y)
        end
        local endAt = fp.life - FIELD_END
        if was < endAt and fp.t >= endAt then
            Sound.play('iceBreak', 0.9)
            for _, sp in ipairs(fieldSpikes(fp, level)) do Entity.emitFx('ice_shatter', sp.x, fp.y - 28) end
        end
        if fp.t >= fp.life then
            table.remove(self.fields, i)
        elseif level.canBreak ~= false then
            -- Tocar un carámbano que ya ha salido: 1 de vida y empujón hacia fuera (un jugador / servidor)
            for _, sp in ipairs(fieldSpikes(fp, level)) do
                if spikeUp(fp, sp) >= 0.6 then
                    local box = { x = sp.x - ICI_HW / 2, y = fp.y - ICI_HH, w = ICI_HW, h = ICI_HH }
                    for _, pa in ipairs(level.players or {}) do
                        if not pa.dying and pa.alive ~= false and not pa:isInvulnerable()
                           and Boss.overlap(pa:getOuterBounds(), box) then
                            Boss.withPlayer(pa, function() pa:hurt() end)
                            if not pa.dying then pa:recoil((pa.x >= sp.x) and 1 or -1) end
                        end
                    end
                end
            end
        end
    end
end

-- (BossZones.safeSpawn: no reaparecer dentro de un campo)
-- F1: además de lo del Mega, las pinzas congeladas (ahí se le pega), las ondas y los carámbanos que ya dañan
function IM:debugBoxes()
    local out = Mega.debugBoxes(self) or {}
    if self.state == 'clap_stuck' then
        for _, cb in ipairs(self:clawBoxes()) do out[#out + 1] = { x = cb.x, y = cb.y, w = cb.w, h = cb.h, kind = 'weak' } end
    end
    for _, w in ipairs(self.waves or {}) do out[#out + 1] = { x = w.x - 22, y = w.y - WAVE_H, w = 44, h = WAVE_H } end
    if self.levelRef then
        for _, fp in ipairs(self.fields or {}) do
            for _, sp in ipairs(fieldSpikes(fp, self.levelRef)) do
                if spikeUp(fp, sp) >= 0.6 then out[#out + 1] = { x = sp.x - ICI_HW / 2, y = fp.y - ICI_HH, w = ICI_HW, h = ICI_HH } end
            end
        end
    end
    return out
end

function IM:unsafeAt(x, y)
    for _, fp in ipairs(self.fields or {}) do
        if x > fp.x0 - T / 2 and x < fp.x1 + T / 2 and y > fp.y - 2.5 * T and y < fp.y + T / 2 then return true end
    end
    return false
end

function IM:updateBoss(dt, level)
    self:updateWaves(dt, level)
    self:updateFields(dt, level)
    local st = self.state
    if st == 'clap' or st == 'clap_stuck' then
        if (self.graceT or 0) > 0 then self.graceT = math.max(0, self.graceT - dt) end
        self.deadTimer = self.deadTimer + dt
        local t = self.deadTimer
        self:walk(level, dt, 0)
        if st == 'clap' then
            if t >= CLAP_AT and not self.clapped then self.clapped = true; self:spawnWaves() end
            if t >= CLAP_END then
                self.state, self.deadTimer, self.hitDrop = 'clap_stuck', 0, false
                Sound.play('cryoFreeze', 0.7)
            end
        elseif t >= (self.props.clapStuck or 1.2) then
            Sound.play('cryoFree', 0.9)
            Entity.emitFx('ice_shatter', self.x, self.y + self.outerH / 2 - 20)
            self.state, self.deadTimer, self.recoverFor = 'recover', 0, 0.5
        end
        return
    end
    Mega.updateBoss(self, dt, level)
    -- Acaba una embestida (sin haber golpeado a nadie): palmada helada
    if st == 'charge' and self.state == 'recover' and (self.graceT or 0) < 0.9 then self:startClap() end
    -- Aterriza del salto desde la pared: campo de carámbanos a los dos lados
    if st == 'pounce' and self.state == 'recover' then self:addField(level) end
end

-- Al morir se acaban las ondas y los carámbanos
function IM:update(dt, level)
    if self.state:sub(1, 6) == 'dying_' and (#self.waves > 0 or #self.fields > 0) then
        self.waves, self.fields = {}, {}
    end
    return Mega.update(self, dt, level)
end

-- ── Red: lo del Mega + ondas + campos de carámbanos ─────────────────────────────────────────
local NB = 9                         -- campos de Mega:netPackExtra
function IM:netPackExtra()
    local out = Mega.netPackExtra(self)
    out[#out + 1] = #self.waves
    for _, w in ipairs(self.waves) do
        out[#out + 1] = w.id; out[#out + 1] = math.floor(w.x); out[#out + 1] = w.y
        out[#out + 1] = w.dir; out[#out + 1] = math.floor(w.t * 100)
    end
    out[#out + 1] = #self.fields
    for _, fp in ipairs(self.fields) do
        out[#out + 1] = fp.x0; out[#out + 1] = fp.x1; out[#out + 1] = fp.y; out[#out + 1] = fp.dir
        out[#out + 1] = math.floor(fp.t * 100); out[#out + 1] = math.floor(fp.life * 100)
    end
    return out
end

function IM:netApplyExtra(a, b, f)
    Mega.netApplyExtra(self, a, b, f)
    a = a or b
    local k = NB + 1
    local n = tonumber(b[k]) or 0
    local prev = {}
    local ka = NB + 1
    for i = 0, (tonumber(a[ka]) or 0) - 1 do
        local j = ka + 1 + i * 5
        if a[j] then prev[a[j]] = tonumber(a[j + 1]) end
    end
    self.waves = {}
    for i = 0, n - 1 do
        local j = k + 1 + i * 5
        local x = tonumber(b[j + 1]) or 0
        local px = prev[b[j]]
        if px then x = px + (x - px) * f end
        self.waves[#self.waves + 1] = { id = b[j], x = x, y = tonumber(b[j + 2]) or 0, dir = tonumber(b[j + 3]) or 1,
                                        t = (tonumber(b[j + 4]) or 0) / 100 }
    end
    k = k + 1 + n * 5
    local np = tonumber(b[k]) or 0
    self.fields = {}
    for i = 0, np - 1 do
        local j = k + 1 + i * 6
        self.fields[#self.fields + 1] = { x0 = tonumber(b[j]) or 0, x1 = tonumber(b[j + 1]) or 0, y = tonumber(b[j + 2]) or 0,
                                          dir = tonumber(b[j + 3]) or 1, t = (tonumber(b[j + 4]) or 0) / 100,
                                          life = (tonumber(b[j + 5]) or 0) / 100 }
    end
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
local function emit(kind, x, y, o)
    Particles = Particles or require 'src/fx/Particles'
    Particles.emit(kind, x, y, o)
end

-- Campo: grietas que parpadean (aviso) y carámbanos que salen del suelo (recortados por abajo)
function IM:renderFields(camX, camY, now)
    for _, fp in ipairs(self.fields or {}) do
        local ending = fp.t >= fp.life - FIELD_END
        for i, sp in ipairs(fieldSpikes(fp, self.levelRef)) do
            local x, y = math.floor(sp.x - camX), math.floor(fp.y - camY)
            local up = spikeUp(fp, sp)
            if up <= 0 and not ending then
                local a = (math.floor(now * 14) % 2 == 0) and 1 or 0.55
                love.graphics.setColor(1, 1, 1, a)
                love.graphics.draw(fieldS.image, fieldS.quads[1], x, y, 0, ICI_SC, ICI_SC, 4, 16)
            elseif up > 0 then
                local rows = math.max(1, math.floor(16 * up + 0.5))
                local fr = ((math.floor(now * 3 + i * 0.37) % 7) == 0) and 3 or 2
                fieldQuad = fieldQuad or love.graphics.newQuad(0, 0, 8, 16, fieldS.image:getDimensions())
                fieldQuad:setViewport((fr - 1) * 8, 0, 8, rows)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(fieldS.image, fieldQuad, x, y, 0, ICI_SC, ICI_SC, 4, rows)
                if not EDITOR_VIEW and math.random() < 0.02 then emit('cryo_mist', sp.x, fp.y - 40) end
            end
        end
    end
end

function IM:renderWaves(camX, camY, now)
    for _, w in ipairs(self.waves or {}) do
        local a = math.min(1, (WAVE_LIFE - (w.t or 0)) / 0.3)
        love.graphics.setColor(0.65, 0.88, 1, a)
        local fr = math.floor(now * 10) % 2 + 1
        shock:draw(fr, math.floor(w.x - camX), math.floor(w.y - camY - 16), 0, 4 * w.dir, 4)
        if not EDITOR_VIEW and math.random() < 0.5 then emit('cryo_mist', w.x, w.y - 18) end
    end
end

-- Pinzas pegadas al suelo por el hielo: un bloque de hielo en cada una
function IM:renderClawIce(camX, camY, now)
    IceEncase = IceEncase or require 'src/fx/IceEncase'
    local left = (self.props.clapStuck or 1.2) - (self.deadTimer or 0)
    for _, cb in ipairs(self:clawBoxes()) do
        IceEncase.draw(math.floor(cb.x - camX), math.floor(cb.y - camY), cb.w, cb.h, now, left)
    end
end

-- Pose de la palmada: alza las pinzas y las estampa contra el suelo, hacia fuera
function IM:pose2d(now, moving, walkPhase)
    local sx, sy, shx, claws, spikeK = Mega.pose2d(self, now, moving, walkPhase)
    local st, t = self.state, self.deadTimer or 0
    if st == 'clap' or st == 'clap_stuck' then
        local q = (st == 'clap') and math.min(1, t / CLAP_AT) or 1
        for i, side in ipairs({ -1, 1 }) do
            if st == 'clap' and t < CLAP_AT then
                claws[i][1] = side * CLAW_OUT * q * 0.5
                claws[i][2] = -3.2 * math.sin(q * math.pi * 0.5)
            else
                local jit = (st == 'clap_stuck') and math.sin(now * 40 + i * 2) * 0.15 or 0
                claws[i][1] = side * CLAW_OUT + jit
                claws[i][2] = CLAW_DOWN
            end
        end
        if st == 'clap' and t >= CLAP_AT then sy = (sy or 1) * (1 - 0.08 * math.max(0, 1 - (t - CLAP_AT) / 0.2)) end
    end
    return sx, sy, shx, claws, spikeK
end

-- Enfadado: la vena y el vapor del Mega (sin el garabato) + vaho helado de las esquirlas
IM.angerKinds = { 'vein', 'vein', 'steam', 'vein', 'steam' }
function IM:renderAnger(now, fx, fy, ang, camX, camY)
    Mega.renderAnger(self, now, fx, fy, ang, camX, camY)
    if self._rageOn and (self._mistT or 0) + 0.2 < now then
        self._mistT = now
        local side = (math.random() < 0.5) and -1 or 1
        emit('cryo_mist', fx + side * self.sprW * (0.2 + math.random() * 0.2), fy - self.sprH * (0.7 + math.random() * 0.3))
    end
end

-- Esquirlas de la rabia: capas encima del cuerpo y de cada pinza (misma transformación, así
-- siguen el squash, el andar y los chasquidos); al salir, un destello blanco
function IM:rageFrame(now) return (math.floor(now * 2.5) % 5 == 0) and 2 or 1 end
function IM:rageFlash(now, draw)
    local t = now - (self._rageAt or now)
    if t >= RAGE_GROW then return end
    local r, g, b, a = love.graphics.getColor()
    love.graphics.setBlendMode('add')
    love.graphics.setColor(1, 1, 1, 1 - t / RAGE_GROW)
    draw()
    love.graphics.setBlendMode('alpha')
    love.graphics.setColor(r, g, b, a)
end
function IM:drawBodyOverlay(s, now)
    if not self._rageOn then return end
    local fr = self:rageFrame(now)
    local function draw() rageBody:draw(fr, 0, -rageBody.h * s / 2, 0, s * self.facing, s) end
    draw()
    self:rageFlash(now, draw)
end
function IM:drawClawOverlay(i, side, cx, cy, cs, now)
    if not self._rageOn then return end
    local fr = self:rageFrame(now + i * 0.7)
    local function draw() rageClaw:draw(fr, cx, cy, 0, -side * cs, cs) end
    draw()
    self:rageFlash(now, draw)
end

-- (sin el rojizo del Mega al enfadarse: aquí son las esquirlas)
function IM:drawLocal(...)
    local angry = self._angry
    if angry and not self._rageOn then self._rageAt = love.timer.getTime() end
    self._rageOn = angry and not EDITOR_VIEW
    self._angry = false
    Mega.drawLocal(self, ...)
    self._angry = angry
end

function IM:render(camX, camY)
    local now = love.timer.getTime()
    self:renderFields(camX, camY, now)
    Mega.render(self, camX, camY)
    if self.state == 'clap_stuck' then self:renderClawIce(camX, camY, now) end
    self:renderWaves(camX, camY, now)
    love.graphics.setColor(1, 1, 1, 1)
end

-- ── Definición: la del Mega + lo helado ───────────────────────────────────────
local props = {}
for _, pr in ipairs(baseDef.props) do props[#props + 1] = pr end
local G = 'Hielo'
for _, pr in ipairs({
    { key='waveFreeze', kind='number', label='Palmada: congela (s)', group=G, default=1.0, min=0.2, max=4, step=0.1,
      help='Tras cada embestida da una palmada: dos ondas de escarcha por el suelo congelan a quien pillen (se saltan)' },
    { key='waveSpeed', kind='number', label='Palmada: velocidad de las ondas', group=G, default=560, min=150, max=1500, step=10 },
    { key='clapStuck', kind='number', label='Palmada: pinzas pegadas (s)', group=G, default=1.2, min=0.3, max=5, step=0.1,
      help='Tiempo con las pinzas pegadas al suelo: se le puede golpear una vez' },
    { key='patchWidth', kind='number', label='Carámbanos: ancho total (casillas)', group=G, default=4, min=1, max=10, step=0.5,
      help='Al caer de su salto desde la pared el suelo se agrieta y brotan carámbanos a sus dos lados (la mitad a cada '
        .. 'uno): tocarlos quita 1 de vida' },
    { key='patchTime', kind='number', label='Carámbanos: duran (s)', group=G, default=5, min=1, max=20, step=0.5 },
    { key='ragePatchTime', kind='number', label='Enfadado: los carámbanos duran (s)', group=G, default=8, min=1, max=30, step=0.5 },
}) do props[#props + 1] = pr end

return {
    name = 'megacrabby_ice', label = 'Mega Crabby helado', category = 'Jefes',
    description = 'El Mega Crabby en versión helada: lo mismo, más una palmada que congela con ondas de '
               .. 'escarcha (después, pinzas pegadas = vulnerable), un campo de carámbanos donde cae su salto desde la '
               .. 'pared y cristales de escarcha al enfadarse. Súbditos: Crabbies helados.',
    class = IM,
    boss = { title = 'MEGA CRABBY HELADO' },
    hide = Boss.HIDE,
    defaults = { points = 60 },
    props = props,
    editor = { sprite = 'assets/images/bosses/megacrabby_ice/crab1.png' },
    summons = function(pl)
        local out = baseDef.summons(pl)
        for _, s in ipairs(out) do s.type = (s.type == 'crabbytramp') and 'crabbytramp_ice' or 'crabby_ice' end
        return out
    end,
}
