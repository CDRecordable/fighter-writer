class_name ProjectileData
extends HitProperties
## Un proyectil del personaje (el panfleto de Lectura Fácil, PLAN.md §4).
##
## Hereda de HitProperties, así que golpea con exactamente las mismas reglas que
## un puñetazo: mismo bloqueo, mismo hitstun, mismo empuje.

var id: StringName = &""
var display_name: String = ""
var debug_color: Color = Color(0.95, 0.90, 0.70)

## Velocidad horizontal en fixed por tick, hacia delante del que lo lanza.
var speed: int = 0
## Ticks que vive antes de desvanecerse.
var lifetime: int = 180
## Desde dónde sale, relativo al que lo lanza (x adelante, y arriba).
var offset_x: int = 0
var offset_y: int = 0
var box: BoxData = null


static func from_dict(id_in: StringName, d: Dictionary) -> ProjectileData:
	var data := ProjectileData.new()
	data.id = id_in
	data.display_name = String(d.get("display_name", String(id_in)))
	data.debug_color = Color(String(d.get("debug_color", "#f2e6b4")))
	data.read_hit_properties(d)
	data.speed = FP.px_from(d, "speed", 2.0)
	data.lifetime = int(d.get("lifetime", 180))
	data.offset_x = int(d.get("offset_x", 20))
	data.offset_y = int(d.get("offset_y", 30))
	data.box = BoxData.from_dict(d.get("box", {"x": -7, "y": -6, "w": 14, "h": 12}))
	return data
