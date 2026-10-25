class_name FondoProcedural
extends RefCounted
## Cielo, sol y mar de un escenario, generados en código a partir del
## stage.json en vez de pintados.
##
## Por qué en código: son las capas más grandes y las más difíciles de
## generar con IA sin que se note (un cielo generado no repite sin costura, y
## en espejo sale simétrico; un mar de tiles es lo más ruidoso de la pantalla).
## En cambio un degradado tramado con un sol y un mar de destellos son pixel art
## clásico de recreativa, salen exactos en la paleta del escenario, y son
## gratis. El arte generado se reserva para lo que tiene forma: barco, mástil,
## nubes, flota.
##
## Todo con semilla fija: el mismo escenario sale siempre igual.

## Matriz de Bayer 4x4 para el tramado ordenado entre bandas de color.
const BAYER := [
	[0, 8, 2, 10],
	[12, 4, 14, 6],
	[3, 11, 1, 9],
	[15, 7, 13, 5],
]


## Color de la banda `y` de un degradado de `n` filas por paradas, con
## tramado: entre dos paradas, el píxel elige una u otra según la matriz.
static func color_tramado(paradas: Array[Color], y: int, alto: int, x: int) -> Color:
	if paradas.size() == 1:
		return paradas[0]
	var v := float(y) / float(maxi(1, alto - 1)) * float(paradas.size() - 1)
	var base := mini(floori(v), paradas.size() - 1)
	var resto := v - float(base)
	var nivel := base
	if resto * 16.0 > float(BAYER[y % 4][x % 4]) + 0.5:
		nivel = mini(base + 1, paradas.size() - 1)
	return paradas[nivel]


## Cielo: degradado por paradas (de arriba al horizonte), estrellas en la
## parte oscura y, si el escenario lo pide, el sol medio hundido en el
## horizonte. Devuelve [textura, estrellas que titilan].
static func cielo(data: StageData, ancho: int) -> Array:
	var alto := data.sky_to_y - data.sky_from_y
	var imagen := Image.create_empty(ancho, alto, false, Image.FORMAT_RGBA8)
	for y in alto:
		for x in ancho:
			imagen.set_pixel(x, y, color_tramado(data.sky_stops, y, alto, x))

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(data.id))
	var titilantes: Array[Vector3i] = []
	var tenue := data.sky_top_color.lerp(Color(0.75, 0.80, 1.0), 0.35)
	var brillante := Color(0.85, 0.88, 1.0)
	for i in data.sky_stars:
		# Solo en la mitad oscura de arriba, y más cuanto más arriba: cerca
		# del horizonte del atardecer no se ve ninguna.
		var y := int(float(alto) * 0.55 * pow(rng.randf(), 1.6))
		var x := rng.randi_range(1, ancho - 2)
		if rng.randf() < 0.15:
			imagen.set_pixel(x, y + 1, brillante)
			for d: Vector2i in [Vector2i(-1, 1), Vector2i(1, 1), Vector2i(0, 0), Vector2i(0, 2)]:
				imagen.set_pixel(x + d.x, y + d.y, tenue)
		else:
			imagen.set_pixel(x, y, tenue if rng.randf() < 0.7 else brillante)
			if titilantes.size() < 10 and rng.randf() < 0.3:
				titilantes.append(Vector3i(x, y, rng.randi_range(0, 239)))

	if not data.sun.is_empty():
		_sol(imagen, data.sun, x_del_sol(data, ancho), alto)
	return [ImageTexture.create_from_image(imagen), titilantes]


## El sol: disco con anillos de color, halo tramado y franjas horizontales que
## lo cortan cerca del horizonte (el atardecer de recreativa). El centro cae
## en la última fila del cielo, así que el mar tapa la mitad de abajo.
static func _sol(imagen: Image, sol: Dictionary, cx: int, alto: int) -> void:
	var radio := int(sol.get("radius", 24))
	var colores: Array[Color] = []
	for c: Variant in sol.get("colors", ["#fff4c8", "#ffe08a", "#ffb45a"]):
		colores.append(Color(String(c)))
	var halo := Color(String(sol.get("glow", "#f08a4b")))
	var cy := alto
	var r_halo := radius_halo(radio)
	for y in range(maxi(0, cy - r_halo), alto):
		for x in range(cx - r_halo, cx + r_halo + 1):
			if x < 0 or x >= imagen.get_width():
				continue
			var d := Vector2(x - cx, y - cy).length()
			if d <= float(radio):
				# Anillos de dentro afuera; franjas de cielo que lo cortan en
				# el tercio de abajo, cada vez más gruesas hacia el horizonte.
				var franja := cy - y
				var hueco := franja < radio / 2 and (franja % 6) < (3 - franja / 6)
				if hueco:
					continue
				var anillo := clampi(int(d / float(radio) * float(colores.size())), 0, colores.size() - 1)
				imagen.set_pixel(x, y, colores[anillo])
			elif d <= float(r_halo):
				# Halo tramado: más denso pegado al disco.
				var t := (d - float(radio)) / float(r_halo - radio)
				if t * 16.0 < float(BAYER[y % 4][x % 4]) * 0.9:
					imagen.set_pixel(x, y, imagen.get_pixel(x, y).lerp(halo, 0.45))


## Columna de la textura donde cae el sol. La capa repetida pone la x 0 de
## la textura en la x 0 del mundo, así que "x" del stage.json es coordenada
## de mundo (con la cámara en el centro), envuelta al ancho de la textura.
static func x_del_sol(data: StageData, ancho: int) -> int:
	return posmod(int(data.sun.get("x", 0)), ancho)


static func radius_halo(radio: int) -> int:
	return radio + radio / 2 + 4


## Mar: bandas de color del horizonte hacia la orilla y destellos cortos que
## se encienden y apagan. Bajo el sol, un reguero de destellos dorados que se
## abre hacia el espectador. Sale como tira de fotogramas para el Stage.
static func mar(data: StageData, ancho: int) -> StageData.Layer:
	var mar_d := data.sea
	var alto := int(mar_d.get("to_y", 110)) - int(mar_d.get("from_y", 40))
	var frames := int(mar_d.get("frames", 8))
	var paradas: Array[Color] = []
	for c: Variant in mar_d.get("stops", ["#2e2257", "#18305a"]):
		paradas.append(Color(String(c)))
	var luces: Array[Color] = []
	for c: Variant in mar_d.get("highlights", ["#3f7a99", "#2f5f86"]):
		luces.append(Color(String(c)))
	var dorados: Array[Color] = []
	for c: Variant in mar_d.get("glitter", ["#ffe08a", "#ffb45a", "#f08a4b"]):
		dorados.append(Color(String(c)))
	var linea := Color(String(mar_d.get("horizon", "#b44a63")))
	var sol_x := x_del_sol(data, ancho)

	var base := Image.create_empty(ancho, alto, false, Image.FORMAT_RGBA8)
	for y in alto:
		for x in ancho:
			base.set_pixel(x, y, color_tramado(paradas, y, alto, x))
	for x in ancho:
		base.set_pixel(x, 0, linea)

	# Destellos: cada uno con su fila, su sitio, su largo y su fase. Más
	# cortos y más juntos cerca del horizonte (la perspectiva los aplasta).
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(data.id)) + 7
	var destellos: Array[Dictionary] = []
	for y in range(2, alto):
		var lejania := 1.0 - float(y) / float(alto)  # 1 en el horizonte
		var por_fila := int(ancho / lerpf(70.0, 26.0, lejania))
		for i in por_fila:
			destellos.append({
				"x": rng.randi_range(0, ancho - 1), "y": y,
				"largo": rng.randi_range(1, 2 + int(7.0 * (1.0 - lejania))),
				"fase": rng.randi_range(0, frames - 1),
				"vida": rng.randi_range(2, 4),
				"luz": rng.randi_range(0, luces.size() - 1),
			})
		# Reguero del sol: un cono que se abre hacia abajo.
		var media_cono := 4.0 + float(y) * 0.9
		for i in int(media_cono / 5.0) + 1:
			destellos.append({
				"x": sol_x + rng.randi_range(-int(media_cono), int(media_cono)), "y": y,
				"largo": rng.randi_range(1, 3 + y / 12),
				"fase": rng.randi_range(0, frames - 1),
				"vida": rng.randi_range(3, 5),
				"oro": rng.randi_range(0, dorados.size() - 1),
			})

	var tira := Image.create_empty(ancho * frames, alto, false, Image.FORMAT_RGBA8)
	for f in frames:
		tira.blit_rect(base, Rect2i(0, 0, ancho, alto), Vector2i(f * ancho, 0))
		for d in destellos:
			var edad := posmod(f - int(d["fase"]), frames)
			if edad >= int(d["vida"]):
				continue
			var color: Color = dorados[int(d["oro"])] if d.has("oro") else luces[int(d["luz"])]
			for k in int(d["largo"]):
				var x := posmod(int(d["x"]) + k, ancho)
				tira.set_pixel(f * ancho + x, int(d["y"]), color)

	var capa := StageData.Layer.new()
	capa.texture = ImageTexture.create_from_image(tira)
	capa.frames = frames
	capa.hold = int(mar_d.get("hold", 9))
	capa.parallax = data.sky_parallax
	capa.y = int(mar_d.get("from_y", 40))
	capa.repeat_x = true
	return capa
