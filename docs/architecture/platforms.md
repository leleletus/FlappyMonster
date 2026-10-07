# Screens, scaling and platforms (PC / Switch / Android)

The game runs on PC (Linux / Windows), Nintendo Switch (homebrew, LÖVE port) and Android. One code base; what differs
is the screen shape, the input device and how updates reach the device.

**Files:** `src/ui/View.lua` (logical resolution, gameplay lock), `libs/lovesize.lua` (scale + letterbox),
`src/ui/Clip.lua` (clipping that respects the scale), `src/ui/TouchControls.lua` (on-screen controls),
`input.lua` (keyboard / gamepad / touch → actions), `Makefile` + `resources/` (builds: `make lovefile`, `win64`,
`switch`, `android`). **Harnesses:** `touch_layout`, `sp_boss MOBILE=1`, `story_flow` (three screen widths).

Actions (`input.lua`): `move_left`, `move_right`, `jump`, `crouch`, `light` (levels); `nav_up/down/left/right`,
`confirm`, `back`, `pause`, `resume` (menus); `flap` (Flappy mode). The game uses the Nintendo layout natively (on an Xbox pad A / B are swapped: a known open item).

## Details

- The game draws in a LOGICAL resolution: height 720, width `WINDOW_W` = 720 ×
  aspect (clamped 4:3..21:9) — 1280 on PC/Switch, e.g. 1600 on a 20:9 phone,
  960 on a 4:3 tablet. That is for MENUS only: inside a level (`AdventureState`,
  `OnlineAdventureState` enter/exit → `src/ui/View.lua` `lockGameplay/unlock`) the view
  is FIXED at 1280x720, scaled with letterbox bands, so every device sees exactly the
  same area (boss arenas!). `View.apply()` in `love.load`/`love.resize`. `main.lua` sets it in `love.load` AND `love.resize` (the
  PC window is resizable; Android rotates). **Never compute layout from
  `WINDOW_W/H` at file load time** (a `local X = WINDOW_W - ...` at the top of a
  module keeps 1280 forever): compute it when drawing (see
  `OnlineRoomState:_layout`, `ModeSelectMenu` `fit()`/`panelX()`).

- `lovesize` scales/letterboxes and sets a SCREEN-pixel scissor. So:
  (1) when rendering into a canvas, `love.graphics.origin()` AND
  `setScissor()` first, restore after (scene canvas in Adventure/Online states,
  level thumbnails in ModeSelectMenu); (2) to clip UI use `src/ui/Clip.lua`
  (`Clip.push(x,y,w,h)` / `Clip.pop()`: transformed + intersected scissor).
  Don't use stencils (Switch/Android backbuffers may lack a stencil buffer).

- Mouse/touch → logical coords in `main.lua` with the same scale as lovesize.

- **Touch controls in levels** (`src/ui/TouchControls.lua`, shared by Adventure/OnlineAdventure):
  drawn in SCREEN pixels after lovesize (`game.lua` calls `top:drawScreen()`), so on wide phones
  they sit in the black letterbox bands. D-pad (left: ←/→/↓, diagonals ↓+dir for the crouch
  jump; ↓ in the air = ground pound) + big jump button (right). Touch zones = the whole lower
  left/right halves (finger direction from the pad centre, slide allowed); above 30 % of the
  height nothing counts (HUD/pause). Sprites `assets/images/ui/touch/dpad-Sheet.png` (7 frames
  40x40) and `jump-Sheet.png` (2 frames 32x32) from `tools/art/ui/make_sprites.py`, integer scale,
  D-pad ≈ 30 % / jump ≈ 22 % of the screen height (the user found 40 % too big), 0.38 alpha over
  the game (0.7 in bands). Harness `touch_layout` (8 phone/tablet sizes) and `sp_boss MOBILE=1`.

- Testing other screens: run the REAL main.lua from a scratch app with a
  custom window size and `love.system.getOS = function() return 'Android' end`
  (Input.isMobile), plus a local server/bot for the online menus.
