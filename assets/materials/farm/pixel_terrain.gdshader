shader_type spatial;
// Terreno da fazenda em pixel art: grama no plano, barranco de terra vermelha onde é íngreme
// e terra solta perto da pista (COLOR.r dos vértices = quanto é terra, vindo do script).
// Tudo em degraus (sem mistura suave), para combinar com o visual de blocos.

uniform sampler2D grass_tex : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D clay_tex : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D macro : filter_linear_mipmap, repeat_enable;
uniform float detail_meters = 4.0;
uniform float macro_meters = 40.0;
uniform float macro_strength = 0.2;
// Inclinação a partir da qual vira barranco (normal.y abaixo disto).
uniform float bank_slope = 0.82;

varying vec3 world_pos;
varying vec3 world_normal;
varying float dirt_amount;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	dirt_amount = COLOR.r;
}

vec3 project(sampler2D tex, vec3 p, vec3 n) {
	vec3 a = abs(n);
	vec2 uv = p.xz;
	if (a.x > a.y && a.x > a.z) {
		uv = p.zy;
	} else if (a.z > a.y) {
		uv = p.xy;
	}
	return texture(tex, uv / detail_meters).rgb;
}

void fragment() {
	float m = texture(macro, world_pos.xz / macro_meters).r;
	// Borda irregular (ruído) entre grama, terra e barranco, em blocos de 1 m.
	float jitter = texture(macro, floor(world_pos.xz) / 9.0).r - 0.5;
	vec3 albedo;
	if (world_normal.y < bank_slope + jitter * 0.08) {
		albedo = project(clay_tex, world_pos, world_normal);
	} else if (dirt_amount + jitter * 0.5 > 0.5) {
		albedo = project(dirt_tex, world_pos, world_normal);
	} else {
		albedo = project(grass_tex, world_pos, world_normal);
	}
	float steps = floor((m * 0.7 + 0.3) * 5.0) / 5.0;
	albedo *= mix(1.0 - macro_strength, 1.0 + macro_strength * 0.5, steps);
	ALBEDO = albedo;
	ROUGHNESS = 1.0;
	SPECULAR = 0.15;
}
