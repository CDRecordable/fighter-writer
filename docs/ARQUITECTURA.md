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

## 5. El buffer de input es una pieza de diseño, no una optimización

`src/core/input_buffer.gd` guarda los últimos 48 ticks de dirección y pulsación
por luchador. Hace tres cosas que el jugador nota aunque no sepa nombrarlas:

**Guarda las direcciones en notación numpad relativa al facing.** 6 es siempre
"hacia el rival", así que la misma media luna vale mirando a los dos lados y no
hay ni una rama de código que dependa de la orientación.

**Perdona las diagonales.** Un ↓↘→ se busca primero completo y, si falla, otra
vez sin las diagonales. A mucha gente le sale ↓→ y rechazarlo solo hace el juego
más hostil, no más profundo — que importa especialmente en un juego cuya mitad es
educativa.

**Guarda el botón 8 ticks.** Sin esto, pulsar un par de frames antes de
recuperarte de un golpe no saca nada y el juego parece que ignora al jugador. Con
esto, el movimiento sale en cuanto puede salir. `BUTTON_LENIENCY` es la perilla
de generosidad del juego.

Detalle que costó encontrar: **durante el hitstop el buffer no envejece**. El
hitstop congela a los dos luchadores, y es justo el momento en que el jugador
prepara el siguiente golpe; si el historial siguiera corriendo, esa pulsación
caducaría antes de poder usarse. Durante la congelación solo se anota lo que se
pulsa, sin avanzar el historial.

## 6. El orden en que se prueban los movimientos

`FighterStats.command_moves` está ordenado por dificultad de entrada, de más a
menos, y se prueba antes que los normales. El orden no es estético:

- Si el 236 se probara antes que el 236236 que lo contiene, **el súper no saldría
  nunca**.
- Si los normales se probaran antes que los comandos, pulsar puño se comería
  siempre al especial que empieza por ese mismo puño.

El agarre entra en el mismo esquema: es un movimiento de comando (`→` + puño
fuerte) con `max_range`. Fuera de rango no arranca y el botón cae al puñetazo
normal, exactamente como en SF2.

## 7. Un golpe es un golpe, venga de donde venga

`HitProperties` (daño, hitstun, blockstun, hitstop, altura, empuje, Tinta) es la
clase base tanto de `MoveData` como de `ProjectileData`. Por eso
`Fighter.receive_hit()` no necesita saber si le ha pegado un puño o un panfleto:
las reglas de bloqueo, aturdimiento y empuje son literalmente el mismo código.

Cuando lleguen los especiales de Reverte o de Cela, cualquier cosa nueva que
golpee solo tiene que heredar de aquí.

## 8. El mapa de controles vive en código

`src/core/input_setup.gd` (autoload `Controles`) registra las acciones al
arrancar, en vez de guardarlas en `project.godot`.

Godot serializa los eventos de input como blobs `Object(InputEventKey, ...)`
ilegibles: cualquier cambio de controles produce un diff imposible de revisar y
propenso a conflictos de merge. En código es una tabla legible, y el remapeo de
la Fase 4 se construye encima sin tocar el motor.

## 9. El dibujo va por su reloj, las cajas por el suyo

Un movimiento tiene dos líneas de tiempo que avanzan a la vez pero se declaran
por separado: la de **cajas** (`frames`, con sus hurtboxes y hitboxes) y la de
**dibujo** (`anim`, con las celdas de la hoja de sprites).

Podrían haber sido una sola, y sería más difícil de desincronizar. Se han
separado porque el cuello de botella del proyecto es el arte (PLAN.md §8) y esta
separación evita dos bloqueos que costarían semanas:

- El artista puede meter un intercalado para que un golpe se lea mejor **sin
  tocar ni un hitbox**, así que no necesita al programador.
- El programador puede recortar dos frames de recuperación para arreglar el
  balance **sin pedir un dibujo nuevo**, así que no necesita al artista.

El riesgo es que se desincronicen, así que el cargador compara las dos duraciones
y avisa por consola cuando no cuadran.

**Si falta la hoja de sprites, el luchador se dibuja como el rectángulo del
prototipo gris.** No es un caso de error: es lo que permite que un personaje sin
arte se pueda programar y probar entero, y que la Fase 3 pueda meter a Cela en el
motor mucho antes de que exista un solo dibujo suyo.

### El placeholder se genera, no se dibuja

`tools/generar_placeholder.gd` produce la hoja provisional **derivándola de las
cajas del propio personaje**: la celda de un puñetazo enseña el brazo justo donde
está el hitbox. Un placeholder cualquiera bajado de internet haría lo contrario —
enseñaría una animación que miente sobre lo que hace el motor, y entonces es peor
que el rectángulo gris para juzgar si un golpe es justo.

De paso le da al artista la referencia exacta de la silueta que tiene que cubrir
cada celda.

### Aviso de escala pendiente de decidir

El plan (§7) pide personajes de **120-128 px de alto**. Las cajas actuales de
Cristina miden **76 px**. La celda ya es de 128, así que el arte definitivo cabe,
pero si se sube el personaje a la altura del plan hay que reescalar cajas,
velocidades, salto y alcances — o sea, rehacer el balance. **Conviene decidirlo
antes de que el artista dibuje nada.**

## 10. Resolución y render

480×270 interno con escalado entero (PLAN.md §7) y filtro *nearest*. Las
posiciones se redondean al píxel al dibujar (`FP.floor_px`): sin eso el pixel art
vibra al moverse, que es el defecto más típico de un 2D mal configurado.

## 11. Lo que es deliberadamente provisional

Esto se tira sin pena cuando llegue su fase:

- `CombatHUD` — dibujado a mano; lo sustituye el marco del artista en la Fase 2.
- El fondo de la arena (`_draw()` de `combat_arena.gd`) — es el escenario del
  galeón el que va ahí.
- `Agents.Dummy` — muñeco de pruebas, no un rival.
- El balance de `fighter.json` — números de primera pasada.
- El agarre es un golpe imbloqueable de rango corto, no una presa con animación:
  sin sprites no hay a qué agarrarse. La animación de presa es de la Fase 2.
- La correspondencia dirección→especial del modo accesible, que hay que decidir
  probándola con gente que no juega a juegos de lucha.

## 12. Lo que falta para cerrar la Fase 1

La lista de sistemas del plan está completa. Lo que queda es criterio, no código:

- **Jugarlo.** El hito de la fase es *"dos rectángulos se pegan y ES DIVERTIDO"*.
  Nadie puede firmar eso desde un test.
- Comprobar que los frame data permiten 2-3 **combos por enlace natural**, como
  pide el plan. Hoy los números son de primera pasada y nadie ha verificado que
  ningún golpe enlace de verdad.
- Afinar el balance con el modo cajas (`F1`) puesto.

Cosas que el plan deja para más adelante y que este código ya soporta sin tocar
motor: más especiales por personaje, proyectiles nuevos, cargas (implementadas y
probadas, aunque Cristina no las use — las necesita Reverte en la Fase 2).
