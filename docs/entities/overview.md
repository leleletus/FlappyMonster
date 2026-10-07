# Entities: the base system

Everything placed in a level that is not a tile or a decoration is an **entity**: enemies, bosses, traps, mechanisms,
items and invisible directors. The user's standing priority is **flexibility: base behaviours live in the BASE and a
type only switches them on** — never copy another entity's code. The recipe is in
[how-to-add-an-enemy](how-to-add-an-enemy.md); every registered type is listed in
[reference/entities](../reference/entities.md).

**Files** (`src/world/entities/`)

| File | Role |
|---|---|
| `Entities.lua` | the registry: `TYPES` list, `Entities.create(placement)`, `solidBodies` |
| `base/Entity.lua` | the base class: movement (walk / fly / static), common states, stomp, knockback, launch, freeze, special deaths, reserve minions, network hooks, debug boxes |
| `base/EntityTypes.lua` | type registration, the COMMON props, categories, the render wrapper (wings, ice block, dark edge) |
| `base/Props.lua` | editable property kinds (int, number, bool, enum, text, patrol, point, points) |
| `base/Interactions.lua` | the player ↔ entity rules: kill / hurt / stomp / bounce / pickup / checkpoint / ground pound |
| `base/Crawler.lua` | surface-following movement (floor ↔ walls ↔ ceiling) |
| `base/FreeFlight.lua` | flying to chosen destinations instead of a back-and-forth route |
| `base/Boss.lua` | the boss base class (see [bosses/system](../bosses/system.md)) |
| `base/BombCore.lua`, `base/CrabVariant.lua`, `base/GloomyNav.lua` | shared code of the bombs, the island Crabby variants, the Gloomy's pathfinder |
| `types/<category>/<name>.lua` | one file per type: `enemies/`, `bosses/`, `traps/`, `mechanisms/`, `items/`, `directors/` |

**Life of an entity:** the level JSON holds placements `{type, col, row, sub, props}` → `Entities.create` builds an
instance (`x, y` = centre; boxes `outerW/H`, `innerW/H`) → single player and the server call `e:update(dt, level)`
each step (through `Difficulty.dt`) and `Interactions.run` against each player → the server packs
`x, y, facing, state, frame, alive, deadTimer, …netPack()` into snapshots → clients apply them to their own instances
and only call `render`. Entities see players through `level.players` and each other through `level.liveEntities`.

**Editor categories** (the def's `category`, in Spanish because the editor is): Enemigos, Jefes, Trampas, Mecanismos,
Objetos, Directores.

**Harnesses:** `mechanics` (dozens of cases), `flyers`, `crawler_drop`, `icecrabby_rules`, `gloomy_rules`,
`level_check` (20 s simulation of every level's entities), `project_check` (every type loads and can be created).

## The flexibility rule and what the base offers

**Flexibility rule (user's priority): base behaviours live in the BASE and a type only switches them on** — never
copy another entity's code. Guide: `docs/entities/how-to-add-an-enemy.md` (every def field, trait and hook).
Switches on the type def: `traits = { needsPound, diesWithBlock, solidFull, renderFront, wantsLevel, freezeFloats }`
(copied onto each instance by `Entity.create`), `noises = { sound = tiles }` / `noise` (see Noise), `summons`,
`activatable`. In the base: RESERVE minions for ANY entity (`Entity:makeReserve` + default `netAtRest/netRest`; hook
`onMakeReserve`), stock crawler (`Crawler.mixin(Class)`: rotated boxes, surface normal, release, no fall while
attached; `Crawler.entityAhead`), block-break deaths (`Level:forStanders`, crawlers included), and for bosses
`Boss:enter(st)`, `Boss:zoneBounds()`, `Boss:minions(level)`, `Boss:nearestPlayer(level)`, `Boss.strike(pa, hit, dir)`
(the Snowball Boss's, now shared) and `src/fx/BossFx.lua` (`stars` = stun stars, `anger` = anger symbols, `target` =
landing mark; sprites in `assets/images/bosses/common/`). Asset layout: enemies `assets/images/<enemy>/`, EVERY boss
`assets/images/bosses/<boss>/` (megacrabby and megacrabby_ice moved there), sounds `player/` (incl. the flashlight
`light_*.wav`), `enemies/<enemy>/` (bomb, crabby, gloomy, gummy, mortar, pufferfish; `common/` = explode, respawn), `bosses/<boss>/`, `ambience/`...

## Instances, hooks and the type definition

- Instance = `Entity.create(cls, placement)`; placement `{type,col,row,sub,props}`.
  `x,y` = center; hitboxes `outerW/H`, `innerW/H` from `tuning.hitbox` × sprite size.

- Hooks: `loadAssets, sizeImage|sizePx, init, updateCustom(dt,level)->true,
  onWalk/onIdle/onDead/onStomp, canBeStomped, isBodyDisabled, getHazardBoxes,
  netPack()/netApply(a,b,f), render(camX,camY)`.

- `level.players` = list of active PlayerAdventure (entities "see" players).
  `level.liveEntities` = entities list.

- Type def fields: name, label, category, class, defaults, props, hide,
  editor={sprite}, pickup, checkpoint, placement='sub', ceilingOnly.

- A type file may return a LIST of defs (Entities.lua registers each), e.g.
  trampoline.lua → 4 palette entries sharing one class.

- Editor hook: `Cls.drawEditorOverlay(props, cx, cy, zoom)` draws extra help
  when the entity is selected (mortar detection radius).

## Player ↔ entity interactions

- `Interactions.check` returns kill/hurt/stomp/pickup/checkpoint; `run()` also
  applies the ground-pound impact (`poundZone` kills, radius knockbacks).
  Entities can override interaction completely with `e:interact(pa)` (see boss).
  Hazard boxes may carry `effect = 'hurt'` (1 HP) instead of the default kill.

- Stomp window fix (all floor enemies, `Interactions.defaultCheck`): a stomp also
  counts when the feet were above the stomp line one step before (`STEP_DT`); fast
  falls (≥ 20 px/step) used to skip the ~20 px window and die on contact.

## Solid entities and collisions between entities and the world

- Solid entities: `isSolidBody()` → put in `level.solidBodies` each step.
  `Cls.solidFull = true` = solid like a block (sides, stand on top, head bump;
  e.g. mortar); otherwise sides only (bosses: the top is the stomp zone).

- Entities vs solid objects: walkers/crawlers collide with `solidFull` bodies
  (trampolines, mortars) like blocks (crawlers climb them: `Level:entitySolidAt`).
  Touching a body's bouncy face → `Entity:touchBody` → `Entity:launch(vx,vy)` →
  common state 'launched' (gravity, lands → walk; patrol bounds dropped). Flyers
  aren't launched. Crawlers: `Crawler.supportBody` (face from the normal).

## Walkers

- Walkers never flip-flop when boxed in: `Entity:isBoxedIn` (can't walk either way —
  `canWalk` = `canGo` + no spike/entity ahead + ground ahead if `turnAtEdges` — or less
  than `MIN_ROOM` (half a tile) of total play from walls/limits/edges) → they switch to the
  IDLE state (`boxedIn`; idle animation, never a walk frame; the idle timer is held) and walk
  again as soon as there is room. 'idle' is in snapshots, so online looks the same. Harness
  `mechanics` case `encerrado`. Crawlers keep their own movement.

- Flyers (`movement='fly'`) NEVER go idle: pauses only for walkers on the ground; in
  the air (also stunned) they keep the walk animation (`Entity:animateWalk`).

## Flyers and free flight

- **Flyers** (`props.movement == 'fly'`): the vertical bob is a TARGET
  (`baseY + sin`) reached with `moveAndCollide` (stops at floors/slabs/solid
  bodies instead of clipping into them). A flyer already embedded > `EMBED` px in a
  face ignores it (gets out instead of flipping every frame); one blocked ahead by an
  entity doesn't turn if it can't go the other way (entity behind, patrol limit or
  wall: `Entity:canGo`) and, after turning for an entity, ignores entities for
  `FLY_TURN_CD` 0.8 s (it passes through): no convulsing, no pinning at a limit.
  The `flyers` harness uses fixed random sequences: `SEED=n` tries others.
  **FREE FLIGHT** (`src/world/entities/base/FreeFlight.lua`; common props `flyMode` = 'route' | 'free' and `flyRange`
  tiles around its home; or `e.freeFly` + `e.flyArea` {x0,y0,x1,y1} set by whoever spawns it): instead of going back
  and forth it picks a DESTINATION inside its area — a point where its box fits with margin (`FF.fits`) and that it
  reaches in a straight clear line (`FF.clear`) — flies to it with smooth steering and picks another on arrival / when
  slowed (`BLOCK_T`) / on timeout. Half the picks go to the candidate nearest a player (a real obstacle), the other
  half explore: the least-visited 3-tile sector of its area (`ffSeen`), farthest on ties. Never trapped: under a
  platform / in a pocket / in a corner it only accepts destinations with a clear path; with none in sight, short
  escapes in 8 directions; INSIDE something (a boss wall appeared on it) it goes to the nearest free spot through it
  (`ffGhost`, no collisions). Sim only (SP/server; clients draw snapshots). Any flying entity can use it. Harness
  `mechanics vuelo_libre` (out of a U pocket, from under a platform, out of a block; ≥ 11 of 15 sectors visited, never
  still > 2.5 s, never inside a block, approaches the player). Wings:
  `EntityTypes.drawWings` in the render wrapper (so every flying entity type gets
  them, behind the body): `assets/images/enemies/wings/wings-Sheet.png` (LEFT wing, 2
  frames 9x13, root at the right edge) + its mirror, integer scale; placed
  SYMMETRIC on the VISIBLE body: the opaque box of the type's `editor.sprite` (first
  frame if `editor.frameW`), measured once, with facing and flip (sprites are not
  always centred in their canvas); no sprite → outer hitbox. Harness `flyers` (every level, all enemies as
  flyers).

## Crawlers (walls and ceilings)

- **Crawler** (`src/world/entities/base/Crawler.lua`): surface-following movement
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
  render draws the same pose. Net: `Crawler.netPack/netApply` (surface code + turn
  progress+1; the client starts the turn from its last drawn pose and runs it on its
  own clock), shared by Crabby and MegaCrabby. Big crawlers can lengthen the turn
  (`e.turnLength`, `e.turnMax`) and an entity can add solidity (`e:crawlSolidAt`).
  Detaches on knockback / drops and
  re-attaches on landing. Net: surface code in Crabby.netPack (`Crabby.NET_N`
  = number of Crabby fields; subclasses append after it).

## Special deaths

- **Special deaths** (`Entity:dieFling(dir)` / `dieBurst()`, states `dead_fling` /
  `dead_burst`, `Entity.SPECIAL_DEATH`): already dead, ghosts (no interactions), fly through
  everything, end like 'dead' (`finishDeath`: respawn or gone). Drawn from state + deadTimer
  + x,y (same online). `dead_fling` = the block under it broke (`Level:breakTile` →
  `Level:forStanders`: 'Enemigos' category standing on the cell), spins up and out.
  `dead_burst` = a LAUNCHED entity lands on spikes / `contact='kill'` material
  (`Entity:onDeadlyGround`): fx `enemy_burst` (flash, shell chunks, smoke) + shake. Hitting
  an ON/OFF Activator (`hitTile` toggle) makes enemies on it hop (vy −380), never kills.
  Trampolines: an UP launch gives walkers their walking speed forward (min
  `LAUNCH_MIN_VX`) and starts them exactly on top of the face (a climbing Crabby was half
  inside the box, hit it sideways and bounced in place forever). Harness `mechanics`.

## Hitboxes on screen (F1)

- **3.84.1 — F1 HITBOXES reviewed** (user: not everything that has a hitbox showed one). (1) ONLINE drew only the
  local player and the level: now also every entity (from its snapshot state; each `renderDebug` under `pcall`, the
  first error printed as `[hitbox] …`) and the other players' boxes. (2) Generic hook `Entity:debugBoxes()` → list of
  `{ x, y, w, h, kind }` / `{ cx, cy, r, kind }` (kind: nil / 'hurt' red, 'weak' yellow = where you hit it, 'area'
  white) drawn by the base `renderDebug` after the outer / inner / hazard boxes — for everything that hits or can be
  hit and is NOT one of those: Mega Crabby contact boxes (`Mega:contactBoxes()`, now also used by `hitPlayers`), Icy
  Mega (frozen claws, frost waves, field icicles that already hurt), Mega Gloomy (attack body box, claw line: white
  while aiming, red when it strikes), Gummy King's PARTS, the Mirror's copied body, Crabby trampoline face, Icy Crabby
  snow mound, boss glass, bombs' three blast radii while lit; SP also draws the bonus BOTS. A new type with its own hit
  area must implement `debugBoxes()`. (3) Lines are 2 px (1 px at ~0.5 alpha was nearly invisible). `FM_HITBOX=1`
  (read in settings.lua) starts with them ON: `FM_HITBOX=1 tools/tests/run.sh all|sp_boss|online_boss …` checks that
  drawing them never errors.
