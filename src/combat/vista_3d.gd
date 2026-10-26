class_name Vista3D
extends Node3D
## Dibuja el combate en 3D: escenario, luces, cámara y los modelos de los
## luchadores que lo tengan. PRUEBA del paso a 3D.
##
## Regla de oro, la misma que los efectos: **solo mira**. El combate sigue
## siendo 2D en punto fijo (posiciones, cajas, estados); esto lee cada frame
## dónde está cada luchador y en qué fotograma de qué movimiento, y coloca el
## modelo y su animación. Si se quitara, el combate sería idéntico.
##
## El truco que hace que todo lo 2D (efectos, cajas de F1, sprites de quien no
## tenga modelo) caiga encima de lo 3D sin tocar nada: la cámara mira de
## frente al plano del combate. En un plano perpendicular a la mirada la
## perspectiva es una escala uniforme, así que con `metros_por_pixel` y la
## distancia se calcula el campo de visión que hace coincidir 1 px del mundo
## 2D con su punto del plano 3D. El fondo, que está más lejos, sí tiene
## perspectiva.
##
## Todo se renderiza a la resolución interna (640x360) y se escala entero: es
## 3D con píxel gordo, y casa con el HUD y los efectos de tinta.

const TINTA := Color("140c1c")

var arena: Node = null
var datos: StageData = null
var escala: float = 0.015
var distancia: float = 9.0

var camara: Camera3D = null
var luz: DirectionalLight3D = null
var _entorno: Environment = null
var _energia_luz: float = 1.0
var _oscuro: int = 0
## Por luchador: {modelo, reproductor, animaciones}
var _modelos: Array[Dictionary] = []
static var _contorno: StandardMaterial3D = null


func setup(arena_in: Node, datos_in: StageData) -> void:
	arena = arena_in
	datos = datos_in
	var m := datos.modo_3d
	escala = float(m.get("metros_por_pixel", 0.015))
	distancia = float(m.get("distancia_camara", 9.0))


func _ready() -> void:
	var m := datos.modo_3d
	_entorno = Environment.new()
	_entorno.background_mode = Environment.BG_COLOR
	_entorno.background_color = Color(String(m.get("fondo", "#1b2340")))
	var amb: Dictionary = m.get("ambiente", {})
	_entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_entorno.ambient_light_color = Color(String(amb.get("color", "#9aa6d6")))
	_entorno.ambient_light_energy = float(amb.get("energia", 0.55))
	_entorno.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var mundo := WorldEnvironment.new()
	mundo.environment = _entorno
	add_child(mundo)

	var l: Dictionary = m.get("luz", {})
	luz = DirectionalLight3D.new()
	luz.light_color = Color(String(l.get("color", "#ffffff")))
	_energia_luz = float(l.get("energia", 1.0))
	luz.light_energy = _energia_luz
	luz.rotation_degrees = Vector3(float(l.get("inclinacion", -50)), float(l.get("giro", -20)), 0)
	luz.shadow_enabled = true
	luz.shadow_normal_bias = 1.5
	luz.directional_shadow_max_distance = 40.0
	add_child(luz)

	var ruta := "res://stages/%s/%s" % [String(datos.id), String(m.get("escena", ""))]
	var escena: PackedScene = load(ruta)
	if escena != null:
		var fondo := escena.instantiate() as Node3D
		var origen: Array = m.get("origen", [0, 0, 0])
		fondo.position = -Vector3(float(origen[0]), float(origen[1]), float(origen[2]))
		add_child(fondo)
		_tinta(fondo, false)
		# El techo dejaría todo el interior a la sombra: el edificio no
		# proyecta sombras, solo los luchadores sobre el suelo.
		for nodo in fondo.find_children("*", "GeometryInstance3D", true, false):
			(nodo as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ocultar_lo_de_delante(fondo, float(m.get("ocultar_delante", 1000.0)))

	camara = Camera3D.new()
	camara.keep_aspect = Camera3D.KEEP_HEIGHT
	var media_alto := float(ProjectSettings.get_setting("display/window/size/viewport_height", 360)) * 0.5
	camara.fov = rad_to_deg(2.0 * atan(media_alto * escala / distancia))
	# Lo que queda entre la cámara y los luchadores (la fachada, la
	# cristalera) se recorta con el plano cercano: la cámara puede estar
	# "fuera" del edificio y ver el interior como un decorado abierto.
	camara.near = maxf(0.1, distancia - float(m.get("recorte_delante", distancia)))
	camara.far = 120.0
	add_child(camara)
	camara.make_current()

	for fighter: Fighter in arena.fighters:
		_montar_modelo(fighter)


func _montar_modelo(fighter: Fighter) -> void:
	var info := {}
	var cfg := fighter.stats.modelo_3d
	if not cfg.is_empty():
		var ruta := "res://characters/%s/%s" % [String(fighter.stats.id), String(cfg.get("escena", ""))]
		var escena: PackedScene = load(ruta)
		if escena != null:
			var modelo := escena.instantiate() as Node3D
			add_child(modelo)
			_tinta(modelo, true)
			info["modelo"] = modelo
			info["reproductor"] = modelo.find_child("AnimationPlayer", true, false)
			info["animaciones"] = cfg.get("animaciones", {})
			# El sprite 2D se apaga: ya lo dibuja el modelo.
			fighter.dibujar_sprite = false
	_modelos.append(info)


## Sombreado de tinta: luz en dos tonos (toon), sin brillos, filtro nearest y,
## en los personajes, contorno de tinta por casco invertido (una segunda
## pasada de la malla, inflada y con las caras de delante ocultas).
func _tinta(raiz: Node, contorno: bool) -> void:
	if _contorno == null:
		_contorno = StandardMaterial3D.new()
		_contorno.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_contorno.albedo_color = TINTA
		_contorno.cull_mode = BaseMaterial3D.CULL_FRONT
		_contorno.grow = true
		_contorno.grow_amount = 0.012
	for nodo in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := nodo as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var original := mi.get_active_material(i)
			if not (original is StandardMaterial3D):
				continue
			var mat := (original as StandardMaterial3D).duplicate() as StandardMaterial3D
			mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			mat.metallic = 0.0
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			if contorno:
				mat.rim_enabled = true
				mat.rim = 0.35
				mat.rim_tint = 0.6
				mat.next_pass = _contorno
			mi.set_surface_override_material(i, mat)


## Quita del decorado lo que queda entero por delante del plano del combate
## (más cerca de la cámara que `umbral`): pilares y cristalera que taparían a
## los luchadores. El suelo pasa por debajo de ellos y no cumple la condición.
func _ocultar_lo_de_delante(raiz: Node3D, umbral: float) -> void:
	for nodo in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := nodo as MeshInstance3D
		var caja := mi.global_transform * mi.get_aabb()
		if caja.position.z > umbral:
			mi.visible = false


## Oscurece el escenario mientras dura la congelación de un súper.
func oscurecer(ticks: int) -> void:
	_oscuro = maxi(_oscuro, ticks + 10)


func _process(_delta: float) -> void:
	if arena == null or arena.camera == null:
		return
	# La cámara 3D copia a la 2D (sacudida incluida).
	var c2: Vector2 = arena.camera.position
	camara.position = Vector3(c2.x * escala, -c2.y * escala, distancia)

	if _oscuro > 0:
		_oscuro -= 1
	var apagado := minf(1.0, float(_oscuro) / 8.0) * 0.75
	luz.light_energy = _energia_luz * (1.0 - apagado)
	_entorno.ambient_light_energy = float(datos.modo_3d.get("ambiente", {}).get("energia", 0.55)) * (1.0 - apagado)

	for i in mini(_modelos.size(), arena.fighters.size()):
		var info: Dictionary = _modelos[i]
		if not info.has("modelo"):
			continue
		var f: Fighter = arena.fighters[i]
		var modelo: Node3D = info["modelo"]
		modelo.position = Vector3(FP.to_px(f.pos_x) * escala, FP.to_px(f.pos_y) * escala, 0.0)
		# Mirar a la izquierda es un espejo, como el sprite: así el lado
		# rapado siempre da a cámara.
		modelo.scale = Vector3(float(f.facing), 1.0, 1.0)
		modelo.rotation = Vector3.ZERO
		if f.state == Fighter.State.KO:
			modelo.rotation.z = deg_to_rad(80.0) * float(f.facing)
		_animar(info, f)


## Qué animación y en qué instante. Los golpes se colocan en el fotograma
## exacto del movimiento (move_frame), así lo que se ve coincide con las cajas.
func _animar(info: Dictionary, f: Fighter) -> void:
	var rep: AnimationPlayer = info.get("reproductor")
	if rep == null:
		return
	var mapa: Dictionary = info["animaciones"]
	var tick := Engine.get_physics_frames()
	var clave := "idle"
	var t := -1.0
	match f.state:
		Fighter.State.ATTACK:
			if f.current_move != null and mapa.has(String(f.current_move.id)):
				clave = String(f.current_move.id)
				t = float(f.move_frame) / 60.0
		Fighter.State.WALK_F:
			clave = "walk_f"
		Fighter.State.WALK_B:
			clave = "walk_b"
	var nombre := String(mapa.get(clave, mapa.get("idle", "")))
	var al_reves := nombre.begins_with("-")
	nombre = nombre.trim_prefix("-")
	if not rep.has_animation(nombre):
		return
	var duracion := rep.get_animation(nombre).length
	if t < 0.0:
		t = fmod(float(tick) / 60.0, maxf(duracion, 0.001))
	if al_reves:
		t = duracion - t
	if rep.current_animation != nombre:
		rep.play(nombre)
		rep.speed_scale = 0.0
	rep.seek(clampf(t, 0.0, duracion), true)
