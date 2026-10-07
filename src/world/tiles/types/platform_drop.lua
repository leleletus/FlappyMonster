-- Plataforma TRASPASABLE: se atraviesa subiendo y se baja manteniendo
-- agachado. Pasarela de madera delgada con tablones (naranja, distinta de
-- la losa gris no traspasable): assets/images/world/tiles/platform_drop.png.
return {
    id = 10, name = 'platform_drop', label = 'Plataforma traspasable', category = 'Plataformas',
    collision = 'oneway', dropThrough = true, material = 'wood',
    hitbox = { x = 0, y = 0, w = 1, h = 0.36 },       -- lo que se ve (pasarela fina)
    editorColor = { 0.86, 0.52, 0.12 },
    texture = { image = 'assets/images/world/tiles/platform_drop.png' },
}
