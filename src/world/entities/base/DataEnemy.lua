-- src/world/entities/base/DataEnemy.lua
-- ENEMIGOS HECHOS CON DATOS. Un enemigo de estos no tiene archivo .lua propio: es un JSON en assets/enemies/
-- (lo crea y lo cambia el editor de enemigos, `love . --enemy`) que dice su arte (un conjunto de animación,
-- src/fx/Anim.lua), su caja, sus valores por defecto, qué animación lleva cada ESTADO y qué COMPORTAMIENTOS tiene
-- (piezas del catálogo src/world/entities/behaviors/). Se registra como cualquier otro tipo: sale en el editor de
-- niveles con todas las propiedades comunes y funciona en un jugador, en el servidor y online.
--
--   assets/enemies/index.json      { "enemies": ["claudio", ...] }   ← la lista (el orden de la paleta)
--   assets/enemies/<id>.json:
--   {
--     "id": "claudio", "label": "Claudio", "category": "Enemigos", "description": "…",
--     "anim": "claudio", "variant": null,        -- conjunto de animación (assets/anim/<anim>.json) y su variante
--     "scale": 4, "facesLeft": false,            -- px por píxel de arte; ¿el dibujo mira a la izquierda?
--     "hitbox": { "outerW": 0.72, "outerH": 0.8, "innerW": 0.44, "innerH": 0.5 },   -- × el tamaño del sprite
--     "hp": 1, "hurtTime": 0.5,                  -- golpes que aguanta; s en el estado 'hurt' (intocable) tras cada uno
--     "defaults": { "movement": "walk", "speed": 55, "points": 10, "onTouch": "hurt", … },   -- props comunes
--     "traits": { "needsPound": false, … }, "darkEdge": null, "breathe": true,
--     "states": { "idle": "idle", "walk": "walk", "run": "run", "attack": "attack", "special": "special",
--                 "hurt": "hurt", "dead": "dead" },                  -- estado → secuencia del conjunto
--     "behaviors": [ { "type": "chase", "range": 5 }, { "type": "melee" } ],          -- en orden de prioridad
--     "sounds": { "attack": "…", "hurt": "…", "special": "…" }       -- (opcional) sonido al ENTRAR en ese estado
--   }
--
-- ESTADOS: los comunes de Entity ('walk', 'idle', 'dead', 'stunned', 'frozen'…) + 'hurt' (aquí) + los de sus
-- comportamientos ('run', 'attack', 'special'…). El reloj de un estado es `deadTimer` (e:enter lo pone a 0): es lo
-- que viaja por red, así que la animación de cada estado sale igual en todas partes.
-- Ayudas para los comportamientos: e:enter(estado), e:backToWalk(), e:seesPlayer(level, casillas, alto),
-- e:nearestPlayer(level), e:addShot(x, y, vx, vy, vida, tamaño, daño).
local Entity    = require 'src/world/entities/base/Entity'
local Anim      = require 'src/fx/Anim'
local Behaviors = require 'src/world/entities/behaviors/Behaviors'
local json      = require 'libs/json'

local T = TILE_PX
local DataEnemy = Entity.extend(Entity, {})
DataEnemy.DIR   = 'assets/enemies/'
DataEnemy.INDEX = DataEnemy.DIR .. 'index.json'
-- Los estados que el editor ofrece siempre (los demás salen de los comportamientos que lleve)
DataEnemy.BASE_STATES = { 'idle', 'walk', 'hurt', 'dead' }
DataEnemy.CATEGORIES  = { 'Enemigos', 'Trampas', 'Objetos' }

-- Un enemigo nuevo, con todo en su valor por defecto
function DataEnemy.blank(id)
    return {
        id = id, label = id, category = 'Enemigos', description = '',
        anim = id, scale = 4, facesLeft = false, breathe = true,
        hitbox = { outerW = 0.72, outerH = 0.80, innerW = 0.44, innerH = 0.50 },
        hp = 1, hurtTime = 0.5,
        defaults = { movement = 'walk', speed = 55, points = 10, onTouch = 'hurt', stompable = true },
        traits = {}, states = {}, behaviors = {}, sounds = {},
    }
end

-- Estados que tiene un enemigo (los de base + los de sus comportamientos), en orden y sin repetir
function DataEnemy.statesOf(spec)
    local out, seen = {}, {}
    local function add(s) if not seen[s] then seen[s] = true; out[#out + 1] = s end end
    for _, s in ipairs(DataEnemy.BASE_STATES) do add(s) end
    for _, b in ipairs(spec.behaviors or {}) do
        local def = Behaviors.byName[b.type]
        for _, s in ipairs(def and def.states or {}) do add(s) end
    end
    for s in pairs(spec.states or {}) do add(s) end
    return out
end

-- Avisos de un enemigo (lo que le falta para funcionar bien): lista de textos
function DataEnemy.validate(spec, set)
    local w = {}
    if not (type(spec.id) == 'string' and spec.id:match('^[%l][%l%d_]*$')) then w[#w + 1] = 'El id solo puede llevar minúsculas, números y _ (y empezar por letra).' end
    set = set or (spec.anim and Anim.read(spec.anim) and Anim.load(spec.anim, spec.variant))
    if not set or #set.frames == 0 then
        w[#w + 1] = 'No tiene conjunto de animación con cuadros (' .. tostring(spec.anim) .. ').'
        return w
    end
    for _, s in ipairs(DataEnemy.statesOf(spec)) do
        local a = (spec.states or {})[s] or s
        if not set:has(a) then w[#w + 1] = ('Estado "%s": no hay una secuencia "%s" (se verá la de reserva, "%s").'):format(s, a, tostring(set.fallback)) end
    end
    for i, b in ipairs(spec.behaviors or {}) do
        local def = Behaviors.byName[b.type]
        if not def then w[#w + 1] = ('Comportamiento %d: "%s" no existe.'):format(i, tostring(b.type))
        else for _, a in ipairs(def.anims or {}) do
            if not set:has(a) then w[#w + 1] = ('%s: falta la secuencia "%s".'):format(def.label, a) end
        end end
    end
    return w
end

-- ── Clase ─────────────────────────────────────────────────────────────────────
function DataEnemy:set() return self.animSet end

function DataEnemy:init()
    local spec = self.spec
    self.animSet = Anim.load(spec.anim, spec.variant)
    self.hp = math.max(1, math.floor(spec.hp or 1))
    self.shots, self.shotId = {}, 0
    self.beh = {}
    for _, b in ipairs(spec.behaviors or {}) do
        local def = Behaviors.byName[b.type]
        if def then self.beh[#self.beh + 1] = { def = def, cfg = Behaviors.config(b) } end
    end
end

function DataEnemy:enter(state)
    self.state, self.deadTimer = state, 0
    local snd = self.spec.sounds and self.spec.sounds[state]
    if snd and snd ~= '' then Sound.play(snd) end
end

function DataEnemy:backToWalk()
    local dir = self.facing ~= 0 and self.facing or 1
    self.vx = self.moving and self.speed * dir or 0
    self:startWalk()
end

function DataEnemy:nearestPlayer(level)
    local best, bd
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false then
            local d = math.abs(pa.x - self.x) + math.abs(pa.y - self.y) * 0.3
            if not bd or d < bd then best, bd = pa, d end
        end
    end
    return best, bd
end

-- ¿Ve a un jugador? A `tiles` casillas como mucho en horizontal (× la dificultad) y `height` en vertical, sin un
-- bloque sólido entre los dos. Devuelve el más cercano.
function DataEnemy:seesPlayer(level, tiles, height)
    local range = tiles * T * require('src/core/Difficulty').k('sense')
    local best, bd
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false then
            local dx, dy = pa.x - self.x, pa.y - self.y
            if math.abs(dx) <= range and math.abs(dy) <= (height or 1.5) * T then
                local clear = true
                for i = 1, math.floor(math.abs(dx) / (T / 2)) do
                    local t = level:collisionAt(self.x + (dx > 0 and 1 or -1) * i * T / 2, self.y)
                    if t and t.collision == 'solid' then clear = false; break end
                end
                if clear and (not bd or math.abs(dx) < bd) then best, bd = pa, math.abs(dx) end
            end
        end
    end
    return best
end

-- Proyectil suyo: recto, se para en un bloque sólido, quita `dmg` al tocar
function DataEnemy:addShot(x, y, vx, vy, life, size, dmg)
    self.shotId = self.shotId % 250 + 1
    self.shots[#self.shots + 1] = { id = self.shotId, x = x, y = y, vx = vx, vy = vy, life = life, size = size or 20, dmg = dmg or 1, t = 0 }
end

local function stepShots(self, dt, level)
    for i = #self.shots, 1, -1 do
        local s = self.shots[i]
        s.x, s.y, s.t = s.x + s.vx * dt, s.y + s.vy * dt, s.t + dt
        local t = level:collisionAt(s.x, s.y)
        if s.t >= s.life or (t and t.collision == 'solid') then table.remove(self.shots, i) end
    end
end

function DataEnemy:updateCustom(dt, level)
    if self.state == 'reserve' then return true end
    stepShots(self, dt, level)
    for _, b in ipairs(self.beh) do                      -- esperas de cada comportamiento (cd_<nombre>)
        local key = 'cd_' .. b.def.name
        if (self[key] or 0) > 0 then self[key] = self[key] - dt end
    end
    if self.state == 'hurt' then
        self.deadTimer = self.deadTimer + dt
        if not self.flying then
            self.vy = self.vy + ADV_GRAVITY * dt
            self:moveAndCollide(level, 0, self.vy * dt)
        end
        if self.deadTimer >= (self.spec.hurtTime or 0.5) then self:backToWalk() end
        return true
    end
    -- un comportamiento tiene el mando (su estado)
    for _, b in ipairs(self.beh) do
        for _, s in ipairs(b.def.states) do
            if self.state == s and self.owner == b then
                self.deadTimer = self.deadTimer + dt
                b.def.update(self, b.cfg, dt, level)
                return true
            end
        end
    end
    -- (un estado de comportamiento sin dueño — p. ej. tras descongelarse —: de vuelta a andar)
    if self.state ~= 'walk' and self.state ~= 'idle' then
        for _, b in ipairs(self.beh) do
            for _, st in ipairs(b.def.states) do if self.state == st then self:backToWalk(); return true end end
        end
    end
    -- en los estados de base: ¿alguno lo toma? (por orden: el primero de la lista manda)
    if self.state == 'walk' or self.state == 'idle' then
        for _, b in ipairs(self.beh) do
            if b.def.think and b.def.think(self, b.cfg, dt, level) then
                self.owner = b
                return true
            end
        end
    end
    return false
end

function DataEnemy:getHazardBoxes()
    local out
    for _, b in ipairs(self.beh) do
        if b.def.hazards and self.owner == b then
            for _, hb in ipairs(b.def.hazards(self, b.cfg) or {}) do out = out or {}; out[#out + 1] = hb end
        end
    end
    for _, s in ipairs(self.shots or {}) do
        out = out or {}
        out[#out + 1] = { x = s.x - s.size / 2, y = s.y - s.size / 2, w = s.size, h = s.size, effect = 'hurt', dmg = s.dmg }
    end
    return out
end

-- Un proyectil que le quita vida a un jugador se gasta
function DataEnemy:onHurtPlayer(pa)
    local b = pa:getOuterBounds()
    for i = #self.shots, 1, -1 do
        local s = self.shots[i]
        local h = s.size / 2 + 6
        if s.x + h > b.x and s.x - h < b.x + b.w and s.y + h > b.y and s.y - h < b.y + b.h then table.remove(self.shots, i) end
    end
end

-- Con más de 1 de vida, un pisotón le quita 1 y lo deja un momento "dolido" (intocable, parpadea)
function DataEnemy:isBodyDisabled() return self.state == 'hurt' end
function DataEnemy:canBeStomped() return self.state ~= 'hurt' end
function DataEnemy:stomp()
    if self.state == 'dead' or self.state == 'hurt' then return end
    if self.state ~= 'frozen' and (self.hp or 1) > 1 then
        self.hp = self.hp - 1
        self.vx, self.owner = 0, nil
        self:enter('hurt')
        if not (self.spec.sounds and self.spec.sounds.hurt) then Sound.play('helmetBounce') end
        return
    end
    self.owner, self.shots = nil, {}
    Entity.stomp(self)
end
function DataEnemy:resetToHome()
    Entity.resetToHome(self)
    self.hp, self.owner, self.shots = math.max(1, math.floor(self.spec.hp or 1)), nil, {}
end

-- ── Red: vida + proyectiles (con id estable para interpolarlos) ──────────────
function DataEnemy:netPack()
    local out = { self.hp or 1 }
    for _, s in ipairs(self.shots) do
        out[#out + 1] = s.id; out[#out + 1] = math.floor(s.x + 0.5); out[#out + 1] = math.floor(s.y + 0.5); out[#out + 1] = math.floor(s.size)
    end
    return out
end
function DataEnemy:netApply(a, b, f)
    a = a or b
    self.hp = b[1] or 1
    local prev, list = {}, {}
    for k = 2, #a - 2, 4 do prev[a[k]] = k end
    for k = 2, #b - 2, 4 do
        local id, x, y, size = b[k], b[k + 1], b[k + 2], b[k + 3]
        local ka = prev[id]
        if ka and type(a[ka + 1]) == 'number' then x, y = a[ka + 1] + (x - a[ka + 1]) * f, a[ka + 2] + (y - a[ka + 2]) * f end
        list[#list + 1] = { id = id, x = x, y = y, size = size, t = love.timer and love.timer.getTime() or 0 }
    end
    self.shots = list
end

-- ── Dibujo: la secuencia del estado, en el instante de su reloj ───────────────
-- → nombre de la secuencia y tiempo (o cuadro k para andar) de lo que toca ahora
function DataEnemy:animNow()
    local st = self.state
    local map = self.spec.states or {}
    local set = self.animSet
    if st == 'walk' or st == 'launched' or st == 'spawning' or st:match('^drop_') then return map.walk or 'walk', nil, self.frame end
    if st == 'idle' then return map.idle or 'idle', self.breatheT or 0 end
    if st == 'stunned' or st == 'frozen' then
        local a = map.hurt or 'hurt'
        return set:has(a) and a or (map.idle or 'idle'), 0
    end
    if st == 'dead' or st == 'dead_fling' then return map.dead or 'dead', self.deadTimer or 0 end
    return map[st] or st, self.deadTimer or 0
end

function DataEnemy:render(camX, camY)
    if self.state == 'reserve' then return end
    local set, spec = self.animSet, self.spec
    local name, t, k = self:animNow()
    local fi = k and set:frameN(name, k) or (set:frameAt(name, t))
    local S = spec.scale or set.scale or 4
    local bx, by = 1, 1
    if spec.breathe ~= false and self.state == 'idle' then bx, by = self:breatheScale() end
    local sx = S * self.facing * (spec.facesLeft and -1 or 1) * bx
    local sy = S * by
    local x = math.floor(self.x - camX)
    local y
    if self.flipped then sy = -sy; y = math.floor(self.y - camY - self.sprH / 2)
    else y = math.floor(self.y - camY + self.sprH / 2) end
    local a = 1
    if self.state == 'hurt' and math.floor((self.deadTimer or 0) * 16) % 2 == 0 then a = 0.45 end
    love.graphics.setColor(1, 1, 1, a)
    set:drawFrame(fi, x, y, 0, sx, sy, 0.5, 1)
    love.graphics.setColor(1, 1, 1, 1)
    -- proyectiles: la secuencia `shot` (si no la hay, el primer cuadro en pequeño)
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

-- ── De los datos al tipo ──────────────────────────────────────────────────────
-- Definición de tipo (lo que registra EntityTypes) a partir de los datos de un enemigo
function DataEnemy.typeDef(spec)
    local set = Anim.load(spec.anim, spec.variant)
    local walk = set:seq((spec.states or {}).walk or 'walk')
    local hb = spec.hitbox or {}
    local cls = Entity.extend(DataEnemy, {
        walkFps = walk and walk.fps or 7, walkFrames = walk and #walk.frames or 1,
        hitbox = { outerW = hb.outerW or 0.72, outerH = hb.outerH or 0.8, innerW = hb.innerW or 0.44, innerH = hb.innerH or 0.5 },
    })
    cls.spec = spec
    cls.darkEdge = spec.darkEdge
    function cls.loadAssets() Anim.load(spec.anim, spec.variant) end
    function cls.sizePx()
        local w, h = set:size(1)
        local S = spec.scale or set.scale or 4
        return w * S, h * S
    end
    local traits = {}
    for k, v in pairs(spec.traits or {}) do if v then traits[k] = v end end
    local f1 = set:frame(1)
    local defaults = {}
    for k, v in pairs(spec.defaults or {}) do defaults[k] = v end
    return {
        name = spec.id, label = spec.label or spec.id, category = spec.category or 'Enemigos',
        description = spec.description ~= '' and spec.description or nil,
        class = cls, defaults = defaults, traits = next(traits) and traits or nil,
        dataEnemy = true,
        editor = f1 and { sprite = f1.path, frameW = (f1.w ~= f1.iw) and f1.w or nil } or nil,
    }
end

-- Los ids del índice (assets/enemies/index.json), en su orden
function DataEnemy.ids()
    local text = love.filesystem.read(DataEnemy.INDEX)
    local ok, idx = pcall(json.decode, text or '')
    local out = {}
    if ok and type(idx) == 'table' then
        for _, id in ipairs(idx.enemies or {}) do if type(id) == 'string' then out[#out + 1] = id end end
    end
    return out
end

function DataEnemy.read(id)
    local text = love.filesystem.read(DataEnemy.DIR .. id .. '.json')
    if not text then return nil, 'no existe' end
    local ok, spec = pcall(json.decode, text)
    if not ok or type(spec) ~= 'table' then return nil, 'JSON no válido' end
    spec.id = id
    return spec
end

-- Registra todos los del índice (lo llama Entities.lua después de los tipos escritos en Lua). Uno roto no
-- tumba el juego: se avisa y se salta.
function DataEnemy.registerAll(EntityTypes)
    for _, id in ipairs(DataEnemy.ids()) do
        local spec, err = DataEnemy.read(id)
        if not spec then
            print('[DataEnemy] ' .. id .. ': ' .. tostring(err))
        elseif EntityTypes.byName[id] then
            print('[DataEnemy] ' .. id .. ': ya hay un tipo con ese nombre (se salta)')
        else
            local ok, def = pcall(DataEnemy.typeDef, spec)
            if ok then EntityTypes.register(def) else print('[DataEnemy] ' .. id .. ': ' .. tostring(def)) end
        end
    end
end

return DataEnemy
