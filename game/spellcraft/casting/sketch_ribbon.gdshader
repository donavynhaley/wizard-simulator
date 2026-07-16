shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled;

// Unshaded mode outputs ALBEDO and ignores EMISSION, so the HDR energy has to
// ride the albedo for the bloom pass to see it. Alpha blending (not additive)
// makes the stroke fade read as transparency; the glow look itself is
// geometric (a soft halo strip in the mesh) so it fades uniformly with opacity
// instead of dying at the bloom threshold.
uniform float emission_energy = 8.0;

void fragment() {
	ALBEDO = COLOR.rgb * emission_energy;
	ALPHA = COLOR.a;
}
