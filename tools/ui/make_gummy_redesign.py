#!/usr/bin/env python3
# tools/ui/make_gummy_redesign.py
# Rediseño de los Gummies, su casco y las alas (genéricas de todos los voladores),
# como el de los Crabbies (tools/ui/make_crab_redesign.py): la MISMA forma de los
# originales (cada píxel) con el estilo nuevo, salvo:
#   dead.png  el Gummy aplastado (también el del Crabby): el original estaba
#             difuminado; ahora en pixel art limpio
#   alas      2 cuadros de 9x13 redibujados (sin píxeles sueltos ni bordes rotos)
#   casco     cúpula de acero en 2 tonos con brillo, ala blanca con sombra
#   python3 tools/ui/make_gummy_redesign.py <carpeta>   vista previa
#   python3 tools/ui/make_gummy_redesign.py --apply     al juego (originales fuera del repo)
import os, sys
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import originals   # noqa: E402
from make_crab_redesign import PAL, grid, restyle   # noqa: E402

APPLY = '--apply' in sys.argv
OUT = next((a for a in sys.argv[1:] if not a.startswith('--')), '/tmp/gummy_redesign')
SRC = 'assets/images/'


def src(rel):
    o = originals.path(SRC + rel)
    return o if os.path.exists(o) else SRC + rel


def helmet():
    """Casco: contorno, ala blanca (brillo / sombra) y cúpula de acero en 2 tonos."""
    im = Image.open(src('gummy/casco.png')).convert('RGBA')
    w, h = im.size
    out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    steel, steelL = (60, 66, 82, 255), (98, 106, 128, 255)
    for y in range(h):
        for x in range(w):
            p = im.getpixel((x, y))
            if not p[3]: continue
            rgbp = p[:3]
            if rgbp == (255, 255, 255):
                c = PAL['S'] if x >= w // 2 + 2 else (PAL['H'] if y <= 2 else PAL['W'])
            elif rgbp == (42, 42, 42):
                c = steelL if (y <= 3 and x <= w // 2) else steel
            else:
                c = PAL['O']
            out.putpixel((x, y), c)
    return out


def dead():
    rows = ["." * 16] * 11 + [
        "....OOOOOOOO....",
        "..OOHHWWWWWWOO..",
        ".OWWWkkWWkkWWSO.",
        ".OSWWWWWWWWWSSO.",
        "..OOOOOOOOOOOO..",
    ]
    return grid(rows)


def wings():
    pal = dict(PAL, f=(180, 196, 220, 255))
    # Ala nueva (no la original): borde de ataque curvo que sale de la raíz (a la
    # derecha) y un abanico de 3 plumas largas con la punta redondeada; 2 cuadros
    # de aleteo: arriba (plumas hacia arriba) y abajo (hacia abajo)
    opn = [
        "O........",
        "OHO......",
        "OWHO..O..",
        ".OWHOOHO.",
        ".OWWHOWWO",
        "..OWWWWWO",
        ".OOWWWWWO",
        "OHWfWWWWO",
        ".OWWfWWSO",
        "..OOWfSSO",
        "....OOSO.",
        "......O..",
        ".........",
    ]
    fold = [
        ".........",
        "......O..",
        "....OOHO.",
        "..OOHWWWO",
        ".OHWWWWWO",
        "OHWWWWWSO",
        ".OOWfWWSO",
        "OHWfWWSSO",
        ".OOfWWSO.",
        "OHWfWSO..",
        ".OOOSO...",
        "...OO....",
        ".........",
    ]
    def g(rows):
        im = Image.new('RGBA', (9, 13), (0, 0, 0, 0))
        for y, r in enumerate(rows):
            for x, ch in enumerate(r):
                if ch in pal: im.putpixel((x, y), pal[ch])
        return im
    out = Image.new('RGBA', (18, 13), (0, 0, 0, 0))
    out.paste(g(opn), (0, 0)); out.paste(g(fold), (9, 0))
    return out


def sprites():
    return {
        'gummy/gummy.png': restyle(src('gummy/gummy.png')),
        'gummy/gummy1.png': restyle(src('gummy/gummy1.png')),
        'gummy/gummy2.png': restyle(src('gummy/gummy2.png')),
        'gummy/dead.png': dead(),
        'gummy/casco.png': helmet(),
        'wings/wings-Sheet.png': wings(),
    }


if __name__ == '__main__':
    if APPLY:
        print('Rediseño de los Gummies, su casco y las alas (originales fuera del repo):')
        for rel, im in sprites().items():
            originals.keep(SRC + rel)
            im.save(SRC + rel)
            print('  %-36s %dx%d' % (SRC + rel, im.width, im.height))
        sys.exit(0)
    os.makedirs(OUT, exist_ok=True)
    for rel, im in sprites().items():
        im.save(os.path.join(OUT, os.path.basename(rel)))
    print('PRUEBA en', OUT)
