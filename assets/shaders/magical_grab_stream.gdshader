shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 lower_color : source_color = vec4(0.04, 0.58, 1.0, 0.82);
uniform vec4 upper_color : source_color = vec4(0.58, 0.12, 0.94, 0.86);
uniform float effect_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float flow_speed : hint_range(0.0, 12.0, 0.1) = 4.8;
uniform float strand_count : hint_range(1.0, 8.0, 1.0) = 3.0;
uniform float twist_count : hint_range(0.0, 8.0, 0.1) = 2.4;
uniform float sway_amount : hint_range(0.0, 0.04, 0.001) = 0.008;
uniform float emission_strength : hint_range(0.0, 8.0, 0.1) = 3.2;


void vertex() {
	float height_phase = UV.y * 8.0;
	VERTEX.x += sin(TIME * 2.1 + height_phase) * sway_amount * UV.y;
	VERTEX.z += cos(TIME * 1.7 + height_phase * 0.83) * sway_amount * UV.y;
}


void fragment() {
	float helix = sin(
		UV.x * 6.283185 * strand_count
		- UV.y * 6.283185 * twist_count
		+ TIME * flow_speed
	);
	float strand = smoothstep(0.82, 0.98, helix);
	float rising_pulse = 0.5 + 0.5 * sin(UV.y * 18.0 - TIME * flow_speed * 1.7);
	rising_pulse = smoothstep(0.42, 0.9, rising_pulse);
	float end_fade = smoothstep(0.0, 0.12, UV.y) * (1.0 - smoothstep(0.82, 1.0, UV.y));
	float center_glow = 0.05 + rising_pulse * 0.1;
	float mask = max(strand * 0.9, center_glow) * end_fade * effect_strength;
	vec3 color = mix(lower_color.rgb, upper_color.rgb, UV.y);

	ALBEDO = color;
	EMISSION = color * emission_strength * mask;
	ALPHA = clamp(mask * mix(lower_color.a, upper_color.a, UV.y), 0.0, 0.78);
}
