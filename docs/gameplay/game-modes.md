# Online game modes and point zones

An online room plays a **mode** on a **level**. A mode is one file in `src/world/modes/` (registry
`src/world/modes/Modes.lua`, API documented at the top of `ModeTypes.lua`): which levels it accepts
(`requires(info)`), its HUD texts, which tile triggers it uses, how the round ends and how players are ranked.
Today: **race** (reach the finish), **hunt** (kill the most enemies), **koth** (King of the Hill: score by standing
in point zones). The list is generated in [reference/decorations-and-modes](../reference/decorations-and-modes.md).

A level can whitelist modes with `"modes": [...]` and set `"matchTime"`; `"peaceful": true` (test galleries) is
never listed. The level info every mode decides from comes from ONE function, `Modes.entityInfo`, used by the server
catalog, the editor and `level_check`.

**Point zones** (`src/world/systems/PointAreas.lua`, entity `pointarea`) are also used offline by the story's bonus
matches against the bot ([bonus-and-bot](../story/bonus-and-bot.md)).

**To add a mode:** a file in `src/world/modes/` + its id in `Modes.lua` `TYPES`, texts `mode.<id>.*` in both
language files, an icon PNG in `assets/images/ui/icons/`. **Harnesses:** `online_smoke MODE=…`, `level_check`,
`bot_nav` (KOTH data rules).

## Modes: which levels, the in-match panel, hidden triggers

Game modes: `requires(info)` decides which levels a mode lists
(`info` = {enemies, killable, finish, bosses, autoScroll, pointAreas}); a level
may also whitelist modes with JSON `"modes": [...]` (editor: Nivel tab → Modos
de juego) and set `"matchTime"` (s) for timed modes. Mode defs may set
`emptyHint` (shown when no level qualifies). `m.level` is available to modes.
Mode defs also carry the in-match objective panel (always visible): a compact
3-line panel (MODE / objective / status) at the top between the score and the
lives when it fits (`topFree = WINDOW_W - 832`), otherwise a single thin line
below the score. HIDDEN during a boss fight (the boss bars own the top centre:
y 48 + 72/boss); only a `big` countdown is drawn, below the bars. Texts: `objective` (one sentence) and
`hudLine(md) -> text, urgent, big` (status line from the server hud `md`;
`big` = giant number below, e.g. countdowns). Tile triggers a mode doesn't
list in `triggers` are hidden: `Modes.hiddenTriggers(mode)` →
`level.hiddenTriggers` (Level:render skips those tiles; thumbnails via
`drawPreview(..., mode)`), e.g. the finish is invisible in Hunt/KOTH.

- Hunt rejects levels whose stompable enemies respawn (`info.respawning`). The level
  info for modes comes from ONE function, `Modes.entityInfo(entities)` (server,
  editor Nivel tab, level_check).

- Levels with bosses are Race-only (`hunt.requires` rejects `info.bosses > 0`).

## King of the Hill and point zones

**King of the Hill** (`src/world/modes/koth.lua`, icon 'hill'): timed (`matchTime`, default
150 s; hud `tl` = centiseconds left, big countdown ≤10 s). Any mode whose hud sends `tl`
turns the HUD TIME clock into a countdown (`roundEndAt` = levelTime + tl, smooth). Points come from
**Point Areas** (`src/world/systems/PointAreas.lua`, entity `pointarea`: rect via
`corner` handle, props points/interval/contested; placeholder entity like
`flood`). `PointAreas.update(level, dt, players, award)` is authoritative (SP
and server: server adds ps.score/scoreT and pushes `score` {kind='zone'} +
`fx` 'points' + sound 'pointGain'); `clientUpdate` only drives the visuals
(occupancy, local progress bar via `drawProgress`). The level draws the zones
in `Level:render`. Rank: score, lives, earlier scoreT; nobody scored → no
winner; generic `last_standing` still wins. Hunt rejects levels with zones.
Balance (data, in the level JSONs): Point Areas give 4 points per second
(points 4, interval 1); enemies give 40% of their usual points (floor: 15→6,
10→4) and ALL of them respawn (`respawn` > 0).
KOTH levels: cumbre_cangrejo, rebote_real, marea_alta (`modes: ["koth"]`; they
list no mode until the user places a Point Area in them).

- (5) ONE ACTIVE POINT ZONE (`src/world/systems/PointAreas.lua`; the user: with several at once everybody sits in their own): with ≥ 2 zones in a level their rects are the STOPS of one zone that travels: `HOLD` 18 s at each (`FIRST` +6 at the first, the most central), `MOVE` 2.5 s travelling (no points). A pure function of `level.zoneClock` (`PointAreas.state/isActive/target/live`); SP and server advance it in `update`, the server sends it (`zc` in the snapshot), the client applies it. Drawing: active zone as before, other stops a faint outline (the next one blinks 3 s before), the travelling rect, and an edge ARROW when the zone is off screen. BOT: goes to `PointAreas.target` (the active one, or already the next when it is about to leave), never holds a stop the zone left, re-evaluates the ON/OFF plan per stop, and enters a zone whose floor is gone (broken ice). lago_de_cristal's lake zone now reaches the lake bottom (swimming in the hole counts). Harness `bot_nav` (60 s, follows the stops).
