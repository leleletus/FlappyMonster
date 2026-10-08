-- src/world/level/LevelWater.lua
-- PARTE de src/world/level/Level.lua: burbujas, respiraderos (vents) y su oxígeno, y la detección de los cuerpos de agua.
-- La carga Level.lua con require(...)(Level, P): añade sus funciones a la tabla Level. P = lo que
-- antes eran locales del archivo y comparten las partes.

return function(Level, P)
local liquidOfRaw, spikeHitbox = P.liquidOfRaw, P.spikeHitbox

-- ── Burbujas ──────────────────────────────────────────────────────────────────
local bubbleImgs = nil

local BUBBLE_DEFS = {
    { path='assets/images/world/bubbles/bubble1.png', w=16, h=16 },
    { path='assets/images/world/bubbles/bubble2.png', w=6,  h=5  },
    { path='assets/images/world/bubbles/bubble3.png', w=3,  h=3  },
    { path='assets/images/world/bubbles/bubble4.png', w=16, h=16 },
}

local function loadBubbleImgs()
    if bubbleImgs then return end
    bubbleImgs = {}
    for _, def in ipairs(BUBBLE_DEFS) do
        local ok, img = pcall(require('src/fx/Anim').image, def.path)
        if ok then
            table.insert(bubbleImgs, { img=img, w=def.w, h=def.h })
        end
    end
end

local BUB_SPEED_MIN = 18
local BUB_SPEED_MAX = 42
local BUB_ZIG_AMP   = 6
local BUB_ZIG_FREQ  = 1.8
local BUB_SPAWN_MIN = 0.6
local BUB_SPAWN_MAX = 2.8
local BUB_SCALE     = 2
local BUB_ALPHA     = 0.72

-- ── EPICAS ENTRADAS OXIGENARIAS MARITIMAS DEL MAR ARTICO (Vents) ─────────────
local ventImg    = nil   -- crack.png 6x6
local VENT_SCALE = 2     -- 6×2 = 12px visual

local function loadVentImg()
    if ventImg then return end
    local ok, img = pcall(require('src/fx/Anim').image, 'assets/images/world/crack.png')
    if ok then ventImg = img end
end

-- Partículas normales: bubble2 y bubble3 (rápidas, seguidas)
local VENT_NORM_SPEED_MIN = 28
local VENT_NORM_SPEED_MAX = 55
local VENT_NORM_SPAWN_MIN = 0.08
local VENT_NORM_SPAWN_MAX = 0.35
local VENT_NORM_ZIG_AMP   = 4
local VENT_NORM_ZIG_FREQ  = 2.8
local VENT_NORM_ALPHA     = 0.80

-- Burbuja de oxígeno coleccionable: bubble1 (ocasional, más grande)
local VENT_OXY_DELAY_MIN  = 8.0    -- mínimo de segundos entre burbujas oxy
local VENT_OXY_DELAY_MAX  = 26.0   -- máximo de segundos entre burbujas oxy
local VENT_OXY_SPEED_MIN  = 20
local VENT_OXY_SPEED_MAX  = 30
local VENT_OXY_ZIG_AMP    = 3
local VENT_OXY_ZIG_FREQ   = 1.2
local VENT_OXY_SCALE      = 7      -- bubble1 grande y visible
local VENT_OXY_ALPHA      = 0.95
-- Colisión de la burbuja de oxígeno = el círculo que SE VE. bubble1.png es
-- 16x16 pero la burbuja ocupa las columnas 4..10 y filas 3..9 (7x7 px); se
-- dibuja centrada en (b.x, b.y) a escala VENT_OXY_SCALE, así que el círculo
-- visible está desplazado respecto a (b.x, b.y). Se compara contra la caja
-- ENTERA del jugador (antes: 14 px contra el centro de su caja, y centrado
-- 10 px más abajo que el dibujo → se atravesaba sin coger aire).
local OXY_VIS_DX  = ((4 + 11) / 2 - 8) * VENT_OXY_SCALE     -- -3.5 px
local OXY_VIS_DY  = ((3 + 10) / 2 - 8) * VENT_OXY_SCALE     -- -10.5 px
local OXY_VIS_R   = 7 / 2 * VENT_OXY_SCALE                  -- 24.5 px
local OXY_HIT_PAD = 6      -- margen extra (online se ven ~0,1 s en el pasado)
local VENT_OXY_HIT_R = OXY_VIS_R + OXY_HIT_PAD

-- ── Flood-fill: detecta cuerpos de agua de >=9 tiles ─────────────────────────
local function findWaterBodies(level)
    local visited = {}
    local bodies  = {}

    local function isWaterTile(col, row)
        if row < 1 or row > level.tileH or col < 1 or col > level.tileW then
            return false
        end
        local m = liquidOfRaw(level:getRaw(col, row))
        return m ~= nil and m.bubbles
    end

    for startRow = 1, level.tileH do
        for startCol = 1, level.tileW do
            local key = startRow * 10000 + startCol
            if isWaterTile(startCol, startRow) and not visited[key] then
                local tiles   = {}
                local queue   = { {startCol, startRow} }
                local minRow, maxRow = startRow, startRow
                visited[key] = true
                local head = 1
                while head <= #queue do
                    local c, r = queue[head][1], queue[head][2]
                    head = head + 1
                    table.insert(tiles, {c, r})
                    if r < minRow then minRow = r end
                    if r > maxRow then maxRow = r end
                    for _, nb in ipairs({{c+1,r},{c-1,r},{c,r+1},{c,r-1}}) do
                        local nc, nr = nb[1], nb[2]
                        local nk = nr * 10000 + nc
                        if isWaterTile(nc, nr) and not visited[nk] then
                            visited[nk] = true
                            table.insert(queue, {nc, nr})
                        end
                    end
                end

                if #tiles >= 9 then
                    -- Fila más baja por columna → puntos de spawn en el fondo
                    local bottomByCol = {}
                    for _, t in ipairs(tiles) do
                        local tc, tr = t[1], t[2]
                        if not bottomByCol[tc] or tr > bottomByCol[tc] then
                            bottomByCol[tc] = tr
                        end
                    end
                    local spawnPoints = {}
                    for col, row in pairs(bottomByCol) do
                        table.insert(spawnPoints, {
                            x = (col - 0.5) * TILE_PX,
                            y = row * TILE_PX,
                        })
                    end
                    table.insert(bodies, {
                        ceilingY    = (minRow - 1) * TILE_PX,
                        spawnPoints = spawnPoints,
                        spawnTimer  = math.random() * BUB_SPAWN_MAX,
                        spawnDelay  = BUB_SPAWN_MIN + math.random() * (BUB_SPAWN_MAX - BUB_SPAWN_MIN),
                    })
                end
            end
        end
    end
    return bodies
end

-- ── Helpers de vent ──────────────────────────────────────────────────────────
local function spawnVentParticle(vent, isOxy)
    if not bubbleImgs or #bubbleImgs == 0 then return end
    if isOxy then
        -- bubble1 = índice 1
        local def = bubbleImgs[1]
        if not def then return end
        table.insert(vent.oxyBubbles, {
            x        = vent.x + (math.random()-0.5)*4,
            y        = vent.y,
            speed    = VENT_OXY_SPEED_MIN + math.random()*(VENT_OXY_SPEED_MAX-VENT_OXY_SPEED_MIN),
            zigPhase = math.random()*math.pi*2,
            zigFreq  = VENT_OXY_ZIG_FREQ*(0.8+math.random()*0.4),
            img      = def.img,
            iw       = def.w,
            ih       = def.h,
            alive    = true,
        })
    else
        -- bubble2 o bubble3 aleatorio (índices 2 y 3)
        local idx = math.random(2,3)
        local def = bubbleImgs[idx]
        if not def then return end
        table.insert(vent.particles, {
            x        = vent.x + (math.random()-0.5)*5,
            y        = vent.y,
            speed    = VENT_NORM_SPEED_MIN + math.random()*(VENT_NORM_SPEED_MAX-VENT_NORM_SPEED_MIN),
            zigPhase = math.random()*math.pi*2,
            zigFreq  = VENT_NORM_ZIG_FREQ*(0.7+math.random()*0.6),
            img      = def.img,
            iw       = def.w,
            ih       = def.h,
        })
    end
end

-- Burbuja decorativa suelta (p. ej. en una inundación): sube hasta salir del agua
function Level:spawnBubble(x, y)
    if not bubbleImgs or #bubbleImgs == 0 then return end
    local def = bubbleImgs[math.random(#bubbleImgs)]
    table.insert(self.bubbles, {
        x = x, y = y,
        speed    = BUB_SPEED_MIN + math.random() * (BUB_SPEED_MAX - BUB_SPEED_MIN),
        zigPhase = math.random() * math.pi * 2,
        zigFreq  = BUB_ZIG_FREQ * (0.7 + math.random() * 0.6),
        ceilingY = -math.huge,
        img = def.img, iw = def.w, ih = def.h,
        alpha    = BUB_ALPHA * (0.7 + math.random() * 0.3),
    })
end

-- ── Update: burbujas ──────────────────────────────────────────────────────────
function Level:update(dt)
    local hasBubbles = bubbleImgs and #bubbleImgs > 0
    -- Bloques ON/OFF que esperaban a que nadie estuviera dentro (solo quien
    -- decide los tiles: un jugador y el servidor)
    if self.switchBlocks and self.canBreak ~= false then
        for _, b in ipairs(self.switchBlocks) do
            if b.pending then self:updateSwitchBlocks(); break end
        end
    end
    -- Hielo fino que se desgasta con alguien encima
    self:updateThinIce(dt)
    -- Bloques golpeados (saltito / aplastarse)
    for k, a in pairs(self.tileAnim or {}) do
        a.t = a.t + dt
        if a.t >= a.dur then self.tileAnim[k] = nil end
    end

    -- Spawn desde cada cuerpo de agua (solo si hay sprites de burbuja)
    if hasBubbles then
    for _, body in ipairs(self.waterBodies) do
        body.spawnTimer = body.spawnTimer + dt
        if body.spawnTimer >= body.spawnDelay then
            body.spawnTimer = body.spawnTimer - body.spawnDelay
            body.spawnDelay = BUB_SPAWN_MIN + math.random() * (BUB_SPAWN_MAX - BUB_SPAWN_MIN)

            local sp  = body.spawnPoints[math.random(#body.spawnPoints)]
            local def = bubbleImgs[math.random(#bubbleImgs)]

            table.insert(self.bubbles, {
                x        = sp.x + (math.random() - 0.5) * TILE_PX * 0.6,
                y        = sp.y - 4,          -- dentro del agua (sp.y es el fondo)
                speed    = BUB_SPEED_MIN + math.random() * (BUB_SPEED_MAX - BUB_SPEED_MIN),
                zigPhase = math.random() * math.pi * 2,
                zigFreq  = BUB_ZIG_FREQ * (0.7 + math.random() * 0.6),
                ceilingY = body.ceilingY,
                img      = def.img,
                iw       = def.w,
                ih       = def.h,
                alpha    = BUB_ALPHA * (0.7 + math.random() * 0.3),
            })
        end
    end
    end  -- hasBubbles

    -- Actualizar y limpiar burbujas
    local t = love.timer.getTime()
    for i = #self.bubbles, 1, -1 do
        local b = self.bubbles[i]
        b.y = b.y - b.speed * dt
        b.x = b.x + math.sin(t * b.zigFreq + b.zigPhase) * BUB_ZIG_AMP * dt
        -- Fuera del agua (superficie, aunque sea irregular) → desaparece
        if b.y < b.ceilingY or not self:liquidAt(b.x, b.y) then
            table.remove(self.bubbles, i)
        end
    end

    -- ── Actualizar vents (siempre, independientemente de los sprites de burbuja) ──
    for _, vent in ipairs(self.vents) do
        -- Spawn de partículas normales (timer propio)
        vent.spawnTimer = vent.spawnTimer + dt
        if vent.spawnTimer >= vent.spawnDelay and hasBubbles then
            vent.spawnTimer = vent.spawnTimer - vent.spawnDelay
            vent.spawnDelay = VENT_NORM_SPAWN_MIN + math.random()*(VENT_NORM_SPAWN_MAX-VENT_NORM_SPAWN_MIN)
            spawnVentParticle(vent, false)
        end

        -- Spawn de burbuja oxy — solo si no está controlado por el servidor
        if not self.disableOxySpawn then
            vent.oxyTimer = vent.oxyTimer + dt
            if vent.oxyTimer >= vent.oxyDelay and hasBubbles then
                vent.oxyTimer = 0
                vent.oxyDelay = (VENT_OXY_DELAY_MIN + math.random()*(VENT_OXY_DELAY_MAX-VENT_OXY_DELAY_MIN)) * require('src/core/Difficulty').of(self.difficulty, 'ventDelay', 1)
                spawnVentParticle(vent, true)
            end
        end

        -- Mover partículas normales
        for i = #vent.particles, 1, -1 do
            local b = vent.particles[i]
            b.y = b.y - b.speed * dt
            b.x = b.x + math.sin(t * b.zigFreq + b.zigPhase) * VENT_NORM_ZIG_AMP * dt
            if b.y < vent.ceilingY then
                table.remove(vent.particles, i)
            end
        end

        -- Mover burbujas de oxígeno (solo en modo local; en online las gestiona el servidor)
        if not self.disableOxySpawn then
            for i = #vent.oxyBubbles, 1, -1 do
                local b = vent.oxyBubbles[i]
                if not b.alive then
                    table.remove(vent.oxyBubbles, i)
                else
                    b.y = b.y - b.speed * dt
                    b.x = b.x + math.sin(t * b.zigFreq + b.zigPhase) * VENT_OXY_ZIG_AMP * dt
                    if b.y < vent.ceilingY then
                        table.remove(vent.oxyBubbles, i)
                    end
                end
            end
        end
    end
end

-- ── Render: burbujas (llamar DESPUÉS de renderWaterEffect) ───────────────────
function Level:renderBubbles(camX, camY)
    if not bubbleImgs or #bubbleImgs == 0 then return end
    for _, b in ipairs(self.bubbles) do
        local sx = math.floor(b.x - camX - (b.iw * BUB_SCALE) / 2)
        local sy = math.floor(b.y - camY - (b.ih * BUB_SCALE) / 2)
        -- Solo dibujar si está en pantalla
        if sx + b.iw * BUB_SCALE > 0 and sx < WINDOW_W and
           sy + b.ih * BUB_SCALE > 0 and sy < WINDOW_H then
            love.graphics.setColor(1, 1, 1, b.alpha)
            love.graphics.draw(b.img, sx, sy, 0, BUB_SCALE, BUB_SCALE)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ── Render: vents (llamar DENTRO del canvas, antes del shader) ───────────────
function Level:renderVents(camX, camY)
    if #self.vents == 0 then return end
    local t = love.timer.getTime()

    for _, vent in ipairs(self.vents) do
        local vsx = math.floor(vent.x - camX)
        local vsy = math.floor(vent.y - camY)

        -- Sprite crak.png (solo si cargó)
        if ventImg then
            local pulse = 0.85 + math.sin(t * 3.5 + vent.x * 0.01) * 0.15
            love.graphics.setColor(1, 1, 1, pulse)
            love.graphics.draw(ventImg, vsx, vsy, 0, VENT_SCALE, VENT_SCALE,
                ventImg:getWidth()/2, ventImg:getHeight()/2)
        end

        -- Partículas normales
        love.graphics.setColor(1, 1, 1, VENT_NORM_ALPHA)
        for _, b in ipairs(vent.particles) do
            local bsx = math.floor(b.x - camX - b.iw)
            local bsy = math.floor(b.y - camY - b.ih)
            love.graphics.draw(b.img, bsx, bsy, 0, BUB_SCALE, BUB_SCALE)
        end

        -- Burbujas de oxígeno (más brillantes)
        for _, b in ipairs(vent.oxyBubbles) do
            if b.alive then
                local bsx = math.floor(b.x - camX - (b.iw * VENT_OXY_SCALE)/2)
                local bsy = math.floor(b.y - camY - (b.ih * VENT_OXY_SCALE)/2)
                -- Brillo pulsante para destacar
                local op = 0.75 + math.sin(t * 5 + b.x) * 0.25
                love.graphics.setColor(0.7, 1, 1, op)
                love.graphics.draw(b.img, bsx, bsy, 0, VENT_OXY_SCALE, VENT_OXY_SCALE)
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- ── Colisión jugador ↔ burbujas de oxígeno ────────────────────────────────────
-- Devuelve true si el jugador tocó una burbuja de oxígeno (y la consume).
-- Llama a callback(ventIdx, bubIdx) si hay colisión.
function Level:checkVentOxyCollision(px, py, pw, ph)
    local r2 = VENT_OXY_HIT_R * VENT_OXY_HIT_R
    for _, vent in ipairs(self.vents) do
        for _, b in ipairs(vent.oxyBubbles) do
            if b.alive then
                -- Punto de la caja del jugador más cercano al centro visible
                local cx, cy = b.x + OXY_VIS_DX, b.y + OXY_VIS_DY
                local nx = math.max(px, math.min(px + pw, cx))
                local ny = math.max(py, math.min(py + ph, cy))
                local dx, dy = cx - nx, cy - ny
                if dx*dx + dy*dy < r2 then
                    b.alive = false
                    return true
                end
            end
        end
    end
    return false
end

-- Círculo de colisión de una burbuja de oxígeno (depuración F1)
function Level.oxyBubbleCircle(b) return b.x + OXY_VIS_DX, b.y + OXY_VIS_DY, VENT_OXY_HIT_R end

-- Reemplaza las burbujas de oxígeno con los datos del servidor (modo online).
function Level:syncOxyBubbles(serverVentBubbles)
    if not serverVentBubbles then return end
    if not bubbleImgs or not bubbleImgs[1] then return end
    local def = bubbleImgs[1]
    for vi, serverBubs in ipairs(serverVentBubbles) do
        local vent = self.vents[vi]
        if vent then
            vent.oxyBubbles = {}
            for _, sb in ipairs(serverBubs) do
                table.insert(vent.oxyBubbles, {
                    x=sb.x, y=sb.y, alive=true,
                    img=def.img, iw=def.w, ih=def.h,
                })
            end
        end
    end
end

-- Exporta spikeHitbox para que AdventureState la reutilice en el debug,
-- garantizando que debug y física usen exactamente la misma función.
Level._spikeHitbox = spikeHitbox

P.loadBubbleImgs = loadBubbleImgs; P.loadVentImg = loadVentImg; P.VENT_NORM_SPAWN_MIN = VENT_NORM_SPAWN_MIN; P.VENT_NORM_SPAWN_MAX = VENT_NORM_SPAWN_MAX; P.VENT_OXY_DELAY_MIN = VENT_OXY_DELAY_MIN
P.VENT_OXY_DELAY_MAX = VENT_OXY_DELAY_MAX; P.findWaterBodies = findWaterBodies
end
