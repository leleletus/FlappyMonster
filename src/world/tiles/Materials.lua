-- src/world/tiles/Materials.lua
-- Registro de MATERIALES: de qué está hecho un tile y qué le hace al jugador.
-- Un tile apunta a un material por nombre (campo `material`). Varios tiles
-- pueden compartir material (piedra, madera...).
--
-- Campos (todos opcionales; los que faltan toman el valor de DEFAULTS):
--
--  Superficie (se aplican al estar DE PIE sobre el tile):
--   friction   multiplicador de la fricción en suelo (hielo: 0.1)
--   speedMult  multiplicador de la velocidad al caminar (barro: 0.5)
--   conveyor   px/s que arrastra al jugador en X (cinta: 120 / -120)
--
--  Contacto (se aplican al TOCAR el tile con la hitbox interna):
--   contact    nil | 'kill' (muerte instantánea) | 'hurt' (quita 1 HP con
--              invulnerabilidad breve)
--
--  Líquido (el tile es un volumen en el que se nada):
--   liquid       true para líquidos
--   gravityMult  gravedad dentro
--   jumpMult     fuerza de salto dentro
--   speedMult    (también) velocidad horizontal dentro
--   drag         amortiguación vertical
--   drown        la cabeza dentro consume aire (ahogamiento)
--   tint         {r,g,b,a} del tinte en pantalla
--   distort      aplica el shader de distorsión de agua
--   bubbles      genera burbujas ambientales en cuerpos grandes
--   splashIn / splashOut  sonidos al entrar / salir
--
--  Editor:
--   label, color   nombre y color para la paleta del editor de niveles

local Materials = { byName = {}, list = {} }

Materials.DEFAULTS = {
    friction = 1, speedMult = 1, conveyor = 0, contact = nil,
    liquid = false, gravityMult = 1, jumpMult = 1, drag = 0, drown = false,
    tint = nil, distort = false, bubbles = false, splashIn = nil, splashOut = nil,
    color = { 0.6, 0.6, 0.6 },
}

local CONTACTS = { kill = true, hurt = true }

function Materials.register(def)
    assert(type(def) == 'table' and type(def.name) == 'string', "material sin nombre")
    assert(not Materials.byName[def.name], "material duplicado: " .. def.name)
    assert(def.contact == nil or CONTACTS[def.contact], "contact invalido en " .. def.name)
    local m = {}
    for k, v in pairs(Materials.DEFAULTS) do m[k] = v end
    for k, v in pairs(def) do m[k] = v end
    m.label = m.label or m.name
    Materials.byName[m.name] = m
    table.insert(Materials.list, m)
    return m
end

function Materials.get(name)
    return Materials.byName[name] or Materials.byName.default
end

return Materials
