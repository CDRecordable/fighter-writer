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

Bloqueo: mantener **hacia atrás**, como en SF2. Los barridos hay que bloquearlos
agachado; los golpes de salto, de pie.

Con mando: cruceta o stick izquierdo, `X`/`Y` puños y `A`/`B` patadas. El mando 0
es el jugador 1 y el mando 1 el jugador 2.

**Teclas de desarrollo:** `F1` muestra las cajas (hurtbox azul, hitbox roja,
pushbox verde), `F2` cambia el modo del muñeco de pruebas (Quieto → Bloquea →
Agresiva), `F5` reinicia el combate.

## Qué hay implementado

- Simulación a 60 ticks fijos, en punto fijo entero y determinista.
- Movimiento, salto (con jumpsquat y landing lag), agacharse, giro automático.
- 7 golpes normales por personaje con hitboxes **por frame definidas en datos**.
- Bloqueo por dirección con alturas (medio / bajo / overhead), blockstun.
- Daño, hitstun, hitstop, empuje, derribo, medidor de Tinta.
- Pushboxes, límites de escenario, cámara que sigue a los dos.
- Rondas al mejor de 3, reloj de 99 s, K.O. y victoria por tiempo.
- IA de pruebas determinista (la IA de verdad es de la Fase 3).

Pendiente de esta fase: agarres, especiales con entradas de mando (medias lunas
y cargas), buffer de input y súper.

## Pruebas

Prueba de humo del combate, sin ventana (verificada con Godot 4.7.1):

```bash
godot --headless --path . --script res://tests/smoke_test.gd
```

Comprueba que un golpe pega, que el bloqueo bloquea, que un barrido no se para
de pie, que el salto vuelve al suelo, que los cuerpos no se atraviesan, que una
ronda acaba en K.O. y que **la simulación es determinista**. Sale con código 1 si
algo falla, así que vale tal cual para integración continua. Pasadla después de
tocar el balance: los números de `fighter.json` pueden romper reglas del motor
sin que salte ningún error.

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
