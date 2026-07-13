extends SceneTree

## Captures the real tower pickup presentation for visual regression review.
## Run with a rendering display:
##   godot --path . -s tools/capture/capture_magical_grab.gd

const WATER_OUT := "/tmp/magical_grab_water.png"
const IDLE_OUT := "/tmp/magical_grab_arm_idle.png"
const GRAB_OUT := "/tmp/magical_grab_arm_grab.png"
const HAND_POSE_OUT := "/tmp/magical_grab_hand_pose.png"
const RELEASE_OUT := "/tmp/magical_grab_arm_release.png"
const FIRE_OUT := "/tmp/magical_grab_fire.png"
const BOOK_OUT := "/tmp/magical_grab_book.png"
const BOOK_READING_OUT := "/tmp/magical_grab_book_reading.png"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://game/world/levels/wizard_tower.tscn") as PackedScene
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame

	var player := scene.get_node("Player") as WizardPlayer
	var fountain := _find_by_type(scene, "FountainOfEndlessSpring")
	var torch := _find_by_type(scene, "TorchOfEternalFlame")
	var book := _find_by_type(scene, "Book") as Book
	if player == null or fountain == null or torch == null or book == null:
		push_error("Magical grab capture needs the tower player, fountain, torch, and book.")
		quit(1)
		return
	await _settle(24)
	var error := _save_viewport(IDLE_OUT)
	if error != OK:
		quit(error)
		return
	if OS.get_cmdline_user_args().has("--idle-only"):
		print("saved=", IDLE_OUT)
		quit()
		return

	fountain.call("interact", player, null)
	await _settle(18)
	error = _save_viewport(GRAB_OUT)
	if error != OK:
		quit(error)
		return
	await _settle(22)
	error = _save_viewport(WATER_OUT)
	if error != OK:
		quit(error)
		return
	player.hands.held_item.visible = false
	await process_frame
	error = _save_viewport(HAND_POSE_OUT)
	player.hands.held_item.visible = true
	if error != OK:
		quit(error)
		return
	player.hands.drop()
	await _settle(6)
	error = _save_viewport(RELEASE_OUT)
	if error != OK:
		quit(error)
		return
	await _settle(10)

	torch.call("interact", player, null)
	await _settle(40)
	error = _save_viewport(FIRE_OUT)
	if error != OK:
		quit(error)
		return
	player.hands.drop()
	await _settle(16)

	book.interact(player, null)
	await _settle(40)
	error = _save_viewport(BOOK_OUT)
	if error != OK:
		quit(error)
		return
	book.cast_from(player, player.get_viewport().get_camera_3d().global_transform)
	await _settle(30)
	error = _save_viewport(BOOK_READING_OUT)
	print("saved=", IDLE_OUT, ", ", GRAB_OUT, ", ", WATER_OUT, ", ", HAND_POSE_OUT, ", ", RELEASE_OUT, ", ", FIRE_OUT, ", ", BOOK_OUT, ", and ", BOOK_READING_OUT)
	quit(error)


func _settle(frame_count: int) -> void:
	for frame in frame_count:
		await process_frame


func _save_viewport(path: String) -> Error:
	return root.get_viewport().get_texture().get_image().save_png(path)


func _find_by_type(node: Node, type_name: String) -> Node:
	if node.get_script() != null and node.get_script().get_global_name() == type_name:
		return node
	for child in node.get_children():
		var found := _find_by_type(child, type_name)
		if found != null:
			return found
	return null
