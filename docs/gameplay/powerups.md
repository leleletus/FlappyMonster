# Power-ups, the inventory and the quick wheel

**What:** consumable POWER-UPS kept in an inventory per save slot and spent in any stage through the QUICK WHEEL (the
game freezes while it is open). Built in Plan 4b ([flappy-plan-4b-powerups](../design/flappy-plan-4b-powerups.md),
0.5.172) for the Flappy campaign; the design and the user's rules are in [powerups](../design/powerups.md). Adventure's
inventory, the map shops and the `big` power-up come later.

**Files**

| File | Role |
|---|---|
| `src/world/powerups/Powerups.lua` + one file per power-up | the catalog as data: `LIST` (the wheel's order and the icon frame), `get`, `forMode` |
| `src/player/PlayerPowerups.lua` | the EFFECTS in the player base: `usePowerup`, `canUse`, `hasEffect`, `damageMult`, `breakShield`, `tickEffects` (timers, size, ghost's end, magnets), `ghostPasses` |
| `src/states/adventure/WheelState.lua` | the quick wheel (state `powerup_wheel`, pushed over the level) |
| `src/flappy/FlappyRun.lua` | the inventory: `addPowerup`, `spendPowerup`, `inventoryCount`, `powerupInventory` (what the level gets), `cageGift` |
| `src/ui/FlappyHud.lua` | the BAG (touch: opens the wheel) and the active effects |
| `tools/art/ui/make_powerups.py` | icons (12×12, ×4), the bag, the shield bubble |

**Data:** a power-up = `{ id, modes, duration }` (ids are stored in saves: never rename). The slot keeps
`inventory = { [id] = count }` (Flappy save version 3; [save-data](../architecture/save-data.md)). Capacity: 6 in total, 3
per type (`FlappyRun.MAX_TOTAL`, `MAX_TYPE`).

| Id | Effect (`PlayerPowerups.lua`) |
|---|---|
| `shield` | absorbs the next hit of any kind (`hurt`, `takeDamage`, `die` without `force`: spikes, lava, drowning), then breaks with an invulnerability; forced deaths (left behind by the camera, the time limit) are not stopped. Drawn as a bubble (`fx/shield.png`, ×4) |
| `heart` | +1 max HP (and +1 HP) for the rest of the stage; they stack |
| `strength` | 12 s: `damageMult()` = 2 — the burst's damage to bosses ×2; the charge a cage or wall needs does not change |
| `magnet_points` / `magnet_items` / `magnet_all` | 20 s: pickups within 4 tiles fly to the player (points = only `score`; items = `lives`, `heal`, `charge`); no single magnet under `magnet_all` |
| `small` | 15 s: half hitbox (`sizeK` 0.5); the sprite is drawn at ×4 (the items' density) instead of ×3 |
| `ghost` | 12 s: Flappy-only hurting tiles (pillars) do not touch it; ending inside one gives 1 s of invulnerability instead of a hit; machines, shots and bosses still hurt |

**Getting and spending:** a CAGE gives its `gift` (a prop) when the stage is FINISHED, once per slot (rule 7); with a
full inventory it is lost with a line on the results screen (the design proposed offering a swap: simplified, for the
user to revisit). SPENDING writes the save at once, whatever happens next (the user). `AdventureState` gets
`args.powerups` (`{ items(), spend(id) }`) from the map.

**The wheel:** hold `Q` / `Tab` / pad `L`, point with the mouse, arrows / WASD or a stick, release to use; release with
nothing chosen, `Esc` or the pause to cancel; keys `1`–`6` use the type at that position directly; touch: the bag button
(right of the hearts) → tap a cell (or hold and slide). Greyed cells (`not pa:canUse`) are never spent. Settings: "wheel:
hold / press" (`Settings.wheelToggle`). Not openable while dying, after the finish, in the start countdown or a scene.

**SP / server / client:** single player only for now (power-ups are off online); every effect is plain player state so
it can go online later (the shield and size would travel in the own state; `Protocol.VERSION` + 1 then).

**How to add a power-up:** a file in `src/world/powerups/` + its name in `Powerups.lua`'s list, an icon in
`make_powerups.py` (same order), lang keys `powerup.<id>` / `.desc`, and its effect in `PlayerPowerups.lua`
(`usePowerup` / `tickEffects`); a test in `flappy_flight powerups`.

**Tests:** `flappy_campaign` (`inventario`, `regalos`), `flappy_flight` (`powerups`), `powerup_wheel`.

**Decisions:** the user's rules (2026-11-07) are in [powerups](../design/powerups.md). Final review of Plan 4b (fixed in 0.5.173): tapping the
bag and lifting the same finger no longer closes the wheel; a mouse click on a cell uses it (`game.lua` sends clicks as
`touchpressed('mouse')`); the "press" option really opens a press-to-choose wheel; releasing with the stick / arrows back
in the centre CANCELS (the design); the bag sits right of 7 hearts. **Open for the user:** keys 1–6 use the n-th type
HELD, so the meaning of a key shifts when a type runs out (the design wants stable keys but also a wheel of only the
types held). Plan 4b rulings: the small sprite at
×4 (density rule of 2026-11-08); a full inventory loses a cage's gift with a notice.
