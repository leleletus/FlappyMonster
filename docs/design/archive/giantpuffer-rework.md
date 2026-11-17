> **Archived design document.** Status: BUILT (fight 0.5.236, island skins 0.5.237, review minors 0.5.238). The system pages win where they differ: [giantpuffer](../../bosses/giantpuffer.md), [enemies](../../entities/enemies.md).

# Giant Pufferfish hyper-rework + pufferfish island skins (2026-11-16)

Status: **design, waiting for the user's approval**. Current boss: [giantpuffer](../../bosses/giantpuffer.md).

## Why

The user (2026-11-16): the Giant Pufferfish is "a miserable, good-for-nothing boss, very easy to slaughter". The
concrete problem: at low tide it flops → gasps → you hit it → it puffs and flops again → gasps again… The 9 s low tide
gives several openings in a row, so a chain of ground pounds kills it in **2 low tides**. Since 0.5.31 (when it was
"almost impossible") a deflated fish does no damage at all, so low tide is also free of danger.

## Goals / non-goals / anti-goals

- Goal: the fight lasts several tides, both halves of the tide threaten the player, and it reads as a proper Coast boss.
- Goal: every pufferfish (small enemy + the giant) has its own look per island, like the Crabbies.
- Keep: the cove, the tide cycle and the undertow, the gasp as THE opening, stomp 1 / ground pound 2, the defeat leap,
  the small pufferfish summons, shard 2, the level `cala_resaca` and its arena (no level rename, rule 3).
- Anti-goal: back to "almost impossible" (0.5.31). Every new attack has a clear warning and a way out; deflated and
  swimming it still does no contact damage.
- Non-goal: changing the tide timing per phase (the flood is a pure function of time since the fight started,
  `Floods` control 'boss'; changing its cycle mid-fight is not worth the netcode risk).

## Approaches considered

- A. Patch the loop (one hit per low tide + more HP): cheap, same dull fight, longer. Rejected: not a rework.
- **B. Keep the tide, make both halves dangerous (CHOSEN by the user):** one opening per low tide, low tide gets a
  spiked ball + floor spine waves, high tide gets three new attacks, three phases by HP.
- C. New structure (never vulnerable on its own; you strand it with geysers / urchins): most work, highest risk of
  becoming impossible again. Rejected.

## The fight (B)

All numbers are proposals, tuned in the harnesses; "{a, b, c}" = phase 1, 2, 3.

### HP and phases
- **HP 6** (+2 per extra player — builder may tune). Stomp 1, ground pound 2 (unchanged) → at least 3 low tides with
  perfect ground pounds, 6 with stomps.
- Phases by HP instead of the single `rageAt`: **phase 2 at ≤ 4 HP**, **phase 3 at ≤ 2 HP** (props `phase2At`,
  `phase3At` as fractions; `rageAt` is kept readable in old levels by mapping it to phase 2). Anger symbols from
  phase 2.

### Low tide (stranded)
- Flops toward the player as now (target mark, locked the last 0.15 s). Wind-up {0.45, 0.38, 0.32} s.
- **Floor spine wave (new):** every flop landing sends a wave of spines along the surface it landed on, both
  directions, ~0.6 tiles tall, {500, 560, 620} px/s, stopping at walls and surface edges. Jumpable; 1 HP + small push.
  Phase 3: two waves per landing (the second 0.35 s later).
- **Gasp** (the only opening) {1.6, 1.4, 1.2} s (difficulty still scales it via `downTime`).
- **ONE opening per low tide (the fix):** after it takes a hit it does `hurt_puff` (shove, 0 damage, as now) and turns
  into the **spiked ball**: fully puffed, spines out, it BOUNCES around the cove (gravity + elastic bounces off floor,
  walls and platforms, horizontal speed aimed loosely at the player, bounce height {3, 4, 4.5} tiles). Touching it =
  1 HP + push (same rule as puffed). It cannot be hurt (stomping it hurts YOU, like any puffed pufferfish). It keeps
  bouncing until the water reaches it, then deflates and swims. Warning: it flashes and the first bounce is in place.
- If the player does not hit it during a gasp, it just flops again (unlimited gasps until it is hit once).

### High tide (swimming)
Swims toward the player as now (no contact damage). Every {3.4, 2.8, 2.3} s an attack, chosen by distance and never
the same twice in a row:
- **Puff** (near, as now).
- **Ring of spines with a gap (replaces the plain rings):** {12, 14, 16} spines per ring, a gap of 3 missing spines;
  the gap ROTATES between rings (the player has to move to the next gap). {2, 3, 3} rings at the 3+3+2 rhythm.
- **Charge (new):** far attack. It stops, draws a line on the water toward the player (0.8 s warning, the line locks
  the last 0.2 s), then dashes along it puffed (spines out) at {700, 800, 900} px/s until it hits a wall or the water
  surface; then deflates. 1 HP + strong push.
- **Whirlpool (new, phases 2-3):** it spins in place (1.0 s warning: a spiral of foam), then for 1.6 s pulls players
  IN THE WATER toward it (pull {220, 280} px/s, weaker than swimming away), then puffs. Must be a shared current like
  the undertow so the online client predicts it (see constraints).
- Phase 2: + the small pufferfish summons (unchanged rules and counts per difficulty).
- Phase 3: charge is followed at once by a ring (combo).

### Intro / defeat
Unchanged (fall into the cove, puff, deflate; deflate flat → daze → leap through the floor, shard 2).

## Pufferfish island skins

- The small `pufferfish` and the giant one change together: the pufferfish becomes an `isleArt` type (editor prop
  `isle`, Auto = the level's island via `Isles.of`). The giant reads the same island (its arena `cala_resaca` is
  Coast → it looks exactly as today).
- **Coast = the user's hand-edited sheet, untouched** (`puffer_fish-Sheet.png`, listed in `docs/art/generators.md`).
  The other 7 islands are NEW sheets derived from it (same 16×16 frames, same animation set `enemies/pufferfish`,
  same silhouette per frame so hitboxes and anims are unchanged), each with its own species detail, like the Crabbies:
  - pradera: river pufferfish — olive/green with dark spots, pale belly.
  - fortaleza: armoured — steel-grey plates, rivet-like spines.
  - nieve: frost — white/ice-blue, crystal spines.
  - cueva: deep-cave — dark body with glowing (bioluminescent) spots and a small lure.
  - volcan: basalt — black body with magma cracks, ember-tipped spines.
  - jungla: poison-dart colours — bright yellow / black bands.
  - estelar: night-blue with star specks, star-point spines.
  These are first proposals: the user approves the preview before anything is applied.
- The boss spine projectile (`bosses/giantpuffer/spine.png`) gets a variant per island too.
- Generator: a new `tools/art/enemies/make_puffer_skins.py` that READS the user's sheet and adds each island's
  palette + detail (never rewrites the Coast sheet). No flag = preview to
  `/home/mtvemo/FlappyMonster_pruebas/pez_globo/vista_previa.png`; `--apply` writes only missing files. Art rules:
  few colours, flat areas, pixel density of the small enemy (`docs/art/style-rules.md`).
- `mechanics islas_arte` must pass with the pufferfish listed.

## Constraints

- Golden rule 1: identical in single player, server and online client. Everything drawn comes from the snapshot
  (`netPackExtra`: phase, mark, charge line, ball state, floor waves, spine rings). The whirlpool pull must act on the
  predicted local player — reuse the path the undertow uses (`Floods.currentAt` / a boss-current hook read by the
  player physics and the Predictor), not a direct velocity write on the server only.
- Protocol: new packed fields → `Protocol.VERSION` + 1 and `version.txt` bump.
- New sounds: reuse existing ones pitched (as the boss does today) unless a new one is clearly needed; any new sound
  is a real file.
- Docs: rewrite `docs/bosses/giantpuffer.md` (with a history line: user verdict 2026-11-16), add the pufferfish to the
  island list in `docs/gameplay/carry-and-push.md` § Islands, `docs/art/generators.md`, regenerate `docs/reference/`.
- Tests: update `giantpuffer_rules` (one opening per low tide, ball can't be hurt, phases, floor wave, charge,
  whirlpool), `boss_sim` / `online_boss` on `jefe_pez`, `mechanics islas_arte`; then `run.sh all`.

## Calls made while writing (not the user's; they can overrule)

- **Two releases:** first the fight (protocol + version bump; the pufferfish is not `isleArt` yet), then the skins
  after the user approves the preview (`islas_arte` needs all 8 sheets, so skins cannot ship half done).
- **Whirlpool pulls sideways only:** a boss-driven horizontal current added next to the undertow
  (`Floods.currentAt` path, already predicted online). No vertical pull, so it never fights a player swimming up.
- A gasp that starts while the tide is already rising still counts as that low tide's opening (no second one).

## Left to the builder

Exact speeds/timings within the stated ranges, hitbox sizes of the new projectiles, how the ball bounces off sloped
or partial tiles, which existing sounds to pitch for the charge and the whirlpool, the internal state names.

## Cannot be judged without the user

Feel and difficulty of the new fight, how the skins look in game, sound.
