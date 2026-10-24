extends Control
## Menú principal: el galeón en penumbra, los escritores en cubierta y tres
## opciones. Existe para que el juego tenga dos mitades a las que llegar —el
## combate y la Biblioteca—; la música y la intro animada son de la Fase 4.
##
## Estructura: un Diorama de fondo y encima un Control que dibuja la interfaz.
## La interfaz va en un hijo y no en el _draw() de este nodo porque los hijos
## se dibujan después del padre: si no, el diorama taparía el texto.

const COMBATE := "res://scenes/seleccion.tscn"
const BIBLIOTECA := "res://scenes/biblioteca.tscn"

const ANCHO_PANEL := 196.0

var _opciones := [
	{ "texto": "COMBATE", "pie": "Elige escritor y a quién zurrarle", "escena": COMBATE },
	{ "texto": "BIBLIOTECA", "pie": "Las fichas de los escritores", "escena": BIBLIOTECA },
	{ "texto": "SALIR", "pie": "Hasta la próxima presentación", "escena": "" },
]
var _seleccion: int = 0
var _ui: Control = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var diorama := Diorama.new()
	diorama.penumbra = 0.5
	var ids := CharacterLoader.list_ids()
	# Los dos primeros escritores, frente a frente en cubierta.
	if ids.size() > 0:
		diorama.figuras.append({ "stats": CharacterLoader.load_stats(ids[0]), "x": -120.0, "mirando": 1 })
	if ids.size() > 1:
		diorama.figuras.append({ "stats": CharacterLoader.load_stats(ids[1]), "x": 120.0, "mirando": -1 })
	add_child(diorama)

	_ui = Control.new()
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui)
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.draw.connect(_dibujar)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_down"):
		_seleccion = posmod(_seleccion + 1, _opciones.size())
		_ui.queue_redraw()
	elif event.is_action_pressed(&"ui_up"):
		_seleccion = posmod(_seleccion - 1, _opciones.size())
		_ui.queue_redraw()
	elif event.is_action_pressed(&"ui_accept"):
		_elegir()


func _elegir() -> void:
	var escena := String(_opciones[_seleccion]["escena"])
	if escena == "":
		get_tree().quit()
		return
	get_tree().change_scene_to_file(escena)


func _dibujar() -> void:
	var ancho := _ui.size.x
	EstiloTinta.rotulo(_ui, Vector2(0, 92), "WRITER FIGHTER", 32, EstiloTinta.DORADO, HORIZONTAL_ALIGNMENT_CENTER, ancho)
	EstiloTinta.texto(_ui, Vector2(0, 114), "escritores españoles repartiéndose", 8, EstiloTinta.PAPEL_TENUE, HORIZONTAL_ALIGNMENT_CENTER, ancho)

	var alto_fila := 24.0
	var caja := Rect2(
		roundf((ancho - ANCHO_PANEL) * 0.5), 140.0,
		ANCHO_PANEL, alto_fila * float(_opciones.size()) + 12.0
	)
	EstiloTinta.marco(_ui, caja, Color(EstiloTinta.TINTA_OSCURA, 0.78))
	var y := caja.position.y + 25.0
	for i in _opciones.size():
		var elegido := i == _seleccion
		var texto := String(_opciones[i]["texto"])
		var color := EstiloTinta.DORADO if elegido else EstiloTinta.PAPEL
		EstiloTinta.texto(_ui, Vector2(caja.position.x, y), texto, 16, color, HORIZONTAL_ALIGNMENT_CENTER, caja.size.x)
		if elegido:
			var mitad := EstiloTinta.ancho_texto(texto, 16) * 0.5
			var cx := caja.position.x + caja.size.x * 0.5
			EstiloTinta.rombo(_ui, Vector2(roundf(cx - mitad - 16.0), y - 11.0), EstiloTinta.DORADO, true)
			EstiloTinta.rombo(_ui, Vector2(roundf(cx + mitad + 9.0), y - 11.0), EstiloTinta.DORADO, true)
		y += alto_fila

	var pie := String(_opciones[_seleccion]["pie"])
	EstiloTinta.texto(_ui, Vector2(0, caja.end.y + 18.0), pie, 8, EstiloTinta.PAPEL, HORIZONTAL_ALIGNMENT_CENTER, ancho)
	EstiloTinta.texto(_ui, Vector2(0, _ui.size.y - 12.0), "↑↓ elegir   ·   Enter aceptar", 8, EstiloTinta.PAPEL_TENUE, HORIZONTAL_ALIGNMENT_CENTER, ancho)
