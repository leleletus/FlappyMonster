-- Nieve: bloque sólido de terreno (se une con 'ground' como la tierra y el césped, y también con el hielo: sin filo
-- entre ellos). Piel por CAPAS (TileTypes.drawSkin, 2026-10-29): el cuerpo sin franjas y la almohadilla de nieve solo
-- arriba al aire, la sombra solo abajo al aire — antes cada casilla llevaba las dos y una pared de nieve se veía bloque
-- a bloque —. Hacia la tierra / la piedra, borde limpio: con la franja tramada de la arena (opción B: `blend =
-- { image = sand_blend.png, of = … }` en la piel) la tierra bajo la nieve parecía hierba de pinchos. Texturas
-- (tools/art/world/make_frozen_tiles.py): snow.png, snow_top.png, snow_under.png; el original del usuario, fuera del repo.

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
}
