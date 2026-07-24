class_name AnimationData
extends RefCounted
## Una animación: qué celdas de la hoja de sprites se dibujan y cuánto dura
## cada una, en ticks.
##
## Va a propósito DESACOPLADA de las cajas. Los frames de combate (startup,
## activo, recuperación) y los frames de dibujo son dos relojes distintos que
## avanzan a la vez: el artista puede meter un intercalado para que un golpe se
## lea mejor sin tocar ni un hitbox, y el programador puede recortar dos frames
## de recuperación sin pedirle un dibujo nuevo a nadie.
##
## El precio es que pueden desincronizarse, así que el cargador avisa si la
## duración total de la animación no cuadra con la del movimiento.

var frames := PackedInt32Array()
var holds := PackedInt32Array()
var loop: bool = false
var total: int = 0


static func from_dict(d: Dictionary) -> AnimationData:
	var anim := AnimationData.new()
	for raw: Variant in d.get("frames", []):
		anim.frames.append(int(raw))
	if anim.frames.is_empty():
		return anim

	var raw_holds: Variant = d.get("holds", null)
	if raw_holds is Array and not (raw_holds as Array).is_empty():
		for raw: Variant in raw_holds:
			anim.holds.append(maxi(1, int(raw)))
	else:
		# "hold": 6  ->  todas las celdas duran lo mismo. Es lo normal en las
		# animaciones de estado (idle, andar), que son de ritmo constante.
		var hold := maxi(1, int(d.get("hold", 6)))
		for i in anim.frames.size():
			anim.holds.append(hold)

	# Si faltan duraciones, se repite la última en vez de fallar: un JSON a
	# medio escribir tiene que poder probarse.
	while anim.holds.size() < anim.frames.size():
		anim.holds.append(anim.holds[anim.holds.size() - 1])

	anim.loop = bool(d.get("loop", false))
	for hold in anim.holds:
		anim.total += hold
	return anim


func is_empty() -> bool:
	return frames.is_empty()


## Celda que toca dibujar en el tick `tick` desde que empezó la animación.
func index_at(tick: int) -> int:
	if frames.is_empty():
		return -1
	var t := tick
	if loop and total > 0:
		t = posmod(t, total)
	elif t >= total:
		return frames[frames.size() - 1]  # se queda congelada en la última
	if t < 0:
		return frames[0]
	for i in frames.size():
		t -= holds[i]
		if t < 0:
			return frames[i]
	return frames[frames.size() - 1]


## Rango de ticks [desde, hasta) que cubre la celda `i`. Lo usa el generador de
## placeholders para saber qué pose representa cada celda.
func tick_range(index: int) -> Array[int]:
	var start := 0
	for i in mini(index, holds.size()):
		start += holds[i]
	var length: int = holds[index] if index < holds.size() else 1
	var out: Array[int] = [start, start + length]
	return out
