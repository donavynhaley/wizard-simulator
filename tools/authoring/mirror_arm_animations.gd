extends SceneTree

## Generates left-hand animation clips for the wizard arms by mirroring the
## authored right-hand clips across the rig's X symmetry plane. Run headless:
##   godot --headless --path . -s tools/authoring/mirror_arm_animations.gd
##
## The rig's rest poses are NOT mirror-symmetric (differing bone rolls), so
## per-key local mirroring twists the arm. Instead each clip is SAMPLED: the
## right chain's global pose is computed per frame, reflected across X
## (proper conjugation, no handedness flip), and left-bone locals are
## re-derived against the actual left hierarchy. Emits "<name>_left" clips
## containing ONLY left-bone tracks, plus "spell_carry_left" - a looping hold
## of spell_held_end's final pose - so a second AnimationPlayer (later in
## tree order) can keep the carrying arm posed while right-hand clips play.
## Output: res://game/player/viewmodel/left_arm_animations.res

const SCENE_PATH := "res://game/player/viewmodel/wizard_arms.tscn"
const OUT_PATH := "res://game/player/viewmodel/left_arm_animations.res"
const SKELETON_TRACK_PREFIX := "arms/Skeleton3D:"
const SAMPLE_FPS := 30.0
const SOURCE_CLIPS: Array[String] = [
	"Reset", "cast_focus", "cast_focus_alt", "spell_cast", "spell_held", "spell_held_end"]
const CARRY_SOURCE := "spell_held_end"

var _skeleton: Skeleton3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var arms := (load(SCENE_PATH) as PackedScene).instantiate()
	root.add_child(arms)
	await process_frame
	_skeleton = arms.get_node("arms/Skeleton3D") as Skeleton3D
	var player := arms.get_node("AnimationPlayer") as AnimationPlayer

	_report_rest_symmetry()

	var library := AnimationLibrary.new()
	for clip_name in SOURCE_CLIPS:
		if not player.has_animation(clip_name):
			push_warning("Missing source clip: %s" % clip_name)
			continue
		var mirrored := _mirror_clip(player.get_animation(clip_name))
		library.add_animation(StringName(clip_name + "_left"), mirrored)
		print("mirrored %-16s -> %s_left (%d tracks)" % [
			clip_name, clip_name, mirrored.get_track_count()])
	if player.has_animation(CARRY_SOURCE):
		var carry := _final_pose_loop(_mirror_clip(player.get_animation(CARRY_SOURCE)))
		library.add_animation(&"spell_carry_left", carry)
		print("generated spell_carry_left (loop, %d tracks)" % carry.get_track_count())

	var err := ResourceSaver.save(library, OUT_PATH)
	if err != OK:
		push_error("Could not save %s (error %d)" % [OUT_PATH, err])
		quit(1)
		return
	print("Saved ", OUT_PATH)
	quit(0)


## Sanity report: world-space bone ORIGINS should mirror even though bone
## rolls do not. Large origin asymmetry would mean the mesh itself is not
## mirrored and the transfer cannot look right.
func _report_rest_symmetry() -> void:
	var worst := 0.0
	var worst_bone := ""
	for i in _skeleton.get_bone_count():
		var bone := _skeleton.get_bone_name(i)
		if not bone.ends_with(".r"):
			continue
		var left := _skeleton.find_bone(bone.trim_suffix(".r") + ".l")
		if left < 0:
			continue
		var right_origin := _skeleton.get_bone_global_rest(i).origin
		var left_origin := _skeleton.get_bone_global_rest(left).origin
		var mirrored := Vector3(-right_origin.x, right_origin.y, right_origin.z)
		var error := mirrored.distance_to(left_origin)
		if error > worst:
			worst = error
			worst_bone = bone
	print("rest origin symmetry: worst %.4f m at %s" % [worst, worst_bone])


## Right-side bone indices in hierarchy order (parents before children).
func _right_bones_in_order() -> Array[int]:
	var out: Array[int] = []
	for i in _skeleton.get_bone_count():
		if _skeleton.get_bone_name(i).ends_with(".r"):
			out.append(i)
	# get_bone_count order is already parent-first for this rig, but sort by
	# chain depth to be safe.
	out.sort_custom(func(a: int, b: int) -> bool:
		return _chain_depth(a) < _chain_depth(b))
	return out


func _chain_depth(bone: int) -> int:
	var depth := 0
	var current := _skeleton.get_bone_parent(bone)
	while current >= 0:
		depth += 1
		current = _skeleton.get_bone_parent(current)
	return depth


## Proper reflection of a transform across the X plane: B' = M B M keeps the
## basis right-handed, origin x negates.
func _reflect(transform: Transform3D) -> Transform3D:
	var m := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
	return Transform3D(m * transform.basis * m,
		Vector3(-transform.origin.x, transform.origin.y, transform.origin.z))


## The clip's local pose for a bone at time t, falling back to rest.
func _sample_local(anim: Animation, bone: int, t: float) -> Transform3D:
	var bone_path := NodePath(SKELETON_TRACK_PREFIX + _skeleton.get_bone_name(bone))
	var pose := _skeleton.get_bone_rest(bone)
	var pos_track := anim.find_track(bone_path, Animation.TYPE_POSITION_3D)
	var rot_track := anim.find_track(bone_path, Animation.TYPE_ROTATION_3D)
	var position := pose.origin
	var rotation := pose.basis.get_rotation_quaternion()
	if pos_track >= 0 and anim.track_get_key_count(pos_track) > 0:
		position = anim.position_track_interpolate(pos_track, t)
	if rot_track >= 0 and anim.track_get_key_count(rot_track) > 0:
		rotation = anim.rotation_track_interpolate(rot_track, t)
	return Transform3D(Basis(rotation), position)


## Mirrors one clip: sampled global reflection, left locals re-derived
## against the actual left hierarchy. Only left-bone tracks are emitted.
func _mirror_clip(source: Animation) -> Animation:
	var out := Animation.new()
	out.length = source.length
	out.loop_mode = source.loop_mode
	var right_bones := _right_bones_in_order()

	# One pos + rot track per left bone, keyed at every sample.
	var track_of := {}
	for right_bone in right_bones:
		var left_name := _skeleton.get_bone_name(right_bone).trim_suffix(".r") + ".l"
		var pos_track := out.add_track(Animation.TYPE_POSITION_3D)
		out.track_set_path(pos_track, NodePath(SKELETON_TRACK_PREFIX + left_name))
		var rot_track := out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(rot_track, NodePath(SKELETON_TRACK_PREFIX + left_name))
		track_of[right_bone] = [pos_track, rot_track]

	var sample_count := maxi(2, int(ceilf(source.length * SAMPLE_FPS)) + 1)
	for s in sample_count:
		var t := minf(source.length, s / SAMPLE_FPS)
		# Globals of every bone at t (locals sampled from the clip; bones the
		# clip does not key sit at rest).
		var globals := {}
		for bone in _skeleton.get_bone_count():
			var parent := _skeleton.get_bone_parent(bone)
			var local := _sample_local(source, bone, t)
			globals[bone] = (globals[parent] * local) if parent >= 0 else local
		# Left chain: target global is the reflected right global; the local is
		# taken against the left parent's target global (or the UNreflected
		# actual global for non-side parents like root).
		var left_globals := {}
		for right_bone in right_bones:
			var left_bone: int = _skeleton.find_bone(
				_skeleton.get_bone_name(right_bone).trim_suffix(".r") + ".l")
			var target: Transform3D = _reflect(globals[right_bone])
			var parent: int = _skeleton.get_bone_parent(left_bone)
			var parent_global: Transform3D
			if left_globals.has(parent):
				parent_global = left_globals[parent]
			elif parent >= 0:
				parent_global = globals[parent]
			else:
				parent_global = Transform3D.IDENTITY
			var local := parent_global.affine_inverse() * target
			left_globals[left_bone] = target
			var tracks: Array = track_of[right_bone]
			out.position_track_insert_key(tracks[0], t, local.origin)
			out.rotation_track_insert_key(tracks[1], t,
				local.basis.get_rotation_quaternion().normalized())
	return out


## Collapses a clip to a single-key looping hold of its final pose.
func _final_pose_loop(source: Animation) -> Animation:
	var out := Animation.new()
	out.length = 0.5
	out.loop_mode = Animation.LOOP_LINEAR
	for t in source.get_track_count():
		var key_count := source.track_get_key_count(t)
		if key_count == 0:
			continue
		var track_type := source.track_get_type(t)
		var final_value: Variant = source.track_get_key_value(t, key_count - 1)
		var new_track := out.add_track(track_type)
		out.track_set_path(new_track, source.track_get_path(t))
		match track_type:
			Animation.TYPE_POSITION_3D:
				out.position_track_insert_key(new_track, 0.0, final_value)
			Animation.TYPE_ROTATION_3D:
				out.rotation_track_insert_key(new_track, 0.0, final_value)
			Animation.TYPE_SCALE_3D:
				out.scale_track_insert_key(new_track, 0.0, final_value)
	return out
