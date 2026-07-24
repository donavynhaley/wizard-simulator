shader_type spatial;
// Alpha-blended rather than additive: the surface has to HIDE the room behind
// it. An additive pass can only brighten, so the doorway kept showing the very
// room you were supposedly leaving.
render_mode unshaded, cull_disabled, depth_draw_never;

// The shimmer filling a bound doorway. Stylised on purpose: a true render-to-
// texture window would cost a second camera per mouth, and the swirl reads as
// magic rather than as a hole in the wall.

uniform vec3 core_color : source_color = vec3(0.06, 0.30, 0.72);
uniform vec3 rim_color : source_color = vec3(0.45, 0.82, 1.0);
uniform float swirl_speed = 1.15;
// Doorway is 1.46 wide by 2.58 tall; squashing x keeps the swirl round.
uniform float aspect = 0.57;

void fragment() {
	vec2 centred = UV - vec2(0.5);
	vec2 shaped = vec2(centred.x * aspect, centred.y);
	float radius = length(shaped);
	float angle = atan(shaped.y, shaped.x);
	float swirl = sin(angle * 3.0 + TIME * swirl_speed - radius * 15.0) * 0.5 + 0.5;
	float ripple = sin(radius * 22.0 - TIME * 2.0) * 0.5 + 0.5;
	// Fade against all four sides so the surface meets the frame softly.
	float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float body = smoothstep(0.0, 0.16, edge);
	vec3 tint = mix(core_color, rim_color, clamp(swirl * 0.60 + ripple * 0.25, 0.0, 1.0));
	ALBEDO = tint * (0.45 + 0.55 * swirl);
	// Fully opaque across the body, fading only against the frame. Any residual
	// transparency let the cottage's emissive window ghost through the centre.
	ALPHA = body;
}
