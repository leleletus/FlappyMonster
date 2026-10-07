# The Flappy mode

The original game: tap to flap between pipes. It shares nothing with Adventure except the monster's sprites, the
sound module and the story's intro film, which pilots the REAL Flappy `Player` and `Pipe` objects.

**Files:** `src/states/flappy/PlayState.lua` (the game + HUD), `src/states/flappy/DifficultySelectionState.lua`,
`src/flappy/Player.lua`, `src/flappy/Pipe.lua`, constants and `DIFFICULTIES` in `settings.lua`, art in
`assets/images/flappy/`, sounds in `assets/sounds/flappy/`, best scores in `<difficulty>_highscore.dat`.
**Harness:** `flappy_hud` (`BOT=1` proves every difficulty is beatable at top speed).

## HUD and pacing

- `src/states/` — Title, MainMenu, Play (flappy; HUD: big score in PixelFont with a black margin + shadow (`boxed`), pops on each point and flashes yellow every 10; best with the crown → "¡NUEVO RÉCORD!" blinking once beaten; difficulty plaque top-left in its colour; game-over card. Labels use PixelFont because FONT_* lack uppercase accents; harness `flappy_hud`). Difficulty pacing = `DIFFICULTIES` in settings.lua: pipes spawn by DISTANCE (`spacing`), speed ramps per pipe passed (`ramp` up to `rampMax`), the gap moves at most `maxJump` from the previous one; easy/normal were reworked to be faster (user: "very slow, boring"), `flappy_hud BOT=1` proves them beatable at top speed), Adventure (SP), FreePlay (SP level hub), Online* (login, hub, room, adventure, results, error), Pause
