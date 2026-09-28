# Pruebas sin humano

Arneses reutilizables (se guardan aquí y no en carpetas temporales, que se
borran). `tools/` no entra en el `.love` ni en las actualizaciones automáticas.
Cada arnés es una app de LÖVE con enlaces relativos a `assets src libs
settings.lua input.lua` del repo; se lanza desde la raíz del repo.

- `online_smoke/` — un cliente real + un bot juegan una partida contra un
  servidor LOCAL y se comprueba que no hay errores:

      love server --headless &
      LEVEL=assets/levels/carrera01.json MODE=race love tools/tests/online_smoke
      pkill -f "^love server"

- `boss_sim/` — pelea de jefe en solitario, sin ventana útil: estados del jefe,
  daño al jugador y golpes (pisotón / ground pound) cuando es vulnerable.
  `LEVEL=assets/levels/jefe_cangrejo.json love tools/tests/boss_sim`
  (`DEBUG_POSE=1`: continuidad del dibujo al trepar).
- `boss_frames/` — la misma pelea dibujada en una rejilla de fotogramas
  (`<save>/boss_frames.png`; `STATES=...`, `EVERY=...`).
- `online_boss/` — pelea de jefe online: cliente real + bot entran en la arena;
  estados recibidos por red, errores y capturas (`<save>/boss_*.png`).

- `sp_boss/` — pelea en el modo UN JUGADOR REAL (AdventureState, como "Probar"
  del editor): estados, súbditos, bloques de jefe y tiempo entre golpes.

- `level_solve/` — ¿se puede COMPLETAR un nivel? Búsqueda con la física real del
  jugador (doble salto, agacharse, agua, pinchos; emula trampolines; ignora
  enemigos, jefes y cámara automática). Necesita pantalla virtual:

      xvfb-run -a love tools/tests/level_solve assets/levels/x.json [más.json]
      MAXN=200000 ...      # presupuesto de estados (por defecto 60000)
      EXPLORE=1 ...        # sin meta: ¿se llega a todos los enemigos/objetos? (caza)
      DUMP=1 ...           # dibuja lo alcanzado (o = visitado)

  Los niveles de `tools/levelgen/` (generador en Python: `python3
  tools/levelgen/build.py [--show nombre]`) se comprueban con esto.

Las carpetas de guardado de las pruebas (`~/.local/share/love/fm_test_*`) se
pueden borrar después. Nunca apuntar una prueba al servidor real.
