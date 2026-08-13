extends Node
## Autoload "Controles": registra el mapa de acciones en tiempo de ejecución.
##
## Por qué en código y no en project.godot: el mapa vive en un archivo legible
## y diffeable en Git (project.godot serializa los eventos como blobs Object(...)
## ilegibles), y el remapeo de controles de la Fase 4 se implementa encima de
## esto sin tocar el motor.
##
## Distribución de botones (PLAN.md §3): puños arriba, patadas abajo, como SF2.
##   Jugador 1 — teclado: W A S D + J (puño débil) K (puño fuerte)
##                                  N (patada débil) M (patada fuerte)
##   Jugador 2 — teclado: flechas  + KP1 KP2 / KP4 KP5
##   Ambos     — mando:   cruceta o stick izquierdo + X Y / A B
##                        (J1 = mando 0, J2 = mando 1)

const PLAYERS := 2

## SOLO TECLADO. Los mandos no pasan por el InputMap a propósito: se leen
## directamente en Agents.Human, filtrando con Input.is_joy_known() los
## dispositivos que no son mandos de juego. Motivo real, no teórico: un
## joystick de vuelo (Saitek X-56) conectado como dispositivo 0 reportaba
## "izquierda" y "derecha" pulsadas a la vez de forma permanente —sus
## interruptores mapean a los índices de la cruceta— y como las acciones del
## InputMap mezclan todos los dispositivos, anulaba el teclado: +1-1 = 0 y el
## personaje no se movía en horizontal.
const KEYS := {
	1: {
		"left": KEY_A, "right": KEY_D, "up": KEY_W, "down": KEY_S,
		"lp": KEY_J, "hp": KEY_K, "lk": KEY_N, "hk": KEY_M,
		"special": KEY_L,
	},
	2: {
		"left": KEY_LEFT, "right": KEY_RIGHT, "up": KEY_UP, "down": KEY_DOWN,
		"lp": KEY_KP_1, "hp": KEY_KP_2, "lk": KEY_KP_4, "hk": KEY_KP_5,
		"special": KEY_KP_0,
	},
}


func _enter_tree() -> void:
	for player in range(1, PLAYERS + 1):
		var prefix := "p%d_" % player
		for action_suffix: String in KEYS[player].keys():
			var action := StringName(prefix + action_suffix)
			_ensure_action(action)
			_add_key(action, KEYS[player][action_suffix])

	# Utilidades de desarrollo. Se quitan (o se esconden) antes de publicar.
	_ensure_action(&"dev_toggle_boxes")
	_add_key(&"dev_toggle_boxes", KEY_F1)
	_ensure_action(&"dev_reset")
	_add_key(&"dev_reset", KEY_F5)
	_ensure_action(&"dev_toggle_dummy")
	_add_key(&"dev_toggle_dummy", KEY_F2)
	_ensure_action(&"dev_toggle_accessible")
	_add_key(&"dev_toggle_accessible", KEY_F3)
	_ensure_action(&"dev_toggle_training")
	_add_key(&"dev_toggle_training", KEY_F4)
	_ensure_action(&"dev_quick_reset")
	_add_key(&"dev_quick_reset", KEY_F6)
	_ensure_action(&"dev_unlock_all")
	_add_key(&"dev_unlock_all", KEY_F9)


func _ensure_action(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.35)


func _add_key(action: StringName, keycode: Key) -> void:
	_ensure_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)
