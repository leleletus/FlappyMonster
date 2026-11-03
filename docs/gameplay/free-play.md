# Free Play (single-player level hub)

Aventura → JUEGO LIBRE opens every level as a scrolling grid of cards. Nothing is saved or unlocked: it is the test
hub (for beta testers and for development). It also offers a difficulty selector (◀ X ▶ at the top right — under the title on narrow screens —: key F, tapping either
half, or keyboard / pad: UP from the first row focuses it, ◀ ▶ change it, DOWN / confirm go back to the cards; ORIGINAL → every id of `Difficulty.ORDER`, remembered) and starts King-of-the-Hill arenas as a
match against the bot.

**Tabs (2026-11-03, the user: "por fin separar los niveles de carrera de los de jefes"):** RACES (levels with no boss
zone) and BOSSES (with one: `LevelCatalog.hasBossZone`, read from the JSON without loading the level). UP from the first
row focuses the tabs (◀ ▶ change), UP again the difficulty. A search looks in both. BOSSES starts with the **BOSS RUSH**
card (`src/story/BossRush.lua`): every boss fight in a row — story bosses world by world, each followed by its secret
bosses, then any other boss-zone level; not EVENT levels —, each level starting inside its first boss arena
(`AdventureState` `atBoss`) and ending when its bosses are beaten (`endOnBoss`, no finish line). Lives carry over (starts
with 5); losing them all ends it. Total time = the sum of the fights; the best with all beaten is kept per difficulty in
`bossrush.dat`. Back in Free Play a summary window shows bosses beaten, time and record.

**Ghost time trials (2026-11-03):** RACE levels (a finish, no boss, not a King-of-the-Hill bonus) are played with
`ghost = true`: `src/story/Ghost.lua` records the player every 1/20 s (x, y, frame, facing); on reaching the finish, a
better time saves it to `ghosts/<level>.dat`; next time the ghost runs alongside (drawn as a translucent `OnlinePlayer`
with its time, behind the player; it touches nothing). The card shows the record. Harness: `free_play` `pestanas`,
`rush_arena`, `rush_cadena`, `fantasma`.

**Files:** `src/states/adventure/FreePlayState.lua`, `src/story/BossRush.lua`, `src/story/Ghost.lua`, `src/world/level/LevelCatalog.lua` (the ONE level-info builder,
shared with the server's lobby catalog), `src/world/level/CatalogWorker.lua` + `CatalogWorkerThread.lua` (the cards in
a thread). **Harness:** `free_play`.

## Details

Aventura → SOLO opens `FreePlayState` (state `free_play`): every level in a scrolling
grid of cards (thumbnail, name, size, monsters, boss, water/floods/auto-scroll/zones,
stars/lives/checkpoints, music, online-mode chips). Nothing is saved or unlocked (a
test hub for beta testers until the story map exists). Level cards come from
`src/world/level/LevelCatalog.lua` — the ONE level-info builder, also used by the server's
lobby catalog (`LevelCatalog.info/load/files/buildPreview`; `RETIRED` = old test files
an installed build still has; `_*` hidden). Cards are computed in a THREAD (`CatalogWorker`, stubs for
`love.graphics` like the headless server, visible cards first) and saved in `freeplay_cards.dat` per game version and
level file, so only the first visit computes them. The thread repeats main.lua's overlay (Switch updates are not
mounted) and, on Switch, sleeps every 20000 VM instructions in case it lands on the game's core (unverified on a real
console). With no thread, or if it fails, the state loads what is missing with a time budget per
frame, as before. At most one thumbnail is built every 12 ms (`PREVIEW_GAP`); only visible cards are drawn; columns come from the
current `WINDOW_W`. Input: arrows/ENTER/ESC, mouse hover + click, wheel, finger drag
(`love.touchmoved/touchreleased` are now routed to states in logical coords). Levels are
started with `{ level, returnTo = 'free_play' }`: AdventureState game over and
PauseState "exit" go back to `returnTo` (Pause looks at the state under it). Level
thumbnails live in canvases → `love.resize` clears `ModeSelectMenu` previews.
Harness `free_play`.
- 0.5.2, the user: Free Play still had the old look. Restyled with the menu pieces (`docs/architecture/menus.md`): teal
  title banner, the difficulty as a selector in its colour (`Difficulty.COLORS`), cards as boxes (preview in a sunken
  well, online modes as coloured pills), a sunken scroll bar. The user also asked how to change the difficulty here:
  the F key (the flashlight key) or tapping the selector.
- 0.5.7, the user: the difficulty could not be reached with keyboard or pad (F / X / Y worked but nobody found it).
  Now it is a focusable item: UP from the top row gives it the focus (cursor + selected look), ◀ ▶ change it. The
  hint says `[UP] / [F]`. Harness `free_play` checks it (`dificultad`).
- 0.5.62: EVENT levels (`LevelCatalog.EVENTS`, JSON `"event": true`) come first, with a pulsing golden frame, an
  "EVENTO / EVENT" ribbon and a one-line description instead of the data lines (`mashup.card_hint`). The first one:
  the [Crab Mega Mashup](../bosses/crab-mashup.md).
- 0.5.77, the user ("I can't find the boss level"): a SEARCH box (top left; under the title on narrow screens, with the
  level count inside it). `/` or Ctrl+F (or tapping it: the on-screen keyboard on mobile) opens it; typing filters the
  cards by name (Spanish and English), file, boss and music, ignoring accents and capitals (`TextUtil.matches`); levels
  not loaded yet are matched by file name until their card loads. Enter or ↓ go back to the cards with the filter on;
  Esc clears the text, a second Esc closes it (it never leaves the screen). Remembered between visits. Harness
  `free_play` (`buscar`).
