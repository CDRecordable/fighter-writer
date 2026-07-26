class_name Progreso
extends RefCounted
## Qué ha desbloqueado el jugador.
##
## En la v1 solo guarda a quién ha vencido, porque de eso depende la Biblioteca:
## vencer a un escritor abre su ficha completa (PLAN.md §6). Antes de vencerlo
## se ve una versión parcial, como los perfiles del manual de SF2.
##
## Esa es la idea que sostiene la mitad educativa del juego: la literatura no se
## sirve de entrada, se gana. Y por eso el desbloqueo se guarda en disco: si se
## perdiera al cerrar, la recompensa no significaría nada.
##
## Es una clase con métodos estáticos y no un autoload a propósito. Los
## autoloads no se resuelven cuando Godot corre con `--script`, que es
## justamente como se ejecutan las pruebas y las herramientas de tools/; con
## esto, el progreso funciona igual en el juego, en los tests y en un script
## suelto.

const RUTA := "user://progreso.cfg"
const SECCION := "biblioteca"

static var _vencidos := {}
static var _cargado := false


static func esta_desbloqueado(character_id: String) -> bool:
	_asegurar_cargado()
	return _vencidos.has(character_id)


static func desbloquear(character_id: String) -> void:
	_asegurar_cargado()
	if character_id == "" or _vencidos.has(character_id):
		return
	_vencidos[character_id] = true
	guardar()


static func desbloquear_todo() -> void:
	_asegurar_cargado()
	for id in CharacterLoader.list_ids():
		_vencidos[id] = true
	guardar()


static func olvidar_todo() -> void:
	_asegurar_cargado()
	_vencidos.clear()
	guardar()


static func _asegurar_cargado() -> void:
	if _cargado:
		return
	_cargado = true
	cargar()


static func cargar() -> void:
	_vencidos.clear()
	var archivo := ConfigFile.new()
	if archivo.load(RUTA) != OK:
		return
	if not archivo.has_section(SECCION):
		return
	for clave in archivo.get_section_keys(SECCION):
		if bool(archivo.get_value(SECCION, clave, false)):
			_vencidos[clave] = true


static func guardar() -> void:
	var archivo := ConfigFile.new()
	for id in _vencidos.keys():
		archivo.set_value(SECCION, String(id), true)
	archivo.save(RUTA)
