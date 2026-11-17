# Giant Pufferfish (Pez Globo Gigante) — `giantpuffer`

The Coast boss since 0.5.30, reworked 2026-11-16 (0.5.236) (rebalanced in 0.5.31: the user found it "almost impossible") (it replaces Mega Crabby, now a secret boss: [new-bosses-plan](new-bosses-plan.md)).
The normal pufferfish (design A "Arena") at scale 13, fought in a cove whose **tide** rises and falls during the fight.
**File:** `src/world/entities/types/bosses/giantpuffer.lua`. **Art:** the pufferfish sheet
(`tools/art/enemies/make_pufferfish.py`, same animations `assets/anim/enemies/pufferfish.json`) + its spine
`assets/images/bosses/giantpuffer/spine.png` (`tools/art/bosses/make_giant_puffer.py`). **Sounds:** reused, pitched
down (`pufferWarn/Inflate/Deflate/Prick`, `kingFlop/kingJump/kingHop`, `stunned`). **Level:** `cala_resaca`
(`tools/levelgen/levels_boss.py`); arena `tools/levelgen/arenas/jefe_pez.json` (`make_jefe_pez.py`).
**Music:** `resaca`. **Shard:** 2.
**Harnesses:** `giantpuffer_rules`, `boss_sim` / `boss_intro` / `online_boss` / `boss_frames` with `LEVEL=` that arena,
`sp_boss LEVEL=assets/levels/cala_resaca.json`.

## The tide

The arena has a flood with `control='boss'` (cols 12-33): it starts EMPTY (0 tiles: low tide has no water at all, so
it never gets in the way of jumps — the user, 0.5.31), waits 7 s, rises to 6 tiles,
holds 9 s, falls and stays low 9 s, repeating while the fight lasts; when the boss dies it falls and stays. It is a pure
function of time (same online). While it FALLS the water drags sideways: the flood prop `undertow` (px/s, signed;
130 → right) is read by `Floods.currentAt(level, x, y)` and added to the player's horizontal move; foam particles
(`undertow_foam`) and a HUD warning with a sound ("¡RESACA!" + arrows, 0.5.34) show the direction ([water-and-floods](../gameplay/water-and-floods.md)). Side platforms (row 9)
drown at high tide; the centre one (row 6) is always dry; two air vents on the floor.

## Behaviour

**Reworked 2026-11-16** ([design](../design/giantpuffer-rework.md), approach B chosen by the user): it used to give
several openings per low tide, so a chain of ground pounds killed it in 2 low tides.

**Damage rule** (0.5.31, unchanged): DEFLATED IT DOES NO DAMAGE. Only spines hurt (puffed, spike ball, charge, rings,
floor waves) and the flop CRUSHES only a player right under it while it falls (the mark shows where).

**HP and phases:** HP 6 (+2 per extra player). Phase 2 at ≤ 4 HP (prop `rageAt`, default 0.67: anger symbols, the
small pufferfish), phase 3 at ≤ 2 HP (prop `phase3At`, 0.34). Pace tables are `{phase 1, 2, 3}`.

- **High tide (in water)** — 'swim': chases the player (touching it does nothing). Every `ATK_EVERY` {3.4, 2.8, 2.3} s
  an attack with a warning, never the same twice in a row (`GP:pickAttack`): near (< `PUFF_NEAR` 4.5 tiles) → puff;
  otherwise one of:
  - **Puff** — 'puff_warn' → 'puffed' (radius `PUFF_R`, 1 HP + strong push) → 'deflate'.
  - **Rings with a gap** — 'spines_warn' → 'spines': {2, 3, 3} rings of {12, 14, 16} spines at the 3+3+2 rhythm, each
    with a gap of `GAP_N` 3 missing spines; the first gap points AWAY from the player, each next ring turns it 3
    spines. 400 px/s, 1 HP + push, stop at walls.
  - **Charge** — 'charge_warn' (0.8 s, a blinking line on the water that follows the player and locks 0.2 s before)
    → 'charge': crosses along the line puffed at {700, 800, 900} px/s until a wall, the bottom or the surface (never
    leaves the water; 2 s max). Phase 3: followed at once by rings (combo).
  - **Whirlpool** (phases 2-3) — 'whirl_warn' (1.0 s, foam spiral) → 'whirl' (1.6 s): pulls players IN THE WATER
    sideways toward it at {—, 220, 280} px/s (`GP:pushAt` through the air system `systems/Push`, so the online client
    predicts it; no vertical pull, never pulls fish or boxes) → 'puff_warn'.
  - Nothing is vulnerable in water: stomping it only bounces.
- **Low tide (stranded)** — 'flop_wind' (target mark, locked the last 0.15 s; {0.45, 0.38, 0.32} s) → 'flop' (onto
  the mark, max 3.5 tiles; crushes only a player under it) → on landing a **floor spine wave** each way along the
  surface it landed on ({500, 560, 620} px/s, 0.6 tiles tall — jump it —, ends at walls and surface edges, 1 HP;
  phase 3: a second pair 0.35 s later) → 'gasp' ({1.6, 1.4, 1.2} s): the ONLY vulnerable state, stomp 1 / ground
  pound 2.
- **One opening per low tide** (`opened`): after a hit → 'hurt_puff' (shove, 0 damage) → **'ball'**, a spike ball that
  bounces around the cove ({3, 4, 4.5} tiles high, drifting toward the player at 260 px/s, first bounce in place and
  blinking): touching it = 1 HP, it cannot be hurt. When the water reaches it, it deflates and swims, and the next
  low tide gives a new opening (a gasp started while the water is already rising still used that tide's opening).
- **Small pufferfish** from phase 2 (0.5.32 rules unchanged): while swimming it releases one every `SPAWN_EVERY` 3 s,
  up to `PUFFERS` at once by difficulty (Easy 1, Normal / none 2, Hard 3, Extreme 4, Xtra 5); reserve entities
  (`def.summons`, `PUFFER_POOL` 5), cannot be killed, die on dry land at low tide and when the boss is beaten.

**Intro:** falls from the sky into the low cove, lands, puffs and deflates (3.4 s). **Defeat** (reworked 0.5.32, the
user): 'dying_deflate' (squashes flat, `FLAT` 0.55) → 'dying_daze' (STAYS flat — it used to pop back to full size,
which looked odd) → 'dying_flee': a crouch (`FLEE_WIND`) and one forward LEAP with no collisions, a pure function of
time (`FLEE_VX/VY/G`): up ~6 tiles nose first, then a dive THROUGH the floor (debris, splash) until out of view
(`fleeOver`) — the Mirror's intro in reverse. Throws the shard 0.8 s into the flight; the tide falls for good.

**Network:** netPackExtra `{phase, markX, markY, burst, lineX, lineY, opened, gapA·1000, nSpines, spines… (id, x, y,
a·1000, t·100), nWaves, waves… (id, x, y, dir)}`; spines and waves are drawn from it, the whirlpool pull uses only
state + x + phase. Protocol 61; 129 for the rework.

## History

- 0.5.30 new Coast boss; 0.5.31 the user: "almost impossible" → deflated does no damage, low tide fully dry.
- 0.5.32 the small pufferfish in phase 2 and the leap defeat.
- 2026-11-16 (0.5.236) the user: "a miserable, good-for-nothing boss, very easy to slaughter" — several openings
  per low tide, killed in 2 low tides with ground pounds. Rework B (chosen over a pure patch and over a new
  structure): one opening per low tide + spike ball, floor waves, rings with a gap, charge, whirlpool, 3 phases,
  HP 10 → 6. Not yet played by the user.
