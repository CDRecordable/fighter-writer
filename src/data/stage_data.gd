class_name StageData
extends RefCounted
## Un escenario: capas de fondo con parallax y elementos animados.
##
## Igual que un personaje, un escenario es UNA CARPETA autocontenida en
## `stages/`: su `stage.json`, sus imágenes y —esto importa— sus créditos.
##
## Los créditos van en los datos a propósito. Si el juego usa arte con licencia
## CC-BY, la atribución es una obligación legal, y dejarla en la memoria de
## alguien es como no tenerla. Aquí viaja pegada al escenario que la genera, y
## `tools/generar_creditos.gd` la vuelca a CREDITOS.md.

const ROOT := "res://stages"


class Layer:
	var texture: Texture2D = null
	## 1.0 = pegada al mundo (se mueve como el suelo). 0.0 = pegada a la
	## cámara, o sea infinitamente lejos. Lo de en medio es la profundidad.
	var parallax: float = 1.0
	var x: int = 0  ## px, desplazamiento horizontal en el mundo
	var y: int = 0  ## px sobre el suelo donde se apoya el BORDE INFERIOR
	var repeat_x: bool = false
	## Tinte multiplicativo. Es la herramienta para meter arte de terceros sin
	## editar el PNG: baja el contraste de una capa que canta o la mete en la
	## paleta del escenario. En un juego de lucha el fondo NUNCA debe competir
	## con los luchadores por la atención.
	var tint: Color = Color.WHITE
	## Tiras horizontales de fotogramas para las cosas que se mueven al fondo
	## (las gaviotas del galeón, PLAN.md §5). 1 = imagen quieta.
	var frames: int = 1
	var hold: int = 8

	func frame_width() -> int:
		if texture == null:
			return 0
		return texture.get_width() / maxi(1, frames)


var id: StringName = &""
var display_name: String = ""
var owner_character: StringName = &""
var half_width: int = 360
var floor_screen_y: int = 96
var sky_color: Color = Color(0.10, 0.07, 0.14)
var layers: Array[Layer] = []
var credits: Array[Dictionary] = []


static func list_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	var dir := DirAccess.open(ROOT)
	if dir == null:
		return ids
	for name in dir.get_directories():
		if FileAccess.file_exists("%s/%s/stage.json" % [ROOT, name]):
			ids.append(name)
	ids.sort()
	return ids


static func load_stage(stage_id: String) -> StageData:
	var path := "%s/%s/stage.json" % [ROOT, stage_id]
	if not FileAccess.file_exists(path):
		push_warning("StageData: falta %s; se usará el fondo provisional." % path)
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		push_error("StageData: JSON inválido en %s" % path)
		return null
	return from_dict(stage_id, parsed)


static func from_dict(stage_id: String, d: Dictionary) -> StageData:
	var stage := StageData.new()
	stage.id = StringName(stage_id)
	stage.display_name = String(d.get("display_name", stage_id))
	stage.owner_character = StringName(String(d.get("owner", "")))
	stage.half_width = int(d.get("half_width", 360))
	stage.floor_screen_y = int(d.get("floor_screen_y", 96))
	stage.sky_color = Color(String(d.get("sky_color", "#1a1224")))

	for raw: Variant in d.get("layers", []):
		if not (raw is Dictionary):
			continue
		var entry: Dictionary = raw
		var layer := Layer.new()
		layer.parallax = float(entry.get("parallax", 1.0))
		layer.x = int(entry.get("x", 0))
		layer.y = int(entry.get("y", 0))
		layer.repeat_x = bool(entry.get("repeat_x", false))
		layer.tint = Color(String(entry.get("tint", "#ffffff")))
		layer.frames = maxi(1, int(entry.get("frames", 1)))
		layer.hold = maxi(1, int(entry.get("hold", 8)))
		var image_path := "%s/%s/%s" % [ROOT, stage_id, String(entry.get("image", ""))]
		if ResourceLoader.exists(image_path):
			layer.texture = load(image_path)
			stage.layers.append(layer)
		else:
			push_warning("StageData: falta la capa %s" % image_path)

	for raw: Variant in d.get("credits", []):
		if raw is Dictionary:
			stage.credits.append(raw)
	return stage
