# Testing without a human

**Always start here — never rebuild a test setup by hand.** Every harness is a small LÖVE app in `tools/tests/<name>/`
(symlinks to `src`, `assets`, `libs`, `settings.lua`, `input.lua`) and runs through ONE command from the repo root:

```
tools/tests/run.sh all                              # the battery (parallel, no visible windows), exit 0 / 1, ends with "TODO OK"
tools/tests/run.sh <harness> [VAR=val ...] [-- args]
```

`tools/tests/README.md` is the table of every harness: what it checks, how to run it, its variables. `run.sh` starts
and stops a FRESH local server for `online_*`, copies test arenas to a temporary level file, applies a timeout and
flags Lua errors in the harness or the server.

**Which to run:** gameplay / core change → `run.sh all`. Visual-only change → syntax check + the targeted capture.
After moving, renaming or deleting files → `project_check` (first in the battery). After adding a type, level or
track → `docs_reference` (the battery runs it with `CHECK=1`). Hitbox drawing → `FM_HITBOX=1 run.sh all`.

**When a test needs something new, extend the HARNESS and its README row** — never work around it in a scratch copy.

Syntax check of everything:
`for f in $(git ls-files '*.lua' | grep -v resources/); do [ -L "$f" ] || luajit -bl "$f" >/dev/null || echo "$f"; done`

**What no harness can judge:** how something feels to play, how music sounds, whether art looks right. Say so at
every hand-off.

## The runner — details

`run.sh` starts / stops a FRESH local server for `online_*` (a reused one keeps stale peers → bots never join), copies
`tools/levelgen/arenas/*.json` to a temporary `assets/levels/zz_tmp_*` (the server ignores `_*` names), cleans
`server/published`, applies a timeout (a LÖVE error screen never exits) and flags Lua errors (`Error:` lines,
tracebacks) in the harness or the server log.

**No windows in the user's way, in parallel (2026-10-27, the user: the flashing windows made the computer unusable
and the battery took 20+ min):** Linux with `xvfb-run` → every harness on a virtual display; macOS (and Linux without
xvfb) → windows open OFF-SCREEN and borderless (`src/core/TestWindow.lua`, called at the end of every harness
`conf.lua`; it also wraps later `setMode` calls); drawing and screenshots are unchanged (verified on macOS). On macOS
`SDL_MAC_BACKGROUND_APP=1` stops them stealing focus and showing in the Dock. `FM_TEST_SHOW=1` shows them. `all`
runs groups in parallel (`FM_JOBS`, default half the cores): a harness and its variants in one sequential group (they
share a save folder), every online harness (+ `update_boot`, same save folder) in one sequential group (one local
server and port), and the timing-sensitive ones (`perf`, `gloomy_rules`) alone at the end. The online wait for the
port uses `ss` on Linux and `lsof` on macOS (before, macOS always waited the full 10 s). Each `════` line prints how
long it took. The list of harnesses is `tools/tests/README.md` (not repeated here).
While working through a long list of fixes, run the targeted harnesses per change and the full battery once per large
group, right before releasing it (the user's preference, 2026-10-20). `tools/` is not shipped (.love / updates).

## Writing a new harness: low-level notes

- Headless sim (no window): a scratch LÖVE app with `t.window=false`,
  `package.path` pointing at the repo, `love.filesystem.read` patched to read
  from the repo and a stub `love.graphics.newImage` (like server headless).

- Screenshots: scratch LÖVE app with symlinks to `assets src libs settings.lua
  input.lua`, `love.filesystem.setSymlinksEnabled(true)`, drive the real state
  with a `Protocol.newInputStub()` as `Input`, `love.graphics.captureScreenshot`
  (files land in `~/.local/share/love/<identity>/` — delete afterwards).

- Online: `love server --headless` + bot clients using `libs/sock.lua` + bitser
  (hello → create_room → set_mode{mode,level} → join_room → set_ready →
  start_game → send `in` {s, b}). Kill the server afterwards (`ss -lunp | grep 22122`).

- Bots: send `in` only when there are new inputs, or the server kicks them
  for flooding.

## Test levels and arenas

- Test levels: boss test arenas are NOT game levels any more (not in the editor
  or the server): `tools/levelgen/arenas/jefe_espejo.json` (mirror boss, mortars),
  `MiniBossArena.json` (Nave Malvada; the user's layout), `jefe_cangrejo.json`
  (Mega Crabby) — small, the boss is in view at once; pass them to `run.sh` as
  `LEVEL=tools/levelgen/arenas/x.json`. Real boss levels: ruta_del_espejo,
  fortaleza_malvada, guarida_cangrejo_rey (default of the boss harnesses; sp_boss
  teleports the player into the arena).
  `assets/levels/lluvia_pinchos.json` (race, auto-scroll + spike rain),
  `assets/levels/rebote_real.json` (King of the Hill: all 4 trampolines +
  both Trampoline Crabbies), `assets/levels/cumbre_cangrejo.json` (KOTH:
  wall-walking Crabbies), `assets/levels/marea_alta.json` (KOTH: floods).
  For online tests of a KOTH level add a `pointarea` to a temp copy.

## Play recorder (how the user really plays a level)

- **Play recorder** (dev): `FM_RECORD=1 love .` → single-player runs are logged to
  `<save>/recordings/<level name>_<date>.csv` (every 0.1 s: cell, px, hp, lives, in
  water, air used; events: daño/muerte with a guessed cause ahogado/pincho/pez/enemigo,
  reaparece, checkpoint, meta). `src/core/PlayRecorder.lua`, hooked in AdventureState. To
  analyse how the user plays a level (editor → F5 also records).
