# Art generators and the hand-edited list

Art is produced by Python scripts (PIL) in `tools/art/<group>/` whose output PNGs are committed. Run them from the
repo root: `python3 tools/art/<group>/<script>.py [--apply]`. Without `--apply` most write a preview to
`FlappyMonster_pruebas/`. The table of every script is in `tools/README.md`.

## HAND-EDITED by the user — never regenerate these

Running the generator again would overwrite the user's work. If one of them must change, port the user's edits into
the generator first, or edit the PNG directly.

| Files | Generator that must NOT be re-run over them |
|---|---|
| `assets/images/enemies/gummy_fortress/*.png` | `tools/art/enemies/make_variant_skins.py` |
| `assets/images/enemies/crabby_lava/` crab1, crab2, crab3 (legs) | `tools/art/enemies/make_crab_species.py` |
| `assets/images/enemies/crabby_ice/` crab1-3, hide-Sheet, meat, sink1-5 | `tools/art/enemies/make_icecrabby_sprites.py` |
| `assets/images/bosses/megacrabby_ice/` crab1, crab2, crab3 | `tools/art/bosses/make_icecrab_sprites.py` |
| `assets/images/bosses/megacrabby/claw_left-Sheet.png` (the user's drawing) | `tools/art/enemies/make_enemy_extras.py`, `make_crab_redesign.py` |
| `assets/images/bosses/megagloomy/` body-Sheet, glow-Sheet, claw_left-Sheet, claw_rage_left-Sheet | `tools/art/enemies/make_gloomy_sprites.py` |
| `assets/images/items/apple.png`, `checkpoint_on.png`, `checkpoint_off.png` | `tools/art/world/make_world_art.py` (checkpoints) |
| `assets/images/bosses/snowboss/verity/` roll_happy, roll_angry, flee, ball | (the user's; `make_verity_body.py` only derives `body-Sheet.png` from them) |
| `assets/images/enemies/bomb/bomb-Sheet.png`, `bombObject-Sheet.png` | (the user's, retouched once by `retouch_bomb.py`) |

Safe to re-run (verified on 2026-10-07 to reproduce the committed pixels exactly): `make_hopper_sprites`,
`make_food_sprites`, `make_sky`, `make_story_fx`, `make_story_icons`, `make_terrain`, `make_mirror_shards`,
`make_ice_spikes`, `make_cryo_chain`, `make_sprites`. The others were moved and had their paths updated but were
NOT executed after the 2026-10-07 reorganisation (their outputs are hand-edited or they need the originals): check
the diff before committing anything they write.

## Notes on specific generators

- Character restyles keep EVERY pixel of the user's original shape and only add the new style (dark navy outline, highlight top-left, soft shade bottom-right): `tools/art/enemies/make_crab_redesign.py --apply` (Crabbies, Mega Crabby body + claws, trampolines, and ALL spikes: one pixel-art steel spike scaled to each original canvas — crabby/Mega 38x38, tiles/falling 32x32, Nave Malvada 26x27 down, icon 8x8); `tools/art/ui/make_player_redesign.py --apply --mix` (the monster + Mirror pieces + life icon: almost-black body with a lighter volume edge on thick parts, shaded white face — the user's mix of A and D); `tools/art/ui/make_flappy_redesign.py --apply` (Flappy pipe + Background.png: same shapes, bevel/volume); `tools/art/enemies/make_gummy_redesign.py --apply` (Gummies, helmet, dead.png; the WINGS are a new design: curved leading edge + fan of 3 long feathers, 2 flap frames, still 9x13). Both read the originals kept outside the repo, so they can be re-run safely.

- Small enemy sprites drawn by hand as character maps: `tools/art/enemies/make_enemy_extras.py --apply` (preview in FlappyMonster_pruebas/extras/): CRUSHED Crabby `crabby/dead.png` and crushed Icy Crabby `crabby_ice/dead.png` (each Crabby skin loads its own `dead.png`; they used to share gummy/dead.png, fine while everything was white), the guard's parachute, the Icy Mega's icicle field (the Mega Crabby's CLAWS are NOT generated any more: after two proposals from this script — a raised hermit-crab pincer and a fat shore-crab one — the USER drew them: `bosses/megacrabby/ claw_left-Sheet.png`, 2 frames 10x7 like the Icy Mega's, no bristles; never overwrite it). Drawn at `CLAW_K` 0.7 (at the body scale, 1.0, the user found them enormous), `CLAW_X` 4.8, `CLAW_Y` −1.4, `CLAW_IN` 1.5) with the Mega's shared claw animation (`pose2d`); art only, not hitboxes.

- **HAND-EDITED by the user (3.66.1): the icy crab bodies** — `bosses/megacrabby_ice/crab1-3.png` and `crabby_ice/`
  crab1-3, hide-Sheet, meat, sink1-5 (same sizes). Do NOT re-run `tools/art/bosses/make_icecrab_sprites.py` / `tools/art/enemies/make_icecrabby_sprites.py`
  over them unless asked (port the edits into the generators first).
