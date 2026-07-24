extends SceneTree
## Prueba de humo del combate. Se ejecuta sin ventana:
##
##   godot --headless --path . --script res://tests/smoke_test.gd
##
## No pretende ser una suite completa: comprueba que las reglas que sostienen
## todo lo demás (que un golpe pega, que el bloqueo bloquea, que un barrido no
## se para de pie, que la simulación es determinista) siguen en pie después de
## tocar el balance o el motor. Devuelve código de salida 1 si algo falla, así
## que sirve tal cual para integración continua.

const ARENA_SCENE := preload("res://scenes/combat_arena.tscn")

const NEAR_X := 20.0  ## px de separación desde el centro para las pruebas


## Agente de pruebas: el test le escribe el input a mano, tick a tick.
class Scripted extends Agents.Agent:
	var snapshot := FighterInput.new()

	func poll(_fighter: Node) -> FighterInput:
		return snapshot

	func hold(dir_x: int = 0, dir_y: int = 0) -> void:
		snapshot.dir_x = dir_x
		snapshot.dir_y = dir_y

	func press(button: int) -> void:
		snapshot.buttons = button
		snapshot.pressed = button

	## El flanco de pulsación dura un solo tick, igual que con un teclado real.
	func consume_edge() -> void:
		snapshot.pressed = 0


var failures: Array[String] = []
var _finished := false


## Las pruebas corren en el primer frame, no en _initialize(): dentro de
## _initialize() el árbol todavía no está en marcha y añadir un nodo NO dispara
## su _ready(), así que la arena llegaría sin luchadores.
func _process(_delta: float) -> bool:
	if _finished:
		return true
	_finished = true
	_run_all()
	return true


func _run_all() -> void:
	_test_golpe_conecta()
	_test_bloqueo_de_pie()
	_test_barrido_no_se_bloquea_de_pie()
	_test_salto_vuelve_al_suelo()
	_test_cuerpos_no_se_atraviesan()
	_test_simulacion_determinista()
	_test_rondas_y_ko()

	print("")
	if failures.is_empty():
		print("OK — todas las pruebas pasan")
		quit(0)
	else:
		for failure in failures:
			printerr("FALLO: %s" % failure)
		print("%d prueba(s) fallida(s)" % failures.size())
		quit(1)


# --- Pruebas -----------------------------------------------------------------

func _test_golpe_conecta() -> void:
	var arena := _make_arena()
	var attacker: Fighter = arena.fighters[0]
	var defender: Fighter = arena.fighters[1]
	var agent: Scripted = attacker.agent

	agent.press(FighterInput.BTN_HP)
	_run(arena, 20)

	_check("un puñetazo fuerte a bocajarro quita vida",
		defender.health < defender.stats.max_health)
	_check("el golpe entra una sola vez",
		defender.health == defender.stats.max_health - attacker.stats.get_move(&"stand_hp").damage)
	arena.free()


func _test_bloqueo_de_pie() -> void:
	var arena := _make_arena()
	var attacker: Fighter = arena.fighters[0]
	var defender: Fighter = arena.fighters[1]

	# Bloquear es mantener hacia atrás: para el jugador 2, alejarse del rival.
	(defender.agent as Scripted).hold(-defender.facing)
	(attacker.agent as Scripted).press(FighterInput.BTN_HP)
	_run(arena, 20)

	_check("bloquear de pie anula el daño de un golpe medio",
		defender.health == defender.stats.max_health)
	_check("bloquear carga algo de Tinta", defender.meter > 0)
	arena.free()


func _test_barrido_no_se_bloquea_de_pie() -> void:
	var arena := _make_arena()
	var attacker: Fighter = arena.fighters[0]
	var defender: Fighter = arena.fighters[1]

	(defender.agent as Scripted).hold(-defender.facing)  # atrás, pero de pie
	var agent: Scripted = attacker.agent
	agent.hold(0, -1)  # agachado
	agent.press(FighterInput.BTN_HK)
	_run(arena, 24)

	_check("un barrido bajo atraviesa el bloqueo alto",
		defender.health < defender.stats.max_health)
	_check("el barrido derriba", defender.airborne or defender.state == Fighter.State.HITSTUN)
	arena.free()


func _test_salto_vuelve_al_suelo() -> void:
	var arena := _make_arena()
	var jumper: Fighter = arena.fighters[0]
	var agent: Scripted = jumper.agent

	agent.hold(0, 1)
	_run(arena, 6)
	_check("el salto despega", jumper.airborne)

	var apex := 0
	for i in 60:
		apex = maxi(apex, jumper.pos_y)
		arena.tick()
		agent.consume_edge()
	agent.hold(0, 0)
	_run(arena, 20)

	_check("el salto alcanza una altura razonable (50-90 px)",
		FP.to_px(apex) > 50.0 and FP.to_px(apex) < 90.0)
	_check("después de saltar se vuelve al suelo", not jumper.airborne and jumper.pos_y == 0)
	arena.free()


func _test_cuerpos_no_se_atraviesan() -> void:
	var arena := _make_arena()
	var a: Fighter = arena.fighters[0]
	var b: Fighter = arena.fighters[1]

	# Los dos empujando hacia el otro durante dos segundos.
	(a.agent as Scripted).hold(1)
	(b.agent as Scripted).hold(-1)
	_run(arena, 120)

	_check("los pushboxes impiden que los cuerpos se solapen",
		not BoxData.overlaps(a.pushbox_world(), b.pushbox_world()))
	_check("el jugador 1 sigue a la izquierda del jugador 2", a.pos_x < b.pos_x)
	arena.free()


func _test_simulacion_determinista() -> void:
	# El mismo guion de inputs tiene que dar exactamente el mismo estado. Es la
	# propiedad de la que dependen el punto fijo y el rollback futuro.
	var first := _run_scripted_match()
	var second := _run_scripted_match()
	_check("dos ejecuciones idénticas dan el mismo estado final (%s vs %s)" % [first, second],
		first == second)


func _test_rondas_y_ko() -> void:
	var arena := _make_arena()
	var loser: Fighter = arena.fighters[1]
	loser.health = 1
	(arena.fighters[0].agent as Scripted).press(FighterInput.BTN_HP)
	_run(arena, 30)

	_check("dejar a cero la vida acaba la ronda", arena.round_state == CombatArena.RoundState.KO)
	_check("la ronda se le apunta al ganador", arena.rounds_won[0] == 1)
	arena.free()


# --- Utilidades --------------------------------------------------------------

func _make_arena() -> CombatArena:
	var arena: CombatArena = ARENA_SCENE.instantiate()
	root.add_child(arena)

	# Fuera el intro: las pruebas quieren el combate, no la cuenta atrás.
	while arena.round_state != CombatArena.RoundState.FIGHTING:
		arena.tick()

	for fighter: Fighter in arena.fighters:
		fighter.agent = Scripted.new()
	arena.fighters[0].pos_x = FP.from_px(-NEAR_X)
	arena.fighters[1].pos_x = FP.from_px(NEAR_X)
	return arena


func _run(arena: CombatArena, ticks: int) -> void:
	for i in ticks:
		arena.tick()
		for fighter: Fighter in arena.fighters:
			(fighter.agent as Scripted).consume_edge()


## Ejecuta un combate guionizado y devuelve una firma del estado final.
func _run_scripted_match() -> String:
	var arena := _make_arena()
	var a: Scripted = arena.fighters[0].agent
	var b: Scripted = arena.fighters[1].agent
	for tick_index in 180:
		match tick_index % 30:
			0: a.press(FighterInput.BTN_LP)
			8: a.hold(1)
			14: a.press(FighterInput.BTN_HK)
			20: a.hold(-1)
			5: b.hold(-1)
			12: b.press(FighterInput.BTN_LK)
			22: b.hold(0, -1)
		arena.tick()
		a.consume_edge()
		b.consume_edge()
	var signature := "%d/%d/%d|%d/%d/%d" % [
		arena.fighters[0].pos_x, arena.fighters[0].health, arena.fighters[0].meter,
		arena.fighters[1].pos_x, arena.fighters[1].health, arena.fighters[1].meter,
	]
	arena.free()
	return signature


func _check(description: String, condition: bool) -> void:
	if condition:
		print("  ok   %s" % description)
	else:
		failures.append(description)
		print("  FALLA %s" % description)
