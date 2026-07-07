class_name Screamer
extends Node3D

## The "screamer" quirk: the spell works fine, it just screams every time.
## Synthesizes a descending shriek with an AudioStreamGenerator (no audio asset
## needed) and throws up a comic "AIEEE!" label. Headless runs skip the audio.

const DURATION := 0.55

var _player: AudioStreamPlayer3D
var _playback: AudioStreamGeneratorPlayback
var _phase := 0.0
var _time := 0.0


static func scream_at(world: Node, pos: Vector3) -> void:
	var screamer := Screamer.new()
	world.add_child(screamer)
	screamer.global_position = pos
	SpellVisuals.floating_text(world, pos, "AIEEE!", Color(1.0, 0.85, 0.4), 40)


func _ready() -> void:
	_player = AudioStreamPlayer3D.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = 0.2
	_player.stream = stream
	_player.unit_size = 6.0
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()


func _process(delta: float) -> void:
	_time += delta
	if _time > DURATION + 0.3:
		queue_free()
		return
	if _playback == null:
		return
	# Sawtooth sweep from shrill to indignant.
	var frames := _playback.get_frames_available()
	var freq := lerpf(1400.0, 300.0, clampf(_time / DURATION, 0.0, 1.0))
	for i in frames:
		_phase = fmod(_phase + freq / 22050.0, 1.0)
		var s := (_phase * 2.0 - 1.0) * 0.25
		if _time > DURATION:
			s *= maxf(0.0, 1.0 - (_time - DURATION) / 0.3)
		_playback.push_frame(Vector2(s, s))
