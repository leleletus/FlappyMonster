#!/usr/bin/env python3
# tools/ui/make_sprites.py
# Genera los sprites de interfaz (pixel art) que usa el juego:
#   assets/images/ui/touch/dpad-Sheet.png   cruceta táctil, 7 cuadros de 40x40:
#                                           neutra, izq, der, abajo, abajo-izq, abajo-der, arriba
#   assets/images/ui/touch/jump-Sheet.png   botón de salto, 2 cuadros de 32x32: suelto, pulsado
#   assets/images/ui/ping/ping-Sheet.png    antena de conexión, 5 cuadros de 20x12:
#                                           0 = sin conexión (X roja), 1 roja, 2-3 amarillas, 4 verdes
# Los PNG que salen son los que carga el juego: se pueden retocar a mano
# (Aseprite...) sin volver a ejecutar esto. Ejecutar desde la raíz del repo:
#     python3 tools/ui/make_sprites.py
import os
from PIL import Image

K = (12, 12, 16, 255)          # contorno
W = (232, 232, 240, 255)       # cuerpo
L = (255, 255, 255, 255)       # brillo
D = (150, 150, 168, 255)       # sombra interior
A = (70, 70, 86, 255)          # flechas
Y = (255, 214, 64, 255)        # pulsado
YD = (196, 150, 20, 255)       # pulsado, sombra
_ = None


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print('  ' + path, img.size)


def sheet(frames, w, h):
    img = Image.new('RGBA', (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        img.paste(f, (i * w, 0))
    return img


# ── Cruceta ───────────────────────────────────────────────────────────────────
def dpad(pressed):
    """pressed = conjunto de brazos pulsados: 'l', 'r', 'd', 'u'."""
    S, arm = 40, 14                      # tamaño y grosor de los brazos
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    px = img.load()
    a0, a1 = (S - arm) // 2, (S + arm) // 2          # 13..27

    def in_cross(x, y):
        return (a0 <= x < a1 and 0 <= y < S) or (a0 <= y < a1 and 0 <= x < S)

    def arm_of(x, y):
        if a0 <= y < a1 and x < a0: return 'l'
        if a0 <= y < a1 and x >= a1: return 'r'
        if a0 <= x < a1 and y >= a1: return 'd'
        if a0 <= x < a1 and y < a0: return 'u'
        return 'c'

    for y in range(S):
        for x in range(S):
            if not in_cross(x, y):
                continue
            edge = not (in_cross(x - 1, y) and in_cross(x + 1, y) and in_cross(x, y - 1) and in_cross(x, y + 1))
            which = arm_of(x, y)
            on = which in pressed
            if edge:
                px[x, y] = K
            else:
                col = Y if on else W
                # brillo arriba-izquierda, sombra abajo-derecha
                if not in_cross(x, y - 2) or not in_cross(x - 2, y):
                    col = L if not on else (255, 236, 150, 255)
                if not in_cross(x, y + 2) or not in_cross(x + 2, y):
                    col = YD if on else D
                px[x, y] = col
    # hoyuelo del centro
    c = S // 2
    for y in range(c - 3, c + 3):
        for x in range(c - 3, c + 3):
            if (x - c + 0.5) ** 2 + (y - c + 0.5) ** 2 <= 9:
                px[x, y] = D
    # flechas en cada brazo (triángulos de 5)
    def tri(cx, cy, dx, dy, col):
        for k in range(4):
            for j in range(-k, k + 1):
                x = cx + dx * (3 - k) + (j if dx == 0 else 0)
                y = cy + dy * (3 - k) + (j if dy == 0 else 0)
                px[x, y] = col
    arrow = lambda a: YD if a in pressed else A
    tri(6, c, -1, 0, arrow('l'))
    tri(S - 7, c, 1, 0, arrow('r'))
    tri(c, S - 7, 0, 1, arrow('d'))
    tri(c, 6, 0, -1, arrow('u'))
    return img


# ── Botón de salto ────────────────────────────────────────────────────────────
def jump(pressed):
    S = 32
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    px = img.load()
    off = 1 if pressed else 0
    c = (S - 1) / 2

    def inside(x, y):
        # círculo "pixelado" (octógono suave)
        return (x - c) ** 2 + (y - c) ** 2 <= 14.6 ** 2

    for y in range(S):
        for x in range(S):
            if not inside(x, y):
                continue
            edge = not (inside(x - 1, y) and inside(x + 1, y) and inside(x, y - 1) and inside(x, y + 1))
            if edge:
                px[x, y] = K
                continue
            col = Y if pressed else W
            if not pressed and (not inside(x - 2, y - 2)):
                col = L
            if not inside(x + 2, y + 2):
                col = YD if pressed else D
            px[x, y] = col
    # flecha hacia arriba (salto)
    ac = (YD if pressed else A)
    cx, top = 15, 8 + off
    for k in range(7):                       # punta
        for j in range(-k, k + 1):
            px[cx + j, top + k] = ac
            px[cx + 1 + j, top + k] = ac if -k <= j + 1 <= k else px[cx + 1 + j, top + k]
    for y in range(top + 7, top + 16):       # palo
        for x in range(cx - 2, cx + 4):
            px[x, y] = ac
    return img


# ── Antena de conexión ────────────────────────────────────────────────────────
def ping(level):
    Wd, H = 20, 12
    img = Image.new('RGBA', (Wd, H), (0, 0, 0, 0))
    px = img.load()
    grey = (220, 220, 232, 255)
    # mástil y travesaño
    for y in range(H - 10, H):
        px[1, y] = grey
    for x in range(0, 3):
        px[x, H - 10] = grey
    cols = {1: (240, 52, 52, 255), 2: (255, 210, 40, 255), 3: (255, 210, 40, 255), 4: (80, 230, 90, 255)}
    empty = (64, 64, 78, 255)
    for i in range(1, 5):
        bx, h = 4 + (i - 1) * 4, i * 2 + 1
        col = cols[level] if i <= level else empty
        for y in range(H - h, H):
            for x in range(bx, bx + 3):
                px[x, y] = col
    if level == 0:                           # X roja gruesa sobre las barras
        red = (240, 40, 40, 255)
        for k in range(10):
            for t in (0, 1):
                y = 1 + k
                px[5 + k + t, y] = red
                px[15 - k + t, y] = red
    return img


if __name__ == '__main__':
    print('Sprites de interfaz:')
    frames = [set(), {'l'}, {'r'}, {'d'}, {'d', 'l'}, {'d', 'r'}, {'u'}]
    save(sheet([dpad(f) for f in frames], 40, 40), 'assets/images/ui/touch/dpad-Sheet.png')
    save(sheet([jump(False), jump(True)], 32, 32), 'assets/images/ui/touch/jump-Sheet.png')
    save(sheet([ping(i) for i in range(5)], 20, 12), 'assets/images/ui/ping/ping-Sheet.png')
