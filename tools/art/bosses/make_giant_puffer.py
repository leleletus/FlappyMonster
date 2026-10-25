#!/usr/bin/env python3
# tools/art/bosses/make_giant_puffer.py — arte propio del PEZ GLOBO GIGANTE (jefe de la costa).
#
# El cuerpo NO se genera aquí: es la MISMA hoja 16x16 del pez globo normal (diseño A "Arena",
# tools/art/enemies/make_pufferfish.py) dibujada a escala 13 (más que los "Mega", a 10: el pez solo llena ~10 de los 16 px del cuadro).
# Aquí solo lo que no tiene el pez pequeño: la PÚA que dispara (con los colores del diseño A).
#
#   python tools/art/bosses/make_giant_puffer.py   → assets/images/bosses/giantpuffer/spine.png (+ vista previa)
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'images', 'bosses', 'giantpuffer')
PREVIEW = '/home/mtvemo/FlappyMonster_pruebas/jefes/pez_globo_gigante'


def hx(s):
    s = s.lstrip('#')
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


O, B, M, T = hx('#5e3b12'), hx('#b5842c'), hx('#e3b84e'), hx('#fff4d4')   # contorno, base, medio, punta (diseño A)
# la púa: 9x5 mirando a la DERECHA (base gruesa a la izquierda, punta clara a la derecha); 1 px de margen
SPINE = ["..........",
         ".oo.......",
         ".obmmmo...",
         ".obbmmmtt.",
         ".obmmmo...",
         ".oo.......",
         ".........."]
COL = {'o': O, 'b': B, 'm': M, 't': T}


def spine():
    w, h = len(SPINE[0]), len(SPINE)
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    for y, row in enumerate(SPINE):
        for x, c in enumerate(row):
            if c in COL: im.putpixel((x, y), COL[c])
    return im


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    s = spine()
    p = os.path.join(OUT, 'spine.png')
    s.save(p)
    print('escrito', p)
    os.makedirs(PREVIEW, exist_ok=True)
    s.resize((s.width * 12, s.height * 12), Image.NEAREST).save(os.path.join(PREVIEW, 'pua.png'))
