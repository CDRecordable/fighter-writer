extends SceneTree
## Genera la hoja de sprites provisional de un personaje:
##
##   godot --headless --path . --script res://tools/generar_placeholder.gd
##
## No dibuja poses inventadas: **deriva cada celda de las cajas del propio
## personaje**. La celda de un puñetazo enseña el brazo exactamente donde está
## el hitbox, y la de un barrido, la pierna donde está el barrido de verdad.
##
## Eso lo hace útil de dos maneras: la capa de sprites queda probada de punta a
## punta con arte que no miente sobre el motor, y el artista recibe una
## referencia exacta de qué silueta tiene que cubrir cada celda para que el
## golpe sea legible. Cuando entregue su PNG, se sustituye el archivo y ya.

## Se generan las hojas de TODOS los personajes de characters/. Añadir a Cela
## no debe obligar a tocar esta herramienta: la carpeta manda, como en todo lo
## demás del proyecto.

const FONDO := Color(0, 0, 0, 0)
## El cuerpo toma el color del propio personaje (`debug_color`), así dos
## luchadores no salen idénticos y se distingue quién es quién sin sprites.
## Verde azulado a propósito: las chispas de impacto son amarillas, y si el
## miembro que golpea también lo fuera no se vería el efecto encima.
const COLOR_GOLPE := Color(0.33, 0.70, 0.70)
const COLOR_CABEZA := Color(0.98, 0.86, 0.78)
const COLOR_FRENTE := Color(0.15, 0.10, 0.18)

## Qué postura tiene cada animación de estado, para elegir la caja del cuerpo.
const POSTURA_AGACHADA := [&"crouch", &"blockstun_low"]


class Celda:
	var cuerpo: BoxData = null
	var miembros: Array[BoxData] = []
	var golpes: Array[BoxData] = []
	var variante: int = 0
	var etiqueta: String = ""


var _finished := false


func _process(_delta: float) -> bool:
	if _finished:
		return true
	_finished = true

	var fallos := 0
	for character_id in CharacterLoader.list_ids():
		if not _generar(character_id):
			fallos += 1
	quit(1 if fallos > 0 else 0)
	return true


func _generar(character_id: String) -> bool:
	var stats := CharacterLoader.load_stats(character_id)
	if stats == null:
		printerr("No se pudo cargar el personaje ", character_id)
		return false
	if stats.sprites == null or stats.animations.is_empty():
		printerr("%s no declara hoja de sprites ni animaciones." % character_id)
		return false

	var celdas := _recoger_celdas(stats)
	if celdas.is_empty():
		printerr("%s no declara ninguna animación." % character_id)
		return false

	var imagen := _dibujar(stats, celdas)
	# El nombre sale del propio JSON: si el personaje declara otra hoja, es esa
	# la que hay que generar, no una con nombre inventado aquí.
	var destino := "res://characters/%s/%s" % [character_id, stats.sprites.sheet_path]
	var error := imagen.save_png(ProjectSettings.globalize_path(destino))
	if error != OK:
		printerr("No se pudo guardar ", destino, " (error ", error, ")")
		return false

	print("Hoja generada: %s  (%d celdas, %dx%d px)" % [
		destino, celdas.size(), imagen.get_width(), imagen.get_height(),
	])
	return true


# --- Qué va en cada celda ----------------------------------------------------

func _recoger_celdas(stats: FighterStats) -> Dictionary:
	var celdas := {}

	for clave: StringName in stats.animations.keys():
		var anim: AnimationData = stats.animations[clave]
		var agachado := clave in POSTURA_AGACHADA
		var cuerpo := stats.crouch_hurtbox if agachado else stats.stand_hurtbox
		for i in anim.frames.size():
			var celda := Celda.new()
			celda.cuerpo = cuerpo
			# Las animaciones en bucle necesitan que sus celdas se distingan:
			# si no, no hay forma de ver si la animación corre o está parada.
			celda.variante = i
			celda.etiqueta = String(clave)
			_asignar(celdas, anim.frames[i], celda)

	for move_id: StringName in stats.moves.keys():
		var move: MoveData = stats.moves[move_id]
		if move.anim == null or move.anim.is_empty():
			continue
		var cuerpo := stats.crouch_hurtbox if move.stance == MoveData.Stance.CROUCH else stats.stand_hurtbox
		for i in move.anim.frames.size():
			var rango := move.anim.tick_range(i)
			var tick := clampi((rango[0] + rango[1]) / 2, 0, maxi(0, move.total_frames() - 1))
			var datos := move.frame_at(tick)
			var celda := Celda.new()
			celda.cuerpo = cuerpo
			celda.etiqueta = "%s[%d]" % [move_id, i]
			if datos != null:
				celda.miembros = datos.hurtboxes.duplicate()
				celda.golpes = datos.hitboxes.duplicate()
			_asignar(celdas, move.anim.frames[i], celda)

	return celdas


func _asignar(celdas: Dictionary, indice: int, celda: Celda) -> void:
	if celdas.has(indice):
		var previa: Celda = celdas[indice]
		push_warning("La celda %d la reclaman '%s' y '%s'. Revisa los índices." % [
			indice, previa.etiqueta, celda.etiqueta,
		])
		return
	celdas[indice] = celda


# --- Dibujo ------------------------------------------------------------------

func _dibujar(stats: FighterStats, celdas: Dictionary) -> Image:
	var conjunto := stats.sprites
	var maximo := 0
	for indice: int in celdas.keys():
		maximo = maxi(maximo, indice)
	var filas := int(ceil(float(maximo + 1) / float(conjunto.columns)))

	var imagen := Image.create_empty(
		conjunto.columns * conjunto.cell_width,
		filas * conjunto.cell_height,
		false,
		Image.FORMAT_RGBA8
	)
	imagen.fill(FONDO)

	for indice: int in celdas.keys():
		_dibujar_celda(imagen, conjunto, indice, celdas[indice], stats.debug_color)
	return imagen


func _dibujar_celda(
	imagen: Image, conjunto: SpriteSet, indice: int, celda: Celda, color_cuerpo: Color
) -> void:
	var origen := Vector2i(
		(indice % conjunto.columns) * conjunto.cell_width,
		(indice / conjunto.columns) * conjunto.cell_height
	)
	var limite := Rect2i(origen, Vector2i(conjunto.cell_width, conjunto.cell_height))

	# Balanceo de 1 px según la variante: es lo que hace visible que un idle o
	# un ciclo de andar están animados y no congelados.
	var balanceo := 0
	if celda.variante > 0:
		balanceo = [0, -1, 0, 1][celda.variante % 4]

	var cuerpo := celda.cuerpo
	if cuerpo != null:
		var rect := _rect_de(conjunto, origen, cuerpo, balanceo)
		_rellenar(imagen, rect, limite, color_cuerpo)
		# Cabeza y franja frontal: sin ellas no se distingue hacia dónde mira.
		var cabeza := Rect2i(
			rect.position.x + rect.size.x / 4,
			rect.position.y + balanceo,
			maxi(2, rect.size.x / 2),
			maxi(2, rect.size.x / 2)
		)
		_rellenar(imagen, cabeza, limite, COLOR_CABEZA)
		var frente := Rect2i(
			rect.position.x + rect.size.x - 3, rect.position.y, 3, rect.size.y
		)
		_rellenar(imagen, frente, limite, COLOR_FRENTE)

	for miembro in celda.miembros:
		# La caja del cuerpo ya está pintada; aquí interesan los brazos y
		# piernas que el movimiento saca fuera de la silueta.
		if cuerpo != null and miembro.x == cuerpo.x and miembro.w == cuerpo.w:
			continue
		_rellenar(
			imagen, _rect_de(conjunto, origen, miembro, balanceo), limite,
			color_cuerpo.lightened(0.35)
		)

	for golpe in celda.golpes:
		_rellenar(imagen, _rect_de(conjunto, origen, golpe, balanceo), limite, COLOR_GOLPE)


## Pasa una BoxData (x hacia delante, y hacia arriba desde los pies) a píxeles
## dentro de la celda, usando el pivote como origen.
func _rect_de(conjunto: SpriteSet, origen: Vector2i, caja: BoxData, balanceo: int) -> Rect2i:
	return Rect2i(
		origen.x + conjunto.pivot_x + caja.x,
		origen.y + conjunto.pivot_y - (caja.y + caja.h) + balanceo,
		maxi(1, caja.w),
		maxi(1, caja.h)
	)


func _rellenar(imagen: Image, rect: Rect2i, limite: Rect2i, color: Color) -> void:
	var recortado := rect.intersection(limite)
	if recortado.size.x <= 0 or recortado.size.y <= 0:
		return
	imagen.fill_rect(recortado, color)
