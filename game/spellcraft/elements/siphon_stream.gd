class_name SiphonStream
extends GPUParticles3D

## A stream of element-tinted wisps drawn out of a source toward the caster while
## siphoning. The caster positions it at the source and points it at the camera
## each frame. It does not deplete the source - it is purely the visual of energy
## being pulled in.

func set_color(color: Color) -> void:
	var mat := process_material as ParticleProcessMaterial
	if mat != null:
		# Push past 1.0 so the wisps bloom against the scene glow.
		mat.color = Color(color.r * 2.0, color.g * 2.0, color.b * 2.0, 1.0)
