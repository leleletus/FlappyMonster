-- src/states/adventure/WinCelebration.lua
-- LA LLEGADA A LA META en un jugador (el usuario, 2026-11-17): al ganar (AdventureState:win)
--   · los ENEMIGOS a la vista revientan uno tras otro, del más cercano al más lejano, y dan sus puntos con la regla de
--     la racha de pisotones (StompChain.step: ×1, ×2, ×4… y, pasado el último multiplicador, una VIDA cada uno), con la
--     escalerita de tonos. Los jefes no. Lo ganado se guarda al terminar el nivel, como todo (regla de oro 7).
--   · la BANDERA (las casillas de meta unidas a la que tocó, o la salida secreta) da un saltito con un destello, se
--     estrecha como una moneda que gira y desaparece en destellos dorados. Sus casillas se quitan del nivel al tocarla
--     (ya da igual: el nivel está ganado) y se dibujan aquí.
-- Solo un jugador: online la meta es de la Carrera (src/world/modes/race.lua) y los enemigos son de todos.
--   local wc = WinCelebration.new(st, trigger)   (st = el AdventureState; trigger = 'finish' | 'secret_exit' | nil)
--   wc:update(dt) · wc:draw(camX, camY)
local StompChain = require 'src/world/systems/StompChain'
local TileTypes  = require 'src/world/tiles/TileTypes'
local Tiles      = require 'src/world/tiles/Tiles'
local Particles  = require 'src/fx/Particles'
local L          = require 'src/core/Lang'

local WC = {}
WC.__index = WC

WC.FIRST   = 0.12        -- s hasta el primer reventón (que se vea el toque)
WC.GAP     = 0.09        -- s entre reventones…
WC.SPAN    = 1.0         -- …sin pasar de esto en total (con muchos, más seguidos)
WC.MARGIN  = 1           -- casillas de más alrededor de la pantalla que cuentan como "a la vista"
WC.HOP_T, WC.SPIN_T = 0.35, 0.4                         -- la bandera: saltito y giro hasta desaparecer
WC.HOP_PX = 18

-- ¿Revienta con la meta? Un enemigo vivo y entero (no los jefes, ni lo que está muriendo o esperando)
local function poppable(e)
    return e.alive and e.def and e.def.category == 'Enemigos' and not e.def.boss and e.state ~= 'dead'
        and not (e.isGhost and e:isGhost()) and e.dieBurst ~= nil
end

local function enemiesInView(st)
    local M = WC.MARGIN * TILE_PX
    local x0, y0 = st.camX - M, st.camY - M
    local x1, y1 = st.camX + WINDOW_W + M, st.camY + WINDOW_H + M
    local px, py = st.player.x, st.player.y
    local list = {}
    for _, e in ipairs(st.level.liveEntities or {}) do
        if poppable(e) and e.x >= x0 and e.x <= x1 and e.y >= y0 and e.y <= y1 then
            list[#list + 1] = { e = e, d = (e.x - px) ^ 2 + (e.y - py) ^ 2 }
        end
    end
    table.sort(list, function(a, b) return a.d < b.d end)
    local gap = math.min(WC.GAP, WC.SPAN / math.max(1, #list))
    for i, q in ipairs(list) do q.at = WC.FIRST + (i - 1) * gap end
    return list
end

-- Las casillas con `trigger` unidas (8 vecinas) a las que toca la caja del jugador
local function flagCells(level, box, trigger)
    if not trigger then return {} end
    local T = TILE_PX
    local seen, out, stack = {}, {}, {}
    local c0, c1 = math.floor(box.x / T) + 1, math.floor((box.x + box.w) / T) + 1
    local r0, r1 = math.floor(box.y / T) + 1, math.floor((box.y + box.h) / T) + 1
    for r = r0 - 1, r1 + 1 do for c = c0 - 1, c1 + 1 do stack[#stack + 1] = { c, r } end end
    while #stack > 0 do
        local c, r = unpack(table.remove(stack))
        local k = r * 65536 + c
        if not seen[k] and c >= 1 and r >= 1 and c <= level.tileW and r <= level.tileH then
            seen[k] = true
            local def = level:getDef(c, r)
            if def.trigger == trigger then
                out[#out + 1] = { c = c, r = r, def = def, raw = level:getRaw(c, r) }
                for dr = -1, 1 do for dc = -1, 1 do stack[#stack + 1] = { c + dc, r + dr } end end
            end
        end
        if #out > 64 then break end                          -- (una meta enorme: con esto basta)
    end
    return out
end

function WC.new(st, trigger)
    local self = setmetatable({ st = st, t = 0, chain = 0, popped = 0 }, WC)
    self.queue = enemiesInView(st)
    self.flag = flagCells(st.level, st.player:getOuterBounds(), trigger)
    -- (fuera del nivel: las dibuja esta celebración; si la celda tenía agua, se queda el agua)
    local codec = Tiles.codec
    for _, f in ipairs(self.flag) do
        st.level:setTileRaw(f.c, f.r, codec.isWaterlogged(f.raw) and TILE_WATER or 0)
    end
    if #self.flag > 0 then
        local sx, sy = 0, 0
        for _, f in ipairs(self.flag) do sx, sy = sx + f.c, sy + f.r end
        self.fcx, self.fcy = (sx / #self.flag - 0.5) * TILE_PX, (sy / #self.flag - 0.5) * TILE_PX
    end
    return self
end

function WC:_pop(e)
    local st = self.st
    local pts = (e.props and e.props.points) or 0
    e:dieBurst()                                             -- (la muerte la cuenta Entity.onKill: stats.kills)
    if pts <= 0 then return end
    self.chain = self.chain + 1
    local got, mult, up = StompChain.step(self.chain, pts)
    local y = e.y - (e.outerH or TILE_PX) / 2
    Sound.play('point', StompChain.pitchOf(self.chain))
    if up then
        st.player.lives = math.min(99, st.player.lives + 1)
        st:spawnPopup(L('hud.plus_life'), e.x, y)
        Sound.play('oneUp'); Particles.emit('oneup', e.x, y)
    else
        st.score = st.score + got
        st:spawnPopup(((mult or 1) > 1 and ('x' .. mult .. ' ') or '') .. '+' .. got .. '!', e.x, y)
        Particles.emit('points', e.x, y)
    end
end

function WC:update(dt)
    local before = self.t
    self.t = self.t + dt
    for _, q in ipairs(self.queue) do
        if not q.done and self.t >= q.at then
            q.done = true
            if poppable(q.e) then self:_pop(q.e) end
        end
    end
    -- (la bandera desaparece: destellos y un tintineo)
    local gone = WC.HOP_T + WC.SPIN_T
    if self.fcx and before < gone and self.t >= gone then
        for _, f in ipairs(self.flag) do Particles.emit('king_sparkle', (f.c - 0.5) * TILE_PX, (f.r - 0.5) * TILE_PX) end
        Sound.play('storyGlint')
    end
end

-- La bandera: saltito (con un destello blanco al principio) → se estrecha girando y sube → nada
local RENDER_CTX = {}
function WC:draw(camX, camY)
    if not self.fcx then return end
    local t = self.t
    if t >= WC.HOP_T + WC.SPIN_T then return end
    local T = TILE_PX
    local lift, wk = 0, 1
    if t < WC.HOP_T then
        lift = math.sin(t / WC.HOP_T * math.pi) * WC.HOP_PX
    else
        local k = (t - WC.HOP_T) / WC.SPIN_T
        lift = k * k * T * 0.6
        wk = math.abs(math.cos(k * math.pi * 1.5)) * (1 - k)        -- (gira una vez y media mientras se encoge)
    end
    -- (anchura en píxeles ENTEROS: pixel art)
    local w = math.max(0, math.floor(T * wk + 0.5))
    if w <= 0 then return end
    local ctx = RENDER_CTX
    ctx.size, ctx.level, ctx.time = T, self.st.level, love.timer.getTime() * 2.5   -- (ondea más deprisa: ¡llegó!)
    local cx = math.floor(self.fcx - camX + 0.5)
    for _, f in ipairs(self.flag) do
        local tx = (f.c - 1) * T - camX
        local ty = math.floor((f.r - 1) * T - camY - lift + 0.5)
        -- (estrecharse hacia el centro de la bandera: cada casilla se acerca a él)
        local nx = math.floor(cx + (tx - cx) * w / T + 0.5)
        love.graphics.push()
        love.graphics.translate(nx, ty)
        love.graphics.scale(w / T, 1)
        ctx.x, ctx.y, ctx.col, ctx.row, ctx.raw = 0, 0, f.c, f.r, f.raw
        TileTypes.drawTile(f.def, ctx)
        love.graphics.pop()
        if t < 0.12 then                                      -- (el destello del toque)
            love.graphics.setBlendMode('add')
            love.graphics.setColor(1, 1, 1, 0.7 * (1 - t / 0.12))
            love.graphics.rectangle('fill', nx, ty, w, T)
            love.graphics.setBlendMode('alpha')
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return WC
