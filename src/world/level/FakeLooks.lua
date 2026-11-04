-- src/world/level/FakeLooks.lua
-- El ASPECTO de las PAREDES FALSAS (tile `fake_solid`, 20; el usuario, 2026-11-03: "por defecto todas son piedra y no
-- combinan"). Solo dibujo: la colisión no cambia (no tienen). Por cada GRUPO de paredes falsas (las que se tocan):
--   · AUTO (por defecto): se ve como el bloque sólido de verdad que más lo rodea (ladrillo del templo, nieve, basalto…);
--     así los niveles que ya las usan combinan sin tocarlos. Sin vecinos sólidos: piedra, como antes.
--   · ELEGIDO en el editor (tecla V sobre una pared falsa: Auto → cada bloque sólido del catálogo): el nivel lo guarda en
--     `fakeLooks = { { col, row, look = '<nombre del tile>' } }` (una celda del grupo basta).
-- level.fakeLook[r * 65536 + c] = el tile que se dibuja en su lugar (Level:getLookDef; LevelRender y las uniones de
-- los bordes — TileTypes.joinsCell — lo miran, así un ladrillo de verdad y uno falso no dibujan borde entre ellos).
local TileTypes = require 'src/world/tiles/TileTypes'
local TileCodec = require 'src/world/tiles/TileCodec'

local FakeLooks = {}
local FAKE = 'fake_solid'

-- Los aspectos que se pueden elegir: los bloques sólidos normales del catálogo (sin trampas, mecanismos ni especiales)
function FakeLooks.choices()
    local out = {}
    for _, t in ipairs(TileTypes.list or {}) do
        if t.collision == 'solid' and not t.fake and not t.toggle and not t.breakable and not t.trigger and not t.thinIce
           and not t.hidden and t.category ~= 'Mecanismos' and t.category ~= 'Trampas' and t.name ~= 'border' then
            out[#out + 1] = t.name
        end
    end
    return out
end

local function isFake(level, c, r)
    local raw = level:getRaw(c, r)
    return raw and TileTypes.get(TileCodec.id(raw)).name == FAKE
end

-- El grupo de paredes falsas que toca (c, r): lista de claves y el tile más común alrededor
local function group(level, c0, r0, seen)
    local cells, count, best, bestN = {}, {}, nil, 0
    local stack = { { c0, r0 } }
    seen[r0 * 65536 + c0] = true
    while #stack > 0 do
        local p = table.remove(stack)
        local c, r = p[1], p[2]
        cells[#cells + 1] = r * 65536 + c
        for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
            local nc, nr = c + d[1], r + d[2]
            local k = nr * 65536 + nc
            if nc >= 1 and nr >= 1 and nc <= level.tileW and nr <= level.tileH then
                if isFake(level, nc, nr) then
                    if not seen[k] then seen[k] = true; stack[#stack + 1] = { nc, nr } end
                else
                    local n = TileTypes.get(TileCodec.id(level:getRaw(nc, nr)))
                    if n.collision == 'solid' and not n.fake and not n.toggle and not n.trigger then
                        count[n.name] = (count[n.name] or 0) + 1
                        if count[n.name] > bestN then best, bestN = n.name, count[n.name] end
                    end
                end
            end
        end
    end
    return cells, best
end

-- Calcula el aspecto de cada pared falsa del nivel. `chosen` = la lista `fakeLooks` del nivel
function FakeLooks.build(level, chosen)
    level.fakeLook = nil
    local pick = {}
    for _, e in ipairs(chosen or {}) do
        local c, r = tonumber(e.col), tonumber(e.row)
        if c and r and TileTypes.byName[e.look] then pick[r * 65536 + c] = e.look end
    end
    local seen = {}
    for r = 1, level.tileH do
        for c = 1, level.tileW do
            if not seen[r * 65536 + c] and isFake(level, c, r) then
                local cells, auto = group(level, c, r, seen)
                local look = auto
                for _, k in ipairs(cells) do if pick[k] then look = pick[k] end end
                local def = look and TileTypes.byName[look]
                if def then
                    level.fakeLook = level.fakeLook or {}
                    for _, k in ipairs(cells) do level.fakeLook[k] = def end
                end
            end
        end
    end
end

-- El grupo (claves) de la pared falsa en (c, r), o nil: para el editor
function FakeLooks.groupAt(level, c, r)
    if not isFake(level, c, r) then return nil end
    return (group(level, c, r, {}))
end

return FakeLooks
