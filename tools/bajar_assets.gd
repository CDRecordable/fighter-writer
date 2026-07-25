extends SceneTree
## Baja el arte de terceros que no puede vivir en el repositorio:
##
##   godot --headless --path . --script res://tools/bajar_assets.gd
##
## Qué problema resuelve: varias licencias buenas (CC-BY de itch.io, OGA-BY)
## permiten usar el arte en el juego pero **prohíben redistribuir los
## archivos**. Como este repositorio es público, subir esos PNG sería
## redistribuirlos. Así el equipo los usa, el repositorio sigue limpio y un
## clon nuevo arranca igual: los sprites que falten caen al rectángulo y las
## capas que falten se saltan con un aviso.
##
## Lo que SÍ se versiona es la lista (tools/assets_externos.json): qué se usa,
## de dónde sale y bajo qué licencia. Eso no es redistribuir, es documentar.
##
## No todo se puede automatizar: itch.io genera enlaces de descarga temporales
## por sesión, así que esos hay que bajarlos a mano. La herramienta lo dice y
## deja claro dónde poner el archivo.

const MANIFIESTO := "res://tools/assets_externos.json"
const AGENTE := "WriterFighter/0.1 (herramienta de assets del proyecto)"

var _started := false
var _pendientes_manuales: Array[String] = []
var _fallos: int = 0


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	# El trabajo lo hace la corrutina; ella llama a quit() cuando acaba.
	return false


func _run() -> void:
	var datos := _leer_manifiesto()
	if datos.is_empty():
		quit(1)
		return

	var carpeta := ProjectSettings.globalize_path(
		"res://%s" % String(datos.get("destino", "assets_externos"))
	)
	DirAccess.make_dir_recursive_absolute(carpeta)

	var http := HTTPRequest.new()
	root.add_child(http)

	for raw: Variant in datos.get("assets", []):
		if raw is Dictionary:
			await _procesar(raw, carpeta, http)

	http.queue_free()
	_resumen(carpeta)
	quit(1 if _fallos > 0 else 0)


func _leer_manifiesto() -> Dictionary:
	if not FileAccess.file_exists(MANIFIESTO):
		printerr("No existe ", MANIFIESTO)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFIESTO))
	if not (parsed is Dictionary):
		printerr("Manifiesto inválido: ", MANIFIESTO)
		return {}
	return parsed


func _procesar(asset: Dictionary, carpeta: String, http: HTTPRequest) -> void:
	var nombre := String(asset.get("obra", asset.get("id", "?")))
	var archivo := String(asset.get("archivo", ""))
	if archivo == "":
		printerr("  [%s] sin 'archivo' en el manifiesto" % nombre)
		_fallos += 1
		return
	var ruta := carpeta.path_join(archivo)

	if FileAccess.file_exists(ruta):
		print("  ya está  %s  (%s)" % [nombre, archivo])
		_post_descarga(asset, ruta, carpeta)
		return

	var url := String(asset.get("descarga", ""))
	if url == "":
		print("  MANUAL   %s" % nombre)
		_pendientes_manuales.append(
			"%s\n      %s\n      %s\n      Guardar como: %s" % [
				nombre,
				String(asset.get("url", "")),
				String(asset.get("manual", "Descarga manual.")),
				ruta,
			]
		)
		return

	print("  bajando  %s ..." % nombre)
	if not await _descargar(url, ruta, http):
		# Un archivo a medias es peor que ninguno: engaña al siguiente que mire.
		if FileAccess.file_exists(ruta):
			DirAccess.remove_absolute(ruta)
		printerr("    no se pudo bajar. Queda como descarga manual:")
		printerr("      %s" % url)
		printerr("      Guardar como: %s" % ruta)
		_fallos += 1
		return

	print("    ok  sha256=%s" % FileAccess.get_sha256(ruta))
	_post_descarga(asset, ruta, carpeta)


## Se intenta por varias vías porque ninguna funciona en todas partes. El TLS
## que trae Godot no da la mano con algunos servidores (opengameart entre
## ellos), y el curl de Windows falla la comprobación de revocación de
## certificados en según qué redes. En vez de elegir una y que el equipo se
## coma el error, se prueban por orden.
func _descargar(url: String, ruta: String, http: HTTPRequest) -> bool:
	http.download_file = ruta
	if http.request(url, PackedStringArray(["User-Agent: " + AGENTE])) == OK:
		var resultado: Array = await http.request_completed
		var codigo: int = resultado[1]
		if resultado[0] == HTTPRequest.RESULT_SUCCESS and codigo >= 200 and codigo < 300:
			return true
		print("    (el TLS de Godot no pudo; probando con el sistema)")
	if FileAccess.file_exists(ruta):
		DirAccess.remove_absolute(ruta)
	return _descargar_con_el_sistema(url, ruta)


func _descargar_con_el_sistema(url: String, ruta: String) -> bool:
	var salida := []
	var codigo := -1
	if OS.get_name() == "Windows":
		# Invoke-WebRequest usa la pila TLS de .NET, que sí valida bien donde
		# el curl de schannel se atasca. Y viene de serie con Windows.
		codigo = OS.execute("powershell", [
			"-NoProfile", "-NonInteractive", "-Command",
			"Invoke-WebRequest -Uri '%s' -OutFile '%s' -UseBasicParsing" % [url, ruta],
		], salida, true)
	else:
		codigo = OS.execute("curl", ["-fsSL", "-o", ruta, url], salida, true)
	if codigo != 0:
		for linea in salida:
			printerr("    ", String(linea).strip_edges())
		return false
	return FileAccess.file_exists(ruta)


func _post_descarga(asset: Dictionary, ruta: String, carpeta: String) -> void:
	if not bool(asset.get("extraer", false)):
		return
	var destino := carpeta.path_join(String(asset.get("id", "asset")))
	if DirAccess.dir_exists_absolute(destino):
		return
	if not _extraer(ruta, destino):
		_fallos += 1


func _extraer(zip_path: String, destino: String) -> bool:
	var zip := ZIPReader.new()
	if zip.open(zip_path) != OK:
		printerr("    no se pudo abrir el zip: ", zip_path)
		return false
	DirAccess.make_dir_recursive_absolute(destino)
	var contados := 0
	for interno in zip.get_files():
		if interno.ends_with("/"):
			continue
		var salida := destino.path_join(interno)
		DirAccess.make_dir_recursive_absolute(salida.get_base_dir())
		var archivo := FileAccess.open(salida, FileAccess.WRITE)
		if archivo == null:
			continue
		archivo.store_buffer(zip.read_file(interno))
		archivo.close()
		contados += 1
	zip.close()
	print("    extraído: %d archivo(s) en %s" % [contados, destino])
	return true


func _resumen(carpeta: String) -> void:
	print("")
	if not _pendientes_manuales.is_empty():
		print("Pendientes de bajar a mano (itch.io no permite automatizarlo):")
		print("")
		for entrada in _pendientes_manuales:
			print("  - ", entrada)
			print("")
	print("Carpeta: ", carpeta)
	print("")
	print("Después de bajar algo hay que reimportar para que Godot lo vea:")
	print("  godot --headless --path . --import")
	print("")
	print("RECORDATORIO: estos assets no se versionan, pero la atribución sigue")
	print("siendo obligatoria al publicar. Actualiza CREDITOS.md con:")
	print("  godot --headless --path . --script res://tools/generar_creditos.gd")
	if _fallos > 0:
		printerr("%d descarga(s) fallida(s)." % _fallos)
