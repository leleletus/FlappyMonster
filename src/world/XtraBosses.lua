-- src/world/XtraBosses.lua
-- XTRA EXTREMO: DOS JEFES a la vez en cada arena (modificador `bossExtra` de src/Difficulty.lua).
-- Lo llama Level.fromData al construir el nivel (servidor, cliente y un jugador por igual: las colocaciones
-- nuevas van justo detrás de las del JSON, antes de los súbditos de reserva, así los índices coinciden).
--
-- De dónde sale el segundo:
--   * el nivel lo dice: JSON `"xtraBosses": [ { type, col, row, props } ]` (el editor de niveles no lo
--     toca: es para colocarlo a mano cuando el automático no sirve);
--   * si no, AUTOMÁTICO: cada jefe dentro de una zona de jefe se copia en ESPEJO respecto al centro de la
--     zona (al menos `MIN_SEP` casillas del original; si el espejo cae encima, hacia el lado con más sitio),
--     y sus puntos (`point` / `points`: rutas, destinos) también en espejo. Lo que es de la ARENA y no del
--     jefe (los carámbanos de la Bola de Nieve) se quita de la copia: el tipo lo dice con `xtraStrip`.
-- Los dos llevan `props.xtraPair` → cada uno con la vida × `pairHp` (Boss:startFight).
local EntityTypes = require 'src/world/entities/EntityTypes'

local XB = { MIN_SEP = 5, MARGIN = 2 }

local function zoneOf(zones, col, row)
    for _, z in ipairs(zones or {}) do
        local zc, zr, zw, zh = tonumber(z.col) or 0, tonumber(z.row) or 0, tonumber(z.w) or 0, tonumber(z.h) or 0
        if col >= zc and col < zc + zw and row >= zr and row < zr + zh then return zc, zr, zw, zh end
    end
end

local function copyTable(t)
    if type(t) ~= 'table' then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = copyTable(v) end
    return o
end

-- La copia automática de una colocación de jefe `n` (ya normalizada), o nil si no está en una zona
function XB.mirror(n, zones)
    local zc, zr, zw = zoneOf(zones, n.col, n.row)
    if not zc then return nil end
    local function mx(c) return 2 * zc + zw - 1 - c end
    local lo, hi = zc + XB.MARGIN, zc + zw - 1 - XB.MARGIN
    local col = mx(n.col)
    if math.abs(col - n.col) < XB.MIN_SEP then
        local dir = (n.col - zc < zc + zw - 1 - n.col) and 1 or -1     -- (hacia donde haya más sitio)
        col = n.col + dir * XB.MIN_SEP
    end
    col = math.max(lo, math.min(hi, col))
    local def = EntityTypes.byName[n.type]
    local props = copyTable(n.props)
    -- puntos del jefe, en espejo
    for _, sch in ipairs((def and def.schema) or {}) do
        local v = props[sch.key]
        if sch.kind == 'point' and type(v) == 'table' then
            v.col = mx(v.col)
        elseif sch.kind == 'points' and type(v) == 'table' then
            for _, q in ipairs(v) do q.col = mx(q.col) end
        elseif sch.kind == 'patrol' and type(v) == 'table' then
            v.left, v.right = mx(v.right), mx(v.left)
        end
    end
    for _, key in ipairs((def and def.xtraStrip) or {}) do
        props[key] = (type(props[key]) == 'table') and {} or nil
    end
    return { type = n.type, col = col, row = n.row, sub = n.sub, props = props }
end

function XB.apply(level, lvl)
    local add = {}
    if type(lvl.xtraBosses) == 'table' then
        for _, raw in ipairs(lvl.xtraBosses) do
            local m = EntityTypes.normalize(raw)
            if m then add[#add + 1] = m end
        end
    else
        for _, n in ipairs(level.entities) do
            local def = EntityTypes.byName[n.type]
            if def and def.category == 'Jefes' then
                local m = XB.mirror(n, lvl.bossZones)
                if m then n.props.xtraPair = true; add[#add + 1] = m end
            end
        end
    end
    for _, m in ipairs(add) do
        m.props.xtraPair, m.xtra = true, true
        level.entities[#level.entities + 1] = m
    end
    -- (con la lista a mano, los jefes de la zona también van de dos en dos)
    if type(lvl.xtraBosses) == 'table' then
        for _, n in ipairs(level.entities) do
            local def = EntityTypes.byName[n.type]
            if def and def.category == 'Jefes' then n.props.xtraPair = true end
        end
    end
    return #add
end

return XB
