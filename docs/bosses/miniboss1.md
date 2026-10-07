# Evil Ship (Nave Malvada) — `miniboss1`

The Fortress boss: a ship piloted by the Evil Monster that patrols waypoints and slams down with spikes.
**File:** `src/world/entities/types/bosses/miniboss1.lua`. **Art:** `assets/images/bosses/miniboss1/`.
**Level:** `fortaleza_malvada` (with a boss-controlled flood); test arena `tools/levelgen/arenas/MiniBossArena.json`.
**Music:** `evil_ship_boss`. **Harnesses:** `boss_sim`, `boss_intro`, `online_boss LEVEL=tools/tests/online_boss/fortaleza_flood.json`.

## Behaviour

- **MiniBoss1** (`types/bosses/miniboss1.lua`, "Nave Malvada"): ship + Evil Monster as
  two independent visuals (ship flips every 1 s; monster cycles Idle/Idle1/
  Idle2, hurt face on hit). States dormant (hidden, not solid) → intro (drops
  in from above the zone view, `miniAppear`) → patrol (waypoints: `points`
  prop, flown in straight 2D lines — they set the height too, minus `lift`)
  → prep (spikes out) → slam (falls until any tile, never below the
  zone floor line `zone.y1`) → stuck (only vulnerable here + first 0.6 s of
  rise) → rise (back to the height it dived from). Breaks `breakTiles` blocks per slam (default 1). Death:
  dying_hold → dying_eject (monster thrown out in an arc, dead anim + X eyes)
  → dying_boom (ship big explosion + screen shake) → dead. Pixel scale 5;
  flies `lift` px (default 32) above its placement cell; 1 full-size spike per
  broken block + 1. The hurt face has no eyes: X eyes are drawn on it (hit +
  death hold) and on the thrown dead sprites, at positions measured per sprite.
