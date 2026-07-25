extends SceneTree
## Recoge los créditos de arte de todo el proyecto y escribe CREDITOS.md:
##
##   godot --headless --path . --script res://tools/generar_creditos.gd
##
## Por qué existe: si el juego usa arte con licencia CC-BY, atribuir no es un
## detalle de cortesía, es una condición de la licencia. Dejar esa lista en un
## documento que alguien actualiza a mano es la forma más fácil de publicar
## incumpliendo sin enterarse.
##
## Así, cada escenario y cada personaje lleva sus créditos pegados en su propio
## JSON, y este script los junta. Si un asset entra sin créditos, sale aquí como
## aviso en vez de desaparecer.
##
## Formato de cada entrada (en el array "credits" del JSON):
##   { "obra": "...", "autor": "...", "licencia": "CC-BY 4.0",
##     "url": "https://...", "cambios": "recortado y repaleteado" }

const CARPETAS := ["res://stages", "res://characters", "res://assets"]
const ARCHIVOS := ["stage.json", "fighter.json", "vfx.json"]
const SALIDA := "res://CREDITOS.md"
const MANIFIESTO_EXTERNOS := "res://tools/assets_externos.json"

var _finished := false


func _process(_delta: float) -> bool:
	if _finished:
		return true
	_finished = true

	var entradas: Array[Dictionary] = []
	var sin_creditos: Array[String] = []
	for raiz: String in CARPETAS:
		_recoger(raiz, entradas, sin_creditos)
	_recoger_externos(entradas)

	var texto := _componer(entradas, sin_creditos)
	var archivo := FileAccess.open(SALIDA, FileAccess.WRITE)
	if archivo == null:
		printerr("No se pudo escribir ", SALIDA)
		quit(1)
		return true
	archivo.store_string(texto)
	archivo.close()

	print("CREDITOS.md escrito: %d entrada(s)." % entradas.size())
	for aviso in sin_creditos:
		print("  sin créditos declarados: ", aviso)
	quit(0)
	return true


func _recoger(raiz: String, entradas: Array[Dictionary], sin_creditos: Array[String]) -> void:
	var dir := DirAccess.open(raiz)
	if dir == null:
		return
	for nombre in dir.get_directories():
		for archivo in ARCHIVOS:
			var ruta := "%s/%s/%s" % [raiz, nombre, archivo]
			if not FileAccess.file_exists(ruta):
				continue
			var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(ruta))
			if not (datos is Dictionary):
				continue
			var lista: Variant = (datos as Dictionary).get("credits", [])
			if not (lista is Array) or (lista as Array).is_empty():
				sin_creditos.append(ruta)
				continue
			for entrada: Variant in lista:
				if entrada is Dictionary:
					var copia: Dictionary = (entrada as Dictionary).duplicate()
					copia["_origen"] = ruta
					entradas.append(copia)


## Los assets externos (tools/assets_externos.json) no viven en el repositorio,
## pero si están bajados sí viajan en la build, así que hay que acreditarlos.
## Solo se listan los que están REALMENTE en disco: acreditar algo que no se
## distribuye confundiría a quien lea los créditos.
func _recoger_externos(entradas: Array[Dictionary]) -> void:
	if not FileAccess.file_exists(MANIFIESTO_EXTERNOS):
		return
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFIESTO_EXTERNOS))
	if not (datos is Dictionary):
		return
	var carpeta := "res://%s" % String((datos as Dictionary).get("destino", "assets_externos"))
	for raw: Variant in (datos as Dictionary).get("assets", []):
		if not (raw is Dictionary):
			continue
		var asset: Dictionary = raw
		var ruta := "%s/%s" % [carpeta, String(asset.get("archivo", ""))]
		if not FileAccess.file_exists(ruta):
			continue
		entradas.append({
			"obra": asset.get("obra", ""),
			"autor": asset.get("autor", ""),
			"licencia": asset.get("licencia", ""),
			"url": asset.get("url", ""),
			"cambios": asset.get("cambios", ""),
			"_origen": MANIFIESTO_EXTERNOS,
		})


func _componer(entradas: Array[Dictionary], sin_creditos: Array[String]) -> String:
	var lineas := PackedStringArray()
	lineas.append("# Créditos de Writer Fighter")
	lineas.append("")
	lineas.append("> Generado por `tools/generar_creditos.gd`. **No editar a mano:**")
	lineas.append("> los créditos viven en el JSON de cada escenario y personaje.")
	lineas.append("")

	if entradas.is_empty():
		lineas.append("Todo el arte del proyecto es propio o generado por las")
		lineas.append("herramientas de `tools/`. No hay assets de terceros.")
	else:
		lineas.append("## Arte de terceros")
		lineas.append("")
		for e in entradas:
			var obra := String(e.get("obra", "(sin título)"))
			var autor := String(e.get("autor", "(autor desconocido)"))
			var licencia := String(e.get("licencia", "(licencia sin declarar)"))
			var url := String(e.get("url", ""))
			var linea := "- **%s** — %s · %s" % [obra, autor, licencia]
			if url != "":
				linea += " · [origen](%s)" % url
			lineas.append(linea)
			if String(e.get("cambios", "")) != "":
				lineas.append("  - Modificaciones: %s" % String(e.get("cambios")))
			lineas.append("  - Usado en: `%s`" % String(e.get("_origen", "")))

	if not sin_creditos.is_empty():
		lineas.append("")
		lineas.append("## Sin créditos declarados")
		lineas.append("")
		lineas.append("Estos archivos no declaran ningún crédito. Si su arte es propio")
		lineas.append("o generado, correcto. Si viene de fuera, hay que declararlo antes")
		lineas.append("de publicar:")
		lineas.append("")
		for ruta in sin_creditos:
			lineas.append("- `%s`" % ruta)

	lineas.append("")
	return "\n".join(lineas)
