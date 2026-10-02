# Cómo crear un jefe nuevo (guía paso a paso)

Guía para añadir un jefe a FlappyMonster sin tener que volver a estudiar todo el código.
Está escrita a partir de los jefes que ya existen y de los errores que ya se pagaron.
Sigue los pasos en orden y marca la **lista de comprobación** del final.

Jefes de referencia (copia del que más se parezca a lo que quieres):

| Jefe | Archivo | Qué copiar de él |
|---|---|---|
| Nave Malvada | `src/world/entities/types/miniboss1.lua` | vuelo por puntos (`points`), caída sobre el suelo, romper bloques |
| Espejo | `types/mirror.lua` | jefe que copia al jugador (cuerpo `PlayerAdventure` propio), portales, plataformas de la arena |
| Mega Crabby (+ helado) | `types/megacrabby.lua`, `megacrabby_ice.lua` | trepar paredes/techo (Crawler), **súbditos de reserva**, entrada con estados propios, subclase con otro arte |
| Gran Bola de Nieve | `types/snowboss.lua` | **física propia** (choques, saltos a una marca, zona), proyectiles, fases que cambian el tamaño, objetos del escenario por fase |
| **Rey Gummy** | `types/megagummy.lua` | **el más limpio para empezar**: reutiliza la física de la Bola, ataque con marca + olas, súbditos (guardia), se divide en trozos, muerte propia |

---

> **Antes de nada:** lo común de los jefes YA está en la base — no lo copies de otro jefe.
> `Boss:enter(st)`, `Boss:zoneBounds()`, `Boss:minions(level)`, `Boss:nearestPlayer(level)`,
> `Boss.strike(pa, {vida, vx, vy, sinControl, aturdido}, dir)`; efectos compartidos en
> `src/fx/BossFx.lua` (`stars`, `anger`, `target`; sprites en `assets/images/bosses/common/`);
> súbditos de reserva: cualquier entidad (`Entity:makeReserve`). El arte de cada jefe va en
> `assets/images/bosses/<jefe>/`. Rasgos y demás: `docs/entidades/COMO_CREAR_UN_ENEMIGO.md`.

## 0. Diseño (antes de escribir código)

Escribe en 10 líneas (luego van a la cabecera del archivo del jefe):

1. **Cómo persigue / se mueve** (anda, salta, vuela...).
2. **Sus ataques** y cómo se ven venir: TODO ataque tiene aviso (marca en el suelo, se agacha,
   tiembla, sonido). Lo que hace daño debe poder esquivarse (saltar, apartarse, subir a una plataforma).
3. **Cuándo es vulnerable**: una ventana clara (mareado, clavado, empapado...). Fuera de ella, caerle
   encima solo rebota (`'bounce'`). Regla general: pisotón = 1, ground pound = 2, un golpe por ocasión.
4. **Fases** (normalmente 3, por fracción de vida): qué cambia (ritmo, ataques nuevos, escenario).
5. **Entrada** (cinemática corta, 3-4.5 s) y **muerte** (propia o la genérica de explosiones).
6. Daño a los jugadores: contacto 1, ataques fuertes 2, aplastar = 2 + `pa:squash`.

Vida por defecto: `hp` para 1 jugador (8-14) y `hpPerPlayer` (3-4) por cada jugador extra.

## 1. Arte (sprites y animaciones)

- **Todo es un archivo** en `assets/images/bosses/<jefe>/` hecho por un **generador** en
  `tools/ui/` (Python + PIL) que se sube al repo. El código solo coloca/anima.
- Si el jefe es la versión "Mega" de un enemigo: **la MISMA rejilla del sprite pequeño** (p. ej.
  el Gummy 16x16) dibujada a escala grande (10). Solo retoques de 1 píxel. Un cuerpo nuevo con más
  resolución NO pega con el juego (el usuario lo rechazó dos veces).
- Si rediseñas una imagen que ya existe: el original va FUERA del repo (`tools/ui/originals.py`).
- Tiras de cuadros (`<algo>-Sheet.png`, cuadros del mismo ancho uno al lado del otro) y en el
  código `SpriteStrip.load(path, anchoCuadro)` → `:draw(i, x, y, r, sx, sy)` / `.image`, `.quads[i]`.
- Lo que se suele necesitar: quieto, andar (2), saltar/aire, aturdido/mareado, dolor, risa, grito;
  marca de dónde cae, sombra, proyectiles/olas, estrellitas de mareo, piezas que salen volando.
- Piezas que se separan del cuerpo (corona, casco...): en una imagen APARTE con la misma rejilla y
  el mismo origen, dibujadas encima → luego pueden salir volando.
- Antes de aplicar, enseña opciones al usuario: vista previa en
  `/home/mtvemo/FlappyMonster_pruebas/<cosa>/vista_previa.png` (o `$FM_PREVIEWS`), con un `--apply`.
- Ejemplo: `tools/ui/make_gummy_variants.py --apply-mega` (función `boss_art`).

## 2. Sonidos

- Generador `tools/sounds/<jefe>.py` → `assets/sounds/bosses/<jefe>/*.wav`. Reutiliza las ayudas de
  `tools/sounds/megacrabby.py` (`env`, `sweep`, `noise`, `lowpass`, `reson`...) y de `snowboss.py`
  (`save`, `voice`, `tink`). Ejemplo completo y corto: `tools/sounds/megagummy.py`.
- Registro en `src/Sound.lua` (3 sitios):
  1. `GAIN` (arriba): ganancia por sonido para quedar en ≈ -12 dBFS (el tramo más fuerte de 100 ms).
     Mídela con este Python y pon `g = 10 ** ((-12 - dB) / 20)` (golpes muy grandes: hasta -9):
     ```python
     import wave, numpy as np
     w = wave.open(f); x = np.frombuffer(w.readframes(w.getnframes()), '<i2') / 32768
     n = int(w.getframerate() * 0.1)
     db = 10 * np.log10(max(np.mean(x[i:i + n] ** 2) for i in range(0, len(x) - n, n // 4)))
     ```
  2. La carga: un bucle `for _, n in ipairs({...}) do load('<prefijo>' .. ..., path, 'static') end`.
  3. `RANGE`: sonidos del jefe que se oyen en toda la arena (2-3).
- Comprobar: `tools/tests/run.sh sounds NAMES=a,b,c` (en un contenedor sin audio "suena=false" es
  normal; lo que importa son los dB).
- Sonidos que solo decide el servidor y debe oír todo el mundo → `Protocol.SHARED_SOUNDS`.

## 3. Partículas

- Nuevos tipos en `src/fx/Particles.lua`, dentro de `Particles.emit(kind, x, y, opts)` (cadena de
  `elseif kind == '...'`). Campos útiles de `add{}`: `vx, vy, g, drag, life, size, col, star, chunk,
  spin, phys (choca con el nivel), bounce, dust, fadeLast`.
- Desde la SIMULACIÓN (un jugador y servidor): `Entity.emitFx(kind, x, y)` → llega a todos los clientes
  como evento `fx` (sin `opts`: si necesitas una variante, usa otro nombre, p. ej. `king_confetti_big`).
- Desde el DIBUJO (solo en ese cliente, continuas: estelas, goteo, brillos): `Particles.emit` directo
  con un temporizador local (`if (self.lastX or 0) + 0.05 < now then ... end`).
- Temblor de pantalla: `Entity.emitFx('shake_small' | 'shake_big' | 'shake_roar', x, y)`.

## 4. La entidad (`src/world/entities/types/<jefe>.lua`)

Esqueleto mínimo (ver `megagummy.lua` entero como modelo):

```lua
local Entity = require 'src/world/entities/Entity'
local Boss   = require 'src/world/entities/Boss'
local SpriteStrip = require 'src/fx/SpriteStrip'
local Snow = require('src/world/entities/types/snowboss').class   -- (física reutilizable)

local X = Entity.extend(Boss, { hitbox = { outerW = 12/16, outerH = 13/16, innerW = 11/16, innerH = 12/16 } })
X.hurtSound   = 'xHurt'
X.introLength = 3.6            -- entrada genérica (s)
X.wantsLevel  = true           -- recibe self.levelRef (BossZones.link): dibujo sobre la superficie real
X.move, X.physics, X.friction, X.groundDecel = Snow.move, Snow.physics, Snow.friction, Snow.groundDecel
X.zoneBounds, X.target, X.jumpTo, X.groundBelow = Snow.zoneBounds, Snow.target, Snow.jumpTo, Snow.groundBelow

function X.loadAssets() ... end
function X.sizePx() return 16 * 10, 16 * 10 end
function X:initBoss() self.y = self.row * TILE_PX - self.outerH / 2 ... end   -- de pie en su celda
function X:onFightStart(n) self:enter('chase') end
function X:updateBoss(dt, level) ... end        -- máquina de estados (self.deadTimer = tiempo en el estado)
function X:isVulnerable() return self:isActive() and self.state == 'dazed' end
function X:netPackExtra() ... end  function X:netApplyExtra(a, b, f) ... end
function X:render(camX, camY) ... end
return { name = 'x', label = 'Nombre', category = 'Jefes', class = X, boss = { title = 'NOMBRE' },
         hide = Boss.HIDE, defaults = { points = 30 },
         props = Boss.props({ hp = 12, hpPerPlayer = 4 }, { ...props propias con group = 'Nombre del jefe' }),
         editor = { sprite = 'assets/images/bosses/x/body-Sheet.png', frameW = 16 } }
```

Reglas que NO se pueden romper:

- **Igual en los 3 sitios** (un jugador, servidor, cliente online). La simulación (`updateBoss`) solo
  corre en un jugador y en el servidor; el cliente recibe `x, y, state, deadTimer` + `netPack`.
  **Todo lo que se dibuja sale de state + deadTimer + x, y + netPackExtra.** Nada de estado que solo
  exista en la simulación si el dibujo lo necesita.
- Nada de `love.graphics` fuera de `render`/`loadAssets`.
- `interact(pa)` **sin efectos** (el cliente lo usa para predecir rebotes). Devuelve
  `'stomp'|'pound'|'bounce', vy, puntos|dirX`. La base (`Boss.interact`) ya hace: encima + vulnerable =
  stomp/pound; encima e inmune = bounce lateral; de lado nada (el cuerpo es sólido).
- Daño a jugadores dentro de `Boss.withPlayer(pa, fn)` (el servidor atribuye sonidos/muertes).
  Golpe con empujón: `Snow.strike(pa, {vida, vx, vy, bloqueoControl, aturdido}, dir)`.
  Comprueba `pa:isInvulnerable()` y "no le está cayendo encima" antes del daño por contacto.
- Muerte propia: sobreescribe `defeat()` (estado `dying_<algo>`), `isDying()`, `isActive()` y
  `releasesZone()` (la zona se libera aunque siga la animación); al final `state='dead', alive=false`.
- Si un golpe puede "pasarse" de un umbral (p. ej. dividirse), recórtalo en `damage()` (ver
  `MG:damage`): la vida no debe bajar más de lo que el diseño dice.
- Fases: `bossPhase()` devuelve la fase → la zona la usa (`PhaseBlocks`, props `phase` de objetos).
- `self.levelRef` puede no estar en el primer paso: ponlo en `updateBoss` (`self.levelRef = self.levelRef or level`).

Física reutilizable (Bola de Nieve): `self:physics(level, dt)` (gravedad 2200, choques con bloques y
cuerpos, plataformas solo desde arriba, paredes/techo de la zona, devuelve `'wall'`),
`self:jumpTo(tx, ty, casillasArriba)` + `self.passY = ty` (salto balístico que ATRAVIESA lo que haya
por encima de la marca y cae justo en ella), `self:friction(level, dt)`, `self:target(level)`.
Para objetos que no son la entidad (trozos, proyectiles grandes) crea una tabla con esos mismos
métodos (ver `Part` en `megagummy.lua`).

### Red (`netPackExtra` / `netApplyExtra`)

- `Boss` ya envía `hp, hpMax, inv, ghost`; lo tuyo va después (índice 1 = primer campo extra).
- Campos fijos primero, luego listas como `n, {campos}×n` (ver `readList` en `megagummy.lua`).
- Proyectiles/olas: con un `id` estable para interpolar entre snapshots (`a` = anterior, `b` = nuevo, `f`).
- Cambiar netPack o las entidades que crea el nivel ⇒ **subir `Protocol.VERSION`** (y `version.txt`).

### Entrada genérica

`introLength` + `onIntroStart(level, players)`, `updateIntro(dt, level, t)` (coloca x, y; sonidos
una vez con un contador `introStep`), `introFocus()` (cámara). Durante la entrada los jugadores están
congelados y la música calla. En `pose()`/`render` usa `t` (y en 'ready' `introLength + t`).
Antes de la entrada (`'dormant'`) no se dibuja (salvo `EDITOR_VIEW`).

## 5. Súbditos (opcional)

- En la definición: `summons = function(pl) return { {type, col, row, summonKey, props}, ... } end` →
  el nivel los crea en RESERVA al cargar, después de las entidades del JSON (mismos índices en servidor
  y clientes). Clave única por jefe: `'xx' .. col .. ',' .. row`.
- El tipo del súbdito necesita `makeReserve(key)`, `netAtRest()`, `netRest()` y no hacer nada en
  `'reserve'` (ya lo tienen **Crabby**, **Gummy** y la bomba objeto).
- El jefe: `minions(level)` (los de su `summonKey` en `level.liveEntities`), `summonable(level)`
  (libres y por debajo del máximo), activarlos: ajustar `e.home`, `e:resetToHome()`,
  `e.state = 'spawning'`, límites (`leftBoundPx/rightBoundPx` = la zona) + `Entity.emitFx('spawn', ...)`.
- Al morir el jefe, los vivos desaparecen (`e.state = 'dead'` + partículas).

## 6. Registro

- `src/world/Entities.lua`: el nombre en `TYPES`.
- Idiomas: `boss.<tipo>` en **TODOS** los `assets/lang/*.lua` (es y en). El arnés `lang_names` lo exige.
- `src/network/Protocol.lua`: `P.VERSION` + 1 (con nota en el comentario).
- `version.txt`: subir (3.x.0 para un jefe nuevo).

## 7. Arena de prueba

- Generador `tools/levelgen/arenas/make_jefe_<x>.py` → `jefe_<x>.json` (ver `make_jefe_gummy.py`:
  usa `write` y `enc` de `make_jefe_nieve.py`). Altura 15 (para injertarla en niveles reales).
- Zona `bossZones: [{id, col, row, w, h, music}]` (música: una pista con `"boss": true` del índice
  `assets/music/index.json`), bloques de jefe (`bosswall`) a izquierda, derecha y techo, el jefe de pie
  en el suelo de la zona (`row` = la fila justo encima del suelo), la meta a la derecha.

## 8. Nivel real

- `tools/levelgen/levels_boss.py`: función `mi_nivel()` = tramo de plataformas con enemigos del tema +
  `graft(L, load_src('jefe_<x>.json'), 6, colInicio)` + añadirla a `BUILDERS`. `L.extra['name_en']`.
- `tools/levelgen/retheme.py`: filas en `THEMES` y `SKY`.
- `python3 tools/levelgen/build.py --only mi_nivel` (¡siempre con `--only`!) y luego
  `python3 tools/levelgen/retheme.py mi_nivel`.
- Comprobar: `tools/tests/run.sh level_solve -- assets/levels/mi_nivel.json` y
  `xvfb-run -a tools/tests/run.sh level_check -- assets/levels/mi_nivel.json` (debe listar `race`).

## 9. Pruebas (arneses)

1. **`<jefe>_rules`** (nuevo): copia `tools/tests/megagummy_rules/` (enlaces + `conf.lua` con su propia
   `identity` + `main.lua`). Un caso por regla del diseño, en la arena real. Trucos ya aprendidos:
   - Al colocar al jefe a mano: pies en `(FILA_SUELO - 1) * TILE_PX` (no dentro del suelo).
   - Las funciones de daño recorren `level.players`: ponlo antes de llamarlas.
   - Para el daño por contacto, coloca al jugador de verdad solapado (`pb.w`) e `invT = 0`.
   - Caso `red`: `netPackExtra` → otro jefe nuevo `netApplyExtra` → mismos datos y mismo `interact`.
   - Añádelo a la batería `all` de `tools/tests/run.sh` y una fila en `tools/tests/README.md`.
2. **`boss_intro`** `LEVEL=<arena> SECS=60`: añade en su `main.lua` el primer estado de pelea y los
   sonidos de la entrada del jefe (tablas junto a `snowboss` / `megagummy`).
3. **`boss_sim`** `LEVEL=<arena>`: añade un bloque que juegue "como se espera" (esquivar la marca,
   saltar lo que se salta, golpear en la ventana) y checks al final (estados vistos, fases, muerte + zona
   `cleared`). Ver el bloque `king`.
4. **`boss_frames`** `LEVEL=<arena> FX=1 ZONE=1 STATES=...`: rejilla de capturas para revisar el aspecto
   (si el jefe necesita golpes para avanzar, añade un gancho como el del Rey Gummy). MIRA la imagen.
5. **`sp_boss`** `LEVEL=assets/levels/mi_nivel.json SECS=60 FIGHT_SHOT=1` (el juego real en un jugador).
6. **`online_boss`** `LEVEL=<arena> NOSHOTS=1` (servidor + cliente: estados y súbditos por red).
7. `sounds NAMES=...`, `lang_names`, y la batería `all` antes de subir.

Comando base en este contenedor: `ALSA_CONFIG_PATH=/dev/null xvfb-run -a tools/tests/run.sh <arnés> ...`.

## 10. Documentación y entrega

- `CLAUDE.md`: un párrafo del jefe en "Boss system" (estados, reglas, archivos, arena, nivel, arneses,
  versión de protocolo), el nivel en la lista de niveles, el arnés en la lista de arneses.
- Cabecera del archivo del jefe (en español): el diseño del paso 0.
- Commit en español, subir a la rama de trabajo y a master. Comprobación rápida de sintaxis:
  `for f in $(git ls-files '*.lua' | grep -v resources/); do luajit -bl "$f" >/dev/null || echo "$f"; done`

---

## Lista de comprobación

- [ ] Diseño escrito (movimiento, ataques con aviso, ventana vulnerable, fases, entrada, muerte)
- [ ] Generador de arte en `tools/ui/` + PNGs en `assets/images/bosses/<jefe>/` (misma rejilla si es "Mega")
- [ ] Generador de sonidos `tools/sounds/<jefe>.py` + `Sound.lua` (GAIN medido, carga, RANGE)
- [ ] Partículas nuevas en `Particles.emit`
- [ ] `types/<jefe>.lua` (+ `TYPES` en `Entities.lua`)
- [ ] Súbditos: `summons` + reserva en el tipo del súbdito (si hay)
- [ ] `netPackExtra/netApplyExtra`; `Protocol.VERSION` + 1; `version.txt`
- [ ] `boss.<jefe>` en todos los idiomas
- [ ] Arena `tools/levelgen/arenas/make_jefe_<x>.py` + `.json`
- [ ] Nivel real en `levels_boss.py` + `retheme.py` (THEMES, SKY) + `build --only` + retheme
- [ ] `level_solve` y `level_check` OK
- [ ] `<jefe>_rules` (nuevo, en `all`) + `boss_intro` + `boss_sim` + `boss_frames` (mirado) + `sp_boss` + `online_boss`
- [ ] `CLAUDE.md` + `tools/tests/README.md`
- [ ] Commit + push (rama y master)
