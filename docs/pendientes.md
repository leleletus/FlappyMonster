# Pendientes — review of 2026-10-20

The full-project review of 2026-10-20 (5 areas: online, gameplay, menus / input, story / saves / editor, tests /
perf / assets / product) plus two reports from the user. Worked through from the top; tick an item (`[x]`) in the
same commit that fixes it and say in which version. Items already in [known-debt](architecture/known-debt.md) are
not repeated here.

## 1. Critical — progress lost, game or server broken

- [x] (0.5.8) **Reward lives thrown away**: `Run.complete` adds the S / world reward lives, then `AdventureState:exit` →
  `onLeave` → `Run.setLives` writes the pre-reward count over them.
- [x] (0.5.8) **SP pause: cancel = confirm**: `PauseState` runs the highlighted option on `resume` / `pause` too; with MENU
  highlighted, Esc / Start / pad cancel quits the level.
- [x] (0.5.8) **Damaged save = empty slot, then wiped**: `Save.write` truncates in place (no temp / backup), a parse failure
  shows the slot as empty and a new game overwrites it; `story.sav` read as `{}` loses the unlocked difficulties;
  a failed write is reported as success.
- [x] (0.5.8) **One Lua error crashes the whole server**: `stepRoom` / broadcast / flush run without `pcall`; no restart loop
  in `tools/deploy_server.sh`.
- [x] (0.5.8) **Online: player frozen forever after a 3–6 s stall**: inputs further than `lastProcSeq + 180` are dropped and
  `lastProcSeq` never catches up.
- [x] (0.5.9) **Enemies don't die in lava**: they sink to the bottom of it as if nothing happened (user report).
- [x] (0.5.9) **Low frame rate tunnelling**: the player's floor check has no sub-steps and no max fall speed (ground pound
  75 px/step at 20 fps goes through a 1-tile floor).
- [x] (0.5.9) **Low frame rate stomps**: `Interactions` uses a fixed `STEP_DT` for "foot was above last step"; at 30 fps a
  stomp becomes a hit. Boss stomp has no fast-fall fallback.
- [x] (0.5.8) **Game Over while replaying an old world locks the later worlds** (`Run.gameOver(world)` with the replayed
  world).
- [x] (0.5.8) **Pause → exit during the win celebration** (`won` / `endingT`) counts the level as not finished.
- [x] (0.5.10) **Updater: old slot mounted over a newer installed build** (no `base` check); a boot error there loops.

## 2. Controls and menus

- [x] (0.5.9) **Create room, max players step (pad)**: cannot be cancelled; check the up / down / left / right behaviour
  (user report).
- [x] (0.5.10) Hints with PC keys written in the text (`free.hint`, `story.*_hint`, `hub.*_hint`, `login.hint`, `msm.*`…) →
  `{key}` placeholders filled by `Input.label`.
- [x] (0.5.10) `Input.label` by platform only → by last device used (keyboard / pad / touch).
- [x] (0.5.10) Pad unplugged and plugged back / swapped stops working (no `joystickremoved`, new pad ignored).
- [x] (0.5.10 / 0.5.11) No repeat when holding a direction in menus; no stick hysteresis (diagonals jump in grids).
- [x] (0.5.10) Save slot cannot be deleted with a pad (BORRAR never gets focus).
- [x] (0.5.10) Online room list cannot be scrolled by touch (rooms after the 5th unreachable on Android).
- [x] (0.5.10) Online room screen: `back` does nothing although the hint shows it.
- [x] (0.5.10) Login: Enter handled twice (`keypressed` + `confirm`).
- [x] (0.5.10) `story.map_hint` describes the old map controls.
- [x] (0.5.10) Touch ignored on `UpdateState` and the hub "waiting for room" overlay.
- [x] (0.5.10) Text fields unusable with a pad only (no delete action, keyboard cannot be reopened).
- [x] (0.5.10) Raw ENet / Lua error strings shown to the player (`NC:_fail(tostring(err))`).
- [x] (0.5.10) `ModeSelectMenu`: selected card can be off-screen after a resize (`first` not re-clamped).
- [x] (0.5.10) Android Back during a level hides the touch controls (`lastDevice = 'keyboard'`).

## 3. Gameplay

- [x] (0.5.11) Easy (`hazardHurt`) does not cover entity spikes / spike rain / mortar (they still kill).
- [x] (0.5.11) Drowning still kills after winning / while frozen / in a boss intro.
- [x] (0.5.11) Data-enemy shots freeze mid-air (but hurt) while the shooter is stunned / launched.
- [x] (0.5.11) Non-stomp kills (bombs, broken block, trampoline into spikes) not counted in `stats.kills` (grade).
- [x] (0.5.11) Oxygen bubbles depend on sprites loading and on wall-clock time (rule 1).
- [x] Respawn overwrites the checkpoint with the auto-scroll / arena point for good. — kept (0.5.11): the arena / auto-scroll point is always further along than the last checkpoint, so respawning there is the better place
- [x] (0.5.11) Rule 2: "fell out of the level" check copied ~8 times; gravity integration copied in behaviours; knockback
  wall release copied in 3 types.

## 4. Online / server

- [x] (0.5.11) `get_levels` spam → ~13 MB/s out per connection (cooldown / cached payload).
- [x] (0.5.11) Update channel without login: `upd_get` spam, 64 slots filled without logging in (in-flight / budget caps).
- [x] Updates unsigned (manifest signature with a public key in `main.lua`). — moved to section 7 (decision)
- [x] (0.5.11) Level catalog rescanned (`io.popen ls` + `Level.new` × 44) on the main thread during matches.
- [x] (0.5.11) Ground pound through breakable blocks mispredicted (`canBreak=false` on the client; `tile` events without
  `playerId`).
- [x] (0.5.11) Large unreliable snapshots silently sent as reliable fragments (measure size in `FM_PERF` / `online_boss`).
- [x] (0.5.11) Room password lockout resets on reconnect (per-connection instead of per-IP).
- [x] "Private" room listed and joinable with an empty password; sequential room ids. — moved to section 7 (decision)
- [x] (0.5.11) Remote players' health bar `hpMax = 3` hard-coded (4 on Easy).
- [x] (0.5.10) Client handler error shown as "connection lost" (one `pcall` around all of `client:update`).
- [x] (0.5.8) `_currentSim` never cleared after `stepRoom`.

## 5. Story, saves, editor, updater

- [x] (0.5.10) Level editor "Save as" overwrites an existing level (story levels included) without asking.
- [x] (0.5.10) Editors: quit guard skipped during F5 playtest; `quitConfirmed` never reset; `f:write` result ignored.
- [x] (0.5.8) Lost lives only saved on `exit` (kill the app = keep the lives).
- [x] (0.5.11) Shards and level completion saved in separate writes.
- [x] Story points farmable by replaying (`d.points` grows on every replay). — moved to section 7 (decision)
- [x] `Save.VERSION` / `options.cfg` version never checked. — no change needed (0.5.11): `Save.write` writes back every field it read, so an older game keeps a newer save's fields
- [x] (0.5.10) Updater manifest: entries without hash count as present; `.manifest.lua` write unchecked; validate hashes.

## 6. Tests, performance, docs

- [x] (0.5.11) No harness for the full update download (publish → chunks → sha256 → install → restart).
- [x] (0.5.11) No online harness with latency / jitter / packet loss.
- [x] Hunt mode in the battery (0.5.8); the Evil Ship fight (`sp_boss LEVEL=fortaleza_malvada`) and the spike rain online (`online_smoke lluvia_pinchos WATCH=rainspike`) in the battery (0.5.11). A full rules harness for the Evil Ship (like the other bosses') is still missing.
- [x] (0.5.11) `mechanics` `persecucion` depends on the random sequence — it now seeds its own RNG (`PSEED`, default 1). Still: with seeds 4 / 5 / 7 / 8 the Mirror never makes a push-only touch (it is left to chance); a forced probe would make it robust.
- [x] No test for a corrupt / truncated save or `options.cfg` round-trip. — `story_flow` `roto` (0.5.8); `menu_flow` `opciones` (0.5.11)
- [ ] `perf`: no online-client or credits scene. The credits film's clock follows its music, which does not play in the perf harness (it stays on the title card): a scene would have to drive the film like `story_film` does. The online client needs the local server (perf is not an `online_*` harness). (The story-map scene was added in 0.5.11 and found 77 KB/frame of garbage, fixed; the boss scene is at 35 KB, not 54.)
- [x] (0.5.11) Particles: no pool, `table.remove(list, 1)` at the cap (O(n²) bursts).
- [x] (0.5.11) Predictor allocates tables every tick / snapshot.
- [x] (0.5.10) `docs/testing/harnesses.md` stale (contradicting intros, 16 harnesses missing); `free_play` README row
  malformed; stale line counts in known-debt; `save-data.md` misses `playTime` / `gameOvers`.

## 7. Decisions for the user

- [x] (0.5.13) "Private" rooms: the user chose — a private room REQUIRES a password (client wizard and server).
- [x] (0.5.14) Replay farming (the user: it also happened with LIVES): extra lives once per level (see-through and
  points afterwards), story points only by beating the level's record. See docs/story/story-mode.md.
- [ ] Signed updates (a public key in `main.lua`, the server signs the manifest): needs a key kept outside the repo and
  only protects devices that install a new build. The user: not needed yet, keep it here.

## 8. Features to add (decide with the user)

- Options: music / SFX volume, mute, vibration, A/B swap (Xbox pads); `love.focus` must respect the volume.
- Device-aware button glyphs (keyboard / Nintendo / Xbox / touch).
- Tutorial / hint layer for touch players.
- Boss rush; ghost time trials in Free Play (`PlayRecorder`).
- Leaderboards + daily challenge on the server.
- Online custom levels (upload from the editor, validated on the server).
- Rejoin a running match / spectate; report / block, quick chat.
- Story: damaged-slot restore, copy slot, retry from results, best time on the map, shard / film gallery.
- Editor: autosave / crash recovery, `validate()` on save, playtest from cursor.
- Jump buffer (~0.1 s).
- Music re-encode at ~96–112 kbps (−30 MB) — needs a listening check.
