#!/usr/bin/env python3
# tools/music/story_music.py
# LA MÚSICA DE LAS CINEMÁTICAS de la historia ("El Espejo Roto"), compuesta SOBRE los tiempos de la película:
# lee assets/story/films.json (cada escena: pulsos, tempo y sus momentos) — la misma tabla con la que el juego
# dibuja la película (src/story/Film.lua) —, así que cada golpe, cada nota y cada cambio caen en su imagen. Si se
# cambia un tiempo en films.json hay que volver a generar la música.
#
# Material (todo propio del juego):
#   · "Rumbo a las islas" (el tema del mapa: empieza con LA LLAMADA, 5-1-3-5 subiendo) = el monstruo, feliz y libre
#   · LA LLAMADA sola, en caja de música = el monstruo ante el espejo
#   · EL MOTIVO DEL ESPEJO = la llamada reflejada (baja 5-2-7-5: el acorde de dominante), y la cabeza del tema
#     del jefe Espejo (aquí en La menor) = el Reflejo
#   INTRO (Do mayor → La menor → Do mayor): vuela con su tema; el tema se queda colgado en el destello; ante el
#     espejo la caja de música canta la llamada y el espejo la devuelve AL REVÉS; el golpe; el Reflejo entra con
#     su tema, le roba la llamada (que se desinfla) y se ríe con el motivo martilleado; seis campanas que bajan,
#     una por fragmento; seis golpes que suben, uno por jefe; y, ya en la Pradera, la llamada: primero no le sale,
#     luego decidida — enlaza con la música del mapa.
#   FINAL (La mayor, el paralelo luminoso): la llamada en la caja de música; siete notas que SUBEN la escala, una
#     por fragmento (las mismas que canta el efecto de sonido al encajar); el acorde entero; el tema del Reflejo se
#     deshace hacia abajo; el tema del mapa a pleno mientras la luz recorre las islas; seis respuestas juguetonas
#     (los jefes encogen); la llamada, nota a nota, con cada aleteo; y el tema entero volando a casa.
#   ~/.venvs/fm-music/bin/python tools/music/story_music.py [intro ending]     REPORT=1 → números, sin exportar
# Se comprueba con números (NO se ha escuchado): duración = la de la película, sonoridad, energía por escena.
import json, os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import famicom as F
from famicom import SR, Chan, Noise, play, wavetable, q_tri, q_saw, q_n163, q_pulse
import tentacle_nes as TN
import gloomy_nes as GN
import worlds_nes as W
import worldmap_nes as WM

FILMS = json.load(open(os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'story', 'films.json')))
NAMES = {'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5, 'F#': 6, 'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11}


def nn(s):
    """'C#5' → nota MIDI"""
    return 12 * (int(s[-1]) + 1) + NAMES[s[:-1]]


WAVES = [wavetable([1.0, 0.5, 0.33, 0.2, 0.12]),                # 0 voz suave
         GN.CWAVES[0],                                          # 1 caja de música / campanas
         wavetable([1.0, 0.25, 0.4, 0.1, 0.2])]                 # 2 coro (colchón)
I_LEAD = {'vol': [15, 14, 13, 13, 12, 12], 'sus': 12, 'vib': (12, 0.22, 5.6), 'duty': [0.25, 0.5]}
I_THIN = {'vol': [9, 8, 7, 6, 6, 5], 'sus': 5, 'duty': 0.125}
I_SAD = {'vol': [10, 9, 8, 7, 6, 5, 4, 3], 'sus': 2, 'duty': 0.25, 'drop': [0, 0, -0.1, -0.2, -0.4, -0.7, -1.0, -1.4]}   # se desinfla
I_SAW = {'vol': [15, 15, 14, 14, 13, 13], 'sus': 13, 'vib': (14, 0.2, 6)}
I_PLUCK = {'vol': [12, 9, 6, 4, 2, 1], 'sus': 0, 'duty': 0.25}
I_STAB = {'vol': [14, 12, 9, 6, 4, 2], 'sus': 1, 'duty': 0.25}
I_ARP = {'vol': [8, 6, 4, 2], 'sus': 1, 'duty': 0.125}
I_BELL = dict(GN.I_BELL, duty=1.0)
I_CHOIR = {'vol': [3, 5, 7, 8, 9, 9, 10], 'sus': 10, 'vib': (20, 0.12, 4.5), 'duty': 2.0}
I_SOFT = {'vol': [8, 11, 12, 12, 11, 11], 'sus': 11, 'vib': (16, 0.18, 5.0), 'duty': 0.0}
I_TRI = {'vol': [15], 'sus': 15}
SNARE_N, CRASH = [14, 10, 6, 3, 1], [14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
HAT = [5, 2, 1]
MAJ, MIN = (0, 4, 7), (0, 3, 7)


class Song:
    def __init__(self, film):
        self.film = film
        self.t0, self.bs, self.cues, self.order = {}, {}, {}, []
        t = 0.0
        for s in FILMS[film]['scenes']:
            beat = 60.0 / s['bpm']
            self.t0[s['id']], self.bs[s['id']], self.cues[s['id']] = t, beat, s.get('cues', {})
            self.order.append((s['id'], t, t + s['beats'] * beat))
            t += s['beats'] * beat
        self.total = t
        self.NF = F.frames_for(t + 3)
        self.C = {k: Chan(self.NF) for k in ('lead', 'lead2', 'thin', 'saw', 'bell', 'bell2', 'soft', 'p1', 'p2', 'p3',
                                             'bass', 's1', 's2', 'arp')}
        self.NZ = {k: Noise(self.NF) for k in ('hat', 'snare', 'crash', 'fx')}
        self.NS = int(self.NF * F.FRAME_S) + SR
        self.kick, self.sn, self.tom = np.zeros(self.NS), np.zeros(self.NS), np.zeros(self.NS)
        self.sc = None

    # ── tiempo ──
    def scene(self, sid): self.sc = sid; return self
    def T(self, beat): return self.t0[self.sc] + beat * self.bs[self.sc]
    def cue(self, name): return self.cues[self.sc][name]

    # ── notas (b = pulso de la escena, d = duración en pulsos) ──
    def n(self, ch, b, d, note, inst, q=q_pulse, vs=1.0, rel=3, leg=0.92):
        if isinstance(note, str): note = nn(note)
        play(self.C[ch], self.T(b), self.T(b) + d * self.bs[self.sc] * leg, note, inst, q=q, vs=vs, release=rel)

    def lead(self, b, d, note, vs=1.0): self.n('lead', b, d, note, I_LEAD, vs=vs)
    def saw(self, b, d, note, vs=1.0, leg=0.92): self.n('saw', b, d, note, I_SAW, q=q_saw, vs=vs, leg=leg)
    def bell(self, b, d, note, vs=1.0, ch='bell'): self.n(ch, b, max(d, 1.2), note, I_BELL, q=q_n163, vs=vs, rel=8, leg=1.0)
    def bass(self, b, d, note, leg=0.9): self.n('bass', b, d, note, I_TRI, q=q_tri, rel=0, leg=leg)

    def pad(self, b, d, notes, vs=1.0):
        for ch, note in zip(('p1', 'p2', 'p3'), notes):
            self.n(ch, b, d, note, I_CHOIR, q=q_n163, vs=vs, rel=5, leg=0.98)

    def stab(self, b, d, root, vs=1.0, fifth=7):
        self.n('s1', b, d, root, I_STAB, vs=vs, rel=2); self.n('s2', b, d, nn(root) + fifth if isinstance(root, str) else root + fifth, I_STAB, vs=vs, rel=2)

    # ── batería ──
    def _hit(self, buf, smp, t, g):
        i = int(t * SR); m = max(0, min(len(smp), self.NS - i))
        buf[i:i + m] += smp[:m] * g

    def k(self, b, g=1.0, deep=False): self._hit(self.kick, TN.KICK_DEEP if deep else TN.KICK, self.T(b), g)
    def s(self, b, g=1.0, vols=SNARE_N): self.NZ['snare'].hit(self.T(b), 4, vols); self._hit(self.sn, TN.SNARE_BODY, self.T(b), g)
    def tm(self, b, i=2, g=1.0): self._hit(self.tom, W.TOMS[i], self.T(b), g)
    def h(self, b, vols=HAT): self.NZ['hat'].hit(self.T(b), 1, vols)
    def cr(self, b): self.NZ['crash'].hit(self.T(b), 3, CRASH)

    def roll(self, b0, b1, per, g0=0.25, g1=1.0):
        """redoble de caja que crece, una nota cada `per` pulsos"""
        n_ = max(1, int(round((b1 - b0) / per)))
        for i in range(n_):
            x = i / max(1, n_ - 1)
            self.s(b0 + i * per, g0 + (g1 - g0) * x, [int(4 + 8 * x), int(2 + 4 * x), 1])

    def riser(self, b0, b1):
        """ruido que sube"""
        t0, t1 = self.T(b0), self.T(b1)
        n_ = int((t1 - t0) * 60)
        for i in range(n_):
            x = i / max(1, n_ - 1)
            self.NZ['fx'].hit(t0 + i / 60.0, int(round(9 - 7 * x)), [max(1, int(round(10 * x ** 1.5)))])

    # ── el tema del mapa: compases `bars` (1-16 de "Rumbo a las islas"), transportado `tr` semitonos ──
    def map_tune(self, bars, tr=0, start=0, band=True, vs=1.0, bells=False, drums='light'):
        for k_, bar in enumerate(bars):
            off = start + 4 * k_
            for (mb, st, note, d) in (WM.MEL_A if bar <= 8 else WM.MEL_B):
                if mb != bar: continue
                self.lead(off + st / 4, d / 4, note + tr, vs)
                self.n('lead2', off + st / 4 + 0.75, min(d / 4, 0.6), note + tr, I_THIN, vs=0.6)       # su eco
                if bells: self.bell(off + st / 4, d / 4, note + tr + 12, 0.8)
            if not band: continue
            r, q = WM.chord(bar)
            r = r + tr
            root = 36 + (r - 36) % 12
            ch_ = [60 + (r - 60) % 12 + iv for iv in q[:3]]
            for bt in range(4):                                     # bajo saltarín: fundamental y quinta
                self.bass(off + bt, 0.45, root + (7 if bt % 2 else 0))
                self.n('s1', off + bt + 0.5, 0.3, ch_[1], I_PLUCK, vs=0.8, rel=1)       # acordes a contratiempo
                self.n('s2', off + bt + 0.5, 0.3, ch_[2], I_PLUCK, vs=0.8, rel=1)
                if drums:
                    if bt % 2 == 0: self.k(off + bt, 0.9)
                    else: self.s(off + bt, 0.7 if drums == 'light' else 1.0)
                    self.h(off + bt); self.h(off + bt + 0.5, [3, 1])
                    if drums == 'full': self.k(off + bt + 0.75, 0.6) if bt == 2 else None
            if drums == 'full' and k_ % 2 == 0: self.cr(off)

    # ── mezcla ──
    def render(self, dyn, lufs=-13.0):
        n = int(self.total * SR)
        tail = int(2.0 * SR)
        cut = lambda x: x[:n + tail] - np.mean(x[:n])
        pulse = lambda k_: cut(F.pulse_dac(F.render_pulse(self.C[k_])))
        wave = lambda k_: cut(F.render_wave(self.C[k_], WAVES) * 0.0075)
        base = F.tnd_dac(np.full(self.NS, 64 / 22638.0))
        S = {
            'lead': pulse('lead'), 'echo': pulse('lead2') + pulse('thin'), 'saw': cut(F.pulse_dac(F.render_saw(self.C['saw']))),
            'bell': GN.delay(wave('bell') + wave('bell2'), 0.28, 0.35, 3, 3000), 'soft': wave('soft'),
            'choir': wave('p1') + wave('p2') + wave('p3'), 'stabs': pulse('s1') + pulse('s2'), 'arp': pulse('arp'),
            'bass': cut(F.tnd_dac(F.render_tri(self.C['bass']) / 8227.0)),
            'kick': cut(F.tnd_dac((self.kick + 64) / 22638.0) - base), 'toms': cut(F.tnd_dac((self.tom + 64) / 22638.0) - base),
            'snare': cut(F.tnd_dac((self.sn + 64) / 22638.0) - base) + cut(F.tnd_dac(self.NZ['snare'].render() / 22638.0 * 12)),
            'hat': cut(F.tnd_dac(self.NZ['hat'].render() / 22638.0 * 12)),
            'crash': cut(F.tnd_dac(self.NZ['crash'].render() / 22638.0 * 12)) + cut(F.tnd_dac(self.NZ['fx'].render() / 22638.0 * 12)),
        }
        LV = {'lead': 0, 'echo': -9, 'saw': -1, 'bell': -2, 'soft': -3, 'choir': -4, 'stabs': -5, 'arp': -9,
              'bass': 2, 'kick': 2, 'toms': 1, 'snare': 0, 'hat': -10, 'crash': -6}
        g = GN.level(S, LV, 'lead')
        from scipy.signal import butter, sosfilt
        x = sum(S[k_] * g[k_] for k_ in S)
        x = sosfilt(butter(1, 30, btype='high', fs=SR, output='sos'), x)
        side = S['arp'] * g['arp'] * 0.6 + S['choir'] * g['choir'] * 0.4 + S['bell'] * g['bell'] * 0.3 + S['hat'] * g['hat'] * 0.3
        # dinámica por escenas (dB al entrar → al salir)
        env = np.ones(len(x))
        for sid, a, e in self.order:
            d0, d1 = dyn.get(sid, (0, 0))
            i0, i1 = int(a * SR), min(len(x), int(e * SR))
            env[i0:i1] = 10 ** (np.linspace(d0, d1, i1 - i0) / 20)
        env[int(self.total * SR):] = env[int(self.total * SR) - 1]
        k_ = int(0.03 * SR); env = np.convolve(np.pad(env, k_, mode='edge'), np.ones(2 * k_ + 1) / (2 * k_ + 1), mode='valid')[:len(x)]
        x, side = x * env, side * env
        y = F.master(np.stack([x + side, x - side], 1), lufs=lufs)
        fade = int(1.2 * SR)                                        # la cola se apaga
        y[-fade:] *= np.linspace(1, 0, fade)[:, None]
        GN.report('story_' + self.film, y, S, g, n)
        mono = y.mean(1)
        print('  escenas (s · dB): ' + ' · '.join('%s %.1f-%.1f %+.1f' % (sid, a, e, 20 * np.log10(np.sqrt(np.mean(mono[int(a * SR):int(e * SR)] ** 2)) + 1e-9)) for sid, a, e in self.order))
        print('  película %.2f s; pista %.2f s' % (self.total, len(y) / SR))
        return y


# ═════════════════════════════════════════════════════════════════════════════
# LA INTRO
# ═════════════════════════════════════════════════════════════════════════════
def intro():
    S = Song('intro')

    # 1. flappy — su tema (Rumbo a las islas, compases 1-4), ligero: acaba colgado en la dominante
    S.scene('flappy')
    S.map_tune([1, 2, 3, 4], drums='light')

    # 2. glint — la batería calla; el acorde se queda; dos campanas (el destello) y el bajo se oscurece hacia La menor
    S.scene('glint')
    S.pad(0, 4, ['G3', 'B3', 'D4'], 0.9)
    S.pad(4, 4, ['F3', 'B3', 'D4'], 0.9)
    S.pad(8, 4, ['E3', 'G#3', 'B3'], 1.0)
    S.bass(0, 3.8, 'G2'); S.bass(4, 3.8, 'F2'); S.bass(8, 3.8, 'E2')
    g_ = S.cue('glint')
    S.bell(g_, 2, 'B6'); S.bell(g_ + 0.25, 2, 'D7', 0.8)
    t_ = S.cue('turn')
    S.bell(t_, 2, 'B6', 0.9); S.bell(t_ + 0.25, 2, 'E7', 0.8)
    for i, note in enumerate(('D5', 'E5', 'D5', 'B4')):               # el tema, a medias: se le va la cabeza hacia allí
        S.n('thin', 1 + i * 2.5, 2, note, I_THIN, vs=0.9)
    S.n('soft', 8, 4, 'E5', I_SOFT, q=q_n163)

    # 3. mirror — la caja de música: la llamada (La menor)... y el espejo se la devuelve AL REVÉS
    S.scene('mirror')
    S.pad(0, 4, ['A3', 'C4', 'E4'], 0.7); S.bass(0, 3.9, 'A2')
    for i, note in enumerate(('E5', 'A5', 'C6', 'E6')): S.bell(i, 1.5, note)
    S.pad(4, 4, ['E3', 'G#3', 'B3'], 0.8); S.bass(4, 3.9, 'E2')
    for i, note in enumerate(('E6', 'B5', 'G#5', 'E5')):
        S.bell(4 + i, 1.5, note, 0.7, ch='bell2')
        S.n('thin', 4 + i + 0.12, 0.8, nn(note) - 12, I_THIN, vs=0.7)                # su sombra, una octava abajo

    # 4. crash — dos latidos, un trémolo que aprieta... y el golpe
    S.scene('crash')
    c_ = S.cue('crash')
    S.k(0, 0.8, True); S.k(1, 0.9, True)
    for i in range(int(c_ * 4)):                                       # trémolo: Mi con su ♭9 (Fa)
        S.n('p1', i / 4, 0.25, 'E4' if i % 2 == 0 else 'F4', I_CHOIR, q=q_n163, vs=0.6 + 0.5 * i / (c_ * 4), rel=1)
    S.bass(0, c_, 'E2', leg=1.0)
    S.k(c_, 1.2, True); S.tm(c_, 2, 1.2); S.cr(c_); S.s(c_, 1.0)
    for i, note in enumerate(('E6', 'F6', 'B6', 'C7', 'G#6')):          # el cristal: un racimo disonante que se apaga
        S.bell(c_ + i * 0.07, 2, note, 0.9 - i * 0.1, ch='bell' if i % 2 == 0 else 'bell2')

    # 5. reflex — el Reflejo: bordón grave, tictac, su motivo en la caja de música, y al plantarse, su tema
    S.scene('reflex')
    for i in range(8):
        S.bass(i, 0.6, 'A1'); S.bass(i + 0.667, 0.3, 'A1')              # galope (12/8)
        S.h(i, [3, 1]); S.h(i + 0.667, [2, 1])
    S.pad(0, 4, ['A3', 'C4', 'E4'], 0.6)
    p_ = S.cue('peek')
    for i, note in enumerate(('E6', 'B5', 'G#5')): S.bell(p_ + i * 0.667, 1.2, note, 0.8)
    l_ = S.cue('land')
    S.k(l_, 1.1); S.tm(l_, 2, 1.0); S.cr(l_); S.stab(l_, 1, 'A2', 1.2)
    S.pad(4, 4, ['A3', 'C4', 'E4'], 1.0)
    for st, d, note in ((0, 1, 'A4'), (1, 0.667, 'E4'), (1.667, 0.333, 'A4'), (2, 1, 'C5'), (3, 0.667, 'B4'), (3.667, 0.333, 'A4')):
        S.saw(4 + st, d, note)                                          # la cabeza del tema del jefe Espejo

    # 6. steal — tira de la llamada: se desinfla; el Reflejo la canta con su voz y se ríe; el monstruo lo intenta y cae
    S.scene('steal')
    pl, got, la, tr_, fa, bl = (S.cue(k_) for k_ in ('pull', 'got', 'laugh', 'try', 'fall', 'blast'))
    for i in range(12):
        S.bass(i, 0.6, 'A1' if i < 8 else 'E1'); S.bass(i + 0.667, 0.3, 'A1' if i < 8 else 'E1')
    for i in range(int((got - pl) * 3)):                               # sube la tensión: colchón cromático
        b_ = pl + i / 3
        S.n('p1', b_, 0.34, nn('A3') + i // 3, I_CHOIR, q=q_n163, vs=0.6 + 0.08 * i, rel=1)
        S.n('p2', b_, 0.34, nn('E4') + i // 3, I_CHOIR, q=q_n163, vs=0.6 + 0.08 * i, rel=1)
    for i, note in enumerate(('E5', 'A5', 'C6')):                       # la llamada, arrancada: cada nota se cae
        S.n('lead', pl + i * 0.9, 0.8, note, I_SAD, vs=1.0 - i * 0.15, rel=1)
    S.k(got, 1.1); S.tm(got, 1, 1.0); S.cr(got); S.stab(got, 1, 'A2', 1.2)
    for i, note in enumerate(('E5', 'A5', 'C6', 'E6')): S.saw(got + i * 0.25, 0.25, note)     # ...y ahora es SUYA
    for i, note in enumerate(('E6', 'E6', 'E6', 'B5', 'B5', 'B5', 'G#5', 'G#5', 'G#5')):   # la risa: el motivo, martilleado
        S.saw(la + i / 3, 0.25, note, leg=0.6)
        S.s(la + i / 3, 0.35, [6, 3, 1])
    S.saw(la + 3, 0.9, 'E5')
    S.pad(la, 3, ['E3', 'G#3', 'B3'], 1.0)
    S.n('thin', tr_, 0.5, 'E5', I_THIN); S.n('thin', tr_ + 0.6, 0.5, 'A5', I_THIN)        # lo intenta: dos notas...
    for i in range(6):                                                  # ...y se cae
        S.n('lead', fa + i * 0.1, 0.1, nn('C6') - i * 3, I_SAD, vs=0.9, rel=0)
    S.k(fa + 0.6, 1.0, True)
    S.roll(bl - 1, bl + 1, 0.125, 0.2, 1.1); S.riser(bl - 1, 12)
    S.pad(bl - 1, 2, ['E3', 'G#3', 'D4'], 1.2)

    # 7. scatter — el golpe y seis campanas que BAJAN, una por fragmento
    S.scene('scatter')
    S.k(0, 1.2, True); S.tm(0, 2, 1.2); S.cr(0); S.stab(0, 1.5, 'A2', 1.3)
    S.pad(0, 8, ['A3', 'C4', 'E4'], 0.9)
    for i in range(8):
        S.bass(i, 0.6, 'A1'); S.bass(i + 0.667, 0.3, 'A1')
        S.k(i, 0.6); S.h(i + 0.667, [3, 1])
    f_ = S.cue('first')
    for i, note in enumerate(('E6', 'D6', 'C6', 'B5', 'A5', 'G#5')):
        S.bell(f_ + i, 1.5, note, 1.0, ch='bell' if i % 2 == 0 else 'bell2')
        S.saw(f_ + i, 0.9, nn(note) - 24, 0.8)

    # 8. fury — seis golpes que SUBEN, uno por jefe; y la dominante, con redoble
    S.scene('fury')
    e_ = S.cue('each')
    roots = ('A2', 'A#2', 'C3', 'D3', 'E3', 'F3')
    for i, r in enumerate(roots):
        b_ = S.cue('first') + i * e_
        for j in range(4):                                             # el fragmento cae: una carrerilla
            S.n('arp', b_ + j * 0.125, 0.12, nn(r) + 36 - j * 2, I_ARP, vs=1.2, rel=0)
        S.k(b_ + 0.5, 1.2, True); S.tm(b_ + 0.5, 2, 1.1); S.cr(b_ + 0.5)
        S.stab(b_ + 0.5, 1.3, r, 1.3)
        S.saw(b_ + 0.5, 1.3, nn(r) + 24)
        S.bass(b_ + 0.5, 1.3, nn(r) - 12)
        S.pad(b_ + 0.5, 1.4, [nn(r) + 12, nn(r) + 15 if r in ('A2', 'D3') else nn(r) + 16, nn(r) + 19], 0.9)
        S.tm(b_ + 1.5, 1, 0.7); S.tm(b_ + 1.75, 0, 0.7)
    S.pad(12, 2, ['E3', 'G#3', 'B3'], 1.3); S.bass(12, 2, 'E1', leg=1.0); S.saw(12, 2, 'E5')
    S.roll(12, 14, 0.125, 0.3, 1.2); S.cr(12)

    # 9. onfoot — cae; silencio; la llamada no le sale; y entonces sí: decidida, en Do mayor (enlaza con el mapa)
    S.scene('onfoot')
    ld, up, wk = S.cue('land'), S.cue('up'), S.cue('walk')
    for i in range(8):
        S.n('thin', i * ld / 8, ld / 8, nn('E6') - i * 2, I_THIN, vs=0.9, rel=0)      # el silbido de la caída
    S.k(ld, 1.2, True); S.tm(ld, 2, 0.9)
    S.bell(ld + 1, 1.5, 'G4', 0.7); S.bell(ld + 2, 1.5, 'C5', 0.7)                     # dos notas sueltas, lejanas
    S.pad(up, wk - up, ['G3', 'B3', 'D4'], 0.6)
    for i, note in enumerate(('G4', 'C5', 'E5')):                                      # intenta aletear: le falta la última
        S.n('lead', 6.5 + i * 0.25, 0.22, note, I_SAD, vs=0.9, rel=1)
    for i, note in enumerate(('G4', 'C5', 'E5')):                                      # ...y echa a andar: LA LLAMADA, entera
        S.lead(wk + i * 0.5, 0.5, note); S.bell(wk + i * 0.5, 1, nn(note) + 12, 0.7)
    S.lead(wk + 1.5, 2.3, 'G5'); S.bell(wk + 1.5, 2.5, 'G6', 0.8)
    S.pad(wk, 4, ['C4', 'E4', 'G4'], 1.1)
    for i in range(4):
        S.bass(wk + i, 0.45, 'C2' if i % 2 == 0 else 'G2')
        S.k(wk + i, 0.9) if i % 2 == 0 else S.s(wk + i, 0.8)
        S.h(wk + i + 0.5, [3, 1])
    S.roll(wk - 0.5, wk, 0.125, 0.3, 0.8); S.cr(wk)

    DYN = {'flappy': (-1, -1), 'glint': (-2, -2), 'mirror': (0, 0), 'crash': (-2, 0), 'reflex': (-2, -1),
           'steal': (-1, 1), 'scatter': (1, 0), 'fury': (0, 2), 'onfoot': (-1, 0)}
    return S.render(DYN)


# ═════════════════════════════════════════════════════════════════════════════
# EL FINAL (La mayor)
# ═════════════════════════════════════════════════════════════════════════════
A_SCALE = ('A5', 'B5', 'C#6', 'D6', 'E6', 'F#6', 'A6')                 # las siete notas: las que canta `storyClink`
TR = -3                                                               # el tema del mapa, de Do a La


def ending():
    S = Song('ending')

    # 1. seven — la llamada, en la caja de música; los fragmentos salen: arpegios que suben
    S.scene('seven')
    S.pad(0, 4, ['A3', 'C#4', 'E4'], 0.7); S.bass(0, 3.9, 'A2')
    for i, note in enumerate(('E5', 'A5', 'C#6', 'E6')): S.bell(i * 0.5, 1.5, note)
    S.pad(4, 2, ['D4', 'F#4', 'A4'], 0.8); S.bass(4, 1.9, 'D2')
    S.pad(6, 2, ['E4', 'G#4', 'B4'], 0.9); S.bass(6, 1.9, 'E2')
    o_ = S.cue('out')
    for i in range(int((8 - o_) * 4)):
        ch_ = ('A4', 'C#5', 'E5', 'A5') if o_ + i / 4 < 4 else (('D5', 'F#5', 'A5', 'D6') if o_ + i / 4 < 6 else ('E5', 'G#5', 'B5', 'E6'))
        S.n('arp', o_ + i / 4, 0.3, ch_[i % 4], I_ARP, vs=1.0 + 0.03 * i, rel=1)

    # 2. pieces — siete notas que SUBEN, una por fragmento, cada una con su acorde; entre ellas, el pulso espera
    S.scene('pieces')
    f_, e_ = S.cue('first'), S.cue('each')
    chords = (('A2', ('A3', 'C#4', 'E4')), ('E2', ('G#3', 'B3', 'E4')), ('A2', ('A3', 'C#4', 'E4')), ('D2', ('A3', 'D4', 'F#4')),
              ('A2', ('C#4', 'E4', 'A4')), ('D2', ('D4', 'F#4', 'A4')), ('E2', ('E4', 'A4', 'B4')))      # el último: suspendido
    for i, note in enumerate(A_SCALE):
        b_ = f_ + i * e_
        S.bell(b_, 2, note, 1.0, ch='bell' if i % 2 == 0 else 'bell2')
        S.n('soft', b_, 1.8, nn(note) - 12, I_SOFT, q=q_n163, vs=0.8 + 0.05 * i)
        r, ch_ = chords[i]
        S.pad(b_, 2, ch_, 0.7 + 0.08 * i)
        S.bass(b_, 1.8, r)
        if i >= 2: S.k(b_, 0.5 + 0.08 * i)
        if i >= 4: S.tm(b_ - 0.5, 1, 0.5); S.tm(b_ - 0.25, 0, 0.5)
        for j in range(3):                                             # camino del marco: tres notas que suben hacia ella
            S.n('arp', b_ - 0.75 + j * 0.25, 0.22, nn(note) - (3 - j) * 2, I_ARP, vs=0.9, rel=0)
    S.roll(14.5, 16, 0.125, 0.2, 1.1); S.riser(14, 16)

    # 3. whole — el acorde entero y la llamada, deprisa, en lo alto
    S.scene('whole')
    S.k(0, 1.2, True); S.tm(0, 2, 1.1); S.cr(0)
    S.pad(0, 4, ['A3', 'C#4', 'E4'], 1.4); S.bass(0, 3.9, 'A1'); S.stab(0, 2, 'A2', 1.2)
    for i, note in enumerate(('E5', 'A5', 'C#6', 'E6')):
        S.lead(i * 0.25, 0.25 if i < 3 else 2.5, note); S.bell(i * 0.25, 2, nn(note) + 12, 0.9)
    S.tm(2, 1, 0.8); S.tm(3, 2, 0.8)

    # 4. return — el tema del Reflejo se deshace hacia abajo; entra en el cristal; el aleteo, libre: dos notas
    S.scene('return')
    pl, ins, orb = S.cue('pull'), S.cue('inside'), S.cue('orb')
    S.pad(0, ins, ['F#3', 'A3', 'C#4'], 0.9)
    for i in range(int(ins)):
        S.bass(i, 0.6, 'F#1'); S.bass(i + 0.667, 0.3, 'F#1'); S.k(i, 0.7); S.h(i + 0.667, [3, 1])
    line = ('F#5', 'C#5', 'F#5', 'A5', 'G#5', 'F#5', 'E5', 'D5', 'C#5', 'B4', 'A4', 'G#4')         # su tema... cayéndose
    for i, note in enumerate(line):
        S.saw(pl + i * (ins - pl) / len(line), (ins - pl) / len(line), note, 1.0 - 0.05 * i, leg=0.8)
    S.k(ins, 1.1, True); S.cr(ins); S.tm(ins, 2, 1.0)
    S.pad(ins, 8 - ins, ['E3', 'G#3', 'B3'], 0.8); S.bass(ins, 8 - ins - 0.1, 'E2')
    S.bell(orb, 1.5, 'E6'); S.bell(orb + 0.5, 2, 'A6', 0.9, ch='bell2')

    # 5. light — el tema del mapa, a pleno, en La mayor (compases 5-7: la llamada que llega más alto)
    S.scene('light')
    S.map_tune([5, 6, 7], tr=TR, bells=True, drums='full', vs=1.0)
    S.pad(0, 12, ['A3', 'C#4', 'E4'], 0.8)

    # 6. shrink — juguetón: el tema sigue (compases 9-11) y cada jefe que encoge contesta con un "pop" que baja
    S.scene('shrink')
    S.map_tune([9, 10, 11], tr=TR, drums='light', vs=0.9)
    e_ = S.cue('each')
    for i in range(6):
        b_ = S.cue('first') + i * e_ + 0.5
        for j in range(4):
            S.n('arp', b_ + j * 0.09, 0.09, nn('A6') + i - j * 3, I_ARP, vs=1.3, rel=0)
        S.tm(b_ + 0.36, 0, 0.6)
    S.pad(12, 2, ['E3', 'G#3', 'D4'], 0.9); S.bass(12, 1.9, 'E2'); S.lead(12, 1.8, 'B5', 0.9)

    # 7. flap — silencio; el aleteo vuelve; con cada aleteo, una nota más de la llamada; y sube
    S.scene('flap')
    ob, t1, t2, rs = S.cue('orb'), S.cue('try1'), S.cue('try2'), S.cue('rise')
    S.pad(0, 8, ['A3', 'E4', 'A4'], 0.5)
    for i in range(8): S.n('arp', ob + i * 0.125, 0.14, nn('A5') + (0, 4, 7, 12, 16, 19, 24, 28)[i], I_ARP, vs=0.9, rel=1)
    S.bell(2, 2, 'A6'); S.bell(2, 2, 'E6', 0.8, ch='bell2')
    S.bell(t1, 1.5, 'E5'); S.n('soft', t1, 1.2, 'E5', I_SOFT, q=q_n163)
    S.bell(t2, 1, 'E5'); S.bell(t2 + 0.45, 1.5, 'A5', ch='bell2'); S.n('soft', t2, 1.6, 'A5', I_SOFT, q=q_n163)
    S.pad(rs, 4, ['E3', 'G#3', 'B3'], 1.0); S.bass(rs, 3.9, 'E2')
    climb = ('E5', 'A5', 'C#6', 'E6', 'A5', 'C#6', 'E6', 'A6', 'C#6', 'E6')                 # la llamada, y sigue subiendo
    for i, note in enumerate(climb):
        S.lead(rs + i * 0.4, 0.38, note, 0.9 + 0.02 * i); S.bell(rs + i * 0.4, 1, nn(note) + 12, 0.7, ch='bell' if i % 2 == 0 else 'bell2')
    S.roll(rs + 2, 12, 0.125, 0.2, 1.1); S.riser(rs + 2, 12)
    for i in range(4): S.k(rs + i, 0.6 + 0.1 * i)

    # 8. home — el tema, entero, volando a casa (compases 5-7); con el logo, el acorde final y la llamada en campanas
    S.scene('home')
    S.map_tune([5, 6, 7], tr=TR, bells=True, drums='full')
    lg = S.cue('logo')
    S.k(lg, 1.2, True); S.tm(lg, 2, 1.1); S.cr(lg)
    S.pad(lg, 7, ['A3', 'C#4', 'E4'], 1.3); S.bass(lg, 6.5, 'A1'); S.stab(lg, 3, 'A2', 1.2)
    S.lead(lg, 5, 'A5')
    for i, note in enumerate(('E5', 'A5', 'C#6', 'E6')): S.bell(lg + 0.5 + i * 0.5, 2.5, nn(note) + 12, 1.0, ch='bell' if i % 2 == 0 else 'bell2')
    S.tm(lg + 3, 1, 0.8); S.tm(lg + 3.5, 2, 0.9); S.k(lg + 4, 1.1, True); S.cr(lg + 4)
    S.n('thin', lg + 4, 2.5, 'A6', I_THIN)

    DYN = {'seven': (0, 0), 'pieces': (-1, 0), 'whole': (0, -1), 'return': (-1, -2), 'light': (0, 1),
           'shrink': (-1, -1), 'flap': (-1, 0), 'home': (1, 1)}
    return S.render(DYN)


if __name__ == '__main__':
    which = [a for a in sys.argv[1:] if a in ('intro', 'ending')] or ['intro', 'ending']
    for film in which:
        y = intro() if film == 'intro' else ending()
        if not os.environ.get('REPORT'):
            GN.export('story_' + film, y)
