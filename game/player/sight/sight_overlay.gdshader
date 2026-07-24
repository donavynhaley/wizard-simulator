shader_type canvas_item;
render_mode unshaded;

// The wash over Wizard Sight. The heavy lifting is the shadow-puppet overlay on
// mundane geometry (SightFade) plus the bright magic reading against it; this
// pulls the backdrop (sky, distance) toward a cold dusk-slate so the only warm
// things in the theater are the guttering rims and the flames themselves, and
// adds a soft vignette so the squint reads. Deliberately gentle: it also washes
// over the magic, and the magic's colours must survive it.
// intensity is faded by SightController; 0 = passthrough.

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform vec3 veil_tint : source_color = vec3(0.76, 0.83, 1.0);
/// Luminance where the veil starts letting self-lit magic through untouched.
uniform float magic_floor : hint_range(0.0, 1.0) = 0.5;
/// Extra brightness on the exempted magic so it pulls the eye in Sight.
uniform float magic_boost : hint_range(1.0, 2.0) = 1.15;

void fragment() {
	vec3 screen = texture(screen_texture, SCREEN_UV).rgb;
	float g = dot(screen, vec3(0.299, 0.587, 0.114));
	vec3 cooled = mix(screen, vec3(g), 0.3) * veil_tint;
	// Self-lit magic (flames, blazing essence) punches through the veil with its
	// own colour and heat - the veil is for the world, not the fire.
	float magic = smoothstep(magic_floor, 0.9, g);
	vec3 veiled = mix(cooled, screen * magic_boost, magic);
	vec3 col = mix(screen, veiled, intensity);
	vec2 offset = SCREEN_UV - vec2(0.5);
	float vignette = smoothstep(1.0, 0.4, length(offset));
	// The squint vignette spares the magic too.
	col *= mix(1.0, 0.72 + 0.28 * vignette, intensity * (1.0 - magic));
	COLOR = vec4(col, clamp(intensity * 4.0, 0.0, 1.0));
}
