shader_type canvas_item;
render_mode unshaded;

// Wizard Sight fullscreen grade: desaturates and cools the world while the
// sight action is held, with a soft vignette pulling focus to the centre aim.
// intensity is faded by SightController; 0 = invisible passthrough.

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

void fragment() {
	vec3 screen = texture(screen_texture, SCREEN_UV).rgb;
	float grey = dot(screen, vec3(0.299, 0.587, 0.114));
	// Reading the world, not watching it: drain colour, cool what remains.
	vec3 col = mix(screen, vec3(grey), 0.6 * intensity);
	col = mix(col, col * vec3(0.8, 0.92, 1.12), 0.5 * intensity);
	vec2 offset = SCREEN_UV - vec2(0.5);
	float vignette = smoothstep(0.9, 0.3, length(offset));
	col *= mix(1.0, 0.35 + 0.65 * vignette, 0.7 * intensity);
	COLOR = vec4(col, clamp(intensity * 4.0, 0.0, 1.0));
}
