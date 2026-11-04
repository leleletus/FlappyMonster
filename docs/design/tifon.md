# Tifón: visual designs and sounds (chosen 2026-11-04)

Looks to choose from for the fortress's secret boss, the Supreme Gust «Tifón» (moves and lair:
[secret-bosses-plan § 4](secret-bosses-plan.md#4-supreme-gust-tifón--fortress-new)). The user (2026-11-04): start with
Tifón (before the Mother Mole), first the visuals and the sounds; its boss theme is composed meanwhile by a
clean-context agent (`tools/music/tifon.py`, three variants in `FlappyMonster_pruebas/musica/tifon/`, see [music-history](../audio/music-history.md)). Nothing is built
or written to `assets/` yet.

- Generator: `tools/art/bosses/make_tifon.py` (previews only; `--still` skips the GIFs).
- Sounds: `tools/sounds/tifon.py` (previews; `--apply` writes the boss's own folder of boss sounds, not done yet).
- Previews: `FlappyMonster_pruebas/tifon/`: `vista_previa.png` (the same art at ×10, ×8 and ×6 on the roofs, eight
  poses each, with the player ×6), `piezas.png` (the 17 body frames ×8), `comunes.png` (vane, Collection icon,
  effects), `pelea_x10.gif` / `pelea_x6.gif` and their `_con_sonido.mp4`, `sonidos/*.wav`. Round 1 is in `ronda1/`.
- Test scene (placeholder, not a design): a stormy gradient, the fortress `far` / `mid` sky layers darkened, `stone`
  roof, two stone chimneys, the real player, bomb, explosion and stun stars.

## Chosen (2026-11-04): ×6, music B — the package in `assets/`

The user: **scale ×6** (the player's pixel) and **music B «vendaval»**. Written with `make_tifon.py --apply`,
`tools/sounds/tifon.py --apply` and `INSTALL=1 TIFON=B tools/music/tifon.py`. Nothing uses it yet: the fight, the lair
and the secret exit are the next step. **Do NOT add `astilla_tifon` to `assets/story/collectibles.json` before the
boss is playable** (the Groove's gate counts every splinter).

- `assets/anim/bosses/tifon.json` (×6, origin [0.5, 0.5] = art (23, 22), facing LEFT): `idle` (2 frames), `warn`,
  `blow` (2), `inhale` (2, does not loop), `gulp`, `boom`, `cough`, `charge`, `spin` (4: front, side, back, side),
  `stun` (2). Frame 46x44 in `assets/images/bosses/tifon/body-Sheet.png`.
- `assets/anim/bosses/tifon_vane.json` (×6, origin [0.5, 1] = the foot of the mast, 17x16): `left`, `right`, `edge`
  (end-on, mid-turn) and the same three `_empty` (no splinter: after the defeat). The mast stays at the centre, so
  flipping does not move it.
- `assets/anim/bosses/tifon_fx.json` (×4, origin centre): `streak` (3), `streak_warn` (3), `mark` (3, no loop), `bolt`
  (16x40, tiles vertically), `arc` (chimney to chimney), `hail`, `hail_break`, `scorch`.
- `assets/images/story/collectibles/astilla_tifon.png` and `astilla_tifon_empty.png` (17x13).
- Sounds `tifon*` ([sound](../audio/sound.md)); music `tifon` ([music-history](../audio/music-history.md)).
- **Anchors** (art pixels from the top left of the body frame, facing left; flip x as `45 - x`): the vane's foot is
  (24, 12) in every frame except `blow1`, `blow2`, `cough` (24, 13), `gulp`, `boom` (24, 11) and `stun1-2` (24, 22).
  The face centre is (20, 20) (idle, blow, cough, spin), (20, 19) (warn, inhale, gulp, boom, charge), (20, 27) (stun);
  the mouth is 1 px left and 5 px below it (stun: 4 below). `make_tifon.py --apply` prints the table.

## Round 2: the chosen look at the game's pixel density

**The user's verdict on round 1:** "A with C's tail": C «Remolino»'s shape (a cloud head on a tornado tail) in A
«Nubarrón»'s soot colours, the head a little wider, like A's. **The sounds are fine.** But the sprite resolution
"doesn't quite convince": the game's sprites almost always share one pixel size, and round 1's ×5 had too much pixel
density, so it looked slightly out of place. Asked: keep the size with fewer, bigger pixels, or make it smaller, in
both cases keeping the design's intent.

Round 2 redraws the art at **half resolution** (one new pixel = 2x2 of round 1): body frame 46x44, the idle body 35x32
art pixels. The face, the mouths and the vane are drawn pixel by pixel (the geometric shapes did not read that small):
4x3 eyes with an L-shaped pupil in front and below, a 5-px angry brow, 1-px mouths. The tail is one tone lighter
than the head and has no highlight, only its spiral stripe. The warn cheeks were dropped (at this size they were
noise): the warning reads from the swelling, the shut eyes and the pursed mouth.

The same art at three scales (pick one):

| Scale | Idle on screen | |
|---|---|---|
| **×10** | 350x320 | option 1: the size of round 1, pixels twice as big (the Megas' ×9-10) |
| **×8** | 280x256 | in between |
| **×6** | 210x192 | option 2: smaller, the player's own pixel size |

The effects (wind streaks, marks, bolts, hail) stay ×4, like bombs and small things.

## Round 1: the four looks (history)

All are the fortress Gust grown huge: a heap of round puffs (the small Gust's language), each front puff leaving a
dark crease on the one behind, cream eyes with a thick angry brow, the mouth low and in front. Facing left (the game
flips). Scale ×5, frame 84x84 art, origin at the body centre. Sizes are the idle body at ×5 (player 54x96, tile 64).

| Look | Idea | Idle |
|---|---|---|
| **A «Nubarrón»** | The soot Gust grown: a wide, low cumulus with a flat base. The most faithful to the small one; reads as "the boss version" at once | 345x170 |
| **B «Yunque»** | A cumulonimbus: a dark slate-blue trunk with the face in its belly under a pale, flat anvil. The tallest; the anvil gives a clear top and reads as STORM, not cloud | 325x250 |
| **C «Remolino»** | A cloud head on a tornado tail that sways (and sweeps the roof). The phase 2 spin is natural to it | 270x300 |
| **D «Fuelle»** | One big violet storm ball with two huge cheeks, the "wind god" face. The most character, the least cloud | 240x205 |

**Recommendation at hand-off: A «Nubarrón».** It keeps the lore readable (the Gust the player already knows, grown),
its wide low shape leaves the air above the roofs free, and its mouth is a large, easy target for the bomb. **B** is
the runner-up: the most "storm", the anvil makes the vane stand out, but it is tall and takes the sky. **C** reads
best while spinning; its tail would need to be harmless or a hazard by design. **D** is the most expressive but looks
least like a cloud.

## Pieces (the same list for every look)

- **Body sheet, 17 frames:** `idle1`, `idle2`, `warn` (cheeks puffed, eyes shut, lips pursed: the blow tell),
  `blow1`, `blow2`, `inhale1`, `inhale2` (the mouth wide open with a swirl inside: the bomb target), `gulp` (mouth
  shut, eyes wide, the bomb glowing inside), `boom` (bigger, X eyes, the mouth on fire), `cough`, `charge` (lightning
  cracks inside, glowing eyes, chattering teeth), `spin1-4` (it turns on a vertical axis: front, side, back, side;
  the face only in `spin1`), `stun1`, `stun2` (sagged flat onto the roof, X eyes, wavy mouth).
- **The vane, a separate layer** so the game can turn it: arrow left, arrow right, end-on (`F`, mid-turn) and
  without the splinter. Brass mast with a short cross and balls, a fin that catches the wind, and the splinter as a
  6-px crystal arrowhead (the same glass colours as the other splinters). Its foot sinks into the cloud. **It turns
  with the wind:** the arrow shows where the next blow comes from, and in phase 2 it squeaks round before the swap.
- **Collection icon (17x13):** the vane's arrow with its fin and the crystal tip, and the empty version (dark tip).
- **Effects (×4):** wind streak (3 frames) and its warning (dashed, 3), lightning mark on the roof (3 stages), bolt
  (16x40, 2 frames, tiles vertically), chimney arc (32x12, 2), hailstone (2 falling + 2 shattering), scorch.

## Sounds (round 1, same for every look)

14 one-shots, loudest 100 ms at −12 dBFS (hail −15, chain −14): `roar` (wind howl over rolling thunder), `warn`
(takes air: a rising whistle, 1 s), `blow` (2.6 s low gale with gusts), `inhale` (2 s suction rising in pitch),
`gulp`, `boom` (muffled explosion inside + the cloud deflating), `cough`, `charge` (sparks getting closer over a
rising hum, 1 s), `thunder` (crack + rumble), `chain` (electric zap), `hail` (ice on a roof tile), `vane` (rusty
squeak, two pulls), `spin` (a whirl passing), `dizzy` (deflating whistle with a wobble). Saturated softly to reach
the level: `roar`, `charge`, `thunder` 1.8-2.6, `hail` 3.5 before its own target. **Nobody has listened to them.**

## Open questions

1. ~~Which scale~~: ×6 (2026-11-04).
2. Is the body solid (the player stands on it while stunned, as in the GIF) or only stompable from above?
3. The vane is 17x16 art pixels (half hidden in the cloud): big enough to show the piece?
4. Should the lightning come from the cloud (bolts start at its body) or from the sky over the marks (as drawn)?
5. Tifón's own colour against a dark stormy sky: A is grey on grey-blue; the roofs' real sky is not designed yet.

## Known weak points

- Not seen in the game: Python mock-ups with scripted motion; the wind barely moves the player in the GIF.
- The spin frames are 90° apart: 4 frames per turn may look choppy at speed.
- The `charge` crackle and `boom` glow are a few loose pixels; they may read as noise at ×5.
- The scene's roofs and chimneys are stand-ins (stone blocks), not the lair's tiles.

## History

- 2026-11-04: round 1, four looks + 14 sounds. The user: A's colours on C's shape with a wider head; sounds approved;
  too much pixel density at ×5.
- 2026-11-04: round 2, half resolution, shown at ×10 / ×8 / ×6. The user chose ×6 and music B «vendaval»; package
  written to `assets/`.
