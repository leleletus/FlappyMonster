-- src/player/DamageSource.lua
-- LA FUENTE DEL DAÑO (0.5.205, docs/design/damage-sources.md; el usuario: que el aviso de la muerte diga EXACTAMENTE qué
-- fue — el pincho del suelo, el que cae, el del Crabby, la espina del pez globo o su proyectil…). Cada golpe al jugador
-- lleva { what, part }: QUÉ (un tipo de entidad, un tile — la lava es el tile `danger` — o una causa: fall, drown, time, crush, explosion,
-- spikes) y QUÉ PARTE
-- (body, spike, projectile…; nil en tiles y causas). El jugador guarda la del último golpe que ENTRÓ (pa.lastHit).
-- Sin dibujo (lo comparten un jugador, el servidor y el cliente).
--   DamageSource.make(what, part) → src          DamageSource.of(entity, part) → src (what = su tipo)
--   DamageSource.encode(src) → número (0 = nada) / decode(n) → src | nil   (viaja en el estado propio online)
--   DamageSource.text(src) → texto traducido | nil   (el aviso de la muerte: src/player/DeathCause.lua)
local DS = {}

DS.CAUSES = { 'crush', 'drown', 'explosion', 'fall', 'spikes', 'time' }   -- (spikes: los pinchos del suelo — subtiles —)
-- (las partes: una más = una línea aquí + su texto `part.<parte>` en assets/lang/translations.csv)
DS.PARTS = { 'beam', 'bite', 'blast', 'body', 'claw', 'dash', 'fire', 'gust', 'hazard', 'ice', 'pound', 'projectile',
             'shock', 'slam', 'spike', 'stomp', 'wave' }
local PART_IX = {}
for i, p in ipairs(DS.PARTS) do PART_IX[p] = i end

function DS.make(what, part) return { what = what, part = part } end
function DS.of(e, part)
    local d = e and e.def
    return { what = (d and d.name) or (e and e.type) or 'enemy', part = part }
end

-- El registro (igual en todas las máquinas de la misma versión): las causas, los tipos de entidad y los tiles, ordenados
local WHATS, WHAT_IX
local function registry()
    if WHATS then return end
    local seen, list = {}, {}
    local function add(n) if type(n) == 'string' and not seen[n] then seen[n] = true; list[#list + 1] = n end end
    for _, c in ipairs(DS.CAUSES) do add(c) end
    pcall(require, 'src/world/entities/Entities')            -- (carga el catálogo de entidades: registra sus tipos)
    local ok, ET = pcall(require, 'src/world/entities/base/EntityTypes')
    if ok and ET.byName then for n in pairs(ET.byName) do add(n) end end
    local ok2, TT = pcall(require, 'src/world/tiles/TileTypes')
    if ok2 and TT.byName then for n in pairs(TT.byName) do add(n) end end
    table.sort(list)
    WHATS, WHAT_IX = list, {}
    for i, n in ipairs(list) do WHAT_IX[n] = i end
end

local STRIDE = #DS.PARTS + 1
function DS.encode(src)
    if not src or not src.what then return 0 end
    registry()
    local w = WHAT_IX[src.what]
    if not w then return 0 end
    return w * STRIDE + (PART_IX[src.part] or 0)
end

function DS.decode(n)
    n = tonumber(n) or 0
    if n <= 0 then return nil end
    registry()
    local w, p = math.floor(n / STRIDE), n % STRIDE
    local what = WHATS[w]
    if not what then return nil end
    return { what = what, part = DS.PARTS[p] }
end

function DS.text(src)
    return nil                                   -- (Task 4)
end

return DS
