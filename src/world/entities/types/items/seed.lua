-- La SEMILLA: se CARGA (systems/Carry: ARRIBA) y se PLANTA con un GROUND POUND llevándola, sobre suelo firme: en ~1 s
-- crece una planta de su isla (4-6 casillas, las que quepan; con menos de 4 no se planta) con HOJAS GRANDES a los
-- lados y una COPA arriba que se pisan (plataformas de un solo sentido: Entities.solidBodies, `bodyParts`). Se
-- MARCHITA a los `life` s, o cuando quien la plantó planta otra; entonces la semilla VUELVE a su sitio de salida
-- (ningún nivel se queda sin solución). La de la cueva (seta) da luz.
-- Es la misma física que la Caja pequeña (se lanza, cae, rebota un poco; nunca se rompe) — hereda de ella.
-- Arte (tools/art/world/make_seed_plants.py): assets/images/items/seed/<isla>-seed.png (12x12) y <isla>-plant<4|5|6>.png
-- con su <isla>-plant<h>.json (= las plataformas medidas sobre el dibujo: {w, h, plats = {{x, y, ancho}, ...}} en
-- píxeles de arte; la base de la imagen es el suelo). Sonidos seedPickup / seedPlant / seedGrow / seedWilt.
-- Red: altura, x y suelo de la planta en su netPack (las plataformas se calculan de ellos).
local Entity = require 'src/world/entities/base/Entity'
local Isles  = require 'src/world/level/Isles'
local SmallBox = require('src/world/entities/types/items/box')[2].class

local Seed = Entity.extend(SmallBox, { debugColor = { 0.5, 0.9, 0.4 },
    hitbox = { outerW = 1, outerH = 1, innerW = 1, innerH = 1 } })

local S       = GUMMY_SCALE
local GROW_T  = 1.0
local WILT_T  = 0.8
local PLAT_H  = 12                       -- px de grosor de cada plataforma (se pisa por arriba)
local MIN_H   = 4

Seed.BREAK_LAND, Seed.BREAK_WALL = math.huge, math.huge      -- (no se rompe)
Seed.weight, Seed.PUSH_K = 0.5, 0
function Seed.sizePx() return 12 * S, 12 * S end
function Seed:isSolidBody() return false end
function Seed:pushable() return false end
function Seed:isObstacle() return false end
function Seed:canBeCarried() return self.state == 'rest' end
function Seed:onPickUp() Sound.play('seedPickup') end
function Seed:onPound() return true end          -- (un ground pound cerca no le hace nada: plantarla es llevándola)

-- Datos de cada planta (imagen + plataformas), por isla y altura
local data = {}
local function plantData(isle, h)
    local key = isle .. h
    if not data[key] then
        local json = require 'libs/json'
        local raw = love.filesystem.read('assets/images/items/seed/' .. isle .. '-plant' .. h .. '.json')
        data[key] = raw and json.decode(raw) or { w = 16, h = 16 * h, plats = {} }
    end
    return data[key]
end
local imgs = {}
local function img(path)
    if not imgs[path] then imgs[path] = love.graphics.newImage(path); imgs[path]:setFilter('nearest', 'nearest') end
    return imgs[path]
end

function Seed:init()
    SmallBox.init(self)
    self.plantH, self.plantX, self.groundY = 0, 0, 0
    self.parts = self.parts or {}
end

function Seed:isle() return Isles.of(self.levelRef, self.props.isle) end

-- ¿Cuánto se ve de la planta? (0..1: crece de abajo arriba, se marchita de arriba abajo)
function Seed:reveal()
    local st, t = self.state, self.deadTimer or 0
    if st == 'grow' then return math.min(1, t / GROW_T) end
    if st == 'plant' then return 1 end
    if st == 'wilt' then return math.max(0, 1 - t / WILT_T) end
    return 0
end

-- Las plataformas (hojas grandes y copa) que ya han salido
local function partBox(part)
    local o = part.owner
    local d = plantData(o:isle(), o.plantH)
    local left, top = o.plantX - d.w * S / 2, o.groundY - d.h * S
    local p = d.plats[part.k]
    return left + p[1] * S, top + p[2] * S, p[3] * S
end
function Seed:bodyParts()
    if self.plantH < MIN_H or (self.state ~= 'grow' and self.state ~= 'plant') then return {} end
    local d = plantData(self:isle(), self.plantH)
    local shown = self.groundY - self:reveal() * d.h * S
    local out = {}
    for k = 1, #d.plats do
        local part = self.parts[k]
        if not part then
            part = { owner = self, k = k, solidFull = true, oneway = true, alive = true }
            function part:getOuterBounds(into)
                local x, y, w = partBox(self)
                local b = into or {}
                b.x, b.y, b.w, b.h = x, y, w, PLAT_H
                return b
            end
            self.parts[k] = part
        end
        local _, y = partBox(part)
        if y >= shown then out[#out + 1] = part end
    end
    return out
end

-- Plantar: con un ground pound llevándola (systems/Carry → onCarriedPound), sobre suelo firme con sitio encima
function Seed:onCarriedPound(pa)
    local level = self.levelRef
    if not level then return end
    local T = TILE_PX
    local col = math.floor(pa.x / T)
    local x = (col + 0.5) * T
    local ob = pa:getOuterBounds()
    local foot = ob.y + ob.h
    local ground = level:collisionAt(x, foot + 4)
    if not ground or ground.collision == 'oneway' then Sound.play('seedWilt'); return end
    local gy = math.floor((foot + 4) / T) * T
    local room = 0
    for k = 1, (self.props.height or 6) do
        if level:collisionAt(x, gy - (k - 0.5) * T) then break end
        room = k
    end
    if room < MIN_H then Sound.play('seedWilt'); return end
    -- (la que plantó antes este mismo jugador se marchita)
    for _, e in ipairs(level.liveEntities or {}) do
        if e ~= self and e.plantedBy == pa and (e.state == 'grow' or e.state == 'plant') then e:wilt() end
    end
    self.plantH, self.plantX, self.groundY, self.plantedBy = room, x, gy, pa
    self.x, self.y = x, gy - self.outerH / 2
    self.state, self.deadTimer = 'grow', 0
    Sound.play('seedPlant'); Sound.play('seedGrow')
    Entity.emitFx('gp_start', x, gy)
end

function Seed:wilt()
    if self.state == 'grow' or self.state == 'plant' then
        self.state, self.deadTimer = 'wilt', 0
        Sound.play('seedWilt')
    end
end

function Seed:updateCustom(dt, level)
    self.levelRef = level
    local st = self.state
    if st == 'grow' or st == 'plant' or st == 'wilt' then
        self.deadTimer = self.deadTimer + dt
        if st == 'grow' and self.deadTimer >= GROW_T then self.state, self.deadTimer = 'plant', 0
        elseif st == 'plant' and self.deadTimer >= (self.props.life or 20) then self:wilt()
        elseif st == 'wilt' and self.deadTimer >= WILT_T then
            -- vuelve a su sitio (la animación de aparecer de Entity)
            self:resetToHome()
            self.plantH, self.plantedBy = 0, nil
            self.state, self.deadTimer = 'spawning', 0
        end
        return true
    end
    return SmallBox.updateCustom(self, dt, level)
end

-- (la seta de la cueva da luz, como las bayas)
function Seed:lights()
    if self:isle() ~= 'cueva' or self.plantH < MIN_H then return nil end
    local k = self:reveal()
    if k <= 0 then return nil end
    local d = plantData('cueva', self.plantH)
    return { { x = self.plantX, y = self.groundY - d.h * S * k + 30, r = 260 * k, color = { 0.6, 0.95, 1 }, a = 0.45, pulse = 1.5 } }
end

-- ── Red ───────────────────────────────────────────────────────────────────────
function Seed:netAtRest() return self.state == 'rest' and self.x == self.home.x and self.y == self.home.y end
function Seed:netRest() self:resetToHome(); self.state, self.plantH = 'rest', 0 end
function Seed:netPack() return { self.plantH or 0, math.floor(self.plantX or 0), math.floor(self.groundY or 0) } end
function Seed:netApply(a, b, f)
    self.plantH, self.plantX, self.groundY = b[1] or 0, b[2] or 0, b[3] or 0
end

-- F1: las plataformas
function Seed:debugBoxes()
    local out = {}
    for _, p in ipairs(self:bodyParts()) do
        local b = p:getOuterBounds()
        out[#out + 1] = { x = b.x, y = b.y, w = b.w, h = b.h, kind = 'area' }
    end
    return out
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
function Seed:render(camX, camY)
    local isle = self:isle()
    love.graphics.setColor(1, 1, 1, 1)
    local k = self:reveal()
    if self.plantH >= MIN_H and k > 0 then
        local im = img('assets/images/items/seed/' .. isle .. '-plant' .. self.plantH .. '.png')
        local w, h = im:getDimensions()
        local vis = math.max(1, math.floor(h * k))
        local q = love.graphics.newQuad(0, h - vis, w, vis, w, h)
        if self.state == 'wilt' then love.graphics.setColor(0.75, 0.7, 0.55, k) end
        love.graphics.draw(im, q, math.floor(self.plantX - camX - w * S / 2), math.floor(self.groundY - camY - vis * S), 0, S, S)
        love.graphics.setColor(1, 1, 1, 1)
        return
    end
    if self.state == 'grow' or self.state == 'wilt' then return end
    local sd = img('assets/images/items/seed/' .. isle .. '-seed.png')
    local bob = (self.state == 'rest' and self.onGround ~= false) and math.floor(math.abs(math.sin(love.timer.getTime() * 2)) * 3) or 0
    love.graphics.draw(sd, math.floor(self.x - camX - 6 * S), math.floor(self.y - camY - 6 * S - bob), 0, S, S)
end

return {
    name = 'seed', label = 'Semilla', category = 'Objetos', class = Seed,
    description = 'Se carga (ARRIBA) y se planta con un ground pound llevándola: crece una planta de su isla con hojas '
               .. 'grandes y copa que se pisan. Se marchita y la semilla vuelve a su sitio.',
    defaults = { movement = 'static', stompable = false },
    hide = 'all',
    props = {
        { key = 'height', kind = 'int', label = 'Altura máxima (casillas)', group = 'Semilla', default = 6, min = 4, max = 6, step = 1,
          help = 'La planta crece hasta esto (o lo que quepa; con menos de 4 casillas libres no se planta)' },
        { key = 'life', kind = 'number', label = 'Dura (s)', group = 'Semilla', default = 20, min = 3, max = 120, step = 1,
          help = 'Luego se marchita y la semilla vuelve a su sitio de salida' },
    },
    isleArt = true,
    editor = { sprite = 'assets/images/items/seed/pradera-seed.png' },
}
