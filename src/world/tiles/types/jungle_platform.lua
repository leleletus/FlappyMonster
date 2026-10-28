-- Plataforma TRASPASABLE de la jungla (0.5.83): la de siempre — se atraviesa subiendo y se baja agachado — hecha de
-- tablones atados con liana (la opción A, elegida por el usuario). assets/images/world/tiles/jungle_platform.png
-- (tools/art/world/make_jungle_sky.py).
return {
    id = 43, name = 'jungle_platform', label = 'Plataforma traspasable (jungla)', category = 'Plataformas',
    collision = 'oneway', dropThrough = true, material = 'wood',
    hitbox = { x = 0, y = 0, w = 1, h = 0.36 },
    editorColor = { 0.6, 0.36, 0.16 },
    texture = { image = 'assets/images/world/tiles/jungle_platform.png' },
}
