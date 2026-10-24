class_name CombatHUD
extends Control
## HUD del combate: vida, Tinta, reloj, rondas, avisos y panel de entrenamiento.
##
## Dibujado a mano con _draw() y no con ProgressBar a propósito: en pixel art
## cada píxel del marco tiene que caer donde toca, los extremos de las barras
## van en bisel a 45° (fila a fila, sin antialiasing) y la estela de daño es
## una segunda barra con su propio ritmo. Con nodos de Control sería pelear
## contra el layout para conseguir lo que aquí son diez líneas.
##
## Todo se coloca relativo a `size`: si cambia la resolución interna, el HUD
## se recoloca solo. La fuente es la pixel del juego (FuentePixel), que a
## tamaño 8 sale a 1×, a 16 a 2× y a 24 a 3×.

const MARGEN := 12.0
const ALTO_BARRA := 10
const ANCHO_BARRA := 252
const ALTO_TINTA := 5
const ANCHO_TINTA := 112

# Paleta "Tinta" (EstiloTinta), con los nombres que tienen en el HUD.
const TINTA_OSCURA := EstiloTinta.TINTA_OSCURA
const PAPEL := EstiloTinta.PAPEL
const PAPEL_TENUE := EstiloTinta.PAPEL_TENUE
const FONDO_BARRA := EstiloTinta.FONDO_PANEL
const VIDA := EstiloTinta.DORADO
const VIDA_LUZ := EstiloTinta.DORADO_LUZ
const VIDA_SOMBRA := EstiloTinta.DORADO_SOMBRA
const VIDA_BAJA := EstiloTinta.ROJO
const VIDA_BAJA_LUZ := EstiloTinta.ROJO_LUZ
const ESTELA := Color("a8243a")
const TINTA_AZUL := EstiloTinta.TINTA_AZUL
const TINTA_LUZ := EstiloTinta.TINTA_LUZ
const SUPER := EstiloTinta.SUPER
const SUPER_LUZ := EstiloTinta.SUPER_LUZ

## La estela roja espera esto antes de vaciarse, y luego baja a este ritmo
## (fracción de la barra por segundo). Es lo que deja leer cuánto ha quitado
## un combo después de que acabe.
const ESPERA_ESTELA := 0.55
const VELOCIDAD_ESTELA := 0.75

var arena: Node = null

var _estela := [1.0, 1.0]
var _espera := [0.0, 0.0]
var _tiempo := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_tiempo += delta
	if arena != null and arena.fighters.size() >= 2:
		for i in 2:
			_actualizar_estela(i, arena.fighters[i].health_ratio(), delta)
	queue_redraw()


## La estela es solo visual: sigue a la vida con retraso y nunca toca el
## combate.
func _actualizar_estela(i: int, vida: float, delta: float) -> void:
	if vida >= _estela[i]:
		_estela[i] = vida
		_espera[i] = 0.0
		return
	_espera[i] += delta
	if _espera[i] > ESPERA_ESTELA:
		_estela[i] = maxf(vida, _estela[i] - VELOCIDAD_ESTELA * delta)
		if _estela[i] <= vida:
			_espera[i] = 0.0


func _draw() -> void:
	if arena == null or arena.fighters.size() < 2:
		return
	var ancho := size.x
	for i in 2:
		_draw_vida(i, arena.fighters[i], ancho)
		_draw_tinta(i, arena.fighters[i], ancho)
	_draw_reloj(ancho)
	_draw_rondas(ancho)
	_draw_banner(ancho)
	if arena.training.enabled:
		_draw_training()
		_draw_ayuda(ancho)


# --- Vida --------------------------------------------------------------------

func _draw_vida(i: int, fighter: Fighter, ancho: float) -> void:
	var espejo := i == 1
	var x := MARGEN if not espejo else ancho - MARGEN - ANCHO_BARRA
	var y := MARGEN + 1.0
	var vida := fighter.health_ratio()
	var baja := vida <= 0.3
	_draw_barra_biselada(
		Vector2(x, y), ANCHO_BARRA, ALTO_BARRA, espejo,
		[_estela[i], vida],
		[[ESTELA, ESTELA, ESTELA.darkened(0.25)],
		 [VIDA_BAJA_LUZ if baja else VIDA_LUZ, VIDA_BAJA if baja else VIDA, VIDA_BAJA.darkened(0.3) if baja else VIDA_SOMBRA]]
	)
	# Nombre bajo la barra, por el lado de fuera, como en los arcade.
	var nombre := fighter.stats.display_name.to_upper()
	var alin := HORIZONTAL_ALIGNMENT_RIGHT if espejo else HORIZONTAL_ALIGNMENT_LEFT
	EstiloTinta.texto(self, Vector2(x + (0.0 if espejo else 2.0), y + ALTO_BARRA + 12.0), nombre, 8, PAPEL, alin, ANCHO_BARRA - 2.0)


## Barra con el extremo interior en bisel de 45°: cada fila se recorta un
## píxel más por el lado del centro. `valores` va de atrás adelante (estela,
## vida) y cada relleno trae tres colores: fila de luz, cuerpo y sombra.
## El relleno se ancla al centro de la pantalla y se vacía hacia fuera, como
## en SF2; el borde vaciado es vertical aunque el extremo sea biselado.
func _draw_barra_biselada(origen: Vector2, ancho: int, alto: int, espejo: bool, valores: Array, colores: Array) -> void:
	var ox := int(origen.x)
	var oy := int(origen.y)
	for fila in range(-1, alto + 1):
		var c := _bisel(fila, alto)
		var a := ox - 1 if not espejo else ox + c - 1
		var b := ox + ancho - c + 1 if not espejo else ox + ancho + 1
		draw_rect(Rect2(a, oy + fila, b - a, 1), TINTA_OSCURA)

	for fila in alto:
		var c := _bisel(fila, alto)
		var a := ox if not espejo else ox + c
		var b := ox + ancho - c if not espejo else ox + ancho
		draw_rect(Rect2(a, oy + fila, b - a, 1), FONDO_BARRA)
		for k in valores.size():
			var vacio := int(round(float(ancho) * (1.0 - clampf(float(valores[k]), 0.0, 1.0))))
			var fa := a + vacio if not espejo else a
			var fb := b if not espejo else b - vacio
			if fb <= fa:
				continue
			var trio: Array = colores[k]
			var color: Color = trio[1]
			if fila <= 1:
				color = trio[0]
			elif fila == alto - 1:
				color = trio[2]
			draw_rect(Rect2(fa, oy + fila, fb - fa, 1), color)


## Cuántos píxeles se recorta la fila por el lado del centro: 1 arriba y
## `alto` abajo, así la barra es más larga arriba.
func _bisel(fila: int, alto: int) -> int:
	return clampi(fila + 1, 1, alto)


# --- Tinta (medidor de súper) --------------------------------------------------

func _draw_tinta(i: int, fighter: Fighter, ancho: float) -> void:
	var espejo := i == 1
	var y := size.y - MARGEN - float(ALTO_TINTA)
	var x := MARGEN if not espejo else ancho - MARGEN - ANCHO_TINTA
	var lleno := fighter.has_super()
	var parpadeo := lleno and int(_tiempo * 6.0) % 2 == 0
	var trio := [TINTA_LUZ, TINTA_AZUL, TINTA_AZUL.darkened(0.35)]
	if lleno:
		trio = [SUPER_LUZ, SUPER if parpadeo else SUPER.darkened(0.15), SUPER.darkened(0.35)]
	_draw_barra_biselada(Vector2(x, y), ANCHO_TINTA, ALTO_TINTA, espejo, [fighter.meter_ratio()], [trio])

	var etiqueta := "¡SÚPER!" if lleno else "TINTA"
	var color := SUPER if lleno else PAPEL_TENUE
	var alin := HORIZONTAL_ALIGNMENT_RIGHT if espejo else HORIZONTAL_ALIGNMENT_LEFT
	EstiloTinta.texto(self, Vector2(x, y - 4.0), etiqueta, 8, color, alin, ANCHO_TINTA)


# --- Reloj y rondas ------------------------------------------------------------

func _draw_reloj(ancho: float) -> void:
	var segundos: int = arena.clock_seconds()
	var caja := Rect2(roundf(ancho * 0.5) - 19.0, MARGEN - 4.0, 38.0, 26.0)
	EstiloTinta.marco(self, caja)
	var color := PAPEL
	if segundos <= 10 and int(_tiempo * 4.0) % 2 == 0:
		color = VIDA_BAJA
	EstiloTinta.texto(self, Vector2(caja.position.x, caja.position.y + 21.0), "%02d" % segundos, 16, color, HORIZONTAL_ALIGNMENT_CENTER, caja.size.x)


## Un rombo por ronda ganada bajo el reloj: hay que ver de un vistazo si el
## combate está en match point.
func _draw_rondas(ancho: float) -> void:
	var centro := roundf(ancho * 0.5)
	var y := MARGEN + 27.0
	for jugador in 2:
		for i in 2:
			var dx := 7.0 + float(i) * 9.0
			var cx := centro - dx - 3.0 if jugador == 0 else centro + dx - 4.0
			var ganada: bool = arena.rounds_won[jugador] > i
			EstiloTinta.rombo(self, Vector2(cx, y), VIDA if ganada else FONDO_BARRA, ganada)


# --- Avisos ----------------------------------------------------------------------

func _draw_banner(ancho: float) -> void:
	var texto := String(arena.banner)
	if texto.is_empty():
		return
	EstiloTinta.rotulo(self, Vector2(0, roundf(size.y * 0.40)), texto, 24, VIDA_LUZ, HORIZONTAL_ALIGNMENT_CENTER, ancho)


# --- Entrenamiento -----------------------------------------------------------------

## Panel de entrenamiento. Números, no adornos: es la herramienta con la que se
## decide si un golpe es seguro y si un combo enlaza de verdad.
func _draw_training() -> void:
	var training: Training = arena.training
	var lineas := [
		["Distancia", "%d px" % training.distance_px(arena.fighters)],
		["Combo", training.combo_line()],
		["Ventaja", training.advantage_line()],
		["Último golpe", "%s  %s" % [training.last_move_name, training.last_move_timing]],
		["Muñeco (F2)", String(arena.dummy_mode_label)],
	]
	var caja := Rect2(MARGEN, MARGEN + 46.0, 236.0, float(lineas.size()) * 11.0 + 20.0)
	EstiloTinta.marco(self, caja, Color(TINTA_OSCURA, 0.82))
	var y := caja.position.y + 12.0
	EstiloTinta.texto(self, Vector2(caja.position.x + 5.0, y), "ENTRENAMIENTO (F4)", 8, VIDA, HORIZONTAL_ALIGNMENT_LEFT, caja.size.x)
	y += 13.0
	for entrada: Array in lineas:
		EstiloTinta.texto(self, Vector2(caja.position.x + 5.0, y), String(entrada[0]), 8, PAPEL_TENUE, HORIZONTAL_ALIGNMENT_LEFT, 74.0, false)
		EstiloTinta.texto(self, Vector2(caja.position.x + 82.0, y), String(entrada[1]), 8, PAPEL, HORIZONTAL_ALIGNMENT_LEFT, caja.size.x - 86.0, false)
		y += 11.0


## La chuleta de controles solo sale en entrenamiento: en un combate normal
## era ruido permanente en pantalla. Va en su caja, simétrica al panel de
## entrenamiento, porque suelta sobre la cubierta no se leía.
func _draw_ayuda(ancho: float) -> void:
	var accesible := "sí" if arena.accessible_mode else "no"
	var lineas := [
		"J1: WASD · J K puños · N M patadas",
		"L especial (modo accesible)",
		"236+P Danza · 236+K Lectura · 214+P Asamblea",
		"236236+P súper · →+HP agarre",
		"F1 cajas · F3 accesible: %s · F5 combate · F6 reinicio" % accesible,
	]
	var ancho_caja := 300.0
	var caja := Rect2(ancho - MARGEN - ancho_caja, MARGEN + 46.0, ancho_caja, float(lineas.size()) * 11.0 + 20.0)
	EstiloTinta.marco(self, caja, Color(TINTA_OSCURA, 0.82))
	var y := caja.position.y + 12.0
	EstiloTinta.texto(self, Vector2(caja.position.x + 5.0, y), "CONTROLES", 8, VIDA, HORIZONTAL_ALIGNMENT_LEFT, caja.size.x)
	y += 13.0
	for linea: String in lineas:
		EstiloTinta.texto(self, Vector2(caja.position.x + 5.0, y), linea, 8, PAPEL, HORIZONTAL_ALIGNMENT_LEFT, caja.size.x - 10.0, false)
		y += 11.0
