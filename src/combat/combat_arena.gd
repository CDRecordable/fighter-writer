class_name CombatArena
extends Node2D
## Prototipo gris de la Fase 1 (PLAN.md §9): dos rectángulos que se pegan.
##
## La arena es el reloj del combate. Ejecuta cada tick en un orden fijo y
## explícito para los dos luchadores; nadie se mueve por su cuenta. Ese orden
## es lo que hace la simulación determinista y lo que evita el clásico bug de
## "el jugador 1 gana los intercambios porque se procesa antes".
##
## Teclas de desarrollo: F1 cajas, F2 modo del muñeco, F5 reiniciar combate.

const TICKS_PER_SECOND := 60
const ROUND_SECONDS := 99
const ROUNDS_TO_WIN := 2

## Escenario que se carga (stages/<id>/stage.json). Fase 1: el galeón de
## Reverte, que es el que valida la Fase 2 según el plan.
const STAGE_ID := "galeon"

const STAGE_HALF_WIDTH := 360  ## px a cada lado del centro (por defecto)
const VIEW_HALF_WIDTH := 240   ## mitad de la resolución interna (480)
const WALL_MARGIN := 18        ## px que el cuerpo no puede pasar del borde
const START_DISTANCE := 62     ## px de separación inicial entre luchadores
const FLOOR_SCREEN_Y := 96     ## altura del suelo respecto al centro de cámara

const INTRO_TICKS := 96
const KO_TICKS := 150

enum RoundState { INTRO, FIGHTING, KO, MATCH_END }

var fighters: Array[Fighter] = []
var projectiles: Array[Projectile] = []
var stage: Stage = null
var effects: Effects = null
## Sacudida de cámara. Es puramente visual: desplaza la cámara, nunca una
## posición del combate, así que no toca la simulación ni el determinismo.
var shake_power: float = 0.0
var shake_tick: int = 0
## Punto de contacto del último golpe encontrado, para colocar las chispas.
## Lo deja `_find_hit`, que es quien sabe dónde se han cruzado las cajas.
var _contact_point := Vector2.ZERO
## Medidas efectivas del escenario. Las manda el stage.json si existe; si no,
## se quedan las constantes de arriba y el fondo provisional.
var stage_half_width: int = STAGE_HALF_WIDTH
var floor_screen_y: int = FLOOR_SCREEN_Y
var hud: CanvasLayer = null
var camera: Camera2D = null
var dummy: Agents.Dummy = null

## Quién pelea. Se pueden fijar antes de meter la arena en el árbol; vacío
## significa "elige tú". Es por donde entrará la pantalla de selección de la
## Fase 2, y por donde el informe de frames mide a cada personaje.
var p1_override: String = ""
var p2_override: String = ""

var round_state: int = RoundState.INTRO
var round_state_frame: int = 0
var round_number: int = 1
var rounds_won := [0, 0]
var clock_ticks: int = ROUND_SECONDS * TICKS_PER_SECOND
var show_boxes: bool = false
var accessible_mode: bool = false
## Solo observa y mide; si desapareciera, el combate se comportaría igual.
var training := Training.new()
var banner: String = ""
var dummy_mode_label: String = "Agresiva"


func _ready() -> void:
	_build_stage()
	_build_camera()
	_build_fighters()
	_build_effects()
	_build_hud()
	_start_round(1)


func _build_effects() -> void:
	effects = Effects.new()
	effects.name = "Efectos"
	add_child(effects)
	for fighter in fighters:
		fighter.landed.connect(_on_fighter_landed.bind(fighter))


func _on_fighter_landed(hard: bool, fighter: Fighter) -> void:
	var at := Vector2(FP.floor_px(fighter.pos_x), 0.0)
	effects.dust(at, 12 if hard else 6, 95.0 if hard else 55.0)
	if hard:
		_shake(1.6)


## El escenario manda sobre sus propias medidas: cuánto mide de ancho y a qué
## altura de pantalla queda el suelo. Así un escenario estrecho y agobiante o
## uno largo son cosa de datos, no de tocar la arena.
func _build_stage() -> void:
	var data := StageData.load_stage(STAGE_ID)
	if data == null:
		return
	stage_half_width = data.half_width
	floor_screen_y = data.floor_screen_y
	stage = Stage.new()
	stage.name = "Escenario"
	stage.setup(data)
	add_child(stage)


func _build_camera() -> void:
	camera = Camera2D.new()
	camera.name = "Camara"
	camera.position = Vector2(0, -floor_screen_y)
	camera.position_smoothing_enabled = false
	add_child(camera)
	camera.make_current()


func _build_fighters() -> void:
	var ids := CharacterLoader.list_ids()
	if ids.is_empty():
		push_error("No hay personajes en res://characters/. El combate no puede arrancar.")
		return

	# Jugable Cristina; de rival, el primer otro personaje que haya. En cuanto
	# existe un segundo escritor deja de ser un espejo y el balance empieza a
	# significar algo.
	var p1_id := p1_override
	if p1_id == "" or not ids.has(p1_id):
		p1_id = "cristina_morales" if ids.has("cristina_morales") else ids[0]
	var p2_id := p2_override
	if p2_id == "" or not ids.has(p2_id):
		p2_id = p1_id
		for id in ids:
			if id != p1_id:
				p2_id = id
				break
	var espejo := p1_id == p2_id

	for index in [1, 2]:
		var stats := CharacterLoader.load_stats(p1_id if index == 1 else p2_id)
		if stats == null:
			return
		var fighter := Fighter.new()
		fighter.name = "Luchador%d" % index
		if index == 2:
			dummy = Agents.Dummy.new()
			fighter.setup(stats, dummy, index)
			if espejo:
				# En espejo los dos usan la misma hoja: sin esto son el mismo
				# muñeco y no sabes a quién estás moviendo.
				stats.debug_color = Color(0.18, 0.71, 0.77)
				fighter.sprite_tint = Color(0.45, 0.85, 1.0)
		else:
			fighter.setup(stats, Agents.Human.new(1), index)
		add_child(fighter)
		fighters.append(fighter)

	fighters[0].opponent = fighters[1]
	fighters[1].opponent = fighters[0]


func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "HUD"
	var panel := CombatHUD.new()
	panel.arena = self
	hud.add_child(panel)
	add_child(hud)
	# and_offsets, no solo anchors: colgando de un CanvasLayer el Control no
	# tiene padre Control que lo estire, y se quedaría con tamaño cero.
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


# --- Bucle -------------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	tick()


## Un tick completo de combate. Separado de _physics_process a propósito: así
## las pruebas (y mañana un replay o el rollback) pueden hacer avanzar el
## combate paso a paso sin depender del reloj del motor.
func tick() -> void:
	if fighters.size() < 2:
		return
	_handle_dev_keys()

	match round_state:
		RoundState.INTRO:
			_tick_intro()
		RoundState.FIGHTING:
			_tick_fight()
		RoundState.KO:
			_tick_ko()
		RoundState.MATCH_END:
			pass

	for fighter in fighters:
		fighter.update_visual()
	for projectile in projectiles:
		projectile.update_visual()
	_update_camera()
	round_state_frame += 1


func _tick_intro() -> void:
	# Los cuerpos siguen simulándose (caen, se colocan) pero no aceptan input.
	for fighter in fighters:
		fighter.input.clear()
		fighter.tick_simulate()
	_resolve_pushboxes()
	_clamp_to_stage()
	banner = ("ROUND %d" % round_number) if round_state_frame < INTRO_TICKS - 36 else "¡PELEA!"
	if round_state_frame >= INTRO_TICKS:
		banner = ""
		_set_round_state(RoundState.FIGHTING)


func _tick_fight() -> void:
	for fighter in fighters:
		fighter.update_facing()
	for fighter in fighters:
		fighter.tick_input()
	for fighter in fighters:
		fighter.tick_simulate()

	_resolve_pushboxes()
	_clamp_to_stage()
	_resolve_hits()
	_spawn_requested_projectiles()
	_tick_projectiles()
	training.tick(fighters)

	if _any_in_hitstop():
		return  # El reloj también se congela con el golpe.

	clock_ticks -= 1
	if clock_ticks <= 0:
		clock_ticks = 0
		_end_round_by_timeout()
		return

	for fighter in fighters:
		if fighter.health <= 0:
			_end_round(fighter.player_index)
			return


func _tick_ko() -> void:
	for fighter in fighters:
		fighter.input.clear()
		fighter.tick_simulate()
	_clamp_to_stage()
	if round_state_frame >= KO_TICKS:
		if rounds_won[0] >= ROUNDS_TO_WIN or rounds_won[1] >= ROUNDS_TO_WIN:
			var ganador := 0 if rounds_won[0] > rounds_won[1] else 1
			banner = "GANA %s" % fighters[ganador].stats.display_name.to_upper()
			if ganador == 0:
				# Vencer a un escritor abre su ficha en la Biblioteca
				# (PLAN.md §6): la literatura se gana, no se sirve de entrada.
				Progreso.desbloquear(String(fighters[1].stats.id))
			_set_round_state(RoundState.MATCH_END)
		else:
			_start_round(round_number + 1)


# --- Reglas del combate ------------------------------------------------------

func _start_round(number: int) -> void:
	round_number = number
	clock_ticks = ROUND_SECONDS * TICKS_PER_SECOND
	var start := FP.from_px(START_DISTANCE)
	_clear_projectiles()
	if effects != null:
		effects.clear()
	shake_power = 0.0
	fighters[0].reset_for_round(-start, 1)
	fighters[1].reset_for_round(start, -1)
	banner = ""
	_set_round_state(RoundState.INTRO)


func _end_round(loser_index: int) -> void:
	var winner := 0 if loser_index == 2 else 1
	rounds_won[winner] += 1
	banner = "K.O."
	_set_round_state(RoundState.KO)


func _end_round_by_timeout() -> void:
	# Se acabó el tiempo: gana quien conserve más vida; si empatan, doble KO.
	var r0 := fighters[0].health_ratio()
	var r1 := fighters[1].health_ratio()
	if is_equal_approx(r0, r1):
		rounds_won[0] += 1
		rounds_won[1] += 1
		banner = "DOBLE K.O."
	else:
		var winner := 0 if r0 > r1 else 1
		rounds_won[winner] += 1
		banner = "TIEMPO"
	_set_round_state(RoundState.KO)


func _set_round_state(new_state: int) -> void:
	round_state = new_state
	round_state_frame = 0


## Los pushboxes impiden que los cuerpos se atraviesen. Se separan a partes
## iguales para que ninguno de los dos gane terreno gratis en un forcejeo.
func _resolve_pushboxes() -> void:
	var a := fighters[0]
	var b := fighters[1]
	var box_a := a.pushbox_world()
	var box_b := b.pushbox_world()
	if not BoxData.overlaps(box_a, box_b):
		return
	var overlap: int
	if a.pos_x <= b.pos_x:
		overlap = box_a[2] - box_b[0]
		a.pos_x -= overlap / 2
		b.pos_x += overlap - overlap / 2
	else:
		overlap = box_b[2] - box_a[0]
		b.pos_x -= overlap / 2
		a.pos_x += overlap - overlap / 2


## Nadie sale de la pantalla ni del escenario, como en SF2.
func _clamp_to_stage() -> void:
	var center := _camera_center_px()
	var view_min := FP.from_px(float(center - VIEW_HALF_WIDTH + WALL_MARGIN))
	var view_max := FP.from_px(float(center + VIEW_HALF_WIDTH - WALL_MARGIN))
	var stage_min := FP.from_px(float(-stage_half_width + WALL_MARGIN))
	var stage_max := FP.from_px(float(stage_half_width - WALL_MARGIN))
	for fighter in fighters:
		fighter.pos_x = clampi(fighter.pos_x, maxi(view_min, stage_min), mini(view_max, stage_max))


## Se recogen los golpes de los dos ANTES de aplicar ninguno. Si se aplicaran
## sobre la marcha, el primero en procesarse metería al otro en hitstun y le
## robaría su golpe: los intercambios simultáneos (trades) dejarían de existir.
func _resolve_hits() -> void:
	var hit_a := _find_hit(fighters[0], fighters[1])
	var contact_a := _contact_point
	var hit_b := _find_hit(fighters[1], fighters[0])
	var contact_b := _contact_point
	if hit_a != null:
		_apply_hit(fighters[0], fighters[1], hit_a, contact_a)
	if hit_b != null:
		_apply_hit(fighters[1], fighters[0], hit_b, contact_b)


func _find_hit(attacker: Fighter, defender: Fighter) -> MoveData:
	var hitboxes := attacker.active_hitboxes()
	if hitboxes.is_empty() or defender.state == Fighter.State.KO:
		return null
	var hurtboxes := defender.active_hurtboxes()
	for hitbox in hitboxes:
		var a := hitbox.to_world(attacker.pos_x, attacker.pos_y, attacker.facing)
		for hurtbox in hurtboxes:
			var b := hurtbox.to_world(defender.pos_x, defender.pos_y, defender.facing)
			if BoxData.overlaps(a, b):
				# Centro del solape: es donde el jugador está mirando cuando
				# conecta, así que es donde tiene que salir la chispa.
				_contact_point = Vector2(
					FP.floor_px((maxi(a[0], b[0]) + mini(a[2], b[2])) / 2),
					-FP.floor_px((maxi(a[1], b[1]) + mini(a[3], b[3])) / 2)
				)
				return attacker.current_move
	return null


func _apply_hit(attacker: Fighter, defender: Fighter, move: MoveData, contact: Vector2) -> void:
	# Se marca antes de nada: un grupo de impacto pega una vez, aunque su
	# hitbox siga activa varios frames.
	attacker.register_hit()
	var result := defender.receive_hit(move, attacker.pos_x)

	if result == Fighter.HitResult.COUNTERED:
		# El contraataque se ha tragado el golpe: ni daño, ni hitstop, ni
		# Tinta. La respuesta del que contra ya llegará por su cuenta.
		effects.block(contact, attacker.facing)
		return

	var blocked := result == Fighter.HitResult.BLOCKED
	_spawn_impact(contact, attacker.facing, move, blocked)
	training.on_hit(attacker, defender, move, blocked)

	attacker.hitstop = move.hitstop
	defender.hitstop = move.hitstop
	# En un intercambio simultáneo el atacante puede haber entrado ya en
	# hitstun por el golpe del otro: entonces manda ese empuje, no el suyo.
	if attacker.is_attacking():
		attacker.vel_x = -attacker.facing * move.self_pushback
	_award_meter(attacker, move, result == Fighter.HitResult.BLOCKED)


## El atacante también carga Tinta, pero menos que quien encaja: la barra
## premia la agresividad sin regalar súperes por pegarle al bloqueo.
func _award_meter(attacker: Fighter, hit: HitProperties, blocked: bool) -> void:
	var gain := hit.meter_block if blocked else hit.meter_hit
	attacker.meter = mini(attacker.stats.max_meter, attacker.meter + gain / 2)


## Chispas y sacudida. La fuerza sale del hitstop del golpe, que ya es la
## medida de "peso" que usa el combate: así el efecto y la sensación no se
## pueden desincronizar al tocar el balance.
func _spawn_impact(contact: Vector2, direction: int, hit: HitProperties, blocked: bool) -> void:
	var strength := clampf(float(hit.hitstop) / 10.0, 0.3, 1.6)
	if blocked:
		effects.block(contact, direction)
		_shake(strength * 0.6)
	else:
		effects.hit(contact, direction, strength)
		_shake(strength * 1.8)


func _shake(power: float) -> void:
	shake_power = maxf(shake_power, power)


# --- Proyectiles -------------------------------------------------------------

func _spawn_requested_projectiles() -> void:
	for fighter in fighters:
		for projectile_id in fighter.take_pending_spawns():
			var data := fighter.stats.get_projectile(projectile_id)
			if data == null:
				push_error("Proyectil desconocido: %s" % projectile_id)
				continue
			var projectile := Projectile.new()
			projectile.setup(data, fighter)
			projectile.show_boxes = show_boxes
			add_child(projectile)
			projectiles.append(projectile)


func _tick_projectiles() -> void:
	var survivors: Array[Projectile] = []
	for projectile in projectiles:
		projectile.tick()
		if not projectile.dead:
			_check_projectile_hit(projectile)
		if projectile.dead or absi(FP.floor_px(projectile.pos_x)) > stage_half_width:
			projectile.queue_free()
		else:
			survivors.append(projectile)
	projectiles = survivors


func _check_projectile_hit(projectile: Projectile) -> void:
	for defender in fighters:
		if defender == projectile.shooter or defender.state == Fighter.State.KO:
			continue
		var box := projectile.world_box()
		for hurtbox in defender.active_hurtboxes():
			if not BoxData.overlaps(box, hurtbox.to_world(defender.pos_x, defender.pos_y, defender.facing)):
				continue
			var result := defender.receive_hit(projectile.data, projectile.pos_x)
			var contact := Vector2(FP.floor_px(projectile.pos_x), -FP.floor_px(projectile.pos_y))
			# Un proyectil se consume aunque lo contraataquen: la Asamblea
			# absorbe el panfleto igual que absorbe un puño.
			projectile.dead = true
			if result == Fighter.HitResult.COUNTERED:
				effects.block(contact, projectile.facing)
				return
			var blocked := result == Fighter.HitResult.BLOCKED
			_spawn_impact(contact, projectile.facing, projectile.data, blocked)
			training.on_hit(projectile.shooter, defender, projectile.data, blocked)
			defender.hitstop = projectile.data.hitstop
			_award_meter(projectile.shooter, projectile.data, result == Fighter.HitResult.BLOCKED)
			return


func _clear_projectiles() -> void:
	for projectile in projectiles:
		projectile.queue_free()
	projectiles.clear()


func _any_in_hitstop() -> bool:
	for fighter in fighters:
		if fighter.hitstop > 0:
			return true
	return false


# --- Cámara y utilidades -----------------------------------------------------

func _camera_center_px() -> int:
	var mid := (fighters[0].pos_x + fighters[1].pos_x) / 2
	var limit := stage_half_width - VIEW_HALF_WIDTH
	return clampi(FP.floor_px(mid), -limit, limit)


func _update_camera() -> void:
	# Oscilación determinista, sin azar: la sacudida no debe meter aleatoriedad
	# en el bucle del combate ni aunque sea solo visual.
	shake_tick += 1
	var offset := Vector2.ZERO
	if shake_power > 0.05:
		offset = Vector2(
			sin(float(shake_tick) * 2.7) * shake_power,
			sin(float(shake_tick) * 4.1) * shake_power * 0.6
		)
		shake_power *= 0.80
	else:
		shake_power = 0.0
	camera.position = Vector2(_camera_center_px(), -floor_screen_y) + offset.round()
	if stage != null:
		stage.advance(camera.position.x)


func _handle_dev_keys() -> void:
	if Input.is_action_just_pressed(&"dev_toggle_boxes"):
		show_boxes = not show_boxes
		for fighter in fighters:
			fighter.show_boxes = show_boxes
		for projectile in projectiles:
			projectile.show_boxes = show_boxes
		queue_redraw()  # las reglas de distancia van con las cajas
	if Input.is_action_just_pressed(&"dev_toggle_accessible"):
		accessible_mode = not accessible_mode
		for fighter in fighters:
			fighter.accessible_mode = accessible_mode
	if Input.is_action_just_pressed(&"dev_reset"):
		rounds_won = [0, 0]
		_start_round(1)
	if Input.is_action_just_pressed(&"dev_toggle_dummy") and dummy != null:
		dummy_mode_label = dummy.cycle_mode()
	if Input.is_action_just_pressed(&"dev_toggle_training"):
		training.enabled = not training.enabled
	if Input.is_action_just_pressed(&"dev_quick_reset"):
		reset_instantaneo()
	if Input.is_action_just_pressed(&"ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


## Vuelve a la posición de salida sin cuenta atrás ni cambio de ronda. Es la
## tecla que más se usa entrenando: probar un combo, fallar, y volver a estar
## listo antes de que se te olvide qué querías probar.
func reset_instantaneo() -> void:
	var start := FP.from_px(START_DISTANCE)
	_clear_projectiles()
	effects.clear()
	shake_power = 0.0
	training.reset()
	fighters[0].reset_for_round(-start, 1)
	fighters[1].reset_for_round(start, -1)
	banner = ""
	_set_round_state(RoundState.FIGHTING)


func clock_seconds() -> int:
	return int(ceil(float(clock_ticks) / float(TICKS_PER_SECOND)))


func _draw() -> void:
	if stage != null:
		# Con escenario cargado, las marcas de distancia solo estorban; se
		# encienden con las cajas (F1), que es cuando se están midiendo cosas.
		if show_boxes:
			_draw_reglas()
		return
	# Fondo provisional del prototipo gris, para cuando no hay escenario.
	var left := float(-stage_half_width)
	var width := float(stage_half_width * 2)
	draw_rect(Rect2(left, -220, width, 220), Color(0.10, 0.07, 0.14))
	draw_rect(Rect2(left, 0, width, 60), Color(0.17, 0.13, 0.22))
	draw_line(Vector2(left, 0), Vector2(left + width, 0), Color(0.35, 0.30, 0.42), 1.0)
	_draw_reglas()


## Marcas cada 40 px y los muros del escenario: sirven para leer distancias de
## un vistazo cuando se está afinando el alcance de un golpe.
func _draw_reglas() -> void:
	for x in range(-stage_half_width, stage_half_width + 1, 40):
		draw_line(Vector2(x, 0), Vector2(x, 6), Color(0.28, 0.24, 0.34), 1.0)
	for x in [-stage_half_width + WALL_MARGIN, stage_half_width - WALL_MARGIN]:
		draw_line(Vector2(x, -220), Vector2(x, 0), Color(0.30, 0.20, 0.30), 1.0)
