# In-game HUD layout

What sits where on the play screen, and the rule that keeps HUD elements from covering each other (0.5.204).

## What

The HUD is drawn every frame by the single player state (`AdventureState:_drawHud` → `renderBossHud`) and the online
client (`OnlineAdventureState:_renderHUD` → `_renderBossHUD` → `_renderModeHUD`). Before 0.5.204 every element had a
fixed position, and some collided: the boss bar covered the score (the user), the death message sat against it, the
light overlapped the pause button, and on 960-wide screens the stars sat on the score.

Now every element **reports its rectangle** to `src/ui/HudRects.lua` as it draws, and the ones that go under others
**place themselves** from what is already there:

| Where | What |
|---|---|
| Top left | score and time (fixed) |
| Top right | lives (fixed), the pause button (pointer devices, fixed), the light (dark levels: under the lives, or under the pause button if it is there — `place`) |
| Top centre | the **boss bar(s)** (the user: "it stays where it belongs"), as wide as the free span between the left and right blocks allows (`centerSpan`; it narrows its segments). If that span is under `BossHud.MIN_TOP_W` (960-wide screens), the bar goes just under the top band, still centred |
| Top centre, after the boss bar | the **stars / cages** counter (`CollectHud`, `place`): at the top when free, under the boss bar during a fight (the user: "the star counter is the one that moves") |
| Online, top centre | the mode's objective panel (`place`; a one-line version under the scoreboard on narrow screens) |
| Under everything above, left | the players' health bars, the Flappy hearts / charges and the power-up bag, then the **death message** (moved from the top centre, where it touched the score — the user) |
| Under everything above, centre | `¡CORRE!` (mirror chase), `¡RESACA!` (undertow), the online mode's big status text |
| Middle / bottom, transient | the boss intro banner, the start "¡YA!", the online mode intro strip (starts under the HUD and rises in; its 4 s start counting after the intro card), the online notices (under the HUD), the air bar, the ping |

## Files

| File | What |
|---|---|
| `src/ui/HudRects.lua` | the frame's rectangles: `clear()`, `add(name, x, y, w, h)`, `below([gap])` (first free y under everything at the top), `place(name, x, y, w, h)` (as asked or moved down past what it would cover), `centerSpan([gap])`, `list()`, `overlaps()` (tests) |
| `src/ui/BossHud.lua` | boss bars (`drawZone`, `drawBoss`: width from `centerSpan`), player bars, `¡CORRE!`, `¡RESACA!` |
| `src/ui/CollectHud.lua`, `DeathBanner.lua`, `LightHud.lua`, `FlappyHud.lua` | each places itself |
| `src/states/adventure/AdventureState.lua`, `src/states/online/OnlineAdventureHud.lua` / `OnlineAdventureRender.lua` / `OnlineAdventureState.lua` | the order: top band first, then the fight, then what stacks under |

## How to extend

A new HUD element: `HudRects.add` its rectangle when it draws at a fixed spot, or `HudRects.place` / `HudRects.below()`
when it can move; draw it after what it must stay under. Transient centre-screen elements that may overlap gameplay but
not the HUD go in `FLOATING` (ignored by `below`). Then add it to a `hud_layout` scene.

## Tests

`tools/tests/run.sh hud_layout`: single player scenes with everything at once (a dark boss fight with light, stars,
pause, player bar and death message; a normal boss; the mirror chase; the undertow; a Flappy stage with hearts and bag),
drawn at 960 / 1280 / 1600; nothing may overlap or leave the screen. Captures `<save>/hud_<scene>_<width>.png`
(`fm_test_hud`). Online: `online_smoke` and `online_boss` record `HudRects.overlaps()` every frame (`hud_online`) and
`online_smoke` checks that the mode's intro strip is seen at all.

## History and decisions

- 0.5.204 (2026-11-13): the HUD layout pass. My first version moved the boss bar down under the top band; the user
  rejected it: the boss bar stays at the top centre and the star counter moves. Narrow screens (960) have no room
  between the score and the lives, so there the bar sits just under them. The online instruction strip was checked as
  the user asked: it did not cover the HUD once placed under it, but it was never visible since the intro card (its
  timer ran under the card) — fixed.
