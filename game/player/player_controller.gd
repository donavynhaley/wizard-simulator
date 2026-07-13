class_name WizardPlayer
extends CharacterBody3D

## First-person wizard controller: movement, stair stepping, mouse look and
## capture, and the viewmodel's walk/sway motion. Body and arm presentation
## lives on the BodyRig child (WizardBodyRig), interaction on the camera's
## Interactor, and held items in the instanced Viewmodel scene.

@export var move_speed: float = 4.2
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.0022
@export_range(45.0, 80.0, 1.0) var look_pitch_limit_degrees: float = 75.0
@export var acceleration: float = 16.0
@export var deceleration: float = 12.0

@export_group("Stair Stepping")
@export var enable_stair_stepping: bool = true
@export var max_step_height: float = 0.8
@export var min_step_height: float = 0.08
@export var step_probe_clearance: float = 0.35
@export var step_forward_distance: float = 0.5
@export var step_down_extra: float = 0.08
@export var step_down_snap_height: float = 0.5
@export var stair_floor_snap_length: float = 0.45
@export_range(0.1, 1.0, 0.01) var stair_climb_speed_multiplier: float = 0.72
@export var stair_step_feedback_time: float = 0.32
@export var stair_camera_lift_amount: float = 0.045
@export var stair_camera_step_smoothing: float = 5.0
@export var debug_stair_stepping: bool = false

@export_group("Viewmodel Motion")
@export var viewmodel_rest_position: Vector3 = Vector3(0.0, -0.5, -0.55)
@export var walk_bob_amount: float = 0.012
@export var walk_sway_amount: float = 0.006
@export var look_sway_position_amount: float = 0.00045
@export var look_sway_return_speed: float = 9.0

@onready var head: Node3D = $Head
@onready var viewmodel: Node3D = $Head/Camera3D/Viewmodel

## Typed accessors for the player's scene-unique components. Interactables
## receive a WizardPlayer, so player.hands / player.interactor autocomplete.
## Plain getters (not @onready) so they work regardless of ready order.
var hands: WizardHands:
	get: return get_node_or_null(^"Head/Camera3D/Viewmodel/HandAnchor") as WizardHands
var interactor: PlayerInteractor:
	get: return get_node_or_null(^"Head/Camera3D/Interactor") as PlayerInteractor

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _look_sway := Vector2.ZERO
var _look_sway_target := Vector2.ZERO
var _stair_step_timer := 0.0
var _stair_step_strength := 0.0
var _head_rest_position := Vector3.ZERO
var _head_step_offset := 0.0


func _ready() -> void:
	_capture_mouse()
	floor_snap_length = maxf(floor_snap_length, stair_floor_snap_length)
	_head_rest_position = head.position
	viewmodel.position = viewmodel_rest_position


## Freezes or resumes the player wholesale: movement, look, interaction, and
## body idle motion. Stations that take over the camera (like the spell
## crafter) call this instead of poking the player's internals.
func set_control_enabled(enabled: bool) -> void:
	set_physics_process(enabled)
	set_process_input(enabled)
	set_process_unhandled_input(enabled)
	if interactor:
		interactor.set_active(enabled)
	var body_rig := get_node_or_null(^"BodyRig") as WizardBodyRig
	if body_rig:
		body_rig.set_active(enabled)


func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_MOUSE_ENTER:
			if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
				_capture_mouse()
		NOTIFICATION_WM_WINDOW_FOCUS_IN:
			if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
				_capture_mouse()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
				_capture_mouse()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			apply_mouse_look(event.relative)
		return

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			_capture_mouse()


func apply_mouse_look(relative: Vector2) -> void:
	rotate_y(-relative.x * mouse_sensitivity)
	head.rotate_x(-relative.y * mouse_sensitivity)
	var pitch_limit := deg_to_rad(look_pitch_limit_degrees)
	head.rotation.x = clamp(head.rotation.x, -pitch_limit, pitch_limit)
	_look_sway_target = relative


func _physics_process(delta: float) -> void:
	var was_on_floor := is_on_floor()
	var position_before_move := global_position
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var pre_snapped_down := false

	if enable_stair_stepping \
			and not was_on_floor \
			and direction != Vector3.ZERO \
			and velocity.y <= 0.0:
		pre_snapped_down = _try_step_down()

	if not is_on_floor() and not pre_snapped_down:
		velocity.y -= _gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var climb_multiplier := stair_climb_speed_multiplier if _stair_step_timer > 0.0 else 1.0
	var target_velocity := direction * move_speed * climb_multiplier

	if direction != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)

	var prepared_step_down_height := -1.0
	if enable_stair_stepping \
			and was_on_floor \
			and direction != Vector3.ZERO \
			and velocity.y <= 0.0:
		var horizontal_speed := Vector3(velocity.x, 0.0, velocity.z).length()
		var horizontal_motion := direction.normalized() * maxf(step_forward_distance, horizontal_speed * delta)
		prepared_step_down_height = _find_step_down_height(global_transform, horizontal_motion)
		if prepared_step_down_height > 0.0:
			velocity.y = minf(velocity.y, -prepared_step_down_height / maxf(delta, 0.001))

	var expected_horizontal_motion := Vector3(velocity.x, 0.0, velocity.z).length() * delta
	move_and_slide()
	if prepared_step_down_height > 0.0 and is_on_floor():
		_apply_stair_feedback(-prepared_step_down_height)

	var actual_horizontal_motion := Vector3(
		global_position.x - position_before_move.x,
		0.0,
		global_position.z - position_before_move.z).length()
	var movement_was_blocked := actual_horizontal_motion < expected_horizontal_motion * 0.55
	var stepped_up := false
	if enable_stair_stepping \
			and was_on_floor \
			and direction != Vector3.ZERO \
			and (_has_forward_wall_collision(direction) or movement_was_blocked):
		stepped_up = _try_step_up(direction, delta)
	if enable_stair_stepping \
			and not stepped_up \
			and direction != Vector3.ZERO \
			and velocity.y <= 0.0:
		_try_step_down()

	_update_viewmodel(delta, input_dir.length())


func _try_step_up(direction: Vector3, delta: float) -> bool:
	var original := global_transform
	var horizontal_speed := Vector3(velocity.x, 0.0, velocity.z).length()
	var forward_distance := maxf(step_forward_distance, horizontal_speed * delta)
	var forward_motion := direction.normalized() * forward_distance
	var probe_lift := max_step_height + step_probe_clearance
	var up_motion := Vector3.UP * probe_lift

	if test_move(original, up_motion):
		_debug_stair("blocked while checking step height")
		return false

	var step_height := _find_step_height(original, forward_motion, probe_lift)
	if step_height < 0.0:
		_debug_stair("no usable step landing found")
		return false

	var stepped := original
	stepped.origin.y += step_height
	global_transform = stepped
	velocity.y = 0.0
	_apply_stair_feedback(step_height)
	_debug_stair("stepped up %.3f" % step_height)
	return true


func _try_step_down() -> bool:
	var original := global_transform
	var max_snap := minf(max_step_height, step_down_snap_height) + step_down_extra
	var down_collision := KinematicCollision3D.new()
	if not test_move(original, Vector3.DOWN * max_snap, down_collision):
		return false

	if down_collision.get_normal().dot(Vector3.UP) < cos(floor_max_angle):
		return false

	var step_height := -down_collision.get_travel().y
	if step_height < min_step_height or step_height > max_snap + 0.01:
		return false

	global_transform = original.translated(down_collision.get_travel())
	velocity.y = 0.0
	apply_floor_snap()
	_apply_stair_feedback(-step_height)
	_debug_stair("stepped down %.3f" % step_height)
	return true


func _find_step_down_height(original: Transform3D, horizontal_motion: Vector3) -> float:
	if horizontal_motion.length_squared() <= 0.000001:
		return -1.0

	var probe := original.translated(horizontal_motion)
	var max_snap := minf(max_step_height, step_down_snap_height) + step_down_extra
	var down_collision := KinematicCollision3D.new()
	if not test_move(probe, Vector3.DOWN * max_snap, down_collision):
		return -1.0

	if down_collision.get_normal().dot(Vector3.UP) < cos(floor_max_angle):
		return -1.0

	var step_height := -down_collision.get_travel().y
	if step_height < min_step_height or step_height > max_snap + 0.01:
		return -1.0

	return step_height


func _find_step_height(original: Transform3D, forward_motion: Vector3, probe_lift: float) -> float:
	var best_height := INF
	var raised := original.translated(Vector3.UP * probe_lift)
	var lowered_motion := Vector3.DOWN * (probe_lift + step_down_extra)

	for fraction: float in [0.35, 0.5, 0.7, 0.9, 1.0]:
		var sampled_forward: Vector3 = forward_motion * fraction
		if test_move(raised, sampled_forward):
			continue

		var down_collision := KinematicCollision3D.new()
		var forward_raised := raised.translated(sampled_forward)
		if not test_move(forward_raised, lowered_motion, down_collision):
			continue

		if down_collision.get_normal().dot(Vector3.UP) < cos(floor_max_angle):
			continue

		var landed_probe := forward_raised.translated(down_collision.get_travel())
		var step_height := landed_probe.origin.y - original.origin.y
		if step_height >= min_step_height \
				and step_height <= max_step_height + 0.01 \
				and step_height < best_height:
			best_height = step_height

	return -1.0 if is_inf(best_height) else best_height


func _has_forward_wall_collision(direction: Vector3) -> bool:
	var forward := direction.normalized()
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var normal := collision.get_normal()
		if normal.dot(Vector3.UP) > 0.2:
			continue
		if forward.dot(-normal) > 0.35:
			return true
	return false


func _debug_stair(message: String) -> void:
	if debug_stair_stepping:
		print("[stair] ", message)


func _apply_stair_feedback(step_delta: float) -> void:
	var step_height := absf(step_delta)
	_stair_step_timer = stair_step_feedback_time
	_stair_step_strength = clampf(step_height / max_step_height, 0.0, 1.0)
	if step_delta > 0.0:
		_head_step_offset = minf(_head_step_offset, -step_height * 0.75)
	else:
		_head_step_offset = maxf(_head_step_offset, step_height * 0.75)


func _update_viewmodel(delta: float, input_amount: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	_head_step_offset = move_toward(_head_step_offset, 0.0, stair_camera_step_smoothing * delta)
	head.position = _head_rest_position + Vector3.UP * _head_step_offset

	_look_sway = _look_sway.lerp(_look_sway_target, minf(1.0, look_sway_return_speed * delta))
	_look_sway_target = _look_sway_target.lerp(Vector2.ZERO, minf(1.0, look_sway_return_speed * delta))
	var stair_feedback := _stair_feedback(delta)

	# Walk bob/sway of the whole viewmodel.
	var bob := sin(t * 7.0) * walk_bob_amount * input_amount
	var sway := cos(t * 3.5) * walk_sway_amount * input_amount
	var look_offset := Vector3(
		clampf(-_look_sway.x * look_sway_position_amount, -0.035, 0.035),
		clampf(_look_sway.y * look_sway_position_amount, -0.025, 0.025),
		0.0)
	var stair_lift := Vector3(0.0, stair_feedback * stair_camera_lift_amount, 0.0)
	var target_position := viewmodel_rest_position + Vector3(sway, bob, 0.0) + look_offset + stair_lift
	viewmodel.position = viewmodel.position.lerp(target_position, minf(1.0, 8.0 * delta))


func _stair_feedback(delta: float) -> float:
	if _stair_step_timer <= 0.0:
		_stair_step_strength = move_toward(_stair_step_strength, 0.0, delta * 6.0)
		return 0.0

	_stair_step_timer = maxf(0.0, _stair_step_timer - delta)
	var phase := 1.0 - _stair_step_timer / maxf(0.001, stair_step_feedback_time)
	return sin(phase * PI) * _stair_step_strength
