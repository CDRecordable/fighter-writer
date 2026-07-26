extends Control
## La Biblioteca: las fichas de los escritores (PLAN.md §6).
##
## Es la mitad del juego que no se pelea. La regla que la sostiene: **vencer a
## un escritor abre su ficha completa**; antes solo se ve el nombre y una línea,
## como los perfiles del manual de SF2. La literatura no se sirve de entrada, se
## gana.
##
## Se construye con nodos de Control y no dibujando a mano como el HUD, porque
## aquí lo que hay es texto largo que se ajusta y se desplaza — y para eso el
## motor ya trae lo necesario. El HUD del combate es al revés: pocas cosas y muy
## colocadas.

const MENU := "res://scenes/main_menu.tscn"

const FONDO := Color(0.09, 0.07, 0.13)
const PANEL := Color(0.14, 0.11, 0.19)
const TEXTO := Color(0.90, 0.88, 0.85)
const TENUE := Color(0.58, 0.55, 0.64)
const ACENTO := Color(0.95, 0.83, 0.25)
const BLOQUEADO := Color(0.45, 0.42, 0.50)

const ANCHO_LISTA := 116.0
const VELOCIDAD_SCROLL := 3

var _ids: PackedStringArray = PackedStringArray()
var _seleccion: int = 0
var _lista: VBoxContainer = null
var _scroll: ScrollContainer = null
var _contenido: VBoxContainer = null
var _fuente: Font = null


func _ready() -> void:
	_fuente = ThemeDB.fallback_font
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ids = CharacterLoader.list_ids()
	_construir()
	_refrescar()


func _construir() -> void:
	var fondo := ColorRect.new()
	fondo.color = FONDO
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo)

	add_child(_etiqueta("BIBLIOTECA", 12, ACENTO, Vector2(8, 4), 200.0))
	# 480 fijo y no size.x: en _ready() el Control aún no tiene tamaño resuelto,
	# y la resolución interna del juego no cambia (project.godot).
	add_child(_etiqueta(
		"←→ escritor   ↑↓ leer   Esc volver",
		7, TENUE, Vector2(480.0 - 184.0, 7), 176.0, HORIZONTAL_ALIGNMENT_RIGHT
	))

	_lista = VBoxContainer.new()
	_lista.position = Vector2(8, 24)
	_lista.custom_minimum_size = Vector2(ANCHO_LISTA, 0)
	_lista.add_theme_constant_override("separation", 3)
	add_child(_lista)

	var marco := ColorRect.new()
	marco.color = PANEL
	marco.position = Vector2(ANCHO_LISTA + 14.0, 22)
	marco.size = Vector2(480.0 - ANCHO_LISTA - 22.0, 240.0)
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(marco)

	_scroll = ScrollContainer.new()
	_scroll.position = marco.position + Vector2(5, 4)
	_scroll.size = marco.size - Vector2(10, 8)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	_contenido = VBoxContainer.new()
	_contenido.custom_minimum_size = Vector2(_scroll.size.x - 4.0, 0)
	_contenido.add_theme_constant_override("separation", 3)
	_scroll.add_child(_contenido)


func _process(_delta: float) -> void:
	# Se lee cada frame en vez de por evento para que mantener la tecla siga
	# desplazando: una ficha larga con pulsaciones sueltas es un suplicio.
	if Input.is_action_pressed(&"ui_down"):
		_scroll.scroll_vertical += VELOCIDAD_SCROLL
	if Input.is_action_pressed(&"ui_up"):
		_scroll.scroll_vertical -= VELOCIDAD_SCROLL


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_tree().change_scene_to_file(MENU)
	elif event.is_action_pressed(&"ui_right"):
		_mover(1)
	elif event.is_action_pressed(&"ui_left"):
		_mover(-1)
	elif event.is_action_pressed(&"dev_unlock_all"):
		# Utilidad de desarrollo: leer las fichas sin tener que ganar cuatro
		# combates cada vez que se cambia una coma.
		Progreso.desbloquear_todo()
		_refrescar()


func _mover(paso: int) -> void:
	if _ids.is_empty():
		return
	_seleccion = posmod(_seleccion + paso, _ids.size())
	_scroll.scroll_vertical = 0
	_refrescar()


func _refrescar() -> void:
	_refrescar_lista()
	_refrescar_ficha()


func _refrescar_lista() -> void:
	for hijo in _lista.get_children():
		hijo.queue_free()
	for i in _ids.size():
		var id := _ids[i]
		var entry := WikiEntry.load_for(id)
		var nombre := entry.display_name if entry != null else id
		var abierto := Progreso.esta_desbloqueado(id)
		var color := TEXTO if abierto else BLOQUEADO
		if i == _seleccion:
			color = ACENTO
		var texto := ("> " if i == _seleccion else "  ") + nombre
		if not abierto:
			texto += "  (?)"
		_lista.add_child(_etiqueta(texto, 8, color, Vector2.ZERO, ANCHO_LISTA))


func _refrescar_ficha() -> void:
	for hijo in _contenido.get_children():
		hijo.queue_free()
	if _ids.is_empty():
		_agregar("No hay escritores en characters/.", 8, TENUE)
		return

	var id := _ids[_seleccion]
	var entry := WikiEntry.load_for(id)
	if entry == null:
		_agregar("Este escritor no tiene wiki.json todavía.", 8, TENUE)
		return

	_agregar_retrato(id)
	_agregar(entry.display_name, 12, TEXTO)
	if entry.epigrafe != "":
		_agregar(entry.epigrafe, 8, ACENTO)
	if entry.lugar_y_anio() != "":
		_agregar(entry.lugar_y_anio(), 7, TENUE)

	if not Progreso.esta_desbloqueado(id):
		_separador()
		_agregar(
			"Ficha bloqueada. Véncele en combate y podrás leerla entera:\n"
			+ "su bibliografía, sus premios, sus manías y por qué sus golpes\n"
			+ "se llaman como se llaman.",
			8, BLOQUEADO
		)
		return

	if entry.borrador:
		_separador()
		_agregar("⚠ Ficha en borrador: pendiente de verificar por el equipo.", 7, ACENTO)

	if not entry.bibliografia.is_empty():
		_seccion("OBRA")
		for libro: Dictionary in entry.bibliografia:
			_agregar("%s  (%d)" % [String(libro.get("titulo", "")), int(libro.get("anio", 0))], 8, TEXTO)
			_agregar("   %s" % String(libro.get("por_que", "")), 7, TENUE)

	if not entry.premios.is_empty():
		_seccion("PREMIOS")
		for premio: Dictionary in entry.premios:
			var linea := "%s (%d)" % [String(premio.get("nombre", "")), int(premio.get("anio", 0))]
			var obra := String(premio.get("obra", ""))
			if obra != "" and obra != "—":
				linea += " — por %s" % obra
			_agregar(linea, 7, TEXTO)

	if not entry.curiosidades.is_empty():
		_seccion("CURIOSIDADES")
		for dato in entry.curiosidades:
			_agregar("· %s" % dato, 7, TEXTO)

	_seccion("POR QUÉ SUS GOLPES SE LLAMAN ASÍ")
	for mov: Dictionary in entry.moveset:
		_agregar(String(mov.get("movimiento", "")), 8, ACENTO)
		_agregar("   %s" % String(mov.get("por_que", "")), 7, TEXTO)

	_seccion("CITA")
	if entry.cita_texto != "":
		_agregar("«%s»" % entry.cita_texto, 8, TEXTO)
		_agregar("   %s" % entry.cita_fuente, 7, TENUE)
	else:
		_agregar("Pendiente de elegir. " + entry.cita_fuente, 7, TENUE)


## Retrato. Mientras no exista el dibujo definitivo se usa la pose de reposo de
## su propia hoja de sprites: no es un retrato, pero es SU silueta y no un
## hueco gris.
func _agregar_retrato(character_id: String) -> void:
	var stats := CharacterLoader.load_stats(character_id)
	if stats == null or stats.sprites == null or not stats.sprites.is_ready():
		return
	var retrato := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = stats.sprites.texture
	atlas.region = stats.sprites.region(0)
	retrato.texture = atlas
	retrato.custom_minimum_size = Vector2(74, 74)
	retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_contenido.add_child(retrato)


# --- Construcción de texto ---------------------------------------------------

func _seccion(titulo: String) -> void:
	_separador()
	_agregar(titulo, 8, ACENTO)


func _separador() -> void:
	var linea := Control.new()
	linea.custom_minimum_size = Vector2(0, 5)
	_contenido.add_child(linea)


func _agregar(texto: String, tamano: int, color: Color) -> void:
	_contenido.add_child(_etiqueta(texto, tamano, color, Vector2.ZERO, _contenido.custom_minimum_size.x))


func _etiqueta(
	texto: String, tamano: int, color: Color, pos: Vector2, ancho: float,
	alineacion: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.position = pos
	etiqueta.custom_minimum_size = Vector2(ancho, 0)
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta.horizontal_alignment = alineacion
	etiqueta.add_theme_font_override("font", _fuente)
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	return etiqueta
