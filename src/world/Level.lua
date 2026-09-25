-- src/world/Level.lua
-- Formato tile (número entero):
--   bits 0-3  : base id
--   bit  4    : waterlogged
--   bits 5-7  : dir(2b)+presente(1b) subceldas TL
--   bits 8-10 : dir(2b)+presente(1b) subcelda TR
--   bits 11-13: dir(2b)+presente(1b) subcelda BL
--   bits 14-16: dir(2b)+presente(1b) subcelda BR

local json  = require 'libs/json'
local Level = {}
Level.__index = Level

local FLAG_WATER  = 16
local SUB_SHIFTS  = {5, 8, 11, 14}

local DIR_UP    = 0
local DIR_DOWN  = 1
local DIR_LEFT  = 2
local DIR_RIGHT = 3

-- ── Decodificación ────────────────────────────────────────────────────────────
local function decTile(raw)
    raw = math.floor(raw or 0)
    local baseId      = raw % 16
    local waterlogged = (math.floor(raw / FLAG_WATER) % 2) == 1
    local spikes = {}
    for i = 1, 4 do
        local sh      = SUB_SHIFTS[i]
        local dir     = math.floor(raw / 2^sh) % 4
        local present = (math.floor(raw / 2^(sh+2)) % 2) == 1
        spikes[i] = {dir=dir, present=present}
    end
    return baseId, waterlogged, spikes
end

local function tileBaseId(raw)
    return math.floor(raw or 0) % 16
end

local function isWaterloggedRaw(raw)
    return (math.floor(raw / FLAG_WATER) % 2) == 1
end

local function hasSpikes(raw)
    local _, _, spikes = decTile(raw)
    for i = 1, 4 do if spikes[i].present then return true end end
    return false
end

-- ── Spike hitbox (función pública vía Level._spikeHitbox) ────────────────────
-- La hitbox cubre la BASE del pincho, es decir la zona donde realmente duele.
-- El triángulo visual tiene la base pegada al borde del tile y la punta libre.
--
--  dir=0 UP    → base en el FONDO  de la subcelda  (sy + HALF - thick)
--  dir=1 DOWN  → base en la CIMA   de la subcelda  (sy)
--  dir=2 LEFT  → base al LADO DER  de la subcelda  (sx + HALF - thick)
--  dir=3 RIGHT → base al LADO IZQ  de la subcelda  (sx)
local function spikeHitbox(sx2, sy2, HALF, dir)
    local mSide = HALF * 0.20
    local thick = HALF * 0.40
    if dir == DIR_UP then
        return sx2 + mSide, sy2 + HALF - thick, HALF - mSide * 2, thick
    elseif dir == DIR_DOWN then
        return sx2 + mSide, sy2,                HALF - mSide * 2, thick
    elseif dir == DIR_LEFT then
        return sx2 + HALF - thick, sy2 + mSide, thick,            HALF - mSide * 2
    else -- DIR_RIGHT
        return sx2,                sy2 + mSide, thick,            HALF - mSide * 2
    end
end

-- ── Shader de agua ────────────────────────────────────────────────────────────
local waterShader = nil
local shaderOk    = false
local function loadWaterShader()
    if waterShader ~= nil then return end
    local ok, sh = pcall(love.graphics.newShader, 'assets/shaders/water.glsl')
    if ok then waterShader=sh; shaderOk=true else shaderOk=false end
end

-- ── Burbujas ──────────────────────────────────────────────────────────────────
local bubbleImgs = nil

local BUBBLE_DEFS = {
    { path='assets/images/bubbles/bubble1.png', w=16, h=16 },
    { path='assets/images/bubbles/bubble2.png', w=6,  h=5  },
    { path='assets/images/bubbles/bubble3.png', w=3,  h=3  },
    { path='assets/images/bubbles/bubble4.png', w=16, h=16 },
}

local function loadBubbleImgs()
    if bubbleImgs then return end
    bubbleImgs = {}
    for _, def in ipairs(BUBBLE_DEFS) do
        local ok, img = pcall(love.graphics.newImage, def.path)
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
    local ok, img = pcall(love.graphics.newImage, 'assets/images/level/crack.png')
    if ok then ventImg = img end
end

-- ── Foliage (decoraciones) ──────────────────────────────────────────────────
local foliageImgs = nil

-- Constantes de animación
local TULIP_BREATHE_SPEED = 1.8
local TULIP_BREATHE_AMP   = 0.05

local STRETCH_FPS    = 3
local STRETCH_FRAMES = 5
-- Duración total de un ciclo completo (ida 1→5 + vuelta 5→1)
local STRETCH_CYCLE  = (STRETCH_FRAMES - 1) * 2 / STRETCH_FPS

local PALM_SWAY_SPEED = 1.2
local PALM_SWAY_AMP   = 0.06

local function loadFoliageImgs()
    if foliageImgs then return end
    foliageImgs = {}

    -- Tulip
    local ok, img = pcall(love.graphics.newImage, 'assets/images/foliage/tulip.png')
    if ok then foliageImgs.tulip = img end

    -- Stretch (5 frames)
    foliageImgs.stretch = {}
    for i = 1, STRETCH_FRAMES do
        local ok2, img2 = pcall(love.graphics.newImage, 'assets/images/foliage/strech/strech'..i..'.png')
        if ok2 then foliageImgs.stretch[i] = img2 end
    end

    -- Palmtree (3 partes)
    local ok3, img3
    ok3, img3 = pcall(love.graphics.newImage, 'assets/images/foliage/Palmtree/palmtree.png')
    if ok3 then foliageImgs.palmtree = img3 end
    ok3, img3 = pcall(love.graphics.newImage, 'assets/images/foliage/Palmtree/palmleaves.png')
    if ok3 then foliageImgs.palmleaves = img3 end
    ok3, img3 = pcall(love.graphics.newImage, 'assets/images/foliage/Palmtree/coques.png')
    if ok3 then foliageImgs.palmcocos = img3 end
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
local VENT_OXY_HIT_R      = 14    -- radio de colisión en px (world)

-- ── Flood-fill: detecta cuerpos de agua de >=9 tiles ─────────────────────────
local function findWaterBodies(level)
    local visited = {}
    local bodies  = {}

    local function isWaterTile(col, row)
        if row < 1 or row > level.tileH or col < 1 or col > level.tileW then
            return false
        end
        local raw = level:getRaw(col, row)
        return tileBaseId(raw) == TILE_WATER or isWaterloggedRaw(raw)
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

-- ── Constructor ───────────────────────────────────────────────────────────────
function Level.new(path)
    local self = setmetatable({}, Level)
    loadWaterShader()
    loadBubbleImgs()
    loadVentImg()
    loadFoliageImgs()
    local data = love.filesystem.read(path)
    assert(data, "No se pudo leer: "..tostring(path))
    local lvl = json.decode(data)
    self.name        = lvl.name or "?"
    self.tileW       = lvl.width
    self.tileH       = lvl.height
    self.playerStart = lvl.playerStart
    self.widthPx     = self.tileW * TILE_PX
    self.heightPx    = self.tileH * TILE_PX
    self.enemies     = lvl.enemies or {}
    self.tiles = {}
    for r = 1, self.tileH do
        self.tiles[r] = {}
        for c = 1, self.tileW do
            self.tiles[r][c] = math.floor(tonumber(lvl.tiles[r][c]) or 0)
        end
    end
    -- Burbujas: detectar cuerpos de agua y preparar pool activo
    self.waterBodies = findWaterBodies(self)
    self.bubbles     = {}
    -- Vents: EPICAS ENTRADAS OXIGENARIAS MARITIMAS DEL MAR ARTICO
    self.vents       = {}   -- instancias activas {x,y, spawnTimer, spawnDelay, particles, oxyBubbles}
    for _, vd in ipairs(lvl.vents or {}) do
        local col = tonumber(vd.col)
        local row = tonumber(vd.row)
        local sub = tonumber(vd.sub)   -- 1=TL, 2=TR, 3=BL, 4=BR
        if col and row and sub then
            -- Centro de la subcelda en px
            local subOffX = ((sub-1)%2) * (TILE_PX/2)
            local subOffY = (math.floor((sub-1)/2)) * (TILE_PX/2)
            local vx = (col-1)*TILE_PX + subOffX + TILE_PX/2
            local vy = (row-1)*TILE_PX + subOffY + TILE_PX/2
            -- Calcular techo del cuerpo de agua sobre este vent
            local ceilRow = row - 1
            while ceilRow >= 1 do
                local tr  = self.tiles[ceilRow] and self.tiles[ceilRow][col] or 0
                local tid = math.floor(tr or 0) % 16
                local twl = (math.floor((tr or 0) / 16) % 2) == 1
                if tid ~= TILE_WATER and not twl then break end
                ceilRow = ceilRow - 1
            end
            local ventCeilingY = ceilRow * TILE_PX
            table.insert(self.vents, {
                x          = vx,
                y          = vy,
                ceilingY   = ventCeilingY,
                spawnTimer = math.random() * VENT_NORM_SPAWN_MAX,
                spawnDelay = VENT_NORM_SPAWN_MIN + math.random()*(VENT_NORM_SPAWN_MAX-VENT_NORM_SPAWN_MIN),
                particles  = {},
                oxyBubbles = {},
                oxyTimer   = VENT_OXY_DELAY_MIN + math.random()*(VENT_OXY_DELAY_MAX-VENT_OXY_DELAY_MIN),
                oxyDelay   = VENT_OXY_DELAY_MIN + math.random()*(VENT_OXY_DELAY_MAX-VENT_OXY_DELAY_MIN),
            })
        end
    end
    -- ── Foliage ──────────────────────────────────────────────────────────────
    self.foliage = {}
    for _, fd in ipairs(lvl.foliage or {}) do
        local ftype = fd.type or 'tulip'
        local col   = tonumber(fd.col)
        local row   = tonumber(fd.row)
        local sub   = fd.sub and tonumber(fd.sub) or nil
        if col and row then
            -- Posición base (pies) en px
            local baseX, baseY
            if sub then
                -- Subcelda: centro-X de la subcelda, fondo-Y de la subcelda
                local subOffX = ((sub-1)%2) * (TILE_PX/2)
                local subOffY = (math.floor((sub-1)/2)) * (TILE_PX/2)
                baseX = (col-1)*TILE_PX + subOffX + TILE_PX/4
                baseY = (col-1)*TILE_PX + subOffY + TILE_PX/2  -- fondo de la subcelda
                -- Corrección: baseY usa row, no col
                baseY = (row-1)*TILE_PX + subOffY + TILE_PX/2
            else
                -- Celda completa (palmtree): misma posición que enemigos
                -- Centro-X de la celda, centro-Y de la celda (el render ancla por base)
                baseX = (col-1)*TILE_PX + TILE_PX/2
                baseY = (row-1)*TILE_PX + TILE_PX    -- fondo de la celda = suelo
            end

            table.insert(self.foliage, {
                type    = ftype,
                x       = baseX,
                y       = baseY,   -- posición de los "pies"
                animT   = math.random() * 10,  -- offset aleatorio para desincronizar
                frame   = math.random(1, STRETCH_FRAMES),
                frameT  = math.random() * (1 / STRETCH_FPS),
                cycleT  = math.random() * STRETCH_CYCLE,  -- offset para estiradora
            })
        end
    end
    return self
end

-- ── Acceso ────────────────────────────────────────────────────────────────────
function Level:getRaw(col, row)
    if row<1 or row>self.tileH or col<1 or col>self.tileW then return TILE_SOLID end
    return self.tiles[row][col] or 0
end

function Level:getTile(col, row)
    return tileBaseId(self:getRaw(col, row))
end

function Level:getTileAt(wx, wy)
    return self:getTile(math.floor(wx/TILE_PX)+1, math.floor(wy/TILE_PX)+1)
end

function Level:getRawAt(wx, wy)
    return self:getRaw(math.floor(wx/TILE_PX)+1, math.floor(wy/TILE_PX)+1)
end

function Level:getSpawnPx()
    local sx=(self.playerStart[1]-1)*TILE_PX+TILE_PX/2
    local sy=(self.playerStart[2]-1)*TILE_PX+TILE_PX/2
    return sx, sy
end

-- ── Consultas de física ───────────────────────────────────────────────────────
function Level:isWaterAt(wx, wy)
    local raw = self:getRawAt(wx, wy)
    local id  = tileBaseId(raw)
    return id == TILE_WATER or isWaterloggedRaw(raw)
end

-- La caja es semiabierta [bx, bx+bw) x [by, by+bh): los bordes derecho e
-- inferior NO pertenecen a la caja. Si un borde cae justo en el límite de un
-- tile (pies apoyados sobre un slab sumergido), ese tile es el de al lado, no
-- uno en el que estemos. Sin esto, la hitbox de pie y la de agachado (misma
-- base, calculada con distinto redondeo) daban resultados distintos y el
-- jugador alternaba agacharse/levantarse cada frame.
local EDGE_EPS = 1e-6
function Level:isInWater(bx, by, bw, bh)
    local rx, ry = bx + bw - EDGE_EPS, by + bh - EDGE_EPS
    local pts = {
        {bx,      by      },{rx,      by      },
        {bx,      ry      },{rx,      ry      },
        {bx+bw/2, by+bh/2 },
    }
    for _, p in ipairs(pts) do
        if self:isWaterAt(p[1], p[2]) then return true end
    end
    return false
end

-- Devuelve lista de {dir, x, y, w, h} de pinchos que intersectan la hitbox.
-- Hitbox = BASE del pincho (misma lógica que el debug en AdventureState).
function Level:getSpikesInBox(bx, by, bw, bh)
    local HALF = TILE_PX / 2
    local result = {}

    local sc = math.max(1, math.floor(bx / TILE_PX))
    local ec = math.min(self.tileW, math.ceil((bx+bw) / TILE_PX) + 1)
    local sr = math.max(1, math.floor(by / TILE_PX))
    local er = math.min(self.tileH, math.ceil((by+bh) / TILE_PX) + 1)

    local subOffsets = {
        {0,    0   },  -- TL
        {HALF, 0   },  -- TR
        {0,    HALF},  -- BL
        {HALF, HALF},  -- BR
    }

    for row = sr, er do
        for col = sc, ec do
            local raw = self:getRaw(col, row)
            if hasSpikes(raw) then
                local _, _, spikes = decTile(raw)
                local tx = (col-1) * TILE_PX
                local ty = (row-1) * TILE_PX
                for i = 1, 4 do
                    local sp = spikes[i]
                    if sp.present then
                        local ox  = subOffsets[i][1]
                        local oy  = subOffsets[i][2]
                        local hx, hy, hw, hh = spikeHitbox(tx+ox, ty+oy, HALF, sp.dir)
                        if bx < hx+hw and bx+bw > hx and
                           by < hy+hh and by+bh > hy then
                            result[#result+1] = {
                                dir = sp.dir,
                                x=hx, y=hy, w=hw, h=hh,
                            }
                        end
                    end
                end
            end
        end
    end
    return result
end

-- ── Helpers de tile-joining ───────────────────────────────────────────────────
-- Devuelve true si el tile (col,row) es "estructural" a efectos de unión de bordes.
-- Solid y Border se unen entre sí. El agua (tile puro o waterlogged) también
-- "tapa" el borde: un bloque sumergido no dibuja el borde que mira al agua.
local function isStructural(level, col, row)
    local id = tileBaseId(level:getRaw(col, row))
    return id == TILE_SOLID or id == TILE_BORDER
end

local function isWaterNeighbor(level, col, row)
    local raw = level:getRaw(col, row)
    local id  = tileBaseId(raw)
    return id == TILE_WATER or isWaterloggedRaw(raw)
end

-- Devuelve qué aristas de un tile estructural están expuestas.
-- Una arista se suprime si el vecino es estructural O si es agua/waterlogged.
local function getExposedEdges(level, col, row)
    local function hidden(c, r)
        return isStructural(level, c, r) or isWaterNeighbor(level, c, r)
    end
    return {
        top    = not hidden(col,   row-1),
        bottom = not hidden(col,   row+1),
        left   = not hidden(col-1, row),
        right  = not hidden(col+1, row),
    }
end

-- ── Render ────────────────────────────────────────────────────────────────────
local HALF_PX = nil

local function drawMiniSpike(dir, px, py, size)
    local s  = size
    local cx = px + s/2
    local cy = py + s/2
    love.graphics.setColor(0.92, 0.92, 0.92, 1)
    if dir == DIR_UP then
        love.graphics.polygon('fill', cx, py+1, px+1, py+s-1, px+s-1, py+s-1)
    elseif dir == DIR_DOWN then
        love.graphics.polygon('fill', cx, py+s-1, px+1, py+1, px+s-1, py+1)
    elseif dir == DIR_LEFT then
        love.graphics.polygon('fill', px+1, cy, px+s-1, py+1, px+s-1, py+s-1)
    elseif dir == DIR_RIGHT then
        love.graphics.polygon('fill', px+s-1, cy, px+1, py+1, px+1, py+s-1)
    end
end

-- Helper para aplicar recorte usando las transformaciones actuales (cámara/zoom)
local function setTransformedScissor(x, y, w, h)
    if x and y and w and h then
        local sx, sy = love.graphics.transformPoint(x, y)
        local ex, ey = love.graphics.transformPoint(x + w, y + h)
        local scX = math.min(sx, ex)
        local scY = math.min(sy, ey)
        local scW = math.abs(ex - sx)
        local scH = math.abs(ey - sy)
        love.graphics.setScissor(math.floor(scX), math.floor(scY), math.ceil(scW), math.ceil(scH))
    else
        love.graphics.setScissor()
    end
end

function Level:render(camX, camY)
    local t = love.timer.getTime()
    HALF_PX = TILE_PX / 2

    local sc2 = math.max(1,          math.floor(camX/TILE_PX)+1)
    local ec2 = math.min(self.tileW, math.ceil((camX+WINDOW_W)/TILE_PX)+1)
    local sr2 = math.max(1,          math.floor(camY/TILE_PX)+1)
    local er2 = math.min(self.tileH, math.ceil((camY+WINDOW_H)/TILE_PX)+1)

    local subOff = {{0,0},{HALF_PX,0},{0,HALF_PX},{HALF_PX,HALF_PX}}

    for row = sr2, er2 do
        for col = sc2, ec2 do
            local raw = self:getRaw(col, row)
            local id  = tileBaseId(raw)
            local wl  = isWaterloggedRaw(raw)
            local px  = (col-1)*TILE_PX - camX
            local py  = (row-1)*TILE_PX - camY

            if id == TILE_SOLID then
                -- Relleno base
                love.graphics.setColor(0.28, 0.28, 0.32, 1)
                love.graphics.rectangle('fill', px, py, TILE_PX, TILE_PX)

                -- Bordes solo en aristas expuestas (tile-joining)
                local edges = getExposedEdges(self, col, row)
                love.graphics.setColor(0.46, 0.46, 0.52, 1)
                if edges.top    then love.graphics.rectangle('fill', px,            py,            TILE_PX, 2) end
                if edges.bottom then love.graphics.rectangle('fill', px,            py+TILE_PX-2,  TILE_PX, 2) end
                if edges.left   then love.graphics.rectangle('fill', px,            py,            2, TILE_PX) end
                if edges.right  then love.graphics.rectangle('fill', px+TILE_PX-2,  py,            2, TILE_PX) end

            elseif id == TILE_BORDER then
                -- Relleno base
                love.graphics.setColor(0.42, 0.30, 0.10, 1)
                love.graphics.rectangle('fill', px, py, TILE_PX, TILE_PX)

                -- Bordes solo en aristas expuestas (tile-joining)
                local edges = getExposedEdges(self, col, row)
                love.graphics.setColor(0.62, 0.48, 0.20, 1)
                if edges.top    then love.graphics.rectangle('fill', px,            py,            TILE_PX, 2) end
                if edges.bottom then love.graphics.rectangle('fill', px,            py+TILE_PX-2,  TILE_PX, 2) end
                if edges.left   then love.graphics.rectangle('fill', px,            py,            2, TILE_PX) end
                if edges.right  then love.graphics.rectangle('fill', px+TILE_PX-2,  py,            2, TILE_PX) end

                -- Líneas de detalle interiores solo en tiles aislados (todas las caras expuestas)
                if edges.top and edges.bottom and edges.left and edges.right then
                    love.graphics.setColor(0.28, 0.18, 0.04, 0.35)
                    love.graphics.line(px+TILE_PX/2, py+2, px+TILE_PX/2, py+TILE_PX-2)
                    love.graphics.line(px+2, py+TILE_PX/2, px+TILE_PX-2, py+TILE_PX/2)
                end

            elseif id == TILE_PLATFORM then
                -- Plataforma traversable: ≈¾ del alto, sin parte inferior.
                -- Color neutro gris-pizarra, similar a los sólidos pero distinguible.
                local visH  = math.floor(TILE_PX * 0.72)
                local surfH = math.max(3, math.floor(TILE_PX * 0.18))

                -- Cuerpo
                love.graphics.setColor(0.30, 0.30, 0.36, 1)
                love.graphics.rectangle('fill', px, py, TILE_PX, visH)

                -- Franja de superficie (arriba)
                love.graphics.setColor(0.52, 0.52, 0.60, 1)
                love.graphics.rectangle('fill', px, py, TILE_PX, surfH)

                -- Línea de borde superior brillante
                love.graphics.setColor(0.78, 0.78, 0.90, 1)
                love.graphics.rectangle('fill', px, py, TILE_PX, 2)

                -- Bordes laterales hasta visH
                love.graphics.setColor(0.46, 0.46, 0.54, 1)
                love.graphics.rectangle('fill', px,           py, 2, visH)
                love.graphics.rectangle('fill', px+TILE_PX-2, py, 2, visH)

                -- Cara inferior (sombra)
                love.graphics.setColor(0.20, 0.20, 0.24, 1)
                love.graphics.rectangle('fill', px, py+visH-2, TILE_PX, 2)

            elseif id == TILE_DANGER then
                love.graphics.setColor(0.80, 0.08, 0.08, 1)
                love.graphics.rectangle('fill', px, py, TILE_PX, TILE_PX)
                love.graphics.setColor(1.0, 0.28, 0.28, 0.55)
                love.graphics.line(px+3, py+3, px+TILE_PX-3, py+TILE_PX-3)
                love.graphics.line(px+TILE_PX-3, py+3, px+3, py+TILE_PX-3)
            end

            -- (sin tinte azul: el efecto agua se aplica íntegramente en renderWaterEffect)

            local _, _, spikes = decTile(raw)
            for i = 1, 4 do
                if spikes[i].present then
                    local ox,oy = subOff[i][1], subOff[i][2]
                    drawMiniSpike(spikes[i].dir, px+ox, py+oy, HALF_PX)
                end
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function Level:renderWaterEffect(camX, camY, sceneCanvas)
    local t = love.timer.getTime()

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(sceneCanvas, 0, 0)

    local sc2 = math.max(1,          math.floor(camX/TILE_PX)+1)
    local ec2 = math.min(self.tileW, math.ceil((camX+WINDOW_W)/TILE_PX)+1)
    local sr2 = math.max(1,          math.floor(camY/TILE_PX)+1)
    local er2 = math.min(self.tileH, math.ceil((camY+WINDOW_H)/TILE_PX)+1)

    if shaderOk and waterShader then
        waterShader:send('time',     t)
        waterShader:send('strength', 0.001)
        waterShader:send('speed',    1.2)
        love.graphics.setShader(waterShader)
    end

    for row = sr2, er2 do
        for col = sc2, ec2 do
            local raw = self:getRaw(col, row)
            local id  = tileBaseId(raw)
            local wl  = isWaterloggedRaw(raw)
            local px  = math.floor((col-1)*TILE_PX - camX)
            local py  = math.floor((row-1)*TILE_PX - camY)

            if id == TILE_WATER or wl then
                if wl and id == TILE_PLATFORM then
                    -- Parte superior (donde está el sprite): distorsión normal
                    local visH  = math.floor(TILE_PX * 0.72)
                    local gapY  = py + visH
                    local gapH  = TILE_PX - visH
                    setTransformedScissor(px, py, TILE_PX, visH)
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(sceneCanvas, 0, 0)
                    -- Parte inferior vacía: también distorsionada, igual que TILE_WATER
                    setTransformedScissor(px, gapY, TILE_PX, gapH)
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(sceneCanvas, 0, 0)
                else
                    setTransformedScissor(px, py, TILE_PX, TILE_PX)
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(sceneCanvas, 0, 0)
                end
            end
        end
    end

    setTransformedScissor()
    if shaderOk and waterShader then love.graphics.setShader() end

    for row = sr2, er2 do
        for col = sc2, ec2 do
            local raw = self:getRaw(col, row)
            local id  = tileBaseId(raw)
            local wl  = isWaterloggedRaw(raw)
            local px  = (col-1)*TILE_PX - camX
            local py  = (row-1)*TILE_PX - camY

            -- (tinte global de agua se aplica en pasada única al final)
        end
    end

    -- ── Tinte de agua: una sola pasada, color uniforme ────────────────────────
    -- Un único setColor para todos los tiles de agua/waterlogged, sin acumulación.
    love.graphics.setColor(0.05, 0.30, 0.90, 0.35)
    for row = sr2, er2 do
        for col = sc2, ec2 do
            local raw = self:getRaw(col, row)
            local id  = tileBaseId(raw)
            local wl  = isWaterloggedRaw(raw)
            local px  = (col-1)*TILE_PX - camX
            local py  = (row-1)*TILE_PX - camY
            if id == TILE_WATER then
                love.graphics.rectangle('fill', px, py, TILE_PX, TILE_PX)
            elseif wl then
                -- Siempre tile completo: el espacio vacío bajo la plataforma
                -- es agua pura, debe tintarse igual que TILE_WATER.
                love.graphics.rectangle('fill', px, py, TILE_PX, TILE_PX)
            end
        end
    end

    local HALF_P = TILE_PX / 2
    local subOff = {{0,0},{HALF_P,0},{0,HALF_P},{HALF_P,HALF_P}}
    for row = sr2, er2 do
        for col = sc2, ec2 do
            local raw = self:getRaw(col, row)
            if isWaterloggedRaw(raw) then
                local _, _, spikes = decTile(raw)
                local px = (col-1)*TILE_PX - camX
                local py = (row-1)*TILE_PX - camY
                for i = 1, 4 do
                    if spikes[i].present then
                        local ox,oy = subOff[i][1], subOff[i][2]
                        drawMiniSpike(spikes[i].dir, px+ox, py+oy, HALF_P)
                    end
                end
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
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

-- ── Update: burbujas ──────────────────────────────────────────────────────────
function Level:update(dt)
    local hasBubbles = bubbleImgs and #bubbleImgs > 0

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
                y        = sp.y,
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
        if b.y + b.ih * BUB_SCALE < b.ceilingY then
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
                vent.oxyDelay = VENT_OXY_DELAY_MIN + math.random()*(VENT_OXY_DELAY_MAX-VENT_OXY_DELAY_MIN)
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
    local pcx = px + pw/2
    local pcy = py + ph/2
    for _, vent in ipairs(self.vents) do
        for _, b in ipairs(vent.oxyBubbles) do
            if b.alive then
                local dx = b.x - pcx
                local dy = b.y - pcy
                if dx*dx + dy*dy < VENT_OXY_HIT_R * VENT_OXY_HIT_R then
                    b.alive = false
                    return true
                end
            end
        end
    end
    return false
end

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

-- ── Update: foliage ──────────────────────────────────────────────────────────
function Level:updateFoliage(dt)
    for _, f in ipairs(self.foliage) do
        f.animT = f.animT + dt
        -- Stretch: avanzar timer de ciclo continuo
        if f.type == 'stretch' then
            f.cycleT = (f.cycleT or 0) + dt
            if f.cycleT >= STRETCH_CYCLE then
                f.cycleT = f.cycleT - STRETCH_CYCLE
            end
        end
    end
end

-- ── Render: foliage (decoraciones, por encima de enemigos y player) ──────────
function Level:renderFoliage(camX, camY)
    if not foliageImgs then return end

    -- Escalas por tipo de foliage
    local TULIP_SCALE    = 3
    local STRETCH_SCALE  = 4
    local PALMTREE_SCALE = 4

    for _, f in ipairs(self.foliage) do
        local sx = math.floor(f.x - camX)
        local sy = math.floor(f.y - camY)

        -- Culling básico
        if sx > -TILE_PX*4 and sx < WINDOW_W + TILE_PX*4 and
           sy > -TILE_PX*4 and sy < WINDOW_H + TILE_PX*4 then

            if f.type == 'tulip' then
                local img = foliageImgs.tulip
                if img then
                    local iw = img:getWidth()
                    local ih = img:getHeight()
                    local breathe = math.sin(f.animT * TULIP_BREATHE_SPEED * math.pi)
                    local scY = TULIP_SCALE * (1.0 + breathe * TULIP_BREATHE_AMP)
                    local scX = TULIP_SCALE * (1.0 - breathe * TULIP_BREATHE_AMP * 0.3)
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(img, sx, sy, 0, scX, scY, iw/2, ih)
                end

            elseif f.type == 'stretch' then
                local imgs = foliageImgs.stretch
                if imgs and #imgs >= STRETCH_FRAMES then
                    -- Progreso ping-pong: 0→1 (ida) → 1→0 (vuelta)
                    local cycleT = f.cycleT or 0
                    local halfCycle = STRETCH_CYCLE / 2
                    local progress
                    if cycleT < halfCycle then
                        progress = cycleT / halfCycle
                    else
                        progress = 1 - (cycleT - halfCycle) / halfCycle
                    end

                    -- Frame discreto (sin crossfade): 1→2→3→4→5→4→3→2→1
                    local frameIdx = math.floor(progress * (STRETCH_FRAMES - 1) + 0.5) + 1
                    frameIdx = math.max(1, math.min(frameIdx, STRETCH_FRAMES))
                    local img = imgs[frameIdx]

                    if img then
                        local iw = img:getWidth()
                        local ih = img:getHeight()

                        -- Estiramiento continuo: achatado en frame 1, estirado en frame 5
                        -- progress=0 → squash (-5%), progress=1 → stretch (+8%)
                        local stretchAmount = -0.05 + progress * 0.13
                        local scY = STRETCH_SCALE * (1.0 + stretchAmount)
                        local scX = STRETCH_SCALE * (1.0 - stretchAmount * 0.25)

                        love.graphics.setColor(1, 1, 1, 1)
                        love.graphics.draw(img, sx, sy, 0, scX, scY, iw/2, ih)
                    end
                end

            elseif f.type == 'palmtree' then
                local sway = math.sin(f.animT * PALM_SWAY_SPEED * math.pi) * PALM_SWAY_AMP

                local parts = {
                    { img = foliageImgs.palmtree,   swayMult = 0.3 },
                    { img = foliageImgs.palmcocos,   swayMult = 0.8 },
                    { img = foliageImgs.palmleaves,  swayMult = 1.0 },
                }

                for _, part in ipairs(parts) do
                    if part.img then
                        local iw = part.img:getWidth()
                        local ih = part.img:getHeight()
                        local rot = sway * part.swayMult
                        love.graphics.setColor(1, 1, 1, 1)
                        love.graphics.draw(part.img, sx, sy, rot,
                            PALMTREE_SCALE, PALMTREE_SCALE, iw/2, ih)
                    end
                end
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return Level