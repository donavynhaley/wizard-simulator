class_name TinyDemon
extends CharacterBody3D

## The tiny useless demon. Summoned by botched forges. Wanders, squeaks,
## flaps, achieves nothing, and leaves after a minute. Do not rely on it.

const LIFETIME := 60.0
const SPEED := 1.3

var _age := 0.0
var _retarget := 0.0
var _squeak := 3.0
var _direction := Vector3.ZERO
var _wings: Array[MeshInstance3D] = []
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("blastable")
	collision_layer = SpellCast.LAYER_WORLD
	collision_mask = SpellCast.LAYER_WORLD
	_rng.randomize()

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.18
	shape.shape = sphere
	shape.position.y = 0.18
	add_child(shape)
	_build_visuals()


func _build_visuals() -> void:
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.75, 0.16, 0.14)
	skin.roughness = 0.7

	var body := MeshInstance3D.new()
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.16
	body_mesh.height = 0.32
	body.mesh = body_mesh
	body.position.y = 0.18
	body.material_override = skin
	add_child(body)

	for side in [-1.0, 1.0]:
		var horn := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.025
		cone.height = 0.09
		horn.mesh = cone
		horn.position = Vector3(0.06 * side, 0.33, 0.0)
		horn.rotation_degrees.z = -18.0 * side
		horn.material_override = SpellVisuals.emissive(Color(0.95, 0.75, 0.35), 0.8)
		add_child(horn)

		var wing := MeshInstance3D.new()
		var wing_mesh := BoxMesh.new()
		wing_mesh.size = Vector3(0.16, 0.01, 0.1)
		wing.mesh = wing_mesh
		wing.position = Vector3(0.15 * side, 0.24, 0.06)
		wing.material_override = skin
		add_child(wing)
		_wings.append(wing)

	var eyes := MeshInstance3D.new()
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.02
	eye_mesh.height = 0.04
	eyes.mesh = eye_mesh
	eyes.position = Vector3(0.05, 0.22, -0.13)
	eyes.material_override = SpellVisuals.emissive(Color(1.0, 0.9, 0.3), 2.0)
	add_child(eyes)
	var eye2 := eyes.duplicate()
	eye2.position.x = -0.05
	add_child(eye2)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		SpellVisuals.spawn_burst(get_tree().current_scene, global_position + Vector3.UP * 0.2,
			Color(0.9, 0.3, 0.3), 16, 2.0)
		SpellVisuals.floating_text(get_tree().current_scene, global_position + Vector3.UP * 0.5,
			"gnak.", Color(1.0, 0.5, 0.4), 26)
		queue_free()
		return

	_retarget -= delta
	if _retarget <= 0.0:
		_retarget = _rng.randf_range(1.2, 3.0)
		var angle := _rng.randf_range(0.0, TAU)
		_direction = Vector3(sin(angle), 0.0, cos(angle))
		if _rng.randf() < 0.25:
			_direction = Vector3.ZERO  # stops to think; thinks about nothing

	_squeak -= delta
	if _squeak <= 0.0:
		_squeak = _rng.randf_range(4.0, 9.0)
		SpellVisuals.floating_text(get_tree().current_scene,
			global_position + Vector3.UP * 0.5, "gnak!", Color(1.0, 0.5, 0.4), 26)

	if not is_on_floor():
		velocity.y -= _gravity * delta
	velocity.x = _direction.x * SPEED
	velocity.z = _direction.z * SPEED
	if _direction.length() > 0.1:
		look_at(global_position + _direction, Vector3.UP)
	move_and_slide()

	for i in _wings.size():
		_wings[i].rotation.z = sin(_age * 14.0) * 0.6 * (1.0 if i == 0 else -1.0)
