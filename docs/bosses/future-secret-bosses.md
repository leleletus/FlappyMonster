# Future secret bosses: 4 ideas (not in the story yet)

Proposal of 2026-10-29; the user asked to keep them for later. None of this exists in the game yet. Secret bosses
already in the game: Mega Crabby, Mega Gloomy Crabby and the Groove ([system](system.md)). How a secret is wired:
[story-mode](../story/story-mode.md#the-secrets-secret-exits-splinters-the-groove-and-the-mashup). Lore:
[story](../story/story.md#the-secrets-the-splinters-the-groove-and-the-true-ending).

Together with the Mega Crabby (crown) and the Mega Gloomy (amulet), these make 6 splinters for the Groove's disco ball. The user wants at least 5 secret bosses: new ones, not necessarily crabs, none reused; the Mashup stays as it is. So at least 3 of these still have to be built.

Common to all:
- A lair behind a secret exit, with a red node on the map.
- The boss drops its piece (its splinter mounted in a worn object) and flees still big.
- It shrinks with the mirror's light in the ending.
- They are built from mechanics that already exist.

## 1. The Mother Mole — Meadow
- **Unlock:** in `pradera_explosiva`, a cracked wall that only a well-placed bomb opens, leading to a burrow going down (the secret exit).
- **Lair:** an arena of soft dirt with patches of hard rock.
- **Fight:**
  - She digs under the floor; the ground trembles where she is heading. She surfaces under you, raising dirt mounds that throw you and stones that fall.
  - **Weak spot:** a ground pound right over where she is moving brings her up dizzy. Or lure her into the hard rock so she bumps her head.
  - **Phase 2:** she opens sinkholes, and the arena gets smaller.
- **Piece:** a **miner's helmet**, the splinter as its lamp.

## 2. The Carnivorous Queen — Jungle
- **Unlock:** in `templo_de_los_pesos`, an underground fake wall behind the scale. You reach it by launching yourself with the scale's catapult loaded with two weights.
- **Lair:** a temple room overgrown with vines.
- **Fight:**
  - She is rooted in the middle. Mouths sprout from walls, floor and ceiling and try to swallow you, using the existing "mash buttons to get out".
  - She spits seeds that grow into small plants.
  - **Weak spot:** feed her thrown bombs. They explode inside her and stun her, and then you hit her flower.
  - **Phase 2:** the mouths move around, and bombs only reappear at the edges of the room.
- **Piece:** a **dewdrop flower**, the splinter as a drop of dew on a petal.

## 3. The Supreme Gust / Tifón — Fortress
- **Unlock:** in `taller_trampas`, a hidden chimney. A Gust's wind lifts you to the roof, where a secret exit sits among the chimneys.
- **Lair:** the fortress roofs, open sky, boxes and loose bombs.
- **Fight:**
  - A giant storm cloud that blows the whole arena (you, boxes, bombs, enemies), in sweeps with a warning.
  - **Weak spot:** use its own wind to fling boxes and bombs into it (the Push system). Or wait behind an obstacle until it tires.
  - **Phase 2:** it spins and changes direction mid-blow.
- **Piece:** a **weather vane**, the splinter as the arrow's tip.

## 4. The Three-Tailed Scorpion — Volcano
The user's idea (2026-10-31), replacing the Emperor Penguin. **Built as entities: [giantscorpion](giantscorpion.md). No level, music or
collectible entry yet.** The user chose design C «Obsidiana» (rejected: A «Basalto», B «Ascua», D «Ceniza»), with a
shorter body and the tails drawn OVER the body. Type ids: `scorpion`, `giantscorpion`.

Package (`tools/art/enemies/make_scorpion.py --apply`, `tools/sounds/scorpion.py --apply`; previews in
`FlappyMonster_pruebas/escorpion/final/`, with `jefe_C_con_sonido.mp4` showing the sounds in place):
- `assets/anim/enemies/scorpion.json` (×4), `assets/anim/bosses/giantscorpion.json` (×10; same grid + gold marks), origin at the feet:
  `idle`, `walk`, `windup`, `hurt`, `dead`.
- `assets/anim/enemies/scorpion_parts.json`, `assets/anim/bosses/giantscorpion_parts.json`, origin at the centre: `segment` (5 sizes,
  base to tip), `pincer_open`, `pincer_closed`, `stinger` (boss: `stinger1-3`) and `stinger_flash`. Directions: frame
  position = round(angle / 22.5°), 0 = right, clockwise on screen. Sequences here are lists of frames to pick from, not to play.
- `assets/anim/bosses/giantscorpion_fx.json`: `mark1-3`, `mark_heavy` (floor warnings), `crack`, `impact`.
- `assets/images/bosses/giantscorpion/wear_clasp.png` (the worn piece); `assets/images/story/collectibles/astilla_escorpion.png` and
  `astilla_escorpion_empty.png`. Do NOT add the entry to `assets/story/collectibles.json` before the boss exists: the
  Groove's gate asks for every splinter, so it would become impossible to open.
- Anchors in the body sheet (art pixels from the top left, facing right): tail base (4, 9), far shoulder (21, 14), near shoulder (24, 15).
  Preview chain: boss 19 segments, 3.4 art px apart; small 8, 3.2 apart.
- Sounds (names in `src/audio/Sound.lua`): `scorpionRattleJoin` / `scorpionRattleSplit` (3 wooden clicks 0.09 s apart in ONE
  file per gesture: three separate network sounds would lose the rhythm online), `scorpionClick` (one click, the small
  one), `scorpionSting`, `scorpionSnap`, `scorpionSkitter`, `scorpionStrike`, `scorpionPull`, `scorpionHiss`.
  **Timing rule (the user):** the rattle sounds exactly while the tails coil or uncoil: play it the frame the movement
  starts, make that movement last about 0.2 s (preview: `COIL_F`, `COIL_K`), one stinger flash per click at 0, 0.09 and
  0.18 s. Wood B «hueca» installed; A «seca», C «grave» with `--click`. Not listened to by anyone yet.
- History: first version rejected ("no me terminan de convencer"): 3 separate clicks 0.36 s apart, not tied to the movement.

- **Normal enemy (the lore rule):** a small one-tailed scorpion of the volcano; touching a splinter split its tail in three.
- **Unlock:** a secret exit in a volcano level (not chosen yet).
- **How it looks:** a low body on splayed legs; the tails are its biggest feature, so it does not read as one more crab
  (the user: too many crabs). At rest they fan out like a trident, each stinger glowing a different colour.
- **The tails are SEGMENTS animated live** (the user's idea): round discs placed along a spring chain, so they need no
  rotation, plus a stinger in 16 directions. The body is a normal sheet; the arms are segments and a pincer in 16 directions.
- **The rattle, its signature:** 3 quick clicks like a wooden matraca, exactly while the tails coil or uncoil; each click flashes one stinger.
  - **Joined:** 3 clicks as they braid into one thick tail, a short pause, one heavy strike at a marked spot. It sticks
    in the ground: the window to hit it.
  - **Split:** 3 clicks as they separate, then each strikes in the order of its click, at its own marked spot.
  - **Harder phases:** faster clicks and mixed patterns (2 + 1), but the clicks never lie.
- **Claws:** they really catch the player, using the existing "mash buttons to get out", with a clear warning while the
  tails get ready. (Mega Gloomy's claw only thrusts and hits.)
- **Piece:** a **clasp** at the base of the tails, the splinter set in it.

The Frozen Coast has no secret boss now. An earlier idea, the Emperor Penguin (rink with thin ice, belly-slides, ride a
chick as a sled and crash it into him), was dropped by the user on 2026-10-31.

The level files the user has hand-edited (`rio_revuelto`, `senda_del_dosel`, and any later ones) take minimal JSON edits only, never a rebuild.

## History

- 2026-10-31: moved here from `FlappyMonster_pruebas/secretos/bosses_secretos_futuros.md`, where nothing in the docs
  pointed to it: asked which bosses were saved for later, Claude answered without these four until the user asked
  about a carnivorous plant boss.
