# Guía musical de Flappy Monster

Estudio de la banda sonora que hay (octubre de 2026) y la BASE para componer lo que falta. Los números salen de
`tools/music/study.py` (los .mid de `tools/music/mid/`) y de medir los .ogg con librosa (tempo, centroide, ataques
por segundo, dinámica, parte percusiva). **Nada de esto se ha escuchado: son medidas.** Lo que diga el oído del
autor del juego manda sobre cualquier número de aquí.

## 1. Qué hay ahora

| Pista | Uso | Tempo | Tonalidad (medida) | Forma | Carácter medido |
|---|---|---|---|---|---|
| `menus` | menús | 140 | La menor / Do mayor | 18 compases | bajo de boogie, acordes de sexta, giro de blues (descenso cromático) |
| `map_<mundo>` ×6 | mapa del mundo | 120 | Do mayor | A-B-A, 24 compases, 48 s | una melodía, seis arreglos; cada isla, su instrumento y su motivo |
| `fortaleza_1` | nivel (Fortaleza) | 137,5 | Do menor | 36 compases, 63 s | saltos de 7ª/8ª que rebotan, arpegios en semicorcheas, muy denso (dinámica 3,9 dB) |
| `cuevas_oscuras` | nivel a oscuras | 72 | Re menor (acaba en La, sin resolver) | A A' B A'', 32 compases | caja de música con eco sobre bordón y latido; 2,6 ataques/s, 6 % percusivo |
| `boss_generic` | jefe genérico | 148 | Do menor | intro 4 + bucle 36 | las notas de `fortaleza_1` con timbres de jefe y batería "industrial" |
| `crab_tantrum_normal` | Mega Crabby | 185 (se siente a 92,5: tresillo 3+3+2) | Sol menor | 72 compases ×2 | melodía por grados (67 %), notas repetidas (26 %), bombo en tresillo |
| `crab_tantrum_icy` | Mega Crabby helado | 185 | Sol menor → Fa mayor (sección de invierno) | 172 compases | lo anterior + caja de música, cascabeles, arpegios 16ª constantes (8,8 notas/s) |
| `crab_tantrum_gloomy` | Mega Crabby lúgubre | 150 | Sol menor | intro 4 + 72 | menos cargada; "patas" en semicorcheas de pulso 12,5 %, silencios al cerrar frase |
| `snowball_boss` | Gran Bola de Nieve | 185 | Fa mayor | 144 compases | caja de música, arpegios, crece por DENSIDAD (dinámica 8,8 dB) |
| `mirror_boss` (+ `_inst`) | Jefe Espejo | 92,5 (3+3+2) | Sol menor | 36 compases ×2 | melodía NUEVA sobre un motivo de nota vecina (Sol–Fa#–Sol), skank a contratiempo |

Huecos sin música todavía: `pradera_1/2`, `costa_1/2`, `fortaleza_2`, `nieve_1/2`, `cuevas_1`, `volcan_1/2`, `victory`.

### OJO: de dónde viene cada melodía
Las pistas prestadas se quitaron, pero **varias de las que quedan son arreglos de esas melodías**:
- `crab_tantrum_normal / icy / gloomy`: la melodía y el bajo son los de *Tentacle Tantrum* nota a nota.
- `snowball_boss` (y la sección central de `crab_tantrum_icy`): *Winter Fallympics*.
- `fortaleza_1` y `boss_generic`: la canción de nivel original (`level.ogg`, de su MIDI).
- Propias de verdad: `menus` (del autor), `map_*`, `cuevas_oscuras`, `mirror_boss`.
Si las prestadas se quitaron por ser de otros, esos arreglos tienen el mismo problema: habría que decidir si se
quedan o si se les compone una melodía propia conservando el arreglo (que sí es nuestro).

## 2. Qué hace que suene a Flappy Monster

**Sonido.** Todo es Famicom "con chips de expansión" (`tools/music/famicom.py`): 2A03 (dos pulsos, triángulo, ruido,
DPCM) + VRC6 (dos pulsos y una sierra) + Namco 163 (tablas de onda). Sin samples reales ni reverb de estudio: el
eco es un retardo, la batería es DPCM de 1 bit y ruido.

**Reparto de papeles que se repite en todas:**
- MELODÍA: tabla de onda del N163 o pulso con barrido de ciclo (12,5 → 50 %) y vibrato en las notas largas; para
  dar fuerza, se dobla con la sierra del VRC6 o un pulso una octava arriba (nunca con otra melodía).
- BAJO: triángulo; en lo movido, corcheas con octavas; en lo tranquilo, blancas o un bordón.
- ACOMPAÑAMIENTO: acordes cortos a contratiempo ("skank"), arpegios en semicorcheas, o colchón del N163.
- BATERÍA: bombo DPCM, caja = ruido corto + cuerpo DPCM, platos de ruido; ruido en modo corto = "metal".
- COLOR por ambiente: caja de música (N163 con parciales de campana), cascabeles (ruido corto), gotas (pulso con
  caída de tono), steel drum (N163 brillante), "patas" (pulso 12,5 % muy corto).

**Ritmo.** Es lo más propio: casi todo va en semicorcheas seguidas y **entre el 56 y el 76 % de las notas de la
melodía caen fuera del tiempo fuerte**. Dos sellos: el **tresillo 3+3+2** (Crab Tantrum, Espejo) y los acordes a
contratiempo. Tempos altos: nivel ~138, menús 140, jefes 148-185; solo el mapa (120) y la cueva (72) bajan.

**Melodía.** Células que comparten varias pistas (medido):
- la **subida pentatónica** 2-2-3 semitonos (en 4 pistas) y sus vecinas 2-3-2;
- **arpegio del acorde** que sube 4-3-5 / 5-4-3 en semicorcheas (3 pistas);
- **saltos que rebotan** de 6ª-7ª arriba y abajo (+9 −9 +9, +10 −10 +10) en las de nivel/jefe;
- **nota vecina** (Sol–Fa#–Sol) y el **descenso cromático** del giro de blues de los menús.
Frases de 8 compases; pregunta-respuesta; la respuesta suele ser la pregunta en secuencia (un grado o una tercera
más arriba o abajo).

**Armonía.** Menor para peligro (Sol menor, Do menor, Re menor), mayor para sitio seguro (Do mayor mapa y menús, Fa
mayor nieve). Progresiones cortas y diatónicas (i–VI–iv–V, I–V–vi–V, IV–IV–V–V antes de un estribillo), con UN giro
oscuro por pieza (la napolitana ♭II en la cueva, la blue note ♭5 en las patas). Acordes de potencia solo si la
quinta está en la armonía.

**Forma.** Intro corta (4 compases) → A (8) → A' → B que contrasta → vuelta; bucle sin costura (la cola se suma al
principio). Las piezas largas crecen por **densidad** (más capas, platos, octavas), no por volumen. Un silencio o
medio compás vacío antes de la entrada fuerte.

**Mezcla** (lo que ya se aprendió, ver CLAUDE.md): melodía 10-30 % de la energía, batería hasta ~40 % en jefes;
nada tapa la melodía en 1-5 kHz; −11 LUFS nivel, −10 jefes, −13 ambiente; pico 0,8.

## 3. La base para lo nuevo

### El motivo del juego: "la llamada"
La melodía del mapa ("Rumbo a las islas") empieza subiendo por el acorde: **Sol–Do–Mi–Sol** (5ª–1ª–3ª–5ª) y
se posa. Es lo único propio que el jugador oye en todo el juego (entre nivel y nivel), así que se propone como
**leitmotiv del juego**: cada música de mundo lo cita una vez (al empezar el tema o al cerrar la frase B), en su
tonalidad y con su instrumento. Así el mapa y los niveles son la misma música.

### Identidad por isla (la paleta ya está estrenada en su arreglo del mapa)

| Isla | Tonalidad / modo | Tempo | Melodía | Ritmo y batería | Motivo propio |
|---|---|---|---|---|---|
| Pradera | Sol o Do mayor | 132-140 | pulso cantarín | bajo saltarín (1-5-8-5), acordes a contratiempo, batería ligera | trino de pájaro |
| Costa | Fa mayor (mixolidio a ratos) | 116-126 | steel drum | bajo de calipso (1, 1y, 3), maraca en semicorcheas | marimba que sube |
| Fortaleza | Do menor | 138-148 | sierra + pulso | marcha: redobles de caja, bajo en octavas, "metal" | fanfarria de tresillos |
| Cumbres | Fa mayor / Re menor | 144-160 | caja de música una octava arriba | cascabeles, bajo en blancas, colchón | campanitas que caen |
| Cuevas | Re menor dórico | 96-110 (72 a oscuras) | caja de música con eco | medio tiempo, bombo grave, sin platos | gotas |
| Volcán | Mi o La menor frigio (♭II) | 156-168 | sierra + pulso a la octava | bajo en corcheas, doble bombo, tresillo 3+3+2 | golpes de "erupción" |

### Qué pista es cada hueco
- `<mundo>_1` = el TEMA del mundo: el más melódico, para los primeros niveles.
- `<mundo>_2` = su segunda cara, misma tonalidad y motivo: más tensa (niveles difíciles, cámara automática) o más
  tranquila (niveles de explorar / agua), según la isla.
- **Bonus de la isla** (propuesta nueva): `<mundo>_bonus`, un arreglo corto y rápido (~+12 % de tempo) del tema
  `_1` con batería de "competición" — suena en la arena de Rey de la Colina de esa isla.
- Jefes: se quedan como están (a falta de decidir lo de las melodías prestadas).
- `victory`: sintonía de 4-6 s con "la llamada" completa resolviendo en la tónica.

### Reglas de composición (para que todo sea del mismo juego)
1. Una idea por pieza: un motivo de 2 compases, que se repite en secuencia y vuelve. No más de dos temas.
2. La melodía, cantable: sobre todo grados conjuntos y las células de la casa (subida pentatónica, arpegio que
   sube, salto que rebota); las notas largas, siempre del acorde.
3. Más de la mitad de las notas, a contratiempo; al menos un compás con el tresillo 3+3+2.
4. Citar "la llamada" una vez, sin forzarla: en un sitio con SU acorde (no injertarla en otra armonía).
5. Un solo giro oscuro por pieza. Nada de transportar una melodía conocida "para oscurecerla".
6. Crecer por capas; un respiro antes de cada entrada fuerte; bucle sin costura.
7. Instrumentos: los de la tabla de su isla; el resto del reparto, el de siempre (triángulo, DPCM, ruido).
8. Comprobar con números antes de darla por buena: duración y bucle, LUFS, reparto de energía, melodía sin tapar,
   y que el .mid diga la tonalidad y el tempo previstos (`study.py`).

## 4. Herramientas
- `tools/music/famicom.py`: el motor (canales, instrumentos por fotograma, DAC, `master`, `out`, `ref`).
- `tools/music/worldmap_nes.py`: el mejor punto de partida para una pieza nueva (melodía como lista de notas,
  acordes por compás, un arreglo por isla, mezcla por grupos).
- `tools/music/study.py`: tonalidad, ámbito, intervalos, síncopa y células de cualquier .mid.
- `~/.venvs/fm-music` (librosa, pyloudnorm, mido, demucs, basic-pitch) para medir audio.
- Límite: no hay oído. Cada pieza debería salir con 2-3 variantes cortas para que elija el autor.
