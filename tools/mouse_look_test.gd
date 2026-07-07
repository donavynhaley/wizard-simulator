extends SceneTree

# Regression test for mouse look: feeds a synthetic InputEventMouseMotion
# through the full input pipeline (including GUI) with the mouse captured and
# checks the player actually turned. Catches HUD controls swallowing motion.
# Needs a display (mouse capture is a no-op headless):
#   godot --path . -s tools/mouse_look_test.gd

var _fail := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := (load("res://scenes/levels/spellcraft_playground.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame

	var player: Node3D = scene.get_node("Player")
	_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "mouse captured on spawn")

	var before := player.rotation.y
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_visible_rect().size * 0.5  # captured cursor sits center
	motion.relative = Vector2(120.0, 0.0)
	motion.velocity = Vector2(1200.0, 0.0)
	Input.parse_input_event(motion)
	await process_frame
	await process_frame
	_check(absf(player.rotation.y - before) > 0.001,
		"mouse motion turns the player (dy=%.5f)" % (player.rotation.y - before))

	var head: Node3D = player.get_node("Head")
	var pitch_before := head.rotation.x
	var motion_up := InputEventMouseMotion.new()
	motion_up.position = root.get_visible_rect().size * 0.5
	motion_up.relative = Vector2(0.0, 90.0)
	Input.parse_input_event(motion_up)
	await process_frame
	await process_frame
	_check(absf(head.rotation.x - pitch_before) > 0.001,
		"mouse motion pitches the head (dx=%.5f)" % (head.rotation.x - pitch_before))

	if _fail == 0:
		print("MOUSE LOOK TEST OK")
	else:
		print("MOUSE LOOK TEST FAILURES: ", _fail)
	quit(_fail)


func _check(cond: bool, label: String) -> void:
	print(("[PASS] " if cond else "[FAIL] ") + label)
	if not cond:
		_fail += 1
