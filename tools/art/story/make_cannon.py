#!/usr/bin/env python3
# tools/art/story/make_cannon.py
# El CAÑÓN del mapa del mundo (el usuario, 2026-10-29: "para cambiar de isla se usa un puente; estaba pensando en usar
# un cañón. El cañón se carga con el jugador, apunta y dispara"). Un cañón de CIRCO (el de la bala humana): cañón
# rojo largo y fino con la boca en campana y aros dorados, sobre una cureña azul de una rueda. Pocos colores, zonas
# planas, contorno oscuro. Escribe assets/images/story/cannon/:
#   barrel-Sheet.png    el CAÑÓN apuntando a la derecha, de 0 a 90 grados de 10 en 10 (cuadros 1..10, 32x32, el eje
#                       en el píxel 16,16) y el cuadro 11: a 20 grados TAPONADO (un corcho: el cruce aún cerrado)
#   carriage.png        la cureña con su rueda (16x11; el eje del cañón en el 7,2; los pies abajo)
#   smoke-Sheet.png     bocanada de humo, 4 cuadros 12x12 (nace, crece, grande, se deshace): humo y polvo
#   flash-Sheet.png     el fogonazo, 3 cuadros 16x16
#   spark-Sheet.png     la chispa de la mecha, 3 cuadros 7x7
# y una hoja de muestra (x4) en /home/mtvemo/FlappyMonster_pruebas/canones/hoja.png
#   python3 tools/art/story/make_cannon.py        (determinista)
import math, os
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..')
OUT = os.path.join(ROOT, 'assets', 'images', 'story', 'cannon')
PREVIEW = '/home/mtvemo/FlappyMonster_pruebas/canones/hoja.png'

INK = (24, 22, 32, 255)
RED, RED_L = (196, 48, 52, 255), (240, 104, 84, 255)
GOLD = (244, 196, 64, 255)
BORE = (12, 10, 18, 255)
BLUE, BLUE_D = (58, 92, 176, 255), (36, 58, 124, 255)
CORK = (196, 140, 84, 255)
FUSE = (110, 74, 48, 255)
CLEAR = (0, 0, 0, 0)

FW = 32            # cuadro del cañón
PIV = 16           # su eje (en el cuadro)


def outline(im):
    """contorno oscuro: los píxeles vacíos que tocan (en cruz) uno pintado"""
    w, h = im.size
    px = im.load()
    add = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0 and any(0 <= x + dx < w and 0 <= y + dy < h and px[x + dx, y + dy][3] > 0 and px[x + dx, y + dy] != INK
                                        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                add.append((x, y))
    for x, y in add:
        px[x, y] = INK


def half(u):
    """medio grosor del cañón a la distancia u del eje (hacia la boca): culata redonda, cuerpo que adelgaza, campana"""
    if u < -3:
        return math.sqrt(max(0.0, 2.6 ** 2 - (u + 3) ** 2))         # culata (media bola)
    if u < 9:
        return 2.6 - 0.75 * (u + 3) / 12                             # el cuerpo, cada vez más fino
    return 1.85 + 1.9 * ((u - 9) / 4) ** 1.6                         # la campana de la boca


def barrel(deg, plug=False):
    im = Image.new('RGBA', (FW, FW), CLEAR)
    a = math.radians(deg)
    dx_, dy_ = math.cos(a), -math.sin(a)               # hacia la boca
    nx, ny = math.sin(a), math.cos(a)                  # hacia "abajo" del cañón
    for y in range(FW):
        for x in range(FW):
            px, py = x + 0.5 - PIV, y + 0.5 - PIV
            u = px * dx_ + py * dy_
            v = px * nx + py * ny
            col = None
            if -5.6 <= u <= 13 and abs(v) <= half(u):
                col = RED
                if v < -half(u) * 0.25:
                    col = RED_L                                         # el brillo de arriba
                if 1.2 <= u <= 2.6 or (u >= 11.4):
                    col = GOLD                                          # el aro y el borde de la boca
                if u >= 12.0 and abs(v) <= half(u) - 1.0:
                    col = BORE                                          # la boca, abierta
            if plug and 11.6 <= u <= 14.8 and abs(v) <= 1.8:
                col = CORK                                              # el corcho (cruce cerrado)
            # la mecha: sale de la culata hacia arriba
            if -3.6 <= u <= -2.4 and -5.4 <= v <= -2.0:
                col = col or FUSE
            if col:
                im.putpixel((x, y), col)
    outline(im)
    return im


def carriage():
    rows = [
        '................',
        '................',
        '.....bbbb.......',
        '...bbbbbbbbb....',
        '..bbBBBBBbbbbb..',
        '..bBBBBBBBBbbb..',
        '..bBBBBBBBBBbb..',
        '.....gggg.......',
        '....g....g......',
        '....g.gg.g......',
        '.....gggg.......',
    ]
    pal = {'b': BLUE, 'B': BLUE_D, 'g': GOLD, '.': CLEAR}
    im = Image.new('RGBA', (16, 11), CLEAR)
    # la rueda: un aro dorado con su buje, sobre la cureña
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            im.putpixel((x, y), pal[ch])
    for y in range(11):
        for x in range(16):
            d = math.hypot(x + 0.5 - 6.5, y + 0.5 - 7.5)
            if 2.2 <= d <= 3.4:
                im.putpixel((x, y), GOLD)
            elif d < 2.2:
                im.putpixel((x, y), BLUE_D if d > 0.9 else GOLD)
    outline(im)
    return im


def blob_frame(size, circles, light=(236, 236, 240, 255), shade=(176, 180, 196, 255)):
    im = Image.new('RGBA', (size, size), CLEAR)
    for y in range(size):
        for x in range(size):
            for cx, cy, r in circles:
                d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
                if d <= r:
                    im.putpixel((x, y), light if (y + 0.5 - cy) < r * 0.25 else shade)
                    break
    return im


def smoke():
    return [blob_frame(12, [(6, 6.5, 2.4)]),
            blob_frame(12, [(6, 6.5, 3.8), (4, 5, 2.2)]),
            blob_frame(12, [(6, 6.5, 4.8), (3.4, 4.6, 2.6), (8.6, 4.4, 2.4)]),
            blob_frame(12, [(3.2, 7, 2.0), (8.4, 6, 2.2), (6, 3, 1.6)])]


def flash():
    out = []
    for k, (r_in, r_out, spikes) in enumerate(((2.6, 5.5, 6), (3.8, 7.6, 8), (2.4, 5.0, 8))):
        im = Image.new('RGBA', (16, 16), CLEAR)
        for y in range(16):
            for x in range(16):
                px, py = x + 0.5 - 8, y + 0.5 - 8
                d = math.hypot(px, py)
                ang = math.atan2(py, px)
                reach = r_in + (r_out - r_in) * max(0.0, math.cos(ang * spikes / 2 + k)) ** 3
                if d <= reach:
                    im.putpixel((x, y), (255, 255, 236, 255) if d < r_in * 0.7 else
                                (255, 214, 72, 255) if d < r_in + 1 else (240, 120, 40, 255))
        out.append(im)
    return out


def spark():
    pal = {'.': CLEAR, 'w': (255, 255, 230, 255), 'y': (255, 210, 70, 255), 'o': (236, 112, 36, 255)}
    frames = [['.......', '.......', '...y...', '..ywy..', '...y...', '.......', '.......'],
              ['.......', '.o...o.', '...y...', '.ywwwy.', '...y...', '.o...o.', '.......'],
              ['...o...', '...y...', '.o.w.o.', 'oywwwyo', '.o.w.o.', '...y...', '...o...']]
    out = []
    for f in frames:
        im = Image.new('RGBA', (7, 7), CLEAR)
        for y, r in enumerate(f):
            for x, ch in enumerate(r):
                im.putpixel((x, y), pal[ch])
        out.append(im)
    return out


def strip(frames, name):
    w, h = frames[0].size
    im = Image.new('RGBA', (w * len(frames), h), CLEAR)
    for i, f in enumerate(frames):
        im.paste(f, (i * w, 0))
    im.save(os.path.join(OUT, name))
    print('  story/cannon/%s %dx%d (%d cuadros)' % (name, im.width, im.height, len(frames)))
    return im


os.makedirs(OUT, exist_ok=True)
bar = strip([barrel(d) for d in range(0, 91, 10)] + [barrel(20, plug=True)], 'barrel-Sheet.png')
car = carriage()
car.save(os.path.join(OUT, 'carriage.png'))
print('  story/cannon/carriage.png 16x11')
smk = strip(smoke(), 'smoke-Sheet.png')
fla = strip(flash(), 'flash-Sheet.png')
spk = strip(spark(), 'spark-Sheet.png')

# ── hoja de muestra (x4): los cañones montados (como en el juego) a varios ángulos, el taponado y los efectos ──
S = 4
os.makedirs(os.path.dirname(PREVIEW), exist_ok=True)
sheet = Image.new('RGBA', (FW * 6 * S, (FW + 26) * S), (54, 112, 168, 255))


def mounted(fi, x0, y0):
    b = bar.crop(((fi - 1) * FW, 0, fi * FW, FW))
    sheet.alpha_composite(b.resize((FW * S, FW * S), Image.NEAREST), (x0 + (7 - PIV) * S, y0 + (2 - PIV) * S))
    sheet.alpha_composite(car.resize((16 * S, 11 * S), Image.NEAREST), (x0, y0))


for i, fi in enumerate((1, 3, 5, 7, 10, 11)):
    mounted(fi, i * FW * S + 8 * S, 18 * S)
for i, f in enumerate([smk, fla, spk]):
    sheet.alpha_composite(f.resize((f.width * S, f.height * S), Image.NEAREST), (8 * S + i * 70 * S, (FW + 2) * S))
sheet.save(PREVIEW)
print('  ' + PREVIEW)
