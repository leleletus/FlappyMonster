# Starway: rhythm objects (proposal, 2026-11-14)

Status: **proposal, waiting for the user's pick**. For the level Starway / Vía Estelar (`via_estelar`), next to the
[beep blocks](beep-blocks.md). The user asked for objects, obstacles or enemies that do something (or let you do
something) to the rhythm of the music, like the beep blocks but **with other patterns**, so the level has variety.

## The clock they all share

Everything reads the same beat clock as the beep blocks (`level.beat.t`, the music's position: 120 BPM, beat 0.5 s,
bar 2 s, phrase 4 s = 8 beats, ×1.189 in the hurry). Proposed base (golden rule 2): a generic **rhythm trait** in the
entity base, `rhythm = { steps = 'x...x...', per = 'beat'|'eighth', offset = 0 }`: a pattern over a bar or a phrase;
the base calls `onBeat(step)` on the 'x' steps and gives `beatPhase()` for drawing. Each object below is then a
type with its own pattern and reaction, as data where possible. Server and single player run it from the clock;
clients draw it from the same clock (no new snapshot fields beyond `bt`).

For reference, the beep blocks are: **once per phrase** (beat 1), warned on beats 6-7-8.

## Proposals

Each one uses a DIFFERENT rhythm, so the player reads several layers of the song at once.

| # | Name (ES / EN) | Kind | Rhythm | What it does |
|---|---|---|---|---|
| 1 | **Plataforma metrónomo** / Metronome platform | platform | **every beat** (0.5 s) | Moves ONE tile per beat, in hard ticks (no smooth glide): e.g. 3 steps right, 3 back… The player rides it in time; jumping off on the tick is the trick. |
| 2 | **Pinchos de palmas** / Clap spikes | hazard | **beats 2 and 4** (the snare, every 1 s) | Spikes shoot out of a crystal plate on the backbeat and retract on the next beat. A short telegraph glint half a beat before. Cross between claps. |
| 3 | **Barrera de luz 3 contra 4** / 3-over-4 light gate | hazard | **every 3 beats** (polyrhythm against the 4/4) | A beam is ON for 1 beat, OFF for 2. It shifts against the bar every time, but its own 3-count never changes: learnable, not random. |
| 4 | **Trampolín de compás** / On-beat star spring | gadget (player rhythm) | **the player's timing** | Landing on it ON a beat (±0.1 s) launches HIGH with a sparkle; off the beat, a small hop. The reach to the next section needs the on-beat bounce. |
| 5 | **Cometa** / Comet | hazard | **once every 2 phrases (8 s), on beat 5** — the middle of the phrase, never on the block switch | A comet crosses a lane of the screen; on beat 1 of its phrase a faint trail line shows where it will pass. |
| 6 | **Gummy tambor** / Drum Gummy | enemy | **beats 1 and 3** (the kick) | Hops on the kick and lands on the next kick with a small shockwave along the floor (jump it). Stompable only while it is in the air, between kicks. |
| 7 | **Ascensor de síncopa** / Offbeat lift | platform | **the "and" of each beat** (offbeat eighths) | Rises a quarter tile on each offbeat for one bar, then drops back during the next bar. Feels "swingy" against the steady blocks. |
| 8 | **Puente de estribillo** / Chorus bridge | structure | **song sections** | Crystal tiles that EXIST only during section B (bars 21-36) and fade during the calm section C, back in A they are gone. A shortcut that opens once per loop (80 s); a beep-style warning on its last phrase. |
| 9 | **Estrellas en órbita** / Orbiting stars | hazard | **one turn per bar** (2 s) | 2-4 spiky stars orbit a centre, locked to the beat: on each beat they are at the same 4 compass points. Pass when the gap is on your side. |
| 10 | **Notas estelares** / Star notes | collectible | **8th-note pickups in a row** | A line of notes that light up one per beat in sequence; collect them while lit (on the beat) for a points combo. Points are only kept when the level is finished (golden rule 7). |

## Recommendation

Start with **4 or 5 that read differently**, building one section of the level around each:
- **1 Metronome platform** (every beat: the steady pulse),
- **2 Clap spikes** (backbeat: the snare),
- **6 Drum Gummy** (the kick: an enemy that dances),
- **8 Chorus bridge** (the song's form: changes the level once per loop),
- and **4 On-beat spring** as the "skill" moment.

Together with the beep blocks (once per phrase) the level layers pulse → backbeat → kick → phrase → song section.
3 (polyrhythm) and 9 (orbit) are good for a harder final stretch.

## Open questions for the user

1. Which ones (and is the recommended set right)?
2. Should the rhythm objects also blink/glint on their warning, like the beep blocks, or stay subtle?
3. Online: all of them work as above; the on-beat spring judges the beat from the player's predicted clock (the
   client) and the server allows ±0.1 s more. OK?
