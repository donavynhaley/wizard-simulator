shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_back;

uniform vec4 base_color : source_color = vec4(0.2, 0.05, 0.025, 1.0);
uniform int surface_kind : hint_range(0, 3) = 0;
uniform float wear_strength : hint_range(0.0, 1.0) = 0.55;

varying vec3 local_position;


float hash21(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
}


float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 blend = fract(point);
	blend = blend * blend * (3.0 - 2.0 * blend);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, blend.x), mix(c, d, blend.x), blend.y);
}


float layered_noise(vec2 point) {
	float result = 0.0;
	float amplitude = 0.55;
	for (int octave = 0; octave < 4; octave++) {
		result += value_noise(point) * amplitude;
		point = point * 2.07 + vec2(7.1, 3.8);
		amplitude *= 0.48;
	}
	return result;
}


void vertex() {
	local_position = VERTEX;
}


void fragment() {
	vec3 normal = normalize(NORMAL);
	vec3 key_direction = normalize(vec3(-0.38, 0.52, 0.76));
	vec3 fill_direction = normalize(vec3(0.62, -0.24, 0.74));
	float key = max(dot(normal, key_direction), 0.0);
	float fill = max(dot(normal, fill_direction), 0.0);
	float fixed_light = 0.64 + key * 0.28 + fill * 0.08;
	vec2 texture_uv = UV;
	if (dot(texture_uv, texture_uv) < 0.00001) {
		texture_uv = local_position.xy * 8.0;
	}
	float edge_distance = min(min(texture_uv.x, 1.0 - texture_uv.x),
		min(texture_uv.y, 1.0 - texture_uv.y));
	float edge_wear = 1.0 - smoothstep(0.015, 0.12, edge_distance);
	vec3 color = base_color.rgb;

	if (surface_kind == 0) {
		vec2 grain_uv = local_position.xy * vec2(320.0, 480.0);
		float broad_grain = layered_noise(grain_uv);
		float pores = value_noise(grain_uv * vec2(7.0, 4.5));
		float scratch_wave = sin(grain_uv.y * 2.1
			+ layered_noise(grain_uv * 0.35) * 8.0) * 0.5 + 0.5;
		float scratches = smoothstep(0.965, 0.995, scratch_wave)
			* smoothstep(0.62, 0.92, value_noise(grain_uv * 0.8));
		color *= mix(0.86, 1.14, broad_grain);
		color *= mix(0.92, 1.06, pores);
		vec3 worn_leather = mix(color, vec3(0.13, 0.065, 0.035), 0.52);
		color = mix(color, worn_leather,
			clamp(edge_wear * wear_strength + scratches * 0.2, 0.0, 0.72));
		float grazing = pow(1.0 - max(dot(normal, VIEW), 0.0), 2.4);
		color += vec3(0.018, 0.006, 0.003) * grazing;
	} else if (surface_kind == 1) {
		float fiber = layered_noise(texture_uv * vec2(55.0, 130.0));
		float horizontal_fiber = sin(texture_uv.y * 820.0
			+ value_noise(texture_uv * 90.0) * 4.0) * 0.5 + 0.5;
		color *= mix(0.88, 1.08, fiber);
		color *= mix(0.94, 1.02, horizontal_fiber);
		color = mix(color, color * vec3(0.72, 0.55, 0.34), edge_wear * 0.32);
	} else if (surface_kind == 2) {
		float tarnish = layered_noise(texture_uv * 20.0);
		color *= mix(0.58, 1.12, tarnish);
		vec3 reflected_key = reflect(-key_direction, normal);
		float highlight = pow(max(dot(reflected_key, VIEW), 0.0), 22.0);
		color += vec3(0.24, 0.12, 0.028) * highlight;
		fixed_light = 0.72 + key * 0.24 + fill * 0.04;
	} else {
		float thread_fuzz = value_noise(texture_uv * 160.0);
		color *= mix(0.76, 1.15, thread_fuzz);
		fixed_light = 0.72 + key * 0.22 + fill * 0.06;
	}

	ALBEDO = clamp(color * fixed_light, vec3(0.0), vec3(1.0));
	ROUGHNESS = surface_kind == 2 ? 0.62 : 0.9;
	METALLIC = surface_kind == 2 ? 0.72 : 0.0;
}
