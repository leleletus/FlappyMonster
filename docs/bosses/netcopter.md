# The Net-Copter (`netcopter`)

The Valley's boss, the first boss of the Flappy campaign (zone 1): a junk machine — a patched balloon, a wooden gondola
and a pedal propeller — that the Evil Monster pedals among the pillars. Names: «REDCÓPTERO» in Spanish, «NET-COPTER»
in English (`boss.netcopter`). Flappy levels only (`flappyOnly`, category `Flappy`): the player flies
([player § Flight](../gameplay/player.md#flight-flappy-levels)). Plan and binding design:
[flappy-plan-5-netcopter](../design/flappy-plan-5-netcopter.md).

Try it: `love . --editor tools/levelgen/arenas/NetcopterArena.json`, then play from the editor.

## Files

| File | What |
|---|---|
| `src/world/entities/types/bosses/netcopter.lua` | the boss (tuning table `T` at the top: every number below) |
| `src/world/entities/types/traps/netshot.lua` | its net (`netshot`, a reserve minion) |
| `src/world/entities/types/traps/glowbomb.lua` | its glowing bomb (`glowbomb`, a reserve minion; the `reflectable` trait) |
| `tools/art/bosses/make_netcopter.py` | art (`--apply` → `assets/images/bosses/netcopter/`, all ×6) |
| `tools/levelgen/arenas/NetcopterArena.json` | test arena: 40x11 Flappy, zone columns 17-36 (full height), music `tuffi` |
| `assets/levels/valle_redcoptero.json` | its campaign stage (zone 1's `boss`), by `tools/levelgen/levels_flappy_valle_boss.py` ([flappy-campaign § Boss stages](../gameplay/flappy-campaign.md#boss-stages-plan-5)) |

Anchors in the 44x40 machine frame (its centre = the entity's x, y): gondola x 12..32, y 29..38; pilot (26x21, the
Evil Monster's `Idle1` grid) top-left at (9, 16); cannon (18x12) top-left at (-6, 28) unfolded, folded behind the
gondola at (12, 28); the claw (54x14, head on the left) comes out of the gondola at its middle height; the arm is
lengthened by repeating its 9-px slice from x 36.

## The fight

Hp 12 + 4 per extra player (`bossHp` scales it: 11 at Normal, 14 at Extreme). Phase 2 at ≤ 50 %: the balloon pops
(`machine_popped`, `gustPop`). States: `dormant → intro → ready → hover ↔ aim_net → [phase 2] sweep_warn → sweep → …
→ dying_hold → fleeing → dead`.

- **Hover:** in the right third of the zone (x = right edge − 1/6 of the width, swaying ±0.5 tiles), its cannon mouth
  following the nearest player's height with a 0.8 s lag (0.5 s in phase 2, and 0.75 tiles lower), never leaving the
  zone (balloon below the top, gondola above the floor).
- **Net** (`aim_net`): the cannon glows 0.6 s (`cannonFuse`), then fires (`cannonWhoosh`) a net left at 520 px/s that
  settles in 0.3 s to the player's height at the moment of firing. Hit: −1 and `ctrlLock` 0.4 s (`Boss.strike`), the
  net vanishes. Phase 2: a spread of 3 (the side ones drift ±150 px/s). Next net after 2.2-3.2 s (1.5-2.3 in phase 2).
- **Glowing bomb:** on its own clock (every 6 s ± 1, 5 s in phase 2), also while attacking: dropped from the gondola
  with `owner` = the boss. Hit while RISING in flight → it flies back: **2 damage** to the boss; otherwise it explodes
  (−1 within a tile; the blast also breaks breakable blocks within a tile). Pillars are `enemySolid`: they STOP both
  nets and bombs (so the short pillars in the arena are real cover). On defeat, falling bombs and nets are spent
  without damage. See `glowbomb.lua`.
- **Claw** (phase 2, every second attack): `sweep_warn` 0.8 s — the band (the claw's height, 84 px) is fixed at the
  player's height when it starts and marked by blinking target marks; the machine moves so the gondola lines up. Then
  `sweep`: the claw goes out to the zone's left edge in 1.0 s and back in 0.6 s; −2 inside the band (arm included),
  nothing outside it.
- **Vulnerable always** while fighting (no stun windows): the special attack (damage = the charge spent) and returned
  bombs; `Boss.INV_TIME` after each hit. **Never stomped:** `interact` returns nil; touching its body costs 1 HP and a
  push to the left (`Boss.strike`, checked in `updateBoss`). Not a solid body.
- **Entry** (3.5 s): pedals in from the right (2 s, `miniAppear`), laughs at 2.1 s (`mirrorLaugh`), unfolds the cannon
  at 2.6 s (`cannonLoad`). It also laughs when a player dies.
- **Defeat:** the generic `dying_hold` (explosions, the pilot's hurt face) and then, instead of falling, `fleeing`
  (`onDeathFall`): the balloon, the plank, a blade and the cannon fall apart and the Evil Monster pedals away to the
  right on a plank with a broken propeller (`pilot_flee`, 240 px/s) — it does NOT die (it comes back at every zone).
  `releasesZone()` from `fleeing`, so the zone is `cleared` at once; `dead` when it is past the zone and no player sees
  it (`Boss:fleeOver`). Nets in the air vanish at the defeat.
- `rollStart`: the first net (1.2-2.8 s), the first bomb (2.5-5 s) and a start height offset (±1.5 tiles, released
  over 2 s).

**Net:** `netPackExtra` = laughing, band y, claw reach, flee start x, y; the phase comes from hp / hpMax. Flappy levels
are not online: no `Protocol.VERSION` change (ruling R2 of the plan).

## Tests

`tools/tests/run.sh netcopter_rules` (cases `vida`, `fase2`, `especial`, `no_pisa`, `red`, `garra`, `huye`, `bomba`,
`azar`, `paquete`, `etapa_jefe`, `muerte_en_pelea`, `pilar`, `red_repetida`, `derrota_bombas`, besides the bomb and drop cases); `boss_intro LEVEL=tools/levelgen/arenas/NetcopterArena.json`;
`boss_frames LEVEL=tools/levelgen/arenas/NetcopterArena.json FX=1 ZONE=1
STATES=intro,hover,aim_net,sweep_warn,sweep,dying_hold,fleeing` (a special hit every 3 s to see it all).

**Not judged yet** (needs the user): the feel, the timings, the looks (the art is provisional: the pilot reads small on
the wide machine) and the reused sounds.

## SP / server / client

Single player only: Flappy levels are not online yet (project 3), so nothing here is simulated by the server or sent
in snapshots beyond the `netPackExtra` above, kept so the boss is already ready for it. The simulation never touches
`love.graphics` outside render functions (rule 1).

## How to extend

Another Flappy boss: [how-to-add-a-boss](how-to-add-a-boss.md) with `flappyOnly`, a generator like
`levels_flappy_valle_boss.py` (`flappy_lib.boss_arena`) and the id as the zone's `boss` in `Zones.LIST`. Retune the
fight in the `T` table of `netcopter.lua`. A new reflectable projectile: the `reflectable` trait
([entities/overview](../entities/overview.md)).

## Decisions

- 2026-11-08, the user approved the Net-Copter as proposed ([plan](../design/flappy-plan-5-netcopter.md)).
- 2026-11-08, the user: `tuffi` is really the FINAL battle's theme and may later be reworked with Evil Monster motifs;
  until the Flappy bosses have music of their own, all use it.
- The art is PROVISIONAL, applied before the user's verdict (preview
  `/home/mtvemo/FlappyMonster_pruebas/redcoptero/vista_previa.png`).
- Hp prop 12 is the base; the difficulty's `bossHp` scales it (Normal 11, Extreme 14 with the extra-player bonus).
- The Evil Monster flees instead of dying: he comes back in every zone.
- Ruling R2: no `Protocol.VERSION` change (Flappy is not online). R4: air respawn in Flappy boss fights.

## History

- 2026-11-08 (Plan 5, task 4): first version (provisional art, reused sounds).
- 2026-11-08 (Plan 5, task 5): the campaign stage `valle_redcoptero`; ruling R4: dying in a Flappy boss fight respawns
  in the air (it respawned standing on the floor, which costs 1 HP in flight).
