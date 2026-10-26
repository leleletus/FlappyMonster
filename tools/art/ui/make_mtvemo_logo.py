#!/usr/bin/env python3
# tools/art/ui/make_mtvemo_logo.py — REDISEÑO del logo de mtvemo (la intro del arranque, docs/architecture/
# startup-intro.md). El usuario (2026-10-25): "rediséñalo por completo, no importa que no se parezca, más bonito,
# animado y bueno; propón ideas y enséñamelas antes". Tres propuestas, cada una animada (GIF) en una pantalla lógica
# de 320x180 (×4 = 1280x720, píxeles enteros como el resto del juego):
#   A "Arcade"   letras gordas con degradado de atardecer y relieve que caen una a una (una por nota de la melodía),
#                aplastándose al caer; luego un brillo las cruza y salen destellos
#   B "Tele"     una tele CRT con antenas cae y bota, se enciende (raya, destello, nieve) y en la pantalla sale una
#                cara que parpadea; debajo, las letras saltan una a una
#   C "Moneda"   un emblema-moneda con el monograma M·T·V (la M cuya V baja hasta abajo con la barra de la T: el guiño
#                al logo original, donde M, T y V se montaban) entra girando, aterriza, brilla y saca el nombre
#   D "Moneda arcade"  (el usuario: "mezcla la moneda con el arcade") la moneda de C entra girando y aterriza; a su
#                derecha caen las letras de A una a una (una por nota) y un brillo cruza moneda y nombre a la vez
#
#   python3 tools/art/ui/make_mtvemo_logo.py [D]      → FlappyMonster_pruebas/logo_mtvemo/ (vista_previa + GIF)
#   python3 tools/art/ui/make_mtvemo_logo.py --apply  → assets/startup/ (el D, el elegido: ver apply())
import os, math
from PIL import Image, ImageDraw

PREVIEW = '/home/mtvemo/FlappyMonster_pruebas/logo_mtvemo'
W, H = 320, 180
FPS = 25
GIF_K = 3                                           # (los GIF a ×3: 960x540)


def hx(s):
    s = s.lstrip('#')
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


# ── Letras: 7x9 en mayúsculas, palos de 2, escaladas a bloques ───────────────────
GLYPH = {
    'M': ['##...##', '###.###', '#######', '##.#.##', '##.#.##', '##...##', '##...##', '##...##', '##...##'],
    'T': ['#######', '#######', '..###..', '..###..', '..###..', '..###..', '..###..', '..###..', '..###..'],
    'V': ['##...##', '##...##', '##...##', '##...##', '##...##', '###.###', '.##.##.', '..###..', '...#...'],
    'E': ['#######', '#######', '##.....', '##.....', '######.', '##.....', '##.....', '#######', '#######'],
    'O': ['.#####.', '#######', '##...##', '##...##', '##...##', '##...##', '##...##', '#######', '.#####.'],
}
WORD = 'MTVEMO'


def glyph_mask(ch, w, h):
    """La letra a w x h píxeles (vecino más cercano: bloques)."""
    g = GLYPH[ch]
    return {(x, y) for y in range(h) for x in range(w) if g[y * len(g) // h][x * len(g[0]) // w] == '#'}


def dilate(s, diag=True):
    out = set(s)
    nb = [(1, 0), (-1, 0), (0, 1), (0, -1)] + ([(1, 1), (-1, -1), (1, -1), (-1, 1)] if diag else [])
    for x, y in s:
        for dx, dy in nb: out.add((x + dx, y + dy))
    return out


def put(img, x, y, c):
    if 0 <= x < W and 0 <= y < H and c[3] > 0:
        b = img.getpixel((x, y))
        if c[3] == 255 or b[3] == 0: img.putpixel((x, y), c)      # (sobre transparente: tal cual)
        else:
            a = c[3] / 255
            img.putpixel((x, y), tuple(int(b[i] * (1 - a) + c[i] * a) for i in range(3)) + (255,))


def styled(img, mask, ox, oy, fill, outline, extr, depth, hi=None, shine=None):
    """Letra con relieve (depth px abajo-derecha), contorno y relleno fill(y_rel 0..1). shine(x, y) → blanco."""
    if not mask: return
    hgt = max(y for _, y in mask) + 1
    ext = set()
    for d in range(1, depth + 1): ext |= {(x + d, y + d) for x, y in mask}
    shape = mask | ext
    for x, y in dilate(shape) - shape: put(img, ox + x, oy + y, outline)
    for x, y in ext - mask: put(img, ox + x, oy + y, extr)
    for x, y in mask:
        c = fill(y / max(1, hgt - 1))
        if hi and (x, y - 1) not in mask: c = hi
        if shine and shine(ox + x, oy + y): c = hx('#ffffff')
        put(img, ox + x, oy + y, c)


def lerp(a, b, k): return tuple(int(a[i] + (b[i] - a[i]) * k) for i in range(4))


def grad(stops):
    def f(k):
        k = max(0.0, min(1.0, k)) * (len(stops) - 1)
        i = min(int(k), len(stops) - 2)
        # (por bandas, sin mezclas suaves: 3 tonos por tramo)
        return lerp(stops[i], stops[i + 1], round((k - i) * 2) / 2)
    return f


def ease_out(k): return 1 - (1 - k) ** 2


def star(img, x, y, r, c):
    """Destello de 4 puntas (r = 0..3)."""
    put(img, x, y, c)
    for d in range(1, r + 1):
        for dx, dy in ((d, 0), (-d, 0), (0, d), (0, -d)): put(img, x + dx, y + dy, c if d < r else lerp(c, (0, 0, 0, 0), 0.5))


def bg(top, bot, dots=None):
    img = Image.new('RGBA', (W, H))
    for y in range(H):
        c = lerp(hx(top), hx(bot), round(y / H * 4) / 4)
        for x in range(W): img.putpixel((x, y), c)
    for x, y, c in dots or []: img.putpixel((x, y), hx(c))
    return img


STARS = [((i * 73) % W, (i * 41 + i * i * 7) % H, '#3b2b5e' if i % 3 else '#5a4890') for i in range(40)]


# ── A: Arcade ───────────────────────────────────────────────────────────────────
def concept_a(t):
    img = bg('#140c24', '#2a1640', STARS)
    LW, LH, GAP = 28, 36, 6
    total = len(WORD) * LW + (len(WORD) - 1) * GAP
    x0, base = (W - total) // 2, 70
    fill = grad([hx('#fff3a0'), hx('#ffb03d'), hx('#ff5a6e'), hx('#c23aa0')])
    sh = None
    if 1.9 <= t <= 2.5:                                        # brillo diagonal que cruza el nombre
        p = x0 - 30 + (t - 1.9) / 0.6 * (total + 60)
        sh = lambda x, y: 0 <= (x + (y - base) * 0.6) - p < 4
    for i, ch in enumerate(WORD):
        t0 = 0.3 + 0.15 * i
        if t < t0: continue
        u = t - t0
        w, h, dy = LW, LH, 0
        if u < 0.22: dy = int(-110 * (1 - u / 0.22) ** 2)      # cae
        elif u < 0.30: w, h = LW + 7, LH - 9                  # se aplasta
        elif u < 0.38: w, h = LW - 4, LH + 5                  # se estira
        if 1.55 <= t < 1.65: dy -= 3                          # (el "latido" del acorde)
        ox = x0 + i * (LW + GAP) - (w - LW) // 2
        oy = base + (LH - h) + dy
        styled(img, glyph_mask(ch, w, h), ox, oy, fill, hx('#12061e'), hx('#6b1f6e'), 4, hi=hx('#fffbe0'), shine=sh)
    # destellos alrededor
    for k, (sx, sy, st) in enumerate(((x0 - 8, base - 6, 2.0), (x0 + total + 6, base + 4, 2.25),
                                      (x0 + 52, base - 12, 2.5), (x0 + 118, base + LH + 10, 2.7))):
        u = t - st
        if 0 <= u < 0.6: star(img, sx, sy, [1, 2, 3, 2, 1, 0][int(u / 0.1)], hx('#fff3a0'))
    return img


# ── B: Tele ─────────────────────────────────────────────────────────────────────
TVW, TVH = 104, 78


def rrect(s, x0, y0, x1, y1, r):
    for y in range(y0, y1):
        for x in range(x0, x1):
            cx = min(max(x, x0 + r), x1 - 1 - r); cy = min(max(y, y0 + r), y1 - 1 - r)
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r + 0.5: s.add((x, y))
    return s


def tv(img, ox, oy, t, sq=0):
    out, case, shade, light = hx('#24101e'), hx('#ff7a59'), hx('#c4493a'), hx('#ffb08f')
    w, h = TVW + 2 * sq, TVH - 2 * sq
    ox -= sq; oy += 2 * sq
    # antenas (se mueven al ritmo)
    wig = 1 if int(t * 5) % 2 else 0
    ax = ox + w // 2
    for dx, tip in ((-1, (-12 - wig, -14)), (1, (11 + wig, -14))):
        n = 18
        tip = (tip[0] * 4 // 3, tip[1] * 4 // 3)
        for k in range(n + 1):
            x = ax + round(tip[0] * k / n); y = oy + round(tip[1] * k / n)
            put(img, x, y, out); put(img, x + 1, y, out)
        for bx in range(-1, 2):
            for by in range(-1, 2): put(img, ax + tip[0] + bx, oy + tip[1] + by, out)
        put(img, ax + tip[0], oy + tip[1], hx('#ffd84a'))
    body = rrect(set(), 0, 0, w, h, 5)
    for x, y in dilate(body) - body: put(img, ox + x, oy + y, out)
    for x, y in body:
        c = case
        if (x, y - 2) not in body or (x - 2, y) not in body: c = light
        if (x, y + 3) not in body or (x + 3, y) not in body: c = shade
        put(img, ox + x, oy + y, c)
    # pies
    for fx in (8, w - 14):
        for x in range(fx, fx + 6):
            for y in range(h + 1, h + 4): put(img, ox + x, oy + y, out)
    # pantalla y mandos
    sx0, sy0, sw, shh = 8, 8, w - 30, h - 16
    scr = rrect(set(), sx0, sy0, sx0 + sw, sy0 + shh, 3)
    for x, y in dilate(scr, False) - scr: put(img, ox + x, oy + y, out)
    on = t - 0.75
    for x, y in scr:
        c = hx('#18202e')
        if 0 <= on < 0.15:                                      # se enciende: una raya que se abre
            mid = sy0 + shh // 2; half = int(shh / 2 * on / 0.15)
            if abs(y - mid) <= half: c = hx('#e8fbff')
        elif 0.15 <= on < 0.4:                                  # nieve
            c = hx('#c8d4e0') if ((x * 7 + y * 13 + int(on * 40) * 31) % 5) < 2 else hx('#3a4658')
        elif on >= 0.4:
            c = hx('#1b3a4a') if y % 2 else hx('#22485a')       # (líneas de barrido)
        put(img, ox + x, oy + y, c)
    if on >= 0.4:                                               # la cara
        face = hx('#8ff4ff')
        blink = (2.3 <= t < 2.42)
        for ex in (sx0 + sw // 2 - 17, sx0 + sw // 2 + 11):
            for x in range(ex, ex + 6):
                for y in range(sy0 + 13, sy0 + 23):
                    if blink and y not in (sy0 + 19, sy0 + 20): continue
                    put(img, ox + x, oy + y, face)
        cx, cy = sx0 + sw // 2, sy0 + 30
        for x in range(-9, 10):                                  # sonrisa (las puntas, más arriba)
            y = cy + 4 - int(round(x * x / 27))
            put(img, ox + cx + x, oy + y, face); put(img, ox + cx + x, oy + y + 1, face)
        for x in (-14, 14):                                      # mofletes
            for dx in range(-2, 2): put(img, ox + cx + x + dx, oy + cy + 1, hx('#ff8fb4'))
    for k, ky in enumerate((16, 32)):
        kx = w - 14
        knob = {(x, y) for x in range(kx, kx + 8) for y in range(ky, ky + 8) if (x - kx - 3.5) ** 2 + (y - ky - 3.5) ** 2 <= 14}
        for x, y in dilate(knob, False) - knob: put(img, ox + x, oy + y, out)
        for x, y in knob: put(img, ox + x, oy + y, hx('#ffd84a') if (x + y) % 5 else hx('#b8861c'))
    for k in range(4): put(img, ox + w - 15 + 2 * k, oy + h - 14, out); put(img, ox + w - 15 + 2 * k, oy + h - 11, out)


def concept_b(t):
    img = bg('#1d1433', '#2e1d4a', STARS)
    ox, rest = (W - TVW) // 2, 22
    sq = 0
    if t < 0.4: oy = int(-80 + (rest + 80) * (t / 0.4) ** 2)
    elif t < 0.48: oy, sq = rest, 3
    elif t < 0.62: oy = rest - int(8 * math.sin((t - 0.48) / 0.14 * math.pi))
    else: oy = rest
    tv(img, ox, oy, t, sq)
    LW, LH, GAP = 14, 18, 4
    total = len(WORD) * LW + (len(WORD) - 1) * GAP
    x0 = (W - total) // 2
    fill = grad([hx('#fff7e0'), hx('#ffd9a8')])
    for i, ch in enumerate(WORD):
        t0 = 1.25 + 0.15 * i
        if t < t0: continue
        u = t - t0
        dy = -int(10 * math.sin(min(1, u / 0.2) * math.pi)) if u < 0.2 else 0
        styled(img, glyph_mask(ch, LW, LH), x0 + i * (LW + GAP), 134 + dy, fill, hx('#24101e'), hx('#c4493a'), 2)
    return img


# ── C: Moneda ───────────────────────────────────────────────────────────────────
def monogram(sz):
    """M·T·V: la barra de la T arriba, los palos de la M y su V que baja hasta abajo."""
    m = Image.new('L', (sz, sz), 0)
    d = ImageDraw.Draw(m)
    th = max(3, sz // 8)
    d.rectangle((0, 0, sz - 1, th - 1), fill=255)                                  # T
    d.rectangle((0, 0, th - 1, sz - 1), fill=255); d.rectangle((sz - th, 0, sz - 1, sz - 1), fill=255)  # M
    d.line((th // 2, th, sz // 2, sz - 2), fill=255, width=th); d.line((sz - 1 - th // 2, th, sz // 2, sz - 2), fill=255, width=th)
    return {(x, y) for y in range(sz) for x in range(sz) if m.getpixel((x, y)) > 128}


MONO = monogram(33)


def coin(img, cx, cy, R, sx, back, glint=None):
    """Moneda de radio R aplastada en horizontal (sx = 0..1); back = la cara de atrás (lisa)."""
    out, rim, rimS, rimL = hx('#2a1400'), hx('#f2b23a'), hx('#b8701a'), hx('#ffe58a')
    face, faceS = hx('#ffcf4a'), hx('#e09b22')
    rx = max(1, R * sx)
    disc = {(x, y) for y in range(-R, R + 1) for x in range(-R - 1, R + 2) if (x / rx) ** 2 + (y / R) ** 2 <= 1 - 0.6 / R}  # (sin pezones en los 4 puntos)
    edge = set() if sx > 0.95 else {(x + 2, y) for x, y in disc} - disc          # (el canto, al girar)
    for x, y in dilate(disc | edge) - (disc | edge): put(img, cx + x, cy + y, out)
    for x, y in edge: put(img, cx + x, cy + y, rimS)
    inner = R - 4
    for x, y in disc:
        r = (x / rx) ** 2 + (y / R) ** 2
        ri = (x / max(1, rx * inner / R)) ** 2 + (y / inner) ** 2
        if ri > 1:
            c = rimL if (x + y) < -R * 0.5 else (rimS if (x + y) > R * 0.5 else rim)
        else:
            c = face if (x + y) < 0 else faceS
        if glint and glint(x, y): c = hx('#fffbe8')
        put(img, cx + x, cy + y, c)
    ring = {(x, y) for x, y in disc if 0.80 < (x / max(1, rx * inner / R)) ** 2 + (y / inner) ** 2 <= 1.0}
    for x, y in ring: put(img, cx + x, cy + y, rimS)
    if not back and sx > 0.3:
        for x, y in MONO:
            mx = int(round((x - 16) * sx)); my = y - 17
            put(img, cx + mx + 1, cy + my + 1, hx('#b8701a'))
        for x, y in MONO:
            mx = int(round((x - 16) * sx)); my = y - 17
            put(img, cx + mx, cy + my, hx('#5a2a0a'))


def concept_c(t):
    img = bg('#0f1a2e', '#1c2c4a', STARS)
    LW, LH, GAP = 21, 27, 4
    total = len(WORD) * LW + (len(WORD) - 1) * GAP
    R = 38
    full = 2 * R + 12 + total
    cx = (W - full) // 2 + R
    cy = 88
    # entra girando y cayendo, aterriza
    if t < 1.0:
        k = t / 1.0
        ang = (1 - ease_out(k)) * math.pi * 5
        sx, back = abs(math.cos(ang)), math.cos(ang) < 0
        y = int(cy - 90 * (1 - k) ** 2)
    elif t < 1.12: sx, back, y = 1, False, cy + 2
    else: sx, back, y = 1, False, cy
    # el nombre sale de detrás de la moneda
    fill = grad([hx('#ffffff'), hx('#cfe4ff')])
    if t >= 1.4:
        k = ease_out(min(1, (t - 1.4) / 0.6))
        tx0 = cx + 2 * R // 3 + int((R + 12 - 2 * R // 3) * k)
        for i, ch in enumerate(WORD):
            lx = tx0 + i * (LW + GAP)
            if lx + LW < cx + R // 2: continue
            sh = (lambda x, yy: 0 <= x + (yy - cy) * 0.5 - (cx + (t - 2.3) / 0.5 * (full + 40)) < 3) if 2.3 <= t < 2.8 else None
            styled(img, glyph_mask(ch, LW, LH), lx, cy - LH // 2, fill, hx('#0a1020'), hx('#3b5a9a'), 2, shine=sh)
    gl = None
    if 1.5 <= t < 2.0:
        p = -R - 6 + (t - 1.5) / 0.5 * (2 * R + 12)
        gl = lambda x, yy: 0 <= (x + yy * 0.7) - p < 4
    coin(img, cx, y, R, sx, back, gl)
    u = t - 2.9
    if 0 <= u < 0.6: star(img, cx + R - 6, cy - R + 4, [1, 2, 3, 2, 1, 0][int(u / 0.1)], hx('#fffbe8'))
    return img


BG_D = ('#140c24', '#2a1640')
# (D, en el juego: la primera letra aterriza a NOTE_AT — ahí suena la primera nota de la melodía, y las demás cada
# 0,15 s — y el acorde, 0,90 s después, es el "latido" de moneda y letras: tools/sounds/startup.py STEP, CHORD_AT)
D_NOTE_AT, D_CHORD_AT, D_DUR = 1.27, 1.27 + 0.90, 4.1


def concept_d(t, clear=False):
    img = Image.new('RGBA', (W, H)) if clear else bg(*BG_D, STARS)
    R, LW, LH, GAP = 34, 24, 32, 5
    total = len(WORD) * LW + (len(WORD) - 1) * GAP
    full = 2 * R + 14 + total
    cx, cy = (W - full) // 2 + R, 86
    x0, base = cx + R + 14, cy - LH // 2 - 2
    # la moneda: entra girando y cayendo, aterriza (y late con el acorde)
    if t < 1.0:
        k = t / 1.0
        ang = (1 - ease_out(k)) * math.pi * 5
        sx, back, y = abs(math.cos(ang)), math.cos(ang) < 0, int(cy - 100 * (1 - k) ** 2)
    elif t < 1.1: sx, back, y = 1, False, cy + 2
    else: sx, back, y = 1, False, cy
    if D_CHORD_AT <= t < D_CHORD_AT + 0.1: y -= 3
    # brillo: cruza la moneda y luego el nombre, una sola pasada
    p = (cx - R - 30 + (t - 2.5) / 0.7 * (full + 60)) if 2.5 <= t < 3.2 else None
    gl = (lambda x, yy: 0 <= (cx + x + yy * 0.6) - p < 5) if p is not None else None
    coin(img, cx, y, R, sx, back, gl)
    fill = grad([hx('#fff3a0'), hx('#ffb03d'), hx('#ff5a6e'), hx('#c23aa0')])
    sh = (lambda x, yy: 0 <= (x + (yy - cy) * 0.6) - p < 4) if p is not None else None
    for i, ch in enumerate(WORD):
        t0 = 1.05 + 0.15 * i
        if t < t0: continue
        u = t - t0
        w, h, dy = LW, LH, 0
        if u < 0.22: dy = int(-120 * (1 - u / 0.22) ** 2)
        elif u < 0.30: w, h = LW + 6, LH - 8
        elif u < 0.38: w, h = LW - 4, LH + 4
        if D_CHORD_AT <= t < D_CHORD_AT + 0.1: dy -= 3        # (el "latido" del acorde)
        ox = x0 + i * (LW + GAP) - (w - LW) // 2
        styled(img, glyph_mask(ch, w, h), ox, base + (LH - h) + dy, fill, hx('#12061e'), hx('#6b1f6e'), 4,
               hi=hx('#fffbe0'), shine=sh)
    for sx_, sy_, st in ((cx + R - 8, cy - R + 5, 3.15), (x0 + total + 7, base - 4, 3.3), (x0 + 60, base + LH + 12, 3.45)):
        u = t - st
        if 0 <= u < 0.6: star(img, sx_, sy_, [1, 2, 3, 2, 1, 0][int(u / 0.1)], hx('#fff3a0'))
    return img


CONCEPTS = [('A', 'Arcade', concept_a, 3.4), ('B', 'Tele', concept_b, 3.2), ('C', 'Moneda', concept_c, 3.6),
            ('D', 'Moneda_arcade', concept_d, D_DUR)]


def main():
    os.makedirs(PREVIEW, exist_ok=True)
    finals = []
    import sys
    only = [a for a in sys.argv[1:] if not a.startswith('-')]                                       # (p. ej. D: solo esa)
    for key, name, fn, dur in CONCEPTS:
        if only and key not in only: continue
        frames = [fn(i / FPS) for i in range(int(dur * FPS))]
        frames += [frames[-1]] * FPS                          # (un segundo quieto al final)
        big = [f.convert('RGB').resize((W * GIF_K, H * GIF_K), Image.NEAREST) for f in frames]
        p = os.path.join(PREVIEW, f'{key}_{name}.gif')
        big[0].save(p, save_all=True, append_images=big[1:], duration=1000 // FPS, loop=0)
        print(p)
        # fila de momentos clave
        keys = [frames[int(s * FPS)] for s in (0.5, 1.1, 1.6, 2.7, dur - 0.05)]
        finals.append((key, name, keys))
    sm = 2
    sheet = Image.new('RGB', (W * sm * 5 + 60, (H * sm + 30) * len(finals) + 10), (20, 20, 24))
    d = ImageDraw.Draw(sheet)
    for r, (key, name, keys) in enumerate(finals):
        y0 = 10 + r * (H * sm + 30)
        d.text((10, y0), f'{key} - {name}', fill=(255, 255, 255))
        for i, f in enumerate(keys):
            sheet.paste(f.convert('RGB').resize((W * sm, H * sm), Image.NEAREST), (10 + i * (W * sm + 10), y0 + 18))
    p = os.path.join(PREVIEW, 'vista_previa.png' if not only else f'vista_previa_{"".join(only)}.png')
    sheet.save(p)
    print(p)


# ── En el juego: el diseño D (el elegido, 2026-10-25) ───────────────────────────────
# assets/startup/logo_anim.png   los cuadros de la animación (solo el logo, fondo transparente, recortados a lo que
#                                ocupa la animación entera), en rejilla; los cuadros repetidos, una sola vez
# assets/startup/logo_anim.json  fps, tamaño y sitio del cuadro en la pantalla de 320x180, columnas, `frames` (el
#                                cuadro de cada instante), noteAt / chordAt (s de la animación)
# assets/startup/sky.png         el cielo: 1 px de ancho x 180 (las franjas del degradado; se estira a lo ancho)
# assets/startup/stars.png       las estrellas (320x180, transparente; se repite a lo ancho)
OUT = 'assets/startup'
APPLY_FPS = 30


def apply():
    import json
    n = int(round(D_DUR * APPLY_FPS))
    frames = [concept_d(i / APPLY_FPS, clear=True) for i in range(n)]
    box = None
    for f in frames:
        b = f.getbbox()
        if b: box = b if not box else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
    fw, fh = box[2] - box[0], box[3] - box[1]
    uniq, index, seen = [], [], {}
    for f in frames:
        c = f.crop(box)
        k = c.tobytes()
        if k not in seen:
            seen[k] = len(uniq); uniq.append(c)
        index.append(seen[k])
    cols = max(1, 4096 // fw)
    rows = (len(uniq) + cols - 1) // cols
    assert rows * fh <= 4096, 'la hoja no cabe en 4096'
    sheet = Image.new('RGBA', (cols * fw, rows * fh))
    for i, c in enumerate(uniq): sheet.paste(c, ((i % cols) * fw, (i // cols) * fh))
    os.makedirs(OUT, exist_ok=True)
    sheet.save(os.path.join(OUT, 'logo_anim.png'), optimize=True)
    json.dump({'fps': APPLY_FPS, 'screen': [W, H], 'x': box[0], 'y': box[1], 'w': fw, 'h': fh, 'cols': cols,
               'noteAt': D_NOTE_AT, 'chordAt': D_CHORD_AT, 'frames': index},
              open(os.path.join(OUT, 'logo_anim.json'), 'w'), separators=(',', ':'))
    sky = Image.new('RGBA', (1, H))
    full = bg(*BG_D)
    for y in range(H): sky.putpixel((0, y), full.getpixel((0, y)))
    sky.save(os.path.join(OUT, 'sky.png'))
    st = Image.new('RGBA', (W, H))
    for x, y, c in STARS: st.putpixel((x, y), hx(c))
    st.save(os.path.join(OUT, 'stars.png'))
    print('%d cuadros (%d distintos) de %dx%d en %dx%d; cielo y estrellas' % (n, len(uniq), fw, fh, *sheet.size))


if __name__ == '__main__':
    import sys
    if '--apply' in sys.argv: apply()
    else: main()
