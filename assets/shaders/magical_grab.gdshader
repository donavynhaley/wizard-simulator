shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;

uniform vec4 aura_color : source_color = vec4(0.16, 0.72, 1.0, 0.72);
uniform vec4 arc_color : source_color = vec4(0.72, 0.32, 1.0, 0.9);
uniform float effect_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float shell_width : hint_range(0.0, 0.01, 0.0005) = 0.002;
uniform float pulse_speed : hint_range(0.0, 10.0, 0.1) = 2.8;
uniform float arc_frequency : hint_range(1.0, 32.0, 1.0) = 13.0;
uniform float emission_strength : hint_range(0.0, 8.0, 0.1) = 2.6;

varying vec3 local_position;


void vertex() {
	local_position = VERTEX;
	float breathe = 0.88 + sin(TIME * pulse_speed + VERTEX.y * 9.0) * 0.12;
	VERTEX += NORMAL * shell_width * breathe * effect_strength;
}


void fragment() {
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 1.6);
	float traveling_arc = 0.5 + 0.5 * sin(
		local_position.y * arc_frequency
		+ local_position.x * arc_frequency * 0.65
		- TIME * pulse_speed * 2.1
	);
	traveling_arc = smoothstep(0.88, 0.985, traveling_arc);
	float pulse = 0.82 + sin(TIME * pulse_speed) * 0.18;
	float mask = max(rim * 0.62, traveling_arc * 0.42);
	mask *= effect_strength * pulse;
	vec3 color = mix(aura_color.rgb, arc_color.rgb, traveling_arc * 0.72);
	float alpha = mask * mix(0.2, 0.34, traveling_arc);

	ALBEDO = color * 0.35;
	EMISSION = color * emission_strength * mask;
	ALPHA = alpha;
}
