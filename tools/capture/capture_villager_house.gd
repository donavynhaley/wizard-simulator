extends SceneTree

const LEVEL_SCENE := preload("res://game/world/levels/wizard_tower.tscn")
const APPROACH_OUT := "/tmp/villager_house_godot_approach.png"
const DOOR_OUT := "/tmp/villager_house_godot_door.png"
const DOOR_OPEN_OUT := "/tmp/villager_house_godot_door_open.png"
const PAIR_OUT := "/tmp/villager_house_godot_both_doors.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1400, 1000)
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var level := LEVEL_SCENE.instantiate() as Node3D
	viewport.add_child(level)
	var player := level.get_node(^"Player") as WizardPlayer
	var house := level.get_node(^"VillagerHouse") as VillagerHouse
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.visible = false
	player.hud.visible = false

	var camera := Camera3D.new()
	level.add_child(camera)
	camera.current = true
	camera.fov = 62.0

	# Tower and cottage together, from the approach.
	camera.position = Vector3(-2.0, 4.5, 26.0)
	camera.look_at(Vector3(5.0, 2.0, 10.0), Vector3.UP)
	await _settle()
	_save(viewport, APPROACH_OUT)

	# Eye-level in front of the cottage door.
	var door := house.entry_door
	var door_face := door.global_position + Vector3(-0.7, 0.3, 0.0) + door.global_transform.basis.z * -0.0
	camera.position = Vector3(3.4, 1.7, 17.5)
	camera.look_at(door_face, Vector3.UP)
	await _settle()
	_save(viewport, DOOR_OUT)

	# The same warded door, swung open.
	door.interact(player, door)
	await create_timer(1.5).timeout
	await _settle()
	_save(viewport, DOOR_OPEN_OUT)
	door.interact(player, door)
	await create_timer(1.5).timeout

	# Both link-spell endpoints in one frame: tower door and cottage door.
	camera.position = Vector3(4.2, 2.6, 20.5)
	camera.look_at(Vector3(3.0, 1.5, 9.5), Vector3.UP)
	await _settle()
	_save(viewport, PAIR_OUT)

	quit(0)


func _save(viewport: SubViewport, path: String) -> void:
	var capture_error := viewport.get_texture().get_image().save_png(path)
	print("saved=", path, " err=", capture_error)


func _settle() -> void:
	for _frame in 14:
		await process_frame
