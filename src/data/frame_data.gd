class_name FrameData
extends RefCounted
## Un tramo de animación de un movimiento: cuántos ticks dura, qué cajas están
## activas durante ellos y qué más ocurre mientras.
##
## Si `hurtboxes` está vacío, el luchador usa la hurtbox por defecto de su
## postura (de pie / agachado). Así el JSON de un golpe solo declara hurtboxes
## cuando el movimiento cambia de verdad la silueta (un puño que se estira).

var duration: int = 1
var hurtboxes: Array[BoxData] = []
var hitboxes: Array[BoxData] = []

## Grupo de impacto. Un movimiento golpea UNA VEZ por cada hit_id distinto: es
## lo que permite que un especial de varios golpes (la Danza Bruta) conecte tres
## veces sin que un golpe normal pueda pegar dos.
var hit_id: int = 0

## Velocidad impuesta durante el tramo, en fixed y relativa al facing (x
## positiva = hacia delante). Es como avanzan los especiales con desplazamiento.
var sets_velocity: bool = false
var vel_x: int = 0

## Id del proyectil a lanzar en el primer tick del tramo (ver ProjectileData).
var spawn: StringName = &""


static func from_dict(d: Dictionary) -> FrameData:
	var frame := FrameData.new()
	frame.duration = maxi(1, int(d.get("duration", 1)))
	frame.hurtboxes = BoxData.list_from(d.get("hurt", []))
	frame.hitboxes = BoxData.list_from(d.get("hit", []))
	frame.hit_id = int(d.get("hit_id", 0))
	frame.spawn = StringName(String(d.get("spawn", "")))
	if d.has("vel_x"):
		frame.sets_velocity = true
		frame.vel_x = FP.px_from(d, "vel_x", 0.0)
	return frame


func has_hitbox() -> bool:
	return not hitboxes.is_empty()
