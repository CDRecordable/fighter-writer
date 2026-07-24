class_name MoveData
extends HitProperties
## Un movimiento completo (normal, especial, agarre o súper) cargado desde el
## JSON del personaje. Ni una sola propiedad de combate vive en el código:
## ajustar el balance es editar datos (PLAN.md §7).

enum Stance { STAND, CROUCH, AIR }

var id: StringName = &""
var display_name: String = ""
var stance: Stance = Stance.STAND

## Un FrameData por tick, ya expandido. Consultar el frame activo es indexar un
## array: sin bucles ni acumuladores en el bucle de simulación.
var timeline: Array[FrameData] = []
## Marca el primer tick de cada tramo. Sirve para que lo que ocurre "una vez"
## (lanzar un proyectil) no ocurra en cada tick del tramo.
var timeline_starts: Array[bool] = []

## --- Entrada -----------------------------------------------------------------
## Secuencia de direcciones en notación numpad relativa al personaje ("236",
## "214", "623", "236236"), o "charge46"/"charge28" para las cargas. Vacío = el
## movimiento no se invoca por comando, sino por postura + botón (los normales).
var motion: StringName = &""
## Botones que lo disparan: "p" (cualquier puño), "k" (cualquier patada) o uno
## concreto ("lp", "hk"...).
var button_mask: int = 0
## Tinta que cuesta. > 0 lo convierte en súper.
var meter_cost: int = 0
## Ticks que se congela el rival al arrancar un súper (el "cinematic freeze").
var super_freeze: int = 0
## Distancia máxima al rival para que salga, en fixed. 0 = sin límite. Los
## agarres la usan: fuera de rango el botón cae al golpe normal, como en SF2.
var max_range: int = 0
## Los agarres no agarran a quien está en el aire.
var requires_grounded_target: bool = false

## --- Comportamiento ----------------------------------------------------------
var self_pushback: int = 0
## Los aéreos se quedan en su último frame hasta tocar suelo, como en SF2.
var until_land: bool = false
## Ventana [desde, hasta] en ticks durante la que el movimiento absorbe un golpe
## y encadena `counter_move`. Es la Asamblea de Cristina (PLAN.md §4).
var counter_from: int = -1
var counter_to: int = -1
var counter_move: StringName = &""

## Orden en que se prueban los comandos. Cuanto más difícil es la entrada, antes
## se comprueba: si no, un 236 se comería siempre al 236236 que lo contiene.
var priority: int = 0

## Qué se dibuja mientras dura. Puede faltar: sin animación el luchador se
## dibuja como el rectángulo del prototipo gris y el movimiento funciona igual.
var anim: AnimationData = null


static func from_dict(id_in: StringName, d: Dictionary) -> MoveData:
	var move := MoveData.new()
	move.id = id_in
	move.display_name = String(d.get("display_name", String(id_in)))
	move.stance = _parse_stance(String(d.get("stance", "stand")))
	move.read_hit_properties(d)

	for raw: Variant in d.get("frames", []):
		if raw is Dictionary:
			var frame := FrameData.from_dict(raw)
			for i in range(frame.duration):
				move.timeline.append(frame)
				move.timeline_starts.append(i == 0)

	move.motion = StringName(String(d.get("motion", "")))
	move.button_mask = _parse_buttons(String(d.get("button", "")))
	move.meter_cost = int(d.get("meter_cost", 0))
	move.super_freeze = int(d.get("super_freeze", 0))
	move.max_range = FP.px_from(d, "max_range", 0.0)
	move.requires_grounded_target = bool(d.get("requires_grounded_target", false))

	move.self_pushback = FP.px_from(d, "self_pushback", 0.0)
	move.until_land = bool(d.get("until_land", false))
	var counter: Variant = d.get("counter", null)
	if counter is Dictionary:
		move.counter_from = int(counter.get("from", -1))
		move.counter_to = int(counter.get("to", -1))
		move.counter_move = StringName(String(counter.get("move", "")))

	move.priority = move._compute_priority()

	var raw_anim: Variant = d.get("anim", null)
	if raw_anim is Dictionary:
		move.anim = AnimationData.from_dict(raw_anim)
		if move.anim.total != move.total_frames():
			# Aviso, no error: durante la producción es normal que el arte vaya
			# por detrás de los frame data. Pero conviene enterarse.
			push_warning("Movimiento '%s': la animación dura %d ticks y el movimiento %d." % [
				move.id, move.anim.total, move.total_frames(),
			])
	return move


static func _parse_stance(s: String) -> Stance:
	match s.to_lower():
		"crouch": return Stance.CROUCH
		"air": return Stance.AIR
		_: return Stance.STAND


static func _parse_buttons(s: String) -> int:
	match s.to_lower():
		"lp": return FighterInput.BTN_LP
		"hp": return FighterInput.BTN_HP
		"lk": return FighterInput.BTN_LK
		"hk": return FighterInput.BTN_HK
		"p": return FighterInput.BTN_LP | FighterInput.BTN_HP
		"k": return FighterInput.BTN_LK | FighterInput.BTN_HK
		"any": return FighterInput.BTN_ALL
		_: return 0


func _compute_priority() -> int:
	if meter_cost > 0:
		return 1000 + motion.length()
	if motion.begins_with("charge"):
		return 400
	return 100 + motion.length() * 10


## ¿Se invoca con un comando (dirección + botón) en vez de con postura + botón?
func is_command_move() -> bool:
	return motion != &"" and button_mask != 0


func is_counter_active(frame_index: int) -> bool:
	return counter_move != &"" and frame_index >= counter_from and frame_index <= counter_to


func total_frames() -> int:
	return timeline.size()


func frame_at(index: int) -> FrameData:
	if timeline.is_empty():
		return null
	return timeline[clampi(index, 0, timeline.size() - 1)]


func starts_frame(index: int) -> bool:
	return index >= 0 and index < timeline_starts.size() and timeline_starts[index]
