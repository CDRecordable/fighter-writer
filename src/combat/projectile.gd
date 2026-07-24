class_name Projectile
extends Node2D
## Un proyectil en vuelo (el panfleto de Lectura Fácil, PLAN.md §4).
##
## Vive en la misma simulación entera que los luchadores: posición en punto
## fijo, un tick por frame, y la arena decidiendo el orden. Golpea con las
## mismas reglas que un puñetazo porque su ProjectileData hereda de
## HitProperties.

var data: ProjectileData = null
var shooter: Fighter = null
var facing: int = 1
var pos_x: int = 0
var pos_y: int = 0
var life: int = 0
var dead: bool = false
var show_boxes: bool = false


func setup(data_in: ProjectileData, shooter_in: Fighter) -> void:
	data = data_in
	shooter = shooter_in
	facing = shooter_in.facing
	pos_x = shooter_in.pos_x + facing * data.offset_x * FP.ONE
	pos_y = shooter_in.pos_y + data.offset_y * FP.ONE
	life = data.lifetime
	update_visual()


func tick() -> void:
	pos_x += facing * data.speed
	life -= 1
	if life <= 0:
		dead = true


func world_box() -> Array[int]:
	return data.box.to_world(pos_x, pos_y, facing)


func update_visual() -> void:
	position = Vector2(FP.floor_px(pos_x), -FP.floor_px(pos_y))
	queue_redraw()


func _draw() -> void:
	draw_rect(_local_rect(), data.debug_color)
	if show_boxes:
		draw_rect(_local_rect(), Color(1.0, 0.4, 0.5, 0.9), false, 1.0)


func _local_rect() -> Rect2:
	var box := data.box
	var x := float(box.x) if facing > 0 else float(-(box.x + box.w))
	return Rect2(x, -float(box.y + box.h), float(box.w), float(box.h))
