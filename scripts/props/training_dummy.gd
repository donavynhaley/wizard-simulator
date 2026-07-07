class_name TrainingDummy
extends StaticBody3D

## A straw practice dummy for spell testing. Takes spell hits, flashes, keels
## over when its health runs out, then pops back up. Emits a death notification
## so "on_death" triggered spells have something to listen for.

signal died
signal hit_taken(hit: Dictionary)

@export var max_health: float = 30.0
@export var respawn_seconds: float = 3.0

var health: float
var dead := false

var _body_mat: StandardMaterial3D
var _label: Label3D
var _visual: Node3D
var _shape: CollisionShape3D


func _ready() -> void:
	add_to_group("spell_target")
	add_to_group("blastable")
	collision_layer = SpellCast.LAYER_WORLD | SpellCast.LAYER_TARGET
	health = max_health

	_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.6
	_shape.shape = capsule
	_shape.position.y = 0.9
	add_child(_shape)
	_build_visuals()
	_update_label()


func _build_visuals() -> void:
	_visual = Node3D.new()
	add_child(_visual)

	var straw := StandardMaterial3D.new()
	straw.albedo_color = Color(0.72, 0.6, 0.3)
	straw.roughness = 1.0
	_body_mat = straw
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.32, 0.22, 0.13)
	wood.roughness = 0.9

	var post := MeshInstance3D.new()
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.06
	post_mesh.bottom_radius = 0.08
	post_mesh.height = 0.8
	post.mesh = post_mesh
	post.position.y = 0.4
	post.material_override = wood
	_visual.add_child(post)

	var torso := MeshInstance3D.new()
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.26
	torso_mesh.height = 1.0
	torso.mesh = torso_mesh
	torso.position.y = 1.15
	torso.material_override = straw
	_visual.add_child(torso)

	var arms := MeshInstance3D.new()
	var arms_mesh := BoxMesh.new()
	arms_mesh.size = Vector3(1.1, 0.09, 0.09)
	arms.mesh = arms_mesh
	arms.position.y = 1.35
	arms.material_override = wood
	_visual.add_child(arms)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.17
	head_mesh.height = 0.34
	head.mesh = head_mesh
	head.position.y = 1.85
	head.material_override = straw
	_visual.add_child(head)

	_label = Label3D.new()
	_label.font_size = 28
	_label.pixel_size = 0.004
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = 2.25
	_label.modulate = Color(0.9, 0.9, 0.85)
	add_child(_label)


func take_spell_hit(hit: Dictionary) -> void:
	if dead:
		return
	health -= float(hit.get("power", 0.0))
	hit_taken.emit(hit)
	_flinch(hit)
	_update_label()
	if health <= 0.0:
		_die(hit)


func _flinch(hit: Dictionary) -> void:
	var color: Color = hit.get("color", Color.WHITE)
	_body_mat.emission_enabled = true
	_body_mat.emission = color
	_body_mat.emission_energy_multiplier = 1.2
	var tween := create_tween()
	tween.tween_property(_body_mat, "emission_energy_multiplier", 0.0, 0.35)
	# A quick tilt away from the blow, then back upright.
	var impulse: Vector3 = hit.get("impulse", Vector3.ZERO)
	var lean := Vector3(impulse.z, 0.0, -impulse.x).normalized() * 0.22
	if lean.length() > 0.01:
		var punch := create_tween()
		punch.tween_property(_visual, "rotation", lean, 0.08)
		punch.tween_property(_visual, "rotation", Vector3.ZERO, 0.4) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _die(hit: Dictionary) -> void:
	dead = true
	died.emit()
	SpellCast.notify_death(global_position)
	SpellVisuals.spawn_burst(get_tree().current_scene,
		global_position + Vector3.UP * 1.2, hit.get("color", Color.WHITE), 30, 3.5)
	SpellVisuals.floating_text(get_tree().current_scene,
		global_position + Vector3.UP * 2.0, "unstuffed!", Color(0.95, 0.8, 0.5), 32)
	_visual.visible = false
	_label.visible = false
	_shape.set_deferred("disabled", true)
	get_tree().create_timer(respawn_seconds).timeout.connect(_respawn)


func _respawn() -> void:
	if not is_inside_tree():
		return
	dead = false
	health = max_health
	_visual.visible = true
	_label.visible = true
	_shape.set_deferred("disabled", false)
	_visual.scale = Vector3.ONE * 0.1
	var tween := create_tween()
	tween.tween_property(_visual, "scale", Vector3.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_update_label()


func _update_label() -> void:
	_label.text = "%d / %d" % [ceili(maxf(health, 0.0)), int(max_health)]
