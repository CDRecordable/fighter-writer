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


## Lee el teclado/mando de un jugador a través del InputMap (ver input_setup.gd).
class Human extends Agent:
	var prefix: String
	var _snapshot := FighterInput.new()
	var _previous_buttons: int = 0

	func _init(player_index: int) -> void:
		prefix = "p%d_" % player_index

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

		_snapshot.dir_x = dir_x
		_snapshot.dir_y = dir_y
		_snapshot.buttons = buttons
		# El flanco lo calculamos nosotros y no con is_action_just_pressed:
		# ese método mira frames de render, y aquí mandan los ticks de
		# simulación. Si el render se salta un tick, el botón se perdería.
		_snapshot.pressed = buttons & ~_previous_buttons
		_previous_buttons = buttons
		return _snapshot


## La "IA tonta" que pide la Fase 1: sirve para probar el combate en solitario,
## no para ser un rival. La de verdad, por niveles, llega en la Fase 3.
class Dummy extends Agent:
	enum Mode { QUIETO, BLOQUEA, AGRESIVA }

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
