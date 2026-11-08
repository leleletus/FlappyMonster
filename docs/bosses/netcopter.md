# The Net-Copter (`netcopter`)

The Valley's boss, the first boss of the Flappy campaign (zone 1): a junk machine — a patched balloon, a wooden gondola
and a pedal propeller — that the Evil Monster pedals among the pillars. Names: «REDCÓPTERO» in Spanish, «NET-COPTER»
in English (`boss.netcopter`). Flappy levels only (`flappyOnly`, category `Flappy`): the player flies
([player § Flight](../gameplay/player.md#flight-flappy-levels)). Plan and binding design:
[flappy-plan-5-netcopter](../design/flappy-plan-5-netcopter.md); the polish after the user's first play:
[flappy-plan-5c-netcopter-polish](../design/flappy-plan-5c-netcopter-polish.md).

Try it: `love . --editor tools/levelgen/arenas/NetcopterArena.json`, then play from the editor.

## Files

| File | What |
|---|---|
| `src/world/entities/types/bosses/netcopter.lua` | the boss (tuning table `T` at the top: every number below) |
| `src/world/entities/types/traps/netshot.lua` | its net (`netshot`, a reserve minion) |
| `src/world/entities/types/traps/glowbomb.lua` | its glowing bomb (`glowbomb`, a reserve minion; the `reflectable` trait) |
| `tools/art/bosses/make_netcopter.py` | art (`--apply` → `assets/images/bosses/netcopter/`, all ×6) |
| `tools/levelgen/arenas/NetcopterArena.json` | test arena: 40x11 Flappy, zone columns 17-36 (full height), music `tuffi`, Valley sky; no floor (Plan 5d: a pillar hangs at column 9, rows 1-3, another rises from the bottom edge at column 13, rows 8-11); by `tools/levelgen/arenas/make_netcopter_arena.py` (hand-made before Plan 5d) |
| `assets/levels/valle_redcoptero.json` | its campaign stage (zone 1's `boss`), by `tools/levelgen/levels_flappy_valle_boss.py` ([flappy-campaign § Boss stages](../gameplay/flappy-campaign.md#boss-stages-plan-5)); no floor and the Valley sky, like the other Valley stages (Plan 5d) |

Art lives in `assets/images/bosses/netcopter/` (all drawn at ×6, the player's pixel). Sheets (frame size, frames):

| Sheet | Frame | What |
|---|---|---|
| `machine-Sheet` / `machine_popped-Sheet` | 44x54 ×3 / ×2 | balloon + gondola; the 3 frames sway the balloon 0 / +1 / -1 px; `popped` is phase 2 (burst balloon), its 2 frames flap |
| `propeller-Sheet` | 12x18 ×4 | the pedal propeller (spins; faster while crossing) |
| `cannon-Sheet` | 18x12 ×2 | the cannon (frame 2 = glowing before firing) |
| `cannon_arm-Sheet` | 3x12 ×3 | the iron arm bolted to the gondola: clamp (12 px from the cannon corner), bar (1 column, repeated), plate at x 9..11 |
| `claw-Sheet` | 54x14 ×3 | closed, half open, open; claw head on the left; the arm is lengthened by repeating its 9-px slice from x 36 (was the single-frame `claw` until round 2) |
| `pilot-Sheet` | 9x16 ×4 | pedal1, pedal2, (3 = an old laugh frame, no longer drawn, see History), hurt |
| `pilot_laugh-Sheet` | 9x16 ×2 | blank head, hands up (A) / head 1 px lower, hands down (B) |
| `joy_eyes` | 5x2 | the «^ ^» laughing eyes painted over the blank head (see below) |
| `pilot_angry` | 11x16 | fist raised, 2 columns wider to the left |
| `pilot_flee-Sheet` | 36x30 ×2 | the escape on the plank with a broken propeller |
| `net-Sheet` | 24x24 ×5 | ball, half-open, open, open turned 30° and 60° |
| `bomb-Sheet` / `mark-Sheet` | 14x18 ×2 / 12x12 ×2 | the bomb (fuse) and its landing mark (four pulsing corners) |
| `puff-Sheet` / `spark-Sheet` | 8x8 ×6 / 7x7 ×3 | smoke (1-3) and net threads (4-6) / hit sparks |
| `parts` | 14x14 ×4 | balloon, plank, blade, cannon: the pieces that fall apart on defeat |
| `net` | 16x16 | the open net, still: only the level editor's icon for `netshot` (`editor.sprite`); the game draws `net-Sheet` |

Anchors in the 44x54 machine frame (its centre = the entity's x, y): balloon y 0..25; gondola x 12..32, y 43..52, with
an iron handlebar at y 39; pilot (9x16: the player's body, `player/monstrito1.png`, with the antennae and head of
`miniboss1/monster/Idle1.png`) top-left at (18, 27), standing on the gondola rim with its hands on the handlebar;
propeller top-left at (32, 37); cannon (18x12) top-left at (-12, 42) unfolded, folded behind the gondola at (14, 42),
hanging from its arm; the claw comes out of the gondola at its middle height. The art faces LEFT; facing right the
whole machine is drawn mirrored around x.

## The fight

Hp 12 + 4 per extra player (`bossHp` scales it: 11 at Normal, 14 at Extreme). Phase 2 at ≤ 50 %: the balloon pops
(`machine_popped`, `balloonPop` + `bossExplode`). States: `dormant → intro → ready → hover ↔ aim_net → [phase 2] sweep_warn → sweep → …
→ dying_hold → fleeing → dead`.

- **Patrol** (`hover` ↔ `cross`): it keeps a SIDE (the right or the left third of the zone, starting on the right)
  attacking for `HOLD` s (7 s, 5 s in phase 2; the first side 5-8 s by `rollStart`), its cannon mouth following the
  nearest player's height with a 0.8 s lag (0.5 s in phase 2, and 0.75 tiles lower), swaying ±0.5 tiles, never leaving
  the zone (balloon below the top, gondola above the floor). Then it CROSSES to the other side (`cross`, 1.8 s, along the
  top strip, no attacks; its body still hurts: −1 and a push downwards, away from it) and TURNS: it faces where it
  goes while crossing and flips at once halfway through the last `TURN_T` (0.2 s) of the cross (`drawFace`; no
  squash, the art pixel never changes size). `facing` is always towards the middle of the zone, and the cannon, the
  net, the bomb throw, the claw and the body push all follow it. At least 0.6 s after crossing until the next net.
- **Net** (`aim_net`): the cannon (on its arm, 12 px out from the gondola) glows 0.6 s (`cannonFuse`), then fires
  (`netFire`, a 0.12 s recoil of 1 px, smoke and threads at the mouth for 0.3 s) a net in the direction it faces at
  520 px/s that settles in 0.3 s to the player's height at the moment of firing. In flight it UNFURLS (ball → open) and
  then SPINS (frames 3-4-5, reversed when it goes right). Hit: −1 and `ctrlLock` 0.4 s (`Boss.strike`), the open net
  WRAPS the player while the lock lasts (`netSnare`), drawn IN FRONT of the monster (`Net:drawsInFront`, from its
  `state`, so the online client draws it the same), then it is spent. Caught on a pillar or solid it comes apart in
  threads (`netSnag`). Phase 2: a spread of 3 (the side ones drift ±150 px/s). Next net after 2.2-3.2 s (1.5-2.3 in
  phase 2).
- **Glowing bomb:** on its own clock (every 6 s ± 1, 5 s in phase 2; never while crossing). It is LOBBED (`bombLob`)
  from the top of the gondola in a ballistic arc (`BOMB_G` 900 px/s²) to where the player was at the throw, the apex
  2.5 tiles above the player's head; a blinking MARK shows the landing spot from the throw. It explodes (−1 within a
  tile; the blast also breaks breakable blocks within a tile) when it touches a player who is not rising, a pillar or a
  solid, or reaches the BOTTOM: its boss zone's bottom edge or the level's, whichever is higher (`GlowBomb:bottomY`;
  Flappy levels have no floor since Plan 5d). A player flying RISING into it sends it back (`reflectable`, `owner` = the boss) in a straight line
  at 700 px/s: **2 damage** to the boss, with sparks. Pillars are `enemySolid`: they STOP both nets and bombs (so the
  short pillars in the arena are real cover). On defeat, falling bombs and nets are spent without damage. See
  `glowbomb.lua`.
- **Claw** (phase 2, every second attack): `sweep_warn` 0.8 s (`clawServo`) — the band (the claw's height, 84 px) is
  fixed at the player's height when it starts and marked by blinking target marks; the machine moves so the gondola
  lines up. The claw slides out of the gondola (`CLAW_OUT_T` 0.2 s) to its READY spot (`CLAW_REST`: the head just past
  the cannon's mouth, which is at the same height) CLOSED, and OPENS at 0.3 s (`clawOpen`; half-open frame 0.1 s). Then
  `sweep`: the open claw goes out across the zone, towards where it faces, to the far edge in 1.0 s, SNAPS SHUT there
  (`clawSnap`, sparks; half-closed frame the last `SNAP_T` 0.08 s) and comes back closed in 0.6 s; −2 inside the band
  (arm included), nothing outside it. The frame comes from `state` + `deadTimer` (`clawFrame`); the drawing is cut at
  the gondola's back edge so the arm never pokes out behind the machine.
- **Alive** (all derived from `state`, `deadTimer`, x, y, `facing`, `netPackExtra`): the propeller spins (4 frames,
  faster crossing), the balloon sways, the legs pedal at their own rate; after a hit: sparks, hurt 0.2 s then ANGRY
  (raised fist) 0.6 s; phase 2: smoke leaves the burst balloon; each hit shakes the screen (fx `shake_tick`, 0.15 s).
- **Laugh** (intro, and 1.2 s whenever a player dies, without stopping the fight): like the Mirror's — the head
  turns blank (`pilot_laugh-Sheet`) and `joy_eyes` «^ ^» are drawn over it; the head goes up and down every 1/6 s.
  The eyes are drawn at the BOSS pixel size (×6, a 5x2 sprite), not the Mirror's half-size cell (pixel-density rule).
- **Vulnerable always** while fighting (no stun windows): the special attack (damage = the charge spent; it hits the
  whole outer box, balloon included) and returned bombs (they fly at `aimPoint()` = the gondola's centre and hit the
  whole outer box); `Boss.INV_TIME` after each hit. **Never stomped:** `interact` returns nil. **Only the CABIN hurts
  on contact** (`contactBoxes()`: the gondola, art 12..31 x 43..52, and the pilot standing on it, 18..26 x 27..42,
  mirrored around x with `drawFace`; red F1 boxes): touching it costs 1 HP and a push towards `facing` (towards the
  middle; while crossing, downwards and away from it) (`Boss.strike`, checked in `updateBoss`). The balloon, the
  ropes, the propeller and the cannon never hurt. Not a solid body.
- **Entry** (3.5 s): pedals in from the right (2 s, `miniAppear`), laughs at 2.1 s (`mirrorLaugh`), unfolds the cannon
  at 2.6 s (`cannonLoad`).
- **Sounds** (`tools/sounds/netcopter.py` → `assets/sounds/bosses/netcopter/`, [sound](../audio/sound.md)): `netFire`,
  `netSnare`, `netSnag`, `bombLob`, `balloonPop` (phase 2), `clawServo`, `clawOpen` and `clawSnap` (once per claw
  attack each), plus the rate-limited ambience `pedalSqueak`
  (0.7 s, 0.4 s crossing), `propWhir` (0.55 s / 0.35 s) and `leakHiss` (phase 2, 1.8 s). Still reused: `cannonFuse`,
  `cannonLoad`, `miniAppear`, `mirrorLaugh`, `gustBlow`, `bossExplode`, `megaFlee`.
- **Defeat:** the generic `dying_hold` (explosions, the pilot's hurt face) and then, instead of falling, `fleeing`
  (`onDeathFall`): the balloon, the plank, a blade and the cannon fall apart and the Evil Monster pedals away to the
  right on a plank with a broken propeller (`pilot_flee`, 240 px/s) — it does NOT die (it comes back at every zone).
  `releasesZone()` from `fleeing`, so the zone is `cleared` at once; `dead` when it is past the zone and no player sees
  it (`Boss:fleeOver`). Nets in the air vanish at the defeat.
- `rollStart`: the first net (1.2-2.8 s), the first bomb (2.5-5 s), how long it holds the first side (`HOLD_FIRST`,
  5-8 s), a start height offset (±1.5 tiles, released over 2 s) and which attack comes first in phase 2.
- **Respawn** (dying in the fight): in the AIR (falling out of the bottom edge hurts in flight) at a third of the zone, on the side AWAY
  from the boss: `BossZones.flightX` picks the third farther from `Boss:respawnAvoidX()`, which the Net-Copter
  overrides with its side's x, or while crossing its destination (`crossX1`). If it respawns while the machine is
  crossing over that third, the body passes overhead within the respawn invulnerability (`SPAWN_INV` 2.5 s >
  `CROSS_T` 1.8 s) and then holds the far side.

**Net:** `netPackExtra` = laughing, band y, claw reach, flee start x, y, `facing`, `shotT` (recoil and mouth smoke);
the phase comes from hp / hpMax. Flappy levels
are not online: no `Protocol.VERSION` change (ruling R2 of the plan).

## Tests

`tools/tests/run.sh netcopter_rules` (33 cases: the bomb and drop cases `rebote`…`ultima_vida`; the fight `vida`,
`fase2`, `especial`, `no_pisa`, `red` (+ `netSnare`, the wrap drawn in front), `garra`, `huye`, `bomba`, `azar`,
`paquete`, `etapa_jefe`, `muerte_en_pelea`, `pilar` (+ `netSnag`), `red_repetida`, `derrota_bombas`; plan 5c:
`lanzada`, `devuelta_arco`, `cruza`, `mira_izq`, `cruce_justo`, `risa`, `dibujo` (+ the turn flip), `ruido`
(+ `balloonPop`), `reaparece_lejos`; round 2: `cabina` (only the cabin hurts; the burst hits the balloon; the returned
bomb aims at the gondola), `garra_anim` (claw frames and `clawOpen` / `clawSnap` once each); `no_pisa` now checks
both the balloon (nothing) and the pilot (−1)); `flappy_flight ataque` (the burst's direction); `boss_intro LEVEL=tools/levelgen/arenas/NetcopterArena.json` (its `reaparece`
case accepts the air respawn of Flappy levels and requires ≥ 2 tiles from the boss and from where it holds — while it
crosses, from its destination);
`boss_frames LEVEL=tools/levelgen/arenas/NetcopterArena.json FX=1 ZONE=1
STATES=intro,hover,aim_net,sweep_warn,sweep,dying_hold,fleeing` (a special hit every 3 s to see it all);
`boss_frames LEVEL=tools/levelgen/arenas/NetcopterArena.json FX=1 HOVER=1 ENTSTATE=netshot:wrap EVERY=0.1` (a net
wrapping the player, drawn in front of it); `boss_frames LEVEL=tools/levelgen/arenas/NetcopterArena.json FX=1 RAGE=1
ZOOM=2.4 STATES=sweep_warn,sweep EVERY=0.1` (the claw opening; `ZONE=1` for the whole arena with its floor). Round 2
capture: `/home/mtvemo/FlappyMonster_pruebas/redcoptero/ronda2.png`.

**Not judged yet** (needs the user): the feel and timings of the patrol, the lobbed bomb and the nets; the whole
plan 5c art (arm, laugh, angry frame, smoke, sparks); the eleven own sounds (verified by numbers only, never listened
to); round 2: whether one more row of air is enough room, the claw's three frames and timing, the cabin-only contact.

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
- 2026-11-08, the user on the first art: the design is good, but (1) the balloon's patches must look like patches
  without raising the sprite's resolution → each patch is a different fabric (denim, burlap) with a dark border and
  alternating light thread stitches, a little crooked; (2) the Evil Monster must have the WHOLE body → he is the
  player's body (neck, arms, dark torso with its shade, legs) with only his own antennae and head from `Idle1` (`hurt`
  for the hurt frame), at the player's pixel size; the stick figure on the `Idle1` grid was wrong. To fit him standing
  between the balloon and the gondola the frame grew from 44x40 to 44x54 (longer ropes); the hitbox is still
  0.75 x 0.9 of the frame. Preview `/home/mtvemo/FlappyMonster_pruebas/redcoptero/vista_previa.png` (with
  `monstrito1` beside the pilot frames).
- Hp prop 12 is the base; the difficulty's `bossHp` scales it (Normal 11, Extreme 14 with the extra-player bonus).
- The Evil Monster flees instead of dying: he comes back in every zone.
- 2026-11-08, the user after playing 0.5.176 (6 points): (1) the bomb is useless: it only falls to the floor, never
  hits the monster and can almost never be returned; (2) the machine must not stay still: it moves from the left side
  to the right side too, and turns; (3) the nets have no sound, no effect and no spin, they don't look like nets;
  (4) the cannon is not really attached to the machine; (5) more sounds, effects and animations: it should feel alive,
  a good boss fight; (6) the Evil Monster's laugh like the Mirror's (blank face + laughing-eye sprites).
- Plan 5c decisions ([plan](../design/flappy-plan-5c-netcopter-polish.md)): the bomb is lobbed in an arc to the
  player's position with a landing mark and an apex 2.5 tiles over the head (returnable by a rising player, 2 damage);
  the machine patrols between the two thirds of the zone, crosses along the top strip and turns, everything follows
  `facing`; nets unfurl, spin, wrap the player and snag on pillars; the cannon hangs from an iron arm and recoils;
  alive = propeller, sway, pedal, sparks, angry frame, smoke in phase 2, hit shake; the laugh is the Mirror's, with
  the eyes at the boss pixel size (×6) and not at the Mirror's half-size cell (pixel-density rule); nine own sounds
  instead of the reused placeholders.
- Ruling R2: no `Protocol.VERSION` change (Flappy is not online). R4: air respawn in Flappy boss fights.
- 2026-11-08, the user after playing 0.5.177 (round 2, 4 points): (1) "the hitbox that hurts the player is too big,
  it should only be the central cabin (not the balloon)"; (2) "the monster's attack only goes right: when the boss
  changes side it shoots at nothing; make the shot go where it is moving or last moved (like throwing things)";
  (3) "the mechanical arm lacks an opening / closing sound and animation"; (4) "lower the floor: it is too high and
  gets in the way of the fight".
- Round 2 decisions: (1) contact damage only from `contactBoxes()` (gondola + pilot); the burst and the returned bomb
  still hit the whole outer box (a big target for the player's own attacks), and the returned bomb aims at the
  gondola (`Entity:aimPoint`, a new base hook). (2) the burst follows the player's `facing`, the rule Carry already
  uses for throws; in flight `facing` = the last non-zero horizontal input (starts right), and the sprite flips with
  it ([player](../gameplay/player.md#flight-flappy-levels)). (3) `claw-Sheet` with 3 frames + `clawOpen` / `clawSnap`;
  the claw now waits CLEAR of the cannon (`CLAW_REST`): at its old spot it was hidden behind the cannon and its opening
  could not be seen. (4) the floor goes to the level's last row (grass only, no dirt row) in `valle_redcoptero` and
  `NetcopterArena`: 10 air rows instead of 9. The level stays 11 rows (704 px): the screen is 720 px tall, so a 12th
  row would need vertical scrolling and would hide the ceiling or the floor; one row is the most the fixed camera
  allows without changing the level height. The arena's short pillars keep their height (the floor one moved down
  with the floor).

## History

- 2026-11-08, the user after 0.5.178: **approved** ("queda aprobado"). The fight, art and sounds stand as built.

- 2026-11-08 (Plan 5, task 4): first version (provisional art, reused sounds).
- 2026-11-08, second art pass after the user's verdict: stitched patches, full-body pilot, 44x54 frame.
- 2026-11-08 (Plan 5, task 5): the campaign stage `valle_redcoptero`; ruling R4: dying in a Flappy boss fight respawns
  in the air (it respawned standing on the floor, which costs 1 HP in flight).
- 2026-11-08 (Plan 5c, tasks 1-3): lobbed bomb + mark, patrol / cross / turn with facing, net unfurl / spin / wrap /
  snag, cannon on an arm with recoil, alive animation, Mirror-style laugh, nine sounds, `shake_tick`.
- 2026-11-08 (Plan 5c, task 4): docs; `boss_intro`'s `reaparece` case made Flappy-aware (Flappy levels respawn in
  the air, `BossZones.respawnPoint` → `Level:flightSpot`; the ≥ 2 tiles from the boss rule applies to Adventure only,
  since the air spot is fixed at the left third and the patrol also holds that side).
- 2026-11-08 (Plan 5c, final review fixes): the Flappy respawn went to the LEFT third always, so with the patrol it
  often respawned next to the boss holding the left side → `BossZones.flightX` + `Boss:respawnAvoidX` (the side
  away from where the boss holds or is going); `boss_intro`'s ≥ 2 tiles check is back for Flappy. The turn squashed
  the machine to half width for 0.2 s (breaks the one-pixel-size rule) → it flips at once halfway (`drawFace`). The
  wrapping net was drawn behind the monster → in front (`Entity:drawsInFront`, a base hook derived from what travels
  in snapshots; the renderers use it instead of reading `renderFront` directly).
- 2026-11-08 (round 2, after the user's 4 points above): cabin-only contact damage, burst direction from `facing`,
  claw open / snap animation and sounds, the floor one row lower. `boss_frames` now draws the whole level for its
  zoom (with `ZONE=1` the floor was cut off: the level culls its tiles to the game window). `project_check` no longer
  reads `server/published/` (the last published copy, which still names deleted assets until the next deploy).
- `pilot-Sheet` frame 3 (the old laugh with an open mouth) is no longer drawn by the boss; it stays in the sheet
  because the hurt frame is read by index (4) by the game and the generator preview.
