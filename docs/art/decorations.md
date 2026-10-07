# Decorations

Render-only scenery (plants, rocks, torches, crystals…): the level JSON key `foliage`. A type is a file in
`src/world/decorations/types/` (it may return a LIST: the themed sets) registered in
`src/world/decorations/Decorations.lua`; shared drawing / animation / particle helpers in
`src/world/decorations/DecoFx.lua`. Sprites in `assets/images/world/decorations/<theme>/` from
`tools/art/world/make_decorations.py` and `make_biome_art.py`. Every type: [reference/decorations-and-modes](../reference/decorations-and-modes.md).
Decorations must stand on THEIR material (no plants on rock): `retheme.py --decor` audits it.

## Details

Render-only (client + editor; the server builds them but never draws). `placement` = 'sub'
(sprite 8 art px wide = 32 px, anchored bottom-centre of the quarter) or 'cell' (16 px wide
= 64, bottom-centre of the cell; taller ones grow upward); hanging ones draw from the TOP of
their cell/quarter (`DecoFx.sheet(..., {hang=true})`). A type file may return a LIST: themed
sets `ice_set` (Hielo y nieve), `cave_set` (Cueva), `water_set` (Acuático), `tropical_set`
(Tropical) + `icicle`, `palmtree` (Tropical), `tulip`/`stretch` (Plantas); palette order
`DecorationTypes.CATEGORIES`. `src/world/decorations/DecoFx.lua` = shared helpers: sprite
strips at ×4, `wave` (row-by-row sine sway, root still), additive `glow`, per-decoration
particles in `d.fx` (`emit/update/draw`, spawned only while seen, `every` timers), `drip`
(forms, falls, splashes on `d.level:landingCross`); bubbles pop out of water. Sprites:
`assets/images/world/decorations/<theme>/` + `fx/` from `tools/art/world/make_decorations.py` (simple
style: 1-px dark outline + 3 tones, no noise; never overwrites; `--force [names]`). Every
sprite gets a 1-px transparent margin (sides + top, or bottom if it hangs) with its outline
closed there, and `edge_check` warns if fill touches the canvas edge (it looked CUT in
game); `DecoFx.strip(path)` without a frame width = the whole image. It also
REDESIGNED the old foliage (tulip, stretch, palmtree parts) in that style from the user's
originals (kept outside the repo); the icicle now uses `decorations/ice/icicle.png` (the user's
original `icespike.png` is kept outside the repo). Showcase arena `tools/levelgen/arenas/decoraciones.json`
(`run.sh editor_open PLAY=...`).
