class_name Diorama
extends Node2D
## Fondo vivo de los menús: un escenario del juego en penumbra, con la cámara
## paseando despacio y, si se quiere, escritores de pie en cubierta.
##
## Existe para que los menús no sean un rectángulo de color plano. Reutiliza el
## mismo Stage del combate (capas, parallax, cielo, gaviotas), así que no cuesta
## arte nuevo y cada escenario nuevo mejora también los menús.
##
## Se dibuja en coordenadas de pantalla: el nodo Stage se recoloca cada frame
## para que el punto de cámara caiga en el centro de la vista.

## Escenario de fondo y a qué altura de la pantalla (desde abajo) va el suelo.
var stage_id: String = "galeon"
var suelo_desde_abajo: float = 40.0
## Cuánto se apaga el escenario (0 = nada, 1 = negro). Los luchadores se
## apagan menos: el fondo acompaña, ellos protagonizan.
var penumbra: float = 0.55
var penumbra_figuras: float = 0.15
## Paseo de cámara: amplitud en px y segundos por vuelta.
var paseo: float = 60.0
var periodo: float = 40.0

## Escritores de pie: [{stats, x (desde el centro), mirando}].
var figuras: Array[Dictionary] = []

var _stage: Stage = null
var _figuras_nodo: Node2D = null
var _tiempo: float = 0.0
var _tick: int = 0


func _ready() -> void:
	var data := StageData.load_stage(stage_id)
	if data != null:
		_stage = Stage.new()
		_stage.setup(data)
		add_child(_stage)
	# Las figuras en un hijo propio: los hijos se dibujan después del padre,
	# así quedan por encima de la penumbra que pinta este nodo.
	_figuras_nodo = Node2D.new()
	_figuras_nodo.name = "Figuras"
	add_child(_figuras_nodo)
	_figuras_nodo.draw.connect(_dibujar_figuras)


func _process(delta: float) -> void:
	_tiempo += delta
	var tamano := get_viewport_rect().size
	var camara := roundf(sin(_tiempo * TAU / periodo) * paseo)
	var suelo := tamano.y - suelo_desde_abajo
	if _stage != null:
		_stage.position = Vector2(roundf(tamano.x * 0.5) - camara, suelo)
		# El escenario anima a 60 ticks como en combate (olas, gaviotas).
		var ticks := int(_tiempo * 60.0)
		while _tick < ticks:
			_stage.advance(camara)
			_tick += 1
	# Pegadas a la cubierta: se mueven con ella, no patinan sobre ella.
	_figuras_nodo.position = Vector2(roundf(tamano.x * 0.5) - camara, suelo)
	queue_redraw()
	_figuras_nodo.queue_redraw()


func _draw() -> void:
	if penumbra > 0.0:
		draw_rect(get_viewport_rect(), Color(EstiloTinta.TINTA_OSCURA, penumbra))


func _dibujar_figuras() -> void:
	var tick := int(_tiempo * 60.0)
	var tinte := Color(1, 1, 1).darkened(penumbra_figuras)
	for f in figuras:
		var pies := Vector2(float(f.get("x", 0.0)), 0.0)
		EstiloTinta.sombra_suelo(_figuras_nodo, pies)
		EstiloTinta.escritor(_figuras_nodo, f.get("stats"), pies, tick, int(f.get("mirando", 1)), tinte)
