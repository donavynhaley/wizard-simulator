shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform float emission_energy : hint_range(0.0, 12.0) = 4.0;
uniform float core_size : hint_range(0.0, 1.0) = 0.22;


void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]
	);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}


void fragment() {
	float radial_distance = length(UV - vec2(0.5)) * 2.0;
	float glow = 1.0 - smoothstep(core_size, 1.0, radial_distance);
	float hot_core = 1.0 - smoothstep(0.0, core_size, radial_distance);
	vec3 flame_color = mix(COLOR.rgb, vec3(1.0, 0.92, 0.52), hot_core * 0.72);
	ALBEDO = flame_color;
	EMISSION = flame_color * emission_energy;
	ALPHA = glow * COLOR.a;
}
