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
- **Music**: the coast boss uses the track made from Final Fall's bass, today `caida_libre` (v3,
  `tools/music/caida_libre.py`; previews only) — it still needs a **new name** (proposed: "Marea Brava", "Mar de
  Fondo", "Resaca"). `final_fall` is ARCHIVED: out of the game's catalog. The cave boss needs a new theme. The crabs
  keep `crab_tantrum_normal` and `crab_tantrum_gloomy`.

## Proposals still open (the user picks)

- Giant Pufferfish fight (proposed, from the coast's systems): a tidal cove with a `flood` that rises and falls — at
  high tide it swims after the player (water, air), at low tide it is stranded and flops: the window to hit it; it
  inflates spiky when hit and deflates to attack; spine volleys on the 3+3+2; sucks / blows water currents.
- Giant Hopper fight (proposed): the cave Hopper's rework decides it — what it hears (noise), what light does to it.
- Which levels get the secret exits, what the secret collectible is and where it is shown.

## Steps

### 0. Groundwork
- [x] (0.5.28) Knockout stars drawn in two passes (behind / in front of the head) everywhere (`src/fx/StunRing.lua`) — the
      last open item of the boss rework (0.5.28).
- [x] (0.5.28) Take `final_fall` out of the catalog (archived in `FlappyMonster_originals/music/versiones/final_fall_v4/`).
- [ ] Rename `caida_libre` and install it as a boss track.

### 1. Giant Pufferfish (coast)
- [ ] Sprite rework of the normal pufferfish: 2-3 proposals → the user picks → install (`docs/art/generators.md`).
- [ ] Giant Pufferfish design (sheets, states) from the chosen pufferfish: proposals → pick.
- [ ] Fight design (attacks, vulnerable window, phases, rage) written in its page `docs/bosses/<boss>.md`.
- [ ] Entity (`types/bosses/`), sounds (`tools/sounds/`), intro, defeat / flight, shard 2; protocol + version.
- [ ] Arena + harness (`<boss>_rules`, `boss_sim`, `boss_intro`, `online_boss`); the story level replacing
      `guarida_cangrejo_rey` in `Worlds.lua` (coast boss slot).

### 2. Giant Hopper (caves)
- [ ] Cave Hopper mechanics rework (noise / light) → user's verdict.
- [ ] Giant Hopper design + fight (sound and light) → page, entity, sounds, arena, harnesses.
- [ ] The story level replacing `gruta_lugubre` (caves boss slot); its theme (music).

### 3. Secret bosses
- [ ] Secret exits (which levels; how a level has two exits; the map shows the lairs once found).
- [ ] `guarida_cangrejo_rey` and `gruta_lugubre` as secret levels; their bosses drop the secret collectible.
- [ ] The secret collectible: what it is, where it is saved and shown (save data, results, map).
- [ ] Films / story text that mention the crabs as shard holders (`docs/story/`).
