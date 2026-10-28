-- El GÉISER: un respiradero en el suelo (se coloca en la casilla del suelo de encima: el respiradero ocupa su mitad de
-- abajo). Cada `interval` s BORBOTEA (~1 s de aviso: `geyserRumble`) y lanza una COLUMNA de `height` casillas (se
-- corta en el primer bloque) durante `erupt` s que EMPUJA HACIA ARRIBA todo lo que tiene física (systems/Push:
-- jugadores, enemigos, cajas, bombas, semillas…), sin daño. Por isla (Isles): pradera y costa AGUA · fortaleza VAPOR ·
-- cueva vapor que BRILLA (da luz) · jungla AGUA · volcán HUMO, que también solo empuja (el usuario: "por continuidad, para no
-- confundir") · nieve: el agua SE CONGELA en un PILAR DE HIELO cuyo remate se pisa (`freeze` s; el último segundo se
-- agrieta) y luego se rompe.
-- Arte (tools/art/world/make_wind_geyser.py): assets/images/mechanisms/geyser/<isla>-vent.png (16x8), -warn-Sheet.png
-- (3 cuadros 16x8), -column-Sheet.png (3 cuadros 16x16, se repite hacia arriba), -crest-Sheet.png (3 cuadros 16x16);
-- nieve: -ice.png (16x16), -icetop.png (16x8), -cracks-Sheet.png (2 cuadros 16x16).
-- Red: estado y tiempo (los de siempre); en reposo no se envía. La altura se mide del nivel en cada sitio.
local Entity = require 'src/world/entities/base/Entity'
local Isles  = require 'src/world/level/Isles'
local Push   = require 'src/world/systems/Push'
local Weight = require 'src/world/systems/Weight'
local Clip   = require 'src/ui/Clip'

local Gey = Entity.extend(Entity, { debugColor = { 0.5, 0.8, 1 },
    hitbox = { outerW = 1, outerH = 0.5, innerW = 1, innerH = 0.5 } })

local S       = GUMMY_SCALE
local LIFT    = 780          -- px/s hacia arriba (× power, ÷ el peso de lo que levanta)
local SHARP   = 3            -- lo brusco del empujón (systems/Push): fuerte pero sin salir disparado (el usuario: con 10
                             -- una caja o el monstruo encima salían volando)
local RISE    = 1100         -- px/s: lo rápido que SUBE el agua (no aparece entera de golpe: sube y se para en lo que toca)
local GROW_T  = 0.12         -- s en los que la fuerza llega a su máximo
local DECAY_T = 0.9          -- s en los que se va apagando al final (baja y empuja menos)
local CRACK_T = 1.0          -- s agrietándose antes de romperse (nieve)
-- Azar fijo por número (las partículas: igual en todos los clientes, sin math.random en el dibujo)
local function hash(a, b)
    local v = math.sin(a * 12.9898 + b * 78.233) * 43758.5453
    return v - math.floor(v)
end
local KIND = { pradera = 'water', costa = 'water', nieve = 'water', fortaleza = 'steam', cueva = 'steam', volcan = 'smoke',
               jungla = 'water' }

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
        -- (sube DE GOLPE y al final se va APAGANDO poco a poco — el chorro baja y empuja menos —: antes desaparecía de
        -- golpe, el usuario. En la nieve no baja: se congela entero)
        local down = self:freezes() and 1 or (e - t) / math.min(DECAY_T, e * 0.6)
        return math.max(0, math.min(1, t / GROW_T, down))
    end
    if st == 'iced' then return 1 end
    return 0
end
-- EL CHORRO ES UNA COLUMNA DE VERDAD (0.5.71; el usuario: antes se calculaba su alto de golpe y "se parcheaba": al
-- empezar subía un instante hasta arriba atravesando lo que tenía encima, y al caerle una caja crecía otra vez). Su
-- cara de arriba `jetY` es un ESTADO: sube a RISE px/s hacia su alto (el que da la fuerza ahora: al final baja) y NUNCA
-- atraviesa nada: se para en la cara de abajo de lo primero que encuentra — un jugador, un enemigo, una caja, una
-- bomba, una semilla… — y solo empuja a ESO (lo que está tocando su cara de arriba), más despacio cuanto más pesa con
-- todo lo que lleva encima (systems/Weight); lo de encima sube porque va encima. Si lo que levanta baja (el chorro se
-- apaga), baja con él: el chorro se acorta, nunca vuelve a crecer por tocarlo. Lo simula un jugador / el servidor; al
-- cliente le llegan `jetY` y `loadF` en el netPack (dibuja con ellos y predice a su jugador: si sus pies están en
-- `jetY`, es lo que levanta).
function Gey:topY() return self.jetY or self:mouthY() end
function Gey:freezes() return self:isle() == 'nieve' and self.props.freeze ~= 0 end

local B = {}
local function inColumn(self, b) return b.x < self.x + TILE_PX * 0.45 and b.x + b.w > self.x - TILE_PX * 0.45 end
function Gey:pushAt(x, y, o)
    if self.state ~= 'erupt' or not self.jetY then return nil end
    if math.abs(x - self.x) > TILE_PX * 0.45 then return nil end
    local k = self:amount()
    if k <= 0.05 or not o then return nil end
    local touching
    if self.simulated then touching = (o == self.load)
    elseif o.getOuterBounds then                                   -- (cliente: por dónde tiene los pies)
        local b = o:getOuterBounds(B)
        touching = inColumn(self, b) and math.abs(b.y + b.h - self.jetY) <= 8
    end
    if not touching then return nil end
    -- (cerca de su ALTO el chorro frena lo que lleva: llega arriba despacio y se queda sostenido, no sale volando — el
    -- usuario —; 1,5 casillas antes de su alto empieza a frenar)
    local mouth = self:mouthY()
    local natural = mouth - (mouth - self:reach()) * k
    local near = math.max(0.3, math.min(1, (self.jetY - natural) / (1.5 * TILE_PX)))
    return 0, -LIFT * (self.props.power or 1) * k * (self.loadF or 1) * near, SHARP, true   -- (`true`: ya va su peso)
end

-- Lo PRIMERO que encuentra el agua al subir hasta `top` (simulación): lo más bajo con los pies entre `top` y el suelo
-- de la boca, dentro de la columna. Jugadores y todo lo que tiene física (no solo cajas)
function Gey:findLoad(level, top)
    local best, bestBot, isPl
    local function try(o, player)
        local b = o:getOuterBounds(B)
        local bot = b.y + b.h
        if inColumn(self, b) and bot >= top - 2 and bot <= self.cellBottom + 2 and (not bestBot or bot > bestBot) then
            best, bestBot, isPl = o, bot, player
        end
    end
    for _, pa in ipairs(level.players or {}) do if not pa.dying and pa.alive ~= false then try(pa, true) end end
    for _, e in ipairs(level.liveEntities or {}) do
        if e ~= self and (Push.canPush(e) or e.solidFull) and Weight.counts(e, self) then try(e, false) end
    end
    if not best then return nil end
    return best, bestBot, Weight.total(best, level, isPl, self)
end

-- Un paso del agua: sube hacia su alto, se para en lo que toca
function Gey:stepJet(dt, level)
    local mouth = self:mouthY()
    if self.state ~= 'erupt' then
        if self.state ~= 'iced' then self.jetY = nil end               -- (congelado: el pilar se queda como quedó)
        self.load, self.loadF = nil, 1
        return
    end
    local natural = mouth - (mouth - self:reach()) * self:amount()
    local jy = self.jetY or mouth
    if natural < jy then jy = math.max(natural, jy - RISE * dt) else jy = natural end
    local o, bot, w = self:findLoad(level, jy)
    if o then jy = math.max(jy, math.min(bot, mouth)) end            -- (se para en su cara de abajo)
    self.jetY, self.load, self.loadF = jy, o, o and 1 / math.max(1, w) or 1
end

-- El pilar de hielo (nieve): su remate se pisa
function Gey:bodyParts()
    if self.state == 'iced' then return { self.part } end
    return {}
end

function Gey:updateCustom(dt, level)
    self.levelRef, self.simulated = level, true
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
    self:stepJet(dt, level)
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
function Gey:netRest() self.state, self.jetY = 'idle', nil end
function Gey:netPack() return { self.jetY and math.floor(self.jetY + 0.5) or 0, math.floor((self.loadF or 1) * 100 + 0.5) } end
function Gey:netApply(a, b, f)
    local ya, yb = a[1] or 0, b[1] or 0
    if yb == 0 then self.jetY = nil
    elseif ya == 0 then self.jetY = yb
    else self.jetY = ya + (yb - ya) * f end
    self.loadF = (b[2] or 100) / 100
end

-- Dónde va a salir (avisando) o sale el chorro: para que los bots se aparten (src/ai/Bot.lua)
function Gey:windArea()
    if self.state ~= 'warn' and self.state ~= 'erupt' then return nil end
    return { x0 = self.x - TILE_PX * 0.6, y0 = self:reach(), x1 = self.x + TILE_PX * 0.6, y1 = self.cellBottom }
end

function Gey:debugBoxes()
    if self.state ~= 'erupt' then return nil end
    local top = self:topY()
    return { { x = self.x - TILE_PX * 0.45, y = top, w = TILE_PX * 0.9, h = self:mouthY() - top, kind = 'area' } }
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
            -- (el agua llega EXACTAMENTE hasta `top` — donde empuja y donde se apoya lo que levanta —: los tramos se ponen
            -- desde arriba y se recortan en la boca; antes subían de casilla en casilla y quedaban hasta una por debajo)
            Clip.push(x - TILE_PX / 2, top, TILE_PX, mouth - top + 2)
            local k = 0
            for y = top, mouth, TILE_PX do
                col:draw(1 + (f + k) % 3, x, y + TILE_PX / 2, 0, S, S)
                k = k + 1
            end
            Clip.pop()
            -- ESPUMA Y VAPOR (el usuario: más, y que no sean dos "líneas" fijas a los lados): un penacho triple arriba
            -- (más grande al reventar), gotas que saltan del penacho, gotas que salpican desde la boca y CAEN, y vapor
            -- que sube desde la boca. Cada partícula, en cada vuelta, con su azar (lado, ángulo, velocidad, tamaño,
            -- vaivén): `hash`. Solo dependen de deadTimer y de su número: igual online. Todo × lo que sale (se apaga)
            local amt = self:amount()
            local burst = math.max(0, 1 - t / 0.35)
            local puffs = strip(base .. '-warn-Sheet.png', 16)
            for k = -1, 1 do
                local sc = S * (0.6 + 0.4 * amt) * (1 + 0.35 * burst) * (k == 0 and 1 or 0.8)
                crest:draw(1 + (f + k + 1) % 3, x + k * 22, top - TILE_PX / 2 + 24 - (k == 0 and 4 or 0), 0, k < 0 and -sc or sc, sc)
            end
            local function part(n, period, salt)
                local ph = hash(n, salt)
                local life = period * (0.7 + 0.6 * hash(n, salt + 1))
                local c = math.floor((t + ph * life) / life)
                return ((t + ph * life) / life) % 1, function(k) return hash(n * 31 + c, salt + k) end
            end
            for n = 0, 15 do                                   -- gotas del penacho
                local u, r = part(n, 0.7, 10)
                local side = r(1) < 0.5 and -1 or 1
                local tt = u * 0.7
                local px = x + side * (6 + (70 + 110 * r(2)) * tt)
                local py = top + 12 - (180 + 220 * r(3)) * tt + 0.5 * ADV_GRAVITY * tt * tt
                love.graphics.setColor(1, 1, 1, (1 - u) * amt)
                local sc = S * (0.8 + 0.9 * r(4))
                puffs:draw(1 + math.floor(r(5) * 3), math.floor(px), math.floor(py), 0, sc, sc)
            end
            for n = 0, 11 do                                   -- salpicaduras de la boca: saltan a los lados y caen
                local u, r = part(n, 0.55, 30)
                local side = r(1) < 0.5 and -1 or 1
                local tt = u * 0.55
                local px = x + side * (10 + (60 + 120 * r(2)) * tt)
                local py = mouth - 4 - (160 + 200 * r(3)) * tt + 0.5 * ADV_GRAVITY * tt * tt
                if py < mouth + 8 then
                    love.graphics.setColor(1, 1, 1, (1 - u) * 0.9 * amt)
                    local sc = S * (0.6 + 0.7 * r(4))
                    puffs:draw(1 + math.floor(r(5) * 2), math.floor(px), math.floor(py), 0, sc, sc)
                end
            end
            for n = 0, 13 do                                   -- vapor: sube, se abre, vaivén
                local u, r = part(n, 1.3, 50)
                local side = r(1) < 0.5 and -1 or 1
                local px = x + side * (6 + (20 + 70 * r(2)) * u) + math.sin(t * (3 + 3 * r(3)) + n) * (4 + 8 * u)
                local py = mouth - 6 - (70 + 120 * r(4)) * u
                local a = math.min(1, u * 8) * (1 - u) ^ 1.3 * 0.8 * (0.4 + 0.6 * amt)
                love.graphics.setColor(1, 1, 1, a)
                local sc = S * (1 + (1.2 + 1.4 * r(5)) * u)
                puffs:draw(3, math.floor(px), math.floor(py), 0, sc, sc)
            end
            love.graphics.setColor(1, 1, 1, 1)
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
