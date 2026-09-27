# FlappyMonster Adventure (Online)

Bienvenido de vuelta a tu proyecto FlappyMonster. Este es un juego de plataformas y aventuras multijugador creado en el motor LÖVE (Love2D). 

El proyecto cuenta con una arquitectura dividida en dos partes que conviven en este repositorio:
1. **Cliente Multipataforma:** Renderiza el juego, maneja el audio, inputs y UI para PC, Nintendo Switch y Android.
2. **Servidor Autoritativo:** Corre la simulación del mundo (física, colisiones, lógica de los enemigos) y retransmite los estados del juego a los clientes para evitar trampas y desincronización.

---

## 🛠 Cambios Recientes y Actualizaciones (Septiembre 2026)

Se han solucionado varios bugs relacionados con controles en dispositivos móviles y consolas, y se han ajustado detalles gráficos:
* **Botón Virtual de Agacharse (Crouch):** Se añadió el botón virtual `v` en la pantalla táctil de móviles (al lado del botón de salto `A`). Esto permite hacer *ground pound*, interactuar con plataformas traspasables y usar el poder de aturdir enemigos/jugadores.
* **Soporte de Navegación en Mando (Login Online):** Ya se puede navegar con el D-pad (izquierda/derecha) entre los botones "CONECTAR" y "VOLVER" al introducir el nombre en el modo aventura online.
* **Botón Volver (Back) en Consola:** Se mapeó correctamente el botón físico `B` (Nintendo Switch) para que funcione como retroceso en todos los menús, solucionando el problema donde los usuarios de mando no podían salir del menú de selección de modos.
* **Fallo de Previsualización en Móvil (Pantalla Azul):** Se limitó dinámicamente el tamaño del *Canvas* de previsualización de niveles en `ModeSelectMenu.lua` al límite máximo de textura del dispositivo móvil, evitando que la creación fallara y dejara la pantalla azul.
* **Sistema de Compilación Android:** Se han hecho pruebas con el SDK de Android usando el script de línea de comandos. 

### 🐛 Errores Actuales Conocidos
* Si se compila el APK sin tener `ANDROID_HOME` configurado correctamente en el sistema, `make android` fallará indicando que falta el SDK.
* En mandos de Xbox, el botón físico A asume la función de "Atrás/Cancelar" y el botón B la de "Confirmar", dado que LÖVE mapea los controles al estándar Xbox pero el juego utiliza disposición de Nintendo Switch nativa.
* El teclado en pantalla en Android/Switch al iniciar sesión *Online* superpone parcialmente la UI en resoluciones muy pequeñas.

### 🚀 Futuros Cambios y Mejoras
* **Re-mapeo de Controles:** Opción para intercambiar la disposición de A/B según si el mando es Xbox o Nintendo.
* **Diseño Responsivo:** Escalar y posicionar dinámicamente los controles virtuales táctiles según el *aspect ratio* exacto del dispositivo para mayor ergonomía.
* **Nuevos Modos y Enemigos:** Expandir la funcionalidad del servidor headless para soportar minijuegos por equipos y entidades más complejas.

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
Asegurate de tener instalado LÖVE 11.4 o superior.
Abre una terminal en la raiz del proyecto y ejecuta:
```bash
love .
```
Tips de Depuración para el Cliente:
* Hitboxes: Presiona F1 durante el juego para mostrar/ocultar las cajas de colisión (hitboxes) e información de red (ping, jitter).
* Consola: En `conf.lua`, cambia `t.console = false` a `true`.

### 2. Correr el Servidor Local
El servidor usa los assets del juego para leer mapas e imágenes. Para correrlo con ventana de monitoreo:
```bash
love server
```
Para correrlo en modo Headless (solo terminal):
```bash
love server --headless
```

---

## Editor de Niveles

```bash
love . --editor                               # abre assets/levels/nivel01.json
love . --editor assets/levels/otro.json
```

Corre dentro del propio juego y usa sus mismos catálogos, dibujo y assets: todo tile, material o entidad nuevo aparece solo en la paleta.

* **Capas (1-6):** Bloques, Agua, Pinchos, Entidades, Decoración, Especial.
* **Herramientas:** Pincel (B), Rectángulo (R), Línea (L), Relleno (F), Borrar (E / clic derecho), Cuentagotas (I), Seleccionar (V).
* **Paneles:** a la izquierda capa, herramienta (con su ayuda) y paleta con buscador y categorías plegables; a la derecha pestañas **Selección** (propiedades en secciones plegables), **Nivel** (tamaño, cámara automática, modos de juego y duración de la partida) y **Avisos**. **F1** muestra todos los atajos.
* **Probar (F5):** juega el nivel al instante; F10 vuelve al editor.
* Guarda en `assets/levels/`. El JSON guarda una fila de tiles por línea y solo las propiedades distintas del valor por defecto, así los diffs de git son legibles.

---

## Modos de juego online

El host elige el modo en la sala (**MODO DE JUEGO**) y, dentro de cada modo, un nivel que lo admita. Luego: sala → partida → pantalla de victoria → vuelta a la sala.

* **Cazamonstruos:** aplasta a todos los monstruos; cuando no queda ninguno gana quien tenga más puntos.
* **Carrera Relámpago:** el primero en llegar a la meta activa una cuenta atrás de 15 s para el resto.
* **Rey de la Colina:** partida con tiempo (150 s por defecto, editable por nivel). Quien esté dentro de una **Zona de puntos** gana puntos cada cierto tiempo; al acabar gana quien más tenga (empates: más vidas, luego quien llegó antes a esa puntuación). Niveles: *Cumbre del Cangrejo*, *Rebote Real* y *Marea Alta* (salen en el menú en cuanto tienen al menos una Zona de puntos).
* En cualquier modo, si solo queda un jugador en pie, gana él.

Cada nivel sale en los modos cuyos requisitos cumple (meta, enemigos, zonas de puntos...) y el editor puede limitarlo a algunos (pestaña Nivel → Modos de juego).

---

## Mecánicas y elementos de nivel

* **Ground pound:** agacharse en el aire (o nadando) congela un instante al monstruito y lo lanza en picado. Aplasta enemigos y aturde a jugadores cercanos.
* **Agacharse bajo el agua:** permite atravesar plataformas traspasables sumergidas.
* **Bloques trampa:** paredes, plataformas, peligros y bloques falsos que se ven igual que los reales pero no tienen colisión.
* **Pincho que cae:** cae del techo cuando un jugador se pone debajo, se clava y vuelve a salir.
* **Crabby de techo que cae:** cae como un pincho, se queda clavado boca abajo. Se puede aplastar antes de que se recupere.
* **Vida (HP):** el jugador tiene 3 puntos de vida; los golpes no letales quitan 1 (parpadea en rojo). Con 0, muere.
* **Zonas de jefe:** rectángulo del nivel (capa Especial → Zona jefe). La cámara se queda fija, nadie puede salir y la pelea empieza cuando **todos** los jugadores han entrado. Música de jefe con intro + bucle. Barras de vida por segmentos (jefe arriba, jugadores con su color). Niveles con jefe: solo modo Carrera.
* **Jefe Espejo:** copia con 1,5 s de retardo lo que pulsa el jugador más cercano (colores invertidos, sonidos más graves, algo más rápido y saltarín), a veces con los controles invertidos. Le quita vida al caerte en la cabeza, se ríe cuando alguien muere y más vida cuantos más jugadores. Pisotón = 1, ground pound encima = 2 y lo deja KO. Nivel de prueba: `assets/levels/jefe_espejo.json`. Aturdido solo admite un golpe; después queda unos segundos invulnerable (parpadea) y se le atraviesa.
* **Mortero:** cañón fijo y sólido. Cuando hay un jugador cerca tiembla, se pone rojo y dispara dos bolas de fuego en arco (una a cada lado) que arden un rato en el suelo y quitan 1 de vida. Alcance, esperas, aviso, fuerza, inclinación, lados y daño se editan en el editor.
* **Reaparecer:** tras morir, 2,5 s de invulnerabilidad total (parpadea).
* **Cámara automática** (panel Nivel del editor): el nivel avanza solo; empieza cuando todos están en la ventana inicial (cuenta atrás), no se puede adelantar a la cámara y quien se queda atrás muere y reaparece en el centro. Se para en la meta. Solo modo Carrera.
* **Lluvia de pinchos + Pincho de lluvia:** un director invisible que hace caer los pinchos de su grupo en olas de dificultad (sube, se mantiene, baja...), solo los que pueden alcanzar a un jugador, apuntando a veces justo encima. Los pinchos se pintan arrastrando por el techo. Nivel: `assets/levels/lluvia_pinchos.json`.
* **Inundación:** un rectángulo cuyo nivel de agua sube, se queda arriba, baja y vuelve a empezar (nivel inicial y máximo, velocidades, escalones con pausas y tiempos de cada fase, todo en el editor). Es agua normal: se nada, se ahoga uno, salpica... Funciona igual en un jugador y online. Nivel: `assets/levels/marea_alta.json`.
* **Zona de puntos:** rectángulo que da puntos a quien está dentro cada cierto tiempo (puntos, intervalo y "disputada" —con varios dentro nadie suma— se editan). Brilla, muestra una barra de progreso sobre la cabeza, suena y suelta monedas al sumar. Es el objetivo de Rey de la Colina.
* **Salto agachado:** agachado no se anda pero se puede saltar (con dirección); en un hueco de una casilla de alto se sigue agachado hasta que haya sitio.
* **Nave Malvada (MiniBoss1):** baja desde fuera de la pantalla, patrulla entre sus waypoints (editables) y, si tiene a alguien debajo, saca pinchos y cae en picado rompiendo el suelo. Solo se le puede dañar clavado tras el golpe. Al morir, el Monstruo Malvado sale despedido y la nave estalla. Nivel: `assets/levels/MiniBossArena.json`.
* **Trampolín** (arriba, abajo, izquierda, derecha): bloque sólido; llegar a su cojín te lanza lejos. Tras lanzar se queda extendido un momento (solo es pared); varios jugadores que llegan a la vez rebotan todos. Fuerza y enfriamiento editables.
* **Crabby trampolín:** al esconderse saca un trampolín en vez del pincho. El del techo cae, rebota en el suelo, se da la vuelta y sigue andando; si cae encima de un jugador lo aplasta (agachado, aturdido, empujado y -1 de vida, editable).
* **Crabbies trepadores:** con "Anda por paredes y techos" (Crabby y Crabby trampolín) dan la vuelta a los bloques: suelo, paredes y techo, girando en las esquinas; el pincho o el trampolín salen hacia fuera de la superficie.
* **Jefes invulnerables:** saltarles encima te empuja hacia un lado (no se puede ir montado).
* **Sonido por distancia:** los sonidos del mundo se oyen menos cuanto más lejos, calculado para cada jugador.

---

## Compilación y Empaquetado

Dentro de la carpeta raíz se encuentra el `Makefile`. Este script permite construir los binarios para las plataformas soportadas.

Importante: Para Android, necesitas el SDK configurado. Se generó recientemente un script de instalación que descarga las Command Line Tools.

* `make lovefile` - Archivo universal .love (portátil).
* `make win64`    - Ejecutable Windows 64-bit.
* `make switch`   - Homebrew Nintendo Switch (.nro).
* `make android`  - Aplicación Android (.apk). Requiere `ANDROID_HOME` y un JDK compatible (ej. Java 17).

Macros rápidos: `make desktop` (lovefile+win64), `make console` (lovefile+switch), `make mobile` (lovefile+android), `make all`.
