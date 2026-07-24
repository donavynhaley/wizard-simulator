class_name Door
extends AnimatableBody3D

const LOCK_BREAK_STREAM := preload("res://assets/sounds/siphon_rip.wav")

@export_range(90.0, 120.0, 1.0) var open_angle_degrees := 105.0
## How the focus prompt names this door ("Open tower door", "Open cottage door").
@export var display_name := "tower door"
## Where a magical link's strand attaches, in the door's local space - lets the
## auto-provided anchor sit on the lock face instead of the hinge.
@export var link_attach_offset := Vector3.ZERO

@onready var _animation_player: AnimationPlayer = $AnimationPlayer

var open_progress := 0.0:
	set(value):
		open_progress = clampf(value, 0.0, 1.0)
		var eased_progress := smoothstep(0.0, 1.0, open_progress)
		rotation.y = deg_to_rad(open_angle_degrees) * eased_progress

var _is_open := false
var _is_bound := false
var _locked := false
var _lock_break_audio: AudioStreamPlayer3D


func _ready() -> void:
	open_progress = 0.0
	_ensure_link_anchor()


## Every door is a link sink a Bind can seal. Provide a LinkAnchor so links can
## reference the door directly, with no hand-placed anchor; a scene that authors
## its own anchor child opts out.
func _ensure_link_anchor() -> void:
	for child in get_children():
		if child is LinkAnchor:
			return
	var anchor := LinkAnchor.new()
	anchor.name = &"LinkAnchor"
	anchor.kind = &"door"
	anchor.attach_offset = link_attach_offset
	add_child(anchor)  # target() defaults to parent = this Door


## An arcane lock holds the door shut. A magical link drives this: while the
## lock is active the door will not budge; when the link releases it (its power
## restored), the lock breaks audibly and the door swings itself open.
func set_locked(locked: bool) -> void:
	if _locked == locked:
		return
	_locked = locked
	if not locked and _is_bound and not _is_open:
		_is_open = true
		_play_toward_target()
		_play_lock_break()


func is_locked() -> bool:
	return _locked


func _play_lock_break() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _lock_break_audio == null:
		_lock_break_audio = AudioStreamPlayer3D.new()
		_lock_break_audio.stream = LOCK_BREAK_STREAM
		_lock_break_audio.pitch_scale = 0.55
		_lock_break_audio.bus = &"SpellCast"
		add_child(_lock_break_audio)
	_lock_break_audio.play()


func bind_imported_door(hinge: Node3D, visual: Node3D) -> void:
	if hinge == null or visual == null:
		push_error("Door: bind_imported_door needs the Blender-authored hinge and visual.")
		return
	reparent(hinge, false)
	transform = Transform3D.IDENTITY
	visual.reparent(self, true)
	_is_bound = true
	# Maren woke this door. In Sight its silhouette breathes - in a theater
	# where everything is still, the alive thing moves (docs/awakened-objects.md).
	add_child(AwakenedPresence.new())


func interact(player: WizardPlayer, _collider: Object) -> void:
	if not _is_bound:
		return
	if _locked and not _is_open:
		WizardHud.toast(player, "An arcane lock holds the door fast")
		return
	_is_open = not _is_open
	_play_toward_target()


func focus_prompt(player: WizardPlayer, _collider: Object) -> String:
	if player == null or not _is_bound:
		return ""
	if _locked and not _is_open:
		return "The door is locked by arcane magic"
	return ("Close %s" if _is_open else "Open %s") % display_name


func is_open() -> bool:
	return _is_open


func _play_toward_target() -> void:
	var animation := _animation_player.get_animation(&"open")
	var playback_position := open_progress * animation.length
	var playback_speed := 1.0 if _is_open else -1.0
	_animation_player.play(&"open", -1.0, playback_speed, not _is_open)
	_animation_player.seek(playback_position, true)
