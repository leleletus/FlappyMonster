-- src/world/Level.lua
-- Nivel: carga el JSON, responde consultas de física (colisión, líquidos,
-- pinchos) y dibuja los tiles. El significado de cada tile (colisión,
-- material, aspecto) vive en el catálogo de tiles (src/world/Tiles.lua) y el
-- formato de cada celda en src/world/tiles/TileCodec.lua.

local json      = require 'libs/json'
local Tiles     = require 'src/world/Tiles'
local TileCodec = Tiles.codec
local TileTypes = Tiles.types
local Materials = Tiles.materials
local EntityTypes = require('src/world/Entities').types   -- carga el catálogo
local DecorationTypes = require('src/world/Decorations').types
local BossZones = require 'src/world/BossZones'
local AutoScroll = require 'src/world/AutoScroll'
local Floods     = require 'src/world/Floods'
local PointAreas = require 'src/world/PointAreas'
local WaterSurface = require 'src/fx/WaterSurface'

local Level = {}
Level.__index = Level

local DIR_UP    = TileCodec.DIR_UP
local DIR_DOWN  = TileCodec.DIR_DOWN
local DIR_LEFT  = TileCodec.DIR_LEFT
local DIR_RIGHT = TileCodec.DIR_RIGHT

local decTile          = TileCodec.decode
local tileBaseId       = TileCodec.id
local isWaterloggedRaw = TileCodec.isWaterlogged
local hasSpikes        = TileCodec.hasSpikes

-- Material líquido de una celda: el del propio tile si es líquido, o agua si
-- la celda está waterlogged. nil = no hay líquido.
local WATERLOGGED_MAT = 'water'
local function liquidOfRaw(raw)
    local m = TileTypes.get(tileBaseId(raw)).mat
    if m.liquid then return m end
    if isWaterloggedRaw(raw) then return Materials.get(WATERLOGGED_MAT) end
    return nil
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

-- ── Constructor ───────────────────────────────────────────────────────────────
function Level.new(path)
    local data = love.filesystem.read(path)
    assert(data, "No se pudo leer: "..tostring(path))
    return Level.fromData(json.decode(data))
end

-- Construye el nivel desde la tabla ya decodificada (el editor la usa para
-- mostrar su nivel en memoria sin guardarlo).
function Level.fromData(lvl)
    local self = setmetatable({}, Level)
    loadWaterShader()
    loadBubbleImgs()
    loadVentImg()
    self.name        = lvl.name or "?"
    self.tileW       = lvl.width
    self.tileH       = lvl.height
    self.playerStart = lvl.playerStart
    self.widthPx     = self.tileW * TILE_PX
    self.heightPx    = self.tileH * TILE_PX
    -- Entidades (enemigos, NPCs): colocaciones normalizadas con sus
    -- propiedades resueltas. Acepta el formato nuevo (`entities`) y el antiguo
    -- (`enemies` con leftBound/rightBound/flipped). Tipos desconocidos se omiten.
    self.entities    = {}
    for _, ed in ipairs(lvl.entities or lvl.enemies or {}) do
        local n = EntityTypes.normalize(ed)
        if n then table.insert(self.entities, n) end
    end
    -- Entidades de reserva que algunas crean (p. ej. los súbditos del Mega
    -- Crabby, def.summons): van DESPUÉS de las del JSON, así el servidor y los
    -- clientes tienen la misma lista (mismos índices)
    local reserve = {}
    for _, n in ipairs(self.entities) do
        local def = EntityTypes.byName[n.type]
        if def and def.summons then
            for _, raw in ipairs(def.summons(n) or {}) do
                local m = EntityTypes.normalize(raw)
                if m then m.reserve, m.summonKey = true, raw.summonKey; reserve[#reserve + 1] = m end
            end
        end
    end
    for _, m in ipairs(reserve) do table.insert(self.entities, m) end
    self.enemies     = self.entities   -- alias de compatibilidad
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
            local vx = (col-1)*TILE_PX + subOffX + TILE_PX/4
            local vy = (row-1)*TILE_PX + subOffY + TILE_PX/4
            -- Calcular techo del cuerpo de agua sobre este vent
            local ceilRow = row - 1
            while ceilRow >= 1 do
                local tr  = self.tiles[ceilRow] and self.tiles[ceilRow][col] or 0
                if not liquidOfRaw(tr) then break end
                ceilRow = ceilRow - 1
            end
            local ventCeilingY = ceilRow * TILE_PX
            -- Límite opcional de altura: la burbuja de aire explota tras subir
            -- `limit` casillas (en océanos profundos no llega a la superficie)
            local limit = tonumber(vd.limit)
            if limit and limit > 0 then
                ventCeilingY = math.max(ventCeilingY, vy - limit * TILE_PX)
            end
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
    -- ── Decoraciones (catálogo src/world/Decorations.lua) ────────────────────
    -- El JSON las guarda en "foliage". Tipos desconocidos se omiten.
    self.decorations = {}
    for _, fd in ipairs(lvl.foliage or {}) do
        local n = DecorationTypes.normalize(fd)
        if n then table.insert(self.decorations, DecorationTypes.instantiate(n)) end
    end
    self.foliage = self.decorations   -- alias de compatibilidad
    -- Zonas de jefe (src/world/BossZones.lua)
    self.bossZones = BossZones.build(lvl.bossZones)
    -- Cámara automática (src/world/AutoScroll.lua), o nil
    self.autoScroll = AutoScroll.build(lvl.autoScroll, self)
    -- Inundaciones (src/world/Floods.lua): salen de las entidades 'flood'
    self.floods = Floods.build(self.entities, Materials)
    self.floodTime = 0
    -- Zonas de puntos (src/world/PointAreas.lua): entidades 'pointarea'
    self.pointAreas = PointAreas.build(self.entities)
    -- Modos en los que se ofrece (nil = todos los que admitan el nivel) y
    -- duración de las partidas con tiempo (Rey de la Colina), en segundos
    self.modes     = type(lvl.modes) == 'table' and #lvl.modes > 0 and lvl.modes or nil
    self.matchTime = tonumber(lvl.matchTime)
    -- Música del nivel: id de assets/music/index.json (nil = la de siempre)
    self.music     = type(lvl.music) == 'string' and lvl.music or nil
    return self
end

-- ── Suelo seguro para reaparecer ─────────────────────────────────────────────
-- ¿Cabe un jugador de pie en la celda (c, r)? (ella y la de encima libres,
-- sin peligros ni pinchos, y algo firme debajo)
function Level:isStandable(c, r)
    for rr = r - 1, r do
        local d = self:getDef(c, rr)
        if d.collision == 'solid' or d.mat.contact or d.trigger then return false end
        if self:hasSpikeCellInBox((c - 1) * TILE_PX + 1, (rr - 1) * TILE_PX + 1, TILE_PX - 2, TILE_PX - 2) then return false end
    end
    local below = self:getDef(c, r + 1)
    return below.collision == 'solid' or below.collision == 'oneway'
end

-- Punto (x, y del jugador de pie) en el suelo más bajo cerca de la columna
-- `col`, buscando hacia los lados dentro de [minCol, maxCol] y de las filas
-- [minRow, maxRow]. nil si no hay ninguno.
function Level:findGround(col, minCol, maxCol, minRow, maxRow)
    minCol, maxCol = math.max(1, minCol or 1), math.min(self.tileW, maxCol or self.tileW)
    minRow, maxRow = math.max(2, minRow or 2), math.min(self.tileH - 1, maxRow or self.tileH - 1)
    for off = 0, maxCol - minCol do
        for _, c in ipairs(off == 0 and { col } or { col + off, col - off }) do
            if c >= minCol and c <= maxCol then
                for r = maxRow, minRow, -1 do
                    if self:isStandable(c, r) then
                        return (c - 0.5) * TILE_PX, r * TILE_PX - 16 * PLAYER_SCALE / 2 - 2
                    end
                end
            end
        end
    end
    return nil
end

-- Paredes invisibles en el punto: zona de jefe sin superar que lo contiene
-- o la ventana de la cámara automática. nil = ninguna.
function Level:arenaAt(wx, wy)
    if #self.bossZones > 0 then
        local z = BossZones.arenaAt(self, wx, wy)
        if z then return z end
    end
    if self.autoScroll then return AutoScroll.arena(self) end
    return nil
end

-- ── Acceso ────────────────────────────────────────────────────────────────────
-- Fuera del mapa todo es bloque sólido.
local OUTSIDE_RAW = TILE_SOLID

function Level:getRaw(col, row)
    if row<1 or row>self.tileH or col<1 or col>self.tileW then return OUTSIDE_RAW end
    return self.tiles[row][col] or 0
end

-- Id del tipo de tile en la celda / en el punto de mundo
function Level:getTile(col, row)
    return tileBaseId(self:getRaw(col, row))
end

function Level:getTileAt(wx, wy)
    return self:getTile(math.floor(wx/TILE_PX)+1, math.floor(wy/TILE_PX)+1)
end

function Level:getRawAt(wx, wy)
    return self:getRaw(math.floor(wx/TILE_PX)+1, math.floor(wy/TILE_PX)+1)
end

-- Tipo de tile (definición del catálogo) en la celda / en el punto de mundo
function Level:getDef(col, row)
    return TileTypes.get(self:getTile(col, row))
end

function Level:getDefAt(wx, wy)
    return TileTypes.get(self:getTileAt(wx, wy))
end

function Level:getSpawnPx()
    local sx=(self.playerStart[1]-1)*TILE_PX+TILE_PX/2
    local sy=(self.playerStart[2]-1)*TILE_PX+TILE_PX/2
    return sx, sy
end

-- ── Consultas de física ───────────────────────────────────────────────────────

-- Tipo que COLISIONA en el punto (respetando su hitbox), o nil.
-- includeOneway: incluir plataformas de un solo sentido.
function Level:collisionAt(wx, wy, includeOneway)
    local t = self:getDefAt(wx, wy)
    if t.collision == 'solid' then
        if TileTypes.hitboxContains(t, wx, wy) then return t end
    elseif includeOneway and t.collision == 'oneway' then
        if TileTypes.hitboxContains(t, wx, wy) then return t end
    end
    return nil
end

-- Plataforma (one-way) cuya celda contiene el punto por DEBAJO de su cara de
-- arriba (aunque la losa sea fina y el punto quede bajo ella). Solo para quien
-- comprueba además que venía de arriba (el aterrizaje del jugador): así un
-- paso rápido no atraviesa una losa fina.
function Level:onewayCellAt(wx, wy)
    local t = self:getDefAt(wx, wy)
    if t.collision ~= 'oneway' then return nil end
    local hb, T = t.hitbox, TILE_PX
    local fx, fy = (wx % T) / T, (wy % T) / T
    if fx >= hb.x and fx < hb.x + hb.w and fy >= hb.y then return t end
    return nil
end

-- Algo que cae (una punta, una bola de fuego...) pasa de y0 a y1 en la
-- columna wx: ¿ha cruzado DESDE ARRIBA la cara superior de un bloque o una
-- plataforma? Devuelve el tile y la Y de esa cara. No importa lo fina que sea
-- la losa ni lo rápido que caiga; y una losa que ya estaba por encima (p. ej.
-- la del techo del que cuelga) no cuenta. Empezar dentro de un bloque sólido
-- cuenta como chocar con él.
function Level:landingCross(wx, y0, y1)
    if y1 < y0 then return nil end
    local T = TILE_PX
    for r = math.floor(y0 / T), math.floor(y1 / T) do
        local t = self:getDefAt(wx, r * T + T / 2)
        if t.collision == 'solid' or t.collision == 'oneway' then
            local hb = t.hitbox
            local fx = (wx % T) / T
            if fx >= hb.x and fx < hb.x + hb.w then
                local top = r * T + hb.y * T
                if y0 <= top + 0.5 and y1 >= top then return t, top end
                if t.collision == 'solid' and y1 > top and y0 < top + hb.h * T then return t, top end
            end
        end
    end
    return nil
end

-- ¿Los enemigos pisan/chocan con lo que hay en el punto?
-- Tipo de tile sólido para las entidades en el punto (con su forma real), o nil
function Level:enemySolidDefAt(wx, wy)
    local t = self:getDefAt(wx, wy)
    if t.enemySolid and TileTypes.hitboxContains(t, wx, wy) then return t end
    return nil
end

-- Objeto sólido "como un bloque" (solidFull: trampolines, morteros...) que
-- contiene el punto, o nil. level.solidBodies lo rellena el juego cada paso.
function Level:bodyAt(wx, wy, except)
    for _, o in ipairs(self.solidBodies or {}) do
        if o.solidFull and o ~= except and o.alive ~= false then
            local b = o:getOuterBounds()
            if wx >= b.x and wx < b.x + b.w and wy >= b.y and wy < b.y + b.h then return o, b end
        end
    end
    return nil
end

-- Sólido para las entidades que andan: tiles (forma real) y objetos sólidos
function Level:entitySolidAt(wx, wy, except)
    return self:isEnemySolidAt(wx, wy) or self:bodyAt(wx, wy, except) ~= nil
end

function Level:isEnemySolidAt(wx, wy)
    local t = self:getDefAt(wx, wy)
    return t.enemySolid and TileTypes.hitboxContains(t, wx, wy)
end

-- Tipo cuyo material tiene efecto de contacto ('kill'/'hurt') en el punto, o nil.
function Level:contactAt(wx, wy)
    local t = self:getDefAt(wx, wy)
    if t.mat.contact and TileTypes.hitboxContains(t, wx, wy) then return t end
    return nil
end

-- Material líquido en el punto (agua, waterlogged...), o nil.
function Level:liquidAt(wx, wy)
    local fl = self.floods
    if fl and fl[1] then
        local m = Floods.liquidAt(fl, wx, wy)      -- agua de una inundación
        if m then return m end
    end
    return liquidOfRaw(self:getRawAt(wx, wy))
end

-- Material líquido de una celda (col,row), o nil.
function Level:liquidOfCell(col, row)
    return liquidOfRaw(self:getRaw(col, row))
end

function Level:isWaterAt(wx, wy)
    return self:liquidAt(wx, wy) ~= nil
end

-- La caja es semiabierta [bx, bx+bw) x [by, by+bh): los bordes derecho e
-- inferior NO pertenecen a la caja. Si un borde cae justo en el límite de un
-- tile (pies apoyados sobre un slab sumergido), ese tile es el de al lado, no
-- uno en el que estemos. Sin esto, la hitbox de pie y la de agachado (misma
-- base, calculada con distinto redondeo) daban resultados distintos y el
-- jugador alternaba agacharse/levantarse cada frame.
local EDGE_EPS = 1e-6

-- Material líquido que toca la caja (primer punto de muestreo con líquido), o nil.
function Level:liquidInBox(bx, by, bw, bh)
    local rx, ry = bx + bw - EDGE_EPS, by + bh - EDGE_EPS
    local pts = {
        {bx,      by      },{rx,      by      },
        {bx,      ry      },{rx,      ry      },
        {bx+bw/2, by+bh/2 },
    }
    for _, p in ipairs(pts) do
        local m = self:liquidAt(p[1], p[2])
        if m then return m end
    end
    return nil
end

-- ¿La caja toca algún tile con el trigger `name` (p. ej. 'finish')?
-- Caja semiabierta como liquidInBox; respeta la hitbox del tile.
function Level:triggerInBox(bx, by, bw, bh, name)
    local T = TILE_PX
    local c0, c1 = math.floor(bx / T) + 1, math.floor((bx + bw - EDGE_EPS) / T) + 1
    local r0, r1 = math.floor(by / T) + 1, math.floor((by + bh - EDGE_EPS) / T) + 1
    for r = r0, r1 do
        for c = c0, c1 do
            local t = self:getDef(c, r)
            if t.trigger == name then
                local hx, hy, hw, hh = TileTypes.worldHitbox(t, c, r)
                if bx < hx + hw and bx + bw > hx and by < hy + hh and by + bh > hy then return true end
            end
        end
    end
    return false
end

-- Cuenta las celdas con cierto trigger (para saber qué modos admite un nivel)
function Level:countTrigger(name)
    local n = 0
    for r = 1, self.tileH do for c = 1, self.tileW do
        if self:getDef(c, r).trigger == name then n = n + 1 end
    end end
    return n
end

-- ── Tiles que cambian durante la partida (bloques rompibles) ────────────────
-- canBreak = false en el cliente online: allí solo se rompen cuando lo dice
-- el servidor (evento), para no romper nada por una predicción equivocada.
-- Los bloques rotos se apuntan en self.brokenQueue para que el servidor los
-- difunda (col, row, nuevo valor).
function Level:breakTile(col, row)
    if self.canBreak == false then return false end
    local raw = self:getRaw(col, row)
    if not TileTypes.get(tileBaseId(raw)).breakable then return false end
    if not (self.tiles[row] and self.tiles[row][col]) then return false end
    local new = TileCodec.isWaterlogged(raw) and TILE_WATER or TILE_EMPTY
    self.tiles[row][col] = new
    self.brokenQueue = self.brokenQueue or {}
    table.insert(self.brokenQueue, { col, row, new })
    return true
end

-- Golpe a un tile (cabezazo desde abajo o ground pound encima): rompe los
-- rompibles y cambia los ON/OFF (`toggle`: nombre del tile en que se
-- convierte, conservando agua y pinchos). Devuelve 'break', 'toggle' o nil.
-- Igual que breakTile: en el cliente online (canBreak = false) no hace nada
-- (lo decide el servidor) y los cambios van a brokenQueue con su tipo.
-- `from` = 'head' (cabezazo desde abajo) o 'pound' (ground pound encima):
-- decide la animación del bloque (saltito / aplastarse, ver tileBump).
function Level:hitTile(col, row, from)
    local def = self:getDef(col, row)
    if def.breakable then return self:breakTile(col, row) and 'break' or nil end
    if not def.toggle or self.canBreak == false then return nil end
    if not (self.tiles[row] and self.tiles[row][col]) then return nil end
    local to = TileTypes.byName[def.toggle]
    if not to then return nil end
    local _, water, spikes = decTile(self:getRaw(col, row))
    local new = TileCodec.encode(to.id, water, spikes)
    self.tiles[row][col] = new
    self.brokenQueue = self.brokenQueue or {}
    table.insert(self.brokenQueue, { col, row, new, 'toggle', from })
    self:tileBump(col, row, from)
    return 'toggle'
end

-- Animación de un bloque golpeado (solo dibujo): 'head' = saltito hacia arriba,
-- 'pound' = se aplasta y recupera. La pone quien golpea (un jugador) o el
-- evento del servidor (online); Level:update la hace avanzar.
local BUMP_T = { head = 0.22, pound = 0.28 }
function Level:tileBump(col, row, from)
    if not BUMP_T[from] then return end
    self.tileAnim = self.tileAnim or {}
    self.tileAnim[row * 65536 + col] = { kind = from, t = 0, dur = BUMP_T[from] }
end

-- Bloques invisibles (tile `hidden`): cuáles se ven. Solo dibujo; cada juego
-- lo llama con las cajas de SUS jugadores (un jugador: el suyo; online: el
-- propio predicho + los remotos). Un bloque aparece al tocarlo (caja del
-- jugador ampliada 1 px: estar de pie encima cuenta), sigue visible mientras
-- alguien lo toca y, sin contacto, espera `hold` s, parpadea `blink` s y se va.
local HIDDEN_HOLD, HIDDEN_BLINK = 0.25, 0.9
function Level:updateHiddenBlocks(dt, boxes)
    if self.hasHidden == nil then
        self.hasHidden = false
        for r = 1, self.tileH do for c = 1, self.tileW do
            if self:getDef(c, r).hidden then self.hasHidden = true end
        end end
    end
    if not self.hasHidden then return end
    local vis = self.hiddenVis or {}
    self.hiddenVis = vis
    local T = TILE_PX
    local touched = {}
    for _, b in ipairs(boxes) do
        local c0, c1 = math.floor((b.x - 1) / T) + 1, math.floor((b.x + b.w + 1) / T) + 1
        local r0, r1 = math.floor((b.y - 1) / T) + 1, math.floor((b.y + b.h + 1) / T) + 1
        for r = r0, r1 do
            for c = c0, c1 do
                if self:getDef(c, r).hidden then touched[r * 65536 + c] = true end
            end
        end
    end
    for k in pairs(touched) do
        local st = vis[k]
        if not st then
            vis[k] = { age = 0, left = 0, hold = HIDDEN_HOLD, blink = HIDDEN_BLINK }
        else
            st.left = 0
        end
    end
    for k, st in pairs(vis) do
        st.age = st.age + dt
        if not touched[k] then
            st.left = st.left + dt
            if st.left >= st.hold + st.blink then vis[k] = nil end
        end
    end
end

-- Aplica un cambio de tile recibido del servidor
function Level:setTileRaw(col, row, raw)
    if self.tiles[row] and self.tiles[row][col] ~= nil then self.tiles[row][col] = raw end
end

function Level:isInWater(bx, by, bw, bh)
    return self:liquidInBox(bx, by, bw, bh) ~= nil
end

-- Devuelve lista de {dir, x, y, w, h} de pinchos que intersectan la hitbox.
-- Hitbox = BASE del pincho (la misma que dibuja Level:renderDebug).
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
            -- Los pinchos sobre un tile trampa son de mentira
            if hasSpikes(raw) and not TileTypes.get(tileBaseId(raw)).fake then
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

-- ¿Hay alguna subcelda con pincho (real) tocando la caja? Para que las
-- entidades que caminan los traten como obstáculo.
function Level:hasSpikeCellInBox(bx, by, bw, bh)
    local HALF = TILE_PX / 2
    local sc = math.max(1, math.floor(bx / TILE_PX) + 1)
    local ec = math.min(self.tileW, math.floor((bx + bw) / TILE_PX) + 1)
    local sr = math.max(1, math.floor(by / TILE_PX) + 1)
    local er = math.min(self.tileH, math.floor((by + bh) / TILE_PX) + 1)
    for row = sr, er do
        for col = sc, ec do
            local raw = self:getRaw(col, row)
            if hasSpikes(raw) and not TileTypes.get(tileBaseId(raw)).fake then
                local _, _, spikes = decTile(raw)
                for i = 1, 4 do
                    if spikes[i].present then
                        local x = (col - 1) * TILE_PX + ((i - 1) % 2) * HALF
                        local y = (row - 1) * TILE_PX + math.floor((i - 1) / 2) * HALF
                        if bx < x + HALF and bx + bw > x and by < y + HALF and by + bh > y then return true end
                    end
                end
            end
        end
    end
    return false
end

-- ── Render ────────────────────────────────────────────────────────────────────
local HALF_PX = nil

-- Púa de tile: assets/images/spikes/spike.png (hacia arriba, del tamaño de
-- media casilla); las otras direcciones son la misma imagen girada o volteada
local spikeImg
local function drawMiniSpike(dir, px, py, size)
    if not spikeImg then
        spikeImg = love.graphics.newImage('assets/images/spikes/spike.png')
        spikeImg:setFilter('nearest', 'nearest')
    end
    local k = size / spikeImg:getWidth()
    love.graphics.setColor(1, 1, 1, 1)
    if dir == DIR_UP then
        love.graphics.draw(spikeImg, px, py, 0, k, k)
    elseif dir == DIR_DOWN then
        love.graphics.draw(spikeImg, px, py + size, 0, k, -k)
    elseif dir == DIR_LEFT then
        love.graphics.draw(spikeImg, px, py + size, -math.pi / 2, k, k)
    elseif dir == DIR_RIGHT then
        love.graphics.draw(spikeImg, px + size, py, math.pi / 2, k, k)
    end
end

-- Helper para aplicar recorte usando las transformaciones actuales (cámara/zoom)
-- Recorte a una celda (varias seguidas) y, con nil, vuelta al recorte que
-- había antes (las bandas de lovesize), no a "sin recorte"
local prevScissor
local function setTransformedScissor(x, y, w, h)
    if x and y and w and h then
        if not prevScissor then prevScissor = { love.graphics.getScissor() } end
        local p = prevScissor
        if p[1] then love.graphics.setScissor(p[1], p[2], p[3], p[4]) else love.graphics.setScissor() end
        local sx, sy = love.graphics.transformPoint(x, y)
        local ex, ey = love.graphics.transformPoint(x + w, y + h)
        local x0, y0 = math.floor(math.min(sx, ex)), math.floor(math.min(sy, ey))
        local x1, y1 = math.ceil(math.max(sx, ex)), math.ceil(math.max(sy, ey))
        love.graphics.intersectScissor(x0, y0, math.max(0, x1 - x0), math.max(0, y1 - y0))
    else
        local p = prevScissor
        prevScissor = nil
        if p and p[1] then love.graphics.setScissor(p[1], p[2], p[3], p[4]) else love.graphics.setScissor() end
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
    local ctx = { size = TILE_PX, level = self, time = t }

    for row = sr2, er2 do
        for col = sc2, ec2 do
            local raw = self:getRaw(col, row)
            local px  = (col-1)*TILE_PX - camX
            local py  = (row-1)*TILE_PX - camY

            -- Aspecto del tipo (el agua se pinta en renderWaterEffect). Los
            -- bloques cuyo trigger no usa el modo en juego (hiddenTriggers, p. ej.
            -- la meta en Cacería) no se dibujan: no tienen colisión.
            ctx.x, ctx.y, ctx.col, ctx.row, ctx.raw = px, py, col, row, raw
            local def = TileTypes.get(tileBaseId(raw))
            local anim = self.tileAnim and self.tileAnim[row * 65536 + col]
            if anim then
                -- Golpeado: cabezazo = sube y baja; ground pound = se aplasta
                -- desde arriba (anclado abajo) y rebota un poco al recuperarse
                local k = anim.t / anim.dur
                love.graphics.push()
                if anim.kind == 'head' then
                    love.graphics.translate(0, -math.floor(math.sin(k * math.pi) * TILE_PX * 0.22))
                else
                    -- (se aplasta hasta el 40 % y rebota amortiguado hasta quedarse igual)
                    local u = (k - 0.4) / 0.6
                    local sq = (k < 0.4) and (k / 0.4) or (1 - u) * math.cos(u * math.pi * 1.5)
                    local sy = 1 - 0.3 * sq
                    local sx = 1 + 0.12 * sq
                    love.graphics.translate(px + TILE_PX / 2, py + TILE_PX)
                    love.graphics.scale(sx, sy)
                    love.graphics.translate(-(px + TILE_PX / 2), -(py + TILE_PX))
                end
            end
            if not (def.trigger and self.hiddenTriggers and self.hiddenTriggers[def.trigger]) then
                TileTypes.drawTile(def, ctx)
            end
            if anim then love.graphics.pop() end

            -- Pinchos (subceldas)
            local _, _, spikes = decTile(raw)
            for i = 1, 4 do
                if spikes[i].present then
                    local ox,oy = subOff[i][1], subOff[i][2]
                    drawMiniSpike(spikes[i].dir, px+ox, py+oy, HALF_PX)
                end
            end
        end
    end

    -- Zonas de puntos (detrás de entidades y jugadores)
    PointAreas.render(self, camX, camY)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Debug (F1): hitboxes REALES que usa la física. Pinchos en rojo, tiles con
-- efecto de contacto en rojo intenso y formas de colisión no completas en cian.
function Level:renderDebug(camX, camY)
    local sc = math.max(1, math.floor(camX/TILE_PX))
    local ec = math.min(self.tileW, math.ceil((camX+WINDOW_W)/TILE_PX)+1)
    local sr = math.max(1, math.floor(camY/TILE_PX))
    local er = math.min(self.tileH, math.ceil((camY+WINDOW_H)/TILE_PX)+1)
    for row = sr, er do
        for col = sc, ec do
            local t = self:getDef(col, row)
            local hx, hy, hw, hh = TileTypes.worldHitbox(t, col, row)
            if t.mat.contact then
                love.graphics.setColor(1, 0, 0, 0.4)
                love.graphics.rectangle('line', hx - camX, hy - camY, hw, hh)
            elseif t.collision ~= 'none' and not t.fullHitbox then
                love.graphics.setColor(0.2, 1, 1, 0.6)
                love.graphics.rectangle('line', hx - camX, hy - camY, hw, hh)
            end
        end
    end
    -- Burbujas de oxígeno: su círculo de colisión (cian)
    love.graphics.setColor(0.2, 1, 1, 0.8)
    for _, vent in ipairs(self.vents or {}) do
        for _, b in ipairs(vent.oxyBubbles) do
            if b.alive then
                local cx, cy, r = Level.oxyBubbleCircle(b)
                love.graphics.circle('line', cx - camX, cy - camY, r)
            end
        end
    end
    local x0, y0 = (sc-1)*TILE_PX, (sr-1)*TILE_PX
    for _, sp in ipairs(self:getSpikesInBox(x0, y0, (ec-sc+1)*TILE_PX, (er-sr+1)*TILE_PX)) do
        love.graphics.setColor(1, 0.3, 0.3, 0.5)
        love.graphics.rectangle('line', sp.x - camX, sp.y - camY, sp.w, sp.h)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ¿Celda de agua con la superficie arriba? (encima hay aire: ni líquido ni
-- un bloque macizo, que sería agua apretada contra un techo)
function Level:isWaterSurfaceCell(col, row)
    if row <= 1 then return false end
    local d = self:getDef(col, row)
    if d.collision == 'solid' and d.fullHitbox then return false end
    if liquidOfRaw(self:getRaw(col, row - 1)) then return false end
    local up = self:getDef(col, row - 1)
    return not (up.collision == 'solid' and up.fullHitbox)
end

-- Efecto de los líquidos: distorsión (shader) y tinte según su material.
function Level:renderWaterEffect(camX, camY, sceneCanvas)
    local t = love.timer.getTime()

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(sceneCanvas, 0, 0)

    local sc2 = math.max(1,          math.floor(camX/TILE_PX)+1)
    local ec2 = math.min(self.tileW, math.ceil((camX+WINDOW_W)/TILE_PX)+1)
    local sr2 = math.max(1,          math.floor(camY/TILE_PX)+1)
    local er2 = math.min(self.tileH, math.ceil((camY+WINDOW_H)/TILE_PX)+1)

    -- Distorsión: la escena se vuelve a dibujar con shader, recortada a cada
    -- celda líquida (tile completo, también el hueco bajo una plataforma).
    if shaderOk and waterShader then
        waterShader:send('time',     t)
        waterShader:send('strength', 0.001)
        waterShader:send('speed',    1.2)
        love.graphics.setShader(waterShader)
    end
    for row = sr2, er2 do
        for col = sc2, ec2 do
            local m = liquidOfRaw(self:getRaw(col, row))
            if m and m.distort then
                local px = math.floor((col-1)*TILE_PX - camX)
                local py = math.floor((row-1)*TILE_PX - camY)
                -- (en la superficie, sin distorsión justo bajo la ola)
                local cut = self:isWaterSurfaceCell(col, row) and WaterSurface.MARGIN or 0
                setTransformedScissor(px, py + cut, TILE_PX, TILE_PX - cut)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(sceneCanvas, 0, 0)
            end
        end
    end
    Floods.renderDistort(self, camX, camY, sceneCanvas, setTransformedScissor, Level.liquidOfCell)
    setTransformedScissor()
    if shaderOk and waterShader then love.graphics.setShader() end

    -- Tinte: una sola pasada, color uniforme por material (sin acumulación)
    for row = sr2, er2 do
        for col = sc2, ec2 do
            local m = liquidOfRaw(self:getRaw(col, row))
            if m and m.tint then
                if self:isWaterSurfaceCell(col, row) then
                    -- Superficie con olas (el tinte sigue a la ola: sin borde plano detrás)
                    WaterSurface.draw((col-1)*TILE_PX, col*TILE_PX, (row-1)*TILE_PX, row*TILE_PX,
                                      camX, camY, m.tint, 2, t)
                else
                    -- Alineado al píxel igual que la franja de la superficie (si
                    -- no, con la cámara en posiciones fraccionarias quedaba una
                    -- rendija de 1 px entre la superficie y el agua de debajo)
                    love.graphics.setColor(m.tint)
                    local x0, y0 = math.floor((col-1)*TILE_PX - camX), math.floor((row-1)*TILE_PX - camY)
                    love.graphics.rectangle('fill', x0, y0, math.floor(col*TILE_PX - camX) - x0,
                                            math.floor(row*TILE_PX - camY) - y0)
                end
            end
        end
    end

    Floods.renderTint(self, camX, camY, Level.liquidOfCell)

    -- (Los pinchos de celdas con agua ya están en la escena: reciben la
    -- distorsión y el tinte igual que el resto de lo que hay bajo el agua.)

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

-- ── Decoraciones: animación y dibujo ────────────────────────────────────────
function Level:updateFoliage(dt)
    for _, d in ipairs(self.decorations) do
        d.animT = d.animT + dt
        if d.def.update then d.def.update(d, dt) end
    end
end

-- Dibuja las decoraciones de una capa: 'front' (por encima de jugador y
-- enemigos) o 'back' (detrás de ellos, justo después del nivel).
function Level:renderDecorations(camX, camY, layer)
    for _, d in ipairs(self.decorations) do
        if d.layer == layer then
            local sx = math.floor(d.x - camX)
            local sy = math.floor(d.y - camY)
            local m  = TILE_PX * d.def.cullMargin
            if sx > -m and sx < WINDOW_W + m and sy > -m and sy < WINDOW_H + m then
                d.def.draw(d, sx, sy)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Level:renderFoliage(camX, camY)     self:renderDecorations(camX, camY, 'front') end
function Level:renderFoliageBack(camX, camY) self:renderDecorations(camX, camY, 'back')  end

return Level