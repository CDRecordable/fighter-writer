class_name PantallaResultado
extends Control
## Pantalla de resultado, superpuesta al combate congelado.
##
## Va encima de la arena y no en una escena aparte a propósito: en un juego de
## lucha el fondo del final del combate —los dos cuerpos donde quedaron— es
## parte del resultado. Cambiar de escena lo borraría.
##
## Lo importante que hace esta pantalla no es decir quién ganó, que ya se veía:
## es **cerrar el bucle del juego**. Ganar a un escritor abre su ficha, y aquí
## es donde se le dice al jugador y se le ofrece ir a leerla. Sin este paso, la
## mitad educativa se queda esperando a que alguien se acuerde de entrar en la
## Biblioteca por su cuenta.

signal revancha
signal ir_a(escena: String)

const SELECCION := "res://scenes/seleccion.tscn"
const MENU := "res://scenes/main_menu.tscn"
const BIBLIOTECA := "res://scenes/biblioteca.tscn"

const VELO := Color(0.05, 0.03, 0.09, 0.78)
const TEXTO := Color(0.92, 0.90, 0.87)
const TENUE := Color(0.62, 0.58, 0.68)
const ACENTO := Color(0.95, 0.83, 0.25)
const PREMIO := Color(1.0, 0.55, 0.85)

var ganador: String = ""
var perdedor: String = ""
var gano_el_jugador: bool = false
var rondas: Array = [0, 0]
var vida_restante: float = 0.0
var ficha_desbloqueada: bool = false

var _opciones: Array[Dictionary] = []
var _seleccion: int = 0
var _fuente: Font = null


func _ready() -> void:
	_fuente = ThemeDB.fallback_font
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_montar_opciones()


func _montar_opciones() -> void:
	_opciones.clear()
	_opciones.append({ "texto": "OTRA VEZ", "accion": "revancha" })
	if ficha_desbloqueada:
		# Primero lo nuevo: si acaba de abrirse una ficha, leerla es la
		# recompensa del combate, no una opción más del menú.
		_opciones.push_front({ "texto": "LEER SU FICHA", "accion": BIBLIOTECA })
	_opciones.append({ "texto": "CAMBIAR DE ESCRITOR", "accion": SELECCION })
	_opciones.append({ "texto": "MENÚ", "accion": MENU })


## Rango con nombre literario (PLAN.md §2). Es puro chiste, pero es el chiste
## del juego: la recompensa de ganar se mide en prestigio editorial.
func rango() -> String:
	if not gano_el_jugador:
		return "BECARIO DE SUPLEMENTO CULTURAL"
	if rondas[1] == 0 and vida_restante > 0.7:
		return "PREMIO NACIONAL"
	if rondas[1] == 0:
		return "PREMIO HERRALDE"
	return "FINALISTA, QUE YA ES ALGO"


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_down"):
		_seleccion = posmod(_seleccion + 1, _opciones.size())
		queue_redraw()
	elif event.is_action_pressed(&"ui_up"):
		_seleccion = posmod(_seleccion - 1, _opciones.size())
		queue_redraw()
	elif event.is_action_pressed(&"ui_accept"):
		_elegir()
	else:
		return
	# La arena sigue viva debajo: sin esto, Esc o las teclas de desarrollo
	# seguirían respondiendo por detrás de la pantalla de resultado.
	get_viewport().set_input_as_handled()


func _elegir() -> void:
	var accion := String(_opciones[_seleccion]["accion"])
	if accion == "revancha":
		revancha.emit()
	else:
		ir_a.emit(accion)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), VELO)

	draw_string(
		_fuente, Vector2(0, 62), "GANA %s" % ganador.to_upper(),
		HORIZONTAL_ALIGNMENT_CENTER, 480.0, 18, ACENTO
	)
	draw_string(
		_fuente, Vector2(0, 80), "%d - %d   ·   %d%% de vida" % [
			rondas[0], rondas[1], roundi(vida_restante * 100.0),
		],
		HORIZONTAL_ALIGNMENT_CENTER, 480.0, 8, TENUE
	)
	draw_string(
		_fuente, Vector2(0, 100), rango(),
		HORIZONTAL_ALIGNMENT_CENTER, 480.0, 11, PREMIO if gano_el_jugador else TENUE
	)

	if ficha_desbloqueada:
		draw_string(
			_fuente, Vector2(0, 122), "Ficha de %s desbloqueada en la Biblioteca" % perdedor,
			HORIZONTAL_ALIGNMENT_CENTER, 480.0, 8, TEXTO
		)

	var y := 158.0
	for i in _opciones.size():
		var elegido := i == _seleccion
		var texto: String = String(_opciones[i]["texto"])
		draw_string(
			_fuente, Vector2(0, y), ("> %s <" % texto) if elegido else texto,
			HORIZONTAL_ALIGNMENT_CENTER, 480.0, 10, ACENTO if elegido else TEXTO
		)
		y += 16.0

	draw_string(
		_fuente, Vector2(0, size.y - 10.0), "↑↓ elegir   Enter aceptar",
		HORIZONTAL_ALIGNMENT_CENTER, 480.0, 7, TENUE
	)
