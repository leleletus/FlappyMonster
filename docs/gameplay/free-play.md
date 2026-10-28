# Free Play (single-player level hub)

Aventura → JUEGO LIBRE opens every level as a scrolling grid of cards. Nothing is saved or unlocked: it is the test
hub (for beta testers and for development). It also offers a difficulty selector (◀ X ▶ at the top right — under the title on narrow screens —: key F, tapping either
half, or keyboard / pad: UP from the first row focuses it, ◀ ▶ change it, DOWN / confirm go back to the cards; ORIGINAL → every id of `Difficulty.ORDER`, remembered) and starts King-of-the-Hill arenas as a
match against the bot.

**Files:** `src/states/adventure/FreePlayState.lua`, `src/world/level/LevelCatalog.lua` (the ONE level-info builder,
shared with the server's lobby catalog). **Harness:** `free_play`.

## Details

Aventura → SOLO opens `FreePlayState` (state `free_play`): every level in a scrolling
grid of cards (thumbnail, name, size, monsters, boss, water/floods/auto-scroll/zones,
stars/lives/checkpoints, music, online-mode chips). Nothing is saved or unlocked (a
test hub for beta testers until the story map exists). Level cards come from
`src/world/level/LevelCatalog.lua` — the ONE level-info builder, also used by the server's
lobby catalog (`LevelCatalog.info/load/files/buildPreview`; `RETIRED` = old test files
an installed build still has; `_*` hidden). Loading is incremental (time budget per
frame) and cached between visits; only visible cards are drawn; columns come from the
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
