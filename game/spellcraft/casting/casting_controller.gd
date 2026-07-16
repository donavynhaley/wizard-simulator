class_name CastingController
extends Node

## Drives the Arx-style casting flow across three states:
##   IDLE       - holding cast_focus (RMB) for enable_sketching_state_time charges
##                the arm and enters SKETCHING.
##   SKETCHING  - the player is frozen from looking; mouse motion draws air-sigil
##                strokes. Recognition on each stroke lift locks a rune and
##                presents it (spell_held + palm effect); redrawing overrides and
##                swaps the presented spell. Releasing RMB commits the locked rune
##                (or cancels if none), so a wrong draw is never force-cast.
##   SPELL_HELD - the committed spell is held in the palm, settling to a casual
##                hold, until fired with a left click (cast).
## Audio lives in the CastingAudio child; the ribbon and arm clips are authored
## in their own scenes and only driven from here.

signal rune_recognized(id: StringName, score: float)
## Emitted when a held spell is fired (left click). The projectile/effect system
## acts on this; locked_rune_id/score identify which spell launched.
signal spell_cast(id: StringName, score: float)

const FOCUS_ANIM := &"cast_focus"
const SPELL_HELD_ANIM := &"spell_held"
const SPELL_END_ANIM := &"spell_held_end"
const SPELL_FIRE_ANIM := &"spell_cast"
const RESET_ANIM := &"Reset"
const AIR_TEMPLATE_DIR := "res://content/runes/air"

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

@export_group("Element Siphon")
## Radius (px) from the sketch cursor to a source's screen position to target it.
@export var siphon_cursor_radius := 60.0
## Seconds of dwelling the cursor over a source to pull its element in.
@export var siphon_dwell_time := 0.6
## Wisp stream drawn from a source toward the caster while siphoning.
@export var siphon_stream_scene: PackedScene

@export_group("Spell Held")
## Per-rune palm effects. A recognized rune spawns the matching scene at the
## palm anchor; a rune with no entry uses default_spell_effect.
@export var spell_effect_bindings: Array[SpellEffectBinding] = []
## Fallback effect when the recognized rune has no binding above.
@export var default_spell_effect: PackedScene
## Tint applied to the spawned effect for now; the element system overrides this.
@export var default_spell_color := Color(0.55, 0.28, 1.0)
## Beat held on the fired pose after the cast clip before the arm resets to rest.
@export var cast_reset_delay := 0.2

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

# Resolved scene nodes.
var _player: WizardPlayer
var _hud: WizardHud
var _camera: Camera3D
var _recognizer: ShapeRecognizer
var _ribbon: SketchRibbon
var _arm_anim: AnimationPlayer
var _arms: Node3D
var _arm_base_transform: Transform3D
var _spell_anchor: Node3D
var _audio: CastingAudio

# Sketching / spell runtime state.
var _spell_effect: Node3D
var _spell_cast: SpellCast       ## the active cast behaviour (bolt / ground AoE)
var _current_element: Element    ## element imbued this cast (null = neutral arcane)
var _siphon_target: ElementSource
var _siphon_dwell := 0.0
var _siphon_stream: Node3D
var _siphon_stream_source: ElementSource
var _ribbon_default_base: Color
var _spell_settled := false      ## true once spell_held_end has played (focus released)
var _spell_presented := false    ## true once spell_held has played this session (no replay on override)
var _focus_used := false         ## blocks auto-resketch while focus stays held after a cast
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


#region Lifecycle
func _ready() -> void:
	_player = owner as WizardPlayer
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as WizardPlayer
	assert(_player != null, "CastingController must live under a WizardPlayer.")

	_audio = get_node_or_null("CastingAudio") as CastingAudio
	_camera = _player.get_node_or_null("Head/Camera3D") as Camera3D
	_configure_recognizer()
	# The ribbon look is authored in sketch_ribbon.tscn, instanced under the
	# camera in player.tscn; the controller only drives it.
	if _camera != null:
		_ribbon = _camera.get_node_or_null("SketchRibbon") as SketchRibbon
		if _ribbon != null:
			_ribbon.visible = false
			_ribbon_default_base = _ribbon.base_color
		_arm_anim = _camera.get_node_or_null(
			"Viewmodel/WizardArms/AnimationPlayer") as AnimationPlayer
		if _arm_anim != null:
			# Chains the cast (spell_cast) clip into the Reset clip so the arm
			# eases home once the spell has launched.
			_arm_anim.animation_finished.connect(_on_arm_anim_finished)
		_arms = _camera.get_node_or_null("Viewmodel/WizardArms") as Node3D
		if _arms != null:
			# The authored mount transform; idle breathing modulates around it.
			_arm_base_transform = _arms.transform
		# Palm anchor rides the wrist bone; held-spell effects parent under it.
		_spell_anchor = _camera.get_node_or_null(
			"Viewmodel/WizardArms/arms/Skeleton3D/RightHandAttachment/SpellAnchor") as Node3D


func _process(delta: float) -> void:
	match current_state:
		CASTING_STATE.IDLE:
			_update_idle(delta)
		CASTING_STATE.SKETCHING:
			_update_sketching(delta)
		CASTING_STATE.SPELL_HELD:
			_update_spell_held(delta)


func _input(event: InputEvent) -> void:
	# The arm-extend charge plays forward while cast_focus is held and rewinds
	# the moment it is released, so an early release smoothly retracts and a
	# hold-to-sketch finishes extended. Handled on the button edges so it works
	# in IDLE (before the threshold) too.
	if event.is_action_pressed("cast_focus"):
		# A fresh focus press re-arms sketching; ignored while a spell is held.
		if current_state != CASTING_STATE.SPELL_HELD:
			_focus_used = false
			_play_focus_animation(true)
	elif event.is_action_released("cast_focus"):
		# Releasing focus: in SPELL_HELD it settles into the casual hold; in
		# SKETCHING with a locked rune it commits (spell_held drives the arm, so
		# skip the retract); otherwise it retracts the charge-up arm.
		if current_state == CASTING_STATE.SPELL_HELD:
			_settle_spell_held()
		elif current_state == CASTING_STATE.SKETCHING and locked_rune_id != &"":
			pass
		else:
			_play_focus_animation(false)

	# A held spell fires on the next cast (left click), regardless of focus; the
	# spell stays in hand until then.
	if current_state == CASTING_STATE.SPELL_HELD:
		if event.is_action_pressed("cast"):
			_fire_spell()
		return

	if current_state != CASTING_STATE.SKETCHING:
		return
	if event is InputEventMouseMotion:
		_on_sketch_motion((event as InputEventMouseMotion).relative)
	elif event.is_action_pressed("cast"):
		_begin_stroke()
	elif event.is_action_released("cast"):
		_end_stroke()
#endregion


#region State machine
func _set_state(next: CASTING_STATE) -> void:
	if next == current_state:
		return
	match current_state:
		CASTING_STATE.SKETCHING: _exit_sketching()
		CASTING_STATE.SPELL_HELD: _exit_spell_held()
	current_state = next
	match next:
		CASTING_STATE.SKETCHING: _enter_sketching()
		CASTING_STATE.SPELL_HELD: _enter_spell_held()


func _update_idle(delta: float) -> void:
	# _focus_used stays set until a fresh focus press, so firing a spell while
	# focus is still held does not immediately roll into a new sketch.
	if Input.is_action_pressed("cast_focus") and not _focus_used:
		sketching_state_time_accumulator += delta
		if sketching_state_time_accumulator >= enable_sketching_state_time:
			_set_state(CASTING_STATE.SKETCHING)
	else:
		sketching_state_time_accumulator = 0.0


func _enter_sketching() -> void:
	_strokes.clear()
	_active_stroke = null
	locked_rune_id = &""
	locked_rune_score = 0.0
	_spell_presented = false
	_clear_spell_cast()
	_current_element = null
	_siphon_target = null
	_siphon_dwell = 0.0
	_idle_time = 0.0
	_player.look_enabled = false
	sketching_cursor_pos = get_viewport().get_visible_rect().size * 0.5
	if _ribbon != null:
		_ribbon.clear()
		_ribbon.reset_ink_color()
		_ribbon.reset_tip_color()
		_ribbon.visible = true
	if _audio != null:
		_audio.start_sketch()
	if _get_hud() != null:
		_hud.set_sketch_cursor(sketching_cursor_pos)
		_hud.show_sketch_cursor(true)


func _update_sketching(delta: float) -> void:
	if not Input.is_action_pressed("cast_focus"):
		# Release commits: a locked rune forms the held spell; otherwise cancel.
		_set_state(CASTING_STATE.SPELL_HELD if locked_rune_id != &"" else CASTING_STATE.IDLE)
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
	if _audio != null:
		_audio.update_sketch(_sketch_draw_speed, _active_stroke != null, delta)
	_update_siphon(delta)
	if _ribbon != null:
		var viewport_size := get_viewport().get_visible_rect().size
		_ribbon.rebuild(_strokes, _camera, viewport_size, stroke_max_lifetime)
		# After siphoning, the cursor keeps emitting element embers even between
		# strokes, so the pulled element visibly follows the cursor.
		_ribbon.update_tip(
			sketching_cursor_pos, _camera, viewport_size,
			_active_stroke != null or _current_element != null)
	_apply_arm_idle(delta)


func _exit_sketching() -> void:
	if not template_recording_id.is_empty():
		_save_template()
	if _ribbon != null:
		_ribbon.clear()
		_ribbon.visible = false
	if _get_hud() != null:
		_hud.show_sketch_cursor(false)
		_hud.set_siphon_markers([])
	_siphon_target = null
	_siphon_dwell = 0.0
	_clear_siphon_stream()
	if _arms != null:
		# Restore the mount so the retract animation plays from a clean pose.
		_arms.transform = _arm_base_transform
	if _audio != null:
		_audio.stop_sketch()
	_sketch_draw_speed = 0.0
	_sketch_motion_accum = 0.0
	_player.look_enabled = true
	sketching_state_time_accumulator = 0.0


## Presents the forming spell for the locked rune: plays spell_held (once) and
## spawns or replaces the palm effect. Called on each match while still sketching,
## so overriding a rune swaps the held effect. Not committed until RMB releases.
func _present_held_spell() -> void:
	_spell_settled = false
	# Play spell_held only on the first match of the session; overriding just
	# swaps the palm effect without replaying the forming animation.
	if not _spell_presented:
		_spell_presented = true
		if _arm_anim != null and _arm_anim.has_animation(SPELL_HELD_ANIM):
			_arm_anim.play(SPELL_HELD_ANIM)
	_spawn_spell_effect(locked_rune_id)


## Commit (focus released with a locked rune): the spell was already presented on
## match, so just settle from the presenting pose into the casual hold.
func _enter_spell_held() -> void:
	_idle_time = 0.0
	if _spell_effect == null:
		_present_held_spell()
	_settle_spell_held()
	_spawn_spell_cast(locked_rune_id)


## Held indefinitely with the same procedural sway; only a left click fires it.
func _update_spell_held(delta: float) -> void:
	_apply_arm_idle(delta)
	if _spell_cast != null:
		_spell_cast.update_aim(delta)


## Focus released while holding: relax from the presenting pose into a casual
## hold. The orb stays in hand and the state persists until the spell fires.
func _settle_spell_held() -> void:
	if _spell_settled:
		return
	_spell_settled = true
	if _arm_anim != null and _arm_anim.has_animation(SPELL_END_ANIM):
		_arm_anim.play(SPELL_END_ANIM)


## Left click while a spell is held: launch it. Leaves SPELL_HELD, which plays
## spell_fire and clears the orb.
func _fire_spell() -> void:
	if _audio != null:
		_audio.play_fire()
	if _spell_cast != null:
		_spell_cast.cast()  # lock the aim; the result launches on resolve()
	spell_cast.emit(locked_rune_id, locked_rune_score)
	_focus_used = true
	_set_state(CASTING_STATE.IDLE)


func _exit_spell_held() -> void:
	if _arms != null:
		_arms.transform = _arm_base_transform
	# The orb rides the hand through the cast clip and is cleared when it finishes
	# (the launch moment). Without the clip there is no finish event, so clear now.
	if _arm_anim != null and _arm_anim.has_animation(SPELL_FIRE_ANIM):
		_arm_anim.play(SPELL_FIRE_ANIM)
	else:
		_clear_spell_effect()
		_resolve_spell_cast()
		_play_focus_animation(false)
#endregion


#region Strokes
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


func _on_sketch_motion(relative: Vector2) -> void:
	var bounds := get_viewport().get_visible_rect().size
	sketching_cursor_pos = (sketching_cursor_pos + relative * sketching_cursor_sensitivity) \
		.clamp(Vector2.ZERO, bounds)
	_sketch_motion_accum += relative.length() * sketching_cursor_sensitivity
	if _get_hud() != null:
		_hud.set_sketch_cursor(sketching_cursor_pos)
	_append_stroke_point()
#endregion


#region Element siphon
## While sketching, projects every on-screen element source to the cursor; dwelling
## over one pulls its element in - recolouring the rune and imbuing the spell.
func _update_siphon(delta: float) -> void:
	if _camera == null:
		return
	var cursor := sketching_cursor_pos
	var bounds := get_viewport().get_visible_rect().size
	var hovered: ElementSource = null
	var hovered_marker: Dictionary = {}
	var markers: Array = []
	for node in get_tree().get_nodes_in_group(ElementSource.GROUP):
		var src := node as ElementSource
		if src == null or src.element == null:
			continue
		var world_point := src.siphon_point()
		if _camera.is_position_behind(world_point):
			continue
		var screen := _camera.unproject_position(world_point)
		if screen.x < 0.0 or screen.y < 0.0 or screen.x > bounds.x or screen.y > bounds.y:
			continue
		var marker := {"pos": screen, "color": src.element.color, "progress": 0.0}
		markers.append(marker)
		if cursor.distance_to(screen) <= siphon_cursor_radius and hovered == null:
			hovered = src
			hovered_marker = marker
	if hovered != null:
		if hovered == _siphon_target:
			_siphon_dwell = minf(_siphon_dwell + delta, siphon_dwell_time)
		else:
			_siphon_target = hovered
			_siphon_dwell = 0.0
		var progress := _siphon_dwell / maxf(siphon_dwell_time, 0.01)
		hovered_marker["progress"] = progress
		_preview_ink(hovered.element, progress)
		if _siphon_dwell >= siphon_dwell_time:
			_lock_element(hovered.element)
	else:
		_siphon_target = null
		_siphon_dwell = 0.0
		_preview_ink(null, 0.0)
	_update_siphon_stream(hovered)
	if _get_hud() != null:
		_hud.set_siphon_markers(markers)


## Streams element wisps from the hovered source toward the caster while dwelling.
func _update_siphon_stream(target: ElementSource) -> void:
	if target != _siphon_stream_source:
		_clear_siphon_stream()
		_siphon_stream_source = target
		if target != null and siphon_stream_scene != null:
			var world: Node = get_tree().current_scene
			if world == null:
				world = get_tree().root
			_siphon_stream = siphon_stream_scene.instantiate() as Node3D
			if _siphon_stream != null:
				world.add_child(_siphon_stream)
				if _siphon_stream.has_method("set_color"):
					_siphon_stream.call("set_color", target.element.color)
	if _siphon_stream != null and _siphon_stream_source != null and _camera != null:
		var origin := _siphon_stream_source.siphon_point()
		_siphon_stream.global_position = origin
		if origin.distance_to(_camera.global_position) > 0.05:
			_siphon_stream.look_at(_camera.global_position, Vector3.UP)


func _clear_siphon_stream() -> void:
	if _siphon_stream != null:
		_siphon_stream.queue_free()
		_siphon_stream = null
	_siphon_stream_source = null


## Ramps the ribbon ink from the committed colour toward the previewed element by
## the dwell progress (or resets to arcane when nothing is being pulled).
func _preview_ink(preview: Element, progress: float) -> void:
	if _ribbon == null:
		return
	if _current_element == null and preview == null:
		_ribbon.reset_ink_color()
		return
	var committed: Color = _current_element.color if _current_element != null else _ribbon_default_base
	var ink := committed if preview == null else committed.lerp(preview.color, progress)
	_ribbon.set_ink_color(ink)


## Locks the pulled element in for this cast: recolours the ink fully and re-tints
## an already-presented orb, so pulling after drawing still works.
func _lock_element(imbued: Element) -> void:
	if imbued == _current_element:
		return
	_current_element = imbued
	if _ribbon != null:
		_ribbon.set_ink_color(imbued.color)
		_ribbon.set_tip_color(imbued.color)  # embers now trail the cursor in element colour
	if _spell_effect != null:
		imbued.apply_to(_spell_effect)
	var label := imbued.display_name if not imbued.display_name.is_empty() else String(imbued.id)
	WizardHud.toast(self, "%s siphoned" % label.capitalize())
#endregion


#region Recognition & templates
## Runs recognition over the live unconsumed strokes on lift. A match locks the
## rune in and consumes its ink (still visible, fading in the recognized tint);
## drawing and matching again overrides the lock, and releasing cast_focus later
## commits whatever is locked. A failed lift changes nothing.
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
		if _audio != null:
			_audio.play_ignite()
		WizardHud.toast(self, "%s rune %s (%d%%)" % [
			String(result["id"]).capitalize(),
			"overrides" if overriding else "ignites",
			int(roundf(score * 100.0))])
		rune_recognized.emit(result["id"], score)
		_present_held_spell()


func _configure_recognizer() -> void:
	_recognizer = ShapeRecognizer.new()
	_load_recorded_templates()
	# Hardcoded fallback for any rune without a recorded exemplar, so recording
	# one rune (e.g. circle) does not knock out the others. Recorded templates
	# (drawn through the real input path) always win when present.
	if not _recognizer.has_template(&"triangle"):
		_recognizer.add_template(&"triangle", [PackedVector2Array([
			Vector2(0.5, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0), Vector2(0.5, 0.0)])])


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
#endregion


#region Arm animation
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


## Once the cast (spell_cast) clip finishes, the spell launches (orb cleared),
## the fired pose is held briefly, then the Reset clip eases the arm back to
## rest. Skipped if a fresh action (e.g. a new charge) took over during the pause.
func _on_arm_anim_finished(anim_name: StringName) -> void:
	if anim_name != SPELL_FIRE_ANIM:
		return
	_clear_spell_effect()  # the orb launches as the cast clip ends
	_resolve_spell_cast()  # spawn the projectile / explosion at the launch moment
	if cast_reset_delay > 0.0:
		await get_tree().create_timer(cast_reset_delay).timeout
	if not is_instance_valid(_arm_anim) or not _arm_anim.has_animation(RESET_ANIM):
		return
	var current := _arm_anim.current_animation
	if current != "" and current != SPELL_FIRE_ANIM:
		return
	_arm_anim.play(RESET_ANIM)


## Subtle breathing on the fully extended arm so the held pose is not frozen.
## Layers a small parent-space bob, drift, and tilt on top of the mount so it
## composes with whichever skeletal pose (cast_focus or spell_held) is playing.
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
#endregion


#region Spell effects
## Instantiates the palm effect for a rune under the anchor: its binding if one
## exists, else default_spell_effect. Tinted via set_color for the element system.
func _spawn_spell_effect(rune_id: StringName) -> void:
	_clear_spell_effect()
	if _spell_anchor == null:
		return
	var scene: PackedScene = default_spell_effect
	for binding in spell_effect_bindings:
		if binding != null and binding.rune_id == rune_id and binding.effect_scene != null:
			scene = binding.effect_scene
			break
	if scene == null:
		return
	_spell_effect = scene.instantiate() as Node3D
	if _spell_effect == null:
		return
	_spell_anchor.add_child(_spell_effect)
	if _spell_effect.has_method("set_color"):
		_spell_effect.call("set_color", default_spell_color)
	if _current_element != null:
		_current_element.apply_to(_spell_effect)


func _clear_spell_effect() -> void:
	if _spell_effect != null:
		_spell_effect.queue_free()
		_spell_effect = null


## Instantiates the rune's cast behaviour (bolt, ground AoE, ...) and begins it.
func _spawn_spell_cast(rune_id: StringName) -> void:
	_clear_spell_cast()
	var scene := _cast_scene_for(rune_id)
	if scene == null:
		return
	_spell_cast = scene.instantiate() as SpellCast
	if _spell_cast == null:
		return
	add_child(_spell_cast)
	# Spawned projectiles/explosions live in the active scene so they outlive the
	# behaviour; fall back to the tree root if there is no current scene.
	var world: Node = get_tree().current_scene
	if world == null:
		world = get_tree().root
	_spell_cast.element = _current_element
	_spell_cast.begin(_camera, _spell_anchor, world, _player)


## Spawns the behaviour's result (projectile / explosion) at the launch moment,
## then frees it.
func _resolve_spell_cast() -> void:
	if _spell_cast != null:
		_spell_cast.resolve()
		_spell_cast.queue_free()
		_spell_cast = null


func _clear_spell_cast() -> void:
	if _spell_cast != null:
		_spell_cast.queue_free()
		_spell_cast = null


func _cast_scene_for(rune_id: StringName) -> PackedScene:
	for binding in spell_effect_bindings:
		if binding != null and binding.rune_id == rune_id:
			return binding.cast_scene
	return null
#endregion


#region Helpers
func _get_hud() -> WizardHud:
	if _hud == null and _player != null:
		_hud = _player.hud
	return _hud
#endregion
