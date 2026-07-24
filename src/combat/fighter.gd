class_name Fighter
extends Node2D
## Un luchador: máquina de estados + física propia en punto fijo.
##
## No usa CharacterBody2D ni nada del motor de física: integra su propio
## movimiento con enteros (ver src/core/fp.gd). Un juego de lucha necesita
## control frame a frame que la física del motor no da, y el determinismo es
## requisito para el rollback futuro (PLAN.md §11).
##
## Quien manda el reloj es la arena, no el nodo: llama a tick_input() y
## tick_simulate() en un orden fijo para los dos luchadores. Por eso aquí no
## hay _physics_process().

enum State {
	IDLE,
	WALK_F,
	WALK_B,
	CROUCH,
	JUMPSQUAT,
	AIR,
	LANDING,
	ATTACK,
	HITSTUN,
	BLOCKSTUN,
	KO,
}

enum HitResult { HIT, BLOCKED, COUNTERED }

## Estados desde los que se puede empezar una acción nueva. En la v1 no hay
## cancels (PLAN.md §3): los combos salen del enlace natural de frames.
const NEUTRAL_GROUND := [State.IDLE, State.WALK_F, State.WALK_B, State.CROUCH]

signal took_damage(amount: int, blocked: bool)
signal knocked_out

var stats: FighterStats = null
var agent: Agents.Agent = null
var opponent: Fighter = null
var player_index: int = 1

## +1 mira a la derecha, -1 a la izquierda.
var facing: int = 1
var pos_x: int = 0  ## fixed, centro del cuerpo
var pos_y: int = 0  ## fixed, altura sobre el suelo (0 = pisando)
var vel_x: int = 0
var vel_y: int = 0
var airborne: bool = false

var state: int = State.IDLE
var state_frame: int = 0

var current_move: MoveData = null
var move_frame: int = 0

var health: int = 0
var meter: int = 0
var stun_frames: int = 0
var hitstop: int = 0
var blocking_low: bool = false
var jump_dir: int = 0

var input := FighterInput.new()
var buffer := InputBuffer.new()

## Modo accesible (PLAN.md §3): especiales con un botón y una dirección, sin
## medias lunas. Lo enciende la arena; es una opción del jugador, no una
## dificultad distinta.
var accessible_mode: bool = false

## Proyectiles que este luchador ha pedido lanzar en este tick. Los recoge la
## arena, que es quien puede meterlos en el escenario.
var pending_spawns: Array[StringName] = []

## Lo enciende la arena con F1. En un juego de lucha ver las cajas no es un
## lujo de depuración: es la única forma de juzgar si un golpe es justo.
var show_boxes: bool = false

## Tinte del sprite. Blanco = el arte tal cual. Sirve de apaño para los
## combates en espejo, donde si no los dos luchadores son indistinguibles. La
## solución de verdad es el cambio de paleta, como en SF2, y es trabajo de arte
## de la Fase 2.
var sprite_tint: Color = Color.WHITE

## Un movimiento golpea una vez por cada hit_id: así los especiales de varios
## golpes conectan varias veces y los normales solo una.
var _connected_hit_ids: Array[int] = []
var _stance_box_buffer: Array[BoxData] = []
var _empty_boxes: Array[BoxData] = []


func setup(stats_in: FighterStats, agent_in: Agents.Agent, index: int) -> void:
	stats = stats_in
	agent = agent_in
	player_index = index
	health = stats.max_health
	_stance_box_buffer.resize(1)


func reset_for_round(start_x: int, start_facing: int) -> void:
	pos_x = start_x
	pos_y = 0
	vel_x = 0
	vel_y = 0
	airborne = false
	facing = start_facing
	state = State.IDLE
	state_frame = 0
	current_move = null
	move_frame = 0
	stun_frames = 0
	hitstop = 0
	blocking_low = false
	health = stats.max_health
	_connected_hit_ids.clear()
	pending_spawns.clear()
	input.clear()
	buffer.clear()
	update_visual()


# --- Bucle de simulación (lo llama la arena) ---------------------------------

func tick_input() -> void:
	if agent == null or state == State.KO:
		input.clear()
	else:
		input.copy_from(agent.poll(self))
	# El historial se alimenta en hitstun y durante un golpe: es justo entonces
	# cuando el jugador prepara el siguiente movimiento. En hitstop, en cambio,
	# el tiempo está parado para todos, así que el buffer tampoco envejece: solo
	# se apunta lo que se pulse.
	if hitstop > 0:
		buffer.merge_press(input.pressed)
	else:
		buffer.push(input, facing)


func tick_simulate() -> void:
	if hitstop > 0:
		hitstop -= 1
		return
	if state == State.KO:
		_apply_physics()
		return
	_advance_state()
	_apply_physics()
	state_frame += 1


func _advance_state() -> void:
	match state:
		State.HITSTUN, State.BLOCKSTUN:
			stun_frames -= 1
			if stun_frames <= 0 and not airborne:
				_enter_neutral()
		State.ATTACK:
			_advance_attack()
		State.JUMPSQUAT:
			if state_frame >= stats.jumpsquat:
				_launch_jump()
		State.LANDING:
			if state_frame >= stats.landing_lag:
				_enter_neutral()
		State.AIR:
			_try_start_action(MoveData.Stance.AIR)
		_:
			_advance_grounded_neutral()


func _advance_grounded_neutral() -> void:
	var crouching := input.dir_y < 0
	if _try_start_action(MoveData.Stance.CROUCH if crouching else MoveData.Stance.STAND):
		return
	if input.dir_y > 0:
		_set_state(State.JUMPSQUAT)
		jump_dir = input.dir_x
		vel_x = 0
		return
	if crouching:
		if state != State.CROUCH:
			_set_state(State.CROUCH)
		vel_x = 0
		return
	if input.dir_x == facing and input.dir_x != 0:
		if state != State.WALK_F:
			_set_state(State.WALK_F)
		vel_x = facing * stats.walk_forward
	elif input.dir_x == -facing and input.dir_x != 0:
		if state != State.WALK_B:
			_set_state(State.WALK_B)
		vel_x = -facing * stats.walk_back
	else:
		if state != State.IDLE:
			_set_state(State.IDLE)
		vel_x = 0


func _advance_attack() -> void:
	move_frame += 1
	var last := current_move.total_frames() - 1
	if current_move.until_land and airborne:
		move_frame = mini(move_frame, last)
		return
	if move_frame > last:
		current_move = null
		_connected_hit_ids.clear()
		if airborne:
			_set_state(State.AIR)
		else:
			_enter_neutral()
		return
	_process_frame_events()


## Lo que ocurre "una vez" al entrar en un tramo: imponer velocidad (los
## especiales que avanzan) o soltar un proyectil.
func _process_frame_events() -> void:
	if not current_move.starts_frame(move_frame):
		return
	var frame := current_move.frame_at(move_frame)
	if frame == null:
		return
	if frame.sets_velocity:
		vel_x = facing * frame.vel_x
	if frame.spawn != &"":
		pending_spawns.append(frame.spawn)


# --- Elegir qué sale ---------------------------------------------------------

## Orden de prueba: primero los comandos difíciles (súper, especiales, agarre) y
## solo después los normales. Al revés, un botón se comería siempre al especial
## que empieza por ese mismo botón.
func _try_start_action(stance: MoveData.Stance) -> bool:
	if _try_accessible_special(stance):
		return true
	if _try_command_move(stance):
		return true
	return _try_normal(stance)


func _try_command_move(stance: MoveData.Stance) -> bool:
	for move: MoveData in stats.command_moves:
		if not _can_start(move, stance):
			continue
		if buffer.pressed_within(move.button_mask) == 0:
			continue
		if not buffer.matches(move.motion):
			continue
		_start_move(move)
		return true
	return false


## Modo accesible: un botón dedicado + la dirección que estés manteniendo.
## Nada de medias lunas. La correspondencia dirección→movimiento es provisional
## y hay que probarla con gente no jugona antes de cerrarla.
func _try_accessible_special(stance: MoveData.Stance) -> bool:
	if not accessible_mode:
		return false
	if buffer.pressed_within(FighterInput.BTN_SPECIAL) == 0:
		return false
	var move := _accessible_move()
	if move == null or not _can_start(move, stance):
		return false
	_start_move(move)
	return true


func _accessible_move() -> MoveData:
	var dir := buffer.current_dir()
	if dir in InputBuffer.UP_DIRS:
		return _find_super()
	if dir in InputBuffer.DOWN_DIRS:
		return _find_command(&"214")
	if dir in InputBuffer.FORWARD_DIRS:
		return _find_command(&"623")
	if dir in InputBuffer.BACK_DIRS:
		return _find_command(&"charge46")
	return _find_command(&"236")


func _find_command(motion: StringName) -> MoveData:
	for move: MoveData in stats.command_moves:
		if move.motion == motion and move.meter_cost == 0:
			return move
	return null


func _find_super() -> MoveData:
	for move: MoveData in stats.command_moves:
		if move.meter_cost > 0:
			return move
	return null


## Los normales leen el buffer igual que los especiales. Es lo que hace que
## pulsar el botón un par de frames antes de recuperarte saque el golpe en
## cuanto puedes, en vez de tragárselo.
func _try_normal(stance: MoveData.Stance) -> bool:
	for button in [FighterInput.BTN_LP, FighterInput.BTN_HP, FighterInput.BTN_LK, FighterInput.BTN_HK]:
		if buffer.pressed_within(button) == 0:
			continue
		var move := stats.get_move(FighterStats.move_id_for(stance, button))
		if move == null or move.total_frames() == 0:
			continue
		_start_move(move)
		return true
	return false


func _can_start(move: MoveData, stance: MoveData.Stance) -> bool:
	if move.total_frames() == 0:
		return false
	# Los especiales de suelo salen igual de pie que agachado, como en SF2; los
	# aéreos solo en el aire.
	if stance == MoveData.Stance.AIR:
		if move.stance != MoveData.Stance.AIR:
			return false
	elif move.stance == MoveData.Stance.AIR:
		return false
	if move.meter_cost > 0 and meter < move.meter_cost:
		return false
	return _range_ok(move)


func _range_ok(move: MoveData) -> bool:
	if move.max_range <= 0:
		return true
	if opponent == null:
		return false
	if move.requires_grounded_target and opponent.airborne:
		return false
	return absi(distance_to_opponent()) <= move.max_range


func _start_move(move: MoveData) -> void:
	current_move = move
	move_frame = 0
	_connected_hit_ids.clear()
	_set_state(State.ATTACK)
	if not airborne:
		vel_x = 0
	if move.meter_cost > 0:
		meter = maxi(0, meter - move.meter_cost)
		if opponent != null and move.super_freeze > 0:
			opponent.hitstop = maxi(opponent.hitstop, move.super_freeze)
	# Sin esto, la misma pulsación (o la misma media luna, que sigue en el
	# historial) dispararía el movimiento otra vez al tick siguiente.
	if move.is_command_move():
		buffer.consume()
	else:
		buffer.consume_buttons()
	_process_frame_events()


func _launch_jump() -> void:
	airborne = true
	vel_y = stats.jump_impulse
	vel_x = jump_dir * stats.jump_forward
	_set_state(State.AIR)


func _apply_physics() -> void:
	pos_x += vel_x
	if airborne:
		vel_y -= stats.gravity
		pos_y += vel_y
		if pos_y <= 0:
			_land()
	elif state in [State.HITSTUN, State.BLOCKSTUN, State.LANDING, State.ATTACK, State.KO]:
		# Rozamiento: el empuje de un golpe (o el avance de un especial) se
		# disipa en unos frames en vez de deslizar para siempre. División
		# entera = determinista.
		vel_x -= vel_x / 6
		if absi(vel_x) < FP.from_px(0.08):
			vel_x = 0


func _land() -> void:
	pos_y = 0
	vel_y = 0
	airborne = false
	if state == State.KO:
		vel_x = 0
		return
	if state == State.HITSTUN or state == State.BLOCKSTUN:
		# Caer al suelo en hitstun aéreo es un derribo: se levanta al acabar.
		stun_frames = maxi(stun_frames, 12)
		return
	current_move = null
	_connected_hit_ids.clear()
	vel_x = 0
	_set_state(State.LANDING)


func _enter_neutral() -> void:
	current_move = null
	_connected_hit_ids.clear()
	blocking_low = false
	_set_state(State.CROUCH if input.dir_y < 0 else State.IDLE)


func _set_state(new_state: int) -> void:
	state = new_state
	state_frame = 0


# --- Golpes ------------------------------------------------------------------

## Encaja un golpe venga de donde venga (un movimiento o un proyectil: los dos
## son HitProperties). Devuelve un HitResult para que la arena sepa qué contar.
func receive_hit(hit: HitProperties, from_x: int) -> int:
	if _try_counter():
		return HitResult.COUNTERED

	var blocked := not hit.unblockable and _can_block(hit)
	var away := 1 if pos_x >= from_x else -1

	if blocked:
		blocking_low = input.dir_y < 0
		stun_frames = hit.blockstun
		vel_x = away * hit.pushback_block
		meter = mini(stats.max_meter, meter + hit.meter_block)
		_set_state(State.BLOCKSTUN)
		took_damage.emit(0, true)
		return HitResult.BLOCKED

	health = maxi(0, health - hit.damage)
	stun_frames = hit.hitstun
	vel_x = away * hit.pushback_hit
	meter = mini(stats.max_meter, meter + hit.meter_hit)
	current_move = null
	_connected_hit_ids.clear()
	if hit.knockdown and not airborne:
		airborne = true
		vel_y = FP.from_px(3.2)
	_set_state(State.HITSTUN)
	took_damage.emit(hit.damage, false)

	if health <= 0:
		_set_state(State.KO)
		airborne = true
		vel_y = FP.from_px(4.0)
		vel_x = away * FP.from_px(2.2)
		knocked_out.emit()
	return HitResult.HIT


## La Asamblea de Cristina: si el golpe llega dentro de la ventana del
## contraataque, se absorbe y sale la respuesta (PLAN.md §4).
func _try_counter() -> bool:
	if state != State.ATTACK or current_move == null:
		return false
	if not current_move.is_counter_active(move_frame):
		return false
	var reply := stats.get_move(current_move.counter_move)
	if reply == null:
		return false
	_start_move(reply)
	return true


## Bloqueo por dirección, como SF2: mantener hacia atrás. La altura del golpe
## decide si vale de pie o agachado (HitProperties.Height).
func _can_block(hit: HitProperties) -> bool:
	if state in [State.ATTACK, State.HITSTUN, State.JUMPSQUAT, State.KO, State.LANDING]:
		return false
	if airborne:
		return false  # En el aire no se bloquea (regla clásica).
	if input.dir_x != -facing or input.dir_x == 0:
		return false
	var crouching := input.dir_y < 0 or state == State.CROUCH
	match hit.height:
		HitProperties.Height.LOW:
			return crouching
		HitProperties.Height.OVERHEAD:
			return not crouching
		_:
			return true


## La arena lo llama cuando el movimiento actual conecta, para que ese mismo
## grupo de impacto no vuelva a pegar.
func register_hit() -> void:
	if current_move == null:
		return
	var frame := current_move.frame_at(move_frame)
	var id := frame.hit_id if frame != null else 0
	if not (id in _connected_hit_ids):
		_connected_hit_ids.append(id)


func take_pending_spawns() -> Array[StringName]:
	var out := pending_spawns.duplicate()
	pending_spawns.clear()
	return out


# --- Consultas para la arena -------------------------------------------------

func is_attacking() -> bool:
	return state == State.ATTACK and current_move != null


func active_hitboxes() -> Array[BoxData]:
	if not is_attacking():
		return _empty_boxes
	var frame := current_move.frame_at(move_frame)
	if frame == null or frame.hitboxes.is_empty():
		return _empty_boxes
	if frame.hit_id in _connected_hit_ids:
		return _empty_boxes
	return frame.hitboxes


func active_hurtboxes() -> Array[BoxData]:
	if is_attacking():
		var frame := current_move.frame_at(move_frame)
		if frame != null and not frame.hurtboxes.is_empty():
			return frame.hurtboxes
	_stance_box_buffer[0] = stance_hurtbox()
	return _stance_box_buffer


func stance_hurtbox() -> BoxData:
	if state == State.CROUCH:
		return stats.crouch_hurtbox
	if state == State.BLOCKSTUN and blocking_low:
		return stats.crouch_hurtbox
	if is_attacking() and current_move.stance == MoveData.Stance.CROUCH:
		return stats.crouch_hurtbox
	return stats.stand_hurtbox


func pushbox_world() -> Array[int]:
	return stats.push_box.to_world(pos_x, pos_y, facing)


func distance_to_opponent() -> int:
	if opponent == null:
		return 0
	return opponent.pos_x - pos_x


## El facing solo se recalcula cuando el luchador está libre: darse la vuelta a
## media patada rompería el golpe y el bloqueo.
func update_facing() -> void:
	if opponent == null or airborne or not (state in NEUTRAL_GROUND):
		return
	var delta := opponent.pos_x - pos_x
	if delta > 0:
		facing = 1
	elif delta < 0:
		facing = -1


func health_ratio() -> float:
	return float(health) / float(maxi(1, stats.max_health))


func meter_ratio() -> float:
	return float(meter) / float(maxi(1, stats.max_meter))


func has_super() -> bool:
	return meter >= stats.max_meter


# --- Render ------------------------------------------------------------------

func update_visual() -> void:
	# Posición redondeada al píxel: sin esto el pixel art vibra al moverse.
	position = Vector2(FP.floor_px(pos_x), -FP.floor_px(pos_y))
	queue_redraw()


func _draw() -> void:
	if not _draw_sprite():
		_draw_gray_box()
	if show_boxes:
		draw_debug_boxes()


## Dibuja la celda que toca de la hoja de sprites. Devuelve false si no hay
## arte todavía, y entonces manda el rectángulo del prototipo gris.
func _draw_sprite() -> bool:
	if stats.sprites == null or not stats.sprites.is_ready():
		return false
	var index := _current_sprite_index()
	if index < 0:
		return false
	# El volteo se hace con la transformada, no dibujando el sprite al revés:
	# así el arte se pinta UNA vez mirando a la derecha y el motor se ocupa.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(float(facing), 1.0))
	draw_texture_rect_region(
		stats.sprites.texture,
		stats.sprites.destination(),
		stats.sprites.region(index),
		_tint(sprite_tint)
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true


func _draw_gray_box() -> void:
	var body := stance_hurtbox()
	draw_rect(_local_rect(body), _tint(stats.debug_color))
	# Marca de orientación: en gris no hay sprite que diga hacia dónde miras.
	var eye_x := 2.0 if facing > 0 else -6.0
	draw_rect(Rect2(eye_x, -float(body.y + body.h) + 6.0, 4.0, 4.0), Color(0, 0, 0, 0.75))


## Color de estado. Con sprites es un tinte sobre el dibujo; en gris, el relleno
## del rectángulo. En los dos casos comunica lo mismo: congelado, bloqueando o
## encajando.
func _tint(base: Color = Color.WHITE) -> Color:
	var color := base
	if hitstop > 0:
		color = color.lightened(0.5)
	if state == State.BLOCKSTUN:
		color = color.lerp(Color.WHITE, 0.35)
	elif state == State.HITSTUN or state == State.KO:
		color = color.lerp(Color.RED, 0.45)
	return color


func _current_sprite_index() -> int:
	if is_attacking() and current_move.anim != null and not current_move.anim.is_empty():
		return current_move.anim.index_at(move_frame)
	var anim := stats.get_animation(_animation_key())
	if anim == null or anim.is_empty():
		return -1
	return anim.index_at(state_frame)


func _animation_key() -> StringName:
	match state:
		State.WALK_F: return &"walk_f"
		State.WALK_B: return &"walk_b"
		State.CROUCH: return &"crouch"
		State.JUMPSQUAT: return &"jumpsquat"
		State.AIR: return &"air"
		State.LANDING: return &"landing"
		State.HITSTUN: return &"hitstun"
		State.BLOCKSTUN: return &"blockstun_low" if blocking_low else &"blockstun"
		State.KO: return &"ko"
		_: return &"idle"


## Convierte una BoxData (x adelante, y arriba) al espacio local del nodo,
## que es el de Godot (y hacia abajo) con el origen en los pies.
func _local_rect(box: BoxData) -> Rect2:
	var x := float(box.x) if facing > 0 else float(-(box.x + box.w))
	return Rect2(x, -float(box.y + box.h), float(box.w), float(box.h))


func draw_debug_boxes() -> void:
	for box in active_hurtboxes():
		draw_rect(_local_rect(box), Color(0.2, 0.6, 1.0, 0.35))
		draw_rect(_local_rect(box), Color(0.4, 0.8, 1.0, 0.9), false, 1.0)
	for box in active_hitboxes():
		draw_rect(_local_rect(box), Color(1.0, 0.15, 0.3, 0.35))
		draw_rect(_local_rect(box), Color(1.0, 0.4, 0.5, 0.9), false, 1.0)
	draw_rect(_local_rect(stats.push_box), Color(0.3, 1.0, 0.4, 0.9), false, 1.0)
