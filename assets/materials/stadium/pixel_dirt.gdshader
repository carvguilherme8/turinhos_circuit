shader_type spatial;
// Terra pixel art com variedade:
// - textura de detalhe projetada pelo eixo dominante da superfície (pixels nítidos, sem mistura);
// - manchas grandes e suaves (dois tamanhos), quantizadas em degraus para combinar com o pixel art;
// - opcional (faixa da pista): sulcos de pneu ondulados e terra solta nas bordas.
//   Na pista, UV.x = distância lateral até a linha central (m) e UV.y = distância percorrida (m).

uniform sampler2D detail : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D macro : filter_linear_mipmap, repeat_enable;
uniform float detail_meters = 4.0;
uniform float macro_meters = 36.0;
uniform float macro_strength = 0.22;
uniform bool use_ruts = false;
uniform float track_half_width = 4.5;
uniform float rut_darkness = 0.3;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 sample_detail(vec3 p, vec3 n) {
	vec3 a = abs(n);
	vec2 uv = p.xz;
	if (a.x > a.y && a.x > a.z) {
		uv = p.zy;
	} else if (a.z > a.y) {
		uv = p.xy;
	}
	return texture(detail, uv / detail_meters).rgb;
}

// Um sulco: linha que ondula ao longo da pista e some em alguns trechos.
float rut(float u, float v, float offset, float phase) {
	float center = offset + sin(v * 0.11 + phase) * 0.35 + sin(v * 0.037 + phase * 2.0) * 0.5;
	float line = step(abs(u - center), 0.13);
	float gaps = step(0.38, texture(macro, vec2(v / 23.0, phase * 0.17)).r);
	return line * gaps;
}

void fragment() {
	vec3 albedo = sample_detail(world_pos, world_normal);

	float m = texture(macro, world_pos.xz / macro_meters).r * 0.65
			+ texture(macro, world_pos.xz / (macro_meters * 0.37) + vec2(0.5)).r * 0.35;
	m = floor(m * 6.0) / 6.0;
	albedo *= mix(1.0 - macro_strength, 1.0 + macro_strength * 0.5, m);

	if (use_ruts) {
		// Quantiza em pixels de 1/16 m para os sulcos ficarem "em degraus".
		float u = floor(UV.x * 16.0) / 16.0;
		float v = floor(UV.y * 16.0) / 16.0;
		float ruts = max(max(rut(u, v, -1.7, 0.0), rut(u, v, -0.15, 2.1)), rut(u, v, 1.4, 4.3));
		albedo *= 1.0 - rut_darkness * ruts;
		// Terra solta (mais clara) perto das bordas.
		float edge = clamp((abs(u) - (track_half_width - 1.0)) / 1.0, 0.0, 1.0);
		albedo *= 1.0 + 0.12 * floor(edge * 3.0) / 3.0;
	}

	ALBEDO = albedo;
	ROUGHNESS = 1.0;
	SPECULAR = 0.2;
}
