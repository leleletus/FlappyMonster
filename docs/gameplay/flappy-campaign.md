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

`flappy_map` draws the zone instead of the menu background. It plays `Zones.LIST[z].map.music`, a track id of
`assets/music/index.json` (the Valley: `map_flappy` "Cielo abierto", [music-history](../audio/music-history.md);
without it, `menus`). Art (`tools/art/ui/make_flappy_map.py`, ×4 like the sky and the story map; prefix
`Zones.LIST[z].map.art`, files `assets/images/flappy/map/<art>_*.png`):
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
- `_sign` (34x49, `make_flappy_map.py`, new file only): the SHOP SIGN over the merchant: a post with an arm (still), a plank hanging
  from two ropes that sways one art pixel (timer) with the translated word `shop.sign` (TIENDA / SHOP) in the pixel font, and a blinking gold spark. A map with a `shop` MUST have its `<art>_sign.png` (a zone without it fails to draw its shop node;
  `project_check` does not catch it).

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

**To add a zone's map:** give the zone `map = { art, music, at, shop }` and make its art (add the zone's drawing to
`make_flappy_map.py`; the files with that prefix: `_bg`, `_pillar`, `_nest-Sheet`, `_boss-Sheet`, `_shop-Sheet`, plus `_sign` when the map has a `shop`). `flappy_campaign CASE=zonas` checks the art exists and every
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
- **Caged flappies** (`cage`, Flappy-only, prop `minCharge` 1–5, shown as lit LAMPS on its base): a burst with enough power frees
  it (`rescuedNow`), less is absorbed. `AdventureState` returns `result.rescued` (placement indices) only when the stage
  is FINISHED; `FlappyRun.complete` stores `rescued[stage]`; replays pass `rescued` and those cages are empty. The map
  card shows "Flappies freed n/m". What freeing ALL of them gives is still PENDING (the user); each one will give a
  power-up: its `gift`, given when the stage is finished ([powerups](powerups.md), Plan 4b, 0.5.172).
- **The cage's look and prompt (0.5.196):** art from `tools/art/items/make_cage.py` in `assets/images/items/cage/`:
  `cage-Sheet.png` (23x24 ×4 = 92x96 px: closed with the padlock on the door's latch · open, the door swung out),
  `flappies-Sheet.png` (one row per VARIANT, 9x16 frames: arms down · arms up — the monster's own body, box head with
  antennae; 8 variants: colours plus horns / bulb / bunny ears / tuft / curl / three antennae, eyes and blush; never
  wings) and `lamp.png` (2x2, one per `minCharge`). The flappy is drawn INSIDE (behind the bars), waves
  its arms while the player is near and flies off flapping its arms when freed. **Which flappy:** `Cage.variantIn` —
  with the level (`levelRef`, `wantsLevel`) its ORDER among the level's cages, shifted by a number made from where all
  the cages are, so a stage never repeats one (up to 8 cages) and stages start at different ones; without the level,
  `Cage.variantAt(col, row)`; prop `look` 1..8 fixes it in the editor (0 = automatic). Nothing travels: every side
  has the level, so it is online-safe with no protocol change. The art cell is anchored on the placement cell at the
  cage's column 11 / row 9 (so a row-1 cage keeps its dome on screen) and the HITBOX follows the drawn cage
  (`sizePx` 68x84, outer 0.9 × 0.95, centre 8 px below the cell): it contains the old 46x51 box, so every burst that
  freed a cage before still does. **Prompt:** with the cage closed and THIS client's player within 7 tiles in front
  (1.5 behind, 4.5 up / down) a bubble says `flappy.cage_hint` ("Free it with the special attack {special}!") or, with
  less charge than it needs, `flappy.cage_need` ({n}); drawn in `Cage:renderOverlay` with the shared
  `src/ui/HintBubble.lua` (the help sign's bubble, moved out of `hint.lua`: button ICONS from `InputGlyphs` —
  `key_x`, `pad_r` added —, the touch name `keys.touch_special` and `TouchControls.highlight('special')` on phones;
  above the target, below it when there is no room). Draw-only, per client. Capture:
  `run.sh level_shots SCALE=1 CROP=36,1,52,11 VIEWER=38,3,1 DEVICE=gamepad -- assets/levels/valle_pilares_1.json`.
- **Cracked walls** (`crackwall`, Flappy-only, props `minCharge`, `rows`): solid like the door until a burst with enough
  power breaks it. They hide shortcuts / prizes: the main route never needs them (the zero-charge bot clears every
  Valley stage — `flappy_flight etapa`). The camera's left edge never pushes the player through an intact wall (0.5.170, final review of
  Plan 4): against a wall it is the usual AutoScroll rule. In the Valley stages a wall shuts the entrance of a `tunnel`: a
  shortcut or a gallery with a cage (`flappy_lib`, below). Since the burst spends ALL the charge and a wall absorbs it,
  the charge for a cage behind a wall must be inside, after the wall (`flappy_flight cargas`).
- **Food:** a Flappy level's `apple` with skin `auto` takes its zone's `food` (`Zones.LIST`, via `level.id`, the level's
  file name set by `Level.new`); the Valley's is a peach (`food_valle.png`).
- **HUD:** `src/ui/FlappyHud.lua` — hearts (always visible) and the charge meter under score / time; lives stay top
  right.
- Stage objects come from `tools/levelgen/flappy_lib.py`: `at_gaps` (charges / food at the centre of chosen pillar
  gaps), `cubby` (a cracked wall at rows 1-2 with one thing shut in behind it; no longer used in the Valley: a
  single-cell pocket leaves no place for the charge its cage needs), `tunnel(c0, c1, gaps, min_charge, floor=3)` (rows 1
  to floor - 1 behind a cracked wall as tall, over a floor of solid blocks; the pillars inside lose those rows —
  `build(..., air=)` —; the gaps below start at floor + 2 or lower; the Valley uses `floor=5`, the only height that
  can be flown), `corridor`, `ledge` ([§ The Valley's stages](#the-valleys-stages-plan-5b)), `launcher(col, row)` (a net-launcher and its `mount`
  from row + 1 to the bottom edge: `write(..., mounts=)`). `write(..., background=)` sets the level's sky biome. NO
  FLOOR (Plan 5d): every pillar column runs from row 1 to the last row except its gap, so the bottom pillars reach the
  bottom edge; `flappy_campaign zonas` checks there is no grass / dirt, no pillar floats and every launcher has its
  mount.
  `flappy_campaign zonas` checks every wall SHUTS something: the cell behind its top row cannot be reached from in
  front of it without breaking it (a search through non-solid cells, pillars passable, up to two columns behind).

## The Valley's stages (Plan 5b)

Redesigned 2026-11-11 (see Decisions). Generator `tools/levelgen/levels_flappy_valle.py` (ids kept: `valle_pilares_1/2` since Plan 3, `valle_pilares_3` since
5b; run the script itself, it writes only those three files), all with `"background": "valley"`
([sky-and-biomes](../art/sky-and-biomes.md)), no floor. Each stage is a `Course`: a column cursor and named SECTIONS
that never repeat, each stage with its own idea and a difficulty curve (gap size, pillar spacing, scroll speed,
corridors, net-launchers). Times = the window crossing the stage.

| Stage | Width · speed · time | Idea and sections | Content |
|---|---|---|---|
| `valle_pilares_1` "The pillars" | 260 cols · 200 px/s · ~80 s | welcome, gaps 4 → 3: A five wide pillars every 8 · B a staircase every 6 (up to the top, down to the bottom, up) · C the first CORRIDOR (12 pillar columns in a row, gap 4, waving) · D the NEST: a cage hung ON a pillar at row 2 over a low gap (the burst passes pillars: fire from the top of the previous gap, then dive) · E gaps of 3 every 7, jumps of 2-3 rows · F the DIVE: a cage at row 10 between two low gaps, next to the bottom edge (charge 2) · G a zigzag every 5 | 9 charges, 3 food, 3 cages (`shield` row 3 charge 1 — the old one, same entity index 8 —, `small` charge 1, `heart` charge 2), no walls |
| `valle_pilares_2` "Cracks and ledges" | 338 cols · 210 px/s · ~97 s | gaps of 3: A warm-up every 7 · B CRACKS: the open cage (row 2, charge 2) and the GALLERY: a 4-row tunnel (`tunnel(..., floor=5)`) behind a wall (charge 2) with, INSIDE, first a charge and then the cage (charge 1), so the charge for the cage can only be taken after the wall · C the canyon (20-column corridor of 3, slopes of 1 row per 2-3 columns) · D DOUBLE pillars (two, 3 columns apart, second gap 1 row off) · E the LEDGE (`flappy_lib.ledge`): a stone floor at row 5 splits the screen; below the safe gaps, above 4 free rows (no stalactites), 2 charges and a cage · F rhythm every 5 (jumps of 3-4 rows) · G a tight descent (a pillar every 4) · H a second 21-column canyon · I big jumps every 6 | 14 charges, 3 food, 3 cages (`heart` and `magnet_points` — the old ones, indices 11 and 10 —, `ghost` on the ledge, charge 2), 1 wall |
| `valle_pilares_3` "The Evil Monster's machine" | 354 cols · 225 px/s · ~95 s | gaps of 3 and NEEDLES of 2 (single columns only), 11 `netlauncher`: A warm-up every 6 · B one launcher under a high route · C the TUNNEL shortcut (4 rows, floor at row 5, wall charge 2; the pillar before it is high so the entry is reachable) over TWO launchers (row 10) · D needles · E the BATTERY: three launchers in a row under the route (with charge, drop to row 9 and burst one), and a cage hung on the last pillar at row 10, next to the third launcher's mount (fly down between them) · F the Evil Monster's LEDGE: two launchers (row 10) under a stone floor at row 5 (nets stop on it) — below the nets, above no nets but one-row stalactites (rows 2-4 free) · G a guarded corridor (slow slopes) with a launcher at its exit · H the old high cage (row 1, charge 3, `strength`, index 15) · I the snake: corridor of 4 with 1-row-per-column slopes · K a needle staircase every 5 with a cage hung at row 3 over the lowest needle (row 8) · J the final: needles with launchers between | 16 charges, 4 food, 3 cages (`strength`, `shield`, `magnet_all` charge 2), 1 wall |

Rules kept by the generator: the main route never needs a wall, a charge or a ledge's upper route (the zero-charge
pilot of `flappy_flight etapa` finishes all three); a net-launcher stands 3+ columns from the pillars beside it; corridor
steps are at most 1 row per column (`flappy_lib.corridor` asserts it); a gap of 2 is never a corridor (a flap rises
75 px, a gap of 2 leaves 83 px for the 45-px hitbox: one column is a timing test, several would be near impossible);
every UPPER route (ledge, tunnel, gallery) has its stone at row 5 or lower: 4 free rows, because touching the stone
costs 1 HP (landing on anything solid in flight) and the monster needs room — its outer box spans 27 px above its centre
and 48 below, its inner box (pillars) 14 above, and one flap rises FLY_FLAP² / (2·FLY_GRAVITY) = 450² / 2700 = 75 px —:
the centre has 181 px over the stone (130 under one-row stalactites); with the stone at row 4 and stalactites it had 66 px
(less than one flap: impossible), the old tunnel at row 3 had 53 (`flappy_flight etapa_arriba` flies every upper route
and fails below one flap + 30 px); every cage and wall can be opened with the charges taken since the previous one,
assuming the player fired at everything before (`flappy_flight cargas`: the burst spends ALL the charge and a wall or a
cage stops it even when it is short); the cages of the old layout keep their ENTITY INDEX and gift (`rescued` in saves stores the index: `Course.cage(...,
legacy=)`). New `flappy_lib` helpers: `corridor(c0, tops, h)`, `ledge(c0, c1, gaps, row)` (a gap with top 2 under a
ledge = a one-row stalactite). Cages can hang on a pillar cell (they are ghosts and the burst passes pillars); a hole in a
pillar would leave a floating chunk (`zonas` forbids it).

The net-launcher and the flyer: it fires every 3.5 s once a player is within 20 tiles (first shot after 1.5 s), so at
225 px/s the second shot comes when the player is ~2.5 tiles before it. Waiting at the window's left edge is not
always enough (the edge carries the player into the column while the net still rises); the pilot of `etapa` does
what a player would: dash past during the 0.6 s glow when it is close, hang back when it is further, wait while a net
rises ahead. Pilot results (no healing, 3 HP): main route 3 → 3, 3 → 3, 3 → 2 HP; upper routes (`etapa_arriba`, walls removed) stage 2
3 → 3, stage 3 3 → 2 HP, never touching the stone.

## Evil Monster machines (Plan 5b)

- **`netlauncher`** (`types/traps/netlauncher.lua`, Flappy-only, `pace = 'trapPace'`): a ground turret. Every `T.EVERY`
  (3.5 s) it glows `T.AIM_T` (0.6 s, `clawServo`) and fires one net straight up at 520 px/s (`netFire`; the net is a `netshot`, whose pace is `bossPace`, so its speed is scaled: Easy x0.7, Normal x0.85, Hard x1; the launcher's own clock follows `trapPace`: Easy x0.8, Normal x1, Hard x1.1). The net is the
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
falling out of the bottom edge would cost 1 HP. `valle_redcoptero`: pillars at columns 18-60 (3 charges, 1 food), zone
66-85 with the `netcopter` at (81, 5) and music `tuffi`, finish at column 93, the Valley sky (`background: valley`).
No floor, like every Flappy stage since Plan 5d (before: grass on the last row, `floor=H`, after the user's "too high"
of 2026-11-08). 11 rows is the most the fixed 720-px camera shows whole.

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
`ataque`, `jaula`, `lanzarredes`, `lanzarredes_techo`, `muro`, `etapa` on every Valley stage, `etapa_arriba`, `cargas`), `netcopter_rules` (`etapa_jefe`: the boss stage is passable
— arena reached, camera stopped, zone fighting, walls down after the win, finish touched; `muerte_en_pelea`: respawn in
the air inside the zone with full HP), `touch_layout` (`especial`), `menu_flow` (`flappy_slots`, `mapa`, `tienda`,
`continuar_flappy`, `candado`).

**Decisions**
- 2026-11-11 (0.5.196), the user asked for a BIGGER cage, a DIFFERENT flappy in each that looks like the game's
  flappies, and a prompt saying what to do. Built as above; the variant comes from the level (order among its cages),
  not from a stored or sent value, so saves and the protocol do not change; a pure position hash was tried first and
  repeated flappies inside a stage. The hitbox grew only to contain the drawn cage (the old box stays inside it). The
  looks of the 8 flappies, the size and the bubble's wording are for the user to judge.
- 2026-11-11, the user after playing the redesign: "bastante bien" (quite good), with two problems. (1) The LEDGES: the
  stone hurts and cannot be stood on, so the route over it was "literally impossible" → every upper route (both ledges,
  the stage-3 tunnel and the new gallery) has its stone at row 5 (4 free rows: 181 px for the monster's centre, 130 under
  stalactites, against a 75-px flap; it was 66 and 53), stage 2's upper route lost its stalactites, the pillar before
  each walled entry is high enough to reach it, and `etapa_arriba` flies them. (2) Stage 2's cracked wall: after breaking
  it there was no charge left for the cage behind it (the charge sat in front of the wall, so it was spent on the wall)
  → the cubby became a GALLERY with the cage's charge inside, after the wall, and `cargas` checks every cage and wall
  of the three stages (all freeable: the numbers are in its message).
- 2026-11-11, the user: the Flappy stages of the first zone are "quite short, repetitive and very easy"; keep the
  special attack, the cages, the power-ups and the wheel, and the boss stage as they are. → The three Valley stages
  redesigned ([§ The Valley's stages](#the-valleys-stages-plan-5b)): ~2-2.5x longer (130 / 139 /
  139 cols, ~38-41 s → 260 / 331 / 350 cols, ~80 / 95 / 95 s), sections instead of one pillar pattern, speed 200 /
  210 / 225, gaps 4-3 / 3 / 3-2, corridors, ledges with a risky upper route, cages that need aiming or a dive, launchers
  alone, in a battery, under a ledge and between needles. Tried and dropped while building: corridors of 3 with long
  1-row-per-column slopes (the pilot could not follow them; kept short, in a corridor of 4, in stage 3 only), doubles one
  column apart (a 2-row passage for 3 columns), holes in pillars for cages (floating chunks). Feel and difficulty NOT
  judged yet: only the pilot proves them passable.
- 2026-11-08, the user after playing 0.5.179 (Plan 5d, [flappy-plan-5d-valley-fixes](../design/flappy-plan-5d-valley-fixes.md)),
  six points + one: (1) the merchant's place does not stand out -> the TIENDA / SHOP sign over its nest; (2) the stage
  ground was still the meadow's and (3) better no ground at all: pillars rise from the bottom edge as they hang from the
  top -> `Level.openBottom`, the bottom-edge rule (1 HP + bounce), tile `mount` under the net-launchers, the glowbomb
  bursting at the zone's bottom; (4) the boss intro must not drop and bounce the monster -> auto-hover while frozen;
  (5) music for the map -> `map_flappy` "Cielo abierto" (A installed, B a preview; the user chooses, NOT listened to by
  the author); (6) the Flappy menus should have the old endless-mode blocks background; extra: the boss stage also gets
  the Valley background (and the sky lost its grass band: a violet haze). CORRECTION by the user: the checkered
  background belongs in the DEBUG menu only; the Flappy menus keep the bot scene (and the idea "the bot should play
  Flappy levels when there are many" is saved in [flappy-prequel](../design/flappy-prequel.md#later-menu-background)).
  Plan 5d decisions: no floor row in any Flappy level; one generic bottom-edge rule; mounts are solid tiles; the
  bomb bursts at the zone bottom; the hover is generic in the flight code; the sign's text is translated and drawn with
  the game's font. All art and the music are provisional until the user judges them.
- 2026-11-08, the user: approved the Plan 5b proposal (Valley look, 3 stages, map, shop + wallet) unchanged.
- Plan 5b: the grade-reward points also enter the wallet; replaying a finished stage adds its points again (farming
  is allowed, prices are high) - FLAGGED for the user to confirm. All 5b art (sky, map, merchant, net-launcher) is
  provisional until the user plays it.
- 2026-11-08, the user: the first boss is the Net-Copter as proposed; `tuffi` music for all Flappy bosses for now
  (details in [netcopter](../bosses/netcopter.md#history)).
- 2026-11-07, the user: FLAPPY first in the main menu, CONTINUE = the last mode played, Free Play only in the debug menu.
- Plan 5b: inserting `valle_pilares_3` before the boss means an old slot with stages 1-2 done must clear stage 3 before the boss; no data is lost and a beaten boss stays done.
- Final review of Plan 3 (fixed in 0.5.168): the grade reward was shown but not given; RETRY did nothing; `taken`
  was not passed (extra lives could be farmed once stages have them).
- 2026-11-08, the user, after Plan 4 (0.5.170): "por lo demás, diría que está bien" — the charge, attack, cages,
  walls, food and HUD stand as built.
- Plan 3 rulings: finishing the placeholder zone does not unlock Adventure (`Campaign.finished` only counts with
  `READY`); the slot screen is shared with the story through descriptors instead of a copy.
