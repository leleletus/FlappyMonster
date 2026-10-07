# Pickups: stars, extra lives, food, checkpoints, shards

A pickup is an entity type whose definition has `pickup = { score, lives, heal }` (or `checkpoint = true`). ONE
function decides what collecting does, for single player and server alike: `Interactions.pickupEffect(pa, pk)`
(`src/world/entities/base/Interactions.lua`).

| Type | File (`src/world/entities/types/items/`) | Effect |
|---|---|---|
| `star` | `star.lua` | points; counted in the level results |
| `extralife` | `extralife.lua` | +1 life. Never placed in a level with point zones (the `bot_nav` data check fails) |
| `apple` ("Comida") | `apple.lua` | heals 1 HP if any is missing, else points. Looks different per island |
| `checkpoint` | `checkpoint.lua` | becomes the respawn point |
| `bombobject` | `bombobject.lua` | not a pickup: a physical bomb (see [enemies](../entities/enemies.md)) |

Mirror shards are NOT entities: they are a single-player, story-only layer (`src/story/Shards.lua`, see
[story-mode](../story/story-mode.md)).

**Rule:** nothing picked up is saved until the level is finished ([save-data](../architecture/save-data.md)).
A pickup may declare `noise = tiles` (how far it is heard in dark levels). **Harness:** `mechanics manzana`.

## Food (the healing item)

- APPLE (`types/items/apple.lua`, "Manzana", Objetos; the USER's sprite `items/apple.png` — and their hand-edited `items/checkpoint_on|off.png`: don't regenerate them with `tools/art/world/make_world_art.py`): `pickup = { heal = 1, score = 20 }` → ONE rule for SP and server, `Interactions.pickupEffect(pa, pk)`: a healing pickup gives back HP if any is missing, else its points. SP: popup `hud.plus_hp`, sound `appleHeal` (`tools/sounds/items.py`); server: `pa.hp` (own state) + pickup event `kind = 'heal'`. PLACED by `tools/levelgen/add_apples.py <levels>` (appends lines to "entities" without touching the rest; skips a level that already has apples; re-run it after `build.py --only`): 4 along each AUTO-SCROLL level (huida_del_espejo, lluvia_pinchos, tren_fugaz) and 2 in every BOSS level (mid-way and right before the arena).

- (8) FOOD PER ISLAND: the `apple` type is now "Comida" with prop `skin` (auto by the level's background, the same rule as the Hopper's): meadow apple (user's sprite), coast pineapple, fortress drumstick, snow ice pop, cave glowing berries (they give a little light: `lights()`), volcano chili — `items/food_<isla>.png` from `tools/art/world/make_food_sprites.py`. Placed: 5 in laberinto_submarino (beside every 2nd checkpoint: `add_apples.py --checkpoints 2`, water cells allowed) and 3 in templo_del_eco (`--at`).
