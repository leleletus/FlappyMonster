-- src/world/level/Level.lua
-- Nivel: carga el JSON, responde consultas de física (colisión, líquidos,
-- pinchos) y dibuja los tiles. El significado de cada tile (colisión,
-- material, aspecto) vive en el catálogo de tiles (src/world/tiles/Tiles.lua) y el
-- formato de cada celda en src/world/tiles/TileCodec.lua.

local json      = require 'libs/json'
local Tiles     = require 'src/world/tiles/Tiles'
local TileCodec = Tiles.codec
local TileTypes = Tiles.types
local Materials = Tiles.materials
local EntityTypes = require('src/world/entities/Entities').types   -- carga el catálogo
local DecorationTypes = require('src/world/decorations/Decorations').types
local PhaseBlocks = require 'src/world/systems/PhaseBlocks'
local BossZones = require 'src/world/systems/BossZones'
local AutoScroll = require 'src/world/systems/AutoScroll'
local Floods     = require 'src/world/systems/Floods'
local PointAreas = require 'src/world/systems/PointAreas'
local SubTiles   = require 'src/world/level/SubTiles'
local SpikeSkins = require 'src/world/level/SpikeSkins'
local WaterSurface = require 'src/fx/WaterSurface'

local Level = {}
local P = {}        -- locales de archivo que comparten las partes (ver abajo "Partes")
local loadWaterShader, loadBubbleImgs, loadVentImg, VENT_NORM_SPAWN_MIN, VENT_NORM_SPAWN_MAX, VENT_OXY_DELAY_MIN, VENT_OXY_DELAY_MAX, findWaterBodies      -- (de las partes: se rellenan al cargarlas)
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

-- ── Constructor ───────────────────────────────────────────────────────────────
-- La luz ambiente de un nivel (ver Level.fromData; el editor la usa para su opción "Luz")
Level.LIGHTS = { day = true, dusk = true, night = true, cave = true, none = true }
function Level.lightMood(lvl)
    if Level.LIGHTS[lvl.light or ''] then return lvl.light end
    if lvl.background == 'cave' then return 'cave' end
    if lvl.time == 'dusk' or lvl.time == 'night' then return lvl.time end
    return 'day'
end

function Level.new(path, difficulty)
    local data = love.filesystem.read(path)
    assert(data, "No se pudo leer: "..tostring(path))
    return Level.fromData(json.decode(data), difficulty)
end

-- Construye el nivel desde la tabla ya decodificada (el editor la usa para
-- mostrar su nivel en memoria sin guardarlo). `difficulty` (src/core/Difficulty.lua) se conoce YA al construirlo
-- porque cambia QUÉ hay en el nivel (Xtra extremo: un segundo jefe, src/world/systems/XtraBosses.lua); servidor,
-- cliente y un jugador lo construyen igual, con los mismos índices.
function Level.fromData(lvl, difficulty)
    local self = setmetatable({}, Level)
    loadWaterShader()
    loadBubbleImgs()
    loadVentImg()
    self.name        = lvl.name or "?"
    self.name_en     = lvl.name_en                      -- (nombre en inglés; ver Lang.localName)
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
    local Difficulty = require 'src/core/Difficulty'
    self.difficulty = Difficulty.valid(difficulty) and difficulty or nil
    if Difficulty.of(self.difficulty, 'bossExtra', false) then
        require('src/world/systems/XtraBosses').apply(self, lvl)
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
    -- Subtiles: bloques de un cuarto de casilla (src/world/level/SubTiles.lua)
    SubTiles.build(self, lvl.subtiles)
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
                -- (`ventDelay` de la dificultad: en las altas las burbujas de aire tardan más en salir)
                oxyTimer   = VENT_OXY_DELAY_MIN + math.random()*(VENT_OXY_DELAY_MAX-VENT_OXY_DELAY_MIN),
                oxyDelay   = (VENT_OXY_DELAY_MIN + math.random()*(VENT_OXY_DELAY_MAX-VENT_OXY_DELAY_MIN)) * Difficulty.of(self.difficulty, 'ventDelay', 1),
            })
        end
    end
    -- ── Decoraciones (catálogo src/world/decorations/Decorations.lua) ────────────────────
    -- El JSON las guarda en "foliage". Tipos desconocidos se omiten.
    self.decorations = {}
    for _, fd in ipairs(lvl.foliage or {}) do
        local n = DecorationTypes.normalize(fd)
        if n then
            local d = DecorationTypes.instantiate(n)
            d.level = self          -- (gotas y burbujas miran el suelo y el agua)
            table.insert(self.decorations, d)
        end
    end
    self.foliage = self.decorations   -- alias de compatibilidad
    -- Zonas de jefe (src/world/systems/BossZones.lua)
    self.bossZones = BossZones.build(lvl.bossZones)
    -- Cámara automática (src/world/systems/AutoScroll.lua), o nil
    self.autoScroll = AutoScroll.build(lvl.autoScroll, self)
    -- Inundaciones (src/world/systems/Floods.lua): salen de las entidades 'flood'
    self.floods = Floods.build(self.entities, Materials)
    self.floodTime = 0
    -- Conexiones de bloques ON/OFF con objetos activables (entidades con
    -- `activatable`, p. ej. inundaciones): { {col, row, to = id}, ... }
    -- (`flood` = nombre antiguo de `to`)
    self.links = {}
    for _, l in ipairs(lvl.links or {}) do
        local c, r, id = tonumber(l.col), tonumber(l.row), tonumber(l.to or l.flood)
        if c and r and id then self.links[#self.links + 1] = { col = c, row = r, to = id } end
    end
    Floods.link(self)
    -- Bloques ON/OFF: su activador (conectado en el editor, o el más cercano)
    self.blockLinks = {}
    for _, l in ipairs(lvl.blockLinks or {}) do
        local c, r, f = tonumber(l.col), tonumber(l.row), l.from
        if c and r and type(f) == 'table' and tonumber(f[1]) and tonumber(f[2]) then
            self.blockLinks[r * 65536 + c] = { tonumber(f[1]), tonumber(f[2]) }
        end
    end
    -- Bloques de fase (src/world/systems/PhaseBlocks.lua): esconde las casillas que salen
    -- con una fase del jefe (antes de buscar los Activadores)
    self.phaseBlocks = PhaseBlocks.build(self, self.entities, lvl._editor)
    self:initSwitchBlocks()
    -- Zonas de puntos (src/world/systems/PointAreas.lua): entidades 'pointarea'
    self.pointAreas = PointAreas.build(self.entities)
    -- Modos en los que se ofrece (nil = todos los que admitan el nivel) y
    -- duración de las partidas con tiempo (Rey de la Colina), en segundos
    self.modes     = type(lvl.modes) == 'table' and #lvl.modes > 0 and lvl.modes or nil
    self.matchTime = tonumber(lvl.matchTime)
    -- Música del nivel: id de assets/music/index.json (nil = la de siempre)
    self.music     = type(lvl.music) == 'string' and lvl.music or nil
    self.snow      = lvl.snow == true                  -- (nieve cayendo: src/fx/Snowfall.lua, solo visual)
    self.parTime   = tonumber(lvl.parTime)             -- (tiempo objetivo del nivel, s: la nota del modo historia; nil = según su ancho)
    self.peaceful  = lvl.peaceful == true              -- (enemigos INOFENSIVOS: niveles de prueba; Interactions.check)
    self.dark      = lvl.dark == true                  -- (nivel a OSCURAS: linternas, src/world/level/Lights.lua; afecta al juego)
    -- LUZ AMBIENTE (solo visual, src/fx/Darkness.lua): "light": day | dusk | night | cave | none; sin ella, de su
    -- hora ("time") y, con fondo de cueva, cueva. La profundidad (debajo de la superficie) va en penumbra.
    self.light     = Level.lightMood(lvl)
    -- (ECO en los sonidos, Sound.setEcho: por defecto, el de las cuevas — a oscuras o en penumbra —; "echo": true/false lo fuerza)
    self.echo      = lvl.echo == true or (lvl.echo == nil and (lvl.dark == true or self.light == 'cave'))
    self.spikeSkin = lvl.spikeSkin                     -- (aspecto de los pinchos: src/world/level/SpikeSkins.lua, solo visual)
    self.background, self.timeOfDay, self.clouds = lvl.background, lvl.time, lvl.clouds   -- (fondo y hora: src/fx/Sky.lua)
    self.depth, self.surfaceRow = lvl.depth, tonumber(lvl.surfaceRow)                    -- (fondo de profundidad y su línea)
    return self
end

-- ── Suelo seguro para reaparecer ─────────────────────────────────────────────
-- ¿Cabe un jugador de pie en la celda (c, r)? (ella y la de encima libres,
-- sin peligros ni pinchos, y algo firme debajo)
function Level:isStandable(c, r)
    for rr = r - 1, r do
        local d = self:getDef(c, rr)
        if d.collision == 'solid' or d.mat.contact or d.trigger then return false end
        if SubTiles.solidInCell(self, c, rr) then return false end
        if self:hasSpikeCellInBox((c - 1) * TILE_PX + 1, (rr - 1) * TILE_PX + 1, TILE_PX - 2, TILE_PX - 2) then return false end
    end
    local below = self:getDef(c, r + 1)
    local sb = self.subSolid and self.subSolid[SubTiles.key(c, r + 1)]
    return below.collision == 'solid' or below.collision == 'oneway' or (sb ~= nil and (sb[1] ~= nil or sb[2] ~= nil))
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

-- ── Conexiones (bloques ON/OFF → objetos activables) ─────────────────────────
-- Casillas de los bloques conectados al objeto `id`
function Level:linkedCells(id)
    local out = {}
    for _, l in ipairs(self.links or {}) do if l.to == id then out[#out + 1] = { l.col, l.row } end end
    return out
end
-- ¿Está encendido? (algún bloque conectado en ON). Autoritativo: un jugador y
-- el servidor (el cliente online recibe el resultado de cada objeto)
function Level:signal(id)
    for _, l in ipairs(self.links or {}) do
        if l.to == id and self:getDef(l.col, l.row).name == 'switch_on' then return true end
    end
    return false
end

-- Paredes invisibles en el punto: zona de jefe sin superar que lo contiene
-- o la ventana de la cámara automática. nil = ninguna.
-- ¿Sin control? (entrada de un jefe: ver BossZones.frozenAt)
function Level:frozenAt(wx, wy)
    return BossZones.frozenAt(self, wx, wy)
end

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

-- (con subtiles: en una celda sin colisión propia, la subcelda sólida que
-- contiene el punto; ver src/world/level/SubTiles.lua)
function Level:getDefAt(wx, wy)
    local t = TileTypes.get(self:getTileAt(wx, wy))
    if self.subSolid and t.collision == 'none' then
        local s = SubTiles.defAt(self, wx, wy)
        if s then return s end
    end
    return t
end

function Level:getSpawnPx()
    local sx=(self.playerStart[1]-1)*TILE_PX+TILE_PX/2
    local sy=(self.playerStart[2]-1)*TILE_PX+TILE_PX/2
    return sx, sy
end

-- ── Consultas de física ───────────────────────────────────────────────────────

-- Puntos donde mirar a lo largo de un lado de una caja, de a a b: los 3 de
-- siempre (extremos y centro) o, si el nivel tiene subtiles (bloques de medio
-- tile, 32 px), los que hagan falta para no saltarse ninguno
local SUB_STEP = 24
function Level:samples(a, b)
    if not self.subSolid or b - a <= 2 * SUB_STEP then return { a, (a + b) / 2, b } end
    local n = math.ceil((b - a) / SUB_STEP)
    local out = {}
    for i = 0, n do out[i + 1] = a + (b - a) * i / n end
    return out
end

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
local MID_Y, SUB_Y = { 0.5 }, { 0.25, 0.75 }     -- dónde mirar en cada celda (con subtiles: las dos mitades)
function Level:landingCross(wx, y0, y1)
    if y1 < y0 then return nil end
    local T = TILE_PX
    local col = math.floor(wx / T) + 1
    for r = math.floor(y0 / T), math.floor(y1 / T) do
        for _, fy in ipairs(SubTiles.solidInCell(self, col, r + 1) and SUB_Y or MID_Y) do
            local t = self:getDefAt(wx, r * T + fy * T)
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

-- ── Partes (el resto de Level.lua, por sistemas) ────────────────────
P.TileCodec = TileCodec; P.TileTypes = TileTypes; P.DIR_UP = DIR_UP; P.DIR_DOWN = DIR_DOWN; P.DIR_LEFT = DIR_LEFT
P.DIR_RIGHT = DIR_RIGHT; P.decTile = decTile; P.tileBaseId = tileBaseId; P.hasSpikes = hasSpikes; P.liquidOfRaw = liquidOfRaw
P.spikeHitbox = spikeHitbox
require('src/world/level/LevelTiles')(Level, P)
require('src/world/level/LevelWater')(Level, P)
require('src/world/level/LevelRender')(Level, P)
loadWaterShader, loadBubbleImgs, loadVentImg, VENT_NORM_SPAWN_MIN, VENT_NORM_SPAWN_MAX = P.loadWaterShader, P.loadBubbleImgs, P.loadVentImg, P.VENT_NORM_SPAWN_MIN, P.VENT_NORM_SPAWN_MAX
VENT_OXY_DELAY_MIN, VENT_OXY_DELAY_MAX, findWaterBodies = P.VENT_OXY_DELAY_MIN, P.VENT_OXY_DELAY_MAX, P.findWaterBodies

return Level