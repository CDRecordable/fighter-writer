# Arquitectura — por qué está montado así

Notas de las decisiones que costaría deshacer más adelante. Lo que no está aquí
es porque se puede cambiar sin dolor.

## 1. La simulación es entera y determinista

Toda la física del combate se calcula con enteros en punto fijo (`src/core/fp.gd`,
1 píxel = 256 unidades), no con `float` ni con `CharacterBody2D`.

Dos motivos, uno de hoy y uno de mañana:

- **Hoy:** un bug de combate se reproduce exactamente. Mismo estado + mismos
  inputs = mismo resultado, siempre. En un juego de lucha, donde los fallos son
  de un frame, esto es la diferencia entre depurar y adivinar.
- **Mañana:** el online con rollback del backlog (PLAN.md §11) exige una
  simulación determinista y re-ejecutable. El plan ya avisa de que la decisión
  se toma en la Fase 1 — está tomada. Meterlo después obligaría a reescribir
  todo el movimiento.

Coste: hay que pensar en unidades fijas y evitar `float` en la lógica. Los únicos
`float` legítimos están en el render y en el HUD.

## 2. La arena es el reloj, el luchador no

`Fighter` no tiene `_physics_process()`. La arena llama, en orden fijo:

1. `update_facing()` de los dos
2. `tick_input()` de los dos
3. `tick_simulate()` de los dos
4. empujes → límites de escenario → detección de golpes

Los golpes de ambos se **buscan antes de aplicar ninguno**. Si se aplicaran sobre
la marcha, el primero en procesarse metería al otro en hitstun y le anularía su
golpe: los intercambios simultáneos desaparecerían y el jugador 1 ganaría todos
los cruces. Con este orden, un trade es un trade.

## 3. Los datos mandan sobre el código

Un personaje es una carpeta en `characters/`:

```
characters/cristina_morales/
  fighter.json   stats + movimientos + cajas por frame
  wiki.json      ficha de la Biblioteca
  sprites/
```

No hay ninguna lista central de personajes: `CharacterLoader` escanea la carpeta.
Añadir a Cela, o publicar un DLC de Lorca, es añadir un directorio.

**Convenio de cajas** (el mismo en todo el proyecto):

- Origen entre los pies, centrado.
- `x` crece **hacia delante** según el facing → una caja se escribe una vez y
  vale mirando a los dos lados.
- `y` crece **hacia arriba** desde el suelo.
- Píxeles enteros de la resolución interna (480×270).

Por qué JSON y no `.tres`: se lee y se diffea en Git, el artista puede tocarlo
sin abrir Godot, y no arrastra dependencias del motor cuando la wiki se use fuera
del combate.

## 4. Nadie lee `Input` directamente

Los luchadores reciben un `FighterInput` por tick de un `Agents.Agent`. Detrás
puede haber un teclado, la IA o —en el futuro— un replay grabado.

Esto abarata tres cosas del plan de golpe: el VS local a dos jugadores es cambiar
un agente por otro, la IA por niveles de la Fase 3 es añadir agentes, y grabar
un combate es guardar la lista de inputs.

Detalle importante: el flanco de "botón recién pulsado" se calcula comparando con
el tick anterior, **no** con `is_action_just_pressed()`. Ese método razona en
frames de render; si el render se salta un tick de simulación, el golpe se
perdería.

## 5. El mapa de controles vive en código

`src/core/input_setup.gd` (autoload `Controles`) registra las acciones al
arrancar, en vez de guardarlas en `project.godot`.

Godot serializa los eventos de input como blobs `Object(InputEventKey, ...)`
ilegibles: cualquier cambio de controles produce un diff imposible de revisar y
propenso a conflictos de merge. En código es una tabla legible, y el remapeo de
la Fase 4 se construye encima sin tocar el motor.

## 6. Resolución y render

480×270 interno con escalado entero (PLAN.md §7) y filtro *nearest*. Las
posiciones se redondean al píxel al dibujar (`FP.floor_px`): sin eso el pixel art
vibra al moverse, que es el defecto más típico de un 2D mal configurado.

## 7. Lo que es deliberadamente provisional

Esto se tira sin pena cuando llegue su fase:

- `CombatHUD` — dibujado a mano; lo sustituye el marco del artista en la Fase 2.
- El fondo de la arena (`_draw()` de `combat_arena.gd`) — es el escenario del
  galeón el que va ahí.
- `Agents.Dummy` — muñeco de pruebas, no un rival.
- El balance de `fighter.json` — números de primera pasada.

## 8. Lo que falta para cerrar la Fase 1

- Agarres (el plan los pide en la v1).
- Entradas de especiales: medias lunas y cargas, con **buffer de input**
  (imprescindible: sin buffer los especiales se sienten rotos).
- Un especial de prueba de cada tipo de entrada.
- Súper con gasto del medidor de Tinta.
- Combos por enlace natural de frames: comprobar que los frame data actuales
  permiten 2-3 enlaces reales.
