extends SceneTree

# Prints the exact local transform for PovPreviewCamera in wizard_arms.tscn so
# it matches the player's eye. Re-run after retuning the WizardArms mount
# transform in player.tscn, then paste the printed line into wizard_arms.tscn:
#   godot --headless --path . -s tools/authoring/solve_pov_preview_camera.gd


func _init() -> void:
	var scene := load("res://game/spellcraft/spellcraft_lab.tscn") as PackedScene
	var world := scene.instantiate()
	root.add_child(world)
	await process_frame
	var player_cam := world.get_node("Player/Head/Camera3D") as Camera3D
	var preview_cam := world.get_node(
		"Player/Head/Camera3D/Viewmodel/WizardArms/PovPreviewCamera") as Camera3D
	preview_cam.global_transform = player_cam.global_transform
	print("Paste into the PovPreviewCamera node in wizard_arms.tscn:")
	print("transform = ", var_to_str(preview_cam.transform).replace("\n", " "))
	quit(0)
