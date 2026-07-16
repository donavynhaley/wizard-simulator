shader_type spatial;
render_mode blend_mix, cull_disabled, specular_disabled, diffuse_lambert;

// A parameterized arcane-energy sphere: a swirling emissive core with a bright
// fresnel rim. One shader, many looks -- the element system drives these uniforms
// (colour, energy, flow, distortion) so fire/ice/lightning are the same code with
// different parameters. HDR EMISSION feeds the scene glow.

uniform vec3 base_color : source_color = vec3(0.55, 0.28, 1.0);
uniform vec3 rim_color : source_color = vec3(0.85, 0.7, 1.0);
uniform float emission_energy : hint_range(0.0, 12.0) = 3.5;
uniform float fresnel_power : hint_range(0.5, 8.0) = 3.0;
uniform float flow_speed : hint_range(0.0, 4.0) = 0.7;
uniform float noise_scale : hint_range(0.5, 10.0) = 3.5;
uniform float core_alpha : hint_range(0.0, 1.0) = 0.75;
uniform float pulse_speed : hint_range(0.0, 8.0) = 2.2;
uniform float pulse_amount : hint_range(0.0, 0.6) = 0.15;

varying vec3 v_local;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float value_noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i + vec3(0.0, 0.0, 0.0)), hash(i + vec3(1.0, 0.0, 0.0)), f.x),
			mix(hash(i + vec3(0.0, 1.0, 0.0)), hash(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(hash(i + vec3(0.0, 0.0, 1.0)), hash(i + vec3(1.0, 0.0, 1.0)), f.x),
			mix(hash(i + vec3(0.0, 1.0, 1.0)), hash(i + vec3(1.0, 1.0, 1.0)), f.x), f.y),
		f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * value_noise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	v_local = VERTEX;
}

void fragment() {
	// Fresnel rim: bright where the surface faces away from the camera.
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), fresnel_power);
	// Swirling energy in the orb's local space; spins with the mesh + flows in time.
	float n = fbm(v_local * noise_scale + vec3(0.0, TIME * flow_speed, 0.0));
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_amount;

	vec3 core = base_color * (0.35 + n * 0.75);
	vec3 col = mix(core, rim_color, fres);
	EMISSION = col * emission_energy * pulse;
	ALBEDO = base_color * 0.05;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	ALPHA = clamp(core_alpha * (0.35 + n * 0.5) + fres * 0.7, 0.0, 1.0);
}
