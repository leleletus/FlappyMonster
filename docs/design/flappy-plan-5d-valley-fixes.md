# Flappy campaign — Plan 5d: the Valley after the user's first play (implementation plan)

<!-- project_check: future-paths (this plan names files that do not exist yet) -->

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** the user's six points after playing 0.5.179 (2026-11-08).

**Spec (the user's words, Spanish, summarised):** 1. the merchant's place does not stand out; many players will miss
it — a sign saying "SHOP" over it. 2. In the levels the ground is still the meadow's. 3. Better no ground in the
levels: just as the pipes come from above, they should also come from the bottom of the screen. 4. During the boss
intro, instead of the monster falling and bouncing (there will be no ground), it hovers / flaps automatically so it
neither dies nor gets hurt during the intro. 5. Music for the Flappy world map. 6. Extra: the Flappy mode's menus
should not have the classic background of the bot playing; they should have the old Flappy (endless) background, the
one with square blocks.

## Decisions (Claude's calls, told to the user)

- **No floor:** Flappy levels have no ground row; pillar columns reach the level's bottom edge. Falling below the
  bottom edge = what the floor did (1 HP + bounce back up, `PlayerFlight`); one generic rule for every Flappy level.
- **Net-launchers** stand on a solid metal MOUNT block rising from the bottom (art; a solid tile or the launcher's own
  base), the net still fires up.
- **The glowbomb** explodes at the boss zone's bottom edge when it reaches it without hitting anything.
- **Boss intro in Flappy:** while a Flappy player is frozen by the intro, it auto-hovers at its height (small flaps,
  no gravity fall, no damage), generic in the flight code (not the netcopter's).
- **Shop sign:** a wooden sign over the merchant's nest with the translated word (`shop.sign`: TIENDA / SHOP),
  gently swaying; drawn text via the game's font, the board is a sprite.
- **Map music:** an original track for the Flappy zone map carrying "la llamada" ([music-guide](../audio/music-guide.md));
  two variants as previews in `FlappyMonster_pruebas/musica/mapa_flappy/`, variant A installed provisionally until the
  user chooses; verified by numbers only (`tools/music/levels.py`).
- **Flappy menu background:** the old Flappy background (`Background.png`, the square blocks, as the endless mode
  draws it, scrolling) behind the Flappy menu (FlappyCampaignState), the Flappy slot screen and the shop; the zone map
  keeps its Valley art; Adventure menus unchanged.

## Global Constraints

- Golden rules 1–7; level files only rewritten by their own generators (`levels_flappy_valle.py`,
  `levels_flappy_valle_boss.py`; the test arena `NetcopterArena.json` and the flight test stage `_flappy_vuelo.json`
  by their generator or a documented one-off); never `build.py` without `--only`.
- Player text in `translations.csv` (CRLF kept, es + en). Music: never claimed listened to.
- Spanish comments / commits, English docs; no `Protocol.VERSION` change (Flappy not online).

## Review Focus

1. **Falling out the bottom** costs exactly 1 HP and returns the player into the playfield (no chain, no death loop),
   also during a boss fight and right after a respawn. Task 1.
2. **Pillars from below** never leave a gap narrower than today's minimum; the zero-charge pilot still clears every
   Valley stage and the boss stage approach. Task 1.
3. **Boss intro**: the player's HP is unchanged after the whole intro and it is still inside the zone at fight start. Task 2.
4. **The sign** is readable at 960 and 1280 widths and does not cover a node. Task 3.
5. **Adventure menus** keep their bot background. Task 4.

---

### Task 1: No floor — pillars from below, the bottom edge rule, mounts, bomb

**Files:** `src/player/PlayerFlight.lua` (bottom-edge rule replaces the floor rule), `tools/levelgen/flappy_lib.py`
(no ground row; bottom pillars to the edge; launcher mounts), `tools/levelgen/levels_flappy_valle.py`,
`levels_flappy_valle_boss.py`, `levels_flappy_test.py` (regenerate their own files only), `NetcopterArena.json`,
`traps/netlauncher.lua` (+ mount art), `traps/glowbomb.lua` (zone bottom), harnesses `flappy_flight`,
`netcopter_rules`, `flappy_campaign`.
- [ ] Failing cases: `fondo` (fall below the bottom → −1 HP once, back in the playfield; invulnerable after), stages
  have no ground row and bottom pillars touch the edge (`zonas`), `etapa` all three stages, `bomba_fondo` (a lob with
  no target hit explodes at the zone bottom).
- [ ] Implement; regenerate; captures of each stage (Read) → `FlappyMonster_pruebas/valle/sin_suelo_*.png`. Commit.

### Task 2: Boss intro hover

**Files:** the flight code (`PlayerFlight.lua` / where `Level:frozenAt` freezes players), `tools/tests/boss_intro`
or `netcopter_rules` (case `intro_planea`).
- [ ] Failing case: during the Net-Copter intro the Flappy player's y stays within ±0.5 tile of where it entered, HP
  unchanged, inside the zone at fight start. Implement generically. Adventure intros unchanged (`boss_intro` on an
  Adventure boss). Commit.

### Task 3: The shop sign

**Files:** `tools/art/ui/make_flappy_map.py` (sign board sprite), `FlappyMapState.lua`, `translations.csv` (`shop.sign`).
- [ ] Draw the board over the merchant's nest with the word, a gentle sway from a timer; captures at 960 / 1280
  (Read) → `FlappyMonster_pruebas/valle/mapa_cartel.png`; `menu_flow`, `lang_names` OK. Commit.

### Task 4: The old Flappy background behind the Flappy menus

**Files:** find how the endless mode draws `Background.png` (src/states/flappy/PlayState.lua) and make a shared
background drawer (no copy) used by FlappyCampaignState, the slot screen when `campaign = 'flappy'`, and
FlappyShopState; Adventure screens keep MenuScene.
- [ ] Captures (Read) → `FlappyMonster_pruebas/valle/menu_fondo.png`; `menu_flow` OK (and its Adventure cases). Commit.

### Task 5: The Flappy map music

**Files:** a generator in `tools/music/` (follow [music-guide](../audio/music-guide.md), [music-catalog](../audio/music-catalog.md)
and an existing map-theme generator), previews A/B, `INSTALL=1` writes the track (A), `assets/music/index.json`,
`FlappyMapState` plays it (the map's music id as data in `Zones` or the state), `tools/music/levels.py` run, docs
([music-catalog](../audio/music-catalog.md), [music-history](../audio/music-history.md)).
- [ ] Generate previews, install A, wire, `run.sh sounds`/music checks if any, `project_check`, `docs_reference`. Commit.

### Task 6: Docs and release

- [ ] Update [flappy-campaign](../gameplay/flappy-campaign.md), [player](../gameplay/player.md) (flight: bottom
  edge), [netcopter](../bosses/netcopter.md), history with the user's six points; `run.sh` targeted harnesses
  (flappy_flight, netcopter_rules, flappy_campaign, menu_flow, boss_intro, project_check, docs_reference); version + 1;
  commit; the controller pushes and deploys after the final review.
