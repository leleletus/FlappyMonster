#!/usr/bin/env python3
# VARIANTES APROBADAS que son el dibujo de siempre con otra paleta y un detalle (las demás, que cambian de forma,
# tendrán su propio generador cuando el usuario elija):
#   · GUMMY DE MAGMA (opción A "Brasa"): roca oscura con grietas, ojos y boca encendidos → assets/images/gummy_magma/
#   · CRABBY DE LA FORTALEZA (opción A "Acero"): chapa gris con remaches → assets/images/crabby_fortress/
# Paletas y detalles: tools/ui/make_enemy_designs.py (GUMMY_SETS, FORT). Se parte de los sprites del juego.
#   python3 tools/ui/make_variant_skins.py --apply
import os, shutil, sys
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import make_enemy_designs as D

IMG = D.ROOT


def recolor(src, dst, pal, edits=()):
    g = D.base(src)
    os.makedirs(os.path.dirname(os.path.join(IMG, dst)), exist_ok=True)
    D.paint(g, pal, edits).save(os.path.join(IMG, dst))


if __name__ == '__main__':
    if '--apply' not in sys.argv:
        sys.exit('usa --apply (las propuestas se ven con make_enemy_designs.py)')
    # Gummy de magma
    lab, pal, edits = D.GUMMY_SETS['gummy_magma'][2][0]
    for f in ('gummy.png', 'gummy1.png', 'gummy2.png'): recolor('gummy/' + f, 'gummy_magma/' + f, pal, edits)
    recolor('gummy/dead.png', 'gummy_magma/dead.png', pal)
    # Crabby de la fortaleza
    lab, pal, gedits, cedits = D.FORT[0]
    for f in ('crab1.png', 'crab2.png', 'crab3.png'): recolor('crabby/' + f, 'crabby_fortress/' + f, pal, cedits)
    recolor('crabby/dead.png', 'crabby_fortress/dead.png', pal)
    recolor('crabby/lookin.png', 'crabby_fortress/lookin.png', pal)
    recolor('crabby/MeatCrabby.png', 'crabby_fortress/meat.png', pal)
    for f in ('hid.png', 'spike.png'): shutil.copy(os.path.join(IMG, 'crabby', f), os.path.join(IMG, 'crabby_fortress', f))

    # ── Los que cambian de FORMA (3ª ronda, elegidos por el usuario) ──
    W1, W2 = [''.join(r) for r in D.base('gummy/gummy1.png')[13:16]], [''.join(r) for r in D.base('gummy/gummy2.png')[13:16]]

    def put(dst, rows, pal, edits=()):
        os.makedirs(os.path.dirname(os.path.join(IMG, dst)), exist_ok=True)
        D.maps(rows, pal, edits).save(os.path.join(IMG, dst))
    # Gummy de CUEVA (versión C "Bajo": ancho y bajito, ojos separados, un cristal)
    cave = D.V3_CAVE[2][1][:13]
    put('gummy_cave/gummy.png', cave + D.LEGS_G, D.CAVE)
    put('gummy_cave/gummy1.png', cave + W1, D.CAVE)
    put('gummy_cave/gummy2.png', cave + W2, D.CAVE)
    put('gummy_cave/dead.png', ['.' * 16] * 10 + ["......oGo.......", "..oooogtooooo...", ".ohbeebbbeebso..", ".oossssssssoo...", "..oooooooooo...."], D.CAVE)
    # Gummy de la FORTALEZA (versión A: muñeco de cuerda con pies de Gummy; la LLAVE gira con el paso)
    # (el arte mira a la DERECHA — el juego lo dibuja tal cual cuando anda hacia la derecha —, así que la llave va
    # en el costado IZQUIERDO = su ESPALDA; estaba a la derecha y le salía por delante. Es EL MISMO dibujo: el cuerpo
    # y los pies una columna a la derecha (cols 3-13) y la llave ENTERA, con su vástago de 1 px, reflejada a las
    # cols 0-2. `helmetDx = 1` en su tipo: el casco se corre con la cabeza)
    def back(key): return [(15 - x, y, c) for x, y, c in key]
    def right(rows): return ['.' + r[:-1] for r in rows]
    put('gummy_fortress/gummy.png', right(D.FORT_BODY + D.FORT_FEET['A']), D.STEEL, back(D.KEY['media']))
    put('gummy_fortress/gummy1.png', right(D.FORT_BODY + W1), D.STEEL, back(D.KEY['alta']))
    put('gummy_fortress/gummy2.png', right(D.FORT_BODY + W2), D.STEEL, back(D.KEY['fina']))
    put('gummy_fortress/dead.png', ['.' * 16] * 11 + ["...ooooooooooo..", "...ohrbbbbbrso..", "...obeebbbeeso..", "kk.oosssssssoo..", "....ooooooooo..."], D.STEEL)
    print('  assets/images/gummy_cave/ y assets/images/gummy_fortress/')
    print('  assets/images/gummy_magma/ y assets/images/crabby_fortress/')
