-- Nieve: bloque sólido de terreno (se une con 'ground' como la tierra y el césped, y también con el hielo: sin filo
-- entre ellos). Piel por CAPAS (TileTypes.drawSkin, 2026-10-29): el cuerpo sin franjas y la almohadilla de nieve solo
-- arriba al aire, la sombra solo abajo al aire — antes cada casilla llevaba las dos y una pared de nieve se veía bloque
-- a bloque —. COSTURA con los otros bloques (el usuario: «así como el hielo / la arena tiene costura con otros bloques,
-- la nieve también debe»): la nieve se DERRAMA sobre la tierra, la piedra… que toca (`spill`, TileTypes.drawSpill: lo
-- dibuja el vecino, dentro de su casilla): un labio de nieve y grumos redondos. (La franja tramada de la arena en
-- colores de tierra, dibujada sobre la nieve, parecía hierba de pinchos.) Texturas (tools/art/world/make_frozen_tiles.py):
-- snow.png, snow_top.png, snow_under.png, snow_spill.png; el original del usuario, fuera del repo.

return {
    id = 29, name = 'snow', label = 'Nieve', category = 'Terreno',
    collision = 'solid', material = 'snow', joinGroup = 'ground', joinAlso = { 'ice' },
    editorColor = { 0.86, 0.91, 1 },
    texture = { image = 'assets/images/world/tiles/snow.png' },
    skin = {
        body   = { image = 'assets/images/world/tiles/snow.png' },
        top    = { image = 'assets/images/world/tiles/snow_top.png' },
        bottom = { image = 'assets/images/world/tiles/snow_under.png' },
        edges  = { left = { 1, 1, 1 }, right = { 0.8, 0.86, 0.97 } },
        capEdge = { { 1, 1, 1 }, 4 },
    },
    -- (sobre qué bloques deja su costura: el terreno que no es nieve ni hielo, que tienen la suya)
    spill = { image = 'assets/images/world/tiles/snow_spill.png', frame = 1,
              onto = { 'dirt', 'grass', 'solid', 'border', 'deep_stone', 'sand', 'basalt', 'ash', 'mud', 'jungle_grass',
                       'temple_brick', 'frost_brick', 'ice_rock', 'frost_window', 'breakable' } },
}
