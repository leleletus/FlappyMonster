-- Plataforma NO traspasable: se atraviesa subiendo, pero no se puede bajar
-- agachándose. Viga de acero remachada (≈¾ del alto; el resto de la imagen es
-- transparente): assets/images/world/tiles/platform.png (tools/art/world/make_world_art.py).
return {
    id = 2, name = 'platform', label = 'Plataforma', category = 'Plataformas',
    collision = 'oneway', dropThrough = false, material = 'stone',
    hitbox = { x = 0, y = 0, w = 1, h = 0.72 },       -- lo que se ve (losa de ¾)
    editorColor = { 0.52, 0.52, 0.60 },
    texture = { image = 'assets/images/world/tiles/platform.png' },
    debris = { { 0.52, 0.52, 0.6 }, { 0.4, 0.4, 0.47 }, { 0.64, 0.64, 0.72 } },
}
