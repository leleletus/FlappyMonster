# Flappy Monster

A pixel-art game made with [LÖVE](https://love2d.org) 11.x. Two games in one:

- **Flappy** — the original: tap to flap between pipes.
- **Adventure** — a platformer: a story mode across six islands with seven bosses ("El Espejo Roto"), a Free Play
  hub with every level, a built-in level editor, and an **online mode** (race, hunt, King of the Hill) backed by an
  authoritative server.

It runs on PC (Linux / Windows), Nintendo Switch (homebrew) and Android, and updates itself from the game server.

## Run it

Install LÖVE 11.4 or newer, then from the repo root:

```bash
love .                                    # the game
love . --editor [assets/levels/x.json]    # the level editor (F1 = shortcuts, F5 = play-test)
love server                               # the server with its monitor window (port 22122)
love server --headless                    # the server in a terminal
FM_SERVER=localhost love .                # play online against your local server
```

In game, **F1** shows hitboxes.

## Build

```bash
make lovefile     # the portable .love (exactly the tracked game files)
make win64        # Windows 64-bit executable
make switch       # Nintendo Switch homebrew (.nro; needs devkitPro)
make android      # Android APK (needs ANDROID_HOME and a JDK; uses the love-android submodule)
```

Shortcuts: `make desktop`, `make console`, `make mobile`, `make all`. The game version is `version.txt`.

## Test

```bash
tools/tests/run.sh all                    # the whole battery (~6 min); must end with "TODO OK"
tools/tests/run.sh <harness> [VAR=val]    # one harness; the list is in tools/tests/README.md
```

## Where things are

| Folder | Contents |
|---|---|
| `main.lua`, `conf.lua` | bootstrap (mounts downloaded updates) and window setup |
| `game.lua`, `settings.lua`, `input.lua` | client entry, global constants, input |
| `src/` | the game code, by system |
| `server/` | the authoritative server |
| `assets/` | images, sounds, music, levels, texts |
| `libs/` | third-party Lua libraries |
| `tools/` | development tools: tests, art / sound / music generators, level builders (never shipped) |
| `resources/` | platform runtimes and icons used by the Makefile |
| `docs/` | **the documentation** |

## Documentation

Everything is documented in [`docs/`](docs/README.md): architecture, every gameplay system, entities and bosses, the
story mode, levels and the editor, art, audio, testing, plus tables generated from the game itself (entity types,
tiles, levels, music). Start at [`docs/README.md`](docs/README.md), which is indexed by task.

`CLAUDE.md` holds the project's working rules for AI-assisted development.

## Credits

Game, levels, original art and the menu theme: Serqwjahk. Font: Press Start 2P (SIL Open Font License). Libraries:
baton, bitser, json.lua, sock.lua, lovesize, classic-style class, timer. Built on LÖVE (zlib licence).
