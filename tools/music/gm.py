# tools/music/gm.py — instrumentos GM de un soundfont (por defecto GeneralUser GS) tocados con fluidsynth, con las notas
# en SEGUNDOS, para mezclarlos con los canales de Famicom como un stem más (como slap.py, pero con cualquier programa y
# con la batería GM en el canal 10). Sin reverb ni chorus del sintetizador (la casa no usa reverb de estudio).
#
#   r = gm.Rec(108)                       # Kalimba (programa GM, 0-127)  ·  gm.Rec(drums=True): batería (kit 0)
#   r.add(t0, t1, nota[, velocidad])
#   stem = r.render(muestras)             # mono, 44,1 kHz
#
# GeneralUser GS v2 (S. Christian Collins): uso libre para crear música, también comercial. No va en el repo: se baja
# a ~/.local/share/soundfonts/ (o FM_SF_GU apunta a él).
import os, subprocess, tempfile
import numpy as np

from famicom import SR

SF_GU = os.environ.get('FM_SF_GU', os.path.expanduser('~/.local/share/soundfonts/GeneralUser-GS.sf2'))
TPS = 960                                                     # (ticks por segundo: a 120 BPM, 480 por negra)


class Rec:
    def __init__(self, program=0, drums=False, sf=SF_GU):
        self.program, self.drums, self.sf, self.ev = program, drums, sf, []

    def add(self, t0, t1, note, vel=100):
        self.ev.append((t0, t1, int(note), int(max(1, min(127, vel)))))

    def render(self, n):
        out = np.zeros(n)
        if not self.ev:
            return out
        import mido, soundfile as sf
        ch = 9 if self.drums else 0
        m = mido.MidiFile(type=0, ticks_per_beat=480); tr = mido.MidiTrack(); m.tracks.append(tr)
        tr.append(mido.MetaMessage('set_tempo', tempo=500000))
        if not self.drums:
            tr.append(mido.Message('program_change', channel=ch, program=self.program))
        ev = []
        for t0, t1, note, vel in self.ev:
            a, b = int(round(t0 * TPS)), int(round(t1 * TPS))
            ev += [(max(a + 1, b), 0, note, 0), (a, 1, note, vel)]
        t = 0
        for tt, on, note, vel in sorted(ev):
            tr.append(mido.Message('note_on' if on else 'note_off', channel=ch, note=note, velocity=vel, time=tt - t)); t = tt
        with tempfile.TemporaryDirectory() as d:
            mp, wp = os.path.join(d, 'g.mid'), os.path.join(d, 'g.wav')
            m.save(mp)
            subprocess.run(['fluidsynth', '-ni', '-R', '0', '-C', '0', '-g', '1.0', '-r', str(SR), '-F', wp, self.sf, mp],
                           capture_output=True)
            y, _ = sf.read(wp)
        y = y.mean(1) if y.ndim == 2 else y
        out[:min(n, len(y))] = y[:n]
        return out - np.mean(out)


_CACHE = {}


def cached(rec, n):
    """render() con memoria: las capas que no cambian entre versiones (batería, bajo…) se tocan una sola vez"""
    key = (type(rec).__name__, getattr(rec, 'program', None), getattr(rec, 'drums', None), tuple(sorted(rec.ev)), n)
    if key not in _CACHE:
        _CACHE[key] = rec.render(n)
    return _CACHE[key]
