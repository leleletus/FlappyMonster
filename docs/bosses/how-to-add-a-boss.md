# How to add a boss (step by step)

A guide to add a boss without studying the whole code again. It is written from the bosses that already exist and
from the mistakes already paid for. Follow the steps in order and tick the **checklist** at the end.

**A simple boss needs no code:** the enemy editor (`love . --enemy`, switch "JEFE") builds one from data — walks at
the player, attacks with behaviour pieces, is hit while tired, rages at low health
([enemy-editor](../entities/enemy-editor.md#bosses), `src/world/entities/base/DataBoss.lua`). Write a Lua boss, as
below, for anything beyond that (minions, arena mechanics, computed poses, more than two phases).

Reference bosses (copy from the one closest to what you want):

| Boss | File (`src/world/entities/types/bosses/`) | What to copy from it |
|---|---|---|
| Evil Ship (Nave Malvada) | `miniboss1.lua` | flight through points (`points`), slam onto the floor, breaking blocks |
| Mirror | `mirror.lua` | a boss that copies the player (its own `PlayerAdventure` body), portals, arena platforms |
| Mega Crabby (+ icy) | `megacrabby.lua`, `megacrabby_ice.lua` | climbing walls / ceiling (Crawler), **reserve minions**, intro with its own states, subclass with other art |
| Snowball Boss | `snowboss.lua` | **its own physics** (crashes, jumps to a mark, zone), projectiles, phases that change its size, stage objects per phase |
| **Gummy King** | `megagummy.lua` | **the cleanest to start from**: reuses the Snowball's physics, attack with a mark + waves, minions (guard), splits into parts, its own death |

> **First of all:** what bosses have in common is ALREADY in the base — do not copy it from another boss.
> `Boss:enter(st)`, `Boss:zoneBounds()`, `Boss:minions(level)`, `Boss:nearestPlayer(level)`,
> `Boss.strike(pa, {hp, vx, vy, ctrlLock, stun}, dir)`, `Boss:mayAttack(level)` (ally turns on Xtra Extreme);
> shared effects in `src/fx/BossFx.lua` (`stars`, `anger`, `target`; sprites in `assets/images/bosses/common/`);
> reserve minions: any entity (`Entity:makeReserve`). Each boss's art goes in `assets/images/bosses/<boss>/`.
> Traits and the rest: [how-to-add-an-enemy](../entities/how-to-add-an-enemy.md). How zones, intros, phases and
> walls work: [system](system.md).

## 0. Design (before writing code)

Write in 10 lines (they then go into the header of the boss file):

1. **How it chases / moves** (walks, jumps, flies…).
2. **Its attacks** and how they are telegraphed: EVERY attack has a warning (floor mark, crouch, shake, sound). What
   hurts must be dodgeable (jump, step aside, get on a platform).
3. **When it is vulnerable**: one clear window (dazed, stuck, soaked…). Outside it, landing on top only bounces
   (`'bounce'`). General rule: stomp = 1, ground pound = 2, one hit per opening.
4. **Phases** (usually 3, by fraction of health): what changes (pace, new attacks, the stage).
5. **Intro** (short cinematic, 3-4.5 s) and **death** (its own, or the generic explosions).
6. Damage to players: contact 1, strong attacks 2, crushing = 2 + `pa:squash`.

Default health: `hp` for 1 player (8-14) and `hpPerPlayer` (3-4) for each extra player.

## 1. Art (sprites and animations)

- **Everything is a file** in `assets/images/bosses/<boss>/` made by a **generator** in `tools/art/bosses/`
  (Python + PIL) that is committed. Code only places / animates.
- If the boss is the "Mega" version of an enemy: **the SAME pixel grid as the small sprite** (e.g. the 16x16 Gummy)
  drawn at a large scale (10). Only 1-pixel touch-ups. A new body with more resolution does NOT fit the game (the
  user rejected it twice).
- If you redesign an image that already exists: the original goes OUTSIDE the repo (`tools/art/lib/originals.py`).
- Frame strips (`<thing>-Sheet.png`, frames of the same width side by side) and in code
  `SpriteStrip.load(path, frameWidth)` → `:draw(i, x, y, r, sx, sy)` / `.image`, `.quads[i]`.
- What is usually needed: idle, walk (2), jump / air, stunned / dazed, hurt, laugh, shout; landing mark, shadow,
  projectiles / waves, stun stars, pieces that fly off.
- Pieces that separate from the body (crown, helmet…): in a SEPARATE image with the same grid and origin, drawn on
  top → they can fly off later.
- Before applying, show options to the user: preview in `/home/mtvemo/FlappyMonster_pruebas/<thing>/vista_previa.png`
  (or `$FM_PREVIEWS`), with an `--apply` flag.
- Example: `tools/art/enemies/make_gummy_variants.py --apply-mega` (function `boss_art`).

## 2. Sounds

- Generator `tools/sounds/<boss>.py` → `assets/sounds/bosses/<boss>/*.wav`. Reuse the helpers of
  `tools/sounds/megacrabby.py` (`env`, `sweep`, `noise`, `lowpass`, `reson`…) and `snowboss.py` (`save`, `voice`,
  `tink`). A complete short example: `tools/sounds/megagummy.py`.
- Registration in `src/audio/Sound.lua` (3 places):
  1. `GAIN` (top): per-sound gain to land at ≈ −12 dBFS (the loudest 100 ms stretch). Measure it with this Python
     and set `g = 10 ** ((-12 - dB) / 20)` (very big hits: up to −9):
     ```python
     import wave, numpy as np
     w = wave.open(f); x = np.frombuffer(w.readframes(w.getnframes()), '<i2') / 32768
     n = int(w.getframerate() * 0.1)
     db = 10 * np.log10(max(np.mean(x[i:i + n] ** 2) for i in range(0, len(x) - n, n // 4)))
     ```
  2. Loading: a loop `for _, n in ipairs({...}) do load('<prefix>' .. ..., path, 'static') end`.
  3. `RANGE`: boss sounds heard across the whole arena (2-3).
- Check: `tools/tests/run.sh sounds NAMES=a,b,c`.
- Sounds decided only by the server that everybody must hear → `Protocol.SHARED_SOUNDS`.

## 3. Particles

- New kinds in `src/fx/Particles.lua`, inside `Particles.emit(kind, x, y, opts)` (chain of `elseif kind == '...'`).
  Useful fields of `add{}`: `vx, vy, g, drag, life, size, col, star, chunk, spin, phys (collides with the level),
  bounce, dust, fadeLast`.
- From the SIMULATION (single player and server): `Entity.emitFx(kind, x, y)` → reaches every client as an `fx`
  event (no `opts`: for a variant use another name, e.g. `king_confetti_big`).
- From DRAWING (only on that client; continuous: trails, drips, glints): `Particles.emit` directly with a local
  timer (`if (self.lastX or 0) + 0.05 < now then ... end`).
- Screen shake: `Entity.emitFx('shake_small' | 'shake_big' | 'shake_roar', x, y)`.

## 4. The entity (`src/world/entities/types/bosses/<boss>.lua`)

Minimal skeleton (see the whole `megagummy.lua` as a model):

```lua
local Entity = require 'src/world/entities/base/Entity'
local Boss   = require 'src/world/entities/base/Boss'
local SpriteStrip = require 'src/fx/SpriteStrip'
local Snow = require('src/world/entities/types/bosses/snowboss').class   -- (reusable physics)

local X = Entity.extend(Boss, { hitbox = { outerW = 12/16, outerH = 13/16, innerW = 11/16, innerH = 12/16 } })
X.hurtSound   = 'xHurt'
X.introLength = 3.6            -- generic intro (s)
X.wantsLevel  = true           -- gets self.levelRef (BossZones.link): drawing on the real surface
X.move, X.physics, X.friction, X.groundDecel = Snow.move, Snow.physics, Snow.friction, Snow.groundDecel
X.zoneBounds, X.target, X.jumpTo, X.groundBelow = Snow.zoneBounds, Snow.target, Snow.jumpTo, Snow.groundBelow

function X.loadAssets() ... end
function X.sizePx() return 16 * 10, 16 * 10 end
function X:initBoss() self.y = self.row * TILE_PX - self.outerH / 2 ... end   -- standing on its cell
function X:onFightStart(n) self:enter('chase') end
function X:updateBoss(dt, level) ... end        -- state machine (self.deadTimer = time in the state)
function X:isVulnerable() return self:isActive() and self.state == 'dazed' end
function X:netPackExtra() ... end  function X:netApplyExtra(a, b, f) ... end
function X:render(camX, camY) ... end
return { name = 'x', label = 'Nombre', category = 'Jefes', class = X, boss = { title = 'NOMBRE' },
         hide = Boss.HIDE, defaults = { points = 30 },
         props = Boss.props({ hp = 12, hpPerPlayer = 4 }, { ...own props with group = 'Boss name' }),
         editor = { sprite = 'assets/images/bosses/x/body-Sheet.png', frameW = 16 } }
```

Rules that can NOT be broken:

- **The same in the 3 places** (single player, server, online client). The simulation (`updateBoss`) only runs in
  single player and on the server; the client receives `x, y, state, deadTimer` + `netPack`. **Everything drawn comes
  from state + deadTimer + x, y + netPackExtra.** No state that exists only in the simulation if drawing needs it.
- No `love.graphics` outside `render` / `loadAssets`.
- `interact(pa)` has **no side effects** (the client uses it to predict bounces). It returns
  `'stomp'|'pound'|'bounce', vy, points|dirX`. The base (`Boss.interact`) already does: on top + vulnerable =
  stomp / pound; on top and immune = sideways bounce; from the side nothing (the body is solid).
- Damage to players inside `Boss.withPlayer(pa, fn)` (the server attributes sounds / deaths). A hit with a push:
  `Boss.strike(pa, {hp, vx, vy, ctrlLock, stun}, dir)` (0 HP = push only). Check `pa:isInvulnerable()` and "it is
  not landing on top" before contact damage.
- Own death: override `defeat()` (state `dying_<something>`), `isDying()`, `isActive()` and `releasesZone()` (the
  zone is released although the animation goes on); at the end `state = 'dead', alive = false`.
- If a hit could "overshoot" a threshold (e.g. splitting), clamp it in `damage()` (see `MG:damage`): health must
  not drop more than the design says.
- Phases: `bossPhase()` returns the phase → the zone uses it (`PhaseBlocks`, `phase` props of objects).
- `self.levelRef` may be missing on the first step: set it in `updateBoss` (`self.levelRef = self.levelRef or level`).
- List the attack states in the tuning table `ATTACKS = {...}` and ask `self:mayAttack(level)` where it decides to
  attack (so two bosses on Xtra Extreme take turns).
- Anything that hits or can be hit and is not the outer / inner / hazard boxes: `debugBoxes()`.

Reusable physics (Snowball Boss): `self:physics(level, dt)` (gravity 2200, collisions with blocks and bodies,
platforms only from above, zone walls / ceiling, returns `'wall'`), `self:jumpTo(tx, ty, tilesUp)` +
`self.passY = ty` (ballistic jump that PASSES THROUGH whatever is above the mark and lands exactly on it),
`self:friction(level, dt)`, `self:target(level)`. For objects that are not the entity (parts, big projectiles) make a
table with those same methods (see `Part` in `megagummy.lua`).

### Network (`netPackExtra` / `netApplyExtra`)

- `Boss` already sends `hp, hpMax, inv, ghost`; yours goes after (index 1 = first extra field).
- Fixed fields first, then lists as `n, {fields}×n` (see `readList` in `megagummy.lua`).
- Projectiles / waves: with a stable `id` to interpolate between snapshots (`a` = previous, `b` = new, `f`).
- Changing netPack or the entities the level creates ⇒ **bump `Protocol.VERSION`** (and `version.txt`).

### Generic intro

`introLength` + `onIntroStart(level, players)`, `updateIntro(dt, level, t)` (place x, y; sounds once with a counter
`introStep`), `introFocus()` (camera). During the intro players are frozen and the music is silent. In
`pose()` / `render` use `t` (and in 'ready' `introLength + t`). Before the intro (`'dormant'`) it is not drawn
(except with `EDITOR_VIEW`).

## 5. Minions (optional)

- In the definition: `summons = function(pl) return { {type, col, row, summonKey, props}, ... } end` → the level
  creates them in RESERVE when loading, after the JSON entities (same indices on server and clients). One unique key
  per boss: `'xx' .. col .. ',' .. row`.
- Any entity type can be a reserve minion (`Entity:makeReserve` in the base; hook `onMakeReserve`).
- The boss: `minions(level)` (those with its `summonKey` in `level.liveEntities`), `summonable(level)` (free and
  below the maximum), activating them: set `e.home`, `e:resetToHome()`, `e.state = 'spawning'`, bounds
  (`leftBoundPx/rightBoundPx` = the zone) + `Entity.emitFx('spawn', ...)`.
- When the boss dies, the living ones vanish (`e.state = 'dead'` + particles).

## 6. Registration

- `src/world/entities/Entities.lua`: `'bosses/<boss>'` in `TYPES`.
- Languages: `boss.<type>` in **EVERY** `assets/lang/*.lua` (es and en). The `lang_names` harness requires it.
- `src/network/Protocol.lua`: `P.VERSION` + 1 (with a note in the comment).
- `version.txt`: bump (3.x.0 for a new boss).

## 7. Test arena

- Generator `tools/levelgen/arenas/make_jefe_<x>.py` → `jefe_<x>.json` (see `make_jefe_gummy.py`: it uses `write`
  and `enc` from `make_jefe_nieve.py`). Height 15 (so it can be grafted into real levels).
- Zone `bossZones: [{id, col, row, w, h, music}]` (music: a track with `"boss": true` in
  `assets/music/index.json`), boss walls (`bosswall`) left, right and ceiling, the boss standing on the zone floor
  (`row` = the row just above the floor), the finish on the right.

## 8. Real level

- `tools/levelgen/levels_boss.py`: function `my_level()` = a platform stretch with enemies of the theme +
  `graft(L, load_src('jefe_<x>.json'), 6, startCol)` + add it to `BUILDERS`. `L.extra['name_en']`.
- `tools/levelgen/retheme.py`: rows in `THEMES` and `SKY`.
- `python3 tools/levelgen/build.py --only my_level` (**always with `--only`**) and then
  `python3 tools/levelgen/retheme.py my_level` (**always with level names**).
- Check: `tools/tests/run.sh level_solve -- assets/levels/my_level.json` and
  `tools/tests/run.sh level_check -- assets/levels/my_level.json` (must list `race`).
- Story: add it to `src/story/Worlds.lua`, its shard to `src/story/Shards.lua`, apples with
  `tools/levelgen/add_apples.py`.

## 9. Tests (harnesses)

1. **`<boss>_rules`** (new): copy `tools/tests/megagummy_rules/` (links + `conf.lua` with its own `identity` +
   `main.lua`). One case per design rule, in the real arena. Tricks already learnt:
   - Placing the boss by hand: feet at `(FLOOR_ROW - 1) * TILE_PX` (not inside the floor).
   - The damage functions go through `level.players`: set it before calling them.
   - For contact damage, really overlap the player (`pb.w`) and set `invT = 0`.
   - Case `red` (network): `netPackExtra` → another new boss `netApplyExtra` → same data and same `interact`.
   - Add it to the `all` battery in `tools/tests/run.sh` and a row in `tools/tests/README.md`.
2. **`boss_intro`** `LEVEL=<arena> SECS=60`: add to its `main.lua` the first fight state and the intro sounds of the
   boss (tables next to `snowboss` / `megagummy`).
3. **`boss_sim`** `LEVEL=<arena>`: add a block that plays "as intended" (dodge the mark, jump what is jumped, hit in
   the window) and checks at the end (states seen, phases, death + zone `cleared`). See the `king` block.
4. **`boss_frames`** `LEVEL=<arena> FX=1 ZONE=1 STATES=...`: a grid of captures to review the look (if the boss needs
   hits to advance, add a hook like the Gummy King's). LOOK at the image.
5. **`sp_boss`** `LEVEL=assets/levels/my_level.json SECS=60 FIGHT_SHOT=1` (the real game in single player); also
   `DIFF=xtra` (two bosses) and `FM_HITBOX=1`.
6. **`online_boss`** `LEVEL=<arena> NOSHOTS=1` (server + client: states and minions over the network).
7. `sounds NAMES=...`, `lang_names`, `docs_reference`, and the `all` battery before pushing.

## 10. Documentation and delivery

- `docs/bosses/<boss>.md` (states, rules, files, arena, level, harnesses, protocol version) + a row in
  `docs/bosses/system.md`; `tools/tests/run.sh docs_reference` for the generated tables; the harness in
  `tools/tests/README.md`.
- Header of the boss file (in Spanish, like all code comments): the design of step 0.
- Commit in Spanish, push to master, `tools/deploy_server.sh`. Quick syntax check:
  `for f in $(git ls-files '*.lua' | grep -v resources/); do luajit -bl "$f" >/dev/null || echo "$f"; done`

## Checklist

- [ ] Design written (movement, telegraphed attacks, vulnerable window, phases, intro, death)
- [ ] Art generator in `tools/art/bosses/` + PNGs in `assets/images/bosses/<boss>/` (same grid if it is a "Mega")
- [ ] Sound generator `tools/sounds/<boss>.py` + `Sound.lua` (measured GAIN, loading, RANGE)
- [ ] New particles in `Particles.emit`
- [ ] `types/bosses/<boss>.lua` (+ `TYPES` in `Entities.lua`), `ATTACKS`, `debugBoxes()`
- [ ] Minions: `summons` (if any)
- [ ] `netPackExtra/netApplyExtra`; `Protocol.VERSION` + 1; `version.txt`
- [ ] `boss.<boss>` in every language
- [ ] Arena `tools/levelgen/arenas/make_jefe_<x>.py` + `.json`
- [ ] Real level in `levels_boss.py` + `retheme.py` (THEMES, SKY) + `build --only` + retheme + Worlds / Shards
- [ ] `level_solve` and `level_check` OK
- [ ] `<boss>_rules` (new, in `all`) + `boss_intro` + `boss_sim` + `boss_frames` (looked at) + `sp_boss` + `online_boss`
- [ ] `docs/bosses/<boss>.md` + `docs_reference` + `tools/tests/README.md`
- [ ] Commit + push + deploy
