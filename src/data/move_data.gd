class_name MoveData
extends RefCounted
## Un movimiento completo (normal, especial o súper) cargado desde el JSON del
## personaje. Ni una sola propiedad de combate vive en el código: ajustar el
## balance es editar datos (PLAN.md §7).

enum Stance { STAND, CROUCH, AIR }

## Altura del golpe, que decide cómo hay que bloquearlo:
##   MID      -> se bloquea de pie o agachado
##   LOW      -> solo agachado (barridos)
##   OVERHEAD -> solo de pie (saltos y golpes descendentes)
enum Height { MID, LOW, OVERHEAD }

var id: StringName = &""
var display_name: String = ""
var stance: Stance = Stance.STAND
var height: Height = Height.MID

## Un FrameData por tick, ya expandido. Consultar el frame activo es indexar
## un array: sin bucles ni acumuladores en el bucle de simulación.
var timeline: Array[FrameData] = []

var damage: int = 0
var hitstun: int = 12
var blockstun: int = 8
## Congelación de ambos luchadores al impactar: es de donde sale el "peso" del
## golpe. Se afina en Fase 4, pero conviene tenerlo desde el prototipo gris.
var hitstop: int = 6
var knockdown: bool = false

## Empuje horizontal en fixed por tick, positivo = alejarse del atacante.
var pushback_hit: int = 0
var pushback_block: int = 0
var self_pushback: int = 0

## Medidor de Tinta (PLAN.md §3).
var meter_hit: int = 0
var meter_block: int = 0

## Los aéreos se quedan en su último frame hasta tocar suelo, como en SF2.
var until_land: bool = false


static func from_dict(id_in: StringName, d: Dictionary) -> MoveData:
	var move := MoveData.new()
	move.id = id_in
	move.display_name = String(d.get("display_name", String(id_in)))
	move.stance = _parse_stance(String(d.get("stance", "stand")))
	move.height = _parse_height(String(d.get("height", "mid")))

	for raw: Variant in d.get("frames", []):
		if raw is Dictionary:
			var frame := FrameData.from_dict(raw)
			for _i in range(frame.duration):
				move.timeline.append(frame)

	move.damage = int(d.get("damage", 0))
	move.hitstun = int(d.get("hitstun", 12))
	move.blockstun = int(d.get("blockstun", 8))
	move.hitstop = int(d.get("hitstop", 6))
	move.knockdown = bool(d.get("knockdown", false))
	move.pushback_hit = FP.px_from(d, "pushback_hit", 1.6)
	move.pushback_block = FP.px_from(d, "pushback_block", 1.2)
	move.self_pushback = FP.px_from(d, "self_pushback", 0.0)
	move.meter_hit = int(d.get("meter_hit", 60))
	move.meter_block = int(d.get("meter_block", 20))
	move.until_land = bool(d.get("until_land", false))
	return move


static func _parse_stance(s: String) -> Stance:
	match s.to_lower():
		"crouch": return Stance.CROUCH
		"air": return Stance.AIR
		_: return Stance.STAND


static func _parse_height(s: String) -> Height:
	match s.to_lower():
		"low": return Height.LOW
		"overhead": return Height.OVERHEAD
		_: return Height.MID


func total_frames() -> int:
	return timeline.size()


func frame_at(index: int) -> FrameData:
	if timeline.is_empty():
		return null
	return timeline[clampi(index, 0, timeline.size() - 1)]
