class_name DroughtField
extends Area3D

@export var restored_amount: float = 0.0
@export var required_restore_amount: float = 24.0
@export var field_radius: float = 1.35

var completed := false
var last_event_id: StringName = &""


func _ready() -> void:
	monitoring = true
	monitorable = true
	if get_node_or_null("CollisionShape3D") == null:
		var shape := CylinderShape3D.new()
		shape.radius = field_radius
		shape.height = 0.2
		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		collision.shape = shape
		add_child(collision)


func receive_spell_event(event_id: StringName, context: SpellHitContext) -> void:
	if completed:
		return
	if event_id != &"mended" and event_id != &"spell_tick":
		return
	if context == null or not context.tags.has(&"water"):
		return

	var multiplier := 2.0 if context.tags.has(&"font") else 1.0
	restored_amount += context.power * multiplier
	last_event_id = event_id
	_update_visual_state()

	if restored_amount >= required_restore_amount:
		_complete_drought_objective(context)


func _update_visual_state() -> void:
	var ratio := clampf(restored_amount / maxf(required_restore_amount, 0.001), 0.0, 1.0)
	if self is GeometryInstance3D:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.42, 0.25, 0.12).lerp(Color(0.24, 0.56, 0.2), ratio)
		material.roughness = 0.9
		(self as GeometryInstance3D).material_override = material


func _complete_drought_objective(context: SpellHitContext) -> void:
	completed = true
	if context != null and not context.tags.has(&"quest_solution"):
		context.tags.append(&"quest_solution")
	WizardHud.toast(self, "The drought field drinks in the spell.")
