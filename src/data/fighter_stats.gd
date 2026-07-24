class_name FighterStats
extends RefCounted
## Todo lo que define a un luchador: constantes de movimiento, cajas por
## defecto y su repertorio de movimientos.
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
			stats.moves[StringName(move_id)] = MoveData.from_dict(StringName(move_id), raw)
	return stats


func get_move(move_id: StringName) -> MoveData:
	return moves.get(move_id, null)


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
