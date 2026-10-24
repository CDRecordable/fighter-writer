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

const VELO := Color(0.05, 0.03, 0.09, 0.72)

var ganador: String = ""
var perdedor: String = ""
var gano_el_jugador: bool = false
var rondas: Array = [0, 0]
var vida_restante: float = 0.0
var ficha_desbloqueada: bool = false

var _opciones: Array[Dictionary] = []
var _seleccion: int = 0


func _ready() -> void:
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
	var ancho := size.x
	draw_rect(Rect2(Vector2.ZERO, size), VELO)

	EstiloTinta.rotulo(self, Vector2(0, 66), "GANA %s" % ganador.to_upper(), 24, EstiloTinta.DORADO, HORIZONTAL_ALIGNMENT_CENTER, ancho)
	EstiloTinta.texto(
		self, Vector2(0, 86), "%d - %d   ·   %d%% de vida" % [
			rondas[0], rondas[1], roundi(vida_restante * 100.0),
		],
		8, EstiloTinta.PAPEL_TENUE, HORIZONTAL_ALIGNMENT_CENTER, ancho
	)
	_dibujar_sello(ancho)

	var y_opciones := 172.0
	if ficha_desbloqueada:
		EstiloTinta.texto(
			self, Vector2(0, 156), "Ficha de %s desbloqueada en la Biblioteca" % perdedor,
			8, EstiloTinta.PAPEL, HORIZONTAL_ALIGNMENT_CENTER, ancho
		)
		y_opciones = 176.0

	var alto_fila := 20.0
	var ancho_panel := 240.0
	var caja := Rect2(roundf((ancho - ancho_panel) * 0.5), y_opciones, ancho_panel, alto_fila * float(_opciones.size()) + 10.0)
	EstiloTinta.marco(self, caja, Color(EstiloTinta.TINTA_OSCURA, 0.85))
	var y := caja.position.y + 21.0
	for i in _opciones.size():
		var elegido := i == _seleccion
		var texto := String(_opciones[i]["texto"])
		EstiloTinta.texto(self, Vector2(caja.position.x, y), texto, 16, EstiloTinta.DORADO if elegido else EstiloTinta.PAPEL, HORIZONTAL_ALIGNMENT_CENTER, caja.size.x)
		if elegido:
			var mitad := EstiloTinta.ancho_texto(texto, 16) * 0.5
			var cx := caja.position.x + caja.size.x * 0.5
			EstiloTinta.rombo(self, Vector2(roundf(cx - mitad - 16.0), y - 11.0), EstiloTinta.DORADO, true)
			EstiloTinta.rombo(self, Vector2(roundf(cx + mitad + 9.0), y - 11.0), EstiloTinta.DORADO, true)
		y += alto_fila

	EstiloTinta.texto(self, Vector2(0, size.y - 12.0), "↑↓ elegir   ·   Enter aceptar", 8, EstiloTinta.PAPEL_TENUE, HORIZONTAL_ALIGNMENT_CENTER, ancho)


## El rango, como un sello de goma estampado: doble marco y tinta del color
## del premio. Es el chiste del juego, así que se le da el sitio de honor.
func _dibujar_sello(ancho: float) -> void:
	var texto := rango()
	var color := EstiloTinta.SUPER if gano_el_jugador else EstiloTinta.PAPEL_TENUE
	var w := roundf(EstiloTinta.ancho_texto(texto, 16)) + 28.0
	var caja := Rect2(roundf((ancho - w) * 0.5), 104.0, w, 30.0)
	draw_rect(caja, Color(EstiloTinta.TINTA_OSCURA, 0.6))
	draw_rect(caja, color, false, 2.0)
	draw_rect(caja.grow(-4.0), color, false, 1.0)
	EstiloTinta.texto(self, Vector2(caja.position.x, caja.position.y + 22.0), texto, 16, color, HORIZONTAL_ALIGNMENT_CENTER, caja.size.x)
