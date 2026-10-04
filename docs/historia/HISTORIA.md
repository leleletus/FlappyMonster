# La historia de Flappy Monster: «El Espejo Roto»

Plan aprobado por el usuario (2026-10-03). Este documento es la referencia de la historia; el guion gráfico sale de
`tools/story/storyboard.py` (la tabla de escenas de abajo se genera con `--md`; no editarla a mano).

## Premisa

El monstruo sabía **aletear** (el modo Flappy). Un día vuela hasta un espejo antiguo escondido en el volcán y choca
con él: el cristal se rompe en **siete fragmentos**.

- Su **Reflejo** sale del marco, le roba el aleteo y se queda en el volcán con el fragmento del centro. Por eso la
  aventura es a pie (solo salto doble).
- Los otros seis fragmentos caen por las islas. Quien encuentra uno **crece y se enfurece** («la furia del espejo»):
  por eso cada jefe es la versión gigante de un enemigo normal.

Cada jefe vencido suelta su fragmento; con los siete el espejo se restaura, el Reflejo vuelve dentro, la furia se
apaga (los jefes encogen) y el monstruo **recupera el aleteo**.

## Los fragmentos (`assets/images/story/mirror/`, de `tools/ui/make_mirror_shards.py`)

Todas las imágenes comparten un lienzo de 48x64: dibujadas en el mismo punto, encajan y el espejo se va completando.

| Nº | Jefe | Nivel | Posición en el espejo |
|---|---|---|---|
| 1 | Rey Gummy | reino_gummy | arriba-izquierda |
| 2 | Mega Crabby | guarida_cangrejo_rey | arriba-derecha |
| 3 | Nave Malvada | fortaleza_malvada | derecha |
| 4 | Gran Bola de Nieve | lago_helado | abajo-derecha |
| 5 | Mega Crabby helado | glaciar_cangrejo | abajo-izquierda |
| 6 | Mega Crabby lúgubre | gruta_lugubre | izquierda |
| 7 | El Espejo | ruta_del_espejo | centro (donde chocó) |

- `frame.png` (marco), `glass.png` (cristal entero, sin grietas), `shard_1..7.png`.
- **Xtra Extremo**: `shard_<n>a.png` / `shard_<n>b.png`, cada fragmento partido en dos (uno por cada jefe de la
  pareja). Contador del mapa: 14 mitades.

## Guion gráfico

Bocetos: `FlappyMonster_pruebas/historia/storyboard_intro.png` y `storyboard_final.png`. Sin diálogos ni texto: todo
se cuenta con imagen, sonido y música.

### Intro (50.0 s)

| Escena | Tiempo | Qué se ve | Sonido y música |
|---|---|---|---|
| **I1** Un día cualquiera | 0.0–6.0 s | El monstruo ALETEA entre las tuberías (el modo Flappy), feliz. Cielo azul. | Música: tema del juego, ligero ("la llamada"). Aleteos. |
| **I2** El destello | 6.0–11.0 s | Atardecer: algo brilla dentro del volcán. Curioso, vuela hacia allí. | La música se queda en una nota; un brillo (campanita). |
| **I3** El espejo antiguo | 11.0–17.0 s | Dentro del cráter: un espejo dorado. Se acerca; su reflejo lo imita. | Caja de música: "la llamada" y su eco INVERTIDO (el reflejo). |
| **I4** ¡CRAC! | 17.0–19.5 s | Aletea demasiado cerca y choca. Destello blanco: el cristal se parte en 7. | Silencio de medio segundo → golpe + cristal roto. Corte seco. |
| **I5** El Reflejo sale | 19.5–25.5 s | Del marco vacío sale su reflejo (colores invertidos). Los fragmentos flotan. | Entra el motivo del Espejo (grave, 12/8). Tintineo de cristales. |
| **I6** Le roba las alas | 25.5–31.5 s | El Reflejo le quita el ALETEO, se ríe y se guarda el fragmento del centro. El monstruo salta... y cae. | Risa del Espejo. Golpe sordo al caer (sin alas). |
| **I7** Seis fragmentos, seis islas | 31.5–37.5 s | El Reflejo lanza los otros seis: cruzan el cielo y caen uno en cada isla (el mapa). | Seis notas descendentes, una por fragmento. |
| **I8** La furia del espejo | 37.5–44.5 s | Quien encuentra un fragmento crece y se enfurece: Rey Gummy, Mega Crabby, la Nave, la Bola, el helado, el lúgubre. | Seis golpes de timbal, uno por jefe; crece. |
| **I9** A pie | 44.5–50.0 s | El monstruo, en la orilla de la Pradera, mira el volcán a lo lejos... y echa a andar. → MAPA. | La llamada, decidida, en trompeta: enlaza con la música del mapa. |

### Final (55.0 s)

| Escena | Tiempo | Qué se ve | Sonido y música |
|---|---|---|---|
| **F1** El Espejo cae | 0.0–4.0 s | En el juego: el jefe Espejo, vencido, cae y suelta el ÚLTIMO fragmento (no hay meta que tocar). | Se corta la música del jefe. Cristal. |
| **F2** Los siete | 4.0–9.0 s | El monstruo lo recoge: los siete fragmentos salen y giran a su alrededor. | Caja de música: la llamada, despacio. Un tintineo por fragmento. |
| **F3** Pieza a pieza | 9.0–17.0 s | Vuelan al marco y encajan uno a uno, en el orden en que se ganaron (el del centro, el último). | Siete notas ASCENDENTES (la escala de la llamada), una por pieza. |
| **F4** El espejo, entero | 17.0–20.0 s | La última pieza: destello. Las grietas se borran. | Acorde mayor lleno + platillo. |
| **F5** El Reflejo vuelve | 20.0–25.0 s | El espejo tira del Reflejo: vuelve dentro, rabiando, y suelta lo que robó. | El motivo del Espejo, al revés (= la llamada). Succión. |
| **F6** La luz recorre las islas | 25.0–32.0 s | Del cráter sale una onda de luz que barre el mapa, isla a isla: LA FURIA DEL ESPEJO se apaga. | Tema del mapa, a pleno. Seis campanas. |
| **F7** Todos, pequeños otra vez | 32.0–39.0 s | Los jefes encogen: un Gummy con una corona enorme, un Crabby, la nave diminuta, una bolita... | Seis "pop" cómicos sobre la música. |
| **F8** Las alas | 39.0–46.0 s | Ante el espejo, su reflejo ya es solo eso. Prueba: un aleteo... dos... ¡se eleva! | Pausa. Aleteo, aleteo → la llamada completa, por fin resuelta. |
| **F9** Volando a casa | 46.0–55.0 s | Sale del cráter y vuela sobre las islas al amanecer; vuelven las tuberías. Logo. FIN → créditos. | Tema del juego a pleno; termina con el aleteo. |

## Pendiente de decidir (usuario)

1. El nombre de la amenaza: aquí «la furia del espejo» (lo que agranda y enfurece a quien toca un fragmento).
2. La Nave Malvada: ¿su piloto encontró un fragmento como los demás (así está en el guion) o es un esbirro del Reflejo?
3. Duraciones (intro 50 s, final 55 s) y si la intro se puede saltar (propuesta: sí, manteniendo pulsado).

## Orden de trabajo (del usuario)

1. Texturas de los fragmentos ✔ (a falta de su visto bueno).
2. Guion gráfico ✔ (bocetos; a falta de su visto bueno).
3. Con el guion aprobado: tiempos exactos, qué hay en pantalla en cada escena y transiciones.
4. Música compuesta SOBRE esos tiempos (nunca al revés), sprites de las escenas, efectos y sonidos sincronizados.
5. En el juego: cada jefe suelta su fragmento al morir, el jugador lo recoge y se guarda en la partida; el mapa
   muestra «Fragmentos: n / 7» (Xtra: n / 14); vencer al Espejo lanza el final sin tocar la meta.
