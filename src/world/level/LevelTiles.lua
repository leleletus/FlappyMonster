-- src/world/level/LevelTiles.lua
-- PARTE de src/world/level/Level.lua: los tiles que CAMBIAN durante la partida — bloques rompibles, bloques ON/OFF, hielo fino, bloques invisibles.
-- La carga Level.lua con require(...)(Level, P): añade sus funciones a la tabla Level. P = lo que
-- antes eran locales del archivo y comparten las partes.

return function(Level, P)
local TileCodec, TileTypes, decTile, tileBaseId, hasSpikes, spikeHitbox = P.TileCodec, P.TileTypes, P.decTile, P.tileBaseId, P.hasSpikes, P.spikeHitbox

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
    self:rememberTile(col, row, raw)
    self.tiles[row][col] = new
    self.brokenQueue = self.brokenQueue or {}
    table.insert(self.brokenQueue, { col, row, new })
    local Noise = require 'src/world/systems/Noise'
    Noise.emit((col - 0.5) * TILE_PX, (row - 0.5) * TILE_PX, Noise.R.tile)       -- (romper un bloque se oye)
    -- Enemigos de pie encima: mueren despedidos girando (no se quedan flotando)
    self:forStanders(col, row, function(e)
        local cx = (col - 0.5) * TILE_PX
        e:dieFling((e.x >= cx) and 1 or -1)
    end)
    return true
end

-- Entidades de suelo (enemigos: Crabby, Gummy...) de pie sobre la casilla
-- (col, row). Solo donde se deciden los tiles (un jugador / servidor).
function Level:forStanders(col, row, fn)
    for _, e in ipairs(self.liveEntities or {}) do
        -- (por defecto los enemigos que no son jefes ni bloques; un tipo lo cambia con el rasgo
        -- `diesWithBlock = true / false`. Los trepadores: el bloque al que se agarran)
        local on = e.diesWithBlock
        if on == nil then on = e.def and e.def.category == 'Enemigos' and not e.def.boss and not e.solidFull end
        if on and e.standingOnCell and e:standingOnCell(col, row) then
            fn(e)
        end
    end
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
    -- Hielo fino: un ground pound encima avanza 3 estados; un cabezazo, 1
    if def.thinIce then return self:crackIce(col, row, (from == 'pound') and 3 or 1, from) end
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
    require('src/world/systems/Noise').emit((col - 0.5) * TILE_PX, (row - 0.5) * TILE_PX, require('src/world/systems/Noise').R.switch)
    -- Enemigos encima del activador: un saltito con el golpe (no mueren)
    self:forStanders(col, row, function(e)
        if e.releaseCrawl then e:releaseCrawl() end
        e.vy, e.onGround = -380, false
    end)
    self:updateSwitchBlocks()
    return 'toggle'
end

-- ── Bloques ON/OFF (tiles con `switchBlock`) ─────────────────────────────────
-- Cada uno depende de un activador (switch_on / switch_off): el conectado en
-- el editor (JSON "blockLinks": [{col, row, from = {c, r}}]) o, si no, el más
-- cercano. Activo = sólido (Bloque ON con el activador en ON; Bloque OFF con
-- él en OFF); inactivo = se atraviesa. El cambio es un cambio de tile: en el
-- servidor va a brokenQueue ('set': sin efectos) y los clientes lo aplican.
local function isActivator(def) return def.name == 'switch_on' or def.name == 'switch_off' end

function Level:initSwitchBlocks()
    self.switchBlocks = nil
    local acts, blocks = {}, {}
    for r = 1, self.tileH do
        for c = 1, self.tileW do
            local d = self:getDef(c, r)
            if isActivator(d) then acts[#acts + 1] = { c, r }
            elseif d.switchBlock then blocks[#blocks + 1] = { c, r } end
        end
    end
    if #blocks == 0 then return end
    self.switchBlocks = {}
    for _, b in ipairs(blocks) do
        local src = self.blockLinks and self.blockLinks[b[2] * 65536 + b[1]]
        if src and not isActivator(self:getDef(src[1], src[2])) then src = nil end
        if not src then
            local bd
            for _, a in ipairs(acts) do
                local d = (a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2
                if not bd or d < bd then src, bd = a, d end
            end
        end
        self.switchBlocks[#self.switchBlocks + 1] = { c = b[1], r = b[2], src = src }
    end
    self:updateSwitchBlocks(true)
end

-- ¿Hay un jugador o una entidad sólida dentro de la celda?
function Level:cellOccupied(c, r)
    local T = TILE_PX
    local x0, y0 = (c - 1) * T, (r - 1) * T
    local function hit(b) return b.x < x0 + T and b.x + b.w > x0 and b.y < y0 + T and b.y + b.h > y0 end
    for _, pa in ipairs(self.players or {}) do
        if pa.alive ~= false and not pa.dying and hit(pa:getOuterBounds()) then return true end
    end
    for _, e in ipairs(self.liveEntities or {}) do
        if e.alive and e.isObstacle and e:isObstacle() and hit(e:getOuterBounds()) then return true end
    end
    return false
end

-- Pone cada Bloque ON/OFF en su estado según su activador. `silent` = al cargar
-- (sin cola: todos parten igual)
function Level:updateSwitchBlocks(silent)
    for _, b in ipairs(self.switchBlocks or {}) do
        local def = self:getDef(b.c, b.r)
        local sb = def.switchBlock
        if sb then
            local on = b.src and self:getDef(b.src[1], b.src[2]).name == 'switch_on' or false
            local want = (sb.kind == 'on') == on
            -- (no se vuelve sólido con alguien dentro: espera a que se aparte)
            b.pending = want and not sb.active and not silent and self:cellOccupied(b.c, b.r)
            if want ~= sb.active and not b.pending then
                local to = TileTypes.byName[sb.other]
                local _, water, spikes = decTile(self:getRaw(b.c, b.r))
                local new = TileCodec.encode(to.id, water, spikes)
                self.tiles[b.r][b.c] = new
                if not silent then
                    self.brokenQueue = self.brokenQueue or {}
                    table.insert(self.brokenQueue, { b.c, b.r, new, 'set' })
                end
            end
        end
    end
end

-- ── Hielo fino (tiles con `thinIce`, ver tiles/types/thin_ice.lua) ──────────
-- Avanza `n` estados; del último se rompe. Solo donde se deciden los tiles (un
-- jugador / servidor): el cambio va a brokenQueue con su tipo ('crack' /
-- 'icebreak') y los clientes ponen el tile, la animación, partículas y sonido.
-- En un jugador, `self.tileFx(kind, c, r)` (lo pone AdventureState) hace esos
-- efectos. Devuelve 'crack' | 'break' | nil.
Level.THIN_ICE_WEAR = 0.8          -- s de pie encima por estado
function Level:crackIce(col, row, n, from)
    if self.canBreak == false then return nil end
    local def = self:getDef(col, row)
    if not def.thinIce or not (self.tiles[row] and self.tiles[row][col]) then return nil end
    local raw = self:getRaw(col, row)
    local _, water, spikes = decTile(raw)
    local stage = def.thinIce.stage + (n or 1)
    local kind, new
    if stage >= 4 then
        self:rememberTile(col, row, raw)
        new = water and TILE_WATER or TILE_EMPTY
        kind = 'icebreak'                                      -- (los de encima simplemente caen)
    else
        local name = ({ 'thin_ice', 'thin_ice_1', 'thin_ice_2', 'thin_ice_3' })[stage + 1]
        new = TileCodec.encode(TileTypes.byName[name].id, water, spikes)
        kind = 'crack'
    end
    self.tiles[row][col] = new
    if self.iceWear then self.iceWear[row * 65536 + col] = nil end
    self.brokenQueue = self.brokenQueue or {}
    table.insert(self.brokenQueue, { col, row, new, kind, from })
    if from ~= 'wear' then                             -- (el hielo que cruje / se rompe se oye; el desgaste de estar encima, no)
        local Noise = require 'src/world/systems/Noise'
        Noise.emit((col - 0.5) * TILE_PX, (row - 0.5) * TILE_PX, (kind == 'icebreak') and Noise.R.icebreak or Noise.R.crack)
    end
    if kind == 'crack' then self:tileBump(col, row, 'crack') end
    if self.tileFx then self.tileFx(kind, col, row) end
    return (kind == 'icebreak') and 'break' or 'crack'
end

-- Desgaste: cada jugador de pie encima de hielo fino lo va agrietando
function Level:updateThinIce(dt)
    if self.canBreak == false or not self.players then return end
    local T = TILE_PX
    local touched = {}
    for _, pa in ipairs(self.players) do
        if pa.onGround and not pa.dying and pa.alive ~= false and pa.getOuterBounds then
            local b = pa:getOuterBounds()
            local fy = b.y + b.h + 2
            for _, fx in ipairs({ b.x + 3, b.x + b.w / 2, b.x + b.w - 3 }) do
                local c, r = math.floor(fx / T) + 1, math.floor(fy / T) + 1
                local d = self:getDef(c, r)
                if d.thinIce and math.abs(fy - 2 - (r - 1) * T) <= 4 then touched[r * 65536 + c] = { c, r } end
            end
        end
    end
    for k, cr in pairs(touched) do
        self.iceWear = self.iceWear or {}
        self.iceWear[k] = (self.iceWear[k] or 0) + dt
        if self.iceWear[k] >= Level.THIN_ICE_WEAR then self:crackIce(cr[1], cr[2], 1, 'wear') end
    end
end

-- Animación de un bloque golpeado (solo dibujo): 'head' = saltito hacia arriba,
-- 'pound' = el mismo hacia abajo. La pone quien golpea (un jugador) o el
-- evento del servidor (online); Level:update la hace avanzar.
local BUMP_T = { head = 0.22, pound = 0.22, crack = 0.35 }     -- (crack: el hielo fino tiembla)
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
    if self.tiles[row] and self.tiles[row][col] ~= nil then
        if self.tiles[row][col] ~= raw then self:rememberTile(col, row, self.tiles[row][col]) end
        self.tiles[row][col] = raw
    end
end

-- Lo que había en una celda antes de cambiarla (solo dibujo: de qué color
-- salen los trozos de un bloque roto; ver Particles 'block_break')
function Level:rememberTile(col, row, raw)
    self.prevTiles = self.prevTiles or {}
    self.prevTiles[row * 65536 + col] = raw
end
function Level:previousDef(col, row)
    local raw = self.prevTiles and self.prevTiles[row * 65536 + col]
    return raw and TileTypes.get(tileBaseId(raw)) or nil
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
end
