extends SceneTree
## Genera las capas provisionales del escenario del galeón:
##
##   godot --headless --path . --script res://tools/generar_escenario.gd
##
## Igual que el placeholder de sprites, esto no pretende ser arte: pretende que
## el sistema de escenarios se pueda probar entero —parallax, capas animadas,
## orden de dibujo— antes de que exista un solo píxel definitivo, y que el
## artista reciba el tamaño exacto de cada franja.
##
## Cuando lleguen las imágenes de verdad se sustituyen los PNG y ya. Los datos
## de stages/galeon/stage.json no hay que tocarlos si se respetan los tamaños.

const DESTINO := "res://stages/galeon/capas/"

# Anchos pensados para repetirse sin costura en una vista de 480 px.
const ANCHO_MAR := 160
const ANCHO_CIELO := 240
const ANCHO_CUBIERTA := 128

const AZUL_NOCHE := Color(0.09, 0.14, 0.24)
const AZUL_MAR := Color(0.12, 0.24, 0.36)
const AZUL_MAR_CLARO := Color(0.18, 0.34, 0.47)
const ESPUMA := Color(0.62, 0.78, 0.84)
const MADERA := Color(0.36, 0.24, 0.16)
const MADERA_CLARA := Color(0.47, 0.32, 0.21)
const MADERA_OSCURA := Color(0.24, 0.15, 0.10)
const NUBE := Color(0.24, 0.29, 0.42)
const GAVIOTA := Color(0.86, 0.88, 0.92)
const METAL := Color(0.55, 0.57, 0.62)
const PANTALLA := Color(0.55, 0.85, 1.0)


var _finished := false


func _process(_delta: float) -> bool:
	if _finished:
		return true
	_finished = true

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DESTINO))
	_guardar("cielo.png", _cielo())
	_guardar("mar_lejos.png", _mar(ANCHO_MAR, 26, AZUL_MAR, 3))
	_guardar("mar_cerca.png", _mar(ANCHO_MAR, 34, AZUL_MAR_CLARO, 5))
	_guardar("gaviotas.png", _gaviotas())
	_guardar("mastil.png", _mastil())
	_guardar("cubierta.png", _cubierta())
	_guardar("barril.png", _barril())
	quit(0)
	return true


# --- Capas -------------------------------------------------------------------

## Cielo con degradado y nubes. Se repite, así que las nubes no pueden tocar los
## bordes o se vería la costura al desplazarse.
func _cielo() -> Image:
	var alto := 120
	var img := _lienzo(ANCHO_CIELO, alto)
	for y in alto:
		var t := float(y) / float(alto - 1)
		img.fill_rect(Rect2i(0, y, ANCHO_CIELO, 1), AZUL_NOCHE.lerp(AZUL_MAR, t * 0.7))
	for nube: Array in [[30, 26, 46, 6], [120, 44, 62, 7], [78, 72, 38, 5], [168, 60, 40, 6]]:
		img.fill_rect(Rect2i(nube[0], nube[1], nube[2], nube[3]), NUBE)
		img.fill_rect(Rect2i(nube[0] + 6, nube[1] - 3, nube[2] - 16, 3), NUBE)
	return img


## Franja de mar con crestas de espuma. `frames` fotogramas que desplazan las
## crestas: al reproducirlos en bucle el mar parece moverse.
func _mar(ancho: int, alto: int, color: Color, crestas: int) -> Image:
	var frames := 4
	var img := _lienzo(ancho * frames, alto)
	for f in frames:
		var base := f * ancho
		img.fill_rect(Rect2i(base, 0, ancho, alto), color)
		img.fill_rect(Rect2i(base, 0, ancho, 2), color.lightened(0.12))
		for i in crestas:
			# El desplazamiento por fotograma es lo que da el vaivén.
			var x := (i * ancho / crestas + f * 5) % ancho
			var y := 4 + (i * 7) % maxi(1, alto - 8)
			var largo := 10 + (i % 3) * 6
			_franja_ciclica(img, base, ancho, x, y, largo, 1, ESPUMA)
	return img


func _gaviotas() -> Image:
	var frames := 4
	var ancho := 64
	var alto := 24
	var img := _lienzo(ancho * frames, alto)
	# Tres gaviotas batiendo las alas en distinto momento: si todas baten a la
	# vez parecen un solo objeto y se nota que es un bucle.
	for f in frames:
		var base := f * ancho
		for g: Array in [[10, 6, 0], [30, 14, 2], [48, 4, 1]]:
			var fase := (f + int(g[2])) % frames
			var apertura: int = [3, 1, 3, 5][fase]
			var x := int(g[0])
			var y := int(g[1])
			img.fill_rect(Rect2i(base + x, y, 2, 2), GAVIOTA)
			img.fill_rect(Rect2i(base + x - 4, y - apertura + 2, 4, 1), GAVIOTA)
			img.fill_rect(Rect2i(base + x + 2, y - apertura + 2, 4, 1), GAVIOTA)
	return img


## Palo mayor con su verga. Va a parallax 0,85: casi pegado al mundo, pero se
## desplaza un poco respecto a la cubierta para dar sensación de volumen.
func _mastil() -> Image:
	var ancho := 40
	var alto := 190
	var img := _lienzo(ancho, alto)
	img.fill_rect(Rect2i(17, 0, 7, alto), MADERA)
	img.fill_rect(Rect2i(17, 0, 2, alto), MADERA_CLARA)
	img.fill_rect(Rect2i(4, 26, 33, 4), MADERA_OSCURA)     # verga
	img.fill_rect(Rect2i(6, 30, 29, 34), NUBE.lightened(0.35))  # vela recogida
	img.fill_rect(Rect2i(2, 120, 37, 3), MADERA_OSCURA)    # cabo tendido
	return img


## Cubierta: tablas y regala. Se repite en horizontal, así que el patrón tiene
## que cerrar en el ancho exacto.
func _cubierta() -> Image:
	var alto := 90
	var img := _lienzo(ANCHO_CUBIERTA, alto)
	img.fill_rect(Rect2i(0, 0, ANCHO_CUBIERTA, 14), MADERA_OSCURA)   # regala
	img.fill_rect(Rect2i(0, 12, ANCHO_CUBIERTA, 2), MADERA_CLARA)
	img.fill_rect(Rect2i(0, 14, ANCHO_CUBIERTA, alto - 14), MADERA)
	for i in 8:
		var y := 20 + i * 9
		if y < alto:
			img.fill_rect(Rect2i(0, y, ANCHO_CUBIERTA, 1), MADERA_OSCURA)
	for i in 4:
		img.fill_rect(Rect2i(i * 32 + 12, 14, 2, alto - 14), MADERA_OSCURA)  # juntas
	return img


## El barril con el móvil que vibra encima (PLAN.md §5). Dos fotogramas: el
## móvil se mueve 1 px. Es el chiste del escenario y no necesita más.
func _barril() -> Image:
	var ancho := 26
	var alto := 34
	var img := _lienzo(ancho * 2, alto)
	for f in 2:
		var base := f * ancho
		img.fill_rect(Rect2i(base + 2, 10, 22, 24), MADERA)
		img.fill_rect(Rect2i(base + 2, 10, 22, 2), MADERA_CLARA)
		img.fill_rect(Rect2i(base + 2, 18, 22, 2), MADERA_OSCURA)
		img.fill_rect(Rect2i(base + 2, 27, 22, 2), MADERA_OSCURA)
		var vibra := f  # 1 px de temblor
		img.fill_rect(Rect2i(base + 9 + vibra, 4, 8, 6), METAL)
		img.fill_rect(Rect2i(base + 10 + vibra, 5, 6, 4), PANTALLA)
	return img


# --- Utilidades --------------------------------------------------------------

func _lienzo(ancho: int, alto: int) -> Image:
	var img := Image.create_empty(ancho, alto, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


## Dibuja una franja horizontal que, si se sale por la derecha del fotograma,
## reaparece por la izquierda. Sin esto las crestas se cortarían en el borde y
## la repetición cantaría.
func _franja_ciclica(img: Image, base: int, ancho: int, x: int, y: int, largo: int, alto: int, color: Color) -> void:
	for i in largo:
		var px := base + (x + i) % ancho
		img.fill_rect(Rect2i(px, y, 1, alto), color)


func _guardar(nombre: String, img: Image) -> void:
	var ruta := DESTINO + nombre
	var error := img.save_png(ProjectSettings.globalize_path(ruta))
	if error != OK:
		printerr("No se pudo guardar ", ruta, " (error ", error, ")")
	else:
		print("  ", nombre, "  ", img.get_width(), "x", img.get_height())
