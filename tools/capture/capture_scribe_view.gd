extends SceneTree

## Renders the scribing composition (scroll, quill, rigged scribe arm) from
## the ScribeCamera and saves it for visual inspection. Needs a display:
##   godot --path . -s tools/capture/capture_scribe_view.gd

const OUT := "/tmp/scribe_view.png"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := (load("res://game/world/levels/wizard_tower.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame

	var player := scene.get_node("Player") as WizardPlayer
	var crafter := scene.find_child("RuneScribingStation", true, false)
	if player == null or crafter == null:
		print("MISSING player or crafter")
		quit(1)
		return

	crafter.interact(player, null)
	if not crafter._active:
		print("SCRIBING DID NOT START")
		quit(1)
		return

	# Park the quill mid-scroll so the grip pose reads clearly.
	crafter._last_cursor_point = Vector2(0.6, 0.55)
	for i in 20:
		await process_frame

	var image := root.get_viewport().get_texture().get_image()
	var err := image.save_png(OUT)
	print("saved=", OUT, " err=", err, " size=", image.get_size())
	quit(err)
