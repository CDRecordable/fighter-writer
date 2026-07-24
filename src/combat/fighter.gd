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
var move_connected: bool = false

var health: int = 0
var meter: int = 0
var stun_frames: int = 0
var hitstop: int = 0
var blocking_low: bool = false
var jump_dir: int = 0

var input := FighterInput.new()
## Lo enciende la arena con F1. En un juego de lucha ver las cajas no es un
## lujo de depuración: es la única forma de juzgar si un golpe es justo.
var show_boxes: bool = false

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
	move_connected = false
	stun_frames = 0
	hitstop = 0
	blocking_low = false
	health = stats.max_health
	input.clear()
	update_visual()


# --- Bucle de simulación (lo llama la arena) ---------------------------------

func tick_input() -> void:
	if agent == null or state == State.KO:
		input.clear()
		return
	input.copy_from(agent.poll(self))


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
			_try_start_attack(MoveData.Stance.AIR)
		_:
			_advance_grounded_neutral()


func _advance_grounded_neutral() -> void:
	var crouching := input.dir_y < 0
	if _try_start_attack(MoveData.Stance.CROUCH if crouching else MoveData.Stance.STAND):
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
		move_connected = false
		if airborne:
			_set_state(State.AIR)
		else:
			_enter_neutral()


func _try_start_attack(stance: MoveData.Stance) -> bool:
	if not input.any_pressed():
		return false
	for button in [FighterInput.BTN_LP, FighterInput.BTN_HP, FighterInput.BTN_LK, FighterInput.BTN_HK]:
		if not input.just_pressed(button):
			continue
		var move := stats.get_move(FighterStats.move_id_for(stance, button))
		if move == null or move.total_frames() == 0:
			continue
		current_move = move
		move_frame = 0
		move_connected = false
		_set_state(State.ATTACK)
		if not airborne:
			vel_x = 0
		return true
	return false


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
		# Rozamiento: el empuje de un golpe se disipa en unos frames en vez de
		# deslizar para siempre. División entera = determinista.
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
	move_connected = false
	vel_x = 0
	_set_state(State.LANDING)


func _enter_neutral() -> void:
	current_move = null
	move_connected = false
	blocking_low = false
	_set_state(State.CROUCH if input.dir_y < 0 else State.IDLE)


func _set_state(new_state: int) -> void:
	state = new_state
	state_frame = 0


# --- Golpes ------------------------------------------------------------------

## Devuelve true si el golpe fue bloqueado. La arena decide el resto.
func receive_hit(move: MoveData, from_x: int) -> bool:
	var blocked := _can_block(move)
	var away := 1 if pos_x >= from_x else -1

	if blocked:
		blocking_low = input.dir_y < 0
		stun_frames = move.blockstun
		vel_x = away * move.pushback_block
		meter = mini(stats.max_meter, meter + move.meter_block)
		_set_state(State.BLOCKSTUN)
		took_damage.emit(0, true)
		return true

	health = maxi(0, health - move.damage)
	stun_frames = move.hitstun
	vel_x = away * move.pushback_hit
	meter = mini(stats.max_meter, meter + move.meter_hit)
	current_move = null
	move_connected = false
	if move.knockdown and not airborne:
		airborne = true
		vel_y = FP.from_px(3.2)
	_set_state(State.HITSTUN)
	took_damage.emit(move.damage, false)

	if health <= 0:
		_set_state(State.KO)
		airborne = true
		vel_y = FP.from_px(4.0)
		vel_x = away * FP.from_px(2.2)
		knocked_out.emit()
	return false


## Bloqueo por dirección, como SF2: mantener hacia atrás. La altura del golpe
## decide si vale de pie o agachado (MoveData.Height).
func _can_block(move: MoveData) -> bool:
	if state in [State.ATTACK, State.HITSTUN, State.JUMPSQUAT, State.KO, State.LANDING]:
		return false
	if airborne:
		return false  # En el aire no se bloquea (regla clásica).
	if input.dir_x != -facing or input.dir_x == 0:
		return false
	var crouching := input.dir_y < 0 or state == State.CROUCH
	match move.height:
		MoveData.Height.LOW:
			return crouching
		MoveData.Height.OVERHEAD:
			return not crouching
		_:
			return true


# --- Consultas para la arena -------------------------------------------------

func is_attacking() -> bool:
	return state == State.ATTACK and current_move != null


func active_hitboxes() -> Array[BoxData]:
	if not is_attacking() or move_connected:
		return _empty_boxes
	var frame := current_move.frame_at(move_frame)
	if frame == null:
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


# --- Render ------------------------------------------------------------------

func update_visual() -> void:
	# Posición redondeada al píxel: sin esto el pixel art vibra al moverse.
	position = Vector2(FP.floor_px(pos_x), -FP.floor_px(pos_y))
	queue_redraw()


func _draw() -> void:
	var body := stance_hurtbox()
	var color := stats.debug_color
	if hitstop > 0:
		color = color.lightened(0.5)
	if state == State.BLOCKSTUN:
		color = color.lerp(Color.WHITE, 0.35)
	elif state == State.HITSTUN or state == State.KO:
		color = color.lerp(Color.RED, 0.45)
	draw_rect(_local_rect(body), color)

	# Marca de orientación: en gris no hay sprite que diga hacia dónde miras.
	var eye_x := 2.0 if facing > 0 else -6.0
	draw_rect(Rect2(eye_x, -float(body.y + body.h) + 6.0, 4.0, 4.0), Color(0, 0, 0, 0.75))

	if show_boxes:
		draw_debug_boxes()


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
