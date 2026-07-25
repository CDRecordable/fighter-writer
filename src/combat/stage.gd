class_name Stage
extends Node2D
## Dibuja el escenario detrás del combate.
##
## Todo el parallax se resuelve aquí, en un solo `_draw()`, en vez de con un
## nodo por capa. Motivo: el orden de dibujo queda explícito y en un sitio, que
## en un juego 2D es exactamente donde se pierden las tardes cuando el cielo
## acaba delante del personaje.
##
## Sistema de coordenadas: el origen del nodo está en el suelo del escenario,
## igual que los pies de los luchadores, e `y` de los datos crece hacia arriba.
## Así una capa se coloca diciendo "a 40 px del suelo" y no hay que pensar en el
## eje invertido de Godot.

const VIEW_HALF_WIDTH := 240

var data: StageData = null
var camera_x: float = 0.0
var tick: int = 0


func setup(data_in: StageData) -> void:
	data = data_in
	# Detrás de luchadores y proyectiles, que están en z 0.
	z_index = -100
	queue_redraw()


func advance(camera_x_in: float) -> void:
	camera_x = camera_x_in
	tick += 1
	queue_redraw()


func _draw() -> void:
	if data == null:
		return
	# El cielo cubre siempre la vista entera, se mueva la cámara donde se mueva.
	draw_rect(
		Rect2(camera_x - VIEW_HALF_WIDTH, -1000.0, VIEW_HALF_WIDTH * 2.0, 1400.0),
		data.sky_color
	)
	for layer in data.layers:
		_draw_layer(layer)


func _draw_layer(layer: StageData.Layer) -> void:
	if layer.texture == null:
		return
	var width := layer.frame_width()
	if width <= 0:
		return
	var height := layer.texture.get_height()
	# Una capa a parallax 1 va clavada al mundo; a 0 se queda pegada a la
	# cámara. El desplazamiento es lo que la cámara NO le traslada.
	var scroll := camera_x * (1.0 - layer.parallax)
	var top := -float(layer.y + height)
	var source := Rect2(float(_frame_index(layer) * width), 0.0, float(width), float(height))

	if not layer.repeat_x:
		draw_texture_rect_region(
			layer.texture,
			Rect2(float(layer.x) + scroll, top, float(width), float(height)),
			source
		)
		return

	# Capa repetida: se tejen copias hasta cubrir la vista. Se empieza en un
	# múltiplo exacto del ancho para que no aparezca una costura al moverse.
	var left := camera_x - VIEW_HALF_WIDTH
	var right := camera_x + VIEW_HALF_WIDTH
	var start := floorf((left - scroll - float(layer.x)) / float(width)) * float(width)
	var x := start
	while x + scroll + float(layer.x) < right:
		draw_texture_rect_region(
			layer.texture,
			Rect2(x + scroll + float(layer.x), top, float(width), float(height)),
			source
		)
		x += float(width)


func _frame_index(layer: StageData.Layer) -> int:
	if layer.frames <= 1:
		return 0
	return (tick / layer.hold) % layer.frames
