#!/usr/bin/env python3
# tools/art/fx/make_screen_crack.py — la PANTALLA ROTA del final de los créditos (src/story/films/credits.lua, F.finale):
# el Espejo vencido sale volando hacia la cámara y se ESTRELLA contra la pantalla; aquí, las grietas del cristal.
# Pixel art (líneas de 1 px, sin suavizar): un golpe en el centro hecho trizas, grietas que salen en estrella
# quebrándose y ramificándose, y trozos de anillo alrededor del golpe. Blanco azulado con su sombra de 1 px (que se
# vea sobre cualquier fondo). Se dibuja a ×5 centrado en el sitio del golpe.
#   assets/images/fx/screen_crack.png     (160 x 120)
#   python3 tools/art/fx/make_screen_crack.py
import math
import os
import random
from PIL import Image

W, H = 160, 120
CX, CY = W // 2, H // 2
LINE = (232, 244, 255, 255)
GLINT = (255, 255, 255, 255)
SHADOW = (12, 16, 32, 150)

rnd = random.Random(7)
lines = set()


def seg(x0, y0, x1, y1):
    """Bresenham: los píxeles de un segmento"""
    x0, y0, x1, y1 = int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        lines.add((x0, y0))
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy; x0 += sx
        if e2 <= dx:
            err += dx; y0 += sy


def crack(x, y, ang, length, depth):
    """Una grieta quebrada: tramos de 5-11 px que tuercen un poco; a veces se abre en dos"""
    left = length
    while left > 0:
        step = rnd.uniform(5, 11)
        ang += rnd.uniform(-0.18, 0.18)
        nx, ny = x + math.cos(ang) * step, y + math.sin(ang) * step
        seg(x, y, nx, ny)
        x, y, left = nx, ny, left - step
        if depth > 0 and rnd.random() < 0.14:
            crack(x, y, ang + rnd.choice((-1, 1)) * rnd.uniform(0.5, 0.9), left * rnd.uniform(0.3, 0.6), depth - 1)
        if x < 1 or x > W - 2 or y < 1 or y > H - 2:
            break


# las grietas en estrella desde el golpe
n = 11
for i in range(n):
    a = i / n * 2 * math.pi + rnd.uniform(-0.2, 0.2)
    crack(CX + math.cos(a) * 3, CY + math.sin(a) * 3, a, rnd.uniform(45, 90), 2)
# anillos rotos alrededor (trozos de polígono)
for r in (8, 15, 24):
    k = 9 + r // 3
    pts = [(CX + math.cos(j / k * 2 * math.pi) * (r + rnd.uniform(-1.5, 1.5)),
            CY + math.sin(j / k * 2 * math.pi) * (r + rnd.uniform(-1.5, 1.5)) * 0.85) for j in range(k)]
    for j in range(k):
        if rnd.random() < 0.7:
            (ax, ay), (bx, by) = pts[j], pts[(j + 1) % k]
            seg(ax, ay, bx, by)
# el centro, hecho trizas
for _ in range(40):
    lines.add((CX + rnd.randint(-3, 3), CY + rnd.randint(-3, 3)))

im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
for (x, y) in lines:                                # (primero la sombra, abajo a la derecha)
    if 0 <= x + 1 < W and 0 <= y + 1 < H and (x + 1, y + 1) not in lines:
        im.putpixel((x + 1, y + 1), SHADOW)
for (x, y) in lines:
    if 0 <= x < W and 0 <= y < H:
        d = math.hypot(x - CX, y - CY)
        im.putpixel((x, y), GLINT if d < 6 or rnd.random() < 0.08 else LINE)
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', 'assets', 'images', 'fx', 'screen_crack.png')
im.save(os.path.normpath(out))
print('screen_crack.png', len(lines), 'px')
