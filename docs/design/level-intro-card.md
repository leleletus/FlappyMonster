# Level intro card (2026-11-12)

**Status:** design approved in conversation, not built. Replaces the lower-third card of the UX round
([ux-round-2026-11](ux-round-2026-11.md) item 2, `LevelCard` (src/ui, removed in 0.5.202)).

## Why

The user: the card that appears during the countdown should instead come BEFORE it, as its own screen, "like the
classic platformer title cards": a black screen built from several real assets (not just text on a panel) that names
the island, the level and its number ("1 - 3"). The current card is a small panel in the lower third shown while the
countdown runs; it feels like an overlay, not an introduction.

## What it looks like (chosen from mockups: "B bands + A strip", number position 2)

Logical screen, any width (layout at draw time from `WINDOW_W/H`, never at load):

- **Black** background over the whole screen (the level is not drawn behind it).
- **Two bands slide in from opposite sides**, stepped (pixel steps, not smooth):
  - top band from the LEFT, wide (about 3/4 of the screen), carrying the **level name** in the big pixel font (wraps to
    two lines if long);
  - lower band from the RIGHT, narrower, carrying the **island name** (`story.world.<id>`).
  - Each band has a darker strip under it (a drop shadow in a darker shade of its colour).
- **Number plate:** a small white plate with the number ("1-3") **drops from above** into the empty space LEFT of the
  island band, so it reads "1-3 · ISLA PRADERA". Small (the user: smaller than in the first mockup, must not cover
  anything).
- **Island strip** along the bottom: a strip of that island's real ground tiles (top tile + the tile under it), one of
  the island's decorations and one of its enemies (idle animation), from real asset files.
- **The monster runs in** from the left along the strip and stops (run animation, then idle). It has a **white
  outline** so it reads on black (the user asked for it).
- Then the card clears and the normal start countdown runs over the level.

Mockups: `.superpowers/brainstorm/` (`level-card.html`, `level-card-v2.html`; not in git).

## Per island (data, not code)

Every island has its own **band palette** (the user: the colours must match the island) and its own strip: ground
tiles, one decoration, one enemy. These live as data next to the island in `src/story/Worlds.lua` (e.g. an
`intro = { bands = {…}, ground = …, deco = …, enemy = … }` per world) so a new island is one more entry. Free Play
levels and story levels use the entry of the island the level belongs to; a level of no island (custom, online-only
maps) uses a neutral default entry (builder picks).

Colours, which decoration and which enemy per island: builder's call within `docs/art/style-rules.md`, matching each
island's look (Pradera green / gold, Nieve icy blues, final island reds…).

## The number

| Level | Plate |
|---|---|
| Normal level, n-th of world w | `w-n` (e.g. `1-3`) |
| Boss | `w-` + the world-map **castle** icon (the user agreed to my recommendation; a number would read as one more level) |
| Bonus level of the world | `w-B` |
| Secret level (secret exit) | `w-?` — also for the secret BOSS levels (all 7 secret levels are boss fights; the user: the secret wins over the castle) |
| Unknown (no island, custom, editor test) **or a Free Play level with an island but no story position** | no plate at all; the bands and the strip still show (the user: "if the number is not known, it is not shown") |

`w` is the world's position in `Worlds.LIST`; `n` the position in `Worlds.nodes(w)`.

## When it shows

- Story mode and **Free Play** (the user), single player, every time a level starts (including after a game over
  restart: builder's call whether a RETRY from pause shows it again; my default: yes, it is the start of the level).
- **Online client**, every match start, with the same look.
- Not in: Flappy stages, the menu background demo, editor test plays (`fromEditor`), bonus mini-games that are not
  levels.
- **Duration ≈ 2 s. It can NOT be skipped** (the user).
- **No pause during the card NOR during the countdown** (the user). The pause input is ignored in both phases (single
  player; online has no pause). Losing window focus does not open the pause menu in those phases either (builder:
  check the focus-loss auto-pause path).
- **Music:** the level's music starts when the card appears (it already starts on entering the state; keep it that way,
  do not delay it to after the countdown).

## Timing — one shared start sequence (the user: "fix it for real", not a patch)

Today the start is `StartCountdown` (3 s frozen + 0.8 s "GO"), shared by single player, the server (`sim.startTicks`,
sent as `cd` in `game_init`) and the online client (remaining time from the snapshot clock).

New: the start becomes **card phase + countdown phase**, defined once in `src/world/systems/StartCountdown.lua` (no
graphics there), used identically by the three places:

- `CARD_TIME` (≈ 2 s): the card is shown; the world is frozen and not drawn.
- then the countdown exactly as today (3, 2, 1, GO; `TIME`, `GO_TIME`). The user will try it in the game and may
  later remove or shorten it: its length must be a single constant that can be set to 0 with nothing else changing.
- The server freezes for `CARD_TIME + TIME` (in ticks); the online client derives "card or countdown, and how far in"
  from the server clock, exactly as single player derives it from its own timer. No client-side timer for the card
  online (today's `cardT0` from `love.timer` goes away).
- **The server WAITS for late players, with a limit** (the user). The round does not start its card clock until every
  player in the room has finished loading the level (a new "loaded" message from the client) or a time limit passes
  (my call: 8 s after the first player is ready). The card IS the waiting screen (the user's idea): a client that is
  ready shows the card and keeps showing it until the server's start sequence begins. While it waits the card stays
  ALIVE, never frozen (the user): the monster keeps animating (idle, with a small hop or look-around now and then),
  the enemy keeps its idle animation, the bands keep a slow shimmer (builder's call). If the wait goes past the
  card's normal end by more than ~1 s, a **"Waiting for players..."** line with animated dots appears in the
  BOTTOM-LEFT corner (the user; new translation key, every language); it goes away when the start begins; the card then lasts at least `CARD_TIME` from that point. A player still loading when the limit passes
  joins late like today (sees whatever part of the card / countdown is left).
- Players who join or reconnect MID-match never see a card (my call: the match has started).
- This changes what the start means on the wire → `Protocol.VERSION` + 1 and `version.txt` bump (CLAUDE.md network
  rule). Old clients get the usual version mismatch.
- Countdown beeps start when the countdown phase starts, not during the card.

## Not changing

- What is saved. The card gives nothing and records nothing.
- Translation keys for island names (`story.world.<id>`) and level names (`L.localName`). Any new text (none expected
  beyond the existing ones) goes in `assets/lang/translations.csv`.

## Rules that apply

- Every image is a real asset file: the bands' look, the plate, the castle icon and the monster's white outline come
  from files (generator in `tools/art/ui/` for anything new, committed; the outline as a generated outlined copy of the
  monster's run frames, like `make_loading.py` made white ones). Never overwrite a hand-edited sprite.
- Pixel art, integer positions, stepped motion. No stencils; clip with `src/ui/Clip.lua`.
- Shared simulation code (`StartCountdown`) never touches graphics.

## Tests

- `story_flow` `tarjeta` rewritten: the card shows before the countdown, for `CARD_TIME`, cannot be skipped by any
  input, pause does nothing during the card and the countdown, the plate text is right for a normal level, a boss, a bonus, a secret and an unknown level; not shown in
  the demo / Flappy / editor test.
- Free Play: the card shows (new check).
- `mechanics` / start: the world does not move during card + countdown; the countdown beeps only in its phase.
- Online (`online_smoke` or the start harness): the server waits for every client's "loaded" (and starts anyway after
  the limit with a client that never sends it); then freezes `CARD_TIME + TIME`; the client draws the card from
  the server clock; prediction does not move the player during it.
- Captures of the card for 2-3 islands at 960 / 1280 / 1600 wide.

## Left to the builder

Exact colours per island, which decoration and enemy per island, band sizes and slide timing within ~2 s, fonts and
sizes (the number plate stays small), the default entry for islandless levels.

## Calls I made (not the user's; the user may overrule)

- The server's wait limit: 8 s after the first player is ready.
- Mid-match joiners and reconnects get no card.
- Online, the card's monster is the normal one (not tinted with the player's colour).
- RETRY from pause and restarting after a game over show the card again (it is the start of the level).
