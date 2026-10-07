# Art: style and hard rules

- **Every image and sound the game uses is a real asset file** (`assets/images/…`, `assets/sounds/…`), never drawn or
  synthesised only in code, so the user can edit or replace it. Generators are fine as long as their output is
  committed and loaded by the game; code only places and animates.
- **Pixel art, 8/16-bit.** Integer positions (`math.floor`; the level states round the CAMERA to whole pixels), hard
  rectangles, black drop shadows offset 2-4 px, no rounded or smooth UI in game. Art is drawn at 1× and scaled by an
  integer (player ×6, small enemies ×4, Megas ×9-10, decorations ×4).
- **House style:** dark outline (the darkest tone of the object's OWN colour, never pure black), highlight
  top-left, soft shade bottom-right, 3-4 tones, no noise, 1-px transparent margin so nothing looks cut.
- **A redesign keeps every pixel of the user's original shape** and only adds the style.
- **Originals live OUTSIDE the repo:** `/home/mtvemo/FlappyMonster_originals/<same path>-orig.png` (or
  `$FM_ORIGINALS`; helper `tools/art/lib/originals.py`). The user's `.aseprite` sources live there too. `*-orig.png`
  and `*.aseprite` are gitignored: never commit backups. The folder mirrors `assets/images/` (moved together on
  2026-10-07; log in `MUDANZA_2026-10-07.txt` there).
- **Previews for the user** go to `/home/mtvemo/FlappyMonster_pruebas/<thing>/vista_previa.png` (outside the repo).
  Show options before applying; generators take `--apply`.
- **Never overwrite a sprite the user hand-edited** — the list is in [generators](generators.md).
- **The monster has NO wings.** (Flying enemies do: `assets/images/enemies/wings/`.)
- A "Mega" boss keeps the small sprite's pixel grid drawn at a bigger scale; only 1-px edits.
- No text baked into images: menu text is drawn with `src/ui/PixelFont.lua`.
