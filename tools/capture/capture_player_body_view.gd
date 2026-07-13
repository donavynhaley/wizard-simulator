extends SceneTree

const OUT := "/tmp/player_body_view.png"


func _init() -> void:
	var scene := load("res://game/world/levels/wizard_tower.tscn") as PackedScene
	var world := scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	var player := world.get_node_or_null("Player")
	if player == null:
		print("NO_PLAYER")
		quit(1)
		return

	player.global_position = Vector3(0.0, 1.0, 5.5)
	player.rotation = Vector3.ZERO

	var head := player.get_node("Head") as Node3D
	head.rotation.x = deg_to_rad(-72.0)

	await physics_frame
	await process_frame
	await process_frame
	await process_frame

	var image := root.get_viewport().get_texture().get_image()
	var err := image.save_png(OUT)
	print("saved=", OUT, " err=", err, " size=", image.get_size())
	quit(err)
