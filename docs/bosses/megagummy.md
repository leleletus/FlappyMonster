# Gummy King (Rey Gummy) — `megagummy`

The Meadow boss and the cleanest file to copy from: the Gummy's sprite at scale 10 with a crown. Belly-flops with a
floor mark and jelly waves, calls its royal guard (reserve Gummies that enter from the floor, the sides, by parachute
or flying), and at the end SPLITS into medium Gummies.
**File:** `src/world/entities/types/bosses/megagummy.lua`. **Art:** `assets/images/bosses/megagummy/`
(`tools/art/enemies/make_gummy_variants.py --apply-mega`). **Sounds:** `tools/sounds/megagummy.py` (ids `king*`).
**Level:** `reino_gummy`; arena `tools/levelgen/arenas/jefe_gummy.json`. **Music:** `gummy_king_boss`.
**Harnesses:** `megagummy_rules`, `boss_sim` / `boss_intro` / `online_boss` / `boss_frames` with `LEVEL=` that arena.

## Behaviour

- **Rey Gummy** (`types/bosses/megagummy.lua`, "Rey Gummy", `boss.megagummy` = REY GUMMY / GUMMY KING): the Gummy's
  16x16 sprite at scale 10 (`MS`) with brows + a gold crown (crown = separate `crown.png` on the same grid, drawn
  over the body so it can fly off). Art `assets/images/bosses/megagummy/` from `tools/art/enemies/make_gummy_variants.py
  --apply-mega` (body-Sheet 8 frames: idle, walk1/2, jump (legs tucked), dazed, hurt, laugh, shout; wave, stars,
  target marker, shadow); sounds `bosses/megagummy/` from `tools/sounds/megagummy.py` (ids `king*`); particles
  king_splat / king_wave / king_sparkle / king_confetti(_big). Physics REUSED from the Snowball Boss
  (`Snow.move/physics/friction/jumpTo/target/zoneBounds/groundBelow/strike`). Chases in small hops (contact 1 HP +
  push, `GRACE`); solid sideways; on top = immune bounce. (1) BELLY-FLOP: 'flop_wind' (marker `landX/landY` follows
  the target, locked the last `FLOP_LOCK` s) → 'flop_air' (`jumpTo` + `passY`: lands on the marked surface, platforms
  included; drawn rotated 90° = belly down while falling) → crush 2 HP + squash, two jelly WAVES along the surface
  (34 px tall: jump them; 1 HP + push; die at walls / zone edge / no floor) → 'dazed' (stars; the ONLY vulnerable
  body state: stomp 1 / GP 2, one hit) → 'recover'. Phase 2 chains `FLOP_CHAIN` 2 ('flop_land' between). (2) ROYAL
  GUARD: phase 2 (`phase2` = fraction of the BODY hp) starts with 'phase_up' (fanfare) and then 'summon' every
  `guardEvery` s: reserve Gummies (`def.summons`: normal / helmet / flyer cycling, pool `guardPool`, max `guardMax`)
  enter from ANY valid place (the user found "always from the sides" too predictable), by kind (`guardSpot`):
  1 FLOOR (pops out of any standable cell, platforms too), 2 SIDE (next to a zone wall, floor or platform), 3 SKY
  (PARACHUTE from under the ceiling: Gummy state 'para', `Gummy:startParachute`, falls at `PARA_SPEED` onto the first
  surface under its WHOLE box, still a normal Gummy on contact/stomp; `gummy/parachute.png`), 4 AIR (flyers, upper
  half; then FREE FLIGHT over the zone, `e.flyArea`). Walkers rotate floor → sky → side. Every entry is chosen when the
  call STARTS and MARKED until the guard is out (the parachutist's until it lands): `self.marks` {x,y,kind} in
  netPackExtra, drawn with the target sprite; a spot is valid only ≥ `GUARD_FAR` 2.5 tiles from every player, clear of
  the boss, other marks and live guards (`spotFree`); fallback = a side. Bounded to the zone; they vanish when it dies.
  It does NOT laugh when a player dies (only in its intro; that is the Mirror's thing). (3) SPLIT: hp = body + `splitCount` ×
  `partHp`; the hit that reaches that budget is CLAMPED (`MG:damage`) and starts 'split' (crown flies to `crownX/Y`)
  → 'parts': medium Gummies (scale 6, `Part` objects with the Snow physics) that hop at players; contact 1 HP; stomp 1 /
  GP 2 per part (`interact` notes `_hitPart`, side-effect-free otherwise); hp bar = sum of parts. Last part →
  'dying_pop' (big confetti, the crown hops and fades; `releasesZone`) → dead. netPackExtra: phase, landX/Y, splitX/Y,
  crownX/Y, waves {id,x,y,dir,t}, parts {x,y,hp,inv,st,facing}, marks {x,y,kind}. Arena `tools/levelgen/arenas/jefe_gummy.json` (from
  `make_jefe_gummy.py`: flat throne hall, side platforms row 10 + middle row 7, music `boss_nes`); real level
  **reino_gummy** "Reino Gummy" / "Gummy Kingdom" (`levels_boss.py`, meadow theme; every Gummy kind on the way).
  Harnesses: `megagummy_rules` (every rule), `boss_sim` / `boss_intro` / `online_boss` / `boss_frames` with
  `LEVEL=tools/levelgen/arenas/jefe_gummy.json`. Protocol v41 (v42: guard entries + marks).
