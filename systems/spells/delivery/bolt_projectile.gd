class_name BoltProjectile
extends Area3D

const SpellDeliveryScript := preload("res://systems/spells/delivery/spell_delivery.gd")

var spell: CompiledSpellData
var cast_context: SpellCastContext
var velocity := Vector3.ZERO
var lifetime := 0.0
var _delivery := SpellDeliveryScript.new()


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func initialize_spell(_spell: CompiledSpellData, _context: SpellCastContext) -> void:
	spell = _spell
	cast_context = _context
	_delivery.spell = spell
	_delivery.cast_context = cast_context

	var direction := cast_context.aim_direction.normalized()
	if direction == Vector3.ZERO:
		direction = Vector3.FORWARD
	global_position = cast_context.origin + direction * 0.45
	look_at(global_position + direction, Vector3.UP)
	velocity = direction * spell.speed
	_build_visual()


func _physics_process(delta: float) -> void:
	if spell == null:
		queue_free()
		return
	lifetime += delta
	global_position += velocity * delta
	if lifetime >= spell.range / maxf(spell.speed, 0.01):
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body == cast_context.caster:
		return
	_delivery.apply_spell_effects(body, global_position)
	queue_free()


func _on_area_entered(area: Area3D) -> void:
	if area == self:
		return
	_delivery.apply_spell_effects(area, global_position)
	queue_free()


func _build_visual() -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "BoltVisual"
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.045
	mesh.height = 0.38
	mesh.radial_segments = 12
	mesh.rings = 4
	mesh_instance.mesh = mesh
	mesh_instance.rotation_degrees.x = 90.0
	mesh_instance.material_override = _spell_material()
	add_child(mesh_instance)


func _spell_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.38, 0.82, 1.0, 0.82)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(0.15, 0.62, 1.0)
	material.emission_energy_multiplier = 1.6
	if spell != null and spell.tags.has(&"gilded"):
		material.emission = Color(0.32, 0.72, 1.0).lerp(Color(1.0, 0.76, 0.22), 0.35)
	return material
