# Automatic updates, releases and deploy

Players never reinstall for a normal update: the game downloads only the changed files from the game server and
restarts. A release is therefore just "bump `version.txt`, push, update the server".

**Files:** `main.lua` (bootstrap: mount / overlay, crash guard, `boot.log`), `src/update/Updater.lua` (download,
verify, slots), `src/states/menu/UpdateState.lua` (the screen), `server/updates.lua` (publisher), `version.txt`,
`tools/deploy_server.sh`. **Harness:** `update_boot` (run with `FM_UPDATE=1`).

**The frozen contract** (installed clients rely on it; changing it strands them): the messages `upd_manifest` /
`upd_get {path, offset}` → `upd_chunk`; the distributed set = root files `game.lua`, `input.lua`, `settings.lua`,
`version.txt` + everything tracked by git under `src/`, `libs/`, `assets/`; and `main.lua` doing `require 'game'`.
Files may move freely INSIDE those roots (a moved file is simply downloaded again); the roots and the four root file
names must not change. `make lovefile` packages exactly that set plus `main.lua` and `conf.lua`.

**Release checklist**

1. `tools/tests/run.sh all` green.
2. Bump `version.txt` (and `Protocol.VERSION` if the network contract changed).
3. Commit, `git fetch` + check `git log HEAD..origin/master`, push to master.
4. `tools/deploy_server.sh` (closes the server's screen session, `git pull --ff-only`, restarts
   `love server --headless`, checks the port; `--status` only looks). It holds no secret: the SSH key's passphrase
   comes from an ssh-agent or from the user's own file through `SSH_ASKPASS`. Restarting drops whoever is playing.
5. The server republishes when it sees the new `version.txt` (at start and every 30 s).

`main.lua` and `conf.lua` only reach a device by reinstalling the game.

## Details

- `main.lua` is only the BOOTSTRAP (never auto-updated, like `conf.lua`; keep
  it small): mounts the active update slot over the installed game, then
  `require 'game'` (the real client entry, `game.lua`). Crash guard: a new
  version is `pending` until it runs 10 s without errors; an error (or 3
  unconfirmed boots) rolls back to `previous` and marks it `bad`.
  Disabled when running from the repo folder (`love .`); `FM_UPDATE=1` forces it.

- The mount is VERIFIED (`version.txt` must read the active version; relative path,
  then absolute save path). If it doesn't take effect (the Switch looped: download →
  restart → old version.txt → "update" again → restart...), main.lua goes back to the
  installed game, sets `nomount` = installed version and `UPDATE_BLOCKED` (UpdateState
  skips; retried when the installed version changes = reinstall). Every boot writes
  `<save>/update/boot.log` (no console on Switch). Updater guards: never reinstall the
  ACTIVE version (even if version.txt disagrees), never delete its slot, max 2
  unconfirmed installs of one version (`tryVer/tries`, cleared on confirm). main.lua
  changes only reach a device by reinstalling. Harness `update_boot` (FM_UPDATE=1).

- Save dir: `update/state.lua` {active, previous, pending, boots, bad, trash},
  `update/slots/<version>/` = only the files that differ from the installed
  game + `.manifest.lua` (hashes, so the next update doesn't rehash).

- `src/update/Updater.lua` + `src/states/menu/UpdateState.lua` (first state; goes
  to the title at once when offline/up to date; also entered from the online
  login when the server rejects the version). Downloads only changed files
  (sha256-checked), copies unchanged ones from the old slot, then
  `love.event.quit('restart')`. Files deleted from the repo can't be hidden if
  the INSTALLED build has them (only matters for directory scans).

- **SWITCH, 3rd attempt (3.67.0; main.lua `BOOT` 3 → needs ONE reinstall on every device to take effect):** v1 looped
  (download → restart → old version → download...), v2 cut the loop by BLOCKING updates on any device where `fs.mount`
  fails (`nomount`) — so the Switch never updated again. Now a version that cannot be mounted is used by OVERLAY
  (`overlay(v)` in main.lua, `UPDATE_MODE = 'mount' | 'overlay'`): nothing is mounted; `love.filesystem.read/getInfo/
  lines/load/newFile/newFileData/getDirectoryItems` (union), the image / font / sound / thread loaders and `require`
  (a `package.loaders` entry) look first in `update/slots/<v>/`. It only needs to READ the save dir. If even that fails
  (the slot's version.txt can't be read) → back to the installed game + `nomount` as before (no loop). A device left
  blocked by the old bootstrap is unblocked (`st.boot ~= BOOT` clears `nomount`). Harness `update_boot`: no_monta /
  no_tapa now expect overlay (new module, new level file, directory union, 2nd boot the same), `ilegible`, `viejo`.
  NOT verified on a real Switch — `update/boot.log` in the save dir says which mode was used.

- Server `server/updates.lua`: publishes a snapshot of `git ls-files` (game.lua,
  input.lua, settings.lua, version.txt, src/, libs/, assets/) into
  `server/published/current/` ONLY when `version.txt` changes (checked at start
  and every 30 s, hashing in a thread) and serves it over ENet:
  `upd_manifest` / `upd_get {path, offset}` → `upd_chunk` (48 KB). That
  message contract is FROZEN (installed clients rely on it). The server must
  be run from the repo root (it needs `git`).

- RELEASE = bump `version.txt` in master (+ git pull/restart the server). Bump it
  too whenever `Protocol.VERSION` changes, or old clients can't join.

- DEPLOY (user's standing request: after EVERY push, update the server): `tools/deploy_server.sh` (ssh host
  `dj-vera-server`, repo `~/FlappyMonsterOnLain`, screen `flappy`: closes the screen, waits for port 22122, `git pull
  --ff-only`, restarts `love server --headless` in the screen with its output to `~/flappy.log`, checks the port;
  `--status` = look only). The script holds NO secret: the key's passphrase comes from an ssh-agent or from the user's
  own file `~/.ssh/id_rsa_pass` (through `SSH_ASKPASS`; never print, copy or commit it). Working since 2026-10-06
  (server went 3.68.5 → 3.84.1). Restarting drops whoever is playing online.

- `SERVER_HOST`/`SERVER_PORT` in settings.lua (`FM_SERVER=localhost` for tests).

- Release: bump version.txt; audio-only changes need only `git pull` on the server
  (it republishes within 30 s); code/protocol changes need a server restart.
