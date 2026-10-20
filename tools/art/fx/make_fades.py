#!/usr/bin/env python3
# tools/art/fx/make_fades.py — la MÁSCARA DE DIFUMINADO de los bordes (src/story/LiveStage.lua: los escenarios vivos
# de los créditos no acaban en seco): una tira blanca de 8 x 1 px cuyo alfa sube de 0 a 1 en escalones (pixel art: sin
# degradado suave), con el color ya multiplicado por el alfa (gris = alfa). El código la estira sobre el borde y la usa para multiplicar el alfa de lo dibujado.
#   assets/images/fx/fade_edge.png      de izquierda (transparente) a derecha (opaco)
#   python3 tools/art/fx/make_fades.py
import os
from PIL import Image

STEPS = [0, 36, 72, 108, 144, 180, 218, 255]
im = Image.new('RGBA', (len(STEPS), 1))
for x, a in enumerate(STEPS):
    im.putpixel((x, 0), (a, a, a, a))          # (premultiplicada: se multiplica en modo 'premultiplied')
im.save(os.path.join('assets/images/fx', 'fade_edge.png'))
print('fade_edge.png')
