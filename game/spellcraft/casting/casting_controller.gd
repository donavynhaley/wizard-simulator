class_name CastingController
extends Node

## Drives air-traced rune casting: the RIGHT hand speaks the verb while the
## ElementHandController independently owns the elemental noun in the LEFT hand.
## Three states:
##   IDLE       - holding cast_focus (RMB) for enable_sketching_state_time charges
##                the arm and enters SKETCHING.
##   SKETCHING  - the player is frozen from looking; mouse motion draws air-sigil
##                strokes at sketch_time_scale (deliberate, never a pause).
##                Recognition on each stroke lift locks a rune and presents it
##                (spell_held + palm effect); redrawing overrides and swaps the
##                presented spell. Releasing RMB commits the locked rune (or
##                cancels if none), so a wrong trace is never force-cast.
##   SPELL_HELD - the traced verb waits in the right palm until used.
##                HURL requests the left hand's carried element and launches
##                that element's distinct attack expression.
## The held verb persists until used or dismissed (drop_item shakes it off; the
## left hand keeps its essence). Sight itself lives in the sibling
## SightController. Audio lives in the CastingAudio child; the ribbon and arm
## clips are authored in their own scenes and only driven from here.

## The player composition root answers this synchronously by atomically taking
## carried essence from ElementHandController and calling fire_hurl().
signal hurl_requested
## A decisive practice trace was saved as a personal exemplar (practice slate).
signal practice_recorded(id: StringName)

const FOCUS_ANIM := &"cast_focus"
const SPELL_HELD_ANIM := &"spell_held"
const SPELL_END_ANIM := &"spell_held_end"
const SPELL_FIRE_ANIM := &"spell_cast"
const RESET_ANIM := &"Reset"
const AIR_TEMPLATE_DIR := "res://content/runes/air"
const FEEDBACK_INTERVAL := 0.12         ## seconds between mid-trace resolves
const PERSONAL_TEMPLATE_LIMIT := 3      ## newest exemplars kept per verb on disk

enum CASTING_STATE {
	IDLE,
	SKETCHING,
	SPELL_HELD,
}

@export var enable_sketching_state_time: float = 0.8
@export var sketching_cursor_sensitivity := 1.0
@export var sketching_min_distance_dedup := 4.0
@export var stroke_max_lifetime := 6.0
## A lift commits to the best-matching verb when its score clears this floor
## and beats the best OTHER verb by match_margin. Relative, not absolute: with
## five known verbs, ambiguity is the failure that matters, not polish - the
## score itself lives on as the spell's stability tier (RuneGlyphs).
@export_range(0.0, 1.0, 0.01) var match_floor := 0.45
@export_range(0.0, 1.0, 0.01) var match_margin := 0.15
## Engine time scale while sketching: deliberate and slightly protected,
## never a pause menu (locked feel decision, game-bible.md).
@export_range(0.1, 1.0, 0.05) var sketch_time_scale := 0.7

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
## a rune template named this instead of recognizing. Trace the rune, release,
## repeat for a couple of exemplars, then clear this field.
@export var template_recording_id := ""

## Where personal exemplars from the practice slate live. Player data, so
## user:// (res:// is read-only in exports) and JSON, never a Resource format a
## player can write - loading .tres executes embedded script. Tests override it.
@export var personal_template_dir := "user://runes/air"

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
var _spell_settled := false      ## true once spell_held_end has played (focus released)
var _dismissing := false         ## true while a shake-off exit is in flight (no cast clip)
var _spell_presented := false    ## true once spell_held has played this session (no replay on override)
var _focus_used := false         ## blocks auto-resketch while focus stays held after a cast
var _focus_blocked_until_release := false
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

## The verb a practice slate is listening for. While set, a decisive trace of
## exactly this verb is also kept as a personal exemplar - the tower learning
## this wizard's hand (see PracticeSlate).
var practice_verb: StringName = &""

var _feedback_accum := 0.0


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


func _exit_tree() -> void:
	# Sketching slows global time and locks look; if the tree drops this node
	# mid-sketch (scene change, player freed) those must not leak.
	if current_state == CASTING_STATE.SKETCHING:
		Engine.time_scale = 1.0
		if _player != null:
			_player.look_enabled = true


func _input(event: InputEvent) -> void:
	if _player == null or not _player.control_enabled():
		return
	if event.is_action_released(&"cast_focus") and _focus_blocked_until_release:
		_focus_blocked_until_release = false
		sketching_state_time_accumulator = 0.0
		return
	if event.is_action_pressed(&"cast_focus") \
			and _player.sight != null and _player.sight.active:
		_focus_blocked_until_release = true
		sketching_state_time_accumulator = 0.0
		WizardHud.toast(self, "Lower Wizard Sight before tracing a rune")
		return
	# The arm-extend charge plays forward while cast_focus is held and rewinds
	# the moment it is released, so an early release smoothly retracts and a
	# hold-to-sketch finishes extended. Handled on the button edges so it works
	# in IDLE (before the threshold) too.
	if event.is_action_pressed("cast_focus"):
		# A fresh focus press re-arms sketching; ignored while a spell is held.
		if current_state != CASTING_STATE.SPELL_HELD:
			_flush_pending_cast()
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

	# Sight owns left click while active. With Sight down, Hurl asks the player
	# composition root for carried essence. Other verbs keep their primed state.
	if current_state == CASTING_STATE.SPELL_HELD:
		if event.is_action_pressed("cast"):
			if _player.sight != null and _player.sight.active:
				return
			if locked_rune_id == &"hurl":
				hurl_requested.emit()
			else:
				WizardHud.toast(self, "The rune stirs, but nothing answers")
		elif event.is_action_pressed("drop_item"):
			_dismiss_spell()
		return

	if current_state != CASTING_STATE.SKETCHING:
		return
	if _player.sight != null and _player.sight.active:
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
	if _focus_blocked_until_release:
		if not Input.is_action_pressed(&"cast_focus"):
			_focus_blocked_until_release = false
		sketching_state_time_accumulator = 0.0
		return
	# _focus_used stays set until a fresh focus press, so firing a spell while
	# focus is still held does not immediately roll into a new sketch.
	if Input.is_action_pressed("cast_focus") and not _focus_used:
		sketching_state_time_accumulator += delta
		if sketching_state_time_accumulator >= enable_sketching_state_time:
			_set_state(CASTING_STATE.SKETCHING)
	else:
		sketching_state_time_accumulator = 0.0


## Sight may coexist with a completed rune, but it cannot interrupt the
## right-click charge or active sketch that creates one.
func blocks_wizard_sight() -> bool:
	if current_state == CASTING_STATE.SKETCHING:
		return true
	if current_state == CASTING_STATE.SPELL_HELD:
		return false
	return Input.is_action_pressed(&"cast_focus") and not _focus_blocked_until_release


func _enter_sketching() -> void:
	_strokes.clear()
	_active_stroke = null
	locked_rune_id = &""
	locked_rune_score = 0.0
	_spell_presented = false
	_clear_spell_cast()
	_idle_time = 0.0
	Engine.time_scale = sketch_time_scale
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
	_update_trace_feedback(delta)
	if _audio != null:
		_audio.update_sketch(_sketch_draw_speed, _active_stroke != null, delta)
	if _ribbon != null:
		var viewport_size := get_viewport().get_visible_rect().size
		_ribbon.rebuild(_strokes, _camera, viewport_size, stroke_max_lifetime)
		_ribbon.update_tip(
			sketching_cursor_pos, _camera, viewport_size, _active_stroke != null)
	_apply_arm_idle(delta)


func _exit_sketching() -> void:
	Engine.time_scale = 1.0
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
	if _audio != null:
		_audio.stop_sketch()
	_sketch_draw_speed = 0.0
	_sketch_motion_accum = 0.0
	_feedback_accum = 0.0
	_player.look_enabled = true
	sketching_state_time_accumulator = 0.0


## Mid-trace "getting warmer" signal: every FEEDBACK_INTERVAL the live ink is
## resolved and the leading score drives the ribbon glow and hum voice, so a
## failing shape is corrected mid-stroke instead of discovered at the lift.
func _update_trace_feedback(delta: float) -> void:
	_feedback_accum += delta
	if _feedback_accum < FEEDBACK_INTERVAL:
		return
	_feedback_accum = 0.0
	if _recognizer == null:
		return
	var confidence := 0.0
	var point_arrays := _stroke_point_arrays(true)
	if not point_arrays.is_empty():
		var live := _recognizer.resolve(point_arrays, match_floor, match_margin)
		confidence = clampf(float(live["score"]), 0.0, 1.0)
		if live["decisive"]:
			confidence = 1.0
	if _ribbon != null:
		_ribbon.set_confidence(confidence)
	if _audio != null:
		_audio.set_confidence(confidence)


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


## Held indefinitely with the same procedural sway.
func _update_spell_held(delta: float) -> void:
	_apply_arm_idle(delta)


## Focus released while holding: relax from the presenting pose into a casual
## hold. The orb stays in hand and the state persists until the spell fires.
func _settle_spell_held() -> void:
	if _spell_settled:
		return
	_spell_settled = true
	if _arm_anim != null and _arm_anim.has_animation(SPELL_END_ANIM):
		_arm_anim.play(SPELL_END_ANIM)


## Completes the synchronous Hurl request after the player root transfers
## ownership of carried essence out of ElementHandController.
func fire_hurl(element: Element) -> bool:
	if current_state != CASTING_STATE.SPELL_HELD \
			or locked_rune_id != &"hurl" or element == null:
		return false
	if not _spawn_spell_cast(locked_rune_id, element):
		WizardHud.toast(self, "%s has no Hurl expression" % _element_label(element))
		return false
	if _audio != null:
		_audio.play_fire()
	if _spell_cast != null:
		_spell_cast.cast()  # lock the aim; the result launches on resolve()
	_focus_used = true
	_set_state(CASTING_STATE.IDLE)
	return true


func refuse_empty_hurl() -> void:
	WizardHud.toast(self, "Your left hand holds nothing to Hurl")


## A held verb was spent by another system - Sight forging or severing a link
## with a Bind or Sever rune. Clear it quietly, like a dismissal but without the
## "fades from your hand" toast (the link interaction speaks for itself).
func consume_held_rune() -> void:
	if current_state != CASTING_STATE.SPELL_HELD:
		return
	_dismissing = true
	_set_state(CASTING_STATE.IDLE)
	_dismissing = false


## Shake off the primed rune (drop_item): the verb dissipates uncast while the
## left hand keeps its essence.
func _dismiss_spell() -> void:
	_dismissing = true
	_set_state(CASTING_STATE.IDLE)
	_dismissing = false
	WizardHud.toast(self, "The rune fades from your hand")


func _exit_spell_held() -> void:
	if _arms != null:
		_arms.transform = _arm_base_transform
	if _dismissing:
		# Dismissal is not a launch: no cast clip, no projectile; just retract.
		_clear_spell_effect()
		_clear_spell_cast()
		locked_rune_id = &""
		locked_rune_score = 0.0
		_play_focus_animation(false)
		return
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


#region Element helpers
func _element_label(element: Element) -> String:
	if element == null:
		return "Essence"
	var label := element.display_name if not element.display_name.is_empty() else String(element.id)
	return label.capitalize()
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
	for candidate in details:
		report += " | %s=%.2f (stray %.1f, missing %.1f, shape %.2f)" % [
			candidate["id"], candidate["score"],
			candidate["forward"], candidate["backward"], candidate["spread_deficit"]]
	print(report)
	var resolution := _recognizer.resolve(point_arrays, match_floor, match_margin)
	var score := float(resolution["score"])
	if resolution["decisive"]:
		var id := resolution["id"] as StringName
		var overriding := locked_rune_id != &""
		locked_rune_id = id
		locked_rune_score = score
		for stroke in _strokes:
			stroke.consumed = true
		if _ribbon != null:
			_ribbon.mark_recognized()
		if _audio != null:
			_audio.play_ignite()
		WizardHud.toast(self, "%s rune %s, %s (%d%%)" % [
			String(id).capitalize(),
			"overrides" if overriding else "ignites",
			RuneGlyphs.stability_label(score),
			int(roundf(score * 100.0))])
		if practice_verb != &"" and id == practice_verb:
			_save_personal_template(id, point_arrays)
		_present_held_spell()
	elif score >= match_floor and resolution["second_id"] != &"":
		# A close call between two verbs is the one honest refusal left; name
		# them so the refusal teaches instead of reading as a dead input.
		WizardHud.toast(self, "The trace wavers between %s and %s" % [
			RuneGlyphs.display_name(resolution["id"] as StringName),
			RuneGlyphs.display_name(resolution["second_id"] as StringName)])


func _configure_recognizer() -> void:
	_recognizer = ShapeRecognizer.new()
	_load_template_dir(AIR_TEMPLATE_DIR)
	_load_template_dir(personal_template_dir)
	_register_fallback_glyphs()


## The five-verb glyph language (RuneGlyphs, game-bible.md rune table). Canon
## glyphs are ALWAYS registered: exemplars per verb coexist and the best match
## wins, so recorded and personal exemplars add leniency for a particular hand
## without ever suppressing the canonical form.
func _register_fallback_glyphs() -> void:
	for id in RuneGlyphs.VERBS:
		_recognizer.add_template(id, [RuneGlyphs.points(id)])


func _load_template_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file_name in dir.get_files():
		if file_name.get_extension() != "json":
			continue
		var file := FileAccess.open(path + "/" + file_name, FileAccess.READ)
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


## The tower learns this wizard's hand: keeps the strokes that just resolved
## decisively as a personal exemplar for the verb. Exemplars only ADD leniency:
## the recognizer keeps every template per verb and the best match wins, so the
## canon glyph keeps working alongside the player's own handwriting.
func _save_personal_template(id: StringName, point_arrays: Array) -> void:
	var err := DirAccess.make_dir_recursive_absolute(personal_template_dir)
	if err != OK:
		push_warning("Could not create %s: %s" % [
			personal_template_dir, error_string(err)])
		return
	var stroke_data: Array = []
	for stroke in point_arrays:
		var points_out: Array = []
		for point in (stroke as PackedVector2Array):
			points_out.append([point.x, point.y])
		stroke_data.append(points_out)
	var path := "%s/%s_%d_%d.json" % [personal_template_dir, id,
		int(Time.get_unix_time_from_system()), Time.get_ticks_msec()]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write personal rune template to %s" % path)
		return
	file.store_string(JSON.stringify({
		"version": 1,
		"id": String(id),
		"strokes": stroke_data,
	}))
	file.close()
	_recognizer.add_template(id, point_arrays)
	_prune_personal_templates(id)
	practice_recorded.emit(id)


## Keeps only the newest PERSONAL_TEMPLATE_LIMIT exemplars per verb on disk;
## filenames sort by their unix-time suffix.
func _prune_personal_templates(id: StringName) -> void:
	var dir := DirAccess.open(personal_template_dir)
	if dir == null:
		return
	var mine: Array[String] = []
	for file_name in dir.get_files():
		if file_name.begins_with("%s_" % id) and file_name.get_extension() == "json":
			mine.append(file_name)
	mine.sort()
	while mine.size() > PERSONAL_TEMPLATE_LIMIT:
		dir.remove(mine.pop_front())


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
		# A node-owned tween dies with the node, so this coroutine can never
		# resume against a freed controller (a SceneTree timer could).
		var pause := create_tween()
		pause.tween_interval(cast_reset_delay)
		await pause.finished
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
	# The rune orb stays colourless: essence lives in the LEFT hand, not the verb.
	if _spell_effect.has_method("set_color"):
		_spell_effect.call("set_color", default_spell_color)
	if _spell_effect.has_method("set_stability"):
		_spell_effect.call("set_stability", clampf(locked_rune_score, 0.0, 1.0))


func _clear_spell_effect() -> void:
	if _spell_effect != null:
		_spell_effect.queue_free()
		_spell_effect = null


## Instantiates the carried element's expression for Hurl and begins it.
func _spawn_spell_cast(rune_id: StringName, element: Element) -> bool:
	_clear_spell_cast()
	var scene := _cast_scene_for(rune_id, element)
	if scene == null:
		return false
	_spell_cast = scene.instantiate() as SpellCast
	if _spell_cast == null:
		return false
	add_child(_spell_cast)
	# Spawned projectiles/explosions live in the active scene so they outlive the
	# behaviour; fall back to the tree root if there is no current scene.
	var world: Node = get_tree().current_scene
	if world == null:
		world = get_tree().root
	_spell_cast.element = element
	_spell_cast.quality = clampf(locked_rune_score, 0.0, 1.0)
	_spell_cast.begin(_camera, _spell_anchor, world, _player)
	return true


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


## A fresh arm action can interrupt the spell_cast clip before its
## animation_finished callback runs; launch the pending result first so consumed
## essence always produces its projectile instead of dying unresolved.
func _flush_pending_cast() -> void:
	if _spell_cast == null:
		return
	if _arm_anim != null and _arm_anim.current_animation == SPELL_FIRE_ANIM:
		_clear_spell_effect()
		_resolve_spell_cast()


func _cast_scene_for(rune_id: StringName, element: Element) -> PackedScene:
	if rune_id == &"hurl" and element != null and element.hurl_cast_scene != null:
		return element.hurl_cast_scene
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
