shader_type spatial;
render_mode unshaded, cull_disabled;

// The opening onto the far door's room. The view is rendered by a camera
// standing where the viewer would be if this doorway were the far one, so it is
// sampled in SCREEN space: the eye and this surface share a projection, and the
// pixel under the doorway is the pixel that eye saw.

uniform sampler2D portal_view : hint_default_black;
uniform vec3 rim_color : source_color = vec3(0.40, 0.74, 1.0);
// How far in from the frame the arcane rim burns.
uniform float rim_width = 0.055;
// A breath of distortion so the threshold reads as worked magic, not a hole.
uniform float shimmer = 0.004;

void fragment() {
	float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	vec2 view_uv = SCREEN_UV + vec2(
		sin(UV.y * 16.0 + TIME * 1.2),
		cos(UV.x * 13.0 + TIME * 0.9)
	) * shimmer;
	vec3 beyond = texture(portal_view, view_uv).rgb;
	float rim = 1.0 - smoothstep(0.0, rim_width, edge);
	// The rim burns only right at the frame: any wider and the scene's bloom
	// smears it across the whole opening, hazing the view it is framing.
	ALBEDO = mix(beyond, rim_color, rim * 0.35);
	EMISSION = rim_color * rim * 0.10;
	ALPHA = smoothstep(0.0, 0.015, edge);
}
