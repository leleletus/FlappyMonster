# Crab Mashup battle (Mega Mashup de los Cangrejos) — the script

**Status: PLAN, nothing built yet.** The music exists (`crab_mashup`, `tools/music/crab_mashup.py`); this page is the
script the battle will be built from. Tick a milestone (`[x]`) in the same commit that does it and say in which
version. The user picks the open points at the end before work starts.

An EVENT fight: the four giant crabs — Mega Crabby (Tantrum), Mega Gloomy Crabby, Icy Mega Crabby and the Groove Crab
— take turns on one stage, **each one while its own theme plays**, and then all four at once in the finale. Like the
[Groove Crab](groovecrab.md), the clock is the song: every attack falls on a bar of the music. Only reachable from
**Free Play** for now (a level file that is not in any world of the story).

## The music map (the clock)

From `secciones_180bpm.json` (written by `crab_mashup.py`). Each crab plays at ITS tempo, so a bar is not always the
same length: the battle must read the map, never assume 180 BPM.

| Section | Crab | Bars | BPM | Seconds | What the music does |
|---|---|---|---|---|---|
| `intro` | — | 1-4 | 180 | 0.0-5.3 | tribal drums, the slap brings the riff cell (plays ONCE) |
| `tantrum_A` | Tantrum | 5-12 | 180 | 5.3-16.0 | theme A on the 3+3+2 tresillo |
| `tantrum_B` | Tantrum | 13-20 | 180 | 16.0-26.7 | the WAR CHANT (short repeated notes 3+3+2); a silent last beat |
| `gloomy_puente` | Gloomy | 21-28 | 144 | 26.7-40.0 | the LEGS alone (16ths), the riff in the bass, the voice answers at bar 5 |
| `gloomy_A` | Gloomy | 29-36 | 144 | 40.0-53.3 | hollow voice, half time, the PAUSE closing each phrase |
| `icy_B` | Icy | 37-44 | 180 | 53.3-64.0 | calm: soft voice, choir, music box |
| `icy_C` | Icy | 45-52 | 180 | 64.0-74.7 | the chorus: bells on the tresillo; a noise riser in the last bar |
| `groove_A` | Groove | 53-60 | 150 | 74.7-87.5 | its CLIMAX, first half: the slap riff, pops sparkle |
| `groove_B` | Groove | 61-68 | 150 (bars 7-8: 160, 170) | 87.5-100.0 | its climax B: the slap sings high; accelerates into the finale |
| `final` | ALL | 69-84 | 180 | 100.0-121.3 | E minor: war chant over the slap riff, legs underneath, music box on top (bars 9-16) |
| `coda` | ALL | 85-92 | 180 | 121.3-132.0 | D minor: chant again, the ♭VI–♭VII–i climb, last bar = STOP + la llamada |

The loop goes back to `tantrum_A` (the intro does not repeat). Loop = 126.6 s.

## The rules of the event

- **Four HP bars** (BossHud already draws several bosses: the Xtra pairs). A crab can only be hurt while it is ON
  STAGE, and it keeps its HP when it leaves.
- **Each crab keeps its own fight** — the same telegraphs and the same opening the player learned in its level
  (Tantrum: stuck after the ceiling drop; Gloomy: tired + flashlight; Icy: ground pound on a frozen claw; Groove: the
  golden note). Nothing new to learn per crab; what is new is that the music decides WHEN.
- **On / off stage**: a crab enters on the first beat of its section and leaves on the last one, whatever its HP. Off
  stage it waits in the BACKGROUND, on the Groove's stage behind the tiles (drawn with `Entities.renderBack`, like the
  crowd): it watches, bobs to the beat, cheers when a player is hurt.
- **A crab beaten in its section** is out (its own death, without leaving the arena: it sits in the background dazed).
  Its next sections become a BREATHER: 2-3 of its small kin (Crabbies / Gloomies / Icy Crabbies / Trampoline
  Crabbies, reserve placements like the Mega's `summons`) and the crowd.
- **Win**: all four bars at 0. If not, the song loops and the cycle starts again from Tantrum (with only the crabs
  still standing). The finale is where most fights should end.
- Pace: `def.pace = false` while conducted (the music is the pace, as the Groove). Xtra Extreme: NO second copy of
  each crab (`xtraStrip` / XtraBosses off for this level), they start enraged instead.
- Respawn inside the zone; the music never restarts on a respawn (the Groove's rule). Game over → the whole event
  restarts from the intro.

## The script, section by section

Bars below are counted inside each section (1-8). "Downbeat" = sixteenth 0.

### Intro (4 bars, players frozen: the boss intro cinema)

The stage lights come up; on each bar's downbeat ONE spotlight shows a crab silhouette in the background: Tantrum,
Gloomy, Icy, Groove (the same order they will fight). The name banner: "¡MEGA MASHUP DE LOS CANGREJOS!". On the last
beat Tantrum jumps from the background onto the stage.

### TANTRUM (16 bars, 180) — Mega Crabby

| Bars | Move (its own states) | Music cue |
|---|---|---|
| A 1-2 | chase | theme A enters |
| A 3-4 | windup on A3 beat 3, CHARGE on A4's downbeat | the cell rises |
| A 5-6 | wallclimb → wallaim → POUNCE lands on A6 beat 3 | the riff on B♭ |
| A 7-8 | ceiling climb → aim (follows the player) → DROP on B1's downbeat → **stuck = OPENING** | the tail ♭VI–♭VII |
| B 1, 3, 5, 7 | the WAR CHANT: on the chant's three hits (16ths 0, 3, 6) it SLAMS the floor — a sand wave each way (`BossWaves`) on each hit; jump them | D D D · F F G |
| B 2, 4, 6 | the fall of the chant: chase / claw snaps | A G F D |
| B 5 | summon 2 Crabbies (the chant goes "higher") | |
| B 8 | ceiling drop on beat 1 → stuck → on the silent last beat (the "breath") it jumps to the background | the breath |

Openings: 2 drops per section (stomp 1 / GP 2).

### GLOOMY (16 bars, 144) — Mega Gloomy Crabby

The lights go DOWN over the first two bars of the bridge (a darkness that fades in, `level.darkness` 0→1: new, see
the base work) and come back up during the last bar of `gloomy_A`. The flashlight works as in a dark level while the
darkness is above 0. Its one rule stays: **it only attacks where there is a red "!"**.

| Bars | Move | Music cue |
|---|---|---|
| bridge 1-4 | it is NOT seen: only its glow and the legs' sound crossing the ceiling (`climb` path) | the legs alone |
| bridge 5, 7 | ECHO PING on the downbeat (the ring) → "!" on whoever it touches → POUNCE on beat 3 | the voice answers with the cell |
| bridge 8, A 8 | the PAUSE (last beat, silence): it freezes mid-move, eyes blink — no attack | the spider's pause |
| A 1-6 | its normal fight on half time: player noises → CHARGE, close "!" → CLAW; ping every 2 bars | hollow voice |
| A 7 | ceiling ping → aim → DIVE on A8's downbeat | |
| after every charge / pounce / dive | tired: **lit by a flashlight = dazzled = OPENING** | |

### ICY (16 bars, 180) — Icy Mega Crabby

| Bars | Move | Music cue |
|---|---|---|
| B 1, 3, 5, 7 | CHARGE across on the downbeat | the soft voice's phrase |
| B 2, 4, 6, 8 | FROST CLAP on the downbeat → two floor waves (freeze) → clap_stuck: **frozen claw = OPENING** (GP 2) | the music box / choir |
| C 1-2, 5-6 | wall POUNCE → ICICLE FIELD where it lands (fields sprout on the bells' tresillo 0-3-6) | the chorus bells |
| C 3-4, 7 | clap + waves (two per bar on 7: the doubled chorus) | |
| C 8 | it slides out on the ice under the noise riser | riser |

### GROOVE (16 bars, 150 → 170) — Groove Crab

The section IS the Groove's own climax, so its fight plays as written in `GC.plan` for section `C`, bars 1-16:

| Bars | Move | Music cue |
|---|---|---|
| A 1, 3, 5, 7 | HOP: crouch with the mark, jump on 16th 8, land on the next downbeat → sand waves | the slap riff |
| A 2, 4, 6, 8 | NOTES on the bass pops (aim / fan / lob patterns) | pops + sparkle |
| A 8, B 8 | GOLDEN NOTE on the band hit (16th 12) → **send it back = knocked out = OPENING** (2 bars) | band hits |
| B 1-8 | DANCE FLOOR (light columns, 3-beat warning) + notes | the slap sings high |
| B 7-8 | the accelerando (160, 170): the floor patterns speed up with it | the ramp |

No DJ decks in the event (open point 3): the golden note is the opening in both phases.

### FINALE (16 bars, 180, ALL FOUR) — one job each

All crabs still standing come back on stage. To stay readable, each one does only ITS SIGNATURE move, tied to the
instrument that plays it:

| Crab | Instrument (always audible) | Its job in the finale |
|---|---|---|
| Groove | the slap riff, every bar | HOPS on odd bars, landing on the downbeat: sand waves |
| Tantrum | the war chant (bars 1, 3, 5, 7, 9…) | on the chant's three hits: ONE slam per bar (the last hit) — a wave; ceiling DROP on bars 8 and 16 → stuck = opening |
| Gloomy | the legs (16ths, underneath) | on the ceiling the whole time; a PING every 4 bars → "!" → claw from above; tired = opening (lights stay ON: the flashlight still dazzles it, for reachability) |
| Icy | the music box (bars 9-16, long notes) | each music-box note drops ONE icicle on the player's x, warned by the note (16 icicles); bar 12: one frost clap |

Waves of the Groove and of the Tantrum never land on the same sixteenth (the chant hits are 0-3-6, the Groove lands on
0: the Tantrum slams on 6 only). Fewer crabs alive = each remaining one adds back one move of its own section.

### CODA (8 bars, 180, ALL) — the last chance of the loop

| Bars | Move | Music cue |
|---|---|---|
| 1-4 | the conga: the crabs still standing cross the stage in a line, hopping one tile per beat (touch = 1 HP); jump over them or ride the Groove's trampoline | the war chant in D |
| 5, 6, 7 | ALL JUMP together on each downbeat → a triple wave on 7 (the big one) | the ♭VI–♭VII–i climb |
| 8 | THE STOP: band hit + la llamada over tribal drums → every crab still standing is DAZED for the bar (1.3 s) = **the shared OPENING**: one hit on any of them (GP 2) | la llamada |

Then the loop returns to Tantrum.

### Defeat

When the last bar reaches 0: the music cuts on the next downbeat (hard stop, the crowd boos the crabs), each crab
plays its own death in turn (Groove bursts, the Megas flee), the stage retracts like the Groove's, victory jingle.
No mirror shard (event).

## Arena and level

- New level **`mashup_cangrejos`** (to create, in `assets/levels/`): ONLY the arena (a short walk-in and the
  zone). Not in `Worlds`, so it is only reachable from Free Play. Zone music `crab_mashup`.
- Shape: the Groove's beach stage at night (flat floor for the hops and the dance floor), WALLS and a CEILING the Megas
  can climb (Tantrum and Gloomy need them), about the Groove arena's width. Arena generator
  `make_mashup_cangrejos.py` in `tools/levelgen/arenas/` (then `build.py --only mashup_cangrejos`; never without `--only`).
- The background: the Groove's stage and crowd (`groovecrab_stage.lua` pieces, moved to a shared stage drawer so both
  the Groove and the event use it), plus the waiting crabs.

## Base work first (golden rule 2: generic, in the base)

1. **`SongClock`** (new, in `src/world/systems/`): `where(t)` → section, bar, sixteenth from a map with a tempo
   per section and per-bar ramps. The Groove Crab moves to it (its `SONG` table becomes data; no behaviour change:
   `groovecrab_rules` must pass unchanged). The map is DATA written by the generator: `crab_mashup.py INSTALL=1`
   also writes a `crab_mashup.map.json` next to the track in `assets/music/bosses/` (sections, bars, BPM, ramps, start times) so the music and
   the battle can never disagree.
2. **Conducted bosses**: a Boss trait `conducted` — the AI timers stop and a conductor calls the crab's own
   attack entry points (`startCharge`, `startPounce`, `startCeiling`, `startPing`, `startClap`, `hop`…) at given
   song times. Each crab type exposes its entry points (most already exist as state transitions; the Mega's are
   timer-driven today and need small `begin*` functions). Plus `enterStage(spot)` / `leaveStage()` (jump to / from
   the background) and an "off stage" state that is drawn behind, not solid, not hittable.
3. **The conductor** (`types/bosses/crabmashup.lua`, invisible Boss that owns the zone fight): `songT`, which crab is
   on stage, the per-section SCRIPTS (tables like the ones above: bar → move — data, not code), the four HP bars,
   the breather spawns, the loop and the win.
4. **Darkness that fades**: `level.darkness` 0..1 (today `level.dark` is fixed at load) read by `Lights` and by the
   noise / flashlight rules; driven by the song clock (so it needs nothing new in snapshots).
5. **Falling icicle on a note** for the Icy's finale job: reuse the ceiling icicle dropper as a spawned hazard.

## Network

New entity type (the conductor) and new packed fields on the four crabs (on/off stage, conducted state) →
`Protocol.VERSION` + 1 and `version.txt`. The conductor sends `songT` like the Groove; everything else derives from
it. Levels with bosses are Race-only online.

## Tests

- New harness **`mashup_rules`** (row in `tools/tests/README.md`): the clock against the map (bar starts at every
  tempo change and in the ramp), who is on stage per section, each scripted move on its bar, HP kept between
  sections, the loop back to Tantrum, a crab beaten → breather, the coda's shared stun, the win.
- `boss_sim` / `boss_intro` / `online_boss` / `sp_boss` with `LEVEL=` the new level;
  `groovecrab_rules` after the `SongClock` move; `run.sh all`; `docs_reference` (new type + level).
- What needs a person: whether each section is readable at its tempo, the finale's chaos level, HP tuning.

## Milestones

- [ ] 1. `SongClock` + the map JSON from the generator + the Groove Crab moved to it (no behaviour change).
- [ ] 2. Level + arena + conductor + the TANTRUM section only, looping (a playable slice for the user to judge).
- [ ] 3. GLOOMY section + the fading darkness.
- [ ] 4. ICY section.
- [ ] 5. GROOVE section (its climax plan) + the shared stage.
- [ ] 6. FINALE + CODA + defeat.
- [ ] 7. Online, intro cinema, breathers, crowd reactions, HP tuning per difficulty.

## Open points (the user picks)

1. **Win condition**: (a) four HP bars, loop until all are down (proposed above); (b) survive one full loop and get a
   score / rank.
2. **Off stage**: (a) wait in the background watching (proposed); (b) leave the screen completely.
3. **The Groove's DJ decks** in the event: (a) no, the golden note in both phases (proposed); (b) yes, decks on
   platforms that appear only during its section.
4. **The finale**: (a) each crab keeps its own opening + the shared stun in the coda's last bar (proposed); (b) only
   the shared stun (simpler, more of a "survive the finale").
5. **Reward**: none for now / a best time in Free Play / something for the story later.
6. **Name** shown in Free Play and the banner: "Mega Mashup de los Cangrejos" / "Crab Mega Mashup"?

## History and decisions

- 2026-10-27: the music came first (0.5.57). Then the user disliked two parts — the Groove section ("it does not bring
  out the best part of its theme, a bit odd") and the move from the "all four" finale into the coda ("abrupt; the
  ending is bland and does not fit") — and asked for this script, Free Play only for now. The music was redone in
  0.5.58 (docs/audio/music-history.md): the Groove section is now its theme's CLIMAX, and the coda keeps all four
  playing in D minor and ends on a stop with la llamada. This script follows that version.
