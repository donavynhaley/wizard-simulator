shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 core_color : source_color = vec4(1.0, 0.94, 0.46, 1.0);
uniform vec4 mid_color : source_color = vec4(1.0, 0.42, 0.06, 0.82);
uniform vec4 edge_color : source_color = vec4(0.72, 0.03, 0.0, 0.0);
uniform vec4 magic_color : source_color = vec4(0.18, 0.5, 1.0, 0.62);
uniform float emission_strength : hint_range(0.0, 10.0, 0.1) = 3.4;
uniform float scroll_speed : hint_range(0.0, 8.0, 0.01) = 1.65;
uniform float swirl_speed : hint_range(0.0, 8.0, 0.01) = 1.2;
uniform float noise_scale : hint_range(1.0, 30.0, 0.1) = 8.0;
uniform float cut_strength : hint_range(0.0, 2.0, 0.01) = 0.72;
uniform float edge_softness : hint_range(0.001, 0.5, 0.001) = 0.12;
uniform float wobble_amount : hint_range(0.0, 0.2, 0.001) = 0.045;
uniform float vanish_start : hint_range(0.0, 1.0, 0.01) = 0.78;
uniform float base_fade : hint_range(0.0, 0.5, 0.01) = 0.08;

float hash(vec2 value) {
	return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(vec2 value) {
	vec2 cell = floor(value);
	vec2 local = fract(value);
	vec2 smooth_local = local * local * (3.0 - 2.0 * local);

	float a = hash(cell);
	float b = hash(cell + vec2(1.0, 0.0));
	float c = hash(cell + vec2(0.0, 1.0));
	float d = hash(cell + vec2(1.0, 1.0));

	return mix(mix(a, b, smooth_local.x), mix(c, d, smooth_local.x), smooth_local.y);
}

float fbm(vec2 value) {
	float result = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		result += value_noise(value) * amplitude;
		value *= 2.03;
		amplitude *= 0.5;
	}
	return result;
}

void vertex() {
	float height = UV.y;
	float angle_wave = sin((UV.x + TIME * swirl_speed * 0.18) * TAU + height * 7.0);
	float vertical_wave = sin(TIME * 7.0 + height * 15.0);
	float strength = (1.0 - height) * wobble_amount;
	VERTEX.xz += normalize(vec2(VERTEX.x, VERTEX.z)) * (angle_wave + vertical_wave * 0.35) * strength;
}

void fragment() {
	vec2 scrolled_uv = vec2(UV.x * noise_scale + TIME * 0.15, UV.y * noise_scale - TIME * scroll_speed);
	vec2 subtract_uv = vec2(UV.x * noise_scale * 1.7 - TIME * 0.24, UV.y * noise_scale * 1.2 - TIME * scroll_speed * 1.36);

	float rising_noise = fbm(scrolled_uv);
	float cut_noise = fbm(subtract_uv);
	float height = UV.y;
	float horizontal = abs(UV.x - 0.5) * 2.0;

	float taper = mix(0.9, 0.04, height);
	float silhouette = smoothstep(taper, taper - edge_softness, horizontal);
	float texture_cut = rising_noise - cut_noise * cut_strength;
	float tongues = smoothstep(0.02, 0.42, texture_cut);
	float vanish = 1.0 - smoothstep(vanish_start, 1.0, height);
	float bottom = smoothstep(0.0, base_fade, height);
	float alpha = silhouette * tongues * vanish * bottom;

	float inner = smoothstep(0.58, 0.95, 1.0 - horizontal) * smoothstep(0.0, 0.62, height);
	float heat_band = smoothstep(0.0, 0.78, height);
	vec3 fire_color = mix(mid_color.rgb, edge_color.rgb, heat_band);
	fire_color = mix(fire_color, core_color.rgb, inner);

	float magic = smoothstep(0.36, 0.0, horizontal) * (1.0 - smoothstep(0.0, 0.48, height));
	fire_color = mix(fire_color, magic_color.rgb, magic * 0.5);

	ALBEDO = fire_color;
	EMISSION = fire_color * emission_strength * alpha;
	ALPHA = alpha * mix(edge_color.a, mid_color.a, alpha);
}
