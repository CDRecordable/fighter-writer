extends SceneTree
## Compone una hoja de sprites del juego a partir de frames bajados de
## PixelLab (o de cualquier otra fuente que deje PNGs sueltos):
##
##   godot --headless --path . --script res://tools/importar_pixellab.gd -- <carpeta_entrada> <salida.png>
##
## La carpeta de entrada contiene subcarpetas, una por animación, con los
## frames numerados (000.png, 001.png...). El orden de las subcarpetas en la
## hoja lo fija MANIFIESTO.json si existe; si no, alfabético.
##
## Qué resuelve: PixelLab entrega frames con SU lienzo y SU centrado, y el
## juego espera celdas de tamaño fijo con el pivote en los pies. Aquí se
## re-centra cada frame: se detecta el bloque de píxeles no transparentes, se
## apoya su base en el pivote de la celda, y se centra horizontalmente. Es el
## pegamento entre lo generado y lo que el motor ya sabe leer.

const CELL := 128
const PIVOT_X := 64
const PIVOT_Y := 116
const COLUMNS := 8


var _finished := false


func _process(_delta: float) -> bool:
	if _finished:
		return true
	_finished = true
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("Uso: -- <carpeta_entrada> <salida.png>")
		quit(1)
		return true
	_importar(args[0], args[1])
	return true


func _importar(entrada: String, salida: String) -> void:
	var dir := DirAccess.open(entrada)
	if dir == null:
		printerr("No existe la carpeta ", entrada)
		quit(1)
		return

	var animaciones := dir.get_directories()
	animaciones.sort()

	var frames: Array[Image] = []
	var manifiesto := {}
	var indice := 0
	print("Composición (celda %dx%d, pivote %d,%d):" % [CELL, CELL, PIVOT_X, PIVOT_Y])
	for anim in animaciones:
		var carpeta := entrada.path_join(anim)
		var lista := DirAccess.open(carpeta).get_files()
		lista.sort()
		var primero := indice
		for archivo in lista:
			if not archivo.ends_with(".png"):
				continue
			var img := Image.load_from_file(carpeta.path_join(archivo))
			if img == null:
				printerr("  no se pudo leer ", archivo)
				continue
			frames.append(_centrar(img))
			indice += 1
		manifiesto[anim] = { "desde": primero, "hasta": indice - 1 }
		print("  %-24s celdas %d-%d" % [anim, primero, indice - 1])

	if frames.is_empty():
		printerr("No había frames que importar.")
		quit(1)
		return

	var filas := int(ceil(float(frames.size()) / float(COLUMNS)))
	var hoja := Image.create_empty(COLUMNS * CELL, filas * CELL, false, Image.FORMAT_RGBA8)
	hoja.fill(Color(0, 0, 0, 0))
	for i in frames.size():
		hoja.blit_rect(
			frames[i],
			Rect2i(0, 0, CELL, CELL),
			Vector2i((i % COLUMNS) * CELL, (i / COLUMNS) * CELL)
		)

	var error := hoja.save_png(salida)
	if error != OK:
		printerr("No se pudo guardar ", salida)
		quit(1)
		return
	print("Hoja: %s  (%d frames, %dx%d)" % [salida, frames.size(), hoja.get_width(), hoja.get_height()])

	# Manifiesto con el rango de celdas de cada animación, para mapear al
	# fighter.json sin contar a mano.
	var ruta_manifiesto := salida.get_basename() + ".manifiesto.json"
	var archivo_manifiesto := FileAccess.open(ruta_manifiesto, FileAccess.WRITE)
	if archivo_manifiesto != null:
		archivo_manifiesto.store_string(JSON.stringify(manifiesto, "  "))
		archivo_manifiesto.close()
		print("Manifiesto: ", ruta_manifiesto)
	quit(0)


## Re-centra un frame en una celda del juego: base del dibujo sobre el pivote,
## centrado horizontal. Si el dibujo es más grande que la celda, se recorta y
## se avisa — mejor un pie cortado visible que un desplazamiento silencioso.
func _centrar(img: Image) -> Image:
	var caja := img.get_used_rect()
	var celda := Image.create_empty(CELL, CELL, false, Image.FORMAT_RGBA8)
	celda.fill(Color(0, 0, 0, 0))
	if caja.size.x <= 0:
		return celda
	if caja.size.x > CELL or caja.position.y + caja.size.y > img.get_height():
		push_warning("frame de %dx%d no cabe en la celda de %d" % [caja.size.x, caja.size.y, CELL])
	var destino := Vector2i(
		PIVOT_X - caja.size.x / 2,
		PIVOT_Y - caja.size.y
	)
	celda.blit_rect(img, caja, destino)
	return celda
