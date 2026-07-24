class_name BoxData
extends RefCounted
## Una caja (hurtbox, hitbox o pushbox) definida en datos, nunca en código.
##
## Convenio de coordenadas, el mismo en todo el proyecto:
##   - Origen del luchador: entre los pies, centrado.
##   - x crece HACIA DELANTE (según el facing del personaje). Así una caja se
##     escribe una sola vez y vale mirando a izquierda o a derecha.
##   - y crece HACIA ARRIBA desde el suelo.
##   - Todo en píxeles enteros de la resolución interna (480x270).
##
## Ejemplo: {"x": -12, "y": 0, "w": 24, "h": 76} es un cuerpo de pie de 24x76
## px centrado en los pies.

var x: int = 0
var y: int = 0
var w: int = 0
var h: int = 0


static func from_dict(d: Dictionary) -> BoxData:
	var box := BoxData.new()
	box.x = int(d.get("x", 0))
	box.y = int(d.get("y", 0))
	box.w = int(d.get("w", 0))
	box.h = int(d.get("h", 0))
	return box


static func list_from(raw: Variant) -> Array[BoxData]:
	var out: Array[BoxData] = []
	if raw is Array:
		for item: Variant in raw:
			if item is Dictionary:
				out.append(BoxData.from_dict(item))
	return out


func is_empty() -> bool:
	return w <= 0 or h <= 0


## Proyecta la caja al mundo, en unidades de punto fijo, devolviendo
## [x_min, y_min, x_max, y_max]. `facing` es 1 (derecha) o -1 (izquierda).
func to_world(pos_x: int, pos_y: int, facing: int) -> Array[int]:
	var x1 := x * FP.ONE
	var x2 := (x + w) * FP.ONE
	if facing < 0:
		var swap := x1
		x1 = -x2
		x2 = -swap
	var world: Array[int] = [
		pos_x + x1,
		pos_y + y * FP.ONE,
		pos_x + x2,
		pos_y + (y + h) * FP.ONE,
	]
	return world


## Solape AABB entre dos cajas ya proyectadas al mundo. Bordes que se tocan
## exactamente NO cuentan como golpe: evita hits ambiguos de 1 unidad.
static func overlaps(a: Array[int], b: Array[int]) -> bool:
	return a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]
