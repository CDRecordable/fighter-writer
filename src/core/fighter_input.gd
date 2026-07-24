class_name FighterInput
extends RefCounted
## Instantánea del input de un luchador en un tick concreto.
##
## Los agentes (humano o IA) producen uno de estos por tick. El luchador nunca
## consulta a Input directamente: así la IA, el jugador y —en el futuro— la
## repetición de un replay o el rollback usan exactamente el mismo camino.

const BTN_LP := 1  ## Puñetazo débil  (botón A del plan)
const BTN_HP := 2  ## Puñetazo fuerte (botón B)
const BTN_LK := 4  ## Patada débil    (botón X)
const BTN_HK := 8  ## Patada fuerte   (botón Y)
## Botón único del modo accesible (PLAN.md §3): especial con dirección + botón,
## sin medias lunas. No es un quinto botón del juego normal.
const BTN_SPECIAL := 16

const BTN_ALL := BTN_LP | BTN_HP | BTN_LK | BTN_HK

## Dirección en espacio del MUNDO, no relativa al personaje: -1 izquierda,
## +1 derecha. La conversión a "adelante/atrás" la hace el luchador con su
## facing, que es lo que permite que bloquear sea "hacia atrás" como en SF2.
var dir_x: int = 0
## -1 agacharse, +1 saltar.
var dir_y: int = 0
## Máscara de botones mantenidos este tick.
var buttons: int = 0
## Máscara de botones que pasan de suelto a pulsado en este tick.
var pressed: int = 0


func held(btn: int) -> bool:
	return (buttons & btn) != 0


func just_pressed(btn: int) -> bool:
	return (pressed & btn) != 0


func any_pressed() -> bool:
	return pressed != 0


func copy_from(other: FighterInput) -> void:
	dir_x = other.dir_x
	dir_y = other.dir_y
	buttons = other.buttons
	pressed = other.pressed


func clear() -> void:
	dir_x = 0
	dir_y = 0
	buttons = 0
	pressed = 0
