# Damage sources (2026-11-13)

**Status:** proposed, waiting for the user's approval.

## Why

The death message (`src/ui/DeathBanner.lua`) says what killed you, but `src/player/DeathCause.lua` GUESSES it at the
moment of death from what is near (spikes, lava, the nearest enemy…). The user wants it certain and precise ("worth
it"): a spike tile vs a falling spike vs a Crabby's spike vs a pufferfish's spike vs a pufferfish's projectile, lava, a
boss's attack, explosions, crushing… The user chose the detailed form: **the thing AND the part** ("Pufferfish spike"
vs "Pufferfish projectile"), not just the thing.

## What gets built

**A source travels with every hit.** A source is a small table `{ what = id, part = id | nil }`:

- `what` = what did it: an entity type (`pufferfish`, `spikefall`, `crabby_ice`, a boss type…), a tile (`spikes`,
  `lava`…), or an environment cause (`fall`, `drown`, `time`, `crush`, `explosion`).
- `part` = which part of it: `body` (touching the enemy itself), `spike`, `projectile`, `fire`, `bite`, `claw`, `shock`…
  (nil for tiles and environment).

**Where it comes from (base first, golden rule 2):**

- `PlayerAdventure:hurt(n, src)`, `die(drown, force, src)`, `hazardHit(src)` take the source and keep it as
  `pa.lastHit` when the hit actually lands (life lost or death; a shield or invulnerability keeps the old one).
- The shared contact rule (`Interactions.run`) fills it **automatically**: touching an enemy's body → `{ what = its
  type, part = 'body' }`; one of its hazard boxes → `{ what = its type, part = hb.part or 'hazard' }`. Each entity names
  its boxes once: a hazard box gets a `part` field (the Crabby's spike, the pufferfish's spines, the mortar's fire…);
  data-enemy shots are `projectile`. About 15 entity files.
- Tiles (`PlayerCollision`: spikes, lava, `contact` materials) pass `{ what = tile name }`.
- The ~35 direct calls (bosses' attacks, explosions, the hard launch, the boss glass, beetles, scorpions, auto-scroll
  crush, falling out, drowning, the 10-minute limit…) pass their source: an attack gets its own part name (the Mirror's
  dash, the Mega Crabby's claws…).
- A call that passes nothing still works: `DeathCause` keeps its old guess as the fallback, so nothing breaks while a
  case is missing.

**The message:** `DeathCause` reads `pa.lastHit` first. The text is built from translation keys, never hardcoded:
the thing's name (`enemy.<family>` / the boss's name / `src.<tile>` / `death.<cause>`), the part (`part.<part>`), and a
template per language (`death.part`: es "{part} de {name}", en "{name} {part}"). `body` and tiles show just the name.

**Online:** the server applies the hit, so the source must reach the client. The own state (`Protocol.packOwnState`)
gets one more field: the last hit's source as a small number from a registry built the same way on both sides
(sorted entity type names, tile names, part names, causes). `Protocol.VERSION` + 1. The client's death message reads
it like single player.

## Not changing

- How much damage anything does, who it hurts, invulnerability, shields. Only the label travels.
- Nothing is saved.

## Tests

- `mechanics` `fuente_dano`: each case dies or gets hurt on purpose and checks `pa.lastHit` and the message text: a
  spike tile, a falling spike, a Crabby's spike, a pufferfish's spike vs its projectile, lava, an explosion, a boss
  attack, crushed by the auto-scroll, a fall, drowning, out of time; a shield keeps the previous source.
- A check that every entity hazard box has a `part` and every `part` / `what` has its translation in every language.
- `Protocol` round trip of the source in the own state; `online_smoke`: the client's player shows the server's source.

## Left to the builder

The exact part names per entity and attack; wording of each translation (the user edits the CSV too).
