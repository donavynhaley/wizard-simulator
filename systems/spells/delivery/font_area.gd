class_name FontArea
extends Area3D

const SpellDeliveryScript := preload("res://systems/spells/delivery/spell_delivery.gd")

@export var tick_interval: float = 1.0

var spell: CompiledSpellData
var cast_context: SpellCastContext
var elapsed := 0.0
var tick_timer := 0.0
var _delivery := SpellDeliveryScript.new()


func initialize_spell(_spell: CompiledSpellData, _context: SpellCastContext) -> void:
	spell = _spell
	cast_context = _context
	_delivery.spell = spell
	_delivery.cast_context = cast_context
	global_position = cast_context.target_position
	scale = Vector3.ONE * maxf(spell.radius, 0.1)
	_build_visual()
	call_deferred("_apply_tick")


func _process(delta: float) -> void:
	if spell == null:
		queue_free()
		return
	elapsed += delta
	tick_timer += delta
	if tick_timer >= tick_interval:
		tick_timer = 0.0
		_apply_tick()
	if elapsed >= spell.duration:
		queue_free()


func _apply_tick() -> void:
	for body in get_overlapping_bodies():
		_delivery.apply_spell_effects(body, global_position, &"spell_tick")
	for area in get_overlapping_areas():
		if area != self:
			_delivery.apply_spell_effects(area, global_position, &"spell_tick")


func _build_visual() -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "FontVisual"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.035
	mesh.radial_segments = 48
	mesh.rings = 1
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _spell_material()
	add_child(mesh_instance)

	var light := OmniLight3D.new()
	light.name = "FontLight"
	light.light_color = Color(0.35, 0.78, 1.0).lerp(Color(1.0, 0.76, 0.26), 0.25 if spell != null and spell.tags.has(&"gilded") else 0.0)
	light.light_energy = 0.75
	light.omni_range = 2.2
	add_child(light)


func _spell_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.18, 0.64, 1.0, 0.42)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(0.08, 0.45, 0.9)
	material.emission_energy_multiplier = 1.2
	if spell != null and spell.tags.has(&"gilded"):
		material.albedo_color = Color(0.24, 0.68, 1.0, 0.48).lerp(Color(1.0, 0.72, 0.16, 0.48), 0.22)
		material.emission = Color(0.1, 0.52, 1.0).lerp(Color(1.0, 0.78, 0.24), 0.35)
	return material
