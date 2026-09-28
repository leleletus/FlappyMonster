# FlappyMonster — project map for Claude

LÖVE 11.x game (Lua / LuaJIT). Two games in one: the original Flappy mode
(`PlayState`) and **Adventure** — a platformer with a single-player mode
(`AdventureState`) and an online mode backed by an **authoritative server**
(`server/main.lua`). Code comments are in Spanish; keep that. Player-facing
text is translated (es/en, see *Languages* below) — never hardcode it. The
level editor is a dev tool and stays in Spanish.

Run: `love .` (game; `main.lua` is the update bootstrap, the game is `game.lua`) · `love . --editor [assets/levels/x.json]` (level editor)
· `love server` / `love server --headless` (server, port 22122).
Quick syntax check of everything: `for f in $(git ls-files '*.lua' | grep -v resources/); do luajit -bl "$f" >/dev/null || echo "$f"; done`

## Golden rules

1. **Everything that affects gameplay must run identically in 3 places**:
   single player (`AdventureState`), the server (`server/main.lua`), and the
   online client (`OnlineAdventureState`, which only *predicts the local
   player* and *renders* everything else from snapshots).
2. Gameplay code must not touch `love.graphics` / real `Input` / real `Sound`
   outside render functions — the server stubs `Sound` (collects events),
   `Input` (per-tick bitmask stub) and, headless, `love.graphics.newImage`
   (returns a fake with real dimensions).
3. Globals used everywhere: `Sound`, `Input`, `TILE_PX`(64), `PLAYER_SCALE`(6),
   `GUMMY_SCALE`(4), `ADV_GRAVITY`, `ADV_JUMP_VEL`, `ADV_MOVE_SPD`,
   `WINDOW_W/H`, fonts `FONT_SMALL/MED/BIG` (Press Start 2P), `DEBUG_HITBOX`.
4. Visual style is 8/16-bit pixel art: integer positions (`math.floor`), hard
   rectangles, black drop shadows offset 2-4 px, no rounded/smooth UI in-game.
5. Data-driven catalogs: new tiles/entities/decorations/modes are a new file
   + one name in a list. The editor and server pick them up automatically.
6. Don't commit the many ` M` files in git status (they're mode-only changes).

## Screens, scaling and platforms (PC / Switch / Android)

- The game draws in a LOGICAL resolution: height 720, width `WINDOW_W` = 720 ×
  aspect (clamped 4:3..21:9) — 1280 on PC/Switch, e.g. 1600 on a 20:9 phone,
  960 on a 4:3 tablet. `main.lua` sets it in `love.load` AND `love.resize` (the
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
- Testing other screens: run the REAL main.lua from a scratch app with a
  custom window size and `love.system.getOS = function() return 'Android' end`
  (Input.isMobile), plus a local server/bot for the online menus.
- Networking: `NC:connect` resolves the server name in a thread
  (`src/network/Resolver.lua`, LuaSocket) — ENet's own DNS lookup blocks the
  main thread (froze the Switch on reconnect). Failed/closed clients destroy
  their ENet host (deferred to the next `NC:update`). Peer timeout 10 s.

## Languages (i18n)

- `src/Lang.lua`: `local L = require 'src/Lang'` → `L('hub.create')`,
  `L('mode.hunt.left', { n = 3 })` (`{var}` interpolation). Missing key → es →
  the key itself. Files with a local `L` layout table (OnlineRoomState,
  OnlineLoginState, Notify) import it as `Lang`.
- Texts: `assets/lang/es.lua` / `en.lua` — nested tables by screen (`common`,
  `hud`, `menu`, `hub`, `room`, `oadv`, `results`, `msm`, `mode`, `srv`, `boss`,
  `notify`, `err`...). Add a key to BOTH files. New language = copy es.lua +
  one entry in `Lang.LANGUAGES`.
- Translate at DRAW time: option lists store keys (`LIST_BTNS`, pause opts,
  `PMENU_LABELS`) and draw `L(key)`; layouts must measure the real text
  (`fitText`, `FONT:getWidth(L(..))`) — English/Spanish differ in length.
- Modes: text fields are keys `mode.<id>.label|tagline|objective|empty_hint`
  resolved on read by `ModeTypes` (`m.label` is already translated).
  `reasonText(reason)` and `rank` notes return KEYS; `Modes.reasonText(mode,
  reason)` translates. Boss bar names: `boss.<type>`.
- Server messages: `Lang.message(key, args, extra)` → `{key, args, msg(es)}`;
  clients show `L.fromServer(data, fallbackKey)` in their own language.
  `round_end` carries `reason` + `noteKey` (plus Spanish text for old clients).
  Lang reads files with `love.filesystem.read` (the server patches it).
- `src/Settings.lua`: player options saved as `options.cfg` in the save dir
  (NEVER a name like settings.lua: the save dir shadows the game's modules).
  `SettingsState` = language selector (main menu → CONFIGURACIÓN).
- Big menu buttons are TEXT drawn with `src/ui/PixelFont.lua` (the 5-px font of
  the old button images, accents included): `PixelFont.draw(text, x, y, scale,
  alpha)`, `.width`, `.height`. No text baked into images.

## Automatic updates

- `main.lua` is only the BOOTSTRAP (never auto-updated, like `conf.lua`; keep
  it small): mounts the active update slot over the installed game, then
  `require 'game'` (the real client entry, `game.lua`). Crash guard: a new
  version is `pending` until it runs 10 s without errors; an error (or 3
  unconfirmed boots) rolls back to `previous` and marks it `bad`.
  Disabled when running from the repo folder (`love .`); `FM_UPDATE=1` forces it.
- Save dir: `update/state.lua` {active, previous, pending, boots, bad, trash},
  `update/slots/<version>/` = only the files that differ from the installed
  game + `.manifest.lua` (hashes, so the next update doesn't rehash).
- `src/update/Updater.lua` + `src/states/UpdateState.lua` (first state; goes
  to the title at once when offline/up to date; also entered from the online
  login when the server rejects the version). Downloads only changed files
  (sha256-checked), copies unchanged ones from the old slot, then
  `love.event.quit('restart')`. Files deleted from the repo can't be hidden if
  the INSTALLED build has them (only matters for directory scans).
- Server `server/updates.lua`: publishes a snapshot of `git ls-files` (game.lua,
  input.lua, settings.lua, version.txt, src/, libs/, assets/) into
  `server/published/current/` ONLY when `version.txt` changes (checked at start
  and every 30 s, hashing in a thread) and serves it over ENet:
  `upd_manifest` / `upd_get {path, offset}` → `upd_chunk` (48 KB). That
  message contract is FROZEN (installed clients rely on it). The server must
  be run from the repo root (it needs `git`).
- RELEASE = bump `version.txt` in master (+ git pull/restart the server). Bump it
  too whenever `Protocol.VERSION` changes, or old clients can't join.
- `SERVER_HOST`/`SERVER_PORT` in settings.lua (`FM_SERVER=localhost` for tests).

## Directory map

```
main.lua            BOOTSTRAP only (mounts updates, see Automatic updates) → game.lua
game.lua            client entry; state machine registry; editor hook (--editor)
settings.lua        global constants; requires src/world/Tiles (defines TILE_* ids)
input.lua           baton-based Input (keyboard/gamepad/touch VirtualPad)
src/Sound.lua       Sound.play(name,pitch,vol), playMusic(name), stopMusic, tracked sounds,
                    per-sound GAIN baked at load. ALL sounds are files (no procedural
                    audio): add one with load('name', 'assets/sounds/<group>/x.wav', 'static')
                    in Sound.load(), then Sound.play('name'). Folders: player/, enemies/,
                    bosses/<boss>/, items/, mechanics/, traps/, water/, jingles/, ui/,
                    flappy/, fireworks/. Images: assets/images/<thing>/ (bosses/<boss>/),
                    all lowercase; music: assets/music/snake_case.wav
src/Music.lua       MUSIC CATALOG from assets/music/index.json (id, name, file |
                    intro+loop, volume, loop, level). Sound loads every track from it
                    (`Sound.loadTrack`); `level=false` tracks (boss, menus, youWin) are
                    not offered as level music. Adding a song = file + one index entry.
                    Level JSON `"music": id` (editor: Nivel tab → Música, ▶ preview).
                    `Sound.playMusic('level')` resolves: `setLevelMusic` override (boss)
                    → `setBaseLevelMusic(level.music)` → 'classic'. Online the client
                    re-seeks the level track every 1 s to the server clock
                    (`Sound.syncMusic('level', t)`; tick 0 = round start), so all players
                    hear the same point of the song (tested: ≤0.1 s).
src/entities/
  PlayerAdventure.lua  THE player physics (shared by SP, server and client prediction)
  OnlinePlayer.lua     remote player renderer (tinted by player color, name tag)
  DeadEyes.lua         X eyes: draw() for the player sprite (9x16);
                       drawPair(midX, midY, sep, scale) for any other sprite's eyes
src/world/
  Level.lua            loads JSON, collision queries, render, vents/bubbles
  Tiles.lua (+tiles/)  tile types & materials registry (recipe at top of file)
  Entities.lua         entity type list TYPES (recipe at top of file)
  entities/Entity.lua  base class: movement, states, stomp, knockback, net hooks
  entities/EntityTypes.lua  registry, COMMON props, render wrapper for common states
  entities/Props.lua   editable property kinds (int, number, bool, enum, text, patrol, point,
                       points = ordered list of cells, e.g. boss waypoints; editor has
                       numbered draggable handles + add/remove buttons)
  entities/Interactions.lua  player<->entity rules (kill/hurt/stomp/pickup/checkpoint/GP)
  entities/types/*.lua gummy, crabby, spikefall, star, extralife, checkpoint, mortar, mirror,
                       rainspike (orchestrated spike), spikerain (the orchestrator),
                       miniboss1 (Nave Malvada), trampoline (4 defs: up/down/left/right),
                       crabbytramp (Crabby trampolín, subclass of crabby),
                       flood (editor-only placeholder for a Floods area)
  AutoScroll.lua       auto-scrolling camera levels (see below)
  Floods.lua           rising/falling water areas (see below)
  BossZones.lua        boss arenas (see below)
  Decorations.lua (+decorations/)  foliage registry
  Modes.lua (+modes/)  online game modes: hunt, race, koth (ModeTypes.lua documents the API)
  PointAreas.lua       point zones (King of the Hill), see below
src/network/
  Protocol.lua         VERSION (bump on incompatible change!), input bits, own-state pack
  NetworkClient.lua    NC singleton (NC:on/off, NC:send, NC.myId)
  Predictor.lua        local prediction + reconciliation (re-sim is SILENT: Sound muted)
  SnapshotBuffer.lua   interpolation buffer for remote stuff
src/states/            Title, MainMenu, Play (flappy), Adventure (SP), Online* (login,
                       hub, room, adventure, results, error), Pause
src/editor/            Editor.lua (UI+tools), EditorModel.lua (data/save/validate), ui.lua
src/fx/Particles.lua   Particles.emit(kind,x,y) — kinds: gp_land, gp_start, block_break,
                       oneup, spawn, spike_land, spike_pop, collect, checkpoint,
                       boss_hit, boss_blast, boss_big_blast, mortar_blast, fire_puff, ember,
                       exhaust, smoke, sparks, shake_small/shake_big (screen shake:
                       states add Particles.shakeOffset() to the camera when drawing)
src/ui/PixelIcons.lua  small pixel icons = PNGs in assets/images/icons/<name>.png (crown,
                       mode icons skull/flag/hill: a new mode icon is just a file); drawn
                       at integer scale with a 1-px drop shadow
Spikes are images too: assets/images/spikes/spike.png (tile spikes, rotated/flipped
                       for the 4 directions; falling spike), crabby/spike.png and
                       bosses/miniboss1/spike.png (stretched in height while they grow)
src/fx/SpriteStrip.lua animation strips (frames side by side in one PNG):
                       SpriteStrip.load(path[, frameW]) → :frameAt(t, fps), :draw(i, x, y, r, sx, sy)
server/main.lua        authoritative sim (see below)
assets/levels/*.json   levels (server scans this dir; files starting with _ hidden)
```

## Player (`PlayerAdventure`)

- Fields: `x,y` = sprite center; `vx,vy`, `onGround`, `facing`, `frame`
  (1..3 walk/fall anim, 2 = rising/GP, 5 = crouch; dying uses monstrito4),
  `puff` (squash scale), `hp/hpMax` (3), `lives`, `hurtT` (i-frames),
  `gpPhase` nil|'windup'|'fall', `gpLanded` (true only the step it lands),
  `stunT`, `dying/alive/deathPhase` ('freeze'→'jump'→'fall', `alive=false`
  when off-screen → caller subtracts a life and respawns).
- `update(dt, level)` reads global `Input.pressed/down` ('jump','crouch',
  'move_left','move_right'). Ground pound = press crouch in the air.
- Crouch: on the ground can't walk but CAN jump (crouch jump; the held direction
  sets vx = ±ADV_MOVE_SPD at takeoff, air control while airborne). Stays crouched
  in the air while crouch is held; `canStand(level)` = headroom for the standing
  box — without it the player is ALWAYS crouched (1-tile-high tunnels). While
  crouched `moveAndCollide` and contact hazards use the crouched boxes (feet
  anchored); no GP without headroom; no 'headBump' sound while crouched.
  `crouching` is in own-state flags (protocol v14 for the new rules).
- Oxygen bubbles: `Level:checkVentOxyCollision` = visible circle of bubble1
  (offset -3.5,-10.5 from b.x,b.y, r 24.5 + 6 px pad) vs the whole outer box.
  F1 draws the circles; breathing point = `getHeadPoint` (top of head).
- `hurt()` = 1 damage with i-frames (`takeDamage`), returns true if it killed.
- `bounce(vy)`, `knockback(dirX)` (GP shove + stun), `die()`, `respawn()`.
- Sounds: 'jump', 'step', 'dies2' (death), 'dies' (non-lethal hit), 'gpStart',
  'gpImpact', 'stunned', 'headBump'.
- Any NEW field that affects physics must be added to
  `Protocol.packOwnState/applyOwnState/isValidOwnState` (and VERSION bumped),
  otherwise reconciliation desyncs.

## Entities

- Instance = `Entity.create(cls, placement)`; placement `{type,col,row,sub,props}`.
  `x,y` = center; hitboxes `outerW/H`, `innerW/H` from `tuning.hitbox` × sprite size.
- Hooks: `loadAssets, sizeImage|sizePx, init, updateCustom(dt,level)->true,
  onWalk/onIdle/onDead/onStomp, canBeStomped, isBodyDisabled, getHazardBoxes,
  netPack()/netApply(a,b,f), render(camX,camY)`.
- `level.players` = list of active PlayerAdventure (entities "see" players).
  `level.liveEntities` = entities list.
- `Interactions.check` returns kill/hurt/stomp/pickup/checkpoint; `run()` also
  applies the ground-pound impact (`poundZone` kills, radius knockbacks).
  Entities can override interaction completely with `e:interact(pa)` (see boss).
  Hazard boxes may carry `effect = 'hurt'` (1 HP) instead of the default kill.
- Solid entities: `isSolidBody()` → put in `level.solidBodies` each step.
  `Cls.solidFull = true` = solid like a block (sides, stand on top, head bump;
  e.g. mortar); otherwise sides only (bosses: the top is the stomp zone).
- Editor hook: `Cls.drawEditorOverlay(props, cx, cy, zoom)` draws extra help
  when the entity is selected (mortar detection radius).
- A type file may return a LIST of defs (Entities.lua registers each), e.g.
  trampoline.lua → 4 palette entries sharing one class.
- Trampolines: `solidFull` bodies with `bouncyFace`. The player's
  `moveAndCollide` records `pa.bodyHit = {o, face, speed}` (face of the BODY it
  hit this step). `e:interact` returns `'launch', vx, vy` when the face and
  speed match → `pa:launch(vx, vy)` + `e:onLaunch(pa)`; predicted on the client
  (`Predictor:recordLaunch`). States ready → bounce (0.1 s: everyone touching
  bounces) → extended (`cooldown`, just a wall) → retract → ready.
- Crabby hooks: `drawTopper(cx, baseY, progress, dir)` (spike by default) and
  `bounceRotation()`; `Interactions.defaultCheck(pa, e)` = the normal rules, for
  entities whose `interact` only overrides some cases.
- `pa:squash(dirX)`: flattened for `squashT` (1.8 s): crouch sprite squashed to
  `SQUASH_K` (0.55) anchored at the feet, hitbox 20 px, stunned, stars at the
  flattened head, sideways hop. Own-state index 28; others see it via `PF_SQUASH`.
- `pa:launch(vx, vy)`: sideways launches set `ctrlLockT` (no input, no
  friction, NO stun/stars) instead of stunT. Own-state index 29 (protocol v12; v13 = flood entity type; v14 = crouch jump).
  Side trampoline faces trigger at any push speed; top/bottom need 120 px/s.
- Tile hitboxes are REAL for entities: platforms are slabs (`platform` h 0.72,
  `platform_drop` h 0.36). `Entity.moveAndCollide` snaps to the hit face of the
  tile hitbox (and of `solidFull` bodies via `Level:bodyAt`), in ≤16 px
  vertical sub-steps. `collisionAt` always uses the real shape. The PLAYER's
  landing also accepts `Level:onewayCellAt` (a one-way tile counts from its top
  face down to the cell bottom; with its prevFoot check a fast fall/GP can't
  skip a thin plank). Anything else that FALLS (Crabby/Crabby-trampolín drop,
  falling spikes, mortar fire) uses `Level:landingCross(x, y0, y1)`: hit only if
  it crossed a top face FROM ABOVE this step (never catches the slab it hung
  from, never tunnels). Walkers' edge probe is 4 px past the surface (half a
  tile fell out of thin slabs → turned every frame).
- Entities vs solid objects: walkers/crawlers collide with `solidFull` bodies
  (trampolines, mortars) like blocks (crawlers climb them: `Level:entitySolidAt`).
  Touching a body's bouncy face → `Entity:touchBody` → `Entity:launch(vx,vy)` →
  common state 'launched' (gravity, lands → walk; patrol bounds dropped). Flyers
  aren't launched. Crawlers: `Crawler.supportBody` (face from the normal).
- Ceiling Crabbies detect players while hidden (`canDropNow`/`isHiding`) and drop
  straight from the shell (`dropHidden`).
- Wall Crabby stomp (Interactions.defaultCheck): in the air, falling onto its top
  end OR coming from the open side (player centre beyond its outer face) =
  'stomp' with 4th return dirX = cnx → `pa:bounce(vy, dirX, soft=true)` (vx 300 +
  ctrlLockT, no stun); predicted via `recordBounce(vy, dir, soft)`. Protocol v15 (v16: King of the Hill; v17: crawler turn in snapshots).
- **Crawler** (`src/world/entities/Crawler.lua`): surface-following movement
  (floor ↔ walls ↔ ceiling, concave and convex corners) for Crabbies with prop
  `wallWalk` (`Crabby.WALL_PROP`, off by default so old levels don't change).
  State `cnx/cny` (surface normal), `cdir`, `cattached`; rests at outerH/2 from the
  surface (same as a normal Crabby, attach snaps pixel-exact); corners are a rigid
  90° rotation about the corner measured pixel by pixel (no jump); `Crawler.angle` for
  drawing (Crabby renders "as floor" inside a rotation), `Crawler.toWorldBox`
  to rotate local boxes (spike, trampoline). Corner turns are part of the SIM
  (`Crawler.beginTurn/advanceTurn`, scalar fields `turnT/turnDur/tsx/tsy/tsang/
  tonx/tony` so the server rewind copies them): the surface switches at once,
  but `Crawler.pose(e)` (feet rolling around the corner + angle) is where the
  body really is. Hitbox, inner box, spike and trampoline boxes use
  `Crawler.poseBox`, stomp rules use `e:surfaceNormal()` (pose normal), and
  render draws the same pose. Net: Crabby field 4 = turn progress+1; the client
  starts the turn from its last drawn pose and runs it on its own clock.
  Detaches on knockback / drops and
  re-attaches on landing. Net: surface code in Crabby.netPack (`Crabby.NET_N`
  = number of Crabby fields; subclasses append after it).
- Projectiles: there is no global projectile system; an entity owns its
  projectiles (list), exposes them as hazard boxes and sends them in
  `netPack` with a stable id so the client interpolates them (see mortar).
- Type def fields: name, label, category, class, defaults, props, hide,
  editor={sprite}, pickup, checkpoint, placement='sub', ceilingOnly.

## Online flow

Server (`server/main.lua`):
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

Client (`OnlineAdventureState`): builds `enemyRenderers` from the level (same
indices as server `sim.enemies`), applies interpolated snapshot data to them,
predicts the local player with `Predictor`, processes events at their render
tick (own-player events immediately). Player colors: `PLAYER_COLORS` in server,
delivered in roster → `self.roster[idx].color`.

Game modes: `requires(info)` decides which levels a mode lists
(`info` = {enemies, killable, finish, bosses, autoScroll, pointAreas}); a level
may also whitelist modes with JSON `"modes": [...]` (editor: Nivel tab → Modos
de juego) and set `"matchTime"` (s) for timed modes. Mode defs may set
`emptyHint` (shown when no level qualifies). `m.level` is available to modes.
Mode defs also carry the in-match objective panel (always visible): a compact
3-line panel (MODE / objective / status) at the top between the score and the
lives when it fits (`topFree = WINDOW_W - 832`), otherwise a single thin line
below the score. HIDDEN during a boss fight (the boss bars own the top centre:
y 48 + 72/boss); only a `big` countdown is drawn, below the bars. Texts: `objective` (one sentence) and
`hudLine(md) -> text, urgent, big` (status line from the server hud `md`;
`big` = giant number below, e.g. countdowns). Tile triggers a mode doesn't
list in `triggers` are hidden: `Modes.hiddenTriggers(mode)` →
`level.hiddenTriggers` (Level:render skips those tiles; thumbnails via
`drawPreview(..., mode)`), e.g. the finish is invisible in Hunt/KOTH.

**King of the Hill** (`modes/koth.lua`, icon 'hill'): timed (`matchTime`, default
150 s; hud `tl` = centiseconds left, big countdown ≤10 s). Points come from
**Point Areas** (`src/world/PointAreas.lua`, entity `pointarea`: rect via
`corner` handle, props points/interval/contested; placeholder entity like
`flood`). `PointAreas.update(level, dt, players, award)` is authoritative (SP
and server: server adds ps.score/scoreT and pushes `score` {kind='zone'} +
`fx` 'points' + sound 'pointGain'); `clientUpdate` only drives the visuals
(occupancy, local progress bar via `drawProgress`). The level draws the zones
in `Level:render`. Rank: score, lives, earlier scoreT; nobody scored → no
winner; generic `last_standing` still wins. Hunt rejects levels with zones.
KOTH levels: cumbre_cangrejo, rebote_real, marea_alta (`modes: ["koth"]`; they
list no mode until the user places a Point Area in them).

## Level JSON

`{name,width,height,playerStart:[c,r],tiles:[[raw...]],entities:[...],
foliage:[...],vents:[...]}` (+ `bossZones:[...]`, see below). Editor writes
one tile row per line and only non-default props.

## Editor

Layers (1-6): tiles, water, spikes, entities, deco, special (`LAYERS`/`TOOLS`
at the top of Editor.lua carry their help texts). Left panel: layer, tool
(+ hint card), palette (search + collapsible categories). Right panel has tabs
Selección / Nivel / Avisos. EVERYTHING editable is drawn by
`drawPropFields(schema, obj, …)` from a prop schema: entities, decorations,
boss zones (`zoneSchema`), vents (`VENT_SCHEMA`), auto-scroll
(`AUTOSCROLL_SCHEMA`); each `group` is a collapsible section (`ui.section`),
min/max may be functions(owner), optional `onChange`. New level objects =
a schema + an inspector function in `drawSelectionTab`, not bespoke widgets.
Catalog metadata that drives the editor (no editor code needed):
- entities: `category` (ordered by `EntityTypes.CATEGORIES`: Enemigos, Jefes,
  Trampas, Mecanismos, Objetos, Directores), `description` (palette tooltip +
  inspector), `hide = 'all'` (no common props), `variant = {group, label,
  groupLabel, prop}` (several defs shown as ONE palette card + selector; X
  cycles; inspector enum changes `e.type`) — used by the 4 trampolines.
  Prop groups: the type's own groups first, then `EntityTypes.COMMON_GROUPS`.
- tiles: `TileTypes.CATEGORIES` order. UI text is Spanish WITH accents.
`ui.lua` widgets: button (opts.hint = key), toggle, number, enum (segmented
when it fits), textField (placeholder), section, tabs, hint, caption, label
(fits/ellipsizes). F1 = shortcuts overlay. `E.instances` renders entities as
in-game. `Model:validate()` → warnings (Avisos tab, clickable). F5 playtests
via `AdventureState` with `editor_playtest.json`.

## Boss system (generic)

Files: `src/world/BossZones.lua` (zones + fight controller),
`src/world/entities/Boss.lua` (base class), `src/world/entities/types/mirror.lua`
(MirrorEnemy), `src/ui/BossHud.lua` (segmented HP bars, banners).

- **Zone** (`level.bossZones`, JSON `bossZones:[{id,col,row,w,h,music}]`):
  states `idle → waiting → fight → cleared`. While not cleared, any player whose
  center is inside is walled in (`Level:arenaAt` → clamp in
  `PlayerAdventure:moveAndCollide`; also clamps the boss body). The fight starts
  when ALL `level.players` are inside; bosses get `startFight(nPlayers)`;
  respawn points move into the zone. Camera: `BossZones.cameraTarget` via
  `cameraZone` — during a fight it also stays fixed for players BELOW the zone
  (fell through a broken floor: walls no longer hold them, camera must not follow).
  Music: `BossZones.music(level)` → `Sound.setLevelMusic(track)` (so every
  `Sound.playMusic('level')` call plays the boss track during the fight).
- **Controller** (`BossZones.newController(level, entities)`) runs in
  AdventureState and on the server; returns events `boss_start`/`boss_clear`.
  Calls `boss:onPlayerDeath(pa)` when a participant dies inside.
- **Net**: snapshot `bz = {{stateCode, arrived, needed}, ...}` →
  `BossZones.netApply` on the client (drives arena prediction, camera, HUD).
  Boss entity extras: `netPack` = {hp, hpMax, inv*100, ...netPackExtra}.
  Sound events now carry `pitch`. Remote players' hurt flash = `PF_HURT` flag.
  Damage a boss does to a player is attributed with `Boss.withPlayer(pa, fn)`
  (server sets `Boss.asPlayer`), and the victim's client plays 'dies' via
  `Predictor.reconcile(...).hpDrop`.
- **Stun rule** (anti ground-pound spam): a ground pound on top of a stunnable
  boss (mirror) deals 2, leaves it KO ('ko') AND makes it invulnerable at once
  for `STUN_INV` (3 s > the 1.4 s KO): no follow-up hit while KO. If it's stunned
  by something else (knockback from a nearby GP), `isStunned()` takes ONE hit,
  then `endStun()` + `STUN_INV`. That "ghost" invulnerability blinks
  (`ghostAlpha`), keeps attacking, can't be stunned, and bosses/players pass
  through each other. Invulnerable players also pass through bosses (but not
  `solidFull` objects) and bosses can't hit them.
- **Boss base**: HP = props.hp + props.hpPerPlayer*(n-1); stomp = 1 dmg,
  ground pound on top = 2 dmg (`'pound'` result → `e:pound(pa)`); i-frames
  `INV_TIME` (red flash, stomps only `'bounce'`); body is solid sideways. Death: `dying_hold` (blasts, alternating
  'bossExplode'/'bossHurt') → `dying_fall` → `dead` (alive=false → zone cleared).
  `e:interact(pa)` must be side-effect free (client uses it to predict bounces).
- **Adding a boss**: `types/<name>.lua` with `Entity.extend(Boss, …)`, def fields
  `category='Jefes'`, `boss={title=…}`, `hide=Boss.HIDE`,
  `props=Boss.props({hp=…, hpPerPlayer=…}, {extra props})`; implement
  `initBoss/updateBoss/render` (+ hooks listed at top of Boss.lua); add the name
  to `TYPES` in `src/world/Entities.lua`. Place it inside a zone in the editor.
- **Immune bounce**: landing on a boss that can't be hurt returns
  `'bounce', vy, dirX` → `pa:bounce(vy, dirX)` pushes the player sideways
  (no riding bosses); predicted on the client via `recordBounce(vy, dir)`.
- **MiniBoss1** (`types/miniboss1.lua`, "Nave Malvada"): ship + Evil Monster as
  two independent visuals (ship flips every 1 s; monster cycles Idle/Idle1/
  Idle2, hurt face on hit). States dormant (hidden, not solid) → intro (drops
  in from above the zone view, `miniAppear`) → patrol (waypoints: `points`
  prop, flown in straight 2D lines — they set the height too, minus `lift`)
  → prep (spikes out) → slam (falls until any tile, never below the
  zone floor line `zone.y1`) → stuck (only vulnerable here + first 0.6 s of
  rise) → rise (back to the height it dived from). Breaks `breakTiles` blocks per slam (default 1). Death:
  dying_hold → dying_eject (monster thrown out in an arc, dead anim + X eyes)
  → dying_boom (ship big explosion + screen shake) → dead. Pixel scale 5;
  flies `lift` px (default 32) above its placement cell; 1 full-size spike per
  broken block + 1. The hurt face has no eyes: X eyes are drawn on it (hit +
  death hold) and on the thrown dead sprites, at positions measured per sprite.
- Boss-zone respawns are validated: `BossZones.respawnPoint(level, pa)` moves
  the spawn to remaining ground in the zone if the floor under it was broken
  (`Level:isStandable`, `Level:findGround` are generic helpers).
- **MirrorEnemy**: owns a real `PlayerAdventure` body (`self.body`) and feeds it
  the delayed inputs of its target through a stub `Input` (and a `Sound` proxy
  that lowers pitch). Players record their raw inputs every step
  (`pa.inMoveX, inCrouch, inJumpN, inCrouchN` in `PlayerAdventure:update`).
  It records ALL players, so switching target (nearest, with hysteresis) is
  seamless. `speedMult/jumpMult` on the body make it a bit faster/higher.
  Rendered with an invert-colors shader; laugh = Body_Arms* + Head_* + JoyEyes.
- Levels with bosses are Race-only (`hunt.requires` rejects `info.bosses > 0`).

Player HP: 3 (`pa.hp/hpMax`), `pa:hurt()` = 1 dmg + i-frames + red flash; 0 → die.
Respawn: `pa.spawnInvT` (2.5 s, `PlayerAdventure.SPAWN_INV`) blocks hurt/die/
knockback/recoil and blinks (`invulnAlpha`); only drowning and `die(nil, true)`
(level time limit) go through. `die()` returns false when it was blocked.
Synced in own-state (index 27) and to others via `PF_INVULN` (protocol v8; v9 adds the boss ghost flag + mortar).
Solid bodies: `level.solidBodies` (set each step from `Entities.solidBodies`,
i.e. entities with `isSolidBody()`, e.g. active bosses) block players sideways
in `moveAndCollide` (contact by movement direction, gentle separation if they
already overlap). A body can use `solidAgainst(level)` instead (the mirror's
body collides with `level.players`). The arena wall is looked up from the
position BEFORE moving, so no push can carry anything out of a boss zone.
Online camera freezes while the local player is dying (same as single player).

## Sound attenuation (world sounds)

`Sound.setListener(x, y)` (the local player; camera centre when spectating)
and an EMITTER: `Sound.setEmitter/clearEmitter/withEmitter(x, y, fn)/playAt`.
Every `Sound.play` while an emitter is set is scaled by distance
(`Sound.NEAR` 480 px full volume → `Sound.FAR` 1400 px silent). No emitter =
full volume (UI, own actions). AdventureState sets the emitter around each
entity update; the server sets `_emitX/_emitY` around each player step,
collision pass and entity update, and sound events carry `x, y`; each client
attenuates with its OWN listener (`Sound.playAt`). New world sounds need
nothing special as long as they're played from those update loops.

## Auto-scroll levels (`src/world/AutoScroll.lua`)

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

## Floods (`src/world/Floods.lua`, entity `flood`)

Editor: entity "Inundacion" (Trampas); its cell = top-left, prop `corner`
(`point` handle, moves with the entity) = bottom-right. Props: startLevel/maxLevel
(tiles above the rect bottom), startDelay, riseSpeed/riseStep/risePause,
holdTime, fallSpeed/fallStep/fallPause, lowTime. `Level.fromData` builds
`level.floods` from those placements; the entity itself does nothing in game
(never sent: `netAtRest`). The water level is a PURE function of
`level.floodTime` (`Floods.levelAt`): SP `Floods.advance(level, dt)`, server
`Floods.setTime(level, tick*TICK_DT)`, client = snapshot clock + ping (the tick
at which its predicted inputs get processed; 0 corrections in tests). Physics:
`Level:liquidAt` returns water below `f.surf`, so swimming/drowning/splash/
fireballs work unchanged. Render in `renderWaterEffect` (distortion + tint per
cell, skipping solid blocks and tile water). Surfaces (floods AND tile water
with air above: `Level:isWaterSurfaceCell`) use `src/fx/WaterSurface.lua`: tint
drawn in 4-px columns whose top follows the wave (no flat edge behind it);
distortion starts `WaterSurface.MARGIN` px below the surface. `Floods.updateFx`
(clients only): 'floodRise'/'floodFall' sounds when the water starts moving
(each step too), bubbles via `Level:spawnBubble`. Level `marea_alta.json`.

## Spike rain (orchestrated spikes)

`rainspike` = `spikefall` with `autoDetect = false` (only falls when
`e:trigger(warn)` is called); painted in the editor by dragging (`def.paint`).
`spikerain` = invisible director entity (EvilCaibles port): wave cycle
(min → up → max → down, each wave peaks higher), picks spikes of its `group`
near players with a clear drop, aims ahead of the player with some probability,
round-robin per player, min spacing, per-spike cooldown. All tunables are
props. `EDITOR_VIEW` global is true while the editor draws the map (use it for
editor-only visuals). `drawEditorOverlay(props, cx, cy, zoom, ctx)` gets
`ctx = {entities, t, camX, camY}`; `editor.draw(x, y, s)` = code-drawn icon.

Network scaling: entities whose `netAtRest()` is true (e.g. hanging spikes)
are NOT sent in snapshots; the client calls `netRest()` for missing entries
(the level with 293 entities sends ~540-byte snapshots).

## Original Unity project (reference only)

`/home/mtvemo/Escritorio/Proyecto_Unity_Exportado/ExportedProject/Assets` —
scripts in `Scripts/Assembly-CSharp/`, real inspector values in
`Scenes/Level1.unity`. Port *behaviour and timings*; the physics differ, so
don't copy speeds/forces literally (the user tunes feel by hand).

## Testing without a human

- **Reusable harnesses live in `tools/tests/`** (see its README; e.g.
  `online_smoke`). Put new ones there, not only in the temporary scratchpad
  (it gets wiped between sessions). `tools/` is not shipped (.love / updates).

- Headless sim (no window): a scratch LÖVE app with `t.window=false`,
  `package.path` pointing at the repo, `love.filesystem.read` patched to read
  from the repo and a stub `love.graphics.newImage` (like server headless).
- Screenshots: scratch LÖVE app with symlinks to `assets src libs settings.lua
  input.lua`, `love.filesystem.setSymlinksEnabled(true)`, drive the real state
  with a `Protocol.newInputStub()` as `Input`, `love.graphics.captureScreenshot`
  (files land in `~/.local/share/love/<identity>/` — delete afterwards).
- Online: `love server --headless` + bot clients using `libs/sock` + bitser
  (hello → create_room → set_mode{mode,level} → join_room → set_ready →
  start_game → send `in` {s, b}). Kill the server afterwards (`ss -lunp | grep 22122`).
- Test levels: `assets/levels/jefe_espejo.json` (race, mirror boss arena, mortars),
  `assets/levels/lluvia_pinchos.json` (race, auto-scroll + spike rain),
  `assets/levels/MiniBossArena.json` (race, Nave Malvada; the user's layout),
  `assets/levels/rebote_real.json` (King of the Hill: all 4 trampolines +
  both Trampoline Crabbies), `assets/levels/cumbre_cangrejo.json` (KOTH:
  wall-walking Crabbies), `assets/levels/marea_alta.json` (KOTH: floods).
  For online tests of a KOTH level add a `pointarea` to a temp copy.
- Bots: send `in` only when there are new inputs, or the server kicks them
  for flooding.
