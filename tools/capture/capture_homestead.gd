extends SceneTree

const LEVEL_SCENE := preload("res://game/world/levels/wizard_tower.tscn")
const OVERVIEW_OUT := "/tmp/wizard_homestead_godot_overview.png"
const HILL_OUT := "/tmp/wizard_homestead_godot_hill.png"
const PROFILE_OUT := "/tmp/wizard_homestead_godot_profile.png"
const FOREST_OUT := "/tmp/wizard_homestead_godot_forest.png"
const MOOD_OUT := "/tmp/wizard_homestead_godot_mood.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1200, 1400)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var level := LEVEL_SCENE.instantiate() as Node3D
	viewport.add_child(level)
	var player := level.get_node_or_null(^"Player") as Node3D
	if player != null:
		player.process_mode = Node.PROCESS_MODE_DISABLED
		player.visible = false
		var hud := player.get_node_or_null(^"WizardHUD") as CanvasLayer
		if hud != null:
			hud.visible = false

	var camera := Camera3D.new()
	level.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 960.0
	camera.position = Vector3(0.0, 500.0, 220.0)
	camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	camera.current = true

	await _settle()
	var overview_error := viewport.get_texture().get_image().save_png(OVERVIEW_OUT)
	print("saved=", OVERVIEW_OUT, " err=", overview_error)

	viewport.size = Vector2i(1400, 1000)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 55.0
	camera.position = Vector3(86.0, 72.0, -105.0)
	camera.look_at(Vector3(0.0, -2.0, 62.0), Vector3.UP)
	await _settle()
	var hill_error := viewport.get_texture().get_image().save_png(HILL_OUT)
	print("saved=", HILL_OUT, " err=", hill_error)

	var profile_ground_height := _ground_height(level, Vector2(0.0, 126.0))
	camera.fov = 43.0
	camera.position = Vector3(0.0, profile_ground_height + 1.8, 126.0)
	camera.look_at(Vector3(0.0, 3.5, 0.0), Vector3.UP)
	await _settle()
	var profile_error := viewport.get_texture().get_image().save_png(PROFILE_OUT)
	print("saved=", PROFILE_OUT, " err=", profile_error)

	var forest_trees := level.find_children("forest_tree_*", "MeshInstance3D", true, false)
	var forest_error := ERR_DOES_NOT_EXIST
	if not forest_trees.is_empty():
		var forest_target := (forest_trees[0] as MeshInstance3D).global_position
		var outward := Vector3(forest_target.x, 0.0, forest_target.z).normalized()
		var camera_horizontal := Vector2(
			forest_target.x + outward.x * 18.0,
			forest_target.z + outward.z * 18.0
		)
		var forest_ground_height := _ground_height(level, camera_horizontal)
		camera.fov = 55.0
		camera.position = Vector3(
			camera_horizontal.x,
			forest_ground_height + 2.0,
			camera_horizontal.y
		)
		camera.look_at(forest_target + Vector3(0.0, 2.4, 0.0), Vector3.UP)
		await _settle()
		forest_error = viewport.get_texture().get_image().save_png(FOREST_OUT)
		print("saved=", FOREST_OUT, " err=", forest_error)

	camera.fov = 58.0
	camera.position = Vector3(19.0, 6.0, -24.0)
	camera.look_at(Vector3(0.0, 5.5, 0.0), Vector3.UP)
	await _settle()
	var mood_error := viewport.get_texture().get_image().save_png(MOOD_OUT)
	print("saved=", MOOD_OUT, " err=", mood_error)
	var capture_error := overview_error
	if capture_error == OK:
		capture_error = hill_error
	if capture_error == OK:
		capture_error = profile_error
	if capture_error == OK:
		capture_error = forest_error
	if capture_error == OK:
		capture_error = mood_error
	quit(capture_error)


func _settle() -> void:
	await physics_frame
	for _frame in 8:
		await process_frame


func _ground_height(level: Node3D, horizontal_position: Vector2) -> float:
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(horizontal_position.x, 100.0, horizontal_position.y),
		Vector3(horizontal_position.x, -100.0, horizontal_position.y)
	)
	var hit := level.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		push_warning("No terrain below profile camera; using fallback height")
		return 0.0
	return (hit.position as Vector3).y
