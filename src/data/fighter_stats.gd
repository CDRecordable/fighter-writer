class_name FighterStats
extends RefCounted
## Todo lo que define a un luchador: constantes de movimiento, cajas por
## defecto, repertorio de movimientos y proyectiles.
##
## Las velocidades llegan del JSON en píxeles por tick (a 60 ticks/s) y se
## guardan ya convertidas a punto fijo, porque es la unidad en la que trabaja
## la simulación.

var id: StringName = &""
var display_name: String = ""
var debug_color: Color = Color.WHITE

var max_health: int = 1000
var max_meter: int = 1000

var walk_forward: int = 0
var walk_back: int = 0
var jump_impulse: int = 0
var jump_forward: int = 0
var gravity: int = 0
var jumpsquat: int = 3
var landing_lag: int = 3

var push_box: BoxData = null
var stand_hurtbox: BoxData = null
var crouch_hurtbox: BoxData = null

## StringName -> MoveData
var moves: Dictionary = {}
## StringName -> ProjectileData
var projectiles: Dictionary = {}

## Hoja de sprites y animaciones de estado (idle, andar, hitstun...). Las de
## los movimientos viven en cada MoveData.
var sprites: SpriteSet = null
## StringName -> AnimationData
var animations: Dictionary = {}

## Los movimientos que se invocan con dirección + botón (súper, especiales,
## agarres), ya ordenados por dificultad de entrada. El orden importa: si un
## 236 se probara antes que el 236236 que lo contiene, el súper no saldría
## nunca.
var command_moves: Array[MoveData] = []


static func from_dict(d: Dictionary) -> FighterStats:
	var stats := FighterStats.new()
	stats.id = StringName(String(d.get("id", "sin_id")))
	stats.display_name = String(d.get("display_name", "Sin nombre"))
	stats.debug_color = Color(String(d.get("debug_color", "#ffffff")))

	var s: Dictionary = d.get("stats", {})
	stats.max_health = int(s.get("max_health", 1000))
	stats.max_meter = int(s.get("max_meter", 1000))
	stats.walk_forward = FP.px_from(s, "walk_forward", 1.5)
	stats.walk_back = FP.px_from(s, "walk_back", 1.1)
	stats.jump_impulse = FP.px_from(s, "jump_impulse", 7.5)
	stats.jump_forward = FP.px_from(s, "jump_forward", 2.2)
	stats.gravity = FP.px_from(s, "gravity", 0.42)
	stats.jumpsquat = int(s.get("jumpsquat", 3))
	stats.landing_lag = int(s.get("landing_lag", 3))

	stats.push_box = BoxData.from_dict(s.get("push_box", {"x": -11, "y": 0, "w": 22, "h": 72}))
	stats.stand_hurtbox = BoxData.from_dict(s.get("stand_hurtbox", {"x": -12, "y": 0, "w": 24, "h": 76}))
	stats.crouch_hurtbox = BoxData.from_dict(s.get("crouch_hurtbox", {"x": -13, "y": 0, "w": 26, "h": 48}))

	var raw_moves: Dictionary = d.get("moves", {})
	for move_id: String in raw_moves.keys():
		var raw: Variant = raw_moves[move_id]
		if raw is Dictionary:
			var move := MoveData.from_dict(StringName(move_id), raw)
			stats.moves[move.id] = move
			if move.is_command_move():
				stats.command_moves.append(move)
	stats.command_moves.sort_custom(_more_demanding_first)

	stats.sprites = SpriteSet.from_dict(String(stats.id), d.get("sprites", {}))
	var raw_animations: Dictionary = d.get("animations", {})
	for anim_name: String in raw_animations.keys():
		var raw: Variant = raw_animations[anim_name]
		if raw is Dictionary:
			stats.animations[StringName(anim_name)] = AnimationData.from_dict(raw)

	var raw_projectiles: Dictionary = d.get("projectiles", {})
	for projectile_id: String in raw_projectiles.keys():
		var raw: Variant = raw_projectiles[projectile_id]
		if raw is Dictionary:
			stats.projectiles[StringName(projectile_id)] = ProjectileData.from_dict(
				StringName(projectile_id), raw
			)
	return stats


static func _more_demanding_first(a: MoveData, b: MoveData) -> bool:
	return a.priority > b.priority


func get_move(move_id: StringName) -> MoveData:
	return moves.get(move_id, null)


func get_projectile(projectile_id: StringName) -> ProjectileData:
	return projectiles.get(projectile_id, null)


## Animación de estado. Si falta la pedida se cae a "idle": un personaje a
## medio animar se ve raro, pero se puede jugar y probar.
func get_animation(key: StringName) -> AnimationData:
	var anim: AnimationData = animations.get(key, null)
	if anim == null:
		anim = animations.get(&"idle", null)
	return anim


## Traduce postura + botón al id de movimiento. El nombre es un convenio, no
## una tabla en código: "stand_lp", "crouch_hk", "air_hk"...
static func move_id_for(stance: MoveData.Stance, button: int) -> StringName:
	var stance_name := "stand"
	match stance:
		MoveData.Stance.CROUCH: stance_name = "crouch"
		MoveData.Stance.AIR: stance_name = "air"
	var button_name := ""
	match button:
		FighterInput.BTN_LP: button_name = "lp"
		FighterInput.BTN_HP: button_name = "hp"
		FighterInput.BTN_LK: button_name = "lk"
		FighterInput.BTN_HK: button_name = "hk"
		_: return &""
	return StringName("%s_%s" % [stance_name, button_name])
