#!/usr/bin/env python3
# tools/ui/make_snowboss_cracks.py
# Grietas del jefe GRAN BOLA DE NIEVE adaptadas a CADA cuadro (fase 3 y muerte).
# Parte de los sprites ACTUALES (no los regenera: body-Sheet.png puede estar retocado
# a mano) y de las grietas base cracks-Sheet.png (dibujadas sobre la bola quieta):
#   cracks_body-Sheet.png  16x16 x (3 niveles x 12 cuadros del cuerpo)
#                          índice = (nivel-1)*12 + cuadro
#   cracks_roll-Sheet.png  16x16 x (3 niveles x 8 cuadros de rodar)
#                          índice = (nivel-1)*8 + cuadro
# Cuerpo: las grietas se aplastan hacia los pies igual que la bola (fila de arriba del
# cuadro → fila de arriba de la bola quieta; los pies quedan fijos). Rodando: giran
# 45° por cuadro como la cara (misma rotación por píxel). Siempre se recortan al
# interior de la nieve del cuadro (nunca sobre el contorno ni fuera de la bola).
# Desde la raíz del repo:  python3 tools/ui/make_snowboss_cracks.py
import os
import sys
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from make_snowboss_sprites import rotated_face  # noqa: E402  (misma rotación que la cara)

D = 'assets/images/bosses/snowboss/'
CLEAR = (0, 0, 0, 0)


def frames(path, fw=16):
    im = Image.open(D + path).convert('RGBA')
    return [im.crop((i * fw, 0, i * fw + fw, im.height)) for i in range(im.width // fw)]


def interior(fr, x, y):
    """Píxel de nieve (no transparente y no contorno oscuro)."""
    p = fr.getpixel((x, y))
    return p[3] > 0 and p[0] >= 60


def span(fr):
    """Primera y última fila con píxeles opacos."""
    rows = [y for y in range(fr.height) if any(fr.getpixel((x, y))[3] for x in range(fr.width))]
    return rows[0], rows[-1]


def crack_pixels(cr):
    return [(x, y, cr.getpixel((x, y))) for y in range(16) for x in range(16) if cr.getpixel((x, y))[3]]


def fit(px, fr):
    out = Image.new('RGBA', (16, 16), CLEAR)
    for x, y, c in px:
        if 0 <= x < 16 and 0 <= y < 16 and interior(fr, x, y):
            out.putpixel((x, y), c)
    return out


def body_cracks(pixels, ref, fr):
    t0, b0 = span(ref)
    t1, b1 = span(fr)
    k = (b1 - t1) / max(1, b0 - t0)
    moved = [(x, b1 - round((b0 - y) * k), c) for x, y, c in pixels]
    return fit(moved, fr)


def roll_cracks(pixels, k, fr):
    if k == 0:
        return fit(pixels, fr)
    out = []
    col = {}
    for x, y, c in pixels:
        col[(x, y)] = c
    # rota la máscara con la misma función que la cara y recupera el color
    rot = rotated_face([(x, y, None) for x, y, _ in pixels], k * 45)
    c = pixels[0][2] if pixels else (0, 0, 0, 255)
    for x, y, _ in rot:
        out.append((x, y, c))
    return fit(out, fr)


def sheet(fs):
    out = Image.new('RGBA', (16 * len(fs), 16), CLEAR)
    for i, f in enumerate(fs):
        out.paste(f, (i * 16, 0))
    return out


def build():
    body = frames('body-Sheet.png')
    rolls = frames('roll_angry-Sheet.png')
    base = frames('cracks-Sheet.png')
    ref = body[0]
    bodys, rollss = [], []
    for cr in base:
        px = crack_pixels(cr)
        bodys += [body_cracks(px, ref, fr) for fr in body]
        rollss += [roll_cracks(px, k, fr) for k, fr in enumerate(rolls)]
    return {'cracks_body-Sheet.png': sheet(bodys), 'cracks_roll-Sheet.png': sheet(rollss)}


if __name__ == '__main__':
    for name, im in build().items():
        im.save(D + name)
        print('  %-44s %dx%d' % (D + name, im.width, im.height))
