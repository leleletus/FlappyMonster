# Pruebas sin humano

Todo se lanza con **un solo comando**, desde la raíz del repo:

    tools/tests/run.sh all                          # batería rápida (~2 min)
    tools/tests/run.sh <arnés> [VAR=valor ...] [-- args]

`run.sh` se encarga de todo lo que antes había que hacer a mano: arranca un
servidor LOCAL nuevo para los arneses online y lo para al acabar, copia las
arenas de prueba de `tools/levelgen/arenas/` a un nivel temporal y lo borra,
limpia `server/published`, pone un límite de tiempo (un error de LÖVE deja la
pantalla de error abierta y no terminaría nunca) y devuelve 0 / 1 según haya
fallos (errores de Lua en el arnés o en el servidor incluidos).

Cada arnés es una app de LÖVE con enlaces relativos a `assets src libs
settings.lua input.lua` del repo. `tools/` no entra en el `.love` ni en las
actualizaciones automáticas. Nunca apuntan al servidor real (usan
`localhost`).

## Arneses

| Arnés | Qué comprueba | Ejemplo |
|---|---|---|
| `flyers` | Enemigos voladores en TODOS los niveles (cada enemigo convertido en volador con oscilación grande): ni metidos en bloques, ni convulsionando (giros seguidos), ni atascados. `SHOT=1` guarda capturas con las alas. | `run.sh flyers` · `run.sh flyers BOB=16` · `SEED=n` (otra secuencia de pausas al azar; `all` prueba 2) · `WHY=1` (qué se atasca/convulsiona) |
| `crawler_drop` | Crabbies trepadores de techo (como los súbditos del Mega Crabby): pisotón al clavado, el trampolín aplasta sin matar y no remata, y repiten la caída varias veces. | `run.sh crawler_drop SUMMON=1` (`NOWALL=1` = Crabby de techo normal, `TRACE=1` = estados) |
| `mechanics` | Bloques ON/OFF (cabezazo y ground pound), bloque invisible (se atraviesa subiendo y de lado, no se baja, aparece/parpadea/desaparece), Gummy con casco (66 caídas de todas las velocidades: siempre rebote sin daño; ground pound = muerto; de lado sí daña), pisotón rápido a un Gummy normal y pez globo (atraviesa bloques, ciclo aviso→hinchado→pinchazo, no se hincha con jugadores fuera del agua). `SHOT=1` = captura `<save>/mechanics.png`. | `run.sh mechanics` |
| `sounds` | Todo `Sound.play('nombre')` del código está cargado; los sonidos de `NAMES` (por defecto los nuevos) se reproducen y, con `Sound.GAIN`, quedan en [-15, -8] dBFS. | `run.sh sounds` (`NAMES=a,b`) |
| `online_helmet` | Online (cliente real + bot + servidor local): rebotar sobre un Gummy con casco (casco intacto, sin daño), ground pound (muere, se oye helmetBreak), pez globo (pincha: -1 vida, se oye pufferPrick). Nivel propio: `tools/tests/online_helmet/level.json`. | `run.sh online_helmet LEVEL=tools/tests/online_helmet/level.json` |
| `boss_sim` | Pelea de jefe en solitario con las clases reales: estados, daño al jugador, golpes cuando es vulnerable. | `run.sh boss_sim` (`LEVEL=`, `HP=`, `DEBUG_POSE=1`) |
| `sp_boss` | La pelea en el modo UN JUGADOR REAL (AdventureState, como "Probar" del editor): súbditos, bloques de jefe, tiempo entre golpes. | `run.sh sp_boss SECS=60` (`SHOTS=1`) |
| `boss_frames` | La pelea dibujada en una rejilla de fotogramas (`<save>/boss_frames.png`). | `run.sh boss_frames STATES=chase,climb EVERY=0.2` |
| `online_smoke` | Un cliente real + un bot juegan una partida online: sin errores en cliente ni servidor. | `run.sh online_smoke LEVEL=assets/levels/isla_flotante.json MODE=koth` |
| `online_boss` | Pelea de jefe online: estados recibidos por red, súbditos, bloques, capturas `<save>/boss_*.png`. | `run.sh online_boss LEVEL=tools/levelgen/arenas/jefe_cangrejo.json NOSHOTS=1` |
| `editor_open` | El editor real: diálogo "Abrir nivel" (Ctrl+O) con scroll; capturas `<save>/editor_open_{1,2}.png`. | `run.sh editor_open` |
| `level_check` | Niveles: avisos del editor, modos que lo listan, 20 s de simulación. | `run.sh level_check -- assets/levels/a.json b.json` |
| `level_solve` | ¿Se puede COMPLETAR un nivel? Búsqueda con la física real del jugador, ahogarse incluido (usa `xvfb-run` si está). Guiada por la distancia por los huecos hasta la meta (`HDIST=0` = en línea recta). `MAXN=` (presupuesto), `NODROWN=1` (solo el terreno: ¿falla por el aire o por el terreno?), `EXPLORE=1`, `DUMP=1` (qué alcanza). No modela enemigos, burbujas de los vents ni rompe bloques de forma fiable. | `run.sh level_solve MAXN=1500000 -- assets/levels/laberinto_submarino.json` |

Niveles de prueba: los de `assets/levels/` (los reales) y las arenas de jefe
de `tools/levelgen/arenas/` (`jefe_cangrejo`, `jefe_espejo`, `MiniBossArena`:
arena pequeña, el jefe está a la vista nada más empezar; ya no son niveles del
juego). Los niveles de `tools/levelgen/` (generador en Python: `python3
tools/levelgen/build.py [--show nombre]`) se comprueban con `level_solve`.

## Reglas para no volver a pelearse con las pruebas

- Lanzar SIEMPRE con `run.sh`, nunca montando el servidor a mano.
- Un arnés nuevo = carpeta en `tools/tests/` (enlaces + `conf.lua` +
  `main.lua` con cabecera que diga qué comprueba y cómo se lanza) + una fila
  en esta tabla (+ en la batería `all` de `run.sh` si es rápido). Que imprima
  `TODO OK` / `FALLA` y salga con `love.event.quit(0|1)`.
- Arneses online: el bot entra en la sala cuando ha iniciado sesión
  (`login_success`), no antes; registrar `online_results` / `online_room`
  (la ronda puede acabar antes del tiempo del arnés).
- El servidor ignora los niveles que empiezan por `_` (`run.sh` usa `zz_tmp_*`).
- Las carpetas de guardado de las pruebas (`~/.local/share/love/fm_test_*`) se
  pueden borrar después.
