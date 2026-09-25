-- src/world/tiles/TileCodec.lua
-- Formato del número entero que guarda cada celda del nivel (JSON "tiles").
-- ÚNICO lugar que conoce los bits; motor y editor usan decode/encode.
--
--   bits 0-3   : id del tipo, parte baja  (id % 16)
--   bit  4     : waterlogged (la celda además está llena de agua)
--   bits 5-7   : pincho subcelda TL  (dir 2 bits + presente 1 bit)
--   bits 8-10  : pincho subcelda TR
--   bits 11-13 : pincho subcelda BL
--   bits 14-16 : pincho subcelda BR
--   bits 17-20 : id del tipo, parte alta  (floor(id / 16))  → ids 0..255
--
-- Los niveles antiguos (ids 0..15, bits 17+ a cero) se leen igual que antes.

local TileCodec = {}

TileCodec.MAX_ID     = 255
TileCodec.FLAG_WATER = 16
TileCodec.SUB_SHIFTS = { 5, 8, 11, 14 }     -- TL, TR, BL, BR
TileCodec.ID_HIGH    = 2^17

-- Direcciones de pincho
TileCodec.DIR_UP, TileCodec.DIR_DOWN, TileCodec.DIR_LEFT, TileCodec.DIR_RIGHT = 0, 1, 2, 3

local floor = math.floor

function TileCodec.id(raw)
    raw = floor(raw or 0)
    return raw % 16 + 16 * (floor(raw / TileCodec.ID_HIGH) % 16)
end

function TileCodec.isWaterlogged(raw)
    return floor(floor(raw or 0) / TileCodec.FLAG_WATER) % 2 == 1
end

-- Pincho de la subcelda i (1..4): presente, dirección
function TileCodec.spike(raw, i)
    local sh = TileCodec.SUB_SHIFTS[i]
    raw = floor(raw or 0)
    return floor(raw / 2^(sh + 2)) % 2 == 1, floor(raw / 2^sh) % 4
end

function TileCodec.hasSpikes(raw)
    for i = 1, 4 do
        if (TileCodec.spike(raw, i)) then return true end
    end
    return false
end

-- Decodifica todo: id, waterlogged, { {present, dir} x4 }
function TileCodec.decode(raw)
    local spikes = {}
    for i = 1, 4 do
        local present, dir = TileCodec.spike(raw, i)
        spikes[i] = { present = present, dir = dir }
    end
    return TileCodec.id(raw), TileCodec.isWaterlogged(raw), spikes
end

-- Codifica. spikes = { [i] = {present=bool, dir=0..3} } (opcional)
function TileCodec.encode(id, waterlogged, spikes)
    assert(id >= 0 and id <= TileCodec.MAX_ID, "id de tile fuera de rango: " .. tostring(id))
    local raw = id % 16 + floor(id / 16) * TileCodec.ID_HIGH
    if waterlogged then raw = raw + TileCodec.FLAG_WATER end
    for i = 1, 4 do
        local s = spikes and spikes[i]
        if s and s.present then
            local sh = TileCodec.SUB_SHIFTS[i]
            raw = raw + (s.dir % 4) * 2^sh + 2^(sh + 2)
        end
    end
    return raw
end

return TileCodec
