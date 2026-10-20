# The Mirror chase — `mirrorchase` and `huida_del_espejo`

The level before the final boss: an auto-scroll run through the volcano while the Reflection roams the screen,
attacks and PUSHES you toward the edge that kills. It is not a fight: it cannot be hurt and has no zone, bar or shard.

**Current behaviour (v3 + the 3.82.0 tuning):** it walks and jumps freely around the player, switching sides; its
attacks (pounce, dash across the screen, dive from a floating mirror, shove) take 1 HP and push; merely touching it
while it walks only pushes. Everything it does runs at `SLOW` 0.9 × the difficulty's `bossPace`.
**Files:** `src/world/entities/types/bosses/mirrorchase.lua`, `tools/levelgen/levels_chase.py`, HUD
`BossHud.drawRun`. **Music:** `mirror_chase`. **Harnesses:** `mechanics persecucion`,
`online_smoke LEVEL=assets/levels/huida_del_espejo.json WATCH=mirrorchase`.

- **3.102.0 — a real body** (the user: it walked, jumped and looked "intangible"). `Chase:body`: the player's
  gravity in REAL time (the difficulty pace now scales its speed, not its time: jumps were in slow motion on Easy), it
  accelerates and brakes like the player (`ADV_FRICTION` / `ADV_AIR_FRIC`), the high jump is a real DOUBLE jump at the
  apex of the first (`wantHigh`; there is a single `JUMP_H` now), and it is drawn with the player's poses (walk 3↔2
  faster when faster, rise 2, fall 1↔3; it used to run with the flap animation) and no trail while walking (only in its
  dash and dive). Out of lava it leaves with ONE jump (it re-jumped every frame while still inside: the jump sound
  played dozens of times per second) and jump sounds are at least 0.25 s apart. Harness `mechanics`
  `persecucion_cuerpo`.

## The level

- Level **huida_del_espejo** "La Huida del Espejo" / "Mirror Escape" (`tools/levelgen/levels_chase.py`,
  `build.py --only huida_del_espejo` + `retheme.py huida_del_espejo`; volcano, dusk, 214x11): story world 6, between
  lluvia_pinchos and the boss (`Worlds.LIST`). An AUTO-SCROLL level (160 px/s; the player runs at 240) built from 9
  repeating motifs: lava pits (LAVA tiles at floor level), steps, a lava lake with slabs, falling spikes under a low
  ceiling, a Hopper, a trampoline wall, three pits in rhythm, a mortar, a slab staircase over lava. It lasts about one
  loop of its music. `level_solve` finds the route; NOT played by a human yet (speed and fairness are the user's call).

## Current rules

- **CHASE v3 (3.81.0; the user: "it still stays fixed at the left wall — it should WALK around, cross from side to
  side, climb platforms and attack organically").** 'stalk' is now `Chase:roam`: a walking body (gravity +
  `Entity.moveAndCollide`, no route) that runs at `RUN` 430 px/s to a point `SIDE_D` tiles to one SIDE of the player
  and then the other (switching every 1.1-2.4 s, clamped to the screen), jumps walls and gaps, takes a high (and
  double) jump when blocked or when the player is above, hops out of lava / spikes unharmed (`onDeadlyGround`), and
  ploughs through the player on the way (`HIT_TOUCH` in its direction). Stuck `STUCK_T`, left behind or off screen →
  it shatters and reappears standing next to the player (`kind = 'blink'`, `blinkSpot`). New attack from wherever it
  stands, POUNCE ('pounce': arcs up over the player in 0.45 s with a floor mark, then the usual 'dive'); `KINDS` =
  pounce, dash, dive, shove... After any attack it keeps walking from where it ended (no return to the edge). The
  walk / jump frame travels in the standard `frame` field (6 run, 2 rise, 1 fall). Harness `persecucion`: switches
  sides ≥ 6 times, jumps the low walls, near the left edge < 35 % of the time (measured 4 %).

- CHASE 3.82.0 (user: v3 is right but maybe too hard): everything it does runs at `SLOW` 0.9 × the difficulty's
  `bossPace` (applied INSIDE `updateCustom`, def `pace = false`: what travels with the camera uses the real dt via
  `self.camK`, the camera itself is not slowed) — easy 0.63, normal 0.77, hard / none 0.9, extreme 1.08; and TOUCHING
  it while it walks (or recovers) no longer hurts: `HIT_TOUCH[1] = 0` = push only (`Boss.strike` with 0 HP: no damage,
  no invulnerability; generic). Its attacks (dive, dash, shove) still take 1 HP.

- HUD: `BossHud.drawRun(level, entities)` (both level states): **"¡CORRE!" / "RUN!"** (`hud.run`) top centre while
  the camera runs, instead of any boss bar.

- Harness `mechanics persecucion`; `online_smoke LEVEL=assets/levels/huida_del_espejo.json WATCH=mirrorchase`.

- **In the story** (3.101.0) the run does not end at the finish (there is none): near the end the level becomes a
  short scene (`src/story/RunOut.lua`, [story-mode](../story/story-mode.md)) and the chaser gets the state `outro`
  (`Chase:startOutro(level, minX)`: if it was behind or mid-teleport it comes in standing at the left edge;
  `Chase:runOut`: runs behind the player at its real pace, no attacks, no screen clamp, jumps an instant after the
  player jumps — it is its reflection) until both leave the frame. Free Play and online keep the old end ('left' when
  the camera stops). Only single player ever sets it.

## History and decisions (dated notes)

Kept because they record WHY things are the way they are and what was tried and rejected. Where a note
conflicts with the sections above, the sections above describe the current behaviour.

- Entity **`mirrorchase`** ("Espejo perseguidor", `types/bosses/mirrorchase.lua`): not a fight — it can't be hurt, stomped,
  frozen or pushed, and touching it KILLS (not while invulnerable after respawning). Its x comes from the level's
  auto-scroll camera (`a.x + LEAD` 1.1 tiles inside the left edge + the lunge), it flies through everything at the
  nearest player's height, and every `lungeEvery` s it LUNGES: 'wind' (0.6 s: shrinks and shakes) → 'dash'
  (`lungeDist` tiles out and back) → 'chase'. 'lurk' before the camera runs (laughs at the countdown); 'left' when the
  run ends (shatters, gone). SP/server compute it; clients draw x, y, state, deadTimer from snapshots. Drawn like the
  Mirror (the player's sprites through an invert shader) with a trail and hard dark bands behind it. Not a `boss` for
  the systems (no zone, no bar, no shard).

- **CHASE v2 (3.80.0, protocol v54; the user: glued to the edge with a little lunge now and then was "very easy" — he
  wanted the boss FREE in the level, immune to it, teleporting, attacking and PUSHING: intense, frantic).** The
  paragraph above describes v1; `mirrorchase` now: collides with nothing, `isGhost` (the normal player ↔ entity rules
  don't apply; it hits from its own update with `Boss.strike`), and chains attacks with `rest` s between them (prop,
  default 1.1): 'stalk' (back at the left edge, following the player's height; touching it = 1 HP + a shove forward) →
  'warp_out' (shatters) → one of `KINDS` in order: DIVE ('portal': the floating mirror — `Mirror.drawPortal/drawMark`,
  now exported by mirror.lua — above the player, follows then locks, floor mark → 'dive' → hit + a knockback wave →
  'recover'), DASH ('aim' at the RIGHT edge at the player's height with a dashed line, travelling with the camera →
  'rush' across the whole screen to the left), SHOVE (appears 4 tiles ahead of the player, short charge at them).
  Every hit = 1 HP and a push, almost always BACKWARD, toward the auto-scroll edge, which is what kills (`GRACE` 0.7 s
  between hits). Laughs when a player dies. netPack {markX, markY, dir, kind}. Harness `mechanics persecucion` (all
  states and the three attacks seen, hits push backward, never leaves the screen, leaves at the end).
