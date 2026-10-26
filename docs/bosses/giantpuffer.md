# Giant Pufferfish (Pez Globo Gigante) — `giantpuffer`

The Coast boss since 0.5.30 (rebalanced in 0.5.31: the user found it "almost impossible") (it replaces Mega Crabby, now a future secret boss: [new-bosses-plan](new-bosses-plan.md)).
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

**Damage rule** (0.5.31, like the small pufferfish): DEFLATED IT DOES NO DAMAGE. Only its spines hurt (puffed, the
spine rings, the shove after a hit is 0 HP), and the flop CRUSHES only a player right under it while it falls (the
mark shows where). The fish does what the water at ITS position allows:

- **High tide (in water)** — 'swim': chases the player (`SWIM_SPD` 150 / 200 angry); touching it does nothing. Every
  `ATK_EVERY` s (3.6 / 2.6) it attacks, always with a warning:
  - near (< `PUFF_NEAR` 4.5 tiles) → 'puff_warn' (trembles half-inflated) → 'puffed' (spines out, radius `PUFF_R` = 6.4 × MS, body + half a spine:
    1 HP + strong push) → 'deflate'. Never puffs twice in a row (hugging it gets spines instead).
  - far → 'spines_warn' (blinks half-inflated) → 'spines': rings at 3+3+2 sixteenths (the rhythm of "Resaca"), two
    rings (three angry, `BURSTS_N`), `SPINES_N` 6 / 8 per ring at 400 px/s, 1 HP + push each; they stop at walls.
  - Nothing is vulnerable in water: stomping it only bounces.
- **Low tide (stranded)** — 'flop_wind' (a target mark follows the player, locked the last 0.15 s) → 'flop' (a deflated
  jump onto the mark, max 3.5 tiles; if the player is lower it aims at the player's floor and drops through platforms;
  crushes only a player under it while falling = 1 HP) → 'gasp' (stars, `GASP_T` 1.7 / 1.25 s): the ONLY
  vulnerable state — stomp 1 / ground pound 2, one hit per opening → 'hurt_puff' (inflates at once and shoves the
  player away, 0 damage).
- **Rage** under `rageAt` (0.5): more spines per ring, longer puff, faster flops and swim, anger symbols.
- **Second phase: small pufferfish** (0.5.32, the user). While angry and swimming it releases a small pufferfish from
  its mouth every `SPAWN_EVERY` 3 s, up to `PUFFERS` at once by difficulty (Easy 1, Normal / none 2, Hard 3, Extreme 4,
  Xtra 5). They are reserve entities (`def.summons`: `PUFFER_POOL` 5 per boss, created by `Level.fromData` after the
  JSON ones, `summonKey` `gp<col>,<row>`), swim the zone as their area, cannot be killed (only avoided: they inflate
  near a swimming player), and die on dry land at low tide (`dryTime` 2.5) — all of them die when the boss is beaten.
- HP 10 (+4 per extra player).

**Intro:** falls from the sky into the low cove, lands, puffs and deflates (3.4 s). **Defeat** (reworked 0.5.32, the
user): 'dying_deflate' (squashes flat, `FLAT` 0.55) → 'dying_daze' (STAYS flat — it used to pop back to full size,
which looked odd) → 'dying_flee': a crouch (`FLEE_WIND`) and one forward LEAP with no collisions, a pure function of
time (`FLEE_VX/VY/G`): up ~6 tiles nose first, then a dive THROUGH the floor (debris, splash) until out of view
(`fleeOver`) — the Mirror's intro in reverse. Throws the shard 0.8 s into the flight; the tide falls for good.

**Network:** netPackExtra `{rage, markX, markY, burst, nSpines, spines…}`; spines are drawn and hit-tested from it, so
clients see the same rings. Protocol 61.
