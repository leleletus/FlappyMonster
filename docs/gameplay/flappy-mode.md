# The Flappy mode

The original game: tap to flap between pipes. It shares nothing with Adventure except the monster's sprites, the
sound module and the story's intro film, which pilots the REAL Flappy `Player` and `Pipe` objects.

**Access (0.5.163; 0.5.167):** the main menu's FLAPPY opens `FlappyCampaignState` (state `flappy_campaign`): CAMPAÑA
(the campaign: [flappy-campaign](flappy-campaign.md)) and, while `Campaign.READY` is false, INFINITO → this endless
mode. Once the campaign is ready, the endless mode is only in the
debug menu ([menus](../architecture/menus.md#debug-menu-secret)). `DifficultySelectionState` takes `args.from`
(`flappy_campaign` / `debug_menu`) and BACK returns there.

**Files:** `src/states/flappy/PlayState.lua` (the game + HUD), `src/states/flappy/DifficultySelectionState.lua`,
`src/flappy/Player.lua`, `src/flappy/Pipe.lua`, constants and `DIFFICULTIES` in `settings.lua`, art in
`assets/images/flappy/`, sounds in `assets/sounds/flappy/`, best scores in `<difficulty>_highscore.dat`.
**Music:** its own track `flappy` ("Aleteo", `assets/music/flappy/`, made by `tools/music/worlds_nes.py flappy`;
[music-history](../audio/music-history.md)); on death its pitch follows the slow-down (`timeScale`). Before 3.97.0 it
played the meadow's `pradera_1`.
**Harness:** `flappy_hud` (`BOT=1` proves every difficulty is beatable at top speed).

## HUD and pacing

- `src/states/` — Title, MainMenu, Play (flappy; HUD: big score in PixelFont with a black margin + shadow (`boxed`), pops on each point and flashes yellow every 10; best with the crown → "¡NUEVO RÉCORD!" blinking once beaten; difficulty plaque top-left in its colour; game-over card. Labels use PixelFont because FONT_* lack uppercase accents; harness `flappy_hud`). Difficulty pacing = `DIFFICULTIES` in settings.lua: pipes spawn by DISTANCE (`spacing`), speed ramps per pipe passed (`ramp` up to `rampMax`), the gap moves at most `maxJump` from the previous one; easy/normal were reworked to be faster (user: "very slow, boring"), `flappy_hud BOT=1` proves them beatable at top speed), Adventure (SP), FreePlay (SP level hub), Online* (login, hub, room, adventure, results, error), Pause

## History

- 2026-11-11, the user: the campaign's first-zone Flappy stages were "quite short, repetitive and very easy" → the three
  Valley stages were redesigned (longer, by sections, a difficulty curve); details and the decision in
  [flappy-campaign § The Valley's stages](flappy-campaign.md#the-valleys-stages-plan-5b). The endless mode on this page
  did not change.
