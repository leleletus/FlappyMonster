-- El GÉISER: un respiradero en el suelo (se coloca en la casilla del suelo de encima: el respiradero ocupa su mitad de
-- abajo). Cada `interval` s BORBOTEA (~1 s de aviso: `geyserRumble`) y lanza una COLUMNA de `height` casillas (se
-- corta en el primer bloque) durante `erupt` s que EMPUJA HACIA ARRIBA todo lo que tiene física (systems/Push:
-- jugadores, enemigos, cajas, bombas, semillas…), sin daño. Por isla (Isles): pradera y costa AGUA · fortaleza VAPOR ·
-- cueva vapor que BRILLA (da luz) · volcán HUMO, que también solo empuja (el usuario: "por continuidad, para no
-- confundir") · nieve: el agua SE CONGELA en un PILAR DE HIELO cuyo remate se pisa (`freeze` s; el último segundo se
-- agrieta) y luego se rompe.
-- Arte (tools/art/world/make_wind_geyser.py): assets/images/mechanisms/geyser/<isla>-vent.png (16x8), -warn-Sheet.png
-- (3 cuadros 16x8), -column-Sheet.png (3 cuadros 16x16, se repite hacia arriba), -crest-Sheet.png (3 cuadros 16x16);
-- nieve: -ice.png (16x16), -icetop.png (16x8), -cracks-Sheet.png (2 cuadros 16x16).
-- Red: estado y tiempo (los de siempre); en reposo no se envía. La altura se mide del nivel en cada sitio.
local Entity = require 'src/world/entities/base/Entity'
local Isles  = require 'src/world/level/Isles'

local Gey = Entity.extend(Entity, { debugColor = { 0.5, 0.8, 1 },
    hitbox = { outerW = 1, outerH = 0.5, innerW = 1, innerH = 0.5 } })

local S       = GUMMY_SCALE
local LIFT    = 640          -- px/s hacia arriba (× power)
local GROW_T  = 0.2          -- s en los que la columna sube (y baja al final)
local CRACK_T = 1.0          -- s agrietándose antes de romperse (nieve)
local KIND = { pradera = 'water', costa = 'water', nieve = 'water', fortaleza = 'steam', cueva = 'steam', volcan = 'smoke' }

Gey.wantsLevel = true
function Gey.sizePx() return TILE_PX, TILE_PX / 2 end

function Gey:init()
    self.moving, self.flying, self.vx, self.vy = false, true, 0, 0
    -- la boca: la mitad de abajo de su casilla
    self.cellBottom = self.row * TILE_PX
    self.x, self.y = (self.col - 0.5) * TILE_PX, self.cellBottom - TILE_PX / 4
    self.state, self.deadTimer = 'idle', (self.props.interval or 3) - (self.props.firstDelay or 1.5)
    self.part = self.part or { owner = self, solidFull = true, oneway = true, alive = true }
    local me = self
    function self.part:getOuterBounds(into)
        local b = into or {}
        local top = me:topY()
        b.x, b.y, b.w, b.h = me.x - TILE_PX / 2, top, TILE_PX, 16
        return b
    end
end
function Gey:canBeStomped() return false end
function Gey:canBeKnocked() return false end
function Gey:canFreeze() return false end
function Gey:isObstacle() return false end
function Gey:isGhost() return true end
function Gey:interact() return nil end

function Gey:isle() return Isles.of(self.levelRef, self.props.isle) end

-- Hasta dónde llega la columna (y de la boca): `height` casillas o hasta el primer bloque
local VENT_Y = 20            -- px desde el fondo de la casilla hasta la boca
function Gey:mouthY() return self.cellBottom - VENT_Y end
function Gey:reach()
    local level, h = self.levelRef, (self.props.height or 5)
    local top = self:mouthY() - h * TILE_PX
    if level then
        for k = 1, h do
            local y = self.cellBottom - TILE_PX - (k - 0.5) * TILE_PX
            if level:collisionAt(self.x, y) then top = self.cellBottom - TILE_PX - (k - 1) * TILE_PX; break end
        end
    end
    return top
end
-- Lo que sale ahora (0..1 de la columna)
function Gey:amount()
    local st, t = self.state, self.deadTimer or 0
    if st == 'erupt' then
        local e = self.props.erupt or 2
        return math.max(0, math.min(1, t / GROW_T, (e - t) / GROW_T + (self:freezes() and 1 or 0)))
    end
    if st == 'iced' then return 1 end
    return 0
end
function Gey:topY() return self:mouthY() - (self:mouthY() - self:reach()) * self:amount() end
function Gey:freezes() return self:isle() == 'nieve' and self.props.freeze ~= 0 end

function Gey:pushAt(x, y)
    if self.state ~= 'erupt' then return nil end
    if math.abs(x - self.x) > TILE_PX * 0.45 then return nil end
    local top = self:topY()
    if y > self.cellBottom or y < top - TILE_PX * 0.6 then return nil end
    return 0, -LIFT * (self.props.power or 1) * math.max(0.4, self:amount())
end

-- El pilar de hielo (nieve): su remate se pisa
function Gey:bodyParts()
    if self.state == 'iced' then return { self.part } end
    return {}
end

function Gey:updateCustom(dt, level)
    self.levelRef = level
    self.deadTimer = self.deadTimer + dt
    local st, p = self.state, self.props
    local kind = KIND[self:isle()] or 'water'
    if st == 'idle' and self.deadTimer >= (p.interval or 3) then
        self.state, self.deadTimer = 'warn', 0
        Sound.play('geyserRumble')
    elseif st == 'warn' and self.deadTimer >= (p.warn or 1) then
        self.state, self.deadTimer = 'erupt', 0
        Sound.play(kind == 'water' and 'geyserBurst' or 'steamHiss')
    elseif st == 'erupt' and self.deadTimer >= (p.erupt or 2) then
        if self:freezes() then
            self.state, self.deadTimer = 'iced', 0
            Sound.play('iceFreeze')
            Entity.emitFx('ice_freeze', self.x, self:topY())
        else
            self.state, self.deadTimer = 'idle', 0
        end
    elseif st == 'iced' and self.deadTimer >= (p.freeze or 3) then
        self.state, self.deadTimer = 'idle', 0
        Sound.play('iceFreeze')
        Entity.emitFx('ice_shatter', self.x, (self:mouthY() + self:reach()) / 2)
    end
    return true
end

-- (la cueva: el vapor brilla)
function Gey:lights()
    if self:isle() ~= 'cueva' or (self.state ~= 'erupt' and self.state ~= 'warn') then return nil end
    local k = self.state == 'warn' and 0.3 or math.max(0.3, self:amount())
    return { { x = self.x, y = (self:mouthY() + self:topY()) / 2, r = 220 * k, color = { 0.75, 0.95, 1 }, a = 0.5, pulse = 3 } }
end

-- ── Red ───────────────────────────────────────────────────────────────────────
function Gey:netAtRest() return self.state == 'idle' end
function Gey:netRest() self.state = 'idle' end

function Gey:debugBoxes()
    if self.state ~= 'erupt' then return nil end
    local top = self:topY()
    return { { x = self.x - TILE_PX * 0.45, y = top - TILE_PX * 0.6, w = TILE_PX * 0.9, h = self.cellBottom - top + TILE_PX * 0.6, kind = 'area' } }
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
local strips = {}
local function strip(path, w)
    if not strips[path] then strips[path] = require('src/fx/SpriteStrip').load(path, w) end
    return strips[path]
end

function Gey:render(camX, camY)
    local isle = self:isle()
    local base = 'assets/images/mechanisms/geyser/' .. isle
    local x = math.floor(self.x - camX)
    local bot = math.floor(self.cellBottom - camY)
    local t = self.deadTimer or 0
    love.graphics.setColor(1, 1, 1, 1)
    local mouth = math.floor(self:mouthY() - camY)
    if self.state == 'erupt' or self.state == 'iced' then
        local top = math.floor(self:topY() - camY)
        if self.state == 'iced' then
            local ice, cap = strip(base .. '-ice.png', 16), strip(base .. '-icetop.png', 16)
            for y = mouth, top + 32, -TILE_PX do ice:draw(1, x, y - TILE_PX / 2, 0, S, S) end
            cap:draw(1, x, top + 16, 0, S, S)
            local left = (self.props.freeze or 3) - t
            if left < CRACK_T then
                local cr = strip(base .. '-cracks-Sheet.png', 16)
                for y = mouth, top + 32, -TILE_PX do cr:draw(left < CRACK_T / 2 and 2 or 1, x, y - TILE_PX / 2, 0, S, S) end
            end
        elseif top < mouth then
            local col, crest = strip(base .. '-column-Sheet.png', 16), strip(base .. '-crest-Sheet.png', 16)
            local f = 1 + math.floor(t * 12) % 3
            for y = mouth, top + TILE_PX, -TILE_PX do col:draw(1 + (f + math.floor((mouth - y) / TILE_PX)) % 3, x, y - TILE_PX / 2, 0, S, S) end
            crest:draw(f, x, top + TILE_PX / 2 - 20, 0, S, S)
        end
    elseif self.state == 'warn' then
        local w = strip(base .. '-warn-Sheet.png', 16)
        w:draw(math.min(3, 1 + math.floor(t / (self.props.warn or 1) * 3)), x, mouth - 16, 0, S, S)
    end
    strip(base .. '-vent.png', 16):draw(1, x, bot - 16, 0, S, S)
end

local function drawIcon(x, y, s)
    love.graphics.setColor(1, 1, 1, 1)
    strip('assets/images/mechanisms/geyser/pradera-vent.png', 16):draw(1, x + s / 2, y + s * 0.75, 0, s / 16, s / 16)
    strip('assets/images/mechanisms/geyser/pradera-crest-Sheet.png', 16):draw(2, x + s / 2, y + s * 0.3, 0, s / 32, s / 32)
end

return {
    name = 'geyser', label = 'Géiser', category = 'Mecanismos', class = Gey,
    description = 'Respiradero en el suelo: borbotea (aviso) y lanza una columna que empuja hacia arriba todo lo que '
               .. 'tiene física, sin daño. En la nieve se congela en un pilar que se pisa y luego se rompe.',
    hide = 'all', defaults = { movement = 'static' },
    props = {
        { key = 'height', kind = 'int', label = 'Altura (casillas)', group = 'Géiser', default = 5, min = 2, max = 12, step = 1,
          help = 'Lo alto de la columna (se corta en el primer bloque)' },
        { key = 'interval', kind = 'number', label = 'En reposo (s)', group = 'Géiser', default = 3, min = 0.5, max = 30, step = 0.5 },
        { key = 'warn', kind = 'number', label = 'Aviso (s)', group = 'Géiser', default = 1, min = 0.3, max = 4, step = 0.1 },
        { key = 'erupt', kind = 'number', label = 'Erupción (s)', group = 'Géiser', default = 2, min = 0.5, max = 10, step = 0.1 },
        { key = 'freeze', kind = 'number', label = 'Pilar de hielo (s)', group = 'Géiser', default = 3, min = 0, max = 15, step = 0.5,
          help = 'Solo en la nieve: lo que dura el pilar congelado antes de romperse (0 = no se congela)' },
        { key = 'firstDelay', kind = 'number', label = 'Primer aviso tras (s)', group = 'Géiser', default = 1.5, min = 0, max = 30, step = 0.5 },
        { key = 'power', kind = 'number', label = 'Fuerza', group = 'Géiser', default = 1, min = 0.3, max = 3, step = 0.05 },
    },
    isleArt = true,
    editor = { draw = drawIcon },
}
