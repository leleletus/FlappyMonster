#!/usr/bin/env python3
# tools/music/tuffi.py — "TUFFI": tema ÉPICO nuevo sobre la melodía del usuario (/home/mtvemo/Descargas/tuffi.mid: 8
# compases a 135 BPM, un arpegio en corcheas agrupado 3+3+2 — Re-Fa#-Do# · Do#-Mi#-Si · Fa#-La-Mi · Mi-Sol#-Re —, con
# un bajo que en la segunda vuelta sube Re-Mi#-Fa# y baja La-Sol#-Fa#-Mi-Re-Do# en 3+3+3+3+2+2). PREVIAS para que el
# usuario elija; no toca assets/ ni el index.json. Se comprueba con números: NO SE HA ESCUCHADO.
#
# LA IDEA: la melodía del usuario, MUCHO más rápida (180 BPM, +33 %, con batería en doble tiempo), y épica:
#   · Fa# menor, la armonía del original: Remaj7 (VI) · Do#7 (V) · Fa#m7 (i) · Mi7 (VII). Las notas, una octava arriba.
#   · EL RITMO es el de la melodía: sus grupos 3+3+2 (golpes en 0 6 12) los tocan el slap, los metales, los taikos y el
#     bombo. El bajo del usuario (La-Sol#-Fa#-Mi-Re-Do# en 3+3+3+3+2+2) vuelve en cada segunda vuelta del tema.
#   · GIRO OSCURO (uno): el Sol mayor napolitano (♭II) → Do#7, al final del himno.
#   · LA LLAMADA (La-Re-Fa#-La), la fanfarria de trompas que abre la intro (y la vuelta R).
#
# LA FORMA (8 + 72 compases a 180 BPM; compás = 1,333 s = 58 800 muestras: 10,7 s de intro + bucle de 96 s):
#   INTRO 8 la fanfarria de trompas sobre la armonía a medio ritmo (Re Re Do# Do# Fa#m Fa#m Mi Mi): golpe de
#           orquesta, taikos, timbales, coro; la batería entra a mitad; el último compás pica tres veces y se calla.
#   A 16    EL TEMA dos veces (la melodía del usuario tal cual); la segunda, con la octava, el remolino de semicorcheas,
#           trémolo de cuerdas y el bajo del usuario.
#   B 16    EL HIMNO: la cabeza del tema (el arpegio 3+3+2) en las trompas y el coro, que se posa en notas largas;
#           otra armonía (Sim7 Do#7 Fa#m7 Remaj7 Mi7 … el napolitano Sol → Do#7). Primero a medio tiempo (taikos), luego
#           en doble tiempo; el último compás, medio vacío antes del solo.
#   S 8     EL SOLO: el tema en DISMINUCIÓN (semicorcheas: dos compases del original en uno), la segunda mitad una octava
#           arriba; guitarras, doble bombo.
#   D 8     EL RESPIRO: la caja de música toca el tema como en el original (4 compases), luego vuelve la voz y todo crece;
#           medio compás de silencio y platillo al revés.
#   C 16    EL CLÍMAX: el tema con todo (guitarras, coro, metales en 3+3+2, golpes de orquesta, doble bombo).
#   R 8     la fanfarria de la intro, con la banda: acaba igual que la intro (la costura es la misma entrada).
#
# DOS VARIANTES (misma armonía, forma y banda; otra voz):
#   A "chip épico"   (de la casa) la melodía en la SIERRA del VRC6 con el pulso a la octava; el solo, en el pulso del
#                    2A03 con el eco de la casa.
#   B "orquesta"     (más atrevida) la melodía en METALES sintéticos GM con la guitarra distorsionada al unísono; el
#                    solo, en la guitarra (con el pulso del chip encima, flojo).
#
#   ~/.venvs/fm-music/bin/python tools/music/tuffi.py [A B] → previas en FlappyMonster_pruebas/musica/tuffi/
#   REPORT=1 → solo números · INSTALL=1 TUFFI=A → assets/music/bosses/tuffi_intro|_loop.ogg (la elegida: A "chip épico", 2026-11-08)
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import famicom as F
from famicom import SR, Chan
import gloomy_nes as GN
import jungla_nes as J
import worlds_nes as W
import montana_nes as M
import slap as SL
import gm as GM

place, nm = M.place, J.nm
PRUEBAS = '/home/mtvemo/FlappyMonster_pruebas/musica/tuffi'
TRACK = 'tuffi'
BPM, LUFS, CEILING = 180, -10.0, 0.70
VNAME = {'A': 'chip_epico', 'B': 'orquesta'}
SCALE = {6, 8, 9, 11, 1, 2, 4}                                      # Fa# menor natural (Mi# solo en Do#7; Sol solo en el napolitano)

# ══ ACORDES CON SÉPTIMA (el CH de worlds_nes solo tiene tríadas) ═══════════════════════════════════════════════════
QUAL = {'maj7': (0, 4, 7, 11), 'm7': (0, 3, 7, 10), '7': (0, 4, 7, 10), 'm': J.MIN, '': J.MAJ}


def CH4(txt):
    def one(t):
        r = t[:2] if len(t) > 1 and t[1] in '#b' else t[:1]
        q = t[len(r):]
        pc = (W._PC[r[0]] + (1 if r[1:] == '#' else -1 if r[1:] == 'b' else 0)) % 12
        return (pc, QUAL[q])
    return [tuple(one(x) for x in tok.split('|')) if '|' in tok else one(tok) for tok in txt.split()]


J.CH = CH4                                                           # (J.Song lee los acordes con esto)


def up(txt, k):
    """la misma frase k octavas más arriba"""
    out = []
    for tok in txt.split():
        st, rest = tok.split(':'); n, d = rest.split('/')
        out.append(f'{st}:{n[:-1]}{int(n[-1]) + k}/{d}')
    return ' '.join(out)


# ══ LA ARMONÍA ═════════════════════════════════════════════════════════════════════════════════════════════════════
H_THEME = "Dmaj7 C#7 F#m7 E7 Dmaj7 C#7 F#m7 E7"
H_IN = "Dmaj7 Dmaj7 C#7 C#7 F#m7 F#m7 E7 E7"
H_B = "Bm7 Bm7 C#7 C#7 F#m7 F#m7 Dmaj7 E7 " + "Bm7 Bm7 C#7 C#7 Dmaj7 G C#7 C#7"   # el GIRO OSCURO: Sol (♭II) → Do#7
H_S = "Dmaj7|C#7 F#m7|E7 " * 3 + "Dmaj7|C#7 E7"

# ══ LA MELODÍA DEL USUARIO (tuffi.mid, una octava arriba; corcheas = 2 semicorcheas) ═══════════════════════════════
THEME = ["0:D5/2 2:F#5/2 4:C#6/2 6:D5/2 8:F#5/2 10:C#6/2 12:D5/2 14:F#5/2",       # Remaj7
         "0:C#5/2 2:E#5/2 4:B5/2 6:C#5/2 8:E#5/2 10:B5/2 12:D6/2 14:C#6/2",       # Do#7
         "0:F#5/2 2:A5/2 4:E6/2 6:F#5/2 8:A5/2 10:E6/2 12:D6/2 14:C#6/2",         # Fa#m7
         "0:E5/2 2:G#5/2 4:D6/2 6:E5/2 8:D6/2 10:C#6/2 12:B5/2 14:C#6/2"]         # Mi7
THEME = THEME * 2                                                    # (la segunda vuelta: mismas notas, otro bajo)

# la fanfarria de la intro y de R (trompas): la llamada, y el perfil del arpegio del tema
FANFARE = ["0:A4/3 3:D5/3 6:F#5/2 8:A5/8",                           # LA LLAMADA (La-Re-Fa#-La) sobre Re
           "0:A5/3 3:F#5/3 6:A5/2 8:C#6/8",                          # … y sube a la 7ª mayor
           "0:G#5/3 3:E#5/3 6:C#5/2 8:G#5/8",
           "0:G#5/3 3:B5/3 6:G#5/2 8:E#5/8",
           "0:F#5/3 3:A5/3 6:C#6/2 8:E6/8",                          # (el arpegio del compás 3 del tema)
           "0:E6/3 3:C#6/3 6:A5/2 8:F#5/8",
           "0:E5/3 3:G#5/3 6:B5/2 8:D6/4 12:E6/4",
           "0:E6/3 3:D6/3 6:B5/2"]                                   # los tres golpes; el resto, silencio

# EL HIMNO: la cabeza del tema (3+3+2) que sube, y una caída que se posa; pregunta y respuesta por pares de compases
HYMN = ["0:B4/2 2:D5/2 4:A5/2 6:B4/2 8:D5/2 10:A5/2 12:B5/4",        # Sim7: el arpegio del tema
        "0:A5/3 3:G#5/1 4:F#5/4 8:D5/8",                             # … y cae
        "0:C#5/2 2:E#5/2 4:B5/2 6:C#5/2 8:E#5/2 10:B5/2 12:C#6/4",   # Do#7
        "0:B5/3 3:A5/1 4:G#5/4 8:E#5/8",
        "0:F#5/2 2:A5/2 4:E6/2 6:F#5/2 8:A5/2 10:E6/2 12:F#6/4",     # Fa#m7: la cima
        "0:E6/3 3:D6/1 4:C#6/4 8:A5/8",
        "0:F#5/4 4:A5/4 8:C#6/4 12:D6/4",                            # Remaj7: sube por el acorde
        "0:E6/6 6:D6/2 8:C#6/2 10:B5/6",                             # Mi7
        "0:B4/2 2:D5/2 4:A5/2 6:B4/2 8:D5/2 10:A5/2 12:B5/4",
        "0:A5/3 3:G#5/1 4:F#5/4 8:D5/8",
        "0:C#5/2 2:E#5/2 4:B5/2 6:C#5/2 8:E#5/2 10:B5/2 12:C#6/4",
        "0:B5/3 3:A5/1 4:G#5/4 8:E#5/8",
        "0:A5/4 4:F#5/4 8:D6/8",                                     # Remaj7
        "0:D6/4 4:B5/4 8:G5/8",                                      # SOL: el napolitano
        "0:G#5/4 4:B5/4 8:E#5/2 10:G#5/2 12:B5/4",                   # Do#7
        "0:C#6/8"]                                                   # (y medio compás vacío antes del solo)

# EL SOLO: el tema en disminución (dos compases del original por compás, en semicorcheas)
S12 = ("0:D5/1 1:F#5/1 2:C#6/1 3:D5/1 4:F#5/1 5:C#6/1 6:D5/1 7:F#5/1 "
       "8:C#5/1 9:E#5/1 10:B5/1 11:C#5/1 12:E#5/1 13:B5/1 14:D6/1 15:C#6/1")
S34 = ("0:F#5/1 1:A5/1 2:E6/1 3:F#5/1 4:A5/1 5:E6/1 6:D6/1 7:C#6/1 "
       "8:E5/1 9:G#5/1 10:D6/1 11:E5/1 12:D6/1 13:C#6/1 14:B5/1 15:C#6/1")
S_END = "0:E6/1 1:D6/1 2:B5/1 3:G#5/1 4:E6/1 5:D6/1 6:B5/1 7:G#5/1 8:E5/4"      # baja por Mi7 y se para
SOLO = [S12, S34, S12, S34, up(S12, 1), up(S34, 1), up(S12, 1), S_END]

# EL RESPIRO: la caja de música con el tema (1-4); la voz vuelve (5-8); el último, medio compás y silencio
BREATH = THEME[:7] + ["0:E5/2 2:G#5/2 4:D6/2 6:E5/2"]


def sections(v):
    return [('intro', H_IN, FANFARE, 16, ''), ('A', H_THEME + ' ' + H_THEME, THEME * 2, 16, ''),
            ('B', H_B, HYMN, 16, ''), ('S', H_S, SOLO, 16, ''), ('D', H_THEME, BREATH, 16, ''),
            ('C', H_THEME + ' ' + H_THEME, THEME * 2, 16, ''), ('R', H_IN, FANFARE, 16, '')]


J.TRACKS[TRACK] = dict(secs=sections, bpm=BPM, scale=SCALE, tonic=(6, J.MIN), lufs=LUFS, variants=tuple(VNAME), title='Tuffi', vname=VNAME)


# ══ LOS NÚMEROS DE LA MELODÍA ══════════════════════════════════════════════════════════════════════════════════════
def melody_numbers(sg, tags=None):
    mel = [m for m in sg.mel if tags is None or sg.tag[m[0] - 1] in tags]
    d16 = lambda m: sg.q(m[0], m[1] + m[3]) - sg.q(m[0], m[1])
    iv = np.diff([m[2] for m in mel])
    return dict(notes=len(mel), lo=nm(min(m[2] for m in mel)), hi=nm(max(m[2] for m in mel)),
                ct=np.mean([m[2] % 12 in sg.tones(m[0], m[1]) for m in mel]),
                step=np.mean([1 <= abs(i) <= 2 for i in iv]), rep=np.mean([i == 0 for i in iv]),
                long=np.mean([d16(m) >= 4 for m in mel]), off=np.mean([m[1] % 4 != 0 for m in mel]))


def melody_report(v, sg):
    lb, lo, out, off = J.check(sg)
    for name, tags in (('todo', None), ('himno (B, lo único nuevo)', ('B',))):
        mn = melody_numbers(sg, tags)
        print(f'── {TRACK} {v} {name}: {mn["notes"]} notas {mn["lo"]}-{mn["hi"]} · del acorde {100 * mn["ct"]:.0f} % · por grado {100 * mn["step"]:.0f} % · '
              f'repetidas {100 * mn["rep"]:.0f} % · largas {100 * mn["long"]:.0f} % · a contratiempo {100 * mn["off"]:.0f} %')
    print(f'    largas fuera del acorde: {lb or "ninguna"}')
    print(f'    sueltas: {len(lo)} (las del tema del usuario: el Re sobre Do#7, de paso) · fuera de escala: {out or "ninguna"}')
    return melody_numbers(sg), lb, lo, out


if __name__ == '__main__' and os.environ.get('MELODIA'):
    for v in [a for a in sys.argv[1:] if a in VNAME] or list(VNAME):
        melody_report(v, J.Song(TRACK, v))
    sys.exit(0)


# ══ EL REPARTO ══════════════════════════════════════════════════════════════════════════════════════════════════════
HORNS, BRASS, SYNBRASS, TREM, STRINGS, CHOIR, TIMPANI, ORCH_HIT, REV_CYM, TAIKO, GTR = 60, 61, 62, 44, 48, 52, 47, 55, 119, 116, 30
TOM_L = 41
LEADS = ('lead', 'sawlead', 'fan', 'horn', 'dbl', 'solo', 'cm', 'gtrlead')
BASS_ROOT = {2: 38, 1: 37, 6: 42, 4: 40, 11: 35, 9: 45, 8: 44, 5: 41, 7: 43}
I_SAW_LEAD = {'vol': [15, 14, 14, 13, 13, 12], 'sus': 12, 'vib': (14, 0.18, 6)}
I_SWIRL = {'vol': [10, 8, 6, 5, 4], 'sus': 4, 'duty': 0.25}
I_SOLO = {'vol': [15, 13, 11, 10, 9], 'sus': 9, 'duty': [0.125, 0.25, 0.25, 0.5]}
I_BOX = {'vol': [15, 12, 10, 8, 7, 6, 5, 4, 3, 3, 2, 2, 1], 'sus': 1, 'duty': 0}      # (onda 0 del N163: campana)
M.TIGHT_KEYS = M.TIGHT_KEYS + ('stab', 'gtr', 'gtrlead', 'horn', 'hit')


class Rig(M.Rig):
    """el Rig de las montañas (GM con bancos y a tiempo) + el slap de los jefes, sierras VRC6, remolino y solo"""
    def __init__(self, sg):
        super().__init__(sg)
        NF = len(self.Cn['lead'].f)
        for k in ('sawlead', 'fan', 'swirl', 'solo'): self.Cn[k] = Chan(NF)
        self.slap = SL.Rec()
        for k in ('snare', 'crash'): self.NZ[k].exact = True

    def sl(self, b, st, n, d, vel=100):
        sg = self.sg
        self.slap.add(sg.t(b, st), sg.t(b, st) + sg.dur(b, d) * 0.95, n, vel)
        self.notes.setdefault('bass', []).append((sg.q(b, st), sg.q(b, st + d), n))

    def timp(self, b, st, n, d, vel):
        self.gm('timp', TIMPANI, b, st, 40 + (n - 40) % 12, d, vel, gate=0.95)

    def taiko(self, b, st, vel, n=41):
        """taiko afinado a la raíz del acorde (n=45: la de arriba, una 4ª/5ª encima)"""
        r = 38 + (self.sg.chord(b, st)[0] - 38) % 12
        self.gm('taiko', TAIKO, b, st, r if n == 41 else r + 7, 2, vel, gate=0.95)

    def chord_gm(self, k, prog, b, st, d, vel, lo, nn=4, gate=0.95):
        """un acorde GM (sin 2ª menor, 7ª mayor ni tritono con la melodía que suena)"""
        for n in place(None, self.sg.chord(b, st), lo)[:nn]:
            if not self.rub(b, st, n, d, voice=LEADS): self.gm(k, prog, b, st, n, d, vel, gate=gate)

    def power(self, b, st, d, vel, gate=0.9, k='gtr'):
        """acorde de quinta de guitarra (raíz, 5ª, 8ª) entre Mi2 y Re#3"""
        r = 40 + (self.sg.chord(b, st)[0] - 40) % 12
        for n in (r, r + 7, r + 12):
            self.gm(k, GTR, b, st, n, d, vel, gate=gate)

    def orch(self, b, st, vel=112):
        """el golpe de orquesta: raíz y octava del acorde"""
        r = 54 + (self.sg.chord(b, st)[0] - 54) % 12
        for n in (r, r + 12): self.gm('hit', ORCH_HIT, b, st, n, 3, vel, gate=0.9)

    def crash(self, b, st=0):
        self.NZ['crash'].hit(self.sg.t(b, st), 3, J.CRASH_N)


def next_root(sg, b):
    return (sg.chords[b][0] if b < sg.NB else sg.chords[sg.INTRO][0])[0]


def r0(sg, b, st):
    return BASS_ROOT.get(sg.chord(b, st)[0], 38)


def approach(sg, R, b, st):
    """la nota del slap que lleva por grado a la raíz siguiente (o la 5ª si el acorde sigue)"""
    nx = BASS_ROOT.get(next_root(sg, b), 38)
    if sg.chord(b, st)[0] == next_root(sg, b): return r0(sg, b, st) + 7
    c = [p for p in (nx + 2, nx - 2, nx + 1, nx - 1) if p % 12 in sg.scale | sg.tones(b, st) and not R.rub(b, st, p, 2, voice=LEADS)]
    return c[0] if c else r0(sg, b, st)


# ══ LA MELODÍA, según la variante ═══════════════════════════════════════════════════════════════════════════════════
def play_melody(sg, R, v):
    for b, st, n, d in sg.mel:
        tag, k = sg.tag[b - 1], sg.pos[b - 1]
        if tag in ('intro', 'R', 'B'):                                 # trompas (la fanfarria y el himno)
            R.gm('horn', HORNS, b, st, n, d, 112 if tag != 'B' or k > 8 else 104, gate=0.95)
            if v == 'A': R.chip('fan', b, st, n - 12, d, I_SAW_LEAD, q=F.q_saw, release=3)
            else: R.gm('horn2', BRASS, b, st, n - 12, d, 96, gate=0.9)
            if (tag == 'B' and k > 8) or (tag != 'B' and k >= 5): R.chip('dbl', b, st, n + 12, d, J.I_DBL, release=2)
            continue
        if tag == 'S':                                                 # el solo
            if v == 'A':
                R.chip('solo', b, st, n, d, I_SOLO, release=1, gate=0.85)
            else:
                R.gm('gtrlead', GTR, b, st, n - 12, d, 112, gate=0.9)
                R.chip('solo', b, st, n, d, I_SOLO, release=1, gate=0.85)
            continue
        if tag == 'D' and k <= 4:                                      # la caja de música
            R.chip('cm', b, st, n, d, I_BOX, q=F.q_n163, release=4, gate=0.9)
            continue
        strong = tag == 'C' or (tag == 'A' and k > 8)
        if v == 'A':
            R.chip('sawlead', b, st, n - 12, d, I_SAW_LEAD, q=F.q_saw, release=3)
        else:
            R.gm('lead', SYNBRASS, b, st, n - 12, d, 112, gate=0.9)
            R.gm('gtrlead', GTR, b, st, n - 12, d, 100, gate=0.85)
        if strong: R.chip('dbl', b, st, n, d, J.I_DBL, release=2)


# ══ LA BANDA ════════════════════════════════════════════════════════════════════════════════════════════════════════
WALK = ((0, 0, 3), (3, -1, 3), (6, -3, 3), (9, -5, 3), (12, -7, 2), (14, -8, 2))   # La Sol# Fa# Mi Re Do# (3+3+3+3+2+2)


def bass_drive(sg, R, b, walk=0):
    """el slap en 3+3+2 (acentos en 0 6 12, el ritmo de la melodía). walk: el bajo del usuario (2ª vuelta del tema):
    1 = Re, 2 = Mi# (Do#7/Mi#), 3 = Fa#, 4 = La-Sol#-Fa#-Mi-Re-Do#"""
    if walk == 4:
        for st, deg, d in WALK: R.sl(b, st, 45 + deg, d, 112 if st in (0, 6, 12) else 98)
        return
    if sg.chords[b - 1][0] != sg.chords[b - 1][1]:                   # (dos acordes: corcheas, raíz y octava)
        for st in range(0, 16, 2):
            r = r0(sg, b, st)
            R.sl(b, st, r + (12 if st % 4 == 2 else 0), 2, 112 if st % 8 == 0 else 96)
        return
    r = {2: 41, 3: 42}.get(walk, r0(sg, b, 0))                       # (Mi# en el Do#7 de la 2ª vuelta)
    fifth = 3 if walk == 2 else 7                                    # (sobre Mi#, la 5ª de Do#7 es Sol#: una 3ª menor)
    for st, deg, d, vel in ((0, 0, 2, 116), (2, 12, 1, 90), (3, 0, 2, 100), (6, 0, 2, 114), (8, 12, 2, 104),
                            (10, fifth, 2, 98), (12, 0, 2, 112)):
        R.sl(b, st, r + deg, d, vel)
    R.sl(b, 14, approach(sg, R, b, 14), 2, 100)


def drums_drive(sg, R, b, level, k):
    """el doble tiempo: caja en 2 y 4; bombo en 0 6 8 (y 14); nivel 3: semicorcheas de ruido; nivel 4: doble bombo"""
    kicks = (0, 6, 8, 14) if level < 4 else (0, 2, 4, 6, 8, 10, 12, 14)
    for st in kicks: R.kick(b, st, 1.0 if st in (0, 8) else 0.8)
    for st in (4, 12): R.snare(b, st, 0.95)
    if k % 4 == 0: R.snare(b, 15, 0.5)
    for st in range(16):
        if st % 2 == 0: R.NZ['hat'].hit(sg.t(b, st), 0, J.HAT if st % 4 else [6, 3, 1])
        elif level >= 3: R.NZ['hat'].hit(sg.t(b, st), 0, [3, 1])


def stabs(sg, R, b, vel, sts=(0, 6, 12)):
    """los metales en 3+3+2, debajo de la voz"""
    for st in sts: R.chord_gm('stab', BRASS, b, st, 2, vel, 50, nn=3, gate=0.6)


def gtr_chug(sg, R, b, vel):
    """guitarras: quintas en corcheas apagadas, las de 0 6 12 abiertas"""
    for st in range(0, 16, 2):
        R.power(b, st, 2, vel if st in (0, 6, 12) else vel - 22, gate=0.85 if st in (0, 6, 12) else 0.45)


def swirl16(sg, R, b):
    """el REMOLINO: semicorcheas por el acorde en 3+3+2 (como la melodía), la segunda mitad un escalón arriba"""
    for st in range(16):
        tones = place(None, sg.chord(b, st), 62)[:6]
        j = (0, 1, 2, 0, 1, 2, 0, 1)[st % 8] + (1 if st >= 8 else 0)
        n = tones[j]
        if not R.rub(b, st, n, 1, voice=LEADS): R.chip('swirl', b, st, n, 1, I_SWIRL, gate=0.6, release=1)


def held(sg, R, b, key, prog, vel, lo):
    for half in (0, 1):
        R.chord_gm(key, prog, b, half * 8, 8, vel, lo, nn=4, gate=0.98)


def toms_fill(sg, R, b, vel=88):
    for i, st in enumerate(range(12, 16)): R.dr('toms', b, st, TOM_L + 6 - 2 * i, vel + 6 * i)


def walk_of(k):
    """el bajo del usuario en la 2ª vuelta de cada tema de 8 (compases 5-8)"""
    kk = (k - 1) % 8 + 1
    return kk - 4 if kk >= 5 else 0


def ending(sg, R, b):
    """el último compás de la intro y de R (iguales: la costura): la banda pica en 0 3 6 y se calla; platillo al revés"""
    for i, st in enumerate((0, 3, 6)):
        R.sl(b, st, 40 + (0, 12, 7)[i], 2, 110 + 4 * i)
        R.kick(b, st); R.snare(b, st, 0.7 + 0.1 * i)
        R.chord_gm('stab', BRASS, b, st, 2, 104 + 4 * i, 50, nn=3, gate=0.6)
        R.power(b, st, 2, 100 + 6 * i, gate=0.8)
        R.timp(b, st, 4, 2, 100 + 8 * i)
    R.orch(b, 6, 108)
    R.gmt('revcym', REV_CYM, sg.t(b, 16) - 1.35, sg.t(b, 16) + 0.1, 60, 90)


def bar_intro(sg, R, b, k, L, full):
    """la fanfarria: 1-4 a medio tiempo (taikos, timbales, coro), 5-7 la banda, 8 los golpes (full: la R, con banda)"""
    if k == L: return ending(sg, R, b)
    held(sg, R, b, 'choir', CHOIR, 70 + 3 * k, 57)
    held(sg, R, b, 'trem', TREM, 66 + 2 * k, 50)
    if k == 1:
        R.crash(b); R.orch(b, 0, 116); R.timp(b, 0, 2, 4, 118)
    if k % 2 == 1: R.taiko(b, 0, 118); R.taiko(b, 6, 96); R.taiko(b, 12, 104, 45)
    if k <= 4 and not full:
        R.sl(b, 0, r0(sg, b, 0), 6, 108); R.sl(b, 6, r0(sg, b, 0) + 12, 6, 100); R.sl(b, 12, r0(sg, b, 0), 4, 104)
        R.kick(b, 0); R.kick(b, 6, 0.8)
        if k >= 3: R.snare(b, 8, 0.9)
        if k % 2 == 0: R.taiko(b, 0, 100); R.taiko(b, 8, 92)
        if k == 4:
            for st in range(8, 16): R.timp(b, st, 6, 1, 64 + 6 * (st - 8))
    else:
        bass_drive(sg, R, b)
        drums_drive(sg, R, b, 2 if not full else 3, k)
        stabs(sg, R, b, 96, (0, 6))
        if k == 5: R.crash(b); R.timp(b, 0, 6, 4, 112)
        if full and k == 1: pass
        if k == L - 1:
            for st in range(8, 16): R.snare(b, st, 0.35 + 0.08 * (st - 8))
            toms_fill(sg, R, b)


def bar_theme(sg, R, b, k, L, tag):
    """A y C: el tema"""
    big = tag == 'C'
    level = 4 if big else (2 if k <= 8 else 3)
    bass_drive(sg, R, b, walk_of(k) if (big or k > 8) else 0)
    drums_drive(sg, R, b, level, k)
    stabs(sg, R, b, 104 if big else 94, (0, 6, 12) if big or k > 8 else (0, 6))
    if k > 8 or big:
        swirl16(sg, R, b); held(sg, R, b, 'trem', TREM, 76 if big else 68, 50)
    if big:
        gtr_chug(sg, R, b, 104)
        held(sg, R, b, 'choir', CHOIR, 78, 57)
        R.taiko(b, 0, 110); R.taiko(b, 6, 92); R.taiko(b, 12, 100, 45)
    if k in (1, 9) or (big and k in (5, 13)):
        R.crash(b); R.timp(b, 0, sg.chord(b, 0)[0], 4, 112)
        if big or k == 1: R.orch(b, 0, 112 if big else 100)
    if k % 8 == 0: toms_fill(sg, R, b, 84 if not big else 96)


def bar_hymn(sg, R, b, k, L):
    """B: el himno. 1-8 a medio tiempo (taikos), 9-16 doble tiempo; el 14 (Sol), golpe; el 16, medio y silencio"""
    held(sg, R, b, 'choir', CHOIR, 76 if k > 8 else 70, 57)
    held(sg, R, b, 'trem', TREM, 74, 50)
    swirl16(sg, R, b)
    if k == L:                                                         # el último: un golpe y medio compás vacío
        R.sl(b, 0, r0(sg, b, 0), 4, 116); R.kick(b, 0, 1.1); R.snare(b, 0)
        R.orch(b, 0, 112); R.timp(b, 0, 1, 4, 116); R.crash(b)
        R.power(b, 0, 4, 108, gate=0.9)
        for st in range(4, 8): R.timp(b, st, 1, 1, 80 + 8 * (st - 4))
        R.gmt('revcym', REV_CYM, sg.t(b, 16) - 1.35, sg.t(b, 16) + 0.1, 60, 92)
        return
    if k <= 8:
        r = r0(sg, b, 0)
        R.sl(b, 0, r, 6, 112); R.sl(b, 6, r + 12, 2, 98); R.sl(b, 8, r, 4, 104); R.sl(b, 12, r + 7, 2, 96)
        R.sl(b, 14, approach(sg, R, b, 14), 2, 98)
        R.kick(b, 0); R.kick(b, 6, 0.7); R.snare(b, 8, 1.0)
        for st in (0, 4, 8, 12): R.NZ['hat'].hit(sg.t(b, st), 0, [6, 3, 1])
        R.taiko(b, 0, 116); R.taiko(b, 6, 98); R.taiko(b, 10, 92, 45); R.taiko(b, 12, 104, 45)
        if k % 2 == 1: R.timp(b, 0, sg.chord(b, 0)[0], 6, 108)
        if k == 1: R.crash(b)
        if k == 8:
            for st in range(8, 16): R.snare(b, st, 0.3 + 0.08 * (st - 8))
            toms_fill(sg, R, b, 92)
    else:
        bass_drive(sg, R, b)
        drums_drive(sg, R, b, 3, k)
        stabs(sg, R, b, 98, (0, 6, 12))
        gtr_chug(sg, R, b, 96)
        if k in (9, 13): R.crash(b); R.timp(b, 0, sg.chord(b, 0)[0], 4, 112)
        if k == 14: R.orch(b, 0, 118); R.crash(b); R.timp(b, 0, 7, 6, 120)     # (el napolitano)
        if k == L - 1:
            for st in range(8, 16): R.snare(b, st, 0.4 + 0.08 * (st - 8))
            toms_fill(sg, R, b, 100)


def bar_solo(sg, R, b, k, L):
    """S: el solo en disminución; doble bombo, guitarras, metales en cada medio compás"""
    bass_drive(sg, R, b)
    if k == L:                                                         # baja por Mi7 y se para en el 3
        for st in (0, 2, 4, 6): R.kick(b, st); R.NZ['hat'].hit(sg.t(b, st), 0, J.HAT)
        R.snare(b, 4); R.kick(b, 8, 1.1); R.snare(b, 8); R.crash(b, 8); R.orch(b, 8, 110); R.timp(b, 8, 4, 4, 116)
        R.power(b, 0, 6, 100, gate=0.9); R.power(b, 8, 6, 110, gate=0.9)
        return
    drums_drive(sg, R, b, 4, k)
    for st in (0, 8): R.chord_gm('stab', BRASS, b, st, 3, 100, 50, nn=3, gate=0.6)
    gtr_chug(sg, R, b, 100)
    held(sg, R, b, 'trem', TREM, 72, 50)
    if k in (1, 5): R.crash(b); R.orch(b, 0, 110)
    if k % 2 == 1: R.timp(b, 0, sg.chord(b, 0)[0], 4, 104)


def bar_breath(sg, R, b, k, L):
    """D: la caja de música (1-4), la voz y la banda que vuelven y crecen (5-8), medio compás de silencio"""
    held(sg, R, b, 'choir', CHOIR, 60 + 3 * k, 57)
    if k <= 4:
        R.sl(b, 0, r0(sg, b, 0), 14, 92)
        R.taiko(b, 0, 92); R.kick(b, 0, 0.7)
        if k == 1: R.timp(b, 0, 2, 8, 90)
        return
    held(sg, R, b, 'trem', TREM, 60 + 4 * k, 50)
    if k < L:
        bass_drive(sg, R, b, walk_of(k))
        for st in ((0, 8) if k == 5 else (0, 4, 8, 12) if k == 6 else range(0, 16, 2)): R.kick(b, st, 0.9)
        if k >= 6: R.snare(b, 4, 0.8); R.snare(b, 12, 0.8)
        if k == 7:
            for st in range(0, 16, 2): R.snare(b, st, 0.35 + 0.03 * st)
        swirl16(sg, R, b) if k >= 6 else None
        R.taiko(b, 0, 100 + 4 * k)
    else:                                                              # el 8: redoble y silencio
        R.sl(b, 0, 52, 2, 104); R.sl(b, 2, 56, 2, 104); R.sl(b, 4, 62, 2, 104); R.sl(b, 6, 52, 2, 104)
        for st in range(8): R.snare(b, st, 0.45 + 0.07 * st); R.kick(b, st, 0.8)
        for st in range(8): R.timp(b, st, 4, 1, 80 + 5 * st)
        R.gmt('revcym', REV_CYM, sg.t(b, 16) - 1.35, sg.t(b, 16) + 0.1, 60, 96)


def arrange(sg, R, v):
    play_melody(sg, R, v)
    for b in range(1, sg.NB + 1):
        tag, k, L = sg.tag[b - 1], sg.pos[b - 1], sg.slen[b - 1]
        if tag in ('intro', 'R'): bar_intro(sg, R, b, k, L, full=tag == 'R')
        elif tag in ('A', 'C'): bar_theme(sg, R, b, k, L, tag)
        elif tag == 'B': bar_hymn(sg, R, b, k, L)
        elif tag == 'S': bar_solo(sg, R, b, k, L)
        else: bar_breath(sg, R, b, k, L)


# ══ LA MEZCLA ═══════════════════════════════════════════════════════════════════════════════════════════════════════
LV = {'lead': 0, 'horn': 0, 'solo': 0, 'cm': -2, 'fan': -5, 'horn2': -7, 'gtrlead': -7, 'dbl': -11,
      'stab': -8, 'trem': -9, 'choir': -8, 'pad': -10, 'swirl': -10, 'gtr': -8, 'hit': -5,
      'bass': -2, 'kick': -1, 'snare': 0, 'hat': -9, 'crash': -6, 'timp': -3, 'taiko': -6, 'toms': -4, 'revcym': -8}
LEAD_GROUP = ('lead', 'horn', 'solo', 'cm')
DRUM_GROUP = ('kick', 'snare', 'hat', 'crash', 'timp', 'taiko', 'toms', 'revcym')
ACC_GROUP = ('stab', 'trem', 'choir', 'pad', 'swirl', 'gtr', 'hit', 'fan', 'horn2', 'gtrlead', 'dbl')
BACKING = 3.5


def build(v):
    sg = J.Song(TRACK, v)
    R = Rig(sg)
    arrange(sg, R, v)
    n = int(round(sg.NB * sg.BAR * SR))
    at = int(round(sg.INTRO * sg.BAR * SR))
    L = n + 5 * SR
    S = M.render_stems(R, n, L, True, at / SR)
    def cut(x):
        x = x[:L] - np.mean(x[:n])
        return np.concatenate([x, np.zeros(L - len(x))]) if len(x) < L else x
    y = GM.cached(R.slap, L)
    S['bass'] = np.concatenate([y[M.GM_LAT:], np.zeros(M.GM_LAT)])
    for k in ('sawlead', 'fan'):
        if np.abs(R.Cn[k].v).max() > 0: S[k] = cut(F.render_saw(R.Cn[k]) * 0.0035)
    for k in ('swirl', 'solo'):
        if np.abs(R.Cn[k].v).max() > 0: S[k] = cut(F.pulse_dac(F.render_pulse(R.Cn[k])))
    if 'sawlead' in S: S['lead'] = S.pop('sawlead')
    if 'solo' in S:                                                    # (el eco de la casa: 3 semicorcheas)
        S['solo'] = GN.delay(S['solo'], 3 * 60.0 / BPM / 4, 0.3, 2, 4000)[:L]
    from scipy.signal import butter, sosfilt
    hp = butter(2, 30, btype='high', fs=SR, output='sos')
    S = {k: sosfilt(hp, x) for k, x in S.items() if np.abs(x).max() > 0}
    g = GN.level(S, {k: LV.get(k, -10) + (0 if k in LEAD_GROUP else BACKING) for k in S}, 'lead')
    x = sum(S[k] * g[k] for k in S)
    sd = lambda k, w: S[k] * g[k] * w if k in S else 0.0
    side = sd('stab', 0.2) - sd('gtr', 0.3) + sd('gtrlead', 0.15) + sd('choir', 0.2) - sd('trem', 0.2) + sd('hat', 0.25) \
        + sd('swirl', 0.3) - sd('dbl', 0.15) + sd('fan', 0.1) - sd('horn2', 0.15) - sd('toms', 0.3) + sd('taiko', 0.1)
    Lx, Rx = x + side, x - side
    st = np.stack([GN.fold(Lx, n, at), GN.fold(Rx, n, at)], 1)
    st = F.master(st, lufs=LUFS, ceiling=CEILING)
    S = {k: GN.fold(s, n, at) for k, s in S.items()}
    return sg, R, S, g, st, n, at


# ══ INFORME (números: NO se ha escuchado) ═══════════════════════════════════════════════════════════════════════════
def report(v, sg, R, S, g, y, n, at):
    mn, lb, lo, out = melody_report(v, sg)
    tot = sum(np.mean((S[k][:n] * g[k]) ** 2) for k in S)
    grp = lambda ks: 100 * sum(np.mean((S[k][:n] * g[k]) ** 2) for k in ks if k in S) / tot
    bar = sg.BAR * SR
    lufs = F.loudness(y)
    print(f'  {sg.NB} compases: intro {sg.INTRO} = {at} muestras ({at / SR:.2f} s) + bucle {sg.NB - sg.INTRO} = {n - at} muestras ({(n - at) / SR:.2f} s) · {lufs:.1f} LUFS, pico {np.abs(y).max():.2f}')
    print(f'  energía: melodía {grp(LEAD_GROUP):.0f} %, batería {grp(DRUM_GROUP):.0f} %, bajo {grp(("bass",)):.0f} %, acompañamiento {grp(ACC_GROUP):.0f} %')
    print('  ' + ' '.join(f'{k} {100 * np.mean((S[k][:n] * g[k]) ** 2) / tot:.1f}' for k in sorted(S, key=lambda k: -np.mean((S[k][:n] * g[k]) ** 2))))
    from scipy.signal import butter, sosfilt
    bp = butter(2, [1000, 5000], btype='band', fs=SR, output='sos')
    rms = lambda z: np.sqrt(np.mean(sosfilt(bp, z[at:n]) ** 2))
    lead = sum(S[k] * g[k] for k in LEAD_GROUP if k in S)
    print('    en 1-5 kHz, frente a la melodía: ' + ' '.join(f'{k} {100 * rms(S[k] * g[k]) / rms(lead):.0f} %' for k in S if k not in LEAD_GROUP and rms(S[k] * g[k]) / rms(lead) > 0.2))
    tot_cl = 0
    for k, notes in R.notes.items():
        if k in LEADS or not notes: continue
        # (solo los que tienen una nota FUERA del acorde: Do# sobre Re en Remaj7 o Sol#-Re en Mi7 son el propio acorde)
        cl = [c for c in J.clashes(sg, sg.mel, notes) if not all(_pc(x) in sg.tones(c[0], c[1]) for x in c[2:])]
        tot_cl += len(cl)
        if cl: print(f'    choques melodía / {k} (≥ corchea): {len(cl)} {cl[:5]}')
    print(f'    choques totales melodía / resto: {tot_cl}')
    ln, bars, jr, dbs, ji, dbi = M.seam_numbers(y, at, bar, [(b0 - 1) * sg.BAR * SR for b0 in sg.starts[2:]])
    print(f'  BUCLE: {ln} muestras = {bars:.4f} compases; costura: salto {jr:.2f}× el de otro tiempo 1 de sección, {dbs:+.1f} dB; intro → bucle {ji:.2f}×, {dbi:+.1f} dB')
    span = lambda b0, L_: (int((b0 - 1) * sg.BAR * SR), int((b0 - 1 + L_) * sg.BAR * SR))
    def db(a, b_):
        z = sum(S[k][a:b_] * g[k] for k in S)
        return 10 * np.log10(np.mean(np.asarray(z) ** 2) + 1e-12)
    r_ = db(*span(sg.starts[1], 16))
    secs = ' '.join(f'{sg.tag[b0 - 1]} {db(*span(b0, sg.slen[b0 - 1])) - r_:+.1f}' for b0 in sg.starts)
    print('  sonoridad por sección vs A (dB): ' + secs)
    w = int(0.025 * SR)
    env = lambda z: np.sqrt(np.convolve(z.mean(1) ** 2, np.ones(w) / w, mode='valid')[::w])
    a_, b_ = env(y[at - int(bar):at]), env(y[n - int(bar):n])
    same = np.corrcoef(a_, b_)[0, 1]
    print(f'  el último compás de la intro y el del bucle (envolvente de 25 ms): correlación {same:.3f}, {20 * np.log10(b_.mean() / a_.mean()):+.2f} dB')
    return dict(lufs=lufs, loop=n - at, intro=at, bars=bars, jr=jr, ji=ji, dbs=dbs, nlb=len(lb), nlo=len(lo), nout=len(out), ncl=tot_cl,
                mn=mn, lead=grp(LEAD_GROUP), peak=np.abs(y).max(), secs=secs, same=same)


def _pc(name):
    return (J.NAMES.index(name[:-1]) if name[:-1] in J.NAMES else 0)


def mmss(t):
    return f'{int(t // 60)}:{t % 60:04.1f}'


def readme(sg, nums):
    desc = {'intro': 'INTRO: la fanfarria de trompas (LA LLAMADA La-Re-Fa#-La), taikos, timbales, coro; la banda entra en el 5',
            'A': 'A: EL TEMA (tu melodía) dos veces; la 2ª con octava, remolino, cuerdas y tu bajo que baja',
            'B': 'B: EL HIMNO en trompas y coro (la cabeza del tema que se posa); medio tiempo y luego doble; el napolitano Sol',
            'S': 'S: EL SOLO — el tema en semicorcheas (dos compases en uno), doble bombo y guitarras',
            'D': 'D: EL RESPIRO — la caja de música toca el tema como en el original; la banda vuelve y crece',
            'C': 'C: EL CLÍMAX — el tema con todo: guitarras, coro, metales 3+3+2, golpes de orquesta, doble bombo',
            'R': 'R: vuelve la fanfarria, con la banda; acaba igual que la intro'}
    t = ['TUFFI — tema épico nuevo sobre tu melodía (tuffi.mid)',
         'tools/music/tuffi.py. NO SE HA ESCUCHADO: comprobado solo con números. El oído es el tuyo.',
         '',
         'Fa# menor, 180 BPM (el original iba a 135), batería en doble tiempo. Tu melodía tal cual (una octava arriba) con tu',
         'armonía: Remaj7 · Do#7 · Fa#m7 · Mi7. Su agrupación 3+3+2 es el ritmo de toda la banda (slap, metales, taikos, bombo).',
         'Reparto: slap de los jefes, bombo y caja de DPCM, ruido; trompas, metales, cuerdas en trémolo, coro, timbales, taikos,',
         'golpe de orquesta, guitarras distorsionadas, platillo al revés; remolino de pulso y caja de música del N163.',
         '',
         'LAS DOS VARIANTES (misma forma y banda; otra voz):',
         '  A chip_epico  la melodía en la SIERRA del VRC6 (+ pulso a la octava); el solo en el pulso del 2A03 con eco.',
         '  B orquesta    la melodía en METALES sintéticos + guitarra distorsionada; el solo en la guitarra.',
         '',
         'ARCHIVOS: tuffi_<v>_preview.ogg / .mp3 (intro + el bucle dos veces), _intro.ogg, _loop.ogg, _costura.ogg (fin del',
         'bucle → principio), .mid.',
         '',
         'SECCIONES (tiempos de la previa):']
    for b0 in sg.starts:
        t.append(f'  {mmss((b0 - 1) * sg.BAR)}  {desc[sg.tag[b0 - 1]]}')
    lp = (sg.NB - sg.INTRO) * sg.BAR
    t.append(f'  {mmss(sg.NB * sg.BAR)}  el bucle empieza otra vez (segunda vuelta: mismas secciones + {mmss(lp)})')
    t += ['', 'NÚMEROS:'] + nums
    t += ['', 'A JUZGAR DE OÍDO: si 180 BPM es "muchísimo más rápido" o hace falta más; si la melodía se oye sobre la banda;',
          'el himno (B) y el solo (S); el volumen de las guitarras y del coro; y dónde va en el juego (jefe, nivel, menú…).']
    return '\n'.join(t) + '\n'


def enc_mp3(y, path):
    wav = path[:-4] + '.wav'
    F.write_wav(wav, y)
    os.system(f'ffmpeg -v quiet -y -i "{wav}" -c:a libmp3lame -q:a 2 "{path}"')
    os.remove(wav)


if __name__ == '__main__':
    which = [a for a in sys.argv[1:] if a in VNAME] or list(VNAME)
    if os.environ.get('INSTALL'): which = [os.environ['TUFFI']]
    os.makedirs(PRUEBAS, exist_ok=True)
    nums = []
    for v in which:
        sg, R, S, g, y, n, at = build(v)
        r = report(v, sg, R, S, g, y, n, at)
        mn = r['mn']
        nums.append(f'  {v} {VNAME[v]}: intro {r["intro"] / SR:.2f} s + bucle {r["loop"] / SR:.2f} s ({r["bars"]:.4f} compases), '
                    f'{r["lufs"]:.1f} LUFS, pico {r["peak"]:.2f}; melodía {r["lead"]:.0f} % de la energía; choques {r["ncl"]}')
        nums.append(f'      costura {r["jr"]:.2f}× un tiempo 1 de sección ({r["dbs"]:+.1f} dB); secciones (dB frente a A): {r["secs"]}')
        if os.environ.get('REPORT'): continue
        if os.environ.get('INSTALL'):
            J.export(y, at, os.path.join(F.MUSIC_DIR, 'bosses', TRACK))
            print(f'  instalada {v} {VNAME[v]} en assets/music/bosses/{TRACK}_intro|_loop.ogg')
            continue
        base = os.path.join(PRUEBAS, f'{TRACK}_{v}_{VNAME[v]}')
        J.export(y, at, base)
        pv = np.concatenate([y, y[at:]])
        J.enc(pv, base + '_preview.ogg')
        enc_mp3(pv, base + '_preview.mp3')
        w = 8 * SR
        J.enc(np.concatenate([y[n - w:n], y[at:at + w]]), base + '_costura.ogg')
        J.write_mid(base + '.mid', sg, R)
    if not os.environ.get('REPORT') and not os.environ.get('INSTALL'):
        with open(os.path.join(PRUEBAS, 'LEEME.txt'), 'w') as f:
            f.write(readme(sg, nums))
        print(f'  previas en {PRUEBAS}')
