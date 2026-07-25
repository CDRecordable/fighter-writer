class_name Training
extends RefCounted
## Modo entrenamiento: mide el combate en vez de adivinarlo.
##
## Existe por una razón muy concreta del plan. El hito de la Fase 1 es *"dos
## rectángulos se pegan y ES DIVERTIDO"*, y el plan pide además 2-3 combos por
## enlace natural de frames. Ninguna de las dos cosas se puede juzgar a ojo: si
## un golpe deja +4 o -2 no se ve, se mide. Y si dos golpes enlazan de verdad o
## el rival simplemente no reaccionó, tampoco.
##
## Solo observa. No toca la simulación: si esta clase desapareciera, el combate
## se comportaría exactamente igual.

## Ticks sin golpear tras los cuales se considera cerrado el combo.
const COMBO_TIMEOUT := 40

var enabled: bool = false

## --- Combo -------------------------------------------------------------------
var combo_hits: int = 0
var combo_damage: int = 0
## Un combo es REAL si el rival no tuvo ni un frame para actuar entre golpe y
## golpe. Si tuvo alguno, es que aceptó los golpes, no que no pudiera evitarlos.
var combo_true: bool = true
var last_combo_hits: int = 0
var last_combo_damage: int = 0
var last_combo_true: bool = false
var _combo_idle: int = 0
var _defender: Fighter = null

## --- Ventaja de frames -------------------------------------------------------
## Positiva = el atacante recupera antes y le toca a él.
var advantage: int = 0
var advantage_valid: bool = false
var _measuring: bool = false
var _attacker: Fighter = null
var _attacker_free: int = -1
var _defender_free: int = -1
var _elapsed: int = 0

## --- Último golpe ------------------------------------------------------------
var last_move_name: String = "—"
var last_move_timing: String = ""
var last_blocked: bool = false


func reset() -> void:
	combo_hits = 0
	combo_damage = 0
	combo_true = true
	_combo_idle = 0
	_measuring = false
	advantage_valid = false
	_defender = null
	_attacker = null


## Lo llama la arena cuando un golpe conecta o se bloquea.
func on_hit(attacker: Fighter, defender: Fighter, hit: HitProperties, blocked: bool) -> void:
	last_blocked = blocked
	if hit is MoveData:
		var move: MoveData = hit
		last_move_name = move.display_name
		last_move_timing = "%d / %d / %d" % [move.startup, move.active, move.recovery]
	else:
		last_move_name = "proyectil"
		last_move_timing = ""

	# Cambiar de víctima cierra el combo anterior.
	if _defender != defender:
		_close_combo()
		_defender = defender
		combo_true = true

	if combo_hits == 0:
		combo_true = true
	combo_hits += 1
	combo_damage += 0 if blocked else hit.damage
	_combo_idle = 0

	# Empieza a medirse la ventaja desde este golpe.
	_attacker = attacker
	_measuring = true
	_attacker_free = -1
	_defender_free = -1
	_elapsed = 0
	advantage_valid = false


## Un tick de observación. Se llama después de simular a los dos luchadores.
func tick(fighters: Array[Fighter]) -> void:
	_tick_combo(fighters)
	_tick_advantage()


func _tick_combo(fighters: Array[Fighter]) -> void:
	if combo_hits == 0:
		return
	_combo_idle += 1
	if _defender != null and _defender.is_actionable():
		# El rival ha recuperado: si le vuelven a dar a partir de aquí, ya no
		# es el mismo combo. Y si le dan sin que él haya hecho nada, es que
		# aceptó el golpe — el combo deja de ser "real".
		combo_true = false
	if _combo_idle >= COMBO_TIMEOUT:
		_close_combo()
	# Un KO también cierra el combo, aunque el contador siga corriendo.
	for fighter in fighters:
		if fighter.state == Fighter.State.KO:
			_close_combo()
			return


func _close_combo() -> void:
	if combo_hits > 0:
		last_combo_hits = combo_hits
		last_combo_damage = combo_damage
		last_combo_true = combo_true and combo_hits > 1
	combo_hits = 0
	combo_damage = 0
	combo_true = true
	_combo_idle = 0


## La ventaja es la diferencia entre cuándo puede actuar cada uno. Se mide
## esperando a que los DOS estén libres: hasta entonces no hay número que dar.
func _tick_advantage() -> void:
	if not _measuring:
		return
	_elapsed += 1
	if _attacker != null and _attacker_free < 0 and _attacker.is_actionable():
		_attacker_free = _elapsed
	if _defender != null and _defender_free < 0 and _defender.is_actionable():
		_defender_free = _elapsed
	if _attacker_free >= 0 and _defender_free >= 0:
		advantage = _defender_free - _attacker_free
		advantage_valid = true
		_measuring = false
	elif _elapsed > 240:
		# Alguien se quedó derribado o KO: no hay ventaja que medir.
		_measuring = false


func distance_px(fighters: Array[Fighter]) -> int:
	if fighters.size() < 2:
		return 0
	return absi(FP.floor_px(fighters[1].pos_x - fighters[0].pos_x))


func combo_line() -> String:
	if combo_hits > 0:
		var etiqueta := "en curso" if combo_hits == 1 else ("REAL" if combo_true else "roto")
		return "%d golpe(s) · %d daño · %s" % [combo_hits, combo_damage, etiqueta]
	if last_combo_hits > 0:
		var etiqueta := "REAL" if last_combo_true else "no enlaza"
		return "último: %d · %d daño · %s" % [last_combo_hits, last_combo_damage, etiqueta]
	return "—"


func advantage_line() -> String:
	if not advantage_valid:
		return "midiendo…" if _measuring else "—"
	var signo := "+" if advantage >= 0 else ""
	var quien := "a favor del atacante" if advantage > 0 else (
		"a favor del que recibe" if advantage < 0 else "neutro"
	)
	return "%s%d  (%s)" % [signo, advantage, quien]
