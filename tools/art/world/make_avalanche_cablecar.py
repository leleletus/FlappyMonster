#!/usr/bin/env python3
# EL ALUD y EL TELEFÉRICO (mecánicas de las Montañas Heladas, 2026-10-29; diseño aprobado por el usuario en
# FlappyMonster_pruebas/islas_heladas/diseno.md §A 4-5). Sencillo y plano: pocos colores, siluetas claras.
#   ALUD (assets/images/traps/avalanche/, solo nieve):
#     cornice-Sheet.png  la CORNISA de nieve que cuelga bajo el saliente de arriba del canal (16x8, 2 cuadros: quieta /
#                        temblando, con grietas); se repite a lo ancho
#     stream-Sheet.png   el TORRENTE (16x16, 3 cuadros que bajan: se repite hacia abajo y a lo ancho)
#     side-Sheet.png     el borde deshilachado del torrente (4x16, 3 cuadros; el derecho, el izquierdo se gira)
#     head-Sheet.png     el FRENTE que cae (16x16, 3 cuadros: una nube de polvo de nieve que rueda)
#     splash-Sheet.png   lo que salta al chocar abajo (16x8, 3 cuadros)
#     flake-Sheet.png    copos del aviso (4x4, 3 cuadros)
#   TELEFÉRICO (assets/images/mechanisms/cablecar/<isla>-*.png, una por isla de Isles.IDS — `isleArt` —; neutro de
#   metal y madera en todas, cada isla con su pintura; la nieve con nieve encima):
#     cabin.png          la CABINA (48x28): gancho arriba, dos brazos en A y la plataforma de madera (filas 22-27: la
#                        que se pisa)
#     trolley-Sheet.png  el CARRO que rueda por el cable (16x8, 2 cuadros: ruedas girando); el cable pasa por la fila 4
#     cable.png          un tramo de CABLE (8x2; se repite girado a lo largo de cada tramo)
#     pulley-Sheet.png   la POLEA de cada punto (12x12, 2 cuadros)
#     tower.png          un tramo de TORRE de celosía (16x16, se repite hacia abajo hasta el suelo)
#     towertop.png       el remate de la torre que sujeta la polea (16x8)
#     towerfoot.png      la zapata de la torre en el suelo (16x8)
#     hanger.png         la VARILLA de la que cuelga una polea sin suelo debajo (4x8, se repite hacia arriba)
#     clamp.png          el anclaje de la varilla en el techo (8x4)
#   python3 tools/art/world/make_avalanche_cablecar.py           → vista previa en FlappyMonster_pruebas/mecanicas_heladas/
#   python3 tools/art/world/make_avalanche_cablecar.py --apply   → además escribe los PNG en assets/
import os, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
PRUEBAS = os.path.join(os.environ.get('FM_PRUEBAS', '/home/mtvemo/FlappyMonster_pruebas'), 'mecanicas_heladas')
OUT_AV = os.path.join(ROOT, 'assets', 'images', 'traps', 'avalanche')
OUT_CC = os.path.join(ROOT, 'assets', 'images', 'mechanisms', 'cablecar')
ISLE_IDS = ['pradera', 'costa', 'fortaleza', 'nieve', 'cueva', 'volcan', 'jungla']


def rgb(h, a=255): return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


class G:
    """Rejilla de letras → imagen con una paleta (letra → color hex; '.' = transparente)"""
    def __init__(self, w, h): self.w, self.h, self.g = w, h, [['.'] * w for _ in range(h)]
    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h: self.g[y][x] = c
    def get(self, x, y): return self.g[y][x] if 0 <= x < self.w and 0 <= y < self.h else '.'
    def rect(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w): self.put(xx, yy, c)
    def line(self, x0, y0, x1, y1, c, th=1):
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(n + 1):
            x = round(x0 + (x1 - x0) * i / n); y = round(y0 + (y1 - y0) * i / n)
            self.rect(x, y, th, 1, c)
    def img(self, pal, alpha=None):
        im = Image.new('RGBA', (self.w, self.h))
        for y in range(self.h):
            for x in range(self.w):
                c = self.g[y][x]
                if c != '.': im.putpixel((x, y), rgb(pal[c], (alpha or {}).get(c, 255)))
        return im


def strip(frames):
    w, h = frames[0].size
    out = Image.new('RGBA', (w * len(frames), h))
    for i, f in enumerate(frames): out.paste(f, (i * w, 0))
    return out


# ── EL ALUD ──────────────────────────────────────────────────────────────────────────────────────────────────────
# o contorno azul · s sombra · b nieve · h brillo · d polvo (semitransparente) · k grieta
SNOW = dict(o='4a78a8', s='9cc4e6', b='e2f2fc', h='ffffff', d='f4fbff', k='6a98c4')
SNOW_A = {'d': 150}


def cornice(shake):
    """La cornisa: una franja de nieve (filas 0-4) con el borde de abajo ondulado y carámbanos de nieve cortos"""
    g = G(16, 8)
    g.rect(0, 0, 16, 4, 'b'); g.rect(0, 0, 16, 1, 'h')
    bottom = [4, 5, 5, 4, 4, 5, 6, 5, 4, 4, 5, 5, 4, 5, 6, 5]           # (el borde de abajo, ondulado)
    for x, yb in enumerate(bottom):
        g.rect(x, 3, 1, yb - 3, 'b'); g.put(x, yb, 'o'); g.put(x, yb - 1, 's')
    if shake:                                                            # (temblando: grietas y un terrón que se suelta)
        for x, y in ((3, 1), (4, 2), (5, 2), (10, 1), (11, 2), (11, 3)): g.put(x, y, 'k')
        g.rect(7, 6, 2, 2, 'b'); g.put(7, 7, 's'); g.put(8, 7, 'o')
    return g.img(SNOW)


def stream(f):
    """El torrente: nieve blanca con rayas de sombra y de brillo que bajan (3 px por cuadro) — se repite en las dos
    direcciones sin juntas"""
    g = G(16, 16)
    g.rect(0, 0, 16, 16, 'b')
    for x, y0, ln, c in ((2, 0, 5, 's'), (7, 6, 6, 's'), (12, 11, 5, 's'), (4, 9, 4, 'h'), (10, 2, 5, 'h'), (14, 4, 3, 's'),
                         (0, 12, 3, 'h')):
        for k in range(ln): g.put(x, (y0 + k + f * 5) % 16, c)
    return g.img(SNOW)


def side(f):
    """El borde (derecho) del torrente: polvo que se deshilacha hacia fuera"""
    g = G(4, 16)
    edge = [2, 3, 3, 2, 1, 2, 3, 4, 3, 2, 2, 1, 2, 3, 3, 2]
    for y in range(16):
        e = edge[(y - f * 5) % 16]
        g.rect(0, y, min(e, 2), 1, 'b')
        if e > 2: g.rect(2, y, e - 2, 1, 'd')
    return g.img(SNOW, SNOW_A)


def head(f):
    """El frente: una nube redonda de polvo de nieve que rueda (más ancha que el torrente: sobresale 2 px por lado)"""
    g = G(16, 16)
    blobs = [((4, 9), 4), ((11, 9), 4), ((8, 12), 4), ((8, 6), 3)]
    rot = [((0, 0), (0, 0), (0, 0), (0, 0)), ((1, -1), (-1, 1), (0, 0), (1, 0)), ((-1, 1), (1, -1), (0, -1), (-1, 0))][f]
    for ((cx, cy), r), (dx, dy) in zip(blobs, rot):
        cx, cy = cx + dx, cy + dy
        for y in range(16):
            for x in range(16):
                d2 = (x - cx) ** 2 + (y - cy) ** 2
                if d2 <= r * r: g.put(x, y, 'b')
    for y in range(16):                                                  # contorno suave abajo, brillo arriba
        for x in range(16):
            if g.get(x, y) == 'b':
                if g.get(x, y + 1) == '.': g.put(x, y, 's')
                elif g.get(x, y - 1) == '.': g.put(x, y, 'h')
    for x, y in ((5 + f, 8), (10 - f, 11), (8, 13 - f)): g.put(x, y, 's')
    return g.img(SNOW)


def splash(f):
    """Lo que salta abajo: un montón que se abre en dos chorros de polvo"""
    g = G(16, 8)
    for x in range(16):                                                  # (el montón: más alto en el centro)
        hgt = max(1, 4 - abs(x - 7.5) // 2)
        g.rect(x, 8 - int(hgt), 1, int(hgt), 'b')
        g.put(x, 8 - int(hgt), 'h')
    spread = (1, 3, 5)[f]
    for k, (x, y) in enumerate(((7 - spread, 3 - f), (8 + spread, 3 - f), (6 - spread - 1, 2), (9 + spread + 1, 2))):
        g.rect(x, max(0, y), 2, 1, 'd' if k > 1 else 'b')
    return g.img(SNOW, SNOW_A)


def flake(f):
    g = G(4, 4)
    if f == 0: g.put(1, 1, 'h'); g.put(2, 1, 'b'); g.put(1, 2, 'b'); g.put(2, 2, 's')
    elif f == 1: g.put(1, 0, 'b'); g.put(0, 1, 'b'); g.put(1, 1, 'h'); g.put(2, 1, 'b'); g.put(1, 2, 'b')
    else: g.put(2, 2, 'h'); g.put(1, 2, 'b')
    return g.img(SNOW)


def avalanche_art():
    return {
        'cornice-Sheet.png': strip([cornice(False), cornice(True)]),
        'stream-Sheet.png': strip([stream(f) for f in range(3)]),
        'side-Sheet.png': strip([side(f) for f in range(3)]),
        'head-Sheet.png': strip([head(f) for f in range(3)]),
        'splash-Sheet.png': strip([splash(f) for f in range(3)]),
        'flake-Sheet.png': strip([flake(f) for f in range(3)]),
    }


# ── EL TELEFÉRICO ────────────────────────────────────────────────────────────────────────────────────────────────
# o contorno del metal · m metal · M metal claro · p pintura (lo de cada isla) · P pintura oscura · W madera oscura ·
# w madera · v madera clara · c cable · C cable oscuro · n nieve (solo la nieve) · N sombra de la nieve · g piedra
# (zapata) · G piedra oscura
BASE = dict(o='2c3038', m='6c7480', M='a4acb8', p='c84c3c', P='8a2c24', W='5a3a22', w='8a5a32', v='b48250',
            c='4c5058', C='24282e', n='ffffff', N='b4d4ee', g='8c8a84', G='5c5a56')
PAINT = {
    'pradera':   dict(p='c84c3c', P='8a2c24'),                               # rojo de refugio de montaña
    'costa':     dict(p='3caab0', P='1e7078', v='c8a070'),                   # turquesa de barco
    'fortaleza': dict(p='585c68', P='34363e', m='5c6470', M='8c94a0'),       # hierro oscuro
    'nieve':     dict(p='4c88c8', P='2c5a90', m='7c8ca0', M='b8c8d8'),       # azul helado, con nieve encima
    'cueva':     dict(p='b0703c', P='744420', m='6a6058', M='988c80'),       # hierro oxidado de mina
    'volcan':    dict(p='e0782c', P='983c14', o='1c1416', m='4a4044', M='726468', g='5a4a48', G='3a2e2c'),
    'jungla':    dict(p='4ca048', P='2a6a2c', W='4a5a24', w='7c8c34', v='a8b450', c='5a5030', C='2e2818'),   # bambú y liana
}


def pal(isle):
    d = dict(BASE); d.update(PAINT[isle]); return d


def cabin(isle):
    g = G(48, 28)
    # el gancho de arriba (agarra el carro): una argolla 4x4
    g.rect(22, 0, 4, 4, 'o'); g.rect(23, 1, 2, 2, 'M')
    # los brazos en A: del vértice a las dos puntas de la plataforma (2 px de grueso, contorno + metal)
    g.line(23, 4, 3, 22, 'o', 2); g.line(24, 4, 44, 22, 'o', 2)
    g.line(23, 5, 4, 22, 'p', 1); g.line(24, 5, 43, 22, 'p', 1)
    g.rect(22, 3, 4, 3, 'p'); g.rect(22, 3, 4, 1, 'o')                  # (la pieza del vértice, pintada)
    # la barra de en medio (refuerzo de la A) a media altura
    g.rect(13, 13, 22, 2, 'o'); g.rect(14, 13, 20, 1, 'M')
    # la PLATAFORMA de madera (filas 22-27): tablas con su borde y dos remaches de metal en las puntas
    g.rect(0, 22, 48, 6, 'w'); g.rect(1, 22, 46, 1, 'v'); g.rect(0, 27, 48, 1, 'W'); g.rect(0, 22, 1, 6, 'W'); g.rect(47, 22, 1, 6, 'W')
    for x in (12, 24, 36): g.rect(x, 23, 1, 4, 'W')
    g.rect(0, 25, 48, 1, 'P' if isle != 'jungla' else 'W')               # (una franja pintada de canto)
    for x in (2, 44): g.rect(x, 23, 2, 2, 'M')
    if isle == 'nieve':                                                  # nieve encima de la barra y de la plataforma
        g.rect(15, 12, 18, 1, 'n'); g.rect(1, 21, 6, 1, 'n'); g.rect(40, 21, 7, 1, 'n'); g.put(41, 20, 'n')
    if isle == 'jungla':                                                 # una liana enrollada en el brazo
        for k in range(4): g.put(9 + k * 3, 17 - k * 3, 'P')
    return g.img(pal(isle))


def trolley(isle, f):
    g = G(16, 8)
    for cx in (4, 11):                                                   # dos ruedas encima del cable (cable en la fila 4)
        g.rect(cx - 2, 0, 4, 4, 'o'); g.rect(cx - 1, 1, 2, 2, 'M')
        g.put(cx - 1 + f, 1, 'm'); g.put(cx - f, 2, 'm')                   # (radio: gira)
    g.rect(1, 4, 14, 3, 'o'); g.rect(2, 5, 12, 1, 'p')                   # la placa (por debajo del cable)
    g.rect(7, 7, 2, 1, 'o')                                              # de donde cuelga el gancho
    if isle == 'nieve': g.rect(2, 0, 2, 1, 'n'); g.rect(10, 0, 3, 1, 'n')
    return g.img(pal(isle))


def cable(isle):
    g = G(8, 2)
    g.rect(0, 0, 8, 1, 'c'); g.rect(0, 1, 8, 1, 'C')
    for x in (1, 5): g.put(x, 0, 'C')                                    # (el trenzado)
    return g.img(pal(isle))


def pulley(isle, f):
    g = G(12, 12)
    cx = cy = 5.5
    for y in range(12):
        for x in range(12):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if d <= 5.6: g.put(x, y, 'o' if d > 4.6 else 'm')
    if f == 0: g.rect(5, 2, 2, 8, 'o'); g.rect(2, 5, 8, 2, 'o')
    else:
        for k in range(-3, 4): g.put(round(cx + k), round(cy + k), 'o'); g.put(round(cx + k), round(cy - k), 'o')
    g.rect(5, 5, 2, 2, 'p')
    if isle == 'nieve': g.rect(3, 0, 6, 1, 'n')
    return g.img(pal(isle))


def tower(isle):
    """Tramo de torre de celosía: dos largueros y una cruz (se repite hacia abajo)"""
    g = G(16, 16)
    for x in (3, 11):
        g.rect(x, 0, 2, 16, 'o'); g.put(x + (1 if x == 3 else 0), 0, 'M')
        g.rect(x + (1 if x == 3 else 0), 0, 1, 16, 'm')
    g.line(5, 1, 10, 7, 'o'); g.line(10, 1, 5, 7, 'o')
    g.line(5, 9, 10, 15, 'o'); g.line(10, 9, 5, 15, 'o')
    g.rect(5, 8, 6, 1, 'o')
    if isle == 'jungla':                                                 # bambú: nudos en los largueros
        for y in (4, 12): g.rect(3, y, 2, 1, 'P'); g.rect(11, y, 2, 1, 'P')
    return g.img(pal(isle))


def towertop(isle):
    """El remate: una cruceta pintada con el eje de la polea en el centro (fila 0-7)"""
    g = G(16, 8)
    g.rect(1, 3, 14, 3, 'o'); g.rect(2, 4, 12, 1, 'p')
    g.rect(3, 6, 2, 2, 'o'); g.rect(11, 6, 2, 2, 'o'); g.rect(4, 6, 1, 2, 'm'); g.rect(11, 6, 1, 2, 'm')
    g.rect(7, 0, 2, 4, 'o')                                              # (el soporte del eje)
    if isle == 'nieve': g.rect(1, 2, 5, 1, 'n'); g.rect(10, 2, 5, 1, 'n')
    return g.img(pal(isle))


def towerfoot(isle):
    g = G(16, 8)
    g.rect(3, 0, 2, 3, 'o'); g.rect(11, 0, 2, 3, 'o'); g.rect(4, 0, 1, 3, 'm'); g.rect(11, 0, 1, 3, 'm')
    g.rect(1, 3, 14, 5, 'g'); g.rect(1, 3, 14, 1, 'G'); g.rect(1, 7, 14, 1, 'G'); g.rect(1, 3, 1, 5, 'G'); g.rect(14, 3, 1, 5, 'G')
    if isle == 'nieve': g.rect(1, 3, 14, 1, 'n')
    return g.img(pal(isle))


def hanger(isle):
    g = G(4, 8)
    g.rect(1, 0, 2, 8, 'o'); g.rect(1, 0, 1, 8, 'm')
    return g.img(pal(isle))


def clamp(isle):
    g = G(8, 4)
    g.rect(0, 0, 8, 2, 'o'); g.rect(1, 0, 6, 1, 'p'); g.rect(3, 2, 2, 2, 'o')
    return g.img(pal(isle))


def cablecar_art(isle):
    return {
        f'{isle}-cabin.png': cabin(isle),
        f'{isle}-trolley-Sheet.png': strip([trolley(isle, f) for f in range(2)]),
        f'{isle}-cable.png': cable(isle),
        f'{isle}-pulley-Sheet.png': strip([pulley(isle, f) for f in range(2)]),
        f'{isle}-tower.png': tower(isle),
        f'{isle}-towertop.png': towertop(isle),
        f'{isle}-towerfoot.png': towerfoot(isle),
        f'{isle}-hanger.png': hanger(isle),
        f'{isle}-clamp.png': clamp(isle),
    }


# ── Vista previa: cada isla en una tira (torre, cable, cabina) + el alud cayendo por un canal ─────────────────────
def frame(im, i, w):
    return im.crop((i * w, 0, (i + 1) * w, im.size[1]))


def preview(av, cc):
    S = 4
    BGC = {'pradera': '8cc8f0', 'costa': '9cdcf0', 'fortaleza': '8a8ea8', 'nieve': '3a4a6a', 'cueva': '3a3450',
           'volcan': '6a2c2c', 'jungla': '5c8a5a'}
    cols = 4
    cw, ch = 110, 70
    rows = (len(ISLE_IDS) + 1 + cols - 1) // cols
    out = Image.new('RGBA', (cols * cw * S, rows * ch * S), rgb('202020'))
    for k, isle in enumerate(ISLE_IDS + ['alud']):
        tile = Image.new('RGBA', (cw, ch), rgb(BGC.get(isle, '3a4a6a')))
        if isle == 'alud':
            rock = Image.new('RGBA', (16, 16), rgb('4a5060'))
            for x in range(0, 40, 16): tile.alpha_composite(rock, (x, 0))     # (el saliente de arriba)
            for x in range(0, cw, 16): tile.alpha_composite(rock, (x, ch - 10))
            for x in range(4, 36, 16): tile.alpha_composite(frame(av['cornice-Sheet.png'], 1, 16), (x, 16))
            for y in range(20, ch - 18, 16):
                for x in range(4, 36, 16): tile.alpha_composite(frame(av['stream-Sheet.png'], (y // 16) % 3, 16), (x, y))
                tile.alpha_composite(frame(av['side-Sheet.png'], 0, 4), (36, y))
                tile.alpha_composite(frame(av['side-Sheet.png'], 0, 4).transpose(Image.FLIP_LEFT_RIGHT), (0, y))
            for x in range(4, 36, 16): tile.alpha_composite(frame(av['splash-Sheet.png'], 1, 16), (x, ch - 18))
            tile.alpha_composite(frame(av['head-Sheet.png'], 0, 16), (60, 20))
            tile.alpha_composite(frame(av['head-Sheet.png'], 1, 16), (80, 20))
            for i in range(3): tile.alpha_composite(frame(av['flake-Sheet.png'], i, 4), (60 + i * 10, 46))
        else:
            a = cc[isle]
            ground = ch - 8
            for x in range(0, cw, 16):
                blk = Image.new('RGBA', (16, 8), rgb('5a6070' if isle != 'nieve' else 'e2f2fc'))
                tile.alpha_composite(blk, (x, ground))
            py = 14                                                            # (la polea de la torre)
            for x0 in (10, 92):
                for y in range(py + 6, ground - 8, 16):
                    t = a[f'{isle}-tower.png'].crop((0, 0, 16, min(16, ground - 8 - y)))
                    tile.alpha_composite(t, (x0 - 8, y))
                tile.alpha_composite(a[f'{isle}-towerfoot.png'], (x0 - 8, ground - 8))
                tile.alpha_composite(a[f'{isle}-towertop.png'], (x0 - 8, py + 2))
            for x in range(10, 92, 8): tile.alpha_composite(a[f'{isle}-cable.png'], (x, py))
            for x0 in (10, 92): tile.alpha_composite(frame(a[f'{isle}-pulley-Sheet.png'], 0, 12), (x0 - 6, py - 5))
            tile.alpha_composite(frame(a[f'{isle}-trolley-Sheet.png'], 0, 16), (44, py - 4))
            tile.alpha_composite(a[f'{isle}-cabin.png'], (28, py + 4))
            hk = Image.new('RGBA', (60, 30))
            tile.alpha_composite(a[f'{isle}-clamp.png'], (70, 0))
            for y in range(4, 30, 8): tile.alpha_composite(a[f'{isle}-hanger.png'], (72, y))
        out.paste(tile.resize((cw * S, ch * S), Image.NEAREST), ((k % cols) * cw * S, (k // cols) * ch * S))
    return out


def main():
    apply = '--apply' in sys.argv
    av = avalanche_art()
    cc = {isle: cablecar_art(isle) for isle in ISLE_IDS}
    os.makedirs(PRUEBAS, exist_ok=True)
    p = os.path.join(PRUEBAS, 'vista_previa.png')
    preview(av, cc).save(p)
    print('vista previa:', p)
    if apply:
        os.makedirs(OUT_AV, exist_ok=True); os.makedirs(OUT_CC, exist_ok=True)
        for n, im in av.items(): im.save(os.path.join(OUT_AV, n))
        for isle in ISLE_IDS:
            for n, im in cc[isle].items(): im.save(os.path.join(OUT_CC, n))
        print('escrito en', OUT_AV, 'y', OUT_CC)


if __name__ == '__main__':
    main()
