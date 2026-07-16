class_name CastingController
extends Node

## Drives the Arx-style casting flow. Holding cast_focus (RMB) for
## enable_sketching_state_time enters SKETCHING: the player is frozen from
## looking and mouse motion draws air-sigil strokes. Strokes fade and expire on
## a per-stroke lifetime, and recognition runs on every stroke lift over the
## still-live strokes. Recognizing a rune flares the ribbon and emits
## rune_recognized (the spell-forming state builds on top of this next).

signal rune_recognized(id: StringName, score: float)

const FOCUS_ANIM := &"cast_focus"

enum CASTING_STATE {
	IDLE,
	SKETCHING,
	SPELL_HELD,
}

@export var enable_sketching_state_time: float = 0.8
@export var sketching_cursor_sensitivity := 1.0
@export var sketching_min_distance_dedup := 4.0
@export var stroke_max_lifetime := 6.0
@export_range(0.0, 1.0, 0.01) var match_threshold := 0.75

@export_group("Audio")
## Looping hum played while a stroke is actively being traced. Its pitch and
## volume track the drawing speed, so a fast confident stroke sounds brighter.
@export_node_path("AudioStreamPlayer") var sketch_loop_audio_path: NodePath = ^"SketchLoopAudio"
## One-shot reward stinger fired the instant a rune locks in.
@export_node_path("AudioStreamPlayer") var rune_ignite_audio_path: NodePath = ^"RuneIgniteAudio"
@export var sketch_pitch_min := 0.82         ## pitch when the hand is nearly still
@export var sketch_pitch_max := 1.65         ## pitch at full draw speed
@export var sketch_speed_for_max_pitch := 2400.0  ## cursor px/sec that maps to max pitch
@export var sketch_volume_db := -7.0         ## loudest (moving) volume of the sketch hum
@export var sketch_quiet_db := -17.0         ## volume while a stroke is held still
@export var sketch_idle_db := -42.0          ## ducked bed when no stroke is being drawn; lower for near-silence

@export_group("Arm Idle")
@export var idle_bob_amount := 0.004        ## vertical breathing, metres
@export var idle_sway_amount := 0.003       ## horizontal drift, metres
@export var idle_rotation_degrees := 1.2    ## gentle tilt of the held pose
@export var idle_speed := 1.5               ## breaths per ~4 seconds

## Dev tool: while non-empty, releasing cast_focus saves the sketched strokes as
## a rune template named this instead of recognizing. Draw the rune, release,
## repeat for a couple of exemplars, then clear this field.
@export var template_recording_id := ""

var current_state: CASTING_STATE = CASTING_STATE.IDLE

var _player: WizardPlayer
var _hud: WizardHud
var _camera: Camera3D
var _recognizer: ShapeRecognizer
var _ribbon: SketchRibbon
var _arm_anim: AnimationPlayer
var _arms: Node3D
var _arm_base_transform: Transform3D
var _sketch_audio: AudioStreamPlayer
var _ignite_audio: AudioStreamPlayer
var _sketch_draw_speed := 0.0    ## smoothed cursor speed (px/sec) driving hum pitch
var _sketch_motion_accum := 0.0  ## cursor distance moved since the last frame
var _idle_time := 0.0
var sketching_state_time_accumulator: float = 0.0
var sketching_cursor_pos: Vector2
var _strokes: Array[SketchStroke] = []
var _active_stroke: SketchStroke = null

## The rune currently locked in for this session. Matching again (any rune)
## overrides it; a failed lift leaves it untouched.
var locked_rune_id: StringName = &""
var locked_rune_score := 0.0


func _ready() -> void:
	_player = owner as WizardPlayer
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as WizardPlayer
	assert(_player != null, "CastingController must live under a WizardPlayer.")

	_camera = _player.get_node_or_null("Head/Camera3D") as Camera3D
	_configure_recognizer()
	# The ribbon look is authored in sketch_ribbon.tscn, instanced under the
	# camera in player.tscn; the controller only drives it.
	if _camera != null:
		_ribbon = _camera.get_node_or_null("SketchRibbon") as SketchRibbon
		if _ribbon != null:
			_ribbon.visible = false
		_arm_anim = _camera.get_node_or_null(
			"Viewmodel/WizardArms/AnimationPlayer") as AnimationPlayer
		_arms = _camera.get_node_or_null("Viewmodel/WizardArms") as Node3D
		if _arms != null:
			# The authored mount transform; idle breathing modulates around it.
			_arm_base_transform = _arms.transform

	# Audio players are authored as children in player.tscn; the controller only
	# drives play/stop and live pitch/volume. All optional: a missing node is
	# simply silent.
	_sketch_audio = get_node_or_null(sketch_loop_audio_path) as AudioStreamPlayer
	_ignite_audio = get_node_or_null(rune_ignite_audio_path) as AudioStreamPlayer


func _process(delta: float) -> void:
	match current_state:
		CASTING_STATE.IDLE:
			_update_idle(delta)
		CASTING_STATE.SKETCHING:
			_update_sketching(delta)


func _input(event: InputEvent) -> void:
	# The arm-extend charge plays forward while cast_focus is held and rewinds
	# the moment it is released, regardless of state, so an early release smoothly
	# retracts and a hold-to-sketch finishes extended. Handled on the button
	# edges so it works in IDLE (before the threshold) too.
	if event.is_action_pressed("cast_focus"):
		_play_focus_animation(true)
	elif event.is_action_released("cast_focus"):
		_play_focus_animation(false)

	if current_state != CASTING_STATE.SKETCHING:
		return
	if event is InputEventMouseMotion:
		_on_sketch_motion((event as InputEventMouseMotion).relative)
	elif event.is_action_pressed("cast"):
		_begin_stroke()
	elif event.is_action_released("cast"):
		_end_stroke()


## Drives the arm-extend clip. Forward extends; reverse retracts from wherever
## the extend reached, so releasing mid-charge rewinds instead of snapping.
func _play_focus_animation(forward: bool) -> void:
	if _arm_anim == null or not _arm_anim.has_animation(FOCUS_ANIM):
		return
	if forward:
		_arm_anim.play(FOCUS_ANIM, -1.0, 1.0)
	else:
		# from_end only matters when starting fresh from the finished, fully
		# extended pose; mid-charge it continues from the current position.
		var from_end := _arm_anim.current_animation != FOCUS_ANIM
		_arm_anim.play(FOCUS_ANIM, -1.0, -1.0, from_end)


func _update_idle(delta: float) -> void:
	if Input.is_action_pressed("cast_focus"):
		sketching_state_time_accumulator += delta
		if sketching_state_time_accumulator >= enable_sketching_state_time:
			_set_state(CASTING_STATE.SKETCHING)
	else:
		sketching_state_time_accumulator = 0.0


func _update_sketching(delta: float) -> void:
	if not Input.is_action_pressed("cast_focus"):
		_set_state(CASTING_STATE.IDLE)
		return
	# Smooth the cursor speed (px/sec) drawn since last frame; drives hum pitch.
	var inst_speed := _sketch_motion_accum / maxf(delta, 0.0001)
	_sketch_motion_accum = 0.0
	_sketch_draw_speed = lerpf(_sketch_draw_speed, inst_speed, clampf(delta * 12.0, 0.0, 1.0))
	for i in range(_strokes.size() - 1, -1, -1):
		var stroke := _strokes[i]
		for j in stroke.point_ages.size():
			stroke.point_ages[j] += delta
		# Expire points from the front (oldest first) so ink drops off the tail.
		var drop := 0
		while drop < stroke.point_ages.size() and stroke.point_ages[drop] >= stroke_max_lifetime:
			drop += 1
		if drop > 0:
			stroke.points = stroke.points.slice(drop)
			stroke.point_ages = stroke.point_ages.slice(drop)
		# Keep the active stroke alive even if it fully expired (holding still),
		# so its reference stays valid; it re-seeds on the next point.
		if stroke.points.is_empty() and stroke != _active_stroke:
			_strokes.remove_at(i)
	_update_sketch_audio(delta)
	if _ribbon != null:
		var viewport_size := get_viewport().get_visible_rect().size
		_ribbon.rebuild(_strokes, _camera, viewport_size, stroke_max_lifetime)
		_ribbon.update_tip(
			sketching_cursor_pos, _camera, viewport_size, _active_stroke != null)
	_apply_arm_idle(delta)


## Subtle breathing on the fully extended arm so the held pose is not frozen.
## Layers a small parent-space bob, drift, and tilt on top of the mount so it
## composes with the skeletal pose the cast_focus clip is holding.
func _apply_arm_idle(delta: float) -> void:
	if _arms == null:
		return
	_idle_time += delta
	var breathe := sin(_idle_time * idle_speed)
	var drift := sin(_idle_time * idle_speed * 0.7 + 0.6)
	var tilt := deg_to_rad(idle_rotation_degrees)
	var transform := _arm_base_transform
	transform.origin += Vector3(drift * idle_sway_amount, breathe * idle_bob_amount, 0.0)
	transform.basis = Basis.from_euler(Vector3(
		breathe * tilt * 0.6, drift * tilt * 0.5, drift * tilt)) * _arm_base_transform.basis
	_arms.transform = transform


## Drives the looping sketch hum. The stream runs continuously for the whole
## sketching session (started in _enter_sketching, stopped in _exit_sketching);
## this only rides its pitch and volume so it never restarts mid-rune. Volume
## swells with draw speed while a stroke is active and ducks to sketch_idle_db
## between strokes. Frame-driven (move_toward) so nothing fights a tween.
func _update_sketch_audio(delta: float) -> void:
	if _sketch_audio == null or not _sketch_audio.playing:
		return
	var pitch_t := clampf(_sketch_draw_speed / sketch_speed_for_max_pitch, 0.0, 1.0)
	_sketch_audio.pitch_scale = lerpf(sketch_pitch_min, sketch_pitch_max, pitch_t)
	var target_db := sketch_idle_db
	if _active_stroke != null:
		# Ease between the still and moving levels by a gentler speed ramp.
		var vol_t := clampf(_sketch_draw_speed / (sketch_speed_for_max_pitch * 0.4), 0.0, 1.0)
		target_db = lerpf(sketch_quiet_db, sketch_volume_db, vol_t)
	_sketch_audio.volume_db = move_toward(_sketch_audio.volume_db, target_db, delta * 90.0)


func _set_state(next: CASTING_STATE) -> void:
	if next == current_state:
		return
	match current_state:
		CASTING_STATE.SKETCHING: _exit_sketching()
	current_state = next
	match next:
		CASTING_STATE.SKETCHING: _enter_sketching()


func _begin_stroke() -> void:
	_active_stroke = SketchStroke.new()
	_active_stroke.points.append(sketching_cursor_pos)
	_active_stroke.point_ages.append(0.0)
	_strokes.append(_active_stroke)


func _append_stroke_point() -> void:
	if _active_stroke == null:
		return
	if _active_stroke.points.is_empty():
		# Re-seed after the stroke's points all expired while held stationary.
		_active_stroke.points.append(sketching_cursor_pos)
		_active_stroke.point_ages.append(0.0)
		return
	var last := _active_stroke.points[_active_stroke.points.size() - 1]
	if last.distance_to(sketching_cursor_pos) < sketching_min_distance_dedup:
		return
	_active_stroke.points.append(sketching_cursor_pos)
	_active_stroke.point_ages.append(0.0)


func _end_stroke() -> void:
	_active_stroke = null
	_try_recognize()


## Runs recognition over the live unconsumed strokes on lift. A match locks the
## rune in and consumes its ink (still visible, fading in the recognized tint);
## drawing and matching again overrides the lock. A failed lift changes nothing.
func _try_recognize() -> void:
	if _recognizer == null:
		return
	if not template_recording_id.is_empty():
		return  # recording session: strokes are saved on cast_focus release instead
	var point_arrays := _stroke_point_arrays(true)
	if point_arrays.is_empty():
		return
	var point_total := 0
	for stroke in _strokes:
		if not stroke.consumed:
			point_total += stroke.points.size()
	var details := _recognizer.evaluate_detailed(point_arrays)
	var report := "Sketch lift: %d strokes, %d pts" % [point_arrays.size(), point_total]
	var result := {"id": &"", "score": 0.0}
	for candidate in details:
		report += " | %s=%.2f (stray %.1f, missing %.1f)" % [
			candidate["id"], candidate["score"],
			candidate["forward"], candidate["backward"]]
		if float(candidate["score"]) > float(result["score"]):
			result = candidate
	print(report)
	var score := float(result["score"])
	if score >= match_threshold:
		var overriding := locked_rune_id != &""
		locked_rune_id = result["id"]
		locked_rune_score = score
		for stroke in _strokes:
			stroke.consumed = true
		if _ribbon != null:
			_ribbon.mark_recognized()
		if _ignite_audio != null:
			_ignite_audio.play()
		WizardHud.toast(self, "%s rune %s (%d%%)" % [
			String(result["id"]).capitalize(),
			"overrides" if overriding else "ignites",
			int(roundf(score * 100.0))])
		rune_recognized.emit(result["id"], score)
		# TODO: audio cue + transition into the palm-up spell-forming state.


const AIR_TEMPLATE_DIR := "res://content/runes/air"


func _configure_recognizer() -> void:
	_recognizer = ShapeRecognizer.new()
	_load_recorded_templates()
	if _recognizer.template_count() > 0:
		return
	# Fallback exemplars in a 0..1 unit square (the recognizer bounding-box
	# normalizes, so they align with pixel-space input). Recorded templates
	# drawn through the real input path always beat these.
	_recognizer.add_template(&"triangle", [PackedVector2Array([
		Vector2(0.5, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0), Vector2(0.5, 0.0)])])
	_recognizer.add_template(&"bolt", [PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.0, 0.2), Vector2(0.0, 0.8), Vector2(1.0, 1.0)])])


func _load_recorded_templates() -> void:
	var dir := DirAccess.open(AIR_TEMPLATE_DIR)
	if dir == null:
		return
	for file_name in dir.get_files():
		if file_name.get_extension() != "json":
			continue
		var file := FileAccess.open(AIR_TEMPLATE_DIR + "/" + file_name, FileAccess.READ)
		if file == null:
			continue
		var data: Variant = JSON.parse_string(file.get_as_text())
		if not (data is Dictionary and data.has("id") and data.has("strokes")):
			push_warning("Skipping malformed rune template: %s" % file_name)
			continue
		var strokes: Array = []
		for stroke_data in (data["strokes"] as Array):
			var stroke := PackedVector2Array()
			for point_data in (stroke_data as Array):
				stroke.append(Vector2(float(point_data[0]), float(point_data[1])))
			strokes.append(stroke)
		_recognizer.add_template(StringName(String(data["id"])), strokes)


## Saves the current live strokes as a template exemplar drawn through the real
## input path. Editor-time authoring only (res:// is read-only in exports).
func _save_template() -> void:
	if _strokes.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(AIR_TEMPLATE_DIR)
	var stroke_data: Array = []
	for stroke in _strokes:
		var point_data: Array = []
		for point in stroke.points:
			point_data.append([point.x, point.y])
		stroke_data.append(point_data)
	var path := "%s/%s_%d.json" % [
		AIR_TEMPLATE_DIR, template_recording_id, Time.get_ticks_msec()]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write rune template to %s" % path)
		return
	file.store_string(JSON.stringify({
		"id": template_recording_id,
		"strokes": stroke_data,
	}))
	file.close()
	_recognizer.add_template(StringName(template_recording_id), _stroke_point_arrays())
	WizardHud.toast(self, "Recorded '%s' template (%d strokes)" % [
		template_recording_id, _strokes.size()])


## Point arrays of the live strokes; recognition passes true so ink already
## consumed by a locked rune stays out of the next evaluation.
func _stroke_point_arrays(unconsumed_only := false) -> Array:
	var out: Array = []
	for stroke in _strokes:
		if unconsumed_only and stroke.consumed:
			continue
		out.append(stroke.points)
	return out


func _enter_sketching() -> void:
	_strokes.clear()
	_active_stroke = null
	locked_rune_id = &""
	locked_rune_score = 0.0
	_idle_time = 0.0
	_player.look_enabled = false
	sketching_cursor_pos = get_viewport().get_visible_rect().size * 0.5
	if _ribbon != null:
		_ribbon.clear()
		_ribbon.visible = true
	if _sketch_audio != null:
		# One continuous voice for the whole session; volume rides draw speed.
		_sketch_audio.volume_db = sketch_idle_db
		_sketch_audio.play()
	if _get_hud() != null:
		_hud.set_sketch_cursor(sketching_cursor_pos)
		_hud.show_sketch_cursor(true)


func _exit_sketching() -> void:
	if not template_recording_id.is_empty():
		_save_template()
	if _ribbon != null:
		_ribbon.clear()
		_ribbon.visible = false
	if _get_hud() != null:
		_hud.show_sketch_cursor(false)
	if _arms != null:
		# Restore the mount so the retract animation plays from a clean pose.
		_arms.transform = _arm_base_transform
	if _sketch_audio != null and _sketch_audio.playing:
		_sketch_audio.stop()
	_sketch_draw_speed = 0.0
	_sketch_motion_accum = 0.0
	_player.look_enabled = true
	sketching_state_time_accumulator = 0.0


func _on_sketch_motion(relative: Vector2) -> void:
	var bounds := get_viewport().get_visible_rect().size
	sketching_cursor_pos = (sketching_cursor_pos + relative * sketching_cursor_sensitivity) \
		.clamp(Vector2.ZERO, bounds)
	_sketch_motion_accum += relative.length() * sketching_cursor_sensitivity
	if _get_hud() != null:
		_hud.set_sketch_cursor(sketching_cursor_pos)
	_append_stroke_point()


func _get_hud() -> WizardHud:
	if _hud == null and _player != null:
		_hud = _player.hud
	return _hud
