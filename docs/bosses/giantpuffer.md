# Giant Pufferfish (Pez Globo Gigante) — `giantpuffer`

The Coast boss since 0.5.30 (it replaces Mega Crabby, now a future secret boss: [new-bosses-plan](new-bosses-plan.md)).
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

The arena has a flood with `control='boss'` (cols 12-33): it starts LOW (0.25 tiles), waits 7 s, rises to 6 tiles,
holds 9 s, falls and stays low 9 s, repeating while the fight lasts; when the boss dies it falls and stays. It is a pure
function of time (same online). While it FALLS the water drags sideways: the flood prop `undertow` (px/s, signed;
130 → right) is read by `Floods.currentAt(level, x, y)` and added to the player's horizontal move; foam particles
(`undertow_foam`) show the direction ([water-and-floods](../gameplay/water-and-floods.md)). Side platforms (row 9)
drown at high tide; the centre one (row 6) is always dry; two air vents on the floor.

## Behaviour

The fish does what the water at ITS position allows:

- **High tide (in water)** — 'swim': chases the player (`SWIM_SPD` 150 / 200 angry); contact = 1 HP + push. Every
  `ATK_EVERY` s (3 / 2.2) it attacks, always with a warning:
  - near (< `PUFF_NEAR` 4.5 tiles) → 'puff_warn' (trembles half-inflated) → 'puffed' (spines out, radius `PUFF_R`:
    1 HP + strong push) → 'deflate'. Never puffs twice in a row (hugging it gets spines instead).
  - far → 'spines_warn' (blinks half-inflated) → 'spines': three rings at 3+3+2 sixteenths (the rhythm of "Resaca"),
    `SPINES_N` 8 / 12 per ring, 1 HP + push each; they stop at walls.
  - Nothing is vulnerable in water: stomping it only bounces.
- **Low tide (stranded)** — 'flop_wind' (a target mark follows the player, locked the last 0.15 s) → 'flop' (a jump
  onto the mark, max 3.5 tiles; in the air with spines out = 1 HP) → 'gasp' (stars, `GASP_T` 1.7 / 1.25 s): the ONLY
  vulnerable state — stomp 1 / ground pound 2, one hit per opening → 'hurt_puff' (inflates at once and shoves the
  player away, 0 damage).
- **Rage** under `rageAt` (0.5): more spines per ring, longer puff, faster flops and swim, anger symbols.
- HP 10 (+4 per extra player).

**Intro:** falls from the sky into the low cove, lands, puffs and deflates (3.4 s). **Defeat:** 'dying_deflate' →
'dying_daze' → 'dying_flee' (flops away over the terrain, `fleeOver`), throwing the shard 0.8 s into the flight; the
tide falls for good.

**Network:** netPackExtra `{rage, markX, markY, burst, nSpines, spines…}`; spines are drawn and hit-tested from it, so
clients see the same rings. Protocol 61.
