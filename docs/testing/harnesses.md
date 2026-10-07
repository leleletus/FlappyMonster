# Testing without a human

**Always start here — never rebuild a test setup by hand.** Every harness is a small LÖVE app in `tools/tests/<name>/`
(symlinks to `src`, `assets`, `libs`, `settings.lua`, `input.lua`) and runs through ONE command from the repo root:

```
tools/tests/run.sh all                              # the battery (~6 min), exit 0 / 1, ends with "TODO OK"
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

## The runner

**ALWAYS start here — don't rebuild test setups by hand.** Every harness lives
in `tools/tests/` and runs through ONE command from the repo root:
`tools/tests/run.sh all` (quick battery, ~2 min, exit 0/1) or
`tools/tests/run.sh <harness> [VAR=val ...] [-- args]`. `run.sh` starts/stops a
FRESH local server for `online_*` (a reused one keeps stale peers → bots never
join), copies `tools/levelgen/arenas/*.json` to a temp `assets/levels/zz_tmp_*`
(the server ignores `_*` names), cleans `server/published`, applies a timeout
(a LÖVE error screen never exits) and flags Lua errors in harness or server.
`tools/tests/README.md` = table of every harness (what it checks, how to run
it, its env vars) + rules for new ones. When a test needs something new, fix
or extend the HARNESS (and its README row) instead of working around it in a
scratch copy: the time spent fighting test setups was the user's complaint.
Harnesses: flyers, crawler_drop, mechanics, sounds, boss_sim, sp_boss, boss_frames, megagummy_rules, gloomy_rules, megagloomy_rules,
editor_open, free_play, update_boot, online_smoke, online_boss, online_helmet,
level_check, level_solve, level_shots, story_flow, difficulty_rules, bot_nav. `tools/` is not shipped (.love / updates).

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
