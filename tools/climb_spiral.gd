extends SceneTree

# Drives the real player up the central spiral staircase (tangent-following) and
# reports the height reached. Headless:
#   godot --headless --path . -s tools/climb_spiral.gd

const STAIR_RADIUS := 1.55
const GAP := 4.7


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := (load("res://legacy/scenes/levels/wizard_tower.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame

	var player := scene.find_child("WizardPlayer", true, false) as CharacterBody3D
	if not player:
		print("NO PLAYER")
		quit(1)
		return

	# Place at the foot of the spiral.
	player.global_position = Vector3(STAIR_RADIUS, 0.7, 0.0)
	await physics_frame
	await physics_frame
	var start_y := player.global_position.y
	var peak := start_y

	Input.action_press("move_forward")
	for i in 1200:
		var p := player.global_position
		var ang := atan2(p.z, p.x)
		var tangent := Vector3(-sin(ang), 0.0, cos(ang))      # ascending (CCW)
		var radial := Vector3(cos(ang), 0.0, sin(ang))
		var want := (tangent - radial * 0.22).normalized()    # curve to hold the radius
		player.rotation.y = atan2(-want.x, -want.z)
		await physics_frame
		peak = maxf(peak, player.global_position.y)
	Input.action_release("move_forward")

	var end := player.global_position
	print("start_y=%.2f  peak_y=%.2f  end=(%.2f,%.2f,%.2f)" % [start_y, peak, end.x, end.y, end.z])
	if peak > 3.8:
		print("SPIRAL CLIMB PASSED (reached y=%.2f, ~floor 2)" % peak)
		quit(0)
	else:
		print("SPIRAL CLIMB FAILED (stuck at y=%.2f)" % peak)
		quit(1)
