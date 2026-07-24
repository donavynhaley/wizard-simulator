shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, shadows_disabled;

// Shadow-puppet: in Wizard Sight, mundane matter flattens into depthless cutouts
// in a shadow-play - deep black fills with a warm lamp-lit paper edge - while
// magic keeps its colour, light, and dimension against them.
//
// Applied as a material_OVERLAY (SightFade), so the real material keeps rendering
// and writing depth underneath: magic stays properly occluded by the cutouts, and
// this pass simply fades over the world. The veil blooms outward from the centre
// of your gaze as wizard_sight rises - the other world takes hold where you
// squint first - and recedes back to centre when Sight drops. The rim gutters
// slowly like the lamp behind a scrim, and the black carries a faint drifting
// mottle so the dark reads as cloth, not void.

global uniform float wizard_sight;

uniform vec3 shadow_color : source_color = vec3(0.012, 0.012, 0.018);
uniform vec3 rim_color : source_color = vec3(1.0, 0.60, 0.25);
uniform float rim_power = 4.5;
uniform float rim_strength : hint_range(0.0, 4.0) = 0.7;
/// Softness of the expanding veil's leading edge.
uniform float veil_feather : hint_range(0.05, 0.6) = 0.3;
/// How much warm mottle drifts in the black fill (0 = dead flat).
uniform float mottle_amount : hint_range(0.0, 0.05) = 0.012;

// --- Per-instance signifier channels (magic breaks the theater's rules) ---
// Elements break the COLOUR rule: a vessel holding essence swaps its lamp-amber
// rim for the element's colour, breathing; it flares under the wizard's aim and
// starves to a faint outline when empty. Driven by ElementSource.
instance uniform vec3 essence_tint : source_color = vec3(0.0, 0.0, 0.0);
instance uniform float essence_amount : hint_range(0.0, 1.0) = 0.0;
instance uniform float essence_flare : hint_range(0.0, 1.0) = 0.0;
// Awakened objects break the STILLNESS rule: their silhouette breathes.
// Driven by AwakenedPresence.
instance uniform float breath_amount : hint_range(0.0, 1.0) = 0.0;
instance uniform float breath_phase = 0.0;

varying vec3 v_world;

float hash2(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash2(i);
	float b = hash2(i + vec2(1.0, 0.0));
	float c = hash2(i + vec2(0.0, 1.0));
	float d = hash2(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// The lamp behind the scrim gutters: slow layered waver, never a buzz.
	float gutter = 1.0 + 0.10 * sin(TIME * 2.3) * sin(TIME * 6.7)
		+ 0.05 * sin(TIME * 11.3 + 1.7);
	// Backlit paper edge on every grazing silhouette.
	float ndv = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fres = pow(ndv, rim_power);
	vec3 lamp_rim = rim_color * rim_strength * gutter * fres;
	// Essence burns through: a broader colored halo replaces the lamp rim,
	// pulsing on its own slow breath and flaring under the wizard's aim.
	float efres = pow(ndv, rim_power * 0.55);
	float epulse = 0.72 + 0.28 * sin(TIME * 1.9 + breath_phase);
	float eburn = essence_amount * epulse * (1.0 + 1.8 * essence_flare);
	float emask = clamp(essence_amount * 6.0, 0.0, 1.0);
	// An awakened silhouette breathes: the whole rim swells and dims.
	float breath = 1.0 + breath_amount * 0.7 * sin(TIME * 1.15 + breath_phase);
	vec3 rim = mix(lamp_rim, essence_tint * 2.4 * eburn * efres, emask) * breath;
	// Faint warm mottle drifting through the black - cloth, not void.
	vec2 weave = vec2(v_world.x + v_world.y * 0.7, v_world.z - v_world.y * 0.7);
	float mottle = vnoise(weave * 0.8 + TIME * 0.05) * mottle_amount;
	vec3 col = shadow_color + rim + rim_color * mottle;

	// The veil: shadow takes hold at the centre of the squint and floods outward,
	// covering the whole frame by full Sight; release and it drains back inward.
	vec2 centered = SCREEN_UV - vec2(0.5);
	centered.x *= VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
	float reach = wizard_sight * (1.1 + veil_feather);
	float veil = 1.0 - smoothstep(reach - veil_feather, reach, length(centered));
	veil *= smoothstep(0.0, 0.15, wizard_sight);

	ALBEDO = col;
	ALPHA = veil;
}
