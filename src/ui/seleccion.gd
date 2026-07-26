extends Control
## Pantalla de selección de escritor.
##
## Eligen los dos lados. En la v1 el jugador 2 lo lleva la IA (PLAN.md §2), pero
## dejar que se elija también su personaje cuesta lo mismo y sirve para dos
## cosas que ya hacen falta: probar cualquier enfrentamiento sin tocar código, y
## tener medio hecho el VS local a dos jugadores del backlog (§11).
##
## El enfrentamiento se pasa a la arena instanciándola a mano y rellenando sus
## campos antes de meterla en el árbol, en vez de por una variable global.
## `change_scene_to_file()` no admite parámetros, y una global para esto sería
## un sitio más donde el estado se queda pegado entre partidas.

const COMBATE := "res://scenes/combat_arena.tscn"
const MENU := "res://scenes/main_menu.tscn"

const FONDO := Color(0.09, 0.07, 0.13)
const PANEL := Color(0.14, 0.11, 0.19)
const TEXTO := Color(0.90, 0.88, 0.85)
const TENUE := Color(0.58, 0.55, 0.64)
const ACENTO := Color(0.95, 0.83, 0.25)
const COLOR_P1 := Color(0.90, 0.25, 0.45)
const COLOR_P2 := Color(0.35, 0.72, 0.95)

const ANCHO_FICHA := 62.0
const ALTO_RETRATO := 84.0
const SEPARACION := 12.0

enum Fase { ELIGE_P1, ELIGE_P2 }

var _ids: PackedStringArray = PackedStringArray()
var _stats: Array[FighterStats] = []
var _fase: int = Fase.ELIGE_P1
var _cursor_p1: int = 0
var _cursor_p2: int = 0
var _fuente: Font = null


func _ready() -> void:
	_fuente = ThemeDB.fallback_font
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ids = CharacterLoader.list_ids()
	for id in _ids:
		_stats.append(CharacterLoader.load_stats(id))
	# De salida, el rival es otro: proponer un espejo sería raro.
	_cursor_p2 = 1 if _ids.size() > 1 else 0


func _input(event: InputEvent) -> void:
	if _ids.is_empty():
		return
	if event.is_action_pressed(&"ui_right"):
		_mover(1)
	elif event.is_action_pressed(&"ui_left"):
		_mover(-1)
	elif event.is_action_pressed(&"ui_accept"):
		_confirmar()
	elif event.is_action_pressed(&"ui_cancel"):
		_atras()


func _mover(paso: int) -> void:
	if _fase == Fase.ELIGE_P1:
		_cursor_p1 = posmod(_cursor_p1 + paso, _ids.size())
	else:
		_cursor_p2 = posmod(_cursor_p2 + paso, _ids.size())
	queue_redraw()


func _confirmar() -> void:
	if _fase == Fase.ELIGE_P1:
		_fase = Fase.ELIGE_P2
		queue_redraw()
		return
	_empezar_combate()


func _atras() -> void:
	if _fase == Fase.ELIGE_P2:
		_fase = Fase.ELIGE_P1
		queue_redraw()
		return
	get_tree().change_scene_to_file(MENU)


func _empezar_combate() -> void:
	var arena: Node = load(COMBATE).instantiate()
	arena.p1_override = _ids[_cursor_p1]
	arena.p2_override = _ids[_cursor_p2]
	var arbol := get_tree()
	arbol.root.add_child(arena)
	arbol.current_scene.queue_free()
	arbol.current_scene = arena


# --- Dibujo ------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), FONDO)
	draw_string(
		_fuente, Vector2(0, 26), "ELIGE ESCRITOR",
		HORIZONTAL_ALIGNMENT_CENTER, 480.0, 16, ACENTO
	)

	var total := float(_ids.size())
	var ancho_total := total * ANCHO_FICHA + maxf(0.0, total - 1.0) * SEPARACION
	var x := 240.0 - ancho_total * 0.5
	for i in _ids.size():
		_dibujar_ficha(i, x)
		x += ANCHO_FICHA + SEPARACION

	_dibujar_pie()


func _dibujar_ficha(indice: int, x: float) -> void:
	var y := 48.0
	var marco := Rect2(x, y, ANCHO_FICHA, ALTO_RETRATO + 14.0)
	draw_rect(marco, PANEL)

	_dibujar_retrato(indice, Rect2(x + 7.0, y + 4.0, 48.0, ALTO_RETRATO))

	var stats := _stats[indice]
	var nombre: String = stats.display_name if stats != null else _ids[indice]
	draw_string(
		_fuente, Vector2(x - 6.0, y + ALTO_RETRATO + 12.0), nombre,
		HORIZONTAL_ALIGNMENT_CENTER, ANCHO_FICHA + 12.0, 7, TEXTO
	)

	# Los dos cursores se ven a la vez: así el jugador tiene delante el
	# enfrentamiento completo antes de confirmarlo, no solo su mitad.
	if indice == _cursor_p1:
		_dibujar_cursor(marco, COLOR_P1, "P1", true)
	if indice == _cursor_p2 and _fase == Fase.ELIGE_P2:
		_dibujar_cursor(marco, COLOR_P2, "P2", false)


func _dibujar_cursor(marco: Rect2, color: Color, etiqueta: String, arriba: bool) -> void:
	draw_rect(marco, color, false, 1.0)
	var pos := marco.position + (Vector2(2, -2) if arriba else Vector2(marco.size.x - 14.0, -2))
	draw_string(_fuente, pos, etiqueta, HORIZONTAL_ALIGNMENT_LEFT, 20.0, 7, color)


## Recorta la zona del personaje dentro de su celda de reposo. Dibujar la celda
## entera lo dejaría diminuto: casi toda es aire reservado para el alcance de
## los golpes.
func _dibujar_retrato(indice: int, destino: Rect2) -> void:
	var stats := _stats[indice]
	if stats == null or stats.sprites == null or not stats.sprites.is_ready():
		draw_rect(destino, TENUE.darkened(0.5))
		return
	var celda := stats.sprites.region(0)
	var origen := Rect2(
		celda.position.x + float(stats.sprites.pivot_x) - destino.size.x * 0.5,
		celda.position.y + float(stats.sprites.pivot_y) - destino.size.y,
		destino.size.x,
		destino.size.y
	)
	draw_texture_rect_region(stats.sprites.texture, destino, origen)


func _dibujar_pie() -> void:
	var stats_p1 := _stats[_cursor_p1]
	var stats_p2 := _stats[_cursor_p2]
	var nombre_p1: String = stats_p1.display_name if stats_p1 != null else "?"
	var nombre_p2: String = stats_p2.display_name if stats_p2 != null else "?"

	var titular := "Elige tu escritor" if _fase == Fase.ELIGE_P1 else "Elige al rival"
	draw_string(
		_fuente, Vector2(0, 178), titular,
		HORIZONTAL_ALIGNMENT_CENTER, 480.0, 9, ACENTO
	)
	if _fase == Fase.ELIGE_P2:
		draw_string(
			_fuente, Vector2(0, 194), "%s  contra  %s" % [nombre_p1, nombre_p2],
			HORIZONTAL_ALIGNMENT_CENTER, 480.0, 8, TEXTO
		)

	draw_string(
		_fuente, Vector2(0, size.y - 12.0),
		"←→ elegir   Enter confirmar   Esc atrás",
		HORIZONTAL_ALIGNMENT_CENTER, 480.0, 7, TENUE
	)
