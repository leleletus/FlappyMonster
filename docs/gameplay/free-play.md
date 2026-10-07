# Free Play (single-player level hub)

Aventura → JUEGO LIBRE opens every level as a scrolling grid of cards. Nothing is saved or unlocked: it is the test
hub (for beta testers and for development). It also offers a difficulty chip and starts King-of-the-Hill arenas as a
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
