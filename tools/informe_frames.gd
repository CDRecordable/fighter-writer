extends SceneTree
## Mide todos los golpes de un personaje y dice qué enlaza con qué:
##
##   godot --headless --path . --script res://tools/informe_frames.gd
##
## El plan pide 2-3 combos por enlace natural de frames (PLAN.md §3) y hasta
## ahora nadie sabía si los números actuales permiten alguno. Esto lo resuelve
## sin tener que jugar: ejecuta cada golpe contra un muñeco, mide la ventaja
## real que deja, y aplica la regla clásica — **X enlaza con Y si la ventaja al
## golpear de X es mayor o igual que el startup de Y**.
##
## No sustituye a jugar (que un combo sea posible no lo hace divertido), pero
## convierte "creo que no enlaza nada" en una tabla.

const ARENA := preload("res://scenes/combat_arena.tscn")
const PERSONAJE := "cristina_morales"
const CERCA := 20.0
## Al bloquear se mantiene atrás, o sea que el muñeco ANDA hacia atrás y los
## golpes cortos dejan de alcanzarle. Se empieza más pegado para medir el
## bloqueo, que si no salen "no llega" que son de la prueba, no del golpe.
const CERCA_BLOQUEO := 12.0

const NORMALES := [
	{ "id": &"stand_lp", "agachado": false, "boton": FighterInput.BTN_LP },
	{ "id": &"stand_lk", "agachado": false, "boton": FighterInput.BTN_LK },
	{ "id": &"stand_hp", "agachado": false, "boton": FighterInput.BTN_HP },
	{ "id": &"stand_hk", "agachado": false, "boton": FighterInput.BTN_HK },
	{ "id": &"crouch_lp", "agachado": true, "boton": FighterInput.BTN_LP },
	{ "id": &"crouch_hk", "agachado": true, "boton": FighterInput.BTN_HK },
]


class Guion extends Agents.Agent:
	var snapshot := FighterInput.new()

	func poll(_f: Node) -> FighterInput:
		return snapshot


var _finished := false


func _process(_delta: float) -> bool:
	if _finished:
		return true
	_finished = true

	var stats := CharacterLoader.load_stats(PERSONAJE)
	if stats == null:
		printerr("No se pudo cargar ", PERSONAJE)
		quit(1)
		return true

	var filas := []
	for entrada: Dictionary in NORMALES:
		var move: MoveData = stats.get_move(entrada["id"])
		if move == null:
			continue
		filas.append({
			"move": move,
			"derriba": move.knockdown,
			"al_golpear": _medir(entrada, move, false),
			"al_bloquear": _medir(entrada, move, true),
		})

	_imprimir_tabla(filas)
	_imprimir_enlaces(filas)
	quit(0)
	return true


## Ejecuta el golpe contra el muñeco y devuelve la ventaja medida, o null si no
## llegó a conectar.
func _medir(entrada: Dictionary, move: MoveData, bloqueando: bool) -> Variant:
	var arena: CombatArena = ARENA.instantiate()
	root.add_child(arena)
	while arena.round_state != CombatArena.RoundState.FIGHTING:
		arena.tick()

	var atacante: Fighter = arena.fighters[0]
	var defensor: Fighter = arena.fighters[1]
	var guion_a := Guion.new()
	var guion_d := Guion.new()
	atacante.agent = guion_a
	defensor.agent = guion_d
	var separacion := CERCA_BLOQUEO if bloqueando else CERCA
	atacante.pos_x = FP.from_px(-separacion)
	defensor.pos_x = FP.from_px(separacion)
	if bloqueando:
		guion_d.snapshot.dir_x = -defensor.facing
		# Un barrido hay que bloquearlo AGACHADO. Bloqueando de pie no se
		# bloquea: se encaja, y entonces el número medido no es el del bloqueo.
		if move.height == HitProperties.Height.LOW:
			guion_d.snapshot.dir_y = -1

	guion_a.snapshot.dir_y = -1 if bool(entrada["agachado"]) else 0
	guion_a.snapshot.buttons = int(entrada["boton"])
	guion_a.snapshot.pressed = int(entrada["boton"])

	var resultado: Variant = null
	for i in 200:
		arena.tick()
		guion_a.snapshot.pressed = 0
		# Un solo golpe: en cuanto arranca, se suelta el botón.
		if atacante.is_attacking():
			guion_a.snapshot.buttons = 0
		if arena.training.advantage_valid:
			resultado = arena.training.advantage
			break
	# Si se pedía bloqueo y el defensor perdió vida, es que NO bloqueó: el
	# número medido sería el de un impacto disfrazado de bloqueo.
	if bloqueando and defensor.health < defensor.stats.max_health:
		resultado = null
	arena.free()
	return resultado


func _imprimir_tabla(filas: Array) -> void:
	print("")
	print("VENTAJA DE FRAMES — %s" % PERSONAJE)
	print("(positivo = te toca a ti antes que al rival)")
	print("")
	print("  %-16s %-12s %8s %10s" % ["golpe", "s/a/r", "al dar", "bloqueado"])
	print("  " + "-".repeat(50))
	for fila: Dictionary in filas:
		var move: MoveData = fila["move"]
		# Tras un derribo no hay "ventaja" que valga: el rival está en el
		# suelo. Ahí lo que se mide es la presión al levantarse, que es otra
		# cosa y no se lee con este número.
		var al_dar: String = "derribo" if bool(fila["derriba"]) else _fmt(fila["al_golpear"])
		print("  %-16s %-12s %8s %10s" % [
			move.display_name,
			"%d/%d/%d" % [move.startup, move.active, move.recovery],
			al_dar,
			_fmt(fila["al_bloquear"]),
		])


## La regla clásica: X enlaza con Y si la ventaja al golpear de X llega para
## que Y salga antes de que el rival recupere.
func _imprimir_enlaces(filas: Array) -> void:
	print("")
	print("ENLACES POSIBLES (ventaja al dar de X  >=  startup de Y)")
	print("")
	var encontrados := 0
	for a: Dictionary in filas:
		if a["al_golpear"] == null or bool(a["derriba"]):
			continue
		var ventaja: int = a["al_golpear"]
		for b: Dictionary in filas:
			var siguiente: MoveData = b["move"]
			if ventaja >= siguiente.startup:
				print("  %s  ->  %s   (+%d, sale en %d)" % [
					(a["move"] as MoveData).display_name,
					siguiente.display_name,
					ventaja,
					siguiente.startup,
				])
				encontrados += 1
	if encontrados == 0:
		print("  NINGUNO. Con los frame data actuales no enlaza nada.")
		print("  El plan pide 2-3 combos por personaje (PLAN.md §3): hay que")
		print("  subir el hitstun de los golpes ligeros o recortar su recuperación.")
	else:
		print("")
		print("  %d enlace(s). Ojo: que sea posible no lo hace divertido." % encontrados)


func _fmt(valor: Variant) -> String:
	if valor == null:
		return "no llega"
	var v: int = valor
	return ("+%d" % v) if v >= 0 else str(v)
