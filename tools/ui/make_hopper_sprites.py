#!/usr/bin/env python3
# EL SALTARÍN (enemigo: src/world/entities/types/enemies/hopper.lua). Diseño B "Muelle" elegido por el usuario: una bola con
# cara sobre un muelle. Sus píxeles y sus seis aspectos de isla están en tools/ui/make_enemy_designs.py (HOP, ISLES,
# HEAD); aquí se montan las hojas del juego: assets/images/enemies/hopper/<isla>-Sheet.png, 4 cuadros de 16x21 con los pies
# abajo: 1 quieto · 2 agachado (va a saltar) · 3 en el aire (muelle estirado) · 4 aplastado.
#   python3 tools/ui/make_hopper_sprites.py           → vista previa (FlappyMonster_pruebas/enemigos/saltarin_hojas.png)
#   python3 tools/ui/make_hopper_sprites.py --apply   → escribe las hojas
import os, sys
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import make_enemy_designs as D

FW, FH = 16, 21
DESIGN = 'B  Muelle'
DEAD = ["..oooooooooo....",
        ".ohhbbbbbbbso...",
        ".obeebbbbeebso..",
        ".oosssssssssoo..",
        "...ooooooooo...."]
OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'images', 'enemies', 'hopper')


def frames(pal, cap):
    ims = D.hopper(DESIGN, pal, cap)                       # quieto, agachado, en el aire (con lo de la cabeza)
    ims.append(D.paint(D.norm(DEAD), pal))
    out = Image.new('RGBA', (FW * 4, FH))
    for i, im in enumerate(ims):
        box = im.getbbox()
        im = im.crop((0, box[1], FW, box[3]))               # (sin las filas vacías de arriba)
        # el cuerpo está dibujado a la izquierda del lienzo: se centra (su bola ocupa las columnas 2-10)
        dx = 2 if i < 3 else 1
        out.paste(im, (i * FW + dx, FH - im.height), im)
    return out


if __name__ == '__main__':
    apply = '--apply' in sys.argv
    sheets = [(isle, frames(pal, cap)) for isle, lab, pal, cap in D.ISLES]
    if apply:
        os.makedirs(OUT, exist_ok=True)
        for isle, im in sheets:
            im.save(os.path.join(OUT, isle + '-Sheet.png'))
            print('  ' + os.path.join(OUT, isle + '-Sheet.png'))
    big = Image.new('RGBA', (FW * 4 * 8, FH * 8 * len(sheets)), D.rgb('6e9a6e'))
    for k, (isle, im) in enumerate(sheets):
        b = im.resize((im.width * 8, im.height * 8), Image.NEAREST)
        bg = Image.new('RGBA', b.size, D.rgb(D.BG[isle]))
        bg.paste(b, (0, 0), b)
        big.paste(bg, (0, k * FH * 8))
    os.makedirs(D.OUT, exist_ok=True)
    big.save(os.path.join(D.OUT, 'saltarin_hojas.png'))
    print('  ' + os.path.join(D.OUT, 'saltarin_hojas.png'))
