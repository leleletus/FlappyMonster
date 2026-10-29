-- Hielo: bloque sólido SEMITRANSPARENTE (se ve lo de detrás) y RESBALADIZO (material ice). Se une con el hielo (grupo
-- 'ice') y con la nieve: sin filo entre ellos y, hacia la nieve, una franja tramada de escarcha. Si debajo no hay
-- nada, gotea (src/fx/IceDrips.lua, solo dibujo). Piel por CAPAS (TileTypes.drawSkin, 2026-10-29): el cuerpo cubre
-- 2x2 casillas (los brillos siguen de un bloque al de al lado), la escarcha solo arriba al aire y lo más denso solo abajo
-- al aire. Texturas (tools/art/world/make_frozen_tiles.py): ice.png, ice_top.png, ice_under.png, ice_blend.png
-- (original del usuario, fuera del repo).
return {
    id = 30, name = 'ice', label = 'Hielo', category = 'Terreno',
    collision = 'solid', material = 'ice', joinGroup = 'ice', iceDrip = true,
    joinAlso = { 'snow', 'packed_snow', 'snow_brick' },
    editorColor = { 0.65, 0.77, 1 },
    texture = { image = 'assets/images/world/tiles/ice.png', span = 2 },
    skin = {
        alpha  = 0.78,
        body   = { image = 'assets/images/world/tiles/ice.png', span = 2 },
        top    = { image = 'assets/images/world/tiles/ice_top.png' },
        bottom = { image = 'assets/images/world/tiles/ice_under.png' },
        blend  = { image = 'assets/images/world/tiles/ice_blend.png', of = { snow = 1, packed_snow = 1, snow_brick = 1 } },
        edges  = { left = { 0.88, 0.94, 1, 0.9 }, right = { 0.88, 0.94, 1, 0.9 } },
    },
}
