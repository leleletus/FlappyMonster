# Music history: every track, version by version, with the user's verdicts

A chronological log. It exists because composing here is done blind (by measurement), so what the user accepted and
rejected — and why — is the most valuable knowledge for the next change. **It is history, not a description of the
current files**: several entries describe arrangements that were later replaced (the borrowed-tune arrangements
`tentacle_*`, `winter_nes`, `melody_nes`, `tentacle_chip`, `menus_chip` are retired and archived outside the repo).
Current state: [reference/music](../reference/music.md) and [music-catalog](music-catalog.md).

Status: **the soundtrack is complete (2026-10-03)**. No borrowed tune ships except the samples the user asked for
(Tentacle Tantrum cells in the Crab Tantrums, the Winter Fallympics motif and 1:48 phrase in the snow set, 8 bars of
the old level tune in the final boss, Verity's hook).

## The reorganisation of 3.48.0 and the island sets

- Renames (old → id/file now): classic / level_nes → `pradera_1`; dark_cave → `cuevas_oscuras`; boss / boss_nes →
  `boss_generic` (intro + loop); tentacle_nes → `crab_tantrum_normal`; tentacle_winter → `crab_tantrum_icy`;
  tentacle_gloomy → `crab_tantrum_gloomy`; winter_nes → `snowball_boss`; tentacle_chip(_instrumental) →
  `crab_tantrum_chip(_instrumental)` (extras); youWin → `victory`. Old ids still work: `"aliases"` in index.json →
  `Music.id(id)` (levels, zones, old rooms).

- PENDING SLOTS (`"pending": true`, file path already set, `fallback` id plays meanwhile via `Music.playable` in
  `Sound.resolve`; a listed file that doesn't exist also counts as pending): pradera_2, costa_1/2, fortaleza_1/2,
  nieve_1/2, cuevas_1, volcan_1/2 (fallback pradera_1; cuevas_1 → cuevas_oscuras) and `victory` (no fallback: silent).
  To fill a slot: drop the file at that path and remove `pending`/`fallback`.

- The BORROWED placeholder tracks the user removed (flying_machine, hidro_city, labyrinth intro/loop, boss_battle
  intro/loop, TentacleTantrum.ogg, winter.ogg, victory.ogg, and the old level.ogg) are archived OUTSIDE the repo:
  `FlappyMonster_originals/music/placeholders/` (generators read their references from there: `famicom.ref(name)`).

- User renames after the reorg: the level tune is `fortaleza_1` (never meant for the meadow; `pradera_1` is a pending slot, default fallback = fortaleza_1) and the chip tracks are `mirror_boss` / `mirror_boss_inst` (the Mirror fight).

- ISLAND LEVEL MUSIC = `tools/music/worlds_nes.py` (follows the guide: intro 4 · A · A' · B · A'', 3+3+2 kick, the
  game motif "la llamada" closing phrase B). MEADOW done (3.49.0, verified by numbers only): `pradera_1` (G major,
  136 BPM, pulse lead + echo, hopping bass, offbeat chords, bird trill; 3 variants for the user to pick: `previas` →
  `FlappyMonster_pruebas/musica/pradera_1_{A,B,C}.ogg`, A installed), `pradera_2` (v3 "Galope": C MAJOR, 144, galop rhythm
  dotted-8th + 16th in melody, bass and kick, flute lead — v1 was pradera_1 transposed to E minor (too similar,
  harmonic rubs), v2 its own E-minor tune (the user: melody and instrumentation didn't fit each other): a minor tune
  over the meadow's happy hopping arrangement doesn't work; the 'second face' changes KEY, RHYTHM and TIMBRE, not mode), `pradera_bonus` (152, four-on-the-floor + an 8-bar
  PERCUSSION SOLO before the last pass: snare/tom call and response, running toms, growing roll; isla_flotante). The
  user approved pradera_1 (variant A) and pradera_bonus. Other islands: add their melody + arrangement there.
  User's decisions: the island table of the guide is approved; arrangements of borrowed tunes stay FOR NOW but get
  replacements with a similar vibe that keep a motif or a recognizable element as a "sample", never a copy.

- FORTRESS (3.51.0, all new; verified by numbers only): the old `fortaleza_1` (level_nes, an arrangement of a
  BORROWED tune) was removed from the game → `FlappyMonster_originals/music/placeholders/fortaleza_1_level_nes.ogg`
  (`melody_nes.py`'s level output now goes there too). New set in `worlds_nes.py`: `fortaleza_1` "Marcha de hierro"
  (C minor, 140: VRC6 saw an octave down + pulse, march rhythm tan · ta-ta in melody, fifth stabs and snare, octave
  bass, metal noise offbeats, triplet FANFARE motif), `fortaleza_2` "Engranajes" (G minor, 126: thin staccato pulse,
  fifth/root tick-tock, locomotive bass, metallic 16th noise, anvil motif — factories, quarry, the train),
  `fortaleza_bonus` (the march at 156 + percussion solo; ciudadela_alterna). `boss_generic` still uses the borrowed
  tune (pending replacement, like the Crab Tantrums and snowball_boss).

- ISLAND BOSS THEMES (3.52.0, `worlds_nes.py`, `boss=True` = crash every 2 bars + snare fill every 4; intro + loop;
  verified by numbers only): `gummy_king_boss` "Su Majestad Gummy" (G major like the meadow, 152: dotted pompous
  fanfare, pulse + its octave, jelly bass hopping to the octave, timpani + the meadow trill; B in E minor;
  reino_gummy + jefe_gummy arena) and `evil_ship_boss` "Persecución" (C minor like the fortress, 160: the march as a
  chase — driving 8ths, saw, non-stop bass, 3+3+2 fifth stabs, metallic 16ths, ALARM motif; fortaleza_malvada).
  `boss_generic` (the borrowed tune) is OUT of the repo (`FlappyMonster_originals/music/placeholders/`); ids boss /
  boss_nes / boss_generic are aliases of `evil_ship_boss`, which is also `BossZones.DEFAULT_MUSIC`.

- SUMMITS (3.55.0, `worlds_nes.py`, all new, intro + loop; verified by numbers only): `nieve_1` "Cumbres de cristal"
  (F major, 148: the melody on the MUSIC BOX an octave up over a soft pulse, half-note bass, 8th "snowflake" chord
  notes, sleigh bells, brushed snare; island motif = falling bells), `nieve_2` "Ventisca" (D natural minor, 156: pulse
  lead with bell sparkles on long notes, 16th wind arpeggio, 8th bass, backbeat — fabrica_criogenica, torre_viento),
  `nieve_bonus` (nieve_1 at 166 + percussion solo; lago_de_cristal), and the new `snowball_boss` "La Gran Bola" (F
  minor, 168, `boss=True`: hopping mocking tune, bass ROLLING in 16ths, rolling toms, sleigh bells, bell doubling). The
  Winter Fallympics CHRISTMAS MOTIF is a sample used SPARINGLY (user: "without abusing"): once per loop, the first 4
  bars of phrase B over its own harmony — nieve_1/bonus in F (IV IV V V) and the boss a minor third up (♭VI ♭VI ♭VII
  ♭VII of F minor); nieve_2 has none (`wmotif(up)`, `MOTIF_THEMES`). The old `snowball_boss` (the Winter Fallympics
  arrangement, winter_nes.py) is outside the repo (`placeholders/snowball_boss_winter_nes.ogg`). Only the two
  `mirror_boss` tracks still carry a borrowed tune.

- SUMMITS v2 (3.56.0): the user found nieve_1/2 (hence the bonus and the boss) "very much like pradera_1/2" — v1 reused
  the meadow's rhythmic mould (dotted 3+3+2 hits, the same B phrase shape) — and asked for a SECOND Winter Fallympics
  sample: the phrase of 1:48-2:08 (Smooth Synth, bars 85-92; `W148` + `W148_END`), the "calm part that loses no energy"
  and BRIDGE to the final chorus. Melodies rewritten with the samples' own vocabulary (three rising 8ths + an offbeat
  quarter, 2-2-2-4 · 2-2-4→; quarter-note leaps like the motif) so own tune and samples are one family; phrases as
  text (`P` / `PH`: "0:Bb4/2 2:C5/2"). Form of nieve_1 and the boss: intro · A · A' · B (bridge = the 1:48 sample:
  its bars 1-4 and its repeated-note build 7-8, two own bars between) · C (chorus = the Christmas motif + answer + la
  llamada; `song()` optional `pc, cc`, tag 'C') · A''. nieve_2: no chorus; its bridge quotes only the first two bars of
  1:48 over the relative minor. Boss: both samples a minor third up (A♭ = relative of F minor). Each sample once per
  loop. `SAMPLE_BARS` = bars excluded from the chord-tone check. Lesson: a new island must not reuse another island's
  rhythmic template — measure attack-position overlap of phrase A against the other themes (now 33-35 % vs pradera).

- 3.57.0 (verified by numbers only): (1) `snowball_boss` phrase A remade — v2 had nieve_1's rhythm bar by bar in minor
  ("not convinced; more distinct from nieve_1, built from the established samples"): its riff is now the 1:48 phrase's
  closing cell (three repeated notes + a leap, `W148_END`), answered by a stepwise descent like the motif's 2nd bar, and
  the motif's octave leap ends the phrase; bridge and chorus unchanged. (2) `gummy_king_boss` REMADE to be regal and
  not meadow-like (v1: G major, hopping bass, offbeat plucks, bird trill): B♭ major, 148, trumpet fanfare ON the beat
  with a "ta-ta taa" call, horns an octave below, held chords, march bass (root/fifth in quarters), military snare
  with drags, timpani, bugle call as its motif; B = a court dance in G minor, baroque stepwise sequence over a 16th
  harpsichord (Alberti). (3) STEMS: `python tools/music/worlds_nes.py <track> --capas` writes every layer as WAV to
  `FlappyMonster_pruebas/musica/<track>_capas/` (each layer gets the master's per-sample gain, so they sum EXACTLY to
  the track; `STEM_NAMES`). Made for pradera_1 because the user hears "little bell-like sounds every 2 beats" in the
  meadow, coast, fortress and summits tracks and wants to point at the layer before anything is changed — WAITING for
  them to say which (candidates: the offbeat chord plucks, the island motif on long tails, the melody echo).

- ACCENTS PER PLACE (3.58.0): with the stems the user identified the `trino_adorno` layer: nearly every level and boss
  theme had "a few high pulse notes in 16ths in the same slot" (the meadow trill adapted), and since the meadow is heard
  first, everything sounded like a meadow remix. The decorative accent stays (same slot: where the melody rests, and in
  the intro) but each is now its own thing — other timbre, rhythm, register, often UNPITCHED (noise channel `fx`,
  helper `swell`): pradera_1/bonus the bird trill (ONLY there); pradera_2 horse hooves (clip-clop); costa_1/bonus a
  WAVE breaking (noise swell); costa_2 bubbles; fortaleza_1/bonus a LOW horn answer (fifth → root) + snare roll;
  fortaleza_2 steam + two unpitched anvil hits; nieve_1/bonus a sleigh shake + ONE ringing bell; nieve_2 a wind gust;
  snowball_boss rolling toms + a low two-note "laugh"; gummy_king_boss a growing timpani roll + cymbal swell;
  evil_ship_boss a low wailing SIREN (one note, ±2 semitones). Stem name: `acento_del_sitio`. Rule for new themes:
  never reuse another place's accent; give each its own sound.

- CAVES (3.59.0, `worlds_nes.py`, intro + loop; verified by numbers only): `cuevas_1` "Ecos de cristal" (D DORIAN —
  B natural, the G major chord —, 104 BPM half time: melody on the music box with a sample-domain cave ECHO, long notes
  with gaps for the echo, pad, whole-note bass, deep kick + one clack, no hats; accent = two falling DRIPS, every other
  bar; cavernas_cristal, nivel01), `cuevas_2` "Laberinto sumergido" (A minor, 92: hollow flute voice with echo moving
  by step, harp 8ths, almost no drums; accent = a SONAR ping and its fainter repeat; laberinto_submarino),
  `cuevas_bonus` (cuevas_1 at 132 + percussion solo; cripta_del_silencio). `cuevas_oscuras` (dark levels) stays.
  Also: the accents of the MEADOW and COAST tracks were "very loud" → 5 dB quieter (fortress and snow were fine).

- VOLCANO (3.60.0, `worlds_nes.py`, intro + loop; verified by numbers only): `volcan_1` "Sendero de ceniza" (E
  PHRYGIAN — F natural, the F major chord —, 164: melody in SNAPS, a 16th then a dotted 8th (attacks 0-1 · 4-5 · 8-9 ·
  12; two earlier rhythms were dropped for sharing 71 % of attack positions with nieve_1 / 58 % with pradera_1), on a harsh
  N163 wave with horns below; 16th tremolo fifths, 8th bass, double kick; accent = ERUPTION: a deep boom + a noise
  swell), `volcan_2` "Lluvia de fuego" (A phrygian — B♭ —, 172: whip-like 16th phrygian runs ending on a long note,
  bass and kick GALLOPING, held fifths; accent = a fireball falling and bursting; the auto-scroll level), `volcan_bonus`
  (volcan_1 at 178 + percussion solo; cantera_real). With this every island has its set; all pending slots are filled
  except `victory`; the only borrowed tune left is in `mirror_boss` / `mirror_boss_inst`.

- VOLCANO v2 (3.60.1): the user had `volcan_1` (and so the bonus) remade completely and the volcano ACCENTS made
  melodic (the noise eruption / fireball "didn't sit well"). volcan_1 is now a singable heroic tune: quarter, two 16ths
  and the long note pushed an 8th early (taa ta-ta-TAAA), 2-bar phrases that climb and answer; E minor with F natural
  (♭II) mid-phrase and at the cadence; B opens to the relative major; lead = warm N163 brass (was a harsh wave) with
  horns below; tremolo fifths, 8th bass and double kick stay. Accents = a plucked figure (`I_GTR`): volcan_1/bonus a
  flourish (fifth, its upper scale neighbour, fifth → root); volcan_2 the chord climbing in 8ths. The snap-rhythm
  version (16th + dotted 8th) is gone.

- 3.60.2: the user wants ALL accents MELODIC — the unpitched ones "didn't sit well" (the volcano set is now approved).
  Changed: costa_1/bonus the marimba answering SYNCOPATED (steps 9 · 11-12 · 14; not a run, not a wave), nieve_2 three
  bells falling, one every three 16ths (not a wind gust), fortaleza_2 a clock chime, fifth-third twice (not steam +
  anvil), gummy_king_boss a trumpet answer climbing the chord in dotted rhythm + one timpani hit (not a timpani roll +
  cymbal swell). Rule: an accent is a short pitched figure in the track's own instrument, with its own rhythm — never
  noise only, never the meadow trill. Left to do: the Mirror boss theme and the `victory` jingle.

- `victory` (3.62.0, `worlds_nes.py victory`; verified by numbers only): the results-screen music, the LAST empty slot.
  Intro = a FANFARE that plays once (the whole "llamada" G-C-E-G on trumpet with timpani on every note, cymbal, a roll
  into the cadence; 7.3 s) + a light celebration LOOP for as long as the screen lasts (C major, 132: trumpet + octave,
  bass walking through the chord, claps on 2 and 4, tambourine, accent "ta-da"; 58 s; the borrowed track it replaces
  was 85 s and simply ended). `song()` themes may now give the intro its own melody and chords (`pi`, `ci`).
  **THE SOUNDTRACK IS COMPLETE (2026-10-03)**: every island has `_1`, `_2`, bonus; every boss its own theme; map,
  menus, results. Nothing pending in `index.json`; no borrowed tune ships except the two samples the user asked for
  (Tentacle Tantrum cells in the Crab Tantrums, Winter Fallympics motif + 1:48 phrase in the snow set and the icy
  crab, the old level tune's 8 bars in the final boss). Retired audio lives in `FlappyMonster_originals/music/placeholders/`.

- 3.66.2 (accents of `evil_ship_boss` and `snowball_boss`): they were "very loud, as if they were the main melody" and
  out of harmony — a wailing siren (±2 semitones of vibrato) and a low "laugh" with a pitch drop. Now both are a quiet
  ACCOMPANIMENT made only of CHORD TONES, no bends (`I_SOFTACC`): the ship alternates fifth and root in 8ths; the
  snowball has three chord notes stepping down (its tom roll halved). Level −15 / −14 dB vs the lead (≈1 % of the
  energy, was 6 %). Rule: an accent is never louder than a backing layer and never leaves the chord.

- `flappy` "Aleteo" (3.97.0, `worlds_nes.py flappy`, theme `aleteo`, arrangement `cielo`, intro + loop; verified by
  numbers only, waiting for the user's verdict): the Flappy mode's OWN track — until now it played `pradera_1`
  (`Music.DEFAULT`). D major (no island uses it), 150 BPM, 36 bars (57.6 s; loop 51.2 s). The idea is the FLAP: the
  monster climbs in little hops (a rest on beat 1 = the push, two offbeat 16ths and the note that lands: ta-ta-TA)
  and glides down by step (gravity), in 2-bar phrases; bar 8 of A' is the 3+3+2. Thin 12.5 % pulse lead with a small
  upward scoop on attack (`I_SKY`), bass root-octave-fifth-octave in 8ths (half notes in B), third + fifth "pushes" on
  the 4th and 7th 16th of every half bar, kick 1 · 3 · 3-and-a (step 11), 16th hats. Dark turn: G MINOR (iv) in bar
  6 of B. Accent (own, melodic, chord tones only): the HOP — root + its octave, fifth + its octave in 16ths. "La
  llamada" in D closes B (A-D-F#-A). Measured: 55 % of melody notes off the beat, lead 17 % of the energy; phrase A's
  attack positions overlap pradera_1 49 % / pradera_2 55 % (between existing themes it is 50-100 %).

- **LONGER TRACKS, NO LLAMADA (3.98.0, `worlds_nes.py`; verified by numbers only).** The user: most level themes
  (and `evil_ship_boss`, `snowball_boss`) don't reach a minute and get repetitive and tiring; and the motif at 0:38-0:40
  of `pradera_2_loop` — LA LLAMADA closing phrase B, in nearly every song with the same rhythm — "fits in some songs,
  but forcing almost ALL melodies to contain it is too much". (1) La llamada was removed from every `worlds_nes.py`
  track except `victory`; each B now closes with its own cadence (bar 8 of B; for nieve_1 / the snowball, bar 8 of the
  chorus C). It stays in the map, the films, the Mirror boss and the victory fanfare; the crab themes still close
  their coda with it (untouched: approved tracks). (2) Every track (the 18 island tracks, the three island bosses and
  `flappy`; not `victory`) got the long form: intro · A · A' · B · [C] · **D** · **E** · A'' · B' · [solo] · A'''
  (64 bars; 56-60 where B/C carry a borrowed sample, which still sounds once per loop). D = DEVELOPMENT, new 8 bars per
  theme built from A's rhythm and contour in another key area (relative minor / major, IV), ending on the chord that
  opens E; E = BREATHER, new 8 bars of long notes in B's arrangement, bass in half notes, kick on 1 + loose hats (caves
  and the reef keep their own sparse drums), a snare that comes back in bar 7 and a roll in bar 8 → crash into A''.
  A'' and B' add a COUNTER-MELODY (N163 pad wave, one chord tone per half bar between A3 and A4, nearest to the last,
  moves if it repeated three times, thirds filled with a scale passing tone; stem `contracanto`), A''' also doubles the
  melody an octave up where the arrangement doesn't already. All new long notes are chord tones and all notes are in
  the scale (checked). Lengths now 92-177 s (were 45-84). Section loudness vs A: E −0.1 to −2.2 dB, A''/B' +0.4 to
  +0.9, A''' +0.5 to +1.4. Melody off-beat share fell to ~40-45 % in the busy tracks (E is long notes on the beat).
  Waiting for the user's verdict on each D and E.

- **3.99.0 — the user's verdict on 3.98.0 and what changed (`worlds_nes.py`; verified by numbers only).** (1) "Bring la
  llamada back where it was: I've heard it so long that it's odd without it" → restored exactly as in 3.97.0 (bar 8 of B;
  nieve_1 / snowball: bar 8 of the chorus); the guide's rule is back. (2) "Make each extension original, not like the
  others: they follow the same logic and flow" → no more shared D·E·A''·B'·A''' recipe: `FORMS` gives each theme its
  own continuation after A·A'·B[·C], from new material (`DEV` D/E where they fit + `EXTRA`) and per-section devices
  (`var`: `cm` counter-melody, `dbl` octave, `thin` breakdown, `stop` stop-time, `swap` melody to another instrument
  while the voice sings the counter-melody, `dial` the accent answers every bar, a transposition):
  pradera_1 new 3+3+2 CHORUS · DIALOGUE with the bird (thin) · chorus + cm · PIVOT bar · A a tone UP (A major) + octave
  · TURN bar back to G; pradera_2 D (A minor) · A stop-time on the gallop · B + cm · A + octave; costa_1 a steel-drum
  SOLO · A on MARIMBA (the steel sings the counter-melody) · B + cm · A + octave; costa_2 E breather (thin) · A + cm;
  fortaleza_1 the DRILL (repeated march notes, stop-time) · D · B + cm · A + cm; fortaleza_2 the MACHINE alone (4,
  thin) · D · A + cm · A + octave; nieve_1 D · A thin (music box and bells) · A + cm; nieve_2 the STORM (16th gusts)
  · D · A stop-time · A + octave; cuevas_1 E · A thin · B + cm · A; cuevas_2 D · A on a fading BELL (swap) · A + cm;
  volcan_1 D · E thin (ends on ♭II) · A + cm · A; volcan_2 the LAVA SOLO (boiling arpeggios) · D · B + cm · A + cm;
  snowball D · A stop-time · A + cm; evil_ship the ALARM alone (4, thin) · D · A + cm · B + cm · A; gummy_king D · E
  (court dance) · PIVOT · A a tone UP (C major) + cm · TURN; flappy D · GLIDE (4, thin) · A + cm · A + octave.
  Loops now 84-138 s. (3) Transitions: entering every new section, a held note that reaches the end of the bar is cut
  at the 15th 16th and two scale 16ths lead into the section's first note (`song.linked`; in the key of the bar
  where they sound); key changes have a pivot bar (the new key's dominant) and a turn bar (home dominant) before the
  loop; the accent is silent in linked, stop-time and swap bars. (4) BONUS: back to the old length (intro · A · A' · B ·
  SOLO · A'', 40-bar loop, 59-80 s; "the bonus zones last a bit over a minute and the solo was the special part —
  now it's never heard") and each is an ORIGINAL bonus tune of its world (`BONUS`), closing B with la llamada:
  pradera "Carrera" (A major 152, two repeated 16ths and the note that leaps), costa "Regata" (C major 138 with a B♭
  in B, a rowing ta · ta-ta · TAA), fortaleza "Asalto" (A minor 156, three repeated hits and the falling note; dotted
  answer), nieve "Descenso" (G major 166, a ski run of two falling 16ths + long note, and the JUMP: three offbeat
  notes), cuevas "Estampida" (E dorian 132, note + long anticipated note), volcan "Erupción" (D phrygian 178, octave
  leap, dotted 8th and its upper neighbour). A DIFFERENT PERCUSSION SOLO per world (`solo_bar(style=)`; the old one,
  the same everywhere, stays only in the meadow): costa congas + 3-2 clave + marimba + timbales and cowbell; fortaleza
  military snare rudiments with flams, orchestral timpani, anvils, a closed buzz roll; nieve sleigh bells, timpani,
  falling and rising bells; cuevas deep drums with echo, wood clacks, drips, a quickening heartbeat; volcan double
  kick, falling tom rolls, blast beat, eruption hits. Pitched solo notes are tonic-chord tones (stem `solo_afinado`).
  Phrase-A attack overlap with the world's siblings: 27-67 %.

- **3.99.1 — repair of 3.98/3.99, track by track with the user's ears (`worlds_nes.py`; audits `revisar.py`, A/B
  previews `previas_ab.py`).** The user: some extensions sounded forced, harmonically wrong or dissonant; some loop
  endings broke. Root causes found: (code) the automatic two-16th PICKUP before every new section (a formula, and it
  silenced the accent in that bar) — removed; 1-bar pivot / turn bars counted as section starts (a crash on the
  dominant bar, no fill into the loop); the counter-melody chose chord tones ignoring the melody, its passing notes
  made m2 / tritones with the chord, and in 'swap' the voice sang it in the melody's register (costa_1 A4 vs B♭4).
  (composition) the D "developments" were the theme's head replayed in another key — the user heard gummy_king's as
  "a remix that sounds bad"; the key changes of pradera_1 (G → E major pivot → A) and gummy_king (→ C) made the seam
  sound broken; a few new melody notes were unprepared 7ths (pradera_1 chorus bar 2: B5 over C). Repairs: no key
  changes; D removed in every track that had one (pradera_2 also because the meadow in minor was already rejected);
  `cmx` = counter-melody whose passing notes don't clash, under the melody in 'swap'; pradera_1 chorus bar 2 → C6 G5 E5 ·
  G5 A5; flappy's glide, cuevas_1's and costa_2's breathers end descending into A; bonus notes fixed (pradera G#→E on
  beat 3 over A, cuevas C#→B over D). Forms now (after A · A' · B [· C]): pradera_1 chorus · dialogue with the bird ·
  chorus + cm · A + octave; pradera_2 A stop-time · B + cm · A + octave; costa_1 steel solo · A on marimba · B + cm · A +
  octave; costa_2 breather · A + cm; fortaleza_1 drill · B + cm · A + cm; fortaleza_2 machine alone · A + cm · A + octave;
  nieve_1 A without drums · A + cm; nieve_2 storm · A stop-time · A + octave; cuevas_1 breather · A without drums · B +
  cm · A; volcan_1 breather · A + cm · A; snowball A stop-time · A + cm; evil_ship alarm alone · A' + cm · B + cm · A';
  gummy_king A + cm · court dance · A; flappy glide · A + cm · A + octave. APPROVED by the user after listening (A/B
  previews): all of these and the pradera / cuevas / volcan bonus. Adjusted afterwards: fortaleza / nieve / costa bonus tunes, the nieve solo, volcan_2's lava solo, cuevas_2's
  sonar accent (see 3.99.2).

- **3.99.2 (user's requests after listening; all approved from A/B previews).** fortaleza_bonus "Asalto": the repeated
  notes an octave higher (the saw, an octave down, played them as a muddy A3) and with more contour (E-E-E → A · C-C-C
  → A); B no longer goes through C major (F · G · Am · E). nieve_bonus "Descenso": no C over B minor in B; its SOLO's
  bells were "small melodic fragments, very loud, combining oddly" → ONE phrase (falling in quarters in bars 3-4,
  rising softly in bar 7, one bell at the end), two octaves lower, 5 dB quieter (`I_BELL_SOLO`, `perc` −8 in the snow
  mix). costa_bonus "Regata": no B♭ (B bar 7 went B♭ → G, two different B's in a row: now Dm → G); A bar 3 returns to C
  by step. volcan_2: the lava solo ("good idea, odd progression and development") is now two phrases — the boiling
  arpeggio over Am · B♭ · Am · Gm, then the same boiling RISING F · Gm · B♭ to C, which leads into B (was Am B♭ Am Gm F
  Gm B♭ B♭). cuevas_2 (old, not part of the extensions): the SONAR accent "too loud, breaks the calm" — was the fifth in
  octaves 6-7 on a thin pulse; now a soft round note in the middle register that fades slowly, with its echo, 5 dB
  lower (`I_SONAR`). mirror_chase: no longer carries the boss fury's "part 2" (the second half of its riff: C#-E, B-D,
  the hammered mirror, the ending) — its second half is the riff over F#m · D · E and the mirror motif slowly; and the
  loop no longer ends with the intro's BUILD (U2): from the last A straight back to the first, tail folded. mirror_boss:
  the user tried a rewritten fury part 2 and preferred the ORIGINAL; only the ending changed: the 4-bar FALL was the
  intro again ("the song must end as a loop") → a 4-bar CLOSE with the theme (F#m · D · E · C#, long falling notes,
  E# → F# into A), arranged like A'.

## Crab Tantrum (the three Mega Crabby themes)

- **CRAB TANTRUM REMADE (3.53.0, `tools/music/crab_tantrum.py`; verified by numbers only; WAITING for the user's
  approval — then the Gloomy and Icy variants are built FROM it)**: `crab_tantrum_normal` is now an original
  composition, the FOUNDATION of the three Mega Crabby themes; the old note-for-note arrangement is outside the repo
  (`placeholders/crab_tantrum_normal_tentacle_nes.ogg`; `tentacle_nes.py` now writes there; icy/gloomy still import it
  until they are remade). From Tentacle Tantrum only SAMPLES: (1) the riff CELL (long tonic, tonic, up a 4th, down to
  the 3rd; rhythm 6-2-2-4) opening bars 1/3 of phrase A (and, varied, 5) and played by the BASS in the bridge, (2) the
  3+3+2 tresillo in bass and kick, (3) the chorus gesture (long note + lower neighbour) once per B phrase, (4) the
  finale's syncopated repeated notes (6-4-4-4) over rising chords in the coda. Everything else is new. HARMONY = D
  NATURAL minor only (v2, 3.53.1): v1 cadenced on A major (C#) next to C-natural chords and its chorus was F–C–Dm–B♭
  (happy) — the user liked the theme and the samples but in the non-sample parts "the melody didn't quite fit the other
  instruments, harmony a bit odd" (the pradera_2 lesson again: no bright major section inside an aggressive minor
  arrangement, no leading tone mixed with ♭VII). v2 (all natural minor, new chorus progression i–♭VI–♭VII–i · iv–♭VI–♭VII
  with a new melody) was "weirder than before". v3 (3.53.2): no cadences and no new progression at all — the non-sample
  parts use the riff's OWN language: tonic + the ♭VI–♭VII turn, melody in D minor PENTATONIC (the cell's notes, 89 %);
  A = Dm | Dm B♭ | Dm | Dm C | B♭ | B♭ C | Dm | B♭ C; chorus = the chorus gesture in a descending sequence, two bars
  per chord (Dm · C · B♭ · C). Only bars 7-8 of A and the chorus have ever been changed; the rest was approved.
  v3 verdict: "better, but it doesn't fully fit the character, and going from the good parts into these is odd". v4
  (3.53.3): (a) A closes with the riff itself — bar 7 = the cell, bar 8 = the riff's TAIL (tonic, tonic, ♭VI, ♭VII; one
  more sample; a third chord in a bar = its last quarter, `Q4`); (b) the chorus is no longer sung in long notes: a WAR
  CHANT (short repeated notes on the 3+3+2, then a fall in the cell's rhythm; Dm Dm B♭ C ×2) and it KEEPS A's half-time
  tresillo groove with more toms (it used to switch to four-on-the-floor + 8th bass: the odd transition). Lesson: for
  this character, sections differ by intensity and register, not by groove or by turning lyrical.
  COAST link: D minor = relative of costa_1's F major, the coast's marimba plays the tresillo, 16th shaker,
  ends with "la llamada". Character (user): powerful, TRIBAL, aggressive — tom ostinato, deep kick, clearly drawn bass
  (triangle + a pulse an octave up), VRC6 saw + pulse lead. 180 BPM (felt at 90); intro 4 (drums; own file) · A · A' ·
  B · B' · tribal BRIDGE · A'' · CODA = 56-bar loop (74.7 s); drums 46 % of the energy, bass 23 %, lead 20 %.
  PLAN for the variants (user): Gloomy = slower, cave-like, with the spider "legs" (constant 16ths in groups of 8,
  12.5 % pulse, pauses at phrase ends — `docs/audio/music-guide.md` §7); Icy = keeps and develops the
  Christmas/music-box motif of Winter Fallympics on this foundation. Reinterpretations, never copies; the three must
  clearly be the same Mega Crabby identity. NOTE: `GN.export(name, y, intro)` DELETES the old single `<name>.ogg`.

- **CRAB TANTRUM: the user APPROVED the main theme (3.53.3 = definitive) and the two variants were built from it
  (3.54.0, `crab_tantrum.py [normal gloomy icy]`, `build(style)`; the normal render is bit-identical to the approved
  one; verified by numbers only).** Same song for the three (cell, tail, war chant, bridge, coda, D minor), other
  atmosphere. GLOOMY (`crab_tantrum_gloomy`, 144 BPM, −11 LUFS): hollow N163 voice with cave echo, triangle bass only,
  no stabs/marimba/doubling, dry drums (deep tresillo kick, short-noise claw clack on 3, far toms) and the spider LEGS
  (`docs/audio/music-guide.md` §7; `GN.LEG8/LEG6/I_LEG`): non-stop 16ths in groups of 8, 12.5 % pulse, chord's minor pentatonic +
  blue note, foreground when the melody rests / background (×0.4) under it, 6-against-8 second pattern from the
  chorus on, octave jump every 4th bar, and the PAUSE at each phrase end (chromatic run down, then the last beat silent
  except the melody = the riff's tail; crash on re-entry). ICY (`crab_tantrum_icy`, 180): the Winter Fallympics
  CHRISTMAS / music-box MOTIF (`MOTIF`, 4 bars over B♭ B♭ C C) as the second idea, only where ITS harmony is — which
  here is the riff's own ♭VI–♭VII turn resolving to D minor: the intro (music box alone + sleigh bells), the first
  half of both choruses (1st: box alone over the band, answered by a NEW phrase built on its octave leap `DEV`; 2nd:
  the voice sings it too and the war chant finishes) and the first half of the bridge (drums empty out). Ice palette:
  smooth N163 voice doubled by the music box an octave up, ice chimes on the tresillo (where the marimba was), sleigh
  bells, 16th shimmer. The old arrangements (tentacle_winter / tentacle_gloomy) are outside the repo
  (`placeholders/crab_tantrum_icy_tentacle_winter.ogg`, `..._gloomy_tentacle_gloomy_{intro,loop}.ogg`); their
  generators write there. Older notes in this file about tentacle_nes / tentacle_winter / gloomy_nes `jefe` describe
  those RETIRED arrangements.

- Crab Tantrum TEMPO (3.54.1): the user approved `crab_tantrum_gloomy` as is (144, half-time) but found normal and icy
  "too slow" in game: at 180 with the snare on beat 3 they FELT at 90. Now both are 200 BPM in FULL time (`fast`): snare
  on 2 and 4 with ghost 16ths, tresillo kick + extra kicks, 16th hats, crash every 4 bars in A, backbeat in the second
  half of the bridge; notes, bass and mix unchanged (loop 67.2 s). The gloomy render is bit-identical. Lesson: for a
  boss, judge tempo by where the SNARE falls, not by the BPM number. 200 was "a bit too much" → 3.54.2: the same full-time
  groove at 172 BPM (loop 78.1 s), the middle point the user asked for. 172 was "very slow" → 3.54.3: 186 BPM (loop 72.3 s). Tried so far, full
  time: 200 too fast, 172 too slow.

- `crab_tantrum_icy` v2 (3.65.1; user: "it has the music-box motif; the other, more important sample is missing: 1:48-2:08").
  The whole 1:48 PHRASE of Winter Fallympics (its bars 85-92, an octave up; `PH_148`) is now section B — the calm-but-
  driving BRIDGE, over the relative minor's chords (Dm · Gm F · B♭ · C · Dm · C · Gm · C), lighter arrangement (`calm`:
  no stabs or toms, tresillo kick, soft backbeat, sleigh bells, shimmer) — and its closing figure (three repeated notes
  + a leap, twice) leads into the motif chorus, which starts on B♭: the same order as in the song both come from. Form:
  intro (motif, music box alone) · A · A' · B (1:48 phrase) · B' (CHORUS: the motif sung + the war chant) · the base
  theme's tribal bridge · A'' · coda. The motif now sounds twice, not four times (no motif in B or the bridge).

- **`crab_tantrum_icy` v3 = a NEW COMPOSITION (3.66.0, `tools/music/crab_icy.py`; verified by numbers only; waiting for
  the user's verdict; its video is NOT re-rendered until then).** v1 put the Winter motif into the crab theme in four
  places and v2 added the whole 1:48 phrase: "you have basically copied and pasted the original melodies" — the user
  wants what the final boss does: motifs as MATERIAL to reinterpret and develop; it may be longer, with more sections
  and new melodies, and sound quite different from the other two crab themes as long as something of the Tentacle
  Tantrum motif is recognisable. Now NO bar is copied from winter (measured: 0 of 71 melody bars share rhythm +
  intervals with a bar of the 1:48 phrase or the motif). From TENTACLE TANTRUM: the riff CELL (bars 3 and 7 of the
  theme, the end of the chorus, the bass in the breather; 6 bars) and the 3+3+2. From WINTER, three IDEAS: (a) the
  motif's OCTAVE LEAP + stepwise descent → theme A starts with the cell's rhythm but THAT contour; the CHORUS is the
  contour in minor, from the 5th degree, in the crab's 3+3+2 rhythm instead of even quarters, in sequence; the
  BREATHER sings it on the music box in long values and continues on its own; (b) the 1:48 gesture (three 8ths + an
  offbeat long note) → section B INVERTS it (the 8ths fall) over a new progression; once upright in the theme (bar 4);
  (c) its closing figure (three repeated notes + a leap) on other degrees, closing B and the breather. And they MEET:
  in the third pass of the theme the music box sings a new long-note counter-melody above the crab's tune. D natural
  minor; chorus i–♭VI–III–♭VII (F major, winter's key, as III). Form: intro 4 (music box alone) · A · A' · B (thaw,
  lighter) · C (chorus) · K (breather: music box, the bass brings the cell, drums return) · A'' (+ counterpoint) · B ·
  C' (full) · coda 4 = 68-bar loop (87.7 s). Section dynamics drawn (`DYN`). `crab_tantrum.py icy` no longer generates
  it (it only does normal and gloomy).

- `crab_tantrum_icy` 3.72.0 (user's verdict on v3: the theme is GOOD; only "make the 1:48 phrase and the music-box /
  Christmas motif sound more like the real reference, recognizable, without changing anything else"): section B (both
  passes) is the 1:48 phrase of Winter Fallympics as is (bars 85-92; chords Dm · Gm F · B♭ · C · Dm · C · Gm · C) instead
  of its inverted gesture (`T_B_OLD` kept), and the Christmas motif is literal on the music box (`MOTIF`, quarter notes
  over B♭ B♭ C C) in the intro and in the first 4 bars of the breather K. Theme A, chorus, counterpoint, arrangement,
  form and mix untouched. Same lesson as Verity: a motif the user calls a reference must be QUOTED somewhere, even in
  a piece that otherwise develops it. Loop times: B 0:21 / 1:02, breather 0:41. OST video not re-rendered.
  3.72.1: that was TOO literal ("practically a copy/paste; v3's transitions and inclusion were more natural; the point
  was a bit more recognizable, not literally the same"). MIDDLE GROUND, v3's harmony and form restored: section B keeps
  the 1:48 phrase's FINGERPRINT — its rhythm (three 8ths + an offbeat long note) and the contour of its head (up the
  chord to the octave), UPRIGHT (v3 inverted it) — but in G minor, continued in sequence over v3's progression, not
  its notes; the Christmas motif = its FIRST BAR as is (quarter notes: octave leap + descent) in the intro and opening
  the breather, then it goes its own way. Literal bars vs winter: 2 of 72 (that motif bar, twice). THE SCALE for this
  user: inverted / half-speed = not recognizable; whole phrase literal = copy-paste; RIGHT = the motif's rhythm and
  head contour (or one literal bar) leading into own material. (Verity's hook is the exception: the user asked for
  that one literal.)
  3.72.2: THE USER WENT BACK TO v3 (3.66.0) — audio, .mid and `crab_icy.py` restored exactly; v3 is the definitive
  `crab_tantrum_icy`. Don't touch its winter references again unless asked. Archived outside the repo:
  `FlappyMonster_originals/music/versiones/crab_tantrum_icy_v3/` (the restored one) and
  `.../crab_tantrum_icy_3.72.1_intermedia/` (the middle-ground attempt, with its generator).

## The final boss theme and the mix pass

- **MIRROR BOSS = the FINAL BOSS theme (3.61.0, `tools/music/mirror_boss.py`, id `mirror_boss`, intro + loop; verified
  by numbers only; waiting for the user's verdict).** Brief: the ultimate confrontation, unlike anything before, epic,
  layered, with quiet bridges (like winter's 1:48) and escalation to a climax that culminates the soundtrack; its own
  instruments, motifs, harmony, structure. What sets it apart: 12/8 METER (everything else is 4/4 in 16ths; `PH` here
  counts 8ths, 12 per bar, ♩. = 150); F# HARMONIC minor (dominant C# with E#, Neapolitan G) and an F# MAJOR climax; the
  MIRROR MOTIF = the game's "llamada" (5-1-3-5 rising) with its intervals INVERTED → C#-G#-E#-C# falling = the dominant
  chord (the boss is your reflection); it closes the theme's first half, opens the intro alone and climbs in the
  build-up; MIRROR COUNTERPOINT: in the last pass of the theme its diatonic inversion sounds at the same time
  (`invert`, stem 'mirror'); in the climax the real llamada finally answers, rising, in major, with choir + bells +
  octaves. FORM: intro 4 (dominant pedal, timpani, the motif slowly) · A 8 · A' 8 (more layers) · B 8 (development:
  hemiola sequence, Neapolitan, the motif) · C 8 (CALM BRIDGE in the relative major: soft voice + music box, 8th
  arpeggio, no snare) · D 4 (BUILD on the dominant: growing roll, noise riser) · A'' 8 (theme + its mirror + double
  kick) · E 8 (CLIMAX; last 2 bars back to the dominant) = 52-bar loop (83.2 s). DYNAMICS are drawn per section
  (`DYN`, dB: per-stem levelling alone left the bridge LOUDER than the theme): measured vs A — intro −4.4, A' +1.3,
  B +1.3, bridge −3.5, build −1.6, A'' +4.0, climax +4.1. The old `mirror_boss` / `mirror_boss_inst` (tentacle_chip) are
  outside the repo; `mirror_boss_inst` is now an alias. No borrowed tune is left in the game. Pending: `victory`.
  3.61.1 (user's request): a SAMPLE of the game's OLD level music (level.ogg 0:40-1:01 = its bars 25-28 and the ending
  33-36; the tune that was classic → pradera_1 → fortaleza_1 and then left the repo) as a new section F, "the hero's
  theme", between A'' and the climax: it was C minor (Fm · G · Cm | Fm · G · A♭ · B♭); a tritone up it lands on Bm · C# ·
  F#m | Bm · C# · D · E = this theme's own chords; its 3+3+2 rhythms become three quarter notes (the hemiola bar 7
  already uses); and its ♭VI–♭VII ending (D–E under A-G#-A-B rising) resolves into the F# MAJOR climax where the
  llamada answers. Loop = 60 bars (96 s); sections vs A: F +3.6 dB, climax +4.7. So the game DOES quote that tune
  here, as a sample (8 bars).

- 3.63.0: (1) FINAL BOSS v2 — after playing it the user found it "melancholically epic" and wanted AGGRESSIVELY epic,
  above all after the level sample: shorter punchier notes, more rhythmic drive, urgency (the quiet parts and the
  atmosphere are right). Changes: 158 (was 150); in every loud section the theme GALLOPS (each dotted quarter split
  long-short, the short one repeating the note: `GALLOP`), short notes are cut earlier, the doubling pulse TREMOLOS in
  8ths over long notes, the kick gallops; new section G "FURY" after the hero's theme (staccato 8th riff, repeated note
  + leap, F#m with the Neapolitan, the mirror motif HAMMERED three times per note, unison 8th bass, continuous double
  kick); the CLIMAX is no longer F# major with the llamada in long notes (triumphant, sweet) but minor with FIFTHS (no
  thirds): the llamada hammered (C#×3 F#×3 A×3 C#) and galloping phrases over i–♭VI–♭VII–i, ending with the mirror motif
  in blows on the dominant. Loop 68 bars (103.3 s); sections vs A: hero +2.7, fury +4.2, climax +5.0 dB.
  (2) OST LEVELS: `tools/music/levels.py` measures each track's LUFS and writes its catalog `volume` so everything is
  equally loud IN GAME (file loudness + volume): levels and map −14.5 effective LUFS, calm tracks −15.3, bosses −13,
  final boss −12.5, results −15, menus −15.5. Before, volumes were set for the borrowed tracks and the new bosses came
  out ~3.5 dB above the levels. RE-RUN it whenever a track is added or regenerated.

- 3.63.2 (after the user played it): (1) the background glow no longer showed at night — LÖVE's 'subtract' blend
  does NOT touch destination alpha, so nothing was being marked; `Sky` now builds a "hole" image per glowing layer
  (alpha 0 on glow, 1 elsewhere) and writes it with colour mask alpha-only + blend 'replace' (verified: pixels marked,
  streams bright, clipped by the boss walls). (2) Volcano blocks kept the GREY light edge the game draws on exposed
  faces: basalt/ash edges (and editor colours) now use the rock's and the ash's own light tones. (3) FINAL BOSS form:
  the fury was 8 bars and after the climax the loop jumped STRAIGHT to theme A ("it ends before the fury finishes
  developing; odd loop from the most intense to the calm start") → fury is 16 bars (2nd half: the riff a fourth up, Bm /
  C, then its hammered ending) and after the climax a 4-bar FALL = the intro again (mirror motif slowly over the
  dominant, timpani, the music empties and the roll rises), so A re-enters exactly as the first time. Loop 80 bars
  (121.5 s); vs A: fury +4.1 / +4.7, climax +5.4, fall −2.9 dB. Lesson: a long boss loop needs its own way back —
  never cut from the peak to the opening.

## The Mirror chase track

- Music `mirror_chase` (`tools/music/mirror_chase.py`, intro + loop, verified by numbers only): DRUM & BASS as fast
  chiptune (the user's reference for genre/energy only: Stonebank "Losing Control (Sophon Remix)"), 174 BPM, F# harmonic
  minor like the boss. The NOTES come from the Mirror boss theme, re-cut into short syncopated 4/4 hits: the theme's
  HEAD = the drop hook (A), the MIRROR MOTIF closes each half phrase / is sung slowly by the bell in the breather /
  climbs in the builds, the HERO'S THEME (the old level tune sample, level.ogg 0:41-1:02) = section B with its 3+3+2
  back as repeated hits, the FURY riff = section G in running 16ths. Two-step drums (kick on 1 and the "and" of 3, snare
  on 2 and 4, ghost snares, 16th hats), bass = triangle sub + a trembling saw an octave up. Form: intro 4 + BUILD 4 |
  A · A' · B · B' · K (half-time breather) · G · A'' · BUILD 4 = 60-bar loop (82.8 s). The BUILD is the same bar at the
  end of the intro and of the loop (no tail folding) and ends in one beat of SILENCE before the drop. Energy: drums
  51 %, bass 30 %, lead 10 %.

- GENRE CHECK of `mirror_chase` against the user's reference (measured, not listened; the user: "fine, but it doesn't
  really follow the genre"; a written guide is coming — DON'T rework the track before it): the reference is 172 BPM,
  has 56 % of its energy BELOW 120 Hz (29 % at 20-60 Hz: a real sub) where ours has 29 % (3 % at 20-60 Hz; our bass
  lives at 120-250 Hz), crest factor 10 dB vs our 13, and its form is long: ~16 quiet bars (−8 dB), a build, a drop
  held ~32 bars at full level, a breakdown back at −8 dB, a second drop. Ours: 8-bar sections, breather only −4 dB.

- `mirror_chase` v2 (3.81.0, from the user's written genre guide + the measurements; verified by numbers only):
  dancefloor FORM — intro 4 + build 4 | DROP 1 = 32 bars (A A' B B') · BREAKDOWN 8 (i–VI–III–VII on the bell, no kick
  at first, −7 dB) · build 4 · DROP 2 = 32 bars (G A'' B'' A''') · build 4 = 80-bar loop (110.3 s; the intro stays
  short on purpose: it is a chase level). BASS in two layers: an almost pure SUB (triangle) an octave lower (F#1 = 46
  Hz), held with the kick, and a REESE on top (two saws 0.17 semitone apart + a growling pulse) with its own 3+3+2
  stabs. SIDECHAIN in the sample domain: bass, pad, arps, stabs and lead duck on every kick (and a little on the
  snare). Drums: two-step with a two-layer snare (dry crack + body), ghost notes, 16th hats with accents and open
  offbeats, a ride in drop 2, a break every 4 bars and a fill every 8, an impact (deep kick + crash) on each drop.
  Lead = two detuned saws + octave, with a ping-pong echo (3 and 6 sixteenths, opposite sides). Master −9 LUFS.
  Measured against the reference: energy below 120 Hz 55 % (ref 56), 20-60 Hz 15 % (ref 29), crest 9.2 dB (ref 10.1).
  The level lasts ~86 s, so in a clean run you hear the intro, drop 1, the breakdown, the build and ~14 s of drop 2.

## Retired arrangements (kept for the lessons)

- Generated music: `tentacle_chip.py` (retired) → `tentacle_chip.ogg` + `.mid` ("Tentacle Chip", boss track): chiptune modelled on an ANALYSIS of TentacleTantrum.ogg (92.5 BPM 4/4 with a 3+3+2 tresillo groove — beat trackers read it as 123 BPM —, 36-bar form ×2, offbeat skank) with its own coherent G-minor harmony and a NEW melody built on one motif (the G–F#–G neighbour note); seamless loop (tail folded onto the start). `--instrumental` → `tentacle_chip_instrumental.ogg`: no melody, extra layers only there (pad, tresillo rhythm chords, cowbell/claps/congas/timbales, fx).

- `menus_chip.py` (retired) → a chiptune take on `menus.ogg` (the user's theme; 140 BPM, 18 bars, boogie bass, sixth chords, blues lick in phrase 2). REJECTED by the user: the game keeps the original `menus.ogg`; the script + .mid stay.

- `tools/music/tentacle_nes.py` → `tentacle_nes.ogg` + `.mid` (catalog id `tentacle_nes`, boss track): Tentacle Tantrum recreated as REAL Famicom music (2A03 + VRC6 + Namco 163 emulation: 60 Hz driver, quantized periods, 32-step triangle, 15-bit LFSR noise, 1-bit DPCM kick/snare, non-linear DAC curves). Melody and bass on N163 wavetables built from the harmonic fingerprint MEASURED on the original's notes (one wave per section); drums from measured curves (kick 275→160 Hz then F#2, a deep ~47 Hz boom in the break, very short bright snare); per-instrument gains FITTED (bounded least squares) so each section's octave-band spectrum matches the original's, then percussion raised to its percussive/harmonic ratio (0.21).

- `melody_nes.py` (retired) → `level_nes.ogg` (catalog `classic`, the default level music; replaces level.ogg) and `boss_nes_intro.ogg` + `boss_nes_loop.ogg` (catalog `boss_nes`), all + .mid, from the level song's MIDI (`tools/music/ref/melody.mid`, local only). Level = faithful, one Famicom channel per MIDI instrument, at 137.5 BPM (level.ogg's real tempo; the MIDI says 140). Boss = the SAME NOTES (recognizable; transposing A→A♭, fifths from every bass note and a sustained noise "fizz" made it sound out of tune and saturated — don't), boss style from timbres (dark bell/organ/clean choir on the long notes), VRC6 power chords whose 5th is used only if it's in the harmony (else octave), short noise hits on chugs, double kick, tom fills; 140 BPM, 4-bar intro, loop from the riff (bars 9-36 + 1-8). Gains fitted PER INSTRUMENT GROUP (bounded around musical base levels) to level.ogg / the original boss remix's band spectrum; then a fixed drum push (×1.6 level, ×2 boss) with a fixed kick/snare/cymbal split (chasing the originals' HPSS ratio buried the melody). Notes from the Musescore MIDI (`tools/music/ref/`, local only, copyrighted, gitignored), everything the MIDI lacks or gets wrong from the ogg analysis: drums (tresillo kick tuned to F#2, snare 2&4, four-on-the-floor break), chords per half bar, and the finale's B–C#–D# bass.

- `winter_nes.py` (retired) → `winter_nes.ogg` + `.mid` (catalog `winter_nes`, the Snowball Boss fight in lago_helado / jefe_nieve): "Winter Fallympics" (winter.ogg, the user's) as loaded Famicom music from `tools/music/ref/winter.mid` (local only), with winter.ogg as the truth: 185 BPM, 144 bars, F major, song starts at 0.045 s of the ogg; MIDI and ogg agree bar by bar (beat DTW) except DYNAMICS (bars 45-60 = a −10 dB drum break → chords ×0.2, arps ×0.45, mix −5 dB) and the BASS: the ogg has it at F1/F2 under the MIDI's F3 → triangle sub 2 octaves down (1 if below E1) + short N163 "slap" an octave down. Mix = per-group levels relative to the lead (`LEVEL_DB`, RMS while playing; fitting the ogg's bands left chords/bells at ~0 % and the bass at 33 %), then a MEASURED octave-band EQ toward the ogg (`eq_to_ref`, 70 %, ±5 dB). Energy: drums ~40 %, lead ~19 %, bass ~17 %, backing ~19 %; band shape within ±2 dB of the ogg in the main sections. Energy additions: ghost 16th hats, snare roll every 8 bars, crash on section entries, intro kicks (the ogg has a low hit there). `REPORT=1` prints the numbers without exporting. ESCALATION (user: the repeated "Christmas" motif = Music Box bars 21/29/37/117/125 sounded copy-pasted, the final not epic): the ogg doesn't get louder (it's limited), it gets DENSER and brighter each time (spectral peaks: motif 15.5→21.9, Smooth Synth 85-116 15→26). So `escalate()` adds layers without touching a MIDI note (bell octave / thirds / two-octave sparkle, lead octave + thirds, a 16th "shimmer" arpeggio of the harmony, bass 8ths) and drums on a separate 'x' bus (open hats, four-on-the-floor, crashes, rolls, tom fill, noise risers before 45/61/117), growing per repetition. Layers take the gain of the instrument they double (`LAYER_OF`/`LAYER_K`; normalizing them as a group flattened the climb). In the final the MIDI lead (8-Bit Square) is ~6 dB under the previous melody → doubled on the VRC6 saw. Break 45-60: the melody stays (only the low end goes) and it rebuilds from bar 53 (the first version cut the chords ×0.2: the melody vanished at 0:57 and jumped back at 1:18). MIDI ERRORS FIXED from the ogg (2:09 on): the "8-Bit Sine" pad repeats one 16-bar cycle 3× but the ogg changes the harmony → `PAD_FIX` (bar → dyad, voiced like the ogg: B♭ with F on top, C with G on top, A7 as G/C#); the ogg also plays that pad 1 and 2 octaves up (strings `str*`, group 'strings'); in the final the motif is harmonized a fifth above (`lay_bell5`), the lead is an octave higher than the MIDI's 8-Bit Square (`lay_leadsaw` at +12) and an F pedal holds bars 121-123 / 129-132 (`lay_ped*`). Same method over the WHOLE song (motif passes too): `CHORD_FIX` snaps the Pop Synth comp to the ogg's chord (passes 2-3 of the motif = B♭ B♭ C C, like the final; same rhythm and register) but ONLY sustained stabs (≥ 6 sixteenths): the short ones are little lines (C/E → B♭/D → A/C in bars 12/28/36, bar 44) and snapping them sounded "different and weird" to the user (the triad metric flags passing tones as wrong chords — don't trust it there), `COMP_LOW` doubles the comp an octave down only where the ogg does (even bars; in the odd F/A bars it added a low A → A minor), the fifth harmony is on every motif pass (from bar 22, growing), F pedals in 33-35 / 41-44 and a G in 36, bar 20's chromatic step also an octave up (`COMP_HIGH`). Result: confident chord mismatches 15 → 2 (intro riser, bar 26 ambiguous), missing notes 966 → ~780 over the song. The final was then SLIMMED (user: overloaded and too strong for chiptune): no duplicate octave, no thirds above, no bell unison/thirds/ double octave, 2-octave pedal, softer shimmer/pump/hats, crash every 2 bars.

- `tentacle_winter.py` (retired) → `tentacle_winter.ogg` + `.mid` (catalog `tentacle_winter`, the Icy Mega Crabby: jefe_cangrejo_helado arena + glaciar_cangrejo): a NEW arrangement, not a blend of the two files (both are 185 BPM). FOUNDATION = tentacle_nes (imports its `load_midi`/`voices`/ `HARM`/`chord_at`/`section`: melody note for note, bass, harmony, drum patterns); PALETTE and DRIVE = winter_nes (imports its `Song`, instruments, kit, `LEVEL_DB`: LEAD = winter's Smooth Synth N163 + MUSIC BOX doubling every note an octave up + winter's pulse lead, saw only added in the final — with the VRC6 saw as main lead the user still heard Tentacle's instrument —, harmonized lead in chorus/final, hollow strings, pad, tri sub + slap, low comp doubling, 8th "pump" bass, offbeat open hats, four-on-the-floor, crashes, shimmer) + sleigh bells. FORM (172 bars, 223.1 s): Tentacle pass 1 (72) | 4-bar BRIDGE (`bridge()`: IV–IV–V–V of the new section, B♭ B♭ C C = exactly the chords of winter's CHRISTMAS MOTIF, which carries the bridge alone on the music box (`MOTIF_F`; a lead cell from Tentacle's final used to play over it: the user had it removed); drums emptied then a snare build + toms + riser, swelling strings; a bare cut was "abrupt") | a NEW SECTION = winter's 1:48 melody (Smooth Synth, bars 85-116) + BOTH passes of the motif from winter's final (117-132) as its payoff; the tail of pass 2 (129-132) is the HAND-OFF (`handoff()`): winter's lead is muted there (`Part.mute`), Tentacle's lead voice already sings the CHORUS phrase (its bars 25-26, then 25 and 34) over winter's backing while the music box answers with motif fragments, and the last bar is turned from D minor into C (V) with a snare build + riser, so the chorus arrives with a phrase already heard instead of replacing the section; with winter_nes's WHOLE arrangement (class `Part` wraps the song while `W.build` runs: keeps only those bars, shifted), UNTRANSPOSED (F major): enters from the final's D# through B♭ (its dominant) and that C resolves into Tentacle's CHORUS (D minor: V → vi, same scale as the motif) | pass 2 = chorus, scales, final only (`SKIP2` 24 bars), which KEEPS the winter section's intensity to the end (user: after the hand-off it must not let up): octave pulse + saw on the lead, shimmer, high strings, 16th hats, four-on-the- floor, crash every 2 bars, snare fill every 4, scales in full time (not half-time), 16th pump bass and 8th kicks in the final, riser + toms into the loop (levels: W 0, pass 2 −0.5…−0.1 dB). Going back to the riff after that payoff sounded like "the song restarted" and made the track a minute longer than the originals (an earlier version had the section in F# major to cadence into the F# minor riff). The motif appears only in those two places, where its own chords are: v1 put it in the gaps of Tentacle's melody (other keys, bent by fits) and the user found it forced in almost every appearance — don't graft a motif onto another song's sections. SECTION CHANGES must not also be instrument changes (user: entry and exit felt strange): the winter melody is sung by the SAME voice as Tentacle's (`Part.note` adds the music box + pulse to `lead3`), Tentacle's chop (on the notes of winter's pad) and tresillo kick run under the whole winter section, winter's shimmer + high strings already play in the last 8 bars before the bridge and stay (fading) over the first 8 bars of the chorus that follows (with octave pulse/saw), and the section is levelled in the mix (`W_DB` −0.8). Boundary jumps (MFCC, 4 bars before vs after): motif→chorus 14.4 (−1.3 dB), final→bridge 25.3 (ordinary section changes: 15-31). MELODY VARIATIONS (`vary`, so it isn't tentacle_nes note for note; all derived from the melody itself): chorus = an ANSWER in the bars the melody leaves empty (27, 31, 35, 39): the previous bar's phrase in sequence a diatonic third down (pass 2: a sixth up), avoid notes snapped to the chord, never over an original note. The `vary` groups notes with `bar_strict` (no tolerance) ON PURPOSE: that is how the approved answers were built. Everything else uses `bar_of` with a 1/64-bar tolerance — the MIDI starts some notes a hair BEFORE the bar line, and the riff's first note of pass 2 counted as pass 1 and played alone in the bridge (the "missed dissonant note" at 1:33). The riff, scales and final stay as the original: riff mordents + octave-up bars were tried and the user found them odd. Strings swap to the root (or drop) when the lead rubs them. Break bell plinks have NO echo (winter's 3/16 echo on offbeat plinks sounded out of phase). Strength = sustained BODY, not louder drums: with the kick at +1.5 dB the crest factor was 11 dB vs winter's 9.7 and sections 1-2 dB weaker → kick +0.3, bass 0, pad −5, master −9.3 LUFS (no quiet stretches like winter's intro). Measured vs winter 85-116 (rms −10.5, 64 spectral peaks/frame, crest 9.7): sections −11.9…−10.7, 65-93 peaks, crest 9.9-10.7.
