# Accessibility options (2026-11-13)

**Status:** built (0.5.208), approved in conversation. Item 7 of the [UX round](ux-round-2026-11.md), second half (the
first half was the [touch-control editor](touch-editor.md)).

## What

A new settings tab, **AYUDAS / ASSIST** (Settings: AUDIO · CONTROLS · GAME · ASSIST · OTHER; the long word
"ACCESSIBILITY" shrank too much in the tab — my call), with four options, all defaulting to the game as it was:

| Option | Key (`src/core/Settings.lua`) | What it does |
|---|---|---|
| SCREEN SHAKE (on) | `shake` | Off: `Particles.shakeOffset` returns 0 — no screen shake from hits, explosions or bosses (one place for all ~96 shake triggers) |
| FLASHES (on) | `flashes` | Off: nothing blinks fast — the bosses' 12 Hz red blink is steady red, their invulnerability blink and the player's are a steady half-transparency — and full-screen flashes (the Big Snowball's hit) are a third as strong. `src/fx/Flash.lua` (`on`, `blink(hz, t)`, `alpha(a)`) |
| SIGN TEXT (normal) | `signText` = `'normal'` / `'large'` | Large: the help / tutorial signs (`src/ui/HintBubble.lua`, `HintBubble.font()`) use the medium font |
| COLOUR-BLIND SYMBOLS (off) | `cbSymbols` | On: the ON / OFF blocks and switches — told apart only by colour (blue / red) — get a ring (ON) or an X (OFF) drawn on top. Generic: a tile type with `cbSymbol = 'on' | 'off'` gets it (`TileTypes.drawTile`); art from `tools/art/ui/make_cb_symbols.py` (`assets/images/world/tiles/cb_on.png`, `cb_off.png`) |

## How to extend

- Something new that blinks fast or flashes the screen: use `Flash.blink` / `Flash.alpha`.
- Something told apart only by colour: give its tile `cbSymbol` (or draw its own symbol behind `Settings.cbSymbols`).

## Tests

`mechanics` `accesibilidad` (shake on / off, blink vs steady, flash alpha, the player's blink, the sign font, every ON/OFF
tile has its symbol and the images load); `menu_flow` `cfg_datos` / `cfg_pestanas` (five tabs, every option with its texts);
`hud_layout` `simbolos` (capture of the symbols on the six ON/OFF tiles).

## Left for later

Not judged by a person yet: whether a third of a flash is soft enough, and whether more things need symbols (the user
can name them).
