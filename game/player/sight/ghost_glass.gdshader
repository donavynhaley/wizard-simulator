shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, shadows_disabled, depth_draw_never;

// Ghost-glass: in Wizard Sight, mundane matter becomes pale translucent glass -
// clear across the faces, cold light catching every edge - so the solid, bright
// magic behind and inside it reads straight through. Driven by the global
// wizard_sight (0..1) that SightController fades, and swapped onto every mundane
// mesh by SightFade (magic and the player's body are left alone). It writes no
// depth, so it never occludes the magic drawn behind it.

global uniform float wizard_sight;

uniform vec3 glass_tint : source_color = vec3(0.42, 0.55, 0.72);
uniform vec3 edge_color : source_color = vec3(0.72, 0.90, 1.15);
uniform float body_alpha : hint_range(0.0, 1.0) = 0.05; // clear across the faces
uniform float edge_alpha : hint_range(0.0, 1.0) = 0.75; // cold light on the edges
uniform float edge_power = 3.0;

void fragment() {
	// Fresnel: faces go clear, grazing edges catch light.
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), edge_power);
	ALBEDO = mix(glass_tint, edge_color * 1.6, fres);
	EMISSION = edge_color * fres * 1.6;
	ALPHA = mix(body_alpha, edge_alpha, fres) * wizard_sight;
}
