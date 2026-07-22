class_name TowerDoor
extends AnimatableBody3D

signal opened
signal closed

@export_range(90.0, 120.0, 1.0) var open_angle_degrees := 105.0

@onready var _animation_player: AnimationPlayer = $AnimationPlayer

var open_progress := 0.0:
	set(value):
		open_progress = clampf(value, 0.0, 1.0)
		var eased_progress := smoothstep(0.0, 1.0, open_progress)
		rotation.y = deg_to_rad(open_angle_degrees) * eased_progress

var _is_open := false
var _is_bound := false
var _sealed := false
var _seal_break_audio: AudioStreamPlayer3D


func _ready() -> void:
	_animation_player.animation_finished.connect(_on_animation_finished)
	open_progress = 0.0


## A warding binding holds the door while powered. When the ward starves the
## Seal breaks audibly and the door swings itself open - the tutorial's payoff.
func set_sealed(sealed: bool) -> void:
	if _sealed == sealed:
		return
	_sealed = sealed
	if not sealed and _is_bound and not _is_open:
		_is_open = true
		_play_toward_target()
		_play_seal_break()


func is_sealed() -> bool:
	return _sealed


func _play_seal_break() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _seal_break_audio == null:
		_seal_break_audio = AudioStreamPlayer3D.new()
		_seal_break_audio.stream = load("res://assets/sounds/siphon_rip.wav")
		_seal_break_audio.pitch_scale = 0.55
		_seal_break_audio.bus = &"SpellCast"
		add_child(_seal_break_audio)
	_seal_break_audio.play()


func bind_imported_door(hinge: Node3D, visual: Node3D) -> void:
	assert(hinge != null, "TowerDoor requires the Blender-authored hinge.")
	assert(visual != null, "TowerDoor requires the Blender-authored door visual.")
	reparent(hinge, false)
	transform = Transform3D.IDENTITY
	visual.reparent(self, true)
	_is_bound = true


func interact(player: WizardPlayer, _collider: Object) -> void:
	if not _is_bound:
		return
	if _sealed and not _is_open:
		WizardHud.toast(player, "The Seal holds the door fast")
		return
	_is_open = not _is_open
	_play_toward_target()


func focus_prompt(player: WizardPlayer, _collider: Object) -> String:
	if player == null or not _is_bound:
		return ""
	if _sealed and not _is_open:
		return "The door is warded shut"
	return "Close tower door" if _is_open else "Open tower door"


func is_open() -> bool:
	return _is_open


func _play_toward_target() -> void:
	var animation := _animation_player.get_animation(&"open")
	var playback_position := open_progress * animation.length
	var playback_speed := 1.0 if _is_open else -1.0
	_animation_player.play(&"open", -1.0, playback_speed, not _is_open)
	_animation_player.seek(playback_position, true)


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name != &"open":
		return
	if _is_open:
		opened.emit()
	else:
		closed.emit()
