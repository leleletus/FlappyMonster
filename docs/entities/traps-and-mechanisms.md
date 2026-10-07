# Traps and mechanisms

Things that are not enemies: **traps** (Freezer, falling spikes, the mortar is an "enemy" by category but behaves
like a turret), **mechanisms** (trampolines, floods, point zones, boss walls, boss glass, phase blocks) and
**directors** (the invisible spike-rain orchestrator). Types and props: [reference/entities](../reference/entities.md).

Related docs: ON/OFF Activators and blocks are tiles → [tiles-and-blocks](../gameplay/tiles-and-blocks.md); floods →
[water-and-floods](../gameplay/water-and-floods.md); point zones → [game-modes](../gameplay/game-modes.md); boss
walls, glass and phase blocks → [bosses/system](../bosses/system.md); spike rain →
[autoscroll](../gameplay/autoscroll.md).

**Linking:** any type with `activatable = true` can be wired to ON/OFF Activators in the editor (tool "Conectar");
in game it asks `level:signal(id)`.

## Trampolines

- Trampolines (top/bottom faces need 120 px/s; UNDER WATER 25: the slow fall never reached 120 and only a ground
  pound launched): `solidFull` bodies with `bouncyFace`. The player's
  `moveAndCollide` records `pa.bodyHit = {o, face, speed}` (face of the BODY it
  hit this step). `e:interact` returns `'launch', vx, vy` when the face and
  speed match → `pa:launch(vx, vy)` + `e:onLaunch(pa)`; predicted on the client
  (`Predictor:recordLaunch`). States ready → bounce (0.1 s: everyone touching
  bounces) → extended (`cooldown`, just a wall) → retract → ready.

- FROZEN TRAMPOLINES (3.73.0): trampoline prop `skin` = 'auto' (default) | 'normal' | 'ice' (render only; editor
  "Aspecto"). Auto = the ICE texture (`trampoline/ice_normal.png` / `ice_extended.png`, the same art as the Icy
  Crabby's trampoline) in snowy levels — `level.spikeSkin == 'ice'` or `level.snow` — so no level data had to change
  and none can be left mixed (`Tramp.skinFor(props, level)`, needs `levelRef`: `wantsLevel`). New skin = 2 PNGs + one
  `SKINS` line. Today only lago_helado has a plain trampoline among the icy levels.

## Freezer (Congelador) and being frozen

- **Freezer** (`types/traps/cryo.lua`, entity "Congelador", Trampas; liquid-nitrogen launcher): solid 1-cell
  block (`solidFull`; prop `phase` > 0 = only from that boss phase on, see Phase system), prop `dir` (right/left/up/down; sprite drawn facing right, rotated). States
  idle → windup (`windup` s: shakes, gauge glows, frost puffs, cryoWindup) → fire (stream grows/leaves at
  `STREAM_SPEED` 1800 px/s for `burst` s, cut at the first solid tile = `reach` in netPack; cryoBlast) →
  idle. `mode` 'interval' (`interval`, `firstDelay`) or 'switch' (`activatable`: fires when its linked ON/OFF
  Activator changes, `trigger` any/on/off; linking it in the editor sets switch) — boss arenas: fires with
  the gates. Stream = hazard box `effect='freeze', time` → `pa:freeze(t)` (own-state index 30 `iceT`,
  `PF_ICE` 128, protocol v36): no control (FROZEN_INPUT), keeps its pose, slides/falls; each jump/crouch
  press removes 0.22 s; on break cryoFree + fx `ice_shatter` + 0.7 s invulnerability. Enemies in the
  stream: `Entity:freeze(t)` → common state 'frozen' (`canFreeze`: category Enemigos only; mortar no;
  bosses no unless they override; `freezeFloats` = stays in place, pufferfish), deadTimer = time LEFT,
  falls (flyers too), harmless (`Interactions.frozenCheck`: landing on it / GP → 'stomp' kills a stompable
  one, else 'shatter' = thaw), `thaw()` resumes the previous state with its timer. Look: `src/fx/IceEncase.lua`
  (9-slice `fx/ice_block.png` around the body + ice tint shader, blinks the last 0.6 s), used by the
  EntityTypes render wrapper, PlayerAdventure and OnlinePlayer. Art `assets/images/traps/cryo/` from
  `tools/art/world/make_cryo_sprites.py`; sounds `traps/cryo_*.wav` from `tools/sounds/cryo.py` (cryoFreeze is a
  SHARED sound). Particles cryo_puff/cryo_mist/cryo_blast/ice_freeze/ice_shatter. Harness `mechanics`
  (cryo_*). Drawn from PIECES (`tools/art/world/make_cryo_parts.py`, all 16x16 centred on the cell): body
  `cryo_body-Sheet` (always upright, 4 frames), cannon `cryo_cannon-Sheet` (drawn facing right, rotated to
  `dir`), feet `cryo_feet` (drawn facing down, rotated to the supporting side); `cryo-Sheet` = the classic
  assembly (editor icon). `Cryo:support()` (render only, needs `levelRef`: `wantsLevel`, also set by the
  editor) = the solid side holding it, never the firing side, preference floor → behind the cannon → sides →
  ceiling; nil = it HANGS: no feet, `cryo/chain.png` + `anchor.png` + `clamp.png` to the ceiling
  (`tools/art/world/make_cryo_chain.py`; two side chains when firing up). Harness `snowboss_look` (snow_cryo.png),
  `online_smoke LEVEL=tools/levelgen/arenas/congelador.json WATCH=gummy WANT=frozen WANTICE=1`,
  `editor_open PLAY=tools/levelgen/arenas/congelador.json`.
