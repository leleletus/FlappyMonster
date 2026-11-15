# Metronome Golem (Gólem Metrónomo)

The boss of **El Santuario del Compás** (`santuario_del_compas`, Free Play; the Starway family: [estelar-levels-2](../design/estelar-levels-2.md)).
Picked by the user from the five ideas on 2026-11-15 ("Haz el Gólem Metrónomo como jefe"). Built in 0.5.231.

## What it does

A stone metronome that FLOATS over the temple arena. Everything follows the level's BEAT CLOCK
(`src/world/systems/BeatClock.lua`: the music's position; 150 BPM here, a phrase = 8 beats = 3.2 s = one Beep Block switch).

| State | What |
|---|---|
| `hover` | CHASES the nearest player over the WHOLE arena (x within the zone minus 2.5 tiles; height so the weight passes through the player's body): 175 / 215 / 250 px/s by phase (the player runs at ~266), 170 px/s vertically. Its **pendulum** (rod 6.5 tiles + a gold weight) swings ONE SIDE PER BEAT: on every beat it is at an extreme (±4.4 tiles), half a beat later it passes underneath, through the player. The weight hurts (1). Phase 3: two sides per beat |
| `windup` | every `SLAM_EVERY` phrases (2, then 1 from phase 2), on **beat 5** of the phrase: tucks the pendulum away (one beat), rises a tile, lamp red, eyes angry, shaking; a TARGET mark appears on the surface UNDER THE PLAYER'S FEET and follows them until beat 8, then locks; it flies over the mark |
| `slam` | on **beat 1** — exactly when the Beep Blocks switch — it falls (5200 px/s²) onto THAT surface, smashing through whatever is above it: the crystal ledge, the real floor (also under a ledge), or the high Beep platform — like the Gummy King's belly flop. Beep Blocks count as floor whatever their state (it never falls into the pit). Under it: 2 and squashed. From phase 2, two crystal SHOCKWAVES run along that surface and stop at its edges (1; jump them) |
| `dazed` | on the surface 6 beats (phase 3: 5), lamp cracked, stars: the ONLY vulnerable window — stomp 1, ground pound 2, one hit per opening (`Boss:downTime`) |
| `rise` | 1.5 beats back up toward the player, the pendulum coming out again; then `hover` |

Landing on it while it floats only bounces (the Boss base). Phases by health: > 2/3 → 1; > 1/3 → 2 (wider swing,
shockwaves); else 3. Health 9 (+3 per extra player). Intro (generic, 3.4 s): it comes down from the ceiling and wakes
(`golemWake`). Death: the generic one of `Boss`.

## Same in the 3 places

The pendulum is a FUNCTION of the beat clock (`G:swingAngle(beats)`), so single player, the server and the client
compute it alike; the extra state in `netPackExtra` is `{ phase, landX, theta0·1000, wavesOn, landSurf, waveL, waveR }`
(the angle when it tucked the pendulum away, the slam x and surface, whether this slam has waves and where they stop).
Waves come from `landX` + the `dazed` timer.

**Tempo (0.5.232):** the level plays a normal level track (`estelar_pulsar`, 140 BPM: `beat.period` 3.4285714) and the
zone its own (`estelar_boss`, 150). The beat clock switches to the fight track's tempo while the zone fights — the
`bpm` of the track in `assets/music/index.json`, `BeatClock.periodNow` — and goes back to 0 with each change of track.
Contact: `G:interact` checks the weight and the waves first (`'hurt', 1, 'hazard'`, part `pendulum` / `wave`), then
`Boss.interact` — the Boss base does not look at hazard boxes (the first test caught the weight not hurting).
Online, the server's clock corrects the client's (`bt`).

## Files

- `src/world/entities/types/bosses/metrogolem.lua` — the boss (header = the design).
- Art: `tools/art/bosses/make_metrogolem.py` → `assets/images/bosses/metrogolem/` (body idle / lit / wind / dazed
  24x28 at ×8, rod, bob, wave). Preview `FlappyMonster_pruebas/metrogolem/vista_previa.png`.
- Sounds: `tools/sounds/metrogolem.py` → `assets/sounds/bosses/metrogolem/` (wake, wind, slam, wave, hurt, rise),
  catalog `assets/sounds/index.json` (`golem*`).
- Level: `assets/levels/santuario_del_compas.json` (the user's edit + the zone `{col 84, row 8, w 42, h 18, music
  "estelar_boss"}`, boss walls at the entrance (82-83) and in front of the finish (125), the Golem at col 104). The zone
  keeps the level's own music: the beat clock follows it.
- Texts: `boss.metrogolem`, `part.pendulum`.

## Tests

- `run.sh metrogolem_rules`: `pendulo`, `persigue` (on the floor and on a ledge: over the player, the weight at body
  height), `golpe` (it lands on the switch, on the mark, 2 of damage), `plataforma` (ledge / floor under a ledge / high
  Beep platform), `inmune`, `ondas`, `fases`, `tempo` (140 → 150 in the fight → 140), `red`.
- `run.sh boss_frames LEVEL=assets/levels/santuario_del_compas.json ZONE=1 STATES=hover,windup,slam,dazed,rise FROM=4`
  (the harness now runs the beat clock).
- `run.sh sp_boss LEVEL=assets/levels/santuario_del_compas.json SECS=30 FIGHT_SHOT=1`.
- `run.sh online_boss LEVEL=tools/tests/online_boss/santuario.json NOSHOTS=1 SECS=40` (a copy with the start next to
  the arena; regenerate it if the level changes).

Protocol 126.

## History

- 2026-11-15, second pass (0.5.232), the user after playing: "the arena is huge and the boss barely moves"; "it
  always slams to the bottom of the boss zone, NOT the floor" (with the zone made taller so the floor is seen, it fell
  into the spikes, and a ledge made you 100 % safe); "it should try to hit the player with its pendulum, with
  determination"; "a bit faster"; "like other bosses' slam, choose a platform, the real floor or another floor
  depending on where the player is"; the level's music must be a normal level track, not the boss one. → the chase,
  the landing on the player's surface, faster numbers, the per-zone tempo.
- 2026-11-15: built (0.5.231). Needs a person: the feel of the swing at 150 BPM, whether the slam on the switch reads,
  the difficulty, the look of the body (simple on purpose).
