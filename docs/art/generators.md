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
| `assets/images/bosses/groovecrab/` arrow.png, ko-Sheet.png (retouched by the user, 2026-10-26) | `tools/art/bosses/make_groove_crab.py` (skips them: `KEEP`) |
| `assets/images/enemies/pufferfish/puffer_fish-Sheet.png` (retouched by the user, 2026-10-26) | `tools/art/enemies/make_pufferfish.py` |
| `assets/images/enemies/beetle/beetle-Sheet.png`, `assets/images/bosses/giantbeetle/body-Sheet.png` (legs retouched by the user, 2026-10-28) | `tools/art/enemies/make_beetle.py` (`--apply` skips them: `KEEP`) |
| `assets/images/bosses/snowboss/verity/` roll_happy, roll_angry, flee, ball | (the user's; `make_verity_body.py` only derives `body-Sheet.png` from them) |
| `assets/images/enemies/bomb/bomb-Sheet.png`, `bombObject-Sheet.png` (redrawn by the user on 2026-10-08) | none writes them: `make_bomb_redesign.py` now only writes the explosion; `make_bomb_fuses.py` only READS them to build the rope sheets and the animations |
| `assets/images/enemies/claudio/` claudio1, claudio2, claudio_idle, claudio_idle2, claudio_idle3, squish (Claudio: the user's character for Claude, 2026-10-08; the user allows Claude to change them) | (the user's; `tools/art/enemies/make_claudio_extras.py` only derives `claudio_blink.png` and the credits' `claudio_dance-Sheet.png` from `claudio_idle.png`) |

Safe to re-run (verified on 2026-10-07 to reproduce the committed pixels exactly): `make_hopper_sprites`,
`make_food_sprites`, `make_sky`, `make_story_fx`, `make_story_icons`, `make_terrain`, `make_mirror_shards`,
`make_ice_spikes`, `make_cryo_chain`, `make_sprites`. The 0.5.68 props (none hand-edited yet; previews without
`--apply`): `tools/art/world/make_scale_box.py` (Box, small box, Scale), `tools/art/enemies/make_gust_sprites.py`
(Gust), `tools/art/world/make_seed_plants.py` (Seed), `tools/art/world/make_wind_geyser.py` (Blizzard, Geyser),
`tools/sounds/props.py` (their sounds), `tools/art/ui/make_prompts.py` (the "grab" tooltip; does not overwrite, `--force`). The others were moved and had their paths updated but were
NOT executed after the 2026-10-07 reorganisation (their outputs are hand-edited or they need the originals): check
the diff before committing anything they write.

## Notes on specific generators

- `tools/art/enemies/make_beetle.py`: the jungle's Rhino Beetle and the Giant Rhino Beetle (22x20 frames: 4-frame tripod walk, charge, on its back; the giant adds toss, wings, landing and the gold rune) + the giant's temple block, debris, floor wave and dust; design D chosen by the user (2026-10-28); without flags = previews, mockups and GIFs in `FlappyMonster_pruebas/escarabajo/`; `--apply` writes the attack sprites and both anim sets; it never rewrites the two body sheets the user retouched (`KEEP`).
- `tools/art/world/make_jungle_decor.py` and `tools/art/world/make_big_trees.py`: the jungle decorations (`jungle_set`)
  and the big trees + extras of every island (`fortress_set` and new names in the other sets), approved by the user
  on 2026-10-28 (the jungle set without the frog, the toucan and the monkey: drawn but `NOT_APPLIED`). Without flags =
  previews in `FlappyMonster_pruebas/selva/decoraciones/` and `FlappyMonster_pruebas/arboles/`; `--apply` writes only
  files that do not exist (`--force` to overwrite) and ADDS their animations to the sets (`add_anims` in
  `tools/anim/common.py`, never touching an existing one). Safe to re-run (nothing hand-edited yet).
  See [decorations](decorations.md).
- `tools/art/world/make_jungle_sky.py`: the JUNGLE island's sky (surface `jungle`, depth `temple`, their gradients appended to `gradients.png` as frames 11-14) and tiles (mud, jungle grass + blades, temple brick + moss, jungle platform — option A, planks tied with liana; option B, bamboo, only in the preview). The user removed the beetle statue from `temple_mid` (2026-10-28; `beetle_statue` kept, unused). `make_sky.py` writes 10 gradient frames: run this script with `--apply` again after it.
- `tools/art/enemies/make_jungle_skins.py`: the JUNGLE island (`jungla`, 0.5.83) variants of everything that changes by island — the tree-frog Gummy (`enemies/gummy_jungle/`), the Halloween-crab Crabby (`enemies/crabby_jungle/`), and `<jungla>-…` files for Hopper, Gust (+ the 7th row of `enemies/gust/wind-Sheet.png`), Box, Scale, Geyser, Blizzard wind, Seed and the food (`items/food_jungla.png`). It imports the island generators (`make_crab_species`, `make_hopper_sprites`, `make_gust_sprites`, `make_scale_box`, `make_seed_plants`, `make_wind_geyser`, `make_food_sprites`) and only adds the jungle palette. Proposal approved by the user (2026-10-28); without flags = previews in `FlappyMonster_pruebas/jungla/variantes/`; `--apply` writes only files that do not exist yet (`--force` to overwrite) and GROWS `wind-Sheet.png` keeping its first six rows untouched. Safe to re-run (nothing of it is hand-edited yet).
- `tools/art/bosses/make_groove_crab.py`: The Groove's OWN art (fiddler crab: body-Sheet 18x10 ×3 with the coast Crabby's legs read from `enemies/crabby/crab1-3.png`, bigclaw/claw sheets, trampoline cut from `mechanisms/trampoline/normal.png`, notes in 4 colours, sand wave reusing the Giant Hopper's wave shapes; 0.5.48: `ko-Sheet` knocked-out body, `glasses`, `deck-Sheet` DJ deck, `led-Sheet`, `arrow`); `--gif` = animated mockup in `FlappyMonster_pruebas/jefes/groove/maqueta.gif`. Approved by the user from that mockup (2026-10-26). Safe to re-run.
- `tools/art/fx/make_screen_crack.py`: the broken screen glass of the credits finale (`assets/images/fx/screen_crack.png`, 160x120, 1 px cracks with a shadow, fixed seed). Safe to re-run.

- Character restyles keep EVERY pixel of the user's original shape and only add the new style (dark navy outline, highlight top-left, soft shade bottom-right): `tools/art/enemies/make_crab_redesign.py --apply` (Crabbies, Mega Crabby body + claws, trampolines, and ALL spikes: one pixel-art steel spike scaled to each original canvas — crabby/Mega 38x38, tiles/falling 32x32, Nave Malvada 26x27 down, icon 8x8); `tools/art/ui/make_player_redesign.py --apply --mix` (the monster + Mirror pieces + life icon: almost-black body with a lighter volume edge on thick parts, shaded white face — the user's mix of A and D); `tools/art/ui/make_flappy_redesign.py --apply` (Flappy pipe + Background.png: same shapes, bevel/volume); `tools/art/enemies/make_gummy_redesign.py --apply` (Gummies, helmet, dead.png; the WINGS are a new design: curved leading edge + fan of 3 long feathers, 2 flap frames, still 9x13). Both read the originals kept outside the repo, so they can be re-run safely.

- Small enemy sprites drawn by hand as character maps: `tools/art/enemies/make_enemy_extras.py --apply` (preview in FlappyMonster_pruebas/extras/): CRUSHED Crabby `crabby/dead.png` and crushed Icy Crabby `crabby_ice/dead.png` (each Crabby skin loads its own `dead.png`; they used to share gummy/dead.png, fine while everything was white), the guard's parachute, the Icy Mega's icicle field (the Mega Crabby's CLAWS are NOT generated any more: after two proposals from this script — a raised hermit-crab pincer and a fat shore-crab one — the USER drew them: `bosses/megacrabby/ claw_left-Sheet.png`, 2 frames 10x7 like the Icy Mega's, no bristles; never overwrite it). Drawn at `CLAW_K` 0.7 (at the body scale, 1.0, the user found them enormous), `CLAW_X` 4.8, `CLAW_Y` −1.4, `CLAW_IN` 1.5) with the Mega's shared claw animation (`pose2d`); art only, not hitboxes.

- **HAND-EDITED by the user (3.66.1): the icy crab bodies** — `bosses/megacrabby_ice/crab1-3.png` and `crabby_ice/`
  crab1-3, hide-Sheet, meat, sink1-5 (same sizes). Do NOT re-run `tools/art/bosses/make_icecrab_sprites.py` / `tools/art/enemies/make_icecrabby_sprites.py`
  over them unless asked (port the edits into the generators first).
