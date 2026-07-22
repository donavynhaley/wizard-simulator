class_name SiphonBurst
extends GPUParticles3D

## One-shot spark burst at the instant an element rips free of its vessel.
## Spawn, tint via set_color, and it cleans itself up.


func _ready() -> void:
	emitting = true
	get_tree().create_timer(lifetime * 1.3).timeout.connect(queue_free)


func set_color(color: Color) -> void:
	var mat := process_material as ParticleProcessMaterial
	if mat != null:
		mat.color = Color(color.r * 2.0, color.g * 2.0, color.b * 2.0, 1.0)
