-- src/world/PhaseBlocks.lua
-- BLOQUES DE FASE: casillas del nivel que NO están hasta que el jefe de su zona llega a
-- una fase (p. ej. el Activador de los congeladores de la Gran Bola de Nieve, que solo
-- aparece en la fase 3). Se colocan con la entidad 'phaseblock' (Mecanismos): un
-- rectángulo (su casilla = esquina superior izquierda, `corner` = inferior derecha),
-- `phase` (la fase del jefe con la que aparecen), `zone` (id de la zona, 0 = la que lo
-- contiene / la más cercana) y `hiddenAs` (lo que hay en su sitio mientras tanto:
-- vacío, hielo, nieve, piedra... para esconder un Activador en el suelo sin dejar hueco).
--
-- En el editor las casillas se ven tal cual (se dibujan y se conectan como siempre); al
-- cargar el nivel en la partida (un jugador, servidor y cliente online, a la vez y de la
-- misma forma) se guardan y se cambian por `hiddenAs`. Al llegar la fase, el controlador
-- de las zonas de jefe (un jugador / servidor) las pone de nuevo: cambio de tile 'set'
-- que llega a los clientes como cualquier otro, con un saltito, chispas y sonido.
-- Una casilla ocupada (un jugador, un cuerpo sólido) espera a que se aparte.

local TileTypes = require 'src/world/tiles/TileTypes'
local TileCodec = require 'src/world/tiles/TileCodec'

local PhaseBlocks = {}

-- Lo que puede ocupar su sitio mientras no han aparecido (nombres de tile)
PhaseBlocks.HIDDEN_AS = { 'empty', 'ice', 'snow', 'solid', 'dirt', 'grass', 'sand' }

local function corner(p, col, row)
    local c = p.corner
    if type(c) == 'table' and tonumber(c.col) and tonumber(c.row) then return tonumber(c.col), tonumber(c.row) end
    return col, row
end

-- Desde las colocaciones (Level.fromData). `editor` = no esconder nada (el editor las ve).
function PhaseBlocks.build(level, entities, editor)
    local list = {}
    for _, e in ipairs(entities or {}) do
        if e.type == 'phaseblock' then
            local p = e.props or {}
            local c1, r1 = corner(p, e.col, e.row)
            local b = {
                c0 = math.min(e.col, c1), r0 = math.min(e.row, r1),
                c1 = math.max(e.col, c1), r1 = math.max(e.row, r1),
                phase = tonumber(p.phase) or 2, zone = tonumber(p.zone) or 0,
                hiddenAs = p.hiddenAs or 'empty', cells = {}, shown = false,
            }
            local hid = TileTypes.byName[b.hiddenAs] or TileTypes.byName.empty
            for r = b.r0, b.r1 do
                for c = b.c0, b.c1 do
                    if level.tiles[r] and level.tiles[r][c] then
                        b.cells[#b.cells + 1] = { c = c, r = r, raw = level.tiles[r][c], done = false }
                        if not editor then level.tiles[r][c] = TileCodec.encode(hid.id) end
                    end
                end
            end
            list[#list + 1] = b
        end
    end
    return #list > 0 and list or nil
end

local function containsCell(z, c, r)
    local T = TILE_PX
    local x, y = (c - 0.5) * T, (r - 0.5) * T
    return x >= z.x0 and x <= z.x1 and y >= z.y0 and y <= z.y1
end

-- Zona de jefe de un bloque de fase (por id, o la que lo contiene, o la más cercana)
function PhaseBlocks.zoneOf(level, b)
    local zones = level.bossZones or {}
    if b.zone and b.zone > 0 then
        for _, z in ipairs(zones) do if z.id == b.zone then return z end end
    end
    local best, bd
    for _, z in ipairs(zones) do
        if containsCell(z, b.c0, b.r0) then return z end
        local T = TILE_PX
        local d = math.abs((z.x0 + z.x1) / 2 - (b.c0 - 0.5) * T) + math.abs((z.y0 + z.y1) / 2 - (b.r0 - 0.5) * T)
        if not bd or d < bd then best, bd = z, d end
    end
    return best
end

-- Un jugador / servidor (lo llama el controlador de las zonas de jefe): aparecen
-- los que ya toca. Devuelve true si cambió algún tile.
function PhaseBlocks.update(level)
    if not level.phaseBlocks or level.canBreak == false then return false end
    local changed = false
    for _, b in ipairs(level.phaseBlocks) do
        if not b.shown then
            local z = PhaseBlocks.zoneOf(level, b)
            if z and (z.phase or 1) >= b.phase then
                local all = true
                for _, cell in ipairs(b.cells) do
                    if not cell.done then
                        if level:cellOccupied(cell.c, cell.r) then
                            all = false                          -- (alguien dentro: luego)
                        else
                            cell.done = true
                            level:setTileRaw(cell.c, cell.r, cell.raw)
                            level.brokenQueue = level.brokenQueue or {}
                            table.insert(level.brokenQueue, { cell.c, cell.r, cell.raw, 'set' })
                            level:tileBump(cell.c, cell.r, 'head')
                            local Entity = require 'src/world/entities/Entity'
                            Entity.emitFx('spawn', (cell.c - 0.5) * TILE_PX, (cell.r - 0.5) * TILE_PX)
                            changed = true
                        end
                    end
                end
                if changed then
                    local d = level:getDef(b.cells[1].c, b.cells[1].r)
                    if d.toggle then
                        local Entity = require 'src/world/entities/Entity'
                        Entity.emitFx('switch_hit', (b.cells[1].c - 1) * TILE_PX, (b.cells[1].r - 1) * TILE_PX)
                    end
                    Sound.play('switchOn', 0.8)
                end
                b.shown = all
            end
        end
    end
    if changed then level:initSwitchBlocks() end
    return changed
end

return PhaseBlocks
