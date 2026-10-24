class_name FuentePixel
extends RefCounted
## Convierte assets/fuente/tinta.txt en una fuente bitmap de Godot.
##
## La fuente se dibuja a tamaño nativo (8) y a múltiplos enteros: pedirla a
## 16 la duplica píxel a píxel y a 24 la triplica. Nunca a escala fraccionaria,
## que es lo que hacía borrosa la fuente vectorial por defecto. Godot redondea
## tamaño / 8 al entero más cercano, así que los tamaños 4–11 salen a 1×,
## 12–19 a 2× y 20–27 a 3×.

const RUTA := "res://assets/fuente/tinta.txt"
const TAMANO := 8
## Filas de la celda: 2 para tildes de mayúscula, 7 de cuerpo, 2 bajo la base.
const FILAS_TILDE := 2
const FILAS_CUERPO := 7
const ALTO_CELDA := 11
const ASCENSO := FILAS_TILDE + FILAS_CUERPO

static var _cache: FontFile = null


static func cargar() -> FontFile:
	if _cache == null:
		_cache = _construir(_leer_glifos())
	return _cache


## Devuelve {carácter: {"ancho": int, "pixeles": Array[Vector2i]}} con las
## coordenadas ya en la celda de 11 filas.
static func _leer_glifos() -> Dictionary:
	var texto := FileAccess.get_file_as_string(RUTA)
	var glifos := {}
	var marcas := {}
	var compuestos: Array[PackedStringArray] = []
	var actual: Array[String] = []
	var destino := ""  # "g:X" o "m:nombre"

	var lineas := texto.split("\n")
	lineas.append("")  # fuerza el cierre del último bloque
	for bruta: String in lineas:
		var linea := bruta.strip_edges()
		var es_fila := not linea.is_empty() and linea.lstrip("#.").is_empty()
		if es_fila and not destino.is_empty():
			actual.append(linea)
			continue
		if not destino.is_empty():
			_cerrar_bloque(destino, actual, glifos, marcas)
			destino = ""
			actual = []
		if linea.begins_with("= "):
			var resto := linea.substr(2)
			if resto.contains(" < "):
				var partes := resto.split(" < ")
				var base_y_marca := partes[1].split(" ")
				compuestos.append(PackedStringArray([partes[0], base_y_marca[0], base_y_marca[1]]))
			else:
				destino = "g:" + (" " if resto == "espacio" else resto)
		elif linea.begins_with("~ "):
			destino = "m:" + linea.substr(2)

	for c in compuestos:
		glifos[c[0]] = _componer(glifos[c[1]], marcas[c[2]])
	return glifos


static func _cerrar_bloque(destino: String, filas: Array[String], glifos: Dictionary, marcas: Dictionary) -> void:
	var nombre := destino.substr(2)
	var ancho := 0
	for f in filas:
		ancho = maxi(ancho, f.length())
	var pixeles: Array[Vector2i] = []
	# Las marcas guardan sus filas tal cual; los glifos empiezan en la línea
	# de mayúsculas, que es la fila FILAS_TILDE de la celda.
	var desplazamiento := 0 if destino.begins_with("m:") else FILAS_TILDE
	for y in filas.size():
		for x in filas[y].length():
			if filas[y][x] == "#":
				pixeles.append(Vector2i(x, y + desplazamiento))
	var glifo := {"ancho": ancho, "pixeles": pixeles}
	if destino.begins_with("m:"):
		marcas[nombre] = glifo
	else:
		glifos[nombre] = glifo


## Pone la marca justo encima del píxel más alto de la base, centrada. Así la
## misma tilde sirve para "a" (va en las filas de las astas) y para "A" (va en
## las dos filas de reserva de arriba).
static func _componer(base: Dictionary, marca: Dictionary) -> Dictionary:
	var arriba := ALTO_CELDA
	for p: Vector2i in base["pixeles"]:
		arriba = mini(arriba, p.y)
	var dx := floori((int(base["ancho"]) - int(marca["ancho"])) / 2.0)
	var desplazar_base := maxi(0, -dx)
	var pixeles: Array[Vector2i] = []
	for p: Vector2i in base["pixeles"]:
		pixeles.append(p + Vector2i(desplazar_base, 0))
	for p: Vector2i in marca["pixeles"]:
		pixeles.append(Vector2i(p.x + dx + desplazar_base, p.y + arriba - 2))
	var ancho := maxi(int(base["ancho"]) + desplazar_base, int(marca["ancho"]) + dx + desplazar_base)
	return {"ancho": ancho, "pixeles": pixeles}


static func _construir(glifos: Dictionary) -> FontFile:
	var ancho_total := 0
	for g: Dictionary in glifos.values():
		ancho_total += int(g["ancho"]) + 1
	var imagen := Image.create(maxi(ancho_total, 1), ALTO_CELDA, false, Image.FORMAT_LA8)

	var fuente := FontFile.new()
	fuente.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	fuente.generate_mipmaps = false
	fuente.multichannel_signed_distance_field = false
	fuente.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	fuente.hinting = TextServer.HINTING_NONE
	fuente.allow_system_fallback = false
	fuente.fixed_size = TAMANO
	fuente.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY

	var celda := Vector2i(TAMANO, 0)
	fuente.set_cache_ascent(0, TAMANO, ASCENSO)
	fuente.set_cache_descent(0, TAMANO, ALTO_CELDA - ASCENSO)

	var x := 0
	for caracter: String in glifos:
		var g: Dictionary = glifos[caracter]
		var ancho := int(g["ancho"])
		for p: Vector2i in g["pixeles"]:
			imagen.set_pixel(x + p.x, p.y, Color.WHITE)
		var indice := caracter.unicode_at(0)
		fuente.set_glyph_advance(0, TAMANO, indice, Vector2(ancho + 1, 0))
		fuente.set_glyph_offset(0, celda, indice, Vector2(0, -ASCENSO))
		fuente.set_glyph_size(0, celda, indice, Vector2(ancho, ALTO_CELDA))
		fuente.set_glyph_uv_rect(0, celda, indice, Rect2(x, 0, ancho, ALTO_CELDA))
		fuente.set_glyph_texture_idx(0, celda, indice, 0)
		x += ancho + 1

	fuente.set_texture_image(0, celda, 0, imagen)
	return fuente
