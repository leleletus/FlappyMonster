#!/usr/bin/env python3
# tools/art/enemies/make_crown_broken.py
# La CORONA ROTA del Rey Gummy (docs/bosses/megagummy.md, derrota): la de siempre (crown.png, misma rejilla 16x16,
# los mismos colores) partida por la mitad — sin la púa del centro, una grieta oscura y el trozo derecho caído un
# píxel —. El Rey la recoge del suelo al recomponerse y se la pone así, torcida, antes de irse.
#   python3 tools/art/enemies/make_crown_broken.py
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', '..', '..', 'assets', 'images', 'bosses', 'megagummy', 'crown_broken.png')
D, G, S = (30, 30, 42, 255), (255, 210, 70, 255), (220, 160, 40, 255)      # contorno, oro, oro en sombra (crown.png)

PIX = {
    (5, 0): D,                                   # púa izquierda (la del centro se rompió)
    (4, 1): D, (5, 1): G, (6, 1): S, (7, 1): D,  # trozo izquierdo, con la grieta
    (9, 1): D,                                   # púa derecha, caída un píxel con su trozo
    (8, 2): S, (9, 2): G, (10, 2): D,            # trozo derecho, un píxel más abajo
}

if __name__ == '__main__':
    im = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    for (x, y), c in PIX.items():
        im.putpixel((x, y), c)
    im.save(OUT)
    print(os.path.relpath(OUT, os.path.join(HERE, '..', '..', '..')))
