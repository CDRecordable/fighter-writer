class_name FP
extends RefCounted
## Aritmética de punto fijo entera para la simulación de combate.
##
## Toda la física del combate se calcula con enteros, nunca con float. Motivo:
## la simulación tiene que ser determinista (mismo estado + mismo input =
## mismo resultado, en cualquier máquina y en cualquier ejecución). Eso nos da
## dos cosas: bugs reproducibles hoy, y la puerta abierta al netcode con
## rollback del backlog (PLAN.md §11), que es imposible con floats.
##
## Unidad: 1 píxel = 256 unidades (8 bits de subpíxel).
## Las velocidades se expresan en unidades por tick (60 ticks/s).

const ONE := 256
const SHIFT := 8


## Convierte píxeles (los datos de personaje se escriben en píxeles) a fixed.
static func from_px(px: float) -> int:
	return int(round(px * float(ONE)))


static func to_px(v: int) -> float:
	return float(v) / float(ONE)


## Píxel entero, redondeando siempre hacia abajo. En GDScript el
## desplazamiento de enteros es aritmético, así que esto ya es floor() también
## para negativos: (-1) >> 8 == -1.
static func floor_px(v: int) -> int:
	return v >> SHIFT


static func mul(a: int, b: int) -> int:
	return (a * b) >> SHIFT


static func div(a: int, b: int) -> int:
	if b == 0:
		return 0
	return (a << SHIFT) / b


## Lee un valor en píxeles de un diccionario JSON y lo devuelve en fixed.
static func px_from(d: Dictionary, key: String, fallback: float = 0.0) -> int:
	return from_px(float(d.get(key, fallback)))
