class_name CombatHUD
extends Control
## HUD provisional del prototipo gris: vida, Tinta, reloj, rondas y avisos.
##
## Dibujado a mano con _draw() y la fuente por defecto del motor. No merece la
## pena montar escenas de Control todavía: esto se tira entero en la Fase 2,
## cuando el artista entregue el marco de la interfaz. Lo que sí importa ya es
## que los NÚMEROS sean legibles mientras se afina el combate.

const MARGIN := 6.0
const BAR_HEIGHT := 9.0
const METER_HEIGHT := 4.0
const BAR_WIDTH := 196.0

var arena: Node = null

var _font: Font = null


func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if arena == null or arena.fighters.size() < 2:
		return
	var width := size.x

	_draw_fighter_panel(arena.fighters[0], MARGIN, false)
	_draw_fighter_panel(arena.fighters[1], width - MARGIN - BAR_WIDTH, true)
	_draw_clock(width)
	_draw_rounds(width)
	_draw_banner(width)
	_draw_help(width)


func _draw_fighter_panel(fighter: Fighter, x: float, mirrored: bool) -> void:
	var y := MARGIN + 8.0
	_draw_bar(
		Rect2(x, y, BAR_WIDTH, BAR_HEIGHT),
		fighter.health_ratio(),
		Color(0.95, 0.83, 0.25),
		mirrored
	)
	# La Tinta llena cambia de color: el jugador tiene que saber que puede
	# gastar el súper sin apartar la vista del combate.
	var meter_color := Color(0.35, 0.75, 1.0)
	if fighter.has_super():
		meter_color = Color(1.0, 0.55, 0.85)
	_draw_bar(
		Rect2(x, y + BAR_HEIGHT + 2.0, BAR_WIDTH * 0.75, METER_HEIGHT),
		fighter.meter_ratio(),
		meter_color,
		mirrored
	)
	var name_pos := Vector2(x, MARGIN + 6.0)
	var align := HORIZONTAL_ALIGNMENT_LEFT
	if mirrored:
		align = HORIZONTAL_ALIGNMENT_RIGHT
	draw_string(
		_font, name_pos + Vector2(0, 0), fighter.stats.display_name.to_upper(),
		align, BAR_WIDTH, 8, Color(0.92, 0.90, 0.86)
	)


func _draw_bar(rect: Rect2, ratio: float, color: Color, mirrored: bool) -> void:
	draw_rect(rect.grow(1.0), Color(0, 0, 0, 0.75))
	draw_rect(rect, Color(0.20, 0.16, 0.24))
	var filled := rect.size.x * clampf(ratio, 0.0, 1.0)
	if filled <= 0.0:
		return
	# Las barras se vacían hacia el centro de la pantalla, como en SF2: el
	# jugador 2 pierde vida de derecha a izquierda.
	var fill_x := rect.position.x + (rect.size.x - filled) if mirrored else rect.position.x
	draw_rect(Rect2(fill_x, rect.position.y, filled, rect.size.y), color)


func _draw_clock(width: float) -> void:
	var text := "%02d" % arena.clock_seconds()
	var color := Color(0.95, 0.95, 0.90)
	if arena.clock_seconds() <= 10:
		color = Color(1.0, 0.35, 0.35)
	draw_string(
		_font, Vector2(width * 0.5 - 20.0, MARGIN + 18.0), text,
		HORIZONTAL_ALIGNMENT_CENTER, 40.0, 18, color
	)


func _draw_rounds(width: float) -> void:
	# Un punto por ronda ganada: el jugador tiene que ver a un golpe de vista
	# si el combate está en match point.
	for player in 2:
		for i in 2:
			var offset := 8.0 + i * 8.0
			var x := width * 0.5 - offset if player == 0 else width * 0.5 + offset - 5.0
			var rect := Rect2(x, MARGIN + 22.0, 5.0, 5.0)
			draw_rect(rect, Color(0.25, 0.22, 0.28))
			if arena.rounds_won[player] > i:
				draw_rect(rect, Color(0.95, 0.83, 0.25))


func _draw_banner(width: float) -> void:
	if String(arena.banner).is_empty():
		return
	draw_string(
		_font, Vector2(0, size.y * 0.42), String(arena.banner),
		HORIZONTAL_ALIGNMENT_CENTER, width, 22, Color(1.0, 0.95, 0.75)
	)


func _draw_help(width: float) -> void:
	var accessible := "sí" if arena.accessible_mode else "no"
	var lines := [
		"J1: WASD · J K puños · N M patadas · L especial (modo accesible)",
		"236+P Danza Bruta · 236+K Lectura Fácil · 214+P Asamblea · 236236+P súper · →+HP agarre",
		"F1 cajas · F2 muñeco: %s · F3 accesible: %s · F5 reiniciar" % [
			String(arena.dummy_mode_label), accessible,
		],
	]
	var y := size.y - MARGIN - 9.0 * float(lines.size() - 1)
	for line: String in lines:
		draw_string(
			_font, Vector2(MARGIN, y), line,
			HORIZONTAL_ALIGNMENT_LEFT, width, 7, Color(0.65, 0.62, 0.70)
		)
		y += 9.0
