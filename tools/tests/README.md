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

Las carpetas de guardado de las pruebas (`~/.local/share/love/fm_test_*`) se
pueden borrar después. Nunca apuntar una prueba al servidor real.
