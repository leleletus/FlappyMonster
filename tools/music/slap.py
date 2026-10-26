# tools/music/slap.py — el BAJO de Resaca para cualquier pista: el Slap Bass GM (TimGM6mb, programa 36) que
# final_fall.render_bass toca con fluidsynth, pero con las notas en SEGUNDOS (sirve a cualquier tempo y a cualquier
# generador). El usuario (0.5.44): "ese bajo me encanta", en todos los temas de jefe en lugar de los de triángulo.
#
#   rec = slap.Rec()                      # en la función bass() del generador:
#   rec.add(t0, t1, nota[, velocidad])    #   (segundos de inicio y fin, nota MIDI)
#   S['bass'] = rec.render(muestras)      # el stem, mono, a 44,1 kHz, recortado / rellenado a `muestras`
import os, subprocess, tempfile
import numpy as np

from famicom import SR
from final_fall import SF_GM

TPS = 960                                                     # (ticks por segundo: a 120 BPM, 480 por negra)


class Rec:
    def __init__(self):
        self.ev = []

    def add(self, t0, t1, note, vel=100):
        self.ev.append((t0, t1, int(note), int(vel)))

    def render(self, n):
        import mido, soundfile as sf
        m = mido.MidiFile(type=0, ticks_per_beat=480); tr = mido.MidiTrack(); m.tracks.append(tr)
        tr.append(mido.MetaMessage('set_tempo', tempo=500000))
        tr.append(mido.Message('program_change', channel=0, program=36))
        ev = []
        for t0, t1, note, vel in self.ev:
            a, b = int(round(t0 * TPS)), int(round(t1 * TPS))
            ev += [(max(a + 1, b - 6), 0, note, 0), (a, 1, note, vel)]   # (suelta antes de que entre la siguiente)
        t = 0
        for tt, on, note, vel in sorted(ev):
            tr.append(mido.Message('note_on' if on else 'note_off', channel=0, note=note, velocity=vel, time=tt - t)); t = tt
        with tempfile.TemporaryDirectory() as d:
            mp, wp = os.path.join(d, 'b.mid'), os.path.join(d, 'b.wav')
            m.save(mp)
            subprocess.run(['fluidsynth', '-ni', '-R', '0', '-C', '0', '-g', '1.0', '-r', str(SR), '-F', wp, SF_GM, mp],
                           capture_output=True)
            y, _ = sf.read(wp)
        y = y.mean(1) if y.ndim == 2 else y
        out = np.zeros(n)
        out[:min(n, len(y))] = y[:n]
        return out - np.mean(out)
