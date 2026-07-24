class_name HitProperties
extends RefCounted
## Lo que pasa cuando algo golpea a alguien.
##
## Vive aparte porque un golpe puede venir de dos sitios muy distintos —un
## movimiento del luchador o un proyectil volando por el escenario— y las reglas
## de impacto tienen que ser idénticas en los dos casos. `MoveData` y
## `ProjectileData` heredan de aquí, así que `Fighter.receive_hit()` no necesita
## saber qué le ha pegado.

## Altura del golpe, que decide cómo hay que bloquearlo:
##   MID      -> de pie o agachado
##   LOW      -> solo agachado (barridos)
##   OVERHEAD -> solo de pie (saltos y golpes descendentes)
enum Height { MID, LOW, OVERHEAD }

var damage: int = 0
var hitstun: int = 12
var blockstun: int = 8
## Congelación de ambos al impactar: de aquí sale el "peso" del golpe.
var hitstop: int = 6
var height: Height = Height.MID
var knockdown: bool = false
## Los agarres no se bloquean. Es lo que los convierte en la respuesta al
## rival que se queda agazapado bloqueando (PLAN.md §3).
var unblockable: bool = false

## Empuje horizontal en fixed por tick, positivo = alejarse de quien pega.
var pushback_hit: int = 0
var pushback_block: int = 0

## Medidor de Tinta que gana QUIEN RECIBE (PLAN.md §3: se llena al dar y al
## recibir). Lo que gana el atacante se calcula a partir de esto en la arena.
var meter_hit: int = 0
var meter_block: int = 0


func read_hit_properties(d: Dictionary) -> void:
	damage = int(d.get("damage", 0))
	hitstun = int(d.get("hitstun", 12))
	blockstun = int(d.get("blockstun", 8))
	hitstop = int(d.get("hitstop", 6))
	height = parse_height(String(d.get("height", "mid")))
	knockdown = bool(d.get("knockdown", false))
	unblockable = bool(d.get("unblockable", false))
	pushback_hit = FP.px_from(d, "pushback_hit", 1.6)
	pushback_block = FP.px_from(d, "pushback_block", 1.2)
	meter_hit = int(d.get("meter_hit", 60))
	meter_block = int(d.get("meter_block", 20))


static func parse_height(s: String) -> Height:
	match s.to_lower():
		"low": return Height.LOW
		"overhead": return Height.OVERHEAD
		_: return Height.MID
