# Generador de niveles (Python) — herramienta de desarrollo

No se distribuye con el juego (`tools/` no entra en el `.love` ni en las
actualizaciones). Escribe los `assets/levels/*.json` desde código.

    python3 tools/levelgen/build.py                 # regenera los 15 niveles
    python3 tools/levelgen/build.py --show nombre   # + dibujo ASCII (# bloque, = losa, - traspasable,
                                                    #   ~ agua, ^ pinchos, x rompible, F meta, letras = entidades)

## Archivos
- `lib.py` — `Level(nombre, ancho, alto, (col,fila), music=, modes=, match_time=)`. Coordenadas
  1-based como el editor. Helpers: `terrain`, `ground`, `rect`, `clear`, `plat`, `water`, `spikes`,
  `half_spikes`, `finish`, `ent`, `walker` (con ruta), `deco`, `vent`; `check()` avisos básicos.
- `levels_run.py` — carreras (con meta). `pit()` = foso con pinchos.
- `levels_hunt.py` — caza (sin meta, `modes:["hunt"]`). `levels_koth.py` — rey de la colina
  (`pointarea`, `matchTime`). `levels_boss.py` — carrera + jefe: `graft()` copia una arena ya probada
  de `jefe_espejo` / `MiniBossArena` / `jefe_cangrejo` (misma altura, 15) tras un tramo propio.
  Esas arenas de prueba viven en `tools/levelgen/arenas/` (ya no son niveles del juego).
- Un nivel nuevo = una función que devuelve `Level` + añadirla a `BUILDERS` del archivo.
  El nombre del archivo JSON es el de la función.

## Reglas de diseño (doble salto, ground pound y salto agachado existen)
- Un salto ≈ 1,6 casillas, dos ≈ 3. Huecos ≤ 4 cómodos, 5 justos. Pasillo de 1 de alto = salto agachado.
- Bloque rompible: cabezazo desde abajo o ground pound encima. Cámaras sobre la azotea con suelo
  rompible se entran de un cabezazo (no atrapan al jugador).
- Trampolín arriba ≈ +5 casillas y ~7 de alcance horizontal; los laterales devuelven al jugador.
- Agua: una charca de 3+ casillas no se sale desde el fondo; pon isletas/peldaños a ≤ 2 casillas.
- Cada nivel limita sus modos con `modes` (race / hunt / koth). Niveles con jefe = solo carrera.
- Publicar = subir `version.txt`.

## Comprobar (siempre antes de commitear)
    xvfb-run -a love tools/tests/level_solve assets/levels/x.json          # ¿se llega a la meta/zona?
    EXPLORE=1 xvfb-run -a love tools/tests/level_solve assets/levels/x.json  # caza: ¿a todos los enemigos?
    xvfb-run -a love tools/tests/level_check assets/levels/x.json          # validador del editor + modos + 20 s de sim
    love server --headless &  LEVEL=assets/levels/x.json MODE=race xvfb-run -a love tools/tests/online_smoke
(ver `tools/tests/README.md`; en el arnés online, dos partidas seguidas pueden dar `login_error`: espera 15 s).
