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

const ANCHO_FICHA := 96.0
const ALTO_RETRATO := 64.0
const SEPARACION := 14.0
const Y_FICHAS := 64.0
## Dónde se plantan los dos escritores elegidos en cubierta, desde el centro.
const X_LUCHADOR := 115.0

enum Fase { ELIGE_P1, ELIGE_P2 }

var _ids: PackedStringArray = PackedStringArray()
var _stats: Array[FighterStats] = []
var _fase: int = Fase.ELIGE_P1
var _cursor_p1: int = 0
var _cursor_p2: int = 0
var _diorama: Diorama = null
var _ui: Control = null
var _tiempo: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ids = CharacterLoader.list_ids()
	for id in _ids:
		_stats.append(CharacterLoader.load_stats(id))
	# De salida, el rival es otro: proponer un espejo sería raro.
	_cursor_p2 = 1 if _ids.size() > 1 else 0

	# El enfrentamiento se ve en vivo en cubierta mientras se elige: el
	# jugador tiene delante el combate que va a jugar, no solo dos nombres.
	_diorama = Diorama.new()
	_diorama.penumbra = 0.6
	_diorama.paseo = 30.0
	add_child(_diorama)
	_ui = Control.new()
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui)
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.draw.connect(_dibujar)
	_actualizar_cubierta()


func _process(delta: float) -> void:
	_tiempo += delta
	_ui.queue_redraw()


func _actualizar_cubierta() -> void:
	_diorama.figuras.clear()
	if _ids.is_empty():
		return
	_diorama.figuras.append({ "stats": _stats[_cursor_p1], "x": -X_LUCHADOR, "mirando": 1 })
	if _fase == Fase.ELIGE_P2:
		_diorama.figuras.append({ "stats": _stats[_cursor_p2], "x": X_LUCHADOR, "mirando": -1 })


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
	_actualizar_cubierta()


func _confirmar() -> void:
	if _fase == Fase.ELIGE_P1:
		_fase = Fase.ELIGE_P2
		_actualizar_cubierta()
		return
	_empezar_combate()


func _atras() -> void:
	if _fase == Fase.ELIGE_P2:
		_fase = Fase.ELIGE_P1
		_actualizar_cubierta()
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

func _dibujar() -> void:
	var ancho := _ui.size.x
	EstiloTinta.rotulo(_ui, Vector2(0, 38), "ELIGE ESCRITOR", 24, EstiloTinta.DORADO, HORIZONTAL_ALIGNMENT_CENTER, ancho)

	var total := float(_ids.size())
	var ancho_total := total * ANCHO_FICHA + maxf(0.0, total - 1.0) * SEPARACION
	var x := roundf(ancho * 0.5 - ancho_total * 0.5)
	for i in _ids.size():
		_dibujar_ficha(i, x)
		x += ANCHO_FICHA + SEPARACION

	_dibujar_pie(ancho)


func _dibujar_ficha(indice: int, x: float) -> void:
	var marco := Rect2(x, Y_FICHAS, ANCHO_FICHA, ALTO_RETRATO + 18.0)
	EstiloTinta.marco(_ui, marco, Color(EstiloTinta.TINTA_OSCURA, 0.85))
	_dibujar_retrato(indice, Rect2(x + 4.0, Y_FICHAS + 3.0, ANCHO_FICHA - 8.0, ALTO_RETRATO))

	var stats := _stats[indice]
	var nombre: String = stats.display_name if stats != null else _ids[indice]
	var elegida := indice == _cursor_p1 or (indice == _cursor_p2 and _fase == Fase.ELIGE_P2)
	EstiloTinta.texto(
		_ui, Vector2(x, Y_FICHAS + ALTO_RETRATO + 14.0), nombre, 8,
		EstiloTinta.PAPEL if elegida else EstiloTinta.PAPEL_TENUE,
		HORIZONTAL_ALIGNMENT_CENTER, ANCHO_FICHA
	)

	# Los dos cursores se ven a la vez: así el jugador tiene delante el
	# enfrentamiento completo antes de confirmarlo, no solo su mitad.
	var parpadeo := int(_tiempo * 3.0) % 2 == 0
	if indice == _cursor_p1:
		var activo := _fase == Fase.ELIGE_P1
		_dibujar_cursor(marco, EstiloTinta.COLOR_J1, "J1", true, activo and parpadeo)
	if indice == _cursor_p2 and _fase == Fase.ELIGE_P2:
		_dibujar_cursor(marco, EstiloTinta.COLOR_J2, "J2", false, parpadeo)


## Marco de color de 2 px y pestaña con el jugador. El cursor del que está
## eligiendo parpadea; el ya confirmado se queda fijo.
func _dibujar_cursor(marco: Rect2, color: Color, etiqueta: String, izquierda: bool, apagado: bool) -> void:
	var c := color if not apagado else color.darkened(0.35)
	var borde := marco.grow(2.0)
	_ui.draw_rect(borde, c, false, 2.0)
	var pestana := Rect2(borde.position.x if izquierda else borde.end.x - 18.0, borde.position.y - 10.0, 18.0, 10.0)
	_ui.draw_rect(pestana, c)
	EstiloTinta.texto(_ui, Vector2(pestana.position.x, pestana.position.y + 9.0), etiqueta, 8, EstiloTinta.TINTA_OSCURA, HORIZONTAL_ALIGNMENT_CENTER, pestana.size.x, false)


## Retrato: el busto del escritor recortado de su pose de reposo. Dibujar la
## celda entera lo dejaría diminuto: casi toda es aire reservado para el
## alcance de los golpes.
func _dibujar_retrato(indice: int, destino: Rect2) -> void:
	_ui.draw_rect(destino, EstiloTinta.FONDO_PANEL)
	var stats := _stats[indice]
	if stats == null or stats.sprites == null or not stats.sprites.is_ready():
		return
	var celda := stats.sprites.region(0)
	# La cabeza queda a ~80 px sobre los pies: se encuadra de ahí hacia abajo.
	var origen := Rect2(
		celda.position.x + float(stats.sprites.pivot_x) - destino.size.x * 0.5,
		celda.position.y + float(stats.sprites.pivot_y) - 86.0,
		destino.size.x,
		destino.size.y
	)
	_ui.draw_texture_rect_region(stats.sprites.texture, destino, origen)


func _dibujar_pie(ancho: float) -> void:
	var titular := "Elige tu escritor" if _fase == Fase.ELIGE_P1 else "Elige al rival"
	EstiloTinta.texto(_ui, Vector2(0, Y_FICHAS + ALTO_RETRATO + 46.0), titular, 16, EstiloTinta.PAPEL, HORIZONTAL_ALIGNMENT_CENTER, ancho)

	# En cubierta, sobre los dos escritores: sus nombres y el VS.
	var suelo := _ui.size.y - 40.0
	var centro := ancho * 0.5
	var stats_p1 := _stats[_cursor_p1]
	var nombre_p1: String = stats_p1.display_name if stats_p1 != null else "?"
	EstiloTinta.texto(_ui, Vector2(centro - X_LUCHADOR - 60.0, suelo - 92.0), nombre_p1.to_upper(), 8, EstiloTinta.COLOR_J1, HORIZONTAL_ALIGNMENT_CENTER, 120.0)
	if _fase == Fase.ELIGE_P2:
		var stats_p2 := _stats[_cursor_p2]
		var nombre_p2: String = stats_p2.display_name if stats_p2 != null else "?"
		EstiloTinta.texto(_ui, Vector2(centro + X_LUCHADOR - 60.0, suelo - 92.0), nombre_p2.to_upper(), 8, EstiloTinta.COLOR_J2, HORIZONTAL_ALIGNMENT_CENTER, 120.0)
		EstiloTinta.rotulo(_ui, Vector2(0, suelo - 36.0), "VS", 32, EstiloTinta.DORADO, HORIZONTAL_ALIGNMENT_CENTER, ancho)

	EstiloTinta.texto(_ui, Vector2(0, _ui.size.y - 12.0), "←→ elegir   ·   Enter confirmar   ·   Esc atrás", 8, EstiloTinta.PAPEL_TENUE, HORIZONTAL_ALIGNMENT_CENTER, ancho)
