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

const KEYS := {
	1: {
		"left": KEY_A, "right": KEY_D, "up": KEY_W, "down": KEY_S,
		"lp": KEY_J, "hp": KEY_K, "lk": KEY_N, "hk": KEY_M,
	},
	2: {
		"left": KEY_LEFT, "right": KEY_RIGHT, "up": KEY_UP, "down": KEY_DOWN,
		"lp": KEY_KP_1, "hp": KEY_KP_2, "lk": KEY_KP_4, "hk": KEY_KP_5,
	},
}

const PAD_BUTTONS := {
	"lp": JOY_BUTTON_X, "hp": JOY_BUTTON_Y,
	"lk": JOY_BUTTON_A, "hk": JOY_BUTTON_B,
}

const PAD_DPAD := {
	"left": JOY_BUTTON_DPAD_LEFT, "right": JOY_BUTTON_DPAD_RIGHT,
	"up": JOY_BUTTON_DPAD_UP, "down": JOY_BUTTON_DPAD_DOWN,
}


func _enter_tree() -> void:
	for player in range(1, PLAYERS + 1):
		var prefix := "p%d_" % player
		var device := player - 1
		for action_suffix: String in KEYS[player].keys():
			var action := StringName(prefix + action_suffix)
			_ensure_action(action)
			_add_key(action, KEYS[player][action_suffix])
		for action_suffix: String in PAD_DPAD.keys():
			_add_pad_button(StringName(prefix + action_suffix), device, PAD_DPAD[action_suffix])
		for action_suffix: String in PAD_BUTTONS.keys():
			_add_pad_button(StringName(prefix + action_suffix), device, PAD_BUTTONS[action_suffix])
		_add_pad_axis(StringName(prefix + "left"), device, JOY_AXIS_LEFT_X, -1.0)
		_add_pad_axis(StringName(prefix + "right"), device, JOY_AXIS_LEFT_X, 1.0)
		_add_pad_axis(StringName(prefix + "up"), device, JOY_AXIS_LEFT_Y, -1.0)
		_add_pad_axis(StringName(prefix + "down"), device, JOY_AXIS_LEFT_Y, 1.0)

	# Utilidades de desarrollo. Se quitan (o se esconden) antes de publicar.
	_ensure_action(&"dev_toggle_boxes")
	_add_key(&"dev_toggle_boxes", KEY_F1)
	_ensure_action(&"dev_reset")
	_add_key(&"dev_reset", KEY_F5)
	_ensure_action(&"dev_toggle_dummy")
	_add_key(&"dev_toggle_dummy", KEY_F2)


func _ensure_action(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.35)


func _add_key(action: StringName, keycode: Key) -> void:
	_ensure_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)


func _add_pad_button(action: StringName, device: int, button: JoyButton) -> void:
	_ensure_action(action)
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _add_pad_axis(action: StringName, device: int, axis: JoyAxis, value: float) -> void:
	_ensure_action(action)
	var ev := InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)
