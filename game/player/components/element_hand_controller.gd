class_name ElementHandController
extends Node

## Owns elemental essence carried in the wizard's left hand.
## Wizard Sight requests source transfers and CastingController requests an
## atomic take when Hurl fires, but neither system owns the carried element.

signal element_changed(element: Element)
signal element_grabbed(element: Element, source: ElementSource)
signal element_placed(element: Element, source: ElementSource)
signal element_consumed(element: Element)

@export_group("Presentation")
@export var held_effect_scene: PackedScene
@export var siphon_stream_scene: PackedScene
@export var siphon_burst_scene: PackedScene
@export var transfer_sound: AudioStream
@export var draw_loop_sound: AudioStream
@export var rip_sound: AudioStream
@export var carry_loop_sound: AudioStream
@export var place_sound: AudioStream

@export_group("Feel")
## Degrees of camera FOV punch when the rip lands.
@export var rip_fov_kick := 1.6
## How far carried essence trails hand motion (seconds of velocity).
@export var held_lag_strength := 0.045

var _player: WizardPlayer
var _camera: Camera3D
var _base_fov := 0.0
var _left_anchor: Node3D
var _left_arm_anim: AnimationPlayer
var _held_effect: Node3D
var _held_element: Element
var _prev_anchor_position := Vector3.ZERO
var _lag_offset := Vector3.ZERO
var _journal_arm_animation: StringName = &""
var _journal_arm_stowing: bool = false
var _journal_arm_completed: bool = false
var _journal_arm_last_progress: float = -1.0

@onready var _transfer_audio: AudioStreamPlayer = $TransferAudio
@onready var _draw_audio: AudioStreamPlayer = $DrawAudio
@onready var _carry_audio: AudioStreamPlayer = $CarryAudio


func _ready() -> void:
	_player = owner as WizardPlayer
	assert(_player != null, "ElementHandController must live under a WizardPlayer.")
	_camera = _player.get_node_or_null(^"Head/Camera3D") as Camera3D
	if _camera == null:
		return
	_base_fov = _camera.fov
	_left_anchor = _camera.get_node_or_null(
		^"Viewmodel/WizardArms/arms/Skeleton3D/LeftHandAttachment/SpellAnchor") as Node3D
	if _left_anchor == null:
		_left_anchor = _camera.get_node_or_null(^"Viewmodel/LeftHandAnchor") as Node3D
	_left_arm_anim = _camera.get_node_or_null(
		^"Viewmodel/WizardArms/LeftAnimationPlayer") as AnimationPlayer
	if _left_arm_anim != null:
		_left_arm_anim.animation_finished.connect(_on_left_arm_anim_finished)
	if _transfer_audio != null:
		_transfer_audio.stream = transfer_sound
	if _draw_audio != null:
		_draw_audio.stream = draw_loop_sound
	if _carry_audio != null:
		_carry_audio.stream = carry_loop_sound


func _exit_tree() -> void:
	for audio in [_transfer_audio, _draw_audio, _carry_audio]:
		if audio != null:
			audio.stop()
			audio.stream = null


func _process(delta: float) -> void:
	_update_held_lag(delta)


func held_element() -> Element:
	return _held_element


func has_element() -> bool:
	return _held_element != null


## True when the held essence matches this empty vessel - the condition under
## which Sight treats the cast press as a pour-back hold instead of a refusal.
func can_place_into(source: ElementSource) -> bool:
	return source != null and not source.available() \
		and _elements_match(_held_element, source.element)


## The pull hold begins: tension you can hear. The draw loop's pitch rises with
## progress via on_pull_updated.
func on_pull_started(_source: ElementSource, _is_push: bool) -> void:
	if DisplayServer.get_name() == "headless" \
			or _draw_audio == null or _draw_audio.stream == null:
		return
	_draw_audio.pitch_scale = 0.85
	_draw_audio.play()


func on_pull_updated(_source: ElementSource, progress: float) -> void:
	if _draw_audio != null and _draw_audio.playing:
		_draw_audio.pitch_scale = 0.85 + 0.6 * clampf(progress, 0.0, 1.0)


func on_pull_canceled(_source: ElementSource) -> void:
	if _draw_audio != null:
		_draw_audio.stop()


## Handles the single Sight action according to the current hand and vessel.
func interact_with_source(source: ElementSource) -> void:
	if source == null:
		WizardHud.toast(self, "No elemental source answers your sight")
		return
	if _held_element == null:
		_grab_from(source)
	else:
		_place_into(source)


## Atomically transfers the carried element to an attack.
## A null result means Hurl must remain primed.
func take_for_hurl() -> Element:
	if _held_element == null:
		return null
	var element := _held_element
	_held_element = null
	_clear_held_effect()
	if _carry_audio != null:
		_carry_audio.stop()
	element_changed.emit(null)
	element_consumed.emit(element)
	return element


## Restores ownership if a configured Hurl expression fails to initialize.
func restore_from_failed_hurl(element: Element) -> void:
	if element == null or _held_element != null:
		return
	_held_element = element
	_spawn_held_effect(element)
	_start_carry_audio()
	element_changed.emit(element)


func hand_position() -> Vector3:
	if _left_anchor != null:
		return _left_anchor.global_position
	if _camera != null:
		return _camera.global_position
	return _player.global_position if _player != null else Vector3.ZERO


func _grab_from(source: ElementSource) -> void:
	if not source.available():
		WizardHud.toast(self, "That vessel is empty")
		return
	if source.element == null:
		WizardHud.toast(self, "That source has no readable nature")
		return
	_held_element = source.element
	_spawn_transfer_stream(source, false)
	_spawn_source_burst(source)
	_spawn_held_effect(_held_element)
	source.consume(hand_position())
	if _draw_audio != null:
		_draw_audio.stop()
	_play_transfer_sound(rip_sound)
	_start_carry_audio()
	_rip_kick()
	# The toast lands with the flame, not with the press - cause, then effect.
	_toast_later(source.consume_time,
		"%s gathered in your left hand" % _element_label(_held_element))
	element_changed.emit(_held_element)
	element_grabbed.emit(_held_element, source)


func _place_into(source: ElementSource) -> void:
	if source.available():
		WizardHud.toast(self, "Your left hand is already full")
		return
	if not _elements_match(_held_element, source.element):
		WizardHud.toast(self, "The vessel refuses foreign essence")
		return
	var placed := _held_element
	_spawn_transfer_stream(source, true)
	source.restore(hand_position())
	_held_element = null
	_clear_held_effect()
	if _draw_audio != null:
		_draw_audio.stop()
	if _carry_audio != null:
		_carry_audio.stop()
	_play_transfer_sound(place_sound)
	_toast_later(source.restore_time, "%s returned to its vessel" % _element_label(placed))
	element_changed.emit(null)
	element_placed.emit(placed, source)


## Pull streams source-to-hand; pushing back reverses the endpoints. Both ends
## are live Callables so the ribbon follows the hand mid-stride and the vessel's
## home point as the visual flies.
func _spawn_transfer_stream(source: ElementSource, reversed: bool) -> void:
	if siphon_stream_scene == null or source == null:
		return
	var stream := siphon_stream_scene.instantiate() as SiphonStream
	if stream == null:
		return
	var world: Node = get_tree().current_scene
	if world == null:
		world = get_tree().root
	world.add_child(stream)
	var source_point := func() -> Vector3:
		return source.siphon_point() if is_instance_valid(source) else Vector3.ZERO
	var hand_point := func() -> Vector3:
		return hand_position()
	var color := source.element.color if source.element != null else Color.WHITE
	if reversed:
		stream.setup(hand_point, source_point, color, source.restore_time)
	else:
		stream.setup(source_point, hand_point, color, source.consume_time)


func _spawn_source_burst(source: ElementSource) -> void:
	if siphon_burst_scene == null or source == null:
		return
	var burst := siphon_burst_scene.instantiate() as Node3D
	if burst == null:
		return
	var world: Node = get_tree().current_scene
	if world == null:
		world = get_tree().root
	world.add_child(burst)
	burst.global_position = source.siphon_point()
	if burst.has_method(&"set_color") and source.element != null:
		burst.call(&"set_color", source.element.color)


## The rip lands with a body: a quick FOV punch and a two-beat camera flinch.
func _rip_kick() -> void:
	if _camera == null or DisplayServer.get_name() == "headless":
		return
	var kick := create_tween()
	kick.tween_property(_camera, "fov", _base_fov + rip_fov_kick, 0.06)
	kick.tween_property(_camera, "fov", _base_fov, 0.26) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var flinch := create_tween()
	flinch.tween_property(_camera, "rotation:z", 0.006, 0.04)
	flinch.tween_property(_camera, "rotation:z", -0.004, 0.05)
	flinch.tween_property(_camera, "rotation:z", 0.0, 0.08)


func _spawn_held_effect(element: Element) -> void:
	_clear_held_effect(false)
	if _left_arm_anim != null and _left_arm_anim.has_animation(&"spell_held_left"):
		_left_arm_anim.play(&"spell_held_left")
	if _left_anchor == null or held_effect_scene == null:
		return
	_held_effect = held_effect_scene.instantiate() as Node3D
	if _held_effect == null:
		return
	_left_anchor.add_child(_held_effect)
	_prev_anchor_position = _left_anchor.global_position
	_lag_offset = Vector3.ZERO
	# Arrive small, overshoot, settle - the essence lands in the palm.
	_held_effect.scale = Vector3.ONE * 0.02
	var pop := _held_effect.create_tween()
	pop.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(_held_effect, "scale", Vector3.ONE * 0.7, 0.3).set_delay(0.05)
	element.apply_to(_held_effect)


## Carried essence trails the hand a few centimetres - secondary motion that
## gives the weightless flame a sense of mass.
func _update_held_lag(delta: float) -> void:
	if _held_effect == null or _left_anchor == null or delta <= 0.0:
		return
	var anchor_pos := _left_anchor.global_position
	var velocity := (anchor_pos - _prev_anchor_position) / delta
	_prev_anchor_position = anchor_pos
	var target := -velocity * held_lag_strength
	if target.length() > 0.08:
		target = target.normalized() * 0.08
	_lag_offset = _lag_offset.lerp(target, 1.0 - exp(-10.0 * delta))
	_held_effect.position = _left_anchor.global_transform.basis.inverse() * _lag_offset


func _clear_held_effect(lower_hand: bool = true) -> void:
	if _held_effect != null:
		_held_effect.queue_free()
		_held_effect = null
	if lower_hand and _held_element == null and _left_arm_anim != null \
			and _left_arm_anim.has_animation(&"Reset_left"):
		_left_arm_anim.play(&"Reset_left")


func _play_transfer_sound(preferred: AudioStream = null) -> void:
	if DisplayServer.get_name() == "headless" or _transfer_audio == null:
		return
	var chosen := preferred if preferred != null else transfer_sound
	if chosen == null:
		return
	_transfer_audio.stream = chosen
	_transfer_audio.play()


func _start_carry_audio() -> void:
	if DisplayServer.get_name() == "headless" \
			or _carry_audio == null or _carry_audio.stream == null:
		return
	_carry_audio.play()


## Effect before cause reads wrong: transfer toasts wait for the visual to
## land instead of answering the input edge.
func _toast_later(delay: float, message: String) -> void:
	get_tree().create_timer(maxf(delay, 0.01)).timeout.connect(func() -> void:
		if is_inside_tree():
			WizardHud.toast(self, message))


func play_journal_summon_animation(animation_name: StringName) -> void:
	if _left_arm_anim == null or not _left_arm_anim.has_animation(animation_name):
		return
	_journal_arm_animation = animation_name
	_journal_arm_stowing = false
	_journal_arm_completed = false
	_journal_arm_last_progress = 0.0
	_left_arm_anim.play(animation_name)


func play_journal_stow_animation(animation_name: StringName) -> void:
	if _left_arm_anim == null or not _left_arm_anim.has_animation(animation_name):
		return
	_journal_arm_animation = animation_name
	_journal_arm_stowing = true
	_journal_arm_completed = false
	_journal_arm_last_progress = 1.0
	_left_arm_anim.play_backwards(animation_name)


func journal_animation_progress(animation_name: StringName) -> float:
	if _left_arm_anim == null or _journal_arm_animation != animation_name:
		return -1.0
	if _journal_arm_completed:
		return 0.0 if _journal_arm_stowing else 1.0
	if _left_arm_anim.current_animation != animation_name:
		return _journal_arm_last_progress
	var animation_length := _left_arm_anim.current_animation_length
	if animation_length <= 0.0:
		return -1.0
	_journal_arm_last_progress = clampf(
		_left_arm_anim.current_animation_position / animation_length, 0.0, 1.0)
	return _journal_arm_last_progress


func restore_animation() -> void:
	_journal_arm_animation = &""
	_journal_arm_completed = false
	_journal_arm_last_progress = -1.0
	if _left_arm_anim == null:
		return
	if _held_element != null and _left_arm_anim.has_animation(&"spell_carry_left"):
		_left_arm_anim.play(&"spell_carry_left")
	elif _left_arm_anim.has_animation(&"Reset_left"):
		_left_arm_anim.play(&"Reset_left")


func _on_left_arm_anim_finished(animation_name: StringName) -> void:
	if animation_name == _journal_arm_animation:
		_journal_arm_completed = true
		_journal_arm_last_progress = 0.0 if _journal_arm_stowing else 1.0
	if _held_element != null and animation_name == &"spell_held_left" \
			and _left_arm_anim.has_animation(&"spell_held_end_left"):
		_left_arm_anim.play(&"spell_held_end_left")
	elif _held_element != null and animation_name == &"spell_held_end_left" \
			and _left_arm_anim.has_animation(&"spell_carry_left"):
		_left_arm_anim.play(&"spell_carry_left")
	elif animation_name == &"Reset_left":
		_left_arm_anim.stop()


func _elements_match(a: Element, b: Element) -> bool:
	if a == null or b == null:
		return false
	return a == b or (a.id != &"" and a.id == b.id)


func _element_label(element: Element) -> String:
	if element == null:
		return "Essence"
	var label := element.display_name if not element.display_name.is_empty() else String(element.id)
	return label.capitalize()
