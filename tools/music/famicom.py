# tools/music/famicom.py
# Motor de sonido de Famicom compartido por los generadores de música
# (tentacle_nes.py, boss_nes.py): NES 2A03 + chips de expansión VRC6 y Namco
# 163, con un "driver" a 60 Hz como el de un juego real:
#   · Chan(nf): registros por frame (frecuencia, volumen 0-15, duty/onda) de un
#     canal; play() escribe una nota con su instrumento (envolvente de volumen,
#     duty, vibrato, arpegio) frame a frame.
#   · render_pulse / render_tri / render_saw / render_wave / render_noise: la
#     salida de cada canal a 44.1 kHz (periodos cuantizados como el chip,
#     triángulo de 32 pasos, sierra del VRC6 de 7 pasos, tablas de 4 bits del
#     N163, LFSR de 15 bits del ruido); dpcm(): muestras de 1 bit.
#   · pulse_dac / tnd_dac: las curvas no lineales del mezclador del 2A03.
import numpy as np

SR = 44100
FPS = 60.0988                      # frames del driver (NTSC)
CPU = 1789773.0
FRAME_S = SR / FPS


def frames_for(seconds):
    """Frames de una canción de `seconds` s (con 2 s de margen para colas)"""
    return int(seconds * FPS) + int(FPS * 2)


def t_(n):
    return np.arange(n) / SR


class Chan:
    """Registros por frame: frecuencia (Hz), volumen (0-15), duty (o nº de onda)"""
    def __init__(self, nf):
        self.f = np.zeros(nf)
        self.v = np.zeros(nf)
        self.d = np.full(nf, 0.5)


def fr(t):
    return int(round(t * FPS))


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def q_pulse(f):                      # frecuencia real del pulso (periodo de 11 bits)
    t = np.clip(np.round(CPU / (16 * f) - 1), 8, 2047)
    return CPU / (16 * (t + 1))


def q_tri(f):
    t = np.clip(np.round(CPU / (32 * f) - 1), 2, 2047)
    return CPU / (32 * (t + 1))


def q_vrc6(f):                       # (12 bits)
    t = np.clip(np.round(CPU / (16 * f) - 1), 8, 4095)
    return CPU / (16 * (t + 1))


def q_saw(f):
    t = np.clip(np.round(CPU / (14 * f) - 1), 8, 4095)
    return CPU / (14 * (t + 1))


def play(chn, t0, t1, m, inst, q=q_pulse, vs=1.0, arp=None, release=3):
    """Una nota con su instrumento: envolvente de volumen, duty, vibrato y
    arpegio frame a frame (como un driver de NES/FamiTracker)"""
    a, b = fr(t0), max(fr(t0) + 1, fr(t1))
    env = inst['vol']
    for k in range(a, min(len(chn.f), b + release)):
        i = k - a
        if k < b:
            vol = env[i] if i < len(env) else inst.get('sus', env[-1])
        else:                                                     # soltar
            vol = (env[min(i, len(env) - 1)] if i < len(env) else inst.get('sus', env[-1])) * (1 - (k - b + 1) / (release + 1))
        semi = 0.0
        vd, vdep, vrate = inst.get('vib', (0, 0, 0))
        if vdep and i >= vd:
            semi += vdep * np.sin(2 * np.pi * vrate * (i - vd) / FPS)
        if arp:
            semi += arp[(i // inst.get('arp_speed', 1)) % len(arp)]
        if inst.get('drop') and i < len(inst['drop']):
            semi += inst['drop'][i]
        chn.f[k] = q(hz(m + semi))
        chn.v[k] = min(15, round(vol * vs)) if k < b else round(vol * vs)
        dseq = inst.get('duty', 0.5)
        chn.d[k] = dseq[min(i, len(dseq) - 1)] if isinstance(dseq, (list, tuple)) else dseq


def polyblep(t, dt):
    y = np.zeros_like(t)
    m = t < dt
    x = t[m] / dt[m]
    y[m] = x + x - x * x - 1
    m2 = t > 1 - dt
    x = (t[m2] - 1) / dt[m2]
    y[m2] = x * x + x + x + 1
    return y


def per_sample(arr):
    nf = len(arr)
    idx = (np.arange(int(nf * FRAME_S)) / FRAME_S).astype(int)
    return arr[np.minimum(idx, nf - 1)]


def render_pulse(chn):
    f, v, d = per_sample(chn.f), per_sample(chn.v), per_sample(chn.d)
    dt = f / SR
    ph = np.cumsum(dt) % 1.0
    sq = np.where(ph < d, 1.0, -1.0)
    sq += polyblep(ph, np.maximum(dt, 1e-9))
    sq -= polyblep((ph - d) % 1.0, np.maximum(dt, 1e-9))
    return (sq * 0.5 + 0.5) * v                                  # 0..15 (como el DAC)


TRI32 = np.concatenate([np.arange(15, -1, -1), np.arange(0, 16)]).astype(float)


def render_tri(chn):
    f, on = per_sample(chn.f), per_sample(chn.v) > 0
    dt = np.where(on, f / SR, 0.0)                               # parado: se queda en su paso
    ph = np.cumsum(dt) % 1.0
    return TRI32[(ph * 32).astype(int) % 32]


def render_saw(chn):
    """Sierra del VRC6: 7 pasos de un acumulador (se oye escalonada)"""
    f, v = per_sample(chn.f), per_sample(chn.v)
    dt = f / SR
    ph = np.cumsum(dt) % 1.0
    step = np.floor(ph * 7) / 6.0
    s = step - polyblep(ph, np.maximum(dt, 1e-9)) * 0.5
    return s * v * 2.0                                           # 0..~31


NOISE_PER = [4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068]


def lfsr(short):
    reg, out = 1, []
    n = 93 if short else 32767
    for _ in range(n):
        tap = 6 if short else 1
        fb = (reg & 1) ^ ((reg >> tap) & 1)
        reg = (reg >> 1) | (fb << 14)
        out.append(reg & 1)
    return np.array(out, float)


LFSR_LONG, LFSR_SHORT = lfsr(False), lfsr(True)


def render_noise(per, vol, short):
    p, v, s = per_sample(per), per_sample(vol), per_sample(short)
    rate = CPU / np.array(NOISE_PER)[p.astype(int)] / SR
    pos = np.cumsum(rate)
    a = LFSR_LONG[pos.astype(np.int64) % len(LFSR_LONG)]
    b = LFSR_SHORT[pos.astype(np.int64) % len(LFSR_SHORT)]
    return np.where(s > 0, b, a) * v


def dpcm(x, rate=33144.0):
    """Codifica en DPCM de 1 bit (±2 sobre 7 bits) y decodifica: el sonido real
    de las muestras del NES"""
    n = int(len(x) * rate / SR)
    src = np.interp(np.arange(n) * SR / rate, np.arange(len(x)), x)
    lvl, out = 64, np.zeros(n)
    tgt = 64 + src * 60
    for i in range(n):
        if tgt[i] > lvl and lvl <= 125: lvl += 2
        elif tgt[i] < lvl and lvl >= 2: lvl -= 2
        out[i] = lvl
    idx = (np.arange(int(n * SR / rate)) * rate / SR).astype(int)
    return out[np.minimum(idx, n - 1)] - 64


def wavetable(harm, seed=3):
    """Tabla del Namco 163 (32 muestras de 4 bits) con esos armónicos"""
    t = np.arange(32) / 32
    ph = np.random.default_rng(seed).uniform(0, 2 * np.pi, len(harm))
    ph[0] = 0
    w = sum(a * np.sin(2 * np.pi * (k + 1) * t + ph[k]) for k, a in enumerate(harm))
    w = (w - w.min()) / (w.max() - w.min() + 1e-9)
    return np.round(w * 15)                                     # 0..15 (4 bits)


def render_wave(chn, waves):
    """Canal del N163: lee su tabla (chn.d = índice de la onda en `waves`)"""
    f, v, d = per_sample(chn.f), per_sample(chn.v), per_sample(chn.d)
    ph = np.cumsum(f / SR) % 1.0
    tab = np.array(waves)[d.astype(int), (ph * 32).astype(int) % 32]
    return (tab - 7.5) / 7.5 * v                                  # ±15


def q_n163(f):
    return f                                                     # (el N163 afina muy fino: 18 bits)


class Noise:
    """Canal de ruido: periodo, volumen y modo (corto = metálico) por frame"""
    def __init__(self, nf):
        self.per, self.vol, self.short = np.zeros(nf), np.zeros(nf), np.zeros(nf)

    def hit(self, t, per, vols, short=0):
        a = fr(t)
        for i, v in enumerate(vols):
            if a + i < len(self.per):
                self.per[a + i] = per if not isinstance(per, list) else per[min(i, len(per) - 1)]
                self.vol[a + i], self.short[a + i] = v, short

    def render(self):
        return render_noise(self.per, self.vol, self.short)


def pulse_dac(p):
    return np.where(p > 0, 95.88 / (8128.0 / np.maximum(p, 1e-6) + 100), 0.0)


def tnd_dac(x):
    return np.where(x > 0, 159.79 / (1.0 / np.maximum(x, 1e-9) + 100), 0.0)


OCT = [(40, 63), (63, 125), (125, 250), (250, 500), (500, 1000), (1000, 2000), (2000, 4000), (4000, 8000), (8000, 16000)]


def band_power(x, a, b):
    """Potencia por bandas de octava entre a y b segundos"""
    from scipy.signal import welch
    seg = x[int(a * SR):int(b * SR)]
    f, P = welch(seg, fs=SR, nperseg=8192)
    return np.array([P[(f >= lo) & (f < hi)].sum() for lo, hi in OCT])


def write_wav(path, x):
    import wave
    with wave.open(path, 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype('<i2').tobytes())


def loudness(y):
    """Sonoridad integrada (LUFS, ITU-R BS.1770) de una señal mono o estéreo"""
    import pyloudnorm as pyln
    return pyln.Meter(SR).integrated_loudness(y)


def master(y, lufs=-10.5, ceiling=0.8, knee=0.55):
    """Masterizado: sube hasta `lufs` con un limitador suave (por encima de
    `knee` comprime con tanh) y deja el pico en `ceiling` (0.8: el OGG sube
    los picos hasta ~20 %; con 0.89-0.95 pasaban de 1.0). (Antes cada
    generador hacía tanh(x·1.4)/1.4, que nunca pasaba de 0.714 de pico:
    ~3 dB desperdiciados y la música se oía floja en el juego.)"""
    def limit(z):
        a = np.abs(z)
        over = a > knee
        out = z.copy()
        out[over] = np.sign(z[over]) * (knee + (1 - knee) * np.tanh((a[over] - knee) / (1 - knee)))
        return out
    g = 1.0
    for _ in range(8):
        z = limit(y * g)
        z = z * (ceiling / (np.abs(z).max() + 1e-9))
        err = lufs - loudness(z)
        if abs(err) < 0.1:
            break
        g *= 10 ** (err / 20)
    return z


def biquad(x, kind, f0, gain_db, q=0.9):
    """EQ de mezcla (RBJ): 'peak' (campana) o 'high' (estantería de agudos)"""
    from scipy.signal import lfilter
    A = 10 ** (gain_db / 40); w = 2 * np.pi * f0 / SR; cw, sw = np.cos(w), np.sin(w)
    if kind == 'peak':
        al = sw / (2 * q)
        b = [1 + al * A, -2 * cw, 1 - al * A]; a = [1 + al / A, -2 * cw, 1 - al / A]
    else:
        al = sw / 2 * np.sqrt(2); sA = 2 * np.sqrt(A) * al
        b = [A * ((A + 1) + (A - 1) * cw + sA), -2 * A * ((A - 1) + (A + 1) * cw), A * ((A + 1) + (A - 1) * cw - sA)]
        a = [(A + 1) - (A - 1) * cw + sA, 2 * ((A - 1) - (A + 1) * cw), (A + 1) - (A - 1) * cw - sA]
    return lfilter(np.array(b) / a[0], np.array(a) / a[0], x, axis=0)



# ── Dónde va cada pista (assets/music/ está ordenada por carpetas; ver su index.json) ─────────────
# nombre con el que la conoce su generador → ruta (sin extensión) desde assets/music/. Los .mid no se
# envían a los jugadores: van a tools/music/mid/. Las grabaciones de referencia (las pistas prestadas
# que hubo de relleno) están FUERA del repo: FlappyMonster_originals/music/placeholders/ (o $FM_ORIGINALS).
import os as _os
MUSIC_DIR = _os.path.join(_os.path.dirname(_os.path.abspath(__file__)), '..', '..', 'assets', 'music')
MID_DIR = _os.path.join(_os.path.dirname(_os.path.abspath(__file__)), 'mid')
REF_DIR = _os.path.join(_os.environ.get('FM_ORIGINALS', '/home/mtvemo/FlappyMonster_originals'), 'music', 'placeholders')
PATHS = {
    # (level_nes = arreglo de una canción ajena: retirado del juego; si se regenera, va FUERA del repo)
    'level_nes': '../../../FlappyMonster_originals/music/placeholders/fortaleza_1_level_nes',
    'fortaleza_1': 'worlds/fortaleza/fortaleza_1', 'fortaleza_2': 'worlds/fortaleza/fortaleza_2', 'fortaleza_bonus': 'worlds/fortaleza/fortaleza_bonus',
    'dark_cave': 'worlds/cuevas/cuevas_oscuras',
    'boss_nes_intro': 'bosses/boss_generic_intro', 'boss_nes_loop': 'bosses/boss_generic_loop',
    'tentacle_nes': 'bosses/crab_tantrum_normal', 'tentacle_winter': 'bosses/crab_tantrum_icy',
    'tentacle_gloomy': 'bosses/crab_tantrum_gloomy', 'winter_nes': 'bosses/snowball_boss',
    'tentacle_chip': 'bosses/mirror_boss', 'tentacle_chip_instrumental': 'bosses/mirror_boss_inst',
    'pradera_1': 'worlds/pradera/pradera_1', 'pradera_2': 'worlds/pradera/pradera_2', 'pradera_bonus': 'worlds/pradera/pradera_bonus',
    'costa_1': 'worlds/costa/costa_1', 'costa_2': 'worlds/costa/costa_2', 'costa_bonus': 'worlds/costa/costa_bonus',
    'menus_chip': 'menus/menus_chip', 'menus': 'menus/menus',
    'map_pradera': 'map/map_pradera', 'map_costa': 'map/map_costa', 'map_fortaleza': 'map/map_fortaleza',
    'map_nieve': 'map/map_nieve', 'map_cuevas': 'map/map_cuevas', 'map_final': 'map/map_final',
}


def out(name, ext):
    """Ruta de salida de la pista `name` (.ogg / .wav en su carpeta de assets/music; .mid en tools/music/mid)"""
    rel = PATHS.get(name, name)
    if ext == 'mid':
        path = _os.path.join(MID_DIR, _os.path.basename(rel) + '.mid')
    else:
        path = _os.path.join(MUSIC_DIR, rel + '.' + ext)
    _os.makedirs(_os.path.dirname(path), exist_ok=True)
    return path


def ref(filename):
    """Una grabación de referencia archivada fuera del repo (TentacleTantrum.ogg, winter.ogg, level.ogg...)"""
    return _os.path.join(REF_DIR, filename)
