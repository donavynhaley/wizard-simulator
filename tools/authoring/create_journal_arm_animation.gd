extends SceneTree

## Authors the dedicated left-arm journal sequence used to reach to the belt,
## unhook the journal, lift it, and settle beneath the opened book.

const ARMS_SCENE := "res://game/player/viewmodel/wizard_arms.tscn"
const OUTPUT_LIBRARY := \
	"res://game/player/viewmodel/journal_arm_animations.tres"
const ANIMATION_NAME := &"journal_unhook_open_left"
const TRACK_PREFIX := "arms/Skeleton3D:"
const BASE_ANIMATION := &"Reset_left"
const LENGTH := 1.1
const PHASE_TIMES := [0.0, 0.12, 0.26, 0.48, 0.72, 1.1]
const FINGER_BONES: Array[StringName] = [
	&"finger_pinky1.l", &"finger_pinky2.l", &"finger_pinky3.l",
	&"finger_ring1.l", &"finger_ring2.l", &"finger_ring3.l",
	&"finger_middle1.l", &"finger_middle2.l", &"finger_middle3.l",
	&"finger_index1.l", &"finger_index2.l", &"finger_index3.l",
	&"finger_thumb1.l", &"finger_thumb2.l", &"finger_thumb3.l",
]

var _skeleton: Skeleton3D
var _base_animation: Animation


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var arms := (load(ARMS_SCENE) as PackedScene).instantiate()
	root.add_child(arms)
	await process_frame
	_skeleton = arms.get_node("arms/Skeleton3D") as Skeleton3D
	var left_player := arms.get_node("LeftAnimationPlayer") as AnimationPlayer
	_base_animation = left_player.get_animation(BASE_ANIMATION)
	if "--inspect" in OS.get_cmdline_user_args():
		_print_chain_pose()
		quit(0)
		return
	var library := AnimationLibrary.new()
	var animation := _build_animation()
	library.add_animation(ANIMATION_NAME, animation)
	var error := ResourceSaver.save(library, OUTPUT_LIBRARY)
	if error != OK:
		push_error("Could not save %s (error %d)" % [OUTPUT_LIBRARY, error])
		quit(1)
		return
	print(
		"Authored ", ANIMATION_NAME,
		" with ", animation.get_track_count(),
		" tracks at ", OUTPUT_LIBRARY)
	quit(0)


func _build_animation() -> Animation:
	var animation := Animation.new()
	animation.resource_name = ANIMATION_NAME
	animation.length = LENGTH
	animation.loop_mode = Animation.LOOP_NONE
	animation.set_meta(&"purpose", "journal_belt_unhook_lift_and_open")
	animation.add_marker(&"reach_belt", 0.12)
	animation.add_marker(&"grip_book", 0.26)
	animation.add_marker(&"begin_open", 0.64)
	animation.add_marker(&"reading_support", 0.9)

	var base_globals := _base_global_poses()
	var base_wrist := (base_globals[_bone(&"wrist.l")] as Transform3D).origin
	var wrist_targets: Array[Vector3] = [
		base_wrist,
		Vector3(-3.1, -4.15, -2.57),
		Vector3(-3.14, -4.02, -2.68),
		Vector3(-3.35, -2.2, -3.3),
		Vector3(-2.75, 0.35, -3.85),
		Vector3(-2.55, 0.85, -3.4),
	]
	var elbow_hints: Array[Vector3] = [
		(base_globals[_bone(&"forearm.l")] as Transform3D).origin,
		Vector3(-4.72, -2.7, -0.72),
		Vector3(-4.76, -2.58, -0.9),
		Vector3(-4.65, -1.55, -1.1),
		Vector3(-4.25, -0.1, -1.15),
		Vector3(-4.05, 0.05, -0.95),
	]
	var wrist_rotations_degrees: Array[Vector3] = [
		Vector3.ZERO,
		Vector3(14.0, -10.0, 22.0),
		Vector3(22.0, -18.0, 38.0),
		Vector3(34.0, -32.0, 58.0),
		Vector3(48.0, -44.0, 70.0),
		Vector3(40.0, -36.0, 62.0),
	]
	var finger_curls := PackedFloat32Array([0.0, 0.08, 0.88, 1.0, 0.82, 0.76])
	var poses: Array[Dictionary] = []
	for phase in PHASE_TIMES.size():
		var pose := _solve_arm_pose(
			base_globals,
			wrist_targets[phase],
			elbow_hints[phase],
			wrist_rotations_degrees[phase])
		_apply_finger_curl(pose, finger_curls[phase])
		poses.append(pose)

	var animated_bones: Array[StringName] = [
		&"shoulder.l", &"bicep.l", &"forearm.l", &"wrist.l",
		&"forearm.Twist0.l", &"forearm.Twist1.l",
	]
	animated_bones.append_array(FINGER_BONES)
	for bone_name in animated_bones:
		_add_transform_tracks(animation, bone_name, poses)
	return animation


func _solve_arm_pose(
		base_globals: Dictionary[int, Transform3D],
		wrist_target: Vector3,
		elbow_hint: Vector3,
		wrist_rotation_degrees: Vector3) -> Dictionary:
	var pose: Dictionary = {}
	for bone_name in [
			&"shoulder.l", &"bicep.l", &"forearm.l", &"wrist.l",
			&"forearm.Twist0.l", &"forearm.Twist1.l"]:
		pose[bone_name] = _sample_base_local(_bone(bone_name))
	for finger_name in FINGER_BONES:
		pose[finger_name] = _sample_base_local(_bone(finger_name))

	var shoulder := _bone(&"shoulder.l")
	var bicep := _bone(&"bicep.l")
	var forearm := _bone(&"forearm.l")
	var wrist := _bone(&"wrist.l")
	var shoulder_global := base_globals[shoulder] as Transform3D
	var base_bicep_global := base_globals[bicep] as Transform3D
	var base_forearm_global := base_globals[forearm] as Transform3D
	var base_wrist_global := base_globals[wrist] as Transform3D
	var upper_origin := base_bicep_global.origin
	var upper_length := upper_origin.distance_to(base_forearm_global.origin)
	var forearm_length := base_forearm_global.origin.distance_to(
		base_wrist_global.origin)
	var elbow := _solve_elbow(
		upper_origin, wrist_target, elbow_hint, upper_length, forearm_length)

	var base_upper_direction := (
		base_forearm_global.origin - upper_origin).normalized()
	var target_upper_direction := (elbow - upper_origin).normalized()
	var bicep_global := Transform3D(
		_align_basis(
			base_bicep_global.basis,
			base_upper_direction,
			target_upper_direction),
		upper_origin)
	pose[&"bicep.l"] = shoulder_global.affine_inverse() * bicep_global

	var base_forearm_direction := (
		base_wrist_global.origin - base_forearm_global.origin).normalized()
	var target_forearm_direction := (wrist_target - elbow).normalized()
	var forearm_global := Transform3D(
		_align_basis(
			base_forearm_global.basis,
			base_forearm_direction,
			target_forearm_direction),
		elbow)
	pose[&"forearm.l"] = bicep_global.affine_inverse() * forearm_global

	var wrist_delta := Basis.from_euler(Vector3(
		deg_to_rad(wrist_rotation_degrees.x),
		deg_to_rad(wrist_rotation_degrees.y),
		deg_to_rad(wrist_rotation_degrees.z)))
	var wrist_global := Transform3D(
		base_wrist_global.basis * wrist_delta,
		wrist_target)
	pose[&"wrist.l"] = forearm_global.affine_inverse() * wrist_global
	return pose


func _solve_elbow(
		shoulder: Vector3,
		wrist: Vector3,
		elbow_hint: Vector3,
		upper_length: float,
		forearm_length: float) -> Vector3:
	var target_offset := wrist - shoulder
	var target_distance := clampf(
		target_offset.length(),
		absf(upper_length - forearm_length) + 0.001,
		upper_length + forearm_length - 0.001)
	var target_direction := target_offset.normalized()
	var along := (
		upper_length * upper_length
		- forearm_length * forearm_length
		+ target_distance * target_distance) / (2.0 * target_distance)
	var height := sqrt(maxf(upper_length * upper_length - along * along, 0.0))
	var center := shoulder + target_direction * along
	var pole_offset := elbow_hint - center
	var perpendicular := pole_offset - target_direction * pole_offset.dot(
		target_direction)
	if perpendicular.length_squared() < 0.0001:
		perpendicular = target_direction.cross(Vector3.UP)
		if perpendicular.length_squared() < 0.0001:
			perpendicular = target_direction.cross(Vector3.RIGHT)
	return center + perpendicular.normalized() * height


func _align_basis(
		base_basis: Basis,
		from_direction: Vector3,
		to_direction: Vector3) -> Basis:
	return Basis(Quaternion(from_direction, to_direction)) * base_basis


func _apply_finger_curl(pose: Dictionary, curl: float) -> void:
	for bone_name in FINGER_BONES:
		var base := pose[bone_name] as Transform3D
		var segment := 1
		if "2.l" in String(bone_name):
			segment = 2
		elif "3.l" in String(bone_name):
			segment = 3
		var bend: float = [0.0, -32.0, -52.0, -38.0][segment] * curl
		var spread := 0.0
		if segment == 1:
			spread = (8.0 if "index" in String(bone_name) else -5.0) \
				* (1.0 - curl)
		if "thumb" in String(bone_name):
			bend *= 0.65
			spread = 18.0 * curl
		var delta := Basis.from_euler(Vector3(
			deg_to_rad(bend), deg_to_rad(spread), 0.0))
		pose[bone_name] = Transform3D(base.basis * delta, base.origin)


func _add_transform_tracks(
		animation: Animation,
		bone_name: StringName,
		poses: Array[Dictionary]) -> void:
	var path := NodePath(TRACK_PREFIX + String(bone_name))
	var position_track := animation.add_track(Animation.TYPE_POSITION_3D)
	animation.track_set_path(position_track, path)
	animation.track_set_interpolation_type(
		position_track, Animation.INTERPOLATION_CUBIC)
	var rotation_track := animation.add_track(Animation.TYPE_ROTATION_3D)
	animation.track_set_path(rotation_track, path)
	animation.track_set_interpolation_type(
		rotation_track, Animation.INTERPOLATION_CUBIC_ANGLE)
	for phase in PHASE_TIMES.size():
		var transform := poses[phase][bone_name] as Transform3D
		animation.position_track_insert_key(
			position_track, PHASE_TIMES[phase], transform.origin)
		animation.rotation_track_insert_key(
			rotation_track,
			PHASE_TIMES[phase],
			transform.basis.get_rotation_quaternion().normalized())


func _base_global_poses() -> Dictionary[int, Transform3D]:
	var globals: Dictionary[int, Transform3D] = {}
	for bone in _skeleton.get_bone_count():
		var parent := _skeleton.get_bone_parent(bone)
		var local := _sample_base_local(bone)
		globals[bone] = globals[parent] * local if parent >= 0 else local
	return globals


func _bone(bone_name: StringName) -> int:
	var bone := _skeleton.find_bone(bone_name)
	assert(bone >= 0, "Missing journal animation bone: %s" % bone_name)
	return bone


func _print_chain_pose() -> void:
	var globals: Dictionary[int, Transform3D] = {}
	for bone in _skeleton.get_bone_count():
		var parent := _skeleton.get_bone_parent(bone)
		var local := _sample_base_local(bone)
		globals[bone] = globals[parent] * local if parent >= 0 else local
	for bone_name in [
			&"shoulder.l", &"bicep.l", &"forearm.l", &"wrist.l"]:
		var bone := _skeleton.find_bone(bone_name)
		print(
			bone_name,
			" index=", bone,
			" parent=", _skeleton.get_bone_name(
				_skeleton.get_bone_parent(bone)),
			" local_origin=", _sample_base_local(bone).origin,
			" global_origin=", globals[bone].origin,
			" global_euler=", globals[bone].basis.get_euler())


func _sample_base_local(bone: int) -> Transform3D:
	var path := NodePath(TRACK_PREFIX + _skeleton.get_bone_name(bone))
	var rest := _skeleton.get_bone_rest(bone)
	var position := rest.origin
	var rotation := rest.basis.get_rotation_quaternion()
	var position_track := _base_animation.find_track(
		path, Animation.TYPE_POSITION_3D)
	var rotation_track := _base_animation.find_track(
		path, Animation.TYPE_ROTATION_3D)
	if position_track >= 0:
		position = _base_animation.position_track_interpolate(
			position_track, 0.0)
	if rotation_track >= 0:
		rotation = _base_animation.rotation_track_interpolate(
			rotation_track, 0.0)
	return Transform3D(Basis(rotation), position)
