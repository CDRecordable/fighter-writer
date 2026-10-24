class_name Effects
extends Node2D
## Salpicaduras de tinta, destellos y polvo.
##
## Regla que no se puede romper: **los efectos no tocan la simulación**. Viven
## fuera del punto fijo, corren con el reloj de render y usan floats y azar sin
## problema, porque nada de lo que pasa aquí cambia una posición, un daño ni un
## frame. Si alguna vez un efecto necesitara influir en el combate, deja de ser
## un efecto y se va a `fighter.gd` con enteros.
##
## El lenguaje visual es la tinta, que es de lo que va el juego:
##   golpe    → salpicadura de tinta china con puntas y destello de papel
##   bloqueo  → tinta azul, la misma de la barra de Tinta, sin destello
##   súper    → el fondo se apaga, brota una mancha enorme y vuelan hojas
## La tinta es casi negra con un filo lila: sobre el mar oscuro se lee por el
## filo y el destello, y no se confunde con sangre (que es lo que parecía en
## la primera prueba, con tinta roja).
## Todo se dibuja con formas a píxel entero (círculos sin antialiasing y
## rectángulos de 1 px), sin texturas: no dependen de ningún asset ni de la
## licencia de nadie, y quedan en la misma rejilla que los sprites.
##
## No usa GPUParticles2D a propósito: son pocas partículas, tienen que caer en
## píxeles enteros y el renderer Compatibility no tiene estelas.

const GRAVEDAD := 300.0

enum Kind { GOTA, POLVO, PAPEL }

## Paletas de tinta: [cuerpo, brillo]. El brillo va arriba a la izquierda de
## cada mancha; es lo que hace que una mancha oscura se lea sobre el mar.
const TINTA_CHINA := [Color("1a0f2b"), Color("b9a3ff")]
const TINTA_AZUL := [Color("2e3bb8"), Color("9fb0ff")]
const TINTA_NEGRA := [Color("120a1c"), Color("6c5a9c")]
const PAPEL := Color("fff4dc")


## Una salpicadura: un racimo de círculos que crece de golpe, aguanta un
## instante y se encoge. Las posiciones se sortean al nacer, nunca después.
class Mancha:
	var position := Vector2.ZERO
	var paleta: Array = []
	var gotas: Array[Vector3] = []  # x, y, radio final
	## Puntas de la salpicadura: ángulo (rad), largo (px), grosor inicial.
	var puntas: Array[Vector3] = []
	var edad: float = 0.0
	var crecer: float = 0.035
	var aguantar: float = 0.08
	var encoger: float = 0.16
	var destello: float = 0.0  # radio del destello de papel; 0 = sin destello
	## Detrás de los luchadores en vez de delante (la mancha del súper: es un
	## halo alrededor de quien lo lanza, no algo que lo tape).
	var detras: bool = false

	func total() -> float:
		return crecer + aguantar + encoger

	## Escala del radio en este instante: 0 → 1 rápido, se queda, → 0.
	func escala() -> float:
		if edad < crecer:
			return edad / crecer
		if edad < crecer + aguantar:
			return 1.0
		return clampf(1.0 - (edad - crecer - aguantar) / encoger, 0.0, 1.0)


class Particle:
	var kind: int = Kind.GOTA
	var position := Vector2.ZERO
	var velocity := Vector2.ZERO
	var life: float = 0.0
	var total_life: float = 0.0
	var size: float = 2.0
	var color := Color.WHITE
	var brillo := Color.WHITE


var _particles: Array[Particle] = []
var _manchas: Array[Mancha] = []
var _rng := RandomNumberGenerator.new()
## Capa para lo que va detrás de los luchadores pero delante del escenario.
var _detras: Node2D = null


func _ready() -> void:
	# Delante de los luchadores: una salpicadura detrás del cuerpo no se ve.
	z_index = 50
	_rng.randomize()
	_detras = Node2D.new()
	_detras.name = "Detras"
	# Relativo al padre: 50 - 60 = -10, entre el escenario (-100) y los
	# luchadores (0).
	_detras.z_index = -60
	add_child(_detras)
	_detras.draw.connect(_draw_detras)


func _process(delta: float) -> void:
	if _particles.is_empty() and _manchas.is_empty():
		return
	var vivas: Array[Mancha] = []
	for m in _manchas:
		m.edad += delta
		if m.edad < m.total():
			vivas.append(m)
	_manchas = vivas

	var survivors: Array[Particle] = []
	for p in _particles:
		p.life -= delta
		if p.life <= 0.0:
			continue
		p.position += p.velocity * delta
		p.velocity.y += GRAVEDAD * delta * (0.35 if p.kind == Kind.PAPEL else 1.0)
		p.velocity.x *= 0.96 if p.kind == Kind.PAPEL else 0.99
		survivors.append(p)
	_particles = survivors
	queue_redraw()
	_detras.queue_redraw()


## Impacto limpio: mancha roja en el contacto, destello de papel y gotas que
## salen en la dirección del golpe y caen.
func hit(at: Vector2, direction: int, strength: float = 1.0) -> void:
	var m := _mancha(at, direction, TINTA_CHINA, 2.0 + 2.0 * strength, 3 + int(2.0 * strength))
	_puntas(m, direction, 5 + int(3.0 * strength), 8.0 + 8.0 * strength)
	m.destello = 8.0 + 6.0 * strength
	_salpicar(at, direction, TINTA_CHINA, int(6.0 + 6.0 * strength), 80.0, 220.0 * (0.6 + strength * 0.5))


## Bloqueo: mancha azul pequeña, sin destello, y gotas hacia arriba. Tiene que
## leerse distinto de un impacto de un vistazo, sin mirar la barra de vida.
func block(at: Vector2, direction: int) -> void:
	var m := _mancha(at, direction, TINTA_AZUL, 2.0, 2)
	_puntas(m, direction, 4, 6.0)
	m.aguantar = 0.03
	for i in 6:
		var p := _gota(at, TINTA_AZUL)
		p.velocity = Vector2(_rng.randf_range(-0.3, 1.0) * direction * 70.0, _rng.randf_range(-150.0, -60.0))
		_particles.append(p)


## Arranque de un súper: mancha negra grande alrededor de quien lo lanza y
## hojas de papel que salen volando. El oscurecimiento del fondo lo pone el
## escenario (Stage.oscurecer), que está detrás de los luchadores.
func super_inicio(at: Vector2, direction: int) -> void:
	var m := _mancha(at, direction, TINTA_NEGRA, 16.0, 10)
	_puntas(m, 0, 14, 56.0)
	m.detras = true
	m.crecer = 0.08
	m.aguantar = 0.30
	m.encoger = 0.30
	m.destello = 20.0
	_salpicar(at, direction, TINTA_NEGRA, 14, 120.0, 260.0)
	for i in 10:
		var p := Particle.new()
		p.kind = Kind.PAPEL
		p.position = at + Vector2(_rng.randf_range(-10, 10), _rng.randf_range(-20, 10))
		var angulo := _rng.randf_range(-PI, 0.0)
		p.velocity = Vector2(cos(angulo), sin(angulo)) * _rng.randf_range(80.0, 180.0)
		p.total_life = _rng.randf_range(0.5, 0.9)
		p.life = p.total_life
		p.size = 3.0
		p.color = PAPEL
		p.brillo = Color("c9b996")
		_particles.append(p)


## Polvo del suelo: al aterrizar y al caer derribado. Del color de la madera
## de la cubierta, no gris: el polvo es del escenario.
func dust(at: Vector2, amount: int = 8, spread: float = 70.0) -> void:
	for i in amount:
		var p := Particle.new()
		p.kind = Kind.POLVO
		p.position = at + Vector2(_rng.randf_range(-8.0, 8.0), 0.0)
		p.velocity = Vector2(_rng.randf_range(-spread, spread), _rng.randf_range(-60.0, -15.0))
		p.total_life = _rng.randf_range(0.20, 0.45)
		p.life = p.total_life
		p.size = _rng.randf_range(1.0, 3.0)
		p.color = Color(0.62, 0.49, 0.38, 0.9)
		p.brillo = p.color
		_particles.append(p)


func clear() -> void:
	_particles.clear()
	_manchas.clear()
	queue_redraw()
	_detras.queue_redraw()


func _mancha(at: Vector2, direction: int, paleta: Array, radio: float, piezas: int) -> Mancha:
	var m := Mancha.new()
	m.position = at.round()
	m.paleta = paleta
	m.gotas.append(Vector3(0, 0, radio))
	# Las piezas se reparten sobre todo hacia donde va el golpe: la tinta
	# salpica en la dirección de la fuerza, no en un círculo perfecto.
	for i in piezas:
		var angulo := _rng.randf_range(-1.3, 1.3)
		var distancia := _rng.randf_range(radio * 0.6, radio * 1.9)
		var r := maxf(1.0, radio * _rng.randf_range(0.25, 0.6))
		m.gotas.append(Vector3(cos(angulo) * distancia * direction, sin(angulo) * distancia, r))
	_manchas.append(m)
	return m


## Puntas radiales: lo que convierte una mancha redonda en una salpicadura.
## Con dirección 0 salen en todas direcciones; si no, sobre todo hacia el golpe.
func _puntas(m: Mancha, direction: int, cuantas: int, largo: float) -> void:
	for i in cuantas:
		var angulo := _rng.randf_range(-PI, PI)
		if direction != 0:
			angulo = _rng.randf_range(-1.4, 1.4)
			if direction < 0:
				angulo = PI - angulo
		m.puntas.append(Vector3(angulo, largo * _rng.randf_range(0.5, 1.0), _rng.randf_range(1.5, 2.5)))


func _salpicar(at: Vector2, direction: int, paleta: Array, cuantas: int, v_min: float, v_max: float) -> void:
	for i in cuantas:
		var p := _gota(at, paleta)
		var angulo := _rng.randf_range(-1.0, 0.7)  # algo hacia arriba
		p.velocity = Vector2(cos(angulo) * direction, sin(angulo)) * _rng.randf_range(v_min, v_max)
		_particles.append(p)


func _gota(at: Vector2, paleta: Array) -> Particle:
	var p := Particle.new()
	p.kind = Kind.GOTA
	p.position = at
	p.total_life = _rng.randf_range(0.25, 0.5)
	p.life = p.total_life
	p.size = float(_rng.randi_range(1, 3))
	p.color = paleta[0]
	p.brillo = paleta[1]
	return p


func _draw() -> void:
	for m in _manchas:
		if not m.detras:
			_draw_mancha(m, self)
	# Los destellos, todos delante, también el del súper: son el chispazo.
	for m in _manchas:
		_draw_destello(m, self)
	for p in _particles:
		_draw_particula(p)


func _draw_detras() -> void:
	for m in _manchas:
		if m.detras:
			_draw_mancha(m, _detras)


## Destello de papel: una estrella de cuatro puntas que solo vive los
## primeros frames. Es el "clac" visual del contacto, y va encima de todo.
func _draw_destello(m: Mancha, lienzo: CanvasItem) -> void:
	if m.destello <= 0.0 or m.edad >= m.crecer + 0.04:
		return
	var largo := roundf(m.destello * (1.0 - m.edad / (m.crecer + 0.04)))
	var c := m.position
	lienzo.draw_rect(Rect2(c.x - largo, c.y, largo * 2.0 + 1.0, 1), PAPEL)
	lienzo.draw_rect(Rect2(c.x, c.y - largo, 1, largo * 2.0 + 1.0), PAPEL)
	var corto := roundf(largo * 0.45)
	lienzo.draw_rect(Rect2(c.x - corto, c.y - 1.0, corto * 2.0 + 1.0, 3), PAPEL)
	lienzo.draw_rect(Rect2(c.x - 1.0, c.y - corto, 3, corto * 2.0 + 1.0), PAPEL)


func _draw_mancha(m: Mancha, lienzo: CanvasItem) -> void:
	# Primero el brillo, desplazado arriba a la izquierda; encima el cuerpo.
	# Lo que asoma del brillo es un filo de luz en cada gota y cada punta.
	var formas := _formas(m, m.escala())
	for f in formas:
		lienzo.draw_circle(Vector2(f.x, f.y) - Vector2.ONE, f.z, m.paleta[1], true, -1.0, false)
	for f in formas:
		lienzo.draw_circle(Vector2(f.x, f.y), f.z, m.paleta[0], true, -1.0, false)


## Círculos (x, y, radio) que forman la mancha en este instante. Las puntas
## son rosarios de círculos que adelgazan: crecen hacia fuera con la mancha.
func _formas(m: Mancha, s: float) -> Array[Vector3]:
	var formas: Array[Vector3] = []
	for g in m.gotas:
		var r := roundf(g.z * s)
		if r >= 1.0:
			var c := m.position + Vector2(g.x, g.y).round()
			formas.append(Vector3(c.x, c.y, r))
	for p in m.puntas:
		var largo := p.y * s
		var paso := 0.0
		while paso <= largo:
			var t := paso / maxf(1.0, p.y)
			var r := roundf(p.z * (1.0 - t) * s)
			if r < 1.0:
				break
			var c := (m.position + Vector2(cos(p.x), sin(p.x)) * paso).round()
			formas.append(Vector3(c.x, c.y, r))
			paso += 1.5
	return formas


func _draw_particula(p: Particle) -> void:
	# Se encogen al apagarse en vez de desvanecerse: en pixel art un
	# degradado de alfa se ve sucio, un píxel que desaparece se ve limpio.
	var t := p.life / maxf(0.001, p.total_life)
	var size := maxf(1.0, roundf(p.size * minf(1.0, t * 1.8)))
	var pos := p.position.round()
	if p.kind == Kind.PAPEL:
		# Hojita que aletea: alterna entre ancha y de canto.
		var ancho := 3.0 if int(p.life * 14.0) % 2 == 0 else 1.0
		draw_rect(Rect2(pos.x, pos.y, ancho, 2), p.color)
		draw_rect(Rect2(pos.x, pos.y + 2.0, ancho, 1), p.brillo)
		return
	draw_rect(Rect2(pos, Vector2(size, size)), p.color)
	if size >= 2.0:
		draw_rect(Rect2(pos, Vector2.ONE), p.brillo)
