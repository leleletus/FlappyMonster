#!/usr/bin/env python3
# tools/art/bosses/make_giant_hopper.py — arte propio del SALTARÍN GIGANTE (jefe de las cuevas).
#
# El cuerpo NO se genera aquí: es la MISMA hoja 16x21 del Saltarín de cueva (tools/art/enemies/make_hopper_sprites.py,
# assets/images/enemies/hopper/cueva-Sheet.png) dibujada a escala 12, con sus mismas animaciones
# (assets/anim/enemies/hopper.json, variante cueva). Aquí solo lo que no tiene el pequeño: la ONDA DE ROCA que corre
# por el suelo cuando cae de un salto (3 cuadros 12x9, mirando a la DERECHA; con los colores de la cueva).
#
#   python tools/art/bosses/make_giant_hopper.py   → assets/images/bosses/gianthopper/wave-Sheet.png (+ vista previa)
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'images', 'bosses', 'gianthopper')
PREVIEW = '/home/mtvemo/FlappyMonster_pruebas/jefes/saltarin_gigante'


def hx(s):
    s = s.lstrip('#')
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


# contorno, roca oscura, roca, roca clara, polvo (la paleta lila del Saltarín de cueva)
COL = {'o': hx('#2a2340'), 'd': hx('#5c4c80'), 'r': hx('#8c78b4'), 'l': hx('#c9b8e0'), 'p': hx('#efe6ff')}
# la cresta de piedras que salta delante de la onda (la derecha = hacia donde corre)
FRAMES = [
    ["............",
     "........p...",
     "......oo..p.",
     ".....olro...",
     "...p.orlro..",
     "..oo.odrrlo.",
     ".odrooddrrro",
     "oddrrdddrrro",
     "oooooooooooo"],
    ["........p...",
     "......p.....",
     ".......oo...",
     ".p....olro.p",
     "......orrlo.",
     "..oo.odrrlo.",
     ".orrooddrrlo",
     "odddrdddrrro",
     "oooooooooooo"],
    ["......p.....",
     ".........p..",
     "........o...",
     "......oolo..",
     "..p..odrrlo.",
     "...o.oddrro.",
     "..orooddrrlo",
     "odddrdddrrro",
     "oooooooooooo"],
]


def sheet():
    w, h = len(FRAMES[0][0]), len(FRAMES[0])
    im = Image.new('RGBA', (w * len(FRAMES), h), (0, 0, 0, 0))
    for i, fr in enumerate(FRAMES):
        for y, row in enumerate(fr):
            for x, c in enumerate(row):
                if c in COL: im.putpixel((i * w + x, y), COL[c])
    return im


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    s = sheet()
    p = os.path.join(OUT, 'wave-Sheet.png')
    s.save(p)
    print('escrito', p)
    os.makedirs(PREVIEW, exist_ok=True)
    s.resize((s.width * 12, s.height * 12), Image.NEAREST).save(os.path.join(PREVIEW, 'onda.png'))
