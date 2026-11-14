-- EL PAQUETE ESTELAR (2026-11-14): los bloques temáticos de la Vía Estelar (docs/design/via-estelar-level.md), con piel
-- por capas como el paquete helado (TileTypes.drawSkin: el cuerpo sin costuras de 2x2 casillas y lo de arriba / abajo
-- solo en las caras al aire). Todos valen también para el plano de fondo (BackPlane.allows); la ventana está pensada
-- para él. Texturas: tools/art/world/make_starway_tiles.py (assets/images/world/tiles/).
--   61 star_crystal    Cristal estelar        sólido; el suelo del camino (filo de luz encima)
--   62 nebula_rock     Roca nebular           sólido; lo de debajo, oscuro (se une con el cristal)
--   63 cloud_block     Nube maciza            sólido, blando (nieve); borde de algodón encima
--   64 star_brick      Ladrillo estelar       sólido; muros y construcciones (estrella incrustada)
--   65 crystal_pillar  Columna de cristal     sólido; capitel arriba y basa abajo donde acaba
--   66 star_window     Ventana estelar        sólido; el ladrillo con un ojo de buey estrellado (para el fondo)
--   67 cloud_platform  Nube traspasable       se sube por debajo y se baja agachado
--   68 crystal_ledge   Repisa de cristal      traspasable
local T = 'assets/images/world/tiles/'
local function img(n, span) return { image = T .. n .. '.png', span = span } end

local STAR_TOP = img('star_top')
local EDGES = { left = { 0.78, 0.75, 0.93 }, right = { 0.3, 0.27, 0.5 }, bottom = { 0.18, 0.16, 0.32 } }
local CAP = { { 0.93, 0.91, 0.99 }, 2 }

return {
    {
        id = 61, name = 'star_crystal', label = 'Cristal estelar', category = 'Terreno',
        collision = 'solid', material = 'frost_stone', joinGroup = 'ground',
        editorColor = { 0.48, 0.44, 0.7 },
        texture = img('star_crystal', 2),
        skin = { body = img('star_crystal', 2), top = STAR_TOP, edges = EDGES, capEdge = CAP },
    },
    {
        id = 62, name = 'nebula_rock', label = 'Roca nebular', category = 'Terreno',
        collision = 'solid', material = 'stone', joinGroup = 'ground',
        editorColor = { 0.2, 0.16, 0.35 },
        texture = img('nebula_rock', 2),
        skin = { body = img('nebula_rock', 2), top = STAR_TOP, edges = EDGES, capEdge = CAP },
    },
    {
        id = 63, name = 'cloud_block', label = 'Nube maciza', category = 'Terreno',
        collision = 'solid', material = 'snow', joinGroup = 'cloud',
        editorColor = { 0.78, 0.77, 0.9 },
        texture = img('cloud_block', 2),
        skin = { body = img('cloud_block', 2), top = img('cloud_top'), bottom = img('cloud_under') },
    },
    {
        id = 64, name = 'star_brick', label = 'Ladrillo estelar', category = 'Terreno',
        collision = 'solid', material = 'stone', joinGroup = 'ground',
        editorColor = { 0.42, 0.38, 0.64 },
        texture = img('star_brick', 2),
        skin = { body = img('star_brick', 2), top = STAR_TOP, edges = EDGES, capEdge = CAP },
    },
    {
        id = 65, name = 'crystal_pillar', label = 'Columna de cristal', category = 'Terreno',
        collision = 'solid', material = 'frost_stone', joinGroup = 'crystal_pillar',
        editorColor = { 0.6, 0.57, 0.82 },
        texture = img('crystal_pillar'),
        skin = { body = img('crystal_pillar'), top = img('crystal_pillar_top'), bottom = img('crystal_pillar_bottom') },
    },
    {
        id = 66, name = 'star_window', label = 'Ventana estelar', category = 'Terreno',
        collision = 'solid', material = 'stone', joinGroup = 'ground',
        editorColor = { 0.3, 0.27, 0.55 },
        texture = img('star_window'),
        skin = { body = img('star_brick', 2), over = img('star_window'), top = STAR_TOP, edges = EDGES, capEdge = CAP },
    },
    {
        id = 67, name = 'cloud_platform', label = 'Nube traspasable', category = 'Plataformas',
        collision = 'oneway', dropThrough = true, material = 'snow',
        hitbox = { x = 0, y = 0, w = 1, h = 0.4 },
        editorColor = { 0.88, 0.87, 0.96 },
        texture = img('cloud_platform'),
    },
    {
        id = 68, name = 'crystal_ledge', label = 'Repisa de cristal (traspasable)', category = 'Plataformas',
        collision = 'oneway', dropThrough = true, material = 'frost_stone',
        hitbox = { x = 0, y = 0, w = 1, h = 0.3 },
        editorColor = { 0.72, 0.68, 0.92 },
        texture = img('crystal_ledge'),
    },
}
