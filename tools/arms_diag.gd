extends SceneTree

# Renders the player's arms from a third-person camera (in front of the player) to
# diagnose viewmodel orientation. Run WITH a display:
#   godot --path . -s tools/arms_diag.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := (load("res://legacy/scenes/levels/wizard_tower.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	for i in 4:
		await process_frame

	var player := scene.find_child("WizardPlayer", true, false) as Node3D
	var player_cam := scene.find_child("Camera3D", true, false) as Camera3D
	if player_cam:
		player_cam.current = false
	var cam := Camera3D.new()
	cam.fov = 55.0
	root.add_child(cam)
	cam.make_current()
	# Player faces -Z; view the arms from the front-right.
	var p := player.global_position
	cam.position = p + Vector3(1.6, 1.9, -2.4)
	cam.look_at(p + Vector3(0.0, 1.5, -0.9), Vector3.UP)
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png("user://arms_diag.png")
	print("rendered arms_diag")
	quit()
