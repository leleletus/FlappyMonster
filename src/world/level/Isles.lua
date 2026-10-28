-- src/world/level/Isles.lua
-- LAS ISLAS: el método GENÉRICO para todo lo que cambia según la isla del nivel (el usuario: uno para todos, sin
-- reglas sueltas en cada tipo). Dos maneras de cambiar, las dos aquí:
--
--  1. ASPECTO (y, si el tipo quiere, alguna regla) de UN tipo: el tipo pide `Isles.of(level, props.isle)` y carga
--     su arte de `<carpeta>/<isla>-….png`. Se declara con `isleArt = true` en la definición: EntityTypes le pone la
--     prop `isle` (Auto = la del nivel, o una isla fija). La Caja, la Balanza, el Soplón, la Semilla, el Géiser, el
--     Saltarín (su prop de siempre se llama `skin`), la comida…
--  2. FAMILIAS de tipos (cada isla tiene su propio Gummy, su Crabby…: tipos distintos, con su arte y a veces con sus
--     reglas): `Isles.FAMILIES` (datos). Todos los de una familia tienen la prop `isle` con 'self' por defecto (= se
--     queda como está: ningún nivel viejo cambia); con 'auto' u otra isla, al cargar el nivel se cambia por el de esa
--     isla (Isles.resolveAll, en Level — igual en un jugador, el servidor y el cliente: mismos índices —).
--     Una familia nueva = una línea en FAMILIES.
--
-- ¿De qué isla es un nivel? Del FONDO (`background`, src/fx/Sky.lua); con nieve (pinchos de hielo o nieve cayendo),
-- la nieve manda. Sin fondo: la pradera.
local Isles = {}

Isles.IDS = { 'pradera', 'costa', 'fortaleza', 'nieve', 'cueva', 'volcan' }
Isles.NAMES = { pradera = 'Pradera', costa = 'Costa', fortaleza = 'Fortaleza', nieve = 'Nieve', cueva = 'Cueva', volcan = 'Volcán' }

-- fondo del nivel → isla (la regla que ya usaba el Saltarín; los fondos nuevos, donde caen)
Isles.BY_BACKGROUND = {
    meadow = 'pradera', forest = 'pradera',
    coast = 'costa',
    fortress = 'fortaleza',
    snow = 'nieve', mountain = 'nieve', icecave = 'nieve',
    cave = 'cueva', underwater = 'cueva', abyss = 'cueva', underground = 'cueva',
    volcano = 'volcan', magma = 'volcan',
}

-- FAMILIAS: el de cada isla (lo que falta en una isla: el primero de la lista, el de la pradera)
Isles.FAMILIES = {
    gummy       = { pradera = 'gummy', costa = 'gummy', fortaleza = 'gummy_fortress', nieve = 'gummy_ice',
                    cueva = 'gummy_cave', volcan = 'gummy_magma' },
    crabby      = { pradera = 'crabby_river', costa = 'crabby', fortaleza = 'crabby_fortress', nieve = 'crabby_ice',
                    cueva = 'crabby_cave', volcan = 'crabby_lava' },
    crabbytramp = { pradera = 'crabbytramp_river', costa = 'crabbytramp', fortaleza = 'crabbytramp_fortress',
                    nieve = 'crabbytramp_ice', cueva = 'crabbytramp_cave', volcan = 'crabbytramp_lava' },
}
local familyOf = {}
for fam, t in pairs(Isles.FAMILIES) do for _, name in pairs(t) do familyOf[name] = fam end end
function Isles.familyOf(typeName) return familyOf[typeName] end

-- La isla del nivel (o la forzada: una id de isla; 'auto' / nil / 'self' = la del nivel)
function Isles.of(level, forced)
    if forced and Isles.NAMES[forced] then return forced end
    if not level then return 'pradera' end
    if level.spikeSkin == 'ice' or level.snow then return 'nieve' end
    return Isles.BY_BACKGROUND[level.background or 'meadow'] or 'pradera'
end

-- La prop `isle` del editor. `family` = la de una familia (con 'self' = este mismo, por defecto)
function Isles.prop(group, family)
    local opts = {}
    if family then opts[#opts + 1] = { value = 'self', label = 'Este (no cambia)' } end
    opts[#opts + 1] = { value = 'auto', label = 'Auto (la del nivel)' }
    for _, id in ipairs(Isles.IDS) do opts[#opts + 1] = { value = id, label = Isles.NAMES[id] } end
    return { key = 'isle', kind = 'enum', label = family and 'Isla (cambia de tipo)' or 'Isla (aspecto)',
             group = group or 'Isla', default = family and 'self' or 'auto', options = opts,
             help = family and 'Auto: se cambia por el de la isla del nivel al cargarlo (otra isla: el de esa isla)'
                    or 'Auto: la isla del nivel (su fondo). Cambia el dibujo y, en algunos, el efecto de su isla' }
end

-- (EntityTypes.register) la prop a quien la necesite
function Isles.schemaFor(def)
    if familyOf[def.name] then return Isles.prop('Isla', true) end
    if def.isleArt then return Isles.prop('Isla') end
    return nil
end

-- (Level, ya con su fondo) cambia las colocaciones de una familia con isla 'auto' / otra por el tipo de esa isla
function Isles.resolveAll(level, normalize)
    for i, n in ipairs(level.entities or {}) do
        local fam = familyOf[n.type]
        local want = n.props and n.props.isle
        if fam and want and want ~= 'self' then
            local target = Isles.FAMILIES[fam][Isles.of(level, want)]
            if target and target ~= n.type then
                local m = normalize({ type = target, col = n.col, row = n.row, sub = n.sub, props = n.props })
                if m then
                    m.reserve, m.summonKey = n.reserve, n.summonKey
                    level.entities[i] = m
                end
            end
        end
    end
end

return Isles
