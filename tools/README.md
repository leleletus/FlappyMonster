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
| `deploy_server.sh` | update the game server after a push (`--status` = look only) | `docs/architecture/updates-and-release.md` |

## Three traps

1. `python3 tools/levelgen/build.py` without `--only <level>` rewrites EVERY generated level (so does `--show`).
2. `python3 tools/levelgen/retheme.py` has no `--help`: any unknown flag runs it over every level. Pass level names.
3. Several art generators would overwrite sprites the user has since hand-edited. Check `docs/art/generators.md`.

## art/

`lib/originals.py` — where the originals of redesigned images live (outside the repo). Scripts add `tools/art/lib`
and their own folder to `sys.path`; scripts that import each other sit in the same folder.

| Script | Writes (under `assets/images/` unless noted) | Re-run? |
|---|---|---|
| `enemies/make_crab_redesign.py` | restyle of Crabbies, trampolines and ALL spikes from the originals | not re-run since the reorganisation |
| `enemies/make_gummy_redesign.py` | restyle of Gummies, helmet, wings | not re-run |
| `enemies/make_puffer_redesign.py` | `enemies/pufferfish/` | not re-run |
| `enemies/make_bomb_sprites.py`, `retouch_bomb.py` | `enemies/bomb/` fuse and explosion sheets; one-off retouch of the user's sheets | no (user's sheets) |
| `enemies/make_enemy_designs.py` | design PROPOSALS (previews) — and the pixel maps other scripts import | previews only |
| `enemies/make_variant_skins.py` | `enemies/gummy_magma/`, `gummy_cave/`, `gummy_fortress/`, `crabby_fortress/` | **NO: gummy_fortress is hand-edited** |
| `enemies/make_crab_species.py` | `enemies/crabby_river/`, `crabby_lava/`, `crabby_cave/` | **NO: lava legs are hand-edited** |
| `enemies/make_hopper_sprites.py --apply` | `enemies/hopper/<island>-Sheet.png` | yes (verified identical) |
| `enemies/make_icecrabby_sprites.py`, `make_icecrabby_claws.py` | `enemies/crabby_ice/` | **NO: bodies hand-edited** |
| `enemies/make_gummy_variants.py` | `enemies/gummy_ice/` (`--apply-helado`), `bosses/megagummy/` (`--apply-mega`) | not re-run |
| `enemies/make_gloomy_sprites.py` | `enemies/gloomy/`, `bosses/megagloomy/` | **NO: Mega Gloomy sheets hand-edited** |
| `enemies/make_enemy_extras.py` | crushed Crabby frames, the guard's parachute, the icicle field | not re-run (never the Mega's claws) |
| `bosses/make_icecrab_sprites.py` | `bosses/megacrabby_ice/` | **NO: bodies hand-edited** |
| `bosses/make_snowboss_sprites.py`, `make_snowboss_cracks.py` | `bosses/snowboss/` | not re-run |
| `bosses/make_verity_body.py --apply` | `bosses/snowboss/verity/body-Sheet.png` from the user's palette | when the user edits Verity's palette |
| `world/make_terrain.py`, `make_world_art.py`, `make_snow_sprites.py`, `make_biome_art.py` | `world/tiles/`, mortar, checkpoints, lava, volcano and meadow art | terrain yes (verified); **make_world_art NO for checkpoints (hand-edited)** |
| `world/make_sky.py` | `world/sky/` | yes (verified) |
| `world/make_decorations.py` | `world/decorations/` | not re-run (never overwrites without `--force`) |
| `world/make_ice_spikes.py`, `make_cryo_sprites.py`, `make_cryo_parts.py`, `make_cryo_chain.py` | `traps/spikes/spike_ice.png`, `traps/cryo/` | spikes and chain yes (verified) |
| `world/make_food_sprites.py` | `items/food_<island>.png` (never the user's apple) | yes (verified) |
| `ui/make_sprites.py`, `make_story_icons.py` | `ui/touch/`, `ui/ping/`, `ui/icons/` | yes (verified) |
| `ui/make_logo_parts.py` | `assets/startup/parts/`, `assets/startup/logo.json` (cuts the user's logo; never writes the logo itself) | yes |
| `enemies/make_claudio_extras.py` | `enemies/claudio/claudio_blink.png` (from the user's `claudio_idle.png`) | yes |
| `ui/make_player_redesign.py`, `make_flappy_redesign.py` | `player/`, the Mirror's pieces, `flappy/` | not re-run |
| `story/make_overworld.py` | `assets/story/overworld.json` + `story/` map sprites | deterministic; not re-run |
| `story/make_mirror_shards.py --apply`, `make_story_fx.py` | `story/mirror/`, `story/fx/` | yes (verified) |

"Verified" = executed on 2026-10-07 after the reorganisation and the output was pixel-identical to the committed
files. "Not re-run" = paths were updated mechanically and the script compiles, but it was not executed: review the
diff of whatever it writes.

## sounds/

One script per family, each writes WAVs into `assets/sounds/<group>/`: `ambience.py`, `bomb.py`, `cryo.py`,
`gloomy.py`, `hopper.py`, `ice.py`, `items.py`, `startup.py` (the logo melody), `mechanics.py`, `megacrabby.py`, `megagummy.py`, `mirror.py`,
`snowboss.py`, `story.py`. After generating: register the sound and its gain in `src/audio/Sound.lua`, then
`tools/tests/run.sh sounds NAMES=…`.

## music/

See the generator table in `docs/audio/music-catalog.md`. `famicom.py` (engine), `tentacle_nes.py` and
`gloomy_nes.py` are imported by the others. After ANY track change: `python tools/music/levels.py`.

## levelgen/

`lib.py`, `levels_*.py` (builders), `build.py --only <level>`, `retheme.py <levels>`, `add_apples.py <levels>`,
`make_sets.py` (film sets), `arenas/` (test arenas and their `make_*.py`).
