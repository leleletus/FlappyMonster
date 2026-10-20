# Menus (title, main menu, sub-menus, save slots, transitions)

**What:** every menu screen sits on the same **living background**: a real RACE level of one of the islands played
by a bot — enemies, spikes, water, checkpoints and the finish with their normal rules (no HUD, no music, silent). The
monster takes hits, dies and respawns at the last checkpoint with endless lives, and its goal is to **reach the
finish**; when it does, a pixel **iris** closes on it, the next level loads in the dark and the iris opens on the
monster again. The **title and the main menu are one screen**: the logo's white box (the original logo, remastered)
drops in with a bounce, its letters pop in one by one and then sway in a wave; pressing a button makes the logo rise
and the buttons come in from below one after another. Buttons are pixel-art 9-slices in muted colours with the
cursor (a gold arrowhead, placed where it fits) next to the selected one and a description of it at the bottom. Screens **enter and leave
with animations** (staggered slide-in with a small bounce, quick slide-out; the logo and the top banners leave
upwards), and leaving the menus (to a level, the story map, the slot screen, Free Play, online) uses the same
**iris** (closing on the centre or on what was chosen, a moment of black, the state changes, it opens). The story
save slots are **cartridges** (Sonic 3 style save select).

**Files**

| File | Role |
|---|---|
| `src/states/menu/TitleState.lua` | title + main menu (`title` starts on the title, `main_menu` starts with the buttons; `args.selected` = 1 adventure, 2 classic, 3 settings) |
| `src/states/menu/AdventureModeSelectState.lua`, `SettingsState.lua`, `src/states/flappy/DifficultySelectionState.lua` | the sub-menus, built with the pieces below |
| `src/states/story/StorySlotState.lua` | the save slots as cartridges (see below) |
| `src/ui/menu/MenuScene.lua` | the living background: `SCENES` (level + seed), `SCENE_MAX`, `STALL`, `CAM_X/CAM_Y` (where the monster sits on screen), iris timings; `update`, `draw`, `backdrop()` (background + big dark panel for content screens), `dim(a)` |
| `src/states/adventure/AdventureState.lua` | `args.demo = { step, camX, camY }`: the demo mode MenuScene uses (no View lock, HUD, pause, music or recorder; endless lives; `step(dt, level)` moves the player instead of the pad); `rebindGlobals()` |
| `src/ai/Bot.lua` | the bonus bot, reused: `opts.goal` (own goal instead of the point zones; returns goal nodes, kind, approach x), `opts.mortal`, `opts.dodge` (caution, below) |
| `src/ui/menu/MenuAnim.lua` | per-screen enter / leave animation: `slide(i, dx, dy[, ex, ey])`, `pop(i)`, `leave(fn)`, `busy()`; offsets snap to 4 px |
| `src/ui/menu/MenuList.lua` | a vertical list of buttons (one geometry for drawing, mouse and touch), plus `header` (title banner) and `footer` (description panel + controls hint) |
| `src/ui/menu/MenuButton.lua` | draws a button / the panel from the 9-slice sheets |
| `src/ui/menu/TitleLogo.lua` | the remastered logo (box + letters, intro animation, wave); used by the title and by the story ending film |
| `src/ui/menu/Transition.lua` | the iris; `Transition.go(state, args[, x, y])` instead of `gStateMachine:change` (hooked in `game.lua`: update, render, and input blocked while it closes); `Transition.drawIris(k, x, y)` (also used between background scenes) |
| `assets/images/ui/menus/title_logo.png` + `.json` | the remastered logo: the box and each letter separately (sheet + where each letter goes) |
| `assets/images/ui/menus/button.png` + `.json`, `panel.png` | buttons (one column per colour; row 1 normal, row 2 selected; the palette is muted by `MUTE` toward grey) and the panel |
| `assets/images/ui/menus/cartridge.png` + `.json`, `cart_labels.png` | cartridge shells (red, blue, green, grey = empty; normal / selected) and the island windows (one per world + "new") |
| `assets/nav/<level>.json` | the bot's navigation graph of each background level (`tools/tests/run.sh bot_nav BUILD=1 -- assets/levels/<level>.json`) |
| `tools/art/ui/make_menu_ui.py` | writes every image above. The logo comes from `logo.png` (kept as is): every pixel of the box and the letters is kept, scaled 2×, with the house style added (box: navy outline, light top-left, shade bottom-right, an inner line echoing the original frame, a 2-px relief lip; letters: almost-black navy with a light top edge and a soft embossed shadow on the white); drawn at `LOGO_SCALE / 2`, so it takes the old logo's size |

`Menu.png` / `MenuDif.png` (the old black-and-white frames) are no longer used by any screen.

**Data**

- Scenes: `MenuScene.SCENES = { { level = 'valle_soleado', seed = 15 }, … }` (today: valle_soleado, arrecife_globo, fabrica_morteros, cumbres_escarcha). Only RACE levels (mode `race`, no boss
  zones, no point zones) whose graph reaches the finish. A scene runs at FIXED 1/60 s steps with its own random
  generator (`seed`), so the race is always the same one: a run where the bot reaches the finish (with its hits and
  deaths on the way). Find a seed with `tools/tests/run.sh menu_flow FINDSEED=40 LEVELS=<level>`; re-find them when
  the level, the bot or the physics change (`menu_flow` fails if a scene stops reaching the finish). A scene also
  ends after `SCENE_MAX` s, or after `STALLS` times `STALL` s without getting closer (it gives up: dies and retries
  from the checkpoint, then moves on).
- Button colours: `green orange blue pink purple yellow red teal grey` (the order of `button.json`). Adding one =
  a palette entry in the generator.
- Continue: shown only when a story slot exists; it opens the most recently written slot file
  (`story<n>.sav` modtime) and goes to the story map. No new saved data.

**The background race:** `MenuScene` creates an `AdventureState` with `args.demo` (the real level, its entities and
rules) and a `Bot` driving `state.player` with `{ mortal, dodge, goal = the finish }`. Everything it does runs inside a
wrapper: `Sound` and `Input` are stubs (silent, the pad is ignored) and `math.random` is the scene's own generator.
Particles and decoration effects keep the normal `math.random` (they are created while DRAWING: with the scene's
generator, how many frames were drawn changed the race). The bot follows its graph to the finish; with an enemy
within `GUARD_R` tiles it is **cautious** (`opts.dodge`): it simulates what it is about to do on a "ghost" copy of the
player with the real physics (`Bot:_safe`: the enemies are assumed to keep moving as they are; hazard boxes count; a
stomp from above is fine) and, if it would get hurt, tries jumping forward, a double jump, a hop, waiting, jumping in
place or backing off, and plays the first safe one. Near the finish it walks until it actually touches it. Nothing
touches saves or the network.

**Save slots (cartridges):** three cartridges in a row (red, blue, green; grey when empty), number on the grip,
the label shows the island where the save is (its world's window), the world name, a progress bar with
levels done / total, play time, difficulty and lives; the footer shows the world and the mirror shards. The selected
one rises and bobs; DELETE is a button UNDER the selected cartridge (second press confirms), never over its
information. Choosing one makes the cartridge "go in" (rises a bit, drops) and the iris closes on it. An empty one
asks the difficulty (muted coloured buttons, locked ones grey with a lock, the description in the footer).

**SP / server / client:** client only. The demo is a local single-player simulation, never online.

**How to extend**

- A new menu screen: `MenuScene.update(dt)` in `update`, `MenuScene.draw()` first in `render`; a `MenuAnim` for its
  elements; `MenuList` for a list of buttons; leave with `anim:leave(function() gStateMachine:change(...) end)` to
  another menu screen, or `Transition.go(...)` to anything else.
- A content screen designed over black (Free Play, online): `MenuScene.backdrop()` instead of its background.
- A new background scene: build its graph, find a seed (`FINDSEED`), add `{ level, seed }`.
- New player-facing text: keys in both `assets/lang/es.lua` and `en.lua` (`menu.*`, `adv.desc_*`, `story.slot_*`).
- Code that runs inside the demo must not depend on drawing: `menu_flow DETCHECK2=<scene>` finds the first step where
  drawing changes the race.

**Tests:** `menu_flow` — title (letters fall, press opens the menu, back closes it), every button reaches its
screen and back returns with that button selected, language change in Settings, the iris (the screen underneath is
frozen while it closes), the cartridges with two saves (1280 / 960) and the difficulty picker, Continue only with a
save and it reaches the story map, every scene is a race level with an up-to-date graph and its seed reaches the
finish, the same race with a variable real dt, death + respawn with endless lives, the iris between scenes; captures
at 1280 / 960 / 1600 (`<save>/menu_*.png`). `story_flow` waits while a cartridge goes in or the iris covers.

## Online screens

**What:** the whole online area (login, room list, create-room wizard, password, room, game-mode menu, pause and
spectator windows in a match, results board, network error) is built from the same pieces as the other menus: the
living background with its panel, a coloured title banner (purple for online, red for the error), muted 9-slice
buttons with the cursor marking the selected one, and the boxes below. Names typed by players (rooms, players) are
drawn in the normal font (the pixel font lacks most symbols); labels, buttons and headings in the pixel font.

| File | Role |
|---|---|
| `src/ui/menu/MenuKit.lua` | the shared pieces: `box(kind)` — `well` (sunken: text fields, lists), `card`, `card_sel` (white edge), `window` (on top of everything) —, `field` (text field with block cursor; `mask` for passwords), `section` (pixel-font label + rule), `stepper` (◀ value ▶ button; `stepperSide` = which arrow was tapped), `arrow`, `marker` (the cursor, also used by `MenuList`; see `cursor.png`), `title` (`MenuList.header`, or the normal font on the same banner when the pixel font lacks a letter: `PixelFont.has`), `hint`, `dim`, `text` |
| `assets/images/ui/menus/cursor.png` | the menu CURSOR (a gold arrowhead with a notch, 8×11, pointing right; `make_menu_ui.py`). **Smart placement** (`MenuKit.marker` / `place` / `flush`): every button, box, panel and text drawn in the frame records its rect (`MenuKit.occupy`, called by `MenuButton.draw` / `panel`, `MenuKit.box` / `text`, `PixelFont.draw`); screens only *ask* for the cursor and `game.lua` draws it after the screen. It tries LEFT, RIGHT, ABOVE, BELOW the selected button and takes the first spot that is inside the smallest box containing the button (the screen if none) and touches nothing else; it is rotated to point at the button and nudges toward it. No free spot → no cursor. `MenuKit.dim` clears the list (what is under a window does not count) |
| `assets/images/ui/menus/box.png` | the four boxes (8×8 cells, cut 2), written by `tools/art/ui/make_menu_ui.py` |
| `src/states/online/OnlineLoginState.lua`, `OnlineHubState.lua`, `OnlineRoomState.lua`, `OnlineErrorState.lua` | each has ONE layout function used by drawing, mouse and touch; enter / leave with `MenuAnim` (windows slide in with their own) |
| `src/ui/ModeSelectMenu.lua` | the game-mode menu (online room and Free Play): tabs are buttons in the mode's `button` colour (`src/world/modes/<mode>.lua`), level cards are boxes |
| `src/states/online/OnlineAdventureHud.lua` | pause and spectator windows (geometry in `OnlineAdventureState:_pauseRects / _specRects`) |
| `src/states/online/OnlineResultsState.lua` | results: podium and celebration as before; the board rows are cards, the column heads pixel-font labels |

**Room difficulty (host):** in a WAITING room the host has a selector **◀ DIFFICULTY: X ▶** among the action buttons:
left / right (or tapping either half) goes through "none" (the game as it is) and EVERY id of `Difficulty.ORDER`, wrapping
round; online nothing is locked (unlocks are a story thing). Its button takes `Difficulty.COLORS[id]` (also used by
the story's difficulty picker); the bottom line shows `difficulty.desc.<id>`. It sends the existing
`set_difficulty { difficulty }` (admin only, WAITING; no protocol change); until the server's `room_update` comes
back the screen shows the requested one (`pendingDiff`). Everyone sees it as a pill on the game card, and it reaches
the match in `game_init` as before (`docs/gameplay/difficulty.md`).

**Tests:** `online_menus` (every screen at 1280 and 960 against the local server, the selector through every
difficulty and back, the match starting with it). `online_smoke`, `online_boss`, `free_play` cover the rest.

**Decisions / history**

- 2026-10-20 (3.103.0): requested by the user ("the menu is just the usual background with a lot of monsters
  bouncing and the logo… simple and easy to improve"). Proposals 1 (living background), 2 (title + menu merged,
  Continue) and 3 (animated logo) were accepted, plus enter / leave / transition animations and changing
  backgrounds, buttons and layouts so everything feels livelier, more fun and less cold and monochrome. The
  bouncing monstritos were dropped (the running monster replaces them; their constant jump sounds were noise).
- 3.103.1, the user: the logo and the buttons were too colourful (everything else liked). The rainbow logo (one
  colour per letter, no box) was replaced by the original white box and dark letters, remastered; the button
  palette is muted 38 % toward grey.
- 3.104.0, the user:
  - choosing a button made the logo go DOWN to the middle, stay and vanish: it now leaves upwards and fades (so do the
    top banners: `slide` takes the exit direction);
  - the background looked strange: no enemies, and the monster fell on spikes without being hurt. It is now a real
    race (enemies, damage, death, respawn, endless lives, the finish as goal), only race levels. First attempt: the
    bot with a reactive "jump at the enemy ahead" — it jumped blindly into spike pits and waited forever in front of
    still enemies; most race levels also need Activators, bombs or trampolines the graph can't use, so the bot never
    reached the finish (pradera_explosiva, bosque_interruptores, playa_rebotes, jungla_colgante, canon_trampolines,
    cavernas_cristal, fabrica_criogenica, cantera_dinamita, caldera_roja). The caution simulation + fixed steps +
    one seed per scene give a run that always finishes;
  - the pixel dissolve between scenes (and the block wave between screens) looked abrupt / out of place: both
    replaced by the iris;
  - the slot cards had their text covered by DELETE at some resolutions: redesigned as cartridges, DELETE below;
  - the story ending film now shows the remastered logo too.
- 0.5.0 (2026-10-20), the user: a facelift and style normalisation of the whole online area, and the host able to
  change the round's difficulty among all the existing ones. The online screens were still the pre-remaster style
  (black boxes, white outlines, white-filled selected buttons); they now use the menu pieces above. The host already
  had a "DIFICULTAD: X" button that only cycled forward with a hard-coded list; it is now the ◀ ▶ selector over
  `Difficulty.ORDER`. Single-player pause / game-over windows still use the old look (not part of this request).
  Then, the user: in the create-room wizard the NEXT button of step 2 was useless — choosing PUBLIC / PRIVATE now
  advances by itself (only CANCEL remains); the max-players step went back to separate ◀ / ▶ buttons beside the
  number (new style: the number in a sunken box, blue arrow buttons, grey at the limits); and sizes were balanced so
  the important thing stands out: button text at pixel scale 4 (5 for the main action of a screen and the privacy
  choices) instead of 6, buttons 56 px high, the error screen led by its message with the error code small below.
- 0.5.1, the user: the menus used the monster's life icon as the cursor; it is now a cursor of its own (an arrowhead,
  "not just a >"), and SMART so it never overlaps: left, else right, above or below, else hidden. Applies to every
  menu (`MenuList` too). Texts count as obstacles (first try put it on the privacy description); a dimmed screen
  under a window does not (it hid the cursor of every window).
- Not yet judged by the user: the look on a real screen, the animation timings, the menu sounds (existing `select`
  sound at different pitches, not listened to), performance on Switch / Android (the menu now simulates and draws a
  full level with its enemies every frame).
