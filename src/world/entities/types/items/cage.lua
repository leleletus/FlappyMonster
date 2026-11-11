-- FLAPPY ENJAULADO (solo niveles Flappy: docs/design/flappy-plan-4-attack-and-cages.md): uno de la raza al que el Evil
-- Monster probó sus máquinas y dejó encerrado. Se libera con el ATAQUE ESPECIAL con al menos `minCharge` de potencia (si
-- no llega, la jaula aguanta y para la ráfaga). Libre, sale volando a casa (por magia: sin alas).
-- Estados: 'closed' · 'open' (liberado AHORA: `rescuedNow`, que AdventureState junta al TERMINAR la etapa en
-- `result.rescued`; FlappyRun lo guarda — golden rule 7 —) · 'empty' (`freed`: liberado en una partida ya terminada).
-- Cada uno REGALA un power-up (`gift`, docs/design/powerups.md) al terminar la etapa: src/flappy/FlappyRun.lua.
-- Arte (0.5.196, más grande y con un flappy distinto en cada jaula): assets/images/items/cage/ (tools/art/items/
-- make_cage.py): cage-Sheet (23x24: cerrada · abierta), flappies-Sheet (9x16: una fila por variante, brazos abajo ·
-- arriba; el cuerpo del monstruo con otros colores y detalles), lamp (las luces de la carga que pide, en la base).
-- QUÉ FLAPPY: Cage.variantAt(col, row) — sale de la casilla, así es el mismo en cada partida y en cada cliente sin
-- enviar nada —, o la prop `look` (1..N) si se fija en el editor.
-- AVISO: con el jugador de este aparato cerca de una jaula cerrada, un bocadillo (src/ui/HintBubble.lua, el de los
-- carteles de ayuda) dice que se libera con el ataque especial (o cuánta carga falta), con el botón del aparato; con el
-- dedo, el botón de la pantalla brilla. Solo dibujo (renderOverlay): cada cliente lo dibuja para su jugador.
local Entity = require 'src/world/entities/base/Entity'
local Bubble = require 'src/ui/HintBubble'

local Cage = Entity.extend(Entity, { debugColor = { 1, 0.5, 0.75 },
    -- (la caja cubre la jaula y contiene la de antes — 46x51 centrada —: la ráfaga que le daba le sigue dando)
    hitbox = { outerW = 0.9, outerH = 0.95, innerW = 0.6, innerH = 0.7 } })
local SCALE = 4
local FW, FH = 23, 24                   -- el cuadro de la jaula (arte)
local OX, OY = 46, 36                   -- px: la casilla cae en el centro de la jaula (col 11) y en su fila 9
local FLX, FLY = 7, 4                   -- dónde va el flappy (9x16) dentro del cuadro
local BOX_W, BOX_H, BOX_DY = 68, 84, 8  -- px: la jaula de verdad (col 3..19, filas 3..23); su centro, 8 px más abajo
local FLY_T = 1.6                       -- s que tarda el liberado en irse volando
local NEAR_AHEAD, NEAR_BEHIND, NEAR_DY = 7, 1.5, 4.5   -- casillas: dónde sale el aviso (delante del jugador)
local img, quads, flImg, flQuads, lampImg
function Cage.loadAssets()
    if img then return end
    local function load(p)
        local im = love.graphics.newImage(p); im:setFilter('nearest', 'nearest'); return im
    end
    img = load('assets/images/items/cage/cage-Sheet.png')
    quads = {}
    for i = 1, 2 do quads[i] = love.graphics.newQuad((i - 1) * FW, 0, FW, FH, img:getDimensions()) end
    flImg = load('assets/images/items/cage/flappies-Sheet.png')
    flQuads = {}
    for v = 1, math.floor(flImg:getHeight() / 16) do
        flQuads[v] = {}
        for p = 1, 2 do flQuads[v][p] = love.graphics.newQuad((p - 1) * 9, (v - 1) * 16, 9, 16, flImg:getDimensions()) end
    end
    lampImg = load('assets/images/items/cage/lamp.png')
end
function Cage.sizePx() return BOX_W, BOX_H end

-- El flappy de una jaula: un número 1..N (N = filas de flappies-Sheet). Con el nivel (`levelRef`, que BossZones.link da
-- en un jugador, en el servidor y en el editor): por su ORDEN entre las jaulas del nivel, empezando en un punto que sale
-- de dónde están todas — así las de una etapa nunca se repiten (hasta N jaulas) y cada etapa empieza en otro —. Sin el
-- nivel: una mezcla de su columna y su fila. Solo cambia el dibujo: no se guarda ni viaja (los dos lados tienen el nivel).
function Cage.variantAt(col, row, n)
    return ((col * 5 + row * 11) % 97) % n + 1
end
function Cage.variantIn(level, col, row, n)
    local rank, seed = nil, 0
    local k = 0
    for _, p in ipairs(level and level.entities or {}) do
        if p.type == 'cage' then
            k = k + 1
            seed = seed + p.col * 5 + p.row * 11
            if not rank and p.col == col and p.row == row then rank = k end
        end
    end
    if not rank then return Cage.variantAt(col, row, n) end
    return (rank - 1 + seed % 97) % n + 1
end
Cage.wantsLevel = true

function Cage:init()
    self.moving, self.flying = false, true
    self.vx, self.vy = 0, 0
    self.state = 'closed'
    self.flyT = 0
end

function Cage:look()
    if self._look and self._lookLevel == self.levelRef then return self._look end
    local n = #flQuads
    local v = tonumber(self.props.look) or 0
    if v >= 1 then
        self._look = math.min(n, math.floor(v))
    else
        self._look = Cage.variantIn(self.levelRef, self.col or 1, self.row or 1, n)
    end
    self._lookLevel = self.levelRef
    return self._look
end

-- (la caja va 8 px más abajo que la casilla: es donde está la jaula dibujada)
function Cage:getOuterBounds(into)
    return Entity.box(into, self.x - self.outerW / 2, self.y + BOX_DY - self.outerH / 2, self.outerW, self.outerH)
end
function Cage:getInnerBounds(into)
    return Entity.box(into, self.x - self.innerW / 2, self.y + BOX_DY - self.innerH / 2, self.innerW, self.innerH)
end

function Cage:updateCustom(dt)
    if self.freed and self.state == 'closed' then self.state = 'empty' end
    if self.state == 'open' then self.flyT = self.flyT + dt end
    return true
end
function Cage:canBeStomped() return false end
function Cage:isGhost() return true end            -- (no se toca: ni daña ni se recoge)

function Cage:onSpecialHit(power)
    if self.state ~= 'closed' then return false end
    if power >= (self.props.minCharge or 1) then
        self.state, self.rescuedNow, self.flyT = 'open', true, 0
        Sound.play('oneUp')
        Entity.emitFx('collect', self.x, self.y)
    else
        Sound.play('headBump')
    end
    return true
end

function Cage:render(camX, camY)
    local x, y = math.floor(self.x - camX + 0.5) - OX, math.floor(self.y - camY + 0.5) - OY   -- (esquina del cuadro)
    local v = flQuads[self:look()]
    local t = love.timer.getTime()
    love.graphics.setColor(1, 1, 1, 1)
    if self.state == 'closed' then
        -- dentro, triste; con el jugador cerca (lo apunta renderOverlay), pide ayuda agitando los brazos
        local pose = (self._near and math.floor(t * 4) % 2 == 0) and 2 or 1
        love.graphics.draw(flImg, v[pose], x + FLX * SCALE, y + FLY * SCALE, 0, SCALE, SCALE)
    end
    love.graphics.draw(img, quads[self.state == 'closed' and 1 or 2], x, y, 0, SCALE, SCALE)
    if self.state == 'open' and self.flyT < FLY_T then
        -- libre: sale volando hacia arriba (por magia: sin alas), aleteando con los brazos
        local k = self.flyT / FLY_T
        local fx = x + FLX * SCALE + math.floor(k * 60)
        local fy = y + FLY * SCALE - math.floor(k * 260 - math.sin(self.flyT * 14) * 6)
        love.graphics.setColor(1, 1, 1, 1 - k * k)
        love.graphics.draw(flImg, v[math.floor(self.flyT * 10) % 2 + 1], fx, fy, 0, SCALE, SCALE)
        love.graphics.setColor(1, 1, 1, 1)
    end
    -- la carga que pide: luces en la base (filas 21-22 del cuadro), centradas
    if self.state == 'closed' then
        local n = self.props.minCharge or 1
        local c0 = math.floor(11.5 - (3 * n - 1) / 2 + 0.5)
        for i = 1, n do
            love.graphics.draw(lampImg, x + (c0 + (i - 1) * 3) * SCALE, y + 21 * SCALE, 0, SCALE, SCALE)
        end
    end
end

-- El AVISO (por encima de todo): solo con la jaula cerrada y el jugador de este aparato acercándose (la jaula delante,
-- a NEAR_AHEAD casillas como mucho: la ráfaga llega a 8)
function Cage:renderOverlay(camX, camY, viewer, dt)
    local near = false
    if self.state == 'closed' and viewer and not viewer.dying then
        local dx, dy = self.x - viewer.x, math.abs(self.y - viewer.y)
        near = dx < NEAR_AHEAD * TILE_PX and dx > -NEAR_BEHIND * TILE_PX and dy < NEAR_DY * TILE_PX
    end
    self._near = near
    self.show = Bubble.fade(self.show, near, dt)
    if (self.show or 0) <= 0 then return end
    local need = self.props.minCharge or 1
    local short = (viewer and viewer.charge or 0) < need
    local top = math.floor(self.y - camY + 0.5) - OY + 1 * SCALE
    Bubble.draw(self, short and 'flappy.cage_need' or 'flappy.cage_hint', { n = need }, short and need or 0,
        self.x - camX, top, top + 23 * SCALE, self.show, near)
end

return {
    name = 'cage', label = 'Flappy enjaulado', category = 'Flappy', flappyOnly = true,
    description = 'Solo niveles Flappy: se libera con el ataque especial (carga mínima). Se guarda al terminar la etapa.',
    class = Cage,
    defaults = { movement = 'static' }, hide = 'all',
    props = {
        { key = 'minCharge', kind = 'int', label = 'Carga mínima', group = 'Jaula', default = 1, min = 1, max = 5, step = 1,
          help = 'Potencia del ataque especial que hace falta para abrirla (1..5)' },
        { key = 'gift', kind = 'enum', label = 'Regala', group = 'Jaula', default = 'shield', options = (function()
              local o = {}
              for _, p in ipairs(require('src/world/powerups/Powerups').forMode('flappy')) do
                  o[#o + 1] = { value = p.id, label = p.id }
              end
              return o
          end)(), help = 'El power-up que da al liberarlo (al terminar la etapa, una vez por partida)' },
        { key = 'look', kind = 'int', label = 'Flappy', group = 'Jaula', default = 0, min = 0, max = 8, step = 1,
          help = 'Qué flappy va dentro: 0 = según su casilla (cada jaula uno distinto), 1..8 = ese' },
    },
    editor = { draw = function(x, y, s)                    -- (la jaula cerrada con su flappy, en la casilla)
        Cage.loadAssets()
        local k = s / FH
        local ox = x + (s - FW * k) / 2
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(flImg, flQuads[1][1], ox + FLX * k, y + FLY * k, 0, k, k)
        love.graphics.draw(img, quads[1], ox, y, 0, k, k)
    end },
}
