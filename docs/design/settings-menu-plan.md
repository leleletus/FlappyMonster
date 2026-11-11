# Settings menu rework — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** replace the long button list of `SettingsState` with a tabbed panel of uniform rows (switches, volume bars,
`< value >` pickers) on a drifting checkered background, and move SETTINGS out of the main menu into a gear button in
the bottom-right corner.

**Architecture:** the options become DATA (`src/ui/menu/SettingsRows.lua`: tabs → rows with a kind, a getter and a
setter) that a rewritten `SettingsState` lays out and draws; one layout function serves drawing, mouse and touch. New
pixel art comes from one committed generator. `TitleState` loses its SETTINGS item and gains a gear button reachable
by pointer and by moving down past the last button.

**Tech Stack:** LÖVE 11 / Lua; plain-Python PNG generator (no PIL); harness `tools/tests/menu_flow`.

**Spec:** [settings-menu-rework.md](settings-menu-rework.md)

## Global Constraints

- Layout computed at draw time from `WINDOW_W/H`, never at file load; no stencils (clip with `src/ui/Clip.lua`).
- Every image is a real asset file from a committed generator; pixel art, integer positions, hard rectangles.
- Player-facing text only through `assets/lang/translations.csv`, every language column (`es`, `en`).
- Saved data unchanged: `src/core/Settings.lua` keys and `options.cfg` format stay as they are.
- Code comments in Spanish; docs in English; tests only through `tools/tests/run.sh`.
- The switch knob is vertically centred in its track; a visible gap separates the title from the tabs.

## Review Focus

- Language change while on the settings screen: every label, tab name and description re-renders in the new
  language at once (no cached text).
- A tab whose rows do not fit at 960×720: the scroll bar appears and the selected row is always fully visible.
- Touch on a phone: tapping an UNSELECTED row selects it without changing its value (no accidental toggles); a second
  tap on its control changes it.
- Returning from the credits film lands on the OTHER tab with CREDITS selected, not on AUDIO.
- Controller on the main menu: down from the last button reaches the gear, up returns; on the title screen
  (menu closed) the gear is not drawn and cannot be activated.

---

### Task 1: Art — checker tile, gear, switch, volume block

**Files:**
- Create: `tools/art/ui/make_settings_ui.py`
- Create (output): `assets/images/ui/settings/checker.png`, `gear-Sheet.png`, `switch-Sheet.png`, `bar-Sheet.png`
- Modify: `docs/art/generators.md` (one line), `docs/art/asset-layout.md` if it lists `ui/` folders

**Interfaces:**
- Produces: `checker.png` 32×32 (two tones of the muted menu blue, 16-px squares); `gear-Sheet.png` 2 frames of 20×20
  (normal · selected/gold); `switch-Sheet.png` 2 frames of 22×11 (off: grey track, knob left · on: green track, knob
  right; knob vertically centred: equal track rows above and below it); `bar-Sheet.png` 2 frames of 4×7 (empty · full).
  All drawn at an integer scale by the state.

- [ ] Step 1: write the generator (palette from `make_menu_ui.py`'s muted button colours); run
  `python3 tools/art/ui/make_settings_ui.py`; expected: four files written.
- [ ] Step 2: look at each PNG enlarged (Read the image) and check the knob centring and the gear reads at 20 px.

### Task 2: Options as data

**Files:**
- Create: `src/ui/menu/SettingsRows.lua`
- Modify: `assets/lang/translations.csv` (tab names `settings.tab_audio|controls|game|other`; row labels
  `settings.row_<id>`; descriptions `settings.desc_<id>`; values `settings.val_on|off|hold|press`)

**Interfaces:**
- Produces: `SettingsRows.TABS` = list of `{ id, label = key, rows = { row... } }` in the order of the spec's table
  (AUDIO: musicVol, sfxVol, muted, rhythmOffset · CONTROLS: swapAB, rumble, wheelToggle · GAME: language, hitStop,
  showPerf · OTHER: credits).
  Row = `{ id, kind = 'volume'|'switch'|'choice'|'number'|'action', label = key, desc = key }` plus
  `value()` → number | boolean | string (display text for choice / number), `step(d)` (d = −1 / +1; volume clamps
  0..10; number steps 10 ms within −300..300; choice wraps; switch toggles), `go(state)` (confirm: switch toggles,
  choice steps +1, action runs; volume / number: nil).
  Setters go through the existing `Settings.set` / `Settings.setLanguage` / `setRhythmOffset` / `setShowPerf` and
  play `select` with the current pitches (1.08 up, 0.94 down).
- [ ] Step 1: in `menu_flow`, a check `cfg_datos`: every current option id appears exactly once across `TABS`; every
  `label` / `desc` key exists in every language (`L.has`).
- [ ] Step 2: implement; run `tools/tests/run.sh menu_flow`; expected: `cfg_datos OK`.

### Task 3: The settings screen

**Files:**
- Rewrite: `src/states/menu/SettingsState.lua` (keep the state name and registry id `settings`)
- Modify: `input.lua` (actions `tab_prev = {'key:q', 'button:leftshoulder'}`, `tab_next = {'key:e', 'key:tab',
  'button:rightshoulder'}`; labels `[Q]/[E]`, `[L]/[R]`)

**Interfaces:**
- Consumes: `SettingsRows.TABS`, Task 1 images.
- Produces: `SettingsState:layout()` → `{ tabs = { {x,y,w,h}... }, panel = {x,y,w,h}, rows = { [i] = {x,y,w,h} },
  first, fit, scroll = {x,y,w,h} | nil }` (one source for draw, mouse, touch); state fields `tab`, `row`
  (0 = the tab bar), `first`; `enter(args)` accepts `{ tab = id, row = id }` (used when coming back from credits).
- Behaviour (spec § Input): up / down rows (up from row 1 → tab bar; down from the bar → row 1); left / right on the bar
  changes tab, on a row calls `step`; confirm calls `go` (on the bar: down to row 1); `tab_prev` / `tab_next` from
  anywhere; back → `main_menu` with `{ select = 'settings' }` (the gear selected). Touch: tap a tab; tap an unselected
  row = select only; tap the selected row's control = `step(±1)` by half (volume / number / choice) or toggle (switch)
  or `go` (action). Background: `checker.png` tiled, offset `(t * 12) % 32` px diagonally; title via
  `MenuList.header` with a gap ≥ 20 px under it before the tabs; panel via `MenuButton.panel`; description of the
  selected row and the button hints via `MenuList.footer`. Rows clip to the panel with `src/ui/Clip.lua`.
- [ ] Step 1: in `menu_flow`, rewrite the settings block: open settings; `tab_next` ×3 cycles AUDIO→…→OTHER and wraps;
  on AUDIO row musicVol `nav_left` ×2 → `Settings.musicVol == 8` and saved in `options.cfg`; on GAME row language
  `nav_right` → language changes and the tab label text changes with it; touch: tap a tab selects it, tap an
  unselected switch row does not change `Settings.rumble`, a second tap toggles it; at 960×720 a tab that overflows
  shows `layout().scroll ~= nil` and the selected row lies inside `layout().panel`; captures `settings_audio`,
  `settings_game`, `settings_960`. Checks: `cfg_pestanas`, `opciones_son`, `idioma`, `cfg_tactil`, `cfg_scroll`.
- [ ] Step 2: run it; expected FAIL (old screen).
- [ ] Step 3: implement; run `tools/tests/run.sh menu_flow`; expected: those checks OK; look at the captures.

### Task 4: Gear on the main menu; version to the bottom-left

**Files:**
- Modify: `src/states/menu/TitleState.lua` (remove the `settings` item; gear; `_versionRect` and the version print move
  to the bottom-left), `src/states/menu/SettingsState.lua` (credits returns with `{ tab = 'other', row = 'credits' }`)

**Interfaces:**
- Produces: `TitleState:_gearRect()` → `x, y, w, h` (bottom-right, inside a 16-px margin, ≥ 56 px square for touch);
  `self.gearSel` (true while the gear has focus). `args.select == 'settings'` focuses the gear.
- Behaviour: drawn only while the menu list is open (`self.menu`), on every device; `nav_down` on the last list item →
  gear focused (list shows no selection); `nav_up` → back to the last item; confirm / tap / click → `_leave('settings')`;
  hover / focus uses frame 2. Footer description while focused: `menu.desc_settings`.
- [ ] Step 1: in `menu_flow`: `sin partida` expects the order `classic,adventure` (no settings item); new check
  `engranaje`: down from the last item focuses the gear, confirm opens `SettingsState`, back returns with the gear
  focused, up returns to the list; tapping `_gearRect()` opens settings; with the menu closed a tap there does not.
  The 7-tap debug check taps `top():_versionRect()` (now bottom-left) and still opens the debug menu.
- [ ] Step 2: run, expected FAIL; implement; run `tools/tests/run.sh menu_flow`; expected all OK.

### Task 5: Docs and the full battery

**Files:**
- Modify: `docs/architecture/menus.md` (settings screen, the gear, version position, history entry with the user's
  verdict), `docs/design/settings-menu-rework.md` (status: built), `docs/design/README.md` (row), `tools/tests/README.md`
  (`menu_flow` row), `version.txt` (+1)
- [ ] Step 1: `tools/tests/run.sh project_check`; expected OK.
- [ ] Step 2: `tools/tests/run.sh all` (background); expected `TODO OK`.
- [ ] Step 3: commit (Spanish message, `git -c core.fileMode=false`, never `tools/deploy_server.sh`), push.
