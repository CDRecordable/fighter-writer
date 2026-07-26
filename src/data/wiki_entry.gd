class_name WikiEntry
extends RefCounted
## Una ficha de la Biblioteca: la mitad educativa del juego (PLAN.md §6).
##
## Se carga del `wiki.json` del propio escritor, que vive en su carpeta junto a
## sus frame data. Esa cercanía es a propósito: quien añade a Cela añade su
## combate y su ficha en el mismo sitio, y es más difícil que se publique un
## personaje jugable sin nada que leer sobre él.
##
## La ficha NO depende de nada del combate. La wiki se abre desde el menú y no
## tiene por qué arrastrar hitboxes ni animaciones para enseñar una biografía.

var id: StringName = &""
var display_name: String = ""
var epigrafe: String = ""
var nacimiento_anio: int = 0
var nacimiento_lugar: String = ""
var base: String = ""
var retrato: String = ""

## Cada entrada: {titulo, anio, por_que}
var bibliografia: Array[Dictionary] = []
## Cada entrada: {nombre, anio, obra}
var premios: Array[Dictionary] = []
var curiosidades: PackedStringArray = PackedStringArray()
var cita_texto: String = ""
var cita_fuente: String = ""
## Cada entrada: {movimiento, por_que} — conecta el juego con la obra, que es
## justo lo que el plan pide que haga esta pantalla.
var moveset: Array[Dictionary] = []
## Marca de que el contenido está sin verificar. Se enseña en pantalla: es
## preferible que se vea un aviso a que alguien se lleve un dato falso.
var borrador: bool = false


static func load_for(character_id: String) -> WikiEntry:
	var d := CharacterLoader.load_wiki(character_id)
	if d.is_empty():
		return null
	var entry := WikiEntry.new()
	entry.id = StringName(String(d.get("id", character_id)))
	entry.display_name = String(d.get("display_name", character_id))
	entry.epigrafe = String(d.get("epigrafe", ""))
	entry.base = String(d.get("base", ""))
	entry.retrato = String(d.get("retrato", ""))
	entry.borrador = d.has("_estado")

	var nacimiento: Dictionary = d.get("nacimiento", {})
	entry.nacimiento_anio = int(nacimiento.get("anio", 0))
	entry.nacimiento_lugar = String(nacimiento.get("lugar", ""))

	entry.bibliografia = _dicts(d.get("bibliografia", []))
	entry.premios = _dicts(d.get("premios", []))
	entry.moveset = _dicts(d.get("moveset_explicado", []))

	for raw: Variant in d.get("curiosidades", []):
		entry.curiosidades.append(String(raw))

	var cita: Dictionary = d.get("cita", {})
	entry.cita_texto = String(cita.get("texto", ""))
	entry.cita_fuente = String(cita.get("fuente", ""))
	return entry


static func _dicts(raw: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if raw is Array:
		for item: Variant in raw:
			if item is Dictionary:
				out.append(item)
	return out


func lugar_y_anio() -> String:
	if nacimiento_anio == 0:
		return base
	var texto := "%s, %d" % [nacimiento_lugar, nacimiento_anio]
	if base != "" and base != nacimiento_lugar:
		texto += "  ·  vive en %s" % base
	return texto
