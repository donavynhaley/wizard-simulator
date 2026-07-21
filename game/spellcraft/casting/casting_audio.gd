class_name CastingAudio
extends Node

## Owns the casting SFX players (authored as children in player.tscn) and the
## draw-speed modulation of the sketch hum. CastingController drives it through
## this small API so the state machine stays free of audio detail.

@export_node_path("AudioStreamPlayer") var sketch_loop_path: NodePath = ^"SketchLoopAudio"
@export_node_path("AudioStreamPlayer") var rune_ignite_path: NodePath = ^"RuneIgniteAudio"
@export_node_path("AudioStreamPlayer") var spell_fire_path: NodePath = ^"SpellFireAudio"

## Sketch hum: pitch and volume ride the drawing speed so a fast confident stroke
## sounds brighter and louder; it ducks to sketch_idle_db between strokes.
@export var sketch_pitch_min := 0.82               ## pitch when the hand is nearly still
@export var sketch_pitch_max := 1.65               ## pitch at full draw speed
@export var sketch_speed_for_max_pitch := 2400.0   ## cursor px/sec mapping to max pitch
@export var sketch_volume_db := -7.0               ## loudest (moving) level
@export var sketch_quiet_db := -17.0               ## while a stroke is held still
@export var sketch_idle_db := -42.0                ## bed when no stroke is being drawn

var _sketch: AudioStreamPlayer
var _ignite: AudioStreamPlayer
var _fire: AudioStreamPlayer
var _playback_enabled := true


func _ready() -> void:
	_playback_enabled = DisplayServer.get_name() != "headless"
	_sketch = get_node_or_null(sketch_loop_path) as AudioStreamPlayer
	_ignite = get_node_or_null(rune_ignite_path) as AudioStreamPlayer
	_fire = get_node_or_null(spell_fire_path) as AudioStreamPlayer


func _exit_tree() -> void:
	# Headless scenarios can free the player while one-shot WAV playback is
	# still active. Stop players explicitly so their playback resources release
	# before SceneTree teardown.
	for player in [_sketch, _ignite, _fire]:
		if player != null:
			player.stop()
			player.stream = null


## Starts the continuous sketch hum for a sketching session (ducked to idle).
func start_sketch() -> void:
	if _playback_enabled and _sketch != null:
		_sketch.volume_db = sketch_idle_db
		_sketch.play()


func stop_sketch() -> void:
	if _sketch != null and _sketch.playing:
		_sketch.stop()


## Rides the hum's pitch/volume each frame from the smoothed draw speed. Frame-
## driven (move_toward) so nothing fights a tween and holding still goes quiet.
func update_sketch(draw_speed: float, drawing: bool, delta: float) -> void:
	if _sketch == null or not _sketch.playing:
		return
	var pitch_t := clampf(draw_speed / sketch_speed_for_max_pitch, 0.0, 1.0)
	_sketch.pitch_scale = lerpf(sketch_pitch_min, sketch_pitch_max, pitch_t)
	var target_db := sketch_idle_db
	if drawing:
		var vol_t := clampf(draw_speed / (sketch_speed_for_max_pitch * 0.4), 0.0, 1.0)
		target_db = lerpf(sketch_quiet_db, sketch_volume_db, vol_t)
	_sketch.volume_db = move_toward(_sketch.volume_db, target_db, delta * 90.0)


## One-shot stinger when a rune locks in.
func play_ignite() -> void:
	if _playback_enabled and _ignite != null:
		_ignite.play()


## One-shot launch when a held spell fires.
func play_fire() -> void:
	if _playback_enabled and _fire != null:
		_fire.play()
