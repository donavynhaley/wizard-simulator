class_name MoodLight
extends OmniLight3D

@export var base_energy: float = 1.0
@export var flicker_strength: float = 0.18
@export var flicker_speed: float = 2.5
@export var pulse_offset: float = 0.0


func _ready() -> void:
	light_energy = base_energy


func _process(_delta: float) -> void:
	var wave := sin(Time.get_ticks_msec() * 0.001 * flicker_speed + pulse_offset)
	var noise := sin(Time.get_ticks_msec() * 0.001 * flicker_speed * 2.73 + pulse_offset * 1.7) * 0.35
	light_energy = base_energy * (1.0 + (wave + noise) * flicker_strength)
