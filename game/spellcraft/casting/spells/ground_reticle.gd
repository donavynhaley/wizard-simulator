class_name GroundReticle
extends MeshInstance3D

## The ground-AoE targeting ring. Tintable to the spell's element, like every
## other indicator, through the shared set_color() convention.

func set_color(color: Color) -> void:
	var mat := material_override as StandardMaterial3D
	if mat == null:
		return
	mat.albedo_color = Color(color.r, color.g, color.b, mat.albedo_color.a)
	mat.emission = color
