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

## Media anchura de la vista, sacada de la resolución interna del proyecto
## para que cambiarla sea tocar project.godot y nada más.
static func media_vista() -> int:
	return int(ProjectSettings.get_setting("display/window/size/viewport_width", 640)) / 2


var data: StageData = null
var camera_x: float = 0.0
var tick: int = 0
## Cielo y mar procedurales (FondoProcedural): se dibujan como capas, antes
## que las del stage.json.
var _cielo: StageData.Layer = null
var _mar: StageData.Layer = null
## Estrellas que parpadean: [posición en la textura, fase].
var _titilantes: Array[Vector3i] = []
## Oscurecimiento de súper: ticks que quedan.
var _oscuro: int = 0
const TINTA_SUPER := Color(0.05, 0.02, 0.09)


func setup(data_in: StageData) -> void:
	data = data_in
	_cielo = _construir_cielo()
	if not data.sea.is_empty():
		_mar = FondoProcedural.mar(data, media_vista() * 2)
	# Detrás de luchadores y proyectiles, que están en z 0.
	z_index = -100
	queue_redraw()


## Apaga el escenario durante la congelación de un súper (y un poco más,
## para que la vuelta de la luz se vea).
func oscurecer(ticks: int) -> void:
	_oscuro = maxi(_oscuro, ticks + 10)


func advance(camera_x_in: float) -> void:
	camera_x = camera_x_in
	tick += 1
	if _oscuro > 0:
		_oscuro -= 1
	queue_redraw()


func _draw() -> void:
	if data == null:
		return
	var media := float(media_vista())
	# El cielo cubre siempre la vista entera, se mueva la cámara donde se mueva:
	# color de arriba en todo, y el de abajo desde donde empieza el degradado.
	draw_rect(Rect2(camera_x - media, -1000.0, media * 2.0, 1400.0), data.sky_top_color)
	draw_rect(
		Rect2(camera_x - media, -float(data.sky_from_y), media * 2.0, 400.0 + data.sky_from_y),
		data.sky_color
	)
	if _cielo != null:
		_draw_layer(_cielo)
		_draw_titilantes()
	if _mar != null:
		_draw_layer(_mar)
	for layer in data.layers:
		_draw_layer(layer)
	if _oscuro > 0:
		# Entra de golpe y se retira en los últimos ticks: el súper "apaga" el
		# escenario y deja a los dos luchadores solos.
		var fuerza := minf(1.0, float(_oscuro) / 8.0) * 0.78
		draw_rect(Rect2(camera_x - media, -1000.0, media * 2.0, 1400.0), Color(TINTA_SUPER, fuerza))


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
			source,
			layer.tint
		)
		return

	# Capa repetida: se tejen copias hasta cubrir la vista. Se empieza en un
	# múltiplo exacto del ancho para que no aparezca una costura al moverse.
	var media := float(media_vista())
	var left := camera_x - media
	var right := camera_x + media
	var start := floorf((left - scroll - float(layer.x)) / float(width)) * float(width)
	var x := start
	while x + scroll + float(layer.x) < right:
		draw_texture_rect_region(
			layer.texture,
			Rect2(x + scroll + float(layer.x), top, float(width), float(height)),
			source,
			layer.tint
		)
		x += float(width)


func _frame_index(layer: StageData.Layer) -> int:
	if layer.frames <= 1:
		return 0
	return (tick / layer.hold) % layer.frames


func _construir_cielo() -> StageData.Layer:
	if data.sky_to_y - data.sky_from_y <= 0:
		return null
	var resultado := FondoProcedural.cielo(data, media_vista() * 2)
	_titilantes = resultado[1]
	var capa := StageData.Layer.new()
	capa.texture = resultado[0]
	capa.parallax = data.sky_parallax
	capa.y = data.sky_from_y
	capa.repeat_x = true
	return capa


## Unas pocas estrellas se encienden un momento de vez en cuando. Nada más:
## el fondo no puede llamar la atención en un juego de lucha.
func _draw_titilantes() -> void:
	var ancho := float(_cielo.frame_width())
	var scroll := camera_x * (1.0 - _cielo.parallax)
	var arriba := -float(data.sky_to_y)
	for s in _titilantes:
		var fase := (tick + s.z) % 240
		if fase > 14:
			continue
		var x := fposmod(float(s.x) + scroll - (camera_x - float(media_vista())), ancho) + camera_x - float(media_vista())
		draw_rect(Rect2(x, arriba + float(s.y), 1, 1), Color(1, 1, 1))
		if fase > 4 and fase < 10:
			for d: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
				draw_rect(Rect2(x + d.x, arriba + float(s.y) + d.y, 1, 1), Color(0.8, 0.85, 1.0, 0.8))
