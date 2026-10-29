# tools/ — development tools (never shipped to players)

Run everything from the repo root. Documentation: `docs/README.md`. Python tools use PIL (art), numpy / soundfile
(sounds) and the venv `~/.venvs/fm-music` (music).

| Folder | What | Read first |
|---|---|---|
| `tests/` | every test harness + `run.sh` | `tools/tests/README.md`, `docs/testing/harnesses.md` |
| `art/` | image generators (their PNGs are committed) | `docs/art/generators.md` (**hand-edited list**) |
| `sounds/` | sound-effect generators → `assets/sounds/` | `docs/audio/sound.md` |
| `music/` | Famicom engine + track generators → `assets/music/` | `docs/audio/music-catalog.md`, `docs/audio/music-guide.md` |
| `levelgen/` | level builders, retheme, test arenas | `docs/levels/generator-and-solver.md` (**read the DANGER note**) |
| `anim/` | generators of animation sets (`assets/anim/`, one per image folder): sheets as named animations, loose images, the Crabby family, `split_states.py` (one animation per state) and `port_names.py` (the data steps of the move to by-name animations) | `docs/art/animation.md` |
| `video/` | OST presentation videos | `docs/tools/ost-videos.md` |
| `legal/` | `make_licenses.py` → `assets/legal/THIRD_PARTY_LICENSES.txt` (the full third-party license texts; `OFL-1.1.txt` = the font's) | `docs/story/credits.md` |
| `story/` | `test_saves.py`: story save slots already advanced to a level (to test something late in the story) | `docs/story/cinematics.md` |
| `deploy_server.sh` | update the game server after a push (`--status` = look only) | `docs/architecture/updates-and-release.md` |

## Three traps

1. `python3 tools/levelgen/build.py` without `--only <level>` rewrites EVERY generated level (so does `--show`).
2. `python3 tools/levelgen/retheme.py` has no `--help` and WITHOUT level names runs over every THEMES level. Pass
   level names. (An unknown flag now stops it without touching anything; `--bg` refuses to run without names or
   `--bg-all`.)
3. Several art generators would overwrite sprites the user has since hand-edited. Check `docs/art/generators.md`.

## art/

`lib/originals.py` — where the originals of redesigned images live (outside the repo). Scripts add `tools/art/lib`
and their own folder to `sys.path`; scripts that import each other sit in the same folder.

| Script | Writes (under `assets/images/` unless noted) | Re-run? |
|---|---|---|
| `enemies/make_crab_redesign.py` | restyle of Crabbies, trampolines and ALL spikes from the originals | not re-run since the reorganisation |
| `enemies/make_gummy_redesign.py` | restyle of Gummies, helmet, wings | not re-run |
| `enemies/make_pufferfish.py` | `enemies/pufferfish/` (design A "Arena", the user's pick; B and C kept in the script) | safe to re-run |
| `enemies/make_bomb_fuses.py` | `enemies/bomb/*-rope-Sheet.png`, `*-fuse-Sheet.png` (the rope, unlit and burning, matched to each bomb of the user's body sheets) and the animations of the set `enemies/bomb` | yes (`--apply`); re-run when the body sheets change; rewrites that set's animations |
| `enemies/make_bomb_redesign.py` | `enemies/bomb/explosion-Sheet.png` only (the bodies are the user's) | yes (`--apply`) |
| `enemies/make_enemy_designs.py` | design PROPOSALS (previews) — and the pixel maps other scripts import | previews only |
| `enemies/make_variant_skins.py` | `enemies/gummy_magma/`, `gummy_cave/`, `gummy_fortress/`, `crabby_fortress/` | **NO: gummy_fortress is hand-edited** |
| `enemies/make_crab_species.py` | `enemies/crabby_river/`, `crabby_lava/`, `crabby_cave/` | **NO: lava legs are hand-edited** |
| `enemies/make_hopper_sprites.py --apply` | `enemies/hopper/<island>-Sheet.png` | yes (verified identical) |
| `enemies/make_jungle_skins.py --apply` | the jungle island (`jungla`) variants: `enemies/gummy_jungle/`, `crabby_jungle/`, `jungla-…` of hopper, gust (+ row 7 of `gust/wind-Sheet.png`), box, scale, geyser, wind, seed, `items/food_jungla.png` (previews in `FlappyMonster_pruebas/jungla/variantes/`) | yes (never overwrites without `--force`) |
| `enemies/make_icecrabby_sprites.py`, `make_icecrabby_claws.py` | `enemies/crabby_ice/` | **NO: bodies hand-edited** |
| `enemies/make_gummy_variants.py` | `enemies/gummy_ice/` (`--apply-helado`), `bosses/megagummy/` (`--apply-mega`) | not re-run |
| `enemies/make_crown_broken.py` | `bosses/megagummy/crown_broken.png` (the King's broken crown after his defeat, from `crown.png`'s colours) | safe to re-run |
| `enemies/make_gloomy_sprites.py` | `enemies/gloomy/`, `bosses/megagloomy/` | **NO: Mega Gloomy sheets hand-edited** |
| `enemies/make_enemy_extras.py` | crushed Crabby frames, the guard's parachute, the icicle field | not re-run (never the Mega's claws) |
| `bosses/make_icecrab_sprites.py` | `bosses/megacrabby_ice/` | **NO: bodies hand-edited** |
| `bosses/make_snowboss_sprites.py`, `make_snowboss_cracks.py` | `bosses/snowboss/` | not re-run |
| `bosses/make_verity_body.py --apply` | `bosses/snowboss/verity/body-Sheet.png` from the user's palette | when the user edits Verity's palette |
| `world/make_terrain.py`, `make_world_art.py`, `make_snow_sprites.py`, `make_biome_art.py` | `world/tiles/`, mortar, checkpoints, lava, volcano and meadow art | terrain yes (verified); **make_world_art NO for checkpoints (hand-edited)** |
| `world/make_sky.py` | `world/sky/` | yes (verified) |
| `world/make_decorations.py` | `world/decorations/` | not re-run (never overwrites without `--force`) |
| `world/make_jungle_decor.py [--apply [--force]]` | `world/decorations/jungle/` (the `jungle_set`) + `fx/` jungle_leaf, firefly, pollen, mist, drip, and their animations in `assets/anim/world/decorations/jungle.json` / `fx.json`; the frog, toucan and monkey are drawn but never applied (`NOT_APPLIED`); previews in `FlappyMonster_pruebas/selva/decoraciones/` | yes (never overwrites without `--force`; animations only added) |
| `world/make_big_trees.py [--apply [--force]] [name …]` | big trees and extras per island in `world/decorations/<meadow\|tropical\|ice\|volcano\|cave\|fortress>/` (palms: `tropical/<name>/trunk\|coconuts\|fronds.png`) and their animations; previews in `FlappyMonster_pruebas/arboles/` | yes (never overwrites without `--force`; animations only added) |
| `world/make_jungle_sky.py [--apply]` | the JUNGLE sky (`world/sky/jungle_far/mid/near/top`, depth `temple_far/mid/top/wall`, 4 frames APPENDED to `gradients.png`) and tiles (`world/tiles/mud`, `jungle_grass`, `jungle_blades`, `temple_brick`, `temple_moss`, `jungle_platform`); previews in `FlappyMonster_pruebas/selva/fondo/` | yes (never overwrites; re-running `make_sky.py` drops the 4 gradient frames: run this again after it) |
| `world/make_ice_spikes.py`, `make_cryo_sprites.py`, `make_cryo_parts.py`, `make_cryo_chain.py` | `traps/spikes/spike_ice.png`, `traps/cryo/` | spikes and chain yes (verified) |
| `world/make_food_sprites.py` | `items/food_<island>.png` (never the user's apple) | yes (verified) |
| `ui/make_sprites.py`, `make_story_icons.py` | `ui/touch/`, `ui/ping/`, `ui/icons/` | yes (verified) |
| `ui/make_menu_ui.py` | `ui/menus/title_logo.png` + `.json` (from `logo.png`, never written), `ui/menus/button.png` + `.json`, `ui/menus/panel.png`, `ui/menus/box.png`, `ui/menus/cursor.png`, `ui/menus/cartridge.png` + `.json`, `ui/menus/cart_labels.png` | yes |
| `fx/make_lights.py` | `fx/light_disc.png`, `fx/light_rings.png`, `fx/light_halo.png` (the lights of the darkness canvas, `src/fx/Darkness.lua`) | yes |
| `fx/make_fades.py` | `fx/fade_edge.png` (the stepped fade mask of the credits' live stages, `src/story/LiveStage.lua`) | yes |
| `ui/make_mtvemo_logo.py [--apply]` | without flags: the logo proposals A-D as GIFs in `FlappyMonster_pruebas/logo_mtvemo/`; `--apply`: `assets/startup/logo_anim.png` + `.json`, `sky.png`, `stars.png` (design D, the boot intro) | yes |
| `enemies/make_claudio_extras.py [parpadeo] [baile]` | `enemies/claudio/claudio_blink.png`, `claudio_dance-Sheet.png` (from the user's `claudio_idle.png`; only the eyes / the arms change) | yes |
| `ui/make_player_redesign.py`, `make_flappy_redesign.py` | `player/`, the Mirror's pieces, `flappy/` | not re-run |
| `story/make_overworld.py` | `assets/story/overworld.json` + `story/` map sprites | deterministic; not re-run |
| `story/make_mirror_shards.py --apply`, `make_story_fx.py` | `story/mirror/`, `story/fx/` | yes (verified) |

"Verified" = executed on 2026-10-07 after the reorganisation and the output was pixel-identical to the committed
files. "Not re-run" = paths were updated mechanically and the script compiles, but it was not executed: review the
diff of whatever it writes.

## sounds/

One script per family, each writes WAVs into `assets/sounds/<group>/`: `ambience.py`, `bomb.py`, `cryo.py`,
`gloomy.py`, `groove.py` (the Groove Crab's crowd: cheer, boo), `hopper.py`, `ice.py`, `items.py`, `jungle.py` (the jungle ambience + the brazier fire; without `--apply` it writes previews and a 40 s level mix to `FlappyMonster_pruebas/selva/sonidos/`), `water.py` (drowning music, alarm, gasp, glug, extra life), `startup.py` (the logo melody), `mechanics.py`, `megacrabby.py`, `megagummy.py`, `mirror.py`,
`snowboss.py`, `story.py`, `ui.py` (entering a level, the start countdown). After generating: register the sound and its gain in `src/audio/Sound.lua`, then
`tools/tests/run.sh sounds NAMES=…`.

## music/

See the generator table in `docs/audio/music-catalog.md`. `famicom.py` (engine), `tentacle_nes.py` and
`gloomy_nes.py` are imported by the others. After ANY track change: `python tools/music/levels.py`. Audit / A/B previews of a `worlds_nes.py` track: `revisar.py`, `previas_ab.py`.

## levelgen/

`lib.py`, `levels_*.py` (builders), `build.py --only <level>`, `retheme.py <levels>` (`retheme.py --bg <levels> [--out <dir>]`:
the background-plane structures per island, `retheme_bg.py`; generated content listed in `bg_gen/<level>.json`), `add_apples.py <levels>`,
`make_sets.py` (film sets), `make_credits_sets.py` (the live stages of the credits: `assets/story/sets/credits_*.json`), `arenas/` (test arenas and their `make_*.py`; `make_decoraciones.py` = the showcase of every decoration, from `docs/reference/decorations-and-modes.md`).
