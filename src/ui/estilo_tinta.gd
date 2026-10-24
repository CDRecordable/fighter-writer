class_name EstiloTinta
extends RefCounted
## El lenguaje visual "Tinta", compartido por el HUD y todas las pantallas:
## paleta, texto con sombra dura, marcos de imprenta y el dibujo de un
## escritor de pie.
##
## Funciones estáticas que reciben el CanvasItem donde dibujar, en vez de una
## clase base para heredar: el HUD es un Control, el diorama un Node2D, y los
## dos dibujan igual sin tener que compartir padre.

# Papel viejo, tinta de imprenta y el dorado de las barras.
const TINTA_OSCURA := Color("140c1c")
const FONDO := Color("1a1124")
const FONDO_PANEL := Color("2b1e33")
const PAPEL := Color("efe3c8")
const PAPEL_TENUE := Color("9c8fa8")
const DORADO := Color("f2c14e")
const DORADO_LUZ := Color("ffe9a0")
const DORADO_SOMBRA := Color("c7892f")
const ROJO := Color("e8553a")
const ROJO_LUZ := Color("ff9a6b")
const TINTA_AZUL := Color("3d4bd6")
const TINTA_LUZ := Color("8f9cff")
const SUPER := Color("ff5fae")
const SUPER_LUZ := Color("ffc2e0")
## Colores de jugador: J1 rojo-tinta de corrector, J2 azul de pluma.
const COLOR_J1 := Color("ff6b6b")
const COLOR_J2 := Color("6fb7ff")


## Texto con sombra dura de 1 px de glifo abajo a la derecha. Se lee sobre
## cualquier fondo sin necesitar una franja opaca detrás. La sombra escala con
## el tamaño: a 2× se separa 2 px, a 3× tres.
static func texto(
	ci: CanvasItem, pos: Vector2, cadena: String, tam: int, color: Color,
	alin: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, ancho: float = -1.0,
	sombra: bool = true
) -> void:
	var fuente := ThemeDB.fallback_font
	if sombra:
		var paso := float(escala(tam))
		ci.draw_string(fuente, pos + Vector2(paso, paso), cadena, alin, ancho, tam, TINTA_OSCURA)
	ci.draw_string(fuente, pos, cadena, alin, ancho, tam, color)


## Rótulo grande: contorno de tinta de 1 px y sombra de un píxel de glifo.
static func rotulo(
	ci: CanvasItem, pos: Vector2, cadena: String, tam: int, color: Color,
	alin: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER, ancho: float = -1.0
) -> void:
	var fuente := ThemeDB.fallback_font
	var paso := float(escala(tam))
	ci.draw_string(fuente, pos + Vector2(paso, paso + 1.0), cadena, alin, ancho, tam, TINTA_OSCURA)
	for d: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		ci.draw_string(fuente, pos + d, cadena, alin, ancho, tam, TINTA_OSCURA)
	ci.draw_string(fuente, pos, cadena, alin, ancho, tam, color)


## A qué múltiplo entero se dibuja la fuente pixel a este tamaño.
static func escala(tam: int) -> int:
	return maxi(1, roundi(float(tam) / float(FuentePixel.TAMANO)))


static func ancho_texto(cadena: String, tam: int) -> float:
	return ThemeDB.fallback_font.get_string_size(cadena, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x


## Caja con marco de tinta, esquinas recortadas y filete de papel arriba.
static func marco(ci: CanvasItem, caja: Rect2, fondo: Color = FONDO_PANEL, borde: Color = TINTA_OSCURA) -> void:
	ci.draw_rect(Rect2(caja.position.x - 1.0, caja.position.y, caja.size.x + 2.0, caja.size.y), borde)
	ci.draw_rect(Rect2(caja.position.x, caja.position.y - 1.0, caja.size.x, caja.size.y + 2.0), borde)
	ci.draw_rect(caja, fondo)
	ci.draw_rect(Rect2(caja.position, Vector2(caja.size.x, 1)), Color(PAPEL, 0.30))


## Rombo de 7x7 con contorno: marca de ronda ganada y cursor de menú.
static func rombo(ci: CanvasItem, pos: Vector2, color: Color, brillo: bool = false) -> void:
	var filas := [1, 3, 5, 7, 5, 3, 1]
	var cx := int(pos.x) + 3
	var y0 := int(pos.y)
	ci.draw_rect(Rect2(cx, y0 - 1, 1, 1), TINTA_OSCURA)
	ci.draw_rect(Rect2(cx, y0 + 7, 1, 1), TINTA_OSCURA)
	for f in filas.size():
		var mitad: int = (filas[f] - 1) / 2
		ci.draw_rect(Rect2(cx - mitad - 1, y0 + f, filas[f] + 2, 1), TINTA_OSCURA)
		ci.draw_rect(Rect2(cx - mitad, y0 + f, filas[f], 1), color)
	if brillo:
		ci.draw_rect(Rect2(cx - 1, y0 + 2, 1, 1), DORADO_LUZ)


## Un escritor de pie con su animación de reposo, pies en `pies`. Para los
## menús y la selección: el mismo sprite del combate, a la misma escala.
static func escritor(
	ci: CanvasItem, stats: FighterStats, pies: Vector2, tick: int, mirando: int = 1,
	tinte: Color = Color.WHITE, animacion: StringName = &"idle"
) -> void:
	if stats == null or stats.sprites == null or not stats.sprites.is_ready():
		return
	var anim := stats.get_animation(animacion)
	var indice := anim.index_at(tick) if anim != null else 0
	ci.draw_set_transform(pies.round(), 0.0, Vector2(float(mirando), 1.0))
	ci.draw_texture_rect_region(
		stats.sprites.texture, stats.sprites.destination(), stats.sprites.region(indice), tinte
	)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Sombra de suelo bajo un escritor: una elipse de píxeles. La usan el
## combate (que la encoge y aclara al saltar) y los menús.
static func sombra_suelo(ci: CanvasItem, pies: Vector2, ancho: float = 46.0, alfa: float = 0.55) -> void:
	var color := Color(0.06, 0.02, 0.09, alfa)
	var filas := [0.6, 0.88, 1.0, 0.92, 0.7, 0.4]
	for f in filas.size():
		var w := roundf(ancho * float(filas[f]) * 0.5) * 2.0
		ci.draw_rect(Rect2(roundf(pies.x) - w * 0.5, roundf(pies.y) - 2.0 + float(f), w, 1.0), color)
