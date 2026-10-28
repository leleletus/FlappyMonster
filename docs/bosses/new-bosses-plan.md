# Plan: two new bosses, the crabs become secret bosses

Approved by the user on 2026-10-25. Tick an item (`[x]`) in the same commit that does it and say in which version.
Lore rule that shapes everything ([story](../story/story.md)): every boss is a NORMAL enemy of its island that grew
giant by touching a mirror shard ("La Furia del Espejo").

## Decisions (the user's)

- **Coast**: the **Giant Pufferfish** replaces Mega Crabby as the coast's boss (story shard 2). It comes with a
  **rework of the normal pufferfish's sprites** (the giant one is its version).
- **Caves**: the **Giant Hopper** replaces Mega Gloomy Crabby as the caves' boss (story shard 6). It comes with a
  **rework of the cave Hopper's mechanics** and the giant one is built to use **sound and light** (the dark-level
  systems: noise, the flashlight).
- **Mega Crabby and Mega Gloomy Crabby become SECRET bosses**: each is reached through a **secret exit** in a level;
  beating them gives a **secret collectible** (not a mirror shard: the 7 shards stay with the main bosses).
- **Music**: the coast boss uses **"Resaca"** (`resaca`, `tools/music/resaca.py`; the user's name, 2026-10-25), the
  track made from Final Fall's bass (it was "Caída libre" while composing). `final_fall` is ARCHIVED: out of the game's catalog. The cave boss needs a new theme (provisionally `crab_tantrum_gloomy`). The crabs
  keep `crab_tantrum_normal` and `crab_tantrum_gloomy`.

## Proposals still open (the user picks)

- Giant Pufferfish fight (proposed, from the coast's systems): a tidal cove with a `flood` that rises and falls — at
  high tide it swims after the player (water, air), at low tide it is stranded and flops: the window to hit it; it
  inflates spiky when hit and deflates to attack; spine volleys on the 3+3+2; sucks / blows water currents.
- Which levels get the secret exits, what the secret collectible is and where it is shown.

## Steps

### 0. Groundwork
- [x] (0.5.28) Knockout stars drawn in two passes (behind / in front of the head) everywhere (`src/fx/StunRing.lua`) — the
      last open item of the boss rework (0.5.28).
- [x] (0.5.28) Take `final_fall` out of the catalog (archived in `FlappyMonster_originals/music/versiones/final_fall_v4/`).
- [x] (0.5.29) Rename `caida_libre` → `resaca` ("Resaca") and install it as a boss track.

### 1. Giant Pufferfish (coast)
- [x] (0.5.29) Sprite rework of the normal pufferfish: design A "Arena" (sand yellow, brown spots, spines that grow as
      it inflates); B "Arrecife" and C "Coral" kept in `tools/art/enemies/make_pufferfish.py`.
- [x] (0.5.30) Giant Pufferfish design: the design-A sheet at scale 13 + its own spine sprite.
- [x] (0.5.30) Fight design written in [giantpuffer](giantpuffer.md) (tide, undertow, puff / spines / flop, gasp).
- [x] (0.5.30) Entity, intro, defeat / flight, shard 2; protocol 61. Sounds: reused pitched-down puffer / king sounds
      (an own `tools/sounds/` set is still open, after the user plays it).
- [x] (0.5.30) Arena + harnesses (`giantpuffer_rules`, `boss_sim`, `boss_intro`, `online_boss`); story level
      `cala_resaca` replaces `guarida_cangrejo_rey` in `Worlds.lua` (coast boss slot).
- [x] (0.5.31) First verdict: "almost impossible" → rebalanced (deflated = no damage, fewer spines, low tide fully
      dry), chubbier pufferfish with a moving fin and a black eye, small pufferfish out of water.
- [x] (0.5.32) Second round: defeat stays squashed and leaves with one leap through the floor; second phase
      releases small pufferfish (more on harder difficulties).
- [ ] The user's verdict on the rebalanced fight.

### 2. Giant Hopper (caves)
- [x] (0.5.38) Cave Hopper mechanics rework: the user picked "the moth" (hunts by light, loud noise scares it, lantern
      off = stomp window; only in dark levels) — [enemies](../entities/enemies.md#hopper-saltarín).
- [ ] The user's verdict on the moth (arena `tools/levelgen/arenas/saltarines_oscuras.json`).
- [x] (0.5.40) Giant Hopper design + fight: the moth giant (sees only light, flare, rock waves; a loud noise near it
      scares it = the only opening; rage releases moths) → [gianthopper](gianthopper.md), entity, arena, harnesses
      (`gianthopper_rules`, `boss_sim`, `boss_intro`, `online_boss`, `boss_frames`). Sounds reused (own set open).
- [x] (0.5.40) Its OWN story level `gruta_del_farol` (the user: like the Giant Pufferfish, `gruta_lugubre` stays in the
      game) in the caves boss slot of `Worlds.lua`, shard 6.
- [ ] Its theme (music): the arena uses `crab_tantrum_gloomy` provisionally.
- [ ] The user's verdict on the fight.

### 3. Secret bosses
- [ ] Secret exits (which levels; how a level has two exits; the map shows the lairs once found).
- [ ] `guarida_cangrejo_rey` and `gruta_lugubre` as secret levels; their bosses drop the secret collectible.
- [ ] The secret collectible: what it is, where it is saved and shown (save data, results, map).
- [ ] Films / story text that mention the crabs as shard holders (`docs/story/`).

### 4. The Groove (secret, after the game) — not in the original plan
- [x] (0.5.45) A third new boss born from its music (`groove`): [groovecrab](groovecrab.md), level `isla_del_groove`,
      a secret map node that appears after beating the Mirror. No shard; the secret collectible (section 3) is still open.
- [ ] The user's verdict on the fight.

### 5. The jungle (future island) — not in the original plan
The user (2026-10-28): a future jungle / temple island (weights, crates, carryables + new enemies and mechanics). Its
boss, chosen by the user: the **Giant Rhino Beetle** (not a crab: "there are too many crabs already"), the giant of a
new jungle-only enemy, the Rhino Beetle. Fight proposed and liked by the user: horn charge into the temple walls (stones
fall), horn toss of stone blocks / crates, wing-case buzz leap + slam with floor shockwaves; the temple's great SCALE
flips it onto its back = the window to hit it. It will need more mirror shards (the user: the story will grow).
- [x] (0.5.73) Its theme `templo` ([music-history](../audio/music-history.md#el-templo-toolsmusictemplopy-boss-track-templo)).
- [ ] Sprites, animations and attack sprites (mockups / GIFs first, in `FlappyMonster_pruebas/escarabajo/`).
- [ ] The entity, its fight and its arena (then the island, its levels and the shard count).

