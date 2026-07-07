extends SceneTree

# Renders the player's first-person view (to check the arms viewmodel) to
# user://pov.png. Run WITH a display:
#   godot --path . -s tools/render_pov.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := (load("res://legacy/scenes/levels/wizard_tower.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	for i in 6:
		await process_frame
	root.get_texture().get_image().save_png("user://pov.png")
	print("rendered pov (interact prompt)")

	# Open the door dialogue to capture the panel.
	var focused: Dictionary = scene.get("_focused")
	if not focused.is_empty():
		scene.call("_start_dialogue", focused)
	for i in 4:
		await process_frame
	root.get_texture().get_image().save_png("user://pov_dialogue.png")
	print("rendered pov_dialogue")
	quit()
