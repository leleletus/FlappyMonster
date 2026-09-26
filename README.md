# FlappyMonster Adventure (Online)

Bienvenido de vuelta a tu proyecto FlappyMonster. Este es un juego de plataformas y aventuras multijugador creado en el motor LOVE (Love2D). 

El proyecto cuenta con una arquitectura dividida en dos partes que conviven en este repositorio:
1. Cliente Multipataforma: Renderiza el juego, maneja el audio, inputs y UI para PC y Nintendo Switch.
2. Servidor Autoritativo: Corre la simulación del mundo (fisica, colisiones, logica de los enemigos) y retransmite los estados del juego a los clientes para evitar trampas y desincronizacion.

---

## Estructura del Proyecto

```
main.lua / conf.lua      Entrada del cliente (y del editor con --editor)
settings.lua, input.lua  Constantes globales y controles (teclado, mando, táctil)
libs/                    Librerías compartidas cliente/servidor (sock, bitser, json...)
server/                  Servidor autoritativo (main.lua + conf.lua propios)
src/
  states/                Pantallas del juego (menús, aventura, online, resultados)
  entities/              Jugador (física compartida con el servidor) y jugadores remotos
  network/               Protocolo, cliente de red, predicción e interpolación
  world/                 Nivel y catálogos data-driven:
    tiles/               tipos de tile y materiales      (receta en world/Tiles.lua)
    entities/            enemigos / NPCs                 (receta en world/Entities.lua)
    decorations/         decoración                      (receta en world/Decorations.lua)
    modes/               modos de juego online           (receta en world/Modes.lua)
  ui/                    Componentes de interfaz: avisos (Notify), menú de modos,
                         botones de pausa/volver, iconos pixel art, utilidades de texto
  editor/                Editor de niveles
assets/
  levels/                Mapas (.json). El servidor los detecta solos (los que
                         empiezan por "_" se ocultan)
  music/                 Música (menús, nivel, victoria)
  sounds/                Efectos (sounds/water/, sounds/fireworks/...)
  images/, fonts/, shaders/
love-online-game/        Makefile y resources/ para compilar los ports (Win64, Switch, Android)
```

---

## Como Ejecutar Localmente

### 1. Correr el Cliente (El Juego en PC)
Asegurate de tener instalado LOVE 11.4 o superior.
Abre una terminal en la raiz del proyecto y ejecuta:
```bash
love .
```
Tips de Depuracion para el Cliente:
* Hitboxes: Puedes presionar la tecla F1 durante el juego para mostrar/ocultar las cajas de colision (hitboxes). En partidas online, F1 tambien muestra estadisticas de red (ping, retardo de interpolacion, jitter y correcciones de la prediccion).
* Consola de depuracion: Si quieres ver los prints en tiempo real en Windows, abre conf.lua y cambia t.console = false por t.console = true.

### 2. Correr el Servidor Local
El servidor usa los assets del juego para leer mapas e imagenes (para el tamano real de los sprites y colisiones). Para correrlo con su propia ventana grafica de monitoreo:
```bash
love server
```
Para correr el servidor en modo Headless (sin ventana ni renderizado grafico, solo terminal), ejecuta:
```bash
love server --headless
```

---

## Editor de Niveles

```bash
love . --editor                               # abre assets/levels/nivel01.json
love . --editor assets/levels/otro.json
```

Corre dentro del propio juego y usa sus mismos catalogos, dibujo y assets: todo tile, material o entidad nuevo aparece solo en la paleta.

* Capas (teclas 1-6): Bloques, Agua (celdas sumergidas sobre cualquier bloque), Pinchos (subceldas, 4 direcciones), Entidades, Decoracion, Especial (inicio del jugador y vents de oxigeno).
* Herramientas: Pincel (B), Rectangulo (R), Linea (L), Relleno (F), Borrar (E / clic derecho), Cuentagotas (I), Seleccionar (V).
* Decoracion: Seleccionar (V) permite moverlas arrastrando y cambiar sus propiedades (espejar, capa delante/detras).
* Entidades: al seleccionarlas, el panel derecho muestra TODAS sus propiedades (movimiento, suelo/techo, velocidad, direccion, ruta con limites, pausas, hostilidad, puntos...). La ruta se ve como una linea con dos cajitas que se arrastran en el mapa. Si una entidad cae desde donde se coloco, se marca su caida.
* Deshacer/Rehacer (Ctrl+Z / Ctrl+Y), zoom con la rueda, mover la vista con clic central, Espacio+arrastrar o flechas, redimensionar el mapa, enmarcar con borde, avisos de validacion (clic para ir a la entidad).
* Probar (F5): juega el nivel al instante; F10 vuelve al editor.
* Guarda en `assets/levels/` (hay que ejecutar el juego desde su carpeta). El JSON guarda una fila de tiles por linea y solo las propiedades distintas del valor por defecto, asi los diffs de git son legibles.

---

## Anadir Contenido (tiles, materiales, entidades, modos, mapas)

Todo es declarativo y se registra en un unico listado; el juego, el servidor online y el editor lo reconocen sin tocar nada mas.

* Tile nuevo: crea `src/world/tiles/types/<nombre>.lua` con un `id` nuevo (0-255, nunca reutilizar) y anade su nombre a `TYPES` en `src/world/Tiles.lua`. Campos: `collision` (none/solid/oneway), `dropThrough`, `hitbox` parcial, `material`, `joinGroup`, y aspecto con `draw`, `texture` (imagen o tira animada) o `color`. Ver cabecera de `src/world/tiles/TileTypes.lua`.
* Material nuevo (hielo, barro, cinta, espinas, lava...): `src/world/tiles/materials/<nombre>.lua` + `MATERIALS` en `src/world/Tiles.lua`. Campos: `friction`, `speedMult`, `conveyor`, `contact` (kill/hurt) y fisica de liquido (`liquid`, `gravityMult`, `jumpMult`, `drag`, `drown`, `tint`...). Ver `src/world/tiles/Materials.lua`.
* Entidad nueva (enemigo, NPC...): `src/world/entities/types/<nombre>.lua` + `TYPES` en `src/world/Entities.lua`. Hereda de `Entity` (movimiento, ruta, pausas, combate ya resueltos); solo define sprites, dibujo, sus valores por defecto y, si quiere, propiedades y comportamiento propios mediante hooks. Receta completa en la cabecera de `src/world/Entities.lua`.
* Decoracion nueva (planta, roca, adorno...): `src/world/decorations/types/<nombre>.lua` + `TYPES` en `src/world/Decorations.lua`. Define `placement` ('sub' o 'cell'), sus imagenes, `draw` y, si quiere, `init`/`update` para animarse. Todas pueden espejarse y ponerse delante o detras del jugador desde el editor. Ver `src/world/decorations/DecorationTypes.lua`.
* Propiedad nueva para TODAS las entidades: anadirla a `EntityTypes.COMMON` (`src/world/entities/EntityTypes.lua`); el editor la muestra automaticamente.
* Modo de juego online nuevo: `src/world/modes/<id>.lua` + `TYPES` en `src/world/Modes.lua`. Define que necesita el nivel (`requires`), cuando termina la ronda (`tick`) y como se clasifica (`rank`, con desempates). El host lo elige en el lobby, el servidor aplica sus reglas y la pantalla de resultados es generica. Ver `src/world/modes/ModeTypes.lua`.
* Mapa nuevo: guardalo desde el editor en `assets/levels/`. En el servidor aparece solo (en ~10 s, sin reiniciar) en los modos que admita: Carrera necesita tiles "Meta"; Cazamonstruos, enemigos pisoteables.
* Avisos al jugador: `Notify.toast(msg, tipo)` para avisos temporales y `Notify.modal(titulo, msg)` para ventanas que hay que aceptar (`src/ui/Notify.lua`).
* Formato de celda: `src/world/tiles/TileCodec.lua` (id, agua, pinchos). Reglas jugador-entidad: `src/world/entities/Interactions.lua`.

---

## Despliegue en Ubuntu Server

El servidor esta optimizado para funcionar en entornos de produccion Linux sin interfaz grafica (headless).

1. Instalar LOVE en tu servidor:
   ```bash
   sudo apt update
   sudo apt install love
   ```
2. Clonar el proyecto y acceder:
   ```bash
   git clone <URL-de-tu-repo>
   cd FlappyMonster
   ```
3. Ejecutar en segundo plano:
   Puedes usar screen o tmux para mantenerlo vivo, o crear un servicio systemd. Para iniciarlo:
   ```bash
   love server --headless
   ```
   El servidor escucha conexiones en el puerto 22122 por defecto (UDP, via ENet). Recuerda abrir este puerto en tu firewall (ej: sudo ufw allow 22122/udp).

---

## Red del Modo Multijugador

* Paso fijo: servidor y cliente simulan al jugador a 60 Hz exactos (src/network/Protocol.lua). El servidor envia snapshots a 30 Hz.
* Prediccion + reconciliacion (src/network/Predictor.lua): el cliente mueve a su jugador al instante con inputs numerados; cada snapshot confirma el ultimo input procesado y el cliente re-simula los pendientes. Las diferencias se corrigen suavemente.
* Interpolacion (src/network/SnapshotBuffer.lua): otros jugadores, enemigos y burbujas se dibujan unos ~60-110 ms en el pasado, interpolando entre snapshots reales. El retardo se adapta al jitter y a la perdida de paquetes.
* Canales ENet: canal 0 fiable (salas y eventos de juego), canal 1 no fiable (snapshots e inputs, con redundancia para tolerar perdidas).
* Anti-trampas y robustez: el servidor es autoritativo; limita mensajes por conexion, conexiones por IP e intentos de contrasena; valida tipos y tamanos de todo lo que recibe; descarta paquetes malformados sin caerse; impide el speed hack (presupuesto de inputs por tick); banea por nombre e IP.
* Version de protocolo: `Protocol.VERSION`. Si cambias el formato de los mensajes, subela: el servidor rechaza clientes con otra version con un mensaje claro.

---

## Compilacion y Empaquetado

Dentro de la carpeta love-online-game/ se encuentra un Makefile. Este script te permite construir los binarios para las plataformas soportadas.

Importante: Para que funcione necesitas herramientas de consola como make, zip, y las herramientas de SDK correspondientes (ej. devkitPro para Switch, Android Studio/JDK para Android). 

Abre tu terminal (ej. Git Bash o MSYS2 en Windows) en la ubicacion del Makefile y usa los siguientes comandos o macros:

* Generar el .love (Universal - macOS y Linux):
  Genera el archivo universal .love. Este archivo es portatil y puede ser ejecutado directamente en macOS (x64/ARM) y Linux (x64/ARM) simplemente teniendo LOVE instalado.
  ```bash
  make lovefile
  ```
* Compilar para Windows 64-bit (.exe):
  Genera el archivo .exe fusionando tu juego con los DLLs de LOVE que tengas en resources/win64/love/.
  ```bash
  make win64
  ```
* Compilar para Nintendo Switch (.nro):
  Genera un .nro listo para correr en el Homebrew Launcher de la Switch.
  ```bash
  make switch
  ```
* Compilar para Android (.apk):
  Descarga automaticamente el repositorio de love-android, inyecta tu .love, configura el icono, modifica el manifiesto y compila el APK con Gradle.
  ```bash
  make android
  ```

Tambien existen macros rapidos definidos en el Makefile para compilar en lote:
* `make desktop` (lovefile + win64)
* `make console` (lovefile + switch)
* `make mobile`  (lovefile + android)
* `make all`     (Genera todos los anteriores)

* Limpiar compilaciones previas:
  Borra la carpeta temporal build/ generada por los procesos anteriores.
  ```bash
  make clean
  ```
