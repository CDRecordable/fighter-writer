class_name InputBuffer
extends RefCounted
## Historial reciente de input de un luchador, y detección de comandos.
##
## Es la pieza que decide si un juego de lucha se siente bien o roto. Hace dos
## cosas que el jugador nota aunque no sepa nombrarlas:
##
## 1. **Guarda las direcciones** para reconocer medias lunas y cargas aunque el
##    jugador las haga a su ritmo, con frames de más o de menos.
## 2. **Guarda el botón unos ticks.** Sin esto, pulsar el botón un frame antes
##    de recuperarte de un golpe = no sale nada, y el juego parece que ignora al
##    jugador. Con esto, el movimiento sale en cuanto puedes actuar.
##
## Las direcciones se guardan en **notación numpad relativa al facing** (6 es
## siempre "hacia el rival"), así el mismo ↓↘→ vale mirando a los dos lados:
##
##     7 8 9        1/2/3 = abajo    4 = atrás
##     4 5 6        5     = neutro   6 = adelante
##     1 2 3        7/8/9 = arriba

const SIZE := 48

## Ticks que se conserva un botón pulsado esperando a poder usarlo. Es la
## perilla de "generosidad" del juego: subirlo perdona más, bajarlo exige más
## precisión. 8 ticks (~0,13 s) está en el rango habitual del género.
const BUTTON_LENIENCY := 8
## El último paso de la secuencia tiene que ser reciente: si no, un ↓↘→ de hace
## medio segundo saldría al pulsar el botón sin querer.
const HEAD_WINDOW := 6
## Ticks que hay que mantener atrás (o abajo) para tener carga.
const CHARGE_TICKS := 45
## Margen para soltar la carga y pulsar adelante.
const CHARGE_RELEASE := 12

const BACK_DIRS := [1, 4, 7]
const FORWARD_DIRS := [3, 6, 9]
const DOWN_DIRS := [1, 2, 3]
const UP_DIRS := [7, 8, 9]

var _dirs := PackedByteArray()
var _presses := PackedByteArray()
var _head: int = 0
var _filled: int = 0

var _charge_back: int = 0
var _charge_back_age: int = SIZE
var _charge_down: int = 0
var _charge_down_age: int = SIZE


func _init() -> void:
	_dirs.resize(SIZE)
	_presses.resize(SIZE)
	clear()


func clear() -> void:
	for i in SIZE:
		_dirs[i] = 5
		_presses[i] = 0
	_head = 0
	_filled = 0
	_charge_back = 0
	_charge_back_age = SIZE
	_charge_down = 0
	_charge_down_age = SIZE


## Se llama una vez por tick, antes de que el luchador decida qué hacer.
func push(input: FighterInput, facing: int) -> void:
	var numpad := to_numpad(input.dir_x, input.dir_y, facing)
	_head = (_head + 1) % SIZE
	_dirs[_head] = numpad
	_presses[_head] = input.pressed
	_filled = mini(_filled + 1, SIZE)
	_update_charges(numpad)


## Apunta una pulsación en el tick más reciente SIN avanzar el historial.
## Se usa durante el hitstop: los dos luchadores están congelados, así que el
## tiempo del buffer tampoco debe correr. Si corriera, la pulsación que el
## jugador hace mientras ve el golpe congelado —que es exactamente cuando
## prepara el siguiente— caducaría antes de poder usarla.
func merge_press(mask: int) -> void:
	_presses[_head] |= mask
	# El tick más reciente pasa a contar aunque el historial esté recién
	# vaciado: si no, las lecturas lo ignorarían por "buffer vacío".
	_filled = maxi(_filled, 1)


static func to_numpad(dir_x: int, dir_y: int, facing: int) -> int:
	# +1 en x es "hacia delante" mire donde mire el personaje.
	var forward := signi(dir_x) * signi(facing)
	return 5 + forward + 3 * signi(dir_y)


## Dirección de hace `age` ticks (0 = la de este tick).
func dir_at(age: int) -> int:
	if age < 0 or age >= SIZE:
		return 5
	return _dirs[(_head - age + SIZE * 2) % SIZE]


func current_dir() -> int:
	return dir_at(0)


## ¿Se pulsó alguno de estos botones en los últimos `window` ticks?
func pressed_within(mask: int, window: int = BUTTON_LENIENCY) -> int:
	for age in mini(window, _filled):
		var hit: int = _presses[(_head - age + SIZE * 2) % SIZE] & mask
		if hit != 0:
			return hit
	return 0


## ¿Se han pulsado TODOS estos botones dentro de la ventana? Hace falta para los
## movimientos de dos botones: sin esto, un súper de carga y el especial de
## carga que comparte su misma entrada se pisan, y el súper se come al especial
## siempre que haya barra.
func pressed_all_within(mask: int, window: int = BUTTON_LENIENCY) -> bool:
	var acumulado := 0
	for age in mini(window, _filled):
		acumulado |= _presses[(_head - age + SIZE * 2) % SIZE]
	return (acumulado & mask) == mask


## Al arrancar cualquier movimiento: olvida las pulsaciones para que la misma
## no dispare un segundo movimiento al tick siguiente. Las direcciones se
## conservan, que el jugador sigue moviendo la palanca.
func consume_buttons() -> void:
	for i in SIZE:
		_presses[i] = 0


## Al arrancar un movimiento por comando: además olvida las direcciones, para
## que la media luna que acaba de salir no siga en el historial y dispare el
## especial otra vez al siguiente botón.
func consume() -> void:
	clear()


func matches(motion: StringName) -> bool:
	if motion == &"":
		return false
	if motion == &"charge46":
		return _has_charge(_charge_back, _charge_back_age, FORWARD_DIRS)
	if motion == &"charge28":
		return _has_charge(_charge_down, _charge_down_age, UP_DIRS)
	var sequence := _parse_sequence(motion)
	if sequence.is_empty():
		return false
	var window := 6 + 4 * sequence.size()
	if _match_sequence(sequence, window):
		return true
	# Segundo intento sin las diagonales: a mucha gente le sale ↓→ en vez de
	# ↓↘→, y rechazarlo solo hace el juego más hostil, no más profundo.
	var relaxed := _without_diagonals(sequence)
	if relaxed.size() == sequence.size() or relaxed.size() < 2:
		return false
	return _match_sequence(relaxed, window)


# --- Interior ----------------------------------------------------------------

func _update_charges(numpad: int) -> void:
	if numpad in BACK_DIRS:
		_charge_back += 1
		_charge_back_age = 0
	elif _charge_back >= CHARGE_TICKS:
		_charge_back_age += 1
		if _charge_back_age > CHARGE_RELEASE:
			_charge_back = 0
	else:
		_charge_back = 0

	if numpad in DOWN_DIRS:
		_charge_down += 1
		_charge_down_age = 0
	elif _charge_down >= CHARGE_TICKS:
		_charge_down_age += 1
		if _charge_down_age > CHARGE_RELEASE:
			_charge_down = 0
	else:
		_charge_down = 0


func _has_charge(charge: int, age: int, release_dirs: Array) -> bool:
	return charge >= CHARGE_TICKS and age <= CHARGE_RELEASE and current_dir() in release_dirs


static func _parse_sequence(motion: StringName) -> Array[int]:
	var sequence: Array[int] = []
	for c in String(motion):
		if c >= "1" and c <= "9":
			sequence.append(int(c))
	return sequence


static func _without_diagonals(sequence: Array[int]) -> Array[int]:
	var out: Array[int] = []
	for d in sequence:
		if d != 1 and d != 3 and d != 7 and d != 9:
			out.append(d)
	return out


## Recorre el historial del tick más reciente al más antiguo buscando la
## secuencia al revés. Los ticks que no encajan se ignoran: da igual cuántos
## frames tarde el jugador entre paso y paso, mientras entren en la ventana.
func _match_sequence(sequence: Array[int], window: int) -> bool:
	var index := sequence.size() - 1
	var limit := mini(window, _filled)
	for age in limit:
		if dir_at(age) != sequence[index]:
			continue
		if index == sequence.size() - 1 and age > HEAD_WINDOW:
			return false  # el último paso es demasiado viejo
		if index == 0:
			return true
		index -= 1
	return false
