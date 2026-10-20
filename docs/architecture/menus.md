# Menus (title, main menu, sub-menus, transitions)

**What:** every menu screen sits on the same **living background**: a slice of a real level from one of the islands
(parallax sky, blocks, water, decorations, light) with the monster running and jumping through it with its real
physics. The scene changes every 16 s with a pixel dissolve. The **title and the main menu are one screen**: the
coloured logo's letters drop in one by one and then sway in a wave; pressing a button makes the logo rise and the
buttons come in from below one after another. Buttons are coloured pixel-art 9-slices with the monster's head
bouncing next to the selected one and a description of it at the bottom. Screens **enter and leave with
animations** (staggered slide-in with a small bounce, quick slide-out), and leaving the menus (to a level, the story
map, the slot list, Free Play, online) uses a **block transition** (a diagonal wave of squares covers the screen,
the state changes, the squares shrink away).

**Files**

| File | Role |
|---|---|
| `src/states/menu/TitleState.lua` | title + main menu (`title` starts on the title, `main_menu` starts with the buttons; `args.selected` = 1 adventure, 2 classic, 3 settings) |
| `src/states/menu/AdventureModeSelectState.lua`, `SettingsState.lua`, `src/states/flappy/DifficultySelectionState.lua` | the sub-menus, built with the pieces below |
| `src/ui/menu/MenuScene.lua` | the living background: `SCENES` (level list), `SCENE_TIME`, `FADE`, `CAM_X/CAM_Y` (where the monster sits on screen); `update`, `draw`, `backdrop()` (background + big dark panel for content screens) |
| `src/ui/menu/MenuAnim.lua` | per-screen enter / leave animation: `slide(i, dx, dy)`, `pop(i)`, `leave(fn)`, `busy()`; offsets snap to 4 px |
| `src/ui/menu/MenuList.lua` | a vertical list of buttons (one geometry for drawing, mouse and touch), plus `header` (title banner) and `footer` (description panel + controls hint) |
| `src/ui/menu/MenuButton.lua` | draws a button / the panel from the 9-slice sheets |
| `src/ui/menu/Transition.lua` | the block transition; `Transition.go(state, args)` instead of `gStateMachine:change` (hooked in `game.lua`: update, render, and input blocked while covering) |
| `assets/images/ui/menus/title_logo.png` + `.json` | the coloured logo, letter by letter (sheet + where each letter goes) |
| `assets/images/ui/menus/button.png` + `.json`, `panel.png` | buttons (one column per colour; row 1 normal, row 2 selected) and the panel |
| `tools/art/ui/make_menu_ui.py` | writes the three images above. The logo comes from `logo.png` (kept as is; the story ending still uses it): every pixel of each letter is kept, scaled 2×, with the house style added (own colour per letter, light top-left, shade bottom-right, 2-px relief below, dark outline of its own colour); drawn at `LOGO_SCALE / 2`, so it takes the old logo's size |

`Menu.png` / `MenuDif.png` (the old black-and-white frames) are no longer used by any screen.

**Data**

- Scenes: `MenuScene.SCENES = { { level = 'valle_soleado' }, … }` — a level of `assets/levels/`. A scene ends after
  `SCENE_TIME`, at the end of the level, or if the monster is stuck (1.8 s without moving forward). Pick only levels
  where it runs the whole time: `tools/tests/run.sh menu_flow LEVELS=a,b,c` prints how far it gets in each.
- Button colours: `green orange blue pink purple yellow red teal grey` (the order of `button.json`). Adding one =
  a palette entry in the generator.
- Continue: shown only when a story slot exists; it opens the most recently written slot file
  (`story<n>.sav` modtime) and goes to the story map. No new saved data.

**The running monster:** `src/story/Actor.lua` (a real `PlayerAdventure` driven by fake input, as in the
cinematics), muted. Each frame it holds right; on the ground it jumps when there is a wall, a gap (no ground within
3 tiles) or spikes / liquid ahead, and double-jumps at the top if there is still a wall or a gap. Enemies are not
spawned (the level is drawn like a cinematic set: `Stage.drawSet`). Nothing touches saves or the network.

**SP / server / client:** client only, drawing only. Not part of the shared simulation.

**How to extend**

- A new menu screen: `MenuScene.update(dt)` in `update`, `MenuScene.draw()` first in `render`; a `MenuAnim` for its
  elements; `MenuList` for a list of buttons; leave with `anim:leave(function() gStateMachine:change(...) end)` to
  another menu screen, or `Transition.go(...)` to anything else.
- A content screen designed over black (slots, Free Play, online): `MenuScene.backdrop()` instead of its background.
- New player-facing text: keys in both `assets/lang/es.lua` and `en.lua` (`menu.*`, `adv.desc_*`).

**Tests:** `menu_flow` — title (letters fall, press opens the menu, back closes it), every button reaches its
screen and back returns with that button selected, language change in Settings, the block transition (the screen
underneath is frozen while covering), Continue only with a save and it reaches the story map, every scene of
`SCENES` runs without the monster getting stuck, the pixel dissolve ends; captures at 1280 / 960 / 1600
(`<save>/menu_*.png`).

**Decisions / history**

- 2026-10-20 (3.103.0): requested by the user ("the menu is just the usual background with a lot of monsters
  bouncing and the logo… simple and easy to improve"). Proposals 1 (living background), 2 (title + menu merged,
  Continue) and 3 (animated logo) were accepted, plus enter / leave / transition animations and changing
  backgrounds, buttons and layouts so everything feels livelier, more fun and less cold and monochrome. The
  bouncing monstritos were dropped (the running monster replaces them; their constant jump sounds were noise).
- First pick of scenes had three levels where the monster got stuck at trampoline walls (playa_rebotes,
  bosque_interruptores, fabrica_morteros); replaced by levels where it runs the full 16 s.
- Not yet judged by the user: the look on a real screen, the animation timings, the sound of the menu clicks
  (existing `select` sound at different pitches, not listened to), performance on Switch / Android (the menu now
  draws a full level every frame, as the cinematics do).
