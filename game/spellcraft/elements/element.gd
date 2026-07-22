class_name Element
extends Resource

## An element (fire, water, earth, air) a spell can be imbued with. Carries the
## visual identity fed to the spell_orb shader across the palm orb, projectile and
## burst - one shader, many looks. Damage type and mesh swaps hang off this later.

@export var id: StringName = &""
@export var display_name := ""
@export var color := Color(0.55, 0.28, 1.0)        ## ink + orb base tint
@export var rim_color := Color(0.85, 0.7, 1.0)
@export var emission_energy := 3.5
@export var flow_speed := 0.7
@export var noise_scale := 3.5
## Cast behaviour selected when the Hurl rune consumes this element.
@export var hurl_cast_scene: PackedScene


## Pushes this element's look onto a spell effect. set_color updates the base/rim
## and any tinted light; set_shader_param then layers the fuller element look
## (explicit rim, energy, flow, turbulence) on top. Both run when available so the
## light gets recoloured too, not just the material.
func apply_to(effect: Node) -> void:
	if effect == null:
		return
	if effect.has_method(&"set_color"):
		effect.call(&"set_color", color)
	if effect.has_method(&"set_shader_param"):
		effect.call(&"set_shader_param", &"base_color", color)
		effect.call(&"set_shader_param", &"rim_color", rim_color)
		effect.call(&"set_shader_param", &"emission_energy", emission_energy)
		effect.call(&"set_shader_param", &"flow_speed", flow_speed)
		effect.call(&"set_shader_param", &"noise_scale", noise_scale)
