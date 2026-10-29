-- EL PAQUETE HELADO (2026-10-29): bloques de construcción para las islas heladas — muros, ruinas y fondos — con piel por
-- capas (TileTypes.drawSkin: el cuerpo sin costuras y lo de arriba / abajo solo en las caras al aire; los de 2x2 casillas
-- siguen su dibujo de un bloque al de al lado). Todos van también al plano de fondo (BackPlane.allows); la ventana está
-- pensada para él. Texturas: tools/art/world/make_frozen_tiles.py (assets/images/world/tiles/).
--   50 frost_brick     Ladrillo helado            sólido, piedra helada; nieve fina encima
--   51 ice_rock        Roca helada                sólido, piedra helada; nieve fina encima
--   52 ice_brick       Sillar de hielo            sólido, opaco, RESBALA (hielo); se une con el hielo y la nieve
--   53 glacier_ice     Hielo glaciar              sólido, opaco en estratos, RESBALA; se une con el hielo y la nieve
--   54 snow_brick      Bloque de nieve (iglú)     sólido, nieve (el Topo lo cava); almohadilla de nieve encima
--   55 ice_pillar      Columna de hielo           sólido, RESBALA; capitel arriba y basa abajo donde acaba
--   56 frost_window    Ventana helada             sólido; el ladrillo helado con una ventana (para el plano de fondo)
--   57 frost_platform  Plataforma helada          traspasable (se baja agachado), madera
--   58 ice_ledge       Repisa de hielo            traspasable, RESBALA, semitransparente, gotea
local T = 'assets/images/world/tiles/'
local function img(n, span) return { image = T .. n .. '.png', span = span } end

local FROST_TOP = img('frost_top')
local SNOW_TOP  = img('snow_top')
local ICE_TOP   = img('ice_top')
local STONE_EDGES = { left = { 0.6, 0.66, 0.8 }, right = { 0.3, 0.35, 0.5 }, bottom = { 0.2, 0.24, 0.37 } }
local OPAQUE_ICE_EDGES = { left = { 0.82, 0.9, 1 }, right = { 0.36, 0.48, 0.78 }, bottom = { 0.3, 0.44, 0.75 } }
local TO_SNOW = { image = T .. 'ice_blend.png', of = { snow = 1, packed_snow = 1, snow_brick = 1 } }

return {
    {
        id = 50, name = 'frost_brick', label = 'Ladrillo helado', category = 'Terreno',
        collision = 'solid', material = 'frost_stone', joinGroup = 'ground',
        editorColor = { 0.38, 0.43, 0.57 },
        texture = img('frost_brick', 2),
        skin = { body = img('frost_brick', 2), top = FROST_TOP, edges = STONE_EDGES, capEdge = { { 0.86, 0.91, 0.99 }, 2 } },
    },
    {
        id = 51, name = 'ice_rock', label = 'Roca helada', category = 'Terreno',
        collision = 'solid', material = 'frost_stone', joinGroup = 'ground',
        editorColor = { 0.38, 0.43, 0.57 },
        texture = img('ice_rock', 2),
        skin = { body = img('ice_rock', 2), top = FROST_TOP, edges = STONE_EDGES, capEdge = { { 0.86, 0.91, 0.99 }, 2 } },
    },
    {
        id = 52, name = 'ice_brick', label = 'Sillar de hielo', category = 'Terreno',
        collision = 'solid', material = 'ice', joinGroup = 'ice', joinAlso = { 'snow', 'packed_snow', 'snow_brick' },
        editorColor = { 0.59, 0.73, 0.94 },
        texture = img('ice_brick', 2),
        skin = { body = img('ice_brick', 2), top = ICE_TOP, blend = TO_SNOW, edges = OPAQUE_ICE_EDGES },
    },
    {
        id = 53, name = 'glacier_ice', label = 'Hielo glaciar', category = 'Terreno',
        collision = 'solid', material = 'ice', joinGroup = 'ice', joinAlso = { 'snow', 'packed_snow', 'snow_brick' },
        editorColor = { 0.5, 0.65, 0.9 },
        texture = img('glacier_ice', 2),
        skin = { body = img('glacier_ice', 2), top = ICE_TOP, blend = TO_SNOW, edges = OPAQUE_ICE_EDGES },
    },
    {
        id = 54, name = 'snow_brick', label = 'Bloque de nieve (iglú)', category = 'Terreno',
        collision = 'solid', material = 'snow', joinGroup = 'ground', joinAlso = { 'ice' },
        editorColor = { 0.88, 0.92, 1 },
        texture = img('snow_brick', 2),
        skin = { body = img('snow_brick', 2), top = SNOW_TOP, edges = { left = { 1, 1, 1 }, right = { 0.7, 0.77, 0.93 } },
                 capEdge = { { 1, 1, 1 }, 4 } },
    },
    {
        id = 55, name = 'ice_pillar', label = 'Columna de hielo', category = 'Terreno',
        collision = 'solid', material = 'ice', joinGroup = 'ice_pillar',
        editorColor = { 0.59, 0.73, 0.94 },
        texture = img('ice_pillar'),
        skin = { body = img('ice_pillar'), top = img('ice_pillar_top'), bottom = img('ice_pillar_bottom') },
    },
    {
        id = 56, name = 'frost_window', label = 'Ventana helada', category = 'Terreno',
        collision = 'solid', material = 'frost_stone', joinGroup = 'ground',
        editorColor = { 0.45, 0.6, 0.85 },
        texture = img('frost_window'),
        skin = { body = img('frost_brick', 2), over = img('frost_window'), top = FROST_TOP, edges = STONE_EDGES,
                 capEdge = { { 0.86, 0.91, 0.99 }, 2 } },
    },
    {
        id = 57, name = 'frost_platform', label = 'Plataforma helada (traspasable)', category = 'Plataformas',
        collision = 'oneway', dropThrough = true, material = 'wood',
        hitbox = { x = 0, y = 0, w = 1, h = 0.36 },       -- (lo que se ve: los tablones; los carámbanos cuelgan)
        editorColor = { 0.48, 0.39, 0.44 },
        texture = img('frost_platform'),
    },
    {
        id = 58, name = 'ice_ledge', label = 'Repisa de hielo (traspasable)', category = 'Plataformas',
        collision = 'oneway', dropThrough = true, material = 'ice', iceDrip = true,
        hitbox = { x = 0, y = 0, w = 1, h = 0.36 },
        editorColor = { 0.72, 0.84, 1 },
        texture = img('ice_ledge'),
        skin = { body = img('ice_ledge'), alpha = 0.85 },
    },
}
