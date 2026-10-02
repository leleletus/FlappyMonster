# Cómo crear un enemigo (o cualquier entidad) sin tocar el código interno

Un enemigo nuevo es **un archivo** en `src/world/entities/types/<nombre>.lua` + **su nombre** en la
lista `TYPES` de `src/world/Entities.lua`. El editor, el servidor y el cliente lo recogen solos.
Todo lo que es "de base" (moverse, chocar, morir, sonar, ser súbdito…) ya existe: el tipo solo lo
**enciende** con un rasgo o una tabla. Si para tu enemigo hace falta cambiar `Entity.lua`,
`Interactions.lua`, `Level.lua`… es que falta una regla base: añádela ahí, genérica, y enciéndela
desde el tipo (no copies código de otro enemigo).

Para un JEFE, sigue además `docs/jefes/COMO_CREAR_UN_JEFE.md`.

## 1. El esqueleto

```lua
local Entity = require 'src/world/entities/Entity'
local Bicho = Entity.extend(Entity, {
    hitbox = { outerW = 0.8, outerH = 0.9, innerW = 0.6, innerH = 0.7 },   -- × el tamaño del sprite
})
function Bicho.loadAssets() ... end          -- imágenes (archivos de assets/, nunca dibujadas por código)
function Bicho.sizePx() return 64, 64 end    -- o sizeImage()
function Bicho:init() ... end
function Bicho:updateCustom(dt, level) ... return true end   -- true = "ya me he movido yo"
function Bicho:render(camX, camY) ... end

return {
    name = 'bicho', label = 'Bicho', category = 'Enemigos', class = Bicho,
    description = 'Lo que sale en la paleta del editor',
    defaults = { speed = 70, points = 15 },
    props = { ... },                          -- propiedades editables (entities/Props.lua)
    editor = { sprite = 'assets/images/bicho/idle.png' },
}
```

## 2. Lo que se enciende desde la definición del tipo (sin código)

| Campo del tipo | Qué hace | Dónde vive la regla |
|---|---|---|
| `traits = { ... }` | Rasgos (tabla de abajo): se copian a cada instancia | `Entity.create` |
| `noises = { miSonido = casillas }` | Ese sonido suyo también es RUIDO que oyen los lúgubres (y sirve de distracción) | `Noise.SOUNDS`, `EntityTypes.register` |
| `noise = casillas` | (coleccionables) cuánto suena al cogerlo | `Interactions.run` |
| `pickup = { score, lives }` / `checkpoint = true` | Se coge / es un punto de control | `Interactions` |
| `summons = function(placement) ... end` | Colocaciones de RESERVA que el nivel crea para él (súbditos) | `Level.fromData` |
| `activatable = true` | Se puede conectar a un Activador ON/OFF (prop `id`) | `Level:signal`, editor |
| `category`, `description`, `variant`, `hide`, `placement`, `ceilingOnly` | Editor: paleta, inspector, colocación | `EntityTypes`, editor |
| `boss = { title }` | Es un jefe (barras, zona) | `Boss.lua`, `BossZones` |

### Rasgos (`traits`, o un campo de la clase si es de todo el tipo)

| Rasgo | Efecto |
|---|---|
| `needsPound = true` | DURO: un pisotón normal rebota; solo lo mata un ground pound. Y tocarlo desde arriba no hace daño (salvo que `hurtsFromAbove()` diga que sí: su propio ataque) |
| `diesWithBlock = true / false` | Muere (despedido) si se rompe el bloque que pisa / al que se agarra. Por defecto: los de categoría Enemigos sí |
| `solidFull = true` | Es sólido como un bloque (lados, encima, cabezazo). Hace falta `isSolidBody()` |
| `renderFront = true` | Se dibuja por delante de los jugadores |
| `wantsLevel = true` | Recibe `levelRef` al cargar el nivel (para dibujar según el terreno) |
| `freezeFloats = true` | Congelado se queda donde está (no cae) |

(Las clases comparten `def` cuando un archivo devuelve varias definiciones con la misma clase: ahí
los rasgos distintos por definición no valen; usa subclases.)

## 3. Lo que se hereda (ganchos de `Entity`, todos con un valor por defecto)

- Movimiento: `props.movement` = walk / fly / static; rutas (`patrol`), bordes, pausas, vuelo libre
  (`flyMode = 'free'`, `entities/FreeFlight.lua`). Los que andan se dan la vuelta ante otra entidad
  (`isObstacle()`), pinchos y bordes; encerrados, se quedan en idle.
- TREPADOR (suelo ↔ paredes ↔ techo): `Crawler.mixin(Clase)` da las cajas giradas, la normal para
  el pisotón, soltarse y no caer agarrado; muévelo con `Crawler.move(self, level, px)` y pregunta
  `Crawler.entityAhead(self, level)` para no atravesar a otros.
- Jugador ↔ entidad: reglas normales en `Interactions.defaultCheck` (pisotón, contacto según
  `props.onTouch`, cajas de peligro `getHazardBoxes()` con `effect = 'hurt' | 'freeze'`…). Reglas
  propias: `interact(pa)` (sin efectos: el cliente la usa para predecir) y los avisos
  `onStomp`, `onBounced`, `onHurtPlayer`, `onLaunch`, `onHelmetBounce`.
- Muertes: `stomp()`, `dieFling(dir)`, `dieBurst()`, reaparición (`props.respawn`).
- Congelarse (`canFreeze`), ser lanzado por trampolines (`canBeLaunched`), empujón del ground
  pound (`knockback`).
- SÚBDITO de reserva: cualquier entidad lo es (`Entity:makeReserve`; gancho `onMakeReserve`).
- Red: `netPack()` / `netApply(a, b, f)` para lo propio; `netAtRest()` / `netRest()` para no
  enviarla cuando está quieta en su estado de siempre.
- Lo que se ve a oscuras: `renderGlow(camX, camY)`.
- Sonidos: `Sound.play('nombre')` desde su update ya se atenúa con la distancia y, si está en
  `noises`, es ruido.

## 4. Otras piezas que son "un archivo + un nombre"

- Tiles: `src/world/tiles/types/` (receta en `Tiles.lua`). Decoraciones: `src/world/decorations/types/`
  (con `light = { r, color, a, dy }` dan luz tenue en los niveles a oscuras). Modos: `src/world/modes/`.
- Sonidos: un archivo en `assets/sounds/<grupo>/` + una línea `load(...)` en `Sound.lua` (y su
  generador en `tools/sounds/`). Carpetas: `player/`, `enemies/`, `bosses/<jefe>/`, `items/`,
  `mechanics/`, `traps/`, `water/`, `ambience/`, `jingles/`, `ui/`.
- Imágenes: `assets/images/<enemigo>/` en minúsculas; los jefes, `assets/images/bosses/<jefe>/`;
  lo que comparten los jefes (estrellas de aturdido, símbolos de enfado, diana), en
  `assets/images/bosses/common/` y se dibuja con `src/fx/BossFx.lua`.

## 5. Antes de entregar

- Arnés: un caso en `tools/tests/` (o uno nuevo) + su fila en `tools/tests/README.md`;
  `tools/tests/run.sh all`.
- Si cambia lo que viaja por red o las reglas con el jugador: `Protocol.VERSION` y `version.txt`.
- Apúntalo en `CLAUDE.md`.
