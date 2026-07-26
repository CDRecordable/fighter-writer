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

	_test_deteccion_de_comandos()
	_test_boton_bufferizado()
	_test_buffer_no_envejece_en_hitstop()
	_test_especial_multigolpe()
	_test_proyectil()
	_test_contraataque()
	_test_super_cuesta_tinta()
	_test_agarre()

	_test_dos_personajes()
	_test_carga_de_reverte()
	_test_super_de_dos_botones()

	_test_cualquier_enfrentamiento()
	_test_fichas_de_la_biblioteca()
	_test_desbloqueo_por_victoria()

	_test_ventaja_de_frames()
	_test_contador_de_combo()
	_test_reinicio_instantaneo()

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


# --- Segundo personaje -------------------------------------------------------

func _test_dos_personajes() -> void:
	# La promesa de la arquitectura es "añadir un escritor = añadir una
	# carpeta". Hasta que no hay un segundo, eso es una promesa, no un hecho.
	_check("hay al menos dos personajes en characters/",
		CharacterLoader.list_ids().size() >= 2)
	var arena := _make_arena()
	_check("el combate por defecto ya no es un espejo",
		arena.fighters[0].stats.id != arena.fighters[1].stats.id)
	_check("el rival tiene sus propios movimientos",
		arena.fighters[1].stats.get_move(&"tuit_incendiario") != null)
	arena.free()


func _test_carga_de_reverte() -> void:
	var arena := _make_arena("perez_reverte", "cristina_morales")
	var reverte: Fighter = arena.fighters[0]
	var agent: Scripted = reverte.agent
	_separate(arena, 90.0)

	# Mantener atrás el tiempo de carga y soltar hacia delante.
	agent.hold(-1)
	_run(arena, InputBuffer.CHARGE_TICKS + 4)
	agent.hold(1)
	agent.press(FighterInput.BTN_LP)
	_run(arena, 3)

	_check("la carga atrás→adelante saca el Tuit Incendiario",
		reverte.current_move != null and reverte.current_move.id == &"tuit_incendiario")
	_run(arena, 20)
	_check("y el tuit sale volando", arena.projectiles.size() == 1)
	arena.free()


func _test_super_de_dos_botones() -> void:
	# El súper de Reverte comparte la carga del proyectil. Se separan pidiendo
	# los dos puños a la vez; si esto falla, con la barra llena el proyectil no
	# saldría nunca.
	var arena := _make_arena("perez_reverte", "cristina_morales")
	var reverte: Fighter = arena.fighters[0]
	var agent: Scripted = reverte.agent
	reverte.meter = reverte.stats.max_meter
	_separate(arena, 90.0)

	agent.hold(-1)
	_run(arena, InputBuffer.CHARGE_TICKS + 4)
	agent.hold(1)
	agent.press(FighterInput.BTN_LP)
	_run(arena, 3)
	_check("con la barra llena y UN puño sale el especial, no el súper",
		reverte.current_move != null and reverte.current_move.id == &"tuit_incendiario")
	arena.free()

	arena = _make_arena("perez_reverte", "cristina_morales")
	reverte = arena.fighters[0]
	agent = reverte.agent
	reverte.meter = reverte.stats.max_meter
	_separate(arena, 90.0)

	agent.hold(-1)
	_run(arena, InputBuffer.CHARGE_TICKS + 4)
	agent.hold(1)
	agent.press(FighterInput.BTN_LP | FighterInput.BTN_HP)
	_run(arena, 3)
	_check("con los DOS puños sale Cabo Trafalgar",
		reverte.current_move != null and reverte.current_move.id == &"super_cabo_trafalgar")
	arena.free()


# --- Selección ---------------------------------------------------------------

func _test_cualquier_enfrentamiento() -> void:
	# La pantalla de selección deja elegir cualquier pareja, espejos incluidos.
	# Si un personaje reventara la arena en alguna combinación, el jugador se
	# lo encontraría antes que nadie: aquí se comprueban todas.
	var ids := CharacterLoader.list_ids()
	var fallos := PackedStringArray()
	for a in ids:
		for b in ids:
			var arena := _make_arena(a, b)
			var bien := (
				arena.fighters.size() == 2
				and String(arena.fighters[0].stats.id) == a
				and String(arena.fighters[1].stats.id) == b
			)
			if not bien:
				fallos.append("%s vs %s" % [a, b])
			arena.free()
	_check("cualquier pareja de escritores arranca (%d combinaciones)" % (ids.size() * ids.size()),
		fallos.is_empty())


# --- Biblioteca --------------------------------------------------------------

func _test_fichas_de_la_biblioteca() -> void:
	# La mitad educativa del juego depende de que cada escritor jugable tenga
	# algo que leer. Un personaje sin ficha es un agujero en el producto, no un
	# detalle pendiente.
	var completos := 0
	for id in CharacterLoader.list_ids():
		var entry := WikiEntry.load_for(id)
		if entry == null:
			_check("%s tiene wiki.json" % id, false)
			continue
		var tiene_contenido := (
			entry.display_name != ""
			and not entry.bibliografia.is_empty()
			and not entry.moveset.is_empty()
		)
		_check("la ficha de %s tiene obra y explicación de sus golpes" % id, tiene_contenido)
		if tiene_contenido:
			completos += 1
	_check("todos los escritores tienen ficha (%d)" % completos,
		completos == CharacterLoader.list_ids().size())


func _test_desbloqueo_por_victoria() -> void:
	Progreso.olvidar_todo()
	var arena := _make_arena()
	var rival: Fighter = arena.fighters[1]
	var rival_id := String(rival.stats.id)
	_check("de entrada la ficha del rival está bloqueada",
		not Progreso.esta_desbloqueado(rival_id))

	# Se fuerza el final del combate: dos rondas ganadas por el jugador.
	arena.rounds_won = [CombatArena.ROUNDS_TO_WIN - 1, 0]
	rival.health = 1
	(arena.fighters[0].agent as Scripted).press(FighterInput.BTN_HP)
	_run(arena, 30)
	for i in 200:
		arena.tick()
		if arena.round_state == CombatArena.RoundState.MATCH_END:
			break

	_check("ganar el combate desbloquea la ficha del rival",
		Progreso.esta_desbloqueado(rival_id))
	arena.free()
	# No se deja el progreso tocado: la ficha se gana jugando, no pasando tests.
	Progreso.olvidar_todo()


# --- Modo entrenamiento ------------------------------------------------------

func _test_ventaja_de_frames() -> void:
	# No se comprueba un número exacto —cambiaría con cada retoque de balance—
	# sino la regla que tiene que cumplirse siempre: un golpe rápido deja mejor
	# situación que uno lento. Si esto se invierte, el balance está roto.
	var jab: Variant = _medir_ventaja(FighterInput.BTN_LP)
	var patada: Variant = _medir_ventaja(FighterInput.BTN_HK)
	_check("se puede medir la ventaja de un jab bloqueado (%s)" % str(jab), jab != null)
	_check("se puede medir la ventaja de una patada bloqueada (%s)" % str(patada), patada != null)
	if jab != null and patada != null:
		_check("el golpe rápido deja mejor situación que el lento (%d vs %d)" % [jab, patada],
			int(jab) > int(patada))


func _medir_ventaja(button: int) -> Variant:
	var arena := _make_arena()
	_separate(arena, 12.0)
	(arena.fighters[1].agent as Scripted).hold(-arena.fighters[1].facing)
	(arena.fighters[0].agent as Scripted).press(button)
	var resultado: Variant = null
	for i in 120:
		arena.tick()
		for fighter: Fighter in arena.fighters:
			(fighter.agent as Scripted).consume_edge()
		if arena.training.advantage_valid:
			resultado = arena.training.advantage
			break
	arena.free()
	return resultado


func _test_contador_de_combo() -> void:
	var arena := _make_arena()
	var attacker: Fighter = arena.fighters[0]

	_input_motion(arena, attacker, [ABAJO, ABAJO_ADELANTE, ADELANTE])
	(attacker.agent as Scripted).press(FighterInput.BTN_LP)
	_run(arena, 60)

	_check("el contador cuenta los tres golpes de la Danza Bruta (contó %d)"
		% maxi(arena.training.combo_hits, arena.training.last_combo_hits),
		maxi(arena.training.combo_hits, arena.training.last_combo_hits) == 3)
	arena.free()


func _test_reinicio_instantaneo() -> void:
	var arena := _make_arena()
	var defender: Fighter = arena.fighters[1]
	(arena.fighters[0].agent as Scripted).press(FighterInput.BTN_HP)
	_run(arena, 20)
	_check("el golpe de prueba ha hecho daño", defender.health < defender.stats.max_health)

	arena.reset_instantaneo()
	_check("el reinicio instantáneo devuelve la vida",
		defender.health == defender.stats.max_health)
	_check("y deja el combate listo, sin cuenta atrás",
		arena.round_state == CombatArena.RoundState.FIGHTING)
	arena.free()


# --- Entradas de comando -----------------------------------------------------

## Direcciones en espacio del mundo mirando a la derecha, para escribir las
## secuencias como se leen: ABAJO, ABAJO_ADELANTE, ADELANTE...
const NEUTRO := [0, 0]
const ABAJO := [0, -1]
const ABAJO_ADELANTE := [1, -1]
const ADELANTE := [1, 0]
const ATRAS := [-1, 0]
const ARRIBA := [0, 1]


func _test_deteccion_de_comandos() -> void:
	_check("↓ ↘ → se reconoce como media luna adelante",
		_buffer_with([ABAJO, ABAJO, ABAJO_ADELANTE, ADELANTE]).matches(&"236"))
	_check("↓ → (sin diagonal) también vale: no castigamos al que no es jugón",
		_buffer_with([ABAJO, ABAJO, ADELANTE]).matches(&"236"))
	_check("una media luna adelante NO se confunde con una hacia atrás",
		not _buffer_with([ABAJO, ABAJO_ADELANTE, ADELANTE]).matches(&"214"))
	_check("→ ↓ ↘ se reconoce como dragón",
		_buffer_with([ADELANTE, ABAJO, ABAJO_ADELANTE]).matches(&"623"))
	_check("un ↓...→ demasiado lento no cuenta como media luna",
		not _buffer_with(_repeat(ABAJO, 2) + _repeat(NEUTRO, 30) + [ADELANTE]).matches(&"236"))
	_check("una media luna vieja ya no dispara nada",
		not _buffer_with([ABAJO, ABAJO_ADELANTE, ADELANTE] + _repeat(NEUTRO, 20)).matches(&"236"))
	_check("dos medias lunas seguidas se reconocen como entrada de súper",
		_buffer_with([ABAJO, ABAJO_ADELANTE, ADELANTE, ABAJO, ABAJO_ADELANTE, ADELANTE]).matches(&"236236"))
	_check("una sola media luna NO cuela como súper",
		not _buffer_with([ABAJO, ABAJO_ADELANTE, ADELANTE]).matches(&"236236"))
	_check("mantener atrás y soltar adelante es una carga",
		_buffer_with(_repeat(ATRAS, InputBuffer.CHARGE_TICKS + 2) + [ADELANTE]).matches(&"charge46"))
	_check("una carga corta no vale: hay que aguantar",
		not _buffer_with(_repeat(ATRAS, 20) + [ADELANTE]).matches(&"charge46"))
	_check("mantener abajo y soltar arriba es la otra carga",
		_buffer_with(_repeat(ABAJO, InputBuffer.CHARGE_TICKS + 2) + [ARRIBA]).matches(&"charge28"))


func _test_boton_bufferizado() -> void:
	# El corazón del "game feel": pulsar durante la recuperación de un golpe
	# tiene que sacar el siguiente en cuanto el personaje puede actuar.
	var arena := _make_arena()
	var attacker: Fighter = arena.fighters[0]
	var agent: Scripted = attacker.agent
	var total: int = attacker.stats.get_move(&"stand_hk").total_frames()
	# Lejos del rival a propósito: el golpe tiene que fallar. Si conectara, el
	# hitstop cambiaría los tiempos y la prueba dejaría de medir el buffer.
	_separate(arena, 90.0)

	agent.press(FighterInput.BTN_HK)
	_run(arena, total - 3)
	_check("el golpe largo sigue en curso justo antes de acabar",
		attacker.current_move != null and attacker.current_move.id == &"stand_hk")

	# Se pulsa 3 ticks ANTES de poder actuar: sin buffer, se perdería.
	agent.press(FighterInput.BTN_LP)
	_run(arena, 5)
	_check("un botón pulsado durante la recuperación sale al recuperarse",
		attacker.current_move != null and attacker.current_move.id == &"stand_lp")
	arena.free()


func _test_buffer_no_envejece_en_hitstop() -> void:
	var arena := _make_arena()
	var fighter: Fighter = arena.fighters[0]
	fighter.hitstop = 6
	(fighter.agent as Scripted).press(FighterInput.BTN_LP)
	_run(arena, 5)

	# pressed_within(…, 1) solo mira el tick más reciente: si la pulsación
	# sigue ahí, es que el historial no ha corrido durante la congelación.
	_check("una pulsación hecha en hitstop sigue fresca al descongelar",
		fighter.buffer.pressed_within(FighterInput.BTN_LP, 1) != 0)
	arena.free()


func _test_especial_multigolpe() -> void:
	var arena := _make_arena()
	var attacker: Fighter = arena.fighters[0]
	var defender: Fighter = arena.fighters[1]
	var danza: MoveData = attacker.stats.get_move(&"danza_bruta")

	_input_motion(arena, attacker, [ABAJO, ABAJO_ADELANTE, ADELANTE])
	(attacker.agent as Scripted).press(FighterInput.BTN_LP)
	_run(arena, 2)
	_check("la media luna + puño saca la Danza Bruta",
		attacker.current_move != null and attacker.current_move.id == &"danza_bruta")

	_run(arena, 60)
	var damage: int = defender.stats.max_health - defender.health
	_check("la Danza Bruta golpea más de una vez (daño %d, un golpe son %d)" % [damage, danza.damage],
		damage >= danza.damage * 2)
	arena.free()


func _test_proyectil() -> void:
	var arena := _make_arena()
	var attacker: Fighter = arena.fighters[0]
	var defender: Fighter = arena.fighters[1]
	# A media pantalla: a bocajarro el panfleto impactaría nada más nacer y no
	# se podría comprobar que vuela.
	_separate(arena, 90.0)

	_input_motion(arena, attacker, [ABAJO, ABAJO_ADELANTE, ADELANTE])
	(attacker.agent as Scripted).press(FighterInput.BTN_LK)
	_run(arena, 16)
	_check("la media luna + patada lanza el panfleto", arena.projectiles.size() == 1)

	_run(arena, 60)
	_check("el panfleto golpea al rival", defender.health < defender.stats.max_health)
	_check("el panfleto se consume al golpear", arena.projectiles.is_empty())
	arena.free()


func _test_contraataque() -> void:
	var arena := _make_arena()
	var counter_user: Fighter = arena.fighters[0]
	var aggressor: Fighter = arena.fighters[1]

	_input_motion(arena, counter_user, [ABAJO, [-1, -1], ATRAS])
	(counter_user.agent as Scripted).press(FighterInput.BTN_LP)
	_run(arena, 2)
	_check("la media luna atrás + puño saca la Asamblea",
		counter_user.current_move != null and counter_user.current_move.id == &"asamblea")

	(aggressor.agent as Scripted).press(FighterInput.BTN_LP)
	_run(arena, 40)
	_check("la Asamblea absorbe el golpe sin recibir daño",
		counter_user.health == counter_user.stats.max_health)
	_check("y devuelve la patada okupa", aggressor.health < aggressor.stats.max_health)
	arena.free()


func _test_super_cuesta_tinta() -> void:
	var arena := _make_arena()
	var attacker: Fighter = arena.fighters[0]
	var doble := [ABAJO, ABAJO_ADELANTE, ADELANTE, ABAJO, ABAJO_ADELANTE, ADELANTE]

	attacker.meter = 0
	_input_motion(arena, attacker, doble)
	(attacker.agent as Scripted).press(FighterInput.BTN_HP)
	_run(arena, 2)
	_check("sin Tinta el súper no sale (sale el especial normal)",
		attacker.current_move != null and attacker.current_move.id != &"super_combatientes")
	arena.free()

	arena = _make_arena()
	attacker = arena.fighters[0]
	attacker.meter = attacker.stats.max_meter
	_input_motion(arena, attacker, doble)
	(attacker.agent as Scripted).press(FighterInput.BTN_HP)
	_run(arena, 2)
	_check("con la Tinta llena sale Los Combatientes",
		attacker.current_move != null and attacker.current_move.id == &"super_combatientes")
	_check("y el súper vacía la barra", attacker.meter == 0)
	_check("el súper congela al rival mientras arranca", arena.fighters[1].hitstop > 0)
	arena.free()


func _test_agarre() -> void:
	var arena := _make_arena()
	var attacker: Fighter = arena.fighters[0]
	var defender: Fighter = arena.fighters[1]
	attacker.pos_x = FP.from_px(-14.0)
	defender.pos_x = FP.from_px(14.0)

	# El rival bloquea con todas sus fuerzas: da igual, un agarre no se bloquea.
	(defender.agent as Scripted).hold(-defender.facing)
	_input_motion(arena, attacker, [ADELANTE])
	(attacker.agent as Scripted).press(FighterInput.BTN_HP)
	_run(arena, 2)
	_check("adelante + puño fuerte a bocajarro saca el agarre",
		attacker.current_move != null and attacker.current_move.id == &"agarre")
	_run(arena, 20)
	_check("el agarre atraviesa el bloqueo", defender.health < defender.stats.max_health)
	arena.free()

	arena = _make_arena()
	attacker = arena.fighters[0]
	attacker.pos_x = FP.from_px(-90.0)
	arena.fighters[1].pos_x = FP.from_px(90.0)
	_input_motion(arena, attacker, [ADELANTE])
	(attacker.agent as Scripted).press(FighterInput.BTN_HP)
	_run(arena, 2)
	_check("fuera de rango el mismo botón saca el puñetazo normal, no el agarre",
		attacker.current_move != null and attacker.current_move.id == &"stand_hp")
	arena.free()


# --- Utilidades --------------------------------------------------------------

func _buffer_with(dirs: Array) -> InputBuffer:
	var buffer := InputBuffer.new()
	var snapshot := FighterInput.new()
	for dir: Array in dirs:
		snapshot.dir_x = dir[0]
		snapshot.dir_y = dir[1]
		buffer.push(snapshot, 1)
	return buffer


func _repeat(dir: Array, times: int) -> Array:
	var out := []
	for i in times:
		out.append(dir)
	return out


## Separa a los luchadores `half` píxeles del centro cada uno.
func _separate(arena: CombatArena, half: float) -> void:
	arena.fighters[0].pos_x = FP.from_px(-half)
	arena.fighters[1].pos_x = FP.from_px(half)


## Ejecuta una secuencia de direcciones en el combate real, dos ticks por paso.
func _input_motion(arena: CombatArena, fighter: Fighter, dirs: Array) -> void:
	var agent: Scripted = fighter.agent
	for dir: Array in dirs:
		agent.hold(dir[0], dir[1])
		_run(arena, 2)

func _make_arena(p1: String = "", p2: String = "") -> CombatArena:
	var arena: CombatArena = ARENA_SCENE.instantiate()
	# Se fijan antes de entrar en el árbol: _ready() crea a los luchadores.
	arena.p1_override = p1
	arena.p2_override = p2
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
