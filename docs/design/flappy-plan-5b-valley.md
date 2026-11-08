# Flappy campaign — Plan 5b: the Valley's look, its stages, the map and the shop (implementation plan)

<!-- project_check: future-paths (this plan names files that do not exist yet) -->

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** zone 1 (Valley of the Pillars) is complete: its own sky, three real stages and the boss, a drawn zone map,
and the first map SHOP where power-ups are bought with a points WALLET.

**Architecture:** the background is a new `Sky` biome (data: PNGs + one `Sky.BIOMES` entry). The stage-3 hazard is a new
Flappy-only entity that reuses the Net-Copter's `netshot` (golden rule 2: `launch` gains a direction vector). Stages
come from the existing `flappy_lib` generators. The wallet lives in the Flappy save; shops are data per zone
(`src/flappy/Shops.lua`) with one shop state. The map gets real art from a generator and node positions from data.

**Tech Stack:** LÖVE 11.x, Lua; harnesses via `tools/tests/run.sh`; generators in Python (`/usr/bin/python3`, Pillow).

**Spec:** [flappy-prequel](flappy-prequel.md) (§ Zones, § Menus), [powerups](powerups.md) (§ Shops on the world maps),
roadmap row 5b. System pages: [flappy-campaign](../gameplay/flappy-campaign.md), [powerups](../gameplay/powerups.md),
[sky-and-biomes](../art/sky-and-biomes.md).

**The user's approval (2026-11-08)** of this proposal, unchanged:
- **Background:** tall basalt pillars in 3 parallax layers, nests in the holes, other flappies (each a little different,
  NO wings) perched or flying in the far layer, warm day sky. Preview before applying.
- **Stages: 3 + boss.** 1 `valle_pilares_1` = gentle intro (flap, charge, food); 2 `valle_pilares_2` = cages and
  cracked walls; 3 `valle_pilares_3` (NEW id) = the first small Evil Monster machine as a hazard: a ground NET-LAUNCHER
  firing nets upward (reusing the Net-Copter's nets). Ids 1 and 2 stay (stored in saves).
- **Map:** the Valley drawn; stages are nests on the pillars, the boss is the machine's icon, a MERCHANT FLAPPY's nest
  is the shop.
- **Shop + wallet:** a wallet filled with each finished stage's points, separate from the points record (buying never
  lowers the record). The Valley shop sells `shield` 300, `heart` 400, `magnet_points` 250; later zones sell the
  rarer ones; prices high enough that cages stay worth it.

## Global Constraints

- Golden rules 1–4, 6 (no wings: on any flappy), 7 (points enter the wallet only when a stage is FINISHED).
- Ids stored forever: biome `valley`, entity `netlauncher`, stage `valle_pilares_3`, shop data keyed by zone id.
- Pixel art at the game's one pixel density; simple flat shapes ([style-rules](../art/style-rules.md)). Previews to
  `/home/mtvemo/FlappyMonster_pruebas/valle/`; art applied provisionally (the user judges in play, as with the boss).
- Level tools: generators write only their own files; never `build.py` without `--only`.
- Player-facing text in `assets/lang/translations.csv` (CRLF, every language column; keep its line endings).
- Flappy save version + 1 for the wallet, migrating older slots (wallet starts at 0).
- Spanish comments / commits, English docs; no `Protocol.VERSION` change (not online).

## Review Focus

1. **Buying with a full inventory** (6, or 3 of that type): refused with a message, the wallet unchanged. Task 4.
2. **Not enough points:** the item is greyed, nothing is spent. Task 4.
3. **Leaving a stage halfway or dying out:** its points never reach the wallet. Task 4.
4. **The net-launcher never makes a stage unbeatable:** the zero-charge bot (`flappy_flight etapa`) clears all three
   stages. Task 3.
5. **An old Flappy save** (version 3) loads with wallet 0 and keeps everything else. Task 4.

---

### Task 1: The Valley sky (`valley` biome)

**Files:** create `tools/art/world/make_valley_sky.py` (preview / `--apply`), `assets/images/world/sky/valley_*.png`;
modify `src/fx/Sky.lua` (`Sky.BIOMES.valley`, editor label "Valle"), [sky-and-biomes](../art/sky-and-biomes.md).
- [ ] Generator: 3 layers (far: pillars + flappies perched/flying, 2–3 kinds; mid: pillars with nest holes; near: big
  pillar bases + grass), its own day/dusk/night gradient or one the time tints; a test level preview.
- [ ] Preview → Read it → `--apply` (if a gradients sheet is appended, follow the jungle note in sky-and-biomes).
- [ ] A `level_shots`/editor capture of a Flappy level with `"background": "valley"` (Read it). `project_check` OK.
  Commit.

### Task 2: The net-launcher (`netlauncher`)

**Files:** create `src/world/entities/types/traps/netlauncher.lua`; modify `traps/netshot.lua` (`launch` takes a
direction vector, default = today's horizontal behaviour), art in `tools/art/bosses/make_netcopter.py` or a new
`tools/art/enemies/make_netlauncher.py` (small ground turret, junk style, 2–3 frames: idle, aim glow, recoil); tests in
`tools/tests/flappy_flight/` (new case `lanzarredes`).
- Behaviour: Flappy-only, placed on the floor; every `T.EVERY` 3.5 s (difficulty `trapPace`) it glows 0.6 s
  (telegraph + sound reuse `clawServo`/`netFire`) and fires one net straight UP at 520 px/s; the net wraps on hit
  (1 HP + `ctrlLock` 0.4, as the boss's), snags on solids/pillars, leaves the top of the level. Not hittable by the
  burst? — it IS: a burst of power ≥ 1 destroys it (the base `onSpecialHit` for enemies).
- [ ] Failing cases: `lanzarredes` (fires up after the telegraph; a player above takes 1 HP + ctrlLock; a burst
  destroys it; nothing fires while the player is > 1 screen away).
- [ ] Implement; `flappy_flight`, `netcopter_rules` (nets unchanged) OK. Commit.

### Task 3: The three Valley stages

**Files:** `tools/levelgen/levels_flappy_valle.py` (writes ONLY `valle_pilares_1/2/3.json`), `flappy_lib.py` if a
helper is needed, `src/flappy/Zones.lua` (stages `{1, 2, 3}`, boss unchanged), `tools/tests/flappy_campaign`
(`zonas`), `tools/tests/flappy_flight` (`etapa` over all three).
- Stage design: `background = "valley"`; 1 — wide gaps (4–5), gentle heights, 5 charges, 2 food, 1 easy cage, no
  walls; 2 — gaps 3–4, two cages (one behind a cracked wall needing charge 2), food 2; 3 — gaps 3–4, three
  net-launchers placed where the route passes above them, one cage high up, food 2, a wall shortcut. Lengths ~110–150
  columns. The zero-charge pilot clears all three without dying.
- [ ] Failing: `zonas` with `valle_pilares_3` listed (missing file); `etapa` on all three.
- [ ] Generate, add to Zones, run `flappy_campaign`, `flappy_flight`, `project_check`, `docs_reference`. Commit.

### Task 4: The wallet and the shop

**Files:** `src/flappy/FlappySave.lua` (version + 1, `wallet`, migration), `src/flappy/FlappyRun.lua`
(`complete` adds the stage's points to `wallet`; `buy(id, price)` → `'ok' | 'poor' | 'full' | 'type_full'`, writes the
save), create `src/flappy/Shops.lua` (`Shops.LIST[zoneId] = { { id = 'shield', price = 300 }, { id = 'heart', price =
400 }, { id = 'magnet_points', price = 250 } }`), create `src/states/flappy/FlappyShopState.lua` (list of items with
icon, name, price, owned count; greyed when unaffordable; buy with confirm; wallet shown; touch, pad, keys; back to
the map), `assets/lang/translations.csv` rows, [save-data](../architecture/save-data.md).
- [ ] Failing cases in `flappy_campaign`: `monedero` (finish a stage → wallet += its points; leave or game over → no
  change; record untouched by buying), `tienda` (buy ok; poor → nothing spent; full / type_full → refused, wallet
  unchanged), `migrar` (a v3 slot loads with wallet 0).
- [ ] Implement; `menu_flow` gains `tienda` (the shop opens from the map and returns). Run `flappy_campaign`,
  `menu_flow`, `lang_names`, `project_check`. Commit.

### Task 5: The Valley map

**Files:** create `tools/art/ui/make_flappy_map.py` (preview / `--apply`) → `assets/images/flappy/map/valle*.png`
(background painting: pillars, sky; nest node sprites: open / done / locked; the machine icon for the boss; the
merchant flappy's nest), `src/flappy/Zones.lua` (per zone: `map` image id + node positions, including the shop node),
`src/states/flappy/FlappyMapState.lua` (draw the art, nodes at the data positions, the shop node opens
`FlappyShopState`; keyboard / pad / touch as today).
- [ ] Preview → Read → `--apply`; capture via `menu_flow` (`mapa`) — Read it.
- [ ] `menu_flow`, `flappy_campaign`, `touch_layout` (if the map is in it), `project_check` OK. Commit.

### Task 6: Docs and release

- [ ] [flappy-campaign](../gameplay/flappy-campaign.md) (stages, map, shop, wallet), [powerups](../gameplay/powerups.md)
  (shops built), [sky-and-biomes](../art/sky-and-biomes.md), [generators](../art/generators.md), the roadmap row 5b in
  [flappy-prequel](flappy-prequel.md#plans), the entity docs for `netlauncher`; `docs_reference`.
- [ ] `tools/tests/run.sh all` (known failure: `bot_nav` `cascada_dorada`, pre-existing); version.txt + 1; commit; the
  controller pushes and deploys after the final review. Report what only a person can judge (art, stage feel, prices).
