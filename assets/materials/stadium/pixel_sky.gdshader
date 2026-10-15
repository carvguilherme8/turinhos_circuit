shader_type sky;
// Céu de entardecer pixel art:
// - degradê em faixas (horizonte quente -> meio rosado -> topo azul-escuro), mais quente na direção do sol;
// - sol quadrado e pixelado (como no Minecraft) com brilho em volta;
// - estrelas quadradinhas piscando no alto do céu.

uniform vec3 top_color : source_color = vec3(0.13, 0.13, 0.34);
uniform vec3 mid_color : source_color = vec3(0.47, 0.3, 0.55);
uniform vec3 horizon_color : source_color = vec3(0.96, 0.56, 0.42);
uniform vec3 ground_color : source_color = vec3(0.12, 0.1, 0.14);
uniform vec3 sun_color : source_color = vec3(1.0, 0.86, 0.55);
// Quantas faixas no degradê (menos = mais "pixel art").
uniform float bands = 16.0;
// Meio-tamanho do sol (em unidades de direção, ~radianos).
uniform float sun_size = 0.05;
uniform float sun_glow = 0.35;
// Tamanho de um "pixel" de estrela (radianos) e fração de pixels que são estrelas.
uniform float star_pixel = 0.0035;
uniform float star_density = 0.006;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void sky() {
	vec3 dir = EYEDIR;
	vec3 color;
	if (dir.y < 0.0) {
		color = ground_color;
	} else {
		float t = floor(pow(dir.y, 0.55) * bands) / bands;
		color = t < 0.5 ? mix(horizon_color, mid_color, t * 2.0) : mix(mid_color, top_color, (t - 0.5) * 2.0);
	}

	if (LIGHT0_ENABLED) {
		vec3 s = LIGHT0_DIRECTION;
		// Horizonte mais quente do lado do sol.
		vec2 flat_dir = normalize(dir.xz + vec2(0.0001));
		vec2 flat_sun = normalize(s.xz + vec2(0.0001));
		float toward = max(dot(flat_dir, flat_sun), 0.0);
		float low = 1.0 - clamp(dir.y * 2.5, 0.0, 1.0);
		float warm = floor(toward * toward * low * 6.0) / 6.0;
		color = mix(color, sun_color * 0.95, warm * 0.45);

		// Sol quadrado, em pixels.
		vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), s));
		vec3 up = cross(s, right);
		float facing = dot(dir, s);
		if (facing > 0.0 && !AT_CUBEMAP_PASS) {
			vec2 local = vec2(dot(dir, right), dot(dir, up));
			float px = sun_size / 5.0;
			vec2 q = (floor(local / px) + 0.5) * px;
			float d = max(abs(q.x), abs(q.y));
			if (d < sun_size) {
				color = d < sun_size * 0.6 ? vec3(1.6, 1.45, 1.1) : sun_color * 1.3;
			} else {
				// Brilho em degraus em volta do sol.
				float glow = exp(-length(local) * 7.0) * sun_glow;
				color += sun_color * floor(glow * 8.0) / 8.0;
			}
		}
	}

	// Estrelas: só no alto, onde já está escuro.
	// (fora do cálculo de luz ambiente: são só detalhe do fundo)
	if (dir.y > 0.2 && !AT_CUBEMAP_PASS) {
		vec2 sph = vec2(atan(dir.x, dir.z), asin(clamp(dir.y, -1.0, 1.0)));
		vec2 cell = floor(sph / star_pixel);
		float r = hash(cell);
		if (r > 1.0 - star_density) {
			float fade = smoothstep(0.25, 0.6, dir.y);
			float twinkle = 0.55 + 0.45 * sin(TIME * (1.5 + r * 3.0) + r * 60.0);
			color += vec3(0.9, 0.92, 1.0) * fade * twinkle;
		}
	}

	COLOR = color;
}
