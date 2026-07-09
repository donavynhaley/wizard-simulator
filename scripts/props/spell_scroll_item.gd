class_name SpellScrollItem
extends Node3D

@export var scroll_data: SpellScrollData
@export var held_position: Vector3 = Vector3(0.025, -0.015, -0.16)
@export var held_rotation: Vector3 = Vector3(-0.72, 0.04, 0.0)
@export var held_scale: Vector3 = Vector3(0.7, 0.7, 0.7)

var _cast_system: SpellCastSystem = SpellCastSystem.new()
var _is_held := false


func _ready() -> void:
	_build_visual()


func get_held_pose() -> Dictionary:
	return {
		"position": held_position,
		"rotation": held_rotation,
		"scale": held_scale,
	}


func get_display_name() -> String:
	if scroll_data != null and not scroll_data.display_name.is_empty():
		return scroll_data.display_name
	return "Spell Scroll"


func set_scroll_data(value: SpellScrollData) -> void:
	scroll_data = value
	name = get_display_name().replace(" ", "")


func set_held(value: bool) -> void:
	_is_held = value


func cast_from(caster: Node, camera_transform: Transform3D) -> String:
	if scroll_data == null:
		return "The scroll is blank."
	if scroll_data.compiled_spell == null:
		return "The scroll has not been sealed."
	if scroll_data.charges <= 0:
		_spend_self(caster)
		return "The scroll has already crumbled."

		var context := SpellCastContext.new()
	context.caster = caster
	context.world = get_tree().current_scene
	context.origin = camera_transform.origin
	context.aim_direction = -camera_transform.basis.z.normalized()
	context.quality = scroll_data.quality
	context.target_position = _target_position(context)

	var result := _cast_system.cast_scroll(scroll_data, context)
	if bool(result.get("spent", false)):
		_spend_self(caster)
	return str(result.get("status", ""))


func _target_position(context: SpellCastContext) -> Vector3:
	var max_range := 6.0
	if context.source_scroll != null and context.source_scroll.compiled_spell != null:
		max_range = context.source_scroll.compiled_spell.range
	elif scroll_data != null and scroll_data.compiled_spell != null:
		max_range = scroll_data.compiled_spell.range

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		context.origin,
		context.origin + context.aim_direction * max_range)
	if context.caster is CollisionObject3D:
		query.exclude = [(context.caster as CollisionObject3D).get_rid()]
	var hit := space.intersect_ray(query)
	if not hit.is_empty() and hit.has("position"):
		return hit["position"] as Vector3
	return context.origin + context.aim_direction * minf(max_range, 4.0)


func _spend_self(caster: Node) -> void:
	if caster is WizardPlayer and (caster as WizardPlayer).hands != null:
		(caster as WizardPlayer).hands.notify_item_gone(self)
	queue_free()


func _build_visual() -> void:
	if get_node_or_null("ScrollVisual") != null:
		return

	var visual := MeshInstance3D.new()
	visual.name = "ScrollVisual"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.34, 0.015, 0.22)
	visual.mesh = mesh
	visual.material_override = _scroll_material()
	add_child(visual)

	var seal := MeshInstance3D.new()
	seal.name = "SealVisual"
	var seal_mesh := CylinderMesh.new()
	seal_mesh.top_radius = 0.035
	seal_mesh.bottom_radius = 0.035
	seal_mesh.height = 0.012
	seal_mesh.radial_segments = 24
	seal.mesh = seal_mesh
	seal.position = Vector3(0.0, 0.016, 0.0)
	seal.material_override = _seal_material()
	add_child(seal)


func _scroll_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.78, 0.68, 0.48)
	material.roughness = 0.82
	if scroll_data != null and scroll_data.ink_id == &"gilded":
		material.emission_enabled = true
		material.emission = Color(0.42, 0.32, 0.08)
		material.emission_energy_multiplier = 0.25
	return material


func _seal_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.18, 0.62, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.12, 0.48, 1.0)
	material.emission_energy_multiplier = 0.9
	if scroll_data != null and scroll_data.ink_id == &"gilded":
		material.albedo_color = Color(0.95, 0.68, 0.18)
		material.emission = Color(1.0, 0.64, 0.12)
	return material
