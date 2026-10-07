#!/usr/bin/env python3
# tools/ui/make_bomb_sprites.py
# Sprites derivados de las bombas del usuario (assets/images/enemies/bomb/):
#   bomb-fuse-Sheet.png        mecha ENCENDIDA de bomb-Sheet.png (bomba viva)
#   bombObject-fuse-Sheet.png  mecha encendida de bombObject-Sheet.png (objeto)
#       8 cuadros de 15x16: 1-4 = los 4 cuadros de la hoja con la mecha en
#       brasa (variante A), 5-8 = la otra variante (parpadeo). Solo están los
#       píxeles de la mecha (se dibuja ENCIMA del sprite).
#   explosion-Sheet.png        explosión, 7 cuadros de 48x48: destello, bola de
#                              fuego que crece, humo que se deshace
# No pisa los que ya existen (--force para rehacerlos). Desde la raíz del repo:
#     python3 tools/ui/make_bomb_sprites.py [--force]
import os, sys, math, random
from PIL import Image

FORCE = '--force' in sys.argv
DIR = 'assets/images/enemies/bomb'
FUSE = (164, 120, 72, 255)                  # color de la mecha en las hojas (cuerda; ver retouch_bomb.py)
FW = 15


def save(img, path):
    if os.path.exists(path) and not FORCE:
        print('  ' + path + ' ya existe: no se toca (--force para rehacerlo)')
        return
    img.save(path)
    print('  ' + path, img.size)


def fuse_sheet(src):
    base = Image.open(os.path.join(DIR, src)).convert('RGBA')
    n = base.width // FW
    out = Image.new('RGBA', (FW * n * 2, base.height), (0, 0, 0, 0))
    tips = []
    # brasa: punta blanca-amarilla, luego naranja, base roja
    palA = [(255, 250, 200, 255), (255, 190, 40, 255), (240, 90, 20, 255), (170, 40, 20, 255)]
    palB = [(255, 220, 90, 255), (255, 240, 170, 255), (250, 120, 30, 255), (200, 60, 20, 255)]
    for f in range(n):
        px = [(x, y) for x in range(f * FW, (f + 1) * FW) for y in range(base.height)
              if base.getpixel((x, y)) == FUSE]
        px.sort(key=lambda p: (p[1], -abs(p[0] - (f * FW + 7))))   # de la punta (arriba) a la base
        tips.append((px[0][0] - f * FW, px[0][1]) if px else (7, 0))
        for v, pal in enumerate((palA, palB)):
            for i, (x, y) in enumerate(px):
                out.putpixel((x + v * n * FW, y), pal[min(i, len(pal) - 1)])
    print('    puntas de la mecha (x, y por cuadro):', tips)
    return out


def explosion():
    S, N = 48, 7
    rnd = random.Random(5)
    out = Image.new('RGBA', (S * N, S), (0, 0, 0, 0))
    K = (20, 12, 10, 255)
    fire = [(255, 255, 230, 255), (255, 230, 90, 255), (255, 150, 40, 255), (220, 70, 30, 255)]
    smoke = [(150, 145, 150, 255), (110, 105, 112, 255), (80, 76, 84, 255)]
    lobes = [(rnd.uniform(0, 6.28), rnd.uniform(0.75, 1.0)) for _ in range(7)]

    def radius_at(a, r):
        # borde irregular: la bola con "lóbulos"
        k = 0.82 + 0.18 * max(math.cos(a - la) ** 8 * lk for la, lk in lobes)
        return r * k

    for f in range(N):
        ox = f * S
        c = (S - 1) / 2
        if f == 0:                                  # destello
            R = 9
            for y in range(S):
                for x in range(S):
                    d = math.hypot(x - c, y - c)
                    if d <= R:
                        out.putpixel((ox + x, y), fire[0] if d < R - 2 else fire[1])
            for k in range(4):                     # rayos del destello
                a = k * math.pi / 2 + math.pi / 4
                for t in range(10, 18):
                    out.putpixel((ox + int(c + math.cos(a) * t), int(c + math.sin(a) * t)), fire[1])
            continue
        if f <= 3:                                  # bola de fuego que crece
            R = [0, 14, 19, 22][f]
            for y in range(S):
                for x in range(S):
                    d = math.hypot(x - c, y - c)
                    a = math.atan2(y - c, x - c)
                    rr = radius_at(a + f * 0.3, R)
                    if d <= rr:
                        edge = d > rr - 1.5
                        if edge:
                            col = K
                        else:
                            q = d / rr
                            col = fire[0] if q < 0.3 else fire[1] if q < 0.55 else fire[2] if q < 0.8 else fire[3]
                        out.putpixel((ox + x, y), col)
            continue
        # humo: varias bolas grises que se separan y encogen
        k = f - 3                                   # 1..3
        for i in range(6):
            a = i / 6 * 6.28 + 0.4
            dist = 8 + k * 5
            cx, cy = c + math.cos(a) * dist, c + math.sin(a) * dist * 0.8 - k * 2
            r = max(2.5, 8 - k * 1.8)
            for y in range(S):
                for x in range(S):
                    d = math.hypot(x - cx, y - cy)
                    if d <= r:
                        col = K if d > r - 1.2 else smoke[min(2, k - 1 if d < r * 0.5 else k)]
                        if out.getpixel((ox + x, y))[3] == 0 or col != K:
                            out.putpixel((ox + x, y), col)
    return out


if __name__ == '__main__':
    print('Sprites de las bombas:')
    save(fuse_sheet('bomb-Sheet.png'), os.path.join(DIR, 'bomb-fuse-Sheet.png'))
    save(fuse_sheet('bombObject-Sheet.png'), os.path.join(DIR, 'bombObject-fuse-Sheet.png'))
    save(explosion(), os.path.join(DIR, 'explosion-Sheet.png'))
