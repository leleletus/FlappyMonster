> **Archived design document.** Status: BUILT (0.5.111), see [story-mode](../../story/story-mode.md#the-secrets-secret-exits-splinters-the-groove-and-the-mashup).
> Copied unchanged on 2026-10-31 from `FlappyMonster_pruebas/secretos/diseno.md`. It records what was proposed and decided at the time: the system pages win where they differ, and paths or ids below may be out of date.

# Secrets, collection and map cannons (user's decisions, 2026-10-29)

## User's decisions
- **Map travel:** two-way CANNONS replace the bridges between islands. The monster gets into the cannon, the cannon aims and fires, and the monster flies across the sea in an arc and lands on the other island's first node. Each crossing has a cannon at both ends: one goes forward, the other brings you back. The user: "se vería mejor y quedaría más cómico".
- **Secret bosses: lore of the SPLINTERS.**
  - When the mirror broke, tiny SPLINTERS flew off as well as the 8 shards. Crabs that found one became the "Mega" crabs, hidden in secret lairs.
  - Each secret boss guards its splinter, and the splinter is its collectible.
  - The GROOVE CRAB's disco ball is made of mirror splinters. With every splinter, after the Mirror is beaten, the splinters assemble and point the way to its island.
- **Secret exits:** a hidden exit in a level of the boss's island leads to its lair:
  - `arrecife_globo` (Coast) → `guarida_cangrejo_rey` (Mega Crabby);
  - `templo_del_eco` (Caves) → `gruta_lugubre` (Mega Gloomy Crabby).

  On the world map the secret node is red, with a keyhole. Its dotted path is DRAWN the first time the secret exit is used; before that it is invisible.
- **The Groove (`isla_del_groove`):** reachable after beating the Mirror AND owning every splinter. Today it only needs the Mirror.
- **The Crab Mega Mashup (`mashup_cangrejos`) is the TRUE FINAL:**
  - The four crabs you beat (Mega Crabby / Tantrum, Icy Mega Crabby, Mega Gloomy, the Groove) gang up for revenge.
  - It is a node on the Groove's island and opens once the Groove is beaten.
  - Its collectible is the finished DISCO BALL, followed by a short epilogue.
- **COLLECTION (inventory):**
  - A screen reached from the world map's menu. It shows one card per collectible: icon, name, what it is, and how it was obtained ("Venciste al Mega Crabby en su guarida, por la salida secreta del Arrecife Globo").
  - Collectibles not yet found show as "???" with a hint.
  - Data-driven, so future secrets are one entry.

## Shared data format (all agents use it)

`assets/story/collectibles.json`:

```json
{ "collectibles": [
  { "id": "astilla_crabby",  "icon": "assets/images/story/collectibles/astilla_crabby.png",
    "source": { "boss": "megacrabby", "level": "guarida_cangrejo_rey", "from": "arrecife_globo" },
    "keys": "story.collect.astilla_crabby", "kind": "splinter" },
  { "id": "astilla_gloomy",  "icon": "...", "source": { "boss": "megagloomy", "level": "gruta_lugubre", "from": "templo_del_eco" },
    "keys": "story.collect.astilla_gloomy", "kind": "splinter" },
  { "id": "bola_disco",      "icon": "...", "source": { "level": "mashup_cangrejos" },
    "keys": "story.collect.bola_disco", "kind": "trophy" }
] }
```

- **Language keys:** each entry's `keys` prefix + `.name`, `.desc`, `.how` and `.hint`, in both `assets/lang/es.lua` and `en.lua`.
- **Save:** `data.collect[id] = true`. Like shards, it is saved only when the level is finished (golden rule 7), and it is migrated for old saves.
- **"Every splinter":** the entries with `kind = "splinter"`. The Groove gate counts those, so a future splinter needs no code change.

## Who does what
1. **Cannons agent:** map travel and art.
   - Owns: the bridge/connect drawing and travel in `StoryMapState`, and the CONNECT/bridge part of `tools/art/story/make_overworld.py`.
   - Also the cannon art and sounds, and the `story_flow` checks for travel.
2. **Secrets agent:** story logic.
   - Owns:
     - the secret exits in the two levels (minimal JSON edits);
     - the secret map nodes and paths (`Worlds` data + the generator's secret section + their drawing);
     - save, drops, the Groove gate and the Mashup node;
     - `collectibles.json` and the collectible-drop mechanism (generic, alongside the shards' `Drops`);
     - docs, the `story_flow` cases and protocol notes.
3. **Collection agent:** the Collection screen UI and art.
   - The splinter and disco-ball icons and in-level sprites (simple, original).
   - The screen, its entry in the map menu, language keys, and a capture harness.
   - Reads `collectibles.json` and `data.collect`.

## How each secret crab carries its splinter (user, 2026-10-29)
Each crab wears its splinter mounted and decorated, and the collectible is that piece:
- **Mega Crabby:** a SHELL CROWN. The splinter is set like a jewel in a small crown of shells and coral on its head. Collectible `astilla_crabby` = the crown with the splinter.
- **Mega Gloomy Crabby:** an AMULET. The splinter hangs from its neck and catches the light. Collectible `astilla_gloomy` = the amulet.
- **The Groove:** its DISCO BALL made of splinters. Collectible `bola_disco`, earned in the Mashup (the true final).

The decorations are drawn as an EXTRA LAYER on the boss. Never edit the bosses' hand-edited sprites (the Mega Crabby's claws are the user's). When the boss falls, the piece it drops is that same item.
