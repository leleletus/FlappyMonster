# La historia de Flappy Monster: «El Espejo Roto»

Plan aprobado por el usuario (2026-10-03). Este documento es la referencia de la historia.

## Premisa

El monstruo sabía **aletear** (el modo Flappy). No tiene alas: aletea por una **magia** suya. Un día vuela hasta un
espejo antiguo escondido en el volcán y choca con él: el cristal se rompe en **siete fragmentos**.

- Su **Reflejo** sale del marco, le roba el aleteo y se queda en el volcán con el fragmento del centro. Al monstruo
  solo le queda lo que puede hacer físicamente y la poca magia que le resta: el **doble salto**. Por eso la aventura
  es a pie.
- Los otros seis fragmentos caen por las islas. Quien encuentra uno **crece y se enfurece**: es **LA FURIA DEL
  ESPEJO**, y por eso cada jefe es la versión gigante de un enemigo normal (el piloto de la Nave Malvada encontró
  el suyo como los demás).

Cada jefe vencido suelta su fragmento; con los siete el espejo se restaura, el Reflejo vuelve dentro, la furia se
apaga (los jefes encogen) y el monstruo **recupera el aleteo**.

## Los fragmentos

Imágenes: `assets/images/story/mirror/` (de `tools/art/story/make_mirror_shards.py`); todas comparten un lienzo de 48x64:
dibujadas en el mismo punto, encajan y el espejo se va completando. Lógica: `src/story/Shards.lua`.

| Nº | Jefe | Nivel | Posición en el espejo |
|---|---|---|---|
| 1 | Rey Gummy | reino_gummy | arriba-izquierda |
| 2 | Mega Crabby | guarida_cangrejo_rey | arriba-derecha |
| 3 | Nave Malvada | fortaleza_malvada | derecha |
| 4 | Gran Bola de Nieve | lago_helado | abajo-derecha |
| 5 | Mega Crabby helado | glaciar_cangrejo | abajo-izquierda |
| 6 | Mega Crabby lúgubre | gruta_lugubre | izquierda |
| 7 | El Espejo | ruta_del_espejo | centro (donde chocó) |

- En el nivel: al caer el jefe, su fragmento sale de él y se queda flotando; el jugador lo recoge tocándolo (si a los
  5 s nadie lo ha recogido, va él hacia el jugador; si se toca la meta antes, se recoge solo). Queda guardado en la
  partida al momento. Un jefe ya vencido con su fragmento recogido no lo vuelve a soltar.
- **Xtra extremo** (dos jefes por arena): cada uno suelta MEDIO fragmento (`3a` el original, `3b` la copia): 14 mitades.
- El mapa muestra el espejo con los fragmentos que se llevan y la cuenta («Fragmentos del espejo 4 / 7»; Xtra: n / 14).
- El del jefe Espejo es el último: al recogerlo el jugador se queda quieto, la pantalla se va a blanco y empieza el
  FINAL, sin tocar la meta; después, la pantalla de resultados de siempre.

## Las cinemáticas

Las dibuja el JUEGO, en el momento, con sus sprites, fondos, decorados y efectos (nada pregrabado): `src/story/Film.lua`
(el reproductor), `src/story/Stage.lua` (las piezas), `src/story/films/intro.lua` y `ending.lua` (las escenas),
`src/states/story/StoryFilmState.lua` (el estado; se saltan MANTENIENDO pulsado un botón o el dedo 1 s). Sin texto.

- **Tiempos: `assets/story/films.json`** — cada escena dura `beats` pulsos a `bpm`, con sus momentos (`cues`). Es la
  única fuente: el juego dibuja con ella y la música (`tools/music/story_music.py`) se compone SOBRE ella. Cambiar un
  tiempo = volver a generar la música.
- Decorado del cráter: `assets/story/sets/crater.json`, un nivel de verdad (`tools/levelgen/make_sets.py`; se abre en el
  editor). El mapa del mundo también hace de decorado (`StoryMapState:filmDraw`).
- Con su música sonando, el reloj de la película es el de la música.
- Capturas de cada escena: `tools/tests/run.sh story_film` (hojas en `FlappyMonster_pruebas/historia/`).

### Intro (al crear una partida) — 51.8 s

| Escena | Tiempo | Qué se ve | Música y sonido |
|---|---|---|---|
| `flappy` Un día cualquiera | 0.0–7.3 s | El monstruo ALETEA entre las tuberías: el modo Flappy de verdad (su fondo, sus tuberías, su jugador, pilotado). | Su tema («Rumbo a las islas», que empieza con la llamada), ligero. Cada aleteo suena. |
| `glint` El destello | 7.3–12.7 s | Las tuberías se acaban; algo brilla a lo lejos; el fondo del Flappy se deshace en el cielo del volcán y va hacia el cráter. | El tema se queda colgado; dos campanas (el destello); el bajo se oscurece. |
| `mirror` El espejo antiguo | 12.7–18.4 s | Baja por la chimenea del cráter (decorado: un nivel de verdad). Un espejo dorado; su reflejo lo imita. | Caja de música: la llamada… y el espejo la devuelve AL REVÉS. |
| `crash` ¡CRAC! | 18.4–21.3 s | Aletea demasiado cerca y choca: destello, temblor, el cristal partido en siete. | Dos latidos, un trémolo… y el golpe (cristal). |
| `reflex` El Reflejo sale | 21.3–26.3 s | Los fragmentos flotan alrededor del marco vacío; dentro aparece su REFLEJO (colores invertidos) y salta fuera. | Bordón grave al galope; el motivo del espejo; al plantarse, la cabeza del tema del jefe Espejo. |
| `steal` Le roba el aleteo | 26.3–33.8 s | El Reflejo le arranca el aleteo (un orbe de magia), sube aleteando y se ríe; se queda el fragmento del centro. El monstruo lo intenta: salta, un segundo salto… y cae. El Reflejo lo echa todo del cráter. | La llamada, arrancada, se desinfla; el Reflejo la canta con su voz; la risa; redoble. |
| `scatter` Seis fragmentos | 33.8–38.8 s | En el mapa: los seis fragmentos (y el monstruo) cruzan el cielo desde el volcán y caen uno a uno. | Seis campanas que BAJAN, una por fragmento. |
| `fury` La furia del espejo | 38.8–45.8 s | Uno a uno, de cerca: quien encuentra un fragmento crece y se enfurece. Luego, todas las islas, enrojecidas. | Seis golpes que SUBEN, uno por jefe; la dominante con redoble. |
| `onfoot` A pie | 45.8–51.8 s | El monstruo cae en la Pradera. Se levanta, intenta aletear (solo un saltito)… y echa a andar. → MAPA. | Silencio; la llamada no le sale; y entonces sí, decidida: enlaza con la música del mapa. |

### Final (al recoger el último fragmento) — 52.5 s

| Escena | Tiempo | Qué se ve | Música y sonido |
|---|---|---|---|
| `seven` Los siete | 0.0–5.7 s | En el cráter, ante el marco vacío: los fragmentos salen y giran a su alrededor (Xtra extremo: las 14 mitades). | La llamada en la caja de música; arpegios que suben. |
| `pieces` Pieza a pieza | 5.7–15.7 s | Vuelan al marco y encajan uno a uno, en el orden en que se ganaron (el del centro, el último). | Siete notas que SUBEN la escala, una por fragmento (las mismas que canta el efecto al encajar). |
| `whole` El espejo, entero | 15.7–18.2 s | Destello: las grietas se borran; rayos de luz. | El acorde entero y la llamada, deprisa, en lo alto. |
| `return` El Reflejo vuelve | 18.2–23.2 s | El espejo tira del Reflejo, que entra pataleando; del cristal sale lo que robó: el orbe del aleteo. | Su tema se deshace hacia abajo; el golpe; dos notas de la llamada. |
| `light` La luz recorre las islas | 23.2–29.2 s | En el mapa: una onda de luz sale del volcán y llega a cada isla: la FURIA DEL ESPEJO se apaga. | El tema del mapa, a pleno; una campana por isla. |
| `shrink` Pequeños otra vez | 29.2–36.2 s | Uno a uno, de cerca: los jefes encogen (el Gummy, ya sin corona). | El tema sigue, juguetón; un «pop» por jefe. |
| `flap` El aleteo | 36.2–43.4 s | El orbe vuelve al monstruo. Prueba: un aleteo… dos… y sube sin parar hasta salir por la chimenea; su reflejo, ya solo un reflejo, lo imita. | Silencio; con cada aleteo, una nota más de la llamada; y sube. |
| `home` Volando a casa | 43.4–52.5 s | Vuela sobre el volcán; el cielo vuelve a ser el del modo Flappy, vuelven las tuberías; el logo. | El tema entero; con el logo, el acorde final y la llamada en campanas. |

## Hecho y pendiente

Hecho (3.68.0): fragmentos (imágenes, recogida, guardado, contador del mapa), las dos cinemáticas en el juego, sus
efectos de sonido (`tools/sounds/story.py`) y su música, el final sin tocar la meta.

Pendiente de la opinión del usuario (no se ha visto en movimiento ni escuchado: solo capturas y números): el ritmo
de cada escena, los encuadres, la música. Los sprites de las escenas son los del juego; si alguna pide un dibujo
propio (el Reflejo saliendo del marco, los jefes pequeños antes de crecer), se añade.
