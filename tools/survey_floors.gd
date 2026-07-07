extends SceneTree

# Loads the round tower, sanity-checks the 5 floors + spiral stair, probes the
# spiral for a continuous walkable surface, and renders each floor to
# user://floor_<n>.png. Run WITH a display:
#   godot --path . -s tools/survey_floors.gd

const MAIN_SCENE_PATH := "res://legacy/scenes/levels/wizard_tower.tscn"
const GAP := 4.7
const STAIR_RADIUS := 1.55
const WR := 6.5
var _fail := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	await process_frame

	_check(scene.find_child("WizardPlayer", true, false) != null, "player spawned")
	_check(scene.find_child("F0_Floor_0Body", true, false) != null or scene.find_child("F0_Floor_1Body", true, false) != null, "floor 0 disc built")
	_check(scene.find_child("WallSeg0Body", true, false) != null, "circular outer wall built")
	_check(scene.find_child("Newel0Body", true, false) != null, "spiral newel built")
	_check(scene.find_child("Step0_0Body", true, false) != null, "spiral steps built")
	_check(scene.find_child("F0_TeleporterBase", true, false) == null, "teleporter removed")
	_check(scene.find_child("EntryDoorLeftBody", true, false) != null, "F1 arcane door")
	_check(scene.find_child("EntryCarpet", true, false) != null, "F1 talking carpet")
	_check(scene.find_child("SkullyCranium", true, false) != null, "F2 Skully skull")
	_check(scene.find_child("BigCauldronPotBody", true, false) != null, "F3 cauldron")
	_check(scene.find_child("TrainingDummyPostBody", true, false) != null, "F4 training dummy")
	_check(scene.find_child("ScryOrbBody", true, false) != null, "F5 scrying orb")
	_check(scene.find_child("QuestCageTop", true, false) != null, "F5 courier cage")

	_probe_spiral(scene)

	# Render each floor from a point in the ring.
	var hud := scene.find_child("HUD", true, false) as CanvasLayer
	if hud:
		hud.visible = false
	var cam := Camera3D.new()
	cam.fov = 74.0
	cam.current = true
	root.add_child(cam)
	var player_cam := scene.find_child("Camera3D", true, false) as Camera3D
	if player_cam:
		player_cam.current = false
	for i in 5:
		var base := i * GAP
		cam.position = Vector3(4.6, base + 2.4, 4.6)
		cam.look_at(Vector3(-2.5, base + 1.4, -1.5), Vector3.UP)
		await process_frame
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png("user://floor_%d.png" % i)
		print("rendered floor ", i)

	if _fail == 0:
		print("TOWER SURVEY OK")
	else:
		print("TOWER SURVEY FAILURES: ", _fail)
	quit(_fail)


func _probe_spiral(scene: Node) -> void:
	# Cast rays down along the spiral centreline (gap 0) and confirm a continuous rise.
	var space := (scene as Node3D).get_world_3d().direct_space_state
	var last := -99.0
	var max_step := 0.0
	var samples := 40
	var covered := 0
	for k in samples + 1:
		var a := TAU * float(k) / samples
		var x := cos(a) * STAIR_RADIUS
		var z := sin(a) * STAIR_RADIUS
		# Sample a local window around the expected ascending-ramp height so we don't
		# hit the overlapping top of the turn at the seam angle.
		var expected := GAP * float(k) / samples
		var params := PhysicsRayQueryParameters3D.create(Vector3(x, expected + 0.9, z), Vector3(x, expected - 1.2, z))
		var hit := space.intersect_ray(params)
		if hit:
			covered += 1
			var h: float = hit.position.y
			if last > -50.0:
				max_step = maxf(max_step, absf(h - last))
			last = h
	_check(covered >= samples - 2, "spiral surface continuous (%d/%d samples hit)" % [covered, samples + 1])
	# The climb test (tools/climb_spiral.gd) is authoritative; small segment junctions
	# up to ~0.7 m are traversable by the controller.
	_check(max_step < 0.75, "no big vertical gaps on spiral (max step %.2f m)" % max_step)


func _check(cond: bool, label: String) -> void:
	print(("[PASS] " if cond else "[FAIL] ") + label)
	if not cond:
		_fail += 1
