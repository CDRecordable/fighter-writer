class_name Agents
extends RefCounted
## Fuentes de input de un luchador. El combate no sabe si detrás hay una
## persona o la IA: pide un FighterInput por tick y ya está.
##
## Esta indirección es lo que hace baratos tres puntos del plan: el VS local a
## dos jugadores (PLAN.md §11) es cambiar un agente, la IA por niveles de la
## Fase 3 es añadir agentes, y un replay determinista es un agente que lee una
## lista grabada.


class Agent extends RefCounted:
	## Devuelve el input de este tick. `fighter` se pasa por si el agente
	## necesita contexto (la IA lo usa; el humano lo ignora).
	func poll(_fighter: Node) -> FighterInput:
		return FighterInput.new()


## Lee teclado (por InputMap) y mando (directo) de un jugador.
##
## El mando NO pasa por el InputMap a propósito. Las acciones del InputMap
## mezclan todos los dispositivos, y un dispositivo que no es un mando de
## juego —el caso real: un joystick de vuelo con interruptores mapeados a los
## índices de la cruceta— puede dejar direcciones "pulsadas" permanentemente y
## anular el teclado. Aquí solo se escuchan los mandos que Godot reconoce como
## tales (Input.is_joy_known), y el teclado siempre manda si dice algo.
class Human extends Agent:
	const DEADZONE := 0.35

	var prefix: String
	## 0 = primer mando reconocido, 1 = segundo. No es el índice de dispositivo:
	## si hay un volante o un stick de vuelo por medio, se salta.
	var pad_slot: int
	var _snapshot := FighterInput.new()
	var _previous_buttons: int = 0

	func _init(player_index: int) -> void:
		prefix = "p%d_" % player_index
		pad_slot = player_index - 1

	func poll(_fighter: Node) -> FighterInput:
		var dir_x := 0
		if Input.is_action_pressed(prefix + "right"):
			dir_x += 1
		if Input.is_action_pressed(prefix + "left"):
			dir_x -= 1
		var dir_y := 0
		if Input.is_action_pressed(prefix + "up"):
			dir_y += 1
		if Input.is_action_pressed(prefix + "down"):
			dir_y -= 1

		var buttons := 0
		if Input.is_action_pressed(prefix + "lp"):
			buttons |= FighterInput.BTN_LP
		if Input.is_action_pressed(prefix + "hp"):
			buttons |= FighterInput.BTN_HP
		if Input.is_action_pressed(prefix + "lk"):
			buttons |= FighterInput.BTN_LK
		if Input.is_action_pressed(prefix + "hk"):
			buttons |= FighterInput.BTN_HK
		if Input.is_action_pressed(prefix + "special"):
			buttons |= FighterInput.BTN_SPECIAL

		var device := _pad_device()
		if device >= 0:
			# El teclado tiene prioridad: el mando solo aporta donde el
			# teclado calla. Evita que un stick con deriva pise a las teclas.
			if dir_x == 0:
				var eje_x := Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
				if eje_x > DEADZONE or Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT):
					dir_x = 1
				elif eje_x < -DEADZONE or Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT):
					dir_x = -1
			if dir_y == 0:
				var eje_y := Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
				if eje_y < -DEADZONE or Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP):
					dir_y = 1
				elif eje_y > DEADZONE or Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN):
					dir_y = -1
			if Input.is_joy_button_pressed(device, JOY_BUTTON_X):
				buttons |= FighterInput.BTN_LP
			if Input.is_joy_button_pressed(device, JOY_BUTTON_Y):
				buttons |= FighterInput.BTN_HP
			if Input.is_joy_button_pressed(device, JOY_BUTTON_A):
				buttons |= FighterInput.BTN_LK
			if Input.is_joy_button_pressed(device, JOY_BUTTON_B):
				buttons |= FighterInput.BTN_HK
			if Input.is_joy_button_pressed(device, JOY_BUTTON_RIGHT_SHOULDER):
				buttons |= FighterInput.BTN_SPECIAL

		_snapshot.dir_x = dir_x
		_snapshot.dir_y = dir_y
		_snapshot.buttons = buttons
		# El flanco lo calculamos nosotros y no con is_action_just_pressed:
		# ese método mira frames de render, y aquí mandan los ticks de
		# simulación. Si el render se salta un tick, el botón se perdería.
		_snapshot.pressed = buttons & ~_previous_buttons
		_previous_buttons = buttons
		return _snapshot

	## El enésimo mando RECONOCIDO como mando de juego, o -1 si no hay.
	func _pad_device() -> int:
		var indice := 0
		for id in Input.get_connected_joypads():
			if not Input.is_joy_known(id):
				continue
			if indice == pad_slot:
				return id
			indice += 1
		return -1


## La "IA tonta" que pide la Fase 1: sirve para probar el combate en solitario,
## no para ser un rival. La de verdad, por niveles, llega en la Fase 3.
class Dummy extends Agent:
	## BLOQUEA_TRAS_EL_PRIMERO es el modo que de verdad hace falta para probar
	## combos: encaja el primer golpe y bloquea todo lo demás. Si la segunda
	## parte del combo entra igual, es que enlaza de verdad; si la bloquea, es
	## que solo funcionaba porque el rival no reaccionaba.
	enum Mode { QUIETO, BLOQUEA, BLOQUEA_TRAS_EL_PRIMERO, AGRESIVA }

	const BUTTONS := [
		FighterInput.BTN_LP, FighterInput.BTN_HP,
		FighterInput.BTN_LK, FighterInput.BTN_HK,
	]

	# Declarado como int a propósito: vamos rotando el modo con aritmética y
	# GDScript avisa al asignar un int a una variable tipada como enum.
	var mode: int = Mode.AGRESIVA
	var _snapshot := FighterInput.new()
	var _rng := RandomNumberGenerator.new()
	var _cooldown: int = 0

	func _init(seed_value: int = 20260724) -> void:
		# Semilla fija: una IA determinista hace que un bug de combate se pueda
		# reproducir tal cual, que es media depuración ganada.
		_rng.seed = seed_value

	func cycle_mode() -> String:
		mode = (mode + 1) % Mode.size()
		return String(Mode.keys()[mode]).capitalize()

	func poll(fighter: Node) -> FighterInput:
		_snapshot.clear()
		match mode:
			Mode.QUIETO:
				pass
			Mode.BLOQUEA:
				# Alejarse del rival = bloquear (bloqueo por dirección, como SF2).
				_snapshot.dir_x = -fighter.facing
			Mode.BLOQUEA_TRAS_EL_PRIMERO:
				if fighter.health < fighter.stats.max_health:
					_snapshot.dir_x = -fighter.facing
			Mode.AGRESIVA:
				_poll_aggressive(fighter)
		return _snapshot

	func _poll_aggressive(fighter: Node) -> void:
		if _cooldown > 0:
			_cooldown -= 1
			return
		var distance: int = absi(fighter.distance_to_opponent())
		if distance > FP.from_px(56):
			_snapshot.dir_x = fighter.facing
		elif _rng.randi_range(0, 100) < 22:
			var button: int = BUTTONS[_rng.randi_range(0, BUTTONS.size() - 1)]
			_snapshot.buttons = button
			_snapshot.pressed = button
			_cooldown = _rng.randi_range(10, 34)
		elif _rng.randi_range(0, 100) < 8:
			_snapshot.dir_x = -fighter.facing
			_cooldown = _rng.randi_range(6, 18)
