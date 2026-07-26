extends Control
## Menú principal. Mínimo a propósito: existe para que el juego tenga dos
## mitades a las que llegar —el combate y la Biblioteca— y no para ser bonito.
## El menú de verdad, con su arte y su música, es de la Fase 4.

const COMBATE := "res://scenes/combat_arena.tscn"
const BIBLIOTECA := "res://scenes/biblioteca.tscn"

const FONDO := Color(0.09, 0.07, 0.13)
const TEXTO := Color(0.90, 0.88, 0.85)
const TENUE := Color(0.58, 0.55, 0.64)
const ACENTO := Color(0.95, 0.83, 0.25)

var _opciones := [
	{ "texto": "COMBATE", "pie": "Cristina Morales contra Pérez-Reverte", "escena": COMBATE },
	{ "texto": "BIBLIOTECA", "pie": "Las fichas de los escritores", "escena": BIBLIOTECA },
	{ "texto": "SALIR", "pie": "", "escena": "" },
]
var _seleccion: int = 0
var _fuente: Font = null


func _ready() -> void:
	_fuente = ThemeDB.fallback_font
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_down"):
		_seleccion = posmod(_seleccion + 1, _opciones.size())
		queue_redraw()
	elif event.is_action_pressed(&"ui_up"):
		_seleccion = posmod(_seleccion - 1, _opciones.size())
		queue_redraw()
	elif event.is_action_pressed(&"ui_accept"):
		_elegir()


func _elegir() -> void:
	var escena := String(_opciones[_seleccion]["escena"])
	if escena == "":
		get_tree().quit()
		return
	get_tree().change_scene_to_file(escena)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), FONDO)
	draw_string(
		_fuente, Vector2(0, 62), "WRITER FIGHTER",
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, ACENTO
	)
	draw_string(
		_fuente, Vector2(0, 78), "escritores españoles repartiéndose",
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 8, TENUE
	)

	var y := 130.0
	for i in _opciones.size():
		var elegido := i == _seleccion
		var texto: String = ("> %s <" % _opciones[i]["texto"]) if elegido else String(_opciones[i]["texto"])
		draw_string(
			_fuente, Vector2(0, y), texto,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, ACENTO if elegido else TEXTO
		)
		y += 20.0

	var pie := String(_opciones[_seleccion]["pie"])
	if pie != "":
		draw_string(_fuente, Vector2(0, y + 10.0), pie, HORIZONTAL_ALIGNMENT_CENTER, size.x, 7, TENUE)
	draw_string(
		_fuente, Vector2(0, size.y - 10.0), "↑↓ elegir   Enter aceptar",
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 7, TENUE
	)
