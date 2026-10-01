-- MEGA CRABBY HELADO: el Mega Crabby (megacrabby.lua: TODOS sus estados, ataques, entrada,
-- descansos, súbditos y muerte) con el aspecto del cangrejo antártico Paralomis birsteini
-- (assets/images/megacrabby_ice/, tools/ui/make_icecrab_sprites.py) y tres cosas de hielo:
--  1. PALMADA HELADA: al acabar cada embestida da un golpe con las pinzas en el suelo ('clap'):
--     dos ondas de escarcha corren por el suelo (una a cada lado) y CONGELAN `waveFreeze` s a
--     quien pillen (se esquivan saltando). Las pinzas se quedan pegadas al suelo por el hielo
--     ('clap_stuck', `clapStuck` s): es otro momento para golpearlo (un golpe: pisotón 1 /
--     ground pound 2), como cuando está clavado.
--  2. PLACAS DE ESCARCHA: donde cae su salto desde la pared deja una placa de hielo de
--     `patchWidth` casillas que resbala como el hielo durante `patchTime` s (level.frostPatches:
--     la física del jugador, también en la predicción online).
--  3. ENFADADO (rageAt): le salen esquirlas de hielo afiladas en el caparazón y las pinzas (capas
--     rage_body-Sheet / rage_claw-Sheet encima del cuerpo y de cada pinza; en vez del rojizo), con
--     la vena y el vapor del Mega (sin el garabato), y sus placas duran `ragePatchTime` s.
-- Sus súbditos son Crabbies helados (púa de hielo / trampolín de hielo).
-- Todo lo que se dibuja sale de state + deadTimer + lo que llega en netPackExtra (igual online).

local Entity      = require 'src/world/entities/Entity'
local Boss        = require 'src/world/entities/Boss'
local SpriteStrip = require 'src/fx/SpriteStrip'
local baseDef     = require 'src/world/entities/types/megacrabby'
local Mega        = baseDef.class
local IceEncase, Particles

local IM = Entity.extend(Mega, { debugColor = { 1, 0.55, 0.25 } })
IM.wantsLevel = true                -- (BossZones.link: el cliente apunta sus placas en el nivel)

local MS = Mega.MS
local T = TILE_PX
local CLAP_AT, CLAP_END = 0.32, 0.6 -- s: golpe de pinzas y fin de la palmada
local WAVE_LIFE = 1.4               -- s que corre cada onda
local WAVE_H = 34                   -- alto de la onda (se esquiva saltando)
local PATCH_FADE = 0.8              -- s del final en que la placa se desvanece
local RAGE_BW, RAGE_CW = 26, 18     -- ancho de cuadro de las capas de rabia (make_icecrab_sprites.py)
local RAGE_GROW = 0.3               -- s del destello al salirle las esquirlas

local rageBody, rageClaw, shock, iceTile, iceQuad
function IM.loadAssets()
    Mega.loadAssets()
    if rawget(IM, 'art') then return end
    -- (pinzas a la escala del cuerpo y más bajas, junto a las patas: ver la vista previa)
    IM.art = Mega.loadArt('assets/images/megacrabby_ice/', 18, 13, 10, 7, 1.0, 5.4, -1.2, 1.5, 2)
    rageBody = SpriteStrip.load('assets/images/megacrabby_ice/rage_body-Sheet.png', RAGE_BW)
    rageClaw = SpriteStrip.load('assets/images/megacrabby_ice/rage_claw-Sheet.png', RAGE_CW)
    shock = SpriteStrip.load('assets/images/bosses/snowboss/shock-Sheet.png', 16)
    iceTile = love.graphics.newImage('assets/images/tiles/ice.png')
    for _, i in ipairs({ iceTile }) do if i.setFilter then i:setFilter('nearest', 'nearest') end end
    if iceTile.getWidth and love.graphics.newQuad then
        iceQuad = love.graphics.newQuad(0, 0, iceTile:getWidth(), 12, iceTile:getWidth(), iceTile:getHeight())
    end
end
function IM.sizePx() return 18 * MS, 13 * MS end

function IM:initBoss()
    Mega.initBoss(self)
    self.waves, self.patches = {}, {}
    self.nextWave = 0
end

-- ── Pinzas pegadas al suelo: el punto débil ──────────────────────────────────
-- Con el pincho de la cabeza el lomo NO se puede pisar (rebotas, como siempre); lo que se
-- golpea es una PINZA congelada: en la palmada salen hacia fuera, planas sobre el suelo y más
-- allá del cuerpo. Un ground pound sobre una rompe el hielo (2 de daño, un golpe por palmada);
-- un pisotón normal rebota (el hielo aguanta).
local CLAW_OUT, CLAW_DOWN = 1.6, 1.2      -- desplazamiento de las pinzas en la palmada (px de arte)
function IM:clawBoxes()
    local A, s = self.art, MS
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

-- ── Placas de escarcha ────────────────────────────────────────────────────────
function IM:addPatch(level)
    local p = self.props
    local fy = self.y + self.outerH / 2
    local half = (p.patchWidth or 3) * T / 2
    local x0, x1 = self.x - half, self.x + half
    if self.zone then x0, x1 = math.max(self.zone.x0, x0), math.min(self.zone.x1, x1) end
    local life = self:rage() and (p.ragePatchTime or 8) or (p.patchTime or 5)
    self.patches[#self.patches + 1] = { x0 = math.floor(x0), x1 = math.floor(x1), y = math.floor(fy), left = life }
    Sound.play('cryoFreeze', 0.8)
    Entity.emitFx('ice_freeze', self.x, fy - 10)
end

function IM:updatePatches(dt, level)
    for i = #self.patches, 1, -1 do
        local fp = self.patches[i]
        fp.left = fp.left - dt
        if fp.left <= 0 then table.remove(self.patches, i) end
    end
    level.frostPatches = self.patches
end

function IM:updateBoss(dt, level)
    self:updateWaves(dt, level)
    self:updatePatches(dt, level)
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
    -- Aterriza del salto desde la pared: placa de escarcha
    if st == 'pounce' and self.state == 'recover' then self:addPatch(level) end
end

-- Al morir se acaban las ondas y las placas
function IM:update(dt, level)
    if self.state:sub(1, 6) == 'dying_' and (#self.waves > 0 or #self.patches > 0) then
        self.waves, self.patches = {}, {}
        level.frostPatches = nil
    end
    return Mega.update(self, dt, level)
end

-- ── Red: lo del Mega + ondas + placas ─────────────────────────────────────────
local NB = 9                         -- campos de Mega:netPackExtra
function IM:netPackExtra()
    local out = Mega.netPackExtra(self)
    out[#out + 1] = #self.waves
    for _, w in ipairs(self.waves) do
        out[#out + 1] = w.id; out[#out + 1] = math.floor(w.x); out[#out + 1] = w.y
        out[#out + 1] = w.dir; out[#out + 1] = math.floor(w.t * 100)
    end
    out[#out + 1] = #self.patches
    for _, fp in ipairs(self.patches) do
        out[#out + 1] = fp.x0; out[#out + 1] = fp.x1; out[#out + 1] = fp.y; out[#out + 1] = math.floor(fp.left * 10)
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
    self.patches = {}
    for i = 0, np - 1 do
        local j = k + 1 + i * 4
        self.patches[#self.patches + 1] = { x0 = tonumber(b[j]) or 0, x1 = tonumber(b[j + 1]) or 0,
                                            y = tonumber(b[j + 2]) or 0, left = (tonumber(b[j + 3]) or 0) / 10 }
    end
    -- (la predicción del jugador local resbala en ellas igual que en el servidor)
    if self.levelRef then self.levelRef.frostPatches = self.patches end
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
local function emit(kind, x, y, o)
    Particles = Particles or require 'src/fx/Particles'
    Particles.emit(kind, x, y, o)
end

function IM:renderPatches(camX, camY, now)
    for _, fp in ipairs(self.patches or {}) do
        local a = math.min(1, fp.left / PATCH_FADE) * 0.85
        love.graphics.setColor(1, 1, 1, a)
        local x = fp.x0
        while x < fp.x1 do
            local w = math.min(64, fp.x1 - x)
            if iceQuad then
                iceQuad:setViewport(0, 0, w, 12)
                love.graphics.draw(iceTile, iceQuad, math.floor(x - camX), math.floor(fp.y - camY - 6))
            end
            x = x + 64
        end
        love.graphics.setColor(0.9, 0.97, 1, a)
        love.graphics.rectangle('fill', math.floor(fp.x0 - camX), math.floor(fp.y - camY - 6), fp.x1 - fp.x0, 2)
        if not EDITOR_VIEW and math.random() < 0.08 then
            emit('cryo_mist', fp.x0 + math.random() * (fp.x1 - fp.x0), fp.y - 8)
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
    self:renderPatches(camX, camY, now)
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
    { key='patchWidth', kind='number', label='Placa de escarcha: ancho (casillas)', group=G, default=3, min=1, max=8, step=0.5,
      help='Al caer de su salto desde la pared deja una placa que resbala como el hielo' },
    { key='patchTime', kind='number', label='Placa de escarcha: dura (s)', group=G, default=5, min=1, max=20, step=0.5 },
    { key='ragePatchTime', kind='number', label='Enfadado: la placa dura (s)', group=G, default=8, min=1, max=30, step=0.5 },
}) do props[#props + 1] = pr end

return {
    name = 'megacrabby_ice', label = 'Mega Crabby helado', category = 'Jefes',
    description = 'El Mega Crabby en versión helada: lo mismo, más una palmada que congela con ondas de '
               .. 'escarcha (después, pinzas pegadas = vulnerable), placas de hielo donde cae su salto desde la '
               .. 'pared y cristales de escarcha al enfadarse. Súbditos: Crabbies helados.',
    class = IM,
    boss = { title = 'MEGA CRABBY HELADO' },
    hide = Boss.HIDE,
    defaults = { points = 60 },
    props = props,
    editor = { sprite = 'assets/images/megacrabby_ice/crab1.png' },
    summons = function(pl)
        local out = baseDef.summons(pl)
        for _, s in ipairs(out) do s.type = (s.type == 'crabbytramp') and 'crabbytramp_ice' or 'crabby_ice' end
        return out
    end,
}
