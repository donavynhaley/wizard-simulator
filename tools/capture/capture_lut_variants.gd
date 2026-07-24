extends SceneTree
## Renders the tower with each palette-grade LUT (plus ungraded) so the
## candidates can be compared side by side. Run windowed, not --headless:
##   godot --path /home/donavynhaley/Repos/wizard-simulator -s tools/capture/capture_lut_variants.gd
## Saves /tmp/lut_<variant>_<view>.png

const LEVEL_SCENE := preload("res://game/world/levels/wizard_tower.tscn")

const VIEWS := [
	{
		"name": "exterior_day",
		"hour": 10.0,
		"fov": 62.0,
		"from": Vector3(24.0, 18.0, -29.0),
		"at": Vector3(0.0, 11.0, 0.0),
	},
	{
		"name": "interior_night",
		"hour": 21.0,
		"fov": 72.0,
		"from": Vector3(3.9, 1.72, 3.1),
		"at": Vector3(-0.2, 1.25, -0.2),
	},
]


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
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.visible = false
	player.hud.visible = false

	var cycle := level.get_node(^"SkyAndTime") as DayNightCycle
	var grade := level.get_node(^"SkyAndTime/PaletteGrade") as PaletteGrade

	var camera := Camera3D.new()
	level.add_child(camera)
	camera.current = true

	var capture_error := OK
	var variants := grade.luts.size() + 1
	for view: Dictionary in VIEWS:
		cycle.time_of_day = view["hour"]
		camera.fov = view["fov"]
		camera.position = view["from"]
		camera.look_at(view["at"], Vector3.UP)
		for variant in variants:
			grade.active_index = variant
			var label := "ungraded" if variant == grade.luts.size() \
				else String(grade.lut_names[variant]).get_slice(" ", 0)
			await _settle()
			var out := "/tmp/lut_%s_%s.png" % [label, view["name"]]
			capture_error = _first_error(
				capture_error,
				viewport.get_texture().get_image().save_png(out))
			print("saved=", out, " err=", capture_error)
	quit(capture_error)


func _settle() -> void:
	await physics_frame
	for _frame in 12:
		await process_frame


func _first_error(current: Error, candidate: Error) -> Error:
	return candidate if current == OK else current
