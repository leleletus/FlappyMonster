#!/usr/bin/env python3
# tools/art/ui/make_rhythm.py — el DUELO DE RITMO del Cangrejo Groove (docs/bosses/groovecrab.md): flechas de 24x24, en el orden de
# los carriles: izquierda, abajo, arriba, derecha. Los colores son los de las notas del Cangrejo.
#   strums-Sheet.png      las 4 quietas, grises (huecas: se ve lo que llega a través)
#   strums_hit-Sheet.png  las mismas al pulsar, encendidas con el color de su carril
#   notes-Sheet.png       las 4 que se mueven, una de cada color
# python3 tools/art/ui/make_rhythm.py   → assets/images/ui/rhythm/ y una previa en FlappyMonster_pruebas/groove_duelo/
import os
from PIL import Image, ImageDraw

OUT = 'assets/images/ui/rhythm'
PREV = '/home/mtvemo/FlappyMonster_pruebas/groove_duelo/flechas_vista_previa.png'
S = 24
LINE = (24, 20, 38, 255)
#          relleno           luz                sombra
COLS = [((236, 72, 153, 255), (255, 170, 214, 255), (160, 32, 104, 255)),   # izquierda: rosa
        ((56, 200, 232, 255), (176, 240, 255, 255), (24, 120, 170, 255)),   # abajo: cian
        ((92, 214, 92, 255), (190, 250, 170, 255), (36, 140, 70, 255)),     # arriba: verde
        ((250, 204, 46, 255), (255, 240, 160, 255), (190, 130, 20, 255))]   # derecha: amarillo
GRAY = ((132, 138, 156, 255), (186, 192, 208, 255), (84, 88, 106, 255))
ROT = [Image.ROTATE_90, Image.ROTATE_180, None, Image.ROTATE_270]           # (dibujada hacia arriba)
# La flecha, hacia arriba: punta, alas y mástil
ARROW = [(11, 1), (12, 1), (22, 12), (22, 14), (16, 14), (16, 22), (7, 22), (7, 14), (1, 14), (1, 12)]
INNER = [(11, 4), (12, 4), (19, 12), (14, 12), (14, 20), (9, 20), (9, 12), (4, 12)]


def arrow(col, hollow=False):
    fill, light, shade = col
    im = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.polygon(ARROW, fill=LINE)
    d.polygon(INNER, fill=fill)
    d.line([(11, 4), (5, 11)], fill=light)                                   # (luz: el ala izquierda)
    d.line([(10, 12), (10, 19)], fill=light)
    d.line([(12, 4), (18, 11)], fill=shade)                                  # (sombra: la derecha)
    d.line([(13, 13), (13, 20)], fill=shade)
    if hollow:
        d.polygon([(11, 8), (12, 8), (15, 11), (12, 11), (12, 17), (11, 17), (11, 11), (8, 11)], fill=(30, 28, 44, 255))
    return im


def sheet(frames):
    out = Image.new('RGBA', (S * 4, S), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.alpha_composite(f.transpose(ROT[i]) if ROT[i] is not None else f, (i * S, 0))
    return out


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    sts = sheet([arrow(GRAY, True)] * 4)
    hit = sheet([arrow(c, True) for c in COLS])
    nts = sheet([arrow(c) for c in COLS])
    sts.save(os.path.join(OUT, 'strums-Sheet.png'))
    hit.save(os.path.join(OUT, 'strums_hit-Sheet.png'))
    nts.save(os.path.join(OUT, 'notes-Sheet.png'))
    os.makedirs(os.path.dirname(PREV), exist_ok=True)
    pv = Image.new('RGBA', (S * 4 * 6 + 20, S * 3 * 6 + 40), (70, 90, 130, 255))
    for r, s in enumerate((sts, hit, nts)):
        pv.alpha_composite(s.resize((S * 24, S * 6), Image.NEAREST), (10, 10 + r * (S * 6 + 10)))
    pv.convert('RGB').save(PREV)
    print('escrito', OUT, PREV)
