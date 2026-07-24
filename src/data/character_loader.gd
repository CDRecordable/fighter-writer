class_name CharacterLoader
extends RefCounted
## Carga los "paquetes de personaje" de res://characters/.
##
## Un personaje es UNA CARPETA autocontenida (PLAN.md §7): fighter.json con
## stats y movimientos, wiki.json con su ficha de la Biblioteca, y sprites/.
## Añadir un escritor —o publicar un DLC— es añadir una carpeta, sin tocar
## código ni ninguna lista central.

const ROOT := "res://characters"


static func list_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	var dir := DirAccess.open(ROOT)
	if dir == null:
		push_error("CharacterLoader: no existe %s" % ROOT)
		return ids
	for name in dir.get_directories():
		if FileAccess.file_exists("%s/%s/fighter.json" % [ROOT, name]):
			ids.append(name)
	ids.sort()
	return ids


static func load_stats(character_id: String) -> FighterStats:
	var data := _read_json("%s/%s/fighter.json" % [ROOT, character_id])
	if data.is_empty():
		return null
	return FighterStats.from_dict(data)


## Ficha de la Biblioteca. Se lee aparte del combate porque tiene otro ciclo de
## vida: la wiki se abre desde el menú y no debe arrastrar datos de frames.
static func load_wiki(character_id: String) -> Dictionary:
	return _read_json("%s/%s/wiki.json" % [ROOT, character_id])


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("CharacterLoader: falta %s" % path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("CharacterLoader: JSON inválido en %s" % path)
		return {}
	return parsed
