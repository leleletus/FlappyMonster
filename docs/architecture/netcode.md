# Online: server, protocol, prediction

The online mode is **server-authoritative**. Clients send numbered inputs; the server simulates every room at a fixed
60 Hz step and sends snapshots (30 Hz, unreliable) plus reliable tick-stamped events; each client predicts only its
own player and reconciles against the last input the server acknowledges. Everything else is interpolated in the past.

**Files**

| File | Role |
|---|---|
| `server/main.lua` | the server: constants and anti-abuse, stubs (`Sound`, `Input`, headless images), level catalog, lag compensation, room simulation (`initRoomSim`, `stepRoom`, `stepPlayer`), broadcasts (snapshots, events, `game_init`), rooms and message handlers, console UI, main loop |
| `server/updates.lua` | publishes and serves game updates (see [updates-and-release](updates-and-release.md)) |
| `src/network/Protocol.lua` | `VERSION`, tick constants, input bits, own-state pack / apply / validate, player flags, `SHARED_SOUNDS` / `PRIVATE_SOUNDS`, the `Input` stub |
| `src/network/NetworkClient.lua` | the `NC` singleton: `NC:connect`, `NC:on / off`, `NC:send`, `NC.myId` |
| `src/network/Resolver.lua` | DNS lookup in a thread |
| `src/network/Predictor.lua` | local prediction + reconciliation (the re-simulation is silent) |
| `src/network/SnapshotBuffer.lua` | interpolation buffer for everything remote |
| `src/network/NameFilter.lua` | player-name rules, shared by client and server |
| `src/states/online/OnlineAdventureState.lua` (+ `OnlineAdventureNet`, `…Render`, `…Hud`) | the in-match client |
| `src/player/OnlinePlayer.lua` | draws the other players |

**Rules when you touch anything that crosses the network**

- A new player field that affects physics goes into `Protocol.packOwnState / applyOwnState / isValidOwnState`.
- An entity sends its own data with `netPack()` / reads it with `netApply(a, b, f)` (bosses: `netPackExtra`);
  entities at rest are not sent at all (`netAtRest()` / `netRest()`).
- Any incompatible change (own state, an entity's packed fields, a new entity type, the entities a level creates)
  ⇒ `Protocol.VERSION` + 1 **and** bump `version.txt`, or old clients cannot join. The server refuses other versions
  and the client then goes to the update screen.
- Level-wide systems that are a pure function of a clock (floods, the moving point zone, auto-scroll) send only the
  clock / state code in the snapshot (`fc`, `zc`, `sc`, `bz`).
- Network data comes from untrusted clients: the server never rebuilds metatables from it, rate-limits every
  message (`on` wrapper) and requires login.

**Harnesses:** `online_smoke` (a bot + a real client; `LEVEL=`, `MODE=`, `WATCH=`, `WANT=`, `DIFF=`),
`online_boss`, `online_helmet`. `tools/tests/run.sh` starts a fresh local server for each.

**Known debt:** `server/main.lua` (1687 lines) keeps its room, player and sound-stub state in file-level locals that
almost every section reassigns, so it could not be split mechanically like the other large files; see
[known-debt](known-debt.md).

## Connection

- Networking: `NC:connect` resolves the server name in a thread
  (`src/network/Resolver.lua`, LuaSocket) — ENet's own DNS lookup blocks the
  main thread (froze the Switch on reconnect). Failed/closed clients destroy
  their ENet host (deferred to the next `NC:update`). Peer timeout 10 s.

- In-match connection indicator: `src/ui/PingIcon.lua`, sprites `assets/images/ui/ping/ping-Sheet.png`
  (5 frames 20x12: 0 = red X, 1..4 bars; bottom-left, bottom-CENTRE when touch controls show): level from ENet RTT AND the age of the last snapshot (RTT freezes when packets
  stop): 4 green, 3-2 yellow, 1 red, 0 = red X (no snapshot for 1.5 s / disconnected);
  improves after 0.6 s, big drops at once. `OnlineAdventureState.lastSnapAt`.

## Server simulation and messages

- `initRoomSim(room)`: Level + `Entities.create` for each placement →
  `sim.enemies`; one `playerSims[pid] = {pa, idx, queue, score, isSpectator,...}`.

- `stepRoom`: per player `processPlayerInputs` → `stepPlayer` (decodes bits into
  the Input stub, `pa:update`, death→lives/respawn/spectate,
  `checkPlayerEnemyCollisions` with lag-compensation rewind), then
  `level.players = active`, `level:update`, `e:update` for each entity,
  collisions again, sound events merged, mode tick / end-of-round.

- Sounds: `Sound.play(name)` on server → `{type='sound', sound, playerId}` event.
  `playerId` = the player whose step caused it (client skips its own, since the
  prediction already played it). Entity sounds get `playerId=nil` → everybody.
  Sound events carry only a name (no pitch). Sounds in
  `Protocol.PRIVATE_SOUNDS` (e.g. 'waterWarning', the drowning alarm) are never
  broadcast: only their owner hears them, from its own prediction.

- Snapshot `"s"` (30 Hz, unreliable): `p` players `{idx,x,y,facing,frame,flags,
  lives,hp,score,drown,air%,place}`, `e` entities `{x,y,facing,state,frame,alive,
  deadTimer*100,breatheT*100,flipped, ...netPack()}`, `md` mode hud, plus own
  state `o`/ack `a` for the receiver.

- Events `"ev"` (reliable, tick-stamped): sound, score, tile, fx, pickup,
  checkpoint, finish, spectate, air_collected, round_end (+ custom).

- `game_init` sends roster (idx,id,name,color) + the level JSON text.

Network scaling: entities whose `netAtRest()` is true (e.g. hanging spikes)
are NOT sent in snapshots; the client calls `netRest()` for missing entries
(the level with 293 entities sends ~540-byte snapshots).

## Client

Client (`OnlineAdventureState`): builds `enemyRenderers` from the level (same
indices as server `sim.enemies`), applies interpolated snapshot data to them,
predicts the local player with `Predictor`, processes events at their render
tick (own-player events immediately). Player colors: `PLAYER_COLORS` in server,
delivered in roster → `self.roster[idx].color`.

- Any NEW field that affects physics must be added to
  `Protocol.packOwnState/applyOwnState/isValidOwnState` (and VERSION bumped),
  otherwise reconciliation desyncs.

## Sounds over the network

- Sounds decided only by the server (the causing client doesn't predict them) go in
  `Protocol.SHARED_SOUNDS` (helmetBreak, pufferPrick): the server sends them with no
  owner, so everybody hears them. New sounds: `tools/sounds/mechanics.py` (switch,
  helmet, puffer), levelled with `Sound.GAIN` to ≈ -12 dBFS (harness `sounds`).

## Projectiles

- Projectiles: there is no global projectile system; an entity owns its
  projectiles (list), exposes them as hazard boxes and sends them in
  `netPack` with a stable id so the client interpolates them (see mortar).

## Player names and room administration

- **Player NAMES (3.67.0)** — `src/network/NameFilter.lua`, shared by client and server: 3-14 characters, only
  unaccented letters, digits, `-` and `_` (no spaces), at least one letter, and no blocked word. `NameFilter.check(name)`
  → ok | false, 'short' | 'long' | 'chars' | 'blocked'; `typed(text)` strips what can't be typed (login field);
  `isBlocked(text)` (also applied to ROOM names → default name). Words: `BLOCKED` (found INSIDE the name), `EXACT` (only
  as the whole name or a token: short words that occur in innocent ones), `RESERVED` (admin, mod, server...), `ALLOWED`
  (innocent words containing a blocked one). Before comparing, the name is NORMALISED: lower case, leetspeak (4→a 3→e
  1→i 0→o 5→s 7→t), separators removed, repeated letters collapsed — "P_U_T_4", "puuuta", "PuT4" all match "puta".
  To maintain: add the word in lower case, no accents, no doubled letters. The client validates before sending
  (`login.name_short|long|chars|blocked`); the server validates again in `hello` (`srv.bad_name` / `srv.name_blocked`).
  Harness `lang_names nombres` (33 bad / 32 good) and `online_smoke` (a disguised name is rejected by the server).

- **Give admin (3.67.0)**: message `give_admin { playerId }` (server `adminTarget`: sender must be the admin, target in
  the room, not self) → `room.adminId = target`, announce `srv.new_host`, `room_update` to everyone; works in any room
  state. Client: first option of the player menu in the room ("DAR ADMIN" / "GIVE ADMIN", `PMENU_ADMIN`). No in-match
  UI. `online_smoke` checks the round trip (client → bot → client).

## Protocol version history

Kept in the comment at the top of `src/network/Protocol.lua` (one line per version). Current: **57**. Milestones:
v12 launches · v14 crouch jump · v16 King of the Hill · v18 Mega Crabby · v21 one invulnerability system · v22 ON/OFF
and invisible blocks, helmet, pufferfish · v24 subtiles · v25 connected floods · v27 ON/OFF blocks · v28 generic boss
intros · v32 bombs · v33 snow / ice · v36 freezer · v38 Snowball Boss, zone phases · v39-40 icy crabs · v41 Gummy
King · v43 dark levels, flashlight, Gloomy · v46 Mega Gloomy · v48-52 Hopper and island variants · v53-54 Mirror
chase · v55 apple / heal pickup · v56 moving point zone clock, difficulty chosen by the host · v57 Claudio (first data-driven type shipped).
