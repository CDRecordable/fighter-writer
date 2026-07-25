class_name Effects
extends Node2D
## Chispas de impacto, polvo y destellos.
##
## Regla que no se puede romper: **los efectos no tocan la simulación**. Viven
## fuera del punto fijo, corren con el reloj de render y usan floats y azar sin
## problema, porque nada de lo que pasa aquí cambia una posición, un daño ni un
## frame. Si alguna vez un efecto necesitara influir en el combate, deja de ser
## un efecto y se va a `fighter.gd` con enteros.
##
## Se dibujan a mano con formas, no con imágenes: así no dependen de ningún
## asset ni de la licencia de nadie, y el artista puede sustituirlos en la Fase
## 4 sin tocar el sitio desde donde se disparan.

const GRAVEDAD := 260.0

enum Kind { GOLPE, BLOQUEO, POLVO, DERRIBO }


class Particle:
	var kind: int = Kind.GOLPE
	var position := Vector2.ZERO
	var velocity := Vector2.ZERO
	var life: float = 0.0
	var total_life: float = 0.0
	var size: float = 2.0
	var color := Color.WHITE


var _particles: Array[Particle] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Delante de los luchadores: una chispa detrás del cuerpo no se ve.
	z_index = 50
	_rng.randomize()


func _process(delta: float) -> void:
	if _particles.is_empty():
		return
	var survivors: Array[Particle] = []
	for p in _particles:
		p.life -= delta
		if p.life <= 0.0:
			continue
		p.position += p.velocity * delta
		if p.kind != Kind.GOLPE:
			p.velocity.y += GRAVEDAD * delta
		survivors.append(p)
	_particles = survivors
	queue_redraw()


## Impacto limpio: chispas rápidas que salen en abanico hacia atrás del golpe.
func hit(at: Vector2, direction: int, strength: float = 1.0) -> void:
	var count := int(6.0 + 6.0 * strength)
	for i in count:
		var p := Particle.new()
		p.kind = Kind.GOLPE
		p.position = at
		var angle := _rng.randf_range(-2.4, 2.4)
		var speed := _rng.randf_range(60.0, 190.0) * (0.6 + strength * 0.6)
		p.velocity = Vector2(cos(angle) * direction, sin(angle)) * speed
		p.total_life = _rng.randf_range(0.10, 0.22)
		p.life = p.total_life
		p.size = _rng.randf_range(1.0, 3.0)
		p.color = Color(1.0, _rng.randf_range(0.80, 1.0), _rng.randf_range(0.35, 0.65))
		_particles.append(p)


## Bloqueo: menos chispas, más frías y hacia arriba. Tiene que leerse distinto
## de un impacto de un vistazo, sin mirar la barra de vida.
func block(at: Vector2, direction: int) -> void:
	for i in 7:
		var p := Particle.new()
		p.kind = Kind.BLOQUEO
		p.position = at
		p.velocity = Vector2(
			_rng.randf_range(0.2, 1.0) * direction * 60.0,
			_rng.randf_range(-120.0, -40.0)
		)
		p.total_life = _rng.randf_range(0.12, 0.26)
		p.life = p.total_life
		p.size = _rng.randf_range(1.0, 2.0)
		p.color = Color(0.65, 0.88, 1.0)
		_particles.append(p)


## Polvo del suelo: al aterrizar y al caer derribado.
func dust(at: Vector2, amount: int = 8, spread: float = 70.0) -> void:
	for i in amount:
		var p := Particle.new()
		p.kind = Kind.POLVO
		p.position = at + Vector2(_rng.randf_range(-6.0, 6.0), 0.0)
		p.velocity = Vector2(_rng.randf_range(-spread, spread), _rng.randf_range(-70.0, -20.0))
		p.total_life = _rng.randf_range(0.20, 0.45)
		p.life = p.total_life
		p.size = _rng.randf_range(1.0, 3.0)
		p.color = Color(0.72, 0.66, 0.58, 0.85)
		_particles.append(p)


func clear() -> void:
	_particles.clear()
	queue_redraw()


func _draw() -> void:
	for p in _particles:
		# Se encogen al apagarse en vez de desvanecerse: en pixel art un
		# degradado de alfa se ve sucio, un píxel que desaparece se ve limpio.
		var t := p.life / maxf(0.001, p.total_life)
		var size := maxf(1.0, roundf(p.size * t))
		var color := p.color
		color.a *= clampf(t * 1.6, 0.0, 1.0)
		draw_rect(
			Rect2(roundf(p.position.x), roundf(p.position.y), size, size),
			color
		)
