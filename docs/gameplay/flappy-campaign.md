# The Flappy campaign (zones, saves, map)

**What:** the main menu's FLAPPY → CAMPAÑA is the prequel campaign of [flappy-prequel](../design/flappy-prequel.md):
3 save slots of its own (Easy / Normal / Hard), a map of ZONES, and STAGES that are Flappy levels (`"flappy": true`, the
player flies: [player](player.md#flight-flappy-levels)) played on Adventure's engine with lives, Game Over and the
results screen. Built in Plan 3 ([flappy-plan-3-campaign-frame](../design/flappy-plan-3-campaign-frame.md), 0.5.167).
Today: zone 1 (Valley of the Pillars) with three stages (Plan 5b, [§ The Valley's stages](#the-valleys-stages-plan-5b)),
its boss stage `valle_redcoptero` (Plan 5), the drawn zone map with the merchant's shop ([§ The zone map](#the-zone-map-plan-5b));
the rest comes in
Plans 4–7 (roadmap: [flappy-prequel § Plans](../design/flappy-prequel.md#plans)).

**Files**

| File | Role |
|---|---|
| `src/flappy/Zones.lua` | the campaign as DATA: zones in order, each with its stages, its boss stage (`boss`) and its map (`map`) |
| `src/flappy/FlappySave.lua` | slots `flappy1..3.sav` (separate from Adventure's `story<n>.sav`), `DIFFICULTIES` |
| `src/flappy/FlappyRun.lua` | the open slot: RunCore + `complete` (score, the WALLET; the last stage of the last zone → `Campaign.finished`), `buy` (the shop) and `gameOver` (back to the start of the zone) |
| `src/flappy/Shops.lua` | the zone SHOPS as data: `LIST[zoneId] = { { id, price }, ... }`, `forZone(z)` |
| `src/states/flappy/FlappyShopState.lua` | a zone's shop (`flappy_shop { zone = z }`, back to `flappy_map { shop = true }`) |
| `src/story/RunCore.lua` | progress rules SHARED with the story (`Run.lua`): open / save / state / frontier / setLives / score / restartWorld |
| `src/core/SaveFile.lua` | save files as Lua tables with a `.bak` copy (shared with `Save.lua`) |
| `src/story/Campaigns.lua` | per-campaign descriptors (`story`, `flappy`) read by the slot screen and CONTINUE |
| `src/states/flappy/FlappyCampaignState.lua` | FLAPPY: CAMPAÑA (→ slots) and, while `Campaign.READY` is false, INFINITO (the old endless mode) |
| `src/states/story/StorySlotState.lua` | the cartridge slot screen, for either campaign (`story_slots { campaign = 'flappy' }`) |
| `src/states/flappy/FlappyMapState.lua` | the zone map (`flappy_map`): the zone drawn, nests, boss icon, the shop node |
| `tools/art/ui/make_flappy_map.py` | the map art `assets/images/flappy/map/valle_*.png` (preview / `--apply [--force]`) |
| `src/flappy/Campaign.lua` | `READY`, the Adventure lock, `finished()` |
| `src/world/entities/types/items/flapcharge.lua`, `items/cage.lua`, `mechanisms/crackwall.lua` | the Flappy-only entities (category Flappy) |
| `src/ui/FlappyHud.lua` | hearts + charge meter |
| `tools/levelgen/levels_flappy_valle.py`, `flappy_lib.py` | the three Valley stages `valle_pilares_1/2/3` (writes only those files) |
| `tools/levelgen/levels_flappy_valle_boss.py` | the Valley's boss stage `valle_redcoptero` (writes only that file) |

**Data:** a zone = one entry in `Zones.LIST` (`id`, `stages`, `boss`, `food`, `map`) + a lang key `flappy.zone.<id>`. Stage ids are level
file names and are stored in saves: never rename them. A slot: `{ version, difficulty, world, node, lives, done, best,
playTime, points, gameOvers, rescued, inventory, wallet }` (version 4; [save-data](../architecture/save-data.md)).

**Wallet and shops (Plan 5b):** `wallet` is a points purse separate from the `points` record. `FlappyRun.complete` adds
the finished stage's points (`summary.points`, with the difficulty's `scoreMult`) plus the grade reward's points to it;
leaving halfway and Game Over never touch it (rule 7); buying lowers only the wallet, never `points` or `best`. Each
zone's shop (`Shops.LIST`, keyed by zone id: the Valley sells `shield` 300, `heart` 400, `magnet_points` 250) is the
`flappy_shop` screen: one card per item (icon, name, price, owned of 3), unaffordable ones greyed; ENTER / a tap on the
selected card asks BUY / CANCEL; `FlappyRun.buy(id, price)` → `'ok'` (spends and saves at once) | `'poor'` | `'full'` |
`'type_full'` (nothing spent, a notice). Refusals are noticed before the confirmation. The map's merchant nest opens it
and BACK returns to the map with the shop selected.

## The zone map (Plan 5b)

`flappy_map` draws the zone instead of the menu background. Art (`tools/art/ui/make_flappy_map.py`, ×4 like the sky and
the story map; prefix `Zones.LIST[z].map.art`, files `assets/images/flappy/map/<art>_*.png`):
- `_bg` (320x180 = 1280x720): the `valley` sky's day gradient, sun, clouds and its three layers (reused from
  `make_valley_sky.py`). Tiled across the width, centred (the layers wrap at 320 art px), so any logical width works.
- `_pillar` (18x160): a basalt pillar in front, darker and outlined; the game draws from the node's point down to the
  grass (`WINDOW_H - 30×4`) and adds its last 10 rows (the base in the grass).
- `_nest-Sheet` (24x22 ×3): a stage = a NEST on its pillar: open (red pennant, egg), done (gold pennant and egg, the
  grade above), locked (grey twigs + the shared `PixelIcons` `lock`). The stage number is written on the pillar.
- `_boss-Sheet` (24x26 ×3): the boss = its MACHINE's icon hovering over its pillar (the Net-Copter: patched balloon,
  ropes, gondola, propeller, in `make_netcopter.py`'s colours): open (bobs), beaten (popped balloon, still), locked (grey).
- `_shop-Sheet` (30x24 ×2): the SHOP = the MERCHANT's nest: a flappy of the same race (round head, antennae, white
  face, NO wings) in a red cap and an apron, with a coin sack; frame 2 (waving) shows now and then.

Positions are DATA: `map.at[stageId] = { x, y }` (normalised: x over the map width = the screen, at most 1280, centred;
y over the height) is the point at the top of that node's pillar; `map.shop` is the merchant's. A node without a
position is spread across the width. Dotted ARCS (the story map's `path.png` dot) join each stage to the next (lit when
the next is open) and the shop to the nearest stage. The cursor is the shared menu cursor (`MenuKit.marker`; every
node box is `MenuKit.occupy`'d so it never covers one). The card shows the stage (name, best / new / locked, cages) or,
on the shop, its name, line and the wallet. Lives top right with the player icon.

**The shop node is not a stage:** it is not in `Zones.nodes`, so progress, the frontier, CONTINUE and the campaign's end
never see it; it is always open. **Input:** ← → move through ALL spots in left-to-right order (the shop included);
ENTER / flap plays the stage or opens the shop (`flappy_shop { zone }`); BACK → slots. Touch: tap a spot to select it,
tap the selected one to play / enter. The state keeps `sel` (stage index) and `onShop`.

**To add a zone's map:** give the zone `map = { art, at, shop }` and make its art (add the zone's drawing to
`make_flappy_map.py`; the five files with that prefix). `flappy_campaign CASE=zonas` checks the art exists and every
node (and the shop, if the zone sells something) has a position on screen that does not overlap another.
Not judged by the user yet: the look of the map, the merchant and the machine icon (art applied provisionally).

**Playing a stage:** the map calls `AdventureState` with the same contract as the story map: `lives`, `onLeave` (lives
LOST are saved however the stage ends), `onGameOver` (`FlappyRun.gameOver()`: the zone starts again, lives back to the
start, records kept), `onFinish` (`FlappyRun.complete`: score, record and the GRADE REWARD the first time — S +1 life, A +500 points, as in the
story — → `story_results` with `returnTo = 'flappy_map'`; its RETRY comes back with `replay` + `cleared` and the map
plays that stage again), and `taken` (extra lives already picked up there only give points). Nothing gained
in a stage is saved before it is finished (golden rule 7).

**CONTINUE** (main menu): the most recently written save of ANY campaign (`TitleState` `lastSave`), Flappy or Adventure;
while Adventure is locked, its saves do not count.

## Charge, special attack, cages, walls, food, HUD (Plan 4, 0.5.169)

- **Charge:** `flapcharge` items (Flappy-only, `pickup = { charge = 1 }`) add 1 to `pa.charge`, up to
  `PlayerAdventure.CHARGE_MAX` = 5, applied in the shared pickup path (`Interactions.run` → `pa:addCharge`). Dying keeps
  it; each stage starts at 0.
- **Special attack** (action `special`: X / K, pad R shoulder, touch: the extra button above the jump button): with
  charge, a BURST leaves the monster's front (towards `facing`: the last direction it was steered, right at the start)
  with `power` = the whole charge (spent), at 900 px/s for up to 8 tiles. A solid tile stops it (pillars do not);
  each entity it overlaps gets `onSpecialHit(power, pa, dir)` once — the base: enemies
  (not bosses) die flung, `Boss` takes `power` damage; returning true absorbs the burst ([player](player.md#flight-flappy-levels)).
- **Caged flappies** (`cage`, Flappy-only, prop `minCharge` 1–5, shown as dots over it): a burst with enough power frees
  it (`rescuedNow`), less is absorbed. `AdventureState` returns `result.rescued` (placement indices) only when the stage
  is FINISHED; `FlappyRun.complete` stores `rescued[stage]`; replays pass `rescued` and those cages are empty. The map
  card shows "Flappies freed n/m". What freeing ALL of them gives is still PENDING (the user); each one will give a
  power-up: its `gift`, given when the stage is finished ([powerups](powerups.md), Plan 4b, 0.5.172).
- **Cracked walls** (`crackwall`, Flappy-only, props `minCharge`, `rows`): solid like the door until a burst with enough
  power breaks it. They hide shortcuts / prizes: the main route never needs them (the zero-charge bot clears every
  Valley stage — `flappy_flight etapa`). The camera's left edge never pushes the player through an intact wall (0.5.170, final review of
  Plan 4): against a wall it is the usual AutoScroll rule. In the Valley stages a wall shuts a cage in a `cubby` or the
  entrance of a `tunnel` shortcut (`flappy_lib`, below).
- **Food:** a Flappy level's `apple` with skin `auto` takes its zone's `food` (`Zones.LIST`, via `level.id`, the level's
  file name set by `Level.new`); the Valley's is a peach (`food_valle.png`).
- **HUD:** `src/ui/FlappyHud.lua` — hearts (always visible) and the charge meter under score / time; lives stay top
  right.
- Stage objects come from `tools/levelgen/flappy_lib.py`: `at_gaps` (charges / food at the centre of chosen pillar
  gaps), `cubby` (a cracked wall at rows 1-2 with one thing — a charge, a cage — shut in behind it), `tunnel` (a
  shortcut: rows 1-2 behind a cracked wall over a floor of solid blocks at row 3; the pillars inside lose rows 1-2 —
  `build(..., air=)` —; the gaps below start at row 5 or lower). `write(..., background=)` sets the level's sky biome.
  `flappy_campaign zonas` checks every wall SHUTS something: the cell behind its top row cannot be reached from in
  front of it without breaking it (a search through non-solid cells, pillars passable, up to two columns behind).

## The Valley's stages (Plan 5b)

Generator `tools/levelgen/levels_flappy_valle.py` (ids kept: `valle_pilares_1/2` since Plan 3, `valle_pilares_3` new),
all with `"background": "valley"` ([sky-and-biomes](../art/sky-and-biomes.md)), auto-scroll 200 px/s, floor at row 10.

| Stage | Width | Pillars | Content |
|---|---|---|---|
| `valle_pilares_1` | 130 | 13, every 8 cols, gaps 4-5, heights change 1-2 rows | 5 charges, 2 food, 1 easy cage (`minCharge` 1, row 3 just above the route, right after the first charge; gift `shield`), no walls |
| `valle_pilares_2` | 139 | 16, every 7 cols, gaps 4 then 3, bigger height jumps | 6 charges, 2 food; a cage in the open (row 2, `minCharge` 2, gift `heart`) and a `cubby` at col 72 (wall `minCharge` 2) with a cage (`minCharge` 1, gift `magnet_points`) behind it: 3 charges in all, 4 are on the route before it |
| `valle_pilares_3` | 139 | 16, every 7 cols, gaps 3-4 | 3 `netlauncher` (cols 30, 72, 100, row 9, each 3 cols from both pillars: room to wait for the net), 6 charges on the route + 2 in the shortcut, 2 food (right after launchers 1 and 3), a cage at row 1 (`minCharge` 3, gift `strength`, before the boss), and the shortcut `tunnel` cols 58-80 (wall `minCharge` 2) running over launcher 2, whose nets stop on its floor |

The net-launcher and a steady flyer: it comes within range 20 tiles (6.4 s at 200 px/s) before the player reaches it
and fires every 3.5 s, so a player who flies straight on without looking is usually hit as it passes (the zero-charge
pilot of `flappy_flight etapa` is hit by launchers 1 and 3 and still finishes, 3 → 1 HP; the harness applies no food
healing, the game does, and the food sits right after those two). Dodging = waiting left of its column or hurrying
past during the 0.6 s glow. Feel judged by the user in play.

## Evil Monster machines (Plan 5b)

- **`netlauncher`** (`types/traps/netlauncher.lua`, Flappy-only, `pace = 'trapPace'`): a ground turret. Every `T.EVERY`
  (3.5 s) it glows `T.AIM_T` (0.6 s, `clawServo`) and fires one net straight up at 520 px/s (`netFire`). The net is the
  Net-Copter's `netshot` (`launch(ty, drift, boundPx, dir, up)`: `up` = vertical flight): 1 HP + `ctrlLock` 0.4 s, snags
  on solids / pillars, leaves through the top. Its 2 nets are reserve minions (`def.summons`, `Entity:freeMinion`, as
  the boss's). It never fires while no player is within `T.RANGE` (20 tiles); a player arriving always has at least `T.FIRST` (1.5 s) before the first shot. An upward net only probes solids inside the level, so it leaves through the top cleanly. The special burst destroys it: the generic
  `diesToSpecial` flag in the type definition (`Entity:onSpecialHit` -> `dieBurst`). Art: `netlauncher-Sheet.png`
  (`tools/art/enemies/make_netlauncher.py`). Test: `flappy_flight` case `lanzarredes`.

## Boss stages (Plan 5)

A zone's `boss` is a Flappy level like the others, built with `flappy_lib.boss_arena(col, boss, ...)` passed to
`write(..., arena=)`: pillars first, then a one-screen BOSS ZONE (full height, its music) with the boss in its right
third and a couple of short pillars inside (`stubs`), then a few columns to the finish. The auto-scroll's `endCol` is
the zone's last column, so the window stops exactly over the zone (`AutoScroll` 'stop', no walls) and the zone takes
the camera; once the boss is beaten the zone opens and the player flies on to the finish (`onFinish` as in any stage).
Inside the fight the boss director (`bossdrops`) hands out charges / food. Dying in the fight respawns IN THE AIR in
the zone's left third (`BossZones.respawnPoint` → `Level:flightSpot`, the same rule as the auto-scroll's Flappy respawn):
standing on the floor would cost 1 HP. `valle_redcoptero`: pillars at columns 18-60 (3 charges, 1 food), zone 66-85
with the `netcopter` at (81, 5) and music `tuffi`, finish at column 93. Its floor is the level's LAST row (grass only:
`write(..., floor=H)`, 10 air rows instead of 9; the user, 2026-11-08: the floor was too high for the fight); the
other stages keep `FLOOR` 10 (grass + dirt). 11 rows is the most the fixed 720-px camera shows whole.

**Return to sender** (Plan 5): a trait `reflectable` on an entity (+ optional `canReflect()`) makes a player who FLIES
and is RISING (`pa.vy < 0`) when touching it get the interaction `'reflect'` (`Interactions.check`) instead of being
hurt; the entity's `onReflect` sends it back. The `glowbomb` (the Net-Copter's bomb, `owner` = the boss) flies back to
its owner and does 2 damage; hit any other way it explodes (-1 within a tile). Details: [netcopter](../bosses/netcopter.md).

**Flappy boss drops** (`bossdrops`, every difficulty, `level.flappy`): there is no floor, so the help does not fall: it
APPEARS where it will float (`Entity:appearAt`) in a free air tile of the zone, 4+ tiles from the boss and 2-6 from the
player who needs it. Food: the usual "when it is needed" rules (own pace `FLAPPY_FOOD`; with the last life and while
suffering, food, since there are no lives to give). Flap charge (`flapcharge`): controlled, at most ONE at a time, one
every `FLAPPY_CHARGE` s to the player with least charge, and at once after `PITY_T` s if everyone in the zone has 0.
No extra lives. What it gives is saved only when the stage is finished (rule 7).

**SP / server / client:** single player only. Flappy levels are listed in no online mode yet (project 3).

**How to extend**
- A stage: a Flappy level file (editor: Nivel → "Nivel Flappy (se vuela)", plus the auto-scroll) and its id in
  `Zones.LIST`; `run.sh flappy_campaign CASE=zonas` checks it (a boss stage needs a boss zone with a boss inside, no cage).
- A boss stage: a generator like `levels_flappy_valle_boss.py` (`flappy_lib.boss_arena`) and the id as the zone's `boss`.
- A zone: an entry in `Zones.LIST` (with its `map`: [§ The zone map](#the-zone-map-plan-5b)) + `flappy.zone.<id>` in
  `assets/lang/translations.csv`.
- Turn the Adventure lock on: `Campaign.READY = true` in the same commit that makes the campaign finishable (Plan 6).

**Tests:** `flappy_campaign` (`archivo`, `progreso`, `zonas`, `partida`, `premio`, `jaulas`, `monedero`, `tienda`, `migrar`), `flappy_flight` (`carga`,
`ataque`, `jaula`, `lanzarredes`, `lanzarredes_techo`, `muro`, `etapa` on every Valley stage), `netcopter_rules` (`etapa_jefe`: the boss stage is passable
— arena reached, camera stopped, zone fighting, walls down after the win, finish touched; `muerte_en_pelea`: respawn in
the air inside the zone with full HP), `touch_layout` (`especial`), `menu_flow` (`flappy_slots`, `mapa`, `tienda`,
`continuar_flappy`, `candado`).

**Decisions**
- 2026-11-08, the user: the first boss is the Net-Copter as proposed; `tuffi` music for all Flappy bosses for now
  (details in [netcopter](../bosses/netcopter.md#history)).
- 2026-11-07, the user: FLAPPY first in the main menu, CONTINUE = the last mode played, Free Play only in the debug menu.
- Final review of Plan 3 (fixed in 0.5.168): the grade reward was shown but not given; RETRY did nothing; `taken`
  was not passed (extra lives could be farmed once stages have them).
- 2026-11-08, the user, after Plan 4 (0.5.170): "por lo demás, diría que está bien" — the charge, attack, cages,
  walls, food and HUD stand as built.
- Plan 3 rulings: finishing the placeholder zone does not unlock Adventure (`Campaign.finished` only counts with
  `READY`); the slot screen is shared with the story through descriptors instead of a copy.
