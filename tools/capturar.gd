extends SceneTree
## Abre una pantalla del juego, la deja correr unos frames y guarda una captura.
##
## Uso (con ventana, NO --headless: sin ventana no hay imagen que capturar):
##   godot --path . --script res://tools/capturar.gd -- <pantalla> <salida.png> [frames] [N=accion ...]
##
## <pantalla>: combate, menu, seleccion, biblioteca o una ruta res://...tscn
## N=accion:   pulsa la acción del InputMap en el frame N y la suelta 4 frames
##             después. Ej.: 130=p1_hp para que la J1 lance un puño fuerte.
## N-M=accion: la mantiene pulsada del frame N al M. Ej.: 100-140=p1_right.
## La salida se guarda a la resolución interna; para verla grande, escálala
## con vecino más próximo.

const PANTALLAS := {
	"combate": "res://scenes/combat_arena.tscn",
	"menu": "res://scenes/main_menu.tscn",
	"seleccion": "res://scenes/seleccion.tscn",
	"biblioteca": "res://scenes/biblioteca.tscn",
}

var _salida := ""
var _frames := 120
var _acciones := {}  # frame -> Array[String]
var _sueltas := {}  # frame -> Array[String]
var _frame := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("Uso: -- <pantalla> <salida.png> [frames] [N=accion ...]")
		quit(1)
		return
	var ruta: String = PANTALLAS.get(args[0], args[0])
	_salida = args[1]
	if args.size() > 2:
		_frames = int(args[2])
	for i in range(3, args.size()):
		var partes := args[i].split("=")
		var tramo := partes[0].split("-")
		var desde := int(tramo[0])
		var hasta := int(tramo[1]) if tramo.size() > 1 else desde + 4
		if not _acciones.has(desde):
			_acciones[desde] = []
		_acciones[desde].append(partes[1])
		if not _sueltas.has(hasta):
			_sueltas[hasta] = []
		_sueltas[hasta].append(partes[1])
	# El autoload de controles no corre con --script: se monta a mano para
	# que existan las acciones y la fuente del juego.
	var controles: Node = load("res://src/core/input_setup.gd").new()
	root.add_child(controles)
	root.add_child(load(ruta).instantiate())


func _process(_delta: float) -> bool:
	_frame += 1
	if _acciones.has(_frame):
		for accion: String in _acciones[_frame]:
			Input.action_press(accion)
			# action_press solo cambia el estado; las pantallas que escuchan
			# _input() necesitan además el evento.
			var evento := InputEventAction.new()
			evento.action = accion
			evento.pressed = true
			Input.parse_input_event(evento)
	if _sueltas.has(_frame):
		for accion: String in _sueltas[_frame]:
			Input.action_release(accion)
	# get_image() devuelve el frame anterior: se guarda dos frames después.
	if _frame == _frames + 2:
		var imagen := root.get_texture().get_image()
		imagen.save_png(_salida)
		print("Captura guardada: ", _salida, " ", imagen.get_size())
		return true
	return false
