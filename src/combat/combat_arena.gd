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

const STAGE_HALF_WIDTH := 360  ## px a cada lado del centro
const VIEW_HALF_WIDTH := 240   ## mitad de la resolución interna (480)
const WALL_MARGIN := 18        ## px que el cuerpo no puede pasar del borde
const START_DISTANCE := 62     ## px de separación inicial entre luchadores
const FLOOR_SCREEN_Y := 96     ## altura del suelo respecto al centro de cámara

const INTRO_TICKS := 96
const KO_TICKS := 150

enum RoundState { INTRO, FIGHTING, KO, MATCH_END }

var fighters: Array[Fighter] = []
var projectiles: Array[Projectile] = []
var hud: CanvasLayer = null
var camera: Camera2D = null
var dummy: Agents.Dummy = null

var round_state: int = RoundState.INTRO
var round_state_frame: int = 0
var round_number: int = 1
var rounds_won := [0, 0]
var clock_ticks: int = ROUND_SECONDS * TICKS_PER_SECOND
var show_boxes: bool = false
var accessible_mode: bool = false
var banner: String = ""
var dummy_mode_label: String = "Agresiva"


func _ready() -> void:
	_build_camera()
	_build_fighters()
	_build_hud()
	_start_round(1)


func _build_camera() -> void:
	camera = Camera2D.new()
	camera.name = "Camara"
	camera.position = Vector2(0, -FLOOR_SCREEN_Y)
	camera.position_smoothing_enabled = false
	add_child(camera)
	camera.make_current()


func _build_fighters() -> void:
	var ids := CharacterLoader.list_ids()
	if ids.is_empty():
		push_error("No hay personajes en res://characters/. El combate no puede arrancar.")
		return

	# Fase 1: Cristina contra sí misma. Es a propósito — un espejo aísla el
	# game feel del balance entre personajes, que aún no toca.
	var character_id := "cristina_morales" if ids.has("cristina_morales") else ids[0]

	for index in [1, 2]:
		var stats := CharacterLoader.load_stats(character_id)
		if stats == null:
			return
		var fighter := Fighter.new()
		fighter.name = "Luchador%d" % index
		if index == 2:
			stats.debug_color = Color(0.18, 0.71, 0.77)
			dummy = Agents.Dummy.new()
			fighter.setup(stats, dummy, index)
			# En espejo los dos usan la misma hoja: sin esto son el mismo
			# muñeco y no sabes a quién estás moviendo.
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
			banner = "GANA %s" % fighters[0 if rounds_won[0] > rounds_won[1] else 1].stats.display_name.to_upper()
			_set_round_state(RoundState.MATCH_END)
		else:
			_start_round(round_number + 1)


# --- Reglas del combate ------------------------------------------------------

func _start_round(number: int) -> void:
	round_number = number
	clock_ticks = ROUND_SECONDS * TICKS_PER_SECOND
	var start := FP.from_px(START_DISTANCE)
	_clear_projectiles()
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
	var stage_min := FP.from_px(float(-STAGE_HALF_WIDTH + WALL_MARGIN))
	var stage_max := FP.from_px(float(STAGE_HALF_WIDTH - WALL_MARGIN))
	for fighter in fighters:
		fighter.pos_x = clampi(fighter.pos_x, maxi(view_min, stage_min), mini(view_max, stage_max))


## Se recogen los golpes de los dos ANTES de aplicar ninguno. Si se aplicaran
## sobre la marcha, el primero en procesarse metería al otro en hitstun y le
## robaría su golpe: los intercambios simultáneos (trades) dejarían de existir.
func _resolve_hits() -> void:
	var hit_a := _find_hit(fighters[0], fighters[1])
	var hit_b := _find_hit(fighters[1], fighters[0])
	if hit_a != null:
		_apply_hit(fighters[0], fighters[1], hit_a)
	if hit_b != null:
		_apply_hit(fighters[1], fighters[0], hit_b)


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
				return attacker.current_move
	return null


func _apply_hit(attacker: Fighter, defender: Fighter, move: MoveData) -> void:
	# Se marca antes de nada: un grupo de impacto pega una vez, aunque su
	# hitbox siga activa varios frames.
	attacker.register_hit()
	var result := defender.receive_hit(move, attacker.pos_x)

	if result == Fighter.HitResult.COUNTERED:
		# El contraataque se ha tragado el golpe: ni daño, ni hitstop, ni
		# Tinta. La respuesta del que contra ya llegará por su cuenta.
		return

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
		if projectile.dead or absi(FP.floor_px(projectile.pos_x)) > STAGE_HALF_WIDTH:
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
			# Un proyectil se consume aunque lo contraataquen: la Asamblea
			# absorbe el panfleto igual que absorbe un puño.
			projectile.dead = true
			if result == Fighter.HitResult.COUNTERED:
				return
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
	var limit := STAGE_HALF_WIDTH - VIEW_HALF_WIDTH
	return clampi(FP.floor_px(mid), -limit, limit)


func _update_camera() -> void:
	camera.position = Vector2(_camera_center_px(), -FLOOR_SCREEN_Y)


func _handle_dev_keys() -> void:
	if Input.is_action_just_pressed(&"dev_toggle_boxes"):
		show_boxes = not show_boxes
		for fighter in fighters:
			fighter.show_boxes = show_boxes
		for projectile in projectiles:
			projectile.show_boxes = show_boxes
	if Input.is_action_just_pressed(&"dev_toggle_accessible"):
		accessible_mode = not accessible_mode
		for fighter in fighters:
			fighter.accessible_mode = accessible_mode
	if Input.is_action_just_pressed(&"dev_reset"):
		rounds_won = [0, 0]
		_start_round(1)
	if Input.is_action_just_pressed(&"dev_toggle_dummy") and dummy != null:
		dummy_mode_label = dummy.cycle_mode()


func clock_seconds() -> int:
	return int(ceil(float(clock_ticks) / float(TICKS_PER_SECOND)))


func _draw() -> void:
	# Escenario provisional: suelo y marcas cada 40 px para leer distancias.
	var left := float(-STAGE_HALF_WIDTH)
	var width := float(STAGE_HALF_WIDTH * 2)
	draw_rect(Rect2(left, -220, width, 220), Color(0.10, 0.07, 0.14))
	draw_rect(Rect2(left, 0, width, 60), Color(0.17, 0.13, 0.22))
	draw_line(Vector2(left, 0), Vector2(left + width, 0), Color(0.35, 0.30, 0.42), 1.0)
	for x in range(-STAGE_HALF_WIDTH, STAGE_HALF_WIDTH + 1, 40):
		draw_line(Vector2(x, 0), Vector2(x, 6), Color(0.28, 0.24, 0.34), 1.0)
	for x in [-STAGE_HALF_WIDTH + WALL_MARGIN, STAGE_HALF_WIDTH - WALL_MARGIN]:
		draw_line(Vector2(x, -220), Vector2(x, 0), Color(0.30, 0.20, 0.30), 1.0)
