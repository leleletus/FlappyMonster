# FlappyMonster Adventure (Online)

Bienvenido de vuelta a tu proyecto FlappyMonster. Este es un juego de plataformas y aventuras multijugador creado en el motor LOVE (Love2D). 

El proyecto cuenta con una arquitectura dividida en dos partes que conviven en este repositorio:
1. Cliente Multipataforma: Renderiza el juego, maneja el audio, inputs y UI para PC y Nintendo Switch.
2. Servidor Autoritativo: Corre la simulación del mundo (fisica, colisiones, logica de los enemigos) y retransmite los estados del juego a los clientes para evitar trampas y desincronizacion.

---

## Estructura del Proyecto

* main.lua / conf.lua: Archivos de entrada principales del Cliente.
* src/: Logica del cliente (estados, entidades graficas, sonido y maquina de estados).
* assets/: Recursos graficos, niveles (.json), fuentes y sonidos del cliente.
* server/: Carpeta que contiene la logica exclusiva del Servidor. Tiene su propio main.lua y conf.lua.
* libs/: Librerias compartidas (ej. sock.lua para red, bitser.lua para serializacion de paquetes, lovesize.lua).
* love-online-game/: Contiene el Makefile y los resources/ para compilar los ports (Win64, Switch).

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
