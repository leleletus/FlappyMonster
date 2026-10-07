# Auto-scroll levels and spike rain

A level with `autoScroll` moves its camera by itself: stay inside the window or die. Used by `lluvia_pinchos`,
`tren_fugaz` and `huida_del_espejo` (the Mirror chase, see [mirror-chase](../bosses/mirror-chase.md)).

**Files:** `src/world/systems/AutoScroll.lua`; the walls come through `Level:arenaAt` (shared with boss zones).
**Editor:** right panel → Nivel → "Cámara automática". **Network:** snapshot field `sc`; the client extrapolates
with `AutoScroll.clientUpdate`. Such levels are Race-only online and should be ≤ 11 rows tall so the whole height is
visible. Apples are placed along them by `tools/levelgen/add_apples.py`.

## Auto-scroll

Level JSON `autoScroll = {startCol, endCol(0=end), speed, width(tiles), margin,
countdown}`; editor: right panel → Nivel → "Camara automatica". States
`wait → countdown → run → stop` (all players inside the start window to begin;
first finish or endCol stops it). Walls through `Level:arenaAt` (combined with
boss zones): wait = both sides, run = right side only; behind `x - margin`
→ forced death (`die(nil,true)`, attributed via `PlayerAdventure.asOwner`).
Respawn: `AutoScroll.respawnPoint(level)` (lowest safe ground near the window
centre) — set `pa.spawnX/Y` right before `pa:respawn()` (SP + server).
Camera X = window centre ONLY (never the player: on screens narrower than the
window it is cropped equally both sides; no lerp), keeps moving while you die. Net: snapshot `sc`,
client extrapolates with `AutoScroll.clientUpdate`. Race-only (hunt rejects
`info.autoScroll`). Keep such levels ≤ 11 rows so the whole height is visible.

## Spike rain (orchestrated falling spikes)

`rainspike` = `spikefall` with `autoDetect = false` (only falls when
`e:trigger(warn)` is called); painted in the editor by dragging (`def.paint`).
`spikerain` = invisible director entity (EvilCaibles port): wave cycle
(min → up → max → down, each wave peaks higher), picks spikes of its `group`
near players with a clear drop, aims ahead of the player with some probability,
round-robin per player, min spacing, per-spike cooldown. All tunables are
props. `EDITOR_VIEW` global is true while the editor draws the map (use it for
editor-only visuals). `drawEditorOverlay(props, cx, cy, zoom, ctx)` gets
`ctx = {entities, t, camX, camY}`; `editor.draw(x, y, s)` = code-drawn icon.
