extends SceneTree

const PLAYER_SCENE := preload("res://game/player/player.tscn")

var _fail: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := PLAYER_SCENE.instantiate() as WizardPlayer
	root.add_child(player)
	await process_frame
	_check(player.get_node_or_null(^"Components/Locomotion") != null,
		"player composes locomotion as a child component")
	_check(player.get_node_or_null(^"Components/Look") != null,
		"player composes mouse look as a child component")
	_check(player.get_node_or_null(^"Components/ViewmodelMotion") != null,
		"player composes viewmodel motion as a child component")
	player.free()
	player = null
	await process_frame

	if _fail == 0:
		print("COMPOSITION TEST OK")
	else:
		print("COMPOSITION TEST FAILURES: ", _fail)
	quit(_fail)


func _check(ok: bool, message: String) -> void:
	if ok:
		print("[PASS] ", message)
	else:
		_fail += 1
		push_error("[FAIL] " + message)
