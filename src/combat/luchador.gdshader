shader_type canvas_item;
// Luz de borde y contorno para los luchadores.
//
// El atardecer del escenario está DETRÁS de los personajes, así que la luz
// que les llega es contraluz: ilumina los bordes de la silueta, sobre todo los
// de arriba. Eso es lo que los separa del fondo y los mete en la misma luz que
// el escenario, sin repintar un solo sprite.
//
// Trabaja por vecinos en la textura: un píxel opaco con un vecino
// transparente encima es borde superior; uno transparente con un vecino opaco
// es contorno. Nada de desenfoques: todo cae en la rejilla de píxeles.

uniform vec4 luz_borde : source_color = vec4(1.0, 0.70, 0.52, 1.0);
uniform float fuerza_arriba : hint_range(0.0, 1.0) = 0.42;
uniform float fuerza_lados : hint_range(0.0, 1.0) = 0.18;
uniform vec4 contorno : source_color = vec4(0.08, 0.04, 0.11, 1.0);
uniform bool con_contorno = false;

// El tinte de estado (golpe, bloqueo, congelado) llega como color de vértice.
varying vec4 modulacion;

void vertex() {
	modulacion = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE;
	float arriba = texture(TEXTURE, UV + vec2(0.0, -px.y)).a;
	float abajo = texture(TEXTURE, UV + vec2(0.0, px.y)).a;
	float izq = texture(TEXTURE, UV + vec2(-px.x, 0.0)).a;
	float der = texture(TEXTURE, UV + vec2(px.x, 0.0)).a;

	if (c.a < 0.5) {
		float vecinos = max(max(arriba, abajo), max(izq, der));
		if (con_contorno && vecinos > 0.5) {
			COLOR = vec4(contorno.rgb * modulacion.rgb, contorno.a * modulacion.a);
		} else {
			COLOR = vec4(0.0);
		}
	} else {
		float borde = (1.0 - step(0.5, arriba)) * fuerza_arriba
			+ (1.0 - step(0.5, min(izq, der))) * fuerza_lados;
		// Mezcla tipo "pantalla": aclara hacia el color de la luz sin quemar
		// los oscuros del contorno dibujado.
		vec3 lit = 1.0 - (1.0 - c.rgb) * (1.0 - luz_borde.rgb * borde);
		COLOR = vec4(lit, c.a) * modulacion;
	}
}
