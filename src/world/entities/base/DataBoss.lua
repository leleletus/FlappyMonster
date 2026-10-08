-- src/world/entities/base/DataBoss.lua
-- JEFES HECHOS CON DATOS. Un enemigo de datos (base/DataEnemy.lua, editor de enemigos `love . --enemy`) cuyo JSON
-- lleva "boss": {…} se registra como JEFE: hereda de base/Boss.lua (vida y barra, zona de jefe, entrada con
-- cinemática, muerte con explosiones, turnos con un aliado, red) y usa las MISMAS piezas del catálogo de
-- comportamientos (src/world/entities/behaviors/) para sus ataques.
--
--   "boss": {
--     "title": "NOMBRE EN LA BARRA", "title_en": "NAME",
--     "hp": 10, "hpPerPlayer": 4,
--     "walkSpeed": 90,            -- px/s con que persigue al jugador entre ataques (0 = no se mueve)
--     "contact": 1,               -- vida que quita al tocarlo de lado (0 = nada); siempre empuja
--     "vulnerable": "tired",      -- cuándo se le puede golpear: "tired" (cansado tras cada ataque) | "always"
--     "tiredTime": 1.8,           -- s cansado (estrellitas: pisotón 1, ground pound 2, un golpe por ocasión)
--     "attackEvery": 1.2,         -- s entre ataques como poco
--     "rageAt": 0.4, "ragePace": 1.35,   -- por debajo de esa fracción de vida: fase 2, todo más deprisa
--     "intro": 3                  -- s de entrada (cae desde arriba y se planta); 0 = sin entrada
--   }
--
-- ESTADOS: 'dormant' (antes de la pelea), 'intro' / 'ready' (entrada), 'fight' (persigue: secuencia `walk`),
-- los de sus comportamientos ('run', 'attack', 'special', 'hide'…), 'tired' (secuencia `tired`, o `hurt`),
-- 'dying_hold' / 'dying_fall' (secuencia `dead`). Todo lo que se dibuja sale de estado + reloj + x, y.
-- Los golpes a los jugadores los da él desde su update (Boss.strike): las cajas de sus comportamientos y sus
-- proyectiles, y el contacto. Para algo que estas piezas no cubren, un jefe escrito en Lua
-- (docs/bosses/how-to-add-a-boss.md) o un comportamiento nuevo.
local Entity    = require 'src/world/entities/base/Entity'
local Boss      = require 'src/world/entities/base/Boss'
local DataEnemy = require 'src/world/entities/base/DataEnemy'
local Anim      = require 'src/fx/Anim'
local Lang      = require 'src/core/Lang'

local T = TILE_PX
local DataBoss = {}
DataBoss.DEFAULTS = { title = 'JEFE', title_en = 'BOSS', hp = 10, hpPerPlayer = 4, walkSpeed = 90, contact = 1, vulnerable = 'tired',
                      tiredTime = 1.8, attackEvery = 1.2, rageAt = 0.4, ragePace = 1.35, intro = 3 }
local GRACE = 0.9              -- s sin daño por contacto tras un golpe (que no encadene)

local function opt(self, k)
    local v = self.spec.boss[k]
    if v == nil then v = DataBoss.DEFAULTS[k] end
    return v
end

local M = {}                   -- métodos de la clase (se copian a cada tipo)
-- (lo mismo que los enemigos de datos)
M.enter, M.nearestPlayer, M.seesPlayer, M.addShot, M.onHurtPlayer = DataEnemy.enter, DataEnemy.nearestPlayer, DataEnemy.seesPlayer, DataEnemy.addShot, DataEnemy.onHurtPlayer

function M:initBoss()
    self.animSet = Anim.load(self.spec.anim, self.spec.variant)
    self.shots, self.shotId = {}, 0
    DataEnemy.Core.buildBehaviors(self)
    self.speed = opt(self, 'walkSpeed')
    self.cool, self.graceT = 0, 0
    self.homeY = self.y
end

function M:title()
    local own = Lang.bossName(self.def.name, self.props)
    if own then return own end
    local b = self.spec.boss
    if Lang.current() ~= 'es' and b.title_en and b.title_en ~= '' then return b.title_en end
    return b.title or self.def.label
end

function M:bossPhase() return (self.hp or 1) <= (self.hpMax or 1) * opt(self, 'rageAt') and 2 or 1 end
function M:isVulnerable()
    if not self:isActive() then return false end
    return opt(self, 'vulnerable') == 'always' or self.state == 'tired'
end
function M:onFightStart() self:enter('fight'); self.cool = 1.0 end
function M:onDamaged()
    -- (un golpe por ocasión: se le pasa el cansancio)
    if self.state == 'tired' then self:enter('fight'); self.cool = opt(self, 'attackEvery') * 0.5 end
end

-- Al acabar un ataque: cansado (golpeable) o de vuelta a perseguir
function M:backToWalk()
    self.owner, self.vx = nil, 0
    self.cool = opt(self, 'attackEvery')
    if opt(self, 'vulnerable') == 'tired' then self:enter('tired') else self:enter('fight') end
end

-- ── Entrada: cae desde arriba de la zona hasta su sitio ──────────────────────
function M:onIntroStart(level, players)
    self.homeX, self.homeY = self.x, self.y
    local _, _, y0 = self:zoneBounds()
    self.introFrom = (y0 or (self.y - 8 * T)) - self.sprH
    self.y = self.introFrom
end
function M:updateIntro(dt, level, t)
    local fall = math.min(1.2, (self:introTime() or 1) * 0.45)
    local k = math.min(1, t / fall)
    self.y = self.introFrom + (self.homeY - self.introFrom) * k * k          -- (acelera al caer)
    if k >= 1 and not self.landed then
        self.landed = true
        Sound.play('kingLand')
        Entity.emitFx('shake_big', self.x, self.y)
    end
end

-- ── Pelea ─────────────────────────────────────────────────────────────────────
local function strikeBoxes(self, level)
    local boxes = DataEnemy.getHazardBoxes(self)
    if not boxes then return end
    for _, pa in ipairs(level.players or {}) do
        local b = pa:getOuterBounds()
        for _, hb in ipairs(boxes) do
            if Boss.overlap(b, hb) then
                local dir = (pa.x >= self.x) and 1 or -1
                if Boss.strike(pa, { hb.effect == 'kill' and 3 or (hb.dmg or 1), 520, -360, 0.3, 0 }, dir) then self:onHurtPlayer(pa) end
                break
            end
        end
    end
end

function M:updateBoss(dt, level)
    self.levelRef = self.levelRef or level
    if self.state == 'dormant' then return end                 -- (aún no ha empezado la pelea: la arranca su zona)
    if self:bossPhase() == 2 then dt = dt * opt(self, 'ragePace') end
    self.deadTimer = self.deadTimer + dt
    if self.cool > 0 then self.cool = self.cool - dt end
    if self.graceT > 0 then self.graceT = self.graceT - dt end
    for _, b in ipairs(self.beh) do
        local key = 'cd_' .. b.def.name
        if (self[key] or 0) > 0 then self[key] = self[key] - dt end
    end
    DataEnemy.Core.stepShots(self, dt, level)
    local st = self.state
    local owner = DataEnemy.Core.ownerNow(self)
    if owner and self.owner == owner then
        owner.def.update(self, owner.cfg, dt, level)
    elseif st == 'tired' then
        self.vy = self.vy + ADV_GRAVITY * dt
        self:moveAndCollide(level, 0, self.vy * dt)
        if self.deadTimer >= opt(self, 'tiredTime') then self:enter('fight') end
    else
        if st ~= 'fight' then self:enter('fight') end
        -- persigue al más cercano, andando
        local pa = self:nearestPlayer(level)
        local vx = 0
        if pa and math.abs(pa.x - self.x) > self.outerW * 0.6 then
            self.facing = pa.x > self.x and 1 or -1
            vx = self.speed * self.facing
        end
        local dir = self.facing
        self.vy = self.vy + ADV_GRAVITY * dt
        self:moveAndCollide(level, vx * dt, self.vy * dt)
        self.facing = dir
        if vx ~= 0 then self:animateWalk(dt) end
        -- ¿ataca? (por orden; con un aliado se turnan: Boss:mayAttack)
        if self.cool <= 0 and self.onGround and self:mayAttack(level) then
            for _, b in ipairs(self.beh) do
                if b.def.think and b.def.think(self, b.cfg, dt, level) then self.owner = b; break end
            end
        end
    end
    -- dentro de su zona
    local x0, x1 = self:zoneBounds()
    if self.zone and x0 then self.x = math.max(x0 + self.outerW / 2, math.min(x1 - self.outerW / 2, self.x)) end
    -- golpes: lo de sus comportamientos y sus proyectiles, y el contacto de lado
    strikeBoxes(self, level)
    local c = opt(self, 'contact')
    if self.graceT <= 0 and self.state ~= 'tired' then
        local ob = self:getOuterBounds()
        local box = { x = ob.x - 6, y = ob.y + ob.h * 0.3, w = ob.w + 12, h = ob.h * 0.7 }
        for _, pa in ipairs(level.players or {}) do
            if Boss.overlap(pa:getOuterBounds(), box) then
                if Boss.strike(pa, { c, 460, -300, 0.25, 0 }, (pa.x >= self.x) and 1 or -1) then self.graceT = GRACE end
            end
        end
    end
end
-- (los estados de ataque, para los turnos con un aliado)
function M:isAttacking()
    local b = DataEnemy.Core.ownerNow(self)
    return b ~= nil and self.owner == b
end

-- ── Red ───────────────────────────────────────────────────────────────────────
function M:netPackExtra()
    local out = {}
    for _, s in ipairs(self.shots) do
        out[#out + 1] = s.id; out[#out + 1] = math.floor(s.x + 0.5); out[#out + 1] = math.floor(s.y + 0.5); out[#out + 1] = math.floor(s.size)
    end
    return out
end
function M:netApplyExtra(a, b, f)
    a = a or b
    local prev, list = {}, {}
    for k = 1, #a - 3, 4 do prev[a[k]] = k end
    for k = 1, #b - 3, 4 do
        local id, x, y, size = b[k], b[k + 1], b[k + 2], b[k + 3]
        local ka = prev[id]
        if ka and type(a[ka + 1]) == 'number' then x, y = a[ka + 1] + (x - a[ka + 1]) * f, a[ka + 2] + (y - a[ka + 2]) * f end
        list[#list + 1] = { id = id, x = x, y = y, size = size }
    end
    self.shots = list
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
function M:animNow()
    local st, map, set = self.state, self.spec.states or {}, self.animSet
    if st == 'fight' then return map.walk or 'walk', nil, self.frame end
    if st == 'dormant' or st == 'intro' or st == 'ready' then return map.idle or 'idle', self.deadTimer or 0 end
    if st == 'tired' then
        local a = map.tired or 'tired'
        return set:has(a) and a or (map.hurt or 'hurt'), self.deadTimer or 0
    end
    if st == 'dying_hold' or st == 'dying_fall' or st == 'dead' then return map.dead or 'dead', self.deadTimer or 0 end
    local b = DataEnemy.Core.ownerNow(self)
    if b and b.def.anim then
        local name, t = b.def.anim(self, b.cfg, set, map)
        if name then return name, t or 0 end
    end
    return map[st] or st, self.deadTimer or 0
end

local BossFx
function M:render(camX, camY)
    if self.state == 'dormant' and not EDITOR_VIEW then return end
    local set, spec = self.animSet, self.spec
    local name, t, k = self:animNow()
    local fi = k and set:frameN(name, k) or (set:frameAt(name, t))
    local S = spec.scale or set.scale or 4
    local x, y = math.floor(self.x - camX), math.floor(self.y - camY + self.sprH / 2)
    local a = self:ghostAlpha()
    if self:flashRed() then love.graphics.setColor(1, 0.35, 0.35, a) else love.graphics.setColor(1, 1, 1, a) end
    set:drawFrame(fi, x, y, 0, S * self.facing * (spec.facesLeft and -1 or 1), S, 0.5, 1)
    love.graphics.setColor(1, 1, 1, 1)
    if self.state == 'tired' then                                   -- "ahora se le puede golpear"
        BossFx = BossFx or require 'src/fx/BossFx'
        BossFx.stars(x, y - self.sprH - 10, self.sprW * 0.32, 8, 3, 1)
    end
    for _, s in ipairs(self.shots or {}) do
        local px, py = math.floor(s.x - camX), math.floor(s.y - camY)
        if set:has('shot') then
            local w = set:size(set:frameN('shot', 1))
            set:draw('shot', love.timer.getTime(), px, py, 0, s.size / w, s.size / w, 0.5, 0.5)
        else
            local w = set:size(1)
            set:drawFrame(1, px, py, 0, s.size / w * 0.6, s.size / w * 0.6, 0.5, 0.5)
        end
    end
end

function M:debugBoxes()
    local out = {}
    for _, hb in ipairs(DataEnemy.getHazardBoxes(self) or {}) do out[#out + 1] = { x = hb.x, y = hb.y, w = hb.w, h = hb.h, kind = 'hurt' } end
    return out
end

-- ── De los datos al tipo ──────────────────────────────────────────────────────
function DataBoss.typeDef(spec)
    local set = Anim.load(spec.anim, spec.variant)
    local walk = set:seq((spec.states or {}).walk or 'walk')
    local hb = spec.hitbox or {}
    local attacks = {}
    for _, st in ipairs(DataEnemy.statesOf(spec)) do attacks[st] = true end
    attacks.idle, attacks.walk, attacks.hurt, attacks.dead = nil, nil, nil, nil
    local cls = Entity.extend(Boss, {
        walkFps = walk and walk.fps or 7, walkFrames = walk and #walk.frames or 1,
        hitbox = { outerW = hb.outerW or 0.72, outerH = hb.outerH or 0.8, innerW = hb.innerW or 0.6, innerH = hb.innerH or 0.7 },
        ATTACKS = attacks,
    })
    for k, v in pairs(M) do cls[k] = v end
    cls.spec = spec
    local b = spec.boss
    local intro = b.intro == nil and DataBoss.DEFAULTS.intro or b.intro
    if intro and intro > 0 then cls.introLength = intro end
    function cls.loadAssets() Anim.load(spec.anim, spec.variant) end
    function cls.sizePx()
        local w, h = set:size(1)
        local S = spec.scale or set.scale or 4
        return w * S, h * S
    end
    local f1 = set:frame(1)
    return {
        name = spec.id, label = spec.label or spec.id, category = 'Jefes', class = cls,
        description = spec.description ~= '' and spec.description or nil,
        boss = { title = b.title or DataBoss.DEFAULTS.title },
        hide = Boss.HIDE, defaults = { points = (spec.defaults or {}).points or 30 },
        props = Boss.props({ hp = b.hp or DataBoss.DEFAULTS.hp, hpPerPlayer = b.hpPerPlayer or DataBoss.DEFAULTS.hpPerPlayer }, {}),
        dataEnemy = true,
        editor = f1 and { sprite = f1.path, frameW = (f1.w ~= f1.iw) and f1.w or nil } or nil,
    }
end

return DataBoss
