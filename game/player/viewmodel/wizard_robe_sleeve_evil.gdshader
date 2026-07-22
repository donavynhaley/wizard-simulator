shader_type spatial;
render_mode depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 robe_color : source_color = vec4(0.105, 0.012, 0.022, 1.0);
uniform vec4 raised_thread_color : source_color = vec4(0.17, 0.025, 0.038, 1.0);
uniform vec4 trim_color : source_color = vec4(0.31, 0.19, 0.07, 1.0);
uniform float viewmodel_fill : hint_range(0.0, 1.0, 0.01) = 0.45;
uniform float sway_amount : hint_range(0.0, 0.08, 0.001) = 0.028;
uniform float sway_speed : hint_range(0.0, 4.0, 0.05) = 1.15;

void vertex() {
	float cuff_influence = smoothstep(0.62, 1.0, UV.y);
	float primary_wave = sin(TIME * sway_speed + UV.x * 12.56637 + UV.y * 4.0);
	float secondary_wave = sin(TIME * sway_speed * 0.63 - UV.x * 18.84956);
	float displacement = (primary_wave * 0.7 + secondary_wave * 0.3) * sway_amount;
	VERTEX += NORMAL * displacement * cuff_influence * cuff_influence;
}

void fragment() {
	float warp = 0.5 + 0.5 * sin(UV.x * 565.4867);
	float weft = 0.5 + 0.5 * sin(UV.y * 439.8230 + UV.x * 6.28318);
	float weave = warp * weft;
	float broad_variation = 0.5 + 0.5 * sin(UV.y * 37.6991 + UV.x * 12.56637);

	vec3 cloth = mix(robe_color.rgb, raised_thread_color.rgb, weave * 0.11);
	cloth *= mix(0.96, 1.035, broad_variation);

	float trim_start = smoothstep(0.875, 0.895, UV.y);
	float trim_end = 1.0 - smoothstep(0.945, 0.965, UV.y);
	float trim_band = trim_start * trim_end;
	float trim_pattern = 0.65 + 0.35 * sin(UV.x * 75.3982 + UV.y * 31.4159);
	float trim = trim_band * smoothstep(0.1, 0.9, trim_pattern);

	ALBEDO = mix(cloth, trim_color.rgb, trim * 0.82);
	ROUGHNESS = mix(0.93, 0.58, trim);
	METALLIC = trim * 0.32;
	SPECULAR = mix(0.16, 0.34, trim);
	EMISSION = ALBEDO * viewmodel_fill;
	NORMAL_MAP = normalize(vec3((warp - 0.5) * 0.045, (weft - 0.5) * 0.045, 1.0));
}
