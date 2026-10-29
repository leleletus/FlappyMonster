-- La PLANTA CARNÍVORA (types/enemies/carnivoreplant.lua; 0.5.96, diseño B «Cepo» elegido por el usuario el
-- 2026-10-29): de la JUNGLA. FIJA en el suelo, como una trampa: dos hojas dentadas tumbadas con una flor de cebo.
--   · Un jugador que pasa POR ENCIMA o justo AL LADO (su caja de disparo: TRIGGER_HW de lado, TRIGGER_H de alto) la
--     dispara: tiembla un instante (el aviso, TELL_T) y se CIERRA de golpe (SNAP_T): quien esté dentro de lo que barren
--     las hojas (SNAP_HW) pierde 1 y sale apartado. Corriendo por encima, te pilla; hay que saltarla.
--   · Luego se queda CERRADA masticando (`chewTime` s): SOLO ENTONCES se la puede pisar (muere: se marchita). Tocarla
--     cerrada no hace nada. Después se vuelve a abrir (OPEN_T) y no se dispara en REARM s.
--   · Se le puede DAR DE COMER: algo con `edible = true` en su clase (hoy el Escarabajo Rinoceronte: lanzado, o andando
--     / embistiendo / patas arriba) que entra en su caja de disparo → se cierra sobre él, se lo COME (desaparece con un
--     crujido: Entity:dieEaten) y DUERME `sleepTime` s ("z"): inofensiva y se la puede pisar. Los demás enemigos no se
--     comen: para los que andan es un obstáculo (se dan la vuelta).
-- No se mueve (static): ni empujones, ni trampolines, ni el aire. Todo lo que se dibuja sale de estado + deadTimer:
-- igual online; abierta y esperando no se envía (netAtRest). Arte: assets/images/enemies/carnivoreplant/plant-Sheet.png
-- (11 cuadros 26x24, la base en la fila de abajo) de tools/art/enemies/make_jungle_enemies.py; conjunto
-- assets/anim/enemies/carnivoreplant.json; la "z" de dormida, BossFx.sleepZ. Sonidos plantRustle / plantSnap /
-- plantCrunch (tools/sounds/jungle_enemies.py).
local Entity       = require 'src/world/entities/base/Entity'
local Interactions = require 'src/world/entities/base/Interactions'
local BossFx

local Plant = Entity.extend(Entity, {
    debugColor = { 0.85, 0.3, 0.5 },
    deadDuration = 2.5,              -- (marchita, se queda un rato)
    -- (la caja es la de la vaina CERRADA: ~8 de los 26 px de ancho, 13 de los 24 de alto)
    hitbox = { outerW = 0.3, outerH = 0.55, innerW = 0.26, innerH = 0.45 },
})

local S         = GUMMY_SCALE
local FW, FH    = 26, 24
local TRIGGER_HW = 52            -- px a cada lado del centro: la caja que la dispara (las hojas abiertas miden ±44)
local TRIGGER_H  = 1.2           -- casillas por encima del suelo
local SNAP_HW    = 44            -- px a cada lado: lo que barren las hojas al cerrarse (ahí muerde)
local SNAP_H     = 0.9           -- casillas de alto de lo que muerde
local TELL_T     = 0.3           -- s temblando (el aviso)
local SNAP_T     = 0.15          -- s cerrándose (lo que dura el mordisco)
local CHEW_T     = 2.4           -- s cerrada masticando (prop `chewTime`): la ventana para pisarla
local SLEEP_T    = 6             -- s dormida tras comer (prop `sleepTime`)
local OPEN_T     = 0.35          -- s abriéndose
local REARM      = 0.4           -- s abierta antes de poder dispararse otra vez
local SHUT = { chew = true, sleep = true }                      -- (cerrada: se la puede pisar)

Plant.animId = 'enemies/carnivoreplant'
Plant.freezeFloats = true
function Plant.sizePx() return FW * S, FH * S end

function Plant:init()
    self.state, self.deadTimer, self.cd = 'idle', 0, 0
    self.vx, self.moving = 0, false
    self.props.stompable, self.props.onTouch = true, 'none'
end

-- ── Reglas ────────────────────────────────────────────────────────────────────
function Plant:canBeStomped() return SHUT[self.state] == true end
function Plant:canBeKnocked() return false end
function Plant:canBeLaunched() return false end
function Plant:canBePushed() return false end
function Plant:canDropNow() return false end

local function feetY(self) return self.y + self.outerH / 2 end
local function overlap(a, b) return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y end

function Plant:triggerBox()
    local f = feetY(self)
    return { x = self.x - TRIGGER_HW, y = f - TRIGGER_H * TILE_PX, w = TRIGGER_HW * 2, h = TRIGGER_H * TILE_PX }
end
function Plant:snapBox()
    local f = feetY(self)
    return { x = self.x - SNAP_HW, y = f - SNAP_H * TILE_PX, w = SNAP_HW * 2, h = SNAP_H * TILE_PX }
end

-- El mordisco: mientras se cierra, lo que barren las hojas quita 1 (zona de peligro: el cliente la predice)
function Plant:getHazardBoxes()
    if self.state ~= 'snap' or not self.alive then return nil end
    local b = self:snapBox()
    b.effect = 'hurt'
    return { b }
end
function Plant:onHurtPlayer(pa)
    if pa.recoil then pa:recoil(pa.x >= self.x and 1 or -1) end
end

-- Sin efectos: solo cerrada (masticando o dormida) se la pisa; abierta, caerle encima solo la dispara (update)
function Plant:interact(pa)
    local r, a, b, c = Interactions.defaultCheck(pa, self)
    if r == 'stomp' and not SHUT[self.state] then return nil end
    return r, a, b, c
end

function Plant:netAtRest() return Entity.netAtRest(self) or (self.alive and self.state == 'idle' and self.cd <= 0) end
function Plant:netRest()
    if self.summonOf then return Entity.netRest(self) end
    self.alive, self.state, self.deadTimer = true, 'idle', 0
end

-- ¿Algún jugador en su caja de disparo? / ¿algo que se come?
function Plant:playerIn(level, box)
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false and overlap(box, pa:getOuterBounds()) then return pa end
    end
    return nil
end
function Plant:foodIn(level, box)
    for _, e in ipairs(level.liveEntities or {}) do
        if e ~= self and e.edible and e.alive and e.state ~= 'dead' and e.state ~= 'carried' and e.state ~= 'reserve'
           and not (e.isGhost and e:isGhost()) and overlap(box, e:getOuterBounds()) then
            return e
        end
    end
    return nil
end

function Plant:shut(st)
    self.state, self.deadTimer = st, 0
end

-- ── Update ────────────────────────────────────────────────────────────────────
function Plant:updateCustom(dt, level)
    local st = self.state
    if st == 'walk' then st = 'idle'; self.state, self.deadTimer = 'idle', 0 end    -- (al reaparecer)
    if self.cd > 0 then self.cd = math.max(0, self.cd - dt) end
    self.deadTimer = self.deadTimer + dt
    local t = self.deadTimer
    self.vx = 0
    self:fall(level, dt)
    if self:onDeadlyGround(level) or self:fellOut(level) or self:inVoid(level) then self:dieBurst(); return true end
    local p = self.props

    if st == 'idle' then
        if self.cd <= 0 then
            local box = self:triggerBox()
            local food = self:foodIn(level, box)
            if food then self:snapOn(food); return true end
            if self:playerIn(level, box) then
                self.state, self.deadTimer = 'tell', 0
                Sound.play('plantRustle')
            end
        end
    elseif st == 'tell' then
        local food = self:foodIn(level, self:triggerBox())
        if food then self:snapOn(food); return true end
        if t >= TELL_T then
            self.state, self.deadTimer = 'snap', 0
            Sound.play('plantSnap')
            Entity.emitFx('crab_dig', self.x, feetY(self) + 4, { n = 3 })
        end
    elseif st == 'snap' then
        local food = self:foodIn(level, self:snapBox())
        if food then self:snapOn(food); return true end
        if t >= SNAP_T then self:shut('chew') end
    elseif st == 'eat' then
        if t >= SNAP_T then self:shut('sleep') end
    elseif st == 'chew' then
        if t >= (p.chewTime or CHEW_T) then self.state, self.deadTimer = 'open', 0 end
    elseif st == 'sleep' then
        if t >= (p.sleepTime or SLEEP_T) then
            self.state, self.deadTimer = 'open', 0
            Sound.play('plantRustle', 1.3, 0.5)
        end
    elseif st == 'open' then
        if t >= OPEN_T then self.state, self.deadTimer, self.cd = 'idle', 0, REARM end
    else
        return false
    end
    return true
end

-- Se cierra sobre algo que se come: desaparece y ella se duerme
function Plant:snapOn(food)
    food:dieEaten()
    self.state, self.deadTimer = 'eat', 0
    Sound.play('plantSnap')
    Sound.play('plantCrunch')
    Entity.emitFx('crab_dig', self.x, feetY(self) + 4, { n = 4 })
end

-- ── Dibujo (de estado + deadTimer) ────────────────────────────────────────────
function Plant:render(camX, camY)
    local st, t = self.state, self.deadTimer or 0
    if st == 'reserve' or st == 'dead_burst' then return end
    local set = self:anims()
    local f = self.facing or 1
    local x = math.floor(self.x - camX)
    local feet = math.floor(feetY(self) - camY)
    local fr, ox, a = nil, 0, 1
    if st == 'tell' then
        fr = set:frameAt('tell', t)
        ox = (math.floor(t * 30) % 2 == 0) and 1 or -1
    elseif st == 'snap' or st == 'eat' then fr = set:frameAt('snap', t)
    elseif st == 'chew' then fr = set:frameAt('chew', t)
    elseif st == 'sleep' then fr = set:frameAt('sleep', t)
    elseif st == 'open' then fr = set:frameAt('snap', math.max(0, set:length('snap') * (1 - t / OPEN_T)))   -- (al revés)
    elseif st == 'dead' or st == 'dead_fling' then
        fr = set:frameAt('dead', 0)
        a = math.max(0, 1 - math.max(0, t - self.tuning.deadDuration * 0.4) / (self.tuning.deadDuration * 0.6))
    else
        fr = set:frameAt('idle', love.timer.getTime() + (self.home and self.home.x or 0) * 0.013)
    end
    love.graphics.setColor(1, 1, 1, a)
    local r = (st == 'dead_fling') and t * 10 * f or 0
    set:drawFrame(fr, x + ox * S, feet, r, S * f, S, 0.5, 1)
    love.graphics.setColor(1, 1, 1, 1)
    if st == 'sleep' then
        BossFx = BossFx or require 'src/fx/BossFx'
        BossFx.sleepZ(t, x + 4 * S, feet - 13 * S, 3)
    end
end

-- F1: la caja que la dispara (blanca) y lo que muerde al cerrarse (roja, solo cerrándose: getHazardBoxes)
function Plant:debugBoxes()
    local b = self:triggerBox()
    b.kind = 'area'
    return { b }
end

function Plant.drawEditorOverlay(props, cx, cy, zoom)
    local f = cy + TILE_PX / 2
    love.graphics.setColor(0.9, 0.3, 0.5, 0.8)
    love.graphics.setLineWidth(2 / zoom)
    love.graphics.rectangle('line', cx - TRIGGER_HW, f - TRIGGER_H * TILE_PX, TRIGGER_HW * 2, TRIGGER_H * TILE_PX)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawIcon(x, y, s)
    local c = require('src/fx/Anim').clip('enemies/carnivoreplant', 'idle')
    c:drawPx(1, x, y + (s - s * c.h / c.w), 0, s / c.w, s / c.w)
end

local G = 'Planta carnívora'
return {
    name = 'carnivoreplant', label = 'Planta carnívora', category = 'Enemigos', class = Plant,
    description = 'De la jungla. Fija en el suelo, abierta. Si pasas por ENCIMA o justo al lado, tiembla y se CIERRA de '
               .. 'golpe: si te pilla, 1 de vida (hay que saltarla). Luego mastica un rato: SOLO cerrada se la puede pisar. '
               .. 'Si le lanzas un Escarabajo Rinoceronte (o pasa uno por ella), se lo come y se DUERME un rato: inofensiva, '
               .. 'se la pisa.',
    defaults = { movement = 'static', speed = 0, points = 20, onTouch = 'none', pauses = false },
    hide = { 'movement', 'attach', 'speed', 'startDir', 'patrol', 'turnAtEdges', 'flyMode', 'flyRange', 'bobAmp', 'pauses',
             'dropOnSight', 'detectRange', 'onTouch', 'stompable' },
    props = {
        { key = 'chewTime', kind = 'number', label = 'Cerrada masticando (s)', group = G, default = CHEW_T, min = 0.5, max = 10,
          step = 0.1, help = 'Tras cerrarse sobre un jugador: el rato en que se la puede pisar' },
        { key = 'sleepTime', kind = 'number', label = 'Dormida tras comer (s)', group = G, default = SLEEP_T, min = 1, max = 30,
          step = 0.5, help = 'Tras comerse un escarabajo: inofensiva y se la puede pisar' },
    },
    editor = { draw = drawIcon },
}
