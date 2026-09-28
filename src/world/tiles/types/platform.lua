-- Plataforma NO traspasable: se atraviesa subiendo, pero no se puede bajar
-- agachándose. Losa gris-pizarra gruesa (≈¾ del alto; el resto de la imagen
-- es transparente): assets/images/tiles/platform.png.
return {
    id = 2, name = 'platform', label = 'Plataforma', category = 'Plataformas',
    collision = 'oneway', dropThrough = false, material = 'stone',
    hitbox = { x = 0, y = 0, w = 1, h = 0.72 },       -- lo que se ve (losa de ¾)
    editorColor = { 0.52, 0.52, 0.60 },
    texture = { image = 'assets/images/tiles/platform.png' },
}
