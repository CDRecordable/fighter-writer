class_name SpriteSet
extends RefCounted
## La hoja de sprites de un personaje: una rejilla de celdas del mismo tamaño.
##
## Convenio de alineación, y es el que hay que respetar al dibujar:
## el **pivote** es el punto de la celda que se apoya en el origen del luchador,
## o sea entre los pies y centrado. Todos los dibujos miran a la DERECHA; el
## motor voltea, nunca se dibujan las dos versiones (sería el doble de trabajo
## de arte para nada).

var texture: Texture2D = null
var cell_width: int = 128
var cell_height: int = 128
var pivot_x: int = 64
var pivot_y: int = 116
var columns: int = 8


static func from_dict(character_id: String, d: Dictionary) -> SpriteSet:
	var set := SpriteSet.new()
	var cell: Dictionary = d.get("cell", {})
	set.cell_width = int(cell.get("w", 128))
	set.cell_height = int(cell.get("h", 128))
	var pivot: Dictionary = d.get("pivot", {})
	set.pivot_x = int(pivot.get("x", set.cell_width / 2))
	set.pivot_y = int(pivot.get("y", set.cell_height - 12))
	set.columns = maxi(1, int(d.get("columns", 8)))

	var sheet := String(d.get("sheet", ""))
	if sheet != "":
		var path := "res://characters/%s/%s" % [character_id, sheet]
		# Sin hoja no se rompe nada: el luchador sigue dibujándose como el
		# rectángulo del prototipo gris. Poder arrancar sin arte es lo que
		# permite que programación y arte avancen por separado.
		if ResourceLoader.exists(path):
			set.texture = load(path)
		else:
			push_warning("SpriteSet: no existe %s; se usará el rectángulo gris." % path)
	return set


func is_ready() -> bool:
	return texture != null


## Zona de la hoja que ocupa la celda `index`.
func region(index: int) -> Rect2:
	if index < 0:
		return Rect2()
	var column := index % columns
	var row := index / columns
	return Rect2(column * cell_width, row * cell_height, cell_width, cell_height)


## Dónde va la celda en el espacio local del luchador (origen en los pies,
## y hacia abajo como en Godot), suponiendo que mira a la derecha.
func destination() -> Rect2:
	return Rect2(-pivot_x, -pivot_y, cell_width, cell_height)
