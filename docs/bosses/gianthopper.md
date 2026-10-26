# Giant Hopper (Saltarín Gigante) — `gianthopper`

The Caves boss since 0.5.40 (it replaces Mega Gloomy Crabby on the world map; that one becomes a secret boss:
[new-bosses-plan](new-bosses-plan.md)). The cave Hopper — "the moth" ([enemies](../entities/enemies.md#hopper-saltarín))
— giant: the same 16x21 sheet (variant `cueva` of `assets/anim/enemies/hopper.json`) at scale 12, with its lantern.
Fought in the DARK. It is the opposite of the Gloomy (blind, hunts by sound): **it hunts by LIGHT and NOISE scares it**.
**File:** `src/world/entities/types/bosses/gianthopper.lua`. **Art:** the cave Hopper sheet + its rock shockwave
`assets/images/bosses/gianthopper/wave-Sheet.png` (`tools/art/bosses/make_giant_hopper.py`). **Sounds:** reused,
pitched down (`hopWind/hopJump/hopLand`, `lightOn/lightOff`, `gpImpact`, `stunned`); its own set is still open.
**Level:** `gruta_del_farol` "Gruta del Farol" / "Lantern Grotto" (`tools/levelgen/levels_boss.py`); arena
`tools/levelgen/arenas/jefe_saltarin.json` (`make_jefe_saltarin.py`). **Music:** its own theme `polilla` "La Polilla"
(`tools/music/polilla.py`; [music-history](../audio/music-history.md)). **Shard:** 6.
**Harnesses:** `gianthopper_rules`, `boss_sim` / `boss_intro` / `online_boss` / `boss_frames` with `LEVEL=` that arena,
`sp_boss LEVEL=assets/levels/gruta_del_farol.json`.

## The arena

"The lantern pit" (zone cols 12-35, rows 3-12, floor 13), dark: rock ceiling, drop-through platforms at the sides (row
8) and in the centre (row 6) — from up there a ground pound falls next to it — and two ROCKS 2 tiles high (cols 17 and
30): behind one, its flare and its lantern don't reach you (light is cut by solid blocks), and it hops over them.

## Behaviour

- **Sight** (`GH:sees`): only who has LIGHT, with a clear line from its lantern (`Lights.clear`, the same blocks that
  cut the flashlight): a player with the flashlight ON within `SEE_R` 16 tiles, or anyone inside its LANTERN (`LAMP_R`
  4.5 tiles) while it is lit. Lost from sight → it goes where it last saw them for `MEMORY` 4 s.
- **Hop** ('crouch' → 'hop'): seeing someone it crouches (`WIND_T` 0.8 / 0.6 s; the lantern flickers, a target mark
  follows the player, locked the last `LOCK` 0.2 s) and jumps onto the mark (≤ `HOP_REACH` 11 tiles: across the whole pit). The mark is the first surface at the
  target's height (`GH:aim`): on the floor, or ON the platform the player climbed (centre or side; only where its body
  fits under the zone ceiling), dropping through platforms if the target is lower. Landing: two ROCK WAVES along the floor, one each way (`WAVE_SPD` 430 px/s, stop
  at walls and edges; jump them: 1 HP + push). Touching it = 1 HP + push (`touch`, not from above).
- **Prowl**: seeing nobody it hops around in small hops (no mark, no waves) and, after `FLARE_EVERY` 7 / 5 s without
  seeing anyone, a **FLARE** ('flare_wind' 1 / 0.8 s: the lantern swells, flickers faster and hums → 'flare' 0.45 s:
  light over the whole arena, `FLARE_R` 12 tiles, cut by rocks). Whoever it lights, it has seen. Hide behind a rock.
- **Scare** (the ONLY opening): a LOUD noise (radius ≥ `LOUD` 6 tiles: ground pound, a kill, a hit, a block...; not
  a hurt player — that noise is tagged `from = 'hurt'` in `PlayerAdventure:takeDamage`) within `SCARE_NEAR` 7 tiles
  while it is on the ground (resting, crouching or charging a flare) → 'scared' (`SCARE_T` 2.6 / 2.0 s): lantern off,
  cowering and shaking, stun stars. Stomp 1 / ground pound 2, one hit per opening → 'hurt' (a jolt that shoves
  without damage, lantern back on). After a scare it can't be scared again for `SCARE_CD` 2.5 s. Noise made while it
  is in the air doesn't count. Flashlight = bait, noise = weapon — the moth's rules.
- **Rage** under `rageAt` (0.5): faster tables (`{ normal, rage }` pairs), flares more often, anger symbols, and it
  releases cave HOPPERS (moths; reserve entities, `def.summons`, `MOTH_POOL` 3, `summonKey gh<col>,<row>`) every
  `SPAWN_EVERY` 6 s while resting, up to `MOTHS` by difficulty (Easy 1, Normal / Hard 2, Extreme / Xtra 3). Killing
  one is a loud noise: near the boss, it scares it.
- HP 10 (+4 per extra player).

**Light:** `GH:lights()` from state + deadTimer (same online): the lantern (`LAMP_R`, warm), flickering in the hunting
crouch, swelling in 'flare_wind', the whole arena in 'flare', off when scared. It has `cast = true`: in dark levels
`Darkness` draws it ALL ROUND and cut by blocks (`castLight`, the same rays as `Lights.ray`), so what you see lit is
what it sees. The target mark, the waves, the front stars and the anger are drawn in `renderGlow` (over the dark).

**Intro** (3.4 s): falls from the dark at its editor spot, lands (shake), the lantern flicks on, it crouches.
**Defeat:** 'dying_out' (the lantern flickers out, stars, `OUT_D` 2.4 s) → 'dying_flee': a crouch and one huge leap
UP through the ceiling (no collisions, a pure function of time: `FLEE_VX/VY/G`), out of view; shard at `THROW_T`;
its hoppers burst.

**Network:** netPackExtra `{rage, hunting, markX, markY, nWaves, waves {id, x, y, dir, t}…}`. Protocol 67.

## History and decisions

- 2026-10-26: the user asked for it to be built "like the Giant Pufferfish": its OWN level (`gruta_del_farol`), with
  `gruta_lugubre` kept in the game; the world map uses the new one for the caves. The design follows the moth the
  user picked for the small cave Hopper ("Polilla": hunts by light, noise scares it). Not played by the user yet.
- 0.5.41: the user: "it should jump farther (if the player climbs a platform, it should be able to jump there too)" —
  `HOP_REACH` 7 → 11 tiles and `GH:aim` scans from the target's height (before, it only looked from its own head down,
  so it never landed on a platform); harness case `plataforma`. And its own music, `polilla`, replaces the provisional
  `crab_tantrum_gloomy`.
