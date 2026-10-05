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
    print('  assets/images/gummy_magma/ y assets/images/crabby_fortress/')
