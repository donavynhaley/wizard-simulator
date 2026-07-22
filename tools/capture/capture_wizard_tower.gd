extends SceneTree

const LEVEL_SCENE := preload("res://game/world/levels/wizard_tower.tscn")
const EXTERIOR_OUT := "/tmp/wizard_tower_godot_exterior.png"
const ENTRANCE_OUT := "/tmp/wizard_tower_godot_entrance.png"
const ENTRANCE_OPEN_OUT := "/tmp/wizard_tower_godot_entrance_open.png"
const GROUND_OUT := "/tmp/wizard_tower_godot_ground_floor.png"
const BASEMENT_OUT := "/tmp/wizard_tower_godot_basement.png"
const OBSERVATORY_OUT := "/tmp/wizard_tower_godot_observatory.png"


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
	var architecture := level.get_node(^"TowerArchitecture") as TowerArchitecture
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.visible = false
	player.hud.visible = false

	var camera := Camera3D.new()
	level.add_child(camera)
	camera.current = true
	camera.fov = 62.0

	camera.position = Vector3(24.0, 18.0, -29.0)
	camera.look_at(Vector3(0.0, 11.0, 0.0), Vector3.UP)
	await _settle()
	var capture_error := viewport.get_texture().get_image().save_png(EXTERIOR_OUT)
	print("saved=", EXTERIOR_OUT, " err=", capture_error)

	camera.fov = 52.0
	camera.position = Vector3(0.0, 1.7, 9.4)
	camera.look_at(Vector3(0.0, 1.5, 5.7), Vector3.UP)
	await _settle()
	capture_error = _first_error(
		capture_error,
		viewport.get_texture().get_image().save_png(ENTRANCE_OUT))
	print("saved=", ENTRANCE_OUT, " err=", capture_error)
	# The entrance is warded shut behind a starved Bind; feeding the lantern
	# (Case Minus One's feed_the_ward resolution) swings the door open.
	var ward_source := level.get_node(
		^"TowerArchitecture/GroundFloorProps/DoorLantern/MagicalFlame/FireSource") as ElementSource
	ward_source.restore(ward_source.global_position + Vector3.UP * 0.5)
	for _frame in 150:
		await physics_frame
	await _settle()
	capture_error = _first_error(
		capture_error,
		viewport.get_texture().get_image().save_png(ENTRANCE_OPEN_OUT))
	print("saved=", ENTRANCE_OPEN_OUT, " err=", capture_error)

	camera.fov = 72.0
	camera.position = Vector3(3.9, 1.72, 3.1)
	camera.look_at(Vector3(-0.2, 1.25, -0.2), Vector3.UP)
	await _settle()
	capture_error = _first_error(
		capture_error,
		viewport.get_texture().get_image().save_png(GROUND_OUT))
	print("saved=", GROUND_OUT, " err=", capture_error)

	architecture.reveal_basement()
	camera.fov = 68.0
	camera.position = Vector3(3.45, -2.45, -2.65)
	camera.look_at(Vector3(-1.65, -2.75, -0.1), Vector3.UP)
	await _settle()
	capture_error = _first_error(
		capture_error,
		viewport.get_texture().get_image().save_png(BASEMENT_OUT))
	print("saved=", BASEMENT_OUT, " err=", capture_error)

	camera.fov = 64.0
	camera.position = Vector3(3.8, 13.3, -3.6)
	camera.look_at(Vector3(0.0, 12.95, 0.0), Vector3.UP)
	await _settle()
	capture_error = _first_error(
		capture_error,
		viewport.get_texture().get_image().save_png(OBSERVATORY_OUT))
	print("saved=", OBSERVATORY_OUT, " err=", capture_error)
	quit(capture_error)


func _settle() -> void:
	await physics_frame
	for _frame in 10:
		await process_frame


func _first_error(current: Error, candidate: Error) -> Error:
	return candidate if current == OK else current
