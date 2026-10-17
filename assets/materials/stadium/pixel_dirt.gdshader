shader_type spatial;
// Terra pixel art com variedade:
// - textura de detalhe projetada pelo eixo dominante da superfície (pixels nítidos, sem mistura);
// - manchas grandes e suaves (dois tamanhos), quantizadas em degraus para combinar com o pixel art;
// - opcional (faixa da pista): sulcos de pneu ondulados e terra solta nas bordas;
// - opcional: marcas de pneu deixadas pela moto, que se acumulam a cada passada.
// - opcional (chuva): terra molhada (mais escura e brilhante) e poças que refletem o céu,
//   com gotinhas caindo nelas.
//   Na pista, UV.x = distância lateral até a linha central (m) e UV.y = distância percorrida (m).

uniform sampler2D detail : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D macro : filter_linear_mipmap, repeat_enable;
uniform float detail_meters = 4.0;
uniform float macro_meters = 36.0;
uniform float macro_strength = 0.22;
uniform bool use_ruts = false;
uniform float track_half_width = 4.5;
uniform float rut_darkness = 0.3;
// Marcas de pneu dinâmicas (preenchidas pelo TrackWear em tempo de jogo).
uniform sampler2D wear : filter_nearest, repeat_disable;
uniform bool use_wear = false;
uniform vec2 wear_origin = vec2(0.0);
uniform vec2 wear_size = vec2(1.0);
uniform float wear_darkness = 0.5;
// Chuva: 0 = seco. Poças: fração do chão plano coberta por poças (0 = nenhuma).
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform float puddle_amount : hint_range(0.0, 1.0) = 0.0;
uniform float puddle_meters = 11.0;

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

	if (use_wear && world_normal.y > 0.5) {
		vec2 wear_uv = (world_pos.xz - wear_origin) / wear_size;
		if (all(greaterThanEqual(wear_uv, vec2(0.0))) && all(lessThanEqual(wear_uv, vec2(1.0)))) {
			// Em degraus, para a marca combinar com o pixel art.
			float w = floor(texture(wear, wear_uv).r * 4.0) / 4.0;
			// Terra compactada: mais escura e um pouco mais fria.
			albedo *= mix(vec3(1.0), vec3(0.58, 0.52, 0.48), w * wear_darkness * 2.0);
		}
	}

	float roughness = 1.0;
	float specular = 0.2;
	if (wetness > 0.0) {
		// Lama: mais escura, puxando para o marrom, e lisa (brilha com a luz do céu).
		albedo *= mix(vec3(1.0), vec3(0.62, 0.52, 0.46), wetness);
		roughness = mix(1.0, 0.42, wetness);
		specular = mix(0.2, 0.45, wetness);
		if (puddle_amount > 0.0 && world_normal.y > 0.96) {
			// Poças em pixels de 1/8 m, onde o ruído grande fica abaixo do limite.
			vec2 cell = floor(world_pos.xz * 8.0) / 8.0;
			float level = texture(macro, cell / puddle_meters + vec2(0.37, 0.71)).r;
			if (level < puddle_amount) {
				float depth = clamp((puddle_amount - level) * 12.0, 0.0, 1.0);
				albedo = mix(albedo * 0.55, vec3(0.05, 0.05, 0.06), floor(depth * 3.0) / 3.0);
				roughness = 0.04;
				specular = 0.9;
				// gotas: pixels que acendem por um instante
				float drop = fract(sin(dot(cell + floor(TIME * 7.0), vec2(12.9898, 78.233))) * 43758.5453);
				albedo += vec3(0.25) * step(0.985, drop);
			}
		}
	}

	ALBEDO = albedo;
	ROUGHNESS = roughness;
	SPECULAR = specular;
}
