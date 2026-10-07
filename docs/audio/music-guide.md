# Music guide: the house style and how to compose for the game

The BASE for composing or changing any track. Numbers come from `tools/music/study.py` (the .mid files in
`tools/music/mid/`) and from measuring the .ogg files with librosa (tempo, centroid, attacks per second, dynamics,
percussive share). **None of this was listened to: it is measurement.** The ear of the game's author overrides any
number here. What exists today: [reference/music](../reference/music.md); how each track got to its current form and
the user's verdicts: [music-history](music-history.md); the catalog, mixing and loudness rules:
[music-catalog](music-catalog.md).

## 1. What makes it sound like Flappy Monster

**Sound.** Everything is Famicom "with expansion chips" (`tools/music/famicom.py`): 2A03 (two pulses, triangle,
noise, DPCM) + VRC6 (two pulses and a saw) + Namco 163 (wavetables). No real samples and no studio reverb: echo is a
delay, drums are 1-bit DPCM and noise.

**The cast of roles, the same in every track:**
- MELODY: an N163 wavetable or a pulse with a duty sweep (12.5 → 50 %) and vibrato on long notes; for strength it is
  doubled by the VRC6 saw or a pulse an octave up (never by another melody).
- BASS: triangle; in lively tracks, 8ths with octaves; in calm ones, half notes or a drone.
- ACCOMPANIMENT: short offbeat chords ("skank"), 16th arpeggios, or an N163 pad.
- DRUMS: DPCM kick, snare = short noise + DPCM body, noise cymbals; noise in short mode = "metal".
- COLOUR per place: music box (N163 with bell partials), sleigh bells (short noise), drips (pulse with a pitch drop),
  steel drum (bright N163), "legs" (very short 12.5 % pulse).

**Rhythm.** The most characteristic part: almost everything runs in continuous 16ths and **56 to 76 % of the melody
notes fall off the strong beat**. Two trademarks: the **3+3+2 tresillo** (Crab Tantrum) and offbeat chords. High
tempos: levels ~138, menus 140, bosses 148-186; only the map (120) and the caves go lower.

**Melody.** Cells shared by several tracks (measured):
- the **pentatonic climb** 2-2-3 semitones and its neighbours 2-3-2;
- the **chord arpeggio** climbing 4-3-5 / 5-4-3 in 16ths;
- **bouncing leaps** of a 6th-7th up and down (+9 −9 +9, +10 −10 +10) in level / boss tracks;
- the **neighbour note** and the **chromatic descent** of the menus' blues turn.
8-bar phrases; question and answer; the answer is usually the question in sequence (a step or a third higher or lower).

**Harmony.** Minor for danger, major for a safe place (C major map and menus, F major snow). Short diatonic
progressions (i–VI–iv–V, I–V–vi–V, IV–IV–V–V before a chorus), with ONE dark turn per piece (the Neapolitan ♭II in
the cave, the blue note ♭5 in the legs). Power chords only when the fifth is in the harmony.

**Form.** Short intro (4 bars) → A (8) → A' → a contrasting B → return; seamless loop. Long pieces grow by
**density** (more layers, cymbals, octaves), not by volume. A silence or an empty half bar before a strong entry. A
long boss loop needs its own way back: never cut from the peak to the opening.

## 2. The game's motif: "la llamada" (the call)

The map tune ("Rumbo a las islas") begins by climbing the chord: **G–C–E–G** (5th–1st–3rd–5th) and settles. It is the
one original thing the player hears throughout the game (between levels), so it is the **leitmotif of the game**:
every world's music quotes it once (opening the theme or closing phrase B), in its key and with its instrument. That
way the map and the levels are the same music. The Mirror boss's motif is la llamada with its intervals INVERTED.

## 3. Identity per island

| Island | Key / mode | Tempo | Melody | Rhythm and drums | Own motif |
|---|---|---|---|---|---|
| Meadow (pradera) | G or C major | 132-140 | singing pulse | hopping bass (1-5-8-5), offbeat chords, light drums | bird trill |
| Coast (costa) | F major (mixolydian at times) | 116-126 | steel drum | calypso bass (1, 1-and, 3), 16th shaker | rising marimba |
| Fortress (fortaleza) | C minor | 138-148 | saw + pulse | march: snare rolls, octave bass, "metal" | triplet fanfare |
| Summits (nieve) | F major / D minor | 144-160 | music box an octave up | sleigh bells, half-note bass, pad | falling bells |
| Caves (cuevas) | D dorian | 96-110 (72 in the dark) | music box with echo | half time, deep kick, no cymbals | drips |
| Volcano (final) | E or A phrygian (♭II) | 156-172 | brass / saw + octave pulse | 8th bass, double kick, 3+3+2 | plucked flourish |

### Which track is which slot
- `<world>_1` = the world's THEME: the most melodic, for its first levels (story order: odd levels).
- `<world>_2` = its second face (even levels): it changes KEY, RHYTHM and TIMBRE and has its OWN melody — never just
  the mode or a transposition of `_1`.
- `<world>_bonus` = `_1` faster (~+12 %) with "competition" drums and an 8-bar percussion solo — it plays in every
  King of the Hill arena of that island.
- Bosses: one theme each. `victory`: a fanfare with the whole llamada + a light loop for the results screen.
- Dark levels: `cuevas_oscuras`.

## 4. Composition rules (so everything belongs to the same game)

1. One idea per piece: a 2-bar motif that repeats in sequence and returns. No more than two themes.
2. A singable melody: mostly stepwise plus the house cells; long notes are always chord tones; ornaments stay in the
   scale (both are asserted by a check in the generators).
3. More than half of the notes off the beat; at least one bar with the 3+3+2 tresillo.
4. Quote "la llamada" once, unforced: in a place with ITS chord (never graft a motif onto another harmony).
5. One dark turn per piece. Never transpose a known melody "to darken it". No bright major section inside an
   aggressive minor arrangement; no leading tone mixed with ♭VII.
6. Grow by layers; a breath before each strong entry; seamless loop.
7. Instruments: those of the island's row; the rest of the cast as always (triangle, DPCM, noise).
8. An island never reuses another island's rhythmic mould: measure where the attacks of phrase A fall against the
   other themes.
9. The ACCENT of each theme (the figure that sounds where the melody rests) is its own and is MELODIC: its
   instrument, its rhythm, chord tones only, never louder than a backing layer; never the meadow trill adapted,
   never noise only.
10. Samples of other people's songs: few, where their harmony is, with own melody around them built from the same
    vocabulary. The scale that worked for this user: inverted / half-speed = not recognisable; a whole phrase literal
    = copy-paste; RIGHT = the motif's rhythm and head contour (or one literal bar) leading into own material. When
    the user names a motif as "the reference", quote it somewhere.
11. For a boss, judge tempo by where the SNARE falls, not by the BPM number. Sections of an aggressive theme differ
    by intensity and register, not by groove or by turning lyrical.
12. Check with numbers before calling it done: length and loop, LUFS, energy split (lead ≤ ~17 %), unmasked melody,
    and that the .mid shows the intended key and tempo (`study.py`). Then run `tools/music/levels.py`.

## 5. Intro and loop (user's rule)

A track with an intro is TWO files: `<track>_intro.ogg` (plays once on entering) and `<track>_loop.ogg` (repeats
without going back to the intro); in `index.json`, `"intro"` + `"loop"`. The tail of the song is folded onto the
start OF THE LOOP (`GN.fold(y, n, at)`), not onto the intro, and `GN.export(name, y, intro)` makes the cut. When the
intro ends differently from the loop's end, give both the same last bar and skip the fold.

## 6. Tools

- `tools/music/famicom.py`: the engine (channels, per-frame instruments, DAC, `master`, `out`, `ref`).
- `tools/music/worlds_nes.py`: the island sets and several bosses — the best starting point for a new piece (melody
  as text phrases, chords per bar, one arrangement per island, mix by groups). `--capas` writes any track as stems.
- `tools/music/study.py`: key, range, intervals, syncopation and cells of any .mid.
- `tools/music/levels.py`: measures every track and writes its catalog `volume` (run it after any change).
- `~/.venvs/fm-music` (librosa, pyloudnorm, mido, demucs, basic-pitch) to measure audio.
- Limit: there is no ear. A new piece should come with 2-3 short variants for the author to choose from, and the
  hand-off must always say it was verified by numbers only.

## 7. The spider effect ("legs" of the Gloomy themes)

From the user's brief (Toby Fox's "Spider Dance" as the reference for the effect, not the notes); implemented as
`GN.LEG8 / LEG6 / I_LEG` in `tools/music/gloomy_nes.py` and used by `crab_tantrum.py gloomy`:

- A 12.5 % pulse with a very short envelope playing constant 16ths in groups of 8, on the chord's minor pentatonic
  plus the blue note (♭5 passing to the 5th). It never stops: foreground when the melody rests, background (×0.4)
  under it.
- A PAUSE at the end of every 8-bar phrase: a chromatic run down, then silence except the melody; a crash on
  re-entry (the "drop").
- A second, DESYNCED pattern of 6 notes against the 8, from the chorus on; register jumps every 4 bars.
- Dry drums and few layers around it: the legs are the texture.
