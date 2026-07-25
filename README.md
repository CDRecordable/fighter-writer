# Writer Fighter

Juego de lucha 2D en pixel art protagonizado por escritores españoles. El diseño
completo está en [PLAN.md](PLAN.md); esto es el repositorio de desarrollo.

**Estado: Fase 1 — prototipo gris.** El combate funciona con rectángulos de
colores, sin arte. El objetivo de esta fase, tal cual lo fija el plan: *"dos
rectángulos se pegan y ES DIVERTIDO"*. Si no lo es en gris, no lo arregla el
pixel art.

## Arrancar

1. Instalar **Godot 4** (versión estándar, no la de .NET): <https://godotengine.org/download>
2. Abrir Godot → *Import* → elegir `project.godot` de esta carpeta.
3. F5 para jugar.

## Controles

| | Jugador 1 | Jugador 2 |
|---|---|---|
| Moverse / saltar / agacharse | `W A S D` | flechas |
| Puñetazo débil / fuerte | `J` / `K` | `KP1` / `KP2` |
| Patada débil / fuerte | `N` / `M` | `KP4` / `KP5` |
| Especial (solo en modo accesible) | `L` | `KP0` |

Bloqueo: mantener **hacia atrás**, como en SF2. Los barridos hay que bloquearlos
agachado; los golpes de salto, de pie. Los agarres no se bloquean.

Con mando: cruceta o stick izquierdo, `X`/`Y` puños y `A`/`B` patadas. El mando 0
es el jugador 1 y el mando 1 el jugador 2.

**Teclas de desarrollo:** `F1` muestra las cajas (hurtbox azul, hitbox roja,
pushbox verde), `F2` cambia el modo del muñeco de pruebas (Quieto → Bloquea →
Agresiva), `F3` enciende el modo accesible, `F5` reinicia el combate.

## Movimientos de Cristina Morales

| Entrada | Movimiento | |
|---|---|---|
| `→` + puño fuerte, pegado | Agarre | No se bloquea. Fuera de rango sale el puñetazo normal |
| `↓↘→` + puño | **Danza Bruta** | Avanza y golpea tres veces |
| `↓↘→` + patada | **Lectura Fácil** | Lanza el panfleto |
| `↓↙←` + puño | **Asamblea** | Absorbe un golpe y responde con la patada okupa |
| `↓↘→↓↘→` + puño | **Los Combatientes** | Súper. Gasta toda la Tinta |

En **modo accesible** (`F3`) no hacen falta medias lunas: el botón de especial
con la dirección que estés manteniendo. Neutro = Danza Bruta, `↓` = Asamblea,
`↑` = súper. La correspondencia es provisional y hay que probarla con gente no
jugona antes de cerrarla.

## Qué hay implementado

- Simulación a 60 ticks fijos, en punto fijo entero y determinista.
- Movimiento, salto (con jumpsquat y landing lag), agacharse, giro automático.
- 7 golpes normales por personaje con hitboxes **por frame definidas en datos**.
- Bloqueo por dirección con alturas (medio / bajo / overhead), blockstun.
- Daño, hitstun, hitstop, empuje, derribo, medidor de Tinta.
- **Buffer de input**: medias lunas, dobles medias lunas, dragón y cargas, con
  tolerancia a las diagonales. Los botones se guardan unos ticks para que el
  golpe salga en cuanto puedes actuar.
- **Especiales, súper, agarre y contraataque**, todos definidos en datos.
- **Proyectiles** con las mismas reglas de impacto que un puñetazo.
- **Capa de sprites** en datos, con vuelta automática al rectángulo si falta el
  arte, y un generador de hoja provisional derivada de las propias cajas.
- **Escenarios en datos** con capas de parallax y elementos animados.
- **Chispas, polvo y sacudida de cámara**, dibujados a mano sin imágenes.
- Pushboxes, límites de escenario, cámara que sigue a los dos.
- Rondas al mejor de 3, reloj de 99 s, K.O. y victoria por tiempo.
- IA de pruebas determinista (la IA de verdad es de la Fase 3).

**La lista de la Fase 1 está completa.** Lo que queda no es código, es criterio:
el hito real del plan es *"dos rectángulos se pegan y ES DIVERTIDO"*, y eso se
decide jugando. Los números de `fighter.json` son una primera pasada y están para
tocarlos.

## Arte: cómo meter sprites

Un personaje se dibuja desde una **hoja de sprites** en rejilla, declarada en su
`fighter.json`:

```json
"sprites": {
  "sheet": "sprites/cristina_placeholder.png",
  "cell":  { "w": 128, "h": 128 },
  "pivot": { "x": 44, "y": 116 },
  "columns": 8
}
```

Reglas del formato, y son innegociables porque el motor cuenta con ellas:

- **Celdas todas del mismo tamaño**, en rejilla, leídas de izquierda a derecha y
  de arriba abajo empezando en 0.
- El **pivote** es el punto de la celda que se apoya en los pies del personaje.
  Es lo que alinea el dibujo con las hitboxes.
- Todo se dibuja **mirando a la derecha**. El motor voltea; no se dibuja nunca la
  versión espejo (sería el doble de trabajo para nada).

Cada animación dice qué celdas usa y cuánto dura cada una, en ticks:

```json
"animations": { "idle": { "frames": [0,1,2,3], "hold": 8, "loop": true } }
```

y cada movimiento lleva la suya:

```json
"anim": { "frames": [30, 31, 32], "holds": [9, 5, 18] }
```

Las duraciones del dibujo van **desacopladas** de las de las cajas: el artista
puede meter un intercalado sin tocar un hitbox, y el programador puede recortar
frames de recuperación sin pedir un dibujo nuevo. Si las dos sumas no cuadran, el
cargador avisa por consola.

**Si falta la hoja, no pasa nada:** el luchador se dibuja como el rectángulo del
prototipo gris y el juego funciona igual. Arte y programación pueden avanzar por
separado.

### La hoja provisional

`characters/cristina_morales/sprites/cristina_placeholder.png` **no está dibujada
a mano: se genera** a partir de las propias cajas del personaje.

```bash
godot --headless --path . --script res://tools/generar_placeholder.gd
```

La celda de un puñetazo enseña el brazo exactamente donde está el hitbox, y la de
un barrido la pierna donde está el barrido. Sirve para dos cosas: probar la
tubería de arte con algo que no miente sobre lo que hace el motor, y darle al
artista la referencia exacta de qué silueta tiene que cubrir cada celda para que
el golpe sea legible. Cuando entregue su PNG, se sustituye el archivo.

## Escenarios

Un escenario es una carpeta en `stages/`, igual que un personaje:

```
stages/galeon/
  stage.json    capas, parallax, ancho, altura del suelo y créditos
  capas/        las imágenes
```

Cada capa declara su profundidad:

```json
{ "image": "capas/mar_cerca.png", "parallax": 0.55, "y": 52,
  "repeat_x": true, "frames": 4, "hold": 9 }
```

- `parallax`: **1.0** va clavada al mundo (se mueve como el suelo), **0.0** se
  queda pegada a la cámara, o sea infinitamente lejos.
- `y`: a cuántos píxeles del suelo se apoya el **borde inferior** de la imagen.
- `repeat_x`: se teje en horizontal para cubrir el desplazamiento.
- `tint`: tinte multiplicativo. Es la herramienta para meter arte de terceros sin
  editar el PNG — baja el contraste de una capa que canta o la mete en la paleta
  del escenario. **El fondo nunca debe competir con los luchadores.**
- `frames` / `hold`: parte la imagen en una tira de fotogramas y los pasa cada
  `hold` ticks. Es lo que anima las gaviotas o el móvil del barril.

El escenario también manda su **ancho** y la **altura del suelo**, así que un
escenario estrecho y agobiante o uno largo son cosa de datos.

Las capas de ahora están generadas, no dibujadas:

```bash
godot --headless --path . --script res://tools/generar_escenario.gd
```

### Créditos del arte de terceros

Si se usa arte con licencia **CC-BY**, atribuir es una condición de la licencia,
no una cortesía. Por eso los créditos van dentro del `stage.json` (o el
`fighter.json`) que los genera, y no en un documento que alguien recuerda
actualizar:

```json
"credits": [
  { "obra": "...", "autor": "...", "licencia": "CC-BY 4.0",
    "url": "https://...", "cambios": "recortado y repaleteado" }
]
```

```bash
godot --headless --path . --script res://tools/generar_creditos.gd
```

Escribe [CREDITOS.md](CREDITOS.md) y **avisa de los archivos que no declaran
créditos**, para que un asset no se cuele sin atribución.

### Arte que no puede ir en el repositorio

Varias licencias buenas (CC-BY de itch.io, OGA-BY) permiten usar el arte en el
juego pero **prohíben redistribuir los archivos**. Como este repositorio es
público, subir esos PNG sería redistribuirlos.

Esos assets se declaran en [tools/assets_externos.json](tools/assets_externos.json)
—qué se usa, de dónde sale, bajo qué licencia— y los archivos van a
`assets_externos/`, que está en `.gitignore`. Declarar no es redistribuir.

Después de clonar:

```bash
godot --headless --path . --script res://tools/bajar_assets.gd
```

Baja lo que puede y da instrucciones exactas para lo que no (itch.io genera
enlaces temporales por sesión, así que esos hay que bajarlos a mano). Luego hace
falta reimportar:

```bash
godot --headless --path . --import
```

**Un clon sin estos assets arranca igual**: los sprites que falten caen al
rectángulo y las capas que falten se saltan con un aviso. Nadie se queda
bloqueado por no tener el arte.

`generar_creditos.gd` mete en CREDITOS.md los assets externos **que estén
realmente en disco**, porque son los que acaban viajando en la build.

## Pruebas

Prueba de humo del combate, sin ventana (verificada con Godot 4.7.1):

```bash
godot --headless --path . --script res://tests/smoke_test.gd
```

43 comprobaciones: que un golpe pega, que el bloqueo bloquea, que un barrido no
se para de pie, que el salto vuelve al suelo, que los cuerpos no se atraviesan,
que una ronda acaba en K.O., que las medias lunas se reconocen y las falsas no,
que el súper cuesta Tinta, que el agarre atraviesa el bloqueo pero solo a
bocajarro, que el contraataque absorbe… y que **la simulación es determinista**.

Sale con código 1 si algo falla, así que vale tal cual para integración continua.
Pasadla después de tocar el balance: los números de `fighter.json` pueden romper
reglas del motor sin que salte ningún error.

## Estructura

```
characters/<escritor>/     Paquete autocontenido: fighter.json, wiki.json, sprites/
scenes/                    Escenas de Godot
src/core/                  Punto fijo, input, agentes
src/data/                  Carga y modelo de datos de personaje
src/combat/                Luchador, arena de combate, HUD
docs/ARQUITECTURA.md       Por qué está montado así
```

**Añadir un escritor = añadir una carpeta en `characters/`.** Esa es la regla que
hace que un DLC sea una carpeta y no una refactorización (PLAN.md §7).

## Antes de tocar el balance

Ni una constante de combate vive en el código: daño, frames, empujes y cajas
están en `characters/<escritor>/fighter.json`. Se edita ahí y se prueba con `F1`
activado para ver el efecto en las cajas.
