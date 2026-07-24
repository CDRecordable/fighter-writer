class_name FrameData
extends RefCounted
## Un tramo de animación de un movimiento: cuántos ticks dura y qué cajas
## están activas durante ellos.
##
## Si `hurtboxes` está vacío, el luchador usa la hurtbox por defecto de su
## postura (de pie / agachado). Así el JSON de un golpe solo declara hurtboxes
## cuando el movimiento cambia de verdad la silueta (un puño que se estira).

var duration: int = 1
var hurtboxes: Array[BoxData] = []
var hitboxes: Array[BoxData] = []


static func from_dict(d: Dictionary) -> FrameData:
	var frame := FrameData.new()
	frame.duration = maxi(1, int(d.get("duration", 1)))
	frame.hurtboxes = BoxData.list_from(d.get("hurt", []))
	frame.hitboxes = BoxData.list_from(d.get("hit", []))
	return frame


func has_hitbox() -> bool:
	return not hitboxes.is_empty()
