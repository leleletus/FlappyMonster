# Menus (title, main menu, sub-menus, save slots, transitions)

**What:** every menu screen sits on the same **living background**: a real RACE level of one of the islands played
by a bot — enemies, spikes, water, checkpoints and the finish with their normal rules (no HUD, no music, silent). The
monster takes hits, dies and respawns at the last checkpoint with endless lives, and its goal is to **reach the
finish**; when it does, a pixel **iris** closes on it, the next level loads in the dark and the iris opens on the
monster again. The **title and the main menu are one screen**: the logo's white box (the original logo, remastered)
drops in with a bounce, its letters pop in one by one and then sway in a wave; pressing a button makes the logo rise
and the buttons come in from below one after another. Buttons are pixel-art 9-slices in muted colours with the
monster's head bouncing next to the selected one and a description of it at the bottom. Screens **enter and leave
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
- Not yet judged by the user: the look on a real screen, the animation timings, the menu sounds (existing `select`
  sound at different pitches, not listened to), performance on Switch / Android (the menu now simulates and draws a
  full level with its enemies every frame).
